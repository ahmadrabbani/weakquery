#!/usr/bin/perl -w

# -----------------------------------------------------------------
# Name:      rerankrt4pol.pl
# Author:    Kiduk Yang, 07/2/2008
#              modified rerankrt4c.pl (5/2008)
#              $Id: rerankrt4.pl,v 1.1 2008/06/27 00:43:44 kiyang Exp kiyang $
# -----------------------------------------------------------------
# Description:  Perform post-retrieval reranking for polarity
#   1. read opinion RR files
#   2. rerank using ploarity scores
#   3. output in TREC format
# -----------------------------------------------------------------
# ARGUMENT:  arg1= query type (i.e. t=train, tx=train w/ subx, e=test, ex=test w/ subx)
#            arg2= rerank subdirectory (e.g. s0baseRc)
#            arg3= input file prifix (optional)
# INPUT:     $ddir/results/$qtype/trecfmt(x)/$arg2/*.2
#              -- results w/ opinion reranking scores
# OUTPUT:    $ddir/results/$qtype/trecfmt(x)/$arg2/*.r2p_trec
#            $ddir/results/$qtype/trecfmt(x)/$arg2/*.r2n_trec
#            $ddir/rrlog/$prog      -- program     (optional)
#            $ddir/rrlog/$prog.log  -- program log (optional)
#            NOTE: $qtype   = query type (train|eval)
# -----------------------------------------------------------------
# NOTES: 
#   1. result file contains only $maxrank docs per topic
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

use constant MAXRANK => 500;
use constant MAXRTCNT => 1000;      # max. number of documents per result

my $wpdir=  "/u0/widit/prog";           # widit program directory
my $tpdir=  "$wpdir/trec08";            # TREC program directory
my $pdir=   "$tpdir/blog";              # TREC program directory
my $ddir=   "/u3/trec/blog08";          # index directory
my $logd=   "$ddir/rrlog";              # log directory

# query type
my %qtype= ("e"=>"test","ex"=>"test","t"=>"train","tx"=>"train");

my %ogwt= (
1=>0.8,
2=>0.82,
3=>0.84,
4=>0.86,
5=>0.88,
6=>0.9,
);

my %rrwt= (
1=>'0.2',
2=>0.18,
3=>0.16,
4=>0.14,
5=>0.12,
6=>0.1,
);

require "$wpdir/logsub2.pl";


#------------------------
# program arguments
#------------------------
my $prompt=
"arg1= query type (i.e. t, tx, e, ex)\n".
"arg2= rerank subdirectory (e.g. s0baseRd)\n".
"arg63 result file name prefix (optional)\n";

my %valid_args= (
0 => " t tx e ex ",
1 => " s0* ",
);

my ($arg_err,$qtype,$rsubd,$fpfx)= chkargs($prompt,\%valid_args,2);
die "$arg_err\n" if ($arg_err);

my $maxrank=MAXRANK;

# TREC format directory
my $rdir= "$ddir/results/$qtype{$qtype}/trecfmt/$rsubd";
$rdir=~s/trecfmt/trecfmtx/ if ($qtype=~/x/);

my $rdir2=$rdir."POL";

`mkdir -p $rdir2` if (!-e $rdir2);


#-------------------------------------------------
# start program log
#-------------------------------------------------

$sfx= "$qtype$rsubd"; # program log file suffix

$noargp=0;              # if 1, do not print arguments to log
$append=0;              # log append flag

if ($log) {
    @start_time= &begin_log($logd,$filemode,$sfx,$noargp,$append);
    print LOG "InF   = $rdir/*.r2\n",
              "OutF  = $rdir2/*.r2P_trec, *.r2N_trec\n\n";
}


#-------------------------------------------------------------
# create opinion score name arrays for easier processing
#-------------------------------------------
# create opinion reranked files
#-------------------------------------------

opendir(IND,$rdir) || die "can't opendir $rdir";
my @files=readdir(IND);
closedir IND;

foreach my $file(@files) {
    next if ($file !~ /\.r2$/);
    
    my $inf= "$rdir/$file";
    print "Reading $inf\n";
    
    &mkRRf($inf,$rdir2,$file);

}


#-------------------------------------------------
# end program
#-------------------------------------------------

&end_log($pdir,$logd,$filemode,@start_time) if ($log);

# notify author of program completion
#&notify($sfx,$author);


##################################
# SUBROUTINE
##################################

BEGIN { print STDOUT "\n"; }
END { print STDOUT "\n"; }

#-------------------------------------------
# create hashes
#   %result: 
#     - k=QN 
#     - v= pointer to array of "DOCNO RANK Orig_SC Rerank_SC RunName"
#   %resultop: k=QN:docno, v=opinion scores
#   %result0: k=QN:docno, v=result line from on-topic reranking plus opinion scores
#   %maxsc: k=QN, v= hash pointer
#                 k= score name v=max. original score
#   %minsc: k=QN, v= hash pointer
#                 k= score name v=min. original score
#-------------------------------------------

sub mkRRf {
    my ($inf,$outd,$fpfx)=@_;

    my %OUT;

    foreach my $sctype('og','rr') {
        foreach my $wtn(1..6) {
            foreach my $pol('N','P') {
                my $k= "$sctype$wtn$pol";
                my $outf= "$outd/$fpfx-$k"."_trec";
                print "writing to $outf\n";
                open($OUT{$k},">$outf") || die "can't write to $outf";
            }
        }
    }

    my %result;
    open(OPIN,$inf) || die "can't read $inf";
    while(<OPIN>) {
        chomp;

        my ($qnum,$docno,$rank,$sc,$group,$run,$rank0,$sc0,@restsc)=split(/\s+/,$_);

        next if ($rank>MAXRTCNT);

        my $scN=pop(@restsc);
        my $scP=pop(@restsc);

        push(@{$result{$qnum}},"$docno $rank $sc $group $run $sc0 $scN $scP");

    } #end-while
    close OPIN;

    my %result0;
    foreach my $qn(sort {$a<=>$b} keys %result) {

        my (%result1,%result2,%result3,%result4,%result5,%rest,%sc,%scdiff,%score)=();

        foreach my $line(@{$result{$qn}}) {
            my($docno,$rank,$sc,$group,$run,$sc0,$scN,$scP)= split/ +/,$line;

            $sc{'og'}=$sc0;
            $sc{'rr'}=$sc;

            $scdiff{'N'}= $scN-$scP;
            $scdiff{'P'}= $scP-$scN;

            foreach my $sctype('og','rr') {
                foreach my $wtn(1..6) {
                    foreach my $pol('N','P') {
                        my $k= "$sctype$wtn$pol";
                        $score{$k}= $ogwt{$wtn}*$sc{$sctype} + $rrwt{$wtn}*$scdiff{$pol};

                    }
                }
            }

            foreach my $sctype('og','rr') {
                foreach my $wtn(1..6) {
                    foreach my $pol('N','P') {

                        my $k= "$sctype$wtn$pol";

                        # create reranking hashes by rerank group
                        if ($rank<=$maxrank) {
                            if ($group=~/A/) { $result1{$k}{$docno}=$score{$k}; }
                            elsif ($group=~/B/) { $result2{$k}{$docno}=$score{$k}; }
                            elsif ($group=~/C/) { $result3{$k}{$docno}=$score{$k}; }
                            else { $result4{$k}{$docno}=$score{$k}; }
                        }

                        # for results beyond rerank range
                        #   1. set score to 0 if rrlow flag is not set
                        #   2. assign their own rerank sort group
                        else {
                            $result5{$k}{$docno}=$score{$k};
                            push(@{$rest{$k}},$docno);
                        }

                        $result0{$k}{"$qn:$docno"}= "$group $rank $sc $run";

                    }
                }
            }

        } #end-foreach my $line

        #-----------------------------------
        # rerank results by group and output
        #-----------------------------------

        foreach my $sctype('og','rr') {
            foreach my $wtn(1..6) {
                foreach my $pol('N','P') {

                    my $k= "$sctype$wtn$pol";

                    my ($OUT,$rank,$rank2,$score,$offset,$oldsc)=($OUT{$k},0,0,0,0,1);
                    
                    foreach my $docno(sort {$result1{$k}{$b}<=>$result1{$k}{$a}} keys %{$result1{$k}}) {
                        $score= sprintf("%.7f",$result1{$k}{$docno});
                        my ($grp,$rank0,$sc,$run)=split(/\s+/,$result0{$k}{"$qn:$docno"});
                        $rank++;
                        # convert zero/negative score to non-zero value
                        if ($score<=0) { $score= sprintf("%.7f",$oldsc-$oldsc*0.1); }
                        printf $OUT "%-4s  Q0   %-32s  %7d   %11.6f   $run\n", $qn,$docno,$rank,$score;
                        $oldsc=$score;
                    }
                    
                    ($rank,$score,$oldsc)=&rrgrp($OUT,$result2{$k},$result0{$k},$qn,$rank,$score,$oldsc);
                    ($rank,$score,$oldsc)=&rrgrp($OUT,$result3{$k},$result0{$k},$qn,$rank,$score,$oldsc);
                    ($rank,$score,$oldsc)=&rrgrp($OUT,$result4{$k},$result0{$k},$qn,$rank,$score,$oldsc);
                    ($rank,$score,$oldsc)=&rrgrp2($OUT,$result5{$k},$result0{$k},$qn,$rank,$score,$oldsc,$rest{$k});

                    print LOG "!Warning: Topic $qn has only $rank results.\n" if ($rank<1000);

                }
            }
        }


    } #end-foreach $qn


} #endsub mkRRF


sub rrgrp {
    my($OUT,$rhp,$r0hp,$qn,$rank,$score,$oldsc)=@_;

    my $rank2=1;
    my $offset=0;
    foreach my $docno(sort {$rhp->{$b}<=>$rhp->{$a}} keys %$rhp) {
        # offset: to ensure correct sorting/ranking for the whole result
        if ($rank2==1 && $rhp->{$docno}>$score) {
            $score -= $score*0.1;
            $offset= $score/$rhp->{$docno};
            print STDOUT "$docno: sc1=$rhp->{$docno}, sc2=$score, off=$offset\n" if ($debug);
        }
        if ($offset) { $score= sprintf("%.7f",$rhp->{$docno}*$offset); }
        else { $score= sprintf("%.7f",$rhp->{$docno}); }
        my ($grp,$rank0,$sc,$run)=split(/\s+/,$r0hp->{"$qn:$docno"});
        $rank++;
        # convert zero/negative score to non-zero value
        if ($score<=0) { $score= sprintf("%.7f",$oldsc-$oldsc*0.1); }
        printf $OUT "%-4s  Q0   %-32s  %7d   %11.6f   $run\n", $qn,$docno,$rank,$score;
        $rank2++;
        $oldsc=$score;
    }

    return($rank,$score,$oldsc);

} #endsub rrgrp


sub rrgrp2 {
    my($OUT,$rhp,$r0hp,$qn,$rank,$score,$oldsc,$lp)=@_;

    my $rank2=1;
    my $offset=0;
    foreach my $docno(@$lp) {
        # offset: to ensure correct sorting/ranking for the whole result
        if ($rank2==1 && $rhp->{$docno}>$score) {
            $score -= $score*0.1;
            $offset= $score/$rhp->{$docno};
            print STDOUT "$docno: sc1=$rhp->{$docno}, sc2=$score, off=$offset\n" if ($debug);
        }
        if ($offset) { $score= sprintf("%.7f",$rhp->{$docno}*$offset); }
        else { $score= sprintf("%.7f",$rhp->{$docno}); }
        my ($grp,$rank0,$sc,$run)=split(/\s+/,$r0hp->{"$qn:$docno"});
        $rank++;
        # convert zero/negative score to non-zero value
        if ($score<=0) { $score= sprintf("%.7f",$oldsc-$oldsc*0.1); }
        printf $OUT "%-4s  Q0   %-32s  %7d   %11.6f   $run\n", $qn,$docno,$rank,$score;
        $rank2++;
        $oldsc=$score;
    }

    return($rank,$score,$oldsc);

} #endsub rrgrp


sub readwts {
    my $inf=shift;

    open(IN,$inf) || die "can't read $inf";

    my %wts;
    while(<IN>) {
        /'(\w+?)'=>([\d\.\-]+)/;
        $wts{$1}=$2;
    }

    close IN;

    return (%wts);

}

