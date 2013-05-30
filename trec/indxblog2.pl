#!/usr/bin/perl -w

# -----------------------------------------------------------------
# Name:      indxblog2.pl
# Author:    Kiduk Yang, 6/20/2006
#             modifed 5/29/2007
#             modifed 6/2/2008
#             $Id: indxblog2.pl,v 1.1 2008/06/27 00:42:14 kiyang Exp $
# -----------------------------------------------------------------
# Description:  INDEXING STEP 2 for Blog track
#   1. stop & stem preprocessed files from indxblog1.pl
#   2. generate sequential index files
# -----------------------------------------------------------------
# Arguments: arg1 = run mode (0=test, 1=docs, 2=docx)
#            arg2 = fnsub number
#            arg3 = (optional) fnsub directory
# Input:     $ddir/fnsub/$arg2 -- list of files to process
#            $ddir/YYYYMMDD/docs/pml$nnn -- processed body text files
#            $ddir/YYYYMMDD/nulldoc      -- list of null docs
#                WIDIT_DOCN TREC_DOCN URL (per line)
#            $ddir/YYMMDD/nonEdoc      -- list of non-English docs
#            $ddir0/YYMMDD/nonEdoc     -- 2007 list of non-English docs
#                WIDIT_DOCN TREC_DOCN URL (per line)
#            $npdir/krovetz.lst -- dictionary subset for combo/krovetz stemmer
#            $tpdir/pnounxlist  -- proper noun list for stemmer exclusion
#            $tpdir/pfxlist     -- prefix list
#            $tpdir/abbrlist3   -- abbr. & acronym list
#            $tpdir/stoplist1   -- document stopwords
# Output:    $ddir/sub$arg2/seqindx/$nnn -- seq. index files
#            $ddir/sub$arg2/dnref   -- WIDIT to TREC doc number mapping
#                WIDIT_DOCN TREC_DOCN (per line)
#            $ddir/sub$arg2/fnref   -- Filename to WIDIT doc number mapping
#                FileNum FilePath first_WIDIT_DOCN last_WIDIT_DOCN (per line)
#            $ddir/$arg2/$prog        -- program     (optional)
#            $ddir/$arg2/$prog.log    -- program log (optional)
# -----------------------------------------------------------------
# Sequential file format:
#   <DN>docN</DN>
#   WORD total_FREQ B_FREQ T_FREQ ... (per line)
#
#   e.g. apple 5 B3 T2
#
#   where
#   B - body text
#   T - title
#
# -----------------------------------------------------------------------------
# NOTE:
#   1. multiple subdirectories can be aggregated into one subdirectory (subN)
#   2. multiple documents per input/output file
#   3. long words are excluded
# -----------------------------------------------------------------


use strict;
use Data::Dumper;
$Data::Dumper::Purity=1;

my ($debug,$filemode,$filemode2,$dirmode,$dirmode2,$author,$group);
my ($log,$logd,$sfx,$noargp,$append,@start_time);

$log=1;                              # program log flag
$debug=0;                            # debug flag
$filemode= 0640;                     # to use w/ perl chmod
$filemode2= 640;                     # to use w/ system chmod
$dirmode= 0750;                      # to use w/ perl mkdir
$dirmode2= 750;                      # to use w/ system chmod (directory)
$group= "trec";                      # group ownership of files
$author= "kiyang\@indiana.edu";      # author's email


#------------------------
# global variables
#------------------------

my $wpdir=  "/u0/widit/prog";           # widit program directory
my $tpdir=  "$wpdir/trec08";            # TREC program directory
my $npdir=  "$wpdir/nstem";             # stemmer program directory
my $pdir=   "$tpdir/blog";              # Blog track program directory
my $ddir=   "/u3/trec/blog08";          # TREC index directory

my $subdict="$npdir/krovetz.lst";       # dictionary subset for stemmer
my $xlist="$tpdir/pnounxlist";          # proper nouns to exclude from stemming
my $abbrlist="$tpdir/abbrlist3";        # acronym & abbreviation list
my $pfxlist="$tpdir/pfxlist";           # valid prefix list
my $stopfile= "$tpdir/stoplist1";       # stopword list

require "$wpdir/logsub.pl";   # subroutine library
require "$tpdir/indxsub.pl";  # indexing subroutine library


#------------------------
# program arguments
#------------------------
my $prompt=
"arg1= run mode (0=test, 1=docs, 2=docx)\n".
"arg2= fnsub number\n".
"arg3= (optional) fnsub directory\n\n";

my %valid_args= (
0 => " 0 1 2 ",
);

my ($arg_err,$dtype,$subn,$fsubd)= chkargs($prompt,\%valid_args,2);
die "$arg_err\n" if ($arg_err);


# list of files to process
my $fnsub;
if ($fsubd) {
    $fnsub= "$ddir/$fsubd/$subn"; 
}
else {
    $fnsub= "$ddir/fnsub/$subn"; 
}

# output directory
my $outd;
if ($dtype==0) { $outd=  "$ddir/subt$subn"; }
elsif ($dtype==1) { $outd=  "$ddir/sub$subn"; }
elsif ($dtype==2) { $outd=  "$ddir/subx$subn"; }

my $seqd=  "$outd/seqindx";     # seqindx directory
my $fnref= "$outd/fnref";       # filen to filename mapping
my $dnref= "$outd/dnref";       # dn to docno


#-------------------------------------------------
# start program log
#-------------------------------------------------

# program log file suffix
if ($dtype==0) { $sfx=  "T"; }
elsif ($dtype==2) { $sfx=  "x"; }
else { $sfx=  ""; }

$noargp=0;             # if 1, do not print arguments to log
$append=0;             # log append flag

# create output directory if needed
if (!-e $seqd) {
    my @errs= &makedir($seqd,$dirmode,$group);
    print "\n",@errs,"\n\n" if (@errs);
}

if ($log) {
    @start_time= &begin_log($outd,$filemode,$sfx,$noargp,$append);
    print LOG "INF = $fnsub\n",
              "OUTF= $outd/dnref, fnref\n",
              "      $seqd/\$n\n\n";
}


#-------------------------------------------------
# create word hashes : key=word, val=1
#  - %stoplist: stopwords
#  - %xlist:    proper nouns that shouldn't be stemmed
#  - %sdict:    word list for Combo/Krovetz stemmer
#  - %abbrlist: word list for acronyms and abbreviations
#  - %pfxlist:  word list for valid prefixes
#-------------------------------------------------

# create the stopword hash
my %stoplist;
&mkhash($stopfile,\%stoplist);

# create proper noun hash
my %xlist;
&mkhash($xlist,\%xlist);

# create krovetz dictionary subset hash
my %sdict;
&mkhash($subdict,\%sdict);

# create acronym/abbreviation hash
my %abbrlist;
open(IN,$abbrlist) || die "can't read $abbrlist";
while(<IN>) {
    my ($word)=split/ /;
    $abbrlist{"\U$word"}=1;
}
close IN;

# create prefix hash
my %pfxlist;
open(IN,$pfxlist) || die "can't read $pfxlist";
while(<IN>) {
    my ($word)=split/-/;
    $pfxlist{"\L$word"}=1;
}
close IN;


#--------------------------------------------------------------------
#  create %fnsub:
#    k= directories (YYYYMMDD) to process
#    v= pointer to fileN array
#--------------------------------------------------------------------

my %fnsub;
open(IN,$fnsub) || die "can't read $fnsub";
while(<IN>) {
    my($n,$file)=split/ /;
    my($yymmdd,$fn)=split(/-/,$file);
    push(@{$fnsub{$yymmdd}},$fn);
}
close IN;


#-------------------------------------------------
# create the sequential indexes
#   1. stop & stem
#   2. count word frequencies
#      - field specific & total
#   Note: multiple subdirectories are aggregated
#-------------------------------------------------

open(DNREF,">$dnref") || die "can't write to $dnref";
open(FNREF,">$fnref") || die "can't write to $fnref";

my $docN=0;
my $fileN=0;
my $fcnt=1;

foreach my $yymmdd(sort keys %fnsub) {

    my $indir= "$ddir/$yymmdd";     # data directory
    my $docdir= "$indir/docs";      # document directory

    my $nonEdoc0="$indir/nonEdoc0"; # list of non-English blogs from feed
    my $nonEdoc="$indir/nonEdoc";   # list of non-English blogs
    my $nulldoc0="$indir/nulldoc0"; # list of null content blogs from feed (404.htm)
    my $nulldoc="$indir/nulldoc";   # list of null content blogs
    my $nulldocx="$indir/nulldocx"; # list of null content blogs after noise exclusion

    # nonEdoc found in 2007
    my $nonEdocOld= $nonEdoc;
    $nonEdocOld=~s|blog08|blog07|;

    # use noise-reduced blogs
    if ($dtype==2) {
	$docdir= "$indir/docx";      # document directory
    }

    my (%nulldoc,%nonEdoc,%nulldocx)=();

    open(INF,"$nulldoc") || die "can't read $nulldoc";
    while(<INF>) {
	chomp;
	my($dn,$docno)=split/ /;
	$nulldoc{$docno}=1;
    }
    close INF;

    open(INF,"$nulldoc0") || die "can't read $nulldoc0";
    while(<INF>) {
	chomp;
	my($dn,$docno)=split/ /;
	$nulldoc{$docno}=1;
    }
    close INF;

    open(INF,"$nonEdoc") || die "can't read $nonEdoc";
    while(<INF>) {
	chomp;
	my($dn,$docno)=split/ /;
	$nonEdoc{$docno}=1;
    }
    close INF;

    open(INF,"$nonEdoc0") || die "can't read $nonEdoc0";
    while(<INF>) {
	chomp;
	my($dn,$docno)=split/ /;
	$nonEdoc{$docno}=1;
    }
    close INF;

    open(INF,"$nonEdocOld") || die "can't read $nonEdocOld";
    while(<INF>) {
	chomp;
	my($dn,$docno)=split/ /;
	$nonEdoc{$docno}=1;
    }
    close INF;

    if ($dtype==2) {
	open(INF,"$nulldocx") || die "can't read $nulldocx";
	while(<INF>) {
	    chomp;
	    my($dn,$docno)=split/ /;
	    $nulldocx{$docno}=1;
	}
	close INF;
    }


    foreach my $fn(sort @{$fnsub{$yymmdd}}) {

	last if (($dtype==0) && ($fcnt++>2));  #!! for testing

	$fileN++;

	my $inf = "$docdir/pml$fn";
	my $outf = "$seqd/$fileN";

	my $fdocn= $docN+1;    # first doc# in a file
	print FNREF "$fileN $inf $fdocn";

	# process files
	print LOG "-- Processing $inf --", timestamp(), "\n";
	my $ldocn= &mkseqindx($inf,$outf,\%nonEdoc,\%nulldoc,\%nulldocx);

	print FNREF " $ldocn\n";

    }

} #endforeach $yymmdd

close DNREF;
close FNREF;


#-------------------------------------------------
# end program
#-------------------------------------------------

print LOG "\nProcessed $fileN files ($docN docs)\n";

&end_log($pdir,$outd,$filemode,@start_time) if ($log);

# notify author of program completion
#&notify($sfx,$author);


##############################################
# SUBROUTINES
##############################################

BEGIN { print STDOUT "\n"; }
END { print STDOUT "\n"; }

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


#-----------------------------------------------------------
# read in processed files and output sequential index
#-----------------------------------------------------------
#  arg1   = processed document file
#  arg2   = sequential index file
#  arg3   = pointer to nonEdoc hash
#  arg4   = pointer to nulldoc hash
#  arg5   = pointer to nulldocx hash
#  r.v.   = last docN
#-----------------------------------------------------------
sub mkseqindx {
    my ($in,$out,$nehp,$nlhp,$nlxhp)= @_;

    my @times= &start_clock("SUBROUTINE MKSEQINDX \#$fileN") if ($log==2);

    # processed output file
    open(IN,$in) || die "can't read $in";
    my @lines=<IN>;
    close IN;

    my @docs= split(/<\/doc>\n<doc>\n/,join("",@lines));

    # sequential index file
    open(OUT,">$out") || die "can't write to $out";

    foreach my $doc(@docs) {

        my ($docno,$title,$body);
        if ($doc=~m|<docno>(.+?)</docno>.+?<ti>(.*?)</ti>.*?<body>(.*?)</body>|s) {
            ($docno,$title,$body)=($1,$2,$3);
        }
        elsif ($doc=~m|<docno>(.+?)</docno>\n.+?\n<ti>(.*?)</ti>\n.*?\n<body>\n(.*?)\n</body>|s) {
            ($docno,$title,$body)=($1,$2,$3);
        }

        # skip null content or non-English docs
        next if (exists($$nlhp{$docno}) || exists($$nehp{$docno}));
        next if ($dtype==2 && exists($$nlxhp{$docno}));

        $docN++;
        print DNREF "$docN $docno\n";
        print OUT "<DN>$docN</DN>\n";

        print "!ti=$title!\n!blog=$body!\n" if ($debug);

	# field-specific word count hashes
	my (%h1,%h2,%hall,%wdcnt)=();

        # all whitespaces including newline were compressed to single blank in indxblog1.pl
        #$body=~s/\n+/ /g;

        # stop & stem (0=simple stemmer)
        my @words= &getword2($body,\%abbrlist,\%pfxlist);
        &countwd(\@words,\%h1,\%stoplist,\%xlist,\%sdict,0);

        if ($title) {
            # stop & stem (0=simple stemmer)
	    @words= &getword2($title,\%abbrlist,\%pfxlist);
	    &countwd(\@words,\%h2,\%stoplist,\%xlist,\%sdict,0);
        }

        if ($debug) {
            foreach my $k(sort keys %h1) {
                print " wd=$k, fq=$h1{$k}\n";
            }
        }

        # hash to map tag prefix to word count hash
        #   key = tag prefix
        #   val = pointer to field-specific hash
        my %taghash = (
            'B' => \%h1,       # body text
            'T' => \%h2,       # title text
        );

	# tally up field-specific word counts
	foreach my $k(sort keys %taghash) {
	    my $hp= $taghash{$k};  
	    foreach my $wd(keys %$hp) {
		$wdcnt{$wd} .= " $k$$hp{$wd}";
		$hall{$wd} += $$hp{$wd};
	    }
	}

	# print out word freqs
	foreach my $wd(sort keys %wdcnt) {
	    # WORD total_FREQ B_FREQ T_FREQ (per line)
	    print OUT "$wd $hall{$wd}$wdcnt{$wd}\n";
	}

    } # end-foreach (@docs)


    close OUT;

    &stop_clock("SUBROUTINE MKSEQINDX \#$fileN","",@times) if ($log==2);

    return $docN;

} # endsub mkseqindx
