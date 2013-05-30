#!/usr/bin/perl -w

# -----------------------------------------------------------------
# Name:      qe-wk3.pl
# Author:    Kiduk Yang, 4/14/2008
#              $Id: qe-wk2.pl,v 1.2 2008/04/18 02:28:19 kiyang Exp $
# -----------------------------------------------------------------
# Description:  query expansion via Wikipedia
#   1. extract heading and related terms from wikipedia
#   2. list top N terms by term type
#   NOTE: uses subroutines created by Athavale & Vaz
# -----------------------------------------------------------------
# Arguments:
#   arg1 = topic type (e=test, t=training)
# Input:
#   $idir/query/$subd/q$qn  -- individual queries (processed)
# Output:
#   $idir/query/$subd/wk/qht$qn - expanded query
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
my $tpdir=  "$wpdir/trec08";            # TREC program directory
my $npdir=  "$wpdir/nstem";             # stemmer directory
my $pdir=   "$tpdir/blog";              # track program directory
my $idir=   "/u3/trec/blog08";          # TREC index directory
my $qdir=   "$idir/query";              # query directory

require "$wpdir/logsub2.pl";   # subroutine library
require "$tpdir/wikisub.pl";   # wikipedia subroutine library


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

my $outd="$qrydir/wk";   # for expansion terms


#------------------------
# start program log
#------------------------

$sfx= $qtype;          # program log file suffix
$noargp=1;             # if 1, do not print arguments to log
$append=0;             # log append flag

if ($log) {
    @start_time= &begin_log($qdir,$filemode,$sfx,$noargp,$append);
    print LOG "Infile  = $qrydir/q\$qn\n",
              "Outfile = $outd/qht\$N\n\n";
}


#-------------------------------------------------
# get query string from TREC topic titles
#-------------------------------------------------

opendir(IND,$qrydir) || die "can't opendir $qrydir";
my @files= readdir(IND);
closedir IND;

my $qcnt=0;
foreach my $file(@files) {

    next if ($file!~/^q(\d+)/);
    my $qn=$1;

        #next if ($qn != 944);

    my $inf="$qrydir/$file";
    open(IN,$inf) || die "can't read $inf";
    my @lines=<IN>;
    close IN;
    chomp @lines;

    my $bstr= join("",@lines);

    # original query
    my $qrystr=$1 if ($bstr=~m|<title><text>(.+?)</text>|s);

    my (@qeterm,%qeTerms);
    &wikiQE($qrystr,\%qeTerms);

    my $outf="$outd/qht$qn";
    open(OUT,">$outf") || die "can't write to $outf";

    foreach my $wd(sort {$qeTerms{$b}<=>$qeTerms{$a}} keys %qeTerms) {
        next if ($wd=~/\d/);
        my $wt=$qeTerms{$wd};
        next if ($wd=~s/[ _]+/-/g>3);
        print OUT "$wd $wt\n";
        push(@qeterm,$wd);
    }

    print LOG "q$qn: $qrystr -> ", join(", ",@qeterm), "\n\n";

    $qcnt++;

}

#-------------------------------------------------
# end program
#-------------------------------------------------

print LOG "\nProcessed $qcnt queries\n\n";

&end_log($pdir,$qdir,$filemode,@start_time) if ($log);


##############################################
# SUBROUTINES 
##############################################
        
BEGIN { print STDOUT "\n"; }
END { print STDOUT "\n"; }

