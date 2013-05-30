#!/usr/bin/perl -w

use strict;
use warnings;

my $home_dir = "/home/huizhang";
my $wpdir = "$home_dir/workspace/epic_prog";
my $tpdir = "$home_dir/workspace/epic_prog";
my $qdir = "$wpdir/query";
require "$tpdir/sub/spidersub_2010.pl";

my $gg_hits_dir = "$qdir/segment/gg/hits/blog";    # for search results
#my $gg_hits_dir = "$qdir/segment/gg/hits/hard";    # for search results

my $maxhtmN = 20;

my $input_file = "$home_dir/Desktop/dissertation/data/topics/topic.run";
open(IN, "<$input_file") || die "cannot open $input_file\n";
my @lines = <IN>;
close IN;
chomp(@lines);

foreach my $line (@lines){
	my ($str, $qn) = split(/::/, $line);
	
	#TREC
	my $query;
	if ($str =~ /"/){
		$str =~ s/"//g;
		$str =~ s/'s/\\'s/g;
		$str =~ s/,//g if ($str =~ /,/);
		$query = $str;
	} 
	else {
		$str =~ s/'s/\\'s/g;
		$str =~ s/,//g if ($str =~ /,/);
		$query = $str;
	}
	
	print "\nStarting Google search --- \n\n";
	my $htmlcnt = &queryGoogle2( $query, $gg_hits_dir, $qn, $maxhtmN ); #use $query
	sleep 0.5;
	
	print "\nhtmlcnt:" . $htmlcnt . "\n\n";
	
	# read in result links
	open( LINK, "$gg_hits_dir/lk$qn" ) || die "can't read $gg_hits_dir/lk$qn";
	my @links = <LINK>;
	close LINK;
	chomp @links;
	
	my $outd_gg = "$gg_hits_dir/q$qn";
	print "outd_gg:" . $outd_gg . "\n\n";
	
	# fetch hit pages
	my $fn = 1;
	foreach my $link (@links) {
		last if ( $fn > $maxhtmN );
		my ( $n, $url ) = split (/: /, $link);
		my ( $htm, $title, $body ) = &fetchHTML( $url, $fn );
		sleep 0.5;
		
		my $outf1 = "$outd_gg/r$fn.html";
		open( OUT1, ">$outf1" ) || die "cannot write to $outf1";
		binmode( OUT1, ":utf8" );
		print OUT1 $htm if ($htm);
		close(OUT1);
	
		my $outf2 = "$outd_gg/r$fn.txt";
		open( OUT2, ">$outf2" ) || die "cannot write to $outf2";
		binmode( OUT2, ":utf8" );
		print OUT2 "$title\n\n" if ($title);
		print OUT2 "$body\n"    if ($body);
		close(OUT2);
	
		$fn++;
	} #end foreach
		
}# end foreach