###########################################################
# subroutines for indexing modules
#   - Kiduk Yang, 6/2004
#----------------------------------------------------------
# getword0:     return an array of words from a string of words (minimal processing)
# getwords:     return an array of words from a string of words
# getword2:     return an array of words from a string of words (for blog processing)
# getword3:     return an array of words from a string of words (updated getword2, 7/14/07)
# stopwd:       flag stopwords
# procwords:    stop and stem text
# procword3:    stop and stem text (updated procwords, 7/14/07)
# stemword:     stem a word (updated to take nonstem list, 7/14/07)
# stemword2:    stop & stem a word (updated to take nonstem list, 7/14/07)
# countwd0:     count word frequencies (simplified version)
# countwd:      count word frequencies
# countwd2:     count word frequencies (double hash version)
# countwd3:     count word frequencies (updated countwd, 7/14/07)
# hash2file:    output hash to a file
# mkfnref:      make fnref hash from fnref file
# mkfnref2:     make fnref hash from fnref file for genomics
# mkfnrefall:   make fnref hash from fnref file for the all subcollections
# findfn:       get file number for a given document number
# subdocs:      subset target document lines from a multi-doc file
# getdocs:      get document lines for a list of document numbers
# getdocs_all:  get document lines for a list of document numbers
# getdf:        get term document frequency
# getctf:       get collection term frequency (occurence of term in whole collection)
# getctf_all:   get collection term frequency (occurence of term in whole collection)
# getstf:       get subcollection token frequency (number of tokens in subcollection)
# getttf:       get collection token frequency (number of tokens in whole collection)
# parseHTML:    parse out tags in HTML document
#----------------------------------------------------------
# calls stemsub.pl w/
#   Simple:     modified simple stemmer
#   Krovetz:    modified Krovetz stemmer
#   Porter:     Porter stemmer
#   combostem:  combo stemmer
###########################################################

use strict;

require "stemsub.pl";


#-----------------------------------------------------------
# return an array of words from a string of words
#   1. remove punctuations at word boundary
#   2. convert words to lowercase 
#   Note: 
#     - designed to capture non-word patterns (e.g. spam)
#     - parenthesis ()<>{}[] removed from input string
#-----------------------------------------------------------
#  arg1   = string
#  r.v.   = word array 
#-----------------------------------------------------------
sub getword0 {
    my ($str)=@_;

    # remove leading & trailing blanks from the string
    $str=~s/^ *(.+?) *$/$1/g;

    my @wd0= split(/\s+/,$str);

    my @wds;
    foreach (@wd0) {
	# remove punctuations at word boundary
	s/^["']*  (.+?)  ["':;,.?!]*$/$1/xg;
	# convert to lowercase
	tr/A-Z/a-z/;
	push(@wds,$_);
    }

    return (@wds);

} # endsub getword0


#-----------------------------------------------------------
# return an array of words from a string of words
#   1. preserve acronyms and abbreviations
#   2. splits words with underscore
#   3. split up hyphenated words
#      - exception: hyphenated bigrams w/ 2+ characters at word start & end
#   4. truncate string after '
#-----------------------------------------------------------
#  arg1   = string
#  arg2   = acronym and abbreviation hash
#  arg3   = prefix hash
#  r.v.   = word array 
#-----------------------------------------------------------
sub getwords {
    my ($str,$achp,$pfhp)=@_;

    # process abbreviations
    $str=~ s/([A-Z])\.([A-Z])/$1$2/g while ($str=~/[A-Z]\.[A-Z]/);

    # remove punctuations (except ')
    $str=~s/[(){}\[\]<>:;\`",.?!]+/ /g;

    # split words with underscore
    #$str=~ s|[/_]+| |g;
    $str=~ s|_+| |g;

    # save acronyms and abbreviations
    #  - 2 to 5 uppercase letters
    #  - a letter followed by a number
    my @names0= ($str=~ /\b[A-Z]{2,5}\b/g);
    my @names2= ($str=~ /\b[A-Z][0-9]\b/g); # save T1, K2, etc.
    #my @names3= ($str=~ /\b[A-Z]&[A-Z]\b/g); # save R&D, Q&A etc.
    # keep acronyms in acronym list only
    my @names1;
    foreach my $name(@names0) {
        if ($achp->{"$name"}) { push(@names1,$name); }
        else { push(@names1,"\L$name"); }
    }
    my @names= (@names1,@names2);

    # delete saved words from string
    foreach my $name(@names0,@names2) {
        $str=~s/\b$name\b/ /g;
    }

    # save special term: 9/11 !!
    $str=~ s!\b(9/11|sept. ?11)\b!9-11!gi;

    # delete trailing numbers
    #  - e.g. word05 to word
    my @words0= ($str=~ /\b[A-Za-z]+[0-9]+\b/g); 
    my @words;
    foreach my $word(@words0) {
        my $word2=$word;
        $word2=~s/\d+$//;
	push(@words,$word2);
    }

    # delete saved words from string
    foreach my $name(@words0) {
        $str=~s/\b$name\b/ /g;
    }

    # save hyphenated words: bigrams only
    #  - must start and end w/ two or more characters
    my @bigram0= ($str=~ /\b[a-z]{2,}-[a-z]{2,}\b/g);
    my @bigrams;
    foreach my $wd(@bigram0) {
	my($pfx)=split(/-/,$wd); 
	# keep only if valid prefix
	if ($$pfhp{"\L$pfx"}) {
	   push(@bigrams,$wd);
	}
    }

    # delete saved words from string
    foreach my $name(@bigrams) {
        $str=~s/\b$name\b/ /g;
    }

    # truncate string after '
    $str=~s/\b(\w+)'+\w+/ $1/g;

    # change - to blank (i.e. split word)
    $str=~s/\-+/ /g;

    # add saved words to the string
    $str .= " ".join(" ",@names,@words,@bigrams);

    # remove leading & trailing blanks from the string
    $str=~s/^ *(.+?) *$/$1/g;

    my @wds= split(/\s+/,$str);

    return (@wds);

} # endsub getwords


#-----------------------------------------------------------
# return an array of words from a string of words
#   1. exclude URLs, email address, words w/ underscore
#   2. preserve acronyms and abbreviations
#   3. split up hyphenated words
#      - exception: hyphenated bigrams w/ 2+ characters at word start & end
#   4. truncate string after '
#-----------------------------------------------------------
#  arg1   = string
#  arg2   = acronym and abbreviation hash
#  arg3   = prefix hash
#  r.v.   = word array 
#-----------------------------------------------------------
sub getword2 {
    my ($str,$achp,$pfhp)=@_;

    # exclude URLs and email addresses
    $str=~s|http://\S+||g;
    $str=~s|\S+@\S+||g;
    $str=~s|\S*_\S*||g;

    # process abbreviations
    $str=~ s/([A-Z])\.([A-Z])/$1$2/g while ($str=~/[A-Z]\.[A-Z]/);

    # remove punctuations (except ')
    $str=~s/[(){}\[\]<>:;\`",.?!]+/ /g;

    # save acronyms and abbreviations
    #  - 2 to 5 uppercase letters
    #  - a letter followed by a number
    my @names0= ($str=~ /\b[A-Z]{2,5}\b/g);
    my @names2= ($str=~ /\b[A-Z][0-9]\b/g); # save T1, K2, etc.
    # keep acronyms in acronym list only
    my @names1;
    foreach my $name(@names0) {
        if ($achp->{"$name"}) { push(@names1,$name); }
        else { push(@names1,"\L$name"); }
    }
    my @names= (@names1,@names2);

    # delete saved words from string
    foreach my $name(@names0,@names2) {
        $str=~s/\b$name\b/ /g;
    }

    # save special term: 9/11 !!
    $str=~ s!\b(9/11|sept. ?11)\b!9-11!gi;

    # delete trailing numbers
    #  - e.g. word05 to word
    my @words0= ($str=~ /\b[A-Za-z]+[0-9]+\b/g); 
    my @words;
    foreach my $word(@words0) {
        my $word2=$word;
        $word2=~s/\d+$//;
	push(@words,$word2);
    }

    # delete saved words from string
    foreach my $name(@words0) {
        $str=~s/\b$name\b/ /g;
    }

    # save hyphenated words: bigrams only
    #  - must start and end w/ two or more characters
    my @bigram0= ($str=~ /\b[a-z]{2,}-[a-z]{2,}\b/g);
    my @bigrams;
    foreach my $wd(@bigram0) {
	my($pfx)=split(/-/,$wd); 
	# keep only if valid prefix
	if ($$pfhp{"\L$pfx"}) {
	   push(@bigrams,$wd);
	}
    }

    # delete saved words from string
    foreach my $name(@bigrams) {
        $str=~s/\b$name\b/ /g;
    }

    # truncate string after '
    $str=~s/\b(\w+)'+\w+/ $1/g;

    # change - to blank (i.e. split word)
    $str=~s/\-+/ /g;

    # add saved words to the string
    $str .= " ".join(" ",@names,@words,@bigrams);

    # remove leading & trailing blanks from the string
    $str=~s/^ *(.+?) *$/$1/g;

    my @wds= split(/\s+/,$str);

    return (@wds);

} # endsub getword2


#-----------------------------------------------------------
# return an array of words from a string of words, 7/14/07
#   1. exclude URLs, email address, words w/ underscore
#      - save last 2 portions of URLs (e.g. indiana.edu)
#   2. preserve acronyms and abbreviations
#      - save allcap words inside parenthesis
#   3. hyphenated words: selected bigrams only
#      - must have 2+ characters at word start & end
#      - must start with valid prefix
#   4. quoted bigram
#      - save as underscored unigram unless contains stopword or ARV word
#      - to be processed by stemming module
#        - keep as is, do not stem
#   5. truncate string after '
#-----------------------------------------------------------
#  arg1   = string
#  arg2   = acronym and abbreviation hash
#  arg3   = prefix hash
#  arg4   = ARV (Adjective, adveRb, Verb) hash
#  r.v.   = word array 
#-----------------------------------------------------------
sub getword3 {
    my ($str,$achp,$pfhp,$stophp,$arvhp)=@_;
    my $debug=0;

    # exclude email addresses, & words w/ underscore 
    $str=~s|\S+@\S+||g;
    $str=~s|\S*_\S*||g;

    # URL: keep last 2 portion & exclude
    my @urls;
    while ($str=~m!\b(\w+\.(com|edu|gov|net|org|mil)\b)!g) {
        push(@urls,$1);
    }
    $str=~s|http://\S+||g;
    $str=~s/www\.\S+//g;
    $str=~s/\S+\.(com|edu|gov|net|org|mil)\b//g;

    # process abbreviations
    $str=~ s/([A-Z])\.([A-Z])/$1$2/g while ($str=~/[A-Z]\.[A-Z]/);

    # save quoted bigrams before punctuation removal
    my @qqph;
    while ($str=~/"([a-z]+)\s+([a-z]+)"/ig) {
        my($whole,$wd1,$wd2)=($&,$1,$2);
        print "getword3: Potential bigram=$whole, wd1=$wd1, wd2=$wd2\n" if ($debug);
        next if (&stopwd($wd1,$stophp) || &stopwd($wd2,$stophp));
        next if ($arvhp->{lc($wd1)} || $arvhp->{lc($wd2)});
        push(@qqph,$wd1."_$wd2");
        $str=~s/$whole//;
        print "getword3: Extracted bigram=$whole\n" if ($debug);

    }

    # save acronyms and abbreviations
    #  - 2 to 5 uppercase letters
    #  - a letter followed by a number
    my @names0= ($str=~ /\b[A-Z]{2,5}\b/g);
    my @names2= ($str=~ /\b[A-Z][0-9]\b/g); # save T1, K2, etc.
    # keep acronyms in acronym list only
    my @names1;
    foreach my $name(@names0) {
        if ($achp->{"$name"}) { push(@names1,$name); }
        elsif ($str=~/\($name\)/) { push(@names1,$name); }  # inside parenthesis
        else { push(@names1,"\L$name"); }
    }
    my @names= (@names1,@names2);

    # remove punctuations (except ')
    $str=~s/[(){}\[\]<>:;\`",.?!]+/ /g;

    # delete saved words from string
    foreach my $name(@names0,@names2) {
        $str=~s/\b$name\b/ /g;
    }

    # save special term: 9/11 !!
    $str=~ s!\b(9/11|sept. ?11)\b!9-11!gi;

    # delete trailing numbers
    #  - e.g. word05 to word
    my @words0= ($str=~ /\b[A-Za-z]+[0-9]+\b/g); 
    my @words;
    foreach my $word(@words0) {
        my $word2=$word;
        $word2=~s/\d+$//;
	push(@words,$word2);
    }

    # delete saved words from string
    foreach my $name(@words0) {
        $str=~s/\b$name\b/ /g;
    }

    # hyphenated words: selected bigrams only
    #  - must start and end w/ two or more characters
    #  - must start w/ valid prefix
    my @bigram0= ($str=~ /\b[a-z]{2,}-[a-z]{2,}\b/g);
    my @bigrams;
    foreach my $wd(@bigram0) {
	my($pfx)=split(/-/,$wd); 
	# keep only if valid prefix
	if ($$pfhp{"\L$pfx"}) {
	   push(@bigrams,$wd);
	}
    }

    # delete saved words from string
    foreach my $name(@bigrams) {
        $str=~s/\b$name\b/ /g;
    }

    # truncate string after '
    $str=~s/\b(\w+)'+\w+/ $1/g;

    # change - to blank (i.e. split word)
    $str=~s/\-+/ /g;

    # add saved words to the string
    $str .= " ".join(" ",@names,@words,@bigrams,@urls,@qqph);

    # remove leading & trailing blanks from the string
    $str=~s/^ *(.+?) *$/$1/g;

    my @wds= split(/\s+/,$str);

    return (@wds);

} # endsub getword2


#-----------------------------------------------------------
# flag stopwords
#    - modified to allow embedded period if flag is set (7/16/07)
#-----------------------------------------------------------
#  arg1   = word
#  arg2   = pointer to stopword hash
#  arg3   = flag to allow embedded period (optional)
#  r.v.   = 1+ if stopword, 0 otherwise
#-----------------------------------------------------------
#  Note: return value
#    1 = stopwords
#    2 = word with invalid characters (valid= alphanumeric and hyphen)
#    3 = word with more than 3 repeated letters
#        word with 3 consecutive groups of repeated characters
#    4 = word with more than 25 characters or
#        non-cap word of length 2 or less
#    5 = word w/ more than 4 digits
#        all alphanumeric word except
#          all single letter followed by up to 2 numbers (e.g. u2, imap4, k12)
#          letter-number-letter (e.g. b2b)
#          all numbers followed by th (e.g. 107th, *1st, *2nd, *3rd)
#          1000 <= number <= 2200 (for years)
#-----------------------------------------------------------
sub stopwd {
    my ($word,$xhash,$flag)=@_;    

    # keep acronyms: all capitalized words of length 2 to 5
    #   not in stoplist as allcaps
    if ($word=~/^[A-Z]{2,5}$/) {
	if (exists($$xhash{$word})) {
	    return (1); 
	}
	else { return (0); }
    }

    # stopwords
    if (exists($$xhash{"\L$word"})) {
	return (1); 
    }

    # word with invalid characters (valid= alphanumeric and hyphen)
    if (!$flag) {
        if ($word=~/[^a-zA-Z0-9-]/) {
            return (2);
        }
    }
    else {
        if ($word=~/[^a-zA-Z0-9-\.]/) {
            return (2);
        }
    }

    # word with more than 3 repeated letters
    # word with 3 consecutive groups of repeated characters
    if ($word=~/([a-zA-Z])\1{3,}/ || $word=~/(\w)\1{1,}(\w)\2{1,}(\w)\3{1,}/) {
        return (3);
    }

    # word with less than 3 (non-cap) or more than 25 characters
    my $wdlen= length($word);
    if ($wdlen>25 ||
        ($wdlen<3 && !($word=~/^[A-Z][0-9]$/ || $word=~/^[A-Z]+$/))) { 
        return (4);
    }

    # alphanumeric words
    if ($word=~ /\d/) {
	return (5) 
          if ( $word=~/\d{5,}/ ||
	       !( ($word=~/^[a-zA-Z]+\d\d$/) ||
	          ($word=~/^[a-zA-Z]\d[a-zA-Z]$/) ||
	          ($word=~/^\d*(1st|2nd|3rd|th)$/) ||
	          ($word=~/^\d{4}$/ && $word>=1000 && $word<=2200) ) );
    }

    return (0);

} # endsub stopwd


#-----------------------------------------------------------
# stem text
#-----------------------------------------------------------
#  arg1   = word to stem
#  arg2   = pointer to proper noun hash
#  arg3   = pointer to krovetz dictionary subset hash
#  arg4   = stemmer (0=simple, 1=combo, 2=Porter, 3=Krovetz)
#  arg5   = pointer to user do-not-stem word hash, 7/14/07
#             (e.g., generated from quoted bigrams)
#  arg6   = pointer to do-not-stem word hash for Simple stemmer, 3/6/08
#             (e.g., 'this')
#  r.v.   = stemmed word
#-----------------------------------------------------------
#  Note: 
#   1. word should be stopped & punctuations removed beforehand
#   2. user no-stem list is checked case-sensitive to be more discriminating
#      e.g., (Steve) Jobs vs. jobs & Jobs
#   3. words in no-stem list2 should be in lowcase (checked case-insensitive)
#-----------------------------------------------------------
sub stemword {
    my ($word,$pnhp,$sdhp,$stemmer,$nostemhp,$nostemhp2)=@_;

    return $word if ($stemmer<0);
    return lc($word) if ($nostemhp && exists($nostemhp->{$word}));

    my $combo="/u0/widit/prog/nstem/nstem0.out";

    #----------------------
    # apply stemmer
    #----------------------

    # save acronyms and abbreviations
    #  - 2 to 5 uppercase letters
    #  - a letter followed by a number
    if ( $word=~/^[A-Z]{2,5}$/ || $word=~/^[A-Z][0-9]$/) { 
        return $word;
    }  
    #   - do not stem proper nouns
    elsif ($word=~/^[A-Z]/ && $$pnhp{$word}) {
	$word=lc($word);  # convert to lowercase
        return $word;
    }  
    else {
	$word=lc($word);  # convert to lowercase
	if ($stemmer==1 && $word=~/(s|ing|ed)$/) {
	    $word= combostem($word,$sdhp);
	}
	elsif ($stemmer==3 && $word=~/(ing|ed)$/) {
	    $word= Krovetz($word,$sdhp);
	}
	elsif ($stemmer==2) {
	    $word= `$combo b $word`;
	    chomp $word;
	}
	elsif ($word=~/s$/) { 
	    $word= Simple($word,$nostemhp2); 
	}
    }

    return $word;

} # endsub-stemword


#-----------------------------------------------------------
# stop & stem text (used by mkphrase, getdef in NLPsub.pl)
#-----------------------------------------------------------
#  arg1   = word to stem
#  arg2   = pointer to stopword hash
#  arg3   = pointer to proper noun hash
#  arg4   = pointer to krovetz dictionary subset hash
#  arg5   = stemmer (0=simple, 1=combo, 2=Porter, 3=Krovetz)
#  arg6   = pointer to user do-not-stem word hash, 7/14/07
#             (e.g., generated from quoted bigrams)
#  arg7   = pointer to do-not-stem word hash for Simple stemmer, 3/6/08
#             (e.g., 'this')
#  r.v.   = stemmed word
#-----------------------------------------------------------
#  Note: 
#   1. word is stopped & punctuations removed in this subroutine
#   2. no-stop list is checked case-sensitive to be more discriminating
#      e.g., proper noun match: Steve Jobs vs. jobs & Jobs
#   3. words in no-stem list2 should be in lowcase (checked case-insensitive)
#-----------------------------------------------------------
sub stemword2 {
    my ($word,$stophp,$pnhp,$sdhp,$stemmer,$nostemhp,$nostemhp2)=@_;

    return $word if ($stemmer<0);
    return lc($word) if ($nostemhp && exists($nostemhp->{$word}));

    my $combo="/u0/widit/prog/nstem/nstem0.out";

    # remove punctuations at word boundary
    $word=~s/^[-']*(.+?)[-']*$/$1/;

    # exclude stopwords
    if (&stopwd($word,$stophp)) { return ""; }

    #----------------------
    # apply stemmer
    #----------------------

    # save acronyms and abbreviations
    #  - 2 to 5 uppercase letters
    #  - a letter followed by a number
    if ( $word=~/^[A-Z]{2,5}$/ || $word=~/^[A-Z][0-9]$/) { 
        return $word;
    }  
    #   - do not stem proper nouns
    elsif ($word=~/^[A-Z]/ && $$pnhp{$word}) {
	$word=lc($word);  # convert to lowercase
        return $word;
    }  
    else {
	$word=lc($word);  # convert to lowercase
	if ($stemmer==1 && $word=~/(s|ing|ed)$/) {
	    $word= combostem($word,$sdhp);
	}
	elsif ($stemmer==3 && $word=~/(ing|ed)$/) {
	    $word= Krovetz($word,$sdhp);
	}
	elsif ($stemmer==2) {
	    $word= `$combo b $word`;
	    chomp $word;
	}
	elsif ($word=~/s$/) { 
	    $word= Simple($word,$nostemhp2); 
	}
    }

    return $word;

} # endsub-stemword2


#-----------------------------------------------------------
# stop and stem text 
#-----------------------------------------------------------
#  arg1   = pointer to word array
#  arg2   = pointer to stopword hash
#  arg3   = pointer to proper noun hash
#  arg4   = pointer to krovetz dictionary subset hash
#  arg5   = stemmer (0=simple, 1=combo, 2=Porter, 3=Krovetz)
#  r.v.   = string of stopped & stemmed words delimited by blank
#-----------------------------------------------------------
#  Note:
#    - stopwords excluded (see stopwd subroutine)
#    - hyphenated words are outputted
#        as a whole and as split words
#-----------------------------------------------------------
sub procwords {
    my ($listp,$stophp,$pnhp,$sdhp,$stemmer)=@_;

    my @words;

    foreach my $word(@$listp) {

        # remove punctuations at word boundary
        $word=~s/^[-']*(.+?)[-']*$/$1/;

        # delete hyphen in hyphenated words
        $word=~s/-//g;

        # exclude stopwords
        next if (&stopwd($word,$stophp));
        #if (my $flg=&stopwd($word,$stophp)) { print "wd=$word, STF=$flg\n"; next; }

        $word=&stemword($word,$pnhp,$sdhp,$stemmer); # apply stemmer

        push(@words,$word);
        
        #if ($word=~/-/) {
        #    my @wds= split(/-/,$word);
        #    foreach my $wd(@wds) {
	#	$wd=&stemword($wd,$pnhp,$sdhp,$stemmer); # apply stemmer
        #        next if (&stopwd($wd,$stophp));
	#	push(@words,$wd);
        #    }
        #}

    }

    my $words= join(" ",@words);
    return $words;

} # endsub procwords



#-----------------------------------------------------------
# stop and stem text (for query processing), 7/14/07
#    1. hyphenated words
#       - output whole & hyphen-compressed
#       - stem
#    2. underscored words
#       - output as hyphenated, underscore-compressed, & as parts
#    3. URL parts (e.g. indiana.com)
#       - output as is & as parts
#       - do not stem
#-----------------------------------------------------------
#  arg1   = pointer to word array
#  arg2   = pointer to stopword hash
#  arg3   = pointer to proper noun hash
#  arg4   = pointer to krovetz dictionary subset hash
#  arg5   = stemmer (0=simple, 1=combo, 2=Porter, 3=Krovetz)
#  arg6   = pointer to user do-not-stem word hash
#  arg7   = pointer to no-Simple stem hash (should be in lowcase)
#  r.v.   = string of stopped & stemmed words delimited by blank
#-----------------------------------------------------------
#  Note: 
#    1. exclude long words (>25 char): mkinvinx.cc requirement
#         - stopwd sub applies longword exclusion
#    2. updated procwords to correspond to getword3 sub
#    3. special words (no-stem, bigrams) that are outputted
#         both as is & stemmed are grouped & separated by comma
#       e.g. r.v. = 'united states, united state'
#-----------------------------------------------------------
sub procword3 {
    my ($listp,$stophp,$pnhp,$sdhp,$stemmer,$nostemhp,$nostemhp2)=@_;

    # add underscored word parts to no-stem list (proper noun words) 
    foreach my $wd(@$listp) {      
        if ($wd=~/_/) {
            my($wd1,$wd2)=split(/_/,$wd);
            $nostemhp->{$wd1}=1;
            $nostemhp->{$wd2}=1;
        }
    }

    my (@words,@words2);

    foreach my $word2(@$listp) {

        my $word=$word2;

        # remove punctuations at word boundary
        $word=~s/^[-']*(.+?)[-']*$/$1/;

        # underscored words (quoted bigrams converted by getword3)
        if ($word=~/_/) {

            # output hyphenated
            $word=~s/_/-/g;       
            push(@words2,lc($word)) if (!&stopwd($word,$stophp));

            # output split parts unstemmed & stemmed
            my @wds= split(/-/,$word);
            foreach my $wd(@wds) {
                push(@words2,lc($wd)) if (!&stopwd($wd,$stophp));
                my $wd2=&stemword($wd,$pnhp,$sdhp,$stemmer,$nostemhp,$nostemhp2); 
                push(@words,$wd2);
            }

            # output compressed 
            $word=~s/-//g;       
            push(@words2,lc($word)) if (!&stopwd($word,$stophp));

        }

        # URL parts
        elsif ($word=~/\w\.\w/) {

            push(@words,lc($word)) if (!&stopwd($word,$stophp,1));  # allow period

            # output split parts
            my @wds= split(/\./,$word);
            foreach my $wd(@wds) {
                push(@words2,lc($wd)) if (!&stopwd($wd,$stophp));
            }

        }
            
        # hyphenated words: output as is & stemmed
        elsif ($word=~/-/) {
            push(@words,$word) if (!&stopwd($word,$stophp));
            $word=~s/-//g;       
            my $wd=&stemword($word,$pnhp,$sdhp,$stemmer,$nostemhp,$nostemhp2); 
            push(@words2,lc($wd));
        }

        # no-stem words: output as is & stemmed
        elsif ($nostemhp->{$word}) {
            # output as is
            push(@words,$word) if (!&stopwd($word,$stophp));
            my $wd=&stemword($word,$pnhp,$sdhp,$stemmer,"",$nostemhp2); 
            push(@words2,lc($wd));
        }

        else {
            # exclude stopwords
            next if (&stopwd($word,$stophp));
            #if (my $flg=&stopwd($word,$stophp)) { print "wd=$word, STF=$flg\n"; next; }

            # apply stemmer
            my $word=&stemword($word,$pnhp,$sdhp,$stemmer,"",$nostemhp2); 

            push(@words,$word);
        }

    } #end-foreach

    my $words1= join(" ",@words);

    my $words2;
    foreach my $wd(@words2) {
        # output only the new form
        next if ($words1=~/\b$wd\b/i);
        #next if ($words1=~/\b$wd\b/i && ($words1!~/$wd\-/ || $words1!~/\-$wd/));
        $words2 .= " $wd";
    }

    if ($words2) { return "$words1 , $words2"; }
    else { return "$words1"; }

} # endsub procword3



#-----------------------------------------------------------
# count word frequencies
#  arg1   = pointer to word array
#  arg2   = pointer to word freq. hash
#             key=word, val=freq
#  arg3   = pointer to stopword hash
#  arg4   = pointer to proper noun hash
#  arg5   = pointer to krovetz dictionary subset hash
#  arg6   = stemmer type
#-----------------------------------------------------------
#  Note:  simplified version (for spam)
#    - single character word excluded
#    - components of hyphenated word are counted as well
#    - components of @-embedded word are counted as well
#-----------------------------------------------------------
sub countwd0 {
    my ($listp,$wcnthp,$stophp,$pnhp,$sdhp,$stemmer)=@_;

    my %wdcnt;

    foreach my $word(@$listp) {      
        $wdcnt{$word}++;
	if ($word=~/[-@]/) {
	    my @wds= split(/[-@]+/,$word);
	    foreach my $wd(@wds) {
	        $wdcnt{$wd}++ if ($wd);
	    }
	}
    }

    foreach my $word(keys %wdcnt) {
	# exclude single character words
        next if (length($word)<2);
	# exclude stopwords
        next if (&stopwd($word,$stophp));
	my $freq= $wdcnt{$word};
        # apply stemmer
	#print STDOUT "st=$stemmer, wd=$word\n";
        $word=&stemword($word,$pnhp,$sdhp,$stemmer);
	#print STDOUT "$word\n";
        $$wcnthp{$word} += $freq;
    }

} # endsub countwd0



#-----------------------------------------------------------
# count word frequencies (for document indexing)
#  arg1   = pointer to word array
#  arg2   = pointer to word freq. hash
#             key=word, val=freq
#  arg3   = pointer to stopword hash
#  arg4   = pointer to proper noun hash
#  arg5   = pointer to krovetz dictionary subset hash
#  arg6   = stemmer type
#  r.v.   = word freq
#-----------------------------------------------------------
#  Note:  
#    - stopwords excluded (see stopwd subroutine)
#    - hyphenated words are converted to one word (hyphen removed)
#-----------------------------------------------------------
sub countwd {
    my ($listp,$wcnthp,$stophp,$pnhp,$sdhp,$stemmer)=@_;

    my %wdcnt;

    foreach my $word(@$listp) {      

	# remove punctuations at word boundary
        $word=~s/^[-']*(.+?)[-']*$/$1/;

	# delete hyphen in hyphenated words
        $word=~s/-//g;

        $wdcnt{$word}++;

    }

    my %wdcnt2;
    foreach my $word(keys %wdcnt) {
	# exclude stopwords
        next if (&stopwd($word,$stophp));
	my $freq= $wdcnt{$word};
        # apply stemmer
        $word=&stemword($word,$pnhp,$sdhp,$stemmer);
        # exclude 2-letter words unless uppercase or letter-number
        next if (length($word)<3 && !($word=~/^[A-Z][0-9]$/ || $word=~/^[A-Z]+$/));
        $$wcnthp{$word} += $freq;
        $wdcnt2{$word}++;
    }

    my @cnt=keys %wdcnt2;
    my $wdcnt= @cnt;

    return $wdcnt;

} # endsub countwd


#-----------------------------------------------------------
# count word frequencies
#  arg1   = pointer to word array
#  arg2   = pointer to word freq. hash
#             key=word, val=freq
#  arg3   = pointer to word freq. hash 2
#  arg4   = pointer to stopword hash
#  arg5   = pointer to proper noun hash
#  arg6   = pointer to krovetz dictionary subset hash
#  arg7   = stemmer type
#  r.v.   = word freq
#-----------------------------------------------------------
#  Note:
#    - stopwords excluded (see stopwd subroutine)
#    - hyphenated words are converted to one word (hyphen removed)
#-----------------------------------------------------------
sub countwd2 {
    my ($listp,$wcnthp,$wcnthp2,$stophp,$pnhp,$sdhp,$stemmer)=@_;

    my %wdcnt;

    foreach my $word(@$listp) {      

	# remove punctuations at word boundary
        $word=~s/^[-']*(.+?)[-']*$/$1/;

	# delete hyphen in hyphenated words
        $word=~s/-//g;

        $wdcnt{$word}++;

    }

    my %wdcnt2;
    foreach my $word(keys %wdcnt) {
        # exclude stopwords
        next if (&stopwd($word,$stophp));
        my $freq= $wdcnt{$word};
        # apply stemmer
        $word=&stemword($word,$pnhp,$sdhp,$stemmer);
        next if (length($word)<3 && !($word=~/^[A-Z][0-9]$/ || $word=~/^[A-Z]+$/));
        $$wcnthp{$word} += $freq;
        $$wcnthp2{$word} += $freq;
        $wdcnt2{$word}++;
    }

    my @cnt=keys %wdcnt2;
    my $wdcnt= @cnt;

    return $wdcnt;

} # endsub countwd2


#-----------------------------------------------------------
# 1. stop & stem text (for document indexing)
# 2. count word frequencies 
#-----------------------------------------------------------
#  arg1   = pointer to word array
#  arg2   = pointer to word freq. hash
#             key=word, val=freq
#  arg3   = pointer to stopword hash
#  arg4   = pointer to proper noun hash
#  arg5   = pointer to krovetz dictionary subset hash
#  arg6   = stemmer type
#  r.v.   = word freq
#-----------------------------------------------------------
#  Note: 7/14/07
#    1. exclude long words (>25 char): mkinvinx.cc requirement
#         - stopwd sub applies longword exclusion
#    2. hyphenated words
#       - output hyphen-compressed & stemmed
#    3. underscored words
#       - output as hyphenated & as parts
#    4. URL parts (e.g. indiana.com)
#       - output as is & as parts
#       - do not stem
#-----------------------------------------------------------
sub countwd3 {
    my ($listp,$wcnthp,$stophp,$pnhp,$sdhp,$stemmer)=@_;

    my (%wdcnt0,%wdcnt);

    # flag words not to be stemmed (proper noun words) 
    my %nostem;
    foreach my $word2(@$listp) {      
        if ($word2=~/_/) {
            my($wd1,$wd2)=split(/_/,$word2);
            $nostem{$wd1}=1;
            $nostem{$wd2}=1;
        }
    }
    
    foreach my $word2(@$listp) {      

        my $word=$word2;

	# remove punctuations at word boundary
        $word=~s/^[-']*(.+?)[-']*$/$1/;

        # underscored words (quoted bigrams converted by getword3)
        if ($word=~/_/) {

            # output hyphenated if proper noun (start w/ caps)
            $word=~s/_/-/g;
            if ($word=~/^[A-Z][a-z]+\-[A-Z][a-z]+$/) {
                $wdcnt0{lc($word)}++ if (!&stopwd($word,$stophp));
            }

            # output split parts
            my @wds= split(/-/,$word);
            foreach my $wd(@wds) {
                if (!&stopwd($wd,$stophp)) {
                    $wdcnt0{lc($wd)}++;
                    $wdcnt{$wd}++;
                }
            }

        }

        # URL part
        elsif ($word=~/\w\.\w/) {

            $wdcnt0{lc($word)}++ if (!&stopwd($word,$stophp,1));   # allow period
            # output split parts
            my @wds= split(/\./,$word);
            foreach my $wd(@wds) {
                $wdcnt0{lc($wd)}++ if (!&stopwd($wd,$stophp));
            }
        }

        else {

            # delete hyphen in hyphenated words
            $word=~s/-//g;

            # no-stem word: ouput as is & stemmed
            if ($nostem{$word}) {
                $wdcnt0{lc($word)}++;
            }

            $wdcnt{$word}++;
        }

    } #end-foreach $word(@$listp) 

    my %wdcnt2;
    foreach my $word(keys %wdcnt) {
	# exclude stopwords
        next if (&stopwd($word,$stophp));
	my $freq= $wdcnt{$word};
        # apply stemmer
        $word=&stemword($word,$pnhp,$sdhp,$stemmer);
        # exclude 2-letter words unless uppercase or letter-number
        next if (length($word)<3 && !($word=~/^[A-Z][0-9]$/ || $word=~/^[A-Z]+$/));
        $$wcnthp{$word} += $freq;
        $wdcnt2{$word}++;
    }

    # do not stem
    foreach my $word(keys %wdcnt0) {
	my $freq= $wdcnt0{$word};
        $$wcnthp{$word} += $freq;
        $wdcnt2{$word}++;
    }

    my @cnt=keys %wdcnt2;
    my $wdcnt= @cnt;

    return $wdcnt;

} # endsub countwd3


#-----------------------------------------------------------
# output hash info to a file
#  - key value 
#  - Note: sorted numerically by key
#-----------------------------------------------------------
#  arg1   = output file
#  arg2   = pointer to word freq. hash 
#  arg3   = filemode
#           key= unique word
#           val= word frequency (tf)
#-----------------------------------------------------------
sub hash2file {
    my ($outf,$hash,$filemode)= @_;

    return if (!%$hash);
    $filemode= 0640 if (!$filemode);

    # output hash info to a file
    open(OUT,">$outf") || die ("Cannot write to $outf\n");
    foreach my $key(sort bynumber keys %$hash) {
        print OUT "$key $$hash{$key}\n";
    }
    close(OUT);
    chmod($filemode,"$outf");      

} # endsub hash2file


#----------------------------------------------------
# create the fnref hashes
#  - %fnref:  key= file#, val= last doc#
#  - %fnref2: key= file#, val= file name
#----------------------------------------------------
# arg1= fnref file (full path)
#       file# filename first_doc# last_doc#
# arg2= pointer to fnref hash
#       key=file#, val=last doc#
# arg3= pointer to fnref2 hash
#       key=file name, val=filename
#----------------------------------------------------
sub mkfnref {
    my($inf,$fnrhp,$fnr2hp)=@_;

    open(IN,$inf) || die "can't read $inf";
    while (<IN>) {
        chomp;
        my ($fn,$fname,$fdn,$ldn)=split/ /;
        $$fnrhp{$fn}=$ldn;
        $$fnr2hp{$fn}=$fname;
    }
    close IN;

} #endsub mkfnref


#----------------------------------------------------
# create the fnref hashes
#  - %fnref:  key= file#, val= last doc#
#  - %fnref2: key= file#, val= file name
#----------------------------------------------------
# arg1= root index directory
# arg2= pointer to subcollection directory array
# arg3= pointer to fnref hash
#       key=file#, val=last doc#
# arg4= pointer to fnref2 hash
#       key=file name, val=filename
#----------------------------------------------------
sub mkfnrefall {
    my($idir,$subd,$fnrhp,$fnr2hp,$dnfhp)=@_;

    # %$dnfhp:  key= dn-subd,    val= number of unique terms
    # %$fnrhp:  key= subd name,  val= pointer to %fnref
    # %$fnr2hp: key= subd name,  val= pointer to %fnref2
    foreach my $subd(@$subd) {

	my $dnf="$idir/$subd/dnf";
	open(IN,$dnf) || die "can't open $dnf";
	while(<IN>) {
	    my($dn,$dtf)=split/ /;
	    $$dnfhp{"$dn-$subd"}=$dtf;
	}
	close IN;

	# %fnref:  key= file#,  val= lastdoc#
	# %fnref2: key= file#,  val= filename
	my (%fnref,%fnref2)=();
	&mkfnref("$idir/$subd/fnref",\%fnref,\%fnref2);
	$$fnrhp{$subd}=\%fnref;
	$$fnr2hp{$subd}=\%fnref2;

    }

} #endsub mkfnref


#----------------------------------------------------
# create the fnref hashes
#  - %fnref:  key= file#, val= last doc#
#----------------------------------------------------
# arg1= fnref file (full path)
#       file# filename first_doc# last_doc#
# arg2= pointer to fnref hash
#       key=file#, val=last doc#
#----------------------------------------------------
sub mkfnref2 {
    my($inf,$fnrhp)=@_;

    open(IN,$inf) || die "can't read $inf";
    while (<IN>) {
        chomp;
        my ($fn,$fdn,$ldn)=split/ /;
        $$fnrhp{$fn}=$ldn;
    }
    close IN;

} #endsub mkfnref2



#----------------------------------------------------
# find file number that contains a given document
#  - Note: pass in a hash created from FNREF file
#----------------------------------------------------
# arg1= document number
# arg2= pointer to fnref hash
#       key=file#, val=last doc#
# r.v.= file number
#----------------------------------------------------
sub findfn {
    my($dn,$fnrhp)=@_;

    my $debug=0;

    my @fns= sort {$a<=>$b} keys %$fnrhp;

    # return -1 for invalid doc#
    if ($dn<1 || $dn>$$fnrhp{$fns[-1]}) {
	print "!!ERROR: dn=$dn, maxdn=$$fnrhp{$fns[-1]}\n";
	return (-1);
    }

    # binary search
    my $i= sprintf("%d",@fns/2);
    my $maxi=@fns;
    my $mini=1;
    print "0: dn=$dn, min=$mini, max=$maxi, i=$i\n" if ($debug);
    while (1) {
        if ($dn > $$fnrhp{$i}) {
            $mini=$i;
            $i= sprintf("%d",($i+$maxi)/2);
            print "1: min=$mini, max=$maxi, i=$i, f=$$fnrhp{$i}\n" if ($debug);
	    if ($i==$mini) {
		$i++;
		last;
	    }
        }
        else {
            $maxi=$i;
            $i= sprintf("%d",($maxi-$mini)/2)+$mini;
            print "2: min=$mini, max=$maxi, i=$i, f=$$fnrhp{$i}\n" if ($debug);
            last if ($i==$maxi);
        }
    }

    return $i;

} #endsub findfn


#----------------------------------------------------
# extract the content lines of target documents
#   from a file that contain multiple documents
#----------------------------------------------------
# arg1= multi-doc file from which to extract lines (full path)
# arg2= document delimiter tag
#       e.g. <$arg2>DN</$arg2>
# arg3= pointer to document number array 
#       (all in the target muti-doc file)
# arg4= pointer to document lines array to be populated by this sub
#       (puts all target document lines into a single array)
#----------------------------------------------------
sub subdocs {
    my($inf,$tag,$dnlp,$doclp)=@_;

    # key= target documents
    my %dns;
    foreach my $dn(@$dnlp) {
        $dns{$dn}=1;
    }

    open(IN,$inf) || die "can't read $inf";

    my $include=0;
    while(<IN>) {
        if (m|<$tag>(.+?)</$tag>|) {
	    if ($dns{$1}) { $include=1; }
	    else { $include=0; }
	}
	push(@$doclp,$_) if ($include);
    }

    close IN;

} #endsub subdocs


#----------------------------------------------------
# extract the content lines of target documents
#   from a file that contain multiple documents
#----------------------------------------------------
# arg1= multi-doc file (full path)
# arg2= document delimiter tag
#       e.g. <$arg3>DN</$arg3>
# arg3= pointer to document number array 
#       (all in the target muti-doc file)
# arg4= pointer to document lines hash 
#       key=doc#, val=pointer to lines array
#----------------------------------------------------
sub subdocs2 {
    my($inf,$tag,$dnlp,$dochp)=@_;

    # key= target documents
    my %dns;
    foreach my $dn(@$dnlp) {
        $dns{$dn}=1;
    }

    open(IN,$inf) || die "can't read $inf";

    my $include=0;
    my $dn;
    while(<IN>) {
        if (m|<$tag>(.+?)</$tag>|) {
	    $dn=$1;
	    if ($dns{$dn}) { $include=1; }
	    else { $include=0; }
	}
	push(@{$$dochp{$dn}},$_) if ($include);
    }

    close IN;

} #endsub subdocs2


#----------------------------------------------------
# extract the content lines of target documents
#   from a file that contain multiple documents
#----------------------------------------------------
# arg1= multi-doc file (full path)
# arg2= subcollection name
# arg3= document delimiter tag
#       e.g. <$arg3>DN</$arg3>
# arg4= pointer to document number array 
#       (all in the target muti-doc file)
# arg5= pointer to document content hash or array
#       key=docID, val=pointer to content array or hash
# arg6= 1 if $arg5 hash value is pointer to term-freq hash
#         (key=word, val=term freq string from seqindx*)
#       0 if $arg4 hash value is pointer to document line array
#----------------------------------------------------
sub subdocs_all {
    my($inf,$subd,$tag,$dnlp,$dochp,$type)=@_;

    # key= target documents
    my %dns;
    foreach my $dn(@$dnlp) {
        $dns{$dn}=1;
    }

    open(IN,$inf) || die "can't read $inf";

    my $include=0;
    my $dn;
    while(my $line=<IN>) {
	chomp $line;
	next if ($line=~/^\s*$/);
        if ($line=~m|<$tag>(.+?)</$tag>|) {
	    $dn=$1;
	    if ($dns{$dn}) { $include=1; }
	    else { $include=0; }
	    next;
	}
	if ($include) {
	    if ($type==1) { 
	        my($wd,$rest)=split(/ /,$line,2);
		if (!exists($$dochp{"$dn-$subd"})) {
		    $$dochp{"$dn-$subd"}= {"$wd"=>"$rest"};
		}
	        else {
		    my $hp= $$dochp{"$dn-$subd"};
		    $$hp{"$wd"}="$rest";
		}
	    }
	    else {
	        next if ($line=~m|</DOC>|);
	        push(@{$$dochp{"$dn-$subd"}},$line);
	    }
	}
    }

    close IN;

} #endsub subdocs_all


#----------------------------------------------------
# get document content lines 
#   given a list of document numbers
# Note1: assumes WIDIT index structure 
#   (e.g. FNREF, SEQINDX/1..fn)
# Note2: stores all document lines into a single array
#----------------------------------------------------
# arg1= index directory
# arg2= document delimiter tag
#       e.g. <$arg3>DN</$arg3>
# arg3= pointer to fnref hash
#       key=file#, val=last doc#
# arg4= pointer to document number array 
#       (in multiple files)
# arg5= pointer to document lines array 
# arg6= pointer to fnref2 hash
#       key=file#, val=filename
# arg7= 1 if using filename, 0 if using file#
#----------------------------------------------------
sub getdocs {
    my($dir,$tag,$fnrhp,$dnlp,$doclp,$fnr2hp,$fnrtype)=@_;

    # %files
    #   key= file numbers
    #   val= pointer to document number array
    my %files;
    foreach my $dn(@$dnlp) {
        my $fn= &findfn($dn,$fnrhp);
        push(@{$files{$fn}},$dn);
    }

    # foreach file that contain 1 or more target documents
    foreach my $fn(sort {$a<=>$b} keys %files) {
        my $file;
        if ($fnrtype) { $file= "$dir/$$fnr2hp{$fn}"; }
        else { $file= "$dir/$fn"; }
        # get document lines
        &subdocs($file,'DN',$files{$fn},$doclp);
    }

} #endsub getdocs


#----------------------------------------------------
# get document content lines 
#   given a list of document numbers
# Note1: assumes WIDIT index structure 
#   (e.g. FNREF, SEQINDX/1..fn)
# Note2: stores each documents as hash element
#----------------------------------------------------
# arg1= index directory
# arg2= document delimiter tag
#       e.g. <$arg3>DN</$arg3>
# arg3= pointer to fnref hash
#       key=file#, val=last doc#
# arg4= pointer to document number array 
#       (in multiple files)
# arg5= pointer to document lines hash 
#       key=doc#, val=pointer to lines array
# arg6= pointer to fnref2 hash
#       key=file#, val=filename
# arg7= 1 if using filename, 0 if using file#
#----------------------------------------------------
sub getdocs2 {
    my($dir,$tag,$fnrhp,$dnlp,$dochp,$fnr2hp,$fnrtype)=@_;

    # %files
    #   key= file numbers
    #   val= pointer to document number array
    my %files;
    foreach my $dn(@$dnlp) {
        next if (exists($$dochp{$dn}));
        my $fn= &findfn($dn,$fnrhp);
        push(@{$files{$fn}},$dn);
    }

    # foreach file that contain 1 or more target documents
    foreach my $fn(sort {$a<=>$b} keys %files) {
        my $file;
        if ($fnrtype) { $file= "$dir/$$fnr2hp{$fn}"; }
        else { $file= "$dir/$fn"; }
        # get document lines
        &subdocs2($file,'DN',$files{$fn},$dochp);
    }

} #endsub getdocs2


#----------------------------------------------------
# get document content lines 
#   given a list of document numbers from all subcollections
# Note1: assumes WIDIT index structure 
#   (e.g. FNREF, SEQINDX/1..fn)
# Note2: stores each documents as hash element
#----------------------------------------------------
# arg1= index root directory
# arg2= file type (e.g. docs, seqindx)
#         (also subdirectory name)
# arg3= document delimiter tag
#         e.g. <$arg3>DN</$arg3>
# arg4= pointer to fnref hash
#        key=subcollection name
#        val= pointer to hash (key=file#, val=last doc#)
# arg5= pointer to array of target docIDs
#         docID=$dn-$subd, e.g. 2341-AFE
# arg6= pointer to document content hash
#         key=docID, val=pointer to document content array or hash
# arg7= 1 if $arg6 hash value is pointer to term-freq hash
#         (key=word, val=term freq string from seqindx*)
#       0 if $arg6 hash value is pointer to document line array
# arg8= pointer to fnref2 hash
#        key=subcollection name
#        val= pointer to hash (key=file#, val=filename)
# arg9= 1 if filenames in $arg2 are alphanumeric (TREC filenames), 
#       0 if numeric (WIDIT filenames)
#----------------------------------------------------
sub getdocs_all {
    my($dir,$dname,$tag,$fnrallhp,$dnlp,$dochp,$dhptype,$fnr2allhp,$fnrtype)=@_;

    # %files
    #   key= file numbers
    #   val= pointer to document number array
    #        (all target documents in a given file)
    my %files;
    foreach my $dname(@$dnlp) {
        my($dn,$subd)=split(/\-/,$dname);
        next if (exists($$dochp{$dname}));   # already extracted documents
	my $fnrhp= $$fnrallhp{$subd};
        my $fn= &findfn($dn,$fnrhp);
        push(@{$files{"$subd-$fn"}},$dn);
    }

    # foreach file that contain 1 or more target documents
    foreach my $fname(sort keys %files) {
        my($subd,$fn)=split(/\-/,$fname);
        my $file;
        if ($fnrtype) { 
	    my $fnr2hp= $$fnr2allhp{$subd};
	    $file= "$dir/$subd/$dname/$$fnr2hp{$fn}"; 
	}
        else { $file= "$dir/$subd/$dname/$fn"; }
        # get document lines
        &subdocs_all($file,$subd,'DN',$files{$fname},$dochp,$dhptype);
    }

} #endsub getdocs_all


#----------------------------------------------------
# get term statistics
#----------------------------------------------------
# arg1= term
# arg2= collection name (e.g. hard, spam)
# arg3= year
# arg4= type (optional: e.g. t=training, e=test, default=e)
# r.v.= df
#----------------------------------------------------
sub getdf {
    my($term,$track,$yr,$type)=@_;

    my %subd= (
      'hard2004'=> ['AFE','APE','CNE','LAT','NYT','SLN','UME','XIE'],
      'hard2005'=> ['APW','NYT1','NYT2','XIE'],
      'hard2005t'=> ['FBIS','FR94','FT','LATIMES'],
    );

    $type="" if ("$track$type" ne 'hardt');

    my $dir= "/u0/trec/$yr/$track$type";
    my $lp= $subd{"$track$yr$type"};

    $dir= "/u0/trec/2005/hardt" if ("$track$type" eq "hardt");

    foreach my $d(@$lp) {

        my $ind= "$dir/$d";          # subcollection directory
	my $tnt2= "$ind/tnt2";       # sorted term#-term mapping file
	my $tnfall= "$ind/tnf_all";  # term#-df file for whole collection

        my ($str,$tn,$tn2,$word,$dfall);

	# get term number
	$str= `grep -i ' $term ' $tnt2`;
        next if (!$str);
	chomp $str;
	($tn2,$word,$tn)=split(/ /,$str);

	# get whole collection df
	$str= `grep '^$tn ' $tnfall`;
	chomp $str;
	($tn,$dfall)=split(/ /,$str);
	return($dfall) if ($dfall);
    }

} #endsub getdf


#----------------------------------------------------
# get collection term frequency
#   - number of times term occurs in the whole collection
#----------------------------------------------------
# arg1= term
# arg2= collection name (e.g. hard, spam)
# arg3= year
# arg4= type (optional: e.g. t=training, e=test, default=e)
# r.v.= ctf
#----------------------------------------------------
sub getctf {
    my($term,$track,$yr,$type)=@_;

    my %subd= (
      'hard2004'=> ['AFE','APE','CNE','LAT','NYT','SLN','UME','XIE'],
      'hard2005'=> ['APW','NYT1','NYT2','XIE'],
      'hard2005t'=> ['FBIS','FR94','FT','LATIMES'],
    );

    $type="" if ("$track$type" ne 'hardt');

    my $dir= "/u0/trec/$yr/$track";
    my $lp= $subd{"$track$yr$type"};

    $dir= "/u0/trec/2005/hardt" if ("$track$type" eq "hardt");

    my $cnt=0;
    foreach my $d(@$lp) {

        my $ind= "$dir/$d";          # subcollection directory
	my $invt= "$ind/inv_t";      # inverted index
	my $tnt2= "$ind/tnt2";       # sorted term#-term mapping file

        my ($str,$tn,$tn2,$word,%tfs);

	# get term number
	$str= `grep -i ' $term ' $tnt2`;
        next if (!$str);
	chomp $str;
	($tn2,$word,$tn)=split(/ /,$str);

	# get whole collection df
	$str= `grep '^$tn ' $invt`;
	chomp $str;
	$str=~s/ -1$//;
	($tn,%tfs)=split(/ /,$str);
	foreach my $v(values %tfs) {
	    $cnt += $v;
	}

    }

    if ($cnt) {
	return $cnt;
    }
    else {
	return -1;
    }

} #endsub getctf


#----------------------------------------------------
# get collection term frequency
#   - number of times term occurs in the whole collection
#----------------------------------------------------
# arg1= pointer to term hash: k=term, v=ctf
# arg2= collection name (e.g. hard, spam)
# arg3= year
# arg4= type (optional: e.g. t=training, e=test, default=e)
# r.v.= df
#----------------------------------------------------
sub getctf_all {
    my($ctfhp,$track,$yr,$type)=@_;

    my %subd= (
      'hard2004'=> ['AFE','APE','CNE','LAT','NYT','SLN','UME','XIE'],
      'hard2005'=> ['APW','NYT1','NYT2','XIE'],
      'hard2005t'=> ['FBIS','FR94','FT','LATIMES'],
    );

    $type="" if ("$track$type" ne 'hardt');

    my $dir= "/u0/trec/$yr/$track";
    my $lp= $subd{"$track$yr$type"};

    $dir= "/u0/trec/2005/hardt" if ("$track$type" eq "hardt");

    # %ctf: k=term, v=ctf
    my %ctf;

    my $debug=1;
    foreach my $d(@$lp) {

        my $ind= "$dir/$d";          # subcollection directory
	my $invt= "$ind/inv_t";      # inverted index
	my $tnt= "$ind/tnt";         # term#-term mapping file

	# %tnt: k=tn, v=term
	open(IN,$tnt) || die "can't open $tnt";
	my %tnt;
	print "processing $tnt\n" if ($debug);
	while(<IN>) {
	    chomp;
	    my($tn,$term)=split/ +/;
	    next if (!exists($$ctfhp{$term}));
	    $tnt{$tn}=$term;
	}
	close IN;

	# get whole collection df
	foreach my $tn(keys %tnt) {
	    my $str= `grep '^$tn ' $invt`;
	    chomp $str;
	    $str=~s/ -1$//;
	    my ($tn,%tfs)=split(/ /,$str);
	    my $term=$tnt{$tn};
	    foreach my $v(values %tfs) {
		$$ctfhp{$term} += $v;
	    }
	}

	# get whole collection df
	#  - much slower than grep
	#open(IN,$invt) || die "can't open $invt";
	#print "processing $invt\n" if ($debug);
	#while(<IN>) {
	#    chomp;
	#    s/ -1$//;
	#    my ($tn,$rest)=split/ +/,$_,2;
	#    next if (!exists($tnt{$tn}));
	#    my(%tfs)=split/ +/,$rest;
	#    my $term=$tnt{$tn};
	#    foreach my $v(values %tfs) {
	#	$$ctfhp{$term} += $v;
	#    }
	#}
	#close IN;

    }

} #endsub getctf_all


#----------------------------------------------------
# get subcollection token frequency
#   - number of tokens in the subcollection
#----------------------------------------------------
# arg1= sub collection name (e.g. FT, FR94)
# arg2= collection name (e.g. hard, spam)
# arg2= year
# arg3= type (optional: e.g. t=training, e=test, default=e)
# r.v.= df
#----------------------------------------------------
sub getstf {
    my($subc,$track,$yr,$type)=@_;

    my $dir= "/u0/trec/$yr/$track";
    $dir= "/u0/trec/2005/hardt" if ($type && "$track$type" eq "hardt");

    my $ttf=0;

    my $ind= "$dir/$subc";          # subcollection directory
    my $fref= "$ind/fnref";      # fn-to-fname mapping

    # get file count
    my $str= `tail $fref`;
    return -1 if (!$str);
    chomp $str;
    my ($fn)=split(/ /,$str);

    # get whole token freq
    for(my $i=1;$i<=$fn;$i++) {
	my $in="$ind/seqindx/$i";
	open(IN,$in) || die "can't read $in";
	while(<IN>) {
	    if (!m|<DN>(.+)?</DN>|) {
		my($term,$tf)=split/ /;
		$ttf += $tf;
	    }
	}
    }

    if ($ttf) {
	return $ttf;
    }
    else {
	return -1;
    }

} #endsub getstf


#----------------------------------------------------
# get collection token frequency
#   - number of tokens in the whole collection
#----------------------------------------------------
# arg1= collection name (e.g. hard, spam)
# arg2= year
# arg3= type (optional: e.g. t=training, e=test, default=e)
# r.v.= df
#----------------------------------------------------
sub getttf {
    my($track,$yr,$type)=@_;

    my %subd= (
      'hard2004'=> ['AFE','APE','CNE','LAT','NYT','SLN','UME','XIE'],
      'hard2005'=> ['APW','NYT1','NYT2','XIE'],
      'hard2005t'=> ['FBIS','FR94','FT','LATIMES'],
    );

    $type="" if ("$track$type" ne 'hardt');

    my $dir= "/u0/trec/$yr/$track";
    my $lp= $subd{"$track$yr$type"};

    $dir= "/u0/trec/2005/hardt" if ("$track$type" eq "hardt");

    my $ttf=0;
    foreach my $d(@$lp) {

        my $ind= "$dir/$d";          # subcollection directory
	my $fref= "$ind/fnref";      # fn-to-fname mapping

	# get file count
	my $str= `tail $fref`;
        return -1 if (!$str);
	chomp $str;
	my ($fn)=split(/ /,$str);

	# get whole token freq
	for(my $i=1;$i<=$fn;$i++) {
	    my $in="$ind/seqindx/$i";
	    open(IN,$in) || die "can't read $in";
	    while(<IN>) {
		if (!m|<DN>(.+)?</DN>|) {
		    my($term,$tf)=split/ /;
                    $ttf += $tf;
		}
	    }
	}

    }

    if ($ttf) {
	return $ttf;
    }
    else {
	return -1;
    }

} #endsub getttf2


#----------------------------------------------------
# parse out HTML tags
#----------------------------------------------------
# arg1= HTML page
# arg2= pointer to text hash: k=field, v=text
# arg3= pointer to URL hash: k=URL, v=anchor text
# arg4= URL of the page (optional)
#----------------------------------------------------
sub parseHTML {
    my($inf,$htmhp,$urlhp,$pageurl)=@_;
    my $debug=0;

    # spam thresholds
    my $maxwdn=10;   # max.# of words kept in title field
    my $maxwdn2=30;  # max.# of words kept in meta field
    my $spamwdn=100; # max.# of words to be non-spam field
    my $maxwdlen=20; # max.# of characters in a word

    open(IN,$inf) || die "can't read $inf";
    my @lines=<IN>;
    close IN;
    chomp @lines;

    my $bigline= join(" ",@lines);

    # delete leading and trailing blanks inside the HTML tags.
    $bigline=~ s/<\s*(.+?)\s*>/<$1>/g;

    # convert underscores to a blank
    $bigline=~ s/_+/ /g;

    # compress multiple white spaces into a blank
    $bigline=~ s/\s+/ /g;

    # delete blanks around equal sign
    $bigline=~ s/ *= */=/g;

    # flag page type for empty body text identification
    my $pagetype;
    if ($bigline=~/http-equiv="?refresh"?/i) {
        $pagetype="redirect";
    }
    elsif ($bigline=~/<frameset/i) {
        $pagetype="frame";
    }
    elsif ($pageurl && $pageurl=~/gif|jpg/i) {
        $pagetype="image";
    }
    elsif ($bigline=~/<map/i) {
        $pagetype="imagemap";
    }
    else { $pagetype="other"; }

    my ($header,$body);
    # split into header and body text
    if ($bigline=~m|<body|i) {
        ($header,$body)= split(/<body.+?>/i,$bigline,2);
    }
    elsif ($bigline=~m|</head>|i) {
        ($header,$body)= split(/<\/head>/i,$bigline,2);
    }
    elsif ($bigline=~m|</title>|i) {
        ($header,$body)= split(/<\/title>/i,$bigline,2);
    }
    else {
        ($header,$body)= ($bigline,$bigline);
    }

    #-----------------------------
    # process header information
    #-----------------------------

    # get title
    #  - truncate to $maxwdn
    #  - skip if longer than $spamwdn
    if ($header=~ m|<title>(.+?)</title>|i) {
        my $text= $1;
        my @wds= ($text=~ /\b[a-zA-Z0-9'-]+\b/g);
	my $str=&procwds($maxwdn,$maxwdlen,\@wds) if (@wds<$spamwdn);
        $$htmhp{'ti'}=$str;
    }

    # get meta keyword
    #  - truncate to $maxwdn2
    #  - skip if longer than $spamwdn
    if ($header=~ m|<meta name=['"]?keywords['"]? content=['"]?([^'">]+)['"]?|i) {
        my $text= $1;
        my @wds= ($text=~ /\b[a-zA-Z0-9'-]+\b/g);
	my $str=&procwds($maxwdn2,$maxwdlen,\@wds) if (@wds<$spamwdn);
        $$htmhp{'kw'}=$str;
    }

    # get meta description
    #  - truncate to $maxwdn2
    #  - skip if longer than $spamwdn
    if ($header=~ m|<meta name=['"]?description['"]? content=['"]?([^'">]+)['"]?|i) {
        my $text= $1;
        my @wds= ($text=~ /\b[a-zA-Z0-9'-]+\b/g);
	my $str=&procwds($maxwdn2,$maxwdlen,\@wds) if (@wds<$spamwdn);
        $$htmhp{'ds'}=$str;
    }

    # get base URL & root URL
    my ($baseurl,$rooturl);
    if ($header=~ m|<base href=['"]?([^ '">]+)['"]?|i) {
        $baseurl=$1;
    }
    else {
        if ($pageurl && $pageurl=~ m|^(http://.+/)|) { $baseurl=$1; }
        elsif ($pageurl) { $baseurl=$pageurl."/"; }
        else { $baseurl="/"; }
    }
    $baseurl=~m|^(http://[^/]+)/|;
    $rooturl= $1;

    $$htmhp{'base'}=$baseurl if ($baseurl);
    $$htmhp{'root'}=$rooturl if ($rooturl);

    # delete spam
    #  - invisable text
    #  !! commented out because of bgcolor
    # $body=~ s|<font[^>]+color=['"]?#ffffff.+?/font>||gi;

    # handle special characters.
    $body=~ s/&hyph;?/-/g;
    $body=~ s/&quot;?/"/g;
    $body=~ s/&nbsp;?|&gt;?|&lt;?/ /g;
    $body=~ s/&amp;?/and/g;

    # handle 2 or 3 letter abbreviations
    #  - e.g. U.S. to US, U.S.A to USA
    $body=~ s/ ([A-Z])\.([A-Z])\.([A-Z])\.([ ,"'!?:;])/ $1$2$3$4/g;
    $body=~ s/ ([A-Z])\.([A-Z])\.([ ,"'!?:;])/ $1$2$3/g;
        
    # get href URL & anchor texts from image maps
    my @hits2= ($body=~ m|<area [^>]*href.+?>|gi);
    foreach (@hits2) {
        m| href=['"]? ?([^ '">]+)['"]?.*?alt=['"]?([^'">]+)['"]?.*?>|i;
        my $url= $1;
        my $anchor= $2;
        next if (($url eq "") || ($anchor eq ""));
        next if ($url=~/^#/); # eliminate in-page links
        # convert to canonical URL
        $url= &canURL($url,$rooturl,$baseurl) if ($rooturl && $baseurl);
        # keep words only
        my @wds= ($anchor=~ /\b[a-zA-Z0-9'-]+\b/g);
        $anchor= join(" ",@wds);
        if ($anchor) { 
            $$urlhp{$url}=$anchor;
	}   
    }   
    
    # extract acronym titles from acronym tags
    $body=~ s|<acronym.+?title=['"]?([^'">]+)['"]?.*?>| $1 |gi;
    
    # get href URL & anchor texts from A-HREF tags
    #  - problematic when </a> tag is not present
    #    e.g. <li><a href>, <td><a href>, etc.
    my $body2= $body;
    $body2=~ s|<area [^>]*href.+?>||gi;
    #!! minor error possible, but better to mine HREFs in javascripts
    #!!$body2=~ s|<script.+?/script>||gi;
    my @hits= ($body2=~ m|href=.+?</?a[> ]|gi);
    foreach (@hits) {
        m|href=['"]? ?([^ '">]+)['"]?.*?>(.+?)</?a[> ]|i;
        my $url= $1;
        my $anchor= $2;
        next if (($url eq "") || $url=~/^mailto/i);
        next if ($url=~/^#/); # eliminate in-page links
        # convert to canonical URL
        $url= &canURL($url,$rooturl,$baseurl) if ($rooturl && $baseurl);
        # delete image tags
        $anchor=~ s|<img.+?alt=['"]?([^'">]+)['"]?.*?>| $1 |i;
        # delete other tags (e.g. font)
        $anchor=~ s|<.+?>||g;
        # keep words only
        my @wds= ($anchor=~ /\b[a-zA-Z0-9'-]+\b/g);
        # compensate for potental anchor parsing error
        #  - if anchor is more than 20 words, take first 5 only.
        if (@wds>20) { @wds= @wds[0..4]; }
        $anchor= join(" ",@wds);
        if ($anchor) { 
            $$urlhp{$url}=$anchor;
	}   
        if ($debug && (!$url || !$anchor)) {
            print "!!parseHTML: missing URL or ANCHOR\n",
                  "  href=$_, url=$url, anchor=$anchor!!\n";
        }
    }

    # get first headings text
    if ($body=~ m|<h(\d).*?>(.+?)</h\1>|i) {
        my $text= $2;
        # delete other tags (e.g. font)
        $text=~ s|<.+?>||g;
        my @wds= ($text=~ /\b[a-zA-Z0-9'-]+\b/g);
	my $str=&procwds($maxwdn2,$maxwdlen,\@wds);
        $$htmhp{'h1'}=$str;
    }

    #-----------------------------
    # process body text
    #-----------------------------

    #!! extract alt text from image tags
    #!!  - caused errors when moved before HREF parsing
    $body=~ s|<img.+?alt=['"]?([^'">]+)['"]?.*?>| $1 |gi;

    # extract emphasized text
    my @emwds;
    push(@emwds,($body=~m|<b>(.+?)</b>|gi));
    push(@emwds,($body=~m|<em>(.+?)</em>|gi));
    push(@emwds,($body=~m|<font size=\+>(.+?)</font>|gi));
    push(@emwds,($body=~m|<u>(.+?)</u>|gi));
    push(@emwds,($body=~m|<h\d>(.+?)</h\d>|gi));

    my $bodyem= join(" ",@emwds);
    $$htmhp{'em'}= $bodyem;

    # delete HTML tags
    $body=~ s/<.+?>/ /gs;
    $$htmhp{'body'}= $body;

}  # endsub-parseHTML


#-----------------------------------------------------------
# 1. return a limited number of word of limited length
#-----------------------------------------------------------
#  arg1   = max. number of words to output
#  arg2   = max. word length
#  arg3   = pointer to word array
#  r.v.   = text string
#-----------------------------------------------------------
sub procwds {
    my ($maxn,$maxlen,$lp)= @_;
    my @list2=();
    if (@$lp>0) {
        push(@list2,$lp->[0]);
        my $i;
        for($i=1;$i<@$lp;$i++) {
            last if ($i>$maxn);
            if (length($lp->[$i])<=$maxlen) {
                push(@list2,$lp->[$i]);
            }
        }
    }
    return join " ",@list2;
} # ensub-printwds


#-----------------------------------------------------------
# 1. delete HTML tags
# 2. return a limited number of word of limited length
#-----------------------------------------------------------
#  arg1   = max. number of words to output
#  arg2   = max. word length
#  arg3   = text string
#  r.v.   = text string
#-----------------------------------------------------------
sub procbody {
    my ($maxn,$maxlen,$str)=@_;

    # delete HTML tags
    $str=~ s/<.+?>/ /g;

    # this is severe word exclusion for common web query types
    #  - modify for more general purpose index
    my @words= ($str=~ /\b[a-zA-Z0-9'-]+\b/g);

    if (@words<1) {
        return ;
    }
    else {
        my $str= procwds($maxn,$maxlen,\@words);
        return $str;
    }

} # endsub-procbody


#-----------------------------------------------------------
# canonize URL
#-----------------------------------------------------------
#  arg1   = input URL string
#  r.v.   = canonized URL
#-----------------------------------------------------------
sub canURL {
    my ($inurl,$root,$base)= @_;

    # convert to absolute URL
    if ($inurl=~m|^/|) { $inurl= $root.$inurl; }
    elsif ($inurl!~/^(http|www)/i) { $inurl= $base.$inurl; }

    $inurl=~ s|^http://||;
    $inurl=~ s/:80//;
    # remove trailing #laksdfjlkasd
    $inurl=~ s|/#[^/]+$|/|;
    # remove trailing index and default.html
    $inurl=~ s!/(index|default)\.s?html?$!/!;
    # lowercase hostname
    if ($inurl=~ m|^.*[A-Z][^/]*|) {
        my ($host,$path)=split(/\//,$inurl,2);
        $host=~tr/A-Z/a-z/;
        $inurl= "$host/$path";
    }
    while ($inurl=~s|//|/|g) { };
    while ($inurl=~s|/\./|/|g) { };
    # /directory/../ to /
    while ($inurl=~s|/[^/]+/\.\./|/|g) { };
    # domain/../ to domain/
    $inurl=~s|^([^/]+/)\.\./|$1|;
    if ($inurl !~ /\//) { $inurl .= "/"; }

    return $inurl;

}




1
