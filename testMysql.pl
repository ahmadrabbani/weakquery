#!/usr/bin/perl -w

use strict;
use warnings;

use DBI;

#Wikipedia database preserves the original word form in page and anchor table
#to find exact match, use the following three topic forms in order with the first match:
#1. original query and/or topic (NOT stop and stemmed), 2. original query/topic with only the first character in the first word in Uppercase(Ucfirst(string))
#3. original query/topic with first character in all words in uppercase


my $topic = 'larimer county colorado jobs';
my $topic1 = ucfirst($topic);
my $topic2;
my @t = split(/ /, $topic);
foreach (@t){
	$topic2 .= ucfirst($_). ' ';
}
$topic2 =~ s/\s+$//;
my $hostname = "localhost";
my $database = "en_20110526";

my $page_id = '';

	my $dbh = DBI->connect("DBI:mysql:database=$database;host=$hostname", "root", "hziub1972") || die "cannot connect to database:" . DBI->errstr;
	my $query = "SELECT page_id FROM page WHERE page_type=1 AND page_title=" . "'" . $topic . "'";
	my $sth = $dbh->prepare($query) || die "cannot prepare statement:" . $dbh->errstr();
	$sth->execute;
	if ($sth->rows == 1){
		$page_id = $sth->fetchrow_array;
		print $topic . $page_id . "\n";
	}
	else {
		$topic = $topic1;
		my $dbh = DBI->connect("DBI:mysql:database=$database;host=$hostname", "root", "hziub1972") || die "cannot connect to database:" . DBI->errstr;
		my $query = "SELECT page_id FROM page WHERE page_type=1 AND page_title=" . "'" . $topic . "'";
		my $sth = $dbh->prepare($query) || die "cannot prepare statement:" . $dbh->errstr();
		$sth->execute;
		if ($sth->rows == 1){
			$page_id = $sth->fetchrow_array;
			print $topic . $page_id . "\n";
		}
		else {
			$topic = $topic2;
			my $dbh = DBI->connect("DBI:mysql:database=$database;host=$hostname", "root", "hziub1972") || die "cannot connect to database:" . DBI->errstr;
			my $query = "SELECT page_id FROM page WHERE page_type=1 AND page_title=" . "'" . $topic . "'";
			my $sth = $dbh->prepare($query) || die "cannot prepare statement:" . $dbh->errstr();
			$sth->execute;
			if ($sth->rows == 1){
				$page_id = $sth->fetchrow_array;
				print $topic . $page_id . "\n";
			}
			
		}
	}
if (length($page_id) > 0 && $page_id =~ /\d+/){
	print "Page id found:" . $page_id;
}
