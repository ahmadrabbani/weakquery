#!/usr/bin/perl -w

use Getopt::Long qw(:config permute);

GetOptions(
"prob|p" => \$outformat,
"token|t" => \$tokenize,
"info|i+" => \$extraf,
"score|s:f" => \$threshold,
);

if (@ARGV<2) {
    die "\narg1= class model file\n",
        "arg2= email to classify\n",
        "arg3= classifier directory\n\n",
        " --prob=  output probability (default=spam|ham)\n",
        " --token= output tokens only (default=classify)\n",
        " --score= spam threshold score (default=0.9)\n",
        " --info=  output extra info (1=scores, 2=tokens)\n\n";
}

my ($model,$email,$bshome)= @ARGV;
#my ($outformat,$threshold,$tokenize,$extraf)=($opt{'f'},$opt{'s'},$opt{'t'},$opt{'x'});

$outformat=0 if (!defined($outformat));
$threshold=0.9 if (!defined($threshold));
$tokenize=0 if (!defined($tokenize));
$extraf=0 if (!defined($extraf));

print "m=$model, e=$email, home=$bshome\n";
print "f=$outformat, s=$threshold, t=$tokenize, x=$extraf\n";

