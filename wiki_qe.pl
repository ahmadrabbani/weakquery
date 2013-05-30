#!/usr/bin/perl -w

# ----------------------
# Wikipedia enhanced query expansion with segmented query
# ----------------------
# Ver 0.1
# 9/26/2011
# ----------------------

use strict;
use warnings;
use DBI;



my $home_dir = "/home/huizhang";
#my $home_dir = "/home/hz3";
my $res_dir = "$home_dir/workspace/epic_prog/query/result/with_stop";
#my $wk_hard_hit_dir = "$home_dir/Desktop/dissertation/query/segment/wk/hits/hard";
#my $wk_blog_hit_dir = "$home_dir/Desktop/dissertation/query/segment/wk/hits/blog";
my $gg_hard_hit_dir = "$home_dir/Desktop/dissertation/query/segment/gg/hits/hard";
my $gg_blog_hit_dir = "$home_dir/Desktop/dissertation/query/segment/gg/hits/blog";
require "$home_dir/workspace/epic_prog/sub/spidersub_2010.pl";
require "$home_dir/workspace/epic_prog/sub/logsub2.pl";
require "$home_dir/workspace/epic_prog/trec/QEsub.pl";
require "$home_dir/workspace/epic_prog/sub/indxsub_2010.pl";
require "$home_dir/workspace/epic_prog/sub/NLPsub_2010.pl";

# segment is a Wikipedia topic: query expand with title, redirect, and 1st paragraph, take top 20 terms by tf
# segment is not a Wikipedia topic: search Wikipedia with quotation, expand query with top 20 results, take top 20 terms by LCA
# keyword query: search Wikipedia, expand query with top 20 results, take top 20 terms by LCA

my $res_hard_file = "$res_dir/hard05.rsl";
my $res_blog_file = "$res_dir/06-08_blog.rsl";

#open(IN, "<$res_hard_file") || die "cannot open $res_hard_file\n";
open(IN, "<$res_blog_file") || die "cannot open $res_blog_file\n";
my @lines = <IN>;
#chomp @lines;
close IN;

#------------------------
# Start MySQL
#------------------------

my $database = "en_20110526";
my $hostname = "localhost";
my $port = "3306"; 
my $user = "root";
my $password = "hziub1972";

my $dbh = DBI->connect("DBI:mysql:database=$database;host=$hostname", $user, $password) || die "cannot connect to database:" . DBI->errstr;
my $qn = 1;

foreach my $line (@lines){
	$line =~ s/^Segmented query://;
	#print $line;
	my ($r, $n) = split(/::/, $line);
	print $r . "\n";
	if ($r =~ /\|\|/){
		# multiple segmentations: topic and context
		my @s = split(/\|\|/, $r);
		my $seged_qry = shift(@s);
		if ($seged_qry =~ /" /){
			#print $seged_qry;
			#"Hubble Telescope:40203" Achievements:22562196 
			#"Waves  Brain" Radio Cancer
			#"Hubble Telescope Achievements" 
			
			#wk article expansion
			#hask key: term, value: tf
			my %wk_db_terms;
			
			#wk LCA expansion
			#hash key: term, value: weight
			my %wk_lca_terms;
			
			my @terms = split(/" /, $seged_qry);
			foreach my $term (@terms){
				if($term =~ /:\d+/ && $term !~ /:22562196/){
					#22562196 is lectionary
					&wkMysqlExpand(lc($term), \%wk_db_terms);
				}
				else{
					my @words = split(/ /, $term);
					if (scalar(@words) > 1){
						#only expand ngrams
						$term =~ s/\s+$//;
						$term =~ s/:22562196//;
						#&wkLcaExpand(lc($term), \%wk_lca_terms, $qn, $gg_hard_hit_dir);
						&wkLcaExpand(lc($term), \%wk_lca_terms, $qn, $gg_blog_hit_dir);
					}
				}
			}
			
			my $maxN = 20;
			
			#hash key: term
			#value: normalized tf/weight
			my ($top_wk_db_terms_ref, $top_wk_lca_terms_ref);
			
			$top_wk_db_terms_ref = &getTopExpandTerms(\%wk_db_terms, $maxN);
			$top_wk_lca_terms_ref = &getTopExpandTerms(\%wk_lca_terms, $maxN);
			
			print $seged_qry . ":" . "\n";
			print "wk_db_terms:";  
			foreach my $k(sort {$top_wk_db_terms_ref->{$b}<=>$top_wk_db_terms_ref->{$a}} keys %$top_wk_db_terms_ref){
				print $top_wk_db_terms_ref->{$k} . ' ' . $k . ' ';
			}
			print "\n";
			
			print "wk_lca_terms:";
			foreach my $k (sort {$top_wk_lca_terms_ref->{$b}<=>$top_wk_lca_terms_ref->{$a}} keys %$top_wk_lca_terms_ref){
				print $top_wk_lca_terms_ref->{$k} . ' ' . $k . ' ';
			}
			
			print "\n";
			
		}	
		else {
			# this will never happens
		}	
	}
	else {
		# whole query is one topic
		#"human smuggling:68714"
		#"Cult Lifestyles"
		
		#wk article expansion
		#hask key: term, value: tf
		my %wk_db_terms;
		
		#wk LCA expansion
		#hash key: term, value: weight
		my %wk_lca_terms;
		
		if($r =~ /:\d+/ && $r !~ /:22562196/){
			&wkMysqlExpand(lc($r), \%wk_db_terms);
		}
		else{
			$r =~ s/\s+$//;
			$r =~ s/:22562196//;
			#&wkLcaExpand(lc($r), \%wk_lca_terms, $qn, $gg_hard_hit_dir);
			&wkLcaExpand(lc($r), \%wk_lca_terms, $qn, $gg_blog_hit_dir);
		}
		
		my $maxqeN = 20;
		
		#hash key: term
		#value: normalized tf/weight
		my ($top_wk_db_terms_ref, $top_wk_lca_terms_ref);
		
		$top_wk_db_terms_ref = &getTopExpandTerms(\%wk_db_terms, $maxqeN);
		$top_wk_lca_terms_ref = &getTopExpandTerms(\%wk_lca_terms, $maxqeN);
		
		print $r . ":" . "\n";
		print "wk_db_terms:";
		foreach my $k(sort {$top_wk_db_terms_ref->{$b}<=>$top_wk_db_terms_ref->{$a}} keys %$top_wk_db_terms_ref){
			print $top_wk_db_terms_ref->{$k} . ' ' . $k . ' ';
		}
		print "\n";
		
		print "wk_lca_terms:";
		foreach my $k (sort {$top_wk_lca_terms_ref->{$b}<=>$top_wk_lca_terms_ref->{$a}} keys %$top_wk_lca_terms_ref){
			print $top_wk_lca_terms_ref->{$k} . ' ' . $k . ' ';
		}
		
		print "\n";	
		
	}# end if-else
	$qn++;
	
}


sub wkMysqlExpand{
	#print "Enter wkMysqlExpand\n";charlie rose
	my ($topic, $qeterm_hash_ref) = @_;
	
	$topic =~ s/^"|^\s+|\s+$// if ($topic =~ /^"|^\s+|\s+$/);
	
	my ($term_str, $wk_page_id) = split(/:/, $topic);
	
	my $query = "SELECT page_title FROM page WHERE page_id=" . "'" . $wk_page_id . "'";
	my $sth = $dbh->prepare($query) || die "cannot prepapre statement:" . $dbh->errstr();
	$sth->execute;
	
	my ($title) = $sth->fetchrow_array if ($sth->rows == 1);
	$sth->finish;
	
	$query = "SELECT df_firstParagraph FROM definition WHERE df_id=" . "'" . $wk_page_id . "'";
	$sth = $dbh->prepare($query) || die "cannot prepare statement:" . $dbh->errstr();
	$sth->execute;
	
	my ($result) = $sth->fetchrow_array if $sth->rows == 1;
	$sth->finish;
	
	my $big_str = lc($title . ' ' . $result);
	
	my @words = split(/ /, $big_str);
	
	my $stopfile= "$home_dir/workspace/epic_prog/stoplist1";     
	my %stoplist;
	&mkhash($stopfile,\%stoplist);
	
	foreach my $word (@words){
		$word =~ s/'|"|\(|\)|\{|\}|\[|\]|\||\*|\?|\.//g;
		#print $word . "\n";
		next if ($stoplist{lc($word)});
		
		my @occurrence = $big_str =~ /\b$word\b/g;
		$qeterm_hash_ref->{$word} = scalar(@occurrence);
	}

}#end sub wkMysqlExpand

 
sub wkLcaExpand{
	#print "Enter wkLcaExpand\n";
	my ($topic, $qeterm_hash_ref, $qn, $hit_dir) = @_;
	
	my $maxdN = 20;
	
	$topic =~ s/^"|^\s+|\s+$// if ($topic =~ /^"|^\s+|\s+$/);
	$topic =~ s/-/ /g;
	#my $status = &queryWikipedia($topic, $hit_dir, $qn);
	my $htmlcnt = &queryGoogle2( $topic, $hit_dir, $qn, $maxdN);
	
	my @words = split(/ /, $topic);
	my $stopfile= "$home_dir/workspace/epic_prog/stoplist1";     
	my %stoplist;
	&mkhash($stopfile,\%stoplist);
	# query term hash
    my %qrywd;
    
    # read in result links
    open(LINK,"$hit_dir/lk$qn") || die "can't read $hit_dir/lk$qn";
    my @links=<LINK>;
    close LINK;
    chomp @links;
    
    my $maxhtmN = 20;
    my $dirmode= 0750;                      # to use w/ perl mkdir
    my $group= "trec";                      # group ownership of files
    
    my $outd2= "$hit_dir/q$qn";
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
        open (OUT, ">$outf") || die "can not write to $outf";
        print OUT $htm if ($htm);
        close(OUT);

        my $outf2= "$outd2/r$fn.txt";
        open (OUT2, ">$outf2") || die "can not write to $outf2";
        binmode(OUT2,":utf8");
        print OUT2 "$title\n\n" if ($title);
        print OUT2 "$body\n" if ($body);
        close(OUT2);
        $fn++;

    }
	
	foreach (@words){
		next if ($stoplist{lc($_)});
		$qrywd{lc($_)}=5;
	}
	
	my %LCA;
	#&LCA("$hit_dir/q$qn", \%qrywd, $maxdN, \%LCA, \%stoplist);
	&LCA("$hit_dir/q$qn", \%qrywd, $maxdN, $qeterm_hash_ref, \%stoplist);
	
	my $maxtN = 20;
	my $outf= "$hit_dir/qft$qn.$maxdN";
    open(OUT,">$outf") || die "can't write to $outf";
    my ($tcnt,@qxterms)=(1);
    #foreach my $term(sort {$LCA{$b}<=>$LCA{$a}} keys %LCA) { 
    foreach my $term(sort {$qeterm_hash_ref->{$b}<=>$qeterm_hash_ref->{$a}} keys %$qeterm_hash_ref) { 
        #next if (exists($qrywd{$term}) || exists($qrywd{$term.'s'}));
        #next if ($qrystr=~/$term/i);
        #printf OUT "$term %.8f\n",$LCA{$term} if ($tcnt<=$maxtN);
        printf OUT "$term %.8f\n",$qeterm_hash_ref->{$term} if ($tcnt<=$maxtN);
        if ($tcnt<=10) {
            
            #my $wt= sprintf("%.0f",$LCA{$term});
            my $wt= sprintf("%.0f",$qeterm_hash_ref->{$term});
            push(@qxterms,"$term:$wt");
        }
        $tcnt++;
    }
	
	
	
}#end sub wkLcaExpand


sub getTopExpandTerms {
	#print "Enter getTopExpandTerms\n";
	my ($wk_term_ref, $maxN) = @_;
	
	my %wk_term = %$wk_term_ref;	
	my %top_wk_term;
	my ($count, $sum) = 0;
	
	#take maxN according to score
	foreach my $word(sort {$wk_term{$b}<=>$wk_term{$a}} keys %wk_term) {
		if ($count < $maxN){
			$sum += $wk_term{$word};
			$top_wk_term{$word} = $wk_term{$word};
		}
		$count++;
	}
	

	#normalize score, the sum is 1
	foreach my $key (keys %top_wk_term){
		my $score = $top_wk_term{$key};
		$top_wk_term{$key} = $score/$sum;
	}	
	
	return \%top_wk_term;
	
	
	
	
}#end sub getTopExpandTerms

#-----------------------------------------------------------
#  create hash from file
#-----------------------------------------------------------
#  arg1 = infile
#  arg2 = pointer to hash to create
#-----------------------------------------------------------
sub mkhash {
	#print "Enter mkhash\n";
    my($file,$hp)=@_;

    open(IN,$file) || die "can't read $file";
    my @terms=<IN>;
    close IN;
    chomp @terms;
    foreach my $word(@terms) { $$hp{$word}=1; }

} #endsub mkhash







