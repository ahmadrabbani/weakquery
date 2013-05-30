#!/usr/bin/perl -w

# -----------------------------------------------------------------
# Name:      qindxblog_qe3x.pl
# Author:    Kiduk Yang, 04/17/2008
#              modified qindxblog_qe1.pl 
#              $Id: qindxblog_qe3x.pl,v 1.1 2008/04/23 04:19:55 kiyang Exp $
# -----------------------------------------------------------------
# Description:  create input queries for the retrieval module
#   - combine wk and gg (ts, ft, fx) expansion terms
# -----------------------------------------------------------------
# Arguments: arg1 = topic type (t=train, e=test)
# Input:     $idir/query/$subd/s0/qsn$qn  -- original short query
#            $idir/query/$subd/wk/qft$qn  -- wikipedia expansion terms
#            $idir/query/$subd/gg/qts$qn.30 
#              -- google expansion terms (title+snippet)
#            $idir/query/$subd/gg/qft$qn.30
#              -- google expansion terms (fulltext)
#            $idir/query/$subd/gg/qfx$qn.30 
#              -- google expansion terms (fulltext w/ combined wk+gg_ts qry)
#            $tpdir/stoplist2   -- document stoplist
#            $tpdir/dict.arv    -- adjective, adverb, verb list
# Output:    $idir/query/$subd/wgx/qsx$qn.30  
#            $idir/query/$subd/wgx/qsx(c|d|e|f|g|h)$qn.30
#              -- expanded queries 
#              --(c|d|e|f|g|h)=top(10|20|30|40|50|60) terms
#            $idir/query/$prog       -- program     (optional)
#            $idir/query/$prog.log   -- program log (optional)
#            where $subd  = train|test
# ------------------------------------------------------------------------
# NOTE:  
#   1. query expansion is done with simple stemmer and short queries
#   2. same as qindxblog_qe3.pl except for following:
#      - add phrase component words with 1/2 weights
#      - exclude adjective, adverb, verb
#      - exclude web stopwords (e.g., google, www, back, seach, url, http, picture, photo, new, etc.)
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

my $stopfile=  "$tpdir/stoplist2";       # document stopword list
my $arvlist=   "$tpdir/dict.arv";        # adjective, adverb, verb

# number of terms to output
my %tns=(
110=>'m',
);

my @dns=(10,30);

my @webstop= qw(www http picture photo new google yahoo home search download shop link seller online help faq sitemap);

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

my $wgdir= "$qrydir/s0wgx";

my @outdir=($wgdir);
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
              "Outfile = $wgdir/qsx(c|d|e|f|g|h)\$qn.30\n",
              "            qsx(c|d|e|f|g|h)=top(10|20|30|40|50|60) terms\n\n";
}


#-------------------------------------------------
# create word list hashes
#  - %stoplist: stopwords
#  - %arvlist:  ARV (adjective, adverb, verb) terms
#-------------------------------------------------

# document stopwords
my %stoplist;
&mkhash($stopfile,\%stoplist);

# add adjective, adverb, & verb to %stoplist
&mkhash($arvlist,\%stoplist);

# add web stopwords
foreach my $wd(@webstop) {
    $stoplist{$wd}=1;
}


#-------------------------------------------------
# create queries;
#   - original short query terms (wt=10)
#   - top (10|20|30|40|50|60) expansion terms (wt= 2/rank)
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

    my $wkqf= "$qrydir/wk/qft$qn";
    my $ggqf= "$qrydir/gg/qts$qn.30";
    my $gg2qf= "$qrydir/gg/qft$qn.30";
    my $gg3qf= "$qrydir/gg/qfx$qn.30";
    
    &comboQry3($oqstr,$wkqf,$ggqf,$gg2qf,$gg3qf,\%qwds,\%stoplist);

    foreach my $tn(keys %tns) {
        next if ($minqxTN && $tn<$minqxTN);
        foreach my $dn(@dns) {
            next if ($minqxDN && $dn<$minqxDN);
            my $outf= "$wgdir/qsx$tns{$tn}$qn.$dn";
            open(OUT,">$outf") || die "can't write to $outf";
            my $rank=1;
            foreach my $wd(sort {$qwds{$b}<=>$qwds{$a}} keys %qwds) {
                next if ($wd=~/^\d+$/);  # exclude all numbers
                last if ($rank>$tn);
                printf OUT "$wd %.4f\n",$qwds{$wd};
                $rank++;
            }
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
#  create hash from file
#-----------------------------------------------------------
#  arg1 = infile
#  arg2 = pointer to hash to create
#-----------------------------------------------------------
sub mkhash {
    my($file,$hp)=@_;

    open(IN,$file) || die "can't read $file";
    my @terms=<IN>;
    close IN;
    chomp @terms;
    foreach my $word(@terms) { $$hp{$word}++; }

} #endsub mkhash



