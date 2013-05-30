#!/usr/bin/perl -w

#As an illustration, consider the query san jose yellow pages with the reference segmentation “san jose” “yellow pages”. 
#A computed segmentation “san jose” yellow pages is not correct on the query level, resulting in a query accuracy of 0.
#However, on the segment-level, 
#“san jose” yellow pages at least contains one of the two reference segments, yielding a segment recall of 0.5. 
#since the other two single word segments are not part of the reference segmentation, precision is 0.333, 
#yielding a segment F -Measure of 0.4. 
#The break accuracy is 0.666, since “san jose” yellow pages decides incorrectly only for one of the three break positions.

# 9/7/2011: query need to remove stopword before sending to segmentation as the annotation format

use strict;
use warnings;

#my $home_dir = "/home/hz3";
my $home_dir = "/home/huizhang";
my $result_dir = "$home_dir/workspace/epic_prog/query/result";

my $anote_dir = "$home_dir/Desktop/dissertation/data/topics";

my $result_file = "$result_dir/hard05.rsl";
my $anote_file = "$anote_dir/hard05.50.topics.annotate";

#my $result = `grep 'Segmented query' $result_file`;
open(IN, "<$result_file") || die "cannot open $result_file\n";
my @result = (<IN>);
close IN;
chomp @result;

#hash key: qn
#value: manually segmented query
my %anote;

my $line = 1;
open (IN, "<$anote_file") || die "cannot open $anote_file\n";
while(<IN>){
	chomp;
	$anote{$line} = $_;
	$line++;
}
close IN;

# hash key: line/qn
# value: segmetation result
my %result;

# accuracy output: segmented query,query accuracy,seg precision,seg recall,seg F1
#hash key: qn
#value: 1.0 if correct, 0.0 if incorrect
my %q_accuracy;

#hash key: qn
#value: precision at segment level 
my %seg_precision;

#hash key: qn
#value: recall at segment level
my %seg_recall;

#hash key: qn
#value: F1 at segment level
my %seg_f1;

#hash key: qn
#value: accuracy percentage at break level
my %break_accuracy;


foreach my $result (@result){
	
	$result =~ s/^Segmented query://;
	#two word query is ;a bigram if wrappered with ""
	my ($str,$qn) = split(/::/,$result);
	my @s;
	my $target;
	if ($str =~ /\|\|/){
		# three ranked segmentation 
		@s = split(/\|\|/, $str);
		$target = $s[0];
	}
	elsif ($str =~ /^".*?"$/){
		$target = $str;
	}
	my $anote;
	if (exists($anote{$qn})){
		#print $target . ':' . $anote{$qn} . "\n\n"; 
		$anote = $anote{$qn};
	}
	else {
		print "$result: " . "does not have annotation found in $anote_file\n\n";
	}
	
	my $q_accu = &calqaccu($target, $anote);
	$q_accuracy{$qn} = $q_accu;
	print "$target: " . "q_accu: " . $q_accu . "\n\n";
	
	#my ($seg_p, $seg_r, $seg_f1, $correct_count) = &calsegaccu($target, $anote);
	#$seg_precision{$qn} = $seg_p;
	#$seg_recall{$qn} = $seg_r;
	#$seg_f1{$qn} = $seg_f1;
	#print "$target: " . "seg accuracy: " . "$seg_p" . ',' . "$seg_r" . ','  . "$seg_f1" . ',' . "$correct_count" . "\n\n";
	
	#my $break_accu = &calbreakaccu($target, $anote);
	#$break_accuracy{$qn} = $break_accu;
	#print "$target: " . "break accuracy: " . "$break_accu" . "\n\n"; 

	
}



sub calqaccu {
	my ($result, $anote) = @_;
	
	#whole query is a wikipedia topic
	if($result =~ /^"(.*?):\d+"$/){
		if ($1 eq $anote){
			return 1.0
		}
		else {
			return 0.0;
		}
	}
	#whole query is a topic
	elsif ($result =~ /^".*?"$/){
		if ($result eq $anote){
			return 1.0;
		}
		else {
			return 0.0;
		}
	}
	#check whether all segments are correct but order is not
	#"Hydroelectric Projects" New vs. "New" "Hydroelectric Projects"
	else {
		#separate topic and context
		my @results = split(/" /, $result);
		#get segments
		my @anotes =  $anote =~ /".*?"/g;
		
		my %anotes;
		
		foreach (@anotes){
			print $_ . "\n\n";
			$anotes{$_} = 1;
		}
		
		my $continue = 1;
		foreach my $result (@results){
			last if ($continue == 0);
			print $result . "\n\n";
			
			#"Hubble Telescope:402039
			if ($result =~ /^"(.*?):(\d+)/){
				print $1 . "\n";
				my $word = '"' . $1 . '"';
				if(exists($anotes{$word})){
					$continue = 1;
				}
				else {
					$continue = 0;
				}
			}
			#"Hubble Telescope
			elsif ($result =~ /^".*?/){
				if(exists($anotes{$result . '"'})){
					$continue = 1;
				}
				else {
					$continue = 0;
				}
			}
			#Radio_Waves:22562196 #International:3741372 #Waves
			else {
				my @r = split(/ /, $result);
				foreach my $r(@r){
					if ($r =~ /(.*?_.*?_?.*?):(\d+)/){
						print $1 . "\n";
						$1 =~ s/_/ /g;
						my $word = '"' . $1 . '"';
						if(exists($anotes{$word})){
							$continue = 1;
						}
						else {
							$continue = 0;
						}
					}					
					elsif ($r =~ /(.*?):(\d+)/){
						my $word = '"' . $1 . '"';
						if(exists($anotes{$word})){
							$continue = 1;
						}
						else {
							$continue = 0;
						}
					}					
					else {				
						my $word = '"' . $r . '"';
						if(exists($anotes{$word})){
							$continue = 1;
						}
						else {
							$continue = 0;
						}
					}#end if else					
				}#end foreach
			}#end if else
		}#end foreach
		
		if ($continue == 1){
			return 1.0;
		}
		else {
			return 0.0;
		}
		
	}#end if else
}

sub calsegaccu{
	my ($result, $anote) = @_;
	my @results = split(/ /, $result);
	my @anotes = split(/ /, $anote);
	
	my %anotes;
	foreach (@anotes){
		$anotes{$_} = 1;
	}
	
	#number of segments that are correct
	my $correct_count = 0;
	
	foreach (@results){				
		#"Hubble Telescope:40203"
		if ($_ =~ /^"(.*?)(:\d+)"$/){
			$_ =~ s/$2//;
			if(exists($anotes{$_})){
				$correct_count++;
			}
		}
		#"Hubble Telescope:40203"
		elsif ($_ =~ /^".*?"$/){
			if(exists($anotes{$_})){
				$correct_count++;
			}
		}
		#Radio_Waves:22562196
		elsif ($_ =~ /.*?_.*?(:\d+)/){
			$_ =~ s/$1//;
			$_ =~ s/_/ /g;
			my $word = '"' . $_ . '"';
			if(exists($anotes{$word})){
				$correct_count++;
			}
		}
		#International:3741372
		elsif ($_ =~ /.*?(:\d+)/){
			$_ =~ s/$1//;
			my $word = '"' . $_ . '"';
			if(exists($anotes{$word})){
				$correct_count++;
			}
		}
		#Waves
		else {
			my $word = '"' . $_ . '"';
			if(exists($anotes{$word})){
				$correct_count++;
			}
		}#end if else
	}#end foreach
	
	my $precision = $correct_count/scalar(@results);
	my $recall = $correct_count/scalar(@anotes);
	my $f1_score = 2*$precision*$recall/($precision+$recall);
	
	return ($precision,$recall,$f1_score,$correct_count);
}

sub calbreakaccu{
	
	
}







