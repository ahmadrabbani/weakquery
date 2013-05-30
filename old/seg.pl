#!/usr/bin/perl -w		

# --------------------
# segment and disambiguate queries
# 1. search query against Gooogle,save top n html pages
# 2. chunk query into p		
#	bisecting n-gram pair
# 3. calculate the association of top-ranked bisecting n-grams(e.g., chi-square) to decide whether
#	the entire query should be considered as a whole 
# --------------------
# Input:
#   $idir/query/$subd/q$qn  -- individual queries (processed)
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
# --------------------
# ver1.0	10/31/2010
#	initial version
# ver1.1	12/16/2010
#	new CRF function
#	replace term weight with MI in calWeight, only compare situations of segmented as two n-grams with not segmented
# --------------------		

use strict;
use warnings;

use LWP::Simple;
use WWW::Wikipedia;
use LWP::UserAgent;

my ($debug,$filemode,$filemode2,$dirmode,$dirmode2,$author,$group);
my ($log,$logd,$sfx,$noargp,$append,@start_time);

$log=1;                              # program log flag
$debug=0;                            # debug flag
$filemode= 0640;                     # to use w/ perl chmod
$filemode2= 640;                     # to use w/ system chmod
$dirmode= 0750;                      # to use w/ perl mkdir
$dirmode2= 750;                      # to use w/ system chmod (directory)
$group= "trec";                      # group ownership of files
$author= "hz3\@indiana.edu";	     # author's email

# ----------------
# global variable
# ----------------

my $home_dir = "/home/huizhang";
#my $home_dir = "/home/hz3";
my $wpdir = "$home_dir/Desktop/dissertation";	#dissertation working directory
my $tpdir = "$wpdir/prog";			#dissertation TREC program directory
my $pdir = "$home_dir/workspace/epic_prog";	#dissertation programming directory
my $idir = "$wpdir/data";			#input query/data directory
my $qdir = "$wpdir/query";			#google and wiki output directory 

my $maxhtmN = 100;
my $MI_threshold = 0.0;
my $seg_threshold = 0.0;

# CRF weight
my $alpha = 0.5;
my $lambda_anchor = 0.1;
my $lambda_title = 0.8;
my $lambda_para = 0.1;

require "$tpdir/logsub2.pl";
require "$tpdir/spidersub_2010.pl";
require "$tpdir/indxsub_2010.pl";
require "$tpdir/NLPsub_2010.pl";

my $stopwordslist = "$tpdir/stoplist1";
# create the stopword hash
my %stoplist;
&mkhash($stopwordslist,\%stoplist);


#------------------------
# program arguments
#------------------------

my $qrydir = "$idir/segments";          # test query dir
my $outd="$qdir/segment/gg/hits";       # for search results
my $outd1="$qdir/segment/wk/hits";  	# for Wikipedia search results

my @outdir=("$outd");
foreach my $outdir(@outdir) {
    if (!-e $outdir) {
        my @errs=&makedir($outdir,$dirmode,$group);
        print "\n",@errs,"\n\n" if (@errs);
    }
}


# ---------------
# start program log
# ---------------

$sfx= 't';             # test
$noargp=1;             # if 1, do not print arguments to log
$append=0;             # log append flag


if ($log) {
    @start_time= &begin_log($qdir,$filemode,$sfx,$noargp,$append);
    print LOG "Infile  = $qrydir/q\$qn\n",
              "Outfile = $outd/rs\$qn.htm, ti\$qn, sn\$qn, lk\$qn\n",
              "          $outd/q\$qn/r\$N.htm, r\$N.txt\n\n";
}

my $seg_query_file = "$qrydir/test.20";

#-------------------------------------------------
# 1. get query string from segments file
# 2. query google and save search result data
# 3. fetch webpages in the search result
#-------------------------------------------------

my $qn=0;
open (IN, "<$seg_query_file") || die "cannot open $seg_query_file";
while (<IN>) {
	chomp;
	my ($a, $b, $c) = split(',', $_);
	# number of single words in the query
	my @a = split(/ /, $a);
	my $n = scalar(@a);
	$qn++;
	
	my $htmlcnt = &queryGoogle2($a, $outd, $qn, $maxhtmN);
    
	# read in result links
	open(LINK,"$outd/lk$qn") || die "can't read $outd/lk$qn";
	my @links=<LINK>;
	close LINK;
	chomp @links;

	my $outd2= "$outd/q$qn";
	if (!-e $outd2) {
		my @errs=&makedir($outd2,$dirmode,$group);
		print "\n",@errs,"\n\n" if (@errs);
	}

	# fetch hit pages
	my $fn=1;
	foreach my $link(@links) {

		last if ($fn>$maxhtmN);

		my($n,$url)=split/: /,$link;

		my ($htm,$title,$body)= &fetchHTML($url,$fn); 

		my $outf= "$outd2/r$fn.htm";
		open (OUT, ">$outf") || die "can't write to $outf";
		binmode(OUT, ":utf8");
		print OUT $htm if ($htm);
		close(OUT);

		my $outf2= "$outd2/r$fn.txt";
		open (OUT2, ">$outf2") || die "can't write to $outf2";
		binmode(OUT2,":utf8");
		print OUT2 "$title\n\n" if ($title);
		print OUT2 "$body\n" if ($body);
		close(OUT2);
		$fn++;
		
	}
	
	my $status= &queryWikipedia($a,$outd1,$qn);
	my $outf2= "$outd1/tx$qn";
	
	
	# query segmentation result:
	# each segment is a n-gram that represents a concept
	# segments are separated by |
	my $qryseg_str = '';

	if ($n == 2) {
		$qryseg_str = &segByMI($a, $outd2, $MI_threshold);
		print "bigram query: $a is segmented as: " . "$qryseg_str" . "\n";
	}
	elsif ($n == 1) {
		print "query with only one word is unprocessable!\n"; 
	}
	elsif ($n > 2) {
		print "starting processing a multi-word query: $a...\n";
		# step #1
        # bisects
        # key: id (1..n-1) bisecting n-gram pairs
        # value: two ngrams of each bisecting pair (preserving the order) separated by ,
		# key: id 0
		# value: query segmented as all single words, separated by ,
		# key: id n
		# value: query segmented as a whole ngram
	    my $bisects_ref = &bisect($a);
		
	    # step #2
       	# calculate bisecting n-grams joint probablity using conditional random field
        # return the bisecting n-gram pair that has the highest probability
        my $ngrampair = &rankByCRF($bisects_ref, $alpha, $lambda_anchor, $lambda_title, $lambda_para, $n, \%stoplist, $outf2);
		
		# step #3
		# dedice whether the query should be segmented as result of step#2 or not segmented
		# by calculating the MI between the two n-gram pairs
		# we try to discover multi-word topic from the query, query as single words is not considered as a segmentation and will be used as baseline for comparison
		my $did = &calWeight($ngrampair, "$outd/q$qn", $seg_threshold);
		if ($did == 0) {
			# not segment, query should be considered as a whole string
			$qryseg_str = $a;
			print "multi-gram query: $a is segmented as a whole: " + "$qryseg_str" . "\n";
		}
		elsif ($did == 1) {
			# query should be segmented as multiple sub ngrams
			foreach my $ngram (split/,/, $ngrampair) {
				my @tmp = split(/ /, $ngram); 
            	if (scalar(@tmp) == 2) {
                	$qryseg_str .= &segByMI($ngram);
                }
                elsif (scalr(@tmp) == 1) {
                	$qryseg_str .= $ngram . '|';
                }
                elsif (scalr(@tmp) > 2) {
                	# dynamic_process includes step#1, #2, and #3
                	# called repeatly until the length of any ngram is <=2
					# return the segmented query string
                	$qryseg_str .= &dynamic_process($ngram);
               	}		
        	}
		}
	}
}
close (IN);

# ----------------
# end program
# ----------------

print LOG "\nProcessed $qn queries\n\n";
&end_log($pdir, $qdir, $filemode, @start_time) if ($log); 


# ----------------
# SUBROUTINES
# ----------------
sub segByMI {
	# decide whether the bigram should be considered as collocation
	# by calculating freuqency-weighted MI using Google results
	# MI = log(N*C(w1,w2)/(C(w1)*C(w2)))/log2
	my ($bigram, $google_dir, $threshold) = @_;
	my ($w1, $w2) = split(/ /, $bigram);
	
	my $big_str = '';
	
	my @files = <$google_dir/*.txt>;
	foreach my $file (@files) {
		open (IN, "<$file") || die "cannot open $file\n";
		my @lines = <IN>;
		close IN;
		
		chomp(@lines);
		$big_str .= join(' ', @lines);
	}
	
	my @words = split(/ /, $big_str);
	my @match = $big_str =~ /(\b$w1\b)( )(\b$w2\b)/i;
	my @w1 = $big_str =~ /(\b$w1\b)/i;
	my @w2 = $big_str =~ /(\b$w2\b)/i;
	
	# mi_value = freq(w1,w2)*MI(w1,w2)
	my $mi_value = scalar(@match)*log(scalar(@words)*scalar(@match)/(scalar(@w1)*scalar(@w2)))/log(2);
	
	my $bigram_seg = '';
	
	if ($mi_value >= $threshold) {
		$bigram_seg = $bigram . '|';
	}
	else {
		$bigram_seg = $w1 . '|' . $w2 . '|';
	}
	
	return $bigram_seg;

}


sub bisect {
	my $qrystr = shift(@_);
	my $qryseg_ref;

	my @words = split(/ /, $qrystr);
	my (@first, @second);
	my ($first, $second) = '';
	
	for (my $i=1; $i<scalar(@words); $i++){
		@first = @words[0..$i];
		@second = @words[$i+1..scalar(@words)];
		$first = join(' ', @first);
		$second = join(' ', @second);
		$qryseg_ref->{$i} = $first . ',' . $second;
	}
	
	$qryseg_ref->{0} = join(',', @words);
	$qryseg_ref->{scalar(@words)} = $qrystr;	

	return $qryseg_ref;
}


sub rankByCRF {
	my ($qryseg_ref, $alpha, $lambda_anchor, $lambda_title, $lambda_para, $n, $stoplist_ref, $outf2) = @_;
	my %qryseg = %$qryseg_ref;
	# hash key: qryseg key
	#value: CRF value
	my %result;
	my $bestpair_ref;
	
	my $wikicsv_dir = "/media/Elements/en_20080727";
	my $anchor_csv = "$wikicsv_dir/anchor.csv";
	open (IN, "<$anchor_csv") || die "cannot open $anchor_csv";
	my @anchors = <IN>;
	close IN;
	chomp @anchors;
	
	my $page_csv = "$wikicsv_dir/page.csv";
	open (IN, "<$page_csv") || die "cannot open $page_csv";
	my @titles = <IN>;
	close IN;
	chomp @titles;
	
	my $definition_csv = "$wikicsv_dir/definition.csv";
	open (IN, "<$definition_csv") || die "cannot open $definition_csv";
	#TODO: parse only the first paragraph
	my @para = <IN>;
	close IN;
	chomp @para;
	

	foreach my $key (keys %qryseg) {
		next if ($key ==0 || $key ==$n);
   		my ($first_tmp, $second_tmp) = split(/,/, $qryseg{$key});
		my @first_tmp = split(/ /, $first_tmp);
		my @second_tmp = split(/ /, $second_tmp);
		
		my (@first, @second);
		
		#TODO: remove stopwords
		for (my $i=0; $i<scalar@first_tmp; $i++){
			next if  (exists($$stoplist_ref{"\L$first_tmp[$i]"}));
			push (@first, $first_tmp[$i]);
		}
		
		for (my $i=0; $i<scalar@second_tmp; $i++){
			next if (exists($$stoplist_ref{"\L$second_tmp[$i]"}));
			push (@second, $second_tmp[$i]);
		}
		
		my $first = join(' ', @first);
		my $second = join(' ', @second);
		
		#TODO: search term against Wikipedia, return the tf and number of words in top 100 Wikipedia results
		# both numbers will be used for three functions
		# skip matching terms without alphabetical characters
		my ($tf_w_1st, $tf_w_2nd, $tf_w_total) = 0;
		open (IN, "<$outf2") || die "cannot open $outf2";
		my @lines = <IN>;
		close IN;
		chomp @lines;
		
		my $bigline = join (' ', @lines);
		$tf_w_1st = $bigline =~ /\b$first\b/i;
		$tf_w_2nd = $bigline =~ /\b$second\b/i;
		
		my @biglines = split(/ /, $bigline);
		foreach (@biglines){
			next unless ($_ =~ /\w+\W*|\W*\w+/);
			$tf_w_total++;
		}
		
		
		# the legalness of a segmentation is ranked by the sum of joint probablities as:
		# p($first, Wikipedia) + p($second, Wikipedia), where p(term,Wikipedia) is ranked by p(term|Wikipedia), and p(term|Wikipedia) is calculated by CRF
		# with function as: 1. term appears as anchor, 2. appears as title and/or rediret, 3. appears in the first paragraph in Wikipedia
		# 1. x*(# anchors that have exact term match/|# anchors|) + (1-x)*(# term appears in the top 100 Wikipedia search results/|# words in top 100 Wikipedia search results |)
		# 2. x*(# title&redireicts that have exact term match/|# title&redirects|) + (1-x)*(# term appears in the top 100 Wikipedia search results/|# words in top 100 Wikipedia search results|)
		# 3. x*(# paragraphs that have exact term match/|# paragraphs|) + (1-x)*(# term appears in the top 100 Wikipedia search results/|# words in top 100 Wikipedia search results|)
		
		# The anchor function		
		my ($tf_a_1st, $tf_a_2nd) = 0;
		foreach my $anchor (@anchors) {
			$tf_a_1st++ if ($anchor =~ /\b$first\b/i);
			$tf_a_2nd++ if ($anchor =~ /\b$second\b/i);
		}
		
		# The title function
		my ($tf_t_1st, $tf_t_2nd) = 0;
		foreach my $title (@titles) {
			$tf_t_1st++ if ($title =~ /\b$first\b/i);
			$tf_t_2nd++ if ($title =~ /\b$second\b/i);
		}

		# The paragraph function
		my ($tf_p_1st, $tf_p_2nd) = 0;
		foreach my $para (@para) {
			$tf_p_1st++ if ($para =~ /\b$first\b/i);
			$tf_p_2nd++ if ($para =~ /\b$second\b/i);
		}
		
		my $afc_1st = $lambda_anchor * ($alpha * log($tf_a_1st/scalar(@anchors))/log(2) + (1-$alpha) * log($tf_w_1st/$tf_w_total)/log(2) );
		my $tfc_1st = $lambda_title * ($alpha * log($tf_t_1st/scalar(@titles))/log(2) + (1-$alpha) * log($tf_w_1st/$tf_w_total)/log(2) );
		my $pfc_1st = $lambda_para * ($alpha * log($tf_p_1st/scalar(@para))/log(2) + (1-$alpha) * log($tf_w_1st/$tf_w_total)/log(2) );
		
		my $afc_2nd = $lambda_anchor * ($alpha * log($tf_a_2nd/scalar(@anchors))/log(2) + (1-$alpha) * log($tf_w_2nd/$tf_w_total)/log(2) );
		my $tfc_2nd = $lambda_title * ($alpha * log($tf_t_2nd/scalar(@titles))/log(2) + (1-$alpha) * log($tf_w_2nd/$tf_w_total)/log(2) );
		my $pfc_2nd = $lambda_para * ($alpha * log($tf_p_2nd/scalar(@para))/log(2) + (1-$alpha) * log($tf_w_2nd/$tf_w_total)/log(2) );
		
		$result{$key} = $afc_1st + $tfc_1st + $pfc_1st + $afc_2nd + $tfc_2nd + $pfc_2nd; 
	
	}
	
	my @keys = sort {$result{$b} <=> $result{$a}} (keys %result);
	
	return shift(@keys);
	
}


sub calWeight {
	my ($bigram, $google_dir, $threshold) = @_;
	my ($w1, $w2) = split(/,/, $bigram);
	my $did = -1;
	
	my $big_str = '';
	
	my @files = <$google_dir/*.txt>;
	foreach my $file (@files) {
		open (IN, "<$file") || die "cannot open $file\n";
		my @lines = <IN>;
		close IN;
		
		chomp(@lines);
		$big_str .= join(' ', @lines);
	}
	
	my @words = split(/ /, $big_str);
	my @match = $big_str =~ /(\b$w1\b)( )(\b$w2\b)/i;
	my @w1 = $big_str =~ /(\b$w1\b)/i;
	my @w2 = $big_str =~ /(\b$w2\b)/i;
	
	# mi_value = freq(w1,w2)*MI(w1,w2)
	my $mi_value = scalar(@match)*log(scalar(@words)*scalar(@match)/(scalar(@w1)*scalar(@w2)))/log(2);
		
	if ($mi_value >= $threshold) {
		# not segment
		$did = 0;
	}
	else {
		# segment as two n-grams
		$did = 1;
	}
	
	return $did;
	
}


sub dynamic_process {
	# initial ngram to be processed
	my $in_ngram = shift(@_);
	my @ngrams = split(/ /, $in_ngram);
	my $ngram_seg = '';
	#perform step1,2,3, send a segment of the ngram to dynamic_process if its length is > 2
	#else $ngram_seg .= segment
		# step #1
        # bisects
        # key: id (1..n-1) bisecting n-gram pairs
        # value: two ngrams of each bisecting pair (preserving the order) separated by ,
		# key: id 0
		# value: query segmented as all single words, separated by ,
		# key: id n
		# value: query segmented as a whole ngram
	    my $bisects_ref = &bisect($in_ngram);
		
	    # step #2
       	# calculate bisecting n-grams joint probablity using conditional random field
        # return the bisecting n-gram pair that has the highest probability
        my $ngrampair = &rankByCRF($bisects_ref, $alpha, $lambda_anchor, $lambda_title, $lambda_para, scalar(@ngrams));
		
		# step #3
		# dedice whether the query should be segmented as result of step#2 or not segmented
		# by calculating the MI between the two n-gram pairs
		# we try to discover multi-word topic from the query, query as single words is not considered as a segmentation and will be used as baseline for comparison
		my $did = &calWeight($ngrampair, "$outd/q$qn", $seg_threshold);
		if ($did == 0) {
			# not segment, query should be considered as a whole string
			$ngram_seg = $in_ngram;
			print "multi-gram query segment: $in_ngram is segmented as a whole: " + "$ngram_seg" . "\n";
		}
		elsif ($did == 1) {
			# query should be segmented as multiple sub ngrams
			foreach my $ngram (split/,/, $ngrampair) {
				my @tmp = split(/ /, $ngram); 
            	if (scalar(@tmp) == 2) {
                	$ngram_seg .= &segByMI($ngram);
                }
                elsif (scalr(@tmp) == 1) {
                	$ngram_seg .= $ngram . '|';
                }
                elsif (scalr(@tmp) > 2) {
                	# dynamic_process includes step#1, #2, and #3
                	# called repeatly until the length of any ngram is <=2
					# return the segmented query string
                	$ngram_seg .= &dynamic_process($ngram);
               	}		
        	}
		}
	
	return $ngram_seg;
	
}

#-----------------------------------------------------------
#  create hash from file
#-----------------------------------------------------------
#  arg1 = infile
#  arg2 = pointer to hash to create
#-----------------------------------------------------------
sub mkhash {
    my($file,$hp)=@_;

    open(IN,$file) || die "can't read $file";
    my @terms=<IN>;
    close IN;
    chomp @terms;
    foreach my $word(@terms) { $$hp{$word}=1; }

} #endsub mkhash

