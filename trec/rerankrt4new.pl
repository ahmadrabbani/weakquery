#!/usr/bin/perl -w

# -----------------------------------------------------------------
# Name:      rerankrt4new.pl
# Author:    Kiduk Yang, 11/16/2008
#              modified rerankrt4qeOptnew1b.pl (5/2008)
#                - uses AVM, idist, multiple lex weights (man, combo, prob)
#              modified rerankrt4.pl, 7/2/2008
#                - apply opinion reraking directly to baseline results (w/o topic RR)
#                - no topic reranking group used
#                - all lex weights combinations are excluded due to poor performance
#              modified rerankrt4c.pl, 7/2/2008
#                - combo lex weights excluded
#              modified rerankrt4d.pl, 11/16/2008
#                - combined rerankrt4c.pl and rerankrt4d.pl
#                - made rall directory an argument
#                - add optional argument to penalize docs w/o query title term match
#              $Id: rerankrt4.pl,v 1.1 2008/06/27 00:43:44 kiyang Exp kiyang $
# -----------------------------------------------------------------
# Description:  Perform post-retrieval reranking (optimized formula)
#   1. order reranking groups
#      - A1 above A2 above B above rest
#        A1: exact match of query title in both doc title & body
#        A2: exact match of multi-term query title to doc title
#   2. boost the rank of documents within reranking groups by combined reranking scores
#      FS = 0.85*normalized_SC + 0.15*(4.5A + 3B + 3C + 2D + 1E + 4F) - 3G - 10H
#           (2006 post-submission reranking formula optimized via dynamic tuning)
#        A. exact match of query title to doc title
#        B. exact match of query title to doc body
#        C. proximity match of query title to doc title
#        D. proximity match of query title to doc body
#        E. proximity match of query title+desc to doc body
#        F. query phrase match to doc body
#        G. query non-rel phrase match to doc body
#        H. query non-rel noun match to doc body
# -----------------------------------------------------------------
# ARGUMENT:  arg1= query type (i.e. t=train, tx=train w/ subx, e=test, ex=test w/ subx)
#            arg2= result subdirectory (e.g. s0)
#            arg3= fusion weight file (wt1, dt1)
#            arg4= number suffix of rall directory (e.g. 8 for rall8)
#            arg5= number of docs to rerank (optional: default=500)
#            arg6= 1 to rerank results beyond maxrank in a group (optional)
#            arg7= input file name (optional)
#            arg8= qtixm penalty flag (optional: 1 to penalize docs w/o qtitle match)
# INPUT:     $ddir/results/$qtype/trecfmt(x)/$arg2.R/rall$arg4/*.2
#              -- results w/ opinion reranking scores
#            $ddir/results/$qtype/trecfmt(x)/$arg2.R/*-$arg3.r1
#              -- topic reranked results
# OUTPUT:    $ddir/results/$qtype/trecfmt(x)/$arg2.R$arg4(c|d)/$arg3.r2
#            $ddir/rtlog/$prog      -- program     (optional)
#            $ddir/rtlog/$prog.log  -- program log (optional)
#            NOTE: $qtype   = query type (train|eval)
# -----------------------------------------------------------------
# NOTES: 
#   1. result file contains only $maxrank docs per topic
# ------------------------------------------------------------------------

use strict;
use Data::Dumper;
$Data::Dumper::Purity=1;

my ($debug,$filemode,$filemode2,$dirmode,$dirmode2,$author,$group);
my ($log,$sfx,$noargp,$append,@start_time);

$log=1;                              # program log flag
$debug=0;                            # debug flag
$filemode= 0640;                     # to use w/ perl chmod
$filemode2= 640;                     # to use w/ system chmod
$dirmode= 0750;                      # to use w/ perl mkdir
$dirmode2= 750;                      # to use w/ system chmod (directory)
$group= "trec";                      # group ownership of files
$author= "kiyang\@indiana.edu";      # author's email


#------------------------
# global variables
#------------------------

use constant MAXRANK => 500;
use constant MAXRTCNT => 1000; 

my $wpdir=  "/u0/widit/prog";           # widit program directory
my $tpdir=  "$wpdir/trec08";            # TREC program directory
my $pdir=   "$tpdir/blog";              # TREC program directory
my $ddir=   "/u3/trec/blog08";          # index directory
my $logd=   "$ddir/rrlog";              # log directory

# query type
my %qtype= ("e"=>"test","ex"=>"test","t"=>"train","tx"=>"train");

require "$wpdir/logsub2.pl";


#------------------------
# program arguments
#------------------------
my $prompt=
"arg1= query type (i.e. t, tx, e, ex)\n".
"arg2= result subdirectory (e.g. s0)\n".
"arg3= opinion rerank weight filename\n".
"arg4= number suffix for rall directory (e.g., 8 for rall8)\n".
"arg5= number of docs to rerank (optional: default=500)\n".
"arg6= 1 to rerank results beyond maxrank in a group (optional)\n".
"arg7= result file name prefix (optional)\n".
"arg8= qtixm penalty flag (optional: 1 to penalize docs w/o qtitle match)\n";

my %valid_args= (
0 => " t tx e ex ",
1 => " s0* ",
2 => " dt1 wt1 dt2 ",
);

my ($arg_err,$qtype,$rsubd,$fwtf,$radn,$maxrank,$rrlow,$fpfx,$qtmflag)= chkargs($prompt,\%valid_args,4);
die "$arg_err\n" if ($arg_err);
die "bad fusion weight file: $fwtf\n" if (!-e "fswtd/oprr/$fwtf");

$maxrank=MAXRANK if (!$maxrank);

# reranking weights
my %fswt=&readwts("fswtd/oprr/$fwtf");

my $cwt=0;
if ($fwtf eq 'wt1') { $cwt=1; }

# TREC format directory
my $rdir0= "$ddir/results/$qtype{$qtype}/trecfmt/$rsubd";
$rdir0=~s/trecfmt/trecfmtx/ if ($qtype=~/x/);

my $rdir;
if ($cwt) { $rdir= $rdir0.$radn."Rc"; }
else { $rdir= $rdir0.$radn."Rd"; }

`mkdir -p $rdir` if (!-e $rdir);

my $ind= "$rdir0"."R/rall$radn";  # original ranking w/ opinion scores


#-------------------------------------------------
# start program log
#-------------------------------------------------

if ($radn) {
    $sfx= "$qtype$rsubd$radn-$fwtf"; # program log file suffix
}
else {
    $sfx= "$qtype$rsubd-$fwtf"; # program log file suffix
}
$sfx .= 'L' if ($rrlow);
$sfx .= 'qx' if ($qtmflag);
$sfx .= "-$maxrank" if ($maxrank != MAXRANK);

$noargp=0;              # if 1, do not print arguments to log
$append=0;              # log append flag

if ($log) {
    @start_time= &begin_log($logd,$filemode,$sfx,$noargp,$append);
    my @str;
    foreach my $name(sort keys %fswt) {
        push(@str,"    $name => $fswt{$name}"); 
    }
    my $wtstr= join("\n",@str);
    print LOG "InF   = $ind/*.2\n",
              "      = $rdir0/*_trec\n",
              "OutF  = $rdir/*-$fwtf.r2\n\n";
    print LOG "fusion weights:\n$wtstr\n\n";
}


#-------------------------------------------------------------
# create opinion score name arrays for easier processing
#-------------------------------------------------------------
# opinion score file format
#   qn docID rank rtsc runname tlen in1 in2
#   ac hf iu lf w1 w2  (manwtSC:combowtSC:probwtSC, where SC=scPscNsc)
#   e (manwtSC:combowtSC:probwtSC, where SC=sc)
#   av 
#   acx acd acd2 hfx hfd hfd2 iux iud iud2 lfx lfd lfd2 w1x w1d wdd2 w2x w2d w2d2  (manwtSC:combowtSC:probwtSC, where SC=scPscNsc)
#   ex ed ed2 (manwtSC:combowtSC:probwtSC, where SC=sc)
#   avx
#-------------------------------------------------------------
# for score processing
#  @vname1: names of opinion scores w/ single wts
#  @vname2: names of opinion scores w/o polarity but multi-wts
#  @vname3: names of opinion scores w/ polarity and multi-wts
#  @vnames: all opinion score names
#-------------------------------------------------------------

# lex weight format
my @wname;
if ($cwt) { @wname=('_m','_c','_p'); }
else { @wname=('_m','_p'); }

# opNames w/o polarity & singleWTs: 
my @vname1=('in1','in2','av','avx');

# opNames w/o polarity & multiWTs: 
my @vname2=('e','ex','ed');

# opNames w/ polarity & multiWTs: idist2 scores not utilized
my @vname3=('ac','hf','iu','lf','w1','w2','acx','acd','hfx','hfd','iux','iud','lfx','lfd','w1x','w1d','w2x','w2d');

my @vnames=@vname1;
my @vnameM=@vname1;
my @vnameC=@vname1;
my @vnameP=@vname1;

foreach my $name(@vname2) {
    foreach my $wname(@wname) {
        push(@vnames,$name.$wname);
        if ($wname eq '_m') { push(@vnameM,$name.$wname); }
        if ($wname eq '_c') { push(@vnameC,$name.$wname); }
        if ($wname eq '_p') { push(@vnameP,$name.$wname); }
    }
}
foreach my $name(@vname3) {
    foreach my $pol('','P','N') {
        foreach my $wname(@wname) {
            push(@vnames,$name.$pol.$wname);
            if ($wname eq '_m') { push(@vnameM,$name.$pol.$wname); }
            if ($wname eq '_c') { push(@vnameC,$name.$pol.$wname); }
            if ($wname eq '_p') { push(@vnameP,$name.$pol.$wname); }
        }
    }
}

print LOG "\nOutput File Format: *-m.r2\n", join(",",@vnameM),"\n\n";
print LOG "\nOutput File Format: *-c.r2\n", join(",",@vnameC),"\n\n" if ($cwt);
print LOG "\nOutput File Format: *-p.r2\n", join(",",@vnameP),"\n\n";

my %vnames= (
    'm'=>\@vnameM,
    'p'=>\@vnameP,
    'c'=>\@vnameC,
);



#-------------------------------------------
# create opinion reranked files
#-------------------------------------------

opendir(IND,$rdir0) || die "can't opendir $rdir";
my @files=readdir(IND);
closedir IND;

foreach my $file(@files) {

    next if ($fpfx && $file !~ /^$fpfx/);

    next if ($file !~ /^(.+?)_trec$/);
    my $fname=$1;
    
    # process submission files only
    next if ($file !~ /top3f|base[f45]|wdoqf|wdoqln|wdoqsBase/);

    my $outf= "$rdir/$fname-$fwtf";
    if ($rrlow && $qtmflag) {
        $outf=~s/($fname)/$1Lqx/; 
    }
    elsif ($rrlow) {
        $outf=~s/($fname)/$1L/;
    }
    elsif ($qtmflag) {
        $outf=~s/($fname)/$1qx/;
    }
    $outf .= "r$maxrank" if ($maxrank != MAXRANK);

    my $outfm= "$outf-m.r2";  # manual lex weight
    my $outfc= "$outf-c.r2";  # combo lex weight
    my $outfp= "$outf-p.r2";  # prob lex weight

    # baseline file
    #my $inf= "$rdir0/$file";
    my $inf= "$ind/$fname.1"; #!! make sure ranking is same as $file
    
    # rerank score file
    my $inf2= "$ind/$fname.2";

    print "Reading $inf\n";
    print "Reading $inf2\n";
    print "writing to $outfm\n";
    print "writing to $outfc\n" if ($cwt);
    print "writing to $outfp\n\n";
    
    &mkRRf($inf,$inf2,$outfm,$outfp,$outfc);

}


#-------------------------------------------------
# end program
#-------------------------------------------------

&end_log($pdir,$logd,$filemode,@start_time) if ($log);

# notify author of program completion
#&notify($sfx,$author);


##################################
# SUBROUTINE
##################################

BEGIN { print STDOUT "\n"; }
END { print STDOUT "\n"; }

#-------------------------------------------
# create hashes
#   %result: 
#     - k=QN 
#     - v= pointer to array of "DOCNO RANK Orig_SC Rerank_SC RunName"
#   %resultop: k=QN:docno, v=opinion scores
#   %result0: k=QN:docno, v=result line from on-topic reranking plus opinion scores
#   %maxsc: k=QN, v= hash pointer
#                 k= score name v=max. original score
#   %minsc: k=QN, v= hash pointer
#                 k= score name v=min. original score
#-------------------------------------------

sub mkRRf {
    my ($tpinf,$opinf,$outm,$outp,$outc)=@_;

    my %resultop;
    open(OPIN,$opinf) || die "can't read $opinf";
    while(<OPIN>) {
        chomp;
        my ($qnum,$docno,$rank,$sc,$run,$restsc)=split(/\s+/,$_,6);
        $resultop{"$qnum:$docno"}=$restsc;
    }
    close OPIN;

    open(TPIN,$tpinf) || die "can't read $tpinf";

    # %maxsc: k(QN -> scName) = v(max_sc)
    # %minsc: k(QN -> scName) = v(min_sc)
    # %max: k(scName) = v(max_sc)
    # %min: k(scName) = v(min_sc)
    my($oldqnum,$oldsc,%result,%maxsc,%minsc,%max,%min,$rank)=(0);


    #-------------------------------------------------------------
    # 1. read in topic reranked file
    # 2. merge in opinion scores from %resultop
    # 3. length-normalize opinion scores
    # 4. get min/max scores for min-max normalization

    while(<TPIN>) {
        chomp;

        # get topic reranked results
        #my ($qnum,$q0,$docno,$rnk,$sc,$run,@rest)=split/\s+/;
        my ($qnum,$docno,$rnk,$sc,$run,@rest)=split/\s+/;

        my $qmatch=0;
        if (@rest==12) {
            if ($rest[11]>0) { $qmatch=1; }
            else { $qmatch=-1; }
        }

        $rank=0 if ($qnum ne $oldqnum);
        $rank++;

        #!!next if ($rank>MAXRTCNT);

        #----------------------------------------
        # store all opinion scores in %sc
        # k(scName) = v(sc)
        my %sc;  

        #----------------------------------------
        # ac hf iu lf w1 w2  (manwtSC:combowtSC:probwtSC, where SC=scPscNsc)
        # e (manwtSC:combowtSC:probwtSC, where SC=sc)
        # acx acd acd2 hfx hfd hfd2 iux iud iud2 lfx lfd lfd2 w1x w1d wdd2 w2x w2d w2d2  (manwtSC:combowtSC:probwtSC, where SC=scPscNsc)
        # ex ed ed2 (manwtSC:combowtSC:probwtSC, where SC=sc)
        #----------------------------------------
        # Note: idist2 (e.g. iud2) are not utilized
        #----------------------------------------
        my ($tlen,$iucnt1,$iucnt2,$ac,$hf,$iu,$lf,$w1,$w2,$emp,$av,$acx,$acd,$acd2,$hfx,$hfd,$hfd2,$iux,$iud,$iud2,
            $lfx,$lfd,$lfd2,$w1x,$w1d,$w1d2,$w2x,$w2d,$w2d2,$empx,$empd,$empd2,$avx)
            =split(/\s+/,$resultop{"$qnum:$docno"}) if ($rank<=$maxrank);

        # iu anchor counts (iucnt1,2) & emphasis scores (emp,empx) have no polarity
        if ($iucnt1) { $sc{'in1'}=$iucnt1; }
        else { $sc{'in1'}=0; }
        if ($iucnt2) { $sc{'in2'}=$iucnt2; }
        else { $sc{'in2'}=0; }
        if ($av) { $sc{'av'}=$av; }
        else { $sc{'av'}=0; }
        if ($avx) { $sc{'avx'}=$avx; }
        else { $sc{'av'}=0; }

        if ($tlen) { $sc{'tlen'}=$tlen; }
        else { $sc{'tlen'}=100; }  ##!! arbituary length
        
        my %empsc= ('e'=>$emp, 'ex'=>$empx, 'ed'=>$empd);
        foreach my $name(keys %empsc) {
            if ($empsc{$name}) {
                my($scM,$scC,$scP)=split/:/,$empsc{$name};
                $sc{$name.'_m'}=$scM;
                $sc{$name.'_p'}=$scP;
                $sc{$name.'_c'}=$scC if ($cwt);
            }
            else {
                $sc{$name.'_m'}=0;
                $sc{$name.'_p'}=0;
                $sc{$name.'_c'}=0 if ($cwt);
            }
        }

        # polarity scores
        #  - score format: SCpSCnSC (e.g. 7p2n0)
        my $k=0;
        foreach my $sc2($ac,$hf,$iu,$lf,$w1,$w2,$acx,$acd,$hfx,$hfd,$iux,$iud,$lfx,$lfd,$w1x,$w1d,$w2x,$w2d) {
            last if ($rank>$maxrank);
            my $name= ($vname3[$k]);
            if ($sc2) {
                my $I=0;
                foreach my $sc1(split/:/,$sc2) {
                    next if ($I==1);
                    $sc1=~/^([\d\.]+)p([\d\.]+)n([\d\.]+)$/;
                    my ($sc,$scp,$scn)=($1,$2,$3);
                    my $wname=$wname[$I];
                    $sc{$name.$wname}=$sc;
                    $sc{$name."P$wname"}=$scp;
                    $sc{$name."N$wname"}=$scn;
                    $I++;
                }
            }
            else {
                die "!!Input parse error: missing opinion score!!\n",
                    "  qn=$qnum, dn=$docno, rank=$rank, name=$name\n";
            }
            $k++;
        }


        #----------------------------------------
        # 1. set missing scores to zero
        #    - when rerank scoring is limited to top N ranks, 
        #      rerank scores will be missing (see rerank24merge.pl)
        # 2. length-normalize opinion scores
        #    !!NOTE!!: opinion scores were not length-normalized previously

        #----------------------------------------
        # for score min-max normalization
        #  1. results are ranked by QN, orig_sc: 
        #     - max/min sc= first/last in QN
        #  2. put max/min scores of each QN in %max/%min
        #  3. put max/min scores of all QNs in %maxsc/%minsc

        if ($rank==1) { 

            # store max/min scores for preceeding query in %maxsc
            $maxsc{$qnum}{'orig'}=$sc; 
            if ($oldqnum) {
                $minsc{$oldqnum}{'orig'}=$oldsc;  
                foreach my $name(@vnames) {
                    $maxsc{$oldqnum}{$name}=$max{$name}; 
                    $minsc{$oldqnum}{$name}=$min{$name}; 
                }
            }
            # initialize max/min scores for each query
            foreach my $name(@vnames) {
                $max{$name}=0; 
                $min{$name}=1000; 
            }
        }

        foreach my $name(@vnames) {
            if (!$sc{$name}) { $sc{$name}=0; }
            else { 
                next if ($name=~/^av/);  # AV score is computed by density function
                $sc{$name} /= $sc{'tlen'}; 
            }
            $max{$name}=$sc{$name} if ($sc{$name}>$max{$name});
            $min{$name}=$sc{$name} if ($sc{$name}<$min{$name});
        }

        #---------------------------------------------------------
        ##!! update grouping
        # on-topic reranking groups:
        #  A = exact match of qtitle in both doc. title & body
        #  B = exact match of multi-term qtitle to doc. title
        #  C = exact match of qtitle to doc. body
        #  D = other
        # opinion reranking reranking groups: 
        #   - !!NOT used, bears investigation!!
        #  I. op1A > op2A > op1B > op2B > op1C > op2C > nopA > nopB > nopC > op2D > nopD
        #     - compensates for false negatives of opinion classification
        #  II. op1A > op2A > op1B > op2B > op1C > op2C > op2D > nopA > nopB > nopC > nopD
        #     - compensates for false negatives of exact match
        #  III. op1A > op2A > op1B > op2B > op1C > op2C > rest (score-boosted)
        #     - let fusion do the work for "rest"

        my ($opf,$opfx,$opf2,$opfx2,$group)=(0,0,0,0);
        foreach my $name(@vname3) { 
            next if (!$sc{$name}); 
            next if ($name=~/[NP]/);  # do not count polarity scores
            next if ($name=~/_[mp]/); # do not count multiple weights
            next if ($name=~/d/);     # do not count distance scores
            $opf++;
            $opfx++ if ($name=~/x/);  # proximity scores
            if ($name=~/iux|acx/) { $opfx2++; }
            elsif ($name=~/ac|lf|hf|w1/) { $opf2++; }
        }

        # penalty for docs w/o qtitle term
        if ($qtmflag && $qmatch<0) { $group='D5'; }

        elsif ($rank<=100) {
            if ($opfx || $opfx2) { $group='A1'; }
            elsif ($opf2) { $group='A2'; }
            elsif ($opf) { $group='A3'; }
            else { $group='A4'; }
        }
        elsif ($rank<=200) {
            if ($opfx || $opfx2) { $group='B1'; }
            elsif ($opf2) { $group='B2'; }
            elsif ($opf) { $group='B3'; }
            else { $group='B4'; }
        }  
        elsif ($rank<=300) {
            if ($opfx || $opfx2) { $group='C1'; }
            elsif ($opf2) { $group='C2'; }
            elsif ($opf) { $group='C3'; }
            else { $group='C4'; }
        }   
        else { 
            if ($opfx || $opfx2) { $group='D1'; }
            elsif ($opf2) { $group='D2'; }
            elsif ($opf) { $group='D3'; }
            else { $group='D4'; }
        }           
        
        # create opinion score string
        my @opstr;
        foreach my $name(@vnames) { push(@opstr,$sc{$name}); }
        my $opstr=join(" ",@opstr);
        push(@{$result{$qnum}},"$docno $rank $sc $group $run $opstr");

        $oldqnum=$qnum;
        $oldsc=$sc;
    }
    close TPIN;

    # store max/min scores for the last query in %maxsc
    $minsc{$oldqnum}{'orig'}=$oldsc;  
    foreach my $name(@vnames) {
        $maxsc{$oldqnum}{$name}=$max{$name}; 
        $minsc{$oldqnum}{$name}=$min{$name}; 
    }


    #-------------------------------------
    # 1. apply min-max normalization
    # 2. combine scores
    # 3. create reranking hashes by group
    # 4. rerank results by combined scores with group
    # 5. output reranked result
    #-------------------------------------

    my %OUT;
    open($OUT{'m'},">$outm") || die "can't write to $outm";
    open($OUT{'p'},">$outp") || die "can't write to $outp";
    open($OUT{'c'},">$outc") || die "can't write to $outc" if ($cwt);

    #my $debug=9;

    my %result0;
    foreach my $qn(sort {$a<=>$b} keys %result) {

        #-----------------------------------
        # read min-max scores into hashses for normalization
        my (%denom,%min2sc);
        foreach my $name('orig',@vnames) {
            $denom{$name}= $maxsc{$qn}{$name}-$minsc{$qn}{$name};
            $min2sc{$name}= $minsc{$qn}{$name};
            print "var=$name, qn=$qn, min=$minsc{$qn}{$name}, max=$maxsc{$qn}{$name}\n" if ($debug>8);
        }

        #-----------------------------------
        # create reranking hashes by group
        #  - %result1: exact match, qtitle to doc. title & doc. body
        #  - %result2: exact match, qtitle to doc. title
        #  - %result3: exact match, qtitle to doc. body
        #  - %result4: rest
        #  - key=docno, val=score
        my(%result1,%result2,%result3,%result4,%result5,%rest)=();

        #-----------------------------------
        # compute fusion scores for each result

        foreach my $line(@{$result{$qn}}) {
            chomp $line;
            my($docno,$rank,$orig,$group,$run,@opsc)= split/ +/,$line;
            print "$docno,$rank,$run\n" if ($debug>8);

            my %sc;        # opinion scores: k(name) = v(score)
            my %sc_norm;   # min-max normalized scores: k(name) = v(score)

            $sc{'orig'}=$orig;
            $sc_norm{'orig'}= $sc{'orig'};
            #!!!$sc_norm{'orig'}= ($sc{'orig'}-$min2sc{'orig'})/$denom{'orig'};

            my (%rr_sc,%rr_scP,%rr_scN);
            foreach my $k('m','c','p') {
                next if (!$cwt && ($k eq 'c'));
                $rr_sc{$k}=0;
                $rr_scP{$k}=0;
                $rr_scN{$k}=0;
            }

            if (@opsc) {
                # read scores (@opsc) into %sc
                for(my $k=0; $k<@vnames; $k++) {
                    $sc{$vnames[$k]}= $opsc[$k];
                }
                # apply min-max normalization
                foreach my $name(keys %sc) {
                    print "qn=$qn, sc($name)=$sc{$name}, min=$min2sc{$name}, denom=$denom{$name}\n" if ($debug>8);
                    if ($name=~/av/) {  # AV score is a density funciton and should not be normallized
                        $sc_norm{$name}= $sc{$name};
                    }
                    elsif ($sc{$name}) {
                        $sc_norm{$name}= $sc{$name};
                        #!!!$sc_norm{$name}= ($sc{$name}-$min2sc{$name})/$denom{$name};
                    }
                    else {
                        $sc_norm{$name}= 0;
                    }
                }

                # fusion score for opinion score boosting
                #  - optimization weights by DTuning of training data
                foreach my $name(@vnames) { 
                    # non-polarity scores
                    if ($name!~/[NP]/) { 
                        if ($name !~ /_[cp]/) { $rr_sc{'m'} += $fswt{$name}*$sc_norm{$name}; }
                        elsif ($name !~ /_[mc]/) { $rr_sc{'p'} += $fswt{$name}*$sc_norm{$name}; }
                        elsif ($cwt && $name !~ /_[mp]/) { $rr_sc{'c'} += $fswt{$name}*$sc_norm{$name}; }
                    }
                    else {
                        my $name2=$name;
                        $name2=~s/[NP]//;
                        # negative-polarity scores
                        if ($name=~/^(.+?)N/) { 
                            if ($name !~ /_[cp]/) { $rr_scN{'m'} += $fswt{$name2}*$sc_norm{$name}; }
                            elsif ($name !~ /_[mc]/) { $rr_scN{'p'} += $fswt{$name2}*$sc_norm{$name}; }
                            elsif ($cwt && $name !~ /_[mp]/) { $rr_scN{'c'} += $fswt{$name2}*$sc_norm{$name}; }
                        }
                        # positive-polarity scores
                        elsif ($name=~/^(.+?)P/) {
                            if ($name !~ /_[cp]/) { $rr_scP{'m'} += $fswt{$name2}*$sc_norm{$name}; }
                            elsif ($name !~ /_[mc]/) { $rr_scP{'p'} += $fswt{$name2}*$sc_norm{$name}; }
                            elsif ($cwt && $name !~ /_[mp]/) { $rr_scP{'c'} += $fswt{$name2}*$sc_norm{$name}; }
                        }
                    }
                }

            } #end-if (@opsc) 

            foreach my $k('m','c','p') {

                next if (!$cwt && ($k eq 'c'));

                my $score= $fswt{'ORIG'}*$sc_norm{"orig"} + $fswt{'RR'}*$rr_sc{$k};
                my $scoreN= $fswt{'ORIG'}*$sc_norm{"orig"} + $fswt{'RR'}*$rr_scN{$k};
                my $scoreP= $fswt{'ORIG'}*$sc_norm{"orig"} + $fswt{'RR'}*$rr_scP{$k};

                # create reranking hashes by rerank group
                #  !! try $group? !!
                if ($rank<=$maxrank) {
                    if ($group=~/A/) { $result1{$k}{$docno}=$score; }
                    elsif ($group=~/B/) { $result2{$k}{$docno}=$score; }
                    elsif ($group=~/C/) { $result3{$k}{$docno}=$score; }
                    else { $result4{$k}{$docno}=$score; }
                }

                # for results beyond rerank range
                #   1. set score to 0 if rrlow flag is not set
                #   2. assign their own rerank sort group
                else {
                    if (!$rrlow) { $score=0; }
                    $result5{$k}{$docno}=$score;
                    push(@{$rest{$k}},$docno);
                }

                # create normalized scores string
                if (@opsc) {
                    my @opstr;
                    # !!!minmax-normalized scores
                    foreach my $name(@{$vnames{$k}}) { 
                        push(@opstr,sprintf("%.4f",$sc_norm{$name})); 
                    }
                    # add polarity scores at the end
                    push(@opstr,sprintf("%.4f",$scoreP));
                    push(@opstr,sprintf("%.4f",$scoreN));
                    my $opstr=join(" ",@opstr);

                    # store normalized scores in %result0
                    $result0{$k}{"$qn:$docno"}= "$group $rank $orig $run $opstr";
                }
                else {
                    $result0{$k}{"$qn:$docno"}= "$group $rank $orig $run";
                }

            } #end-foreach $k

        } #end-foreach $line

        #-----------------------------------
        # rerank results by group and output
        #-----------------------------------

        foreach my $k('m','c','p') {

            next if (!$cwt && ($k eq 'c'));

            my ($OUT,$rank,$rank2,$score,$offset,$oldsc)=($OUT{$k},0,0,0,0,1);
            
            foreach my $docno(sort {$result1{$k}{$b}<=>$result1{$k}{$a}} keys %{$result1{$k}}) {
                $score= sprintf("%.7f",$result1{$k}{$docno});
                my ($grp,$rank0,$sc,$run,$restsc)=split(/\s+/,$result0{$k}{"$qn:$docno"},5);
                $rank++;
                # convert zero/negative score to non-zero value
                if ($score<=0) { $score= sprintf("%.7f",$oldsc-$oldsc*0.1); }
                print $OUT "$qn $docno $rank $score $grp $run $rank0 $sc $restsc\n";
                $oldsc=$score;
            }
            
            ($rank,$score,$oldsc)=&rrgrp($OUT,$result2{$k},$result0{$k},$qn,$rank,$score,$oldsc);
            ($rank,$score,$oldsc)=&rrgrp($OUT,$result3{$k},$result0{$k},$qn,$rank,$score,$oldsc);
            ($rank,$score,$oldsc)=&rrgrp($OUT,$result4{$k},$result0{$k},$qn,$rank,$score,$oldsc);
            ($rank,$score,$oldsc)=&rrgrp2($OUT,$result5{$k},$result0{$k},$qn,$rank,$score,$oldsc,$rest{$k});

            print LOG "!Warning: Topic $qn has only $rank results.\n" if ($rank<1000);

        } #end-foreach $k

    } #end-foreach $qn

    close $OUT{'m'};
    close $OUT{'c'} if ($cwt);
    close $OUT{'p'};

} #endsub mkRRF


sub rrgrp {
    my($OUT,$rhp,$r0hp,$qn,$rank,$score,$oldsc)=@_;

    my $rank2=1;
    my $offset=0;
    foreach my $docno(sort {$rhp->{$b}<=>$rhp->{$a}} keys %$rhp) {
        # offset: to ensure correct sorting/ranking for the whole result
        if ($rank2==1 && $rhp->{$docno}>$score) {
            $score -= $score*0.1;
            $offset= $score/$rhp->{$docno};
            print STDOUT "$docno: sc1=$rhp->{$docno}, sc2=$score, off=$offset\n" if ($debug);
        }
        if ($offset) { $score= sprintf("%.7f",$rhp->{$docno}*$offset); }
        else { $score= sprintf("%.7f",$rhp->{$docno}); }
        my ($grp,$rank0,$sc,$run,$restsc)=split(/\s+/,$r0hp->{"$qn:$docno"},5);
        $rank++;
        # convert zero/negative score to non-zero value
        if ($score<=0) { $score= sprintf("%.7f",$oldsc-$oldsc*0.1); }
        if ($restsc) {
            print $OUT "$qn $docno $rank $score $grp $run $rank0 $sc $restsc\n";
        }
        else {
            print $OUT "$qn $docno $rank $score $grp $run $rank0 $sc\n";
        }
        $rank2++;
        $oldsc=$score;
    }

    return($rank,$score,$oldsc);

} #endsub rrgrp


sub rrgrp2 {
    my($OUT,$rhp,$r0hp,$qn,$rank,$score,$oldsc,$rlp)=@_;

    my $rank2=1;
    my $offset=0;
    foreach my $docno(@{$rlp}) {
        # offset: to ensure correct sorting/ranking for the whole result
        if ($rank2==1 && $rhp->{$docno}>$score) {
            $score -= $score*0.1;
            $offset= $score/$rhp->{$docno};
            print STDOUT "$docno: sc1=$rhp->{$docno}, sc2=$score, off=$offset\n" if ($debug);
        }
        if ($offset) { $score= sprintf("%.7f",$rhp->{$docno}*$offset); }
        else { $score= sprintf("%.7f",$rhp->{$docno}); }
        my ($grp,$rank0,$sc,$run,$restsc)=split(/\s+/,$r0hp->{"$qn:$docno"},5);
        $rank++;
        # convert zero/negative score to non-zero value
        if ($score<=0) { $score= sprintf("%.7f",$oldsc-$oldsc*0.1); }
        if ($restsc) {
            print $OUT "$qn $docno $rank $score $grp $run $rank0 $sc $restsc\n";
        }
        else {
            print $OUT "$qn $docno $rank $score $grp $run $rank0 $sc\n";
        }
        $rank2++;
        $oldsc=$score;
    }

    return($rank,$score,$oldsc);

} #endsub rrgrp


sub readwts {
    my $inf=shift;

    open(IN,$inf) || die "can't read $inf";

    my %wts;
    while(<IN>) {
        /'(\w+?)'=>([\d\.\-]+)/;
        $wts{$1}=$2;
    }

    close IN;

    return (%wts);

}

