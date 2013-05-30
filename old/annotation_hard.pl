#!/usr/bin/perl -w

use strict;
use warnings;

my $home_dir = "/home/huizhang";

my $hard_topic = "$home_dir/Desktop/dissertation/data/topics/hard05.50.topics.txt";

my $hard_output = "$home_dir/Desktop/dissertation/data/topics/hard05.50.topics.annotation";

my @tags= ('title','desc','narr');
my %tags= (
'title'=>'Title',
'desc'=>'Description',
'narr'=>'Narrative'
);

my @lines;

open(IN, "<$hard_topic") || die "cannot open $hard_topic\n";
while(<IN>){
	chomp;
    next if (/^\s*$/);
	push (@lines, $_);
}
close (IN);

my $big_str = join(" ", @lines);
@lines = split(/<\/top>/, $big_str);

my $qcnt = 0;
my $acnt = 0;
open (OUT, ">$hard_output") || die "cannot write to $hard_output\n";
foreach (@lines) {

    my $qn;
    
    my $flag = 1;

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
        my @str = split(/ /, $str);
        if (scalar@str > 1){
        	push(@topic,"<title_annotate>$str</title_annotate>");
    	}
    	else {
    		$flag = 0;
    	}	
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
    
    if ($flag){
    	print OUT join("\n", @topic), "\n";
    	$acnt++;
    }
    
}# endforeach

print "qcnt: $qcnt\n";
print "acnt: $acnt\n";
