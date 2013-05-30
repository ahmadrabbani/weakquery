#!/usr/bin/perl -w

# ------------------------------------------------------------------------------------------
# Name:      fusion1.pl
# Author:    Kiduk Yang, 07/29/2006
#            modified, 06/03/07
#              - updated /u0/widit/prog/trec06/blog/fusion1s0.pl
#            modified, 06/13/08
#              - runs to combine & their fusion weights are specified by $arg2
#              - consolidates fusion1.pl, fusion2.pl, fusion_qe1[a].pl
#            $ID: $
# ------------------------------------------------------------------------------------------
# Description:  execute fusion of baseline runs (e.g., s0 directory)
#   1. read in runs to combine and fusion weights from a file
#   2. merge multiple retrieval result sets
#        SC(fusion) = sum(wt_i*SC_i);
#        where SC are normalized scores, i= system index
#   3. convert to TREC format
# ------------------------------------------------------------------------------------------
# ARGUMENTS: arg1= query type (t for train, e for test, etc.)
#            arg2= fusion list file
#            arg3= fusion file prefix (q, qs, ql, okapi, vsm, etc.)
# INPUT:     $ddir/results/$qtype/trecfmt(x)/s0*/*   -- runs to cobmine
#            $pdir/fslist/$arg3 -- fusion input file
# OUTPUT:    $ddir/results/$qtype/trecfmt(x)/s0*/*f
#              -- fusion result file
#            $ddir/$prog      -- program     (optional)
#            $ddir/$prog.log  -- program log (optional)
#            NOTE: $qtype    = (train|test)
# ------------------------------------------------------------------------------------------
# NOTES: 
# ------------------------------------------------------------------------------------------

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
my $ddir=   "/u3/trec/blog08";          # index directory
my $qdir=   "$ddir/query";              # topic directory

my $logdir= "$ddir/fslog";              # log directory
my $fsdir= "$pdir/fslist";              # fusion input list directory

# query type
my %qtype= ("e"=>"test","ex"=>"test","t"=>"train","tx"=>"train");

require "$wpdir/logsub2.pl";


#------------------------
# program arguments
#------------------------
my $prompt=
"arg1= query type (i.e. t, tx, e, ex)\n".
"arg2= fusion list file\n";

my %valid_args= (
0 => " t tx e ex ",
);

my ($arg_err,$qtype,$fslist)= chkargs($prompt,\%valid_args,2);
die "$arg_err\n" if ($arg_err);

# determine document directory name
my $docdname;
if ($qtype=~/x/) {
    $docdname= "docx";
}
else {
    $docdname= "docs";
}

# fusion input list file
my $fsf= "$fsdir/$fslist";

# processed query directory
my $qrydir= "$qdir/$qtype{$qtype}";

# TREC format result directory
my $rdir= "$ddir/results/$qtype{$qtype}/trecfmt";
$rdir .= 'x' if ($qtype=~/x/);

# read in fslist file
my %fswt;
my ($outf,$wtstr)= &getfswt($fsf,$rdir,\%fswt);
my $outf2= $outf."_trec";


#-------------------------------------------------
# start program log
#-------------------------------------------------

$sfx= "$qtype-$fslist"; # program log file suffix

$noargp=0;              # if 1, do not print arguments to log
$append=0;              # log append flag

# output directory
if (!-e "$logdir") { 
    my @errs=&makedir($logdir,$dirmode,$group);
    print LOG "\n",@errs,"\n\n" if (@errs);
}       

# logs for different runs are appended to the same log file
if ($log) {
    @start_time= &begin_log($logdir,$filemode,$sfx,$noargp,$append);
    print LOG "Inf   = $fsf\n",
              "Outf  = $outf\n",
              "      = $outf2\n\n",
              "Fusion weights:\n$wtstr\n\n";
}


#-------------------------------------------
# read in results to combine
#   %result0: holds results to combine
#     - k=QN:docno, v=pointer to run result hash
#             k= run_name v="score rank"
#   %maxsc: for score normalization
#     - k=QN, v= pointer to max score hash
#             k= run_name v=max. original score
#   %minsc: for score normalization
#     - k=QN, v= pointer to min score hash
#             k= run_name v=min. original score
#-------------------------------------------

my (%result0,%maxsc,%minsc);

foreach my $file(keys %fswt) {

    my $inf="$rdir/$file";
    printf LOG "Reading $inf\n";

    open(IN,$inf) || die "can't read $inf";

    my ($oldsc,$oldrun,$oldqnum,$rank)=(0);

    while(<IN>) {

        my ($qnum,$docno,$rnk,$sc);

        # TREC format file
        if (/^\d+\s+Q0\s+/) { 
            my $dummy;
            ($qnum,$dummy,$docno,$rnk,$sc)=split/\s+/; 
        }

        else {
            my $c1;
            ($qnum,$docno,$rnk,$sc,$c1)=split/\s+/; 

            # rerank runs
            if ($c1=~/^[a-zA-Z]\d$/) {
                my $grp=$c1;
            }
        }

        if (!$oldqnum || ($oldqnum ne $qnum)) { $rank=0; }
        $rank++; 

        $result0{"$qnum:$docno"}{$file}="$sc $rank";
        if ($rank==1) { 
            $maxsc{$qnum}{$file}=$sc; 
            $minsc{$oldqnum}{$oldrun}=$oldsc if ($oldsc);
            print "qn=$qnum, f=$file, max=$sc, min=$oldsc, oqn=$oldqnum, of=$oldrun\n" if ($debug);
        }
        $oldqnum=$qnum;
        $oldsc=$sc;
        $oldrun=$file;

    } #end-while

    close IN;

    $minsc{$oldqnum}{$oldrun}=$oldsc;
}


#-------------------------------------------------
# compute fusion scores for each documents
#   %result: combined results
#     - k=QN, v= pointer to array of "DOCNO fusion_SC rank_run1 rank_run2.."
#   %result0: holds results to combine
#     - k=QN:docno, v=pointer to run result hash
#             k= run_name v="score rank"
#   %maxsc: for score normalization
#     - k=QN, v= pointer to max score hash
#             k= run_name v=max. original score
#   %minsc: for score normalization
#     - k=QN, v= pointer to min score hash
#             k= run_name v=min. original score
#-------------------------------------------------
my %result;
foreach my $qndn(keys %result0) {
    my($qn,$dn)=split/:/,$qndn;

    my ($fscore,@ranks)=(4);
    foreach my $run(keys %{$maxsc{$qn}}) {
        next if (!exists($result0{$qndn}{$run}));

        my $maxsc= $maxsc{$qn}{$run};  # max. score for run-topic
        my $minsc= $minsc{$qn}{$run};  # min. score for run-topic
        my $denom= $maxsc-$minsc;      
        print "qn=$qn, run=$run, max=$maxsc, min=$minsc\n" if ($debug);

        my ($sc,$rnk)= split/ /,$result0{$qndn}{$run};
        my $sc_norm= ($sc-$minsc)/$denom;  # normalized score for each run result

        my ($runName,$wt)= split(/ /,$fswt{$run});
        $fscore += $wt*$sc_norm;

        push(@ranks,$rnk."_$runName");

    } #end-foreach $run

    push(@{$result{$qn}},"$dn $fscore @ranks");

} #end-foreach $qndn


#-------------------------------------------------
# sort and output fusion results
#   %result: combined results
#     - k=QN, v= pointer to array of "DOCNO fusion_SC rank_run1 rank_run2.."
#-------------------------------------------------

open(OUT,">$outf") || die "can't write to $outf";
open(OUT2,">$outf2") || die "can't write to $outf2";

foreach my $qn(sort {$a<=>$b} keys %result) {
 
    # create reranking hashes
    #  - %result1:
    #      key=docno, val=score
    #  - %resultA: all results for a given QN
    #      key=docno, val='rank1 rank2 ..'
    my(%result1,%resultA)=();
    
    foreach my $line(@{$result{$qn}}) {
        my($docno,$sc,$restrank)=split(/ /,$line,3);
        $result1{$docno}=$sc; 
        $resultA{$docno}="$restrank";
    } #end-foreach $line
    
    #-----------------------------------
    # rerank results 
    #-----------------------------------
    
    my ($rank,$rank2,$score,$oldsc)=(0,0,0,1);

    foreach my $docno(sort {$result1{$b}<=>$result1{$a}} keys %result1) {
        $score= sprintf("%.7f",$result1{$docno});
        $rank++;
        # convert zero/negative score to non-zero value
        if ($score<=0) { $score= sprintf("%.7f",$oldsc-$oldsc*0.1); }
        print OUT "$qn $docno $rank $score $resultA{$docno}\n";
        printf OUT2 "%-4s  Q0   %-32s  %7d   %11.6f   $fslist\n", $qn,$docno,$rank,$score;
        $oldsc=$score;
    }

} #end-foreach $qn
close OUT;
close OUT2;



# ------------------------------------------------
# end program
# ------------------------------------------------

if ($log) { &end_log($pdir,$logdir,$filemode,@start_time); }

# notify author of program completion
#&notify($sfx,$author);


#################################
# SUBROUTINES
#################################

BEGIN { print STDOUT "\n"; }
END { print STDOUT "\n"; }

#--------------------------------
# read in fusion list into %fswt
#--------------------------------
#   arg1= fslist file
#   arg2= result directory
#   arg3= pointer to %fswt
#   r.v.= (output file name, file-weight string)
#--------------------------------
sub getfswt {
    my($in,$dir,$hp)=@_;

    open(IN,$in) || die "can't read $in";

    my $out=<IN>;
    chomp $out;

    my @wts;
    while(<IN>) {
        chomp;
        my($file,$run,$wt)=split/ +/;
        $hp->{$file}="$run $wt";
        push(@wts,"  $wt * $file");
    }

    my $wtstr= join("\n",@wts);

    return ("$dir/$out",$wtstr);



} #endsub getfswt
