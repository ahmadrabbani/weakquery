#!/usr/bin/perl -w

# ----------------------
# Wikipedia enhanced query expansion with segmented query
# segment is a Wikipedia topic: query expand with title, redirect, and 1st paragraph, take top 20 terms by tf
# segment is not a Wikipedia topic: search Wikipedia with quotation, expand query with top 20 results, take top 20 terms by LCA
# keyword query: search Wikipedia, expand query with top 20 results, take top 20 terms by LCA
# ----------------------
# Ver 1.0
# 11/16/2011
# ----------------------
# use QE_OUT to avoid possible issue with 
# same OUT to LCA
# ----------------------

use strict;
use warnings;
use DBI;


my $home_dir = "/home/huizhang";
#my $home_dir = "/home/hz3";
require "$home_dir/workspace/epic_prog/sub/spidersub_2010.pl";
require "$home_dir/workspace/epic_prog/sub/logsub2.pl";
require "$home_dir/workspace/epic_prog/trec/QEsub.pl";
require "$home_dir/workspace/epic_prog/sub/indxsub_2010.pl";
require "$home_dir/workspace/epic_prog/sub/NLPsub_2010.pl";


my $res_dir = "$home_dir/workspace/epic_prog/query/result/with_stop";
#my $result_hit_dir = "$home_dir/workspace/epic_prog/query/segment/gg/hits/hard";
my $result_hit_dir = "$home_dir/workspace/epic_prog/query/segment/gg/hits/blog";
#my $original_qry_file = "$home_dir/Desktop/dissertation/data/topics/hard05.50.topics_qn.run";
#my $original_qry_file = "$home_dir/Desktop/dissertation/data/topics/06-08.all-blog-topics_qn.run";
my $original_qry_file = "$home_dir/Desktop/dissertation/data/topics/topic.run";

#my $result_file = "$res_dir/hard05.rsl";
#my $result_file = "$res_dir/06-08_blog.rsl";
#my $result_file = "$res_dir/hard05_wsd.rsl";
my $result_file = "$res_dir/06-08_blog_wsd.rsl";

open(IN, "<$result_file") || die "cannot open $result_file\n";
my @lines = <IN>;
chomp @lines;
close IN;

#my $output_file = "$res_dir/hard05_qe.term";
#my $output_file = "$res_dir/06-08_blog_qe.term";
#my $output_file = "$res_dir/hard05_wsd_qe.term";
my $output_file = "$res_dir/06-08_blog_wsd_qe.term";

open (QE_OUT, ">$output_file") || die "cannot write to $output_file\n";

#------------------------
# Start MySQL
#------------------------

my $database = "en_20110526";
my $hostname = "localhost";
my $port = "3306"; 
my $user = "root";
my $password = "hziub1972";

my $dbh = DBI->connect("DBI:mysql:database=$database;host=$hostname", $user, $password) || die "cannot connect to database:" . DBI->errstr;
my $qcnt = 0;

foreach my $line (@lines){
	$line =~ s/^Segmented query://;
	#print $line;
	my ($res, $qn) = split(/::/, $line);
	#print QE_OUT $res . ' ' . $qn . "\n";
	
	my $original_qry = &getOriginalQry($original_qry_file, $qn);
	#print QE_OUT "original qry:" . $original_qry . "\n";
	
	#gg LCA expansion
	#hash key: expansion term, value: weight
	my %gg_lca_terms;
	&ggLcaExpand(lc($original_qry), \%gg_lca_terms, $qn, $result_hit_dir);
	my @gg_lca_keys = keys %gg_lca_terms;
	#print QE_OUT "number of gg_lca_keys: " . scalar(@gg_lca_keys) . "\n";
	
	if ($res =~ /\|\|/){
		#print QE_OUT "multiple segmentations: topic and context" . "\n";
		# multiple segmentations: topic and context
		my @res = split(/\|\|/, $res);
		my $top_res = shift(@res);
		if ($top_res =~ /" /){
			#print $seged_qry;
			#"Hubble Telescope:40203" Achievements:22562196 
			#"Waves  Brain" Radio Cancer
			#"Hubble Telescope Achievements" 
			
			#wk article expansion
			#hask key: term, value: tf
			my %wk_db_terms;
			
			my @segs = split(/" /, $top_res);
			foreach my $seg (@segs){
				if($seg =~ /:\d+/ && $seg !~ /:22562196/){
					#22562196 is lectionary
					$seg =~ s/^"|^\s+|\s+$// if ($seg =~ /^"|^\s+|\s+$/);
					&wkMysqlExpand(lc($seg), \%wk_db_terms);
				}
			}
			
			my $maxN = 20;
			
			#hash key: term
			#value: normalized tf/weight
			my ($top_wk_db_terms_ref, $top_gg_lca_terms_ref);
			
			$top_wk_db_terms_ref = &getTopExpandTerms(\%wk_db_terms, $maxN);
			$top_gg_lca_terms_ref = &getTopExpandTerms(\%gg_lca_terms, $maxN);
			
			print QE_OUT $top_res . '::' . $qn . ':' . "\n";
			print QE_OUT "wk_db_terms:";  
			foreach my $k(sort {$top_wk_db_terms_ref->{$b}<=>$top_wk_db_terms_ref->{$a}} keys %$top_wk_db_terms_ref){
				print QE_OUT $top_wk_db_terms_ref->{$k} . ' ' . $k . ' ';
			}
			print QE_OUT "\n";
			
			print QE_OUT "gg_lca_terms:";
			foreach my $k (sort {$top_gg_lca_terms_ref->{$b}<=>$top_gg_lca_terms_ref->{$a}} keys %$top_gg_lca_terms_ref){
				print QE_OUT $top_gg_lca_terms_ref->{$k} . ' ' . $k . ' ';
			}
			
			print QE_OUT "\n\n";
			
		}	
		else {
			# this will never happens
		}	
	}
	else {
		#print QE_OUT "whole query is one topic" . "\n";
		# whole query is one topic
		#"human smuggling:68714"
		#"Cult Lifestyles"
		
		#wk article expansion
		#hask key: term, value: tf
		my %wk_db_terms;
		
		if($res =~ /:\d+/ && $res !~ /:22562196/){
			$res =~ s/^"|^\s+|\s+$// if ($res =~ /^"|^\s+|\s+$/);
			&wkMysqlExpand(lc($res), \%wk_db_terms);
		}
		
		# !!!NOT create %gg_lca_terms again
		
		my $maxqeN = 20;
		
		#hash key: term
		#value: normalized tf/weight
		my ($top_wk_db_terms_ref, $top_gg_lca_terms_ref);
		
		$top_wk_db_terms_ref = &getTopExpandTerms(\%wk_db_terms, $maxqeN);
		$top_gg_lca_terms_ref = &getTopExpandTerms(\%gg_lca_terms, $maxqeN);
		
		print QE_OUT $res . '::' . $qn . ':' . "\n";
		print QE_OUT "wk_db_terms:";
		foreach my $k(sort {$top_wk_db_terms_ref->{$b}<=>$top_wk_db_terms_ref->{$a}} keys %$top_wk_db_terms_ref){
			print QE_OUT $top_wk_db_terms_ref->{$k} . ' ' . $k . ' ';
		}
		print QE_OUT "\n";
		
		print QE_OUT "gg_lca_terms:";
		foreach my $k (sort {$top_gg_lca_terms_ref->{$b}<=>$top_gg_lca_terms_ref->{$a}} keys %$top_gg_lca_terms_ref){
			print QE_OUT $top_gg_lca_terms_ref->{$k} . ' ' . $k . ' ';
		}
		
		print QE_OUT "\n\n";	
		
	}# end if-else
	$qcnt++;
	
}

print QE_OUT "Processed $qcnt queries\n\n";

# ----------
# arg1: topic
# arg2: return hash
# ----------

sub wkMysqlExpand{
	#print QE_OUT "Enter wkMysqlExpand\n";
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

# ----------
# arg1: topic
# arg2: return hash
# arg3: qn
# arg4: hit dir
# ----------
sub ggLcaExpand{
	#print QE_OUT "Enter ggLcaExpand\n";
	my ($topic, $qeterm_hash_ref, $qn, $hit_dir) = @_;
	#print QE_OUT $topic . ' ' . $hit_dir . "\n";
		
	my $maxdN = 20;
	
	$topic =~ s/^\s+|\s+$// if ($topic =~ /^\s+|\s+$/);
	$topic =~ s/"//g if ($topic =~ /"/);
	$topic =~ s/-/ /g;
	
	#print QE_OUT "LCA topic: " . $topic . "\n";
	
	my @words = split(/ /, $topic);
	my $stopfile= "$home_dir/workspace/epic_prog/stoplist1";     
	my %stoplist;
	&mkhash($stopfile,\%stoplist);
	# query term hash
    my %qrywd;
	
	foreach (@words){
		next if ($stoplist{lc($_)});
		$qrywd{lc($_)}=5;
	}
	
	my %LCA;
	#&LCA("$hit_dir/q$qn", \%qrywd, $maxdN, \%LCA, \%stoplist);
	&LCA("$hit_dir/q$qn", \%qrywd, $maxdN, $qeterm_hash_ref, \%stoplist);
	
	my $maxtN = 20;
	my $outf= "$hit_dir/qft$qn.$maxdN";
    open(LCA,">$outf") || die "can't write to $outf";
    my ($tcnt,@qxterms)=(1);
    #foreach my $term(sort {$LCA{$b}<=>$LCA{$a}} keys %LCA) { 
    foreach my $term(sort {$qeterm_hash_ref->{$b}<=>$qeterm_hash_ref->{$a}} keys %$qeterm_hash_ref) { 
        #next if (exists($qrywd{$term}) || exists($qrywd{$term.'s'}));
        #next if ($qrystr=~/$term/i);
        #printf LCA "$term %.8f\n",$LCA{$term} if ($tcnt<=$maxtN);
        printf LCA "$term %.8f\n",$qeterm_hash_ref->{$term} if ($tcnt<=$maxtN);
        if ($tcnt<=$maxtN) {
            
            #my $wt= sprintf("%.0f",$LCA{$term});
            my $wt= sprintf("%.0f",$qeterm_hash_ref->{$term});
            push(@qxterms,"$term:$wt");
        }
        $tcnt++;
    }
	
}#end sub ggLcaExpand

# ----------
# arg1: term hash
# arg2: top k
# ----------
# r.v.: top k term
# ----------
sub getTopExpandTerms {
	#print QE_OUT "Enter getTopExpandTerms\n";
	my ($wk_term_ref, $maxN) = @_;
	
	my %wk_term = %$wk_term_ref;	
	my %top_wk_term;
	my ($count, $sum) = 0;
	
	my @wk_keys = keys %wk_term;
	#print QE_OUT "number of wk_term: " . scalar(@wk_keys) . "\n";
	
	#take maxN according to score
	foreach my $word(sort {$wk_term{$b}<=>$wk_term{$a}} keys %wk_term) {
		if ($count < $maxN){
			$sum += $wk_term{$word};
			$top_wk_term{$word} = $wk_term{$word};
		}
		$count++;
	}
	
	my @top_keys = keys %top_wk_term;
	#print QE_OUT "number of top_wk_term: " . scalar(@top_keys) . "\n";
	
	#normalize score, the sum is 1
	foreach my $key (keys %top_wk_term){
		my $score = $top_wk_term{$key};
		$top_wk_term{$key} = $score/$sum;
	}	
	
	return \%top_wk_term;
	
}#end sub getTopExpandTerms

# ----------
# arg1: original qry file
# arg2: qn
# ----------
# r.v.: original qry
# ----------
sub getOriginalQry {
	#print QE_OUT "Enter getOriginalQry\n";
	my ($qry_file, $qn) = @_;
	
	#print QE_OUT "qn" . ' ' . $qn . "\n";
	open (IN, "<$qry_file") || die "cannot open $qry_file\n";
	my @lines = <IN>;
	chomp @lines;
	close IN;
	
	foreach my $line (@lines){
		my ($qry, $qn_1) = split(/::/, $line);
		if ($qn_1 eq $qn) {
			return $qry;
			last;
		}
	}
	
	
}#end sub getOriginalQry 


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







