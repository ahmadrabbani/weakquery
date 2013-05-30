#!/usr/bin/perl -w

# --------------------
# segment and disambiguate queries
# 1. segment query into n-grams and contexts
# 2. rank n-gram by its contexts: the top-ranked n-gram and context are considered as
# 	 query topic and the most appropriate query segmetation
# --------------------
# Input:
#   individual keyword queries as command line argument (un-processed)
# Output:
#   $idir/query/$subd/gg/hits/rs$qn.htm  -- result page
#   $idir/query/$subd/gg/hits/lk$qn     -- hit URLs
#   $idir/query/$subd/gg/hits/ti$qn     -- hit titles
#   $idir/query/$subd/gg/hits/sn$qn     -- hit snippets
#   $idir/query/$subd/gg/hits/$qn/r$n.htm -- hit HTML
#   $idir/query/$subd/gg/hits/$qn/r$n.txt -- hit text
#   $idir/query/$prog       -- program     (optional)
#   $idir/query/$prog.log   -- program log (optional)
#     where $subd= train|test
# Result:
#	print to STDOUT as: orginal query, qry_seg1|qry_seg2|...qry_segi
# --------------------
# ver1.0	3/17/2011
# --------------------

use strict;
use warnings;

use LWP::Simple;
use WWW::Wikipedia;
use LWP::UserAgent;
use WWW::Mechanize;

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

#my $home_dir = "/home/hz3";
my $wpdir = "$home_dir/Desktop/dissertation";    #dissertation working directory
my $tpdir = "$wpdir/prog";    #dissertation TREC program directory
my $pdir = "$home_dir/workspace/epic_prog";  #dissertation programming directory
my $idir = "$wpdir/data";                    #input query/data directory
my $qdir = "$wpdir/query";                   #google and wiki output directory

my $maxhtmN = 100;

require "$tpdir/logsub2.pl";
require "$tpdir/spidersub_2010.pl";
require "$tpdir/indxsub_2010.pl";
require "$tpdir/NLPsub_2010.pl";

my $stopwordslist = "$tpdir/stoplist1";

# create the stopword hash
my %stoplist;
&mkhash( $stopwordslist, \%stoplist );

#------------------------
# program arguments
#------------------------

my $segdir = "$idir/segments";           # test query dir
my $outd   = "$qdir/segment/gg/hits";    # for search results
my $outd1  = "$qdir/segment/wk/hits";    # for Wikipedia search results

my @outdir = ("$outd");
foreach my $outdir (@outdir) {
	if ( !-e $outdir ) {
		my @errs = &makedir( $outdir, $dirmode, $group );
		print "\n", @errs, "\n\n" if (@errs);
	}
}

my @outdir1 = ("$outd1");
foreach my $outdir (@outdir1) {
	if ( !-e $outdir ) {
		my @errs = &makedir( $outdir, $dirmode, $group );
		print "\n", @errs, "\n\n" if (@errs);
	}
}

# ---------------
# start program log
# ---------------

$sfx    = 't';    # test
$noargp = 1;      # if 1, do not print arguments to log
$append = 0;      # log append flag

if ($log) {
	@start_time = &begin_log( $qdir, $filemode, $sfx, $noargp, $append );
	print LOG "Infile  = $segdir/q\$qn\n",
	  "Outfile = $outd/rs\$qn.htm, ti\$qn, sn\$qn, lk\$qn\n",
	  "          $outd/q\$qn/r\$N.htm, r\$N.txt\n\n";
}

my $seg_query_file  = "$segdir/test.dev";
my $seg_result_file = "$qdir/test.result";

my $qn = 1;
open( OUT, ">$seg_result_file" ) || die "cannot write $seg_result_file";
open( IN,  "<$seg_query_file" )  || die "cannot open $seg_query_file";
while (<IN>) {
	chomp;
	my ( $seg, $url ) = split( '\t', $_ );

	#convert segmented training data to original form for testing
	my $word = $seg;
	$word =~ s/"//g;
	$qn++;

	#search Google
	my $htmlcnt = &queryGoogle2( $word, $outd, $qn, $maxhtmN );

	# read in result links
	open( LINK, "$outd/lk$qn" ) || die "can't read $outd/lk$qn";
	my @links = <LINK>;
	close LINK;
	chomp @links;
	
	my $outd2 = "$outd/q$qn";
	if ( !-e $outd2 ) {
		my @errs = &makedir( $outd2, $dirmode, $group );
		print "\n", @errs, "\n\n" if (@errs);
	}

	# fetch hit pages
	my $fn = 1;
	foreach my $link (@links) {

		last if ( $fn > $maxhtmN );

		my ( $n, $url ) = split /: /, $link;

		my ( $htm, $title, $body ) = &fetchHTML( $url, $fn );
				
		my $outf = "$outd2/r$fn.html";
		open(OUT1, ">$outf") || die "cannot write to $outf";
		binmode( OUT1, ":utf8" );
		print OUT1 $htm if ($htm);
		close(OUT1);
				
		my $outf2 = "$outd2/r$fn.txt";
		open( OUT2, ">$outf2" ) || die "cannot write to $outf2";
		binmode( OUT2, ":utf8" );
		print OUT2 "$title\n\n" if ($title);
		print OUT2 "$body\n" if ($body);
		close(OUT2);
		
		$fn++;
	}
	
	# search Wikipedia
	my $status = &queryWikipedia( $word, $outd1, $qn );
	my $outfw  = "$outd1/tx$qn";
	
	
	# segment query into n-grams and n-gram contexts
	my @ngrams;

	# hash key: ngram
	# value: contexts (i.e., query without the ngram)
	my %contexts;
	( @ngrams, %contexts ) = &segmentation($word);
	
	#TODO: rank the ngrams based on co-occurrence with their contexts in Google and Wikipedia
	# hash key: ngram
	# value: ngram score
	# hash is sorted by value in descend
	my %ngrams_score = &rankSeg(@ngrams, %contexts, $outd2, $outd1);
	

}    #end while

close(IN);
close(OUT);

# ----------------
# end program
# ----------------

print LOG "\nProcessed $qn queries\n\n";
&end_log( $pdir, $qdir, $filemode, @start_time ) if ($log);

#-----------------------------------------------------------
#  rank the ngrams based on co-occurrence with their contexts in Google and Wikipedia
#-----------------------------------------------------------
#  arg1 = ngram array
#  arg2 = ngram hash 
#  arg3 = Google result directory
#  arg4 = Wikipedia result directory
#-----------------------------------------------------------
sub rankSeg {
	my (@ngrams, %contexts, $google_dir, $wiki_dir) = @_;
	#hash key: ngram
	#value: ngram score
	my %rankscore;
	
	
	
	
	
	return %rankscore;
	
}#end sub rankSeg


#-----------------------------------------------------------
#  segment query into ngrams and contexts
#-----------------------------------------------------------
#  arg1 = query
#  arg2 = Google output directory
#  arg3 = MI threshold with Google results
#-----------------------------------------------------------
sub segmentation {
	my ( $query, $outd2, $MI_threshold ) = @_;
	my ( @ngrams, %contexts );

	my @words = split( / /, $query );
	my $len   = scalar(@words);

	if ( $len == 2 ) {
		my $seg_str = &segByMI( $query, $outd2, $MI_threshold );
		open( OUT, ">$seg_result_file" ) || die "cannot write $seg_result_file";
		print OUT $query . ',' . $seg_str;
		close OUT;
	}
	elsif ( $len == 1 ) {
		print LOG "\nQuery $query must have more than two words\n\n";
	}
	elsif ( $len > 2 ) {
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
		
		foreach my $ngram (@ngrams){
			my $result = index($query, $ngram);
			#print $ngram . ':' . $result . "\n";
		
			if ($result == 0){
				$contexts{$ngram} = substr($query, length($ngram));
			}
			else {
				$contexts{$ngram} = substr($query, 0, $result) . substr($query, $result+length($ngram));
			}	
 		}
	}
	
	return (@ngrams, %contexts);

}    #end sub segmentation

#-----------------------------------------------------------
#  examine whether the bigram is collocation
#-----------------------------------------------------------
#  arg1 = bigram
#  arg2 = Google output directory
#  arg3 = MI threshold with Google results
#-----------------------------------------------------------
sub segByMI {

	# decide whether the bigram should be considered as collocation
	# by calculating freuqency-weighted MI using Google results
	# MI = log(N*C(w1,w2)/(C(w1)*C(w2)))/log2

	my ( $bigram, $google_dir, $threshold ) = @_;
	my ( $w1, $w2 ) = split( / /, $bigram );

	my $big_str = '';

	my @files = <$google_dir/*.txt>;
	foreach my $file (@files) {
		open( IN, "<$file" ) || die "cannot open $file\n";
		my @lines = <IN>;
		close IN;

		chomp(@lines);
		$big_str .= join( ' ', @lines );
	}

	my @words = split( / /, $big_str );
	my $match = 0;

	for ( my $i = 1 ; $i < scalar(@words) ; $i += 5 ) {
		my $str = join( ' ', @words[ $i .. $i + 4 ] );
		$match++ if ( $str =~ /\b$w1\b/ && $str =~ /\b$w2\b/ );
	}

	#my @match = $big_str =~ /(\b$w1\b)( )(\b$w2\b)/i;
	my @w1 = $big_str =~ /(\b$w1\b)/i;
	my @w2 = $big_str =~ /(\b$w2\b)/i;

	#TODO: smoonth $match necessary?

	# mi_value = freq(w1,w2)*MI(w1,w2)
	my $mi_value =
	  $match * log( scalar(@words) * $match / ( scalar(@w1) * scalar(@w2) ) ) /
	  log(2);

	my $bigram_seg = '';

	if ( $mi_value >= $threshold ) {
		$bigram_seg = $bigram;
	}
	else {
		$bigram_seg = $w1 . '|' . $w2;
	}

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

