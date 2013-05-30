#!/usr/bin/perl -w

# -----------------------------------------------------------------
# Name:      qindxblog_qe1.pl
# Author:    Kiduk Yang, 04/17/2008
#              modified qindxblog2.pl (6/2007)
#              $Id: qindxblog_qe1.pl,v 1.1 2008/04/23 04:19:42 kiyang Exp $
# -----------------------------------------------------------------
# Description:  create input queries for the retrieval module
#   - process wk and gg (ts & ft) terms to create retrieval queries
# -----------------------------------------------------------------
# Arguments: arg1 = topic type (t=train, e=test)
#            arg2 = expansion directory (optional: wk, gg)
#            arg3 = min. feedback docN (optional: e.g. 30)
#            arg4 = min. expansion termN (optional: e.g. 30)
# Input:     $idir/query/$subd/s0/qsn$qn  -- original short query
#            $idir/query/$subd/wk/qft$qn  -- wikipedia expansion terms
#            $idir/query/$subd/wk|gg/q(ts|ft)$qn.(3|5|10|20|30) 
#              -- google expansion terms
#              -- ts=title+snippet, ft=fulltext 
#              -- (3|5|10|20|30): top N docs used by QE
# Output:    $idir/query/$subd/s0wk/qsx$qn  
#            $idir/query/$subd/s0(gg|gg2)/qsx(a|b|c|d|e|f|g|h)$qn.(3|5|10|20|30)
#              -- expanded queries 
#              -- gg=ts, gg2=ft, (a|b|c|d|e|f|g|h)=top(3|5|10|20|30|40|50|60) terms
#            $idir/query/$prog       -- program     (optional)
#            $idir/query/$prog.log   -- program log (optional)
#            where $subd  = train|test
# ------------------------------------------------------------------------
# NOTE:  
#   1. query expansion is done with simple stemmer and short queries
#   2. processes wikipedia and google expanded queries  
#   3. after QE optimization (select best N doc and M terms), 
#        run qe-gg4.pl and qindxblog_qe2.pl
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
my $pdir=   "$tpdir/blog";              # BLOG track program directory
my $idir=   "/u3/trec/blog08";          # TREC index directory
my $qdir=   "$idir/query";              # query directory

# number of terms to output
my %tns0=(
3=>'a',
5=>'b',
10=>'c',
20=>'d',
30=>'e',
40=>'f',
50=>'g',
60=>'h',
70=>'i',
80=>'j',
90=>'k',
100=>'l',
110=>'m',
120=>'n',
);
my %tns=(
110=>'m',
);

# number of documents used in QE
my @dns=(10,30);
#my @dns=(3,5,10,20,30,40,50,60);

require "$wpdir/logsub2.pl";   # subroutine library


#------------------------
# program arguments
#------------------------
my $prompt=
"arg1= topic type (e=test, t=train)\n".
"arg2= expansion directory (optional: wk, gg)\n".
"arg3= min. feedback docN (optional: e.g., 30)\n".
"arg4= min. expansion termN (optional: e.g., 30)\n";

my %valid_args= (
0 => " e t ",
);

my ($arg_err,$qtype,$qxsubd,$minqxDN,$minqxTN)= chkargs($prompt,\%valid_args,1);
die "$arg_err\n" if ($arg_err);


my $qrydir;
if ($qtype eq 'e') {
    $qrydir="$qdir/test";
}
elsif ($qtype eq 't') {
    $qrydir="$qdir/train";
}

my $ggdir= "$qrydir/s0gg";
my $gg2dir= "$qrydir/s0gg2";
my $wkdir= "$qrydir/s0wk";

my @outdir=($ggdir,$gg2dir,$wkdir);
foreach my $outdir(@outdir) {
    if (!-e $outdir) {
        my @errs=&makedir($outdir,$dirmode,$group);
        print "\n",@errs,"\n\n" if (@errs);
    }
}


#------------------------
# start program log
#------------------------

$sfx= $qtype;          # program log file suffix
$sfx .= $qxsubd if ($qxsubd);
$sfx .= "d$minqxDN" if ($minqxDN);
$sfx .= "t$minqxTN" if ($minqxTN);

$noargp=1;             # if 1, do not print arguments to log
$append=0;             # log append flag

if ($log) {
    @start_time= &begin_log($qdir,$filemode,$sfx,$noargp,$append);
    print LOG "Infile  = $qrydir/s0/qs(n)\$qn\n",
              "          $qrydir/gg|wk/q(ft|ts)\$qn.(3|5|10|20|30)\n",
              "Outfile = $qrydir/s0(wk|gg|gg2)/qsx(a|b|c|d|e|f|g|h)\$qn.(3|5|10|20|30)\n",
              "            gg=ts, gg2=fs, qsx(a|b|c|d|e|f|g|h)=top(3|5|10|20|30|40|50|60) terms\n\n";
}


#-------------------------------------------------
# create queries;
#   - original short query terms (wt=10)
#   - top (3|5|10|20|30|40|50|60) expansion terms (wt= 2/rank)
#-------------------------------------------------

opendir(IND,$qrydir) || die "can't opendir $qrydir";
my @files= readdir(IND);
closedir IND;

my $qcnt=0;
my $qcnt2=0;
foreach my $file(@files) {

    next if ($file!~/^q(\d+)/);
    my $qn=$1;

        #next if ($qn != 907);

    # original short query
    my %qwds;
    my $oqf=  "$qrydir/s0/qsn$qn";
    $oqf= "$qrydir/s0/qs$qn" if (!-e $oqf);
    foreach my $wd(split/\s+/,`cat $oqf`) {
        $qwds{$wd}=10;
    }

    # $ggf:  google-expanded query using title & snippets
    # $gg2f: google-expanded query using fulltext & orig query
    # $wkf:  wikipedia-expanded query 
    my $ggf=  "$qrydir/gg/qts$qn";
    my $gg2f= "$qrydir/gg/qft$qn";
    my $wkf=  "$qrydir/wk/qft$qn";

    foreach my $tn(keys %tns) {
        last if ($qxsubd && $qxsubd!~/^wk/);
        my $outf= "$wkdir/qsx$tns{$tn}$qn";
        &addTerms($wkf,$outf,$tn,\%qwds);
        $qcnt2++;
    }

    foreach my $tn(keys %tns) {
        last if ($qxsubd && $qxsubd!~/^gg/);
        next if ($minqxTN && $tn<$minqxTN);
        foreach my $dn(@dns) {
            next if ($minqxDN && $dn<$minqxDN);
            my $outf= "$ggdir/qsx$tns{$tn}$qn.$dn";
            my $outf2= "$gg2dir/qsx$tns{$tn}$qn.$dn";
            &addTerms("$ggf.$dn",$outf,$tn,\%qwds);
            &addTerms("$gg2f.$dn",$outf2,$tn,\%qwds);
            $qcnt2++;
        }
    }

    $qcnt++;
	
} # endforeach $file(@files) 



#-------------------------------------------------
# end program
#-------------------------------------------------

print LOG "\nProcessed $qcnt queries: created $qcnt2 expanded queris\n\n";

&end_log($pdir,$qdir,$filemode,@start_time) if ($log);

# notify author of program completion
#&notify($sfx,$author);


#####################################
# SUBROUTINES
#####################################

BEGIN { print STDOUT "\n"; }
END { print STDOUT "\n"; }


#-----------------------------------------------------------
#  create term hash from file
#-----------------------------------------------------------
#  arg1 = infile
#  arg2 = outfile
#  arg3 = number of terms to extract from file
#  arg3 = pointer to original query term hash
#-----------------------------------------------------------
sub addTerms {
    my($inf,$outf,$maxtN,$ohp)=@_;

    open(OUT,">$outf") || die "can't write to $outf";
    foreach my $wd(keys %$ohp) {
        printf OUT "$wd %.4f\n",$ohp->{$wd};
    }

    if (!-e $inf) {
        print LOG "!!$inf does not exist\n";
        return;
    }

    open(IN,$inf) || die "can't read $inf";
    my $rank=1;
    while(<IN>) {
        last if ($rank>$maxtN);
        my($wd)=split/ /;
        next if ($wd=~/^\d+$/);  # exclude all numbers
        my $wt=2/$rank;
        printf OUT "$wd %.4f\n",$wt;
        $rank++;
    }

    close OUT;

} #endsub addTerms


