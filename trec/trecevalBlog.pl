#!/usr/bin/perl -w

# -----------------------------------------------------------------
# Name:      trecevalBlog.pl
# Author:    Kiduk Yang, 06/13/2008
#              modified trec07/treceval.pl (11/2007)
# -----------------------------------------------------------------
# Description:  evaluate TREC results
# -----------------------------------------------------------------
# ARGUMENTS: arg1 -- query type (t for training, e evaluation topics)
#            arg2 -- query subdirectory (e.g. s0, s1, s1R, s0wk, s0gg, s0gg2)
#            arg3 -- result subdirectory (optional: results, results2)
#            arg4 -- result file prefix (optional)
# Input:     $idir/$arg1/results/$qtype/trecfmt/*
# Output:    $idir/$arg1/results/$qtype/eval/*
#            $idir/$arg1/$prog      -- program     (optional)
#            $idir/$arg1/$prog.log  -- program log (optional)
#            NOTE: $qtype   = query type (train|test)
# -----------------------------------------------------------------
# NOTES:     runs trec_eval.c
# ------------------------------------------------------------------------

use strict;
use Data::Dumper;
$Data::Dumper::Purity=1;

my ($debug,$filemode,$filemode2,$dirmode,$dirmode2,$author,$group);
my ($log,$logd,$sfx,$noargp,$append,@start_time);

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

my $wpdir=  "/u0/widit/prog";           # widit program directory
my $tpdir=  "$wpdir/trec08";            # TREC program directory
my $pdir=  "$tpdir/blog";               # TREC program directory
my $ddir=   "/u3/trec/blog08";          # index directory
my $qreld=  "/u1/trec/qrels";           # index directory


# trec_eval.c by Chris Buckley
my $evalc=  "$tpdir/trec_eval.8.1/trec_eval";

# query type
my %qtypes= ("e"=>"test","ex"=>"test","t"=>"train","tx"=>"train");


require "$tpdir/logsub2.pl";     # general subroutine library


#------------------------
# program arguments
#------------------------
my $prompt= 
"arg1= query type (i.e. t, tx, e, ex)\n".
"arg2= query subdirectory (e.g. s0, s0R, s0R1, etc.)\n".
"arg3= result subdirectory (optional: results, results2)\n".
"arg4= result file prefix (optional)\n";

my %valid_args= (
0 => " t e tx ex ",
1 => " s0* ",
);

my ($arg_err,$qtype,$qsubd,$resultd,$rfpfx)= chkargs($prompt,\%valid_args);
die "$arg_err\n" if ($arg_err);

# qrels files
my $qrels;
if ($qtype=~/^e/) {
    $qrels= "$qreld/qrels.opinion.blog08";
}
else {
    $qrels= "$qreld/qrels.opinion.blog06-07";
}

$resultd="results" if (!$resultd);

my ($trecd,$fsfx);
if ($qtype=~/x/) { 
    $trecd='trecfmtx'; 
    $fsfx='x'; 
}
else { 
    $trecd='trecfmt'; 
    $fsfx=''; 
}

# TREC format result directory
my $idir= "$ddir/$resultd/$qtypes{$qtype}/$trecd/$qsubd";

# evaluation directory
my $odir= "$ddir/$resultd/$qtypes{$qtype}/eval/$qsubd";

# log directory
$logd= "$ddir/rtlog";               
`mkdir -p $logd` if (!-e $logd);


#-------------------------------------------------
# start program log
#-------------------------------------------------

$sfx= "$qtype$qsubd";         # program log file suffix
$sfx .= "_$1" if ($resultd=~/results(.+)$/);
$sfx .= "_$rfpfx" if ($rfpfx);
$noargp=0;                    # if 1, do not print arguments to log
$append=0;                    # log append flag

if ($log) { 
    @start_time= &begin_log($logd,$filemode,$sfx,$noargp,$append); 
    print LOG "Input Files  = $idir/*\n",
              "Output Files = $odir/*\n\n";
}

foreach my $d($odir,$logd) {
    if (!-e $d) {
        my @errs=&makedir($d,$dirmode,$group);
        die "\n",@errs,"\n\n" if (@errs);
    }
}


#-------------------------------------------------
# run trec_eval
#-------------------------------------------------

# get the list of result files
opendir(IND,$idir) || die "can't opendir $idir";
my @files= readdir IND;
closedir IND;

# write out evaluations
foreach my $file(@files) {

    my $inf= "$idir/$file";

    next if (-d $inf);
    next if ($rfpfx && $file !~/$rfpfx/);
    next if (!&chkstat($inf));     # not in TREC format

    my $file2;

    # reranking directory
    if ($qsubd=~/R/) {
        $file2=$file;
    }
    else {
        if ($file=~/^(.+)_trec$/) { $file2 = $1.'.r0'.'_trec'; }
        else { die "Invalid file name: $inf\n"; }
    }

    my $err1= `$evalc -q -M1000 -c $qrels $idir/$file > $odir/$file2$fsfx\_topic`;
    print LOG "CMD1=$evalc -q -M1000 -c $qrels $idir/$file > $odir/$file2$fsfx\_topic\n";
    print LOG "Error ($err1): CMD1" if ($err1);
    my $err2= `$evalc -q -M1000 -c -l2 $qrels $idir/$file > $odir/$file2$fsfx\_opinion`;
    print LOG "CMD2=$evalc -q -M1000 -c -l2 $qrels $idir/$file > $odir/$file2$fsfx\_opinion\n";
    print LOG "Error ($err2): CMD2" if ($err2);

}


# ------------------------------------------------
# end program
# ------------------------------------------------

if ($log) { &end_log($pdir,$logd,$filemode,@start_time); }

# notify author of program completion
#&notify($sfx,$author);


########################
# subroutines
########################

BEGIN { print STDOUT "\n"; }
END { print STDOUT "\n"; }

#----------------------------------------
# check file to confirm TREC format
#----------------------------------------
#   arg1= file
#   r.v.= 1 if TRECfmt, 0 otherwise
#----------------------------------------
sub chkstat {
    my $inf=shift;

    open(IN,$inf) || die "can't read $inf";
    my $line= <IN>;
    close IN;

    if ($line=~/^\d+\s+Q0\s+BLOG[\d\-]+\s+\d+\s+[\-\d.]+\s+[\w\-.]+$/) {
        return 1;
    }
    else {
        return 0;
    }

}
