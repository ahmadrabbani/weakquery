#!/usr/bin/perl -w

use strict;
use warnings;

my $query = 'new york times square';

my @ngrams = &getNextTwo($query);

sub getNextTwo{
	my $query = shift(@_);
	my (@ngrams, %context);
	
	#take ngram: start with the first word, get all ngrams with more than two words, then move to the second word...
	#new york, new york times, new york times square
	#york times, york times square
	#times square
	
	my @words = split(/ /, $query);
	for (my $i=0; $i<scalar(@words); $i++){
		for (my $j=$i+1; $j<scalar(@words); $j++){
			$words[$i] .= ' ' . $words[$j];
			#print $words[$i] . "\n";
			push (@ngrams, $words[$i])
		}
	}
	
	#print "@ngrams";
	#print "\n\n";
	
	foreach my $ngram (@ngrams){
		my $result = index($query, $ngram);
		#print $ngram . ':' . $result . "\n";
		
		if ($result == 0){
			$context{$ngram} = substr($query, length($ngram));
		}
		else {
			$context{$ngram} = substr($query, 0, $result) . substr($query, $result+length($ngram));
		}
		
 	}
	
	foreach my $key (keys %context){
		print $key . ':' . $context{$key} . "\n";
	}
	
	
		
		
		
		#$i = 1 $words[$i]$words[$i+1] #word 2
		 #      $words[$i], $words[$i+1]
		#
		#$i = 2 $words[$i]$words[$i+1]$words[$i+2] #word 3
		#		$words[$i]$words[$i+1], $words[$i+2]
		#		
		#		$words[$i], $words[$i+1]$words[$i+2]
		#		$words[$i], $words[$i+1], $words[$i+2]
		#
		#$i = 3 $words[$i]$words[$i+1]$words[$i+2]$words[$i+3] #word 4
		#		$words[$i]$words[$i+1]$words[$i+2],$words[$i+3]
		#		
		#		$words[$i]$words[$i+1], $words[$i+2]$words[$i+3]
		#		$words[$i]$words[$i+1], $words[$i+2], $words[$i+3]
		#		
		#		$words[$i], $words[$i+1]$words[$i+2]$words[$i+3]
		#		$words[$i], $words[$i+1]$words[$i+2], $words[$i+3]
		#		
		#		$words[$i], $words[$i+1], $words[$i+2]$words[$i+3]
		#		$words[$i], $words[$i+1], $words[$i+2], $words[$i+3]
	
	
	
}