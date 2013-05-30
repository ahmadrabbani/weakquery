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

my $home_dir = "/home/hz3"; 
my $pdir = "$home_dir/Desktop/dissertation/prog";
my $wpdir = "$home_dir/Desktop/dissertation";
my $qdir = "$wpdir/query";

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

# gangs of new york
# bank of new york
# new york times square
my $query = 'new york times square';
my $qn = 10001;
my $maxhtmN = 10;
my $dirichlet_smooth = 2500;	#same as Indri
my $lambda = 0.5;
my $MI_threshold = 0.0;

my $gg_hits_dir = "$qdir/segment/gg/hits";    # for search results


# move process query to the beginning
# -----stop and stem query
my $stem_query = '';

my @query_words = split(/ /, $query);
my @stem_query;
foreach my $word (@query_words){
	my $stem = &stemword2($word,\%stoplist, \%xlist, \%sdict,$stemmer);
	push(@stem_query, $stem);
}

$stem_query = join(' ', @stem_query);

print $stem_query . "\n";

# takes 5 minutes

print "Starts Wikipedia process\n";

my $wkcsv_dir = "/media/Elements/en_20080727";

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
	#$b =~ s/\\|\.|,|:|'|//g;
	$c =~ s/^\s+|\s+$//;
	$a =~ s/^\s+|\s+$//;
	
	# article type == 1
	if ($c eq '1'){
		my @b = split(/ /, $b);
	
		my (@stem_b, $stem_b);
		foreach my $word (@b) {
			my $stem = &stemword2($word,\%stoplist, \%xlist, \%sdict, $stemmer);
			push (@stem_b, $stem) if ($stem ne '');
		}
	
		$stem_b = join(' ', @stem_b);
		
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
	#$a =~ s/\\|\.|,|:|'|//g;
	$b =~ s/^"|"$//;
	my @a = split(/ /, $a);
	
	my (@stem_a, $stem_a);
	foreach my $word (@a) {
		my $stem = &stemword2($word,\%stoplist, \%xlist, \%sdict, $stemmer);
		push (@stem_a, $stem) if ($stem ne '');
	}
	
	$stem_a = join(' ', @stem_a);
	
	if ($stem_a eq $stem_query) {
		print $b . ',';
		print $stem_a . "\n";
	}
	
	$stem_wk_anchor{$stem_a} = $b;
}

print "Wikipedia process completes\n";

#search Google
my $htmlcnt = &queryGoogle2( $query, $gg_hits_dir, $qn, $maxhtmN ); #use $query

# read in result links
open( LINK, "$gg_hits_dir/lk$qn" ) || die "can't read $gg_hits_dir/lk$qn";
my @links = <LINK>;
close LINK;
chomp @links;

my $outd_gg = "$gg_hits_dir/q$qn";
if ( !-e $outd_gg ) {
	my @errs = &makedir( $outd_gg, $dirmode, $group );
	print "\n", @errs, "\n\n" if (@errs);
}

# fetch hit pages
my $fn = 1;
foreach my $link (@links) {
	last if ( $fn > $maxhtmN );
	my ( $n, $url ) = split /: /, $link;
	my ( $htm, $title, $body ) = &fetchHTML( $url, $fn );

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


# -----stop, stem google result, save into array
# contains all stemmed words, one word per element
my @google_stem_words;
# contains all stemmer doc content, one doc per element
my @google_stem_docs;

my @files = <$outd_gg/*.txt>;
my $big_line;
my $doc_line;
foreach my $file (@files) {
	open(IN, "<$file") or die "cannot open $file";
	my @lines = <IN>;
	close IN;
	
	chomp @lines;
	
	$big_line .= join(' ', @lines);
	
	$doc_line = join(' ', @lines);
	
	my @ws = split(/ /, $doc_line);
	my @stem_ws;
	foreach my $ws (@ws){
		my $stem_ws = &stemword2($ws,\%stoplist, \%xlist, \%sdict,$stemmer);
		push(@stem_ws, $stem_ws) if ($stem_ws ne '');
	}
	
	push (@google_stem_docs, join(' ', @stem_ws));
}

my @words = split(/ /, $big_line);
foreach my $word (@words){
	my $w = &stemword2($word,\%stoplist, \%xlist, \%sdict,$stemmer);
	push (@google_stem_words, $w) if ($w ne '');
}

my @ngrams = ('new york','new york time', 'new york time square','york time','york time square','time square');
my %contexts = (
	'new york' => '"time square" time square',
	'york time' => 'new square',
	'new york time' => 'square',
	'york time square' => 'new',
	'time square' => '"new york" new york',
);

my $result=
		  &rankSeg( \@ngrams, \%contexts, $dirichlet_smooth, $lambda, \@google_stem_words, \@google_stem_docs, \@stem_wk_page, \%stem_wk_anchor, \%stem_wk_page_id) . '::' . $qn;

sub rankSeg {
	my ( $ngrams_ref, $contexts_ref, $dirichlet_smooth, $lambda, $google_words_ref, $google_docs_ref, $wk_stem_page_ref, $wk_stem_anchor_ref, $wk_stem_page_id_ref )
	  = @_;
	
	my @ngrams = @$ngrams_ref;
	my %contexts = %$contexts_ref;
	
	#hash key: ngram
	#value: ngram probability p(ti|Cti)
	my %rankscore;
	
	# with article type == 1
	my %wk_stem_page_id = %$wk_stem_page_id_ref;
	my %wk_stem_anchor = %$wk_stem_anchor_ref;
	
	#hash key: Wikipedia topic as the aggregation Wikipedia page and anchor
	# value: Wikipedia page id
	my %page_id;
	
	foreach my $topic ( keys %contexts ) {
		
		#use Google to count n(ti,cti)
		# three approaches to count n(ti,cti):
		# with only ngram, with only single words, with both
		
		print $topic . "\n";
		
		my $count_n = &gg_count( $topic, $contexts{$topic}, $google_docs_ref );

		#use Google to count sigma n(ti,cti)
		my $sigma_n = &gg_count_sigma( $contexts{$topic}, $google_docs_ref );
		
		my $pti = 0;
		my $isTopic = &chkWkTopic($topic, $wk_stem_page_id_ref, $wk_stem_anchor_ref);
		if ($isTopic >= 1){
			# pti
			$pti = 1.0/scalar(@$wk_stem_page_ref);
			print "topic: " . $topic . "is a Wikipedia topic with pti" . $pti . "\n";
			
			# get page_id
			if(exists($wk_stem_page_id{$topic})){
				my $id = $wk_stem_page_id{$topic};
				$page_id{$topic} = $id;
			}
			else {
				# should exist as anchor text
				my ($flag, $link_line) = &chkAmbiguation( $topic, $wk_stem_anchor_ref );
			
				if ($flag) {
					# disambiguation
					# get context
				}
				else {
					my ($link, $count) = split(/:/, $link_line);
					$page_id{$topic} = $link;
				}
			}
		}
		else {
			# calculate pti
			$pti = calPti( $topic, $wk_stem_page_ref, $wk_stem_anchor_ref, $lambda );
			print "topic: " . $topic . "is not a Wikipedia topic with pti" . $pti . "\n";
		}
		
		#calculate p(ti|ci) with Dirichlet smoothing
		my $conditional_prob =
		  &calConditionalProb( $pti, $count_n, $sigma_n, $dirichlet_smooth );
		
		print $topic  . ':' . $conditional_prob . "\n";
		
		#assign p(ti|ci) to ti in %rankscore
		$rankscore{$topic} = $conditional_prob;
		
	}# end foreach
	

	

}    #end sub rankSeg

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



sub gg_count {

	my ( $topic, $context, $google_docs_ref ) = @_;
	
	my @google_stem_docs = @$google_docs_ref;
	
	# context: "abc" "xyz" ll mm nn
	my @contexts = split(/ /, $context);
	my $co_count = 0;
	my $doc_has_allcontext;
	
	#topic and context co-occurrence count at doc level
	foreach my $doc (@google_stem_docs){
		# doc that all context appear
		foreach my $context (@contexts){
			$context =~ s/^"|"$// if ($context =~ /^"|"$/);
			if ($doc =~ /\b$context\b/i){
				$doc_has_allcontext = 1;
			}
			else {
				$doc_has_allcontext = 0;
				last;
			}
		}
		if ($doc_has_allcontext){
			my $tf_topic = $doc =~ /\b$topic\b/i;
			$co_count += $tf_topic;
		}
	}
	
	return $co_count;

}    #end sub gg_count

sub gg_count_sigma {
	
	my ($context, $google_docs_ref) = @_;
	
	my @google_stem_docs = @$google_docs_ref;
	
	# context: "abc" "xyz" ll mm nn
	my @contexts = split(/ /, $context);
	
	my $sigma_count = 0;
	
	my $doc_has_allcontext;
	
	foreach my $doc (@google_stem_docs){
		# doc that all context appear
		foreach my $context (@contexts){
			$context =~ s/^"|"$// if ($context =~ /^"|"$/);
			if ($doc =~ /\b$context\b/i){
				$doc_has_allcontext = 1;
			}
			else {
				$doc_has_allcontext = 0;
				last;
			}
		}
		if ($doc_has_allcontext){
			my @words = split (/ /, $doc);
			$sigma_count += scalar(@words);
		}
	}
	
	return $sigma_count;
	
}    #end sub gg_count_sigma

sub calPti {
	my ($topic, $wk_page_ref, $wk_anchor_ref, $lambda) = @_;
	
	# it is array, not hash
	my @wk_stem_page = @$wk_page_ref;
	
	my %wk_stem_anchor = %$wk_anchor_ref;
	
	my @words = split(/ /, $topic);
	
	my $page_line = join (' ', @wk_stem_page);
	my @page_words = split(/ /, $page_line);
	
	my $anchor_line = join(' ', keys %wk_stem_anchor);
	my @anchor_words = split(/ /, $anchor_line);

	my $mle_page = 1.0;
	my $mle_anchor = 1.0;
	
	foreach my $word (@words){
		my $page_count = $page_line =~ /\b$word\b/i;
		my $anchor_count = $anchor_line =~ /\b$word\b/i;
		
		$mle_page *= $page_count/scalar(@page_words);
		print "mle_page" . $mle_page . "\n";
		$mle_anchor *= $anchor_count/scalar(@anchor_words);
		print "mle_anchor" . $mle_anchor . "\n";
	}
	
	return $lambda * $mle_page + (1 - $lambda) * $mle_anchor;
	
}    #end sub calPti

sub calConditionalProb {
	my ($pti, $count_n, $sigma_n, $dirichlet_smoothing) = @_;
	
	return ($count_n + $dirichlet_smoothing * $pti) / ($sigma_n + $dirichlet_smoothing);
	
}    #end sub calConditionalProb

sub mkhash {
	my ( $file, $hp ) = @_;

	open( IN, $file ) || die "can't read $file";
	my @terms = <IN>;
	close IN;
	chomp @terms;
	foreach my $word (@terms) { $$hp{$word} = 1; }

}    #endsub mkhash
