#!/usr/bin/perl -w

# -----------------------------------------------------------------
# Name:      treceval.pl
# Author:    Kiduk Yang, 07/02/2005
#              modified trec04/treceval.pl (7/2004)
# -----------------------------------------------------------------
# Description:  evaluate TREC results
# -----------------------------------------------------------------
# ARGUMENTS: arg1 -- track (genomics, hard, robust, web)
#            arg2 -- query type (t for training, e evaluation topics)
#            arg3 -- query subdirectory (e.g. s0o0, s1o0)
#            arg4 -- index type (optional: body, head, anchor)
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
$tpdir0=  "$wpdir/trec04";           # TREC eval directory
$tpdir=  "$wpdir/trec06";            # TREC program directory
$idir=   "/u3/trec";                 # index directory

# trec_eval.c by Chris Buckley
$evalc=  "$tpdir0/trec_evald/trec_eval";

# qrels files
%qrels_t= (
"blog" => "/u1/trec/qrels/qrels.blog06train.txt",
);
%qrels_e= (
#"blog" => "/u1/trec/qrels/qrels.blog2006.txt",!!NY
"blog" => "/u1/trec/qrels/qrels.blog06",
);

# query type
%qtype= ("e"=>"test","t"=>"train");

require "$wpdir/logsub.pl";          # general subroutine library


#------------------------
# program arguments
#------------------------
$prompt= 
"arg1= track name (e.g. blog)\n".
"arg2= query type (i.e. t, tx, e, ex)\n".
"arg3= query subdirectory (i.e. s0R)\n";


%valid_args= (
0 => " blog ",
1 => " t e tx ex ",
2 => " s0R ",
);

($arg_err,$dname,$qtype,$qsubd)= chkargs($prompt,\%valid_args);
die "$arg_err\n" if ($arg_err);

$qtype2=substr($qtype,0,1);

# determine qrels for topic type
if ($qtype=~/^t/) { %qrels=%qrels_t; }
elsif ($qtype=~/e/) { %qrels=%qrels_e; }

if ($dname eq 'blog') { $dname2='blog06'; }
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
$idir= "$ddir/results/$qtype{$qtype2}/$trecd/$qsubd";

# evaluation directory
$odir= "$ddir/results/$qtype{$qtype2}/eval/$qsubd";

# log directory
$logd= "$ddir/rtlog";               


#-------------------------------------------------
# start program log
#-------------------------------------------------

$sfx= "$qtype$qsubd";         # program log file suffix
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
    next if ($file!~/_trec/);
    my $err= `$evalc -q $qrels{$dname} $idir/$file > $odir/$file$fsfx`;
    print LOG "CMD=$evalc -q $qrels{$dname} $idir/$file > $odir/$file$fsfx\n";
    print LOG "Error ($err): $evalc -q $qrels{$dname} $idir/$file > $odir/$file$fsfx\n" if ($err);
}


# ------------------------------------------------
# end program
# ------------------------------------------------

if ($log) { &end_log($tpdir,$logd,$filemode,@start_time); }

# notify author of program completion
#&notify($sfx,$author);
