#!/usr/bin/perl -w

# -----------------------------------------------------------------
# Name:      treceval.pl
# Author:    Kiduk Yang, 07/02/2005
#              modified trec04/treceval.pl (7/2004)
#              modified 11/03/2006 to use trec_eval.8.1
#              modified 06/23/2007
# -----------------------------------------------------------------
# Description:  evaluate TREC results
# -----------------------------------------------------------------
# ARGUMENTS: arg1 -- track (genomics, hard, robust, web)
#            arg2 -- query type (t for training, e evaluation topics)
#            arg3 -- query subdirectory (e.g. s0o0, s1o0)
#            arg4 -- result subdirectory (optional: results, results_old)
# Input:     $idir/$arg1/results/$qtype/trecfmt/*
# Output:    $idir/$arg1/results/$qtype/eval/*
#            $idir/$arg1/$prog      -- program     (optional)
#            $idir/$arg1/$prog.log  -- program log (optional)
#            NOTE: $qtype   = query type (train|test)
# -----------------------------------------------------------------
# NOTES:     runs trec_eval.c
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
$idir=   "/u3/trec";                 # index directory

# trec_eval.c by Chris Buckley
$evalc=  "$tpdir/trec_eval.8.1/trec_eval";

# qrels files
%qrels_t= (
"blog" => "/u1/trec/qrels/qrels.blog06",
);
%qrels_t0= (
"blog" => "/u1/trec/qrels/qrels.blog06train.txt2",
);
%qrels_e= (
"blog" => "/u1/trec/qrels/07.qrels.opinion",
);

# query type
%qtypes= ("e"=>"test","t"=>"train","t0"=>"train0");

require "$wpdir/logsub.pl";          # general subroutine library


#------------------------
# program arguments
#------------------------
$prompt= 
"arg1= track name (e.g. blog)\n".
"arg2= query type (i.e. t, tx, e, ex)\n".
"arg3= query subdirectory (i.e. s0, s0R)\n".
"arg4= result subdirectory (optional: results, results_old)\n";


%valid_args= (
0 => " blog ",
1 => " t e tx ex t0 t0x ",
2 => " s0* ",
);

($arg_err,$dname,$qtype,$qsubd,$resultd)= chkargs($prompt,\%valid_args);
die "$arg_err\n" if ($arg_err);

$resultd="results" if (!$resultd);

if ($qtype=~/t0/) { $qtype2='t0'; }
else { $qtype2=substr($qtype,0,1); }

# determine qrels for topic type
if ($qtype=~/^t0/) { %qrels=%qrels_t0; }
elsif ($qtype=~/^t/) { %qrels=%qrels_t; }
elsif ($qtype=~/^e/) { %qrels=%qrels_e; }

if ($dname eq 'blog') { $dname2='blog07'; }
else { $dname2=$dname; }

if ($qtype=~/x$/) { 
    $trecd='trecfmtx'; 
    $fsfx='x'; 
}
else { 
    $trecd='trecfmt'; 
    $fsfx=''; 
}

# data directory
$ddir= "$idir/$dname2";               

# TREC format result directory
$idir= "$ddir/$resultd/$qtypes{$qtype2}/$trecd/$qsubd";

# evaluation directory
$odir= "$ddir/$resultd/$qtypes{$qtype2}/eval/$qsubd";

# log directory
$logd= "$ddir/rtlog";               


#-------------------------------------------------
# start program log
#-------------------------------------------------

$sfx= "$qtype$qsubd";         # program log file suffix
$sfx .= 'old' if ($resultd=~/old/);
$sfx .= 'new' if ($resultd=~/new/);
$noargp=0;                    # if 1, do not print arguments to log
$append=0;                    # log append flag

if ($log) { 
    @start_time= &begin_log($logd,$filemode,$sfx,$noargp,$append); 
    print LOG "Input Files  = $idir/*\n",
              "Output Files = $odir/*\n\n";
}

foreach $d($odir,$logd) {
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
@files= readdir IND;
closedir IND;

# write out evaluations
foreach $file(@files) {
    next if (-d "$idir/$file");
    # reranking directory
    if ($qsubd=~/R[A-Za-z\d]?$/) {
        next if ($file!~/_trec$/);
        my $err1= `$evalc -q -M1000 -c $qrels{$dname} $idir/$file > $odir/$file$fsfx\_topic`;  #!!NY
        print LOG "CMD1=$evalc -q -M1000 -c $qrels{$dname} $idir/$file > $odir/$file$fsfx\_topic\n";
        print LOG "Error ($err1): CMD1" if ($err1);
        my $err2= `$evalc -q -M1000 -c -l2 $qrels{$dname} $idir/$file > $odir/$file$fsfx\_opinion`;
        print LOG "CMD2=$evalc -q -M1000 -c -l2 $qrels{$dname} $idir/$file > $odir/$file$fsfx\_opinion\n";
        print LOG "Error ($err2): CMD2" if ($err2);
    }
    else {
        next if ($file!~/^\w/ || $file=~/f2?$/);  # baseline fusion runs: *f=raw, *f_trec=trecfmt
        my $file2;
        if ($file=~/^(.+)_trec$/) { $file2 = $1.'.r0'.'_trec'; }
        else { $file2 = $file.'.r0'.'_trec'; }
        my $err1= `$evalc -q -M1000 -c $qrels{$dname} $idir/$file > $odir/$file2$fsfx\_topic`;
        print LOG "CMD1=$evalc -q -M1000 -c $qrels{$dname} $idir/$file > $odir/$file2$fsfx\_topic\n";
        print LOG "Error ($err1): CMD1" if ($err1);
        my $err2= `$evalc -q -M1000 -c -l2 $qrels{$dname} $idir/$file > $odir/$file2$fsfx\_opinion`;
        print LOG "CMD2=$evalc -q -M1000 -c -l2 $qrels{$dname} $idir/$file > $odir/$file2$fsfx\_opinion\n";
        print LOG "Error ($err2): CMD2" if ($err2);
    }
}


# ------------------------------------------------
# end program
# ------------------------------------------------

if ($log) { &end_log($tpdir,$logd,$filemode,@start_time); }

# notify author of program completion
#&notify($sfx,$author);
