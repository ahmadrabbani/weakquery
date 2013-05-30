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

my $home_dir = "/home/hz3"; 
my $tpdir = "$home_dir/workspace/epic_prog";    #programming directory
my $pdir = "$home_dir/Desktop/dissertation/prog";
my $wpdir = "$home_dir/Desktop/dissertation";
my $qdir = "$wpdir/query";
my $maxhtmN = 10;

require "$tpdir/sub/logsub2.pl";
require "$tpdir/sub/spidersub_2010.pl";
require "$tpdir/sub/indxsub_2010.pl";
require "$tpdir/sub/NLPsub_2010.pl";

my $gg_hits_dir = "$qdir/segment/gg/hits";    # for search results

my @outdir = ("$gg_hits_dir");
foreach my $outdir (@outdir) {
	if ( !-e $outdir ) {
		my @errs = &makedir( $outdir, $dirmode, $group );
		print "\n", @errs, "\n\n" if (@errs);
	}
}



my $query = "new york times square";
my $qn = 100;

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
	
	my $doc = join(' ', @stem_ws);
	
		
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

foreach my $topic ( keys %contexts ) {
		
		print $topic . ':';
		
		my $count_n = &gg_count( $topic, $contexts{$topic}, \@google_stem_docs );
		
		print $count_n . "\n";
		
}

sub gg_count {

	my ( $topic, $context, $google_docs_ref ) = @_;
	
	#new york:"time square" time square
		
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
			my @words = split(/ /, $topic);
			my $tf_topic = $doc =~ /\b$topic\b/i;
			$co_count += $tf_topic;
		}
	}
	
	return $co_count;

}    #end sub gg_count



