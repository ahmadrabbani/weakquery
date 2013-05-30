#!/usr/bin/perl -w

# --------------------
# query reformulation through topic boundary detection and disambiguation
#	given a keyword query,
#	Question: boundary and meaning of the ngram that represent user information need
#	1. derive query ngrams (n>=2)by segmenting the query at different word boundary
#	2. find query topic by ranking ngram ti by p(ti|Cti) where Cti is the context including other ngrams
#      assumption: topic extraction (boundary and meaning) determined by its context -> the ngram that most likely to occur based on the context is the topic 
# --------------------
# Input:
#	$query::$qn
#	$qn for AOL will be an integer starts 10,000
# Output:
#   $qdir/$subd/gg/hits/rs$qn.htm  -- result page
#   $qdir/$subd/gg/hits/lk$qn     -- hit URLs
#   $qdir/$subd/gg/hits/ti$qn     -- hit titles
#   $qdir/$subd/gg/hits/sn$qn     -- hit snippets
#   $qdir/$subd/gg/hits/$qn/r$n.htm -- hit HTML
#   $qdir/$subd/gg/hits/$qn/r$n.txt -- hit text
#   $qdir/$prog       -- program     (optional)
#   $qdir/$prog.log   -- program log (optional)
#     where $subd= trec|aol
#	  $qn for AOL will be an integer starts 10,000
# Result:
#	"topic:Wikipedia_page_id" "topic_context_ngram:Wikipedia_page_id" ... "topic_context_word:Wikipedia_page_id"::$qn
#	OR
#	"topic" topic_context_word::$qn given no matched Wikipedia_page_id
#	OR
#	original query in single words::$qn given no topic is recognized
#	
#	the ngram in the context is recognized as a topic only when the ngram appear as a Wikipedia title, otherwise it will be considered as single words
#	it is because we donot calculate p(ti|Cti) to ngrams in context, therefore cannot tell whether the ngram is valid 
#	check Wikipedia page id with single context word
#	there could be mltiple topics per query given p(ti|Cti) is close to top score or above threshold
# --------------------
# P(ti|Cti)MLE Dirichlet smoothing: A Study of Smoothing Methods for Language Models Applied to Ad Hoc Information Retrieval Zhai and Laffery (2001)
# topic context includes contained ngrams and single words:
# count_n: topic tf in Google docs where all contexts appear
# sigma_n: Google doc length where all contexts appear
# topic must be multiple word, but a single word query or context also need to check whether it is a Wikipedia 
# --------------------
# assumption:
#	1. topic must be a ngram
#	2. topic preserve the string order and continunity 
#		e.g., female bus driver produces female bus, female bus driver, and bus driver, but NOT female driver
# --------------------
# ver1.0	3/17/2011
#	Use dirichlet smoothing to relax MLE p(ti|Cti)
#	p(ti) = pmle(ti|wk)= lambda*pmle(ti|title) + (1-lambda)*pmle(ti|anchor)
# ver1.1	4/25/2011
# ver2.0    6/26/2011
#	Create Wikipedia DB by importing Wikipedia csv to MySQL
#	Use MySQL Wikipedia for topic detection 
# --------------------
# update based on test results 5/19/2011
# update stemword to use getword3 and procword3
# --------------------
# TODO:
#	update result: one query only has one segmentation ranked by p(ti|Cti) now, the program will: 
#   1. produce multiple segmentations given their p(ti|Cti) is above threshold
#   implement two different ranking approaches:
#   2. based on the Wikipedia topic in each segmentation including context topics, if the number is same, use the sum p(ti) where ti refers to any n-gram in the segmentation
#   3. based on the sum p(ti) where ti refers to any n-gram in the segmentation (default)
#	tune: Dirichlet smoothing, lambda, topic threshold, MI_threshold
# --------------------
# Complete:
#	update count_n and sigma_n
#	update segByMI on only bigram is topic
# --------------------

use strict;
use warnings;

use LWP::Simple;
use WWW::Wikipedia;
use LWP::UserAgent;
use WWW::Mechanize;
use DBI;

my ( $debug, $filemode, $filemode2, $dirmode, $dirmode2, $author, $group );
my ( $log, $logd, $sfx, $noargp, $append, @start_time );

$log       = 1;                     # program log flag
$debug     = 0;                     # debug flag
$filemode  = 0640;                  # to use w/ perl chmod
$filemode2 = 640;                   # to use w/ system chmod
$dirmode   = 0750;                  # to use w/ perl mkdir
$dirmode2  = 750;                   # to use w/ system chmod (directory)
$group     = "trec";                # group ownership of files
$author    = "hz3\@indiana.edu";    # author's email

# ----------------
# global variable
# ----------------

my $home_dir = "/home/huizhang";
my $wkcsv_dir = "$home_dir/en_20080727";      # wikiminer directory

#my $home_dir = "/home/hz3";
#my $wkcsv_dir = "/media/Elements/en_20080727";      # wikiminer directory


my $wpdir = "$home_dir/Desktop/dissertation";    #working directory
my $tpdir = "$home_dir/workspace/epic_prog";    #programming directory
my $qdir = "$wpdir/query";                   #google and wiki output directory

#TODO:
# dirichlet_smoothing: conditional probability p(ti|Cti)
# lambda: linear interpolation weight p(ti) = lambda*p(ti|title)+(1-lambda)*p(ti|anchor)
my $maxhtmN = 10;
my $dirichlet_smooth = 2500;	#same as Indri
my $lambda = 0.5;
my $MI_threshold = 0.0;

require "$tpdir/sub/logsub2.pl";
require "$tpdir/sub/spidersub_2010.pl";
require "$tpdir/sub/indxsub_2010.pl";
require "$tpdir/sub/NLPsub_2010.pl";

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

my $gg_hits_dir = "$qdir/segment/gg/hits";    # for search results
my $wk_hits_dir = "$qdir/segment/wk/hits";    # for Wikipedia search results

my @outdir = ("$gg_hits_dir");
foreach my $outdir (@outdir) {
	if ( !-e $outdir ) {
		my @errs = &makedir( $outdir, $dirmode, $group );
		print "\n", @errs, "\n\n" if (@errs);
	}
}

my @outdir1 = ("$wk_hits_dir");
foreach my $outdir (@outdir1) {
	if ( !-e $outdir ) {
		my @errs = &makedir( $outdir, $dirmode, $group );
		print "\n", @errs, "\n\n" if (@errs);
	}
}

#------------------------
# program arguments
#------------------------

#my $input = join( ' ', @ARGV );
#my ( $query, $qn ) = split( '::', $input );
#$query =~ s/^\s+|\s+$//;
#$qn    =~ s/^\s+|\s+$//;


my $query = 'new york times square';
my $qn = 10001;

# ---------------
# start program log
# ---------------

$sfx    = 't';    # test
$noargp = 1;      # if 1, do not print arguments to log
$append = 0;      # log append flag

if ($log) {
	@start_time = &begin_log( $qdir, $filemode, $sfx, $noargp, $append );
	print LOG "Infile  = $query, $qn\n",
	  "Outfile = $gg_hits_dir/rs\$qn.htm, ti\$qn, sn\$qn, lk\$qn\n",
	  "          $gg_hits_dir/q\$qn/r\$N.htm, r\$N.txt\n\n",
	  "			 $wk_hits_dir\n";
}

# ---------------
# main program
# ---------------

# move process query to the beginning
# -----stop and stem query
my @q_words = &getword3($query, \%abbrlist, \%pfxlist, \%stoplist, \%arvlist);
my $stem_query = &procword3(\@q_words, \%stoplist, \%xlist, \%sdict, $stemmer, \%qnoun2);
print LOG "stem query:" . $stem_query . "\n";


print LOG "\nStarting Google search --- ", timestamp(0), "\n\n";

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
my $big_line = '';
my $doc_line = '';
foreach my $file (@files) {
	open(IN, "<$file") or die "cannot open $file";
	my @lines = <IN>;
	close IN;
	
	chomp @lines;
	
	$big_line .= join(' ', @lines);
	
	$doc_line = join(' ', @lines);
	
	my @ws = &getword3($doc_line, \%abbrlist, \%pfxlist, \%stoplist, \%arvlist);
		
	my $stem_ws = &procword3(\@ws, \%stoplist, \%xlist, \%sdict, $stemmer, \%qnoun2);
	
	push (@google_stem_docs, $stem_ws);
}

my @b_ws = &getword3($big_line, \%abbrlist, \%pfxlist, \%stoplist, \%arvlist);
my $b_ws = &procword3(\@b_ws, \%stoplist, \%xlist, \%sdict, $stemmer, \%qnoun2);
my @words = split(/ /, $b_ws);
foreach my $word (@words){
	push (@google_stem_words, $word) if ($word ne '');
}


print LOG "\nStarting Wikipedia process step 1 --- ", timestamp(0), "\n\n";

# takes 5 minutes
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
	
		push (@stem_wk_page, $stem_b);
	
		$stem_wk_page_id{$stem_b} = $a;
	}
}


# -----stop, stem Wikiminer anchor_summary.csv, save into hash
# hash key: anchor text
# value: linked page ids
# new york city is linked to many pages, so only pages that are
# redirected to more than n times should be included as word sense
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
	
	$stem_wk_anchor{$stem_a} = $b;
}


print LOG "\nStarting Wikipedia process step 2 --- ", timestamp(0), "\n\n";

# takes 20 minute with 6gb memory
# -----stop, stem Wikiminer definition.csv, save into hash
# hash key: page id
# value: leading paragraph
my %stem_wk_definition;

my $definition = "$wkcsv_dir/definition.csv";
open( IN, "<$definition" ) || die "can't read $definition";
my @definitions = <IN>;
close IN;
chomp @definitions;

foreach my $definition (@definitions) {
	my ($id, $sentence, $paragraph) = split(/\t/, $definition);
	$id =~ s/^\s+|\s+$//;
	if ($paragraph ne '') {
		$paragraph =~ s/^\s+|\s+$//;
		my @words = &getword3($paragraph,\%abbrlist,\%pfxlist,\%stoplist,\%arvlist);
		
		my $stem_para = &procword3(\@words,\%stoplist,\%xlist,\%sdict,0,\%qnoun2);
	
		$stem_wk_definition{$id} = $stem_para;
	}
}


print LOG "\nStarting query segmentation --- ", timestamp(0), "\n\n";

# start segmentation
# "topic:Wikipedia_page_id" "topic_context_ngram:Wikipedia_page_id" ... topic_context_words::$qn
#	OR
#	original query in single word given no topic is recognized
my $result = '';

my $isWkTopic = 0;
$isWkTopic = &chkWkTopic( $stem_query, \%stem_wk_page_id, \%stem_wk_anchor );

# add query Wkipedia page id
# separated by ':' inside quotation
# e.g., "bush:62343"
if ($isWkTopic >= 1) {
	my $id = '';
	if(exists($stem_wk_page_id{$stem_query})){
		$id = $stem_wk_page_id{$stem_query};
	}
	elsif (exists($stem_wk_anchor{$stem_query})){
		my ($flag, $line) = &chkAmbiguation($stem_query, \%stem_wk_anchor);
		if ($flag){
			# no context, use the most common sense
			my @b = split(/;/, $line);
			my $base_count = 1;
			foreach my $b (@b){
				my ($link, $count) = split(/:/, $b);
				if ($count > $base_count){
					$base_count = $count;
					$id = $link;
				}
			}
		}
		else {
			my ($link, $count) = split(/:/, $line);
			$id = $link;
		}
	}
	
	if (length($id) > 0 && $id =~ /\d+/){
		$result = '"' . $stem_query . ':' . $id . '"' . '::' . $qn;
	}
	else {
		print LOG "Error!!!$stem_query is a Wikipedia topic but cannot find page id\n";
	}
}
else {
	# query (single or multiple word) is NOT a Wikipedia topic
	# topic detection via segment and disambiguate ngrams
	my @words = split( / /, $stem_query );
	
	if ( scalar(@words) == 1 ) {
		# not a Wikipedia topic and not has context
		$result = $stem_query . '::' . $qn;
		print LOG "$stem_query has one word and is NOT a Wikipedia topic\n";
	}
	elsif ( scalar(@words) == 2 ) {
		$result = &segByMI( $stem_query, \@google_stem_words, \%stem_wk_page_id, \%stem_wk_anchor, $MI_threshold ) . '::' . $qn;
	}
	elsif ( scalar(@words) > 2 ) {

		# segment query into n-grams and n-gram contexts
		my $ngrams_ref;

		# hash key: ngram
		# value: contexts (i.e., query without the ngram)
		my $contexts_ref;
		( $ngrams_ref, $contexts_ref ) = &segmentation($stem_query, \%stem_wk_page_id, \%stem_wk_anchor);
		
		print LOG "\nStarting query segmentation ranking --- ", timestamp(0), "\n\n";
		
		#TODO: rank the ngrams based on co-occurrence with their contexts in Google and Wikipedia
		$result=
		  &rankSeg( $ngrams_ref, $contexts_ref, $dirichlet_smooth, $lambda, \@google_stem_words, \@google_stem_docs, \@stem_wk_page, \%stem_wk_anchor, \%stem_wk_definition, \%stem_wk_page_id) . '::' . $qn;
	}
}

print LOG "\nProduce result --- ", timestamp(0), "\n\n";
print LOG $query . ":" . $result . "\n";


# ----------------
# end program
# ----------------

print LOG "\nProcessed $qn queries\n\n";
&end_log( $wpdir, $qdir, $filemode, @start_time ) if ($log);

# ---------------
# subroutines
# ---------------

#-----------------------------------------------------------
#  check whether the query is a Wikipedia topic or anchor
#-----------------------------------------------------------
#  arg1 = query
#  arg2 = wk_stem_page_id reference
#  arg3 = wk_stem_anchor reference
#  r.v. = >=1 if is a Wikipedia topic, 0 if otherwise
#-----------------------------------------------------------
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
#  rank the ngrams based on co-occurrence with their contexts in Google and Wikipedia
#-----------------------------------------------------------
#  arg1 = ngram array
#  arg2 = ngram hash
#  arg3 = Dirichlet smoothing
#  arg4 = lambda
#  arg5 = google stem words array reference
#  arg6 = google stem doc array reference
#  arg7 = wk stem page array reference
#  arg8 = wk stem anchor reference
#  arg9 = wk stem definition reference
#  arg10 = wk stem page id reference
#  r.v.1 = %ngrams_score
#  r.v.2 = %ngrams_wk_page
#-----------------------------------------------------------
#  ok to have white space between words with word boundary match
#  simple stemmer will take care normal non-word characters
#-----------------------------------------------------------
sub rankSeg {
	my ( $ngrams_ref, $contexts_ref, $dirichlet_smooth, $lambda, $google_words_ref, $google_docs_ref, $wk_stem_page_ref, $wk_stem_anchor_ref, $wk_stem_definition_ref, $wk_stem_page_id_ref )
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
		my $count_n = &gg_count( $topic, $contexts{$topic}, $google_docs_ref );

		#use Google to count sigma n(ti,cti)
		my $sigma_n = &gg_count_sigma( $contexts{$topic}, $google_docs_ref );
		
		my $pti = 0;
		my $isTopic = &chkWkTopic($topic, $wk_stem_page_id_ref, $wk_stem_anchor_ref);
		if ($isTopic >= 1){
			# pti
			$pti = 1.0/scalar(@$wk_stem_page_ref);
			
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
					if (!exists($contexts{$topic})){die "No context is found with topic: $topic\n";}
					my $context = $contexts{$topic};
					if ($context == ''){die "Context is null or empty with topic:$topic\n";}
				
					my $page_id = &wikiDisambiguation( $topic, $context, $wk_stem_definition_ref, $link_line );
					$page_id{$topic} = $page_id;
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
		}
		
		#calculate p(ti|ci) with Dirichlet smoothing
		my $conditional_prob =
		  &calConditionalProb( $pti, $count_n, $sigma_n, $dirichlet_smooth );
		
		#assign p(ti|ci) to ti in %rankscore
		$rankscore{$topic} = $conditional_prob;
		
	}# end foreach
	
	#TODO: get the most appropriate query segmentation by p(ti|Cti)
	# all ngrams (ti, and ngrams in context): get the Wikipedia page id
	# the result:dissertation TREC 
	#	segmented query with topic wrapped in quoatation and single word context separated by white space
	#	add topic Wkipedia page id separated by ':' inside quotation
	# 	e.g., "bush:62343"
	# 	"new york:id1" "times square:id2" building
	my $seg_result = '';
	
	my @ranked_topic = sort {$rankscore{$b} <=> $rankscore{$a}} keys %rankscore;
	print LOG "ranked query topics: @ranked_topic\n";
	
	# top three topics
	my @top_topic = @ranked_topic[0,2];
	
	foreach my $top_topic (@top_topic){
		my $top_topic_context = $contexts{$top_topic};
	
		my $context_result = '';
		# context can be mixed with Wikipedia topic wrapped with quotation and single word
		# e.g., "times square" building
		my @context_terms = split(/ /, $top_topic_context);
		foreach my $term (@context_terms){
			if ($term =~ /^".*?"$/){
				$term =~ s/^"|"$//; 
			}
			my $id = '';
			if(exists($stem_wk_page_id{$term})){
				$id = $stem_wk_page_id{$term};
			}
			elsif (exists($stem_wk_anchor{$term})){
				my ($flag, $line) = &chkAmbiguation($term, $wk_stem_anchor_ref);
				if ($flag){
					# no context, use the most common sense
					my @b = split(/;/, $line);
					my $base_count = 1;
					foreach my $b (@b){
						my ($link, $count) = split(/:/, $b);
						if ($count > $base_count){
							$base_count = $count;
							$id = $link;
						}
					}
				}
				else {
					my ($link, $count) = split(/:/, $line);
					$id = $link;
				}
			}
	
			if (length($id) > 0 && $id =~ /\d+/){
				$context_result .= '"' . $term . ':' . $id . '"' . ' '; 
			}
			else {
				$context_result .= '"' . $stem_query . '"' . ' ';
			}
		}# end foreach context_terms
	
		# top_topic is not necessarily Wikipedia topic
		my $isTopic = &chkWkTopic($top_topic, $wk_stem_page_id_ref, $wk_stem_anchor_ref);
		if ($isTopic >= 1){
			$seg_result .= '"' . $top_topic . ':' . $page_id{$top_topic} . '"' . ' ' . $context_result;
		}
		else {
			$seg_result .= '"' . $top_topic . '"' . ' ' . $context_result;
		}
	}#end foreach topic
	
	
	
	return $seg_result;

}    #end sub rankSeg

#-----------------------------------------------------------
#  count co-occurrence topic and query context
#-----------------------------------------------------------
#  arg1 = topic
#  arg2 = query context of the topic in topics and single words
#  arg3 = google docs array reference
#  r.v. = number that topic co-occur with the context in google result
#-----------------------------------------------------------
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

#-----------------------------------------------------------
#  count co-occurrence topic and all possible query context (i.e., document length where topic appears)
#-----------------------------------------------------------
#  arg1 = topic context
#  arg2 = google docs reference
#  r.v. = total document length where the topic appears
#-----------------------------------------------------------
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

#-----------------------------------------------------------
#  check whether topic is a polysemy
#-----------------------------------------------------------
#  arg1 = topic
#  arg2 = Wikipedia anchor reference
#  r.v.1 = 1: the topic is a polysemy 0: the topic is not a polysemy
#  r.v.2 = linked page ids
#-----------------------------------------------------------
sub chkAmbiguation {
	my ($topic, $wk_anchor_ref) = @_;
	my $isPolysemy = 0;
	my $line = '';
	
	my %wk_stem_anchor = %$wk_anchor_ref;
	
	foreach my $anchor (keys %wk_stem_anchor){
		if ($anchor eq $topic) {
			$isPolysemy = 1 if ($wk_stem_anchor{$anchor} =~ /;/);
			$line = $wk_stem_anchor{$anchor};
			last;
		}
	}
	
	return ($isPolysemy, $line);

}    #end sub chkAmbiguation

#-----------------------------------------------------------
#  disambiguate a polysemy topic with Wikipedi anchor
#-----------------------------------------------------------
#  arg1 = topic
#  arg2 = context
#  arg3 = Wikipedia definition reference
#  atg4 = string page ids
#  r.v. = the polysemy topic's page id
#-----------------------------------------------------------
#  TODO: use the most common sense in case there is no context
#-----------------------------------------------------------
sub wikiDisambiguation {
	# sense inventory: link page ids
	# sense definition: Wikipeda definition
	# use context to decide the most appropriate topic sense
	
	
	# topic: time square
	# context: "new york" new york
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
	
	# hash key: word appears in the page id
	# value: word distribution ratio as tf in this sense divide by tf in all other senses
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
	
	#my $sense_context = '';
	
	#if (index($context, '"') != -1){
	#	my @context_ngrams = split(/\" /, $context);
		# single word context is behind ngram context
		# based on sub segmnentation
				
		# get single word context
	#	my $context_word = pop(@context_ngrams);
	#	$sense_context = $context_word;		
	#}
	#else {
	#	$sense_context = $context;
	#}
	
	my @contexts = split(/ /, $context);
	
	foreach my $link (@link_pages){
		my ($id, $num) = split(/:/, $link);
		my $feature_ref = $sense_represent{$id};
		my $score = 0;
		foreach my $word (@contexts){
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

#-----------------------------------------------------------
#  calculate topic probability
#  P(ti) <=> P(ti|wk) = lambda*Pmle(ti|wk_title) + (1-lambda)*Pmle(ti|wk_anchor)
#  Pmle(ti|M) = Pmle(w1|M)*Pmle(w2|M)...*P(wn|M) where w1,w2...wn belong ti
#-----------------------------------------------------------
#  arg1 = topic
#  arg2 = Wikipedia page reference
#  arg3 = Wikiopeda anchor reference
#  arg3 = lambda
#  r.v. = Pti: topic probability
#-----------------------------------------------------------
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

	my ($mle_page, $mle_anchor) = 1.0;
	
	foreach my $word (@words){
		my $page_count = $page_line =~ /\b$word\b/i;
		my $anchor_count = $anchor_line =~ /\b$word\b/i;
		
		$mle_page *= $page_count/scalar(@page_words);
		$mle_anchor *= $anchor_count/scalar(@anchor_words);
	}
	
	return $lambda * $mle_page + (1 - $lambda) * $mle_anchor;
	
}    #end sub calPti


#-----------------------------------------------------------
#  calculate conditional probability between query topic and its context
#  p(ti|cti) = (count_n + dirichlet smoothing*Pti) / (sigma_n + dirichlet smoothing)
#  P(ti) <=> P(ti|wk) = lambda*Pmle(ti|wk_title) + (1-lambda)*Pmle(ti|wk_anchor)
#  Pmle(ti|M) = Pmle(w1|M)*Pmle(w2|M)...*P(wn|M) where w1,w2...wn belong ti
#  it combines Google and Wikipedia to estimate the conditional probability
#  see more details in "Introduction to Information Retrieval" Chapter 12.2.2 (p.224)
#-----------------------------------------------------------
#  arg1 = topic probability
#  arg2 = number that topic co-occur with the context in google result
#  arg3 = count co-occurrence topic and all possible query context (i.e., document length where topic appears)
#  arg4 = Dirichlet smoothing
#  r.v. = conditional probability between query topic and its context
#-----------------------------------------------------------
sub calConditionalProb {
	my ($pti, $count_n, $sigma_n, $dirichlet_smoothing) = @_;
	
	return ($count_n + $dirichlet_smoothing * $pti) / ($sigma_n + $dirichlet_smoothing);
	
}    #end sub calConditionalProb


#-----------------------------------------------------------
#  segment query into ngrams and contexts
#-----------------------------------------------------------
#  arg1 = query
#  arg2 = stoplist ref
#  arg3 = pp ref
#  arg4 = Krovetz ref
#  arg5 = stemmer
#  r.v.1 = @ngrams contains all derived ngrams (n>=2)
#  r.v.2 = %contexts, hash key: ngram, value: query context (i.e., the rest query content) 
#-----------------------------------------------------------
sub segmentation {
	my ( $query, $stem_wk_page_id, $stem_wk_anchor ) = @_;
	my ( @ngrams, %contexts );
	
	my @stem_words = split( / /, $query );
	
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
		my $result = index( $query, $ngram );

		#print $ngram . ':' . $result . "\n";
		
		my $remain_qry;

		if ( $result == 0 ) {
			#ngram is at the beginning of the query
			if ($query eq $ngram){
				$remain_qry = '';
			}
			else {
				$remain_qry = substr( $query, length($ngram)+1 ); #remove the leading white space
			}

			# check whether the $remain_qry contains any Wikipedia topic
			# if exist, the context is: "topic" + remain_qry
			foreach my $another (@ngrams) {
				if ( index( $remain_qry, $another ) != -1
					&& $another ne $ngram )
				{
					if (&chkWkTopic($another, $stem_wk_page_id, $stem_wk_anchor)>=1){
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
			foreach my $another (@ngrams) {
				if ( index( $remain_qry, $another ) != -1
					&& $another ne $ngram )
				{
					if (&chkWkTopic($another, $stem_wk_page_id, $stem_wk_anchor)>=1){
						$contexts{$ngram} .= '"' . $another . '"' . ' ';
					}
				}
			}
			$contexts{$ngram} .= $remain_qry;
		}
	}

	return ( \@ngrams, \%contexts );

}    #end sub segmentation

#-----------------------------------------------------------
#  examine whether the bigram is topic
#-----------------------------------------------------------
#  arg1 = bigram
#  arg2 = google all stem words array
#  arg3 = Wikipedia id page reference
#  arg4 = Wikipedia anchor reference
#  arg5 = MI threshold
#  r.v. = bigram segmentation
#-----------------------------------------------------------
sub segByMI {

	# check bigram in the order:
	# 1. a Wikipedia topic
	# 2. calculate MI
	# 3. whether each word is a Wikipedia topic

	my ( $bigram, $google_stem_words_ref, $wk_stem_page_id_ref, $wk_stem_anchor_ref, $threshold ) = @_;
	my %stem_wk_page_id = %$wk_stem_page_id_ref;
	my %stem_wk_anchor = %$wk_stem_anchor_ref;
	
	# is bigram a Wikipedia topic
	my $id = '';
	if(exists($stem_wk_page_id{$bigram})){
		$id = $stem_wk_page_id{$bigram};
	}
	elsif (exists($stem_wk_anchor{$bigram})){
		my ($flag, $line) = &chkAmbiguation($bigram, $wk_stem_anchor_ref);
		if ($flag){
			# no context, use the most common sense
			my @b = split(/;/, $line);
			my $base_count = 1;
			foreach my $b (@b){
				my ($link, $count) = split(/:/, $b);
				if ($count > $base_count){
					$base_count = $count;
					$id = $link;
				}
			}
		}
		else {
			my ($link, $count) = split(/:/, $line);
			$id = $link;
		}
	}
	
	
	my ( $w1, $w2 ) = split( / /, $bigram );
	
	# decide whether the bigram should be considered as collocation
	# by calculating freuqency-weighted MI using Google results
	# MI = log(N*C(w1,w2)/(C(w1)*C(w2)))/log2
	my @google_words = @$google_stem_words_ref;
	
	my $match = 0;
	
	my $big_line = join (' ', @google_words);

	# count cooccurrence in window with size 5
	for ( my $i = 1 ; $i < scalar(@google_words) ; $i += 5 ) {
		my $str = join( ' ', @google_words[ $i .. $i + 4 ] );
		$match++ if ( $str =~ /\b$w1\b/i && $str =~ /\b$w2\b/i );
	}

	#my @match = $big_str =~ /(\b$w1\b)( )(\b$w2\b)/i;
	my @w1 = $big_line =~ /(\b$w1\b)/i;
	my @w2 = $big_line =~ /(\b$w2\b)/i;

	# mi_value = freq(w1,w2)*MI(w1,w2)
	my $mi_value =
	  $match * log( scalar(@words) * $match / ( scalar(@w1) * scalar(@w2) ) ) /
	  log(2);

	my $bigram_seg = '';
	
	if (length($id) > 0 && $id =~ /\d+/){
		$bigram_seg = '"' . $bigram . ':' . $id . '"' . ' ';
	}
	else {
		$bigram_seg = '"' . $bigram . '"' . ' ';
	}
	
	# check context
	foreach my $word (split/ /, $bigram){
		my $id = '';
		if(exists($stem_wk_page_id{$word})){
			$id = $stem_wk_page_id{$word};
		}
		elsif (exists($stem_wk_anchor{$word})){
			my ($flag, $line) = &chkAmbiguation($word, $wk_stem_anchor_ref);
			if ($flag){
				# no context, use the most common sense
				my @b = split(/;/, $line);
				my $base_count = 1;
				foreach my $b (@b){
					my ($link, $count) = split(/:/, $b);
					if ($count > $base_count){
						$base_count = $count;
						$id = $link;
					}
				}
			}
			else {
				my ($link, $count) = split(/:/, $line);
				$id = $link;
			}
		}
	
		if (length($id) > 0 && $id =~ /\d+/){
			$bigram_seg .= '"' . $word . ':' . $id . '"' . ' ';
		}
		else {
			$bigram_seg .= '"' . $word . '"' . ' ';
		}
	}# end foreach word


	return $bigram_seg;

}    #end sub segByMI

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
