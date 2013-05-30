#!/usr/bin/perl
###########################################################
#    Program to generate query expansion via Wikipedia
#    Ashwini Athavale, Nigel Vaz
#    Last Updated: April 21, 2008
###########################################################
# Description: 
# Query expansion by wikipedia titles
# Query expansion by Synonyms and Associated terms obtained from 
# Wikipedia Thesaurus
#----------------------------------------------------------
# Input : Query file provided as an argument with command line execution
#         of the file
# Output: List containing expanded terms for the input query 
#         Currently printed to screen
#         Later on would be written to a file
#-----------------------------------------------------------
# Subroutines used:
# count_words : count number of words and perform sliding window functionality
# group_words: create the groups of words and fill the array slidewinarray  
# clean_array:  clean the sliding window array and retain the phrases 
# checkanddelete:  checks if we have the subterms included further 
#                   in the list and sets a corresponding flag 
# fetch_wikipage: feTch the wikipage for every phrase in the clean array
# fetch_thesaurus_terms: fetch the titles, associated terms and synonyms from Wikipedia   
#                        thesaurus for every phrase in the clean array  
#
###########################################################


use lib "/u2/home/aeathava/share/perl/5.8.8";
$path = "/u2/home/aeathava/share/perl/5.8.8";
unshift( @INC, "$path" );

use LWP::Simple;
use WWW::Mechanize;
use WWW::Wikipedia;
use LWP::UserAgent;
use Text::Capitalize;

# Get the input filename and divide the input string into words
$argn = 1;

# check the command line arguments

if ( ( @ARGV < $argn ) or ( @ARGV > $argn ) ) {
    print
"\nError! Please provide one filename that contains the query as an argument!\n";
    exit;
}

$filename = $ARGV[0];

if ( -e $filename ) {

    #read the query if file exists
    open( INF, $filename ) || die "can not read the file $filename";
    $query = <INF>;
    chomp $query;

#------------------------------------
# Global Variables 
#------------------------------------
    @slidewinarray       = ();
    @slidewinarrayflag   = ();
    $sizeofslidewinarray = 0;

    #final array to store the query word groups
    @finalarray     = ();
    @disambiguation = ();
    %expandedlist   = ();
    %assortedexpansion = ();

    &count_words($query);
}

else {
    print "\n Sorry ! the file specified does not exist !\n";
}

#########################################################################
# Subroutines
#########################################################################

#--------------------------------------------------------------------------
#subroutine to count number of words and perform sliding window functionality
#--------------------------------------------------------------------------

sub count_words {
    my $fullquery = $_[0];
    print "\nQuery is: $fullquery\n";

    #split the query to get the individual words
    local @qwords = split( / +/, $fullquery );

    #get the total num of words in the query
    local $num = @qwords;
    print "\nThe num of words are $num\n";


    #group the words - sliding window functionality
    for ( my $i = $num ; $i >= 1 ; $i-- ) {
        &group_words( $i, @qwords );
        $sizeofslidewinarray = $sizeofslidewinarray + $i;
    }
    my $length = @slidewinarray;
    print "The length of sliding window array is $length\n";
    print "\nIndividual elements of sliding window are: \n";
    foreach $word (@slidewinarray)
    {
    print "\n$word\n";
    }
    &clean_array;

    # called for every word in the array
    $finallength = @finalarray - 1;
    for ( my $count = 0 ; $count <= $finallength ; $count++ ) {
        my $headreturned = &fetch_wikipage( $finalarray[$count] );

        #send the array term as well as the value of disambiguation flag
        &fetch_thesaurus_terms( $finalarray[$count], \$disambiguation[$count],
            $headreturned );
    }
    print "\n-----Disambiguation array - with final QE values -----\n";
    print join( $delim, @disambiguation );
#   print the final output
    print "\n\n-----The final expanded list is -----\n";
    my $delim = "!!!";
#    print join( $delim, %expandedlist );
    foreach $expandedterm (keys %expandedlist)
    {
       $expandedterm =~ s/_/ /g;
       print "$expandedterm\n";
    }
    print "\n";
#    print "\n-----Disambiguation array - with final QE values -----\n";
#    print join( $delim, @disambiguation );
    print "\n----- Assorted expansion hash- with final QE terms -----\n";

for $phrase ( keys %assortedexpansion ) {
    print "$phrase: ";
    for $phrase_expansion ( keys %{ $assortedexpansion{$phrase} } ) {
#         print "$phrase_expansion=$assortedexpansion{$phrase}{$phrase_expansion} ";
          print "$phrase_expansion ,";
    }
    print "\n";
}
print "\n\n";
}

#---------------------------------------------------------------------------------------------
# Routine to create the groups of words and fill the array slidewinarray with the words created
#---------------------------------------------------------------------------------------------
sub group_words {

    #get the size of the sliding window from previous routine
    my $winsize = $_[0];

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
        for ( $j = $winlowerbound ; $j <= $winupperbound ; $j++ ) {
            if ( $flag == 0 ) {
                $smallquery = $qwords[$j];
                $flag       = 1;
            }
            else {
                $smallquery = $smallquery . " " . $qwords[$j];
            }
        }

        # save the small query to sliding window array
        push( @slidewinarray,     $smallquery );
        push( @slidewinarrayflag, 1 );
        $winlowerbound = $winlowerbound + 1;
        $winupperbound = $winupperbound + 1;
    }
}


#--------------------------------------------------------------------------
#Subroutine to clean the sliding window array and retain the phrases 
#--------------------------------------------------------------------------
sub clean_array {
    my $count=0;
    my $result=();
    foreach $arrayentry (@slidewinarray) {
        $result = ();
        #if the wikipedia entry found - save the term further
        my $wiki = WWW::Wikipedia->new();
        $arrayentrynospace = $arrayentry;

       	#$arrayentrynospace =~ s/\s+/_/g;
        $arrayentrylowercase = lc($arrayentrynospace);
        $arrayentryuppercase = capitalize($arrayentrynospace);

        if ( $slidewinarrayflag[$count] ) {
            my $resultuppercase = $wiki->search($arrayentryuppercase);
            if ($resultuppercase) {
               # print" result found - changing to uppercase\n";
                $arrayentrynospace = $arrayentryuppercase;
                $result = $resultuppercase;
            }else {
               my $resultlowercase = $wiki->search($arrayentrylowercase);
               if ($resultlowercase) {
               #    print "result fouund - changing to lowercase\n";
                   $arrayentrynospace = $arrayentrylowercase;
                   $result = $resultlowercase;
               }
            }
         
            if ($result) {
                #this is the routine to delete remaning entries in array if the phrase retrieves wikipedia result
                &checkanddelete( $arrayentrynospace, $count );
               
                 if ( $result->categories() ) {
                    #not a disambiguation entry
                    push( @finalarray,     $arrayentrynospace );
                    push( @disambiguation, 0 );
                    $assortedexpansion{$arrayentrynospace}{$arrayentrynospace}=1;
                }
                else {
                    push( @finalarray,     $arrayentrynospace );
                    push( @disambiguation, 1 );
                    $assortedexpansion{$arrayentrynospace}{$arrayentrynospace} = 1;

                }
            }
            $count++;
        }
        else {
            $count++;
        }
    }

    	print "\n-----clean array output-----\n";
    	$delim = "!!";
    	print join($delim,@finalarray);
        print "\ndisambiguation array\n";
        print join($delim, @disambiguation);            
        print "\n\n";

    my $finalarraylength = @finalarray;
    if ( $finalarraylength == 0 ) {
        print "\nwikipedia can not be used for expansion!\n";
        exit;
    }
}

##-----------------------------------------------------------------------------------------------------
#Routine which checks if we have the subterms included further in the list and sets a corresponding flag
##-----------------------------------------------------------------------------------------------------
sub checkanddelete {
    for ( my $i = $_[1] + 1 ; $i < $sizeofslidewinarray ; $i++ ) {
#        if ( index( lc( $_[0] ), lc( $slidewinarray[$i] ) ) >= 0 ) {
         my $origword = lc($_[0]); my $findword = lc($slidewinarray[$i]);
         if ($origword =~/$findword/i){;
            $slidewinarrayflag[$i] = 0;

            #make the corresponding flag 0 now
        }
    }
}

#------------------------------------------------------------------------
# Routine to feTch the wikipage for every phrase in the clean array
#------------------------------------------------------------------------
sub fetch_wikipage {
    local $wikiquery = $_[0];
    my $wikiquery_with_sp = $wikiquery;
    $wikiquery_lower = lc($wikiquery);
    $expandedlist{$wikiquery_lower} = 1;
    $wikiquery =~ s/\s+/_/g;
    $url = "http://en.wikipedia.org/wiki/" . $wikiquery;
    my $ua = LWP::UserAgent->new(
        env_proxy  => 1,
        keep_alive => 1,
        timeout    => 30,
    );

    $response = $ua->get($url);
    $htmlcode = $response->content;
    if ( $htmlcode =~ /<h1 class=\"firstHeading\">((\w*\s*)+)<\/h1>/ ) {
        $heading                      = $1;
        $heading_lower                = lc($heading);
        $expandedlist{$heading_lower} = 0;
        $assortedexpansion{$wikiquery_with_sp}{$heading_lower} = 1;
    }

    # return the heading found to pass to the thesaurus fetch further
    return $heading_lower;
}

#------------------------------------------------------------------------
# Routine to fetch the titles, associated terms and synonyms from Wikipedia
# thesaurus for every phrase in the clean array
#------------------------------------------------------------------------
sub fetch_thesaurus_terms {
    my $wikiquery   = $_[0];
    my $wikiquery_with_sp = $wikiquery;
    my $disamb_flag = $_[1];
    my $heading     = $_[2];
    $wikiquery_lower = lc($wikiquery);
    $expandedlist{$wikiquery_lower} = 1;
    $wikiquery =~ s/\s+/_/g;
    $wikiurl = 'http://en.wikipedia.org/wiki/' . $wikiquery;
    my $url =
        'http://wikipedia-lab.org:8080/WikipediaThesaurusV2/Search.aspx?k='
      . $wikiquery
      . '&t=2&l=English';
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
    my @matches  = ();
    @matches = $htmlcode =~
/<a id=\"dSearchResults_ctl.._hTitle\" href=\"http:\/\/en\.wikipedia\.org\/wiki\/.+?\" target=\"_blank\">(.+?)<\/a>/g;
    if ( !@matches ) {
        $response = $ua->get($headingurl);
        $htmlcode = $response->content;
        $wikiurl  = 'http://en.wikipedia.org/wiki/' . $heading;
        $url      = $headingurl;
        @matches  = $htmlcode =~
/<a id=\"dSearchResults_ctl.._hTitle\" href=\"http:\/\/en\.wikipedia\.org\/wiki\/.+?\" target=\"_blank\">(.+?)<\/a>/g;
    }

# Entry finds a single wikipedia page without disambiguation - pick the synonyms/associated terms for the entry
print "disf=$$disamb_flag\n";
    if ( $$disamb_flag == 0 ) {
        my $matcheslength = @matches;
        if ( $matcheslength > 1 ) {

            #Type 2 - regular thesaurus call for query term
            $$disamb_flag = 0.8;

print "disf2=$$disamb_flag\n";
# multiple entries found for the term in thesaurus - pick the one consistent with
# the wikipedia title entry picked in earlier routine
            if ( $htmlcode =~
/<a id=\"dSearchResults_ctl(..)_hTitle\" href=\"$wikiurl\" target=\"_blank\">(.+?)<\/a>/i
              )
            {

                #pick the synonyms from the thesaurus entry
                my @synomatches = $htmlcode =~
/<span id=\"dSearchResults_ctl$1_dSynonyms_ctl.._lSynonym\">(.+?)<\/span>/g;
                my $lensynomatches = @synomatches;
                if ( $lensynomatches < 3 ) {
                    for ( my $m = 0 ; $m <= ( $lensynomatches - 1 ) ; $m++ ) {
                        $expandedlist{ $synomatches[$m] } = 0;
                        $synomatches[$m] =~ s/_/ /g;
                        $assortedexpansion{$wikiquery_with_sp}{$synomatches[$m]} = 1;
                    }
                }
                else {
                    for ( my $k = 0 ; $k <= 2 ; $k++ ) {

                        #push the synonyms in the expanded list array
                        $expandedlist{ $synomatches[$k] } = 0;
                        $synomatches[$k] =~ s/_/ /g;
                        $assortedexpansion{$wikiquery_with_sp}{$synomatches[$k]} = 1;
                    }
                }
                print "synlen=$lensynomatches\n";
            }
        }
        else {

    #only one entry found in wikipedia - just pick the synonyms/associated terms
            my @synomatches = $htmlcode =~
/<span id=\"dSearchResults_ctl.._dSynonyms_ctl.._lSynonym\">(.+?)<\/span>/g;
            my $lensynomatches = @synomatches;
            if ( $lensynomatches < 3 ) {
                for ( my $m = 0 ; $m <= ( $lensynomatches - 1 ) ; $m++ ) {
                    $expandedlist{ $synomatches[$m] } = 0;
                    $synomatches[$m] =~ s/_/ /g;
                    $assortedexpansion{$wikiquery_with_sp}{$synomatches[$m]} = 1;
                }
            }
            else {
                for ( my $k = 0 ; $k <= 2 ; $k++ ) {

                    #push the synonyms in the expanded list array
                    $expandedlist{ $synomatches[$k] } = 0;
                    $synomatches[$k] =~ s/_/ /g;
                    $assortedexpansion{$wikiquery_with_sp}{$synomatches[$k]} = 1;
                }
            }

                print "synlen2=$lensynomatches\n";
            # find associated terms and push in the expanded list
            my @assomatches = $htmlcode =~
/<a id=\"dSearchResults_ctl.._dAssociations_ctl.._hRelatedTerm\" href=\".+?\">(.+?)<\/a>/g;
            my $lenassomatches = @assomatches;
            if ( $lenassomatches < 3 ) {
                for ( my $j = 0 ; $j <= ( $lenassomatches - 1 ) ; $j++ ) {
                    $expandedlist{ $assomatches[$j] } = 0;
                    $assomatches[$j] =~ s/_/ /g;
                    $assortedexpansion{$wikiquery_with_sp}{$assomatches[$j]} = 1;
                }
            }
            else {
                for ( my $t = 0 ; $t <= 2 ; $t++ ) {

                    #push the synonyms in the expanded list array
                    $expandedlist{ $assomatches[$t] } = 0;
                    $assomatches[$t] =~ s/_/ /g;
                    $assortedexpansion{$wikiquery_with_sp}{$assomatches[$t]} = 1;
                }
            }
                print "synlen3=$lenassomatches\n";

            #Type 2 - regular thesaurus call for query term
            $$disamb_flag = 1.0;
        }

        #my $delim = "!";
        #print "\n the thesaurus matches array is:\n";
        #print join($delim, @matches);
    }    #end if disamb flag is 0

    #check whether disambiguation is 1 and process further
    else {

        foreach $titlematched (@matches) {
            $expandedlist{$titlematched} = 0;
            $titlematched =~ s/_/ /g;
            $assortedexpansion{$wikiquery_with_sp}{$titlematched} = 1;
        }

        #Type 3
        $$disamb_flag = 0.6;
    }    #end else disambiguation 1
}
