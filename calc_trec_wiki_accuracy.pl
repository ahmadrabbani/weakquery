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
my $result_dir = "$home_dir/workspace/epic_prog/query/result/with_stop";

my $anote_dir = "$home_dir/Desktop/dissertation/data/topics";

my $result_file = "$result_dir/hard05.rsl";
my $anote_file = "$anote_dir/hard05.50.topics.annotate";
#my $total_qry = 49;
my $total_qry = 24;	#pti
#my $total_qry = 10; #ambiguous	

#my $result_file = "$result_dir/wt09.rsl";
#my $anote_file = "$anote_dir/wt09.topics.full.annotate";
#my $total_qry = 33;

#my $result_file = "$result_dir/06-08_blog.rsl";
#my $anote_file = "$anote_dir/06-08.all-blog-topics.annotate";
#my $total_qry = 101;
#my $total_qry = 15;	#pti
#my $total_qry = 4;	#ambiguous


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
	my $str = lc($_);
	$str =~ s/^\s+//;
	$str =~ s/\s+$//;
	$anote{$line} = $str;	
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

my $correct_num = 0;
my $total_precision = 0;
my $total_recall = 0;
my $total_f1score = 0;

foreach my $line (@result){
	$line =~ s/^Segmented query://;
	my $lc_line = lc($line);
	$lc_line =~ s/^\s+//;
	$lc_line =~ s/\s+$//;
	#two word query is ;a bigram if wrappered with ""
	my ($result,$qn) = split(/::/,$lc_line);
	$result =~ s/[ \t]+$//;
	my @s;
	my $target;
	if ($result =~ /\|\|/){
		# three ranked segmentation 
		@s = split(/\|\|/, $result);
		#"Waves  Brain" Radio Cancer||"Waves  Brain Cancer" Radio:15368428 ||"Waves :180846" Brain_Cancer:37284 Radio Brain Cancer||::3
		#use lower rank if it has more than two wikipedia topic and the top rank has none 
		$target = $s[0];
		$target =~ s/[ \t]+$//;
	}
	elsif ($result =~ /^"(.*?)"$/){
		#"Airport Security:284770", "journalist risks"
		$target = $result;
	}
	else {
		print "!!!result: " . $result . "has special pattern" . "\n\n";
	}
	my $anote;
	if (exists($anote{$qn})){
		$anote = $anote{$qn};
	}
	else {
		print "!!!$result: " . "does not have annotation found in $anote_file\n\n";
	}
	
	my $q_accu = &calqaccu($target, $anote);
	$q_accuracy{$qn} = $q_accu;
	print "target:" . $target . ' ' . "anote:" . $anote . "\n" . "q_accu:" . $q_accu . "\n\n";
	$correct_num++ if ($q_accu == 1.0);
	
	my ($seg_p, $seg_r, $seg_f1, $correct_count) = &calsegaccu($target, $anote);
	$seg_precision{$qn} = $seg_p;
	$seg_recall{$qn} = $seg_r;
	$seg_f1{$qn} = $seg_f1;
	print "target:" . $target . ' ' . "anote:" . $anote . "\n" . "seg accuracy:" . "$seg_p" . ',' . "$seg_r" . ','  . "$seg_f1" . ',' . "$correct_count" . "\n\n";
	
	#my $break_accu = &calbreakaccu($target, $anote);
	#$break_accuracy{$qn} = $break_accu;
	#print "$target: " . "break accuracy: " . "$break_accu" . "\n\n"; 

}#end foreach


print "Accuracy at query level is:" . $correct_num/$total_qry . "\n\n";

foreach my $key (keys %seg_precision){
	$total_precision += $seg_precision{$key};
}

foreach my $key (keys %seg_recall){
	$total_recall += $seg_recall{$key};
}

foreach my $key (keys %seg_f1){
	$total_f1score += $seg_f1{$key};
}

print "Accuracy at segmentation level is:" . $total_precision/$total_qry . ',' . $total_recall/$total_qry . ',' . $total_f1score/$total_qry . "\n\n"; 


sub calqaccu {
	my ($result, $anote) = @_;
	print "result:" . $result . "\n";
	
	#whole query is a wikipedia topic, "Airport Security:284770"
	#anote: "Airport" "Security"
	if($result =~ /^"(.*?):\d+"$/){
		print "1:" . $1 . ' ' . $anote . "\n";
		#Wikipedia title or anchor is a valid topic
		return 1.0;
		#my $word = '"' . $1 . '"';
		#if ($word eq $anote){
		#	return 1.0;
		#}
		#else {
		#	return 0.0;
		#}
	}
	#whole query is a topic but not Wikipedia title or anchor, e.g., a bigram
	elsif ($result =~ /^"[a-zA-Z0-9 \-\']+"$/){
		print "2:" . $result . ' ' . $anote . "\n";
		if ($result eq $anote){
			return 1.0;
		}
		else {
			return 0.0;
		}
	}
	#check whether all segments are correct but order is not
	#"Hydroelectric Projects" New:22562196 vs. "New" "Hydroelectric Projects"
	else {
		#separate topic and context
		#"Hubble Telescope:40203
		#New:22562196
		my @results = split(/" /, $result);
		#get segments
		my @anotes =  $anote =~ /".*?"/g;
		
		my %anotes;
		foreach (@anotes){
			$_ =~ s/^"|"$//g;
			$anotes{$_} = 1;
		}
		
		my $continue = 1;
		foreach my $result (@results){
			last if ($continue == 0);
			
			#"Hubble Telescope:402039
			if ($result =~ /^"(.*?):(\d+)/){
				my $word = $1;
				$word =~ s/^\s+//;
				$word =~ s/\s+$//;
				print '$1_1:' . $word . "\n";
				#anotes inside else
				if(exists($anotes{$word})){
					$continue = 1;
				}
				else {
					$continue = 0;
				}
			}
			#"Hubble Telescope
			elsif ($result =~ /^"/){
				$result =~ s/^"//;
				print '$1_2:' . $result . "\n";
				if(exists($anotes{$result})){
					$continue = 1;
				}
				else {
					$continue = 0;
				}
			}
			#Radio_Waves:22562196 International:3741372 Waves
			else {
				my @r = split(/ /, $result);
				foreach my $r(@r){
					if ($r =~ /(.*?_.*?_?.*?):(\d+)/){
						my $word = $1;
						$word =~ s/_/ /g;
						print '$word_1:' . $word . "\n";
						if(exists($anotes{$word})){
							$continue = 1;
						}
						else {
							$continue = 0;
						}
					}					
					elsif ($r =~ /(.*?):(\d+)/){
						my $word = $1;
						print '$word_2:' . $word . "\n";
						if(exists($anotes{$word})){
							$continue = 1;
						}
						else {
							$continue = 0;
						}
					}					
					else {			
						my $word = $r;
						print '$word_3:' . $word . "\n";
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
	print "result:" . $result . "\n";
	
	#whole query is a wikipedia topic, "Airport Security:284770"
	#anote: "Airport" "Security"
	if($result =~ /^"(.*?):\d+"$/){
		print "1:" . $1 . ' ' . $anote . "\n";
		#Wikipedia title or anchoe is a valid topic
		return (1.0, 1.0, 1.0, 1);
		#my $word = '"' . $1 . '"';
		#if ($word eq $anote){
		#	return (1.0, 1.0, 1.0, 1);
		#}
		#else {
		#	return (0.0, 0.0, 0.0, 0);
		#}
	}
	#whole query is a topic but not Wikipedia title or anchor, e.g., a bigram
	elsif ($result =~ /^"[a-zA-Z0-9 \-\']+"$/){
		print "2:" . $result . ' ' . $anote . "\n";
		if ($result eq $anote){
			return (1.0, 1.0, 1.0, 1);
		}
		else {
			return (0.0, 0.0, 0.0, 0);
		}
	}
	#calculate segment accuracy 
	else {
		my $num_segments = 0;
		#number of segments that are correct
		my $correct_count = 0;		
		
		#separate topic and context
		#"Hubble Telescope:40203
		#New:22562196
		my @results = split(/" /, $result);
		#get segments
		my @anotes =  $anote =~ /".*?"/g;
		
		my %anotes;
		foreach (@anotes){
			$_ =~ s/^"|"$//g;
			$anotes{$_} = 1;
		}
		
		foreach my $result (@results){			
			#"Hubble Telescope:402039
			if ($result =~ /^"(.*?):(\d+)/){
				my $word = $1;
				$word =~ s/^\s+//;
				$word =~ s/\s+$//;
				print '$1_1:' . $word . "\n";
				#anotes inside else
				if(exists($anotes{$word})){
					$correct_count++;
				}
				$num_segments++;
			}
			#"Hubble Telescope
			elsif ($result =~ /^"/){
				$result =~ s/^"//;
				print '$1_2:' . $result . "\n";
				if(exists($anotes{$result})){
					$correct_count++;
				}
				$num_segments++;
			}
			#Radio_Waves:22562196 International:3741372 Waves
			else {
				my @r = split(/ /, $result);
				foreach my $r(@r){
					if ($r =~ /(.*?_.*?_?.*?):(\d+)/){
						#the single word in this segment will also be parsed
						#and add to the count, so need to lower the num_segments 
						my $word = $1;
						$word =~ s/_/ /g;
						print '$word_1:' . $word . "\n";
						if(exists($anotes{$word})){
							$correct_count++;
						}
						$num_segments++;
						my @w = split(/_/, $1);
						$num_segments -= scalar(@w);
					}					
					elsif ($r =~ /(.*?):(\d+)/){
						my $word = $1;
						print '$word_2:' . $word . "\n";
						if(exists($anotes{$word})){
							$correct_count++;
						}
						$num_segments++;
					}					
					else {
						#single word not count as segment
						my $word = $r;
						print '$word_3:' . $word . "\n";
						if(exists($anotes{$word})){
							$correct_count++;
						}
						$num_segments++;
					}#end if else					
				}#end foreach
			}#end if else
		}#end foreach
		
		my $precision = $correct_count/$num_segments;
		my $recall = $correct_count/scalar(@anotes);
		my $f1_score;
		if ($precision == 0 || $recall == 0){
			$f1_score = 0;
		}
		else{
			$f1_score = 2*$precision*$recall/($precision+$recall);
			
		}
		
		return($precision, $recall, $f1_score, $correct_count);
		
	}#end if else
	
	
	#return ($precision,$recall,$f1_score,$correct_count);
}

sub calbreakaccu{
	
	
}







