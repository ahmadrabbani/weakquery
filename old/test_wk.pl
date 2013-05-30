#!/usr/bin/perl -w

use strict;
use warnings;

require "sub/logsub2.pl";
require "sub/spidersub_2010.pl";
require "sub/indxsub_2010.pl";
require "sub/NLPsub_2010.pl";

my $log       = 1;                     # program log flag
my $debug     = 0;                     # debug flag
my $filemode  = 0640;                  # to use w/ perl chmod
my $filemode2 = 640;                   # to use w/ system chmod
my $dirmode   = 0750;                  # to use w/ perl mkdir
my $dirmode2  = 750;                   # to use w/ system chmod (directory)
my $group     = "trec";                # group ownership of files
my $author    = "hz3\@indiana.edu";    # author's email

#my $home_dir = "/home/hz3";
my $home_dir = "/home/huizhang";
my $wpdir = "$home_dir/Desktop/dissertation";    #working directory
my $tpdir = "$home_dir/workspace/epic_prog";    #programming directory
my $qdir = "$wpdir/query";                   #google and wiki output directory

my $stopwordslist = "$tpdir/stoplist2";  # document stopword list
my $subdict="$tpdir/krovetz.lst";        # dictionary subset for stemmer
my $xlist="$tpdir/pnounxlist2";          # proper nouns to exclude from stemming
my $abbrlist=  "$tpdir/abbrlist4";       # abbreviation list
my $pfxlist =  "$tpdir/pfxlist2";        # valid prefix list
my $arvlist=   "$tpdir/dict.arv";        # adjective, adverb, verb
my %qnoun2;

# create hash of adjective, adverb, & verb
my %arvlist;
&mkhash($arvlist,\%arvlist);

# document stopwords
my %stoplist;
&mkhash( $stopwordslist, \%stoplist );

# dictionary subset for combo/krovetz stemmer
my %sdict;
&mkhash($subdict,\%sdict);

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

# stemmer (0=simple, 1=combo, 2=Porter, 3=Krovetz)
my $stemmer = 0;

# gangs of new york
# bank of new york
# new york times square
my $query = "new york times square";
my $qn = 10001;
my $maxhtmN = 2;

# move process query to the beginning
# -----stop and stem query
my @q_words = &getword3($query, \%abbrlist, \%pfxlist, \%stoplist, \%arvlist);
my $stem_query = &procword3(\@q_words, \%stoplist, \%xlist, \%sdict, $stemmer, \%qnoun2);

print $stem_query . "\n";

# takes 5 minutes

print "Starts Wikipedia process\n";

#my $wkcsv_dir = "/media/Elements/en_20080727";

my $wkcsv_dir = "$home_dir/en_20080727";


# -----stop, stem Wikiminer page.csv, save into array
# contains stemmed title, one per element
my @stem_wk_page;
my %stem_wk_page_id;

my $page = "$wkcsv_dir/page.csv";
open( IN, "<$page" ) || die "can't read $page";
my @pages = <IN>;
close IN;
chomp @pages;

foreach my $page (@pages) {
	my ($a, $b, $c) = split(/,/, $page);
	$b =~ s/^"|"$//;
	$c =~ s/^\s+|\s+$//;
	$a =~ s/^\s+|\s+$//;
	
	# article type == 1
	if ($c eq '1'){
		my @b = &getword3($b, \%abbrlist,\%pfxlist,\%stoplist,\%arvlist);
		
		my $stem_b = &procword3(\@b,\%stoplist,\%xlist,\%sdict,0,\%qnoun2);
			
		if ($stem_b eq $stem_query) {
			print $a . ',';
			print $stem_b . "\n";
		}
		
		push (@stem_wk_page, $stem_b);
	
		$stem_wk_page_id{$stem_b} = $a;
	}
}

# -----stop, stem Wikiminer anchor_summary.csv, save into hash
# hash key: anchor text
# value: linked page ids

# new york city is linked to many pages, so only pages that are
# redirected to more than n times should be included when disambiguation

my %stem_wk_anchor;

my $anchor = "$wkcsv_dir/anchor_summary.csv";
open( IN, "<$anchor" ) || die "can't read $anchor";
my @anchors = <IN>;
close IN;
chomp @anchors;

foreach my $anchor (@anchors) {
	my ($a, $b) = split(/,/, $anchor);
	$a =~ s/^"|"$//;
	$b =~ s/^"|"$//;
	my @a = &getword3($a,\%abbrlist,\%pfxlist,\%stoplist,\%arvlist);
	
	my $stem_a = &procword3(\@a,\%stoplist,\%xlist,\%sdict,0,\%qnoun2);
	
	if ($stem_a eq $stem_query) {
		print $b . ',';
		print $stem_a . "\n";
	}
	
	$stem_wk_anchor{$stem_a} = $b;
}

print "Wikipedia process completes\n";



# segment query into n-grams and n-gram contexts
my $ngrams_ref;

# hash key: ngram
# value: contexts (i.e., query without the ngram)
my $contexts_ref;
( $ngrams_ref, $contexts_ref ) = &segmentation($stem_query, \%stoplist, \%xlist, \%sdict, $stemmer);

foreach (@$ngrams_ref){
	print "ngram: " . $_ . "\n";
}

foreach my $key (keys %$contexts_ref){
	print "key: " . $key . ' ' . "context: " . $contexts_ref->{$key} . "\n" if ($contexts_ref->{$key} ne '');
}

#-----------------------------------------------------------
#  segment query into ngrams and contexts
#-----------------------------------------------------------
#  arg1 = stem query
#  arg2 = stoplist ref
#  arg3 = pp ref
#  arg4 = Krovetz ref
#  arg5 = stemmer
#  r.v.1 = @ngrams contains all derived ngrams (n>=2)
#  r.v.2 = %contexts, hash key: ngram, value: query context (i.e., the rest query content) 
#-----------------------------------------------------------
sub segmentation {
	my ( $query, $stopref, $ppref, $stemref, $stemmer ) = @_;
	my ( @ngrams, %contexts );
	
	
	my @stem_words = split(/ /, $query);	
	
	#take ngram: start with the first word, get all ngrams with more than two words, then move to the second word...
	#ngram preserve order and continunity
	#new york, new york times, new york times square
	#york times, york times square
	#times square
	for ( my $i = 0 ; $i < scalar(@stem_words); $i++) {
		for ( my $j = $i + 1 ; $j < scalar(@stem_words); $j++) {
			$stem_words[$i] .= ' ' . $stem_words[$j];

			#print $words[$i] . "\n";
			push( @ngrams, $stem_words[$i] );
		}
	}

	foreach my $ngram (@ngrams) {
		print "query:" . $query . "\n";
		my $result = index( $query, $ngram );

		print $ngram . ':' . $result . "\n";

		my $remain_qry;

		if ( $result == 0 ) {
			#ngram is at the beginning of the query
			if ($ngram eq $query) {
				$remain_qry = '';
			}
			else {
				$remain_qry = substr( $query, length($ngram)+1 ); #remove the leading white space
			}
			
			print $remain_qry . "\n";
			
			# check whether the $remain_qry contains any Wikipedia topic
			# if exist, the context is: "topic" + remain_qry
			foreach my $another (@ngrams) {
				if ( index( $remain_qry, $another ) != -1
					&& $another ne $ngram )
				{
					if (&chkWkTopic($another, \%stem_wk_page_id, \%stem_wk_anchor)>=1){
						$contexts{$ngram} .= '"' . $another . '"' . ' ';
					}
				}
			}
			$contexts{$ngram} .= $remain_qry;
		}
		else {
			$remain_qry =
			    substr( $query, 0, $result-1 )
			  . substr( $query, $result + length($ngram) ); #include a white space in the second part
			  
			print $remain_qry . "\n";
			  
			foreach my $another (@ngrams) {
				if ( index( $remain_qry, $another ) != -1
					&& $another ne $ngram )
				{
					if (&chkWkTopic($another, \%stem_wk_page_id, \%stem_wk_anchor)>=1){
						$contexts{$ngram} .= '"' . $another . '"' . ' ';
					}
				}
			}
			$contexts{$ngram} .= $remain_qry;
		}
	}

	return ( \@ngrams, \%contexts );

}    #end sub segmentation


sub chkWkTopic {
	my ( $query,  $wk_stem_page_id, $wk_stem_anchor ) = @_;
	my $isPage = 0;
	my $isAnchor = 0;
	
	my %wk_stem_page_id = %$wk_stem_page_id;
	my %wk_stem_anchor = %$wk_stem_anchor;
	
	$isPage = 1 if (exists($wk_stem_page_id{$query}));
	
	$isAnchor = 1 if (exists($wk_stem_anchor{$query}));
		
	my $result = $isPage + $isAnchor;
	return $result;

}    #end sub chkWkTopic




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




