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
#	- Use original query/topic with calPti, chkAmbiguation, segmentation, segByMI, wikiDisambiguation, rankSeg
#	and all MySQL get subroutines to match Wikipedia title/anchor. Use original query/topic with gg_coint and gg_count_sigma but
#	need be stemmed to match with Google results
#	- calConditionalProb smoothes the P(ti) calcualted by calPti
#	- Mysql subroutines: 
#
#		getPageid: $query is a Wikipedia title and page_type == 1
#		getAntoid: $query is a Wikipedia anchor and if multiple an_to, use the one with largest an_count
#		getMysqlTopic:
#		getMysqlPageTopic: 
#		getMysqlAnchorTopic:
#		getPagelinkIn: $id is a Wikipedia an_to
#		getDefById: $id is a Wikipedia page id or an_to
#		calTf($term, $paragraph): 
#		calOverlapLink($ary_ref, $sense_as_links{$an_to}):
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


my $home_dir = "/home/hz3";
#my $home_dir = "/home/huizhang";
#my $wpdir = "$home_dir/Desktop/dissertation";    #working directory
my $wpdir = "$home_dir/workspace/epic_prog";    #working directory
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
    my ($word)=split(/-/, $_);
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
# Start MySQL
#------------------------

my $database = "en_20110526";
my $hostname = "localhost";
my $port = "3306"; 
my $user = "root";
my $password = "hziub1972";
	
#Not use REGEXP and LIKE with stemmed words in select
#Wikipedia database preserves the original word form in page and anchor table
#to find exact match, use the following three topic forms in order with the first match:
#1. original query and/or topic (NOT stop and stemmed), 2. original query/topic with only the first character in the first word in Uppercase(Ucfirst(string))
#3. original query/topic with first character in all words in uppercase
	
my $dbh = DBI->connect("DBI:mysql:database=$database;host=$hostname", $user, $password) || die "cannot connect to database:" . DBI->errstr;

# ---------------
# start program log
# ---------------

$sfx    = 't';    # test
$noargp = 1;      # if 1, do not print arguments to log
$append = 0;      # log append flag
	
if ($log) {
	@start_time = &begin_log( $qdir, $filemode, $sfx, $noargp, $append );
	print LOG "\nStarting Wikipedia database: $database connection", timestamp(0), "\n\n";
}


#------------------------
# program arguments
#------------------------

#my $input_file = "$home_dir/Desktop/dissertation/data/segments/segments.greater4.train.run";
my $input_file = "$home_dir/Desktop/dissertation/data/topics/06-08.all-blog-topics.run";
open(IN, "<$input_file") || die "cannot open $input_file\n";
my @lines = <IN>;
close IN;
chomp(@lines);

my $qn = 1;
foreach (@lines){
	#my ($a, $b) = split(/\t/, $_);
	#$a =~s/"//g;
	#my $query = $a;
	#$query =~ s/'s//g;
	
	my $query;
	if ($_ =~ /"/){
		$_ =~ s/"//g;
		$_ =~ s/'s/\\'s/g;
		$_ =~ s/,//g if ($_ =~ /,/);
		$query = $_;
	} 
	else {
		$_ =~ s/'s/\\'s/g;
		$_ =~ s/,//g if ($_ =~ /,/);
		$query = $_;
	}
	
	print LOG "Infile  = $query, $qn\n",
		  "Outfile = $gg_hits_dir/rs\$qn.htm, ti\$qn, sn\$qn, lk\$qn\n",
		  "          $gg_hits_dir/q\$qn/r\$N.htm, r\$N.txt\n\n",
		  "			 $wk_hits_dir\n";

	# ---------------
	# main program
	# ---------------
	
	# move process query to the beginning
	# -----stop and stem query
	my @q_words = &getword3($query, \%abbrlist, \%pfxlist, \%stoplist, \%arvlist);
	my $stem_query = &procword3(\@q_words, \%stoplist, \%xlist, \%sdict, $stemmer, \%qnoun2);
	print LOG "Stemmed query:" . $stem_query . "\n\n";
	
	print LOG "\nStarting query segmentation --- ", timestamp(0), "\n\n";
	# start segmentation
	# "topic:Wikipedia_page_id" "topic_context_ngram:Wikipedia_page_id" ... topic_context_words::$qn
	#	OR
	#	original query in single word given no topic is recognized
	my $result = '';
	
	#check whether the whole query is a Wikipedia title
	#use original query
	
	#condition: $query is a Wikipedia title and page_type == 1
	my $page_id = &getPageid($query);
	#condition: $query is a Wikipedia anchor and if multiple an_to, use the one with largest an_count
	my $an_to_id = &getAntoid($query);
	
	# add query Wkipedia page id
	# separated by ':' inside quotation
	# e.g., "bush:62343"
	if (length($page_id) >0 && $page_id =~ /\d+/) {
		$result = '"' . $query . ':' . $page_id . '"' . '::' . $qn;
	}
	elsif (length($an_to_id) >0 && $an_to_id =~ /\d+/) {
		#if the query appear as both title and anchor, take title
		$result = '"' . $query . ':' . $an_to_id . '"' . '::' . $qn;
	}
	else {
		# query (single or multiple word) is NOT a Wikipedia topic
		# topic detection via segment and disambiguate ngrams
		
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
			my ( $n, $url ) = split (/: /, $link);
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
		}	#end foreach
		
		my @b_ws = &getword3($big_line, \%abbrlist, \%pfxlist, \%stoplist, \%arvlist);
		my $b_ws = &procword3(\@b_ws, \%stoplist, \%xlist, \%sdict, $stemmer, \%qnoun2);
		my @b_words = split(/ /, $b_ws);
		foreach my $word (@b_words){
			push (@google_stem_words, $word) if ($word ne '');
		}
		
		# remove stopword
		$query =~ s/\bthe\b|\bon\b|\band\b|\bfor\b|\bin\b|\bof\b//g;
		
		my @words = split( / /, $query );
		
		if ( scalar(@words) == 1 ) {
			# not a Wikipedia topic and not has context
			$result = $query . '::' . $qn;
			print LOG "Not processed! $query has one word and is NOT a Wikipedia topic\n\n";
		}
		elsif ( scalar(@words) == 2 ) {
			#$result = &segByMI( $stem_query, \@google_stem_words, \%stem_wk_page_id, \%stem_wk_anchor, $MI_threshold ) . '::' . $qn;
			$result = &segByMI( $query, $stem_query, \@google_stem_words, $MI_threshold ) . '::' . $qn;
		}
		elsif ( scalar(@words) > 2 ) {
	
			# segment query into n-grams and n-gram contexts
			my $ngrams_ref;
	
			# hash key: ngram
			# value: contexts (i.e., query without the ngram)
			my $contexts_ref;
			#( $ngrams_ref, $contexts_ref ) = &segmentation($stem_query, \%stem_wk_page_id, \%stem_wk_anchor);
			( $ngrams_ref, $contexts_ref ) = &segmentation($query);
			
			print LOG "\nStarting query segmentation ranking --- ", timestamp(0), "\n\n";
			
			#TODO: rank the ngrams based on co-occurrence with their contexts in Google and Wikipedia
			#$result= &rankSeg( $ngrams_ref, $contexts_ref, $dirichlet_smooth, $lambda, \@google_stem_words, \@google_stem_docs, \@stem_wk_page, \%stem_wk_anchor, \%stem_wk_definition, \%stem_wk_page_id) . '::' . $qn;
			$result= &rankSeg( $ngrams_ref, $contexts_ref, $dirichlet_smooth, $lambda, \@google_stem_words, \@google_stem_docs) . '::' . $qn;
		}
	}	#end if-else
	
	print LOG "\nProduce result --- ", timestamp(0), "\n\n";
	print LOG "Original query:" . $query . "\n" . "Segmented query:" . $result . "\n\n";
	$qn++;
}	#end foreach


# ----------------
# end program
# ----------------

print LOG "\nProcessed $qn queries\n\n";
&end_log( $wpdir, $qdir, $filemode, @start_time ) if ($log);

# ---------------
# subroutines
# ---------------

#-----------------------------------------------------------
#  check whether the string is a Wikipedia topic or anchor
#-----------------------------------------------------------
#  arg1 = original query
#  r.v. = >=1 if is a Wikipedia topic, 0 if otherwise
#-----------------------------------------------------------
sub chkWkTopic {
	my $query = shift(@_);
	my $result = 0;
	#print LOG "Enter chkWkTopic:" . ' ' . $query . "\n\n";
	#condition: $query is a Wikipedia title and page_type == 1
	#getPageid should call getMysqlPageTopic at the beginning
	my $page_id = &getPageid($query);
	#condition: $query is a Wikipedia anchor and if multiple an_to, use the one with largest an_count
	#getAntoid should call getMysqlAnchorTopic at the beginning
	my $an_to_id = &getAntoid($query);
	#print LOG "query: $query" . "page_id: $page_id" . "an_to_id: $an_to_id" . "\n\n";
	
	$result = 1 if (length($page_id) > 0 || length($an_to_id) > 0);
	#print LOG "result: $result" . "\n\n";
	return $result;

}    #end sub chkWkTopic

#-----------------------------------------------------------
#  get Wikipedia page_id
#-----------------------------------------------------------
#  arg1 = original query
#  r.v. = Wikipedia id
#-----------------------------------------------------------
sub getPageid {
	my $topic = shift(@_);
	my $mysql_topic = &getMysqlPageTopic($topic);
	
	#print LOG "Enter getPageid:" . ' ' . $mysql_topic . "\n\n";
	#print $mysql_topic . "\n";
	
	my $query = "SELECT page_id FROM page WHERE page_title=" . "'" . $mysql_topic . "'" . " AND page_type='1'";
	my $sth = $dbh->prepare($query) || die "cannot prepapre statement:" . $dbh->errstr();
	$sth->execute;
	
	#id is undefined if topic not exist
	my ($id) = $sth->fetchrow_array if ($sth->rows == 1);
	$sth->finish;
	
	if(defined($id)){
		return $id;
	}
	else {
		$id = '';
		return $id;
	}
	
}	#end sub getPageid

#-----------------------------------------------------------
#  get Wikipedia an_to
#-----------------------------------------------------------
#  arg1 = original query
#  r.v. = Wikipedia an_to
#-----------------------------------------------------------
sub getAntoid {
	my $topic = shift(@_);
	
	#print LOG "Enter getAntoid:" . ' ' . $topic . "\n\n";
	my $mysql_topic = &getMysqlAnchorTopic($topic);
	
	my $query = "SELECT an_to FROM anchor WHERE an_text=" . "'" . $mysql_topic . "'";
	my $sth = $dbh->prepare($query) || die "cannot prepare statement:" . $dbh->errstr();
	$sth->execute();
	
	if ($sth->rows == 1){
		
		my ($id) = $sth->fetchrow_array;
		
		return $id
	}
	elsif ($sth->rows > 1) {
		$query = "SELECT an_to, an_count FROM anchor WHERE an_text=" . "'" . $mysql_topic . "'";
		my $sth = $dbh->prepare($query) || die "cannot prepare statement:" . $dbh->errstr();
		$sth->execute();
		
		my %sense_count;
		while((my $id, my $count) = $sth->fetchrow_array){
			$sense_count{$id} = $count;
		}
		
		my @keys = sort {$sense_count{$b} <=> $sense_count{$a}} keys %sense_count;
		return shift(@keys);
	}
	else {
		my $id = '';
		return $id;		
	}
	
	$sth->finish;
	
}	#end sub getAntoid

#-----------------------------------------------------------
#  get Wikipedia pageline to an_to or page id
#-----------------------------------------------------------
#  arg1 = id
#  r.v. = array_ref to pagelnk
#-----------------------------------------------------------
sub getPagelinkIn {
	my $id = shift(@_);
	#print LOG "Enter getPageLinkIn:" . ' ' . $id . "\n\n";
	my $query = "SELECT li_data FROM pagelink_in WHERE li_id=" . "'" . $id . "'";
	my $sth = $dbh->prepare($query) || die "cannot prepare statement:" . $dbh->errstr();
	$sth->execute();
	
	my @links;
	
	my ($result) = $sth->fetchrow_array if ($sth->rows == 1);
	if (defined($result)){
		@links = split(/:/, $result);
	}
	
	return \@links;
	
}	#end sub getPagelinkIn

#-----------------------------------------------------------
#  get Wikipedia paragraph
#-----------------------------------------------------------
#  arg1 = Wikipedia an to
#  r.v. = the first paragraph to the an to
#-----------------------------------------------------------
sub getDefById {
	my $an_to = shift(@_);
	#print LOG "Enter getDefById:" . ' ' . $an_to . "\n\n";
	my $query = "SELECT df_firstParagraph FROM definition WHERE df_id=" . "'" . $an_to . "'";
	my $sth = $dbh->prepare($query) || die "cannot prepare statement:" . $dbh->errstr();
	$sth->execute;
	
	my ($result) = $sth->fetchrow_array if $sth->rows == 1;
	
	if(defined($result)){
		return $result;
	}
	else {
		$result = '';
		return $result;
	}
		
}    #end sub getDefById

#-----------------------------------------------------------
#  calculate term occurrence in paragraph
#-----------------------------------------------------------
#  arg1 = term
#  arg2 = Wikipedia paragraph
#  r.v. = the term occurrence in paragraph
#-----------------------------------------------------------
sub calTf {
	my ($term, $paragraph) = @_;
	#print LOG "Enter calTf:" . ' ' . $term . "\n\n";
	# get multiple word terms, could have duplicates
	my @terms = $paragraph =~ m/\[\[(.*?)\]\]/g;
	
	# get single word, could have non-alphabetic characters
	my @words = split(/\[\[.*?\]\]/, $paragraph);
	
	my @total = (@terms, @words);
	
	my $tf = 0;
	
	foreach (@total){
		$tf++ if (lc($term) eq $_);
	}
	
	return $tf;
	
}	#end sub calTf

#-----------------------------------------------------------
#  calculate overlaplink
#-----------------------------------------------------------
#  arg1 = array ref to one pagelink
#  arg2 = array ref to another pagelink
#  r.v. = the overlap between two pagelink
#-----------------------------------------------------------
sub calOverlapLink {
	my ($array_ref1, $array_ref2) = @_;
	#print LOG "Enter calOverlapLink" . "\n\n";
	my @pagelink1 = @$array_ref1;
	my @pagelink2 = @$array_ref2;
	
	#hash key: pagelink id
	#value: 1
	my %pagelink1;
	
	foreach (@pagelink1){
		$pagelink1{$_} = 1;
	}
	
	my $overlap = 0;
	
	foreach (@pagelink2){
		$overlap++ if (exists($pagelink1{$_}));
	}
	
	return $overlap;
	
}	#end sub calOverlapLink

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
#TODO: 
# Program getPageid (page_type = 1 ), getAntoid, getPagelinkIn, getDefById
#-----------------------------------------------------------
sub rankSeg {
	#print LOG "Enter rankSeg" . "\n\n";
	my ( $ngrams_ref, $contexts_ref, $dirichlet_smooth, $lambda, $google_words_ref, $google_docs_ref)
	  = @_;
	
	my @ngrams = @$ngrams_ref;
	my %contexts = %$contexts_ref;
	
	#hash key: ngram
	#value: ngram probability p(ti|Cti)
	my %rankscore;
	
	#hash key: Wikipedia title and anchor
	# value: disambiguated Wikipedia page id and an_to
	my %wk_id;
	
	
	foreach my $topic ( keys %contexts ) {

		#use Google to count n(ti,cti)
		# three approaches to count n(ti,cti):
		# with only ngram, with only single words, with both
		my $count_n = &gg_count( $topic, $contexts{$topic}, $google_docs_ref );

		#use Google to count sigma n(ti,cti)
		my $sigma_n = &gg_count_sigma( $contexts{$topic}, $google_docs_ref );
		
		my $pti = 0;
		my $isTopic = &chkWkTopic($topic);
		if ($isTopic){
			# pti
			my $page_table_count = 9171075;
			my $anchor_table_count = 12598642;
			$pti = 1.0/($page_table_count + $anchor_table_count);
			
			# get page_id
			my $page_id = &getPageid($topic);
			if(length($page_id) > 0 && $page_id =~ /\d+/){
				$wk_id{$topic} = $page_id;
			}
			else {
				#topic is a Wiki anchor if not a title
				if (&chkAmbiguation($topic)){
					$page_id = &wikiDisambiguation($topic, $contexts{$topic});
				}
				else {
					$page_id = &getAntoid($topic);
				}
				$wk_id{$topic} = $page_id;
			}
		}
		else {
			# calculate pti
			$pti = calPti( $topic, $lambda );
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
	print LOG "ranked query topics:" . (join ',', @ranked_topic) . "\n\n";
	
	#TODO: top three topics
	my @top_topic = @ranked_topic[0..2];
	
	foreach my $top_topic (@top_topic){
		my $top_topic_context = $contexts{$top_topic};
		print LOG "top topic:context:" . $top_topic . ':' . $top_topic_context . "\n\n";
		my $context_result = '';
		# context can be mixed with Wikipedia topic wrapped with quotation and single word
		# e.g., "times square" building
		my @context_terms = split(/ /, $top_topic_context);
		foreach my $term (@context_terms){
			if ($term =~ /^"|"$/){
				$term =~ s/^"|"$//; 
			}
			my $wk_id;
			if (&chkWkTopic($term)){
				# get page_id
				my $page_id = &getPageid($term);
				if(length($page_id) > 0 && $page_id =~ /\d+/){
					$wk_id = $page_id;
				}
				else {
					#getAntoid will disambiguate term if necessary to return an_to with the largest an_count
					$wk_id = &getAntoid($term);
				}
				$context_result .= '"' . $term . ':' . $wk_id . '"' . ' '; 
			}
			else {
				$context_result .= '"' . $term . '"' . ' ';
			}
		}# end foreach context_terms
	
		# top_topic is not necessarily Wikipedia topic
		if (&chkWkTopic($top_topic)){
			$seg_result .= '"' . $top_topic . ':' . $wk_id{$top_topic} . '"' . ' ' . $context_result . '||';
		}
		else {
			$seg_result .= '"' . $top_topic . '"' . ' ' . $context_result . '||';
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
	#print LOG "Enter gg_count:" . ' ' . $topic . "\n\n";
	#stop and stem topic and context
	my @t_words = &getword3($topic, \%abbrlist, \%pfxlist, \%stoplist, \%arvlist);
	my $stem_topic = &procword3(\@t_words, \%stoplist, \%xlist, \%sdict, $stemmer, \%qnoun2);
	#print LOG "original topic: $topic" . "\n" . "stem topic: $stem_topic\n\n";
	
	my @c_words = &getword3($context, \%abbrlist, \%pfxlist, \%stoplist, \%arvlist);
	my $stem_context = &procword3(\@c_words, \%stoplist, \%xlist, \%sdict, $stemmer, \%qnoun2);
	#print LOG "original context: $context" . "\n" . "stem context: $stem_context\n\n";
	
	my @google_stem_docs = @$google_docs_ref;
	
	# context: "abc" "xyz" ll mm nn
	my @contexts = split(/ /, $stem_context);
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
			my @tf_topic = $doc =~ /\b$stem_topic\b/gi;
			$co_count += scalar(@tf_topic);
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
	
	#print LOG "Enter gg_count_sigma:" . ' ' . $context . "\n\n";
	my @google_stem_docs = @$google_docs_ref;
	
	my @c_words = &getword3($context, \%abbrlist, \%pfxlist, \%stoplist, \%arvlist);
	my $stem_context = &procword3(\@c_words, \%stoplist, \%xlist, \%sdict, $stemmer, \%qnoun2);
	
	# context: "abc" "xyz" ll mm nn
	my @contexts = split(/ /, $stem_context);
	
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
#  r.v.1 = 1: the topic is a polysemy 0: the topic is not a polysemy
#-----------------------------------------------------------
sub chkAmbiguation {
	my ($topic) = @_;
	#print LOG "Enter chkAmbiguation" . ' ' . $topic . "\n\n";
	my $topic1 = ucfirst($topic);
	my $topic2;
	my @t = split(/ /, $topic);
	foreach (@t){
		$topic2 .= ucfirst($_). ' ';
	}
	$topic2 =~ s/\s+$//;
	
	my $isPolysemy = 0;
	my $count = 0;
	
	my $query = "SELECT count(*) an_to FROM anchor WHERE an_text=" . "'" . $topic . "'";
	my $sth = $dbh->prepare($query) || die "cannot prepare statement:" . $dbh->errstr();
	$sth->execute;
	$count = $sth->fetchrow_array;
	
	if ($count == 1){
		return $isPolysemy;
	}
	elsif ($count > 1){
		$isPolysemy = 1;
		return $isPolysemy;
	}
	elsif ($count == 0) {
		$topic = $topic1;
		$query = "SELECT count(*) an_to FROM anchor WHERE an_text=" . "'" . $topic . "'";
		$sth = $dbh->prepare($query) || die "cannot prepare statement:" . $dbh->errstr();
		$sth->execute;
		$count = $sth->fetchrow_array;
		
		if ($count == 1){
			return $isPolysemy;
		}
		elsif ($count > 1){
			$isPolysemy = 1;
			return $isPolysemy;
		}
		elsif ($count == 0){
			$topic = $topic2;
			$query = "SELECT count(*) an_to FROM anchor WHERE an_text=" . "'" . $topic . "'";
			$sth = $dbh->prepare($query) || die "cannot prepare statement:" . $dbh->errstr();
			$sth->execute;
			$count = $sth->fetchrow_array;
			
			if ($count == 1){
				return $isPolysemy;
			}
			elsif ($count > 1){
				$isPolysemy = 1;
				return $isPolysemy;
			}
			elsif ($count == 0){
				return $isPolysemy;
				print LOG "topic: $topic is unsuccessful to get an_to in anchor table\n\n";	
			}
		}
	}
	
}    #end sub chkAmbiguation

#-----------------------------------------------------------
#  disambiguate a polysemy topic with Wikipedia anchor
#-----------------------------------------------------------
#  arg1 = original topic
#  arg2 = context
#  r.v. = the polysemy topic's disambiguated page id
#-----------------------------------------------------------
#  TODO: use the most common sense in case there is no context
#-----------------------------------------------------------
sub wikiDisambiguation {
	# sense inventory: hyperlinks
	# sense repesentation: pagelink_in, Wikipedia definition, anchor count
	#disambiguate a polysemy when it is an anchor text, not use disambiguation page because:
	# some sense rarely used -> waste time, no sense statistics
	# use REGEXP to handle various forms: SELECT name FROM employees WHERE name REGEXP '^A'
	# or SELECT * FROM pet WHERE name LIKE 'b%';
	# use context to decide the most appropriate topic sense (topic: time square context: "new york" new york)
	
	my ($topic, $context) = @_;
	print LOG "Enter wikiDisambiguation:" . $topic . ' ' . $context . "\n\n";
	
	#get point to page where topic appears as an_text
	my @an_to;
	
	#hash key:an_to (i.e., word sense)
	#value:an_count
	my %sense_as_count;
	
	#hash key:an_to (i.e., word sense)
	#value:pagelink_in
	my %sense_as_links;
	
	#hash key:an_to (i.e., word sense)
	#value:Wikipedia definition
	my %sense_as_def;
	
	#Given a topic, the getMysqlTopic (both page and anchor) will decide which form is used in the Wikipedia database:
	#1. original query and/or topic (NOT stop and stemmed), 2. original query/topic with only the first character in the first word in Uppercase(Ucfirst(string))
	#3. original query/topic with first character in all words in uppercase
	my $mysql_topic = &getMysqlAnchorTopic($topic);
	my $query = "SELECT an_to, an_count FROM anchor WHERE an_text=" . "'" . $mysql_topic . "'";
	my $sth = $dbh->prepare($query) || die "cannot prepare statement:" . $dbh->errstr();
	$sth->execute();
		
	#Each time we call fetchrow_array, we get back a different record from the database.
	#fetchrow_array returns one of the selected rows from the database. You get back an array whose elements contain the data from the selected row
	while((my $id, my $count) = $sth->fetchrow_array){
		$sense_as_count{$id} = $count;
		#getPagelinkIn returns array ref to pages link with an_to inside Wikipedia
		my $array_ref = &getPagelinkIn($id);
		if (@$array_ref){
			$sense_as_links{$id} = $array_ref;
		}

		#getDefById return a string of parsed Wikipedia definition with stop and stemmed 
		$sense_as_def{$id} = &getDefById($id);
		push (@an_to, $id);
	}
	
	$sth->finish;
	
	# disambiguation
	#if any context is a Wikipedia title, use overlapping pagelink_in between an_to and context to disambiguate topic
	#otherwise, if context exist in an_to Wikipedia definition, use context tf to disambiguate topic
	#else, use an_count to disambiguate topic
	
	
	#hash key: an_to
	#value: overlapping pagelink_in
	my %overlap_link_withcontext;
	
	#hash key: an_to
	#value: context tf as it occurs in an_to definition 
	my %tf_withcontext;
	
	my @terms = split(/ /, $context);
	foreach my $term (@terms){
		my $overlap_count = 0;
		$term =~ s/^"||\s"//;
		my $mysql_term = &getMysqlPageTopic($term);
		my $query = "SELECT page_id FROM page WHERE page_title=" . "'" . $mysql_term . "'" . " AND page_type='1'";
		$sth = $dbh->prepare($query) || die "cannot prepapre statement:" . $dbh->errstr();
		$sth->execute;
		if($sth->rows == 1){
			# a list variable that matches the result
			# a variable without the parentness will get the fetchrow_array size, which will be number of column in the result based upon the select ???
			my ($id) = $sth->fetchrow_array;
			#if term is a Wikipedia title, get its pagelink_in
			if (length($id) > 0 && $id =~/\d+/){
				my $ary_ref = &getPagelinkIn($id);
				if (@$ary_ref){
					foreach my $an_to (keys %sense_as_links){
						$overlap_count += &calOverlapLink($ary_ref, $sense_as_links{$an_to});
						$overlap_link_withcontext{$an_to} = $overlap_count if $overlap_count > 0;
					}
				}
			}
		}
		$sth->finish;
	}
	
	if (keys(%overlap_link_withcontext)>0){
		#has overlap pagelinks between topic and context
		# rank keys by associated value in desend
		my @keys = sort {$overlap_link_withcontext{$b} <=> $overlap_link_withcontext{$a}} keys %overlap_link_withcontext;
		return shift(@keys);
	}
	else {
		#disambiguate by context occurrence in an_to definition
		foreach my $term (@terms){
			my $tf_count = 0;
			$term =~ s/^"||\s"//;
			foreach my $an_to (keys %sense_as_def){
				$tf_count += &calTf($term, $sense_as_def{$an_to});
				$tf_withcontext{$an_to} = $tf_count if $tf_count > 0;
			}
		}
		
		if (keys(%tf_withcontext) > 0){
			my @keys = sort {$tf_withcontext{$b} <=> $tf_withcontext{$a}} keys %tf_withcontext;
			return shift(@keys);
		}
		else {
			#context term not found in an_to Wikipedia definition
			#use an_count
			my @keys = sort {$sense_as_count{$b} <=> $sense_as_count{$a}} keys %sense_as_count;
			return shift(@keys);
		}
	}
	
}    #end sub wikiDisambiguation

#-----------------------------------------------------------
#  calculate topic probability
#  P(ti) <=> P(ti|wk) = lambda*Pmle(ti|wk_title) + (1-lambda)*Pmle(ti|wk_anchor)
#  Pmle(ti|M) = Pmle(w1|M)*Pmle(w2|M)...*P(wn|M) where w1,w2...wn belong ti
#-----------------------------------------------------------
#  arg1 = topic
#  arg2 = lambda
#  r.v. = Pti: topic probability
#-----------------------------------------------------------
sub calPti {
	my ($topic, $lambda) = @_;
	
	#print LOG "Enter calPti:" . ' ' . $topic . "\n\n";
	# get from MySQL
	my $page_table_count = 9171075;
	my $anchor_table_count = 12598642;
	
	my $mle_page = 1.0;
	my $mle_anchor = 1.0;
	my @words = split(/ /, $topic);
	
	foreach my $word (@words){
		my $mysql_page_word = &getMysqlPageTopic($word);
		my $query = "SELECT count(*) FROM page WHERE page_title=" . "'" . $mysql_page_word . "'" . " AND page_type='1'";
		my $sth = $dbh->prepare($query) || die "cannot prepare statement:" . $dbh->errstr();
		$sth -> execute;
		my ($page_word_count) = $sth->fetchrow_array if $sth->rows == 1;
		
		my $mysql_anchor_word = &getMysqlAnchorTopic($word);
		$query = "SELECT count(*) FROM anchor WHERE an_text=" . "'" . $mysql_anchor_word . "'";
		$sth = $dbh->prepare($query) || die "cannot prepare statement:" . $dbh->errstr();
		$sth -> execute;
		my ($anchor_word_count) = $sth->fetchrow_array if $sth->rows == 1;
		$sth->finish;
		
		if (defined($page_word_count)){
			$mle_page *= $page_word_count/$page_table_count;
		}
		if (defined($anchor_word_count)){
			$mle_anchor *= $anchor_word_count/$anchor_table_count;
		}
	}
	
	if ($mle_page == 1.0 && $mle_anchor == 1.0){
		return 0.0;
	}
	elsif ($mle_page > 0 && $mle_anchor == 1.0){
		return $lambda * $mle_page;
	}
	elsif ($mle_page == 1.0 && $mle_anchor > 0){
		return (1-$lambda) * $mle_anchor;
	}
	else{
		return $lambda * $mle_page + (1 - $lambda) * $mle_anchor;
	}
	
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
	print LOG "Enter calConditionalProb:" . $pti . ' ' . $count_n . ' ' . $sigma_n . ' ' . $dirichlet_smoothing . "\n\n";
	my $prob = ($count_n + $dirichlet_smoothing * $pti) / ($sigma_n + $dirichlet_smoothing);
	
	if ($prob > 0){
		return log($prob)/log(2);
	}
	else {
		return 0.0;
	}
	#return log($prob)/log(2);
	
}    #end sub calConditionalProb


#-----------------------------------------------------------
#  segment query into ngrams and contexts
#-----------------------------------------------------------
#  arg1 = original query
#  r.v.1 = @ngrams contains all derived ngrams (n>=2)
#  r.v.2 = %contexts, hash key: ngram, value: query context (i.e., the rest query content) 
#-----------------------------------------------------------
sub segmentation {
	#original query
	my $query = shift(@_);
	#print LOG "Enter segmentation:" . ' ' . $query . "\n\n";
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
					if (&chkWkTopic($another)){
						#$another is either Wk title or anchor
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
					if (&chkWkTopic($another)){
						#$another is either Wk title or anchor
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
#  arg2 = stem bigram
#  arg3 = google all stem words array
#  arg4 = MI threshold
#  r.v. = bigram segmentation
#  TODO: pass original query/two words, if Wikipedia topic, output as bigram
#  else, stem, calculate MI, if MI > threshold, output as bigram
#-----------------------------------------------------------
sub segByMI {
	
	# check bigram in the order:
	# 1. a Wikipedia topic
	# 2. calculate MI
	# 3. whether each word is a Wikipedia topic
	my ( $bigram, $stem_bigram, $google_stem_words_ref, $threshold ) = @_;
	#print LOG "Enter segByMI:" . ' ' . $bigram . "\n\n";
	my $bigram_seg = '';
	
	# is bigram a Wikipedia topic
	#condition: $stem_query is a Wikipedia title and page_type == 1
	my $page_id = &getPageid($bigram);
	
	# if bigram is a Wikipedia topic, wrap in quotation
	# otherwise, if the collocation is above threshold, wrap in quotation
	# else, return as single words
	if (length($page_id) >0 && $page_id =~ /\d+/){
		$bigram_seg = '"' . $bigram . ':' . $page_id . '"' . ' ';
	}
	else {
		#condition: $stem_query is a Wikipedia anchor and if multiple an_to, use the one with largest an_count
		my $an_to_id = &getAntoid($bigram);
		if (length($an_to_id) > 0 && $an_to_id =~ /\d+/ ){
			$bigram_seg = '"' . $bigram . ':' . $an_to_id . '"' . ' ';
		}
		else {
			my ( $w1, $w2 ) = split( / /, $stem_bigram );
			print LOG "w1, w2:" . ' ' . $w1 . ',' .$w2 . "\n\n";
	
			# decide whether the bigram should be considered as collocation
			# by calculating freuqency-weighted MI using Google results
			# MI = log(N*C(w1,w2)/(C(w1)*C(w2)))/log2
			my @google_words = @$google_stem_words_ref;
	
			my $match = 0;
	
			my $big_line = join (' ', @google_words);
			
			print LOG $big_line . "\n\n";

			# count cooccurrence in window with size 5
			for ( my $i = 1 ; $i < scalar(@google_words) ; $i += 5 ) {
				my $str = join( ' ', @google_words[ $i..$i+4 ] );
				$match++ if ( $str =~ /\b$w1\b/i && $str =~ /\b$w2\b/i );
				
				my ($ori_w1, $ori_w2) = split(/ /, $bigram);
				$match++ if ( $str =~ /\b$ori_w1\b/i && $str =~ /\b$ori_w2\b/i );
			}

			#my @match = $big_str =~ /(\b$w1\b)( )(\b$w2\b)/i;
			my @w1 = $big_line =~ /\b$w1\b/gi;
			my @w2 = $big_line =~ /\b$w2\b/gi;
			
			print LOG scalar(@w1) . ' ' . scalar(@w2) . "\n\n";

			# mi_value = freq(w1,w2)*MI(w1,w2)
			my $mi_value = log( (scalar(@google_words) * $match) / (scalar(@w1) * scalar(@w2)) ) / log(2);
	  		if ($mi_value > $threshold){
				$bigram_seg = '"' . $bigram . '"' . ' ';
			}
			else {
				$bigram_seg = $bigram . ' ';
			}
		}
	}
		
	return $bigram_seg;

}    #end sub segByMI

#-----------------------------------------------------------
#  get Mysql topic in page and anchor table
#------------------------------------------------------------
#  arg1 = original query
#  r.v. = query form used in Mysql
#-----------------------------------------------------------
sub getMysqlTopic {

}    #getMysqlTopic

#-----------------------------------------------------------
#  get Mysql topic in anchor table
#------------------------------------------------------------
#  arg1 = original query
#  r.v. = query form used in Mysql
#-----------------------------------------------------------
sub getMysqlAnchorTopic {
	
	my ($topic) = @_;
	#print LOG "Enter getMysqlAnchorTopic:" . ' '. $topic . "\n\n";
	my $topic1 = ucfirst($topic);
	my $topic2;
	my @t = split(/ /, $topic);
	foreach (@t){
		$topic2 .= ucfirst($_). ' ';
	}
	$topic2 =~ s/\s+$//;
	
	my $count = 0;
		
	my $query = "SELECT count(*) an_to FROM anchor WHERE an_text=" . "'" . $topic . "'";
	my $sth = $dbh->prepare($query) || die "cannot prepare statement:" . $dbh->errstr();
	$sth->execute;
	$count = $sth->fetchrow_array;

	if ($count == 1){
		return $topic;
	}
	elsif ($count == 0) {
		$query = "SELECT count(*) an_to FROM anchor WHERE an_text=" . "'" . $topic1 . "'";
		$sth = $dbh->prepare($query) || die "cannot prepare statement:" . $dbh->errstr();
		$sth->execute;
		$count = $sth->fetchrow_array;
		
		if ($count == 1){
			return $topic1;
		}
		elsif ($count == 0){
			$query = "SELECT count(*) an_to FROM anchor WHERE an_text=" . "'" . $topic2 . "'";
			$sth = $dbh->prepare($query) || die "cannot prepare statement:" . $dbh->errstr();
			$sth->execute;
			$count = $sth->fetchrow_array;
			
			if ($count == 1){
				return $topic2;
			}
			elsif ($count == 0){
				return $topic;
				print LOG "topic: $topic is unsuccessful to get MysqlTopic in Mysql page\n\n";	
			}
		}
	} 

}    #getMysqlAnchorTopic

#-----------------------------------------------------------
#  get Mysql topic in page table
#------------------------------------------------------------
#  arg1 = original query
#  r.v. = query form used in Mysql
#-----------------------------------------------------------
sub getMysqlPageTopic {
	my ($topic) = @_;
	#print LOG "Enter getMysqlPageTopic:" . ' ' . $topic . "\n\n";
	my $topic1 = ucfirst($topic);
	my $topic2;
	my @t = split(/ /, $topic);
	foreach (@t){
		$topic2 .= ucfirst($_). ' ';
	}
	$topic2 =~ s/\s+$//;
	
	my $count = 0;
		
	my $query = "SELECT count(*) page_id FROM page WHERE page_title=" . "'" . $topic . "'" . " AND page_type='1'";
	my $sth = $dbh->prepare($query) || die "cannot prepare statement:" . $dbh->errstr();
	$sth->execute;
	$count = $sth->fetchrow_array;

	if ($count == 1){
		return $topic;
	}
	elsif ($count == 0) {
		$query = "SELECT count(*) page_id FROM page WHERE page_title=" . "'" . $topic1 . "'" . " AND page_type='1'";
		$sth = $dbh->prepare($query) || die "cannot prepare statement:" . $dbh->errstr();
		$sth->execute;
		$count = $sth->fetchrow_array;
		
		if ($count == 1){
			return $topic1;
		}
		elsif ($count == 0){
			$query = "SELECT count(*) page_id FROM page WHERE page_title=" . "'" . $topic2 . "'" . " AND page_type='1'";
			$sth = $dbh->prepare($query) || die "cannot prepare statement:" . $dbh->errstr();
			$sth->execute;
			$count = $sth->fetchrow_array;
			
			if ($count == 1){
				return $topic2;
			}
			elsif ($count == 0){
				return $topic;
				print LOG "topic: $topic is unsuccessful to get MysqlTopic in Mysql anchor\n\n";	
			}
		}
	} 

}    #getMysqlPageTopic

#-----------------------------------------------------------
#  create hash from file
#------------------------------------------------------------

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
