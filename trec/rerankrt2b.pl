#!/usr/bin/perl -w

# -----------------------------------------------------------------
# Name:      rerankrt2b.pl
# Author:    Kiduk Yang, 06/26/2008
#            modified rerankrt2qeOptnew1b.pl (6/2008)
#              - scores are min-max normalized (TI2 & BD2 scores are too large!!)
#            modified rerankrt2.pl, 7/2/2008
#              - topic RR scores are not normalized
#              $Id: rerankrt2qeOpt.pl,v 1.1 2008/04/25 01:06:31 kiyang Exp $
# -----------------------------------------------------------------
# Description:  Perform post-retrieval ontopic reranking (optimized formula)
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
#            arg3= fusion weight file
#            arg4= number of docs to rerank (e.g. 500)
#            arg5= 1 to rerank results beyond maxrank in a group (optional)
# INPUT:     $ddir/results/$qtype/trecfmt(x)/$arg2.R/rall7/*.1
#              -- results w/ topic reranking scores
# OUTPUT:    $ddir/results/$qtype/trecfmt(x)/$arg2.R/*-$arg3.r1
#            $ddir/rtlog/$prog      -- program     (optional)
#            $ddir/rtlog/$prog.log  -- program log (optional)
#            NOTE: $qtype   = query type (train|test)
# -----------------------------------------------------------------
# NOTES: 
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

my $wpdir=  "/u0/widit/prog";           # widit program directory
my $tpdir=  "$wpdir/trec08";            # TREC program directory
my $pdir=   "$tpdir/blog";              # TREC program directory
my $ddir=   "/u3/trec/blog08";          # index directory
my $qdir=   "$ddir/query";              # topic directory
my $logd=   "$ddir/rrlog";              # log directory

# query type
my %qtype= ("e"=>"test","ex"=>"test","t"=>"train","tx"=>"train","tx2"=>"train2","ex2"=>"test2");

require "$wpdir/logsub2.pl";


#------------------------
# program arguments
#------------------------
my $prompt=
"arg1= query type (i.e. t, tx, e, ex)\n".
"arg2= result subdirectory (e.g. s0)\n".
"arg3= topic rerank weight filename\n".
"arg4= number of docs to rerank (optional: default=500)\n".
"arg5= 1 to rerank results beyond maxrank in a group (optional)\n";

my %valid_args= (
0 => " t tx e ex tx2 ex2 ",
1 => " s0* ",
);

my ($arg_err,$qtype,$rsubd,$fwtf,$maxrank,$rrlow)= chkargs($prompt,\%valid_args,3);
die "$arg_err\n" if ($arg_err);
die "bad fusion weight file: $fwtf\n" if (!-e "fswtd/tprr/$fwtf");

$maxrank=MAXRANK if (!$maxrank);


# reranking weights
my %fswt=&readwts("fswtd/tprr/$fwtf");

# processed query directory
my $qrydir= "$qdir/$qtype{$qtype}";

# TREC format directory
my $rdir= "$ddir/results/$qtype{$qtype}/trecfmt/$rsubd"."Rb";
$rdir=~s/trecfmt/trecfmtx/ if ($qtype=~/x/);

my $ind= "$rdir/rall7";  # original ranking w/ opinion scores


#-------------------------------------------------
# start program log
#-------------------------------------------------

$sfx= "$qtype$rsubd-$fwtf"; # program log file suffix

$sfx .= 'L' if ($rrlow);

$noargp=0;              # if 1, do not print arguments to log
$append=0;              # log append flag

# logs for different runs are appended to the same log file
if ($log) {
    @start_time= &begin_log($logd,$filemode,$sfx,$noargp,$append);
    my @str;
    foreach my $name(sort keys %fswt) {
        push(@str,"    $name => $fswt{$name}");
    }
    my $wtstr= join("\n",@str);
    print LOG "InF   = $ind/*.1\n",
              "OutF  = $rdir/*-$fwtf.r1\n\n";
    print LOG "fusion weights:\n$wtstr\n\n";
}

#-------------------------------------------
# create query title hash
#   %qtitle: k=QN, v=title
#-------------------------------------------

opendir(IND,$qrydir) || die "can't opendir $qrydir";
my @files= readdir(IND);
closedir IND;

my %qtitle;
foreach my $file(@files) {
    
    next if ($file!~/^q(\d+)/);
    my $qn=$1;
    
    my $inf="$qrydir/$file";
    open(IN,$inf) || die "can't read $inf";
    my @lines=<IN>;
    close IN;
    #chomp @lines;
    
    my $bstring= join("",@lines);
    
    # get title text
    if ($bstring=~m|<title>(.+?)</title>|s) {
        my $str=$1;
        $str=~m|<text>(.+?)</text>|s;
        my $ti=$1;
        $ti=~s/^['"]?(.+?)['"]$/$1/;
        $qtitle{$qn}=$ti;
    }

} #end-foreach $file(@files)


#-------------------------------------------
# create topic reranked files
#-------------------------------------------

opendir(IND,$ind) || die "can't opendir $ind";
@files=readdir(IND);
closedir IND;


foreach my $file(@files) {
    next if ($file !~ /^(.+?)\.1$/);

    my $fname=$1;
    my $outf= "$rdir/$fname-$fwtf.r1";
    $outf=~s/($fname)/$1L/ if ($rrlow);
    my $inf= "$ind/$file";

    print "Reading $inf\n";
    print "Writing to  $outf\n";

    &mkRRf($inf,$outf,\%qtitle);

}

#-------------------------------------------------
# end program
#-------------------------------------------------

&end_log($pdir,$logd,$filemode,@start_time) if ($log);

# notify author of program completion
#&notify($sfx,$author);


#######################
# SUBROUTINES
#######################

BEGIN { print STDOUT "\n"; }
END { print STDOUT "\n"; }

#-------------------------------------------
# create hashes
#   %result: 
#     - k=QN 
#     - v= pointer to array of "DOCNO RANK Orig_SC Rerank_SC RunName"
#-------------------------------------------
# %maxsc: k(QN -> scName) = v(max_sc)
# %minsc: k(QN -> scName) = v(min_sc)
# %max: k(scName) = v(max_sc)
# %min: k(scName) = v(min_sc)
# @vnames: topic reranking score names
#-------------------------------------------
sub mkRRf {
    my($inf,$outf,$qtihp)=@_;

    my ($oldqnum,$oldsc,%result,%maxsc,%minsc,%max,%min);

    # ex1=TI, ex2=BD, px1=TIX, px2=BDX, px3=BDX2, ph=PH, ph2=PH2, nr=NRPH, nr2=NRN
    #   - not Used: wx1=TI2, wx2=BD2
    my @vnames=('ex1','ex2','px1','px2','px3','ph','ph2','nr','nr2');

    open(INF,$inf) || die "can't read $inf";
    while(<INF>) {
        chomp;

        my %sc;

        my ($qnum,$docno,$rank,$sc,$run,$extsc1,$extsc2,$wxsc1,$wxsc2,$prxsc1,$prxsc2,$prxsc3,$phsc,$phsc2,$nrsc,$nrsc2)=split/\s+/;

        # set missing scores to zero
        #  - when rerank scoring is limited to top N ranks, 
        #    rerank scores will be missing (see rerank24merge.pl)
        my $k=0;
        foreach my $sc2($extsc1,$extsc2,$prxsc1,$prxsc2,$prxsc3,$phsc,$phsc2,$nrsc,$nrsc2) {
            my $name= $vnames[$k];
            if (defined($sc2)) { $sc{$name}=$sc2; }
            else { $sc{$name}=0; } 
            $k++;
        }

        # for score min-max normalization
        #  - results are ranked by QN, orig_sc:
        #    max/min sc= first/last in QN
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

        #  set min-max values
        foreach my $name(@vnames) {
            $max{$name}=$sc{$name} if ($sc{$name}>$max{$name});
            $min{$name}=$sc{$name} if ($sc{$name}<$min{$name});
        }

        if ($debug) {
            print "qn=$qnum, dn=$docno, rnk=$rank, ex1=$extsc1, ex2=$extsc2, ",
                "px1=$prxsc1, px2=$prxsc2, px3=$prxsc3, ph=$phsc, ph2=$phsc2, nr=$nrsc, nr2=$nrsc2\n";
        }

        # flag multi-term query
        my $qphrase=0;
        $qphrase=1 if ($qtihp->{$qnum}=~/ /);

        # reranking groups:
        #  1 = exact match of qtitle in both doc. title & body
        #  2 = exact match of multi-term qtitle to doc. title
        #  3 = exact match of qtitle to doc. body 
        #  4 = other in rerank range
        #  5 = beyond rerank range
        my $group;
        if ($sc{'ex1'}>0 && $sc{'ex2'}>0) { $group=1; }
        elsif ($sc{'ex1'}>0 && $qphrase) { $group=2; }
        elsif ($sc{'ex2'}>0) { $group=3; }
        else { $group=4; }

        # create topicRR score string
        my @tpstr;
        foreach my $name(@vnames) { push(@tpstr,$sc{$name}); }
        my $tpstr=join(" ",@tpstr);
        push(@{$result{$qnum}},"$docno $rank $sc $group $run $tpstr");

        $oldqnum=$qnum;
        $oldsc=$sc;
    }
    close INF;

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
            
    open(OUT,">$outf") || die "can't write to $outf";
        
    # k=QN:docno, v=result line from on-topic reranking plus opinion scores
    my %result0;

    foreach my $qn(sort {$a<=>$b} keys %result) {

        #-----------------------------------
        # read min-max scores into hashses for normalization
        my (%denom,%min2sc);
        foreach my $name('orig',@vnames) {
            $denom{$name}= $maxsc{$qn}{$name}-$minsc{$qn}{$name};
            $min2sc{$name}= $minsc{$qn}{$name};
            print "var=$name, qn=$qn, min=$minsc{$qn}{$name}, max=$maxsc{$qn}{$name}\n" if ($debug);
        }   

        # create reranking hashes by group
        #  - %result1: exact match, qtitle to doc. title & doc. body
        #  - %result2: exact match, qtitle to doc. title
        #  - %result3: exact match, qtitle to doc. body
        #  - %result4: rest
        #  - key=docno, val=score
        my(%result1,%result2,%result3,%result4,%result5)=();

        foreach my $line(@{$result{$qn}}) {
            chomp $line;
            my($docno,$rank,$orig,$group,$run,@tpsc)= split/ +/,$line;
            print "$orig,$rank,$run\n" if ($debug>99);
            
            my %sc;        # opinion scores: k(name) = v(score) 
            my %sc_norm;   # min-max normalized scores: k(name) = v(score)
            
            $sc{'orig'}=$orig;
            $sc_norm{'orig'}= ($sc{'orig'}-$min2sc{'orig'})/$denom{'orig'};
            
            my $rr_sc=0;
            
            if (@tpsc) {
                # read scores (@tpsc) into %sc 
                for(my $k=0; $k<@vnames; $k++) {
                    $sc{$vnames[$k]}= $tpsc[$k];
                } 
                # apply min-max normalization
                foreach my $name(keys %sc) {
                    print "qn=$qn, sc($name)=$sc{$name}, min=$min2sc{$name}, denom=$denom{$name}\n" if ($debug);
                    if ($sc{$name}) {
                        $sc_norm{$name}= ($sc{$name}-$min2sc{$name})/$denom{$name};
                    }
                    else {
                        $sc_norm{$name}= 0;
                    }
                }
                
                # fusion score for opinion score boosting
                #  - optimization weights by DTuning of training data
                foreach my $name(@vnames) {
                    $rr_sc += $fswt{$name}*$sc{$name}; 
                }
            
            } #end-if (@tpsc)
            
            # fusion score for on-topic score boosting
            # NOTE:
            #  1. since topic reranking scores are essentially IR similarity scores
            #     between query & document and computed in similar fashion among them,
            #     they are not normalized for fusion as will be done with opinion scores
            #  2. original scores are min/max normalized when combining w/ reranking scores
            #     in order to dampen the effect of original ranking
            my $score= $fswt{'ORIG'}*$sc_norm{"orig"} + $fswt{'RR'}*$rr_sc;
            
            # create reranking hashes by rerank group
            if ($rank<=$maxrank) {
                if ($group==1) { $result1{$docno}=$score; }
                elsif ($group==2) { $result2{$docno}=$score; }
                elsif ($group==3) { $result3{$docno}=$score; }
                elsif ($group==4) { $result4{$docno}=$score; }
            } 

            # for results beyond rerank range
            #   1. set score to 0 if rrlow flag is not set
            #   2. assign their own rerank sort group
            else {
                if (!$rrlow) { $score=0; }
                $group=5;
                $result5{$docno}=$score;
            }

            # create reranking scores string
            if (@tpsc) {
                my @tpstr;
                foreach my $name(@vnames) { push(@tpstr,sprintf("%.4f",$sc{$name})); }
                my $tpstr=join(" ",@tpstr);
                # store scores in %result0
                $result0{"$qn:$docno"}= "$group $rank $orig $run $tpstr";
            }       
            else {  
                $result0{"$qn:$docno"}= "$group $rank $orig $run";
            }       
                

        } #end-foreach $line

        #-----------------------------------
        # rerank results by group and output
        #-----------------------------------

        my ($rank,$rank2,$score,$offset,$oldsc)=(0,0,0,0,1);

        foreach my $docno(sort {$result1{$b}<=>$result1{$a}} keys %result1) {
            $score= sprintf("%.7f",$result1{$docno});
            my ($grp,$rank0,$sc,$run,$restsc)=split(/\s+/,$result0{"$qn:$docno"},5);
            $rank++;
            # convert zero/negative score to non-zero value
            if ($score<=0) { $score= sprintf("%.7f",$oldsc-$oldsc*0.1); }
            print OUT "$qn $docno $rank $score $grp $run $rank0 $sc $restsc\n";
            $oldsc=$score;
        }

        ($rank,$score,$oldsc)=&rrgrp(\%result2,\%result0,$qn,$rank,$score,$oldsc);
        ($rank,$score,$oldsc)=&rrgrp(\%result3,\%result0,$qn,$rank,$score,$oldsc);
        ($rank,$score,$oldsc)=&rrgrp(\%result4,\%result0,$qn,$rank,$score,$oldsc);
        ($rank,$score,$oldsc)=&rrgrp(\%result5,\%result0,$qn,$rank,$score,$oldsc);

        print LOG "!Warning: Topic $qn has only $rank results.\n" if ($rank<1000);

    } #end-foreach $qn
    close OUT;

} #endsub mkRRF


sub rrgrp {
    my($rhp,$r0hp,$qn,$rank,$score,$oldsc)=@_;

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
            print OUT "$qn $docno $rank $score $grp $run $rank0 $sc $restsc\n";
        }
        else {
            print OUT "$qn $docno $rank $score $grp $run $rank0 $sc\n";
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


