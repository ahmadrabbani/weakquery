#!/usr/bin/perl -w

# -----------------------------------------------------------------
# Name:      qindxblog1.pl
# Author:    Kiduk Yang, 07/19/2006
#              modified 6/17/2007
#              modified 7/14/2007, 
#              modified 6/2/2008, 
#              $Id: qindxblog1.pl,v 1.5 2007/07/23 20:59:18 kiyang Exp $
# -----------------------------------------------------------------
# Description:  create individual queries from TREC topics file
#   1. stop and stem queries
#   2. identify nouns and noun phrases
#   3. add expanded form of abbreviations
# Modifications, 7/14/2007
#   1. updated prefix list for hyphenated words
#      - created pfxlist2
#   2. save last 2 portions of URLs 
#      - e.g. indiana.edu
#      - implemented in getword3 subroutine of indxsub.pl
#   3. quoted bigram 
#      - saved as phrase (getword3 sub)
#      - do not stem wordparts (stem sub in indxsub.pl)
#   4. hyphenated words
#      - as is & hyphen-compressed
# -----------------------------------------------------------------
# Arguments: 
#   arg1 = topic type (e=test, t=training, t0=old training)
# Input:     
#   $idir/06.topics.blog-train -- 2006 training topics
#   $idir/06.topics.851-900    -- 2007 training topics
#   $idir/07.topics.901-950    -- 2007 evaluation topics
#   $npdir/krovetz.lst -- dictionary subset for combo/krovetz stemmer
#   $tpdir/pnounxlist2 -- proper noun list for stemming exclusion
#   $tpdir/pfxlist2    -- prefix list (updated list, 7/14/07)
#   $tpdir/abbrlist4   -- abbreviation & acronym list
#   $tpdir/stoplist2   -- document stoplist
#   $tpdir/dict.arv    -- adjective, adverb, verb list
#   $tpdir/qstoplist   -- topic stoplist
# Output:    
#   $odir/query/$subd/q$qn  -- individual queries (processed)
#     within each <title> <desc> <narr> field
#     <title|desc|narr>
#       <text> raw query text </text>
#       <text0> stopped & stemmed w/ simple stemmer </text0>
#       <text1> stopped & stemmed w/ combo stemmer </text1>
#       <text2> stopped & stemmed w/ porter stemmer </text2>
#       <noun> nouns sperated by space </noun>
#       <phrase> hyphenated phrase sperated by space </phrase>
#       <acronym> acronyms/abbreviations:expanded by comma </acronym>
#       <nrtext> non-rel raw query text </nrtext>
#       <nrtext0> non-rel text stopped & stemmed w/ simple stemmer </nrtext0>
#       <nrtext1> non-rel text stopped & stemmed w/ combo stemmer </nrtext1>
#       <nrtext2> non-rel text stopped & stemmed w/ porter stemmer </nrtext2>
#     <nrnoun> nouns sperated by space </nrnoun>
#     <nrphrase> hyphenated phrase sperated by space </nrphrase>
#     <nracronym> acronyms/abbreviations:expanded by comma </nracronym>
#     </title|desc|narr>
#   $odir/query/$prog       -- program     (optional)
#   $odir/query/$prog.log   -- program log (optional)
#     where $subd= train0|train|test
# ------------------------------------------------------------------------
# NOTE:   
#   1. uses both document and topic-specific stopword lists
#   2. different stemmed versions are outputted
#   3. abbrlist4 is updated list of abbrlist3 using http://csob.berry.edu/faculty/jgrout/acronym.html
# ------------------------------------------------------------------------

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
my $npdir=  "$wpdir/nstem";             # stemmer directory
my $pdir=   "$tpdir/blog";              # HARD track program directory
my $idir=   "/u1/trec/topics";          # TREC topics directory
my $odir=   "/u3/trec/blog08";          # TREC index directory
my $qdir=   "$odir/query";              # query directory

my $subdict =  "$npdir/krovetz.lst";     # dictionary subset file for combo/krovetz stemmer
my $xlist   =  "$tpdir/pnounxlist2";     # proper noun list
my $abbrlist=  "$tpdir/abbrlist4";       # abbreviation list
my $pfxlist =  "$tpdir/pfxlist2";        # valid prefix list
my $stopfile=  "$tpdir/stoplist2";       # document stopword list
my $stopfile2= "$tpdir/qstoplist";       # topic stopword list
my $arvlist=   "$tpdir/dict.arv";        # adjective, adverb, verb

# test/evaluation topics: ?
my $qtest=  "$idir/08.blog-topics";

# training topics:  2006-2007
my $qtrain=  "$idir/06-07.blog-topics";

my @tags= ('title','desc','narr');
my %tags= (
'title'=>'Title',
'desc'=>'Description',
'narr'=>'Narrative'
);

require "$wpdir/logsub.pl";   # general subroutine library
require "$tpdir/NLPsub.pl";   # NLP subroutine library


#------------------------
# program arguments
#------------------------
my $prompt=
"arg1= topic type (e=test, t=train)\n";

my %valid_args= (
0 => " e t ",
); 

my ($arg_err,$qtype)= chkargs($prompt,\%valid_args,1);
die "$arg_err\n" if ($arg_err);      


my($qin,$outdir);
if ($qtype eq 'e') {
    $qin= $qtest;
    $outdir="$qdir/test";
}
elsif ($qtype eq 't') {
    $qin= $qtrain;
    $outdir="$qdir/train";
}


#------------------------
# start program log
#------------------------

$sfx= $qtype;          # program log file suffix
$noargp=1;             # if 1, do not print arguments to log
$append=0;             # log append flag

if (!-e $outdir) {
    my @errs=&makedir($outdir,$dirmode,$group);
    if (@errs) {
        print STDOUT "\n",@errs,"\n\n";
        die;
    }
}

if ($log) {
    @start_time= &begin_log($qdir,$filemode,$sfx,$noargp,$append);
    print LOG "Infile  = $qin\n",
              "Outfile = $outdir/q\$N\n\n";
}


#-------------------------------------------------
# create word list hashes
#  - %stoplist: stopwords
#  - %xlist:    proper nouns that shouldn't be stemmed
#  - %sdict:    word list for Combo/Krovetz stemmer
#  - %abbrlist: word list for acronyms and abbreviations
#  - %pfxlist:  word list for valid prefixes
#  - %arvlist:  ARV (adjective, adverb, verb) terms
#-------------------------------------------------

# create hash of adjective, adverb, & verb
my %arvlist;
&mkhash($arvlist,\%arvlist);

# document stopwords
my %stoplist;
&mkhash($stopfile,\%stoplist);

# topic stopwords
&mkhash($stopfile2,\%stoplist);

# create proper noun hash
my %xlist;
&mkhash($xlist,\%xlist);

# dictionary subset for combo/krovetz stemmer
my %sdict;
&mkhash($subdict,\%sdict);

# create acronym/abbreviation hash
my %abbrlist;
open(IN,$abbrlist) || die "can't read $abbrlist";
while (<IN>) {
    chomp;
    my ($word,$str)=split(/ +/,$_,2);
    $abbrlist{$word}=$str;
}
close IN;

# create prefix hash 
my %pfxlist;
open(IN,$pfxlist) || die "can't read $pfxlist";
while (<IN>) {
    chomp;
    my ($word)=split/-/;
    $pfxlist{"\L$word"}=1;
}
close IN;


#-------------------------------------------------
# process topics
#   1. stop & stem
#   2. create phrases
#   3. expand acronyms and abbreviations
#-------------------------------------------------

# read the topics file
open(IN,$qin) || die "can't read $qin";
my @lines=<IN>;
close IN;
chomp @lines;

# make one line per query
my $bstring= join(" ",@lines);
@lines= split(m|</top>|,$bstring);

my $qcnt=0;
my @errs;


#----------------------------------------------------
# process topics file
#   Modifications, 7/14/2007
#   1. updated prefix list for hyphenated words
#       - created pfxlist2
#   2. save last 2 portions of URLs 
#       - e.g. indiana.edu
#       - implemented in getword3 subroutine of indxsub.pl
#   3. quoted bigram 
#       - saved as phrase (getword3 sub)
#       - do not stem wordparts (stem sub in indxsub.pl)
#   4. hyphenated words: as is & hyphen-compressed
#   5. output single word string as is & stemmed
#----------------------------------------------------

foreach (@lines) {

    # exclude blank lines
    next if (/^\s*$/);

    # compress blanks
    s/ +/ /g;

    my $qn;

    # get query number
    if (/<num>.+?(\d+)/) {
	$qn= $1; 
	print LOG "Processing QN $qn\n";
	$qcnt++;
        my $outf= "$outdir/q$qn";   # processed queries
        open(OUT,">$outf") || die "can't write to $outf";
    }
    else {
        push(@errs,"$qcnt: missing QN\n");
    }

    my %abbrfound;

    # qtext: holds query text for title & desc
    # qnoun/qphrase: holds nouns/phrases for whole query
    # qnoun2: holds singleword string nouns for whole query
    # qphrase2: holds quoted string phrases for whole query
    my ($qtext,$qnoun,$qphrase,%qnoun2,%qphrase2);

    # get query text
    foreach my $tag(@tags) {

	# process each include tag field
	if (/<$tag>([^<]+)/) {

            my (@str,@nrstr);

	    my $text=$1;
            chomp $text;
	    $text=~s/$tags{$tag}:?//i;
	    $text=~s/^ *(.+?) *$/$1/;

            my ($text0,$nrtext0,$nrtext,$nrtext2,$nrstr0,$nrstr1,$nrstr2);
	    if ($tag=~/narr/) {
		($text0,$text,$nrtext0,$nrtext,$nrtext2)= &nonrel0($text,$qtext);
                # identify phrases
                #  - use full sentence w/ period for POS tagging
		($nrstr[0],$nrstr[1])= &mkphrase2($nrtext2,\%stoplist,\%xlist,\%sdict,0,0,\%qnoun2);
                # quoted phrases
                if (my ($phrase)= &getphrase($nrtext2)) {
                    if ($nrstr[1]) {
                        $nrstr[1] .= " \L$phrase";
                    }
                    else {
                        $nrstr[1] = lc($phrase);
                    }
                }
		my @nrwords= &getword3($nrtext,\%abbrlist,\%pfxlist,\%stoplist,\%arvlist);
		my $nrtext2= join(" ",@nrwords);
		$nrstr[2]= &unmkabbr3($nrtext2,\%abbrlist,\%abbrfound,$text);
		$nrstr0= &procword3(\@nrwords,\%stoplist,\%xlist,\%sdict,0,\%qnoun2);
		$nrstr1= &procword3(\@nrwords,\%stoplist,\%xlist,\%sdict,1,\%qnoun2);
		$nrstr2= &procword3(\@nrwords,\%stoplist,\%xlist,\%sdict,2,\%qnoun2);
		$nrstr[0]=~s/-//g;
	    }
            else { 
                $qtext .= " $text"; 
                $text0=$text;
            }

            my ($str0,$str1,$str2);

            # mark quoted phrases from prior fields
            foreach my $ph(keys %qphrase2) {
                $ph=~s/-/ /g;
                $text0=~s/($ph)/"$1"/gi;
                # compress multiple quotes
                $text0=~s/"+/"/g;  
            }

            # quoted phrases
            if (my ($phrase)= &getphrase($text0)) {

                # add phrases to %qphrase2
                my@ph=split(/ +/,$phrase);
                foreach my$ph(@ph) {
                    next if ($ph=~/^\s*$/);
                    $qphrase2{lc($ph)}++;
                }

                ($str[0],$str[1])= &mkphrase2($text0,\%stoplist,\%xlist,\%sdict,0,0,\%qnoun2);

                # add quoted phrase to phrase string
                if ($str[1]) { $str[1] .= " \L$phrase"; }
                else { $str[1] = lc($phrase); }

            }

            else {
                # identify phrases
                #  - before stop & stem: tagger requirement
                #  - $str[0]= noun string
                #  - $str[1]= phrase string (hyphenated phrases)
                #  - use full sentence w/ period for POS tagging
                ($str[0],$str[1])= &mkphrase2($text0,\%stoplist,\%xlist,\%sdict,0,0,\%qnoun2);
            }

            # process text
            #  - identify acronym/abbreviation
            #  - remove punctuations
            my @words= &getword3($text,\%abbrlist,\%pfxlist,\%stoplist,\%arvlist);

            # expand acronyms/abbreviations
            my $text2= join(" ",@words);
            # if single word string,
            #   - check for acronym expansion
            #   - add to %qnoun2 to output as is & stemmed
            if ($text2 !~ / /) {
                $qnoun2{$text2}++;
                $text2=uc($text2);
            }
            $str[2]= &unmkabbr3($text2,\%abbrlist,\%abbrfound,$text0);
            print "!ACRONYMS:\n$str[2]\n" if ($debug);

            # stop & stem 
            #  - str0= stemmed with simple stemmer
            #  - str1= stemmed with combo stemmer
            #  - str2= stemmed with porter stemmer
            $str0= &procword3(\@words,\%stoplist,\%xlist,\%sdict,0,\%qnoun2);
            $str1= &procword3(\@words,\%stoplist,\%xlist,\%sdict,1,\%qnoun2);
            $str2= &procword3(\@words,\%stoplist,\%xlist,\%sdict,2,\%qnoun2);

	    print OUT "<$tag>\n",
		      "<text>$text0</text>\n",
	              "<text0>$str0</text0>\n",
		      "<text1>$str1</text1>\n",
		      "<text2>$str2</text2>\n";

            # delete hyphens in hyphenated nouns to be consistent with document indexing
	    $str[0]=~s/-//g if ($str[0]);

            # delete trailing blanks
            $str[1]=~s/ +$// if ($str[1]);  

	    print OUT "<noun>$str[0]</noun>\n" if ($str[0]);
	    print OUT "<phrase>$str[1]</phrase>\n" if ($str[1]);
	    print OUT "<acronym>$str[2]</acronym>\n" if ($str[2]);

            $qnoun .= " $str[0]" if ($str[0]); 
            $qphrase .= " $str[1]" if ($str[1]); 

            if ($nrtext) {
                # take out rel. nouns from non-rel noun
                $nrstr[0]= &xwds($qnoun,$nrstr[0]) if ($nrstr[0] && $qnoun!~/^\s*$/);
                # take out rel. phrases from non-rel phrase
                $nrstr[1]= &xwds($qphrase,$nrstr[1]) if ($nrstr[1] && $qphrase!~/^\s*$/);
                print OUT
		      "<nrtext>$nrtext0</nrtext>\n",
	              "<nrtext0>$nrstr0</nrtext0>\n",
		      "<nrtext1>$nrstr1</nrtext1>\n",
		      "<nrtext2>$nrstr2</nrtext2>\n";
		print OUT "<nrnoun>$nrstr[0]</nrnoun>\n" if ($nrstr[0]);
		print OUT "<nrphrase>$nrstr[1]</nrphrase>\n" if ($nrstr[1]);
		print OUT "<nracronym>$nrstr[2]</nracronym>\n" if ($nrstr[2]);
            }

            print OUT "</$tag>\n";

	}

	else {
	    push(@errs,"$qcnt ($qn): missing $tag\n");
	}

    }

} # endforeach

# print out potential topic processing errors
if (@errs) {
    print LOG "\n-- !Warning: Potential errors in Topics Processing! --\n",@errs,"\n\n";
}


#-------------------------------------------------
# end program
#-------------------------------------------------

print LOG "\nProcessed $qcnt queries\n\n";

&end_log($pdir,$qdir,$filemode,@start_time) if ($log);

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
    foreach my $word(@terms) { $$hp{$word}++; }

} #endsub mkhash


#-------------------------------------------------
# parse sentences that ends w/ 'not relevant'
#-------------------------------------------------
#  arg1= raw text
#  arg2= raw text for title & desc
#  r.v.= $txt0:  text w/o non-rel string (whole)
#        $txt:   text w/o non-rel string (processed)
#        $nrtxt0: non-rel text (whole)
#        $nrtxt: non-rel text (processed)
#        $nrtxt2: non-rel text (absolute)
#-------------------------------------------------
sub nonrel0 {
    my ($str,$qtxt)=@_;

    # remove embedded period to prevent false sentence boundary
    $str=&xdot($str); 

    # artificial sentence break
    $str=~s/, (but|however) /. /g;
    my @sentence=split(/[;\.] +/,$str);

    my (@txt0,@txt,@txt2,@nrtxt0,@nrtxt1,@nrtxt2);

    foreach my $st(@sentence) {

        if ($st=~/not relevant/i) {

	    $st =~ s/\W$//;
	    push(@nrtxt0,$st);

            # A1 w/o B1 or A2 w/o B2 is non relevant
            # Non relevant is A1 w/o B1 or A2 w/o B2
            #  - A1, A2 = weak negative
            #  - B1, B2= positive
            if ($st=~/without (.+?) or.+?without (.+?) not relevant/ || 
                $st=~/Not relevant .+?without(.+)or+?without(.+?)/) { 
                push(@txt0,"$1 are relevant"); 
                push(@txt0,"$2 are relevant"); 
                push(@txt,$1);
                push(@txt,$2);
            }

            # A but notB is non relevant
            # Non relevant is A but notB
            #  - A= weak negative
            #  - B= positive
            elsif ($st=~/(outside|without|with no|where no) (.+) not relevant/ || 
                $st=~/Not relevant .+?(outside|without|with no|where no)(.+)/) { 
                my ($prep,$hit)=($1,$2);
                if ($prep=~/where/i) {
                    push(@txt0,$hit); 
                }
                else {
                    push(@txt0,"$hit is relevant"); 
                }
                push(@txt,$hit); 
            }

            # A not relevant, but B relevant
            #  - A= negative
            #  - B= positive
            elsif ($st=~/(.+) not relevant, but (.+) relevant.?$/) {
                push(@nrtxt1,$1); 
                push(@nrtxt2,"$1 not relevant"); 
                push(@txt0,"$2 relevant"); 
                push(@txt,$2); 
            }

            # A not relevant unless B
            #  - A= weak negative
            #  - B= strong positive 
            elsif ($st=~/.+ not relevant,? (unless|without) (.+)$/) {
                my ($prep,$hit)=($1,$2);
                if ($prep=~/without/i) {
                    push(@txt0,"$hit is relevant");
                }
                else {
                    push(@txt0,$hit);
                }
                push(@txt,$hit); 
            }

            # A that don't B is not relevant
            #  - A= weak negative
            #  - B= strong positive 
            elsif ($st=~/(do not|don't) (.+) not relevant.?$/) {
                push(@txt0,"$2 relevant"); 
                push(@txt,$2); 
            }

            # not relevant if/when A
            #  - A= negative
            elsif ($st=~/not relevant (only )?(if|when) (.+)$/) {
                push(@nrtxt1,$3); 
                push(@nrtxt2,$3); 
            }

            # relevant if/when A
            #  - A= positive
            elsif ($st=~/relevant (only )?(if|when) (.+)$/) {
                push(@txt0,$3); 
                push(@txt,$3); 
            }

            # exclude: A when only B is not relevant
            elsif ($st!~/only/i) {
		push(@nrtxt1,$st); 
		push(@nrtxt2,$st); 
            }
        }

        else {
	    push(@txt0,$st);
	    push(@txt,$st);
        }

    } # end foreach

    my $txt0= join(". ",@txt0);
    my $txt= join(" ",@txt);

    my $nrtxt0= join(". ",@nrtxt0);
    my $nrtxt1= join(" ",@nrtxt1);
    my $nrtxt2= join(" ",@nrtxt2);
    
    my $nrtxt= &xwds("$txt $qtxt",$nrtxt1);

    return ($txt0,$txt,$nrtxt0,$nrtxt,$nrtxt2);

} #endsub nonrel0


#-------------------------------------------------
# parse sentences that ends w/ 'not relevant'
#   - coded by Ning Yu, 7/22/2006
#-------------------------------------------------
#  arg1= raw text
#  arg2= raw text for title & desc
#  r.v.= text w/o non-rel string
#        non-rel text (whole)
#        non-rel text (processed)
#-------------------------------------------------
sub nonrel {
    my ($str,$qtxt)=@_;

    # remove embedded period to prevent false sentence boundary
    $str=&xdot($str); 

    my @sentence=split(/[;\.] +/,$str);
    my (@txt0,@txt1,@nrtxt0,@nrtxt1);

    foreach my $st(@sentence) {
        
        if ($st=~/not relevant/i) {
            $st =~ s/\W$//;
            push(@nrtxt0,$st);
            #--------------------------------------------------
            #not relevant appear at the begining or end of a sentence
            #--------------------------------------------------
 
            if(($st=~/^(.*) not relevant$/)||($st=~/^Not relevant (.*)$/)){
                #possible non-relevant
                my $pnr = $1;
 
                if($pnr !~ /\brelevant\b/i){
                    &parse($pnr, 0, \@txt0,\@nrtxt0,\@txt1,\@nrtxt1);
                }
                # won't work for 'this is not relevant, and that is also not relevant'
                elsif($st=~/^(.+) relevant, (.+) not relevant$/){
                    &parse($2, 0, \@txt0,\@nrtxt0,\@txt1,\@nrtxt1);
                    &parse($1, 1, \@txt0,\@nrtxt0,\@txt1,\@nrtxt1);
                }
                elsif($st=~/relevant (.+?), (.+) not relevant$/i){
                   &parse($2, 0, \@txt0,\@nrtxt0,\@txt1,\@nrtxt1);
                   &parse($1, 1, \@txt0,\@nrtxt0,\@txt1,\@nrtxt1);
                }
                elsif($st=~ /^Not relevant (.+?), (.+) relevant/){
                    &parse($1, 0, \@txt0,\@nrtxt0,\@txt1,\@nrtxt1);
                    &parse($2, 1, \@txt0,\@nrtxt0,\@txt1,\@nrtxt1);
                }
                elsif($st=~ /^Not relevant (.+), relevant (.+)$/){
                     &parse($1, 0, \@txt0,\@nrtxt0,\@txt1,\@nrtxt1);
                     &parse($2, 1, \@txt0,\@nrtxt0,\@txt1,\@nrtxt1);
                }
            }

            #--------------------------------------------------
            # not relevant appear in the middle of a sentence
            #--------------------------------------------------

            # A not relevant, but B relevant
            #  - A= negative
            #  - B= positive
            elsif($st =~/^(.+) not relevant, (.+) relevant$/){
                #possible non-relevant
                &parse($1, 0, \@txt0,\@nrtxt0,\@txt1,\@nrtxt1);
                &parse($2, 1, \@txt0,\@nrtxt0,\@txt1,\@nrtxt1);
            }

            # A not relevant unless B
            #  - A= weak negative
            #  - B= strong positive
            elsif($st =~ /^.+ not relevant,? (unless|without) (.+)$/){
                &parse($2, 1, \@txt0,\@nrtxt0,\@txt1,\@nrtxt1);
            }

            # not relevant if/when A
            #  - A= negative
            elsif($st=~/not relevant (only )?(if|when) (.+)$/) {
                &parse($3, 0,\@txt0,\@nrtxt0,\@txt1,\@nrtxt1);
            }

        }#end of if has 'not relevant

        #-----------------------------------------------
        # relevant appear in the middle of a sentence
        #----------------------------------------------

        # relevant if/when A
        #  - A= positive
        elsif ($st=~/relevant (only )?(if|when) (.+)$/) {
            &parse($3, 1, \@txt0,\@nrtxt0,\@txt1,\@nrtxt1);
        }

        #-----------------------------------------------
        # all the others
        #----------------------------------------------
        else{
             push(@txt1,$st);
        }

    } # end foreach

    my $txt0= join(" ",@txt0);
    my $txt1= join(" ",@txt1);
    my $txt= "$txt0 $txt1";

    my $nrtxt0= join(". ",@nrtxt0);
    my $nrtxt1= join(" ",@nrtxt1);
    
    my $nrtxt= &xwds("$txt $qtxt",$nrtxt1);

    return ($txt,$nrtxt0,$nrtxt);

}


#-----------------------------------------------------
# parse the possible non relevant text
#   - coded by Ning Yu, 7/22/2006
#-----------------------------------------------------
#   arg1 = relevent or non-relevant text
#   arg2 = flag (1: relevant text, 0: non-relevant text)
#   arg3 = reference to @txt0
#   arg4 = reference to @nrtxt0
#   arg5 = reference to @txt1
#   arg6 = reference to @rntxt1
#-----------------------------------------------------
#  note: A1 w/o B1 or A2 w/o B2 or... is taken care of
#-----------------------------------------------------
sub parse{
    my ($text, $flag, $txt0,$nrtxt0,$txt1,$nrtxt1) =@_;
    my $conj = "(outside|without|with no|where no|do not|don\'t)";
    #if having $conj in middle
    if($text =~ /$conj/){
         my $cont = 1;
         while($cont){
            $cont = 0;
            if (my @matches = $text=~/$conj(.+?)(,? (or|and).+?($conj.+?))?$/){
                if(@matches >0){
                   foreach my $match(@matches){
                         next if (!$match);
                         next if ($match =~ /^\s*$/);
                         next if ($match =~ /^$conj$/);
                         next if ($match =~ /^(or|and)$/);
                         if($match =~ /$conj/){$text=$match; $cont = 1;}
                         else{
                             if($flag == 0){
                                push(@$txt0,$match);
                             }
                             else{
                                push(@$nrtxt0,$match);
                             }
                         }
                   }
                }
             }
         }#end of while
    }
    #else absolute non-relevant
    else{
        if($flag ==0){
            if($text!~/only/i){
               push(@$nrtxt1, $text);
            }
        }
        else{
            push(@$txt1, $text);
        }
    }

} #endsub parse

