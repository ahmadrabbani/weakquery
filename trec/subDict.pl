#!/usr/bin/perl -w

# -----------------------------------------------------------------------------
# Name:      subDict.pl
# Author:    Kiduk Yang, 7/16/2007
#              $Id: subDict.pl,v 1.2 2007/07/20 16:37:58 kiyang Exp $
# -----------------------------------------------------------------------------
# Description:  
#   1. create a word list of target type from bigdict.dat
# -----------------------------------------------------------------------------
# Arguments: arg1 = word type
#              N=noun, V=verb, A=adjective, R=adverb, P=proper noun, 
#              a=article, ab=abbreviation, c=conjunction, pn=pronoun, pp=preposition, pr=prefix, x=other
#            arg2 = exclusion flag (optional: if 1, exclude non-letter words and capitalized words)
#            arg3 = output filename (optional: output to STDOUT if 1)
# Input:     /u0/widit/prog/nstem/bigdict.dat
# Output:    $pdir/$outf     -- word list
#            $pdir/$outf.log -- program log
# -----------------------------------------------------------------------------
# NOTE:
# -----------------------------------------------------------------------------

$inf= "/u0/widit/prog/nstem/bigdict.dat";

%tagmap=(
'A'=>'O',
'R'=>'P',
'N'=>'KLM',
'P'=>'N', 
'V'=>'GHIJ',
'a'=>'RS',
'ab'=>'Y',
'c'=>'V',
'pn'=>'Q',
'pp'=>'T',
'pr'=>'U',
);

if (@ARGV<1) {
    print "arg1= word type\n",
        "  A  = adjective\n",
        "  R  = adverb\n",
        "  N  = noun\n",
        "  P  = proper noun\n", 
        "  V  = verb\n",
        "  a  = article\n",
        "  ab = abbreviation\n",
        "  c  = conjunction\n",
        "  pn = pronoun\n",
        "  pp = preposition\n",
        "  pr = prefix\n",
        "  x = other\n",
        "arg2 = exclusion tags (optional)\n",
        "arg3 = exclusion flag (optional: if 1, exclude non-letter & capitalized words)\n",
        "arg4= debug flag (optional)\n",
        "arg5= output file (optional: output to STDOUT if missing)\n\n";
    die;
}
($intag,$xtag,$xflag,$debug,$outf)=@ARGV;

foreach $c(split//,$intag) { 
    # create tag string
    $tags .= $tagmap{$c}; 
}
foreach $c(split//,$xtag) { 
    # create tag string
    $xtags .= $tagmap{$c}; 
}
    print "tag=$tags, xtag=$xtags\n" if ($debug);


open(IN,$inf) || die "can't read $inf";
while(<IN>) {
    chomp;
    my ($wd,$p,$tag,$m)=unpack("A23 A23 A23 A*",$_);
    # exclude tags
    if ($xtags && $tag=~/[$xtags]/) {
        print "xd: $wd,\n" if ($debug);
        $xdict{lc($wd)}=$_;
        next;
    }
    next if ($tag !~ /[$tags]/);  # include target word type only
    next if ($xflag && $wd=~/[^a-zA-Z]/ || $wd=~/^[A-Z]/);
        print "$_\n" if ($debug);
    $dict{$wd}=$_;
}
close IN;

if ($outf) {
    open(OUT,">$outf") || die "can't write to $outf";
    foreach $wd(sort keys %dict) {
        next if ($xdict{lc($wd)});
        print OUT "$wd\n";
    }
    close OUT;

    $logf="$outf.log";
    chomp($date=`date`);
    open(OUT2,">$logf") || die "can't write to $logf";
    print OUT2 "$outf created by $0, $date\n";
    print OUT2 " - intag=$intag, xtag=$xtag\n";
    print OUT2 " - non-letter & capitalized words are excluded\n" if ($xflag);
    close OUT2;
}
else {
    foreach $wd(sort keys %dict) {
        next if ($xdict{lc($wd)});
        print "$wd\n";
    }
}
