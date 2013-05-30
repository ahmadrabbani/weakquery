#!/usr/bin/perl -w

# -----------------------------------------------------------------
# Name:      qindxblog_qe5.pl
# Author:    Kiduk Yang, 04/23/2008
#              modified qindxblog_qe3.pl 
#              $Id: qindxblog_qe4.pl,v 1.1 2008/04/23 04:20:01 kiyang Exp $
# -----------------------------------------------------------------
# Description:  create expanded short (title) queries for the raranking module
#   - use wk2 (heading & thesaurus) expansion terms
# -----------------------------------------------------------------
# Arguments: arg1 = topic type (t=train, e=test)
# Input:     $idir/query/$subd/wk/qht$qn  -- wikipedia expansion terms
#            $tpdir/stoplist2   -- document stoplist
# Output:    $idir/query/$subd/wk2/qsx$qn
#              -- expanded queries 
#            $idir/query/$prog       -- program     (optional)
#            $idir/query/$prog.log   -- program log (optional)
#            where $subd  = train|test
# ------------------------------------------------------------------------
# NOTE:  
#   1. query expansion is done with simple stemmer and short queries
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

my $indir= "$qrydir/wk";
my $odir= "$qrydir/s0wk2";

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
    print LOG "Infile  = $indir/qht\$qn\n",
              "Outfile = $odir/qsx\$qn\n\n";
}


#-------------------------------------------------
# create word list hashes
#  - %stoplist: stopwords
#  - %arvlist:  ARV (adjective, adverb, verb) terms
#-------------------------------------------------

# document stopwords
my %stoplist;
&mkhash($stopfile,\%stoplist);



#-------------------------------------------------
# create queries;
#-------------------------------------------------

opendir(IND,$indir) || die "can't opendir $indir";
my @files= readdir(IND);
closedir IND;

my $qcnt=0;
my $qcnt2=0;
foreach my $file(@files) {

    next if ($file!~/^qht(\d+)/);
    my $qn=$1;

        #next if ($qn != 907);

    my $inf="$qrydir/q$qn";
    open(IN,$inf) || die "can't read $inf";
    my @lines=<IN>;
    close IN; 
    chomp @lines;

    # original query
    my $bstr= join("",@lines);
    my $oqstr=$1 if ($bstr=~m|<title><text>(.+?)</text>|s);

    # query term hash
    my %qwds;

    my $inf2="$indir/$file";
    open(IN,$inf2) || die "can't read $inf2";
    while(<IN>) {
        chomp;
        my($wd,$wt)=split/ +/;
        $wd=~tr/A-Z/a-z/;
        $wd=~s/[(),]//g;
        $wd=~s/<.+?>//g;  # temporary fix: remove after rerunning qe-wk3.pl
        next if ($qwds{$wd});
        $qwds{$wd}=$wt;
        if ($wd=~/-/) {
            foreach my $wd2(split/-/,$wd) {
                next if ($stoplist{$wd2});
                next if (length($wd2)<3 || $wt<0.4);
                $qwds{$wd2}= sprintf("%.4f",$wt/2);
            }
        }
    }
    close IN;

    my $outf= "$odir/qsx$qn";
    open(OUT,">$outf") || die "can't write to $outf";
    print LOG "q$qn: $oqstr\n";

    my @wds;
    foreach my $wd(sort {$qwds{$b} <=> $qwds{$a}} keys %qwds) {
        print LOG "  $wd $qwds{$wd}\n";
        print OUT "$wd $qwds{$wd}\n";
    }
    close OUT;
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



