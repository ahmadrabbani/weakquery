#!/usr/bin/perl -w

# -----------------------------------------------------------------
# Name:      qindxblog_qe2.pl
# Author:    Kiduk Yang, 04/17/2008
#              modified qindxblog_qe1.pl 
#              $Id: qindxblog_qe2.pl,v 1.1 2008/04/23 04:19:46 kiyang Exp $
# -----------------------------------------------------------------
# Description:  create input queries for the retrieval module
#   - process gg4 (fx: LCA w/ combo qry) terms to create retrieval queries
# -----------------------------------------------------------------
# Arguments: arg1 = topic type (t=train, e=test)
# Input:     $idir/query/$subd/s0/qsn$qn  -- original short query
#            $idir/query/$subd/wk/qft$qn  -- wikipedia expansion terms
#            $idir/query/$subd/gg/qts$qn.30 
#              -- google expansion terms (title+snippet)
#            $idir/query/$subd/gg/qfx$qn.30 
#              -- google expansion terms (fulltext w/ combined wk+gg_ts qry)
# Output:    $idir/query/$subd/s0gg3/qsx$qn.30  
#            $idir/query/$subd/s0gg3/qsx(a|b|c|d|e|f|g|h)$qn.30
#              -- expanded queries 
#              --(a|b|c|d|e|f|g|h)=top(3|5|10|20|30|40|50|60) terms
#            $idir/query/$prog       -- program     (optional)
#            $idir/query/$prog.log   -- program log (optional)
#            where $subd  = train|test
#                  $qsubd = e.g. s0, s1, s2 (stemmer type)
# ------------------------------------------------------------------------
# NOTE:  
#   1. query expansion is done with simple stemmer and short queries
#   2. recreated input qry to qe-gg4.pl (wk+gg_ts) and add to output qry
#   3. test runs show best performance by 30 docs and 30 terms (40+terms not tested yet)
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
my %tns=(
110=>'m',
);

# number of documents used in QE
my @dns=(10,30);
#my @dns=(3,5,10,20,30,40,50,60);


require "$wpdir/logsub2.pl";   # subroutine library
require "$tpdir/QEsub.pl";


#------------------------
# program arguments
#------------------------
my $prompt=
"arg1= topic type (e=test, t=train)\n".
"arg2= min. feedback docN (optional: e.g., 30)\n".
"arg3= min. expansion termN (optional: e.g., 30)\n";

my %valid_args= (
0 => " e t ",
);

my ($arg_err,$qtype,$minqxDN,$minqxTN)= chkargs($prompt,\%valid_args,1);
die "$arg_err\n" if ($arg_err);


my $qrydir;
if ($qtype eq 'e') {
    $qrydir="$qdir/test";
}
elsif ($qtype eq 't') {
    $qrydir="$qdir/train";
}

my $gg3dir= "$qrydir/s0gg3";

my @outdir=($gg3dir);
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
$noargp=1;             # if 1, do not print arguments to log
$append=0;             # log append flag

if ($log) {
    @start_time= &begin_log($qdir,$filemode,$sfx,$noargp,$append);
    print LOG "Infile  = $qrydir/s0/qs(n)\$qn\n",
              "          $qrydir/gg|wk/q(ft|ts)\$qn.30\n",
              "Outfile = $gg3dir/qsx(a|b|c|d|e|f|g|h)\$qn.30\n",
              "            qsx(a|b|c|d|e|f|g|h)=top(3|5|10|20|30|40|50|60) terms\n\n";
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

    my $inf="$qrydir/$file";
    open(IN,$inf) || die "can't read $inf";
    my @lines=<IN>;
    close IN;
    chomp @lines;

    my $bstr= join("",@lines);

    # query term hash
    my %qwds;

    # original query
    my $oqstr=$1 if ($bstr=~m|<title><text>(.+?)</text>|s);

    my $ggqf= "$qrydir/gg/qts$qn.30";
    my $wkqf= "$qrydir/wk/qft$qn";

    &comboQry1($oqstr,$wkqf,$ggqf,\%qwds);

    # $gg3f: google-expanded query using fulltext & combo query
    my $gg3f= "$qrydir/gg/qfx$qn";

    foreach my $tn(keys %tns) {
        next if ($minqxTN && $tn<$minqxTN);
        foreach my $dn(@dns) {
            next if ($minqxDN && $dn<$minqxDN);
            my $outf= "$gg3dir/qsx$tns{$tn}$qn.$dn";
            &addTerms("$gg3f.$dn",$outf,$tn,\%qwds);
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


