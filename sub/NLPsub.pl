###########################################################
# NLP subroutines
#   -- Kiduk Yang, Ning Yu, 7/2004
#        modified by Ning Yu, 6/2005
#        modiefied by Ning Yu, 6/2007
#----------------------------------------------------------
# mkphrase:        identify noun phrase (dictionary lookup)
# mkphrase2:       identify noun phrase (Brill's or Monty tagger)
# mkphrase3:       identify noun phrase (Monty Extractor)
# xwds:            like diff (eliminate words), 7/2006
# getphrase:       extract quoted or hyphenated phrase from text, 7/2006
#                    updated 7/14/2007
# unmkabbr1:       expand acronym/abbreviations (web search)
# unmkabbr2:       expand acronym/abbreviations (no web search)
# unmkabbr3:       expand acronym/abbreviations (added text search), 7/14/2007
# getinflx:        expand words with inflexions
# xdot:            remove period from non-sentence boundary
# off_topic:       identify off-topic narrative sentences
# getsyn:          get synonyms from WordNet
# getdef:          get word definitions
# getdefall:       get word definitions strings (multiple sources)
# getdefall_terms: get word definitions terms(multiple sources)
# extract_def:     parse out the word definition from the search result text
# brilltag:        tag text with Brill tagger
# montytag:        tag text with Monty tagger
# montyExtractor   extract nouns and noun phrases using Monty module
# exAdj:           get the raw adj of the comparative or superlative
# cleantag:        clean tags
###########################################################

use strict;
use LWP::Simple;
require "/u0/widit/prog/trec08/indxsub.pl";

#-----------------------------------------------------------
# expand abbreviations
#  - Note1: input string should keep upper/lowercases intact
#  - Note2: uses web search when not found in acronym list
#-----------------------------------------------------------
# arg1 = string of words
# arg2 = pointer to acronym/abbreviation list
#        (key=acronym/abbreviation, val=expanded string)
# arg3 = pointer to found acronym/abbreviation list
#        (key=acronym/abbreviation, val=expanded string)
# r.v. = string of acronym:expanded separated by semicolon
#-----------------------------------------------------------
sub unmkabbr1 {

    my ($instr,$abbrhp,$abbrhp2)=@_;

    my %inwds;
    my @inwds=split(/ +/,$instr);
    foreach my $wd(@inwds) {
        $inwds{$wd}++;
    }

    my @outwds;
    foreach my $wd(keys %inwds) {
        if ($$abbrhp{$wd}) {
            push(@outwds,"$wd:$$abbrhp{$wd}");
            $$abbrhp2{$wd}=$$abbrhp{$wd};
        }
        else {
            next if ($wd=~/[a-z]/);
            my $wd2= &findabbr($wd);
            if ($wd2) {
                push(@outwds,"$wd:$wd2");
                $$abbrhp2{$wd}=$wd2;
            }
        }
    }

    return join("; ",@outwds);

} # endsub unmkabbr1



#-----------------------------------------------------------
# expand abbreviations & acronyms
#  - Note1: input string should keep upper/lowercases intact
#  - Note2: expand only terms in the acronym/abbr. list
#-----------------------------------------------------------
# arg1 = string of words
# arg2 = pointer to acronym/abbreviation list
#        (key=acronym/abbreviation, val=expanded string)
# arg3 = pointer to found acronym/abbreviation list
#        (key=acronym/abbreviation, val=expanded string)
# r.v. = string of acronym:expanded separated by semicolon
#-----------------------------------------------------------
sub unmkabbr2 {

    my ($instr,$abbrhp,$abbrhp2)=@_;

    my %inwds;
    my @inwds=split(/ +/,$instr);
    foreach my $wd(@inwds) {
	$inwds{$wd}++;
	$$abbrhp2{$wd}=$$abbrhp{$wd};
    }

    my @outwds;
    foreach my $wd(keys %inwds) {
        if ($$abbrhp{$wd}) { 
	    push(@outwds,"$wd:$$abbrhp{$wd}"); 
            $$abbrhp2{$wd}=$$abbrhp{$wd};
	}
    }

    return join("; ",@outwds);

} # endsub unmkabbr2



#-----------------------------------------------------------
# expand abbreviations & acronyms, 7/14/2007
#  - Note1: input string should keep upper/lowercases intact
#  - Note2: look in supplementary text if not found in acronym/abbr. list
#-----------------------------------------------------------
# arg1 = string of words
# arg2 = pointer to acronym/abbreviation list
#        (key=acronym/abbreviation, val=expanded string)
# arg3 = pointer to found acronym/abbreviation list
#        (key=acronym/abbreviation, val=expanded string)
# arg4 = supplementary text string
# r.v. = string of acronym:expanded separated by semicolon
#-----------------------------------------------------------
sub unmkabbr3 {

    my ($instr,$abbrhp,$abbrhp2,$text)=@_;
    my $debug=0;

    my %inwds;
    my @inwds=split(/ +/,$instr);
    foreach my $wd(@inwds) {
	$inwds{$wd}++;
	#$$abbrhp2{$wd}=$$abbrhp{$wd};
    }

    my @outwds;
    foreach my $wd(keys %inwds) {
        if ($$abbrhp2{$wd}) { 
	    push(@outwds,"$wd:$$abbrhp2{$wd}"); 
	}
        elsif ($$abbrhp{$wd}) { 
	    push(@outwds,"$wd:$$abbrhp{$wd}"); 
            $$abbrhp2{$wd}=$$abbrhp{$wd};
	}
        else {
            my $wlen=length($wd);
            print "text=$text\n" if ($debug);
            while ($text=~/([A-Z][a-z]+ ?){$wlen}/g) {
                my $match=$&;
                $match=~s/ +$//;
                my @caps= $match=~/[A-Z]/g;
                my $cap=join("",@caps);
                print "match=$match, cap=$cap, wd=$wd\n" if ($debug);
                if ($cap eq $wd) {
                    push(@outwds,"$wd:$match"); 
                    $$abbrhp2{$wd}=$match;
                    last;
                }
            }

	}
    }

    return join("; ",@outwds);

} # endsub unmkabbr2



#-----------------------------------------------------------
# expand words with inflexions
# (Note: input string should be stopped and stemmed)
#-----------------------------------------------------------
# arg1 = string of words
# arg2 = pointer to inflextion list
#        (key=word, val= word inflexion)
# r.v. = string of phrase bigrams
#-----------------------------------------------------------
sub getinflx {

    my ($instr,$inflxhp)=@_;

    my @inwds=split(/ +/,$instr);

    my @outwds;
    foreach my $wd(@inwds) {
        $wd=~tr/A-Z/a-z/;
        if ($$inflxhp{$wd}) { push(@outwds,$$inflxhp{$wd}); }
    }

    return join(" ",@outwds);

} # endsub getinflx


#-----------------------------------------------------------
# remove period from non-sentence boundary
#   - added name initial handling: kiyang 6/19
#-----------------------------------------------------------
# arg1 = string of text
# r.v. = modified string
#-----------------------------------------------------------
sub xdot {
    my ($str)= @_;

    # remove period to prevent false sentence recognition
    my @bad=qw(Ave Bldg Blvd Co Corp Dept Dr Gen Inc Ltd Prof Maj Mgr Mr Mrs Ms Mt Rd Rev Sgt am asst cc cf etc ibid tel vol vs);
    foreach my $bad(@bad) {
	$str=~s/\b$bad\./$bad/ig;
    }
    $str=~s/\bph\.d\.?/phd/ig;
    $str=~s/\ba\.m\./am/ig;
    $str=~s/\bp\.m\./pm/ig;
    $str=~s/\bU\.S\./US/ig;
    $str=~s/\be\.g\./eg/g;
    $str=~s/\bi\.e\./ie/g;

    # remove period from middle initial
    $str=~s/\b([A-Z][a-z]+) ([A-Z])\. ([A-Z][a-z]+)\b/$1 $2 $3/g;

    return $str;

} #endsub xdot;


#-----------------------------------------------------------
# identify off-topic narrative sentences
#  - based on ex_offtopic.pl by Ning Yu
#-----------------------------------------------------------
# arg1 = string of text
# r.v. = (on-topic sentences, off-topic sentences)
#-----------------------------------------------------------
sub off_topic {
    my ($str)= @_;

    # remove period to prevent false sentence recognition
    $str=&xdot($str);

    my $sep="#!#";
    $str=~s/([\.?!])/$1$sep/g;
    my @sentences= split(/$sep/,$str);
    
    my (@on,@off);
    my $off_start=0;
    foreach my $s(@sentences) {

	$s=~s/^ *(.+?) *$/$1/; # delete leading/trailing blanks

        # flag off-topic sentence
	if ($s=~/off[ \-]topic/i || $s=~/irrelevant/i) { 
	    push(@off,$s); 
	    $off_start=1;
	}

	else { 
	    # contiguouis off-topic sentence
	    if ($off_start && $s=~/^(As is|As are)/) {
		push(@off,$s); 
	    }
	    else {
		push(@on,$s); 
		$off_start=0;
	    }
	}
    }

    my $off= join("\n",@off);
    $off=~s/\n$//;
    my $on= join("\n",@on);
    $on=~s/\n$//;

    return ($on,$off);

} #endsub off_topic



# ------------------------------------------------------------------------
# get synonyms from WordNet
#   by Ning Yu, 06/29/2004 (qryWordNet.pl)
#   modified by Kiduk Yang, 07/09/2004
# ------------------------------------------------------------------------
# arg1 - query word
# arg2 - search type (f=familiarity, s=synonyms)
# arg3 - glossary flag (1=on, 0=off)
# r.v. - synonym string
# ------------------------------------------------------------------------
# NOTES: 
#   - calls get_postnumber & rqryWordNet subroutines
# ------------------------------------------------------------------------
sub getsyn {
    my ($keyword,$stype,$gloss)= @_;

    # search type
    my %type=("f"=>24, "s"=>2);

    # WordNet CGI
    my $wnURL= "http://www.cogsci.princeton.edu/cgi-bin/webwn2.0";

    #search in the first stage to find the 
    my $url_1 = "$wnURL?stage=1&word=$keyword";

    my $body_1= get($url_1);
    my @posts = get_postnumber($keyword,$body_1);

    my %posnumber = ();
    $posnumber{'noun'}=1;
    $posnumber{'verb'}=2;
    $posnumber{'adjective'}=3;
    $posnumber{'adverb'}=4;

    return "" if ($posts[0] eq 'bad');

    my @hits;
    foreach my $attr(@posts) {

	chomp $attr;
	my $url_2 = "$wnURL?stage=2&word=$keyword&posnumber=$posnumber{$attr}&searchtypenumber=$type{$stype}&senses=";
	$url_2 .= "&showglosses=1" if ($gloss);

	my $keyword_att = "$keyword($attr)";

	# print the fetched page content
	my $body_2= get($url_2);
	my @results= &rqryWordNet($stype,$keyword_att,$body_2);

	next if ($results[0] eq 'bad'); # failed terms

	foreach my $line(@results){
	    push(@hits,"$line");
	}

    } #end-foreach $attr(@posts)

    my $result= join("!#! ",@hits) if (@hits);

    return $result;

} #endsub getsyn


#--------------------------------------
# get posternumber from first stage search
#   by Ning Yu, 06/29/2004 (qryWordNet.pl)
#--------------------------------------
# arg1  = query term
# arg2  = string of body text (first search result)
# r.v.  = array of post numbers if successful search
#         ("bad",query term) otherwise
#--------------------------------------
sub get_postnumber{
    my($keyword, $text)=@_;

    my @post =();
    my @lines=split(/\n+/,$text);
    foreach(@lines){
       if($_ =~/<HR><BR>/ix){
            $_ =~ s|^.*<b>(.*)</b>.*$|$1|i;
            push(@post,$_);
        }
    }

    if(@post ==0){
        push(@post, 'bad');
        push(@post,$keyword);
    }
    return (@post);

} #endsub get_postnumber


#--------------------------------------
# conduct the second stage WordNet search 
#   by Ning Yu, 06/29/2004 (qryWordNet.pl)
#   modified by Kiduk Yang, 07/09/2004
#--------------------------------------
# arg1  = type of search
# arg2  = query term with its attribute
# arg3  = body text string
#        (familarity or synonym search result)
# r.v.  = search result
#--------------------------------------
sub rqryWordNet {
    my ($type,$term,$text) = @_;
   
    my ($syntype,$famtype)= ("s","f");

    my @text=split(/\n+/,$text);
    my %hits = ();
   
    # sysnonym search
    if($type eq $syntype){
   
       my $newsense=0;
       
       foreach (@text){
   
          next if /^\s*$/;  # skip blank lines
   
          my $dup=0;

          if(/^Sense\&nbsp\;[0-9]*<BR>$/i) {
              $newsense=1;
              next;
          }

          if ($newsense) {
             s|^(.*)<BR>$|$1|;
             s|(&nbsp;)+| |g;
             s|^ ||;
             s|, |,|g;
             $hits{$_}++;
             $newsense=0;
          }
       }

    } #end-if($type eq $syntype)


    # familiarity search
    elsif($type eq $famtype){

         foreach (@text){
             if (/polysemy/) {
                  s|^(.*)\(.*|$1|;
                  s|^.*is&nbsp;(.*)&nbsp;$|$1|;
                  s|(&nbsp;)+| |g;
                  $hits{$_}++;
             }
         }
    }
   
   my @hits= keys %hits;
   
   if(!@hits){
         push(@hits, "bad");
         push(@hits, $term);
   }
   
   return (@hits);

} #endsub rqryWordNet



#-------------------------------------------------------------------------
# return the word definitions from multiple web sources
#   by Kiduk Yang, 07/09/2004
#   modified by Ning Yu, 06/20/2005
#-------------------------------------------------------------------------
# arg1 - query word
# arg2  = pointer to stopword hash
# arg3  = pointer to proper noun hash
# arg4  = pointer to krovetz dictionary subset hash
# arg5  = stemmer (0=simple, 1=combo, 2=porter)
# r.v. - definition string
#-------------------------------------------------------------------------
# NOTES: 
#   - calls getdef subroutine
#-------------------------------------------------------------------------
sub getdefall {
    my ($query,$stophp,$pnhp,$sdhp,$stemmer)= @_;

    # source names
    my %sourceName = (
        #"an" => "Answers",
	"di" => "Dictionary", 
	"gg" => "Google",
        "iq" => "WordIQ",
    );

    my @results;
    foreach my $source(sort keys %sourceName) {
        push(@results,getdef($source,$query,$stophp,$pnhp,$sdhp,$stemmer));
    }

    my $result= join(" #!# ",@results);

    $result=~ s/,/, /g;
    $result=~ s/ +/ /g;
    $result=~ s/the meaning of//ig;

    return $result;

} #endsub getdef


# ------------------------------------------------------------------------
# return the word definitions from multiple web sources
#  and find the overlap terms between them.
#   by Kiduk Yang, 07/09/2004
#   modified by Ning Yu, 06/20/2005
#-------------------------------------------------------------------------
# arg1 - query word
# arg2  = pointer to stopword hash
# arg3  = pointer to proper noun hash
# arg4  = pointer to krovetz dictionary subset hash
# arg5  = stemmer (0=simple, 1=combo, 2=porter)
# r.v. - noun string, noun-phrase string from all source
#-------------------------------------------------------------------------
# NOTES: 
#   - calls getdef subroutine
#   - calls getoverlap subroutine(need to be implement later)
#-------------------------------------------------------------------------
sub getdef_term {
    my ($def,$stophp,$pnhp,$sdhp,$stemmer)= @_;
    
    my ($noun, $noun_p)=();
    ($noun, $noun_p)= &mkphrase2($def,$stophp,$pnhp,$sdhp,$stemmer);
    
    return ($noun, $noun_p);

} #endsub getdef_term


sub getdefall_term {
    my ($query,$stophp,$pnhp,$sdhp,$stemmer)= @_;
    
    # source names
    my %sourceName = (
        #"an" => "Answers",
	"di" => "Dictionary", 
	"gg" => "Google",
        "iq" => "WordIQ",
    );
    
    my ($noun, $nouns_p)=();
    my (@results,@nouns, @nouns_ps)=();
    foreach my $source(sort keys %sourceName) {
        push(@results,getdef($source,$query,$stophp,$pnhp,$sdhp,$stemmer));
    }
    
    foreach my $result(@results){
            $result=~ s/ +/ /g;
            $result=~ s/the meaning of//ig;
            ($noun, $nouns_p)= &mkphrase2($result,$stophp,$pnhp,$sdhp,$stemmer);
            push(@nouns, $noun);
            push(@nouns_ps, $nouns_p);
    }
    
    return (@nouns, @nouns_ps);

} #endsub getdefall_term


# ------------------------------------------------------------------------
# fetch the word definition from web
#   by Ning Yu, 07/07/2004 (qryDef.pl)
#   modified by Kiduk Yang, 07/09/2004
#   modified by Ning Yu, 06/20/2005
# ------------------------------------------------------------------------
# arg1 - search source
#        (iq= WordIQ, di= dictionary.com, gg= Google, an= answer.com)
# arg2 - query word
# arg3  = pointer to stopword hash
# arg4  = pointer to proper noun hash
# arg5  = pointer to krovetz dictionary subset hash
# arg6  = stemmer (0=simple, 1=combo, 2=porter)
# r.v. - definition string
# ------------------------------------------------------------------------
# NOTES: 
#   - calls extract_def subroutine
# ------------------------------------------------------------------------
sub getdef {
    my ($source,$query,$stophp,$pnhp,$sdhp,$stemmer)= @_;

    # search CGI
    my %sourceURL = (
	"iq" => "http://www.wordiq.com/define/",
	"di" => "http://dictionary.reference.com/search?q=",
	"gg" => "http://www.google.com/search?sourceid=navclient&ie=UTF-8&oe=UTF-8&q=",
        #"an" => "http://www.answers.com/",
    );


    # source names
    my %sourceName = (
        #"an" => "Answers",
	"di" => "Dictionary", 
	"gg" => "Google",
        "iq" => "WordIQ",
    );

    # return empty string if invalid source
    my $valid= join(" ",keys %sourceName);
    return "" if ($valid !~ /\b$source\b/);

    # stop & stem the word
    $query=&stemword2($query,$stophp,$pnhp,$sdhp,$stemmer);
    #$query= lc($query);

    if ($source eq 'iq') {
	$query=~s/ +/_/g;
    }
	
    # query the search source
    my ($url,$body);
    $url= $sourceURL{$source}.$query;
    if (($source eq "iq")||($source eq 'an')) { $body= get($url); }
    else { $body= &getpage0($url); }

    # parse out the definition from the search result
    my $result= &extract_def($source,$query,$body);

    return $result;

} #endsub getdef


#--------------------------------------------------------------
# Parse out the word definition from the search result text
#   by Ning Yu, 07/07/2004 (qryDef.pl)
#   modified by Kiduk Yang, 07/09/2004
#   modified by Ning Yu, 06/20/2005
#--------------------------------------------------------------
# arg1  = search source
# arg2  = query term 
# arg3  = body text string
# r.v.  = search result
#--------------------------------------------------------------
sub extract_def {
    my ($source,$term,$text) = @_;

    my ($tmp,$result,$fetchKey,@results,@matches,@matches_notes,@matches_pl,@matches_notes_pl);

    # wordIQ search
    if ($source eq "iq") {

       $text=~m|<div><a name="ttl1"></a>(.+?)</div>|s;
       $result=$1;

       return "" if (!$result);

       $result=~s/\n/ /g;

       #$result=~s|<.+?>||g;  # delete tags
       $result= cleanTag($result);
       $result=~s|\(.+?\)||g;  # delete POS & explanations
       $result=~s|\[.+?\]||g;  # delete synonyms
       $result=~s|".+?"||g;  # delete examples
       $result=~s|--.+?\d||g;  # delete examples
       $result=~s|\d+:||g;  # delete numbers
       $result=~s| [:;]||g;  
       $result=~s| +| |g;  

       $term=~s/_/ /g;
       $result=~s/$term//ig;   # delete query term
       
       return $result;

    } #end-if($type eq "iq")


    # dictionary search
    elsif ($source eq "di") {
	$text=~s/\s+/ /g;
	$text=~m!(entries|entry) found for.+?<TABLE>.+?</TABLE>!ig;
	$text=$&;
	@results= $text=~m|<DD>(.+?)</DD>|ig;
	@results= $text=~m|<LI>(.+?)</LI>|ig if (!@results);
    } #end-if($type eq "di")

    # google search
    elsif ($source eq "gg") {
        $text=~s/\s+/ /g;
        $text=~s/-/ /g;
        $text=~s/\.com//g;
	$term=~s/\+/ /;  # change space back to + for phrases
        @results= $text=~m|<b>$term</b>.+?<b>\.\.\.</b> ?<br>|ig;
        $text= join(" ",@results);
        $text=~ s/<.+?>/ /g;
        @results= $text=~ m|$term([ ,\.a-zA-Z]{3,}?)\.\.\.|ig;
    } #end-if($type eq "gg")

    elsif($source eq "an"){
         $text=~m|<span class=\"hw\">(.+?)</div>|s;
	 $tmp=$1;
	 $tmp= cleanTag($tmp);
	 $result=$1 if ($tmp=~m|#(.+?)#|);

	 return $result;

         #get the proper contents
         # if($text =~ /<tr><td><a class=\"ilnk\" href=\"#Dictionary\">Dictionary<\/a><\/td><\/tr>/s){
         #      if($text =~ /^(.*?)Dictionary<\/h2>.*?<span class=\"hw\">(.*?)<hr style=\"clear:both\"\/>.*$/si){
         #             $tmp = $2;
         #             $tmp =~ s/^.*<p>(.*?)<\/p>.*$/$1/si;
         #             $tmp =~ s/^.*<ol>(.*?)<\/ol>.*$/$1/si;
         #             $tmp = cleanTag($tmp);
         #             push(@results,"$tmp\n");
         #      }
         #  }
         #  elsif($text =~ /<tr><td><a class=\"ilnk\" href=\"#Obscure\">Obscure<\/a><\/td><\/tr>/s){
         #       if($text =~ /^(.*?)Obscure<\/h2>.*?<span class=\"hw\">($term)<\/span>(.*?)<br clear=\"right\" \/>.*$/si){
         #             $tmp = $3;
         #             $tmp = cleanTag($tmp);
         #             $tmp =~ s/^\s*\/.+?\/(.*)$/$1/;
         #             push(@results, "$tmp\n");
         #       }
         #  }
    } #end-if($type eq "an")

    $result= join(" ",@results);
    $result=~ s/<.+?>/ /g;
    #$result=~ s/$term//ig;
    $result=~ s/ +/ /g;

    return $result;

} #endsub extract_def



#-----------------------------------------------------
# eliminate string A words from string B
#-----------------------------------------------------
#   arg1 = string A
#   arg2 = string B
#   r.v. = processed string B
#-----------------------------------------------------
sub xwds {
    my($str1,$str2)=@_;

    $str1=~s/[",]/ /g;
    my @wd1= split(/ +/,$str1);

    my %wd1;
    foreach my $wd(@wd1) {
        $wd1{lc($wd)}++;
    }

    $str2=~s/[",]/ /g;
    my @wd2= split(/ +/,$str2);

    my @wds;
    foreach my $wd(@wd2) {
        push(@wds,$wd) if (!exists($wd1{lc($wd)}));
    }

    return join(" ",@wds);

} #endsub xwds



#-----------------------------------
# extract quoted phrase from text
#  - Kiduk, 7/24/2006
#  - return text w/o phrases as second value
#      updated, 7/14/2007
#-----------------------------------
#  arg1= text string
#  arg2= phrase string
#  r.v.= (phrase string, text sans phrases)
#-----------------------------------
sub getphrase {
    my ($text)=@_;

    my @phrases;
    while ($text=~/"([\w \-]+)"/g) {
        my ($ph,$mstr)=($1,$&);
        $text=~s/$mstr//;
        if ($ph=~/ /) {
            $ph=~s/ +/-/g;
            push(@phrases,$ph);
        }
    }
    while ($text=~/\b(\w+\-\w+)\b/g) {
        push(@phrases,$1);
    }

    my $phstr= join(" ",@phrases);
    return ($phstr,$text);

} #endsub getphrase



#-----------------------------------------------------------
# make phrases
#   - adjacent nouns
#   - adjacent words that are valid hyphenated words
# (Note: input string should be stopped and stemmed)
#-----------------------------------------------------------
# arg1 = string of words
# arg2 = pointer to hyphenated word hash
#        (key= hyphenated-word)
# arg3 = pointer to noun hash
#        (key= noun)
# r.v. = string of phrase bigrams
#-----------------------------------------------------------
sub mkphrase {

    my ($instr,$hyphp,$nounhp)=@_;
    my ($noun,$pnoun,$pwd,@outwds);

    my @inwds=split(/ +/,$instr);

    $pwd="";
    foreach my $wd(@inwds) {
        $wd=~tr/A-Z/a-z/;
        if ($$nounhp{$wd}) { $noun=1; }
        else { $noun=0; }
        my $hwd= "$pwd-$wd";
        if (($$hyphp{$hwd}) || ($noun && $pnoun)) { 
            push(@outwds,"$pwd-$wd"); 
            push(@outwds,"$wd-$pwd"); 
        }
        $pnoun=$noun;
        $pwd=$wd;
    }

    return join(" ",@outwds);

} # endsub mkphrase



#--------------------------------------------------------------
# identify noun phrases
#   by Ning Yu, 07/09/2004 (getNoun_final.pl)
#   modified by Kiduk Yang, 07/10/2004
#   added non-stem list to arguments, Kiduk, 7/14/07
#    - no-stem words are output as is & stemmed
#--------------------------------------------------------------
# arg1  = text string
# arg2  = pointer to stopword hash
# arg3  = pointer to proper noun hash
# arg4  = pointer to krovetz dictionary subset hash
# arg5  = stemmer (0=simple, 1=combo, 2=porter)
# arg6  = tagger(0=brill's, 1=monty)
# arg7  = pointer to non-stem word hash
# r.v.  = (noun-string, phrase-string)
#--------------------------------------------------------------
# NOTES: 
#   - replaces the false clause delimiter. (e.g. U.S.)
#   - stop & stem should not be performed prior to this routine
#   - phrases are hyphenated in the output string
#--------------------------------------------------------------
sub mkphrase2 {
    my ($text,$stophp,$pnhp,$sdhp,$stemmer,$tagger,$nostemhp)=@_;
    if(!$tagger){$tagger=0;}#default is brill's tagger now

    my $debug=0;

    my @lines;
   
    if($tagger ==0){
       @lines=&brilltag($text);
    }
    else{
       @lines=&montytag($text);
    }


    #-------------------------------------------------
    # extract noun (@nouns) and noun phrases (@noun_ps)
    #-------------------------------------------------
    my (@nouns,@noun_ps);

    foreach (@lines){
	chomp;

	my @words= split/ +/;

        my ($ptag,$pptag,$tag,$pwd,$ppwd)=('O','O');

	foreach my $word(@words) {
            print "mkphrase2: wd=$word\n" if ($debug);
            if ($word =~ /\/NNP?S?$/) {
                $word =~ s/(.*)\/NNP?S?$/$1/;
                if ($nostemhp->{$word}) { push(@nouns,$word); }  # output no-stem word as is & stemmed
                if (!$$pnhp{$word}) {
                    $word=&stemword2($word,$stophp,$pnhp,$sdhp,$stemmer);
                }
                # stopped word
                if (!$word || $$stophp{$word}) { $tag="O"; }
                else {
                    push(@nouns,$word);
                    $tag="N"; # noun
                }
            }
            elsif ($word =~ /\/(JJ[RS]?)$/) {
                my $jtag = $1;
                $word =~ s/(.*)\/JJ[RS]?$/$1/;
                if ($$stophp{$word}) {$tag="O";}
                else {
                    if($jtag =~ /[RS]$/){
                        $tag= "eJ";
                    }
                    else{
                       $tag="J"; # adjective
                    }
                }
            }
            elsif ($word =~ /\/VB[GN]$/) {
                $word =~ s/(.*)\/VB[GN]$/$1/;
                if ($$stophp{$word}) { $tag="O"; }
                else {
                    $tag="V"; # present or past participle verb
                }
            }
            else {
                $tag="O"; # other
            }

            print "MKPH2: wd=$word, tag=$tag, pwd=$pwd, ptag=$ptag\n" if ($debug);
            next if (length($word)<2);

            my $tags2= $pptag.$ptag.$tag;
            push(@noun_ps,"$ppwd-$pwd-$word") if ($tags2=~/NNN/);

            my $tags= $ptag.$tag;
            if ($tags=~/[JNV]N$/) {
                if ($tags =~ /^e/){
                     my $pwd_ex = &exAdj($pwd);
                     if($pwd_ex&&!$$stophp{$pwd_ex}){
                         push(@noun_ps,"$pwd_ex-$word");
                         print "MKPH2: ph1=$pwd_ex-$word\n" if ($debug);
                     }
                }
                push(@noun_ps,"$pwd-$word");
                print "MKPH2: ph2=$pwd-$word\n" if ($debug);
            }

            $pptag=$ptag;
            $ptag=$tag;
            $ppwd=$pwd;
            $pwd=$word;

        } #end-foreach $word(@words)

    } #end-foreach (@lines)

    return ("@nouns","@noun_ps");

} #endsub mkphrase2

#--------------------------------------------------------------
# identify noun phrases
#   by Ning Yu, 06/14/2007
#--------------------------------------------------------------
# arg1  = text string
# arg2  = pointer to stopword hash
# arg3  = pointer to proper noun hash
# arg4  = pointer to krovetz dictionary subset hash  
# arg5  = stemmer (0=simple, 1=combo, 2=porter)       
# r.v.  = (noun-string, phrase-string)
#--------------------------------------------------------------
# NOTES:
#   - replaces the false clause delimiter. (e.g. U.S.)
#   - stop & stem is should be performed prior to this routine
#   - phrases are hyphenated in the output string
#   - return n+n and adj+n but not verb+noun
#--------------------------------------------------------------

sub mkphrase3 {
    my ($text,$stophp,$pnhp,$sdhp,$stemmer)=@_;
    my $debug=0;

    my @lines = &montyExtractor($text) ;

    #-------------------------------------------------
    # extract noun (@nouns) and noun phrases (@noun_ps)
    #-------------------------------------------------
    my (@nouns,@noun_ps);      
    foreach (@lines){
        chomp;
        print "MKPH3: line=$_\n" if ($debug);
        if($_ !~ /\w\s\w/){
            if (!$$pnhp{$_}) {
                $_=&stemword2($_,$stophp,$pnhp,$sdhp,$stemmer);
            }
            next if (/^\s*$/);  # kiyang, 6/19/2007
            # stopped word
            if (!exists($$stophp{$_})){
                $_ =~s/^\s+//;
                $_ =~s/\s+$//;
                push(@nouns, "$_");
            }
        }
        else{
            next if ($_ =~ /[.?!,:;'"<>(){}\[\]]/);
            my @tagged_wds = split(/\s+/,$_);
            my $phrase="";
            my $phrase_ex="";    
            while(my $tagged_wd=shift(@tagged_wds)){
                 my ($wd,$tag)=split(/\//,$tagged_wd);
                 next if(exists($$stophp{$wd}));
                 if($tag =~ /jj[rs]?/i){
                     $phrase.='-'.$wd;
                     my $wd_ex = &exAdj($wd);
                     if($wd_ex){
                        $phrase_ex.='-'.$wd_ex;
                     }
                 }
                 else{
                    if($tag =~/nn/i){
                       $wd=&stemword2($wd,$stophp,$pnhp,$sdhp,$stemmer);
                    }
                    # skip middle initial
                    if (!exists($$stophp{$wd}) && length($wd)>1){
                        $phrase.='-'.$wd;
                         if($phrase_ex){
                             $phrase_ex.='-'.$wd;
                         }
                    }
                    else{next;}
                 }
            }
            $phrase=~s/^-//;
            next if ($phrase=~/-$/ || $phrase!~/-/);
            print "MKPH3: ph=$phrase\n" if ($debug);
            push(@noun_ps,"$phrase");
            # modified by kiyang, 6/19/07
            my(@wds)=split(/-/,$phrase);
            if (@wds>2) {
                for(my $i=0;$i<@wds-1;$i++) {
                    push(@noun_ps,"$wds[$i]-$wds[$i+1]");
                }
            }
            if($phrase_ex){
                $phrase_ex=~s/^-//;
                push(@noun_ps,"$phrase_ex");
                my(@wds)=split(/-/,$phrase_ex);
                if (@wds>2) {
                    for(my $i=0;$i<@wds-1;$i++) {
                        push(@noun_ps,"$wds[$i]-$wds[$i+1]");
                    }
                }
            }
        }
   }
  return ("@nouns","@noun_ps");

} #endsub mkphrase3


#--------------------------------------------------------------
# tag text with Brill tagger
#   by Ning Yu, 07/09/2004 (getNoun_final.pl)
#   modified by Kiduk Yang, 07/13/2004
#  1. break up the text into sentences
#  2. tag each sentences
#--------------------------------------------------------------
# arg1  = text string
# r.v.  = (array of tagged string)
#--------------------------------------------------------------
# NOTES: 
#   - replaces the false clause delimiter. (e.g. U.S.)
#--------------------------------------------------------------
sub brilltag {
    my ($text)=@_;

    my $tagdir= "/u0/widit/prog/trec04/hard/RULE_BASED_TAGGER_V1.14/Bin_and_Data";
    my $tagger= "$tagdir/tagger";

    my $dir= `pwd`;
    chomp $dir;

    my @lines;

    # remove period to prevent false sentence recognition
    $text=&xdot($text);

    # break text into clauses
    @lines = split(/[.?!,:;'"<>(){}\[\]]/,$text);

    # write to a temporary file
    my ($ss,$mn)=localtime(time);
    my $tmpf= "$dir/tmp$ss$mn";
    open(TMP,">$tmpf") || die "can't write to $tmpf";
    foreach my $line(@lines) { print TMP "$line\n"; }
    close TMP;

    # set file mode: 33272
    #  - !!use stat function 
    `chmod 770 $tmpf`;

    # change to tagger directory: tagger requirement
    chdir($tagdir);

    # call the tagger
    my $text2= `$tagger LEXICON $tmpf BIGRAMS LEXICALRULEFILE CONTEXTUALRULEFILE 2>tmpf`;
    @lines=split(/\n/,$text2);

    # change back to original directory
    chdir($dir);

    `rm -f $tmpf`;

    return (@lines);

} #endsub brilltag


#--------------------------------------------------------------
# tag text with montyTagger
#   by Ning Yu, 06/15/2007
#  1. break up the text into sentences
#  2. tag each sentences
#--------------------------------------------------------------
# arg1  = text string
# r.v.  = (array of tagged string)
#--------------------------------------------------------------
# NOTES: 
#   - replaces the false clause delimiter. (e.g. U.S.)
#--------------------------------------------------------------
sub montytag {
    my ($text)=@_;

    my $tagdir= "/u0/widit/prog/trec07/montylingua-2.1/python";

    my $dir= `pwd`;
    chomp $dir;

    my @lines;

    # remove period to prevent false sentence recognition
    $text=&xdot($text);

    # break text into clauses
    @lines = split(/[.?!,:;'"<>(){}\[\]]/,$text);

    # write to a temporary file
    my ($ss,$mn)=localtime(time);
    my $tmpf= "$dir/tmp$ss$mn";
    open(TMP,">$tmpf") || die "can't write to $tmpf";
    foreach my $line(@lines) { print TMP "$line\n"; }
    close TMP;

    # set file mode: 33272
    #  - !!use stat function 
    `chmod 770 $tmpf`;

    # change to tagger directory: tagger requirement
    chdir($tagdir);

    # call the tagger
    my $text2= ` python tagText.py $tmpf`;
    @lines=split(/\s*#\/# !\/\. #\/#\s*/,$text2);

    # change back to original directory
    chdir($dir);

    `rm -f $tmpf`;

    return (@lines);

} #endsub montytag


#--------------------------------------------------------------
# extractor nouns and noun phrases with Monty
#   by Ning Yu, 06/15/2007
#--------------------------------------------------------------
# arg1  = text string
# r.v.  = (array of nouns and noun phrases)
#--------------------------------------------------------------
# NOTES:
#   - replaces the false clause delimiter. (e.g. U.S.)
#--------------------------------------------------------------
sub montyExtractor {
    my ($text)=@_;

    my $tagdir= "/u0/widit/prog/trec07/montylingua-2.1/python";

    my $dir= `pwd`;
    chomp $dir;

    my @lines;

    # remove period to prevent false sentence recognition
    $text=&xdot($text);

    # break text into clauses
    @lines = split(/[.?!,:;'"<>(){}\[\]]/,$text);

    # write to a temporary file
    my ($ss,$mn)=localtime(time);
    my $tmpf= "$dir/tmp$ss$mn";
    open(TMP,">$tmpf") || die "can't write to $tmpf";
    #foreach my $line(@lines) { print TMP "$line\n"; }
    print TMP "$text\n";
    close TMP;

    # set file mode: 33272
    #  - !!use stat function      
    `chmod 770 $tmpf`;

    # change to tagger directory: tagger requirement
    chdir($tagdir);

    # call the tagger
    @lines  = `python extractNP.py $tmpf`;

    # split tagged line by conjuction
    my @lines2;
    foreach (@lines) {
        if (m!/(CC|JJ)!) {
            s|( \w+/CC )|##|g;
            s| (\w+/JJ)|##$1|;
            my @ls=split/##/;
            foreach my $l(@ls) {
                push(@lines2,$l);
            }
        }
        else { push(@lines2,$_); }
    }

    # change back to original directory
    chdir($dir);

    `rm -f $tmpf`;

    return (@lines2);

} #endsub montyExtractor


#------------------------------------------------
# check to get the raw format of a comparative
#       or superlative adj via wordnet
# Author: Ning Yu, 06/15/2007
#------------------------------------------------
# arg1= comparative or superlative adj
# r.v.= raw adj
#------------------------------------------------
sub exAdj{
    my $adj=shift;
    my $adj_raw=''; 
    my $ex=''; 
    my $wnDir = "/usr/local/WordNet-3.0/dict";
    my ($find,$find1)=('','');
    my $debug = 0;

    print "input: $adj\n" if($debug);

    my $adj_tmp= $adj;    
    if(($adj_tmp =~ s/er$//)||($adj_tmp=~ s/est$//)){       
        #check if it is a valid word against data.adj
        # word is at column 5
        print "The word ends with er or est\n" if ($debug);
        my @finds= `grep \'\\b$adj_tmp\\b\' $wnDir/data.adj`;
        foreach (@finds){       
            chomp $_;
            print "Find $adj_tmp in data.adj\n" if ($debug);
            my @tmps=split(/\s+/, $_);
            if($tmps[4] eq $adj_tmp ){
               print "Find $adj_tmp in data.adj!!\n" if ($debug);
               $find=1;
                last;
             }
        }
        # check if after delete er or est at the end if there is

        # only one letter left(e.g.,best)
        if($adj_tmp=~/^\w{1}$/){
            print "After remove er or est, there is only one letter left\n!"if ($debug);
            $find=0;
        }

        #if not valid, check adj.exc then
        if(!$find){
            print "Can't find in data.adj\n" if($debug);
            $find1=`grep \'\\b$adj\\b\' $wnDir/adj.exc`;
            if($find1){
                print "find in adj.exc: $find1!!"if($debug);
               ($ex,$adj_raw) = split(/\s+/, $find1);
            }
        }
        else{
            $adj_raw = $adj_tmp;
        }
    }
    else{
       #check adj.exc
         print "$adj doesn't end with er or est"if($debug);
          $find1= `grep \'\\b$adj\\b\' $wnDir/adj.exc`;
         if($find1){
              print "find in adj.exc: $find1!!"if($debug);
             ($ex,$adj_raw) = split(/\s+/, $find1);
         }
    }
    return "$adj_raw";
}#end of exAdj

sub cleanTag{
        my($tmp) = @_;
        $tmp =~ s/<\/?p>//igs;
        $tmp =~ s/<\/?ol>//igs;
        $tmp =~ s/<li>/#/igs;
        $tmp =~ s/<.+?>/ /gs;
        $tmp =~ s/^\s*\n$//mg;
        $tmp =~ s/\s+/ /gs;
        $tmp =~ s/&nbsp;/ /gs;
        $tmp =~ s/&[a-z]+;/ /gs;
        return $tmp;
} 

# ------------------------------------------------------------------------
# load in the wordnet index
# Author:    Ning Yu, 07/2/2005
# ------------------------------------------------------------------------
# r.v.= pointer to WordNet index 
# ------------------------------------------------------------------------
#sub load_WNet {
#    use WordNet::QueryData;
#    my $wnp = WordNet::QueryData->new("/usr/share/wordnet/dict/");
#    return $wnp;
#}

# ------------------------------------------------------------------------
# get best synsets from words in a sentence
# Author:    Ning Yu, 07/2/2005
# ------------------------------------------------------------------------
# arg1 = pointer to WordNet index (returned by &load_WNet)
# arg2 = input text
# r.v. = an array of best synset for nouns
#        originalNoun#POS#sensekey#syn1#!#syn2#!#syn3#!# (per element)
#           where POS=n for noun
# ------------------------------------------------------------------------
sub getSyn2{
    my ($wn,$text) = @_;
    my @noun_syns;

    # call Brill's tagger first      
    my @tlines = &brilltag($text);
    chomp @tlines;
    my $ttext = $tlines[-1];

    # find the best sense for noun only
    my @noun_senses = &getSense($ttext);
       
    # query wordnet and get the synsets for the particular sense
    foreach my $n_s(@noun_senses){
         my $noun_syn = '';
         my @synsets = $wn->querySense("$n_s", "syns");
         $n_s =~ s/^(.+)#(.+)#(.+)$/$1/;
         $noun_syn .= $n_s.'##'; #the original noun
         foreach my $synset(@synsets){
              my @triple = split('#', $synset);
              my $s_n = $triple[0];
              if($n_s !~ /^$s_n$/i){
                  $noun_syn .= "$s_n#!#";
              }
        }
        push(@noun_syns, $noun_syn);
    }

   return(@noun_syns);

} #endsub getSyn2


#--------------------------------------------     
# call wsd.pl to get the best synsets
# Author:    Ning Yu, 07/2/2005
#              modified by Kiduk Yang, 07/03/2005
#--------------------------------------------
# arg1 = a string (in raw format)
# r.v. = triple noun sense word#POS#sensekey
#--------------------------------------------
sub getSense {
    my ($text) = @_;
    my $debug=0;
    my @senses = ();

    # write text to temporary file
    my $tmpfile= &writeTotf("tmp",$text);

    # get output filename
    my $outfile = &getfname("out");
  
    my $ec= system "perl /usr/local/bin/wsd.pl --context=$tmpfile --format=tagged --silent > $outfile";
    warn "getSense Error($ec): wsd.pl $tmpfile\n" if ($ec);
   
    # delete temporary file
    unlink ($tmpfile);

    open(RESULT, "$outfile");
    my @lines = <RESULT>;
    chomp @lines;
    close(RESULT);

    # delete output file
    unlink ($outfile);
    print "after wsd: @lines\n" if ($debug);

    foreach(@lines){
        my @triples = split(' ', $_);
        foreach my $tri(@triples){
            #print "$tri\n";
            if($tri =~ /^(.+)#(.+)#(.+)$/){
               my  $pos= $2;
               if($pos eq 'n'){
                  push(@senses,$tri);
                }
            }
        } 
     }
 
     return(@senses);
}


#------------------------------------------------
# check to see if file already exists
#   - if yes, add $n to the name, and recheck
#   - else return name
#------------------------------------------------
# arg1= filename stem
# arg2= text string to write
# r.v.= filename
#------------------------------------------------
sub writeTotf {
    my($fname,$str)=@_;
    my $outf=&getfname($fname);
    open(TMPF,">$outf") || die "can't write to $outf";
    flock(TMPF,2) || die "MKPH@ ERROR: cannot flock $outf";
    print TMPF "$str\n"; 
    close TMPF;
    return $outf;
}


#------------------------------------------------
# check to see if file already exists
#   - if yes, add $n to the name, and recheck
#   - else return name
#------------------------------------------------
# arg1= filename
# r.v.= filename
#------------------------------------------------
sub getfname {
    my $name=shift;
    my $dir= `pwd`;
    chomp $dir;
    my $newf= "$dir/$name";  
    my $i=0;
    while (-e $newf) { 
	$i++; 
	$newf= "$dir/$name$i"; 
    }
    return "$newf";
}

1
