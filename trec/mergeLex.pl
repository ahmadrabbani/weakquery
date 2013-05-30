#!/usr/bin/perl -w

# -----------------------------------------------------------------
# Name:      mergeLex.pl
# Author:    Kiduk Yang, 06/14/2008
# -----------------------------------------------------------------
# Description:  consolidate lexicon files
# -----------------------------------------------------------------
# ARGUMENTS: arg1 - 1 to run
# Input:     
#   -- Lexicon with manual weights
#   $ddir/lex/wilson_strongsubj.lex - type=strongsubj (TERM PORLARITY POS)
#   $ddir/lex/wilson_weaksubj.lex   - type=weaksubj (TERM PORLARITY POS)
#   $ddir/lex/wilson_emp.lex        - emphasis lexicon (TERM)
#   $pdir/AC.list                   - AC lexicon (TERM(string):polSC:freq)
#   $pdir/IU2.lst                   - IU lexicon (IUngrams:polSC)
#   $pdir/HF2.lst                   - HF lexicon (TERMs:polSC)
#   $pdir/LF2.lst                   - LF lexicon (TERM:polSC)
#   $pdir/LF2.rgx                   - LF regex (regex polSC)
#   $pdir/LF2mrp.rgx                - LF morph regex (regex polSC)
#   -- Lexicon with combined weights
#   $ddir/lex/final/W1.lex          - strong subj. lexicon (TERM:polSC)
#   $ddir/lex/final/W2.lex          - weak subj. lexicon (TERM:polSC)
#   $ddir/lex/final/EM.lex          - emphasis lexicon  (TERM:polSC)
#   $ddir/lex/final/AC.lex          - AC lexicon (TERM(string):polSC)
#   $ddir/lex/final/IU.lex          - IU lexicon (IUngrams:polSC)
#   $ddir/lex/final/HF.lex          - HF lexicon (TERMs:polsc)
#   $ddir/lex/final/LF.lex          - LF lexicon (TERM:polsc)
#   $ddir/lex/final/LFrgx.lex       - LF regex (regex polSC)
#   $ddir/lex/final/LFmrp.lex       - LF morph regex (regex polSC)
#   -- Lexicon with probabilistic weights
#   $ddir/lex/final2/W1.lex          - strong subj. lexicon (TERM:polSC)
#   $ddir/lex/final2/W2.lex          - weak subj. lexicon (TERM:polSC)
#   $ddir/lex/final2/EM.lex          - emphasis lexicon  (TERM:polSC)
#   $ddir/lex/final2/AC.lex          - AC lexicon (TERM(string):polSC)
#   $ddir/lex/final2/IU.lex          - IU lexicon (IUngrams:polSC)
#   $ddir/lex/final2/HF.lex          - HF lexicon (TERMs:polsc)
#   $ddir/lex/final2/LF.lex          - LF lexicon (TERM:polsc)
#   $ddir/lex/final2/LFrgx.lex       - LF regex (regex polSC)
#   $ddir/lex/final2/LFmrp.lex       - LF morph regex (regex polSC)
# Output:    
#   $pdir/lex/W1.lex    - strong subj. lexicon (TERM:polSC-manual:polSC-prob:polSC-combo)
#   $pdir/lex/W2.lex    - weak subj. lexicon (TERM:polSC-manual:polSC-prob:polSC-combo)
#   $pdir/lex/AC.lex    - AC lexicon (TERM(string):polSC-manual:polSC-prob:polSC-combo)
#   $pdir/lex/EM.lex    - emphasis lexicon  (TERM:polSC-manual:polSC-prob:polSC-combo)
#   $pdir/lex/IU.lex    - IU lexicon (IUngrams:polSC-manual:polSC-prob:polSC-combo)
#   $pdir/lex/HF.lex    - HF lexicon (TERMs:polsc-manual:polSC-prob:polSC-combo)
#   $pdir/lex/LF.lex    - LF lexicon (TERM:polsc-manual:polSC-prob:polSC-combo)
#   $pdir/lex/LFrgx.lex - LF regex (regex polSC-manual:polSC-prob:polSC-combo)
#   $pdir/lex/LFmrp.lex - LF morph regex (regex polSC-manual:polSC-prob:polSC-combo)
#   $pdir/lex/$prog      -- program     (optional)
#   $pdir/lex/$prog.log  -- program log (optional)
# -----------------------------------------------------------------
# NOTES: run mklex*.pl first to create lexicon files
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

# qrels files
my $qrels= "$qreld/qrels.opinion.blog06-07";

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
