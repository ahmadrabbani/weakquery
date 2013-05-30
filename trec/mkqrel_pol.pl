#!/usr/bin/perl -w

my $ind='/u1/trec/qrels';
my $inf="$ind/qrels.opinion.blog06-07";
my $outP="$ind/qrels.pos.blog06-07";
my $outN="$ind/qrels.neg.blog06-07";

open(IN,$inf) || die "can't read $inf";
open(OP,">$outP") || die "can't write to $outP";
open(NP,">$outN") || die "can't write to $outN";

while(<IN>) {
    chomp;
    my($qn,$d,$id,$rel)=split/ +/;
    if ($rel==3) { $relp=1; $reln=1; }
    elsif ($rel==2) { $relp=1; $reln=2; }
    elsif ($rel==4) { $relp=2; $reln=1; }
    elsif ($rel==1) { $relp=1; $reln=1; }
    else { $relp=$rel; $reln=$rel; }
    print OP "$qn $d $id $relp\n";
    print NP "$qn $d $id $reln\n";
}
close IN;
close NP;
close OP;
