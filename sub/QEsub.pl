###########################################################
# subroutines for query expansion
#   - Kiduk Yang, 4/2008
#----------------------------------------------------------
# minDist:     compute term distance
# LCA:         compute LCA term weights
# comboqry1:   combine wk & gg_ts terms with orig qry
# comboqry2:   combine wk, gg_ts, & gg_ft terms with orig qry
# comboqry3:   combine wk, gg_ts, & gg_ft terms with orig qry
#               - add phrase components and remove stopwords
# comboqry4:   combine wk, gg_ts, & gg_ft terms with orig qry
#               - select top term and phrase
###########################################################


#-----------------------------------------------------------
#  compute term distance
#-----------------------------------------------------------
#  arg1 = position of wd1
#  arg2 = pointer to array of wd2 positions
#  r.v. = minimum number of words between wd1 & wd2
#-----------------------------------------------------------
sub minDist {
    my($pos,$poslp)=@_;

    my $min=10**3; 
    
    foreach my $pos2(@$poslp) {
        my $diff=($pos-$pos2);
        if (abs($diff)<$min) {
            $min=abs($diff);
            last if ($diff<0);
        }
        elsif ($diff<0) { last; }
    }

    return $min; 
}   



#-----------------------------------------------------------
#  compute LCA term weights
#-----------------------------------------------------------
#  arg1 = working directory
#  arg2 = pointer to query term hash
#  arg3 = number of docs to process
#  arg4 = ptr to term wt hash
#  arg5 = ptr to stopwd hash
#  arg6 = #words for each document to use in LCA (default=300)
#  arg7 = seq.index directory prefix (default=seq)
#  arg8 = filename prefix (default= r)
#  arg9 = file extension (default= txt)
#-----------------------------------------------------------
#  INPUT:  $arg1/$arg7$N.$arg8  (e.g., $dir/r1.txt)
#  OUTPUT: $arg1/seq$arg3/r$N   (e.g., $dir/seq20/r1)
#-----------------------------------------------------------
sub LCA {
    my($dir,$qwhp,$maxN,$wthp,$sthp,$maxwdcnt,$sqpfx,$fpfx,$fext)=@_;

    my %coFrqAll;     # co(c,wi) = sum(tfNorm*qtfNorm)

    my $dirmode= 0750;                      # to use w/ perl mkdir
    my $group= "trec";                      # group ownership of files

    my ($mindlen,$maxdlen)=(10,1000);
    $maxwdcnt=300 if (!$maxwdcnt);
    $fpfx='r' if (!$fpfx);
    $fext='txt' if (!$fext);

    my $outd;
    if ($sqpfx) { $outd="$dir/$sqpfx$maxN"; }
    else { $outd="$dir/seq$maxN"; }

    if (!-e $outd) {
        my @errs=&makedir($outd,$dirmode,$group);
        print "\n",@errs,"\n\n" if (@errs);
    }

    my $debug2=0;

    # process top n results from a single query.
    my ($fn,$LCAcnt)=(0,1);
    while ($LCAcnt<=$maxN && $fn<=100) {

        $fn++;

        my $inf= "$dir/$fpfx$fn.$fext";

        next if (!-e $inf);
        print "Processing $inf\n" if ($debug2); 

        open(DATA,$inf) || die "can't read $inf";
        my @lines=<DATA>;
        close DATA;
        chomp @lines;

        my $body=join(" ",@lines);

        $body=~s/\s+\W+/ /g;
        $body=~s/\W+\s+/ /g;
        $body=~s/[\(\)\[\]]+/ /g;
        $body=~s/[^\n\x20-\x80]+/ /gs;

        # exclude email addresses
        $body=~s|\S+@\S+||g;

        # HTML stopwords
        $body=~s!\bshopping list|shopping cart|http://\b!!xig;
        $body=~s!\bgoogle|yahoo|home|search|download|shop|link|seller|online|help|faq|sitemap\b!!ig;

        $body=~s/^\s+//;
        my @bds=split/\s+/,$body;

        # exclude very long or short docs
        next if (@bds<$mindlen || @bds>$maxdlen);

        my $lastN=$maxwdcnt-1;
        # truncate to first $maxdwdcnt words
        #   - exclude last 20 words if shorter than $maxwdcnt
        if (@bds<$maxwdcnt) { $lastN=$#bds-20; }

        $body= join(" ",@bds[0..$lastN]);

        # flag query words occuring in document
        my ($found,%qrywd2,%stemwd)=(0);
        foreach my $qwd(keys %$qwhp) {
            my $qwd0=Simple($qwd);
            my $qwd2=$qwd;
            if ($qwd ne $qwd0) {
                $stemwd{$qwd}=$qwd0;
                $stemwd{$qwd0}=$qwd;
            }
            if ($qwd=~/\./) {   # e.g. google.com
                $qwd2=~s/\./\\./g;
                $qwd0=~s/\./\\./g;
            }
            if ($body=~/[\s,:;]$qwd2[\s,:;]/is) {
                $qrywd2{$qwd}=$qwhp->{$qwd};
                $found++;
                print "F1: $qwd2:$&\n" if ($debug2);
            }
            if (($qwd0 ne $qwd2) && $body=~/[\s,:;]$qwd0[\s,:;]/is) {
                $qrywd2{$qwd0}=$qwhp->{$qwd};
                $found++;
                print "F2: $qwd0:$&\n" if ($debug2);
            }
        }

        if (!$found) {
            print " !Query terms not found in $inf\n";
            next;
        }
        
        my @wd0=split/[\s,:;]+/,lc($body);
        my @wds=();
        foreach my $wd(@wd0) {
            next if ($sthp->{lc($wd)});
            next if ($wd=~/[^a-zA-Z.\-]/);
            if (exists($qwhp->{$wd})) { push(@wds,$wd); }
            else { 
                $wd=Simple($wd); 
                next if (length($wd)<3);
                push(@wds,$wd);
            }
        }

        # %wdpos: k=term, v=array of term positions
        my %wdpos=();
        WD: for(my $p=0; $p<@wds; $p++) {
            push(@{$wdpos{$wds[$p]}},$p);
            if ($p<@wds-1) {
                my $wd2=$wds[$p]."-$wds[$p+1]";
                foreach my $qwd(keys %qrywd2) {
                    if ($wd2=~/\b$qwd\b/) {
                        next WD;
                    }
                }
                push(@{$wdpos{$wd2}},$p);
            } 
        }
            
        my %tfNorm;
        foreach my $wd(keys %wdpos) {
            next if ($qrywd2{$wd});
            foreach my $pos(@{$wdpos{$wd}}) {
                foreach my $qwd(keys %qrywd2) {
                    #print "wd=$wd, qwd=$qwd, pos=$pos\n  @{$wdpos{$qwd}}\n";
                    my $idist= 1/(log(&minDist($pos,$wdpos{$qwd})+1)/log(5));
                    $tfNorm{$wd}{$qwd} += $idist;
                }
            }
        }

        my %qtfNorm;
        foreach my $qwd(keys %qrywd2) {
            print "QWD=$qwd\n" if ($debug2);
            foreach my $pos(@{$wdpos{$qwd}}) {
                print "POS=$pos\n" if ($debug2);
                foreach my $wd(keys %wdpos) {
                    next if ($qrywd2{$wd});
                    my $idist= 1/(log(&minDist($pos,$wdpos{$wd})+1)/log(5));
                    $qtfNorm{$wd}{$qwd} += $idist;
                    print "1:wd=$wd, qwd=$qwd, tfn=$tfNorm{$wd}{$qwd}, qfn=$qtfNorm{$wd}{$qwd}\n" if ($debug2);
                }
            }
        }

        # compute distance-normalized co-occurrence freq
        my %coFrq=();     # tfNorm*qtfNorm
        foreach my $qwd(keys %qrywd2) {
            foreach my $wd(keys %tfNorm) {
                next if ($qrywd2{$wd});
                my $qtfNorm;
                print "1b:wd=$wd, qwd=$qwd\n" if ($debug2);
                if (!$qtfNorm{$wd}{$qwd}) { next; }
                if ($qtfNorm{$wd}{$qwd}) { $qtfNorm=$qtfNorm{$wd}{$qwd}; }
                elsif ($qtfNorm{$wd}{$stemwd{$qwd}}) { $qtfNorm=$qtfNorm{$wd}{$stemwd{$qwd}}; } 
                else { next; }  ## upgrade later.i!!!
                print "2:wd=$wd, qwd=$qwd, tfn=$tfNorm{$wd}{$qwd}, qfn=$qtfNorm\n" if ($debug2);
                $coFrq{$wd}{$qwd} += $tfNorm{$wd}{$qwd}*$qtfNorm*($qrywd2{$qwd}**2);
                $coFrqAll{$wd}{$qwd} += $coFrq{$wd}{$qwd};
            }
        }

        # output seq. index file
        #    TERM FREQ  CO_FRQ per line
        my $outf= "$outd/$fpfx$fn";
        open(OUT,">$outf") || die "can't write to $outf";
        foreach my $wd(sort keys %wdpos) {
            my $tf= @{$wdpos{$wd}};
            my @wtstr;
            foreach my $qwd(sort keys %qrywd2) {
                my $wt=0;
                if ($coFrq{$wd}{$qwd}) {
                    $wt=sprintf("%.4f",$coFrq{$wd}{$qwd});
                }
                push(@wtstr,"$qwd:$wt");
            }
            print OUT "$wd $tf ", join(", ",@wtstr), "\n";
        }
        close OUT;

        $LCAcnt++;

    } #end-while ($fn<=100 && $LCAcnt<=$maxN) 


    # compute LCA score: product(0.4+co_degree(c,wi))
    #  - coDegree;  # co_degree(c,wi) = log(co(c,wi)+1)/log(n)
    foreach my $wd(keys %coFrqAll) {
        $wthp->{$wd}=1;
        foreach my $qwd(keys %$qwhp) {
            my $coDegree;
            if ($coFrqAll{$wd}{$qwd}) {
                $coDegree= log($coFrqAll{$wd}{$qwd}+1)/log($maxN);
            }
            else { $coDegree=0; }
            $wthp->{$wd} *= (0.4+$coDegree);
        }
    }


} #endsub LCA


#-----------------------------------------------------------
#  combine wk & gg_ts terms with orig qry
#-----------------------------------------------------------
#  arg1 = orig qry string
#  arg2 = wk QE term file
#  arg3 = gg_ts QE term file
#  arg4 = pointer to QE term hash
#-----------------------------------------------------------
sub comboQry1 {
    my($oqstr,$wkqf,$ggqf,$qwdhp)=@_;

    # original query
    $oqstr=~s/"//g;
    $oqstr=~s/ and|or / /ig;
    foreach my $wd(split/ +/,$oqstr) {
        $qwdhp->{lc($wd)}=10;
        if ($wd=~/-/) {
            foreach my $wd2(split/\-+/,$wd) {
                $qwdhp->{lc($wd2)}=2;
            }
        }
    }

    my(%gg,%wk);
    &mkqHash($ggqf,\%gg);
    &mkqHash($wkqf,\%wk);

    # select
    #  - common terms in top 10
    #  - top term and phrase 

    my ($swf,$phf,%cterms)=(0,0);

    foreach my $wd(sort {$gg{$a}<=>$gg{$b}} keys %gg) {

        my($rank,$rank2)=($gg{$wd},$wk{$wd});
        my $ph=1 if ($wd=~/-/);

        next if ($rank>10);

        # common term
        if ($wk{$wd}) { 
            if ($ph) { $phf++; }
            elsif ($rank+10>$rank2) { $swf++; }
            else { next; }
            $qwdhp->{$wd}+=5 if (!$cterms{$wd}); 
            $cterms{$wd}++;
        }
        else {
            next if ($swf>=1 && $phf>=1);
            if ($phf<1 && $ph) {
                $qwdhp->{$wd}+=2; 
                $phf++;
            }
            elsif ($swf<1 && !$ph) {
                $qwdhp->{$wd}+=1; 
                $swf++;
            }
        }
    }


    ($swf,$phf)=(0,0);

    foreach my $wd(sort {$wk{$a}<=>$wk{$b}} keys %wk) {

        my($rank,$rank2)=($wk{$wd},$gg{$wd});
        my $ph=1 if ($wd=~/-/);

        next if ($rank>10);

        # common term
        if ($gg{$wd}) { 
            next if ($cterms{$wd});
            if ($ph) { $phf++; }
            elsif ($rank+10>$rank2) { $swf++; }
            else { next; }
            $qwdhp->{$wd}+=5;
            $cterms{$wd}++;
        }
        else {
            next if ($swf>=1 && $phf>=1);
            if ($phf<1 && $ph) {
                $qwdhp->{$wd}+=2; 
                $phf++;
            }
            elsif ($swf<1 && !$ph) {
                $qwdhp->{$wd}+=1; 
                $swf++;
            }
        }
    }


} #endsub comboQry1


#-----------------------------------------------------------
#  combine wk & gg terms with orig qry
#-----------------------------------------------------------
#  arg1 = orig qry string
#  arg2 = wk QE term file
#  arg3 = gg_ts QE term file
#  arg4 = gg_ft QE term file
#  arg5 = gg_fx QE term file
#  arg6 = pointer to QE term hash
#-----------------------------------------------------------
sub comboQry2 {
    my($oqstr,$wkqf,$ggqf,$ggqf2,$ggqf3,$qwdhp)=@_;

    # original query
    $oqstr=~s/"//g;
    $oqstr=~s/ and|or / /ig;
    foreach my $wd(split/ +/,$oqstr) {
        $qwdhp->{lc($wd)}=10;
        if ($wd=~/-/) {
            foreach my $wd2(split/\-+/,$wd) {
                $qwdhp->{lc($wd2)}=2;
            }
        }
    }

    my(%wk,%gg,%gg2,%gg3);
    &mkqHash($wkqf,\%wk);
    &mkqHash($ggqf,\%gg);
    &mkqHash($ggqf2,\%gg2);
    &mkqHash($ggqf3,\%gg3);

    # select from each source:
    #  - common terms 
    #  - top 10 terms and phrases 

    my ($swf,$phf,%cterms)=(0,0);

    foreach my $wd(sort {$wk{$a}<=>$wk{$b}} keys %wk) {

        my$rank=$wk{$wd};
        my $ph=1 if ($wd=~/-/);

        # common term
        if ($gg{$wd} && ($gg2{$wd} || $gg3{$wd})) { 
            next if ($cterms{$wd}); 
            if ($ph) { $phf++; }
            else { $swf++; }
            $qwdhp->{$wd}+=(10/$rank);
            $cterms{$wd}++;
        }
        # common term
        elsif ($gg{$wd} || $gg2{$wd} || $gg3{$wd}) { 
            next if ($cterms{$wd}); 
            if ($ph) { $phf++; }
            else { $swf++; }
            $qwdhp->{$wd}+=(5/$rank);
            $cterms{$wd}++;
        }
        else {
            next if ($swf>=10 && $phf>=10);
            if ($phf<10 && $ph) {
                $qwdhp->{$wd}+=(2/$rank); 
                $phf++;
            }
            elsif ($swf<10 && !$ph) {
                $qwdhp->{$wd}+=(1/$rank); 
                $swf++;
            }
        }
    }


    ($swf,$phf)=(0,0);

    foreach my $wd(sort {$gg{$a}<=>$gg{$b}} keys %gg) {

        my$rank=$gg{$wd};
        my $ph=1 if ($wd=~/-/);

        # common term
        if ($wk{$wd} && ($gg2{$wd} || $gg3{$wd})) { 
            next if ($cterms{$wd}); 
            if ($ph) { $phf++; }
            else { $swf++; }
            $qwdhp->{$wd}+=(10/$rank);
            $cterms{$wd}++;
        }
        # common term
        elsif ($wk{$wd}) { 
            next if ($cterms{$wd}); 
            if ($ph) { $phf++; }
            else { $swf++; }
            $qwdhp->{$wd}+=(5/$rank);
            $cterms{$wd}++;
        }
        # common term
        elsif ($gg2{$wd} || $gg3{$wd}) { 
            next if ($cterms{$wd}); 
            if ($ph) { $phf++; }
            else { $swf++; }
            $qwdhp->{$wd}+=(3/$rank);
            $cterms{$wd}++;
        }
        else {
            next if ($swf>=10 && $phf>=10);
            if ($phf<10 && $ph) {
                $qwdhp->{$wd}+=(2/$rank); 
                $phf++;
            }
            elsif ($swf<10 && !$ph) {
                $qwdhp->{$wd}+=(1/$rank); 
                $swf++;
            }
        }
    }


    ($swf,$phf)=(0,0);

    foreach my $wd(sort {$gg2{$a}<=>$gg2{$b}} keys %gg2) {

        my$rank=$gg2{$wd};
        my $ph=1 if ($wd=~/-/);

        # common term
        if ($wk{$wd} && ($gg{$wd} || $gg3{$wd})) { 
            next if ($cterms{$wd}); 
            if ($ph) { $phf++; }
            else { $swf++; }
            $qwdhp->{$wd}+=(10/$rank);
            $cterms{$wd}++;
        }
        # common term
        elsif ($wk{$wd}) {
            next if ($cterms{$wd}); 
            if ($ph) { $phf++; }
            else { $swf++; }
            $qwdhp->{$wd}+=(5/$rank);
            $cterms{$wd}++;
        }
        # common term
        elsif ($gg{$wd} || $gg3{$wd}) { 
            next if ($cterms{$wd}); 
            if ($ph) { $phf++; }
            else { $swf++; }
            $qwdhp->{$wd}+=(3/$rank);
            $cterms{$wd}++;
        }
        else {
            next if ($swf>=10 && $phf>=10);
            if ($phf<10 && $ph) {
                $qwdhp->{$wd}+=(2/$rank); 
                $phf++;
            }
            elsif ($swf<10 && !$ph) {
                $qwdhp->{$wd}+=(1/$rank); 
                $swf++;
            }
        }
    }

    ($swf,$phf)=(0,0);

    foreach my $wd(sort {$gg3{$a}<=>$gg3{$b}} keys %gg3) {

        my$rank=$gg3{$wd};
        my $ph=1 if ($wd=~/-/);

        # common term
        if ($wk{$wd} && ($gg{$wd} || $gg2{$wd})) { 
            next if ($cterms{$wd}); 
            if ($ph) { $phf++; }
            else { $swf++; }
            $qwdhp->{$wd}+=(10/$rank);
            $cterms{$wd}++;
        }
        # common term
        elsif ($wk{$wd}) {
            next if ($cterms{$wd}); 
            if ($ph) { $phf++; }
            else { $swf++; }
            $qwdhp->{$wd}+=(5/$rank);
            $cterms{$wd}++;
        }
        # common term
        elsif ($gg{$wd} || $gg2{$wd}) { 
            next if ($cterms{$wd}); 
            if ($ph) { $phf++; }
            else { $swf++; }
            $qwdhp->{$wd}+=(3/$rank);
            $cterms{$wd}++;
        }
        else {
            next if ($swf>=10 && $phf>=10);
            if ($phf<10 && $ph) {
                $qwdhp->{$wd}+=(2/$rank); 
                $phf++;
            }
            elsif ($swf<10 && !$ph) {
                $qwdhp->{$wd}+=(1/$rank); 
                $swf++;
            }
        }
    }


} #endsub comboQry2


#-----------------------------------------------------------
#  combine wk & gg terms with orig qry
#    - add phrase componet words with 1/5 weight
#    - exclude stopwords 
#-----------------------------------------------------------
#  arg1 = orig qry string
#  arg2 = wk QE term file
#  arg3 = gg_ts QE term file
#  arg4 = gg_ft QE term file
#  arg5 = gg_fx QE term file
#  arg6 = pointer to QE term hash
#  arg7 = pointer to stopword hash
#-----------------------------------------------------------
sub comboQry3 {
    my($oqstr,$wkqf,$ggqf,$ggqf2,$ggqf3,$qwdhp,$sthp)=@_;

    # original query
    $oqstr=~s/"//g;
    $oqstr=~s/ and|or / /ig;
    foreach my $wd(split/ +/,$oqstr) {
        $qwdhp->{lc($wd)}=10;
        if ($wd=~/-/) {
            foreach my $wd2(split/\-+/,$wd) {
                $qwdhp->{lc($wd2)}=2;
            }
        }
    }

    my(%wk,%gg,%gg2,%gg3);
    &mkqHash($wkqf,\%wk);
    &mkqHash($ggqf,\%gg);
    &mkqHash($ggqf2,\%gg2);
    &mkqHash($ggqf3,\%gg3);

    # select from each source:
    #  - common terms 
    #  - top 10 terms and phrases 

    my ($swf,$phf,%cterms)=(0,0);

    foreach my $wd(sort {$wk{$a}<=>$wk{$b}} keys %wk) {

        next if ($sthp->{$wd}); # exclude stopwords

        my$rank=$wk{$wd};

        my($ph,$wd1,$wd2);
        if ($wd=~/-/) {
            $ph=1;
            ($wd1,$wd2)=split(/-/,$wd);
        }

        # common term
        if ($gg{$wd} && ($gg2{$wd} || $gg3{$wd})) { 
            next if ($cterms{$wd});
            $cterms{$wd}++;
            $qwdhp->{$wd}+=(10/$rank);
            if (!$ph) { $swf++; }
            else { 
                $phf++; 
                $qwdhp->{$wd1}+=(2/$rank);
                $qwdhp->{$wd2}+=(2/$rank);
            }
        }
        # common term
        elsif ($gg{$wd} || $gg2{$wd} || $gg3{$wd}) { 
            next if ($cterms{$wd});
            $cterms{$wd}++;
            $qwdhp->{$wd}+=(5/$rank);
            if (!$ph) { $swf++; }
            else { 
                $phf++; 
                $qwdhp->{$wd1}+=(1/$rank);
                $qwdhp->{$wd2}+=(1/$rank);
            }
        }
        else {
            next if ($swf>=10 && $phf>=10);
            if ($phf<10 && $ph) {
                $qwdhp->{$wd}+=(2/$rank); 
                $qwdhp->{$wd1}+=(2/(5*$rank));
                $qwdhp->{$wd2}+=(2/(5*$rank));
                $phf++;
            }
            elsif ($swf<10 && !$ph) {
                $qwdhp->{$wd}+=(1/$rank); 
                $swf++;
            }
        }
    }


    ($swf,$phf)=(0,0);

    foreach my $wd(sort {$gg{$a}<=>$gg{$b}} keys %gg) {

        next if ($sthp->{$wd}); # exclude stopwords

        my$rank=$gg{$wd};

        my($ph,$wd1,$wd2);
        if ($wd=~/-/) {
            $ph=1;
            ($wd1,$wd2)=split(/-/,$wd);
        }

        # common term
        if ($wk{$wd} && ($gg2{$wd} || $gg3{$wd})) { 
            next if ($cterms{$wd});
            $cterms{$wd}++;
            $qwdhp->{$wd}+=(10/$rank);
            if (!$ph) { $swf++; }
            else { 
                $phf++; 
                $qwdhp->{$wd1}+=(2/$rank);
                $qwdhp->{$wd2}+=(2/$rank);
            }
        }
        # common term
        elsif ($wk{$wd}) { 
            next if ($cterms{$wd});
            $cterms{$wd}++;
            $qwdhp->{$wd}+=(5/$rank);
            if (!$ph) { $swf++; }
            else { 
                $phf++; 
                $qwdhp->{$wd1}+=(1/$rank);
                $qwdhp->{$wd2}+=(1/$rank);
            }
        }
        # common term
        elsif ($gg2{$wd} || $gg3{$wd}) { 
            next if ($cterms{$wd});
            $cterms{$wd}++;
            $qwdhp->{$wd}+=(3/$rank);
            if (!$ph) { $swf++; }
            else { 
                $phf++; 
                $qwdhp->{$wd1}+=(3/(5*$rank));
                $qwdhp->{$wd2}+=(3/(5*$rank));
            }
        }
        else {
            next if ($swf>=10 && $phf>=10);
            if ($phf<10 && $ph) {
                $qwdhp->{$wd}+=(2/$rank); 
                $qwdhp->{$wd1}+=(2/(5*$rank));
                $qwdhp->{$wd2}+=(2/(5*$rank));
                $phf++;
            }
            elsif ($swf<10 && !$ph) {
                $qwdhp->{$wd}+=(1/$rank); 
                $swf++;
            }
        }
    }

    ($swf,$phf)=(0,0);

    foreach my $wd(sort {$gg2{$a}<=>$gg2{$b}} keys %gg2) {

        next if ($sthp->{$wd}); # exclude stopwords

        my$rank=$gg2{$wd};

        my($ph,$wd1,$wd2);
        if ($wd=~/-/) {
            $ph=1;
            ($wd1,$wd2)=split(/-/,$wd);
        }

        # common term
        if ($wk{$wd} && ($gg{$wd} || $gg3{$wd})) { 
            next if ($cterms{$wd});
            $cterms{$wd}++;
            $qwdhp->{$wd}+=(10/$rank);
            if (!$ph) { $swf++; }
            else { 
                $phf++; 
                $qwdhp->{$wd1}+=(2/$rank);
                $qwdhp->{$wd2}+=(2/$rank);
            }
        }
        # common term
        elsif ($wk{$wd}) { 
            next if ($cterms{$wd});
            $cterms{$wd}++;
            $qwdhp->{$wd}+=(5/$rank);
            if (!$ph) { $swf++; }
            else {
                $phf++;
                $qwdhp->{$wd1}+=(1/$rank);
                $qwdhp->{$wd2}+=(1/$rank);
            }
        }
        # common term
        elsif ($gg{$wd} || $gg3{$wd}) { 
            next if ($cterms{$wd});
            $cterms{$wd}++;
            $qwdhp->{$wd}+=(3/$rank);
            if (!$ph) { $swf++; }
            else {
                $phf++;
                $qwdhp->{$wd1}+=(3/(5*$rank));
                $qwdhp->{$wd2}+=(3/(5*$rank));
            }
        }
        else {
            next if ($swf>=10 && $phf>=10);
            if ($phf<10 && $ph) {
                $qwdhp->{$wd}+=(2/$rank); 
                $qwdhp->{$wd1}+=(2/(5*$rank));
                $qwdhp->{$wd2}+=(2/(5*$rank));
                $phf++;
            }
            elsif ($swf<10 && !$ph) {
                $qwdhp->{$wd}+=(1/$rank); 
                $swf++;
            }
        }
    }

    ($swf,$phf)=(0,0);

    foreach my $wd(sort {$gg3{$a}<=>$gg3{$b}} keys %gg3) {

        next if ($sthp->{$wd}); # exclude stopwords

        my$rank=$gg3{$wd};

        my($ph,$wd1,$wd2);
        if ($wd=~/-/) {
            $ph=1;
            ($wd1,$wd2)=split(/-/,$wd);
        }

        # common term
        if ($wk{$wd} && ($gg{$wd} || $gg2{$wd})) { 
            next if ($cterms{$wd});
            $cterms{$wd}++;
            $qwdhp->{$wd}+=(10/$rank);
            if (!$ph) { $swf++; }
            else {
                $phf++;
                $qwdhp->{$wd1}+=(2/$rank);
                $qwdhp->{$wd2}+=(2/$rank);
            }
        }
        # common term
        elsif ($wk{$wd}) { 
            next if ($cterms{$wd});
            $cterms{$wd}++;
            $qwdhp->{$wd}+=(5/$rank);
            if (!$ph) { $swf++; }
            else {
                $phf++;
                $qwdhp->{$wd1}+=(1/$rank);
                $qwdhp->{$wd2}+=(1/$rank);
            }
        }
        # common term
        elsif ($gg{$wd} || $gg2{$wd}) { 
            next if ($cterms{$wd});
            $cterms{$wd}++;
            $qwdhp->{$wd}+=(3/$rank);
            if (!$ph) { $swf++; }
            else {
                $phf++;
                $qwdhp->{$wd1}+=(3/(5*$rank));
                $qwdhp->{$wd2}+=(3/(5*$rank));
            }
        }
        else {
            next if ($swf>=10 && $phf>=10);
            if ($phf<10 && $ph) {
                $qwdhp->{$wd}+=(2/$rank); 
                $qwdhp->{$wd1}+=(2/(5*$rank));
                $qwdhp->{$wd2}+=(2/(5*$rank));
                $phf++;
            }
            elsif ($swf<10 && !$ph) {
                $qwdhp->{$wd}+=(1/$rank); 
                $swf++;
            }
        }
    }


} #endsub comboQry3


#-----------------------------------------------------------
#  extract top ranking phrases from wk & gg terms
#    - exclude stopwords 
#    - add original query words
#-----------------------------------------------------------
#  arg1 = orig qry string
#  arg2 = wk QE term file
#  arg3 = gg_ts QE term file
#  arg4 = gg_ft QE term file
#  arg5 = gg_fx QE term file
#  arg6 = pointer to QE term hash
#  arg7 = pointer to stopword hash
#-----------------------------------------------------------
sub comboQry4 {
    my($oqstr,$wkqf,$ggqf,$ggqf2,$ggqf3,$qwdhp,$sthp)=@_;

    my $maxtn=1;

    # extract phrases from original query
    $oqstr=~s/"//g;
    my $owt=5;
    if ($oqstr=~/ or /i) {
        my@wds=split(/ or /i,$oqstr);
        foreach my $ph(@wds) {
            $ph=~s/ +/-/g;
            $owt++ if ($ph=~/-/);
            $qwdhp->{lc($ph)}="$owt:1orig";
        }
    }
    else {
        $oqstr=~s/ and /-/ig;
        $oqstr=~s/ +/-/g;
        $owt++ if ($oqstr=~/-/);
        $qwdhp->{lc($oqstr)}="$owt:1orig";
    }

    my(%wk,%gg,%gg2,%gg3);
    &mkqHash($wkqf,\%wk);
    &mkqHash($ggqf,\%gg);
    &mkqHash($ggqf2,\%gg2);
    &mkqHash($ggqf3,\%gg3);

    # select from each source:
    #  - common terms 
    #  - top terms and phrase 

    my ($xwt,$phf,%cterms)=(4,0);

    WD: foreach my $wd(sort {$wk{$a}<=>$wk{$b}} keys %wk) {

        next if ($sthp->{$wd}); # exclude stopwords
        next if ($wd!~/-/);
        next if ($phf>=$maxtn);

        foreach $w(split/-/,$wd) { next WD if ($sthp->{$w}); }

        my $rank=$wk{$wd};

        my $cn=0;
        $cn++ if ($gg{$wd});
        $cn++ if ($gg2{$wd});
        $cn++ if ($gg3{$wd});

        next if ($cn==1 && $rank>50);

        # common term
        if ($cn>2) {
            next if ($cterms{$wd});
            $cterms{$wd}++;
            $xwt++;
            $qwdhp->{$wd}.="$xwt:2acom:$rank($cn)";
            $phf++;
        }
        elsif ($gg{$wd} && ($gg2{$wd} || $gg3{$wd})) { 
            next if ($cterms{$wd});
            $cterms{$wd}++;
            $qwdhp->{$wd}.="$xwt:2bcom:$rank($cn)";
            $phf++;
        }
        # common term
        elsif ($cn>1) {
            next if ($cterms{$wd});
            $cterms{$wd}++;
            $qwdhp->{$wd}.="$xwt:2ccom:$rank($cn)";
            $phf++;
        }
    }


    ($xwt,$phf)=(3,0);

    WD1: foreach my $wd(sort {$gg{$a}<=>$gg{$b}} keys %gg) {


        next if ($sthp->{$wd}); # exclude stopwords
        next if ($wd!~/-/);
        next if ($phf>=$maxtn);

        foreach $w(split/-/,$wd) { next WD1 if ($sthp->{$w}); }

        my $rank=$gg{$wd};

        my $cn=0;
        $cn++ if ($wk{$wd});
        $cn++ if ($gg2{$wd});
        $cn++ if ($gg3{$wd});

        next if ($cn==1 && $rank>50);

        # common term
        if ($cn>2) {
            next if ($cterms{$wd});
            $cterms{$wd}++;
            $xwt++;
            $qwdhp->{$wd}.="$xwt:3acom:$rank($cn)";
            $phf++;
        }
        elsif ($wk{$wd} && ($gg2{$wd} || $gg3{$wd})) { 
            next if ($cterms{$wd});
            $cterms{$wd}++;
            $qwdhp->{$wd}.="$xwt:3bcom:$rank($cn)";
            $phf++;
        }
        # common term
        elsif ($wk{$wd}) { 
            next if ($cterms{$wd});
            $cterms{$wd}++;
            $qwdhp->{$wd}.="$xwt:3ccom:$rank($cn)";
            $phf++;
        }
    }

    ($xwt,$phf)=(2,0);

    WD2: foreach my $wd(sort {$gg2{$a}<=>$gg2{$b}} keys %gg2) {

        next if ($sthp->{$wd}); # exclude stopwords
        next if ($wd!~/-/);
        next if ($phf>=$maxtn);

        foreach $w(split/-/,$wd) { next WD2 if ($sthp->{$w}); }

        my $rank=$gg2{$wd};

        my $cn=0;
        $cn++ if ($wk{$wd});
        $cn++ if ($gg{$wd});
        $cn++ if ($gg3{$wd});

        next if ($cn==1 && $rank>50);

        # common term
        if ($cn>2) {
            next if ($cterms{$wd});
            $cterms{$wd}++;
            $xwt++;
            $qwdhp->{$wd}.="$xwt:4acom:$rank($cn)";
            $phf++;
        }
        if ($wk{$wd} && ($gg{$wd} || $gg3{$wd})) { 
            next if ($cterms{$wd});
            $cterms{$wd}++;
            $qwdhp->{$wd}.="$xwt:4bcom:$rank($cn)";
            $phf++;
        }
        # common term
        elsif ($wk{$wd}) { 
            next if ($cterms{$wd});
            $cterms{$wd}++;
            $qwdhp->{$wd}.="$xwt:4ccom:$rank($cn)";
            $phf++;
        }
    }

    ($xwt,$phf)=(1,0);

    WD3: foreach my $wd(sort {$gg3{$a}<=>$gg3{$b}} keys %gg3) {

        next if ($sthp->{$wd}); # exclude stopwords
        next if ($wd!~/-/);
        next if ($phf>=$maxtn);

        foreach $w(split/-/,$wd) { next WD3 if ($sthp->{$w}); }

        my $rank=$gg3{$wd};

        my $cn=0;
        $cn++ if ($wk{$wd});
        $cn++ if ($gg{$wd});
        $cn++ if ($gg2{$wd});

        next if ($cn==1 && $rank>50);

        # common term
        if ($cn>2) {
            next if ($cterms{$wd});
            $cterms{$wd}++;
            $xwt++;
            $qwdhp->{$wd}.="$xwt:5acom:$rank($cn)";
            $phf++;
        }
        elsif ($wk{$wd} && ($gg{$wd} || $gg2{$wd})) { 
            next if ($cterms{$wd});
            $cterms{$wd}++;
            $qwdhp->{$wd}.="$xwt:5bcom:$rank($cn)";
            $phf++;
        }
    }

} #endsub comboQry4


#-----------------------------------------------------------
#  extract top ranking phrases from wk & gg terms
#    - exclude stopwords 
#    - add original query words
#-----------------------------------------------------------
#  arg1 = orig qry string
#  arg2 = wk QE term file
#  arg3 = gg_ts QE term file
#  arg4 = gg_ft QE term file
#  arg5 = gg_fx QE term file
#  arg6 = pointer to QE term hash
#  arg7 = pointer to stopword hash
#-----------------------------------------------------------
sub comboQry5 {
    my($wkqf,$wkqf2,$ggqf,$ggqf2,$ggqf3,$qwdhp,$sthp)=@_;

    my(%wk,$wk,%gg,%gg2,%gg3);
    &mkqHash($wkqf,\%wk);
    &mkqHash($wkqf2,\%wk2);
    &mkqHash($ggqf,\%gg);
    &mkqHash($ggqf2,\%gg2);
    &mkqHash($ggqf3,\%gg3);


    my $rank=1;
    foreach my $wd(sort {$wk{$a}<=>$wk{$b}} keys %wk) {

        next if ($sthp->{$wd}); # exclude stopwords
        foreach $w(split/-/,$wd) { next if ($sthp->{$w}); }

        my $cn=0;
        $cn++ if ($wk2{$wd});
        $cn++ if ($gg{$wd});
        $cn++ if ($gg2{$wd});
        $cn++ if ($gg3{$wd});

        $qwdhp->{$wd}= sprintf("%.4f",$cn/$rank);

        $rank++;
    }

    $rank=1;
    foreach my $wd(sort {$wk2{$a}<=>$wk2{$b}} keys %wk2) {

        next if ($sthp->{$wd}); # exclude stopwords
        foreach $w(split/-/,$wd) { next if ($sthp->{$w}); }

        my $cn=0;
        $cn++ if ($wk{$wd});
        $cn++ if ($gg{$wd});
        $cn++ if ($gg2{$wd});
        $cn++ if ($gg3{$wd});

        $qwdhp->{$wd}= sprintf("%.4f",$cn/$rank);

        $rank++;
    }

    $rank=1;
    foreach my $wd(sort {$gg{$a}<=>$gg{$b}} keys %gg) {

        next if ($sthp->{$wd}); # exclude stopwords
        foreach $w(split/-/,$wd) { next if ($sthp->{$w}); }

        my $cn=0;
        $cn++ if ($wk{$wd});
        $cn++ if ($wk2{$wd});
        $cn++ if ($gg2{$wd});
        $cn++ if ($gg3{$wd});

        $qwdhp->{$wd}= sprintf("%.4f",$cn/$rank);

        $rank++;
    }

    $rank=1;
    foreach my $wd(sort {$gg2{$a}<=>$gg2{$b}} keys %gg2) {

        next if ($sthp->{$wd}); # exclude stopwords
        foreach $w(split/-/,$wd) { next if ($sthp->{$w}); }

        my $cn=0;
        $cn++ if ($wk{$wd});
        $cn++ if ($wk2{$wd});
        $cn++ if ($gg{$wd});
        $cn++ if ($gg3{$wd});

        $qwdhp->{$wd}= sprintf("%.4f",$cn/$rank);

        $rank++;
    }

    $rank=1;
    foreach my $wd(sort {$gg3{$a}<=>$gg3{$b}} keys %gg3) {

        next if ($sthp->{$wd}); # exclude stopwords
        foreach $w(split/-/,$wd) { next if ($sthp->{$w}); }

        my $cn=0;
        $cn++ if ($wk{$wd});
        $cn++ if ($wk2{$wd});
        $cn++ if ($gg{$wd});
        $cn++ if ($gg2{$wd});

        $qwdhp->{$wd}= sprintf("%.4f",$cn/$rank);

        $rank++;
    }

} #endsub comboQry5


#-----------------------------------------------------------
#  create term hash from file
#-----------------------------------------------------------
#  arg1 = infile
#  arg2 = pointer to term hash (term => rank)
#  arg3 = number of terms to extract from file (optional)
#-----------------------------------------------------------
sub mkqHash {
    my($file,$hp,$tcnt)=@_;

    $tcnt=100 if (!$tcnt);

    open(IN,$file) || die "can't read $file";
    my $rank=1;
    while(<IN>) {
        last if ($rank>$tcnt);
        chomp;
        my($wd)=split/ /;
        next if ($wd=~/^\d+$/); # exclude all numbers
        $hp->{lc($wd)}=$rank; 
        $rank++;
    }

} #endsub mkqHash




1
