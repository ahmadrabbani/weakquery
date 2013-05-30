#!/usr/bin/perl -w

# ----------------------
# Wikipedia enhanced query expansion with segmented query
# ----------------------
# Ver 0.1
# 9/26/2011
# ----------------------

use strict;
use warnings;
use DBI;


my $home_dir = "/home/hz3";
my $res_dir = "$home_dir/workspace/epic_prog/query/result/with_stop";

# segment is a Wikipedia topic: query expand with title, redirect, and 1st paragraph, take top 20 terms by tf
# segment is not a Wikipedia topic: search Wikipedia with quotation, expand query with top 20 results, take top 20 terms by LCA
# keyword query: search Wikipedia, expand query with top 20 results, take top 20 terms by LCA

my $res_file = "$res_dir/hard05.rsl";

open(IN, "<$res_file") || die "cannot open $res_file\n";
my @lines = <IN>;
chomp @lines;
close IN;

#------------------------
# Start MySQL
#------------------------

my $database = "en_20110526";
my $hostname = "localhost";
my $port = "3306"; 
my $user = "root";
my $password = "hziub1972";

my $dbh = DBI->connect("DBI:mysql:database=$database;host=$hostname", $user, $password) || die "cannot connect to database:" . DBI->errstr;

foreach my $line (@lines){
	my $line =~ s/^Segmented query://;
	my ($a, $b) = split(/::/, $line);
	if ($a =~ /||/){
		# multiple segmentations: topic and context
		my @s = split(/||/, $a);
		my $seged_qry = shift(@s);
		if ($seged_qry =~ /" /){
			#"Hubble Telescope:40203" Achievements:22562196 
			#"Waves  Brain" Radio Cancer
			#"Hubble Telescope Achievements" 
			
			#wk article expansion
			#hask key: term, value: tf
			my %wk_db_terms;
			
			#wk LCA expansion
			#hash key: term, value: weight
			my %wk_lca_terms;
			
			my @terms = split(/" /, $seged_qry);
			foreach my $term (@terms){
				if($term =~ /:\d+/){
					&wkArticleExpand($term, \%wk_db_terms);
				}
				else{
					&wkLcaExpand($term, \%wk_lca_terms);
				}
			}
			
			my $maxN = 10;
			
			#hash key: term
			#value: normalized tf/weight
			my ($top_wk_db_terms_ref, $top_wk_lca_terms_ref);
			
			$top_wk_db_terms_ref = &getTopExpandTerms(\%wk_db_terms, $maxN);
			$top_wk_lca_terms_ref = &getTopExpandTerms(\%wk_lca_terms, $maxN);
			
			print $seged_qry . ":";
			
			foreach my $k (keys %$top_wk_db_terms_ref){
				print $top_wk_db_terms_ref->{$k} . ' ' . $k . ' ';
			}
			
			foreach my $k (keys %$top_wk_lca_terms_ref){
				print $top_wk_lca_terms_ref->{$k} . ' ' . $k . ' ';
			}
			
			print "\n";
			
		}
		else {
			# this will never happens
		}	
	}
	else {
		# whole query is one topic
		#"human smuggling:68714"
		#"Cult Lifestyles"
		
		#wk article expansion
		#hask key: term, value: tf
		my %wk_db_terms;
		
		#wk LCA expansion
		#hash key: term, value: weight
		my %wk_lca_terms;
		
		if($a =~ /:\d+/){
			&wkArticleExpand($a, \%wk_db_terms);
		}
		else{
			&wkLcaExpand($a, \%wk_lca_terms);
		}
		
		my $maxN = 10;
		
		#hash key: term
		#value: normalized tf/weight
		my ($top_wk_db_terms_ref, $top_wk_lca_terms_ref);
		
		$top_wk_db_terms_ref = &getTopExpandTerms(\%wk_db_terms, $maxN);
		$top_wk_lca_terms_ref = &getTopExpandTerms(\%wk_lca_terms, $maxN);
		
		print $a . ":";
		
		foreach my $k (keys %$top_wk_db_terms_ref){
			print $top_wk_db_terms_ref->{$k} . ' ' . $k . ' ';
		}
		
		foreach my $k (keys %$top_wk_lca_terms_ref){
			print $top_wk_lca_terms_ref->{$k} . ' ' . $k . ' ';
		}
		
		print "\n";	
		
	}# end if-else

}


sub wkArticleExpand{
	my ($term, $term_hash_ref) = @_;
	
	my $term =~ s/^"|^\s+|\s+$// if ($term =~ /^"|^\s+|\s+$/);
	
	my ($term_str, $wk_page_id) = split(/:/, $term);
	
	my $query = "SELECT page_id FROM page WHERE page_title=" . "'" . $wk_page_id . "'";
	my $sth = $dbh->prepare($query) || die "cannot prepapre statement:" . $dbh->errstr();
	$sth->execute;
	
	my ($title) = $sth->fetchrow_array if ($sth->rows == 1);
	$sth->finish;
	
	
	
	
}











