###########################################################
#  subroutines to generate query expansion via Wikipedia
#     - Ashwini Athavale, Nigel Vaz
#     - Last Updated: April 21, 2008
#     - modified by Kiduk yang, 4/22/08
#-----------------------------------------------------------
# wikiQE :  expand query with wikipedia
#   wikiPhrase :       extract valid phrase/terms from text using wikipedia
#     slidechopString: use slidewindow to chop up text into pieces
#     group_words:     create the groups of words and fill the array slidewinarray  
#                      (called by slideChopString)
#     wikiValidPh:     clean the sliding window array and retain the phrases 
#     checkanddelete:  set subterms flags to zero 
#                    (called by wikiValidPh)
#   fetch_wikipage:    feTch the wikipage for every phrase in the clean array
#   fetch_thesaurus_terms: 
#                    fetch the titles, associated terms and synonyms from Wikipedia   
#                    thesaurus for every phrase in the clean array  
#
###########################################################

use lib "/u0/widit/PM/share/perl/5.8.8";

use strict;

use LWP::Simple;
use WWW::Mechanize;
use WWW::Wikipedia;
use LWP::UserAgent;
use Text::Capitalize;


#--------------------------------------------------------------------------
# expand query with wikipedia
#--------------------------------------------------------------------------
# arg1= query string
# arg2= pointer to expanded term hash (k=term, v=weight)
#--------------------------------------------------------------------------
sub wikiQE {
    my ($query,$xthp)=@_;

    my $debug=0;

    $query=~s/"//g;
    $query=~s/ (or|and|the|a|an) / /ig;

    $xthp->{$query}=2;

    # %ngrams holds n-grams validated via wikipedia
    #   k=n-gram, v=disambiguaiton status
    my %ngrams;  

    my $phcnt= &wikiPhrase($query,\%ngrams);
    print "query = $query ($phcnt n-grams)\n" if ($debug);

    foreach my $ph(keys %ngrams) {

        my $disamb= $ngrams{$ph};
        print "PH: $ph (disamb=$disamb)\n" if ($debug);

        my$heading= &fetch_wikipage($ph);
        warn "!!No Heading returned\n" if (!$heading);

        &fetch_thesaurus_terms($ph,$heading,$xthp,$disamb);

        $ph=~tr/A-Z/a-z/;
        $heading=~tr/A-Z/a-z/;
        if ($disamb==0) { 
            $xthp->{$ph}=2; 
            $xthp->{$heading}=2 if ($heading);
        }
        else { 
            $xthp->{$ph}=1; 
            $xthp->{$heading}=1 if ($heading);
        }

    }

} #endsub wikiQE


#--------------------------------------------------------------------------
# extract phrases from text
#  1. use slidewindow to chop up text into pieces
#  2. query wikipedia to validate phrases
#  3. retain longest valid phrases
#--------------------------------------------------------------------------
# arg1= query string
# arg2= pointer to phrase hash (k=phrase, v=disambiguation status)
# r.v.= number of phrases extracted
#--------------------------------------------------------------------------
sub wikiPhrase {
    my ($text,$php)=@_;

    my $debug=0;
    my (@slidewindow,@slidewindowflag);

    &slidechopString($text,\@slidewindow,\@slidewindowflag);
    my $phcnt= &wikiValidPh(\@slidewindow,\@slidewindowflag,$php);

    return $phcnt;

} #endsub wikiPhrase


#--------------------------------------------------------------------------
# use slidewindow to chop up text into pieces
#--------------------------------------------------------------------------
# arg1= query string
# arg2= pointer to slide window arrary
# arg3= pointer to slidewin array flag array
#--------------------------------------------------------------------------
# Note: calls &group_words
#--------------------------------------------------------------------------
sub slidechopString {
    my ($fullquery,$swlp,$flaglp)=@_;

    my $debug=0;

    print "\nQuery is: $fullquery\n" if ($debug);

    #split the query to get the individual words
    my @qwords = split( / +/, $fullquery );

    #get the total num of words in the query
    my $num = @qwords;
    print "\nThe num of words are $num\n" if ($debug);

    #group the words - sliding window functionality
    my $sizeofslidewinarray=0;
    for ( my $i = $num ; $i >= 1 ; $i-- ) {
        &group_words( $i, $num, \@qwords, $swlp, $flaglp);
        $sizeofslidewinarray = $sizeofslidewinarray + $i;
    }

    if ($debug) {
        #my $length = @$swlp;
        print "The length of sliding window array is ", @$swlp."\n";
        print "\nIndividual elements of sliding window are: \n";
        foreach my $word (@$swlp) { print "\n$word\n"; }
    }

} #endsub slidechopString


#---------------------------------------------------------------------------------------------
# create the groups of words and fill the array slidewinarray with the words created
#---------------------------------------------------------------------------------------------
# arg1= window size
# arg2= number of words in the query string
# arg3= pointer to qword arrary
# arg4= pointer to slide window arrary
# arg5= pointer to slidewin array flag array
#---------------------------------------------------------------------------------------------
sub group_words {
    my ($winsize,$num,$qwlp,$swlp,$flaglp)=@_;

    #initialize for first pass/grouping
    # due to array index - sliding window will be 0-1-2 1-2-3 etc
    # set the lower bound accordingly
    my $winlowerbound = 0;
    my $winupperbound = ( $winsize - 1 );
    my $flag          = 0;

    # first num in iteration would be 0 and last would be exitcount as follows: arraysize-windowsize
    my $exitcount = $num - $winsize;

    while ( $winlowerbound <= $exitcount ) {

        #initialize $smallquery
        my $smallquery = ();
        $flag = 0;
        for ( my $j = $winlowerbound ; $j <= $winupperbound ; $j++ ) {
            if ( $flag == 0 ) {
                $smallquery = $qwlp->[$j];
                $flag       = 1;
            }
            else {
                $smallquery = $smallquery . " " . $qwlp->[$j];
            }
        }

        # save the small query to sliding window array
        push( @$swlp,     $smallquery );
        push( @$flaglp, 1 );
        $winlowerbound = $winlowerbound + 1;
        $winupperbound = $winupperbound + 1;
    }

} #endsub group_words


#--------------------------------------------------------------------------
# clean the sliding window array and retain the phrases 
#   1. queries wikipedia to validate phrases
#   2. only the longest phrases are retained
#--------------------------------------------------------------------------
# arg1= pointer to slide window arrary
# arg2= pointer to slidewin array flag array
# arg3= pointer to final phrase hash (k=phrase, v=disambiguation status)
#--------------------------------------------------------------------------
# Note; calls &checkanddelete
#--------------------------------------------------------------------------
sub wikiValidPh {
    my ($swlp,$flaglp,$finalhp)=@_;

    my $debug=0;

    my ($count,$result,@disambiguation,@finalarray,%assortedexpansion)=(0);

    foreach my $arrayentry (@$swlp) {

        $result = ();

        #if the wikipedia entry found - save the term further
        my $wiki = WWW::Wikipedia->new();
        my $arrayentrynospace = $arrayentry;

       	#$arrayentrynospace =~ s/\s+/_/g;
        my $arrayentrylowercase = lc($arrayentrynospace);
        my $arrayentryuppercase = capitalize($arrayentrynospace);

        if ( $flaglp->[$count] ) {
            my $resultuppercase = $wiki->search($arrayentryuppercase);
            if ($resultuppercase) {
                print" result found - changing to uppercase\n" if ($debug);
                $arrayentrynospace = $arrayentryuppercase;
                $result = $resultuppercase;
            }else {
               my $resultlowercase = $wiki->search($arrayentrylowercase);
               if ($resultlowercase) {
                   print "result fouund - changing to lowercase\n" if ($debug);
                   $arrayentrynospace = $arrayentrylowercase;
                   $result = $resultlowercase;
               }
            }
         
            if ($result) {

                # delete remaning entries in array if the phrase retrieves wikipedia result
                &checkanddelete($swlp, $flaglp, lc($arrayentrynospace), $count);
                print "r=$arrayentrynospace\n" if ($debug);
               
                if ( $result->categories() ) {
                    #not a disambiguation entry
                    push( @finalarray,     $arrayentrynospace );
                    push( @disambiguation, 0 );
                    $assortedexpansion{$arrayentrynospace}{$arrayentrynospace}=1;
                    $finalhp->{$arrayentrynospace}=0;
                }
                else {
                    push( @finalarray,     $arrayentrynospace );
                    push( @disambiguation, 1 );
                    $finalhp->{$arrayentrynospace}=1;
                    $assortedexpansion{$arrayentrynospace}{$arrayentrynospace} = 1;

                }
            }
            $count++;
        }

        else { $count++; }

    }  #end-foreach


    if ($debug) {
    	print "\n-----clean array output-----\n";
    	my $delim = "!!";
    	print join($delim,@finalarray);
        print "\ndisambiguation array\n";
        print join($delim, @disambiguation);            
        print "\n\n";
    }

    my $finalarraylength = keys %{$finalhp};
    print "\nwikipedia can not be used for expansion!\n" if ($debug && $finalarraylength<1);

    return $finalarraylength;

} #endsub wikiValidPh


#-----------------------------------------------------------------------------------------------------
# check the subterms included further in the list and set a corresponding flag
#-----------------------------------------------------------------------------------------------------
# arg1= pointer to slide window arrary
# arg2= pointer to slidewin array flag array
# arg3= current word
# arg4= array index of current word
#-----------------------------------------------------------------------------------------------------
sub checkanddelete {
    my ($swlp,$flaglp,$origword,$pos)=@_;

    my $debug=0;

    for ( my $i = $pos + 1 ; $i < @$swlp ; $i++ ) {
         my $findword = lc($swlp->[$i]);
         if ($origword =~/$findword/i){;
            $flaglp->[$i] = 0; # set the corresponding flag 0 now
        }
    }

} #endsub chekanddelete


#------------------------------------------------------------------------
# query wikipedia to extract the heading of returned entry page
#------------------------------------------------------------------------
# arg1= query string
# r.v.= wikipedia heading for the query string,
#------------------------------------------------------------------------
sub fetch_wikipage {
    my ($wikiquery)= @_;

    $wikiquery =~ s/\s+/_/g;

    my $url = "http://en.wikipedia.org/wiki/" . $wikiquery;

    my $ua = LWP::UserAgent->new(
        env_proxy  => 1,
        keep_alive => 1,
        timeout    => 30,
    );

    my $response = $ua->get($url);
    my $htmlcode = $response->content;
    my $heading=$1 if ( $htmlcode =~ /<h1 class=\"firstHeading\">((\w*\s*)+)<\/h1>/ );

    # return the heading found to pass to the thesaurus fetch further
    return $heading;

} #endsub fetch_wikipage


#------------------------------------------------------------------------
# 1. query wikipedia to fetch the title and related terms
# 2. query wikipedia thesaurus to fetch associated terms and synonyms
#------------------------------------------------------------------------
# arg1= query string
# arg2= heading of returned page
# arg3= ptr to related term hash
# arg5= disambiguation flag
# r.v.= disambiguation weight
#------------------------------------------------------------------------
sub fetch_thesaurus_terms {
    my ($wikiquery,$heading,$xthp,$disamb_flag)= @_;

    my $debug=0;

    $wikiquery =~ s/\s+/_/g;

    my $wikiurl = 'http://en.wikipedia.org/wiki/' . $wikiquery;

    # thesaurus query with query string
    my $url =
        'http://wikipedia-lab.org:8080/WikipediaThesaurusV2/Search.aspx?k='
      . $wikiquery
      . '&t=2&l=English';

    # thesaurus query with wiki heading extracted previously
    my $headingurl =
        'http://wikipedia-lab.org:8080/WikipediaThesaurusV2/Search.aspx?k='
      . $heading
      . '&t=2&l=English';

    my $ua = LWP::UserAgent->new(
        env_proxy  => 1,
        keep_alive => 1,
        timeout    => 30,
    );

    my $response = $ua->get($url);
    my $htmlcode = $response->content;

    # extract thesaurus entries
    my @matches = $htmlcode =~
    /<a id=\"dSearchResults_ctl.._hTitle\" href=\"http:\/\/en\.wikipedia\.org\/wiki\/.+?\" target=\"_blank\">(.+?)<\/a>/g;

    # if no result w/ query string, requery with heading
    if ( !@matches ) {
        $response = $ua->get($headingurl);
        $htmlcode = $response->content;
        $wikiurl  = 'http://en.wikipedia.org/wiki/' . $heading;
        $url      = $headingurl;

        @matches  = $htmlcode =~
        /<a id=\"dSearchResults_ctl.._hTitle\" href=\"http:\/\/en\.wikipedia\.org\/wiki\/.+?\" target=\"_blank\">(.+?)<\/a>/g;
    }

    # Entry finds a single wikipedia page without disambiguation 
    # - pick the synonyms/associated terms for the entry

    if ( $disamb_flag == 0 ) {
        my $matcheslength = @matches;

        if ( $matcheslength == 1 ) {

            #Type 1 - regular thesaurus call for query term
            $disamb_flag = 1.0;

            #only one entry found in wikipedia - just pick the synonyms/associated terms
            my @synomatches = $htmlcode =~ /<span id=\"dSearchResults_ctl.._dSynonyms_ctl.._lSynonym\">(.+?)<\/span>/g;
            my $lensynomatches = @synomatches;
            if ( $lensynomatches < 3 ) {
                for ( my $m = 0 ; $m <= ( $lensynomatches - 1 ) ; $m++ ) {
                    $xthp->{ $synomatches[$m] } = sprintf("%.4f",$disamb_flag/2);
                }
            }
            else {
                for ( my $k = 0 ; $k <= 2 ; $k++ ) {

                    #push the synonyms in the expanded list array
                    $xthp->{ $synomatches[$k] } = sprintf("%.4f",$disamb_flag/2);
                }
            }
            print "slen2=$lensynomatches\n" if ($debug);

            # find associated terms and push in the expanded list
            my @assomatches = $htmlcode =~ /<a id=\"dSearchResults_ctl.._dAssociations_ctl.._hRelatedTerm\" href=\".+?\">(.+?)<\/a>/g;
            my $lenassomatches = @assomatches;
            if ( $lenassomatches < 3 ) {
                for ( my $j = 0 ; $j <= ( $lenassomatches - 1 ) ; $j++ ) {
                    $xthp->{ $assomatches[$j] } = sprintf("%.4f",$disamb_flag/3);
                }
            }
            else {
                for ( my $t = 0 ; $t <= 2 ; $t++ ) {

                    #push the synonyms in the expanded list array
                    $xthp->{ $assomatches[$t] } = sprintf("%.4f",$disamb_flag/3);
                }
            }
            print "alen3=$lenassomatches\n" if ($debug);

        }

        else {

            # Type 2 - regular thesaurus call for query term
            $disamb_flag = 0.8;

            # multiple entries found for the term in thesaurus - pick the one consistent with
            # the wikipedia title entry picked in earlier routine
            if ( $htmlcode =~ /<a id=\"dSearchResults_ctl(..)_hTitle\" href=\"$wikiurl\" target=\"_blank\">(.+?)<\/a>/i) {

                #pick the synonyms from the thesaurus entry
                my @synomatches = $htmlcode =~ /<span id=\"dSearchResults_ctl$1_dSynonyms_ctl.._lSynonym\">(.+?)<\/span>/g;
                foreach my $syn(@synomatches) { $syn=~s/<.+?>//g; }  #!! need better parsing above

                my $lensynomatches = @synomatches;
                if ( $lensynomatches < 3 ) {
                    for ( my $m = 0 ; $m <= ( $lensynomatches - 1 ) ; $m++ ) {
                        $xthp->{ $synomatches[$m] } = sprintf("%.4f",$disamb_flag/2);
                    }
                }
                else {
                    for ( my $k = 0 ; $k <= 2 ; $k++ ) {

                        #push the synonyms in the expanded list array
                        $xthp->{ $synomatches[$k] } = sprintf("%.4f",$disamb_flag/2);
                    }
                }
                print "slen=$lensynomatches\n" if ($debug);
            }
        }

        #my $delim = "!";
        #print "\n the thesaurus matches array is:\n";
        #print join($delim, @matches);

    }    #end if disamb flag is 0

    #check whether disambiguation is 1 and process further
    else {

        #Type 3
        $disamb_flag = 0.6;

        foreach my $titlematched (@matches) {
            $xthp->{$titlematched} = sprintf("%.4f",$disamb_flag/3);
        }


    }    #end else disambiguation 1

    return $disamb_flag;

} #endsub fetch_thesaurus_terms 



1
