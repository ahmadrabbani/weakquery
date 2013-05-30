#!/usr/bin/perl -w

# -----------------------------------------------------------------
# Name:      indx4.pl
# Author:    Kiduk Yang, 06/05/2004
#              modified trec04/indx4.pl (06/25/2004)
#              modified trec05/indx4.pl for blog data (07/19/2006)
#              modified trec06/indx4.pl (05/30/2007)
#              $Id: indx4.pl,v 1.2 2007/07/16 22:08:16 kiyang Exp $
# -----------------------------------------------------------------
# Description:  
#   1. for each subcollection, run sr_preproc2.c to create files
#      needed for sr.c for subcollection retrieval.
#   2. create avg_uniq_coll for the whole collection
#     -- the average number of unique terms per document for the collection
#   3. for each subcollection, run Lnu_all.c to create doc_norms_all
#     -- length normalized doc. term wts pivoted for the whole collection
#   4. for each subcollection, create tnf_all file, which
#      is tnf file updated with the whole collection df.
#      also, create token_cnt file (total number of tokens)
#   5. compute statistics needed for okapi weights
#     -- dl/avgdl, Robertson-Sparck Jones weight (w/o relevance data)
#   6. call mkrab.cc to create the RAB file.
# -----------------------------------------------------------------
# Arguments: arg1 = run mode (0 for test, 1 for real)
#            arg2 = subcollection prefix (e.g., sub, subx)
#            arg3 = subcollection count (e.g., 53)
# INPUT:  $ddir/$subd/tnf    -- term-df file
#         $ddir/$subd/tnt    -- term-to-term# file
#         $ddir/$subd/dnf    -- doc-tf file
# OUTPUT: $ddir/avg_uniq_coll
#            -- avg# uniq terms per doc for whole collection
#         $ddir/maxdocno
#            -- total number of documents in whole collection
#         $ddir/token_cnt
#            -- total number of tokens in whole collection
#         $ddir/$sub/avg_uniq_coll
#            -- avg# uniq terms per doc for subcoll.
#         $ddir/$sub/token_cnt
#            -- total number of tokens in subcollection
#         $ddir/$sub/index_params  -- indexing parameter file
#         $ddir/$sub/alm_params    -- parameters for alm.mr.c
#         $ddir/$sub/doc_norms     -- length-normalized term weights
#                                      pivotted for subcollection.
#         $ddir/$sub/doc_norms_all -- length-normalized term weights
#                                      pivotted for whole collection.
#         $ddir/$sub/avg_tf        -- tf summary statistics file
#         $ddir/$subd/sum_dnf      -- df summary statistics file
#         $ddir/$subd/tnf_all      -- term-df file for whole collection
#         $ddir/$subd/ran_tnf_all  -- RAB: term-df file for whole collection
#         $ddir/$subd/RS_wt        -- Robertson-Sparc Jones weight (estimated)
#         $ddir/$subd/dl_avdl      -- doc_length / avg_doc_length (in tokens)
#         $ddir/$prog            -- program     (optional)
#         $ddir/$prog.log        -- program log (optional)
#         $ddir/$subd/$sr_preproc2.c.log -- program log for sr_preproc2.c
#         $ddir/$subd/avg_tf.c.log      -- program log for avg_tf.c
#         $ddir/$subd/Lnu.c.log         -- program log for Lnu_all.c
#         $ddir/Lnu_all(x).c.log           -- program log for Lnu_all.c
#         NOTE: $ddir = data directory
#               $subd = subcollection directory 
# ------------------------------------------------------------------------
# NOTE1:  see sr_preproc2.c for detailed explanation of subprocesses
#           - sr_preproc2.out calls avg_tf.out and Lnu.out
# NOTE2:  currently works for hard track only
# ------------------------------------------------------------------------

$log=1;                              # program log flag
$debug=0;                            # debug flag
$filemode= 0640;                     # to use w/ perl chmod
$filemode2= 640;                     # to use w/ system chmod
$dirmode= 0750;                      # to use w/ perl mkdir
$dirmode2= 750;                      # to use w/ system chmod (directory)
$group= "trec";                      # group ownership of files
$author= "kiyang\@indiana.edu";      # author's email

print "$debug,$filemode,$filemode2,$dirmode,$dirmode2,$group,$author\n" if ($debug);


#------------------------
# global variables
#------------------------

$wpdir=  "/u0/widit/prog";           # widit program directory
$tpdir=  "$wpdir/trec08";            # TREC program directory
$ddir=   "/u3/trec/blog08";          # index directory
$slope=  "0.3";                      # slope for Lnu weight

# files created by sr_preproc2.c
@new_files= ("doc_norms*","sum_dnf","avg*","*log","*params","*all");

# C programs used 
@cprogs= ("Lnu.c","avg_tf.c","sr_preproc2.c","Lnu_all.c");

#------------------------
# program arguments
#------------------------
if (@ARGV<3) {
    die "arg1= run mode (0 for test, 1 for real)\n",
        "arg2= subcollection prefix (e.g. sub, subx)\n",
        "arg3= subcollection count (e.g. 51)\n";
}
($run_mode,$subdpfx,$subdn) = @ARGV;

$subdn= 2 if ($run_mode==0);

$cprogs[-1] = "Lnu_allx.c" if ($subdpfx=~/x$/);

# collection subdirectories
for($i=1;$i<=$subdn;$i++) {
    push(@subd,"$subdpfx$i");
}


#-------------------------------------------------
# start program log
#-------------------------------------------------

require "$wpdir/logsub2.pl";   # general subroutine library

$sfx= $subdpfx;        # program log file suffix
$argp=0;               # if 1, do not print arguments to log
$append=0;             # log append flag

@start_time= &begin_log($ddir,$filemode,$sfx,$argp,$append) if ($log);


#--------------------------------------------------------------------
# run sr_preproc2.out for each subcollection
#  - create files needed for the retrieval and feedback modules
#    (sr_preproc2.out calls avg_tf.out and Lnu.out)
#--------------------------------------------------------------------

foreach $subd(@subd) {

    # subcollection directory
    my  $dir="$ddir/$subd";

    # determine total number of files to process
    my $fnref="$dir/fnref";
    my $maxfn= `cat $fnref | wc -l`;
    chomp $maxfn;

    print LOG "-- Executing: sr_preproc2.out $dir $tpdir $slope $maxfn\n";

    chdir($tpdir);
    my $ec= system("$tpdir/sr_preproc2.out $dir $tpdir $slope $maxfn");
    if ($ec) { print LOG "  !!Error w/ sr_preproc: EC= $ec\n"; }

}


#--------------------------------------------------------------------
# 1. create avg_uniq_coll file for the whole collection
#   - average number of unique terms per document for the whole collection
# 2. create maxdocno file
#   - total number of documents in the whole collection
# Note: this step requires avg_tf created in above step     
#--------------------------------------------------------------------

$cum_uniq_all=0;
$docno_all=0;

foreach $subd(@subd) {

    # subcollection directory
    my  $dir="$ddir/$subd";

    print LOG "\n-- Creating avg_uniq_coll for the whole collection\n";

    my $inf= "$dir/avg_tf";
    open(IN,$inf) || die "can't read $inf";
    my @lines=<IN>;
    close IN;
    chomp @lines;

    $cum_uniq=0;
    $docno=0;
    foreach (@lines) {
        s/^\s+//;
        my($dn,$max_tf,$tot_tf,$termcnt,$avg_tf)=split/\s+/;
        $cum_uniq += $termcnt;
        $cum_uniq_all += $termcnt;
	$docno++;
	$docno_all++;
    }

    print LOG "  $inf\n    $docno documents has total length of $cum_uniq terms\n";

}

print LOG "  Total number of documents = $docno_all\n\n";

# total number of documents in the collection
$outf1= "$ddir/maxdocno";
$outf1 .= "X" if ($subdpfx=~/x$/);
$outf1 .= "_new" if ($subdpfx=~/^n/);
open(OUT1,">$outf1") || die "can't write to $outf1";
print OUT1 "$docno_all\n";
close OUT1;

# average unique terms per documents (for whole collection)
$avg_uniq= $cum_uniq_all/$docno_all;

$outf2= "$ddir/avg_uniq_coll";
$outf2 .= "X" if ($subdpfx=~/x$/);
$outf2 .= "_new" if ($subdpfx=~/^n/);
open(OUT2,">$outf2") || die "can't write to $outf2";
printf OUT2 ("%.13f\n",$avg_uniq);
close OUT2;
 

#--------------------------------------------------------------------
# run Lnu_all.c for each subcollection
# Note: Lnu_all.c requires avg_uniq_coll created above
#--------------------------------------------------------------------
print LOG "\n";
foreach $subd(@subd) {

    # subcollection directory
    my  $dir="$ddir/$subd";

    if ($subdpfx=~/x$/) {
	print LOG "-- Executing Lnu_allx.out $ddir $subd $slope _new\n";
	my $ec= system("$tpdir/Lnu_allx.out $ddir $subd $slope _new");
	if ($ec) { print LOG "  !!Error w/ Lnu_allx.out: EC= $ec\n"; }
    }
    else {
	print LOG "-- Executing Lnu_all.out $ddir $subd $slope _new\n";
	my $ec= system("$tpdir/Lnu_all.out $ddir $subd $slope _new");
	if ($ec) { print LOG "  !!Error w/ Lnu_all.out: EC= $ec\n"; }
    }
}


#--------------------------------------------------------------------
# create tnf_all and its RAB file
#--------------------------------------------------------------------
$file= "tnf_all";
&tnfall($file);



#--------------------------------------------------------------------
# create files needed for okapi weight
# 1. RS_wt_all:   Robertson-Sparck Jones weight for whole collection
#      TN wt per line
#   wt = log(($N-$n+0.5)/($n+0.5))
#      where $N = total number of documents
#            $n = number of documents in which term occurs (df)
# 2. dl_avdl_all: doclen/avg_doclen (in tokens) for whole collection
#      DN value
#--------------------------------------------------------------------

# total number of documents in the whole collection
$maxdnf= "$ddir/maxdocno";
$maxdnf .= "X" if ($subdpfx=~/x$/);
$maxdnf .= "_new" if ($subdpfx=~/^n/);
$N= `cat $maxdnf`; 
chomp $N;

# target string to get subcollection avdl
$tstr= 'Average number of tokens per document';

# compute & output Robertson-Sparck Jones weight for whole collection
$avdl_all=0;
$tkcnt_all=0;
print LOG "\n";
foreach $subd(@subd) {
    my $inf= "$ddir/$subd/tnf_all";
    my $outf= "$ddir/$subd/RS_wt_all";

    open(IN,$inf) || die "can't read $inf";
    open(OUT,">$outf") || die "can't write to $outf";
    while(<IN>) {
        chomp;
        my($tn,$df)=split/\s+/;
        my $wt= log(($N-$df+0.5)/($df+0.5));
        printf OUT ("$tn %.10f\n",$wt);
    }
    close IN;
    close OUT;

    print LOG "$ddir/$subd/RS_wt_all created for Okapi weight\n";

    # get subcollection avdl
    my $avdl= `grep '$tstr' $ddir/$subd/sum_dnf`;
    $avdl=~s/^ +$tstr: (\d+\.\d+)\n/$1/;
    $avdl_all += $avdl;

    # get token counts
    $tkcnt= &getstf("$ddir/$subd");
    `echo $tkcnt > $ddir/$subd/token_cnt`;
    $tkcnt_all += $tkcnt;

}

$tkcntf= "$ddir/token_cnt";
$tkcntf .= "X" if ($subdpfx=~/x$/);
$tkcntf .= "_new" if ($subdpfx=~/^n/);
`echo $tkcnt_all > $tkcntf`; 


# avdl for whole collection
$avdl_all /= $subdn;

# compute dl/avdl for the whole collection
foreach $subd(@subd) {
    my $inf= "$ddir/$subd/avg_tf";
    my $outf= "$ddir/$subd/dl_avdl_all";

    open(IN,$inf) || die "can't read $inf";
    open(OUT,">$outf") || die "can't write to $outf";
    while(<IN>) {
        chomp;
        s/^\s+//;
        my($dn,$d2,$dl)=split/\s+/;
        my $wt= $dl/$avdl_all;
        printf OUT ("$dn %.10f\n",$wt);
    }
    close IN;
    close OUT;
    print LOG "$ddir/$subd/dl_avdl_all created for Okapi weight\n";

}



#--------------------------------
# copy programs & set file permissions
#--------------------------------
@errs=();

foreach $prog(@cprogs) {
    system "cp $tpdir/$prog $ddir";
    my $ec= system "chmod $filemode2 $ddir/$prog";
    push(@errs,"!!ERROR ($ec): chmod $filemode2 $ddir/$prog") if ($ec);
}

foreach $subd(@subd) {
    foreach $file(@new_files) {
	#my $ec= system "chown :$group $ddir/$subd/$file";
	#print LOG "\n!!ERROR ($ec): chown :$group $ddir/$subd/$file\n\n" if ($ec);
	my $ec2= system "chmod $filemode2 $ddir/$subd/$file";
	push(@errs,"!!ERROR ($ec2): chmod $filemode2 $ddir/$subd/$file") if ($ec2);
    }
}

if (@errs) {
    $errstr= join("\n",@errs);
    print LOG "\n\n$errstr\n\n";
}


#--------------------------------
# end program
#--------------------------------
if ($log) { &end_log($tpdir,$ddir,$filemode,@start_time); }


# notify author of program completion
#&notify($sfx,$author);


###################################
# subroutines
###################################

BEGIN { print STDOUT "\n"; }
END { print STDOUT "\n"; }

#-----------------------------------------------------------
# compute tn-collection DF files
#-----------------------------------------------------------
# arg1= output filename
#-----------------------------------------------------------
sub tnfall {
    my $fname=shift;

    print LOG "-- Computing collection DF for $fname --", timestamp(), "\n";

    my %tnf=();

    #---------------------------------
    # get DF for the whole collection
    #---------------------------------

    my $dcnt=0;  # directory count

    foreach $subd(@subd) {

        print LOG "   processing subcollection $subd\n";

        $dcnt++;

	# subcollection directory
	my  $dir="$ddir/$subd";

        my $tnt="$dir/tnt";
        my $tnf="$dir/tnf";

        my $name="tnt$dcnt";
        %$name=();

        open(TNT,"$tnt") || die "can't read $tnt";
        while(<TNT>) {
            chomp;
            my ($tn,$term)=split(/ /,$_);
            $$name{$tn}=$term;
        }
        close(TNT);

        open(TNF,"$tnf") || die "can't read $tnf";
        while(<TNF>) {
            chomp;
            my ($tn,$df)=split(/ /,$_);
            $tnf{$$name{$tn}} += $df;
        }
        close(TNF);

    }

    #---------------------------------
    # output collection DF to a file
    #---------------------------------

    $dcnt=0;  # directory count

    foreach $subd(@subd) {

        $dcnt++;

	# subcollection directory
	my  $dir="$ddir/$subd";

        my $tnfall="$dir/$fname";
        
        my $name="tnt$dcnt";
        
        open(OUT,">$tnfall") || die "can't write to $tnfall";
        local $tcnt=0;
        foreach $tn(sort bynumber keys %$name) {
            print OUT "$tn $tnf{$$name{$tn}}\n";
            $tcnt++;
        }
        close(OUT);
        
        print LOG "  $tcnt terms in $tnfall\n";
        my $ec= system "$tpdir/mkrab.out $dir $fname 1";
        if ($ec>0) { print LOG "  !!mkrab.out problem\n"; }
    
    }
    
    my $maxtn= keys(%tnf); 
    print LOG "  $maxtn unique terms in the whole collection\n\n";
    
} # endsub tnfall


#----------------------------------------------------
# get subcollection token frequency
#   - number of tokens in the subcollection
#----------------------------------------------------
# arg1= sub collection directory
# r.v.= df
#----------------------------------------------------
sub getstf {
    my($ind)=@_;

    my $ttf=0;

    my $fref= "$ind/fnref";      # fn-to-fname mapping

    # get file count
    my $str= `tail $fref`;
    return -1 if (!$str);
    chomp $str;
    my ($fn)=split(/ /,$str);

    # get whole token freq
    for(my $i=1;$i<=$fn;$i++) {
        my $in="$ind/seqindx/$i";
        open(IN,$in) || die "can't read $in";
        while(<IN>) {
            if (!m|<DN>(.+)?</DN>|) {
                my($term,$tf)=split/ /;
                $ttf += $tf;
            }
        }
    }

    if ($ttf) {
        return $ttf;
    }
    else {
        return -1;
    }

} #endsub getstf

