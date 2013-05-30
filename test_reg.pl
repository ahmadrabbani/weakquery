#!/usr/bin/perl -w

use strict;
use warnings;

my $str = "Women on Numb3rs";
$str =~ s/\bthe\b\s+?|\bon\b\s+?|\band\b\s+?|\bfor\b\s+?|\bin\b\s+?|\bof\b\s+?//g;;
print "str:" . $str . "::stop" . "\n";