#!/usr/bin/perl -w

# -----------------------------------------------------------------
# Name:      qindxblog2.pl
# Author:    Kiduk Yang, 07/19/2006
#              modified trec04/qindxhard2.pl (6/2005)
#              modified 6/1/2007
#              modified 6/2/2008
#              $Id: qindxblog2.pl,v 1.2 2007/08/01 05:28:02 kiyang Exp $
# -----------------------------------------------------------------
# Description:  create input queries for the retrieval module
# -----------------------------------------------------------------
# Arguments: arg1 = topic type (t=train, e=test)
# Input:     $idir/query/$subd/q$qn                   -- stopped & stemmed queries
# Output:    $idir/query/$subd/$qsubd/q$qlen$qemp$qn  -- processed queries
#            $idir/query/$prog       -- program     (optional)
#            $idir/query/$prog.log   -- program log (optional)
#            where $subd = train|test
#                          (test=w/o non-rel terms, test0=w/ non-rel terms)
#                  $qsubd = e.g. s0, s1, s2 (stemmer type)
#                  $qlen = s|m|l (s=title, m=s+description, l=m+narrative)
#                  $qemp = a|n|z (a=acronym n=noun, z=all)
# ------------------------------------------------------------------------
# NOTE:   
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

require "$wpdir/logsub2.pl";   # subroutine library


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

# s0: queries stemmed w/ simple stemmer
# s1: queries stemmed w/ combo stemmer
# s2: queries stemmed w/ porter stemmer
my @outdir=("$qrydir/s0","$qrydir/s1","$qrydir/s2");
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
    print LOG "Infile = $qrydir/q\$N\n",
              "Outfile = $qrydir/s(0|1|2)/q(s|m|l)(a|n|z)\$N\n\n";
}

my %btags=(
"title"   => "s",
"desc"    => "m",
"narr"    => "l",
);


#-------------------------------------------------
# create queries: q$qlen$qform$qn
#   query length (s, m, l)
#     - s=title, m=s+description, l=m+narrative
#   query expansion (a, n, x)
#     - a=acronyms, n=noun, z=both
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
    #chomp @lines;

    my $bstring= join("",@lines);

    my (%qstr0,%qstr1,%qstr2,%qstr,%nstr,%astr,%acronym);

    foreach my $btag('title','desc','narr') {
	
	# process each include tag field
	if ($bstring=~m|<$btag>(.+?)</$btag>|s) {
	    my $text=$1;
	    my $key= $btags{$btag};
            $text=~m|<text0>(.+?)</text0>|s;
            $qstr0{$key}=$1;
            $text=~m|<text1>(.+?)</text1>|s;
            $qstr1{$key}=$1;
            $text=~m|<text2>(.+?)</text2>|s;
            $qstr2{$key}=$1;

            my $stag;

	    if ($btag=~/title/) {

		# find acronyms
		$stag="acronym";
		if ($text=~m|<$stag>(.+?)</$stag>|s) {
		    my $str=$1;
		    my @words=split(/, /,$str);
		    foreach my $word(@words) {
			my ($acr,$exp)=split(/:/,$word);
			$acronym{$acr}=$exp;
		    }
		}
		my @acrs= $qstr0{$key}=~/\b[A-Z]+\b/g;
		foreach my $acr(@acrs) { $astr{$acr}=1; }

		# find nouns
		$stag="noun";
		if ($text=~m|<$stag>(.+?)</$stag>|s) { 
		    my $nouns=$1; 
		    my @nouns=split(/ +/,$nouns);
		    foreach my $noun(@nouns) { $nstr{$noun}=1; }
		}

	    }

	    elsif ($btag=~/desc/) {

		# find acronyms that occur in both title and description field
		$stag="acronym";
		if ($text=~m|<$stag>(.+?)</$stag>|s) {
		    my $str=$1;
		    my @words=split(/, /,$str);
		    foreach my $word(@words) {
			my ($acr,$exp)=split(/:/,$word);
			$acronym{$acr}=$exp;
		    }
		}
		my @acrs= $qstr0{$key}=~/\b[A-Z]+\b/g;
		foreach my $acr(@acrs) { $astr{$acr}++; }
		foreach my $acr(keys %astr) { 
		    if ($astr{$acr}>1) {
			if ($acronym{$acr}) {
			    $qstr{'a'} .= "$acr $acronym{$acr} ";
			}
			else {
			    $qstr{'a'} .= "$acr ";
			    print LOG "Warning!: acronym expansion failure for $acr in Q$qn\n";
			}
		    }
		}

		# find nouns that occur in both title and description field
		$stag="noun";
		if ($text=~m|<$stag>(.+?)</$stag>|s) { 
		    my $nouns=$1; 
		    my @nouns=split(/ +/,$nouns);
		    foreach my $noun(@nouns) { $nstr{$noun}++; }
		}
		foreach my $noun(keys %nstr) { 
		    $qstr{'n'} .= "$noun " if ($nstr{$noun}>1); 
		}

		# concatenate found nouns & acronyms if both exists
		if ($qstr{'a'} && $qstr{'n'}) {
		    $qstr{'z'}= $qstr{'a'}." $qstr{'n'}";
		}

	    }


	} #endif

    } #end-foreach $btag(keys %btags) 


    my ($qry01, $qry02, $qry11, $qry12, $qry21, $qry22, $qtype);
    foreach my $len("s","l") {

        $qry01 .= "$qstr0{$len}\n";
        my $outf0= "$qrydir/s0/q$len$qn";
        open OUT0,">$outf0" || die "can't write to $outf0";
        print OUT0 "$qry01\n";
        close OUT0;

        $qry11 .= "$qstr1{$len}\n";
        my $outf1= "$qrydir/s1/q$len$qn";
        open OUT1,">$outf1" || die "can't write to $outf1";
        print OUT1 "$qry11\n";
        close OUT1;

        $qry21 .= "$qstr2{$len}\n";
        my $outf2= "$qrydir/s2/q$len$qn";
        open OUT2,">$outf2" || die "can't write to $outf2";
        print OUT2 "$qry21\n";
        close OUT2;

        #next if ($len eq 's');

        foreach my $emp("n") {

            my $qtype= $len.$emp;
            if ($qstr{$emp}) {
                $qry02 = "$qry01\n$qstr{$emp}";
                my $outf0= "$qrydir/s0/q$qtype$qn";
                open OUT0,">$outf0" || die "can't write to $outf0";
                print OUT0 "$qry02\n";
                close OUT0;
                $qry12 = "$qry11\n$qstr{$emp}";
                my $outf1= "$qrydir/s1/q$qtype$qn";
                open OUT1,">$outf1" || die "can't write to $outf1";
                print OUT1 "$qry12\n";
                close OUT1;
                $qry22 = "$qry21\n$qstr{$emp}";
                my $outf2= "$qrydir/s2/q$qtype$qn";
                open OUT2,">$outf2" || die "can't write to $outf2";
                print OUT2 "$qry22\n";
                close OUT2;
            }

        }

    }

    $qcnt++;
	
} # endforeach $file(@files) 



#-------------------------------------------------
# end program
#-------------------------------------------------

print LOG "\nProcessed $qcnt queries\n\n";

&end_log($pdir,$qdir,$filemode,@start_time) if ($log);

# notify author of program completion
#&notify($sfx,$author);

BEGIN { print STDOUT "\n"; }
END { print STDOUT "\n"; }
