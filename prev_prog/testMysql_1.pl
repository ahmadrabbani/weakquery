#!/usr/bin/perl -w

use strict;
use warnings;

use DBI;

my $hostname = "localhost";
my $database = "en_20110526";

	my $dbh = DBI->connect("DBI:mysql:database=$database;host=$hostname", "root", "hziub1972") || die "cannot connect to database:" . DBI->errstr;
	my $query = "SELECT df_firstParagraph FROM definition WHERE df_id='26769'";
	my $sth = $dbh->prepare($query) || die "cannot prepare statement:" . $dbh->errstr();
	$sth->execute;
	my ($result) = $sth->fetchrow_array if $sth->rows == 1;
	#print $result . "\n";
	
	my @terms;
	
	my @w = split(/\[\[.*?\]\]/, $result);
	#foreach (@t){
	#	print $_ . "\n";
	#}
	
	@terms = $result =~ m/\[\[(.*?)\]\]/g;
	foreach (@terms){
		print $_ . "\n";
	}

	my $mysql_topic = "new york times square";
		
	$query = "SELECT page_id FROM page WHERE page_title=" . "'" . $mysql_topic . "'";
	$sth = $dbh->prepare($query) || die "cannot prepapre statement:" . $dbh->errstr();
	$sth->execute;
	
	my ($id) = $sth->fetchrow_array;
	print $id . "\n";
	$sth->finish;

