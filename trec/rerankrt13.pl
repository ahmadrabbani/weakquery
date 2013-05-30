#!/usr/bin/perl -w

# -----------------------------------------------------------------
# Name:      rerankrt13.pl
# Author:    Kiduk Yang, 06/14/2008
#            modified rerankrt13NEW2.pl (06/2008)
#              - lexicons: AC, HF2, LC2, WL2, IU2, AV
#              - lexicon weights: manual, combined, probabilistic
#              - opinion scores: freq, proximity, idist
#            $Id: rerankrt13.pl,v 1.1 2008/06/27 00:43:29 kiyang Exp $
# -----------------------------------------------------------------
# Description:  compute reranking scores for a rank set of retrieval results
#    1. compute onTopic Reranking scores (length-normalized)
#       a. exact match of query title in doc title
#       b. exact match of query title in doc body
#       c. proximity match of query title in doc title (multi-word query only)
#       d. proximity match of query title in doc body (multi-word query only)
#       e. proximity match of query description in doc body (long query forms only)
#       f. query phrase match in doc title + body
#       g. query non-relevant phrase match in doc title + body
#       i. query non-relevant noun match in doc title + body
#    2. compute opinion Reranking scores: (NOT length-normalized)
#       a. text length in word count
#       b. number of I anchor (I, my, me)
#       c. number of YouWe anchor (you, we, your, our, us)
#       d. simple match score of emphasis terms 
#       foreach (AC, HF, IU, LF, W1, W2)
#           i.   simple match score
#           ii.  simple positive polarity score
#           iii. simple negative polarity score
#           iv.  proximity match score
#           v.   proximity positive polarity score
#           vi.  proximity negative polarity score
#    3. output reranking result files
#       - topic reranking scores: 1a-1i
#       - opinion reranking scores: 2a-2d, 2i-2vi
#       a. qry-dependent scores file
#       b. qry-independent scores file
#    3. output reranking score files
#       - qry-independent scores: 2a-2d, 2i, 2ii, 2iii
#       - qry-dependent scores: 1a-1i, 2iv, 2v, 2vi
#       a. qry-dependent scores file
#       b. qry-independent scores file
# NOTE: proximity and distance measure scoring algorithm is updated
#       to match individual query terms
# -----------------------------------------------------------------
# Execution Sequence:
#   1. read in existing individual blog files
#   2. read in existing rerank scores
#   3. get blogIDs from result files
#       - terminate if files are missing
#   4. read in the lexicons
#   5. read in processed queries
#   6. compute reranking scores & output results for missing records
#   7. update rerank score files
#   8. output result files w/ reranking scores
# -----------------------------------------------------------------
# ARGUMENT: 
#   arg1= runmode (0 to get counts only, 1 to extract)
#   arg2= query type (t, tx, e, ex)
#   arg3= result subdirectory (e.g. s0)
#   arg4= rank set number (e.g. 1, 2, 3)
#   arg5= result file filter (optional: e.g. _q, vsm, default=.)
#   arg6= log append flag (optional: 1 to overwrite log)
#   arg7= RRSC file overwrite flag (optional: 1 to overwrite existing rerank scores)
#   arg8= R0 subdirectory suffix (e.g., a for s0Ra)
#   arg9= lex boost flag (optional: default=no boost)
#   arg10= lex no compression flag (optional: default=compress)
#   arg11= term no morph flag (optional: default=morph)
#   arg12= max document length (optional: default=1000 word)
#   arg13= 1 to turnoff RRSC overwrite safty
# INPUT:     
#   $ddir/results/$qtype/trecfmt(x)/$arg3/* -- result files
#   $ddir/results/$arg3/(tmp/)rrsc|rrscxN/$arg2-$runname.1
#     -- existing qry-independent scores file
#   $ddir/results/$arg3/(tmp/)rrsc|rrscxN/$arg2-$runname.2
#     -- existing qry-dependent scores file
#   $ddir/results/$arg3/docs|docx/YYYYMMDD/$fn-$offset
#     -- existing individual doc files
#        <ti>$title</ti><body>$body</body>
#   $ddir/YYYYMMDD/doc(x)/pmlN      - processed blog data
#   -- Lexicon Files --
#   $ddir/lex/wilson_strongsubj.lex - type=strongsubj (TERM PORLARITY POS)
#   $ddir/lex/wilson_weaksubj.lex   - type=weaksubj (TERM PORLARITY POS)
#   $ddir/lex/wilson_emp.lex        - emphasis lexicon (TERM)
#   $ddir/lex/wilson_neg.lex        - negation lexicon (TERM)
#   $pdir/IU2.lst                   - IU lexicon
#   $pdir/HF2.lst                   - HF lexicon
#   $pdir/LF2.lst                   - LF lexicon
#   $pdir/LF2.rgx                   - LF regex
#   $pdir/LF2mrp.rgx                - LF morph regex
#   $pdir/AC.list                   - AC lexicon
# OUTPUT:    
#   $ddir/results(_new)/$qtype/trecfmt(x)/$arg3.R$arg8/rset6/$runname-$arg4.1
#     -- results w/ topic reranking scores
#        QN docID RANK RT_SC RunName Topic_SCs (per line)
#   $ddir/results(_new)/$qtype/trecfmt(x)/$arg3.R$arg8/rset6/$runname-$arg4.2
#     -- results w/ opinion reranking scores
#        QN docID RANK RT_SC RunName Opinion_SCs (per line)
#   $ddir/results/$arg3/tmp/rrsc6$arg8(x)/$arg2-$runname-$arg4.1
#     -- new qry-independent scores file
#        docID SCOREs (per line)
#   $ddir/results/$arg3/tmp/rrsc6$arg8(x)/$arg2-$runname-$arg4.2
#     -- new qry-dependent scores file
#        docID QN SCOREs (per line)
#   $ddir/rrlog/$prog      -- program     (optional)
#   $ddir/rrlog/$prog.log  -- program log (optional)
# -----------------------------------------------------------------
# NOTES: 
#   1. works the same as rerankrt13pnew.pl except 
#        - doc truncation is done at 1000 words rather than 5000
#        - lexicon scores are exaggerated (1,2,3) to (1,3,6)
#        - %rrsc is output every 250 records rather than 500
#   2. rank set size is set to 100 (process 100 ranks per run)
#   3. consider outputting a single consolidated rrsc file
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


#------------------------
# global variables
#------------------------

my $wpdir=  "/u0/widit/prog";           # widit program directory
my $tpdir=  "$wpdir/trec08";            # TREC program directory
my $pdir=   "$tpdir/blog";              # TREC program directory
my $ddir=   "/u3/trec/blog07";          # index directory
my $ddir2=  "/u3/trec/blog08";          # index directory
my $qdir=   "$ddir2/query";              # query directory
my $logdir= "$ddir2/rrlog";              # log directory

my $subj1f= "$ddir/lex2/final/W1.lex";          # strong subj. lexicon
my $subj2f= "$ddir/lex2/final/W2.lex";          # weak subj. lexicon
my $empf=   "$ddir/lex2/final/EM.lex";          # emphasis lexicon
my $IUlexf= "$ddir/lex2/final/IU.lex";          # IU lexicon file
my $HFlexf= "$ddir/lex2/final/HF.lex";          # HF lexicon file
my $LFlexf= "$ddir/lex2/final/LF.lex";          # LF lexicon file
my $LFrgxf= "$ddir/lex2/final/LFrgx.lex";       # LF regex file
my $LFmrpf= "$ddir/lex2/final/LFmrp.lex";       # LF morph regex file
my $AClexf= "$ddir/lex2/final/AC.lex";          # AC lexicon file
my $AVlexf= "$pdir/AV.list";            # AV lexicon file
my $modeld= "$pdir/newLexicon";         # AdjVerb model directory


my $maxwdcnt= 1000;   # doc truncation length
my $poutcnt= 250;     # rrsc output interval

# query type
my %qtype= (
"t"=>"train",
"tx"=>"train",
"t2"=>"train2",
"tx2"=>"train2",
"e"=>"test",
"ex"=>"test",
"e2"=>"test",
"ex2"=>"test2",
);

my %qtype2= (
"t"=>"results/train/trecfmt",
"tx"=>"results/train/trecfmtx",
"t2"=>"results/train2/trecfmt",
"tx2"=>"results/train2/trecfmtx",
"e"=>"results/test/trecfmt",
"ex"=>"results/test/trecfmtx",
"e2"=>"results/test2/trecfmt",
"ex2"=>"results/test2/trecfmtx",
);

require "$wpdir/logsub2.pl";    # subroutine library
require "$pdir/blogsub.pl";     # blog subroutine library


#------------------------
# program arguments
#------------------------
my $prompt=
"arg1= runmode (0 to get counts only, 1 to score)\n".
"arg2= query type (t, tx, t2, tx2, e, ex, e2, ex2)\n".
"arg3= result subdirectory (e.g. s0)\n".
"arg4= rank set number (i.e., 1..10)\n".
"arg5= result file filter (optional: e.g. _q, vsm_ql, default=.)\n".
"arg6= log append flag (optional: 1 to overwrite log)\n".
"arg7= RRSC file overwrite flag (optional: 1 to overwrite RRSC files)\n".
"arg8= R0 subdirectory suffix [a-k] (optional: e.g. a for R0a, '' for R0)\n".
"arg9= lex boost flag [1-3] (optional: default=no boost)\n".
"arg10= lex no compression flag (optional: default=compress)\n".
"arg11= term no morph flag (optional: default=morph)\n".
"arg12= max. document length (optional: default=1000 words)\n".
"arg13= 1 to turnoff RRSC overwrite safety\n";

my %valid_args= (
0 => " 0 1 ",
1 => " t tx t2 tx2 e ex e2 ex2 ",
2 => " s0* ",
3 => " 1 2 3 4 5 6 7 8 9 10 ",
7 => " a b c d e f g h i j k ",
8 => " 0 1 2 3 ",
);

my ($arg_err,$runmode,$qtype,$rsubd,$rsetnum,$runfx,$apf,$rrscnewf,$odsfx,$lexbf,$nocmpf,$nomrpf,$maxdlen,$nosafety)= 
    chkargs($prompt,\%valid_args,4);
die "$arg_err\n" if ($arg_err);

my $rsubd0=$1 if ($rsubd=~/^(s\d)/);
die "Bad rsubd2: $rsubd0\n" if ($rsubd0 ne 's0');

#$nosafety=1;

# doc truncation length
$maxwdcnt= $maxdlen if (defined($maxdlen));

my $rrdname= "rrsc7";  ###!!
$rrdname .= $odsfx if ($odsfx);

my $rsetsize=100;
my $endrank=$rsetnum*$rsetsize;     # last rank in result file to process
my $begrank=$endrank-$rsetsize+1;   # first rank in result file to process

# determine directory names
my $docdname;
if ($qtype=~/x/) { 
    $rrdname .= 'x';
    $docdname= "docx"; 
}
else { 
    $docdname= "docs"; 
}

# processed query directory
my $qrydir="$qdir/$qtype{$qtype}";

# web-expanded query phrases
my $qrydir2= "$qrydir/s0x";

# TREC format directory
#   e.g., /u3/trec/blog07/results/trecfmtx
my $rdir= "$ddir/$qtype2{$qtype}";      

# i.e. /u3/trec/blog07/results/s0
my $rdir0= "$ddir/results/$rsubd0";

my $ind= "$rdir0/$docdname";    # individual blog file directory
my $outd0= $ind."2";    # individual blog file directory (with query matches marked)
my $resultd= "$rdir/$rsubd";    # input result directory
$resultd=~s/blog07/blog08/; #!!

my $r0d= $resultd."R";          # R0 directory
$r0d .= $odsfx if ($odsfx);

my $outd= "$r0d/rset7";         # !!rerank result file directory

my $outd2= "$rdir0/$rrdname";   # rerank scores directory

# exit if R0 rall directory exists 
#   - to avoid overwriting existing rerank files by mistake
if (-e "$r0d/rall7" && !$nosafety) {
    print STDOUT "$r0d/rall7/ already exist. Cannot continue\n";
    #exit;
}


# temporary rerank scores directory
#  - rereank scores is saved periodically during the job
my $outd2tmp= "$rdir0/$rrdname/tmp";   

foreach my $d($outd,$outd2,$outd2tmp) {
    `mkdir -p $d` if (!-e $d);
}


#-------------------------------------------------
# start program log
#-------------------------------------------------

$sfx= "$qtype$rsubd-$rsetnum";   # program log file suffix
$sfx .= $odsfx if ($odsfx);
$noargp=0;              # if 1, do not print arguments to log
$append=1;              # log append flag
$append=0 if ($apf);

# logs for different runs are appended to the same log file
if ($log) {
    @start_time= &begin_log($logdir,$filemode,$sfx,$noargp,$append);
    print LOG "InF   = $resultd/*\n",
              "        $ind/YYMMDD/\$fn-\$offset\n",
              "        $outd2/*.1, *.2\n",
              "        $outd2tmp/*.1, *.2\n",
              "OutF  = $outd/\$result_fname-$rsetnum.(1,2)\n",
              "        $outd2/$qtype-\$result_fname-$rsetnum.(1,2)\n",
              "        $outd2tmp/$qtype-\$result_fname-$rsetnum.(1,2)\n\n";
}

#-------------------------------------------------
# read in existing individual blog files
#-------------------------------------------------
# %dlist0: existing blog files
#   k(docID) = v(1)
#-------------------------------------------------

opendir(D1,$ind) || die "can't opendir $ind";
my @subds=readdir(D1);
closedir D1;

my %dlist0;
my $dcnt=0;

print LOG "Checking blog files:\n" if ($debug>1);

foreach my $ymd(@subds) {
    next if ($ymd!~/^200/);

    my $ind2= "$ind/$ymd";
    print LOG "  - reading directory $ind2\n" if ($debug>1);

    opendir(D2,$ind2) || die "can't opendir $ind2";
    my @files=readdir(D2);
    closedir D2;

    foreach my $file(@files) {
        next if ($file!~/^\d{3}-\d+$/);
        $dcnt++;
        $dlist0{"BLOG06-$ymd-$file"}=1;
    }
}

print LOG "Existing blog files = $dcnt\n\n";


#-------------------------------------------------
# read in existing rerank scores
#   - qry-independent scores: same for docID by trecfmt(x)
#   - qry-dependent scores: same for QN-docID by trecfmt(x)
#-------------------------------------------------
# %rrsc: existing rerank scores
#   k(docID -> QN -> name) = v(score)
#-------------------------------------------------

my %rrsc;

if (!$rrscnewf) {
    my @flist1=&mkRRSChash($outd2,\%rrsc);
    my @flist2=&mkRRSChash($outd2tmp,\%rrsc);
    my @flist=(@flist1,@flist2);
    if (@flist) {
        print LOG "Reading rerank score files:\n";
        foreach my $in(@flist) { print LOG "  - $in\n"; }
        print LOG "\n";
    }
    else {
        print LOG "Note: There are no rerank score files to be read in\n\n";
    }
}

else {
    print LOG "NOTE (arg7=1): Rerank scores (not read in) will be overwritten\n\n";
}


#-------------------------------------------------
# 1. read in result files
# 2. store retrieval score in %result
# 3. store original ranking order in %result0
#-------------------------------------------------
# %result0: for sorting back to original result order
#   k(filename -> QN -> rank) = v(docID)
# %result:  for storing original retrieval scores
#   k(filename -> QN -> docID) = v(RT_SC runname)
# %dlist: blogIDs from result files
#   k(docID -> QN) = v(1,0)
#   k1 = docID
#   v1 = hash pointer
#        k2 = QN
#        v2 = 0, 1
#             0 - scores exist (in %rrsc)
#             1 - scores to be computed
#-------------------------------------------------

opendir(IND,$resultd) || die "can't opendir $resultd";
my @files=readdir(IND);
closedir IND;

my (%dlist,%result,%result0);;

foreach my $file(@files) {
    my $inf= "$resultd/$file";
    
    # *f are bseline fusion results not in trec format.
    #   - use *f_trec instead
    next if ($file !~ /_trec$/);
    next if ((-d $inf) || $file=~/f\d?$/);
    next if ($runfx && $file!~/$runfx/);
    
    print LOG "Processing result file $inf\n";
    
    open(IN,"$inf") || die "can't read $inf";
    while(<IN>) {
        chomp;
        #my ($qn,$c,$docID,$rank,$sc,$run)=split/\s+/;
        my ($qn,$docID,$rank,$sc,$run);
        if (/^(\d+).+(BLOG06-200\d+-\d{3}-\d+)\s+(\d+)\s+([\d\.\-]+)\s+(.+)$/) {
            ($qn,$docID,$rank,$sc,$run)=($1,$2,$3,$4,$5);
        }
        else {
            print LOG "  !!Error: Problem result file: $inf\n";
        }
        # process only records in the target rank set
        next if ($rank<$begrank || $rank>$endrank);
        $result0{$file}{$qn}{$rank}=$docID;
        $result{$file}{$qn}{$docID}="$sc $run";
        $dlist{$docID}{$qn}=1;
    }
    close IN;

} #end-foreach


my %rrlist;
foreach my $file(keys %result0) {
    foreach my $qn(%{$result0{$file}}) {
        foreach my $rank(keys %{$result0{$file}{$qn}}) {
            my $docID= $result0{$file}{$qn}{$rank};
            # create %rrlist
            $rrlist{$file}{$docID}=1;
        }
    }
}


#-------------------------------------------------
# 1. check for missing files
#     - terminate if files are missing
# 2. identify docIDs to be scored & create %dlist2
#     - reset %dlist flag to 0 if scores exist
#-------------------------------------------------
# %dlist2: blogIDs to be scored
#   k(docID) = v(1)
# %dlist: blogIDs from result files
#   k(docID -> QN) = v(1,0)
# %dlist0: existing blog files
#   k(docID) = v(1)
# %rrsc: existing rerank scores
#   k(docID -> QN -> name) = v(score)
#-------------------------------------------------

my %dlist2;
my $dcnt1=0;  # number of IDs to extract
my $dcnt2=0;  # number of IDs in result file
my $dqcnt1=0;  # number of ID-QNs to score
my $dqcnt2=0;  # number of ID-QNs in result file

foreach my $docID(keys %dlist) {
    if (!$dlist0{$docID}) {
        $dcnt1++;
        print "missID=$docID\n" if (0);
    }
    $dcnt2++;
    foreach my $qn(keys %{$dlist{$docID}}) {
        # scores already exist
        if (exists($rrsc{$docID}{$qn})) {  
            $dlist{$docID}{$qn}=0;
        }
        else {
            $dqcnt1++;
            $dlist2{$docID}=1;
        }
        $dqcnt2++;
    }
}

print LOG "\n$dqcnt1 of $dqcnt2 ID-QN reranking scores to be computed\n\n";

if ($dcnt1) {
    print LOG "Warning!! $dcnt1 of $dcnt2 IDs need be extracted\n",
              "  - run rerankrt1.pl first to extract the files\n";   
    #exit;
}
else {
    print LOG "All blog files for reranking already exists.\n\n";
}
exit if (!$runmode);


#--------------------------------------------------------------------
# create the lexicon hashes
#--------------------------------------------------------------------
# %IUlex:   IU phrases
#   k(I|my|me -> term) = v($pol$sc)
# %HFlex:   HF terms
#   k(term) = v($pol$sc)
# %LFlex:   LF terms
#   k(term) = v($pol$sc)
# %LFrgx:   LF regexes
#   k(regex) = v($pol$sc)
# @LFrgx:   LF regexes
# @LFrgxsc: LF regexes scores
# %LFmrp:   LF morphed term regexes
#   k(regex) = v($pol$sc)
# @LFmrp:   LF morphed term regexes
# @LFmrpsc: LF morphed term scores
# %AClex:   Acronyms
#   k(acryonym|expanded AC) = v($pol$sc)
# %W1lex:   Wilson's strong subjective terms
#   k(term) = v($pol$sc)
# %W2lex:   Wilson's weak subjective terms
#   k(term) = v($pol$sc)
# %emplex:  Wilson's emphasis terms
#   k(term) = v($pol$sc)
# %AVlex:   k= IU ngram, v=1
#--------------------------------------------------------------------

my %IUlex;
&mkIUhh($IUlexf,\%IUlex,0,$lexbf,$nocmpf);

my %HFlex;
&mkHFhh($HFlexf,\%HFlex,$lexbf,$nocmpf);

my %LFlex;
&mkLFhh2($LFlexf,\%LFlex,$lexbf);
    
my (%LFrgx,@LFrgx,@LFrgxscM,@LFrgxscC,@LFrgxscP);
&mkLFhh1($LFrgxf,\%LFrgx,\@LFrgx,\@LFrgxscM,\@LFrgxscC,\@LFrgxscP,$lexbf);

my (%LFmrp,@LFmrp,@LFmrpscM,@LFmrpscC,@LFmrpscP);
&mkLFhh1($LFmrpf,\%LFmrp,\@LFmrp,\@LFmrpscM,\@LFmrpscC,\@LFmrpscP,$lexbf);

my %AClex; 
&mkAChh($AClexf,\%AClex);

my %w1lex;
&mkWhh($subj1f,\%w1lex,$lexbf,$nocmpf);

my %w2lex;
&mkWhh($subj2f,\%w2lex,$lexbf,$nocmpf);

my %emplex;
&mkWhh($empf,\%emplex,0,$nocmpf,'m1');

my %AVlex;
open(IN,$AVlexf) || die "can't read $AVlexf";
while(<IN>) {
    chomp;
    $AVlex{$_}=1;
}
close IN;

# model hash for AdjVerb module
my(%PSEhash,%NPSEhash);
&build_ad_v($modeld,\%PSEhash,\%NPSEhash);


#-------------------------------------------------
# create hashes of query text
#-------------------------------------------------
# %qtitle:  query titles (for exact match)
#   k(QN) = v(title)
# %qtitle2: processed query titles (for proximity mach)
#   k(QN) = v(title2)
# %qtitle3: expanded query titles (for IDIST scoring)
#   k(QN) = v(title3)
# ----------------------------------------------
# for medium & long query runs
# ----------------------------------------------
# %qdesc2:  processed query descriptions (for prox. match)
#   k(QN) = v(desc2)
# %phrase:  query phrase
#   k(QN -> phrase) = v(freq)
# %phrase2: expanded query phrase
#   k(QN -> phrase) = v(weight)
# %nr_phrase:  query non-relevant phrase
#   k(QN -> nonrel_phrase) = v(freq)
# %nr_noun:  query non-relevant noun
#   k(QN -> nonrel_noun) = v(freq)
#-------------------------------------------------

my (%qtitle,%qtitle2,%qtitle3,%qdesc2,%phrase,%phrase2,%nr_phrase,%nr_noun);
&mkQRYhash($qrydir,$qrydir2,\%qtitle,\%qtitle2,\%qtitle3,\%qdesc2,\%phrase,\%phrase2,\%nr_phrase,\%nr_noun);

if ($debug>1) {
    foreach my $qn(sort keys %qtitle) {
        print "QN=$qn\n";
        print " ti=$qtitle{$qn}\n";
        print " ti2=$qtitle2{$qn}\n";
        print " ti3= ", join(", ",keys %{$qtitle3{$qn}}),"\n";
        print " desc2=$qdesc2{$qn}\n";
        if ($phrase{$qn}) {
            print " Noun Phrases:\n";
            foreach my $k(sort keys %{$phrase{$qn}}) { print "   $k: $phrase{$qn}{$k}\n"; }
        }
        if ($phrase2{$qn}) {
            print " Expanded Noun Phrases:\n";
            foreach my $k(sort keys %{$phrase2{$qn}}) { print "   $k: $phrase2{$qn}{$k}\n"; }
        }
        if ($nr_phrase{$qn}) {
            print " Nonrel Phrases:\n";
            foreach my $k(sort keys %{$nr_phrase{$qn}}) { print "   $k: $nr_phrase{$qn}{$k}\n"; }
        }
        if ($nr_noun{$qn}) {
            print " Nonrel Nouns:\n";
            foreach my $k(sort keys %{$nr_noun{$qn}}) { print "   $k: $nr_noun{$qn}{$k}\n"; }
        }
        print "\n";
    }
}


#-------------------------------------------------
# 1. compute reranking scores 
# 2. update %rrsc
#-------------------------------------------------
# %dlist2: blogIDs to be scored
#   k(docID) = v(1)
# %dlist: blogIDs from result files
#   k(docID -> QN) = v(1,0)
#   - compute scores if v=1
#   - get scores from %rrsc if v=0
# %rrsc: existing rerank scores
#   k(docID -> QN -> name) = v(score)
# %score: computed reranking scores for a document
#   k(QN -> name) = v(score)
#-------------------------------------------------

print LOG "Computing rerank scores\n";

my $pcnt=0;
foreach my $docID(keys %dlist) {
            
    #-----------------------
    # blogIDs to be scored
    if (exists($dlist2{$docID})) {
        
        print LOG " - processing $docID\n";
        
        # after every 250 records have been processed,
        #   1. save %rrsc to file
        #   2. read in existing rerank score files to update %rrsc
        #   3. update %dlist and %dlist2 to prevent score re-computations
        if ($pcnt && $pcnt%$poutcnt==0) {
            &printRRSC(\%rrlist,\%rrsc,$outd2tmp);
            &mkRRSChash($outd2tmp,\%rrsc);
            my @flist1=&mkRRSChash($outd2,\%rrsc);
            my @flist2=&mkRRSChash($outd2tmp,\%rrsc);
            my @flist=(@flist1,@flist2);
            if (@flist) {
                print LOG "Rerank score files read in:\n";
                foreach my $in(@flist) { print LOG "  - $in\n"; }
                print LOG "\n";
            }
            %dlist2=();
            my ($dqcnt1,$dqcnt2)=(0,0);
            foreach my $docID(keys %dlist) {
                foreach my $qn(keys %{$dlist{$docID}}) {
                    # scores already exist
                    if (exists($rrsc{$docID}{$qn})) {  
                        $dlist{$docID}{$qn}=0; 
                    }
                    else {
                        $dqcnt1++;
                        $dlist2{$docID}=1;
                    }
                    $dqcnt2++;
                }
            }
            print LOG "\nAfter $pcnt ID: $dqcnt1 of $dqcnt2 ID-QN remaining to be computed\n\n";
        } 
        
        $pcnt++;

        # get document texts from individual doc files
        my ($title,$body);
        my($b,$subd,$fn,$offset)=split/-/,$docID;
        my $docf= "$ind/$subd/$fn-$offset";

        next if (!-e $docf);  #!!  deal with it later in rerankrt4

        open(IN,$docf) || die "can't read $docf";
        my @lines=<IN>;
        close IN;
        my $doc= join("",@lines);
        if ($doc=~m|<ti>(.*?)</ti>.*?<body>(.*?)</body>|s) {
            ($title,$body)=($1,$2);
            chomp $body;
        }
        else {
            print LOG " - !!text extraction ERROR!! $docf\n";
            next;
        }

        #-----------------------------------------------------
        # create query subset hashes for each blogID
        #   - each $docID will have its own set of QNs
        #     depending on its appearance in search results
        #-----------------------------------------------------
        # $dlist{$docID} = pointer to QN hash (QN->1,0) for $docID
        #-----------------------------------------------------
        my %qti=&subQN(\%qtitle,$dlist{$docID});
        my %qti2=&subQN(\%qtitle2,$dlist{$docID});
        my %qti3=&subQN(\%qtitle3,$dlist{$docID});
        my %qds2=&subQN(\%qdesc2,$dlist{$docID});
        my %ph=&subQN(\%phrase,$dlist{$docID});
        my %ph2=&subQN(\%phrase2,$dlist{$docID});
        my %nrph=&subQN(\%nr_phrase,$dlist{$docID});
        my %nrn=&subQN(\%nr_noun,$dlist{$docID});


        #-----------------------------------------------------
        # compute reranking scores for a given docID & query set
        #-----------------------------------------------------
        my %score;
        &calrrSCall7($title,$body,\%qti,\%qti2,\%qti3,\%qds2,\%ph,\%ph2,\%nrph,\%nrn,\%score,\%AClex,\%HFlex,\%IUlex,\%LFlex,
        \@LFrgx,\@LFrgxscM,\@LFrgxscC,\@LFrgxscP,\@LFmrp,\@LFmrpscM,\@LFmrpscC,\@LFmrpscP,
        \%w1lex,\%w2lex,\%emplex,\%PSEhash,\%NPSEhash,$maxwdcnt,$nomrpf);

        # update rerank score hash
        foreach my $qn(keys %score) {
             $rrsc{$docID}{$qn}=$score{$qn};
        }

        &pdump(\%score,"score") if ($debug);

    } #end-if ($dlist2{$docID})

} #end-foreach $docID


&pdump(\%rrsc,"rrsc") if ($debug>1);

print LOG "\n";


#-------------------------------------------------
# output rerank result files
#-------------------------------------------------
# %rrsc: existing rerank scores
#   k(docID -> QN -> name) = v(score)
# %result0: for sorting back to original result order
#   k(filename -> QN -> rank) = v(docID)
# %result:  for storing original retrieval scores
#   k(filename -> QN -> docID) = v(RT_SC runname)
#-------------------------------------------------

foreach my $file(keys %result0) {

    my $outf1= "$outd/$file-$rsetnum.1";  # topic reranking scores
    my $outf2= "$outd/$file-$rsetnum.2";  # opinion reranking scores

    open(OUT1,">$outf1") || die "can't write to $outf1";
    open(OUT2,">$outf2") || die "can't write to $outf2";
    print LOG "Writing to $outf1\n";
    print LOG "Writing to $outf2\n\n";

    foreach my $qn(sort keys %{$result0{$file}}) {
        foreach my $rank(sort {$a<=>$b} keys %{$result0{$file}{$qn}}) {

            my $docID= $result0{$file}{$qn}{$rank};

            # retrieval data: QN ID rank rtSC runname
            print OUT1 "$qn $docID $rank $result{$file}{$qn}{$docID} ";
            print OUT2 "$qn $docID $rank $result{$file}{$qn}{$docID} ";

            # topical scores: 
            #   ti_exact, bd_exact, ti_prox, bd_prox, bd2_prox, phrase, exp. phrase, nonrel_phrase, nonrel_noun
            my @scs;
            foreach my $name('ti','bd','ti2','bd2','tix','bdx','bdx2','ph','ph2','nrph','nrn') {
                if ($rrsc{$docID}{$qn}{$name}) {
                    push(@scs,sprintf("%.4f",$rrsc{$docID}{$qn}{$name}));
                }
                else {
                    push(@scs,0);
                }
            }
            print OUT1 join(" ",@scs),"\n";

            @scs=();

            # qry-independent opinion scores 
            foreach my $name('tl','in1','in2') {
                if ($rrsc{$docID}{0}{$name}) {
                    push(@scs,sprintf("%.4f",$rrsc{$docID}{0}{$name}));
                }
                else {
                    push(@scs,0);
                }
            }
            foreach my $name('ac','hf','iu','lf','w1','w2') {
                my %score;
                foreach my $wtype('man','combo','prob') {
                    my ($sc,$psc,$nsc);
                    $sc=0 if (!($sc= $rrsc{$docID}{0}{$name}{$wtype}));
                    $psc=0 if (!($psc= $rrsc{$docID}{0}{$name.'P'}{$wtype}));
                    $nsc=0 if (!($nsc= $rrsc{$docID}{0}{$name.'N'}{$wtype}));
                    $score{$wtype}= $sc."p$psc"."n$nsc";
                }
                my $score= $score{'man'}.":".$score{'combo'}.":".$score{'prob'};
                push(@scs,$score);
            }
            if ($rrsc{$docID}{0}{'e'}) {
                my %score;
                foreach my $wtype('man','combo','prob') {
                    $score{$wtype}= $rrsc{$docID}{0}{'e'}{$wtype};
                }
                my $score= $score{'man'}.":".$score{'combo'}.":".$score{'prob'};
                push(@scs,$score);
            }
            else {
                push(@scs,"0:0:0");
            }
            if ($rrsc{$docID}{0}{'pav'}) {
                my ($ol_pse,$ol_npse) = ($rrsc{$docID}{0}{'pav'},$rrsc{$docID}{0}{'nav'});
                push(@scs,sprintf("%-4s",$ol_pse/($ol_pse+$ol_npse)));
            }
            else {
                push(@scs,sprintf("%-4s",0));
            }

            # qry-dependent opinion scores 
            foreach my $name('acx','acd','acd2','hfx','hfd','hfd2','iux','iud','iud2',
                             'lfx','lfd','lfd2','w1x','w1d','w1d2','w2x','w2d','w2d2') {
                my %score;
                foreach my $wtype('man','combo','prob') {
                    my ($sc,$psc,$nsc);
                    $sc=0 if (!($sc= $rrsc{$docID}{$qn}{$name}{$wtype}));
                    $psc=0 if (!($psc= $rrsc{$docID}{$qn}{$name.'P'}{$wtype}));
                    $nsc=0 if (!($nsc= $rrsc{$docID}{$qn}{$name.'N'}{$wtype}));
                    $score{$wtype}= $sc."p$psc"."n$nsc";
                }
                my $score= $score{'man'}.":".$score{'combo'}.":".$score{'prob'};
                push(@scs,$score);
            }
            if ($rrsc{$docID}{$qn}{'ex'}) {
                my %score;
                foreach my $wtype('man','combo','prob') {
                    $score{$wtype}= $rrsc{$docID}{$qn}{'ex'}{$wtype};
                }
                my $score= $score{'man'}.":".$score{'combo'}.":".$score{'prob'};
                push(@scs,$score);
            }
            else {
                push(@scs,"0:0:0");
            }
            if ($rrsc{$docID}{$qn}{'ed'}) {
                my %score;
                foreach my $wtype('man','combo','prob') {
                    $score{$wtype}= $rrsc{$docID}{$qn}{'ed'}{$wtype};
                }
                my $score= $score{'man'}.":".$score{'combo'}.":".$score{'prob'};
                push(@scs,$score);
            }
            else {
                push(@scs,"0:0:0");
            }

            if ($rrsc{$docID}{$qn}{'ed2'}) {
                my %score;
                foreach my $wtype('man','combo','prob') {
                    $score{$wtype}= $rrsc{$docID}{$qn}{'ed2'}{$wtype};
                }
                my $score= $score{'man'}.":".$score{'combo'}.":".$score{'prob'};
                push(@scs,$score);
            }
            else {
                push(@scs,"0:0:0");
            }
            if ($rrsc{$docID}{$qn}{'pavx'}) {
                my ($ol_pse,$ol_npse) = ($rrsc{$docID}{$qn}{'pavx'},$rrsc{$docID}{$qn}{'navx'});
                push(@scs,sprintf("%-4s",$ol_pse/($ol_pse+$ol_npse)));
            }
            else {
                push(@scs,sprintf("%-4s",0));
            }
            print OUT2 join(" ",@scs),"\n";

        } #end-foreach $rank
    } #end-foreach $qn

    close OUT1;
    close OUT2;

} #end-foreach $file


#-------------------------------------------------
# output rerank score files
#-------------------------------------------------
# %rrlist: for creating rerank score files
#   k(filename -> docID) = v(1)
# %rrsc: existing rerank scores
#   k(docID -> QN -> name) = v(score)
#-------------------------------------------------

&printRRSC(\%rrlist,\%rrsc,$outd2);


#-------------------------------------------------
# end program
#-------------------------------------------------

&end_log($pdir,$logdir,$filemode,@start_time) if ($log);

# notify author of program completion
#&notify($sfx,$author);


#####################
# subroutines
#####################

BEGIN { print STDOUT "\n"; }
END { print STDOUT "\n"; }


#-----------------------------------------------------------
# create a subset of query hash
#-----------------------------------------------------------
# arg1 = pointer to input hash
# arg2 = pointer to inclusion hash
# r.v. = subset hash
#-----------------------------------------------------------
sub subQN {
    my($hp,$inchp)=@_;
    my $debug=0;

    my %hash;
    foreach my $qn(keys %$hp) {
        $hash{$qn}=$hp->{$qn} if ($inchp->{$qn});
        print "subQN: QN=$qn\n" if ($debug);
    }

    return %hash;

} #endsub subQN


#-------------------------------------------------
# create hashes of query text
#   - qdesc2, phrase, nr_phrase, nr_nouns should not be used for short query runs
#-------------------------------------------------
#  arg1 = processed query directory
#  arg2 = webx query phrases directory
#  arg3 = pointer to query title hash
#           k= QN, v= query title text (raw)
#  arg4 = pointer to processed query title hash
#           k= QN, v= query title text (stopped & stemmed)
#  arg5 = pointer to query title hash (combine raw & processed terms)
#           k= QN, v= hash pointer (k=term, v=1)
#  arg6 = pointer to processed query description hash
#           k= QN, v= query description text (stopped & stemmed)
#  arg7 = pointer to processed query phrase hash
#           k= QN, v= hash pointer
#             k= phrase, v= freq
#  arg8 = pointer to expanded query phrase hash
#           k= QN, v= hash pointer
#             k= phrase, v= freq
#  arg9 = pointer to processed query non-relevant phrase hash
#           k= QN, v= hash pointer
#             k= nonrel_phrase, v= freq
#  arg10 = pointer to processed query non-relevant noun hash
#           k= QN, v= hash pointer
#             k= nonrel_noun, v= freq
#-------------------------------------------------
sub mkQRYhash {  #!!! test qti3hp
    my($in,$in2,$qtihp,$qti2hp,$qti3hp,$qdesc2hp,$php,$ph2p,$nrphp,$nrnhp)=@_;

    opendir(IND,$in) || die "can't opendir $in";
    my @files= readdir(IND);
    closedir IND;

    foreach my $file(@files) {

        next if ($file!~/^q(\d+)/);
        my $qn=$1;

        # get expanded noun phrases 
        my $inf2="$in2/qsx$qn";
        open(IN2,$inf2) || die "can't read $inf2";
        while(<IN2>) {
            chomp;
            my($wd,$wt)=split/ +/;
            $ph2p->{$qn}={"$wd"=>$wt};
            $qti3hp->{$qn}{lc($wd)}=1; 
        }
        close IN2;

        my $inf="$in/$file";
        open(IN,$inf) || die "can't read $inf";
        my @lines=<IN>;
        close IN;

        my $bstring= join("",@lines);

        # get title text
        if ($bstring=~m|<title>(.+?)</title>|s) {
            my $str=$1;
            $str=~m|<text>(.+?)</text>\n<text0>(.+?)</text0>|s;
            my ($ti,$ti2)=($1,$2);

            # delete quotations & punctuations
            $ti=~s/"//g;
            $ti=~s/^\W*(.+?)\W*$/$1/g;

            # accomodate (Boolean) OR in title text
            $ti=~s/\s+OR\s+/ | /ig;

            # accomodate changes in indexing module (7/20/2007)
            $ti2=$1 if ($ti2=~/^(.+?)\s+,/);
            $qtihp->{$qn}=$ti;
            $qti2hp->{$qn}=$ti2;

            foreach my $wd(split/[ \|]/,"$ti $ti2") { $qti3hp->{$qn}{lc($wd)}=1; }
        }

        # get description text
        if ($bstring=~m|<desc>(.+?)</desc>|s) {
            my $str=$1;
            $str=~m|<text0>(.+?)</text0>|s;
            my $desc=$1;

            # accomodate changes in indexing module (7/20/2007)
            $desc=$1 if ($desc=~/^(.+?)\s+,/);
            $qdesc2hp->{$qn}=$desc;
        }

        # get noun phrases
        if (my @text= $bstring=~m|<phrase>(.+?)</phrase>|gs) {
            my %wds;
            foreach my $str(@text) {
                my @wds=split(/ +/,$str);
                foreach my $wd(@wds) {
                    $wds{"$wd"}++;
                }
            }
            $php->{$qn}=\%wds;
        }

        # get nonrel phrases
        if ($bstring=~m|<nrphrase>(.+?)</nrphrase>|s) {
            my @wds=split(/ +/,$1);
            my %wds;
            foreach my $wd(@wds) {
                $wds{"$wd"}++;
            }
            $nrphp->{$qn}=\%wds;
        }

        # get nonrel nouns
        if ($bstring=~m|<nrnoun>(.+?)</nrnoun>|s) {
            my @wds=split(/ +/,$1);
            my %wds;
            foreach my $wd(@wds) {
                $wds{"$wd"}++;
            }
            $nrnhp->{$qn}=\%wds;
        }

    } #end-foreach $file(@files) 

} #endsub mkQRYhash


#-----------------------------------------------------------
# create %rrsc from existing rerank score files
#-----------------------------------------------------------
# %rrsc: existing rerank scores
#   k(docID -> QN -> name) = v(score)
#   k1= docID
#   v1= hash pointer
#       k2= QN (NOTE: 0= query independent scores)
#       v2= hash pointer
#           k2= score name
#           v2= score
#               onTopic key values:
#                 ti   - exact match of query title in doc title
#                 bd   - exact match of query title in doc body
#                 tix  - proximity match of query title in doc title
#                 bdx  - proximity match of query title in doc body
#                 bdx2 - proximity match of query description in doc body
#                 ph   - query phrase match in doc title + body
#                 ph2  - expanded query phrase match in doc title + body
#                 nrph - query non-relevant phrase match in doc title + body
#                 nrn  - query non-relevant noun match in doc title + body
#               opinion key values (QN=0):  iu[NP],hf[NP],lf[NP],w1[NP],w2[NP],e[NP]
#               opinion key values (QN!=0): iux[NP],hfx[NP],lfx[NP],w1x[NP],w2x[NP],ex[NP]
#                 e.g iu   - IU simple match score
#                     iuP  - IU simple positive poloarity match score
#                     iuN  - IU simple negative poloarity match score
#                     iux  - IU proximity match score
#                     iuxP - IU proximity positive polarity match score
#                     iuxN - IU proximity negative polarity match score
#                     iud  - IU idist score
#                     iudP - IU idist positive polarity score
#                     iudN - IU idist negative polarity score
#               misc. key values (QN=0):
#                 tlen   - text length in word count
#                 iucnt  - number of I, my, me
#                 iucnt2 - number of you, we, your, our, us
#-----------------------------------------------------------
# arg1 = rerank score file directory
# arg2 = pointer to %rrsc
# r.v. = list of files read
#-----------------------------------------------------------
sub mkRRSChash {
    my($ind,$rrhp)=@_;

    my @wname=('man','combo','prob');

    opendir(IND,$ind) || die "can't opendir $ind";
    my @files= readdir(IND);
    closedir IND;

    my @flist;

    foreach my $file(@files) {
        next if ($file !~ /\.([12])$/);

        # *.1 = query-independent score file
        # *.2 = query-dependent score file
        my $ftype=0;
        $ftype=1 if ($1 eq '1');  

        my $inf= "$ind/$file";
        push(@flist,$inf);

        open(IN,$inf) || die "can't read $inf";
        my @lines=<IN>;
        close IN;

        foreach (@lines) {
            chomp;
            
            # query-independent scores
            #  - $qn=0
            if ($ftype) {

                my $qn=0;  
                my ($docID,$tlen,$iucnt1,$iucnt2,$acsc,$hfsc,$iusc,$lfsc,$w1sc,$w2sc,$empsc,$avsc)=split/\s+/;

                foreach my $sc2($tlen,$iucnt1,$iucnt2,$avsc) {
                    $sc2=~/^(.+?)=(.+)$/;
                    my ($name,$sc)=(lc($1),$2);
                    $rrhp->{$docID}{$qn}{$name}=$sc;
                }

                $empsc=~/^(.+?)=(.+)$/;
                my ($name,$sc1)=(lc($1),$2);
                my ($scM,$scC,$scP)=split/:/,$sc1;
                $rrhp->{$docID}{$qn}{$name}{'man'}=$scM;
                $rrhp->{$docID}{$qn}{$name}{'combo'}=$scC;
                $rrhp->{$docID}{$qn}{$name}{'prob'}=$scP;

                foreach my $sc2($acsc,$hfsc,$iusc,$lfsc,$w1sc,$w2sc) {
                    $sc2=~/^(.+?)=(.+)$/;
                    my ($name,$sc1)=(lc($1),$2);
                    my $i=0;
                    foreach my $sc0(split/:/,$sc1) {
                        $sc0=~/^([\d\.]+)p([\d\.]+)n([\d\.]+)$/;
                        my ($sc,$scp,$scn)=($1,$2,$3);
                        $rrhp->{$docID}{$qn}{$name}{$wname[$i]}=$sc;
                        $rrhp->{$docID}{$qn}{$name.'P'}{$wname[$i]}=$scp;
                        $rrhp->{$docID}{$qn}{$name.'N'}{$wname[$i]}=$scn;
                        $i++;
                    }
                }
            }

            # query-dependent scores
            # ti2, bd2: match of individual query terms
            else {

                my ($docID,$qn,$ti,$bd,$ti2,$bd2,$tix,$bdx,$bdx2,$ph,$ph2,$nrph,$nrn,
                    $acx,$acd,$acd2,$hfx,$hfd,$hfd2,$iux,$iud,$iud2,$lfx,$lfd,$lfd2,
                    $w1x,$w1d,$w1d2,$w2x,$w2d,$w2d2,$empx,$empd,$empd2,$avx)=split/\s+/;

                foreach my $sc2($ti,$bd,$ti2,$bd2,$tix,$bdx,$bdx2,$ph,$ph2,$nrph,$nrn,$avx) {
                    $sc2=~/^(.+?)=(.+)$/;
                    my ($name,$sc)=(lc($1),$2);
                    $rrhp->{$docID}{$qn}{$name}=$sc;
                }

                foreach my $sc2($empx,$empd,$empd2) {
                    $sc2=~/^(.+?)=(.+)$/;
                    my ($name,$sc1)=(lc($1),$2);
                    my $i=0;
                    #print "id=$docID, qn=$qn, name=$name, sc2=$sc2, sc1=$sc1\n";
                    foreach my $sc0(split/:/,$sc1) {
                        #print "  sc0=$sc0, i=$i, wname=$wname[$i]\n";
                        $rrhp->{$docID}{$qn}{$name}{$wname[$i]}=$sc0;
                        $i++;
                    }
                }

                foreach my $sc2($acx,$acd,$acd2,$hfx,$hfd,$hfd2,$iux,$iud,$iud2,$lfx,$lfd,$lfd2,$w1x,$w1d,$w1d2,$w2x,$w2d,$w2d2) {
                    $sc2=~/^(.+?)=(.+)$/;
                    my ($name,$sc1)=(lc($1),$2);
                    my $i=0;
                    foreach my $sc0(split/:/,$sc1) {
                        $sc0=~/^([\d\.]+)p([\d\.]+)n([\d\.]+)$/;
                        my ($sc,$scp,$scn)=($1,$2,$3);
                        $rrhp->{$docID}{$qn}{$name}{$wname[$i]}=$sc;
                        $rrhp->{$docID}{$qn}{$name.'P'}{$wname[$i]}=$scp;
                        $rrhp->{$docID}{$qn}{$name.'N'}{$wname[$i]}=$scn;
                        $i++;
                    }
                }
            }
        }

    } #endsub-foreach

    return (@flist);

} #endsub-mkRRSChash



#-------------------------------------------------
# output rerank score files
#-------------------------------------------------
# %rrlist: for creating rerank score files
#   k(filename -> docID) = v(1)
# %rrsc: existing rerank scores
#   k(docID -> QN -> name) = v(score)
#-------------------------------------------------
# arg1= pointer to %rrsc
# arg2= pointer to %rrlist
# arg3= output directory
#-------------------------------------------------
sub printRRSC {
    my($rrlhp,$rrschp,$dir)=@_;

    foreach my $file(keys %$rrlhp) {

        my $outf1= "$dir/$qtype-$file-$rsetnum.1";  # qry-independent scores
        my $outf2= "$dir/$qtype-$file-$rsetnum.2";  # qry-dependent scores

        open(OUT1,">$outf1") || die "can't write to $outf1";
        open(OUT2,">$outf2") || die "can't write to $outf2";
        print LOG "Writing to $outf1\n";
        print LOG "Writing to $outf2\n\n";

        foreach my $docID(sort keys %{$rrlhp->{$file}}) {

            # skip docID without qny rerank scores
            #   - needed for interim %rrsc output
            my @qns= keys %{$rrschp->{$docID}};
            next if (!@qns);

            print OUT1 "$docID ";

            foreach my $qn(sort {$a<=>$b} keys %{$rrschp->{$docID}}) {

                print OUT2 "$docID $qn " if ($qn>0);

                my @scs;

                #-------------------------
                # qry-independent scores 
                if ($qn==0) {

                    foreach my $name('tl','in1','in2') {
                        if ($rrschp->{$docID}{0}{$name}) {
                            push(@scs,"\U$name\E=$rrschp->{$docID}{0}{$name}");
                        }
                        else {
                            push(@scs,"\U$name\E=0");
                        }
                    }
                    foreach my $name('ac','hf','iu','lf','w1','w2') {
                        my %score;
                        foreach my $wtype('man','combo','prob') {
                            my ($sc,$psc,$nsc);
                            $sc=0 if (!($sc= $rrsc{$docID}{0}{$name}{$wtype}));
                            $psc=0 if (!($psc= $rrsc{$docID}{0}{$name.'P'}{$wtype}));
                            $nsc=0 if (!($nsc= $rrsc{$docID}{0}{$name.'N'}{$wtype}));
                            $score{$wtype}= $sc."p$psc"."n$nsc";
                        }
                        my $score= $score{'man'}.":".$score{'combo'}.":".$score{'prob'};
                        push(@scs,"\U$name\E=$score");
                    }
                    if ($rrschp->{$docID}{0}{'e'}) {
                        my %score;
                        foreach my $wtype('man','combo','prob') {
                            $score{$wtype}= $rrsc{$docID}{0}{'e'}{$wtype};
                        }
                        my $score= $score{'man'}.":".$score{'combo'}.":".$score{'prob'};
                        push(@scs,"E=$score");
                    }
                    else {
                        push(@scs,"E=0:0:0");
                    }
                    if ($rrschp->{$docID}{0}{'pav'}) {
                        my ($ol_pse,$ol_npse) = ($rrschp->{$docID}{0}{'pav'},$rrschp->{$docID}{0}{'nav'});
                        my $sc= sprintf("%.4f",$ol_pse/($ol_pse+$ol_npse));
                        push(@scs,sprintf("%-8s","AV=$sc"));
                    }
                    else {
                        push(@scs,sprintf("%-8s","AV=0"));
                    }


                    print OUT1 join(" ",@scs),"\n";

                } #end-if ($qn==0)

                #-------------------------
                # qry-dependent scores 
                else {

                    @scs=();

                    foreach my $name('ti','bd','ti2','bd2','tix','bdx','bdx2','ph','ph2','nrph','nrn') {
                        my $sc;
                        if ($rrschp->{$docID}{$qn}{$name}) {
                            $sc=sprintf("%.4f",$rrschp->{$docID}{$qn}{$name});
                        }
                        else {
                            $sc=0;
                        }
                        push(@scs,"\U$name\E=$sc");
                    }

                    foreach my $name('acx','acd','acd2','hfx','hfd','hfd2','iux','iud','iud2','lfx','lfd','lfd2',
                                     'w1x','w1d','w1d2','w2x','w2d','w2d2') {
                        my %score;
                        foreach my $wtype('man','combo','prob') {
                            my ($sc,$psc,$nsc);
                            $sc=0 if (!($sc= $rrsc{$docID}{$qn}{$name}{$wtype}));
                            $psc=0 if (!($psc= $rrsc{$docID}{$qn}{$name.'P'}{$wtype}));
                            $nsc=0 if (!($nsc= $rrsc{$docID}{$qn}{$name.'N'}{$wtype}));
                            $score{$wtype}= $sc."p$psc"."n$nsc";
                        }
                        my $score= $score{'man'}.":".$score{'combo'}.":".$score{'prob'};
                        push(@scs,"\U$name\E=$score");
                    }
                    if ($rrschp->{$docID}{$qn}{'ex'}) {
                        my %score;
                        foreach my $wtype('man','combo','prob') {
                            $score{$wtype}= $rrsc{$docID}{$qn}{'ex'}{$wtype};
                        }
                        my $score= $score{'man'}.":".$score{'combo'}.":".$score{'prob'};
                        push(@scs,"EX=$score");
                    }
                    else {
                        push(@scs,"EX=0:0:0");
                    }
                    if ($rrschp->{$docID}{$qn}{'ed'}) {
                        my %score;
                        foreach my $wtype('man','combo','prob') {
                            $score{$wtype}= $rrsc{$docID}{$qn}{'ed'}{$wtype};
                        }
                        my $score= $score{'man'}.":".$score{'combo'}.":".$score{'prob'};
                        push(@scs,"ED=$score");
                    }
                    else {
                        push(@scs,"ED=0:0:0");
                    }
                    if ($rrschp->{$docID}{$qn}{'ed2'}) {
                        my %score;
                        foreach my $wtype('man','combo','prob') {
                            $score{$wtype}= $rrsc{$docID}{$qn}{'ed2'}{$wtype};
                        }
                        my $score= $score{'man'}.":".$score{'combo'}.":".$score{'prob'};
                        push(@scs,"ED2=$score");
                    }
                    else {
                        push(@scs,"ED2=0:0:0");
                    }
                    if ($rrschp->{$docID}{$qn}{'pavx'}) {
                        my ($ol_pse,$ol_npse) = ($rrschp->{$docID}{$qn}{'pavx'},$rrschp->{$docID}{$qn}{'navx'});
                        my $sc= sprintf("%.4f",$ol_pse/($ol_pse+$ol_npse));
                        push(@scs,sprintf("%-8s","AVX=$sc"));
                    }
                    else {
                        push(@scs,sprintf("%-8s","AVX=0"));
                    }

                    print OUT2 join(" ",@scs),"\n";

                } #end-else

            } #end-foreach $qn

        } #end-foreach $docID

        close OUT1;
        close OUT2;

    } #end-foreach $file

} #endsub printRRSC


