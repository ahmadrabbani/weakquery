#!/usr/bin/perl -w

#----------------------------------------------------
# NOTE: manually move files to "old" directory first
#----------------------------------------------------

if (@ARGV<1) { die "arg1=rset number\n"; }
my ($rsetn)=@ARGV;

my $rsubd='s0base';

my $out1="/u3/trec/blog07/results/s0/rrsc7x";
my $in1= "$out1/old";

&mergeRRSC($in1,$out1);

my $out2="/u3/trec/blog07/results/s0/rrsc7x/tmp";
my $in2= "$out2/old";

&mergeRRSC($in2,$out2);

# consolidate RRSC files
sub mergeRRSC {
    my ($ind,$outd)=@_;

    opendir(IND,$ind) || die "can't opendir $ind";
    my @files= readdir(IND);
    closedir IND;

    my (%line1,%line2);

    foreach my $file(@files) {

        my ($ftype,$qtype);

        # *.1 = query-independent score file
        # *.2 = query-dependent score file
        if ($file =~ /\.1$/) { $ftype=1; }
        elsif ($file =~ /\.2$/) { $ftype=0; }
        else { next; }

        if ($file=~/^e/) { $qtype='e'; }
        else { $qtype='t'; }

        my $inf= "$ind/$file";

        print "Reading $inf\n"; 

        open(IN,$inf) || die "can't read $inf";
        my @lines=<IN>;
        close IN;

        foreach (@lines) {
            chomp;
            
            # query-independent scores
            #  - $qn=0
            if ($ftype) {

                my $qn=0;  
                my ($docID,$tlen,$iucnt1,$iucnt2,$acsc,$hfsc,$iusc,$lfsc,$w1sc,$w2sc,$empsc,$avsc)=split/\s+/;

                next if (!defined($avsc) || $avsc!~/=/);  # skip incomplete lines

                $line1{$docID}=$_;

            }

            # query-dependent scores
            # ti2, bd2: match of individual query terms
            else {

                my ($docID,$qn,$ti,$bd,$ti2,$bd2,$tix,$bdx,$bdx2,$ph,$ph2,$nrph,$nrn,
                    $acx,$acd,$acd2,$hfx,$hfd,$hfd2,$iux,$iud,$iud2,$lfx,$lfd,$lfd2,
                    $w1x,$w1d,$w1d2,$w2x,$w2d,$w2d2,$empx,$empd,$empd2,$avx)=split/\s+/;

                next if (!defined($avx) || $avx!~/=/);  # skip incomplete lines

                $line2{$qtype}{$docID}{$qn}=$_;
            }
        }
    }

    print "\n";

    my $outf1= "$outd/$rsubd-$rsetn.1";
    print "writing to $outf1\n";
    open(OUT,">$outf1") || die "can't write to $outf1";
    foreach my $docID(keys %line1) {
        print OUT "$line1{$docID}\n";
    }
    close OUT;

    my $outf2t= "$outd/tx-$rsubd-$rsetn.2";
    print "writing to $outf2t\n";
    my $qt='t';
    open(OUT,">$outf2t") || die "can't write to $outf2t";
    foreach my $docID(keys %{$line2{$qt}}) {
        foreach my $qn(keys %{$line2{$qt}{$docID}}) {
            print OUT "$line2{$qt}{$docID}{$qn}\n";
        }
    }
    close OUT;


    my $outf2e= "$outd/ex-$rsubd-$rsetn.2";
    print "writing to $outf2e\n\n";
    $qt='e';
    open(OUT,">$outf2e") || die "can't write to $outf2e";
    foreach my $docID(keys %{$line2{$qt}}) {
        foreach my $qn(keys %{$line2{$qt}{$docID}}) {
            print OUT "$line2{$qt}{$docID}{$qn}\n";
        }
    }
    close OUT;

} #endsub



