
$f1="/u3/trec/blog07/results/train2/trecfmtx/s0qxRf/okapi-bestR4_trec";
$f2="/u3/trec/blog07/results/test2/trecfmtx/s0qxRf/okapi-bestR4_trec";

$runin="best-okapiR4";
$runout="wdoqsBase";
$outf="submit/$runout";

open(OUT,">$outf") || die "can't write to $outf";

open(IN,$f1) || die "can't read $f1";
while(<IN>) {
    s/$runin/$runout/;
    print OUT;
}
close IN;

open(IN,$f2) || die "can't read $f2";
while(<IN>) {
    s/$runin/$runout/;
    print OUT;
}
close IN;
close OUT;

$f1="/u3/trec/blog07/results/train2/trecfmtx/s0R1/okapi_qlnvN.r1_trec";
$f2="/u3/trec/blog07/results/test2/trecfmtx/s0R1/okapi_qlnvN.r1_trec";

$runin="wdoqsx_qlnvN.";
$runout="wdoqlnvN";
$outf="submit/$runout";

open(OUT,">$outf") || die "can't write to $outf";

open(IN,$f1) || die "can't read $f1";
while(<IN>) {
    s/$runin/$runout/;
    print OUT;
}
close IN;

open(IN,$f2) || die "can't read $f2";
while(<IN>) {
    s/$runin/$runout/;
    print OUT;
}
close IN;
close OUT;
