
$rdir="/u3/trec/blog08/results";
$rsubd= "trecfmtx/s0baseRd";
$rsubc= "trecfmtx/s0baseRc";
$rsubdf= "trecfmtx/s0baseRdf";

%fname=(
"$rsubd/top3f-dt1-m.r2_trec"=>'top3dt1mRd',
"$rsubc/top3f-wt1-m.r2_trec"=>'top3wt1mRc',
"$rsubd/base4-dt1-m.r2_trec"=>'b4dt1mRd',
"$rsubd/base4-dt1-p.r2_trec"=>'b4dt1pRd',

"$rsubd/base5-dt1-m.r2_trec"=>'b5dt1mRd',
"$rsubd/base5-dt1-p.r2_trec"=>'b5dt1pRd',
"$rsubc/base5-wt1-m.r2_trec"=>'b5wt1mRc',
"$rsubc/base5-wt1-p.r2_trec"=>'b5wt1pRc',

"$rsubd/wdoqf-dt1-m.r2_trec"=>'wdqfdt1mRd',
"$rsubd/wdoqf-dt1-p.r2_trec"=>'wdqfdt1pRd',
"$rsubd/wdoqsBase-dt1-m.r2_trec"=>'wdqbdt1mRd',
"$rsubd/wdoqsBase-dt1-p.r2_trec"=>'wdqbdt1pRd',
);

foreach $file(keys %fname) {
    my $f1= "$rdir/train/$file";
    my $f2= "$rdir/test/$file";

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
    close OUT;

}
