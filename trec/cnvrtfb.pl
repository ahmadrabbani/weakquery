#!/usr/bin/perl -w

# -----------------------------------------------------------------
# Name:      cnvrtf.pl
# Author:    Kiduk Yang, 07/02/2005
#              modified trec04/cnvrtf.pl (07/2004)
# -----------------------------------------------------------------
# Description:  converts WIDIT retrieval results to default TREC format.
#    -- batch mode to process multiple subdirectories
# -----------------------------------------------------------------
# ARGUMENTS: arg1 -- track (genomics, hard, robust, web)
#            arg2 -- query type (t for training, e evaluation topics)
#            arg3 -- query subdirectory (e.g. s0o0, s1o0)
# INPUT:     $idir/$arg1/results/$qtype/$arg3/all/$qsubd/q$qlen$qform$qn.$iter
#              -- merged ranked list (whole collection)
# OUTPUT:    $idir/$arg1/results/$qtype/trecfmt/$arg3/$outf
#            $idir/$arg1/$prog      -- program     (optional)
#            $idir/$arg1/$prog.log  -- program log (optional)
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
$tpdir=  "$wpdir/trec05";            # TREC program directory
$idir=   "/u0/trec/2005";            # index directory
$maxrtcnt= 1000;                     # max. number of documents per result

# query type
%qtype= ("e"=>"test","t"=>"train","e0"=>"test0","t0"=>"train0");

# retrieval type
%rtypes= ("okapi"=>"o","okapi25"=>"o2","okapi50"=>"o5","okapi250"=>"o25","vsm"=>"v");

# query subdirectory
%qsubs= (
"cf"=>"cf",
"def"=>"d",
"def2"=>"d2",
"syn"=>"s",
"syndef"=>"sd",
"syndef2"=>"sd2",
"nla"=>"na",
"nlc"=>"nc",
"nld"=>"nd",
"nln"=>"nn",
"nls"=>"ns",
"olw_td"=>"ows",
"olw_tdn"=>"ow",
"wpb"=>"wb",
"wptb"=>"wtb",
"wpt0b"=>"wt0b",
"wpt1b"=>"wt1b",
"wwb"=>"wwb",
"wps"=>"ws",
"wpts"=>"wts",
"wpt0s"=>"wt0s",
"wpt1s"=>"wt1s",
"wws"=>"wws",
"fallb"=>"fab",
"fallf"=>"faf",
"fcf"=>"fcf",
"fnlp"=>"fnl",
"folw"=>"fow",
"ftopb"=>"ftb",
"ftopf"=>"ftf",
"fwbx"=>"fwx",
);

# collection subdirectories
@hard_subd= ("APW","NYT1","NYT2","XIE");
@hardt_subd= ("FBIS","FR94","FT","LATIMES");
#@hardm_subd= ("AFE","APE","CNE","LAT","NYT","SLN","UME","XIE");

require "$wpdir/logsub.pl";          # general subroutine library


#------------------------
# program arguments
#------------------------
$prompt= 
"arg1= track name (i.e. hard, spam)\n".
"arg2= query type (i.e. t for training, e for evaluation)\n".
"arg3= query subdirectory prefix (e.g. s0, s1, s2)\n";

%valid_args= (
0 => " hard spam ",
1 => " t e t0 e0 ",
2 => " s* s0* s1* s2* f* cf nl* wx* fusion ",
);

($arg_err,$dname,$qtype,$qdpfx)= chkargs($prompt,\%valid_args);
die "$arg_err\n" if ($arg_err);


# for HARD2005, use the same queries but different doc collections
#  - train: 2005 test topics;  2004 robust collection
#  - test:  2005 test topics;  2005 HARD collection
if (($dname eq 'hard') && ($qtype=~/^t/)) { 
    $dname2= $dname.$qtype;
    if ($qtype eq 't') { $qtype2= $qtype{'e'}; }
    elsif ($qtype eq 't0') { $qtype2= $qtype{'e0'}; }
}
else {
    $dname2= $dname;
    $qtype2= $qtype{$qtype};
}

# data directory
$ddir= "$idir/$dname2";               

# ------------------------------------------------
# get collection specific subdirectories & qnums
#-------------------------------------------------

if ($dname2 eq "hard") {
    @subd= @hard_subd;
    $subdn= @hard_subd;
}
elsif ($dname2 eq "hardt") {
    @subd= @hardt_subd;
    $subdn= @hardt_subd;
}

# create dnref hash
%dnref=();
&mkdnref($ddir,\@subd,\%dnref);

# TREC format result directory
$odir= "$ddir/results/$qtype{$qtype}/trecfmt";

# output directory
if (!-e $odir) {
    my @errs=&makedir($odir,$dirmode,$group);
    print LOG "\n",@errs,"\n\n" if (@errs);
}


#-------------------------------------------------
# start program log
#-------------------------------------------------

$sfx= "$qtype$qdpfx";   # program log file suffix
$noargp=0;              # if 1, do not print arguments to log
$append=0;              # log append flag

if ($log) { 
    @start_time= &begin_log($ddir,$filemode,$sfx,$noargp,$append); 
    print LOG "OutDir= $odir\n\n";
}


#-------------------------------------------------
# convert results to TREC format
#-------------------------------------------------

# 2005 test/evaluation topics
$qnlist=  "/u1/trec/topics/hard05.50.topics.txt";
open(IN,"grep '<num>' $qnlist |") || die "can't read $qnlist";
while(<IN>) {
    chomp;
    push(@qns,$1) if (/: (\d+)/);
}
close IN;

foreach $rtype('okapi','vsm') {

    my $indir= "$ddir/results/$qtype{$qtype}/$rtype";
    opendir(IND,$indir) || die "can't opendir $indir";
    my @dirs=readdir(IND);
    closedir IND;

    foreach $qsubd(@dirs) {
        next if ($qsubd !~/^$qdpfx/);

	# runtag suffix
	my ($runsfx,$qsubd0);
	if ($qsubd=~/^s(\d)(.*)$/) {
	    $qsubd0= "s$1";
	    $runsfx= $1;  
	    $runsfx .= $qsubs{$2} if ($2);
	}
	elsif ($qsubd=~/^(f.+)$/) {
	    $qsubd0= "s0";
	    $runsfx= $qsubs{$1};  
	}

	# merged result directory
	$rdir= "$indir/$qsubd/all";
	$rdir0= "$indir/$qsubd0/all";

	# get the list of result files to convert
	opendir(IND,$rdir) || die "can't opendir $rdir";
	my @files= readdir IND;
	closedir IND;

	# make random result file for failed queries
	$random_rtf= "$rdir/qran.1";
	&mkranrtf($rdir,\@files,$random_rtf);

	# write out TREC formated results
	foreach $subd(@files) {

	    next if ($subd=~/^\./);
	    next if (!-d "$rdir/$subd");

	    my $ind="$rdir/$subd";
	    my $outf="$odir/$qsubd/$rtype"."_$subd";

	    if (!-e "$odir/$qsubd") {
		my @errs=&makedir("$odir/$qsubd",$dirmode,$group);
		print LOG "\n",@errs,"\n\n" if (@errs);
	    }

	    print LOG "-- writing $outf\n";

	    $system= "wd$rtypes{$rtype}$subd$runsfx";

	    &cnvrtf($rdir,$rdir0,$subd,$outf,$system,\%dnref);

	}
    } #end-foreach $qsubd(@dirs) 
    
} #end-foreach $rtype('okapi','vsm') 


# ------------------------------------------------
# end program
# ------------------------------------------------

if ($log) { &end_log($tpdir,$ddir,$filemode,@start_time); }

# notify author of program completion
#&notify($sfx,$author);



############################################
# subroutines & print formats
############################################

# ------------------------------------------------
# Print format for TREC results
# ------------------------------------------------
             
format RDLIST =
@<<<    @<<   @<<<<<<<<<<<<<<<<<<  @######   @###.######  @<<<<<<<<<<<<
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
    my @dns= &sorthashbyval(\%randn,1,1);
    $rank=1;
    my $sc=10;
    open(OUT,">$outf") || die "can't write to $outf";
    foreach $dn(@dns) {
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
# arg2 = output file
# arg3 = system name
# arg4 = pointer to dnref hash
#-----------------------------------------------------
sub cnvrtf {
    my ($dir,$dir0,$subd,$out,$system,$dnrefhp)=@_;

    open(OUT,">$out") || die "can't write to $out";

    foreach $qn(@qns) {

        my $pfx=$subd;
        my $file= "$pfx$qn.1";
	my $in="$dir/$pfx/$file";

        # if query does not have any results,
        #  - use simpler query results
	my $file2;
        if (!-e $in) {
            chop $pfx;
            $file2= "$pfx$qn.1";
	    $in="$dir/$pfx/$file2";
	    #  if no simpler query results
	    #  - use simple expansion results
	    if (!-e $in) {
		$in="$dir0/$subd/$file";
		if (!-e $in) {
		    $in="$dir0/$subd/$file2";
		    if (!-e $in) {
			$in="$dir0/$pfx/$file2";
			#  if still no simpler query results
			#  - use random results
			if (!-e $in) {
			    $in= $random_rtf;
			}
		    }
		}
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
