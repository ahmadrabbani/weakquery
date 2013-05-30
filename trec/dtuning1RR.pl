#!/usr/bin/perl -w

# ------------------------------------------------------------------------
# Name:      dtuning1RR.pl
# Author:    Kiduk Yang, 7/25/2007
#             modified mkdtuning1.pl (11/2006)
#             modified dtuning1qenew.pl, 7/1/2008
# ------------------------------------------------------------------------
# Description:
#   create preliminary files needed for dynamic tuning
#    - modified to handle idist and wqx phrase scores
#    - input files are rerank files (*.r1, *r2)
# ------------------------------------------------------------------------
# ARGUMENTS: arg1 -- query type (t for training, e evaluation topics)
#            arg2 -- result subdirectory (e.g., s0)
# Input:     $idir/results/$qtype/trecfmt[x]/s.[R]/$run
# Output:    $idir/results/$qtype/qrelcnt - qrelcnt file
#               QN topic_relN opinion_relN
#            $idir/results/$qtype/trecfmt[x]/rerank/$run/evalstat
#               QN apT rpT p10T p50T p100T apO rpO p10O p50O p100O
#            $idir/results/$qtype/trecfmt[x]/rerank/$run/minmaxsc
#               QN minsc maxsc
#            $idir/results/$qtype/trecfmt[x]/rerank/$run/rt$qn
#               DN relsc ...
#            $twdir/results/$qtype/$prog     - program (optional)
#            $twdir/results/$qtype/$prog.log - program log (optional)
#            NOTE: $qtype   = query type (train|test)
# ------------------------------------------------------------------------
# NOTES:     
# ------------------------------------------------------------------------


use strict;
use Data::Dumper;
$Data::Dumper::Purity=1;

my ($debug,$filemode,$filemode2,$dirmode,$dirmode2,$author,$group);
my ($log,$sfx,$noargp,$append,@start_time);

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
my $pdir=  "$wpdir/trec08/blog";        # TREC program directory
my $rdir=   "/u3/trec/blog08/results";  # blog result directory

my %qrelf= (
't' => "/u1/trec/qrels/qrels.opinion.blog06-07",
'tx' => "/u1/trec/qrels/qrels.opinion.blog06-07",
'e' => "/u1/trec/qrels/qrels.opinion.blog08",
'ex' => "/u1/trec/qrels/qrels.opinion.blog08",
);

# query type
my %qtypes= ("e"=>"test/trecfmt","t"=>"train/trecfmt","ex"=>"test/trecfmtx","tx"=>"train/trecfmtx");

require "$wpdir/logsub2.pl";          # general subroutine library


#------------------------
# program arguments
#------------------------
my $prompt= 
"arg1= query type (e.g t, tx)\n".
"arg2= query subdirectory (s0R)\n".
"arg3= filename prefix (optional)\n";


my %valid_args= (
0 => " t* e* ",
1 => " s0* ",
);

my ($arg_err,$qtype,$rsubd,$fpfx)= chkargs($prompt,\%valid_args);
die "$arg_err\n" if ($arg_err);

my $qcnt;
if ($qtype=~/^t/) { $qcnt=100; }
else { $qcnt=50; }

# TREC format result directory
my $idir= "$rdir/$qtypes{$qtype}";

# qrelcnt file
my $qrelcntf= "$idir/qrelcnt";
$qrelcntf=~s|trecfmtx?/||;

# TREC format result directory
my $ind= "$idir/$rsubd";

# dtuning rerank directory
my $outd= $ind;
$outd=~s|($rsubd)|rerank/$1|;


#-------------------------------------------------
# start program log
#-------------------------------------------------

$sfx= "$qtype$rsubd";         # program log file suffix
$noargp=0;              # if 1, do not print arguments to log
$append=0;              # log append flag

if ($log) { 
    @start_time= &begin_log($idir,$filemode,$sfx,$noargp,$append); 
    print LOG "InD  = $ind/\$run\n",
              "OutF = $qrelcntf\n",
              "       $outd/\$run/\n",
              "         evalstat, rt\$qn\n\n";
}


#-------------------------------------------------
# 1. create qrels hash
# 2. output qrelcnt file
#    - QN topic_relN opinion_relN
#-------------------------------------------------

my %qrels;

# create qrels hash
#     key=QN, val=pointer to docID
open(IN,$qrelf{$qtype}) || die "can't read $qrelf{$qtype}";
my @lines=<IN>;
chomp @lines;
foreach(@lines){
    my($qn,$dummy,$dname,$relsc)= split(/\s+/,$_); #($qnumber 0 $dn $rel_score)
    next if ($relsc<1);
    $qrels{$qn}{$dname}=$relsc;
}

my %qrelcnt;
foreach my $qn(keys %qrels) {
    foreach my $dn(keys %{$qrels{$qn}}) {
        $qrelcnt{$qn}{'topic'}++ if($qrels{$qn}{$dn}>0);
        $qrelcnt{$qn}{'opinion'}++ if($qrels{$qn}{$dn}>1);
    }
}

open(OUT,">$qrelcntf") || die "can't write to $qrelcntf";
foreach my $qn(sort {$a<=>$b} keys %qrelcnt) {
    print OUT "$qn $qrelcnt{$qn}{'topic'} $qrelcnt{$qn}{'opinion'}\n";
}
close OUT;


#-------------------------------------------------
# 1. read in result file names
# 2. create rerank subdirectories for each result
# 3. create result file per topic
#-------------------------------------------------


# get the list of result files
opendir(IND,$ind) || die "can't opendir $ind";
my @files= readdir IND;
closedir IND;


foreach my $fname(@files) {

    next if ($fname !~ /\.r[12]$/);
    next if (-d "$ind/$fname");

    # output directory
    my $outdir= "$outd/$fname";

    if (!-e "$outdir") {
        my @errs=&makedir($outdir,$dirmode,$group);
        print LOG "\n",@errs,"\n\n" if (@errs);
    }

    my $inf= "$ind/$fname";
    open(IN,$inf) || die "can't read $inf";

    print LOG "INF=  $inf\n";
    print LOG "OUTF= $outdir/rt\$qn\n";

    my %result=();  # k=qn, v=array of result lines
    while(<IN>) {

        my ($qn,$dn,$rest)=split(/\s+/,$_,3);

        my $qrel=0;
        $qrel=$qrels{$qn}{$dn} if ($qrels{$qn}{$dn});

        push(@{$result{$qn}},"$dn $qrel $rest");

    }
    close IN;

    my $evalf= "$outdir/evalstat";
    my %evalall;

    open(EVALF,">$evalf") || die "can't write to $evalf";

    print EVALF "QN AP_topic RP_topic P10_topic P50_topic p100_topic AP_op RP_op P10_op P50_op P100_op\n";

    foreach my $qn(sort {$a<=>$b} keys %result) {

        my $outf= "$outdir/rt$qn";

        open(OUT,">$outf") || die "can't write to $outf";
        my $lcnt=0;
        foreach my $line(@{$result{$qn}}) {
            print OUT $line;
            $lcnt++;
            last if ($lcnt>=1000);
        }
        close OUT;

        my %evals;
        &evalstat($qn,$outf,\%evals);

        printf EVALF "$qn %.4f %.4f %.4f %.4f %.4f %.4f %.4f %.4f %.4f %.4f\n",
                        $evals{'apT'},$evals{'rpT'},$evals{'p10T'},$evals{'p50T'},$evals{'p100T'},
                        $evals{'apO'},$evals{'rpO'},$evals{'p10O'},$evals{'p50O'},$evals{'p100O'};

        foreach my $name(keys %evals) {
            $evalall{$name}+= $evals{$name};
        }

    } #end-foreach $qn

    printf EVALF "ALL %.4f %.4f %.4f %.4f %.4f %.4f %.4f %.4f %.4f %.4f\n",
        $evalall{'apT'}/$qcnt,$evalall{'rpT'}/$qcnt,$evalall{'p10T'}/$qcnt,$evalall{'p50T'}/$qcnt,$evalall{'p100T'}/$qcnt,
        $evalall{'apO'}/$qcnt,$evalall{'rpO'}/$qcnt,$evalall{'p10O'}/$qcnt,$evalall{'p50O'}/$qcnt,$evalall{'p100O'}/$qcnt;

    close EVALF;

} #end-foreach $fname(@files) 



# ------------------------------------------------
# end program
# ------------------------------------------------

if ($log) { 
    print LOG "\n";
    &end_log($pdir,$idir,$filemode,@start_time); 
}

# notify author of program completion
#&notify($sfx,$author);



####################
# subroutines
####################

BEGIN { print STDOUT "\n"; }
END { print STDOUT "\n"; }


#---------------------------------------------
# compute eval stat from result file
#---------------------------------------------
#  arg1= query number
#  arg2= pointer to result file
#  arg3= pointer to eval hash
#---------------------------------------------
sub evalstat {
    my($qn,$rtf,$evalp)=@_;

    my ($relnT,$relnO)=(0,0);
    my (%P,%R)=();

    open(IN,$rtf) || die "can't read $rtf";
    my @lines=<IN>;
    close IN;

    $evalp->{'apT'}=0;
    $evalp->{'apO'}=0;

    my $rank2=0;
    foreach (@lines) {

        $rank2++;

        s/^\s+//;

        my ($dn,$rel)=split/\s+/;

        if ($rel) {
            $relnT++;
            $relnO++ if ($rel>1);
        }

        my $Pt=sprintf("%.4f",$relnT/$rank2);
        my $Rt=sprintf("%.4f",$relnT/$qrelcnt{$qn}{'topic'});
        $P{$rank2}{'topic'}=$Pt;
        $R{$rank2}{'topic'}=$Rt;

        my $Po=sprintf("%.4f",$relnO/$rank2);
        my $Ro=sprintf("%.4f",$relnO/$qrelcnt{$qn}{'opinion'});
        $P{$rank2}{'opinion'}=$Po;
        $R{$rank2}{'opinion'}=$Ro;

        if ($rel) {
            $evalp->{'apT'} += $Pt;
            $evalp->{'apO'} += $Po if ($rel>1);
        }

    }

    $evalp->{'apT'}= sprintf("%.4f",$evalp->{'apT'}/$qrelcnt{$qn}{'topic'});
    $evalp->{'rpT'}= $P{$qrelcnt{$qn}{'topic'}}{'topic'};

    $evalp->{'apO'}= sprintf("%.4f",$evalp->{'apO'}/$qrelcnt{$qn}{'opinion'});
    $evalp->{'rpO'}= $P{$qrelcnt{$qn}{'opinion'}}{'opinion'};

    foreach my $rnk(10,50,100) {
        my $rnkT= "p$rnk"."T";
        my $rnkO= "p$rnk"."O";
        $evalp->{$rnkT}= $P{$rnk}{'topic'};
        $evalp->{$rnkO}= $P{$rnk}{'opinion'};
    }

} #endsub evalstat

