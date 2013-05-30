#!/usr/bin/perl -w

# -----------------------------------------------------------------
# Name:      qe-wkn.pl
# Author:    Kiduk Yang, 4/17/2008
#              $Id: qe-wk1.pl,v 1.1 2008/04/17 21:38:32 kiyang Exp $
# -----------------------------------------------------------------
# Description:  query expansion via Wordnet
#   1. get synonyms, hypernyms, and hypernyms from wordnet
# -----------------------------------------------------------------
# Arguments:
#   arg1 = topic type (e=test, t=training)
# Input:
#   $idir/query/$subd/q$qn  -- individual queries (processed)
# Output:
#   $idir/query/$subd/wn/hits/rs$qn -- result page
#   $idir/query/$subd/wn/hits/tx$qn -- page content
#   $idir/query/$prog       -- program     (optional)
#   $idir/query/$prog.log   -- program log (optional)
#     where $subd= train|test
# -----------------------------------------------------------------


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
my $tpdir=  "$wpdir/trec07";            # TREC program directory
my $npdir=  "$wpdir/nstem";             # stemmer directory
my $pdir=   "$tpdir/blog";              # track program directory
my $idir=   "/u3/trec/blog07";          # TREC index directory
my $qdir=   "$idir/query";              # query directory

require "$wpdir/logsub2.pl";     # subroutine library
require "$tpdir/spidersub.pl";   # spider subroutine library


#------------------------
# program arguments
#------------------------
my $prompt=
"arg1= topic type (e=test, t=train, t0=train old)\n";

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

my $outd="$qrydir/wk/hits";  # for search results

my @outdir=("$outd");
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
    print LOG "Infile = $qrydir/q\$qn\n",
              "Outfile = $outd/rs\$qn.htm, tx\$qn\n\n";
}


#-------------------------------------------------
# 1. get query string from TREC topic titles
# 2. query wikipedia and save search result data
#-------------------------------------------------

opendir(IND,$qrydir) || die "can't opendir $qrydir";
my @files= readdir(IND);
closedir IND;

my $qcnt=0;
my %rtype;  # result type

foreach my $file(@files) {

    next if ($file!~/^q(\d+)/);
    my $qn=$1;

    my $inf="$qrydir/$file";
    open(IN,$inf) || die "can't read $inf";
    my @lines=<IN>;
    close IN;
    chomp @lines;

    my $bstr= join("",@lines);
    my $qrystr=$1 if ($bstr=~m|<title><text>(.+?)</text>|s);
    $qrystr=~s/^(.+?) or .+$/$1/i;

    # query Wikipedia & save search data
    my $status= &queryWikipedia($qrystr,$outd,$qn);

    $rtype{$status}++;

    $qcnt++;

}


#-------------------------------------------------
# end program
#-------------------------------------------------

print LOG "\nProcessed $qcnt queries\n\n";

print LOG "Search Result Types:\n";
foreach my $type(sort keys %rtype) {
    print LOG "  $type = $rtype{$type}\n";
}

&end_log($pdir,$qdir,$filemode,@start_time) if ($log);


##############################################
# SUBROUTINES 
##############################################
        
BEGIN { print STDOUT "\n"; }
END { print STDOUT "\n"; }

