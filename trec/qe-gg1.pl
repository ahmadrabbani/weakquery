#!/usr/bin/perl -w

# -----------------------------------------------------------------
# Name:      qe-gg1.pl
# Author:    Kiduk Yang, 4/13/2008
#              based on /u2/home/glakshmi/google.pl by Lakshminarayanan
#              $Id: qe-gg1.pl,v 1.3 2008/04/17 21:37:53 kiyang Exp $
# -----------------------------------------------------------------
# Description:  query expansion via Google
#   1. query google to extract title, snippets, & URLs of search results
#   2. fetch the search result content
# -----------------------------------------------------------------
# Arguments:
#   arg1 = topic type (e=test, t=training, t0=old training)
# Input:
#   $idir/query/$subd/q$qn  -- individual queries (processed)
# Output:
#   $idir/query/$subd/gg/hits/rs$qn.htm  -- result page
#   $idir/query/$subd/gg/hits/lk$qn     -- hit URLs
#   $idir/query/$subd/gg/hits/ti$qn     -- hit titles
#   $idir/query/$subd/gg/hits/sn$qn     -- hit snippets
#   $idir/query/$subd/gg/hits/$qn/r$n.htm -- hit HTML
#   $idir/query/$subd/gg/hits/$qn/r$n.txt -- hit text
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

my $maxhtmN= 100; # number of HTML results to fetch

require "$wpdir/logsub2.pl";      # subroutine library
require "$tpdir/spidersub.pl";    # spider subroutine library


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

my $outd="$qrydir/gg/hits";   # for search results

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
    print LOG "Infile  = $qrydir/q\$qn\n",
              "Outfile = $outd/rs\$qn.htm, ti\$qn, sn\$qn, lk\$qn\n",
              "          $outd/q\$qn/r\$N.htm, r\$N.txt\n\n";
}


#-------------------------------------------------
# 1. get query string from TREC topic titles
# 2. query google and save search result data
# 3. fetch webpages in the search result
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
    my $qrystr=$1 if ($bstr=~m|<title><text>(.+?)</text>|s);

    # query google & save search data
    my $htmcnt= &queryGoogle2($qrystr,$outd,$qn,$maxhtmN);

    # read in result links
    open(LINK,"$outd/lk$qn") || die "can't read $outd/lk$qn";
    my @links=<LINK>;
    close LINK;
    chomp @links;

    my $outd2= "$outd/q$qn";
    if (!-e $outd2) {
        my @errs=&makedir($outd2,$dirmode,$group);
        print "\n",@errs,"\n\n" if (@errs);
    }

    # fetch hit pages
    my $fn=1;
    foreach my $link(@links) {

        last if ($fn>$maxhtmN);

        my($n,$url)=split/: /,$link;

        my ($htm,$title,$body)= &fetchHTML($url,$fn); 

        my $outf= "$outd2/r$fn.htm";
        open (OUT, ">$outf") || die "can't write to $outf";
        print OUT $htm if ($htm);
        close(OUT);

        my $outf2= "$outd2/r$fn.txt";
        open (OUT2, ">$outf2") || die "can't write to $outf2";
        binmode(OUT2,":utf8");
        print OUT2 "$title\n\n" if ($title);
        print OUT2 "$body\n" if ($body);
        close(OUT2);
        $fn++;

    }

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


