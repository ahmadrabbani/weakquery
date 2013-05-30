#!/usr/bin/perl -w

$rdir="/u3/trec/blog08/results";
$rsubd= "trecfmtx/s0baseRdPOL5";

%fname=(

"$rsubd/top3f-dt1-m.r2-rr1"=>'top3dt1mP5',
"$rsubd/top3f-dt1-p.r2-rr1"=>'top3dt1pP5',

"$rsubd/base4-dt1-m.r2-rr1"=>'b4dt1mP5',
"$rsubd/base4-dt1-p.r2-rr1"=>'b4dt1pP5',

"$rsubd/wdoqsBase-dt1-m.r2-rr1"=>'wdqbdt1mP5',
"$rsubd/wdoqsBase-dt1-p.r2-rr1"=>'wdqbdt1pP5',
);

foreach $file(keys %fname) {
    my $f1= "$rdir/train/$file"."P_trec";
    my $f2= "$rdir/test/$file"."P_trec";

    $runout=$fname{$file};

    my $outf="submit/$runout";
    open(OUT,">$outf") || die "can't write to $outf";

    open(IN,$f1) || die "can't read $f1";
    while(<IN>) {
        my($qn,$q0,$docno,$rank,$score,$run)=split/\s+/;
        $score += (1/$rank);
        printf OUT "%-4s  Q0   %-32s  %7d   %11.6f   $runout\n", $qn,$docno,$rank,$score;
    }
    close IN;

    open(IN,$f2) || die "can't read $f2";
    while(<IN>) {
        my($qn,$q0,$docno,$rank,$score,$run)=split/\s+/;
        $score += (1/$rank);
        printf OUT "%-4s  Q0   %-32s  %7d   %11.6f   $runout\n", $qn,$docno,$rank,$score;
    }
    close IN;

    print OUT "\n";

    $f1= "$rdir/train/$file"."N_trec";
    $f2= "$rdir/test/$file"."N_trec";

    open(IN,$f1) || die "can't read $f1";
    while(<IN>) {
        my($qn,$q0,$docno,$rank,$score,$run)=split/\s+/;
        $score += (1/$rank);
        printf OUT "%-4s  Q0   %-32s  %7d   %11.6f   $runout\n", $qn,$docno,$rank,$score;
    }
    close IN;

    open(IN,$f2) || die "can't read $f2";
    while(<IN>) {
        my($qn,$q0,$docno,$rank,$score,$run)=split/\s+/;
        $score += (1/$rank);
        printf OUT "%-4s  Q0   %-32s  %7d   %11.6f   $runout\n", $qn,$docno,$rank,$score;
    }
    close IN;

    close OUT;

}
