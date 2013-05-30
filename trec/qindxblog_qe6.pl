#!/usr/bin/perl -w

# -----------------------------------------------------------------
# Name:      qindxblog_qe6.pl
# Author:    Kiduk Yang, 04/23/2008
#              modified qindxblog_qe3.pl 
#              $Id: qindxblog_qe4.pl,v 1.1 2008/04/23 04:20:01 kiyang Exp $
# -----------------------------------------------------------------
# Description:  create expanded short (title) queries 
#   - combine wk, wk2 and gg (ts, ft, fx) expansion terms
# -----------------------------------------------------------------
# Arguments: arg1 = topic type (t=train, e=test)
# Input:     $idir/query/$subd/s0wk/qsx$qn  -- original short query
#            $idir/query/$subd/s0wk2/qsx$qn  -- wikipedia expansion terms
#            $idir/query/$subd/gg/qsxh$qn.30 
#              -- google expansion terms (title+snippet)
#            $idir/query/$subd/gg2/qsxh$qn.30
#              -- google expansion terms (fulltext)
#            $idir/query/$subd/gg3/qsxh$qn.30 
#              -- google expansion terms (fulltext w/ combined wk+gg_ts qry)
#            $tpdir/stoplist2   -- document stoplist
#            $tpdir/dict.arv    -- adjective, adverb, verb list
# Output:    $idir/query/$subd/s0fx/qsx$qn  
#              -- expanded queries 
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

my @webstop= qw(new www http picture photo new home search download shop link seller online help faq sitemap service-prvider york-time);

require "$wpdir/logsub2.pl";   # subroutine library
require "$tpdir/QEsub.pl";


#------------------------
# program arguments
#------------------------
my $prompt=
"arg1= topic type (e=test, t=train)\n";

my %valid_args= (
0 => " e t ",
);

my ($arg_err,$qtype)= chkargs($prompt,\%valid_args,1);
die "$arg_err\n" if ($arg_err);


my $qrydir;
if ($qtype eq 'e') {
    $qrydir="$qdir/test";
}
elsif ($qtype eq 't') {
    $qrydir="$qdir/train";
}

my $odir= "$qrydir/s0fx";

my @outdir=($odir);
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
              "Outfile = $odir/qsx\$qn.30\n\n";
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

    my $wkqf= "$qrydir/s0wk/qsxh$qn";
    my $wk2qf= "$qrydir/s0wk2/qsx$qn";
    my $ggqf= "$qrydir/s0gg/qsxh$qn.30";
    my $gg2qf= "$qrydir/s0gg2/qsxh$qn.30";
    my $gg3qf= "$qrydir/s0gg3/qsxh$qn.30";
    
    &comboQry5($wkqf,$wk2qf,$ggqf,$gg2qf,$gg3qf,\%qwds,\%stoplist);

    my $outf= "$odir/qsx$qn";
    open(OUT,">$outf") || die "can't write to $outf";
    print LOG "Q$qn = $oqstr\n";
    my $cnt=0;
    foreach my $wd(sort {$qwds{$b} cmp $qwds{$a}} keys %qwds) {
        my ($wt)=split/:/,$qwds{$wd};
        print LOG " $wd $qwds{$wd}\n" if ($cnt<30);;
        print OUT "$wd $wt\n";
        $cnt++;
    }
    print LOG "\n";


    $qcnt++;
	
} # endforeach $file(@files) 



#-------------------------------------------------
# end program
#-------------------------------------------------

print LOG "\nProcessed $qcnt queries\n\n";

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



