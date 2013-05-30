
use strict;

use Sentry;

no warnings 'recursion';


#------------------------------------------------------------
# make HF hash from HF lexicon file
#  - handle prob. lex weights
#-----------------------------------------------------------
#   arg1 = HF lexicon file
#   arg2 = pointer to HF lexicon hash
#          key: term
#          val: polarity score (p1..p3,n1..n3,m1..m3)
#   arg3 = score boost flag
#            1: map (1, 2, 3) to (1, 2, 4)
#            2: map (1, 2, 3) to (1, 3, 6)
#            3: map (1, 2, 3) to (1, 4, 10)
#   arg4 = no term compression flag (optional: default=compress)
#-----------------------------------------------------------
sub mkHFhh {
    my($inf,$lexhp,$emf,$nocmf)=@_;
    my $debug=0;

    my %em1= (1=>1, 2=>2, 3=>4);
    my %em2= (1=>1, 2=>3, 3=>6);
    my %em3= (1=>1, 2=>4, 3=>10);
    my %em;
    if ($emf && $emf==1) { %em=%em1; }
    elsif ($emf && $emf==2) { %em=%em2; }
    elsif ($emf && $emf==3) { %em=%em3; }

    open(IN,$inf) || die "can't read $inf";
    my @lines=<IN>;
    close IN;
    chomp @lines;

    foreach (@lines) {
        my($str,$scM,$scC,$scP)=split/:/;
        if ($emf) {
            foreach my $sc($scM,$scC,$scP) {
                my($pol,$sc2)=split//,$sc,2;
                $sc2 *= $em{3}; 
                $sc= $pol.$sc2;
            }
        }
        $str=~tr/A-Z/a-z/;  # conver to lowercase
        if ($str=~/,/) {
            my @wds=split/,/,$str;
            foreach my $wd(@wds) {
                $lexhp->{$wd}{'man'}=$scM; 
                $lexhp->{$wd}{'combo'}=$scC; 
                $lexhp->{$wd}{'prob'}=$scP; 
                if ($wd=~/-/) {
                    $wd=~s/-//g;
                    $lexhp->{$wd}{'man'}=$scM; 
                    $lexhp->{$wd}{'combo'}=$scC; 
                    $lexhp->{$wd}{'prob'}=$scP; 
                }
            }
        }
        elsif ($str=~s/\(v\)//) {
            my($past,$ing,$now3);
            if ($str=~/^(.+?)e$/) {
                $ing=$1."ing"; 
                $past=$str."d"; 
            }
            else {
                $ing=$str."ing"; 
                $past=$str."ed"; 
            }
            # third person singular
            if ($str=~/(s|ch)$/) { $now3=$str."es";  }
            elsif ($str=~/^(.+[^aieou])y$/) { $now3=$1."ies";  }
            else { $now3=$str."s"; }
            $lexhp->{$str}{'man'}=$scM; 
            $lexhp->{$past}{'man'}=$scM;
            $lexhp->{$ing}{'man'}=$scM;
            $lexhp->{$now3}{'man'}=$scM;
            $lexhp->{$str}{'combo'}=$scC; 
            $lexhp->{$past}{'combo'}=$scC;
            $lexhp->{$ing}{'combo'}=$scC;
            $lexhp->{$now3}{'combo'}=$scC;
            $lexhp->{$str}{'prob'}=$scP; 
            $lexhp->{$past}{'prob'}=$scP;
            $lexhp->{$ing}{'prob'}=$scP;
            $lexhp->{$now3}{'prob'}=$scP;
        }
        elsif ($str=~s/\(n\)//) {
            $lexhp->{$str}{'man'}=$scM;
            $lexhp->{$str}{'combo'}=$scC; 
            $lexhp->{$str}{'prob'}=$scP; 
            # plural
            if ($str=~/s$/) { $str .= "es";  }
            elsif ($str=~/^(.+[^aieou])y$/) { $str=$1."ies";  }
            else { $str .= "s"; }
            $lexhp->{$str}{'man'}=$scM;
            $lexhp->{$str}{'combo'}=$scC; 
            $lexhp->{$str}{'prob'}=$scP; 
        }
        else {
            $lexhp->{$str}{'man'}=$scM;
            $lexhp->{$str}{'combo'}=$scC; 
            $lexhp->{$str}{'prob'}=$scP; 
            # compress hyphens
            if ($str=~/-/) {
                $str=~s/-//g;
                $lexhp->{$str}{'man'}=$scM;
                $lexhp->{$str}{'combo'}=$scC; 
                $lexhp->{$str}{'prob'}=$scP; 
            }
        }
    }

    # compress embedded repeat characters
    #  - exception: e, o
    if (!$nocmf) {
        foreach my $wd(keys %{$lexhp}) {
            my $scM=$lexhp->{$wd}{'man'};
            my $scC=$lexhp->{$wd}{'combo'};
            my $scP=$lexhp->{$wd}{'prob'};
            print "mkHFhash: $wd=$scM\n" if ($debug);
            if ($wd=~/([a-cdf-np-z])\1+\B/) {
                $wd=~s/([a-cdf-np-z])\1+\B/$1/g;
                $lexhp->{$wd}{'man'}=$scM;
                $lexhp->{$wd}{'combo'}=$scC; 
                $lexhp->{$wd}{'prob'}=$scP; 
                print "    wd2=$wd\n" if ($debug);
            }
        }
    }

} #endsub mkHFhh


#------------------------------------------------------------
# make IU hash from lexicon file
#-----------------------------------------------------------
#   arg1 = lexicon file
#   arg2 = pointer to IU lexicon hash
#          key: I, me
#          val: pointer to term-polarity hash (k=term, v=polarity score)
#   arg3 = optional flag to keep the original IU values in hash key 
#          e.g., key: I, my, I'm, me
#   arg4 = optional score boost flag
#            1: map (1, 2, 3) to (1, 2, 4)
#            2: map (1, 2, 3) to (1, 3, 6)
#            3: map (1, 2, 3) to (1, 4, 10)
#   arg5 = no term compression flag (optional: default=compress)
#-----------------------------------------------------------
sub mkIUhh {
    my($inf,$lexhp,$flag,$emf,$nocmf)=@_;
    my $debug=0;

    my %em1= (1=>1, 2=>2, 3=>4);
    my %em2= (1=>1, 2=>3, 3=>6);
    my %em3= (1=>1, 2=>4, 3=>10);
    my %em;
    if ($emf && $emf==1) { %em=%em1; }
    elsif ($emf && $emf==2) { %em=%em2; }
    elsif ($emf && $emf==3) { %em=%em3; }

    open(IN,$inf) || die "can't read $inf";
    my @lines=<IN>;
    close IN;
    chomp @lines;

    foreach (@lines) {
        my($iu,$scM,$scC,$scP)=split/:/;
        if ($emf) {
            foreach my $sc($scM,$scC,$scP) {
                my($pol,$sc2)=split//,$sc,2;
                $sc2 *= $em{3}; 
                $sc= $pol.$sc2;
            }
        }
        $iu=~tr/A-Z/a-z/;   # convert to lowercase
        if ($iu=~/^I (.+)$/i) {
            my $term=$1;
            if ($term=~/,/) {
                my($now,$past,$ing)=split/,/,$term;
                $lexhp->{'I'}{$now}{'man'}=$scM; 
                $lexhp->{'I'}{$past}{'man'}=$scM;
                $lexhp->{'I'}{$ing}{'man'}=$scM;
                $lexhp->{'I'}{$now}{'combo'}=$scC; 
                $lexhp->{'I'}{$past}{'combo'}=$scC;
                $lexhp->{'I'}{$ing}{'combo'}=$scM;
                $lexhp->{'I'}{$now}{'prob'}=$scP; 
                $lexhp->{'I'}{$past}{'prob'}=$scP;
                $lexhp->{'I'}{$ing}{'prob'}=$scP;
            }
            else {
                my($past,$ing);
                if ($term=~/^(.+?)e$/) {
                    $ing=$1."ing"; 
                    $past=$term."d"; 
                }
                else {
                    $ing=$term."ing"; 
                    $past=$term."ed"; 
                }
                $lexhp->{'I'}{$term}{'man'}=$scM; 
                $lexhp->{'I'}{$past}{'man'}=$scM;
                $lexhp->{'I'}{$ing}{'man'}=$scM;
                $lexhp->{'I'}{$term}{'combo'}=$scC; 
                $lexhp->{'I'}{$past}{'combo'}=$scC;
                $lexhp->{'I'}{$ing}{'combo'}=$scM;
                $lexhp->{'I'}{$term}{'prob'}=$scP; 
                $lexhp->{'I'}{$past}{'prob'}=$scP;
                $lexhp->{'I'}{$ing}{'prob'}=$scP;
            }
        }
        elsif ($iu=~/^I'm ([^ ]+)/i) {
            my $key;
            if ($flag) { $key="I'm"; }
            else { $key="I"; }
            $lexhp->{$key}{$1}{'man'}=$scM; 
            $lexhp->{$key}{$1}{'combo'}=$scC; 
            $lexhp->{$key}{$1}{'prob'}=$scP; 
        }
        elsif ($iu=~/^my (.+)$/i) {
            my $term=$1;
            # plural
            my $terms;
            if ($term=~/s$/) { $terms=$term."es";  }
            elsif ($term=~/^(.+[^aieou])y$/) { $terms=$1."ies";  }
            else { $terms=$1."s"; }
            $lexhp->{'my'}{$term}{'man'}=$scM; 
            $lexhp->{'my'}{$terms}{'man'}=$scM; 
            $lexhp->{'my'}{$term}{'combo'}=$scC; 
            $lexhp->{'my'}{$terms}{'combo'}=$scC; 
            $lexhp->{'my'}{$term}{'prob'}=$scP; 
            $lexhp->{'my'}{$terms}{'prob'}=$scP; 
        }
        elsif ($iu=~/^(.+) me$/i) {
            my $term=$1;
            if ($term=~/^(.+?) for$/) {
                $lexhp->{'me'}{$1}{'man'}=$scM; 
                $lexhp->{'me'}{$1}{'combo'}=$scC; 
                $lexhp->{'me'}{$1}{'prob'}=$scP; 
            }
            else {
                $term=~s/ ([a-z]+)$//;
                if ($term=~/,/) {
                    my($now,$past,$ing)=split/,/,$term;
                    # third person singular
                    my $now3;
                    if ($now=~/(s|ch)$/) { $now3=$now."es";  }
                    elsif ($now=~/^(.+[^aieou])y$/) { $now3=$1."ies";  }
                    else { $now3=$now."s"; }
                    $lexhp->{'me'}{$now}{'man'}=$scM; 
                    $lexhp->{'me'}{$now3}{'man'}=$scM; 
                    $lexhp->{'me'}{$past}{'man'}=$scM;
                    $lexhp->{'me'}{$ing}{'man'}=$scM;
                    $lexhp->{'me'}{$now}{'combo'}=$scC; 
                    $lexhp->{'me'}{$now3}{'combo'}=$scC; 
                    $lexhp->{'me'}{$past}{'combo'}=$scC;
                    $lexhp->{'me'}{$ing}{'combo'}=$scM;
                    $lexhp->{'me'}{$now}{'prob'}=$scP; 
                    $lexhp->{'me'}{$now3}{'prob'}=$scP; 
                    $lexhp->{'me'}{$past}{'prob'}=$scP;
                    $lexhp->{'me'}{$ing}{'prob'}=$scP;
                }
                else {
                    # third person singular
                    my $now3;
                    if ($term=~/(s|ch)$/) { $now3=$term."es";  }
                    elsif ($term=~/^(.+[^aieou])y$/) { $now3=$1."ies";  }
                    else { $now3=$term."s"; }
                    my($past,$ing);
                    if ($term=~/^(.+?)e$/) {
                        $ing=$1."ing"; 
                        $past=$term."d"; 
                    }
                    else {
                        $ing=$term."ing"; 
                        $past=$term."ed"; 
                    }
                    $lexhp->{'me'}{$term}{'man'}=$scM; 
                    $lexhp->{'me'}{$now3}{'man'}=$scM; 
                    $lexhp->{'me'}{$past}{'man'}=$scM;
                    $lexhp->{'me'}{$ing}{'man'}=$scM;
                    $lexhp->{'me'}{$term}{'combo'}=$scC; 
                    $lexhp->{'me'}{$now3}{'combo'}=$scC; 
                    $lexhp->{'me'}{$past}{'combo'}=$scC;
                    $lexhp->{'me'}{$ing}{'combo'}=$scM;
                    $lexhp->{'me'}{$term}{'prob'}=$scP; 
                    $lexhp->{'me'}{$now3}{'prob'}=$scP; 
                    $lexhp->{'me'}{$past}{'prob'}=$scP;
                    $lexhp->{'me'}{$ing}{'prob'}=$scP;
                }
            }
        }
    }

    # compress embedded repeat characters
    #  - exception: e, o
    if (!$nocmf) {
        foreach my $iu(keys %{$lexhp}) {
            foreach my $wd(keys %{$lexhp->{$iu}}) {
                my $scM=$lexhp->{$iu}{$wd}{'man'};
                my $scC=$lexhp->{$iu}{$wd}{'combo'};
                my $scP=$lexhp->{$iu}{$wd}{'prob'};
                print "mkIUhash: iu=$iu, $wd=$scM\n" if ($debug);
                if ($wd=~/([a-cdf-np-z])\1+\B/) {
                    $wd=~s/([a-cdf-np-z])\1+\B/$1/g;
                    $lexhp->{$iu}{$wd}{'man'}=$scM; 
                    $lexhp->{$iu}{$wd}{'combo'}=$scC; 
                    $lexhp->{$iu}{$wd}{'prob'}=$scP; 
                    print "    wd2=$wd\n" if ($debug);
                }
            }
        }
    }

} #endsub mkIUhh


#------------------------------------------------------------
# make LF hash from regex file
#-----------------------------------------------------------
#   arg1 = LF regex file
#   arg2 = pointer to LF regex hash
#   arg3 = pointer to LF regex array (optional)
#   arg4 = pointer to LF regex score array (optional)
#          key: regex
#          val: polarity score (p1..p3,n1..n3,m1..m3)
#   arg5 = score boost flag
#            1: map (1, 2, 3) to (1, 2, 4)
#            2: map (1, 2, 3) to (1, 3, 6)
#            3: map (1, 2, 3) to (1, 4, 10)
#-----------------------------------------------------------
sub mkLFhh1 {
    my($inf,$rgxhp,$rgxlp,$scMlp,$scClp,$scPlp,$emf)=@_;
    my $debug=0;

    my %em1= (1=>1, 2=>2, 3=>4);
    my %em2= (1=>1, 2=>3, 3=>6);
    my %em3= (1=>1, 2=>4, 3=>10);
    my %em;
    if ($emf && $emf==1) { %em=%em1; }
    elsif ($emf && $emf==2) { %em=%em2; }
    elsif ($emf && $emf==3) { %em=%em3; }

    open(IN,$inf) || die "can't read $inf";
    my @lines=<IN>;
    close IN;
    chomp @lines;

    foreach (@lines) {
        my($rgx,$scM,$scC,$scP)=split/ +/;
        if ($emf) {
            foreach my $sc($scM,$scC,$scP) {
                my($pol,$sc2)=split//,$sc,2;
                $sc2 *= $em{3}; 
                $sc= $pol.$sc2;
            }
        }
        $rgxhp->{"$rgx"}{'man'}=$scM;
        $rgxhp->{"$rgx"}{'combo'}=$scC;
        $rgxhp->{"$rgx"}{'prob'}=$scP;
    }

    # create an array of regex & corresponding array of scores
    # by character sort of rgx by descending score
    #  - order = polarity (p, n, m), then polarity strength (3, 2, 1) 
    #    (to ensure strongest match, stop after first hit)
    if ($rgxlp) {
        foreach my $rgx(sort {$rgxhp->{$b}{'man'} cmp $rgxhp->{$a}{'man'}} keys %{$rgxhp}) {
            push(@{$rgxlp},$rgx);
            push(@{$scMlp},$rgxhp->{$rgx}{'man'});
            push(@{$scClp},$rgxhp->{$rgx}{'combo'});
            push(@{$scPlp},$rgxhp->{$rgx}{'prob'});
        }
    }

} #endsub mkLFhh


#------------------------------------------------------------
# make LF hash from LF lexicon file
#-----------------------------------------------------------
#   arg1 = LF lexicon file
#   arg2 = pointer to LF lexicon hash
#          key: LF term
#          val: polarity score (p1..p3,n1..n3,m1..m3)
#   arg3 = score boost flag
#            1: map (1, 2, 3) to (1, 2, 4)
#            2: map (1, 2, 3) to (1, 3, 6)
#            3: map (1, 2, 3) to (1, 4, 10)
#-----------------------------------------------------------
sub mkLFhh2 {
    my($inf,$lexhp,$emf)=@_;
    my $debug=0;

    my %em1= (1=>1, 2=>2, 3=>4);
    my %em2= (1=>1, 2=>3, 3=>6);
    my %em3= (1=>1, 2=>4, 3=>10);
    my %em;
    if ($emf && $emf==1) { %em=%em1; }
    elsif ($emf && $emf==2) { %em=%em2; }
    elsif ($emf && $emf==3) { %em=%em3; }

    open(IN,$inf) || die "can't read $inf";
    my @lines=<IN>;
    close IN;
    chomp @lines;

    foreach (@lines) {
        my($wd,$scM,$scC,$scP)=split/:/;
        if ($emf) {
            foreach my $sc($scM,$scC,$scP) {
                my($pol,$sc2)=split//,$sc,2;
                $sc2 *= $em{3}; 
                $sc= $pol.$sc2;
            }
        }
        $lexhp->{"\L$wd"}{'man'}=$scM;
        $lexhp->{"\L$wd"}{'combo'}=$scC;
        $lexhp->{"\L$wd"}{'prob'}=$scP;
    }

} #endsub mkLFhash2


#------------------------------------------------------------
# make AC hash from acronym file
#-----------------------------------------------------------
#   arg1 = acronym file
#   arg2 = pointer to AC hash
#          key: acronyms, expanded phrase
#          val: polarity score (p1..p3,n1..n3,m1..m3)
#-----------------------------------------------------------
sub mkAChh {
    my($inf,$lexhp)=@_;

    open(IN,$inf) || die "can't read $inf";
    my @lines=<IN>;
    close IN;
    chomp @lines;

    foreach (@lines) {
        my($str,$scM,$scC,$scP)=split/:/;
        $str=~tr/A-Z/a-z/;  # convert to lowercase
        $str=~/^(.+?)\((.+)\)$/;
        my($wd,$ph)=($1,$2);
        $lexhp->{"$wd"}{'man'}=$scM;
        $lexhp->{"$ph"}{'man'}=$scM;
        $lexhp->{"$wd"}{'combo'}=$scC;
        $lexhp->{"$ph"}{'combo'}=$scC;
        $lexhp->{"$wd"}{'prob'}=$scP;
        $lexhp->{"$ph"}{'prob'}=$scP;
    }

} #endsub mkAChh


#-----------------------------------------------------------
# create lexicon hash from Wilson's subjective terms
#-----------------------------------------------------------
#   arg1 = input file
#   arg2 = pointer to lexicon hash
#            k = term  (lowercase) 
#            v = score ($polarity$strength)
#   arg3 = score boost flag (optional)
#            1: map (1, 2, 3) to (1, 2, 4)
#            2: map (1, 2, 3) to (1, 3, 6)
#            3: map (1, 2, 3) to (1, 4, 10)
#   arg4 = no term compression flag (optional: default=compress)
#   arg5 = score (optional: e.g. m1)
#            for term list without scores
#-----------------------------------------------------------
sub mkWhh {
    my($in,$lexhp,$emf,$nocmf)=@_;

    my %em1= (1=>1, 2=>2, 3=>4);
    my %em2= (1=>1, 2=>3, 3=>6);
    my %em3= (1=>1, 2=>4, 3=>10);
    my %em;
    if ($emf && $emf==1) { %em=%em1; }
    elsif ($emf && $emf==2) { %em=%em2; }
    elsif ($emf && $emf==3) { %em=%em3; }

    open(IN,$in) || die "can't read $in";
    while(<IN>) {
        chomp;
        my($term,$scM,$scC,$scP)=split/:/;
        if ($emf) {
            foreach my $sc($scM,$scC,$scP) {
                my($pol,$sc2)=split//,$sc,2;
                $sc2 *= $em{3}; 
                $sc= $pol.$sc2;
            }
        }
        $lexhp->{"\L$term"}{'man'}=$scM;
        $lexhp->{"\L$term"}{'combo'}=$scC;
        $lexhp->{"\L$term"}{'prob'}=$scP;
    }            
    close IN;
        
    # add compressed terms
    &updatelex2($lexhp) if (!$nocmf); 
        
} #endsub mkWhh      



#------------------------------------------------------------
# preprocess blog text for opinion scoring
#   1. replace negation words w/ placeholder
#   2. make spell-correction (e.g. repeated characters)
#-----------------------------------------------------------
#   arg2 = text to process
#   arg4 = negation placeholder    (e.g., MM--negstr--MM)
#   r.v. = (processed text)
#-----------------------------------------------------------
sub preptext0 {
    my($text,$NOT)=@_;
    my $debug=0;

    $text=~s/<.+?>/ /gs;
    $text=~s/\s+/ /gs;

    print "PrepText0: T1=$text\n" if ($debug);

    # expand contractions
    $text=~s/I'm\b/I am/gi;
    $text=~s/\b(he|she|that|it)'s\b/$1 is/gi;
    $text=~s/'re\b/ are/gi;
    $text=~s/'ve\b/ have/gi;
    $text=~s/'ll\b/ will/gi;

    # replace negations
    $text=~s/\b(cannot|can not|can't|could not|couldn't|will not|won't|would not|wouldn't|shall not|shan't|should not|shouldn't|must not|mustn't|does not|doesn't|do not|don't|did not|didn't|may not|might not|is not|isn't|am not|was not|wasn't|are not|aren't|were not|weren't|have not|haven't|had not|hadn't|need not|needn't)\b/ $NOT /gi;
    $text=~s/\b(hardly|hardly ever|never|barely|scarcely)\s+(can|could|will|would|shall|should|must|does|do|did|may|might|is|am|was|are|were|have to|had to|have|had|need)\b/ $NOT /gi;
    $text=~s/\b(can|could|will|would|shall|should|must|does|do|did|may|might|is|am|was|are|were|have to|had to|have|had|need)\s+(hardly|hardly ever|never|barely|scarcely|no)\b/ $NOT /gi;

    # compress embedded triple repeat chars to double chars
    foreach my $c('b','c','d','e','f','g','l','n','o','p','r','s','t','z') {
        $text=~s/\B$c$c$c\B/$c$c/ig;
    }

    print "PrepText0: T2=$text\n" if ($debug);

    return($text);

} #endsub preptext0


#------------------------------------------------------------
# compute opinion polarity score 
#   - no proximity match scores
#-----------------------------------------------------------
#   arg1 = polarity (p,n)
#   arg2 = polarity score
#   arg3 = preceding word
#   arg4 = pre-preceding word
#   arg5 = pre-pre-preceding word
#   arg6 = pointer to negation hash
#          key: term, val: 1
#   arg7 = negation flag
#   r.v. = (Psc, Nsc)
#-----------------------------------------------------------
sub polSC0 {
    my($pol,$sc,$pwd,$ppwd,$pppwd,$neghp,$negflag)=@_;
    my $debug=0;

    my($p2,$n2)=(0,0);

    # preceding word is a negation: e.g. 'not good', 'not so good', 'isn't really very good'
    if ( ($pwd && $neghp->{$pwd}) || ($ppwd && $neghp->{$ppwd}) || ($pppwd && $neghp->{$pppwd}) || $negflag ) {
        if ($pol eq 'n') { 
            $p2 = $sc; 
        }
        elsif ($pol eq 'p') { 
            $n2 = $sc; 
        }
    }
    else {
        if ($pol eq 'p') { 
            $p2 = $sc; 
        }
        elsif ($pol eq 'n') { 
            $n2 = $sc; 
        }
    }

    print "polSC: pol=$pol, sc=$sc, p2=$p2, n2=$n2\n" if ($debug);

    return ($p2,$n2);

} #endsub polSC0


#------------------------------------------------------------
# compute opinion polarity score
#-----------------------------------------------------------
#   arg1 = polarity (p,n)
#   arg2 = polarity score
#   arg3 = preceding word
#   arg4 = pre-preceding word
#   arg5 = pre-pre-preceding word
#   arg6 = pointer to negation hash
#          key: term 
#          val: 1
#   arg7 = proximity match flag
#   arg8 = negation flag
#   r.v. = (prox_Psc, Psc, prox_Nsc, Nsc)
#-----------------------------------------------------------
sub polSC {
    my($pol,$sc,$pwd,$ppwd,$pppwd,$neghp,$proxM,$negflag)=@_;
    my $debug=0;

    my($p1,$p2,$n1,$n2)=(0,0,0,0);

    # preceding word is a negation: e.g. 'not good', 'not so good', 'isn't really very good'
    if ( ($pwd && $neghp->{$pwd}) || ($ppwd && $neghp->{$ppwd}) || ($pppwd && $neghp->{$pppwd}) || $negflag ) {
        if ($pol eq 'n') { 
            $p2 = $sc; 
            $p1 = $sc if ($proxM);
        }
        elsif ($pol eq 'p') { 
            $n2 = $sc; 
            $n1 = $sc if ($proxM);
        }
    }
    else {
        if ($pol eq 'p') { 
            $p2 = $sc; 
            $p1 = $sc if ($proxM);
        }
        elsif ($pol eq 'n') { 
            $n2 = $sc; 
            $n1 = $sc if ($proxM);
        }
    }

    print "polSC: pol=$pol, prx=$proxM, sc=$sc, p1=$p1, p2=$p2, n1=$n1, n2=$n2\n" if ($debug);

    return ($p1,$p2,$n1,$n2);

} #endsub polSC


#------------------------------------------------------------
# add repeat-char compressed terms to lexicon hash
#-----------------------------------------------------------
# arg1 = pointer to lexicon hash
#          key: term, val: [pnm]N
#-----------------------------------------------------------
sub updatelex {
    my($lexhp)=@_;
    my $debug=0;

    # add to lexicon terms w/ compress embedded repeat characters
    #  - exception: e, o
    foreach my $wd(keys %{$lexhp}) {
        my $sc=$lexhp->{$wd};
        print "UpLex: $wd=$sc\n" if ($debug);
        if ($wd=~/([a-cdf-np-z])\1+\B/) {
            $wd=~s/([a-cdf-np-z])\1+\B/$1/g;
            $lexhp->{$wd}=$sc; 
            print "    $wd\n" if ($debug);
        }
    }

} #endsub updatelex

sub updatelex2 {
    my($lexhp)=@_;
    my $debug=0;

    # add to lexicon terms w/ compress embedded repeat characters
    #  - exception: e, o
    foreach my $wd(keys %{$lexhp}) {
        my $scM=$lexhp->{$wd}{'man'};
        my $scC=$lexhp->{$wd}{'combo'};
        my $scP=$lexhp->{$wd}{'prob'};
        print "UpLex: $wd=$scM\n" if ($debug);
        if ($wd=~/([a-cdf-np-z])\1+\B/) {
            $wd=~s/([a-cdf-np-z])\1+\B/$1/g;
            $lexhp->{$wd}{'man'}=$scM; 
            $lexhp->{$wd}{'combo'}=$scC; 
            $lexhp->{$wd}{'prob'}=$scP; 
            print "    $wd\n" if ($debug);
        }
    }

} #endsub updatelex



#------------------------------------------------------------
# compute reranking scores
#   - use length-normalized match count
#------------------------------------------------------------
## multiple weights per term: manual, combo, probabilistic
## changes from calrrSCall7, 11/16/2008
#  - prxwsize & maxwdist increased from 10, 20 to 30, 60
#  - caltpSCall4: added $schp->{$qn}{'qtixm'} 
#                  2 if exact n-gram title string found in body
#                  1 if exact unigram title string found in body
#                  0 otherwise
#  - calopScall8: added 'nothing' to %negwds
#                 fixed prox. match bug (@wdsM & @wds not lined up due to preprocessing)
#-----------------------------------------------------------
# arg1 = document title text
# arg2 = document body text
# arg3 = pointer to query title hash
#          k= QN, v=title
# arg4 = pointer to query title text (stopped & stemmed)
#          k= QN, v=title2
# arg5 = pointer to query description text (stopped & stemmed)
#          k= QN, v=desc2
# arg6 = pointer to noun phrase hash
#          k1= QN, v= hash pointer
#              k2= phrase, v2= freq
# arg7 = pointer to noun phrase hash from web-expanded query
#          k1= QN, v= hash pointer
#              k2= phrase, v2= weight
# arg8 = pointer to nonrel phrase hash
#          k1= QN, v= hash pointer
#              k2= nonrel-phrase, v2= freq
# arg9 = pointer to nonrel noun hash
#          k1= QN, v= hash pointer
#              k2= nonrel-noun, v2= freq
# arg10 = pointer to reranking score hash
#          k1= QN (NOTE: 0= query independent scores)
#          v1= hash pointer
#              k2= score name
#              v2= score
#                  onTopic key values:
#                     ti   - exact match of query title in doc title
#                     bd   - exact match of query title in doc body
#                     tix  - proximity match of query title in doc title
#                     bdx  - proximity match of query title in doc body
#                     bdx2 - proximity match of query description in doc body
#                     ph   - query phrase match in doc title + body
#                     ph2  - expanded query phrase match in doc title + body
#                     nrph - query non-relevant phrase match in doc title + body
#                     nrn  - query non-relevant noun match in doc title + body
#                  opinion key values (QN=0):  iu[NP],hf[NP],lf[NP],w1[NP],w2[NP],e[NP]
#                  opinion key values (QN!=0): iux[NP],hfx[NP],lfx[NP],w1x[NP],w2x[NP],ex[NP]
#                  opinion key values (QN!=0): iud[NP],hfd[NP],lfd[NP],w1d[NP],w2d[NP],ed[NP]
#                  e.g iu   - IU simple match score
#                      iuP  - IU simple positive poloarity match score
#                      iuN  - IU simple negative poloarity match score
#                      iux  - IU proximity match score
#                      iuxP - IU proximity positive polarity match score
#                      iuxN - IU proximity negative polarity match score
#                      iud  - IU idist match score
#                      iudP - IU idist positive polarity match score
#                      iudN - IU idist negative polarity match score
#                  misc. key values:
#                      tl   - text length in word count
#                      in1  - number of I, my, me
#                      in2 - number of you, we, your, our, us
# arg10 = pointer to AC hash
# arg11 = pointer to HF hash
# arg12 = pointer to IU hash
# arg13 = pointer to LF hash
# arg14 = pointer to LF regex array
# arg15 = pointer to LF regex score array
# arg16 = pointer to LF morph regex array
# arg17 = pointer to LF morph regex score array
# arg18 = pointer to Wilson's strong subj hash
# arg19 = pointer to Wilson's weak subj hash
# arg20 = pointer to Wilson's emphasis  hash
# arg21 = optional maxwdcnt
# arg22 = optional no term morphing flag
#-----------------------------------------------------------
# NOTE:
#   1. bdx2, ph, nrph, nrn scores should not be used for short query results
#-----------------------------------------------------------
sub calrrSCall8 {
    my($ti,$bd,$qtihp,$qti2hp,$qti3hp,$qdesc2hp,$phhp,$ph2hp,$nrphhp,$nrnhp,$schp,$achp,$hfhp,$iuhp,$lfhp,
       $lfxlp,$lfxsclpM,$lfxsclpC,$lfxsclpP,$lfmlp,$lfmsclpM,$lfmsclpC,$lfmsclpP,
       $w1hp,$w2hp,$emphp,$pavhp,$navhp,$maxwdcnt2,$nomrpf)=@_;
    my $debug=0;

    my $QTM='MM--qxmatch--MM',   # query string match placeholder
    my $QTM2='MM--qxmatch2--MM', # query word match placeholder
    my $NOT='MM--negstr--MM';    # negation placeholder
    my $prxwsize=30;             # proximity match window
    my $maxwdist=60;             # max. word distance for idist score

    my $minwdcnt=10;             # min. doclen (wdcnt) for processing
    my $maxwdcnt=5000;           # max. number of words to process

    $maxwdcnt=$maxwdcnt2 if ($maxwdcnt2);

    #chomp($bd);

    # do not compute reranking scores for short documents (less than 10 word)
    my @wdcnt= $bd=~/\s+/g;
    return if (@wdcnt+1<=$minwdcnt);

    # truncate long documents to 5000 words
    if (@wdcnt>$maxwdcnt) {
        my @wds;
        @wds[0..$maxwdcnt-1]=split/ +/,$bd;
        $bd= join(" ",@wds);
    }

    my $text= "$ti $bd";

    #-----------------------------------------------------
    # 1. compute topic scores
    #  - NOTE: length-normalized
    # 2. return text tagged with exact query match
    #  - e.g. 'token1 token2$QTM$qn token3 token4$QTM$qn'
    #-----------------------------------------------------
    my ($qtxmN,$qtxmN2,$textM)=&caltpSCall4($ti,$bd,$text,$QTM,$QTM2,$qtihp,$qti2hp,$qti3hp,$qdesc2hp,$phhp,$ph2hp,$nrphhp,$nrnhp,$schp);

    #-----------------------------------------------------
    # compute opinion scores
    #  - NOTE: NOT length-normalized (i.e., match count)
    #-----------------------------------------------------
    $textM=&preptext0($textM,$NOT);

    if ($qtxmN) {
        &calopSCall8($textM,$QTM,$QTM2,$NOT,$maxwdist,$qtihp,$prxwsize,$schp,$achp,$hfhp,$iuhp,$lfhp,
                    $lfxlp,$lfxsclpM,$lfxsclpC,$lfxsclpP,$lfmlp,$lfmsclpM,$lfmsclpC,$lfmsclpP,
                    $w1hp,$w2hp,$emphp,$pavhp,$navhp,$nomrpf);
    }

    return ($qtxmN,$textM);

} #endsub calrrSCall8


sub calrrSCall9 {
    my($ti,$bd,$qtihp,$qti2hp,$qti3hp,$qdesc2hp,$phhp,$ph2hp,$nrphhp,$nrnhp,$schp,$achp,$hfhp,$iuhp,$lfhp,
       $lfxlp,$lfxsclpM,$lfxsclpC,$lfxsclpP,$lfmlp,$lfmsclpM,$lfmsclpC,$lfmsclpP,
       $w1hp,$w2hp,$emphp,$pavhp,$navhp,$maxwdcnt2,$nomrpf,$stophp)=@_;
    my $debug=0;

    my $QTM='MM--qxmatch--MM',   # query string match placeholder
    my $QTM2='MM--qxmatch2--MM', # query word match placeholder
    my $NOT='MM--negstr--MM';    # negation placeholder
    my $prxwsize=30;             # proximity match window
    my $maxwdist=60;             # max. word distance for idist score

    my $minwdcnt=10;             # min. doclen (wdcnt) for processing
    my $maxwdcnt=5000;           # max. number of words to process

    $maxwdcnt=$maxwdcnt2 if ($maxwdcnt2);

    #chomp($bd);

    # do not compute reranking scores for short documents (less than 10 word)
    my @wdcnt= $bd=~/\s+/g;
    return if (@wdcnt+1<=$minwdcnt);

    # truncate long documents to 5000 words
    if (@wdcnt>$maxwdcnt) {
        my @wds;
        @wds[0..$maxwdcnt-1]=split/ +/,$bd;
        $bd= join(" ",@wds);
    }

    my $text= "$ti $bd";

    #-----------------------------------------------------
    # 1. compute topic scores
    #  - NOTE: length-normalized
    # 2. return text tagged with exact query match
    #  - e.g. 'token1 token2$QTM$qn token3 token4$QTM$qn'
    #-----------------------------------------------------
    my ($qtxmN,$qtxmN2,$textM)=&caltpSCall5($ti,$bd,$text,$QTM,$QTM2,$qtihp,$qti2hp,$qti3hp,$qdesc2hp,$phhp,$ph2hp,$nrphhp,$nrnhp,$schp,$stophp);

    #-----------------------------------------------------
    # compute opinion scores
    #  - NOTE: NOT length-normalized (i.e., match count)
    #-----------------------------------------------------
    $textM=&preptext0($textM,$NOT);

    if ($qtxmN2) {
        &calopSCall8($textM,$QTM,$QTM2,$NOT,$maxwdist,$qtihp,$prxwsize,$schp,$achp,$hfhp,$iuhp,$lfhp,
                    $lfxlp,$lfxsclpM,$lfxsclpC,$lfxsclpP,$lfmlp,$lfmsclpM,$lfmsclpC,$lfmsclpP,
                    $w1hp,$w2hp,$emphp,$pavhp,$navhp,$nomrpf);
    }

    return ($qtxmN,$qtxmN2,$textM);

} #endsub calrrSCall9




#------------------------------------------------------------
# compute topic reranking scores for all queries
#   - use length-normalized match count
# changes from caltpSCall3, 11/16/2008
#  - added $schp->{$qn}{'qtixm'}
#                  2 if exact n-gram title string found in body
#                  1 if exact unigram title string found in body
#                  0 otherwise
#-----------------------------------------------------------
# arg1 = document title text
# arg2 = document body text
# arg3 = pointer to query title text hash
#          k= QN, v= query title
# arg4 = pointer to query title text hash (stopped & stemmed)
#          k= QN, v= query title
# arg5 = pointer to query description text hash (stopped & stemmed)
#          k= QN, v= query title
# arg6 = pointer to noun phrase hash
#          k1= QN, v1= hash pointer
#              k2= phrase, v2= freq
# arg7 = pointer to nonrel phrase hash
#          k1= QN, v1= hash pointer
#              k2= nonrel_phrase, v2= freq
# arg8 = pointer to nonrel noun hash
#          k1= QN, v1= hash pointer
#              k2= nonrel_noun, v2= freq
# arg9 = pointer to reranking score hash
#          k1= QN (NOTE: 0= query independent scores)
#          v1= hash pointer
#              k2= score name, v= score
#              onTopic key values:
#                ti   - exact match of query title in doc title
#                bd   - exact match of query title in doc body
#                tix  - proximity match of query title in doc title
#                bdx  - proximity match of query title in doc body
#                bdx2 - proximity match of query description in doc body
#                ph   - query phrase match in doc title + body
#                nrph - query non-relevant phrase match in doc title + body
#                nrn  - query non-relevant noun match in doc title + body
#              misc. key values: tl
#                tl   - text length in word count
#-----------------------------------------------------------
# NOTE:
#   1. bdx2, ph, nrph, nrn scores should not be used for short query results
#-----------------------------------------------------------
sub caltpSCall4 {
    my($ti,$bd,$text,$QTM,$QTM2,$qtihp,$qti2hp,$qti3hp,$qdesc2hp,$phhp,$ph2hp,$nrphhp,$nrnhp,$schp)=@_;
    my $debug=0;

    my ($ti2,$bd2)=($ti,$bd);  # for marking query matches

    my %len0;
    # get document text lengths
    #  -%len0: k=(ti|bd|text), v=token count
    my %hash=('ti'=>$ti,'bd'=>$bd,'text'=>$text);
    foreach my $name(keys %hash) {
        my $var= $hash{$name};
        print "caltpSCall2: name=$name, var=$var\n" if ($debug);
        if ($var) {
            my @wds= ($var=~/\s+/g);
            $len0{$name}= @wds+1;
        }
        else { $len0{$name}=0; }
    }
    $schp->{0}{'tl'}= $len0{'text'};

    #--------------------------------------
    # compute topic scores for each query
    #--------------------------------------

    my $qtixmCNT=0;  # query title (exact string) match count
    my $qtixmCNT2=0;  # query title (any word) match count

    foreach my $qn(keys %$qtihp) {

        # %qtihp,%qti2hp,%qds2hp: k(QN) = v(text)
        # %phhp,%nrphhp,%nrnhp:   k(QN -> term) = v(freq)
        my ($qti,$qti2,$qdesc2)=($qtihp->{$qn},$qti2hp->{$qn},$qdesc2hp->{$qn});
        my ($php,$ph2p,$nrphp,$nrnp)=($phhp->{$qn},$ph2hp->{$qn},$nrphhp->{$qn},$nrnhp->{$qn});

        # accomodate changes in indexing module (7/20/2007)
        #   - $qti2: words after comma (,) = alternate wordform of special query terms
        # NOTE: should be handled in the calling program (e.g. rerankrt13new.pl)
        #$qti2=$1 if ($qti2=~/^(.+?)\s+,/);

        my %len;
        # get query text lengths
        #  -%len: k=(qti|qt2|qdesc2), v=token count
        my %hash=('qti'=>$qti,'qti2'=>$qti2,'qdesc2'=>$qdesc2);
        foreach my $name(keys %hash) {
            my $var= $hash{$name};
            print "caltpSCall2: name=$name, var=$var\n" if ($debug);
            if ($var) {
                my @wds= ($var=~/\s+/g);
                $len{$name}= @wds+1;
            }
            else { $len{$name}=0; }
        }

        # allow for plurals
        $qti .= 's' if ($qti!~/s$/i);

        # flag if exact query title string occurs in body text
        if ($bd=~/\b$qti?\b/i) { 
            if ($qti=~/ /) { $schp->{$qn}{'qtixm'}=2; }
            else { $schp->{$qn}{'qtixm'}=1; }
            $qtixmCNT++;
            $qtixmCNT2++;
        }
        else { 
            $schp->{$qn}{'qtixm'}=0; 
            if ($qti=~/ /) {
                my @qwds=split(/ +/,$qti);
                foreach my $qwd(@qwds) {
                    next if (length($qwd)==1);
                    if ($bd=~/\b$qwd?\b/i) { 
                        $qtixmCNT2++;
                    }
                }
            }
        }

        #------------------------------
        # compute exact match scores of title string
        #   - proportion of match string
        #------------------------------
        # match in doc title
        if (my @hits= $ti=~/\b$qti?\b/ig) {
            $ti2=~s/\b($qti?($QTM\d+)*)\b/$1$QTM$qn/ig;
            if ($debug) { my$hit=@hits; print "caltpSCall2: tiH=$hit\n"; }
            $schp->{$qn}{'ti'}= ($len{'qti'}*@hits / $len0{'ti'});
        }
        # match in doc body
        #  - compute score only if multiple word query
        ###!! 11/16/08  - !!! consider doing it for single term query as well
        #if ($qti=~/ /) {
            if (my @hits= $bd=~/\b$qti?\b/ig) {
                $bd2=~s/\b($qti?($QTM\d+)*)\b/$1$QTM$qn/ig;
                if ($debug) { my$hit=@hits; print "caltpSCall2: bdH=$hit\n"; }
                $schp->{$qn}{'bd'}= ($len{'qti'}*@hits / $len0{'bd'});
            }
        #}

        #------------------------------
        # compute exact match scores of title words: !!! added 4/26
        #   - proportion of match string
        #------------------------------
        # match in doc title
        my ($ti2hit,$bd2hit)=(0,0);
        foreach my $wd(keys %{$qti3hp->{$qn}}) {
            if (my @hits= $ti=~/\b$wd\b/ig) {
                $ti2=~s/\b($wd($QTM2\d+)*)\b/$1$QTM2$qn/ig;
                if ($debug) { my$hit=@hits; print "caltpSCall3: tiH=$hit\n"; }
                $ti2hit += @hits;
            }
            # match in doc body
            if (my @hits= $bd=~/\b$wd\b/ig) {
                $bd2=~s/\b($qti?($QTM2\d+)*)\b/$1$QTM2$qn/ig;
                if ($debug) { my$hit=@hits; print "caltpSCall3: bdH=$hit\n"; }
                $bd2hit += @hits;
            }
        }
        $schp->{$qn}{'bd2'}= ($bd2hit / $len{'qti'}*$len0{'bd'});
        $schp->{$qn}{'ti2'}= ($ti2hit / $len{'qti'}*$len0{'ti'});

        #------------------------------
        # compute proximity match scores of query title
        #  - using stopped & stemmed title text
        #  - proportion of match string
        #------------------------------
        # multiple word query only
        if ($qti2=~/ /) {
            # match in doc title
            #  - allow avg. 2 words between query words
            my $hit1= &swinprox($qti2,$ti,2);
            print "caltpSCall2: tixH=$hit1\n" if ($debug);
            $schp->{$qn}{'tix'}= ($len{'qti2'}*$hit1 / $len0{'ti'}) if ($hit1);
            # match in doc body
            #  - allow avg. 2 words between query words
            my $hit2= &swinprox($qti2,$bd,2);
            print "caltpSCall2: bdxH=$hit2\n" if ($debug);
            $schp->{$qn}{'bdx'}= ($len{'qti2'}*$hit2 / $len0{'bd'}) if ($hit2);
        }

        #------------------------------
        # compute proximity match score of query description
        #  - using stopped & stemmed description text
        #  - proportion of match string
        #------------------------------
        # multiple word query only
        if ($qdesc2 && $qdesc2=~/ /) {
            # allow avg. 2 words between query words
            my $hit= &swinprox($qdesc2,$bd,2);
            print "caltpSCall2: bdx2H=$hit\n" if ($debug);
            $schp->{$qn}{'bdx2'}= ($len{'qdesc2'}*$hit / $len0{'bd'}) if ($hit);
        }

        #------------------------------
        # compute phrase match scores
        #  - length-normalized
        #------------------------------
        if ($php) {
            foreach my $ph(sort keys %$php) {
                my $phfreq= $php->{$ph};
                
                my @wd=split(/-/,$ph);
                
                # bigram
                if (@wd==2) {
                    # allow for plurals
                    $wd[0] .= 's' if ($wd[0]!~/s$/i);
                    $wd[1] .= 's' if ($wd[1]!~/s$/i);
                    if (my @hits= ($text=~/\b$wd[0]? $wd[1]?\b/ig)) {
                        if ($debug) { my$hit=@hits; print "caltpSCall2: phH1=$hit\n"; } 
                        $schp->{$qn}{'ph'} += (@hits*$phfreq / $len0{'text'});  # phrase wt = qtf
                    }
                }
                
                # 3 or more words: exact match except for the last word plural
                else {
                    $ph=~s/\-/ /g;
                    $ph .= 's' if ($ph!~/s$/i);
                    if (my @hits= ($text=~/\b$ph?\b/ig)) {
                        if ($debug) { my$hit=@hits; print "caltpSCall2: phH2=$hit\n"; } 
                        $schp->{$qn}{'ph'} += (@hits*$phfreq / $len0{'text'});  # phrase wt = qtf
                    }
                }
            
            } #end-foreach
        } #end-if ($php)

        #------------------------------
        # compute expanded phrase match scores
        #  - length-normalized
        #------------------------------
        if ($ph2p) {
            foreach my $ph(sort keys %$ph2p) {
                my $phwt= $ph2p->{$ph};
                
                my @wd=split(/-/,$ph);
                
                # bigram
                if (@wd==2) {
                    # allow for plurals
                    $wd[0] .= 's' if ($wd[0]!~/s$/i);
                    $wd[1] .= 's' if ($wd[1]!~/s$/i);
                    if (my @hits= ($text=~/\b$wd[0]? $wd[1]?\b/ig)) {
                        if ($debug) { my$hit=@hits; print "caltpSCall2: ph2H1=$hit\n"; } 
                        $schp->{$qn}{'ph2'} += (@hits*$phwt / $len0{'text'});  
                    }
                }
                
            } #end-foreach
        } #end-if ($ph2p)

        #------------------------------
        # compute nonrel phrase scores
        #  - length-normalized
        #------------------------------
        if ($nrphp) { 
            foreach my $ph(sort keys %$nrphp) {
                my $phfreq= $nrphp->{$ph};

                my @wd=split(/-/,$ph);

                # bigram
                if (@wd==2) {
                    # allow for plurals
                    $wd[0] .= 's' if ($wd[0]!~/s$/i);
                    $wd[1] .= 's' if ($wd[1]!~/s$/i);
                    if (my @hits= $text=~/\b$wd[0]? $wd[1]?\b/ig) {
                        if ($debug) { my$hit=@hits; print "caltpSCall2: nrphH1=$hit\n"; }
                        $schp->{$qn}{'nrph'} += (@hits*$phfreq / $len0{'text'});  # phrase wt = qtf
                    }
                }

                # 3 or more words: exact match except for the last word plural
                else {
                    $ph=~s/\-/ /g;
                    $ph .= 's' if ($ph!~/s$/i);
                    if (my @hits= $text=~/\b$ph?\b/ig) {
                        if ($debug) { my$hit=@hits; print "caltpSCall2: nrphH2=$hit\n"; }
                        $schp->{$qn}{'nrph'} += (@hits*$phfreq / $len0{'text'});  # phrase wt = qtf
                    }
                }

            } #end-foreach
        } #end-if ($nrphp)

        #------------------------------
        # compute nonrel noun scores
        #  - length-normalized
        #------------------------------
        if ($nrnp) {
            foreach my $nrn(sort keys %$nrnp) {
                my $nrnfreq= $nrnp->{$nrn};
                $nrn .= 's' if ($nrn!~/s$/i);
                if (my @hits= $text=~/\b$nrn?\b/ig) {
                    if ($debug) { my$hit=@hits; print "caltpSCall2: nrnH=$hit\n"; }
                    $schp->{$qn}{'nrn'} += (@hits*$nrnfreq / $len0{'text'});
                }
            }   
        } #end-if ($nrnp)

    } #end-foreach $qn

    my $text2= "$ti2\n$bd2";  # for opinion scoring proximity match

    return ($qtixmCNT,$qtixmCNT2,$text2);

} #endsub caltpSCall4


# redifined $schp->{$qn}{'qtixm'}
#                  1 if exact n-gram title string found in body
#                  2 if exact unigram title string found in body
#                  3 if title word found in body
#                  0 otherwise
sub caltpSCall5 {
    my($ti,$bd,$text,$QTM,$QTM2,$qtihp,$qti2hp,$qti3hp,$qdesc2hp,$phhp,$ph2hp,$nrphhp,$nrnhp,$schp,$stophp)=@_;
    my $debug=0;

    my ($ti2,$bd2)=($ti,$bd);  # for marking query matches

    my %len0;
    # get document text lengths
    #  -%len0: k=(ti|bd|text), v=token count
    my %hash=('ti'=>$ti,'bd'=>$bd,'text'=>$text);
    foreach my $name(keys %hash) {
        my $var= $hash{$name};
        print "caltpSCall2: name=$name, var=$var\n" if ($debug);
        if ($var) {
            my @wds= ($var=~/\s+/g);
            $len0{$name}= @wds+1;
        }
        else { $len0{$name}=0; }
    }
    $schp->{0}{'tl'}= $len0{'text'};

    #--------------------------------------
    # compute topic scores for each query
    #--------------------------------------

    my $qtixmCNT=0;  # query title (exact string) match count
    my $qtixmCNT2=0;  # query title (any word) match count

    foreach my $qn(keys %$qtihp) {

        # %qtihp,%qti2hp,%qds2hp: k(QN) = v(text)
        # %phhp,%nrphhp,%nrnhp:   k(QN -> term) = v(freq)
        my ($qti,$qti2,$qdesc2)=($qtihp->{$qn},$qti2hp->{$qn},$qdesc2hp->{$qn});
        my ($php,$ph2p,$nrphp,$nrnp)=($phhp->{$qn},$ph2hp->{$qn},$nrphhp->{$qn},$nrnhp->{$qn});

        # accomodate changes in indexing module (7/20/2007)
        #   - $qti2: words after comma (,) = alternate wordform of special query terms
        # NOTE: should be handled in the calling program (e.g. rerankrt13new.pl)
        #$qti2=$1 if ($qti2=~/^(.+?)\s+,/);

        my %len;
        # get query text lengths
        #  -%len: k=(qti|qt2|qdesc2), v=token count
        my %hash=('qti'=>$qti,'qti2'=>$qti2,'qdesc2'=>$qdesc2);
        foreach my $name(keys %hash) {
            my $var= $hash{$name};
            print "caltpSCall2: name=$name, var=$var\n" if ($debug);
            if ($var) {
                my @wds= ($var=~/\s+/g);
                $len{$name}= @wds+1;
            }
            else { $len{$name}=0; }
        }

        # allow for plurals
        $qti .= 's' if ($qti!~/s$/i);

        # flag if exact query title string occurs in body text
        $schp->{$qn}{'qtixm'}=0; 
        if ($bd=~/\b$qti?\b/i) { 
            if ($qti=~/ /) { $schp->{$qn}{'qtixm'}=1; }
            else { $schp->{$qn}{'qtixm'}=2; }
            $qtixmCNT++;
            $qtixmCNT2++;
        }
        else { 
            $schp->{$qn}{'qtixm'}=0; 
            if ($qti=~/ /) {
                my @qwds=split(/ +/,$qti);
                foreach my $qwd(@qwds) {
                    next if (length($qwd)==1 || $stophp->{lc($qwd)});
                    if ($bd=~/\b$qwd?\b/i) { 
                        $schp->{$qn}{'qtixm'}=3; 
                        $qtixmCNT2++;
                    }
                }
            }
        }

        #------------------------------
        # compute exact match scores of title string
        #   - proportion of match string
        #------------------------------
        # match in doc title
        if (my @hits= $ti=~/\b$qti?\b/ig) {
            $ti2=~s/\b($qti?($QTM\d+)*)\b/$1$QTM$qn/ig;
            if ($debug) { my$hit=@hits; print "caltpSCall2: tiH=$hit\n"; }
            $schp->{$qn}{'ti'}= ($len{'qti'}*@hits / $len0{'ti'});
        }
        # match in doc body
        #  - compute score only if multiple word query
        ###!! 11/16/08  - !!! consider doing it for single term query as well
        #if ($qti=~/ /) {
            if (my @hits= $bd=~/\b$qti?\b/ig) {
                $bd2=~s/\b($qti?($QTM\d+)*)\b/$1$QTM$qn/ig;
                if ($debug) { my$hit=@hits; print "caltpSCall2: bdH=$hit\n"; }
                $schp->{$qn}{'bd'}= ($len{'qti'}*@hits / $len0{'bd'});
            }
        #}

        #------------------------------
        # compute exact match scores of title words: !!! added 4/26
        #   - proportion of match string
        #------------------------------
        # match in doc title
        my ($ti2hit,$bd2hit)=(0,0);
        foreach my $wd(keys %{$qti3hp->{$qn}}) {
            if (my @hits= $ti=~/\b$wd\b/ig) {
                $ti2=~s/\b($wd($QTM2\d+)*)\b/$1$QTM2$qn/ig;
                if ($debug) { my$hit=@hits; print "caltpSCall3: tiH=$hit\n"; }
                $ti2hit += @hits;
            }
            # match in doc body
            if (my @hits= $bd=~/\b$wd\b/ig) {
                $bd2=~s/\b($qti?($QTM2\d+)*)\b/$1$QTM2$qn/ig;
                if ($debug) { my$hit=@hits; print "caltpSCall3: bdH=$hit\n"; }
                $bd2hit += @hits;
            }
        }
        $schp->{$qn}{'bd2'}= ($bd2hit / $len{'qti'}*$len0{'bd'});
        $schp->{$qn}{'ti2'}= ($ti2hit / $len{'qti'}*$len0{'ti'});

        #------------------------------
        # compute proximity match scores of query title
        #  - using stopped & stemmed title text
        #  - proportion of match string
        #------------------------------
        # multiple word query only
        if ($qti2=~/ /) {
            # match in doc title
            #  - allow avg. 2 words between query words
            my $hit1= &swinprox($qti2,$ti,2);
            print "caltpSCall2: tixH=$hit1\n" if ($debug);
            $schp->{$qn}{'tix'}= ($len{'qti2'}*$hit1 / $len0{'ti'}) if ($hit1);
            # match in doc body
            #  - allow avg. 2 words between query words
            my $hit2= &swinprox($qti2,$bd,2);
            print "caltpSCall2: bdxH=$hit2\n" if ($debug);
            $schp->{$qn}{'bdx'}= ($len{'qti2'}*$hit2 / $len0{'bd'}) if ($hit2);
        }

        #------------------------------
        # compute proximity match score of query description
        #  - using stopped & stemmed description text
        #  - proportion of match string
        #------------------------------
        # multiple word query only
        if ($qdesc2 && $qdesc2=~/ /) {
            # allow avg. 2 words between query words
            my $hit= &swinprox($qdesc2,$bd,2);
            print "caltpSCall2: bdx2H=$hit\n" if ($debug);
            $schp->{$qn}{'bdx2'}= ($len{'qdesc2'}*$hit / $len0{'bd'}) if ($hit);
        }

        #------------------------------
        # compute phrase match scores
        #  - length-normalized
        #------------------------------
        if ($php) {
            foreach my $ph(sort keys %$php) {
                my $phfreq= $php->{$ph};
                
                my @wd=split(/-/,$ph);
                
                # bigram
                if (@wd==2) {
                    # allow for plurals
                    $wd[0] .= 's' if ($wd[0]!~/s$/i);
                    $wd[1] .= 's' if ($wd[1]!~/s$/i);
                    if (my @hits= ($text=~/\b$wd[0]? $wd[1]?\b/ig)) {
                        if ($debug) { my$hit=@hits; print "caltpSCall2: phH1=$hit\n"; } 
                        $schp->{$qn}{'ph'} += (@hits*$phfreq / $len0{'text'});  # phrase wt = qtf
                    }
                }
                
                # 3 or more words: exact match except for the last word plural
                else {
                    $ph=~s/\-/ /g;
                    $ph .= 's' if ($ph!~/s$/i);
                    if (my @hits= ($text=~/\b$ph?\b/ig)) {
                        if ($debug) { my$hit=@hits; print "caltpSCall2: phH2=$hit\n"; } 
                        $schp->{$qn}{'ph'} += (@hits*$phfreq / $len0{'text'});  # phrase wt = qtf
                    }
                }
            
            } #end-foreach
        } #end-if ($php)

        #------------------------------
        # compute expanded phrase match scores
        #  - length-normalized
        #------------------------------
        if ($ph2p) {
            foreach my $ph(sort keys %$ph2p) {
                my $phwt= $ph2p->{$ph};
                
                my @wd=split(/-/,$ph);
                
                # bigram
                if (@wd==2) {
                    # allow for plurals
                    $wd[0] .= 's' if ($wd[0]!~/s$/i);
                    $wd[1] .= 's' if ($wd[1]!~/s$/i);
                    if (my @hits= ($text=~/\b$wd[0]? $wd[1]?\b/ig)) {
                        if ($debug) { my$hit=@hits; print "caltpSCall2: ph2H1=$hit\n"; } 
                        $schp->{$qn}{'ph2'} += (@hits*$phwt / $len0{'text'});  
                    }
                }
                
            } #end-foreach
        } #end-if ($ph2p)

        #------------------------------
        # compute nonrel phrase scores
        #  - length-normalized
        #------------------------------
        if ($nrphp) { 
            foreach my $ph(sort keys %$nrphp) {
                my $phfreq= $nrphp->{$ph};

                my @wd=split(/-/,$ph);

                # bigram
                if (@wd==2) {
                    # allow for plurals
                    $wd[0] .= 's' if ($wd[0]!~/s$/i);
                    $wd[1] .= 's' if ($wd[1]!~/s$/i);
                    if (my @hits= $text=~/\b$wd[0]? $wd[1]?\b/ig) {
                        if ($debug) { my$hit=@hits; print "caltpSCall2: nrphH1=$hit\n"; }
                        $schp->{$qn}{'nrph'} += (@hits*$phfreq / $len0{'text'});  # phrase wt = qtf
                    }
                }

                # 3 or more words: exact match except for the last word plural
                else {
                    $ph=~s/\-/ /g;
                    $ph .= 's' if ($ph!~/s$/i);
                    if (my @hits= $text=~/\b$ph?\b/ig) {
                        if ($debug) { my$hit=@hits; print "caltpSCall2: nrphH2=$hit\n"; }
                        $schp->{$qn}{'nrph'} += (@hits*$phfreq / $len0{'text'});  # phrase wt = qtf
                    }
                }

            } #end-foreach
        } #end-if ($nrphp)

        #------------------------------
        # compute nonrel noun scores
        #  - length-normalized
        #------------------------------
        if ($nrnp) {
            foreach my $nrn(sort keys %$nrnp) {
                my $nrnfreq= $nrnp->{$nrn};
                $nrn .= 's' if ($nrn!~/s$/i);
                if (my @hits= $text=~/\b$nrn?\b/ig) {
                    if ($debug) { my$hit=@hits; print "caltpSCall2: nrnH=$hit\n"; }
                    $schp->{$qn}{'nrn'} += (@hits*$nrnfreq / $len0{'text'});
                }
            }   
        } #end-if ($nrnp)

    } #end-foreach $qn

    my $text2= "$ti2\n$bd2";  # for opinion scoring proximity match

    return ($qtixmCNT,$qtixmCNT2,$text2);

} #endsub caltpSCall5



#------------------------------------------------------------
# compute opinion scores for all queries
## multiple lex weights
## changes from calopSCall7
#   - added 'nothing' to %negwds
#   - fixed prox. match bug: @wdsM & @wds not lined up due to preprocessing
#   - does not compute opinion score if qtixm=0 (no target found) && target is unigram
#-----------------------------------------------------------
# arg1 = text to be scored
# arg2 = text tagged for query match
# arg3 = pointer to query title hash
#          k= QN, v= query title
# arg4 = negation placeholder
# arg5 = query title match placeholder
# arg6 = proximity window size
# arg7 = pointer to opinon score hash
#          k1= QN (NOTE: 0= query independent scores)
#          v1= hash pointer
#              k2= score name
#              v2= score
#                  opinion key values (QN=0):  iu[NP],hf[NP],lf[NP],w1[NP],w2[NP],e
#                  opinion key values (QN!=0): iux[NP],hfx[NP],lfx[NP],w1x[NP],w2x[NP],ex
#                  e.g iu   - IU simple match score
#                      iuP  - IU simple positive poloarity match score
#                      iuN  - IU simple negative poloarity match score
#                      iux  - IU proximity match score
#                      iuxP - IU proximity positive polarity match score
#                      iuxN - IU proximity negative polarity match score
#                  misc. key values:
#                      in1  - number of I, my, me
#                      in2  - number of you, we, your, our, us
# arg8 = pointer to IU hash
# arg9 = pointer to HF hash
# arg10 = pointer to LF hash
# arg11 = pointer to LF regex array
# arg12 = pointer to LF regex score array
# arg13 = pointer to LF morph regex array
# arg14 = pointer to LF morph regex score array
# arg15 = pointer to AC hash
# arg16 = pointer to Wilson's strong subj hash
# arg17 = pointer to Wilson's weak subj hash
# arg18 = pointer to Wilson's emphasis  hash
# arg19 = optional no term morphing flag
#-----------------------------------------------------------
# NOTE:
#   1. $textM is marked w/ query match
#      - e.g. 'token1 token2$QTM$qn token3 token4$QTM$qn'
#   2. $text should be prepped w/ preptext0
#-----------------------------------------------------------
sub calopSCall8 {
    my($textM,$QTM,$QTM2,$NOT,$maxwdist,$qthp,$prxwsize,$schp,$achp,$hfhp,$iuhp,$lfhp,
       $lfxlp,$lfxsclpM,$lfxsclpC,$lfxsclpP,$lfmlp,$lfmsclpM,$lfmsclpC,$lfmsclpP,
       $w1hp,$w2hp,$emphp,$pavhp,$navhp,$nomrpf)=@_;
    my $debug=0;

    # !! add 'nothing': e.g. 'nothing bad'
    my %negwds=("not"=>1,"never"=>1,"no"=>1,"without"=>1,"hardly"=>1,"barely"=>1,"scarcely"=>1,"nothing"=>1,
                "$NOT"=>1,"I-NOT"=>1,"ME-NOT"=>1,"MY-NOT"=>1);

    # IU anchor cnt
    my ($iucnt,$iucnt2,@iucnt,@iucnt2)=(0,0); 
    @iucnt= $textM=~/\b(I|my|me)\b/gi;
    @iucnt2= $textM=~/\b(you|we|your|our|us)\b/gi;
    $iucnt=@iucnt;
    $iucnt2=@iucnt2;
    $schp->{0}{'in1'} += $iucnt;
    $schp->{0}{'in2'} += $iucnt2;

    # convert opinion phrase to acronyms:
    #   e.g. 'in my humble opinion' to 'imho in my humble opinion'
    foreach my $str(keys %{$achp}) {
        next if ($str !~ / /);  # phrases only
        my $ac= lc(join("",$str=~/\b([A-Za-z])/g));
        $str=~s/I'm/I am/;
        $textM=~s/($str)/ $ac $1/ig if ($textM=~/$str/i);
    }   

    print "calopSCall8: TEXT1=\n$textM\n\n" if ($debug);

    #-------------------------------------------------------------------------
    # Normalize IU phrase:
    #  NOTE: some opinion terms can be compressed w/ this normalization
    #-------------------------------------------------------------------------

    # compress select prepositions, conjunctions, articles: for proximity match
    $textM=~s/\s+(for|to|over|on|upon|in|with|of|and|or|a|an|the)\s+/ /gi;

    # e.g., 'cannot ever really be truly and completely satisfying to me' to 'every really be truly satisfying ME-NOT'
    $textM=~s/\b($NOT\s+([A-Za-z]+\s+){0,6})(me|you|us)\b/$1ME-NOT/gi;

    # e.g., 'cannot really ever truly and unconditionally have my' to 'really ever truly unconditionally have MY-NOT'
    $textM=~s/\b($NOT\s+([A-Za-z]+\s+){0,6})(my|your|our)\b/$1MY-NOT/gi;

    # e.g., 'my total and undying support of him really and truly cannot' to 'MY-NOT total undying support really truly cannot'
    $textM=~s/\b(my|your|our)\s+(([A-Za-z]+\s+){0,6}$NOT)\s+/MY-NOT $2 /gi;

    # e.g., 'I truly and seriously cannot' to 'I-NOT'
    $textM=~s/\b(I|you|we)\s+([A-Za-z]+\s+){0,2}$NOT\s+/I-NOT /gi;

    # e.g., 'I very likely will' to 'I '
    $textM=~s/\b(I|you|we)\s+([A-Za-z]+\s+){0,2}(can|could|will|would|shall|should|must|do|did|may|might|am|was|are|were|have to|had to|have|had|need)\s+/I /gi;

    print "calopSCall8: TEXT2=\n$textM\n\n" if ($debug);

    # $textM QTM markup has trailing numbers ($qn)
    #   - e.g. 'token1 token2$QTM$qn token3 token4$QTM$qn'
    my @wdsM0=split(/[^a-z!\-\d]+/,lc($textM));
    my @wdsM;

    # exclude non-letter tokens without QTM markup
    #  - to line up @wdsM with @wds
    my %qtmcnt;
    my %qtm2cnt;
    my %qwpos;  # k=QN, v=arry of term positions for whole query string
    my %qwpos2;  # k=QN, v=arry of term positions for query word
    my $pos=0;
    foreach my $wd(@wdsM0) {
        if ($wd=~/\d/) {
            my $added=0;
            if (my @qns= $wd=~/$QTM(\d+)/ig) {
                foreach my $qn(@qns) { 
                    $qtmcnt{$qn}++; 
                    push(@{$qwpos{$qn}},$pos);
                }
                push(@wdsM,$wd);
                $pos++;
                $added=1;
            }   
            if (my @qns= $wd=~/$QTM2(\d+)/ig) {
                foreach my $qn(@qns) { 
                    $qtm2cnt{$qn}++; 
                    push(@{$qwpos2{$qn}},$pos);
                }
                if (!$added) {
                    push(@wdsM,$wd);
                    $pos++;
                }
            }   
        }   
        else { 
            push(@wdsM,$wd); 
            $pos++;
        }
    }

    my $text=$textM;
    $text=~s/($QTM|$QTM2)\d+//g;

    # words are converted to lowercase
    my @wds0=split(/[^a-z!\-\d]+/,lc($text));
    my @wds;

    # exclude non-letter tokens
    foreach my $wd(@wds0) {
        next if ($wd=~/\d/);
        push(@wds,$wd); 
    }

    if ($debug) {
        foreach my $qn(sort keys %qtmcnt) { print "calopSCall8: QTM $qn match = $qtmcnt{$qn}\n"; }
        for(my $i=0;$i<@wds;$i++) { print "calopSCall8: ($i) wd=$wds[$i], wdM=$wdsM[$i]\n"; }
    }

    my $wdcnt=@wds;

    if ($debug) {
        print "wds=", join " ",@wds,"\n\n";
        print "wdsM=", join " ",@wdsM,"\n\n";
    }

    for(my $i=0; $i<$wdcnt; $i++) {
        next if ($wds[$i]=~/^\s*$/);

        my $word=$wds[$i];
        print "I=$i, wd=$word, wdm=$wdsM[$i]\n" if ($debug);

        # compress hyphens
        my $wordh;
        if (!$nomrpf && $word=~/\-/) {
            # delete leading/trailing hyphen 
            $word=~s/^\-?(.+?)\-?$/$1/;
            $wordh=$word;
            $wordh=~s/\-+//g;
        }

        my ($emp,$emp2)=(0,0);

        # words ending w/ !
        $emp=1 if ($word=~s/!$//);

        # words w/ 3+ repeat characters
        $emp2=1 if ($word=~/([a-z])\1{2,}/i);

        # compress embedded repeat characters
        #  - exception: e, o
        my $wordc;
        if (!$nomrpf && $word=~/([a-cdf-np-z])\1+\B/) {
            $wordc=$word;
            $wordc=~s/([a-cdf-np-z])\1+\B/$1/g;
        }

        # flag proximity match !
        #  - %prxm: k=QN, v=0,1
        # compute word distance between current word and query string
        #  - %wdist: k=QN, v=word distance
        # compute word distance between current word and query word
        #  - %wdist2: k=QN, v=word distance
        my (%wdist,%wdist2,%prxm);
        foreach my $qn(keys %$qthp) {
            my $mindist=1000;
            my $mindist2=1000;
            my $prxmatch=0;
            my $text2=$text;
            # replace query strings
            if ($qtmcnt{$qn} || $qtm2cnt{$qn}) {  ###!! 11/16/08
                my $minI=$i-$prxwsize;
                my $maxI=$i+$prxwsize;
                $minI=0 if ($minI<0);
                $maxI=$#wds if ($maxI>$#wds);
                my $proxstr= join(' ',@wdsM[$minI..$maxI]);
                $prxmatch=1 if ($proxstr=~/$QTM$qn/i);
                $mindist= &minDist($i,$qwpos{$qn});
                ###!! for single term query, 11/16/08
                if ($qtmcnt{$qn} && !$qtm2cnt{$qn}) { $mindist2= $mindist; }
                else { $mindist2= &minDist($i,$qwpos2{$qn}); }
                print "prxstr=$proxstr\n" if ($debug);
            }
            $prxm{$qn}=$prxmatch;
            $wdist{$qn}=$mindist;
            $wdist2{$qn}=$mindist2;
            print "  qn=$qn, prxmatch=$prxmatch\n" if ($debug);
        }

        # get preceding words (for catching negations)
        my($pwd,$ppwd,$pppwd);  # preceding words
        if ($i>2) { ($pppwd,$ppwd,$pwd)=($wds[$i-3],$wds[$i-2],$wds[$i-1]); }
        elsif ($i>1) { ($ppwd,$pwd)=($wds[$i-2],$wds[$i-1]); }
        elsif ($i>0) { $pwd=$wds[$i-1]; }
        foreach my $wd2($pwd,$ppwd,$pppwd) {
            next if (!$wd2);
            # delete leading/trailing hyphen
            $wd2=~s/^\-?(.+?)\-?$/$1/ if ($wd2=~/\-/);
        }

        print "calopSCall8: word=$word, emp=$emp, emp2=$emp2\n" if ($debug>2);

        #-----------------------------------------
        # flag IU phrase and get adjacent terms

        my ($neg,$iu,$iu2)=(0);
        my ($wd1,$wd2,$wd3,$wd1b,$wd2b,$wd3b);

        if ($word=~/^(I|we|I-NOT)$/i) {
            $neg=1 if ($1=~/\-NOT/i);
            $iu='I';
            # allow for up to 2 words in-between
            #  e.g., "I truly seriously believe",
            if ($i+3 < $wdcnt) { ($wd1,$wd2,$wd3)=($wds[$i+1],$wds[$i+2],$wds[$i+3]); }
            elsif ($i+2 < $wdcnt) { ($wd1,$wd2)=($wds[$i+1],$wds[$i+2]); }
            elsif ($i+1 < $wdcnt) { $wd1=$wds[$i+1]; }
        }

        elsif ($word=~/^(my|your|our|MY-NOT)$/i) {
            $neg=1 if ($1=~/\-NOT/i);
            $iu='my';
            # allow for up to 2 words in-between
            #  e.g., "I truly seriously believe",
            if ($i+3 < $wdcnt) { ($wd1,$wd2,$wd3)=($wds[$i+1],$wds[$i+2],$wds[$i+3]); }
            elsif ($i+2 < $wdcnt) { ($wd1,$wd2)=($wds[$i+1],$wds[$i+2]); }
            elsif ($i+1 < $wdcnt) { $wd1=$wds[$i+1]; }
        }

        elsif ($word=~/^(me|us|ME-NOT)$/i) {
            $neg=1 if ($1=~/\-NOT/i);
            $iu='me';
            # allow for up to 2 words in-between
            #  e.g. "impressed the hell out of me"
            #  NOTE: 'the' & 'of' are already compressed
            if ($i > 2) { ($wd1,$wd2,$wd3)=($wds[$i-1],$wds[$i-2],$wds[$i-3]); }
            elsif ($i > 1) { ($wd1,$wd2)=($wds[$i-1],$wds[$i-2]); }
            elsif ($i > 0) { $wd1=$wds[$i-1]; }
        }

        # NOTE: 'you believe' or 'impressed you'
        elsif ($word=~/^you$/i) {
            $iu='I';
            # allow for up to 2 words in-between
            #  e.g., "you truly seriously believe",
            if ($i+3 < $wdcnt) { ($wd1,$wd2,$wd3)=($wds[$i+1],$wds[$i+2],$wds[$i+3]); }
            elsif ($i+2 < $wdcnt) { ($wd1,$wd2)=($wds[$i+1],$wds[$i+2]); }
            elsif ($i+1 < $wdcnt) { $wd1=$wds[$i+1]; }
            $iu2='me';
            # allow for up to 2 words in-between
            #  e.g. "impressed the hell out of you"
            #  NOTE: 'the' & 'of' are already compressed
            if ($i > 2) { ($wd1b,$wd2b,$wd3b)=($wds[$i-1],$wds[$i-2],$wds[$i-3]); }
            elsif ($i > 1) { ($wd1b,$wd2b)=($wds[$i-1],$wds[$i-2]); }
            elsif ($i > 0) { $wd1b=$wds[$i-1]; }
        }

        # get preceding words (for $iu='me')
        my (@iuwds,%pwds);
        if ($iu) {
            @iuwds= ($wd1,$wd2,$wd3,$wd1b,$wd2b,$wd3b);
            for my $k(0,1,2) {
                my($pwd,$ppwd,$pppwd);  # preceding words
                if ($i>3) {
                    ($pppwd,$ppwd,$pwd)=($wds[$i-3-$k],$wds[$i-2-$k],$wds[$i-1-$k]);
                }
                elsif ($i>2) {
                    ($ppwd,$pwd)=($wds[$i-2-$k],$wds[$i-1-$k]);
                }
                elsif ($i>1) {
                    $pwd=$wds[$i-1-$k];
                }
                foreach my $wd2($pwd,$ppwd,$pppwd) {
                    next if (!$wd2);
                    # delete leading/trailing hyphen
                    $wd2=~s/^\-?(.+?)\-?$/$1/ if ($wd2=~/\-/);
                }
                $pwds{$k}=[$pwd,$ppwd,$pppwd];
            }

            #----------------------------------------------------
            # compute IU opinion scores for each term
            #  - IU anchors need to be matched w/ original only
            #----------------------------------------------------

            my %sc= &IUsc7($word,$emp,$emp2,\%prxm,\%wdist,\%wdist2,$maxwdist,$iuhp,\%negwds,$pwd,$ppwd,$pppwd,\%pwds,\@iuwds,$iu,$iu2,$neg,$nomrpf);

            # increment opinion scores
            #   %sc key1  = QN
            #       key2a = sc,  scP,  scN  (when QN=0: query-independent socres)
            #       key2b = scx, scxP, scxN (when QN!=0: query-dependent socres)
            foreach my $qn(keys %sc) {
                foreach my $name(keys %{$sc{$qn}}) {
                    my $name2=$name;
                    $name2=~s/sc/iu/;
                    foreach my $wname('man','combo','prob') {
                        $schp->{$qn}{$name2}{$wname} += $sc{$qn}{$name}{$wname};
                    }
                }
            }

        }


        #------------------------------------------------------------
        # compute opinion scores for each word form
        #   - original, repeat-char compressed, hyphen compressed
        #   - search is stopped at first match for each opinion module
        #------------------------------------------------------------

        my %found;
        foreach my $wd($word,$wordc,$wordh) {
            next if (!$wd);

            print "calopSCall7: wd=$wd\n" if ($debug>2);

            if (!$found{'av'}) {  ##!!!!
                my %sc= &AVsc($wd,\%prxm,$pavhp,$navhp);
                # increment opinion scores
                #   %sc key1  = QN or 0
                #       key2a = psc,  nsc,  (when QN=0: query-independent socres)
                #       key2b = pscx, nscx  (when QN!=0: query-dependent socres)
                foreach my $qn(keys %sc) {
                    foreach my $name(keys %{$sc{$qn}}) {
                        my $name2=$name;
                        $name2=~s/sc/av/;
                        $schp->{$qn}{$name2} += $sc{$qn}{$name};
                    }
                }
                # stop when correct wordform is matched
                $found{'av'}=1 if ($sc{'sc'});  
            }

            if (!$found{'ac'}) {
                print "calling AC-HFsc7\n" if ($debug>3); ##!!
                my %sc= &HFsc7($wd,$emp,$emp2,\%prxm,\%wdist,\%wdist2,$maxwdist,$achp,\%negwds,$pwd,$ppwd,$pppwd);
                # increment opinion scores
                #   %sc key1  = QN
                #       key2a = sc,  scP,  scN  (when QN=0: query-independent socres)
                #       key2b = scx, scxP, scxN (when QN!=0: query-dependent socres)
                foreach my $qn(keys %sc) {
                    foreach my $name(keys %{$sc{$qn}}) {
                        my $name2=$name;
                        $name2=~s/sc/ac/;
                        foreach my $wname('man','combo','prob') {
                            $schp->{$qn}{$name2}{$wname} += $sc{$qn}{$name}{$wname};
                        }
                    }
                }
                # stop when correct wordform is matched
                $found{'ac'}=1 if ($sc{'sc'});  
            }

            if (!$found{'hf'}) {
                print "calling HF-HFsc7\n" if ($debug>3); ##!!
                my %sc= &HFsc7($wd,$emp,$emp2,\%prxm,\%wdist,\%wdist2,$maxwdist,$hfhp,\%negwds,$pwd,$ppwd,$pppwd);
                # increment opinion scores
                #   %sc key1  = QN
                #       key2a = sc,  scP,  scN  (when QN=0: query-independent socres)
                #       key2b = scx, scxP, scxN (when QN!=0: query-dependent socres)
                foreach my $qn(keys %sc) {
                    foreach my $name(keys %{$sc{$qn}}) {
                        my $name2=$name;
                        $name2=~s/sc/hf/;
                        foreach my $wname('man','combo','prob') {
                            $schp->{$qn}{$name2}{$wname} += $sc{$qn}{$name}{$wname};
                        }
                        #print "wd=$wd, qn=$qn, name=$name, name2=$name2, sc=$sc{$qn}{$name}\n";
                    }
                }
                # stop when correct wordform is matched
                $found{'hf'}=1 if ($sc{'sc'});  
            }

            if (!$found{'lf'}) {
                print "calling LF-HFsc7\n" if ($debug>3); ##!!
                my %sc= &LFsc7($wd,$emp,$emp2,\%prxm,\%wdist,\%wdist2,$maxwdist,$lfhp,
                                $lfxlp,$lfxsclpM,$lfxsclpC,$lfxsclpP,$lfmlp,$lfmsclpM,$lfmsclpC,$lfmsclpP,
                                \%negwds,$pwd,$ppwd,$pppwd);
                # increment opinion scores
                #   %sc key1  = QN
                #       key2a = sc,  scP,  scN  (when QN=0: query-independent socres)
                #       key2b = scx, scxP, scxN (when QN!=0: query-dependent socres)
                foreach my $qn(keys %sc) {
                    foreach my $name(keys %{$sc{$qn}}) {
                        my $name2=$name;
                        $name2=~s/sc/lf/;
                        foreach my $wname('man','combo','prob') {
                            $schp->{$qn}{$name2}{$wname} += $sc{$qn}{$name}{$wname};
                        }
                    }
                }
                # stop when correct wordform is matched
                $found{'lf'}=1 if ($sc{'sc'});  
            }

            if (!$found{'w1'}) {
                print "calling W1-HFsc7\n" if ($debug>3); ##!!
                my %sc= &HFsc7($wd,$emp,$emp2,\%prxm,\%wdist,\%wdist2,$maxwdist,$w1hp,\%negwds,$pwd,$ppwd,$pppwd);
                # increment opinion scores
                #   %sc key1  = QN
                #       key2a = sc,  scP,  scN  (when QN=0: query-independent socres)
                #       key2b = scx, scxP, scxN (when QN!=0: query-dependent socres)
                foreach my $qn(keys %sc) {
                    foreach my $name(keys %{$sc{$qn}}) {
                        my $name2=$name;
                        $name2=~s/sc/w1/;
                        foreach my $wname('man','combo','prob') {
                            $schp->{$qn}{$name2}{$wname} += $sc{$qn}{$name}{$wname};
                        }
                    }
                }
                # stop when correct wordform is matched
                $found{'w1'}=1 if ($sc{'sc'});  
            }

            if (!$found{'w2'}) {
                print "calling W2-HFsc7\n" if ($debug>3); ##!!
                my %sc= &HFsc7($wd,$emp,$emp2,\%prxm,\%wdist,\%wdist2,$maxwdist,$w2hp,\%negwds,$pwd,$ppwd,$pppwd);
                # increment opinion scores
                #   %sc key1  = QN
                #       key2a = sc,  scP,  scN  (when QN=0: query-independent socres)
                #       key2b = scx, scxP, scxN (when QN!=0: query-dependent socres)
                foreach my $qn(keys %sc) {
                    foreach my $name(keys %{$sc{$qn}}) {
                        my $name2=$name;
                        $name2=~s/sc/w2/;
                        foreach my $wname('man','combo','prob') {
                            $schp->{$qn}{$name2}{$wname} += $sc{$qn}{$name}{$wname};
                        }
                    }
                }
                # stop when correct wordform is matched
                $found{'w2'}=1 if ($sc{'sc'});  
            }

            if (!$found{'emp'}) {
                print "calling EMP-HFsc7\n" if ($debug>3); ##!!
                my %sc= &HFsc7($wd,$emp,$emp2,\%prxm,\%wdist,\%wdist2,$maxwdist,$emphp,\%negwds,$pwd,$ppwd,$pppwd);
                # increment opinion scores
                #   %sc key1  = QN
                #       key2a = sc  (when QN=0: query-independent socres)
                #       key2b = scx (when QN!=0: query-dependent socres)
                foreach my $qn(keys %sc) {
                    foreach my $name(keys %{$sc{$qn}}) {
                        my $name2=$name;
                        $name2=~s/sc/e/;
                        foreach my $wname('man','combo','prob') {
                            $schp->{$qn}{$name2}{$wname} += $sc{$qn}{$name}{$wname};
                        }
                    }
                }
                # stop when correct wordform is matched
                $found{'emp'}=1 if ($sc{'sc'});  
            }

        } #end-foreach my $wd($word,$wordc,$wordh) 

    } #end-for(my $i=0; $i<$wdcnt; $i++) 

} #endsub calopSCall8



#------------------------------------------------------------
# match all query words in sliding window
#------------------------------------------------------------
#   arg1= query string
#   arg2= target string
#   arg3= number of words between query terms
#   r.v.= number of "all the word" matches
#------------------------------------------------------------
sub swinprox {
    my($qstr,$tstr,$wspan)=@_;

    my @qwd=split(/ +/,$qstr);
    my ($qwdn,%qwd);
    foreach my $wd(@qwd) {
        # allow for plurals
        $wd .= 's' if ($wd!~/s$/i);
        $qwd{$wd}++;
        $qwdn++;
    }

    # window size
    #  - allow avg. 2 words between query words
    my $wdwin= $wspan*($qwdn-1) + $qwdn;

    # check for all word match in sliding window
    my @bwd=split(/\s+/,$tstr);
    my $hit=0;

    if (@bwd<=$wdwin) {
        # each sliding window
        my $txt= join(" ",@bwd);
        my $wn=0;
        foreach my $wd(keys %qwd) {
            if ($txt=~/$wd?/i) {
                $wn++;
                $txt=~s/\b$wd?\b/#!$wn!#/ig;
            }
        }
        # all the words are found
        if ($txt=~/#!$qwdn!#/) {
            $hit++;
        }
    }

    else {
        for(my $i=0; $i<@bwd; $i++) {

            my $i2= $i+$wdwin;

            last if ($i2>=@bwd);

            # each sliding window
            my $txt= join(" ",@bwd[$i..$i2]);
            my $wn=0;
            foreach my $wd(keys %qwd) {
                if ($txt=~/$wd?/i) {
                    $wn++;
                    $txt=~s/\b$wd?\b/#!$wn!#/ig;
                }
            }
            # all the words are found
            if ($txt=~/#!$qwdn!#/) {
                $hit++;
                $i=$i2; # check rest of target text
            }
        }
    } #end-else

    return $hit;

} #endsub swinprox


#------------------------------------------------------------
# compute HF opinion score
#   - length-normalized match count
#-----------------------------------------------------------
# arg1 = word to be scored
# arg2 = emphasis flag
# arg3 = emphasis flag 2
# arg4 = pointer to proximity match hash
#          key: QN, val: 1,0
# arg5 = pointer to word distance hash
#          key: QN, val: min. distance between word and query match
# arg6 = pointer to HF lexicon hash
#          key: term, val: [pnm]N
# arg7 = pointer to negation hash
# arg8 = preceding word
# arg9 = pre-preceding word
# arg10 = pre-pre-preceding word
# r.v. = score hash
#        k1= QN (NOTE: 0= query independent scores)
#        v1= hash pointer
#            k2: score name
#                sc   - simple match score
#                scP  - simple positive poloarity match score
#                scN  - simple negative poloarity match score
#                scx  - proximity match score
#                scxP - proximity positive polarity match score
#                scxN - proximity negative polarity match score
#                scd  - distance match score
#                scdP - distance positive polarity match score
#                scdN - distance negative polarity match score
#            v2: score
#-----------------------------------------------------------
# NOTE:
#   1. repeated characters are compressed if word not found  in lexicon
#      - lexicon should contain repeat-compressed words as well as original
#-----------------------------------------------------------
sub HFsc7 {
    my($wd,$emp,$emp2,$prxhp,$dsthp,$dst2hp,$maxwdist,$lexhp,$neghp,$pwd,$ppwd,$pppwd)=@_;
    my $debug=0;

    my %sc;

    if ($lexhp->{$wd}) {

        foreach my $wname('man','combo','prob') {

            my $lexsc= $lexhp->{$wd}{$wname};

            print "lexsc=$lexsc, name=$wname\n" if ($debug>3);  ##!!
            my($pol,$sc)=split//,$lexsc,2;
            $sc++ if ($emp);
            $sc++ if ($emp2);

            # opinion score
            $sc{0}{'sc'}{$wname} = $sc;

            # polarity score
            my($p,$n)=(0,0);
            if ($pol=~/[np]/) {
                ($p,$n)=&polSC0($pol,$sc,$pwd,$ppwd,$pppwd,$neghp);
                $sc{0}{'scP'}{$wname} = $p;
                $sc{0}{'scN'}{$wname} = $n;
                print "HFsc4(q0): wd=$wd, pol=$pol, scp=$p, scn=$n\n" if ($debug);
            }

            # prox. match score
            foreach my $qn(keys %$prxhp) {
                my $prxmatch= $prxhp->{$qn};
                ($sc{$qn}{'scx'}{$wname},$sc{$qn}{'scxP'}{$wname},$sc{$qn}{'scxN'}{$wname})=(0,0,0);

                if ($prxmatch) {
                    $sc{$qn}{'scx'}{$wname} = $sc;
                    # polarity score
                    if ($pol=~/[np]/) {
                        $sc{$qn}{'scxP'}{$wname} = $p;
                        $sc{$qn}{'scxN'}{$wname} = $n;
                    } 
                    print "HFsc4-prxm(q$qn): scx=$sc{$qn}{'scx'}, scxp=$sc{$qn}{'scxP'}, scxn=$sc{$qn}{'scxN'}\n" if ($debug);
                } 
            } 

            # dist. match score !
            foreach my $qn(keys %$dsthp) {
                my $wdist= $dsthp->{$qn};
                ($sc{$qn}{'scd'}{$wname},$sc{$qn}{'scdP'}{$wname},$sc{$qn}{'scdN'}{$wname})=(0,0,0);

                if ($wdist<$maxwdist) {  # max. word distance
                    my $idist=1/log($wdist+2);
                    $sc{$qn}{'scd'}{$wname} = sprintf("%.4f",$sc*$idist);
                    # polarity score
                    if ($pol=~/[np]/) {
                        $sc{$qn}{'scdP'}{$wname} = sprintf("%.4f",$p*$idist);
                        $sc{$qn}{'scdN'}{$wname} = sprintf("%.4f",$n*$idist);
                    } 
                } 
                print "HFsc4-dist(q$qn): scd=$sc{$qn}{'scd'}, scdp=$sc{$qn}{'scdP'}, scdn=$sc{$qn}{'scdN'}\n" if ($debug);
            } 
            foreach my $qn(keys %$dst2hp) {
                my $wdist= $dst2hp->{$qn};
                ($sc{$qn}{'scd2'}{$wname},$sc{$qn}{'scd2P'}{$wname},$sc{$qn}{'scd2N'}{$wname})=(0,0,0);

                if ($wdist<$maxwdist) {  # max. word distance
                    my $idist=1/log($wdist+2);
                    print "qn=$qn, wname=$wname, sc=$sc, idist=$idist\n" if ($debug>3);  ##!!
                    $sc{$qn}{'scd2'}{$wname} = sprintf("%.4f",$sc*$idist);
                    # polarity score
                    if ($pol=~/[np]/) {
                        $sc{$qn}{'scd2P'}{$wname} = sprintf("%.4f",$p*$idist);
                        $sc{$qn}{'scd2N'}{$wname} = sprintf("%.4f",$n*$idist);
                    } 
                } 
                print "HFsc4-dist2(q$qn): scd=$sc{$qn}{'scd2'}, scdp=$sc{$qn}{'scd2P'}, scdn=$sc{$qn}{'scd2N'}\n" if ($debug);
            } 

        } 

    } #end-if ($lexhp->{$wd})

    return (%sc);

} #endsub HFsc7


sub AVsc {
    my($wd,$prxhp,$plexhp,$nlexhp)=@_;
    my $debug=0;

    my %sc;
    $sc{0}{'psc'} = 0;
    $sc{0}{'nsc'} = 0;

    if ($plexhp->{$wd}) {

        # opinion score
        $sc{0}{'psc'} = 1;

        # prox. match score
        foreach my $qn(keys %$prxhp) {
            my $prxmatch= $prxhp->{$qn};
            if ($prxmatch) { $sc{$qn}{'pscx'} = 1; } 
            else { $sc{$qn}{'pscx'} = 0; } 
        } 


    } #end-if ($lexhp->{$wd})

    elsif ($nlexhp->{$wd}) {

        # opinion score
        $sc{0}{'nsc'} = 1;

        # prox. match score
        foreach my $qn(keys %$prxhp) {
            my $prxmatch= $prxhp->{$qn};
            if ($prxmatch) { $sc{$qn}{'nscx'} = 1; } 
            else { $sc{$qn}{'nscx'} = 0; } 
        } 


    } #end-if ($lexhp->{$wd})

    return (%sc);

} #endsub AVsc



#------------------------------------------------------------
# compute IU opinion scoring of a term for a set of queries
#  - idist score computation added
#-----------------------------------------------------------
# arg1 = word to be scored
# arg2 = emphasis flag
# arg3 = emphasis flag 2
# arg4 = pointer to proximity match hash
#          key: QN, val: 1,0
# arg5 = pointer to word distance hash
#          key: QN, val: min. distance between word and query match
# arg6 = pointer to IU lexicon hash
#          key: term, val: [pnm]N
# arg7 = pointer to negation hash
# arg8 = preceding word
# arg9 = pre-preceding word
# arg10 = pre-pre-preceding word
# arg11 = pointer to preceding word hash for iu=me
#           k=0,1,2;  v= [pwd,ppwd,pppwd]
# arg12 = pointer to adjacent IU words list
# arg13 = iu anchor 1
# arg14 = iu anchor 2
# arg15 = negation flag
# arg16 = optional no term morph flag
# r.v. = score hash
#        k1= QN (NOTE: 0= query independent scores)
#        v1= hash pointer
#            k2: score name
#                sc   - simple match score
#                scP  - simple positive poloarity match score
#                scN  - simple negative poloarity match score
#                scx  - proximity match score
#                scxP - proximity positive polarity match score
#                scxN - proximity negative polarity match score
#                scd  - distance match score
#                scdP - distance positive polarity match score
#                scdN - distance negative polarity match score
#            v2: score
#-----------------------------------------------------------
# NOTE:
#   1. repeated characters are compressed if word not found  in lexicon
#      - lexicon should contain repeat-compressed words as well as original
#-----------------------------------------------------------
sub IUsc7 {
    my($wd,$emp,$emp2,$prxhp,$dsthp,$dst2hp,$maxwdist,$lexhp,$neghp,$pwd,$ppwd,$pppwd,$pwdhp,$iuwdlp,$iu,$iu2,$neg,$nomrpf)=@_;
    my $debug=0;

    print "IUsc4a: wd=$wd, iu=$iu, p1=$pwd, p2=$ppwd, p3=$pppwd, iuwds=@{$iuwdlp}\n" if ($debug);

    my %sc;

    my $forI=0;

    # search adjacent terms to IU anchor for lexicon match
    DONE: foreach my $word(@{$iuwdlp}) {

        $forI++;
        next if (!$word);

        my $fI= $forI%3;

        # compress hyphens
        my $wordh;
        if (!$nomrpf && $word=~/\-/) {
            # delete leading/trailing hyphen
            $word=~s/^\-?(.+?)\-?$/$1/;
            $wordh=$word;
            $wordh=~s/\-+//g;
        }

        # words ending w/ !
        $emp=1 if ($word=~s/!$//);

        # words w/ 3+ repeat characters
        $emp2=1 if ($word=~/([a-z])\1{2,}/i);

        $iu=$iu2 if ($forI>3);

        # compress repeat characters
        #  - exception: e, o
        my $wordc;
        if (!$nomrpf && $word=~/([a-cdf-np-z])\1+\B/) {
            $wordc=$word;
            $wordc=~s/([a-cdf-np-z])\1+\B/$1/g;
        }

        print "IUsc4b: iu=$iu, word=$word, emp=$emp, emp2=$emp2, forI=$forI, fI=$fI\n" if ($debug);

        foreach my $wd($word,$wordc,$wordh) {
            next if (!$wd);

            print "IUsc4c: wd=$wd\n" if ($debug);

            if ($lexhp->{$iu}{$wd}) {

                foreach my $wname('man','combo','prob') {

                    my $lexsc= $lexhp->{$iu}{$wd}{$wname};

                    my($pol,$sc)=split//,$lexsc,2;
                    $sc++ if ($emp);
                    $sc++ if ($emp2);
                        
                    print "IUsc4e: FOUND wd=$wd, iu=$iu, sc=$sc, pol=$pol\n" if ($debug);

                    # opinion score
                    $sc{0}{'sc'}{$wname} = $sc;
                            
                    # polarity score
                    my($p,$n)=(0,0);
                    if ($pol=~/[np]/) {
                        ($p,$n)=&polSC0($pol,$sc,$pwd,$ppwd,$pppwd,$neghp,$neg);
                        $sc{0}{'scP'}{$wname} = $p;
                        $sc{0}{'scN'}{$wname} = $n;
                        if ($iu eq 'I') {
                            ($pwd,$ppwd,$pppwd)= ();
                        }
                        elsif ($iu eq 'me') {
                            # e.g. 'hardly make a strong impression on me'
                            #      (compressed to 'HARDLY make strong impression me')
                            ($pwd,$ppwd,$pppwd)= ($pwdhp->{$fI}[0],$pwdhp->{$fI}[1],$pwdhp->{$fI}[2]);
                        }
                        print "IUsc4f(q0): wd=$wd, pol=$pol, scp=$p, scn=$n\n" if ($debug);
                    }

                    # prox. match score
                    foreach my $qn(keys %$prxhp) {
                        my $prxmatch= $prxhp->{$qn};
                        ($sc{$qn}{'scx'}{$wname},$sc{$qn}{'scxP'}{$wname},$sc{$qn}{'scxN'}{$wname})=(0,0,0);

                        if ($prxmatch) {
                            $sc{$qn}{'scx'}{$wname} = $sc;
                            # polarity score
                            if ($pol=~/[np]/) {
                                $sc{$qn}{'scxP'}{$wname} = $p;
                                $sc{$qn}{'scxN'}{$wname} = $n;
                            }
                            print "IUsc4g-prxm(q$qn): scx=$sc{$qn}{'scx'}, scxp=$sc{$qn}{'scxP'}, scxn=$sc{$qn}{'scxN'}\n" if ($debug);
                        }

                    } #end-foreach $qn

                    # dist. match score !
                    foreach my $qn(keys %$dsthp) {
                        my $wdist= $dsthp->{$qn};
                        ($sc{$qn}{'scd'}{$wname},$sc{$qn}{'scdP'}{$wname},$sc{$qn}{'scdN'}{$wname})=(0,0,0);

                        if ($wdist<$maxwdist) {  # max. word distance
                            my $idist=1/log($wdist+2);
                            $sc{$qn}{'scd'}{$wname} = sprintf("%.4f",$sc*$idist);
                            # polarity score
                            if ($pol=~/[np]/) {
                                $sc{$qn}{'scdP'}{$wname} = sprintf("%.4f",$p*$idist);
                                $sc{$qn}{'scdN'}{$wname} = sprintf("%.4f",$n*$idist);
                            }
                        }
                        print "IUsc4-dist(q$qn): scd=$sc{$qn}{'scd'}, scdp=$sc{$qn}{'scdP'}, scdn=$sc{$qn}{'scdN'}\n" if ($debug);
                    }
                    foreach my $qn(keys %$dst2hp) {
                        my $wdist= $dst2hp->{$qn};
                        ($sc{$qn}{'scd2'}{$wname},$sc{$qn}{'scd2P'}{$wname},$sc{$qn}{'scd2N'}{$wname})=(0,0,0);

                        if ($wdist<$maxwdist) {  # max. word distance
                            my $idist=1/log($wdist+2);
                            $sc{$qn}{'scd2'}{$wname} = sprintf("%.4f",$sc*$idist);
                            # polarity score
                            if ($pol=~/[np]/) {
                                $sc{$qn}{'scd2P'}{$wname} = sprintf("%.4f",$p*$idist);
                                $sc{$qn}{'scd2N'}{$wname} = sprintf("%.4f",$n*$idist);
                            } 
                        } 
                        print "IUsc4-dist2(q$qn): scd=$sc{$qn}{'scd2'}, scdp=$sc{$qn}{'scd2P'}, scdn=$sc{$qn}{'scd2N'}\n" if ($debug);
                    } 

                } 

                # stop searching adjacent terms at first match
                last DONE;

            } #end-if ($wd && $lexhp->{$iu}->{$wd}) 

        } #end-foreach my $wd($word,$wordc,$wordh) 

    } #end-foreach my $word(@$iuwdhp)

    return (%sc);

} #endsub IUsc7



#------------------------------------------------------------
# compute LF opinion scoring of a term for a set of queries
#  - idist score computation added
#-----------------------------------------------------------
# arg1 = word to be scored
# arg2 = emphasis flag
# arg3 = emphasis flag 2
# arg4 = pointer to proximity match hash
#          key: QN, val: 1,0
# arg5 = pointer to word distance hash
#          key: QN, val: min. distance between word and query match
# arg6 = pointer to LF lexicon hash
#          key: term, val: [pnm]N
# arg7 = pointer to LF regex array
# arg8 = pointer to LF regex score array
# arg9 = pointer to LF repeat-char morph regex array
# arg10 = pointer to LF repeat-char morph regex score array
# arg11 = pointer to negation hash
# arg12 = preceding word
# arg13 = pre-preceding word
# arg14 = pre-pre-preceding word
# r.v. = score hash
#        k1= QN (NOTE: 0= query independent scores)
#        v1= hash pointer
#            k2: score name
#                sc   - simple match score
#                scP  - simple positive poloarity match score
#                scN  - simple negative poloarity match score
#                scx  - proximity match score
#                scxP - proximity positive polarity match score
#                scxN - proximity negative polarity match score
#                scd  - distance match score
#                scdP - distance positive polarity match score
#                scdN - distance negative polarity match score
#            v2: score
#-----------------------------------------------------------
# NOTE:
#   1. search multiple sources, stop at first match
#   seach order = lexicon, regex, repeat-char morph regex
#-----------------------------------------------------------
sub LFsc7 {
    my($wd,$emp,$emp2,$prxhp,$dsthp,$dst2hp,$maxwdist,$lexhp,
        $rgxlp,$rgxsclpM,$rgxsclpC,$rgxsclpP,$mrplp,$mrpsclpM,$mrpsclpC,$mrpsclpP,
        $neghp,$pwd,$ppwd,$pppwd)=@_;
    my $debug=0;

    print "LFsc4a: wd=$wd, emp=$emp, emp2=$emp2, pws=",join(" ",($pppwd,$ppwd,$pwd)),"\n" if ($debug>1);

    my (%sc0,%sc);
    my ($found,$pol,$sc)=(0);

    #----------------------------
    # matches in LF lexicon
    if ($lexhp->{$wd}) {
        $found=1;

        foreach my $wname('man','combo','prob') {
            
            my $lexsc= $lexhp->{$wd}{$wname};

            ($pol,$sc)=split//,$lexsc,2;

            $sc++ if ($emp);
            $sc++ if ($emp2);

            $sc0{$wname}=$sc;

            print "LFsc4b(lex): wd=$wd, pol=$pol, sc=$sc\n" if ($debug);

        } 
    } 

    #----------------------------
    # matches in LF regex
    else {

        # alread sorted in the match order of polarity-strength: p,n,m then 3,2,1
        #  - avoids sorting hash for each word
        my $index=0;
        foreach my $rgx(@{$rgxlp}) {

            if($wd=~/$rgx/i) {
                $found=1;

                ($pol,$sc)=split//,$rgxsclpM->[$index],2;
                $sc++ if ($emp);
                $sc++ if ($emp2);
                $sc0{'man'}=$sc;

                ($pol,$sc)=split//,$rgxsclpC->[$index],2;
                $sc++ if ($emp);
                $sc++ if ($emp2);
                $sc0{'combo'}=$sc;

                ($pol,$sc)=split//,$rgxsclpP->[$index],2;
                $sc++ if ($emp);
                $sc++ if ($emp2);
                $sc0{'prob'}=$sc;

                print "LFsc4c(rgx): rgx=$rgx, wd=$wd, pol=$pol, sc=$sc\n" if ($debug);

                last;  # stop at the first regex match

            } #end-if($wd=~/$rgx/i) 

            $index++;

        } #end-foreach 

        #  - check morph regex if repeat-char word
        if (!$found && $wd=~/([a-z])\1{2,}/i) {

            # alread sorted in the match order of polarity-strength: p,n,m then 3,2,1
            #  - avoids sorting hash for each word
            $index=0;
            foreach my $rgx(@{$mrplp}) {

                if($wd=~/$rgx/i) {
                    $found=1;

                    ($pol,$sc)=split//,$mrpsclpM->[$index],2;
                    $sc++ if ($emp);
                    $sc++ if ($emp2);
                    $sc0{'man'}=$sc;

                    ($pol,$sc)=split//,$mrpsclpC->[$index],2;
                    $sc++ if ($emp);
                    $sc++ if ($emp2);
                    $sc0{'combo'}=$sc;

                    ($pol,$sc)=split//,$mrpsclpP->[$index],2;
                    $sc++ if ($emp);
                    $sc++ if ($emp2);
                    $sc0{'prob'}=$sc;

                    print "LFsc4c(mrp): rgx=$rgx, wd=$wd, pol=$pol, sc=$sc\n" if ($debug);

                    last;  # stop at the first regex match

                } #end-if($wd=~/$rgx/i) 

                $index++;

            } #end-foreach

        } #end-if (!$found && $wd=~/([a-z])\1{2,}/i))

    } #end-else

    if ($found) {

        foreach my $wname('man','combo','prob') {
                    
            # opinion score
            $sc{0}{'sc'}{$wname} = $sc0{$wname};
                    
            # polarity score
            my($p,$n)=(0,0);
            if ($pol=~/[np]/) {
                ($p,$n)=&polSC0($pol,$sc0{$wname},$pwd,$ppwd,$pppwd,$neghp);
                $sc{0}{'scP'}{$wname} = $p;
                $sc{0}{'scN'}{$wname} = $n;
                print "LFsc4(q0): wd=$wd, pol=$pol, scp=$p, scn=$n\n" if ($debug);
            }

            # prox. match score
            foreach my $qn(keys %$prxhp) {
                my $prxmatch= $prxhp->{$qn};
                ($sc{$qn}{'scx'}{$wname},$sc{$qn}{'scxP'}{$wname},$sc{$qn}{'scxN'}{$wname})=(0,0,0);

                if ($prxmatch) {
                    $sc{$qn}{'scx'}{$wname} = $sc;
                    # polarity score
                    if ($pol=~/[np]/) {
                        $sc{$qn}{'scxP'}{$wname} = $p;
                        $sc{$qn}{'scxN'}{$wname} = $n;
                    }
                    print "LFsc4d-prxm(q$qn): scx=$sc{$qn}{'scx'}, scxp=$sc{$qn}{'scxP'}, scxn=$sc{$qn}{'scxN'}\n" if ($debug);
                }
            }

            # dist. match score !
            foreach my $qn(keys %$dsthp) {
                my $wdist= $dsthp->{$qn};
                ($sc{$qn}{'scd'}{$wname},$sc{$qn}{'scdP'}{$wname},$sc{$qn}{'scdN'}{$wname})=(0,0,0);

                if ($wdist<$maxwdist) {  # max. word distance
                    my $idist=1/log($wdist+2);
                    $sc{$qn}{'scd'}{$wname} = sprintf("%.4f",$sc*$idist);
                    # polarity score
                    if ($pol=~/[np]/) {
                        $sc{$qn}{'scdP'}{$wname} = sprintf("%.4f",$p*$idist);
                        $sc{$qn}{'scdN'}{$wname} = sprintf("%.4f",$n*$idist);
                    }
                }
                print "LFsc4-dist(q$qn): scd=$sc{$qn}{'scd'}, scdp=$sc{$qn}{'scdP'}, scdn=$sc{$qn}{'scdN'}\n" if ($debug);
            }
            # dist. match score !
            foreach my $qn(keys %$dst2hp) {
                my $wdist= $dst2hp->{$qn};
                ($sc{$qn}{'scd2'}{$wname},$sc{$qn}{'scd2P'}{$wname},$sc{$qn}{'scd2N'}{$wname})=(0,0,0);

                if ($wdist<$maxwdist) {  # max. word distance
                    my $idist=1/log($wdist+2);
                    $sc{$qn}{'scd2'}{$wname} = sprintf("%.4f",$sc*$idist);
                    # polarity score
                    if ($pol=~/[np]/) {
                        $sc{$qn}{'scd2P'}{$wname} = sprintf("%.4f",$p*$idist);
                        $sc{$qn}{'scd2N'}{$wname} = sprintf("%.4f",$n*$idist);
                    }
                }
                print "LFsc4-dist(q$qn): scd=$sc{$qn}{'scd'}, scdp=$sc{$qn}{'scdP'}, scdn=$sc{$qn}{'scdN'}\n" if ($debug);
            }
        }

    } #end-if ($found)

    return (%sc);

} #endsub LFsc7


#------------------------------------------------------------
# compute Weka opinion score (documen)
#-----------------------------------------------------------
#   arg1 = text to be scored
#   arg2 = filter model
#   r.v. = (class,sc)
#-----------------------------------------------------------
sub wekaDsc {
    my($qti,$text,$tlen,$lexhp1,$lexhp2)=@_;
    my $debug=0;

} #endsub wekaDsc


#-----------------------------------------------------------
#  compute term distance
#-----------------------------------------------------------
#  arg1 = position of wd1
#  arg2 = pointer to array of wd2 positions
#  r.v. = minimum number of words between wd1 & wd2
#-----------------------------------------------------------
sub minDist {
    my($pos,$poslp)=@_;

    my $min=10**3;

    foreach my $pos2(@$poslp) {
        my $diff=($pos-$pos2);
        if (abs($diff)<$min) {
            $min=abs($diff);
            last if ($diff<0);
        }
        elsif ($diff<0) { last; }
    }

    return $min;
}

#--------------------------------------------
# build the ad_v module
#--------------------------------------------
#   arg1 = reference to PSE hash
#   r.v. = updated PSE hash
#--------------------------------------------
sub build_ad_v{
    my ($mdir,$pseHash, $npseHash)=@_;
    #$mdir = "/u2/home/nyu/BLOG06/ad_v_Model/newLexicon"; #model directory
    #create hash for the ad_v lexicon
    my $file1 = "$mdir/PSE_clean.list"; #PSE file
    my $file2 = "$mdir/nonPSE_2.list"; #non-PSE file
    open(IN,$file1)||die "can't open file $file1\n";
    my @lines = <IN>;
    chomp@lines;
    close(IN);
    foreach (@lines){
       next if(/^[#|!]/);
       next if(/^\s*$/);
       #my($pse, $weight)= split($sep, $_);
       #$$pseHash{$_} = $weight;#we are not going to use this weight
       $$pseHash{$_} = 1;
    }

    open(IN,$file2)||die "can't open file $file2\n";
    @lines = <IN>;
    chomp@lines;
    close(IN);
    foreach (@lines){
       next if(/^[#|!]/);
       next if(/^\s*$/);
       #my($pse, $weight)= split($sep, $_);
       #$$npseHash{$_} = $weight;#we are not going to use this weight
       $$npseHash{$_} = 1;
    }
}#end of sub build_ad_v



1
