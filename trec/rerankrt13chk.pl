#!/usr/bin/perl -w

my $rsubd='s0base';

my $ind1="/u3/trec/blog07/results/s0/rrsc7x";
my $ind2="/u3/trec/blog07/results/s0/rrsc7x/tmp";

&chkrrf($ind1);
&chkrrf($ind2);

sub chkrrf {
    my $ind=shift;

    opendir(IND,$ind) || die "can't opendir $ind";
    my @files= readdir(IND);
    closedir IND;

    foreach my $file(@files) {

        my $ftype;

        # *.1 = query-independent score file
        # *.2 = query-dependent score file
        if ($file =~ /\.1$/) { $ftype=1; }
        elsif ($file =~ /\.2$/) { $ftype=0; }
        else { next; }

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

                print "  $docID, tlen=$tlen, emp=$empsc\n" if (!defined($avsc) || $avsc!~/=/ || $avsc!~/AV/);  # skip incomplete lines

            }

            # query-dependent scores
            # ti2, bd2: match of individual query terms
            else {

                my ($docID,$qn,$ti,$bd,$ti2,$bd2,$tix,$bdx,$bdx2,$ph,$ph2,$nrph,$nrn,
                    $acx,$acd,$acd2,$hfx,$hfd,$hfd2,$iux,$iud,$iud2,$lfx,$lfd,$lfd2,
                    $w1x,$w1d,$w1d2,$w2x,$w2d,$w2d2,$empx,$empd,$empd2,$avx)=split/\s+/;

                print "  $docID, qn=$qn, empd2=$empd2\n"  if (!defined($avx) || $avx!~/=/ || $avx!~/AV/);  # skip incomplete lines

            }
        }
    }

}
