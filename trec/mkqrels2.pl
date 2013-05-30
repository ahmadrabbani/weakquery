#!/usr/bin/perl -w

$ind= '/u3/trec/blog06/eval/train';
$outf= '/u1/trec/qrels/qrels.blog06train.txt2';

open(OUT,">$outf") || die "can't write to $outf";
for($qn=1;$qn<=12;$qn++) {
    open(IN,"$ind/$qn.qrel") || die "can't read $ind/$qn.qrel";
    while(<IN>) {
        chomp;
        my($dn,$rel0)=split/ /;
        $rel0=~s/\(\d+\)//g;
        if ($rel0=~/#/) {
            my(@rels)=split/#/,$rel0;
            $rel=$rels[-1];
        }
        else {
            $rel=$rel0;
        }
        $rel=-2 if ($rel=~/0.5/);
        print OUT "$qn 0 $dn $rel\n";
    }
    close IN;
}
