#!/usr/bin/perl -w

# -----------------------------------------------------------------
# Name:      cnvrtf.pl
# Author:    Kiduk Yang, 07/02/2005
#              modified trec04/cnvrtf.pl (07/2004)
#              modified 4/18/2008 to handle webxQ results (e.g. qsxa901.10.1)
# -----------------------------------------------------------------
# Description:  converts WIDIT retrieval results to default TREC format.
# -----------------------------------------------------------------
# ARGUMENTS: arg1 -- subd prefix (sub, subx)
#            arg2 -- query type (t for training, e evaluation topics)
#            arg3 -- query subdirectory (e.g. s0)
#            arg4 -- retrieval type (vsm, okapi)
#            arg5 -- query prefix (optional)
#            arg6 -- result subdirectory (optional: results, results_new)
# INPUT:     $ddir/results/$qtype/$arg3/all/$qsubd/q$qlen$qform$qn.$iter
#              -- merged ranked list (whole collection)
# OUTPUT:    $ddir/results/$qtype/trecfmt/$arg3/$outf
#            $ddir/cnvlog/$prog      -- program     (optional)
#            $ddir/cnvlog/$prog.log  -- program log (optional)
#            NOTE: $qtype   = query type (train|eval)
#                  $qsubd   = q$qlen$qform
#                  $qname   = query name (q$qlen$qform$qn.$iter)
#                  $outf    = output filename
#                             ($arg4_q$qlen$qform$iter, e.g. vsm_qlc1)
#                  $qn      = query number
#                  $qlen    = query length (s, m, l)
#                  $qform   = query format (a=phrase, b=inflexion, c=acronym)
# -----------------------------------------------------------------
# NOTES:     
# ------------------------------------------------------------------------


$log=1;                              # program log flag
$debug=0;                            # debug flag
$filemode= 0640;                     # to use w/ perl chmod
$filemode2= 640;                     # to use w/ system chmod
$dirmode= 0750;                      # to use w/ perl mkdir
$dirmode2= 750;                      # to use w/ system chmod (directory)
$group= "trec";                      # group ownership of files
$author= "kiyang\@indiana.edu";      # author's email

print "$debug,$filemode,$filemode2,$dirmode,$dirmode2,$author\n" if ($debug);


#------------------------
# global variables
#------------------------

$wpdir=  "/u0/widit/prog";           # widit program directory
$tpdir=  "$wpdir/trec07";            # TREC program directory
$ddir=   "/u3/trec/blog07";          # index directory
$maxrtcnt= 1000;                     # max. number of documents per result

# query type
%qtype= ("e"=>"test","t"=>"train","t0"=>"train0");

# retrieval type
%rtypes= ("okapi"=>"o","vsm"=>"v");

# topic file
%topics= ("e"=>"07.topics.901-950","t"=>"06.topics.851-900","t0"=>"06.topics.blog-train");

require "$wpdir/logsub2.pl";          # general subroutine library


#------------------------
# program arguments
#------------------------
$prompt= 
"arg1= collection subd name (e.g. sub, subx)\n".
"arg2= query type (i.e. t for training, e for evaluation)\n".
"arg3= query subdirectory (e.g. s0, s1, s2)\n".
"arg4= retrival type (e.g. okapi, vsm)\n".
"arg5= query prefix (optional)\n".
"arg6= result subdirectory (e.g. results_new)\n";

%valid_args= (
0 => " sub subx nsub nsubx ",
1 => " t t0 e ",
2 => " s0* s1 ",
3 => " okapi vsm ",
);

($arg_err,$subdpfx,$qtype,$qsubd,$rtype,$qpfx,$resultd)= chkargs($prompt,\%valid_args);
die "$arg_err\n" if ($arg_err);

$qpfx="q" if (!$qpfx);
$resultd="results" if (!$resultd);

# runtag suffix
if ($qsubd=~/^s(.+)$/) {
    $runsfx= $1;
}
$runsfx .= 'x' if ($subdpfx=~/subx$/);

$qnlist= "/u1/trec/topics/$topics{$qtype}";

if ($subdpfx=~/sub$/) {
    # merged result directory
    $rdir= "$ddir/$resultd/$qtype{$qtype}/$rtype/$qsubd/all";
    # TREC format result directory
    $odir= "$ddir/$resultd/$qtype{$qtype}/trecfmt/$qsubd";
}
elsif ($subdpfx=~/subx$/) {
    # merged result directory
    $rdir= "$ddir/$resultd/$qtype{$qtype}/$rtype/$qsubd/allx";
    # TREC format result directory
    $odir= "$ddir/$resultd/$qtype{$qtype}/trecfmtx/$qsubd";
}


# log directory
$logd= "$ddir/cnvlog";               
if (!-e $logd) {
    my @errs=&makedir($logd,$dirmode,$group);
    print "\n",@errs,"\n\n" if (@errs);
}


# ------------------------------------------------
# get collection specific subdirectories & qnums
#-------------------------------------------------

opendir(IND,$ddir) || die "can't opendir $ddir";
my @files=readdir(IND);
closedir IND;
$subdn=0;
foreach (@files) {
    $subdn++ if (/^$subdpfx\d+$/);
}

for($i=1; $i<=$subdn; $i++) {
    push(@subd,"$subdpfx$i");
}

# test/evaluation topics
open(IN,"grep '<num>' $qnlist |") || die "can't read $qnlist";
while(<IN>) {
    chomp;
    push(@qns,$1) if (/: (\d+)/);
}
close IN;


#-------------------------------------------------
# start program log
#-------------------------------------------------

$sfx= $rtypes{$rtype}."$qtype$qsubd";   # program log file suffix
$sfx .= 'x' if ($subdpfx=~/x$/);
$sfx .= 'old' if ($resultd=~/old/);
$sfx .= 'new' if ($resultd=~/new/);

$noargp=0;                    # if 1, do not print arguments to log
$append=0;                    # log append flag

if ($log) { 
    @start_time= &begin_log($logd,$filemode,$sfx,$noargp,$append); 
    print LOG "Input Files  = $rdir/\$qsubd/q*\n",
              "Output Files = $odir\n\n";
}

# output directory
if (!-e $odir) {
    my @errs=&makedir($odir,$dirmode,$group);
    print LOG "\n",@errs,"\n\n" if (@errs);
}




#-------------------------------------------------
# convert results to TREC format
#-------------------------------------------------

# create dnref hash
%dnref=();
&mkdnref($ddir,\@subd,\%dnref);

# get the list of result files to convert
opendir(IND,$rdir) || die "can't opendir $rdir";
@files= readdir IND;
closedir IND;

# make random result file for failed queries
$random_rtf= "$rdir/qran.1";
&mkranrtf($rdir,\@files,$random_rtf);

# write out TREC formated results
foreach $subd(@files) {

    next if ($subd!~/^$qpfx/ || (!-d "$rdir/$subd"));

    my $ind="$rdir/$subd";
    my $outf="$odir/$rtype"."_$subd";

    print LOG "-- writing $outf\n";

    if ($subd=~/\./) {
        my ($pfx,$sfx)=split/\./,$subd;
        $system= "wd$rtypes{$rtype}$pfx$runsfx$sfx";
    }
    else {
        $system= "wd$rtypes{$rtype}$subd$runsfx";
    }

    &cnvrtf($rdir,$subd,$outf,$system,\%dnref);

}
    

# ------------------------------------------------
# end program
# ------------------------------------------------

if ($log) { &end_log($tpdir,$logd,$filemode,@start_time); }

# notify author of program completion
#&notify($sfx,$author);



############################################
# subroutines & print formats
############################################

# ------------------------------------------------
# Print format for TREC results
# ------------------------------------------------
             
format RDLIST =
@<<<  @<<  @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<  @######   @###.######  @<<<<<<<<<<<<
$qn, Q0, $docn, $rank, $score, $system
.

        
#-----------------------------------------------------
# create %dnref
#  - key= $dn-$dir
#  - val= $trdn
#-----------------------------------------------------
# arg1= data directory
# arg2= pointer to subcollection directory array
# arg3= pointer to dnref hash
#-----------------------------------------------------
sub mkdnref {
    my($dir,$subdlp,$drefhp)= @_;

    foreach $subd(@$subdlp) {
	my $file="$dir/$subd/dnref";
	open(IN,"$file") || die "can't read $file";
	while(<IN>) {
	    chomp;
	    my ($dn,$trdn)=split(/ +/);
	    $$drefhp{"$dn-$subd"}=$trdn;
	}
	close(IN);
    }

} #endsub mkdnref


#-----------------------------------------------------
# create a random result file
#-----------------------------------------------------
# arg1= result directory
# arg2= pointer to sub-result directory array
# arg3= output file 
#-----------------------------------------------------
sub mkranrtf {
    my($dir,$subdlp,$outf)= @_;
    my %randn;

    foreach $d(@$subdlp) {
	my $subd="$dir/$d";
        next if (!-d $subd);
	opendir(IND,"$subd") || die "can't opendir $subd";
	my @ds=readdir(IND);
	closedir IND;
	foreach $f(@ds) {
	    my $file="$subd/$f";
	    open(IN,"$file") || die "can't read $file";
	    my $rank=0;
	    while(<IN>) {
		last if ($rank>$maxrtcnt);
		s/^\s+//;
		my ($rnk,$dn)=split(/\s+/);
		$rank++;
		$randn{$dn}++;
	    }
	    close(IN);
	}
    }

    # rank by number of occurence in results
    $rank=1;
    my $sc=10;
    open(OUT,">$outf") || die "can't write to $outf";
    foreach $dn(sort {$randn{$b}<=>$randn{$a}} keys %randn) {
        $sc -= 0.002;
        print OUT "$rank $dn $sc\n";
	$rank++;
	last if ($rank>$maxrtcnt);
    }
    close OUT;

} #endsub mkdnref


#-----------------------------------------------------
# convert results to TREC format
#-----------------------------------------------------
# arg1 = input directory
# arg2 = subdirectory name (e.g., ql, qln, qs)
# arg3 = output file
# arg4 = system name
# arg5 = pointer to dnref hash
#-----------------------------------------------------
sub cnvrtf {
    my ($dir,$subd,$out,$system,$dnrefhp)=@_;

    open(OUT,">$out") || die "can't write to $out";

    foreach $qn(@qns) {

        my ($pfx,$sfx,$file);
        if ($subd=~/\./) { 
            ($pfx,$sfx)=split/\./,$subd; 
            $file= "$pfx$qn.$sfx.1";
        }
        else { 
            $pfx=$subd; 
            $file= "$pfx$qn.1";
        }

	my $in="$dir/$subd/$file";

        # if query does not have any results,
        #  - use simpler query results
	my $file2;
        if (!-e $in) {
            print LOG "!!Random used for missing result: $in\n";
            chop $pfx;
            $file2= "$pfx$qn.1";
	    $in="$dir/$pfx/$file2";
	    #  if still no simpler query results
	    #  - use random results
	    if (!-e $in) {
		$in= $random_rtf;
	    }
        }

	open(IN,$in) || die "can't read $in";

	select(OUT);
	$~= "RDLIST";

	$rank=1;
	while (<IN>) {
	    last if ($rank>$maxrtcnt);
	    chomp;
	    s/^\s+//;
	    local ($rnk,$dn,$score)=split(/\s+/);
	    print "rank=$rnk, dn=$dn, sc=$score\n" if ($debug);
	    warn "Rank Error? $rank NE $rnk\n" if ($rnk != $rank);
	    $docn=$$dnrefhp{$dn};
	    write; 
	    $rank++;
	}
	close(IN);

    }

    close(OUT);
    select(STDOUT);

} #endsub cnvrtf
