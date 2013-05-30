###########################################################
# subroutines for stemming modules
#   - Kiduk Yang, 6/2004
#   -   modified Simple, 7/21/2006
#----------------------------------------------------------
# Simple:     modified simple stemmer
# Simpler:    streamlined simple stemmer (Adam Wead, 12/2004)
# Porter:     Porter Stemmer (Martin Porter)
# mkKVhash:   make a hash of words with 'ed' or 'ing' suffix
#               (for Krovetz stemmer)
# Krovetz:    modified Krovetz stemmer
# combostem:  combo stemmer
###########################################################
            

#-----------------------------------------------------------
# apply simple plural stemming algorithm to a word
#  by Rong Tang, 11/96
#     modified by Kiduk Yang, 6/2004
#     modified by Adam Wead, 7/2004
#     modified by Kiduk Yang, 2/2008
#      - added the second optional argument
#-----------------------------------------------------------
#  arg1   = word
#  arg2   = pointer to exclusion hash
#  r.v.   = stemmed word
#-----------------------------------------------------------
sub Simple {
    my ($word,$xhp)= @_;

    # singular and plural forms are identical
    # also, M7 tag in bigdict.dat
    #  - 7/21/2006: added 'news'
    my $xlist="axis biceps bourgeois caries civies cosmos ethos falsies finis ".
              "nopheles pharos polaris precis rabies scabies series shambles ".
              "species superficies undies willies fungus calculus papyrus apparatus ".
              "gas canvas mass class glass mass trespass brass grass success ".
              "excess wireless mess kindness rudeness likeness highness business ".
              "pettiness weakness thickness sickness illness witness unpleasantness ".
              "fastness dress address egress express stress loss moss fuss muss " .
	      "bias asbestos news";


    # exceptions to 'ies' conflation
    my $xlist1="bookies indies bourgeoisies talkies brownies gillies zombies ".
               "boogie-woogies Mounties menageries sorties outvies gaucheries ".
               "nighties mince-pies sweeties movies genies laddies corries neckties ".
               "walkie-talkies dominies Aussies goalies Aries rookies knobkerries ".
               "gendarmeries coteries belies rotisseries underlies cup-ties dixies ".
               "toughies lassies causeries collies magpies boogies prairies quickies ".
               "reveries cowries coolies patisseries unties budgies calories weirdies ".
               "koppies brasseries stymies";

    # exceptions to 'es' conflation
    my $xlist2="axes ice-axes battle-axes poleaxes pickaxes overseas ";

    %xlist0= ('monies'=>'money', 'civvies'=>'civies', 'viruses'=>'virus',
                                'vetoes'=>'veto', 'hypotheses'=>'hypothesis');

    if ($word=~/sis$/i || $xlist=~/\b$word\b/i) {
        return $word;
    }

    elsif ($xlist0{"\L$word"}) {
        return $xlist0{$word};
    }

    elsif ($xhp && $xhp->{$word}) {
        return $word;
    }

    elsif ($word=~/s$/) {
        if ($word=~/.[^ae]ies$/i && $xlist1!~/\b$word\b/i)  { $word=~s/ies$/y/i; }
        elsif ($word=~/itis$/i)  { $word=$word; }
        elsif ($word=~/sses$/i)  { $word=~s/es$//i; }
        elsif ($word=~/[ai]ches$/i)  { $word=~s/es$/e/i; }
        elsif ($word=~/hes$/i || ($word=~/xes$/i && $xlist2!~/\b$word\b/i)) { $word=~s/es$//i; }
        elsif ($word=~/.[^aeo]es$/i)  { $word=~s/es$/e/i; }
        elsif ($word=~/.[^su]s$/i)  { $word=~s/s$//i; }
    }

    return $word;

} # endsub Simple


# singular and plural forms are identical
# also, M7 tag in bigdict.dat
#  - 7/21/2006: added 'news'
$SimplerSame= "
academicals acropolis address aegis aerobatics aeronautics alas alias alms amaryllis 
ambergris amidships analects annals anopheles antipodes aphis apparatus apropos arras 
asbestos astronautics astrophysics atlas avoirdupois axis backwoods badlands banns bathos bedclothes 
betimes bias biceps billiards binoculars bonkers bourgeois brass breadthways business butterfingers
calculus calends calisthenics callisthenics cannabis canvas caries chamois chaos chrysalis 
civies class clematis clitoris collywobbles compos consols contretemps corps cos cosmos 
cripes crossbones crosskeys crosstrees dais debris diabetes dickens dietetics doldrums dramatis 
dress dungarees eaves edgeways egress elevenses endways entrails epidermis epiglottis 
erysipelas ethos eugenics eurhythmics eurythmics excess express faeces faeces falsies 
fastness finis fisticuffs fleshings footlights forceps fracas fungus fuss gallows 
gas gasworks geophysics geopolitics giblets glanders glass glottis grass grassroots gratis 
greaves habeas haggis headphones headquarters hereabouts highness hors houselights hubris 
hustings ibis ides ignes ignis illness innards iris isosceles jackanapes 
jakes kalends kindness kansas knickers kudos kumis lapis lazybones leastways lengthways 
lens levis lexis likeness litotes longways los loss lowlands malapropos mantis maquis 
marquis mass mass matins mattins mavis measles mesdames mesdemoiselles meseems mess messieurs
messrs methinks meths metropolis midships molasses morris moss muggins mumps muss mutatis necropolis 
news nopheles nowadays numismatics oaves oodles orchis overclothes oyes pajamas pancreas 
panties papyrus paratroops paterfamilias pathos patois pelvis penis pettiness pharos 
pliers polaris portcullis precis proboscis prophylaxis rabies reredos revers rhinoceros 
riches rickets rudeness saltworks sandshoes sans scabies schnapps schooldays scissors secateurs senores 
series shambles shucks sickness sideburns sideways smithereens soapsuds species starkers stress success 
suds sulphonamides superficies syphilis tennis testis thermos thickness tiddlywinks trellis 
trespass trews tripos turps underclothes underpants undies unpleasantness upstairs verdigris 
vespers vibes waterworks weakness whereabouts willies wireless witness
";

# conflation exception list #1
$SimplerXlist1= "
aloes aches microfiches cliches niches pastiches quiches avalanches brioches cloches 
demarches schottisches douches barouches psyches amanuenses analyzes antitheses apices apotheoses 
axes battle-axes beeves bronzes canoes catharses cloverleaves codices cortices crises 
diaereses diereses dyes elves emphases eyes floes flyleaves foes friezes 
fuzes goodbyes hooves hypnoses ice-axes icefloes indices loaves lyes nemeses 
neuroses oases oboes oxeyes oyes paralyzes parentheses periphrases pickaxes poleaxes 
princes prognoses psychoanalyzes psychoses roes scarves sheaves sloes synopses syntheses 
throes tiptoes topazes trapezes turves vertices vortices wharves
";

# conflation exception list #2
$SimplerXlist2= "
Aries topazes quizes jazzes fizzes frizzes buzzes detaches Aussies Mounties 
appendices belies boogie-woogies boogies bookies bourgeoisies brasseries brownies budgies calories 
calyces causeries cervices collies coolies corries coteries cowries cup-ties dixies 
dominies gaucheries gendarmeries genies gillies goalies indies knobkerries koppies laddies 
lassies magpies matrices menageries mince-pies movies neckties nighties outvies patisseries 
prairies quickies reveries rookies rotisseries sorties stymies sweeties talkies toughies 
underlies unties walkie-talkies weirdies zombies 
";

# irregular conflations
%SimplerUnique = (
'monies'	  => 'money',
'civvies'	  => 'civies',
'viruses'	  => 'virus',
'vetoes'	  => 'veto',
'hypotheses'  => 'hypothesis',
'aphides'	  => 'aphis',
'naiades'	  => 'naiad',
'iambuses'	  => 'iamb',
'testes'	  => 'testis',
'pelves'	  => 'pelvis',
'marquises'	  => 'marquess',
'helves'	  => 'helve',
'phalanges'	  => 'phalanx'
);


#-----------------------------------------------------------
# Simpler : new and improved simple stemmer
#           Adam Wead, 12/1/2004
#           modified by Kiduk Yang, 12/6/2004
#-----------------------------------------------------------
# apply simple plural stemming algorithm to a word
#  - for efficiency, input should be a word with 's' suffix
#-----------------------------------------------------------
#  arg1  = input word
#  arg2  = list of words whose singluar & plural forms are the same
#  arg3  = conflation exception list 1
#  arg4  = conflation exception list 2
#  arg5  = pointer to irregular conflation hash
#  r.v.  = stemmed word
#  (NOTE: arg2, 3, 4 are space-delimited strings)
#-----------------------------------------------------------
sub Simpler {
    my ($word,$same,$xlist1,$xlist2,$uniquehp)= @_;

    # initialize
    $same=$SimplerSame if (!$same);
    $xlist1=$SimplerXlist1 if (!$Xlist1);
    $xlist2=$SimplerXlist2 if (!$Xlist2);
    $uniquehp=\%SimplerUnique if (!$uniquehp);

    # words not to stem
    #  - sis suffix
    #  - singular and plural forms are identical
    #  - M7 tag in bigdict.dat
    if ($word=~/sis$/i || $word=~/itis$/i || $same=~/\b$word\b/i) {
	return $word;
    }
	
    # words with irreqular conflation
    elsif ($$uniquehp{"\L$word"}) {
	return $$uniquehp{$word};
    }
	
    # all words ending in s
    else {
	    
	#-------------
	# es rules
	#-------------

	# -ies
	if ($word=~/.[^ae]ies$/i && $xlist2!~/\b$word\b/i)  { $word=~s/ies$/y/i; }

	# -ces
	elsif ($word=~/[iy]ces$/i)  { 
	    if ($xlist1=~/\b$word\b/i)  { $word=~s/ices$/ex/i; }
	    elsif ($xlist2=~/\b$word\b/i) { $word=~s/ces$/x/i; }
	    else { $word=~s/s$//i; }
	}	

	# -hes
	elsif ($word=~/hes$/i)  { 
	    if ($xlist2=~/\b$word\b/i) { $word=~s/es$//i; }
	    elsif ($xlist1=~/\b$word\b/i || $word=~/[^eo]aches$/i || $word=~/[pt]hes$/i)
                { $word=~s/s$//i; }
	    else { $word=~s/es$//i; }
	}	

	# -oes
	elsif ($word=~/oes$/i) {
	    if ($word=~/shoes$/i) { $word=~s/s$//i; }
	    elsif ($xlist1=~/\b$word\b/i) { $word=~s/s$//i; }
	    else { $word=~s/es$//i; }
	}

	# -sses
	elsif ($word=~/sses$/i)  { 
	    $word=~s/es$//i; 
	}

	# -ses
	elsif ($word=~/ses$/i)  { 
	    #??if ($word=~/sses$/i && $xlist1=~/\b($word)ses\b/i) { $word=~s/ses$//i; }
	    if ($xlist1=~/\b$word\b/i) { $word=~s/es$/is/i; }
	    else { $word=~s/es$//i; }
	}

	# -ves
	elsif ($word=~/ves$/i) { 
	    if ($word=~/[^n]nives$/i || $word=~/wives$/i) { $word=~s/ves$/fe/i; }
	    elsif ($word=~/shelves$/i || $word=~/[^dw]elves$/i || $word=~/[ch]alves$/i || 
                   $xlist1=~/\b$word\b/i || $word=~/wolves$/i)
                { $word=~s/ves$/f/i; } 
	    else { $word=~s/s$//i; }
	}

	# -xes, -yes, -zes
	elsif ($word=~/[xyz]es$/i)  { 
	    if ($xlist2=~/\b$word\b/i) { $word=~s/es$//i; }
	    elsif ($word=~/izes$/i || $word=~/eezes/i || $xlist1=~/\b$word\b/i || $word=~/[ao]zes/i) 
		{ $word=~s/s$//i; }
	    elsif ($word=~/zzes$/i) { $word=~s/zes$//i; }
	    else { $word=~s/es$//i; }
	}

	# catch-all for es
	elsif ($word=~/.[^aeo]es$/i)  { $word=~s/es$/e/i; }

	#--------------------------
	# everything else
	#--------------------------
	elsif ($word!~/itis$/i && $word=~/.[^su]s$/i)  { $word=~s/s$//i; }

	return $word;

    } # end-else: all words ending in s

} # endsub Simpler



#-----------------------------------------------------------
# initialization to run for Porter stemmer
#   - Martin Porter, 1980, 
#-----------------------------------------------------------
(%P_step2list,%P_step3list,$P_C,$P_v,$P_mgr0,$P_meq1,$P_mgr1,$P_mv)=();

sub initPorter {
   my ($P_c,$P_V);

   %P_step2list =
   ( 'ational'=>'ate', 'tional'=>'tion', 'enci'=>'ence', 'anci'=>'ance', 'izer'=>'ize', 'bli'=>'ble',
     'alli'=>'al', 'entli'=>'ent', 'eli'=>'e', 'ousli'=>'ous', 'ization'=>'ize', 'ation'=>'ate',
     'ator'=>'ate', 'alism'=>'al', 'iveness'=>'ive', 'fulness'=>'ful', 'ousness'=>'ous', 'aliti'=>'al',
     'iviti'=>'ive', 'biliti'=>'ble', 'logi'=>'log');

   %P_step3list =
   ('icate'=>'ic', 'ative'=>'', 'alize'=>'al', 'iciti'=>'ic', 'ical'=>'ic', 'ful'=>'', 'ness'=>'');

   $P_c =    "[^aeiou]";            # consonant
   $P_v =    "[aeiouy]";            # vowel
   $P_C =    "${P_c}[^aeiouy]*";    # consonant sequence
   $P_V =    "${P_v}[aeiou]*";      # vowel sequence

   $P_mgr0 = "^(${P_C})?${P_V}${P_C}";                 # [C]VC... is m>0
   $P_meq1 = "^(${P_C})?${P_V}${P_C}(${P_V})?" . '$';  # [C]VC[V] is m=1
   $P_mgr1 = "^(${P_C})?${P_V}${P_C}${P_V}${P_C}";     # [C]VCVC... is m>1
   $P_mv   = "^(${P_C})?${P_v}";                       # vowel in stem

} # endsub initPorter


#-----------------------------------------------------------
# apply Porter stemming algorithm to a word
#   - Martin Porter, 1980, 
#     An algorithm for suffix stripping, Program, 14(3), 130-137
#     http://www.tartarus.org/~martin/PorterStemmer
#   - modified by Kiduk Yang, 12/6/2004
#   (NOTE: run initPorter first)
#-----------------------------------------------------------
#  arg1   = word
#  r.v.   = stemmed word
#-----------------------------------------------------------
sub Porter {
    my ($word)= @_;
    my ($stem, $suffix, $firstch);

    if (length($word) < 3) { return $word; } # length at least 3

    # now map initial y to Y so that the patterns never treat it as vowel:
    if ($word =~ /^y/) { 
        $word = ucfirst $word; 
        $firstch= 'y';
    }

    # Step 1a
    if ($word =~ /(ss|i)es$/) { $word=$`.$1; }
    elsif ($word =~ /([^s])s$/) { $word=$`.$1; }

    # Step 1b
    if ($word =~ /eed$/) { if ($` =~ /$P_mgr0/o) { chop($word); } }
    elsif ($word =~ /(ed|ing)$/)
    {  $stem = $`;
       if ($stem =~ /$P_mv/o)
       {  $word = $stem;
          if ($word =~ /(at|bl|iz)$/) { $word .= "e"; }
          elsif ($word =~ /([^aeiouylsz])\1$/) { chop($word); }
          elsif ($word =~ /^${P_C}${P_v}[^aeiouwxy]$/o) { $word .= "e"; }
       }
    }

    # Step 1c
    if ($word =~ /y$/) { $stem = $`; if ($stem =~ /$P_mv/o) { $word = $stem."i"; } }

    # Step 2
    if ($word =~ /(ational|tional|enci|anci|izer|bli|alli|entli|eli|ousli|ization|ation|ator|alism|iveness|fulness|ousness|aliti|iviti|biliti|logi)$/)
    { $stem = $`; $suffix = $1;
      if ($stem =~ /$P_mgr0/o) { $word = $stem . $P_step2list{$suffix}; }
    }

    # Step 3
    if ($word =~ /(icate|ative|alize|iciti|ical|ful|ness)$/)
    { $stem = $`; $suffix = $1;
      if ($stem =~ /$P_mgr0/o) { $word = $stem . $P_step3list{$suffix}; }
    }

    # Step 4
    if ($word =~ /(al|ance|ence|er|ic|able|ible|ant|ement|ment|ent|ou|ism|ate|iti|ous|ive|ize)$/)
    { $stem = $`; if ($stem =~ /$P_mgr1/o) { $word = $stem; } }
    elsif ($word =~ /(s|t)(ion)$/)
    { $stem = $` . $1; if ($stem =~ /$P_mgr1/o) { $word = $stem; } }

    #  Step 5
    if ($word =~ /e$/)
    { $stem = $`;
      if ($stem =~ /$P_mgr1/o or
          ($stem =~ /$P_meq1/o and not $stem =~ /^${P_C}${P_v}[^aeiouwxy]$/o))
         { $word = $stem; }
    }
    if ($word =~ /ll$/ and $word =~ /$P_mgr1/o) { chop($word); }

    # and turn initial Y back to y
    if ($firstch && $firstch eq 'y') { $word = lcfirst $word; }

    return $word;

} # endsub Porter



#-----------------------------------------------------------
# Create a hash of Krovetz word list
#-----------------------------------------------------------
#  arg1   = dictionary subset file for Krovetz stemmer
#            e.g. krovetz.lst
#  arg2   = pointer to a word hash
#            key= dictionary words that ends in ed, ing
#            val= 1
#-----------------------------------------------------------
sub mkKVhash {
    my ($subdict,$wordhp)= @_;
    open(IN,$subdict) || die "can't read $subdict";
    my @terms=<IN>;
    close IN;
    chomp @terms;
    foreach $word(@terms) { $$wordhp{$word}++; }
} # endsub mkKVhash


#-----------------------------------------------------------
# apply modified Krovetz stemming algorithm to a word
#-----------------------------------------------------------
#  arg1   = word
#  arg2   = pointer to dictionary hash
#            key= dictionary words that ends in ed, ing
#            val= 1
#  r.v.   = stemmed word
#-----------------------------------------------------------
sub Krovetz {
    my ($word,$dicthp)= @_;

    my $word2;
    $word2= $word;

    # do not stem if word is in dictionary
    if ($$dicthp{$word}) { return $word; }

    elsif ($word=~/ed$/) {

	# 'ied' to 'y'
	if ($word2=~/ied$/) {
	    $word2=~s/ied$/y/;    
	    if ($$dicthp{$word2}) { return $word2; }
	    else { $word2= $word; }
	}

	# remove 'ed'
        $word2=~s/ed$//;   
	if ($$dicthp{$word2}) { return $word2; }

	# remove a consonant, if double consonant ending
	elsif ($word2=~/([^aieou])\1$/) {
	    my $lt= chop $word2;
	    if ($$dicthp{$word2}) { return $word2; }
	    else { $word2 .= $lt; }
	}

	# 'ed' to 'e'
	$word2 .= "e";
	if ($$dicthp{$word2}) { return $word2; }

	else { 

	    # 'ed' to 'ee'
	    $word2 .= "e";
	    if ($$dicthp{$word2}) { return $word2; }

	    else { 
		# 'ed' to 'eed'
		$word2 .= "d";
		if ($$dicthp{$word2}) { return $word2; }

		else { return $word; }

	    }
	}
    }

    elsif ($word=~/ing$/) {

	# remove 'ing'
        $word2=~s/ing$//;   
	if ($$dicthp{$word2}) { return $word2; }

	# remove a consonant, if double consonant ending
	elsif ($word2=~/([^aieou])\1$/) {
	    my $lt= chop $word2;
	    if ($$dicthp{$word2}) { return $word2; }
	    else { $word2 .= $lt; }
	}

	# 'ing' to 'e'
	$word2 .= "e";
	if ($$dicthp{$word2}) { return $word2; }

	else { 

	    # 'ing' to 'ee'
	    $word2 .= "e";
	    if ($$dicthp{$word2}) { return $word2; }

	    else { return $word; }

	}
    }

    return $word;

} # endsub Krovetz


#-----------------------------------------------------------
# apply combo stemmer
#  1. stem words ending in 's' with modified Simple stemmer
#  2. stem words ending in 'ed' or 'ing' with modified Krovetz stemmer
#-----------------------------------------------------------
#  arg1   = word
#  arg2   = pointer to dictionary hash
#            key= dictionary words that ends in ed, ing
#            val= 1
#  r.v.   = stemmed word
#-----------------------------------------------------------
sub combostem {
    my ($word,$dicthp)= @_;

    if ($word=~/s$/) { return &Simpler($word); }
    elsif ($word=~/(ed|ing)$/) { return &Krovetz($word,$dicthp); }
    else { return $word; }

}

1
