#!/usr/bin/perl -w

use strict;
use warnings;

require "sub/logsub2.pl";
require "sub/spidersub_2010.pl";
require "sub/indxsub_2010.pl";
require "sub/NLPsub_2010.pl";

my $home_dir = "/home/hz3";
my $tpdir = "$home_dir/Desktop/dissertation/prog";
my $wkcsv_dir = "/media/Elements/en_20080727";

my $stopwordslist = "$tpdir/stoplist2";
my $subdict="$tpdir/krovetz.lst";       # dictionary subset for stemmer
my $xlist="$tpdir/pnounxlist2";          # proper nouns to exclude from stemming
my $abbrlist=  "$tpdir/abbrlist4";       # abbreviation list
my $pfxlist =  "$tpdir/pfxlist2";        # valid prefix list
my $arvlist=   "$tpdir/dict.arv";        # adjective, adverb, verb
my %qnoun2;

# create hash of adjective, adverb, & verb
my %arvlist;
&mkhash($arvlist,\%arvlist);

# create the stopword hash
my %stoplist;
&mkhash( $stopwordslist, \%stoplist );

# create krovetz dictionary subset hash
my %sdict;
&mkhash($subdict,\%sdict);
# stemmer (0=simple, 1=combo, 2=Porter, 3=Krovetz)
my $stemmer = 0;

# create proper noun hash
my %xlist;
&mkhash($xlist,\%xlist);

# create acronym/abbreviation hash
my %abbrlist;
open(IN,$abbrlist) || die "can't read $abbrlist";
while (<IN>) {
    chomp;
    my ($word,$str)=split(/ +/,$_,2);
    $abbrlist{$word}=$str;
}
close IN;

# create prefix hash 
my %pfxlist;
open(IN,$pfxlist) || die "can't read $pfxlist";
while (<IN>) {
    chomp;
    my ($word)=split/-/;
    $pfxlist{"\L$word"}=1;
}
close IN;


print "Process starts\n";

# takes 20 minute with 2gb memory

#my %stem_wk_definition;


#my $definition = "$wkcsv_dir/definition.csv";
#open( IN, "<$definition" ) || die "can't read $definition";
#my @definitions = <IN>;
#close IN;
#chomp @definitions;

#foreach my $definition (@definitions) {
#	my ($id, $sentence, $paragraph) = split(/\t/, $definition);
#	$id =~ s/^\s+|\s+$//;
#	if ($paragraph ne '') {
#		$paragraph =~ s/^\s+|\s+$//;
#		my @words = split(/ /, $paragraph);
#	
#		my (@stem_para, $stem_para);
#		foreach my $word(@words){
#			my $stem = &stemword2($word,\%stoplist, \%xlist, \%sdict,$stemmer);
#			push(@stem_para, $stem) if ($stem ne '');
#		}
#	
#		$stem_para = join(' ', @stem_para);
#		
#		$stem_wk_definition{$id} = $stem_para;
#	}
#}

my %stem_wk_anchor;

#my $anchor = "$wkcsv_dir/anchor_summary.csv";
my $anchor = "$home_dir/Desktop/test.csv";
open( IN, "<$anchor" ) || die "can't read $anchor";
my @anchors = <IN>;
close IN;
chomp @anchors;

foreach my $anchor (@anchors) {
	my ($a, $b) = split(/,/, $anchor);
	$a =~ s/^"|"$//;
	$b =~ s/^"|"$//;
	print $a . "," . $b . "\n";
	my @words= &getword3($a,\%abbrlist,\%pfxlist,\%stoplist,\%arvlist);

            
    my $str0= &procword3(\@words,\%stoplist,\%xlist,\%sdict,0,\%qnoun2);
		
	print $str0 . "\n";
	
	$stem_wk_anchor{$str0} = $b;
}

print "Process complete\n";

my $topic = 'new york';
my $context = '"time square" time square';

my ($flag, $link_line) = &chkAmbiguation( $topic, \%stem_wk_anchor );

if ($flag) {
	# disambiguation
	# get context
					
	#my $page_id = &wikiDisambiguation( $topic, $context, \%stem_wk_definition, $link_line );
	#print "$topic: " . 'page id: ' . $page_id . "\n"; 
}
else {
	my ($link, $count) = split(/:/, $link_line);
	print "$topic: " . 'page id: ' . $link . "\n"; 
}




sub wikiDisambiguation {
	# sense inventory: link page ids
	# sense definition: Wikipeda definition
	# use context to decide the most appropriate topic sense
	
	my ($topic, $context, $wk_definition_ref, $link_page_line) = @_;
	
	my %wk_stem_definition = %$wk_definition_ref;
	
	# get link page as sense inventory
	my @link_pages = split(/;/, $link_page_line);
	
	# get sense representation
	my $sense_num = scalar(@link_pages);
	my $big_line = '';
	my $count = 0;
	foreach my $link (@link_pages){
		my ($id, $num) = split(/:/, $link);
		if (!exists($wk_stem_definition{$id})){
			print LOG "Wikipedia page id: $id not found content in definition.csv\n";
			$count++;
		}
		else {
			$big_line .= $wk_stem_definition{$id};
		}
		print LOG "Wikipedia page id: id has $count out of $sense_num senses not found in definition.csv\n";
	}
	
	# hash key: page id <=> word sense
	# value: reference to feature hash %sense_feature
	my %sense_represent;
	
	# hash key: word appears with the page id
	# value: word distribution ratio in different senses
	my %sense_feature;
	
	foreach my $link (@link_pages){
		my ($id, $num) = split(/:/, $link);
		if (exists($wk_stem_definition{$id})){
			my @words = split(/ /, $wk_stem_definition{$id});
			foreach my $word (@words){
				my @tf_word = $wk_stem_definition{$id} =~ /\b$word\b/i;
				my @tf_all = $big_line =~ /\b$word\b/i;
				# word score: tf_word in i/sum (tf_word in j) where i != j
				$sense_feature{$word} = scalar(@tf_word)/(scalar(@tf_all) - scalar(@tf_word));
			}			
		}
		$sense_represent{$id} = \%sense_feature;	
	}
	
	# disambiguation
	
	#hash key: Wikipedia page id
	#value: sense score
	my %sense_score;
	
	my $sense_context = '';
	
	if (index($context, '"') != -1){
		my @context_ngrams = split(/\" /, $context);
		# single word context is behind ngram context
		# based on sub segmnentation
				
		# get single word context
		my $context_word = pop(@context_ngrams);
		$sense_context = $context_word;		
	}
	else {
		$sense_context = $context;
	}
	
	my @sense_contexts = split(/ /, $sense_context);
	
	foreach my $link (@link_pages){
		my ($id, $num) = split(/:/, $link);
		my $feature_ref = $sense_represent{$id};
		my $score = 0;
		foreach my $word (@sense_contexts){
			if (exists($feature_ref->{$word})){
				$score += $feature_ref->{$word};
			}
		}
		$sense_score{$id} = $score;
	}
	
	my $disambiguated_sense;
	
	# rank %sense_score keys by associated value in desend
	my @ids = sort {$sense_score{$b} <=> $sense_score{$a}} keys %sense_score;
	
	# the largest value is at the beginning
	return shift(@ids);
	
}    #end sub wikiDisambiguation


sub chkAmbiguation {
	my ($topic, $wk_anchor_ref) = @_;
	print "topic:" . $topic . "\n";
	my $isPolysemy = 0;
	my $line = '';
	
	my %wk_stem_anchor = %$wk_anchor_ref;
	
	foreach my $anchor (keys %wk_stem_anchor){
		print "anchor:" . $anchor . ',' . "context:" . $wk_stem_anchor{$anchor} . "\n";
		if ($anchor eq $topic) {
			$isPolysemy = 1 if ($wk_stem_anchor{$anchor} =~ /;/);
			$line = $wk_stem_anchor{$anchor};
			last;
		}
			
	}
	
	print $isPolysemy . $line . "\n";
	
	return ($isPolysemy, $line);

}    #end sub chkAmbiguation


#-----------------------------------------------------------
#  create hash from file
#-----------------------------------------------------------
#  arg1 = infile
#  arg2 = pointer to hash to create
#-----------------------------------------------------------
sub mkhash {
	my ( $file, $hp ) = @_;

	open( IN, $file ) || die "can't read $file";
	my @terms = <IN>;
	close IN;
	chomp @terms;
	foreach my $word (@terms) { $$hp{$word} = 1; }

}    #endsub mkhash

