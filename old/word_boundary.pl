#!/usr/bin/perl -w
use strict;

my $string = "new-york times square";
my $pattern = "new york";

my $match = $string =~ /\b$pattern\b/i;
print "match: $match\n";