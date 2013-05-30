#!/usr/bin/perl -w

# -----------------------------------------------------------------
# Name:      qe-gg2.pl
# Author:    Kiduk Yang, 4/13/2008
#              $Id: qe-gg2.pl,v 1.5 2008/04/23 04:20:38 kiyang Exp $
# -----------------------------------------------------------------
# Description:  query expansion via Google
#   1. compute term weights from the title+snippet of google search results
#   2. list top N terms by term freq
# -----------------------------------------------------------------
# Arguments:
#   arg1 = topic type (e=test, t=training)
#   arg2 = number of document to use for QE
# Input:
#   $idir/query/$subd/q$qn  -- individual queries (processed)
#   $idir/query/$subd/gg/hits/ti$qn     -- hit titles
#   $idir/query/$subd/gg/hits/sn$qn     -- hit snippets
#   $npdir/krovetz.lst -- dictionary subset for combo/krovetz stemmer
#   $tpdir/pnounxlist2 -- proper noun list for stemming exclusion
#   $tpdir/pfxlist2    -- prefix list (updated list, 7/14/07)
#   $tpdir/abbrlist4   -- abbreviation & acronym list
#   $tpdir/stoplist2   -- document stoplist
#   $tpdir/dict.arv    -- adjective, adverb, verb list
# Output:
#   $idir/query/$subd/gg/qts$qn.arg2 - expanded query
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

my $subdict="$npdir/krovetz.lst";       # dictionary subset for stemmer
my $xlist="$tpdir/pnounxlist";          # proper nouns to exclude from stemming
my $abbrlist="$tpdir/abbrlist3";        # acronym & abbreviation list
my $pfxlist="$tpdir/pfxlist";           # valid prefix list
my $stopfile= "$tpdir/stoplist1";       # stopword list
my $arvlist=  "$tpdir/dict.arv";        # adjective, adverb, verb

my $maxtN=120;   # number of search terms to output

require "$wpdir/logsub2.pl";   # subroutine library
require "$tpdir/indxsub.pl";   # indexing subroutine library
require "$tpdir/NLPsub.pl";    # NLP subroutine library


#------------------------
# program arguments
#------------------------
my $prompt=
"arg1= topic type (e=test, t=train)\n".
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


#------------------------
# start program log
#------------------------

$sfx= $qtype.$maxdN;   # program log file suffix
$noargp=0;             # if 1, do not print arguments to log
$append=0;             # log append flag

if ($log) {
    @start_time= &begin_log($qdir,$filemode,$sfx,$noargp,$append);
    print LOG "Infile  = $outd/hits/ti\$qn, sn\$qn\n",
              "Outfile = $outd/qts\$qn.$maxdN\n\n";
}


#-------------------------------------------------
# create word hashes : key=word, val=1
#  - %stoplist: stopwords
#  - %xlist:    proper nouns that shouldn't be stemmed
#  - %sdict:    word list for Combo/Krovetz stemmer
#  - %abbrlist: word list for acronyms and abbreviations
#  - %pfxlist:  word list for valid prefixes
#  - %arvlist:  ARV (adjective, adverb, verb) terms
#-------------------------------------------------

# create hash of adjective, adverb, & verb
my %arvlist;
&mkhash($arvlist,\%arvlist);

# create the stopword hash
my %stoplist;
&mkhash($stopfile,\%stoplist);

# create proper noun hash
my %xlist;
&mkhash($xlist,\%xlist);
    
# create krovetz dictionary subset hash
my %sdict;
&mkhash($subdict,\%sdict);

# create acronym/abbreviation hash
my %abbrlist;
open(IN,$abbrlist) || die "can't read $abbrlist";
while(<IN>) {
    my ($word)=split/ /;
    $abbrlist{"\U$word"}=1;     
}
close IN;

# create prefix hash
my %pfxlist;
open(IN,$pfxlist) || die "can't read $pfxlist";
while(<IN>) {
    my ($word)=split/-/;
    $pfxlist{"\L$word"}=1;
}
close IN;


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

    my $inf="$qrydir/$file";
    open(IN,$inf) || die "can't read $inf";
    my @lines=<IN>;
    close IN;
    chomp @lines;

    my $bstr= join("",@lines);

    # original query
    my %qrywd; # query term hash
    my $qrystr=$1 if ($bstr=~m|<title><text>(.+?)</text>|s);
    $qrystr=~s/"//g;
    $qrystr=~s/ and|or / /ig;
    foreach my $wd(split/ +/,$qrystr) {
        $qrywd{lc($wd)}=1;
        my $wd2=&Simple($wd);
        $qrywd{$wd2}=1;
    }

    # compute term freq and output $maxtN terms to $outd/q$qn
    my $qestr= &getTerms($qn,$qrystr,$outd,\%qrywd,$maxdN,$maxtN,
                         \%stoplist,\%xlist,\%sdict,\%abbrlist,\%pfxlist,\%arvlist);

    print LOG "q$qn: $qrystr -> $qestr\n\n";

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

#-----------------------------------------------------
# 1. compute term freq from search result
# 2. output $maxtN terms to $outd/q$qn
#-----------------------------------------------------
#  arg1 = query number
#  arg2 = query string
#  arg3 = work directory
#  arg4 = ptr to query term hash
#  arg5 = number of docs to process
#  arg6 = number of terms to output
#  arg7 = input directory
#  r.v. = expanded query string
#-----------------------------------------------------
#  OUTPUT:
#    $arg2/q$arg3 - expanded query
#-----------------------------------------------------
sub getTerms {
    my ($qn,$qstr,$dir,$qwhp,$maxdN,$maxtN,$sthp,$xlhp,$sdhp,$abhp,$pfhp,$arhp)=@_;

    my (%wds,@terms)=();
    my $ind= "$dir/hits";
    my $outf= "$dir/qts$qn.$maxdN";

    my $titles= "$ind/ti$qn";
    open(TI,"$titles") || die "can't read $titles";
    my @tis=<TI>;
    close TI;

    my $snips= "$ind/sn$qn";
    open(SN,"$snips") || die "can't read $snips";
    my @sns=<SN>;
    close SN;

    my $dcnt=1;
    my @body;
    for(my $i=0; $i<@tis; $i++) {
        next if ($tis[$i]=~/unavailable|error/i);
        next if ($sns[$i]=~/^\s*$/i);
        push(@body,$tis[$i]);
        push(@body,$sns[$i]);
        last if ($dcnt>$maxdN);
        $dcnt++;
    }
    my $body= join(" ",@body);

    my ($nouns,$phrases)= &mkphrase2($body,$sthp,$xlhp,$sdhp,0,0);
    foreach my $ph(split/ +/,$phrases) {
        $ph="$2-$3" if ($ph=~/^(.+?)-(.+?)-(.+)$/);
        my($wd1,$wd2)=split/-/,lc($ph);
        next if ($qwhp->{$wd1} || $qwhp->{$wd2});
        $wds{$ph}++;
    }

    # convert special characters to blank space
    $body=~s/[\(\)\[\]]+/ /g;

    my @words= &getword3($body,$abhp,$pfhp,$sthp,$arhp);
    &countwd(\@words,\%wds,$sthp,$xlhp,$sdhp,1);

    # terms in descending term weight order
    open(OUT,">$outf") || die "can't write to $outf";
    print "Writing to $outf\n";
    my $tcnt=1;
    foreach my $term(sort {$wds{$b}<=>$wds{$a}} keys %wds) { 
        next if (exists($qwhp->{$term}));
        if ($tcnt<=$maxtN) {
            print OUT "$term $wds{$term}\n";
            push(@terms,$term);
        }
        $tcnt++;
    }

    return join(" ",@terms);

} #endsub getTerms


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



