#!/usr/bin/perl -w

# -----------------------------------------------------------------
# Name:      qindxblog1.pl
# Author:    Kiduk Yang, 06/02/08
#              $Id: qindxblog1.pl,v 1.5 2007/07/23 20:59:18 kiyang Exp $
# -----------------------------------------------------------------
# Description:  split 2008 blog topics into training and test sets
# -----------------------------------------------------------------
# Arguments: 
#   arg1 = 1 to run
# Input:     
#   $idir/06-08.all-blog-topics  -- 2008 test topics
# Output:    
#   $idir/06-07.blog-topics  -- 2006-2007 topics
#   $idir/08.blog-topics  -- 2008 topics
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
my $pdir=   "$tpdir/blog";              # blog track program directory
my $idir=   "/u1/trec/topics";          # TREC topics directory

# test topics: 
my $qin=  "$idir/06-08.all-blog-topics";

# training topics:  2008
my $qtest=  "$idir/08.blog-topics";

# training topics:  2006-2007
my $qtrain=  "$idir/06-07.blog-topics";

my @tags= ('title','desc','narr');
my %tags= (
'title'=>'Title',
'desc'=>'Description',
'narr'=>'Narrative'
);

require "$wpdir/logsub.pl";   # general subroutine library


#------------------------
# program arguments
#------------------------
my $prompt=
"arg1= 1 to run\n";

my %valid_args= (
0 => " 1 ",
); 

my ($arg_err,$qtype)= chkargs($prompt,\%valid_args,1);
die "$arg_err\n" if ($arg_err);      


#------------------------
# start program log
#------------------------

$noargp=1;             # if 1, do not print arguments to log
$append=0;             # log append flag

if ($log) {
    @start_time= &begin_log($idir,$filemode,$sfx,$noargp,$append);
    print LOG "Infile  = $qin\n",
              "Outfile = $qtrain\n",
              "          $qtest\n\n";
}


#-------------------------------------------------
# process topics
#-------------------------------------------------

# read the topics file
open(IN,$qin) || die "can't read $qin";
my @lines;
while(<IN>) {
    chomp;
    next if (/^\s*$/);
    push(@lines,$_);
}
close IN;

# make one line per query
my $bstring= join(" ",@lines);
@lines= split(m|</top>|,$bstring);

my $qcnt=0;
my $qcntT=0;
my $qcntE=0;


open(OUTT,">$qtrain") || die "can't write to $qtrain";
open(OUTE,">$qtest") || die "can't write to $qtest";

foreach (@lines) {

    my $qn;

    s/\s+/ /g;

    my @topic=();
    push(@topic,"<top>");

    # get query number
    if (m|<num>.+?(\d+).*?</num>|) {
	$qn= $1; 
	$qcnt++;
        push(@topic,$&);
    }
    else {
        print "$qcnt: missing QN\n";
        next;
    }

    # get query title
    if (m|<title> *(.+?) *</title>|) {
	my $str= $1; 
        print "Q$qn: missing title\n" if ($str=~/^\s*$/);
        push(@topic,"<title>$str</title>");
    }

    # get query desc
    if (m|<desc> *(.+?) *</desc> *(.*?) *<narr>|s) {
	my $str= $1; 
	my $str2= $2; 
        $str=~s/$tags{'desc'}:? *//;
        if ($str=~/^\s*$/) {
            if ($str2=~/^\s*$/) {
                print "Q$qn: missing description\n";
            }
            else {
                print "Q$qn: missing description CORRECTED\n";
                print " - $str2\n\n";
                push(@topic,"<desc>\n$str2\n</desc>");
            }
        }
        else {
            push(@topic,"<desc>\n$str\n</desc>");
        }
    }


    # get query narrative
    if (m|<narr> *(.+?) *</narr> *(.*?) *$|s) {
	my $str= $1; 
	my $str2= $2; 
	my $str3= $&; 
        $str=~s/$tags{'narr'}:? *//;
        if ($str=~/^\s*$/) {
            if ($str2=~/^\s*$/) {
                print "Q$qn: missing narrative\n";
            }
            else {
                print "Q$qn: missing narrative CORRECTED\n";
                print " - $str2\n\n";
                push(@topic,"<narr>\n$str2\n</narr>");
            }
        }
        else {
            push(@topic,"<narr>\n$str\n</narr>");
        }
    }

    push(@topic,"</top>");


    if ($qn<1000) { 
        print OUTT join("\n",@topic),"\n";
        $qcntT++;
    }
    else {
        print OUTE join("\n",@topic),"\n";
        $qcntE++;
    }

} # endforeach



#-------------------------------------------------
# end program
#-------------------------------------------------

print LOG "\nProcessed $qcnt queries ($qcntT train, $qcntE test)\n\n";

&end_log($pdir,$idir,$filemode,@start_time) if ($log);

# notify author of program completion
#&notify($sfx,$author);


##############################################
# SUBROUTINES
##############################################

BEGIN { print STDOUT "\n"; }
END { print STDOUT "\n"; }

