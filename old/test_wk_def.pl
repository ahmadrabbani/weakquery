#!/usr/bin/perl -w

use strict;
use warnings;

require "sub/logsub2.pl";
require "sub/spidersub_2010.pl";
require "sub/indxsub_2010.pl";
require "sub/NLPsub_2010.pl";

my $home_dir = "/home/hz3";
my $pdir = "$home_dir/Desktop/dissertation/prog";

my $stopwordslist = "$pdir/stoplist1";
my $subdict="$pdir/krovetz.lst";       # dictionary subset for stemmer
my $xlist="$pdir/pnounxlist2";          # proper nouns to exclude from stemming

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

# takes 20 minute with 2gb memory

my %stem_wk_definition;


my $definition = "$home_dir/definition.csv";
open( IN, "<$definition" ) || die "can't read $definition";
my @definitions = <IN>;
close IN;
chomp @definitions;

foreach my $definition (@definitions) {
	my ($id, $sentence, $paragraph) = split(/\t/, $definition);
	$id =~ s/^\s+|\s+$//;
	if ($paragraph ne '') {
		$paragraph =~ s/^\s+|\s+$//;
		my @words = split(/ /, $paragraph);
	
		my (@stem_para, $stem_para);
		foreach my $word(@words){
			my $stem = &stemword2($word,\%stoplist, \%xlist, \%sdict,$stemmer);
			push(@stem_para, $stem) if ($stem ne '');
		}
	
		$stem_para = join(' ', @stem_para);
		
		$stem_wk_definition{$id} = $stem_para;
	}
}

print "Process complete\n";

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

