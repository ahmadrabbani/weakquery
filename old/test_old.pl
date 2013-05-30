#!/usr/bin/perl -w

# --------------------
# segment and disambiguate queries
# 1. search query against Gooogle,save top n html pages
# 2. chunk query into pairs of bisecting n-grams, calculate the joint probability of each 
#	bisecting n-gram pair
# 3. calculate the association of top-ranked bisecting n-grams(e.g., chi-square) to decide whether
#	the entire query should be considered as a whole 
# --------------------
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
# --------------------
# ver0.1	10/31/2010
# ver1.0	11/21/2010       
# --------------------

use strict;
use warnings;

my ($debug,$filemode,$filemode2,$dirmode,$dirmode2,$author,$group);
my ($log,$logd,$sfx,$noargp,$append,@start_time);

$log=1;                              # program log flag
$debug=0;                            # debug flag
$filemode= 0640;                     # to use w/ perl chmod
$filemode2= 640;                     # to use w/ system chmod
$dirmode= 0750;                      # to use w/ perl mkdir
$dirmode2= 750;                      # to use w/ system chmod (directory)
$group= "trec";                      # group ownership of files
$author= "hz3\@indiana.edu";	     # author's email

# ----------------
# global variable
# ----------------

my $home_dir = "/home/hz3";
my $working_dir = "$home_dir/Desktop/dissertation";
my $tpdir = "$working_dir/prog";	#Dissertation program directory
my $idir = "$working_dir/data";		#input query directory
my $qdir = "$working_dir/query";	#google and wiki output directory 

my $maxhtmN = 100;


require "$tpdir/logsub2.pl";
require "$tpdir/spidersub_2010.pl";

my $qrydir = "$idir/segments";          #test query dir
my $outd="$qdir/segment/gg/hits";       # for search results

my @outdir=("$outd");
foreach my $outdir(@outdir) {
    if (!-e $outdir) {
        my @errs=&makedir($outdir,$dirmode,$group);
        print "\n",@errs,"\n\n" if (@errs);
    }
}

my $outd1="$qdir/segment/wk/hits";  # for search results

my @outdir1=("$outd1");
foreach my $outdir1(@outdir1) {
    if (!-e $outdir1) {
        my @errs=&makedir($outdir1,$dirmode,$group);
        print "\n",@errs,"\n\n" if (@errs);
    }
}

my $a = "steve jobs";
my $qn = 1;

my $htmlcnt = &queryGoogle2($a, $outd, $qn, $maxhtmN);
    
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
	binmode(OUT, ":utf8");
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


my $status= &queryWikipedia($a,$outd1,$qn);