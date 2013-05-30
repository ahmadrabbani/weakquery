#!/usr/bin/perl -w

#
# Kiduk Yang, 6/13/2008

# 1. split TREC official baseline files into training (topic 851-950) and test (topic 1001-1050) files  
# 2. copy to appropriate result directories
#

use strict;

my $ind= '/u0/widit/prog/trec08/blog/baseline';
my $outd1= '/u3/trec/blog08/results/train/trecfmtx/s0base';
my $outd2= '/u3/trec/blog08/results/test/trecfmtx/s0base';

foreach my $dir($outd1,$outd2) {
    `mkdir -p $dir` if (!-e $dir);
}

for(my $i=1; $i<=5; $i++) {

    my $inf= "$ind/baseline$i";
    my $outf1= "$outd1/base$i"."_trec";
    my $outf2= "$outd2/base$i"."_trec";

    open(IN,$inf) || die "can't read $inf";
    open(OUT1,">$outf1") || die "can't write to $outf1";
    open(OUT2,">$outf2") || die "can't write to $outf2";

    while (<IN>) {
        my $qn;
        if (/^(\d+)\s/) { $qn=$1; }
        else { die "Bad record in $inf\n$_"; }

        if ($qn>1000) { print OUT2; }
        else { print OUT1; }

    }

    close IN;
    close OUT1;
    close OUT2;

}

my $ind2= '/u0/widit/prog/trec08/blog/submit';

foreach my $file("wdoqsBase","wdoqlnvN") {

    my $inf= "$ind2/$file";
    my $outf1= "$outd1/$file"."_trec";
    my $outf2= "$outd2/$file"."_trec";

    open(IN,$inf) || die "can't read $inf";
    open(OUT1,">$outf1") || die "can't write to $outf1";
    open(OUT2,">$outf2") || die "can't write to $outf2";

    while (<IN>) {
        my $qn;
        if (/^(\d+)\s/) { $qn=$1; }
        else { die "Bad record in $inf\n$_"; }

        if ($qn>1000) { print OUT2; }
        else { print OUT1; }

    }

    close IN;
    close OUT1;
    close OUT2;

}
