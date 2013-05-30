#!/usr/bin/perl -w

# -----------------------------------------------------------------
# Name:      evalrt.pl
# Author:    Kiduk Yang, 07/03/2005
#            modified by Kiduk, 7/30/2006
#            modified by Ning, 10/25/2006
#              (update to adapt to the new treceval output format)
#            modified by Kiduk, 11/03/2006
#            modified by Kiduk, 06/23/2007
#            modified by Kiduk, 04/18/2008 to add the 3rd argument
# -----------------------------------------------------------------
# Description: produce summary evaluations from treceval results
#   1. for each eval subdirectory (s0, s0R),
#      a. extract avg. eval measures from individual trec_eval results
#      b. output to *.eall file (s0.eall, s0R.eall)
#   2. generate eval stats from *.eall files
# -----------------------------------------------------------------
# ARGUMENT:  arg1= query type (i.e. t=train, e=test)
#            arg2= result subdirectory (optional: results, results_old)
#            arg3= eval subdirectory (optional: s0, s0R, s0R1, s0wk, s0gg, etc.)
# INPUT:
#     $evald/$subd/* - treceval files
# OUTPUT: 
#     $evald/*.eall  - summary eval file
#     $evald/$prog      -- program     (optional)
#     $evald/$prog.log  -- program log (optional)
#     ./eval/evalrt.pl_$arg1.log - overall eval stat file
#     ./eval/evalrt.pl_$arg1.log2 - ranking of all runs
#     ./eval/evalrt.pl_$arg1.log3 - score with all factor info
#     ./eval/evalrt.pl_$arg1.log4 - score of pairs for each factor
# -----------------------------------------------------------------

use strict;
use Data::Dumper;
$Data::Dumper::Purity=1;

my ($debug,$filemode,$filemode2,$dirmode,$dirmode2,$author,$group);
my ($log,$logd,$sfx,$noargp,$append,@start_time);


$log=1;                              # program log flag
$debug=0;                            # debug flag
$filemode= 0640;                     # to use w/ perl chmod
$filemode2= 640;                     # to use w/ system chmod
$dirmode= 0750;                      # to use w/ perl mkdir
$dirmode2= 750;                      # to use w/ system chmod (directory)
$group= "trec";                      # group ownership of files
$author= "kiyang\@indiana.edu";      # author's email

print "$debug,$filemode,$filemode2,$dirmode,$dirmode2,$author,$group\n" if ($debug);


#------------------------
# global variables
#------------------------

my $wpdir=  "/u0/widit/prog";           # widit program directory
my $tpdir=  "$wpdir/trec08";            # TREC program directory
my $pdir=   "$tpdir/blog";              # TREC program directory
my $ddir=   "/u3/trec/blog08";          # index directory

# query type
my %qtypes= ("e"=>"test","t"=>"train");

my @measures = ('MAP','MRP','P10'); #!!NY
my @levels = ('topic', 'opinion');#!!NY

require "$wpdir/logsub2.pl";


#------------------------
# program arguments
#------------------------
my $prompt=
"arg1= query type (i.e. t=train, e=test)\n".
"arg2= result subdirectory (optional: results, results_old)\n".
"arg3= eval subdirectory (optional: s0, s0R, s0wk, s0gg, etc.)\n";

my %valid_args= (
0 => " t e ",
);

my ($arg_err,$qtype,$resultd,$evalsubd)= chkargs($prompt,\%valid_args,1);
die "\n$arg_err\n" if ($arg_err);

$sfx=$qtype;
$resultd="results" if (!$resultd);
$sfx .= "_$1" if ($resultd=~/results(.+)$/);
$sfx .= $evalsubd if ($evalsubd);

my $evald= "$ddir/$resultd/$qtypes{$qtype}/eval";
my $pname=$0;
$pname=~s|\.|./eval|;
my $logf= $pname."_$sfx.log";
my $logf2= $pname."_$sfx.log2";
my $logf3= $pname."_$sfx.log3";
my $logf4= $pname."_$sfx.log4";


#-------------------------------------------------
# start program log
#-------------------------------------------------

$noargp=0;              # if 1, do not print arguments to log
$append=0;              # log append flag

if ($log) {
    @start_time= &begin_log($evald,$filemode,$sfx,$noargp,$append);
    print LOG "InD = $evald\n\n";
}


#-------------------------------------------
# for each eval subdirectory (s0, s0R)
#   1. read individual trec_eval results
#   2. extract eval measures for all queries 
#   3. output to *.eall file
#-------------------------------------------

opendir(IND,$evald) || die "can't opendir $evald";
my @dirs=readdir(IND);
closedir IND;

my @eall;
foreach my $dir(@dirs) {

    next if ($evalsubd && ($dir ne $evalsubd));
    next if ($dir=~/^\./ || !-d "$evald/$dir");

    my ($fcnt,@fnames)=&chkdir("$evald/$dir");
    die "Empty Directory: $evald/$dir\n" if ($fcnt<1);

    my $outf= $dir.".eall";

    # MAP, MRP, P10
    my $ec = system "tail --lines=25 $evald/$dir/*_topic $evald/$dir/*_opinion > $evald/$outf";#!!NY
    die "Error ($ec): tail --lines=25 $evald/$dir/*_topic $evald/$dir/*_opinion > $evald/$outf" if ($ec); #!!NY

    # MAP only
    #my $ec = system "tail --lines=25 $evald/$dir/*_* | grep -A1 '==' > $evald/$outf";
    #die "Error ($ec): tail --lines=25 $evald/$dir/*_* | grep -A1 '==' > $evald/$outf" if ($ec); 

    # add filename header manually when only 1 file in a directory
    if ($fcnt==1) {
        my $line= `cat $evald/$outf`;
	open(OUT,">$evald/$outf") || die "can't write to $evald/$outf";
	print OUT "==> $evald/$dir/$fnames[0] <==\n";
	print OUT $line;
	close OUT;
    }

    print LOG "OutF= $outf\n" if ($log);

    push(@eall,$outf);

}


#-------------------------------------------
# Generate eval stats from *.eall files
#-------------------------------------------

open(OUT,">$logf") || die "can't write to $logf"; 
open(OUT2,">$logf2") || die "can't write to $logf2"; 
open(OUT3,">$logf3") || die "can't write to $logf3";
open(OUT4,">$logf4") || die "can't write to $logf4";

my (%all,%allbyql)=();
my %allbyfactors = ();

foreach my $file(@eall) {

    $file=~/^(.+?)\.eall/;
    my $subd=$1;
    my $name="";

    my %all_stat=();

    open(IN,"$evald/$file") || die "can't read $evald/$file";
    my ($eLevel,$fullfactor);
    while(<IN>) {
        #!!NY the session below has changed
        if (m|==> $evald/$subd/(.+?)\_?([^\_]+?) <==|) {
            $name=$1;
            $eLevel=$2; #eval level
            $fullfactor = $name;
            if ($fullfactor !~ /(vsm|okapi)/i){
                $fullfactor = 'null_'.$fullfactor;
            }
            #take care of the bugs such as qf2_trec.r0_trecx_opinion
            if ($fullfactor =~ /_trec\.r/){
                $fullfactor =~ s/_trec\.r/\.r/;
            }
            #for the reranking +500 okapifL.r1_trecx_topic
            if ($fullfactor =~ /L\.r(.*?)_trec/){
                 $fullfactor =~ s/L\.r(.*?)_trec/\.r$1L_trec/;
            }
           if ($fullfactor !~ /q/i){
                $fullfactor =~ s/^(\w+?)\.(.*?)$/$1\|null\|$2/;
            }
            #tWeight|qLength|rerankType|w/(o)noise
            $fullfactor =~ s/[\.\-\_]/\|/g; 
        }
        elsif (/^map\s*/i) {
            if (/\s+(\d\.\d+)\s*$/){
                $all_stat{'MAP'}{$eLevel}{$name}=$1;
                $allbyfactors{$eLevel}{$subd}{$fullfactor}{'MAP'}=$1;
            }
        }
        elsif (/^P10\s+/i) {
            if (/\s+(\d\.\d+)\s*$/){
                $all_stat{'P10'}{$eLevel}{$name}=$1;
                $allbyfactors{$eLevel}{$subd}{$fullfactor}{'P10'}=$1;
            }
        }
        elsif (/^R-prec/i) {
            if (/\s+(\d\.\d+)\s*$/){
                $all_stat{'MRP'}{$eLevel}{$name}=$1;
                $allbyfactors{$eLevel}{$subd}{$fullfactor}{'MRP'}=$1;
            }
        }
    }
    close IN;

    foreach my $measure(@measures){

         print OUT "-----------------------------------------\n";
         print OUT "$measure for $file:\n";
         print OUT "-----------------------------------------\n";

         foreach my $level(keys %{$all_stat{$measure}}){

            my (%bql,%bql2,$bqlf)=();

            print OUT "*****************************************\n";
            print OUT "At $level Level:\n";
            print OUT "*****************************************\n";

            foreach my $k(sort {$all_stat{$measure}{$level}{$b}<=>$all_stat{$measure}{$level}{$a}} keys %{$all_stat{$measure}{$level}}) {
                my $sc=sprintf("%.4f",$all_stat{$measure}{$level}{$k});
                printf OUT "%-25s %10s\n",$k,$sc;
                #$k=~/([a-z0-9]+)_q([ls])/; #!!NY we only care about l and s , right?
                #my $model=$1; #!!NY
                my $qlen;
                if ($k=~/q([ls])/){
                   $qlen=$1;
                }
                else { $qlen='f'; }
                $all{$measure}{$level}{"$subd-$k"}=$sc;
                $allbyql{$measure}{$level}{$qlen}{"$subd-$k"}=$sc;
                if (!defined($bql{$qlen})) {
                    $bql{$qlen}= $sc;
                    $bql2{$qlen}= $k;
                    $bqlf++;
                }
            }#end of for each run

            if ($bqlf) {
                print OUT "\nBest $measure by Query Length ($file):\n";
                foreach my $ql(sort {$bql{$b}<=>$bql{$a}} keys %bql) {
                   printf OUT "%-25s %10s\n",$bql2{$ql},$bql{$ql};
                }
            }

            print OUT "\n";

       }#end of foreach level

    }#end of foreach measure

} #end-foreach $file(@eall) {


print OUT "\n";
foreach my $m(@measures){
   foreach my $l(@levels){
      &print_best("$m ($l)",\%{$all{$m}{$l}},\%{$allbyql{$m}{$l}});
   }
}

foreach my $l(@levels){
  foreach my $d(keys %{$allbyfactors{$l}}){
    print OUT3 "=> $l:$d <=\n";
    print OUT3 "tWeight|qLength|rerankType|w/(o)noise|MAP|MRP|P10\n";
    foreach my $f(keys %{$allbyfactors{$l}{$d}}){
       print OUT3 $f.'|'.$allbyfactors{$l}{$d}{$f}{'MAP'}.'|'.$allbyfactors{$l}{$d}{$f}{'MRP'}.'|'.$allbyfactors{$l}{$d}{$f}{'P10'}."\n";
    }
  }
}
&eval_factor(\%allbyfactors,'qlength');
&eval_factor(\%allbyfactors,'tweight');
&eval_factor(\%allbyfactors,'noise');
&eval_factor(\%allbyfactors,'rerank');
#&eval_factor(\%allbyfactors,'evalLevel');

close OUT;
close OUT2;
close OUT3;
close OUT4;

if ($log) {
    foreach my $f($logf,$logf2,$logf3,$logf4) {
        $f=~s/\./$pdir/;
        print LOG "LogF= $f\n";
    }
}


#-------------------------------------------------
# end program
#-------------------------------------------------

&end_log($pdir,$evald,$filemode,@start_time) if ($log);

# notify author of program completion
#&notify($sfx,$author);




######################
# Subroutines
######################


sub eval_factor {
    my($allbyfactorshp,$factor)=@_;
    #tWeight|qLength|rerankType|w/(o)noise

    print OUT4 "##########################################\n";
    print OUT4 " affect of $factor\n";
    print OUT4 "------------------------------------------\n";

    my %fposition = ('qlength'=>2, 'tweight'=>1, 'noise'=>4, 'rerank'=>3);
    my $index = $fposition{$factor}-1;
    my %pairs=();
    my %mvalues=(); #matched factor values
    foreach my $l(@levels){
      foreach my $d(keys %{$$allbyfactorshp{$l}}){
        foreach my $f(keys %{$$allbyfactorshp{$l}{$d}}){
           my @fs = split(/\|/,$f);
           my $fvalue = $fs[$index];
           #if($fvalue eq 'null'){next;}
           #if($fvalue eq 'q'){next;}
           $f =~ /^(.*?)\|?$fvalue(.*?)$/;
           my $other;
           if($2){$other = $1.$2;}
           else{$other=$1;}
           $other =~ s/\|\|/\|/;
           $other =~ s/^\|//;
           $other =~ s/\|/\_/g;
           $pairs{$l}{$d}{$other}{$fvalue}=$f;
           $mvalues{$fvalue}++;
        }
      }
    }
    
    foreach my $l(@levels){
      foreach my $d(keys %{$$allbyfactorshp{$l}}){
        print OUT4 "=> $l:$d <=\n";
        print OUT4 " ";
        foreach my $m(@measures){
           foreach(sort keys %mvalues){
              print OUT4 '|'.$_.'_'.$m;
           }
        }
        print OUT4 "\n";

        foreach my $other(sort keys %{$pairs{$l}{$d}}){
           next if (keys(%{$pairs{$l}{$d}{$other}})<2);
           print OUT4 "$other";
           foreach my $m(@measures){
               foreach my $match(sort keys %mvalues){
                  if(exists($pairs{$l}{$d}{$other}{$match})){
                      my $rname=$pairs{$l}{$d}{$other}{$match};
                      print OUT4 "|$$allbyfactorshp{$l}{$d}{$rname}{$m}";
                 }
                 else{
                      print OUT4 "| ";
                 }
              }
           }
           print OUT4 "\n";
        }
       }
     }

}#end sub eval_factor



sub print_best {
    my($type,$allhp,$allbyqlhp)=@_;

    print OUT "##########################################\n";
    print OUT "10 Best $type Runs:\n";
    print OUT "------------------------------------------\n";
    my (%best,%best2)=();
    my $cnt=1;
    foreach my $k(sort {$$allhp{$b}<=>$$allhp{$a}} keys %$allhp) {
       #!!NY
       my $qlen = '';
       if ($k=~/q([ls])/){
          $qlen=$1 ;
       }
       else{
           $qlen='f';
       }
	printf OUT "%-25s %10s\n",$k,$$allhp{$k} if ($cnt<=10);
	my $k2=$k;
	$k2=~s|-|/|;
	if ($qlen && !defined $best{$qlen}) {
	    $best{$qlen}= $$allhp{$k};
	    $best2{$qlen}= $k;
	}
	$cnt++;
    }
    print OUT "\n";


    foreach my $k(sort keys %$allbyqlhp) {
	print OUT "3 Best $type Runs by Query Length = $k\n";
	print OUT "-----------------------------------------\n";
	$cnt=1;
	foreach my $k2(sort {$$allbyqlhp{$k}{$b}<=>$$allbyqlhp{$k}{$a}} keys %{$$allbyqlhp{$k}}) {
	    printf OUT "%-25s %10s\n",$k2,$$allbyqlhp{$k}{$k2} if ($cnt<=3);
	    my $k3=$k2;
	    $k3=~s|-|/|;
	    $cnt++;
	}
	print OUT "\n";
    }
    print OUT "\n";


    print OUT "Best $type by Query Length (Overall):\n";
    print OUT "-----------------------------------------\n";
    foreach my $ql(sort {$best{$b}<=>$best{$a}} keys %best) {
	printf OUT "%-25s %10s\n",$best2{$ql},$best{$ql};
	$best2{$ql}=~s|-|/|;
    }
    print OUT "##########################################\n\n\n";


    #--------------------------------
    # print all by peformance order
    #--------------------------------
    print OUT2 "-----------------------------------------\n";
    print OUT2 "All runs by $type order:\n";
    print OUT2 "-----------------------------------------\n";
    foreach my $k(sort {$$allhp{$b}<=>$$allhp{$a}} keys %$allhp) {
	my $qlen=$1 if ($k=~/_q(.)/);
	printf OUT2 "%-25s %10s\n",$k,$$allhp{$k};
    }

} #endsub-print_best


sub chkdir {
    my $ind=shift;
    opendir(IND,$ind) || die "can't opendir $ind";
    my @files=readdir(IND);
    closedir IND;
    my @files2;
    my $fcnt=0;
    foreach my $file(@files) {
        next if (-d "$ind/$file");
        push(@files2,$file);
        $fcnt++;
    }
    return ($fcnt,@files2);
} #endsub chkdir


