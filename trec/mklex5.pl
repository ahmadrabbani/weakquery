#!/usr/bin/perl -w

# -----------------------------------------------------------------
# Name:      mklex5.pl
# Author:    Kiduk Yang, 5/01/2008
#             $Id: mklex5.pl,v 1.1 2008/06/27 00:43:22 kiyang Exp $
# -----------------------------------------------------------------
# Description:  convert merged term lists to lexicon files
# -----------------------------------------------------------------
# Argument:  arg1= 1 to run
# Input:     
#   $ddir/W1b.lst   - type=strongsubj 
#   $ddir/W2b.lst   - type=weaksubj 
#   $ddir/EMPb.lst  - emphasis lexicon 
#   $ddir/IU3b.lst  - IU lexicon
#   $ddir/HF3b.lst  - HF lexicon
#   $ddir/LF3b.lst  - LF lexicon
#   $ddir/LF3b.rgx  - LF regex
#   $ddir/LF3mrpb.rgx - LF morph regex
#   $ddir/AC2b.list   - AC lexicon
#   $ddir/W1m.lst   - type=strongsubj 
#   $ddir/W2m.lst   - type=weaksubj 
#   $ddir/EMPm.lst  - emphasis lexicon 
#   $ddir/IU3m.lst                   - IU lexicon
#   $ddir/HF3m.lst                   - HF lexicon
#   $ddir/LF3m.lst                   - LF lexicon
#   $ddir/LF3m.rgx                   - LF regex
#   $ddir/LF3mrpm.rgx                - LF morph regex
#   $ddir/AC2m.list                   - AC lexicon
#   $pdir/IU2.lst                   - IU lexicon
#   $pdir/HF2.lst                   - HF lexicon
#   $pdir/LF2.lst                   - LF lexicon
#   $pdir/LF2.rgx                   - LF regex
#   $pdir/LF2mrp.rgx                - LF morph regex
#   $pdir/AC.list                   - AC lexicon
# Output:   
#   $ddir/final/W1.lex   - type=strongsubj 
#   $ddir/final/W2.lex   - type=weaksubj 
#   $ddir/final/EMP.lex  - emphasis lexicon 
#   $ddir/final/LF.lex                   - LF lexicon
#       TERM:POL-MAN_WT:POL-COMB_WT:POL-PROB_WT
#   $ddir/final/IU.lex                   - IU lexicon
#       IU_Phrase:POL-MAN_WT:POL-COMB_WT:POL-PROB_WT
#   $ddir/final/HF.lex                   - HF lexicon
#       TERMs:POL-MAN_WT:POL-COMB_WT:POL-PROB_WT
#   $ddir/final/LFrgx.lex                - LF regex
#   $ddir/final/LFmrp.lex                - LF morph regex
#       REGEX POL-MAN_WT POL-COMB_WT POL-PROB_WT
#   $ddir/final/AC.list                   - AC lexicon
#       TERM(Phrase):POL-MAN_WT:POL-COMB_WT:POL-PROB_WT
#   $prog        -- program     (optional)
#   $prog.log    -- program log (optional)
# -----------------------------------------------------------------
# NOTE: uses clean training data generated by mklex2.pl
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
my $pdir=   "$tpdir/blog";              # Blog track program directory
my $pdir0=   "$wpdir/trec07/blog";              # Blog track program directory
my $ddir=   "/u3/trec/blog07";          # TREC index directory

my $odir= "$ddir/lex2";
my $odir0= "$ddir/lex";

# input files
my $w1A= "$odir/W1b.list";
my $w2A= "$odir/W2b.list";
my $emA= "$odir/EMb.list";
my $iuA= "$odir/IU3b.list";                  # IU lexicon file
my $hfA= "$odir/HF3b.list";                  # HF lexicon file
my $lfA= "$odir/LF3b.list";                  # LF lexicon file
my $lfrA="$odir/LF3b.rgx";                   # LF regex file
my $lfmA="$odir/LF3mrpb.rgx";                # LF morph regex file
my $acA= "$odir/AC2b.list";                   # AC lexicon file

my $w1B= "$odir/W1m.list";
my $w2B= "$odir/W2m.list";
my $emB= "$odir/EMm.list";
my $iuB= "$odir/IU3m.list";                  # IU lexicon file
my $hfB= "$odir/HF3m.list";                  # HF lexicon file
my $lfB= "$odir/LF3m.list";                  # LF lexicon file
my $lfrB="$odir/LF3m.rgx";                   # LF regex file
my $lfmB="$odir/LF3mrpm.rgx";                # LF morph regex file
my $acB= "$odir/AC2m.list";                   # AC lexicon file

my $iulex= "$pdir0/IU2.list";                  # IU lexicon file
my $hflex= "$pdir0/HF2.list";                  # HF lexicon file
my $lflex= "$pdir0/LF2.list";                  # LF lexicon file
my $lfrlex= "$pdir0/LF2.rgx";                   # LF regex file
my $lfmlex= "$pdir0/LF2mrp.rgx";                # LF morph regex file
my $aclex= "$pdir0/AC.list";                   # AC lexicon file
my $w1lex= "$odir0/wilson_strongsubj.lex"; # strong subj. lexicon
my $w2lex= "$odir0/wilson_weaksubj.lex";   # strong subj. lexicon
my $emlex= "$odir0/wilson_emp.lex";        # emphasis lexicon

# output files
my $w1out= "$odir/final/W1.lex";
my $w2out= "$odir/final/W2.lex";
my $emout= "$odir/final/EM.lex";
my $iuout= "$odir/final/IU.lex";                  # IU lexicon file
my $hfout= "$odir/final/HF.lex";                  # HF lexicon file
my $lfout= "$odir/final/LF.lex";                  # LF lexicon file
my $lfrout="$odir/final/LFrgx.lex";                   # LF regex file
my $lfmout="$odir/final/LFmrp.lex";                # LF morph regex file
my $acout= "$odir/final/AC.lex";                   # AC lexicon file

require "$wpdir/logsub2.pl";   # subroutine library
require "$pdir/blogsub.pl";   # blog subroutine library

`mkdir -p $odir/final` if (!-e "$odir/final");


#------------------------
# program arguments
#------------------------
my $prompt=
"arg1= 1 to run\n";

my %valid_args= (
0 => " 1 ",
);

my ($arg_err,$arg1)= chkargs($prompt,\%valid_args,1);
die "$arg_err\n" if ($arg_err);


#-------------------------------------------------
# start program log
#-------------------------------------------------

$sfx= "";              # program log file suffix
$noargp=1;             # if 1, do not print arguments to log
$append=0;             # log append flag

if ($log) {
    @start_time= &begin_log($odir,$filemode,$sfx,$noargp,$append);
    print LOG "INF = $odir/*b.list, *m.list\n",
              "      $pdir0/*.list\n",
              "OUTF= $odir/final/*.lex\n\n";
}



#-------------------------------------------------
# 1. process non-opinion training data
# 2. compute term frequencies
#    - { term => op|nop => df }
#-------------------------------------------------

my (%HF,%LF,%LFr,%LFm,%AC,%W1,%W2,%EM,%IU);

&mkLexHash($hfA,$hfB,\%HF);
&mkHFlex($hflex,$hfout,\%HF,3);

&mkLexHash($acA,$acB,\%AC);
&mklex($aclex,$acout,\%AC,':',30,10);

&mkLexHash($w1A,$w1B,\%W1);
&mkwlex($w1lex,$w1out,\%W1,3);

&mkLexHash($w2A,$w2B,\%W2);
&mkwlex($w2lex,$w2out,\%W2,3);

&mkLexHash($emA,$emB,\%EM);
&mkwlex($emlex,$emout,\%EM,3,'m1');

&mkLexHash($lfA,$lfB,\%LF);
&mklex($lflex,$lfout,\%LF,':',3);

&mkLexHash($lfrA,$lfrB,\%LFr);
&mklex($lfrlex,$lfrout,\%LFr,' ',3);

&mkLexHash($lfmA,$lfmB,\%LFm);
&mklex($lfmlex,$lfmout,\%LFm,' ',3);

&mkLexHash($iuA,$iuB,\%IU);
&mkIUlex($iulex,$iuout,\%IU,3);


#-------------------------------------------------
# end program
#-------------------------------------------------

&end_log($pdir,$odir,$filemode,@start_time) if ($log);

# notify author of program completion
#&notify($sfx,$author);


##############################################
# SUBROUTINES
##############################################

BEGIN { print STDOUT "\n"; }
END { print STDOUT "\n"; }

#-------------------------------------------------
# create a lexicon hash
#-------------------------------------------------
#  arg1 = term list 1
#  arg2 = term list 2
#  arg3 = pointer to lex hash (term => wt)
#-------------------------------------------------
sub mkLexHash {
    my($in1,$in2,$hp)=@_;

    open(IN,"$in1") || die "can't read $in1";
    while(<IN>) {
        chomp;
        my($wd,$wt)=split/ /;
        $hp->{$wd}=$wt;
    }
    close IN;

    open(IN,"$in2") || die "can't read $in2";
    while(<IN>) {
        chomp;
        my($wd,$wt)=split/ /;
        $hp->{$wd}=$wt if (!$hp->{$wd} || $wt>$hp->{$wd});
    }
    close IN;

}

#-------------------------------------------------
# ouput updated lexicon file
#-------------------------------------------------
#  arg1 = input lexicon file 
#  arg2 = output lexicon file 
#  arg3 = pointer to lex hash
#  arg4 = field delimiter
#  arg5 = max manual weight
#  arg6 = weight multiplication factor
#-------------------------------------------------
sub mklex {
    my($inf,$outf,$hp,$sep,$maxsc,$rate)=@_;

    $sep=':' if (!$sep);
    
    open(OUT,">$outf") || die "can't write to $outf";
    print LOG " - Writing to $outf\n";
    
    open(IN,"$inf") || die "can't read $inf";
    while(<IN>) {
        chomp;
        my ($str0,$sc)=split/$sep/;
        $sc=~/^([npm])(.+)$/;
        my($pol,$sc2)=($1,$2);
        
        my $wd=$str0;
        $wd=~s/\(.+?\)//;
        
        my $wt=-1;
        $wt=$hp->{$wd} if ($hp->{$wd} && $hp->{$wd}>$wt);

        $wt=0.0001 if ($wt<=0);

        my $wt2=-1;
        $wt2=$hp->{$wd} if ($hp->{$wd} && $hp->{$wd}>$wt2);
        
        $wt2=$sc2/$maxsc if ($wt2<=0);
        $wt2*=$rate if ($rate);
        
        printf OUT "$str0$sep$sc$sep$pol%.1f$sep$pol%.3f\n", $sc2*$wt*1000, $wt2*100;
    }
    close IN;
    close OUT;
    print LOG "\n";

} #endsub mklex



#-------------------------------------------------
# ouput updated lexicon file
#-------------------------------------------------
#  arg1 = input lexicon file 
#  arg2 = output lexicon file 
#  arg3 = pointer to lex hash
#  arg4 = max manual weight
#-------------------------------------------------
sub mkwlex {
    my($inf,$outf,$hp,$maxsc,$score)=@_;
    
    open(OUT,">$outf") || die "can't write to $outf";
    print LOG " - Writing to $outf\n";
    
    open(IN,"$inf") || die "can't read $inf";
    while(<IN>) {
        chomp;
        my($wd,$value)=split/ /;

        my($pol,$sc2);

        if ($score) {
            $score=~/^([npm])(.+)$/;
            ($pol,$sc2)=($1,$2);
        }
        else {
            if ($value=~/pos/) { $pol='p'; }
            elsif ($value=~/neg/) { $pol='n'; }
            else { $pol='m'; }
            if ($value=~/strong/) { $sc2=3; }
            elsif ($value=~/weak/) { $sc2=1; }
            else { $sc2=2; }
        }

        my $wt=-1;
        $wt=$hp->{$wd} if ($hp->{$wd} && $hp->{$wd}>$wt);
        $wt=0.0001 if ($wt<=0);

        my $wt2=-1;
        $wt2=$hp->{$wd} if ($hp->{$wd} && $hp->{$wd}>$wt2);
        $wt2=$sc2/$maxsc if ($wt2<=0);

        printf OUT "$wd:$pol$sc2:$pol%.1f:$pol%.3f\n", $sc2*$wt*1000, $wt2*100;
    }
    close IN;
    close OUT;
    print LOG "\n";

} #endsub mkwlex



#-------------------------------------------------
# ouput updated lexicon file
#-------------------------------------------------
#  arg1 = input lexicon file 
#  arg2 = output lexicon file 
#  arg3 = pointer to lex hash
#  arg4 = max manual weight
#-------------------------------------------------
sub mkHFlex {
    my($inf,$outf,$hp,$maxsc)=@_;

    open(OUT,">$outf") || die "can't write to $outf";
    print LOG " - Writing to $outf\n";

    open(IN,"$inf") || die "can't read $inf";
    while(<IN>) {
        chomp;
        my($str0,$sc)=split/:/;
        $sc=~/^([npm])(.+)$/;
        my($pol,$sc2)=($1,$2);
        my $str=$str0;
        $str=~tr/A-Z/a-z/;  # conver to lowercase

        my ($wt,$wt2)=(-1,-1);

        if ($str=~/,/) {
            my @wds=split/,/,$str;
            foreach my $wd(@wds) {
                $wt=$hp->{$wd} if ($hp->{$wd} && $hp->{$wd}>$wt);
                $wt2=$hp->{$wd} if ($hp->{$wd} && $hp->{$wd}>$wt2);
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
            foreach my $wd($str,$past,$ing,$now3) {
                $wt=$hp->{$wd} if ($hp->{$wd} && $hp->{$wd}>$wt);
                $wt2=$hp->{$wd} if ($hp->{$wd} && $hp->{$wd}>$wt2);
            }
        }
        elsif ($str=~s/\(n\)//) {
            # plural
            if ($str=~/s$/) { $str .= "es";  }
            elsif ($str=~/^(.+[^aieou])y$/) { $str=$1."ies";  }
            else { $str .= "s"; }
            foreach my $wd($str0,$str) {
                $wt=$hp->{$wd} if ($hp->{$wd} && $hp->{$wd}>$wt);
                $wt2=$hp->{$wd} if ($hp->{$wd} && $hp->{$wd}>$wt2);
            }
        }
        else {
            # compress hyphens
            if ($str=~/-/) {
                $str=~s/-//g;
            }
            foreach my $wd($str0,$str) {
                $wt=$hp->{$wd} if ($hp->{$wd} && $hp->{$wd}>$wt);
                $wt2=$hp->{$wd} if ($hp->{$wd} && $hp->{$wd}>$wt2);
            }
        }


        $wt=0.0001 if ($wt<=0);
        $wt2=$sc2/$maxsc if ($wt2<=0);

        printf OUT "$str0:$sc:$pol%.1f:$pol%.3f\n", $sc2*$wt*1000, $wt2*100;
    }
    close IN;
    close OUT;
    print LOG "\n";

} #endsub mkHFlex


#-------------------------------------------------
# ouput updated lexicon file
#-------------------------------------------------
#  arg1 = input lexicon file 
#  arg2 = output lexicon file 
#  arg3 = pointer to lex hash
#  arg4 = max manual weight
#-------------------------------------------------
sub mkIUlex {
    my($inf,$outf,$hp,$maxsc)=@_;

    open(OUT,">$outf") || die "can't write to $outf";
    print LOG " - Writing to $outf\n";

    open(IN,"$inf") || die "can't read $inf";
    while(<IN>) {
        chomp;
        my($iu0,$sc)=split/:/;
        $sc=~/^([npm])(.+)$/;
        my($pol,$sc2)=($1,$2);

        my $iu=lc($iu0);

        my ($wt,$wt2)=(-1,-1);

        if ($iu=~/^I (.+)$/i) {
            my $term=$1;
            if ($term=~/,/) {
                my($now,$past,$ing)=split/,/,$term;
                foreach my $wd($past,$ing,$now) {
                    $wt=$hp->{$wd} if ($hp->{$wd} && $hp->{$wd}>$wt);
                    $wt2=$hp->{$wd} if ($hp->{$wd} && $hp->{$wd}>$wt2);
                }
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
                foreach my $wd($past,$ing,$term) {
                    $wt=$hp->{$wd} if ($hp->{$wd} && $hp->{$wd}>$wt);
                    $wt2=$hp->{$wd} if ($hp->{$wd} && $hp->{$wd}>$wt2);
                }
            }
        }  
        elsif ($iu=~/^I'm ([^ ]+)/i) {
            my $wd=$1;
            $wt=$hp->{$wd} if ($hp->{$wd} && $hp->{$wd}>$wt);
            $wt2=$hp->{$wd} if ($hp->{$wd} && $hp->{$wd}>$wt2);
        }    
        elsif ($iu=~/^my (.+)$/i) {
            my $term=$1;
            # plural
            my $terms;
            if ($term=~/s$/) { $terms=$term."es";  }
            elsif ($term=~/^(.+[^aieou])y$/) { $terms=$1."ies";  }
            else { $terms=$1."s"; }
            foreach my $wd($term,$terms) {
                $wt=$hp->{$wd} if ($hp->{$wd} && $hp->{$wd}>$wt);
                $wt2=$hp->{$wd} if ($hp->{$wd} && $hp->{$wd}>$wt2);
            }
        }
        elsif ($iu=~/^(.+) me$/i) {
            my $term=$1; 
            if ($term=~/^(.+?) for$/) { 
                my $wd=$1;
                $wt=$hp->{$wd} if ($hp->{$wd} && $hp->{$wd}>$wt);
                $wt2=$hp->{$wd} if ($hp->{$wd} && $hp->{$wd}>$wt2);
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
                    foreach my $wd($now,$past,$ing,$now3) {
                        $wt=$hp->{$wd} if ($hp->{$wd} && $hp->{$wd}>$wt);
                        $wt2=$hp->{$wd} if ($hp->{$wd} && $hp->{$wd}>$wt2);
                    }
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
                    foreach my $wd($term,$past,$ing,$now3) {
                        $wt=$hp->{$wd} if ($hp->{$wd} && $hp->{$wd}>$wt);
                        $wt2=$hp->{$wd} if ($hp->{$wd} && $hp->{$wd}>$wt2);
                    }
                }
            }
        }

        $wt=0.0001 if ($wt<=0);
        $wt2=$sc2/$maxsc if ($wt2<=0);

        printf OUT "$iu0:$sc:$pol%.1f:$pol%.3f\n", $sc2*$wt*1000, $wt2*100;
    }
    close IN;
    close OUT;
    print LOG "\n";

} #endsub mkIUlex

