#!/usr/bin/perl -w

# -----------------------------------------------------------------
# Name:      qe-gg4.pl
# Author:    Kiduk Yang, 4/15/2008
#              $Id: qe-gg4.pl,v 1.2 2008/04/23 04:20:45 kiyang Exp $
# -----------------------------------------------------------------
# Description:  query expansion via Google
#   1. compute term weights from the fulltext of google search results
#   2. list top N terms by term freq
# -----------------------------------------------------------------
# Arguments:
#   arg1 = topic type (e=test, t=training, t0=old training)
#   arg2 = number of document to use for QE
# Input:
#   $idir/query/$subd/q$qn  -- individual queries (processed)
#   $idir/query/$subd/gg/hits/q$qn/r$N.txt  -- hit fulltext
#   $idir/query/$subd/gg/qts$qn - goolge_snippet expanded query
#   $idir/query/$subd/wk/qft$qn - wikipedia expanded query
#   $npdir/krovetz.lst -- dictionary subset for combo/krovetz stemmer
#   $tpdir/pnounxlist2 -- proper noun list for stemming exclusion
#   $tpdir/pfxlist2    -- prefix list (updated list, 7/14/07)
#   $tpdir/abbrlist4   -- abbreviation & acronym list
#   $tpdir/stoplist2   -- document stoplist
#   $tpdir/dict.arv    -- adjective, adverb, verb list
# Output:
#   $idir/query/$subd/gg/qfx$qn.$arg2 - expanded query
#   $idir/query/$subd/gg/hits/q$qn/seqx$arg2/r$N - seq. index file
#   $idir/query/$prog       -- program     (optional)
#   $idir/query/$prog.log   -- program log (optional)
#     where $subd= train|test
# -----------------------------------------------------------------
# Note: uses extended-LCA expanison using wiki- & google_snippet expanded
#       terms for proximity anchor
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

my $subdict="$npdir/krovetz.lst";       # dictionary subset for stemmer
my $xlist="$tpdir/pnounxlist";          # proper nouns to exclude from stemming
my $abbrlist="$tpdir/abbrlist3";        # acronym & abbreviation list
my $pfxlist="$tpdir/pfxlist";           # valid prefix list
my $stopfile= "$tpdir/stoplist1";       # stopword list
my $arvlist=  "$tpdir/dict.arv";        # adjective, adverb, verb

my $maxtN=120; # number of terms to output

require "$wpdir/logsub2.pl";   # subroutine library
require "$tpdir/indxsub.pl";   # indexing subroutine library
require "$tpdir/NLPsub.pl";    # NLP subroutine library
require "$tpdir/QEsub.pl";     # QE subroutine library


#------------------------
# program arguments
#------------------------
my $prompt=
"arg1= topic type (e=test, t=train, t0=train old)\n".
"arg2= number of documents to process\n";

my %valid_args= (
0 => " e t ",
);

my ($arg_err,$qtype,$maxdN)= chkargs($prompt,\%valid_args,2);
die "$arg_err\n" if ($arg_err);

my $qrydir;
if ($qtype eq 'e') {
    $qrydir="$qdir/test";
}
elsif ($qtype eq 't') {
    $qrydir="$qdir/train";
}

my $outd="$qrydir/gg";   # for expansion terms
my $hitd="$outd/hits";   # for search results


#------------------------
# start program log
#------------------------

$sfx= $qtype.$maxdN;   # program log file suffix
$noargp=1;             # if 1, do not print arguments to log
$append=0;             # log append flag

if ($log) {
    @start_time= &begin_log($qdir,$filemode,$sfx,$noargp,$append);
    print LOG "Infile  = $hitd/q\$qn/r\$N.txt\n",
              "Outfile = $hitd/q\$qn/seqx$maxdN/r\$N\n",
              "          $outd/qfx\$qn.$maxdN\n\n";
}


#-------------------------------------------------
# create stopword hashe : key=word, val=1
#-------------------------------------------------
# create the stopword hash
my %stoplist;
&mkhash($stopfile,\%stoplist);



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

        #next if ($qn != 1004);
        #last if ($qn > 1005);

    my $inf="$qrydir/$file";
    open(IN,$inf) || die "can't read $inf";
    my @lines=<IN>;
    close IN;
    chomp @lines;

    my $bstr= join("",@lines);

    # query term hash
    my %qrywd;

    # original query
    my $oqstr=$1 if ($bstr=~m|<title><text>(.+?)</text>|s);

    my $ggqf= "$qrydir/gg/qts$qn.30";
    my $wkqf= "$qrydir/wk/qft$qn";

    &comboQry1($oqstr,$wkqf,$ggqf,\%qrywd);

    my @qterms;
    foreach my $term(sort {$qrywd{$b}<=>$qrywd{$a}} keys %qrywd) { 
        push(@qterms,"$term:$qrywd{$term}");
    }


    # compute term freq and output $maxtN terms to $outd/q$qn
    my %LCA;
    &LCA("$outd/hits/q$qn",\%qrywd,$maxdN,\%LCA,\%stoplist,300,'seqx');

    # terms in descending term weigh order
    my $outf= "$outd/qfx$qn.$maxdN";
    open(OUT,">$outf") || die "can't write to $outf";
    my ($tcnt,@qxterms)=(1);
    foreach my $term(sort {$LCA{$b}<=>$LCA{$a}} keys %LCA) { 
        #next if (exists($qrywd{$term}) || exists($qrywd{$term.'s'}));
        #next if ($qrystr=~/$term/i);
        printf OUT "$term %.8f\n",$LCA{$term} if ($tcnt<=$maxtN);
        if ($tcnt<=10) {
            my $wt= sprintf("%.0f",$LCA{$term});
            push(@qxterms,"$term:$wt"); 
        }
        $tcnt++;
    }

    print LOG "q$qn: @qterms ->\n@qxterms\n\n";

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
    foreach my $word(@terms) { $$hp{$word}=1; }

} #endsub mkhash

