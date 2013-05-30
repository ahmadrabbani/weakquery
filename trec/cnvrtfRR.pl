#!/usr/bin/perl -w

# -----------------------------------------------------------------
# Name:      cnvrtfRR.pl
# Author:    Kiduk Yang, 07/30/2005
#              modified trec05/cnvrtf.pl (07/2005)
#              modified to consolidate cnvrtf*.pl, 6/24/07
#              modified to get better padding of results, 7/25/07
#              modified to handle QE results, 4/2008
#              modified cnvrtf_qe.pl, 7/1/2008
#               - padding removed
# -----------------------------------------------------------------
# Description:  converts BLOG reranked results to default TREC format.
# -----------------------------------------------------------------
# ARGUMENTS: arg1 -- query type (t, tx, e, ex)
#            arg2 -- query subdirectory (e.g. s0wk)
#            arg3 -- file suffix (optional: defalut=f)
# INPUT:     $ddir/results/$qtype/trecfmt(x)/$arg2/*
#            $ddir/results/$qtype/trecfmt(x)/padDN.$arg2
# OUTPUT:    $ddir/results/$qtype/trecfmt(x)/$arg2/*_trec
#            $ddir/cnvlog/$prog      -- program     (optional)
#            $ddir/cnvlog/$prog.log  -- program log (optional)
#            NOTE: $qtype   = query type (train|eval)
# -----------------------------------------------------------------
# NOTES:    
# ------------------------------------------------------------------------

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


#------------------------
# global variables
#------------------------

my $wpdir=  "/u0/widit/prog";           # widit program directory
my $tpdir=  "$wpdir/trec08";            # TREC program directory
my $pdir=   "$tpdir/blog";              # blog program directory
my $ddir=   "/u3/trec/blog08";          # index directory

my $trecdname=  "trecfmt";              # trec format directory name

use constant MAXRTCNT => 1000;      # max. number of documents per result

# query type
my %qtypes= ("e"=>"test","ex"=>"test","t"=>"train","tx"=>"train","tx2"=>"train2","ex2"=>"test2");

# topic file
my %topics= (
"t"=>"06-07.blog-topics",
"tx"=>"06-07.blog-topics",
"e"=>"08.blog-topics",
"ex"=>"08.blog-topics",
);

require "$wpdir/logsub2.pl";          # general subroutine library


#------------------------
# program arguments
#------------------------
my $prompt= 
"arg1= query type (t, tx, e, ex)\n".
"arg2= query subdirectory (e.g. s0wk, s0gg)\n".
"arg3= file suffix (optional: e.g. okapif)\n".
"arg4= overwrite log flag (e.g. 1, default=append)\n\n";

my %valid_args= (
0 => " t e tx ex tx2 ex2 ",
1 => " s0* ",
);

my ($arg_err,$qtype,$qsubd,$fsfx,$noapf)= chkargs($prompt,\%valid_args,2);
die "$arg_err\n" if ($arg_err);

$sfx= $qtype;
if ($qtype=~/x/) {
    $trecdname .= 'x';
}
$sfx .= $qsubd;

my $ind= "$ddir/results/$qtypes{$qtype}/$trecdname/$qsubd";
my $qnlist= "/u1/trec/topics/$topics{$qtype}";

# log directory
$logd= "$ddir/cnvlog";               
if (!-e $logd) {
    my @errs=&makedir($logd,$dirmode,$group);
    print "\n",@errs,"\n\n" if (@errs);
}


#-------------------------------------------------
# start program log
#-------------------------------------------------

$noargp=0;      # if 1, do not print arguments to log
$append=1;      # log append flag
$append=0 if ($noapf);

if ($log) { 
    @start_time= &begin_log($logd,$filemode,$sfx,$noargp,$append); 
    print LOG "InD  = $ind\n\n";
}


# ------------------------------------------------
# get topic numbers
#   - to check for missing results
#-------------------------------------------------

open(IN,"grep '<num>' $qnlist |") || die "can't read $qnlist";
my ($qncnt,%qns)=(0);
while(<IN>) {
    chomp;
    if (/: (\d+)/) {
        $qns{$1}=1;
        $qncnt++;
    }
}
close IN;


# ------------------------------------------------
# convert reranked results to official TREC format
#   - check for suspect scores, rank, QN
#   - check for duplicate DN
#   - check for missing result
#   - pad results to $maxrtcnt docs per topic
#-------------------------------------------------

print LOG "Checking for $qncnt topic results\n";

opendir(IND,$ind) || die "can't opendir $ind";
my @files=readdir IND;
close IND;

my($qn,$docn,$rank,$score,$runname);

foreach my $filename(@files) {
    next if ((-d "$ind/$filename") || $filename!~/r[12]$/);
    next if ($fsfx && $filename !~/$fsfx/);

    $runname=$filename;
    $runname=~s/-//g;
    if ($runname=~/^okapi(.+)$/) { $runname= "wdoqsx$1"; }
    elsif ($runname=~/^vsm(.+)$/) { $runname= "wdvqsx$1"; }
    elsif ($runname=~/^q(.+)$/) { $runname= "wdqsx$1"; }

    my $inf= "$ind/$filename";
    my $outf= "$ind/$filename"."_trec";

    print LOG "Reading $inf\n";
    open(IN,$inf) || die "can't read $inf";

    # read input file
    my ($oldqn0,$oldrank0,$oldsc0,@results,%docs)=(0);
    while(<IN>) {
        my ($qn,$docn,$rnk,$score)=split/\s+/;

        die "Error: input file is already in TREC format" if ($docn eq 'Q0');

        print "qn=$qn, dn=$docn, rank=$rnk, sc=$score\n" if ($debug);

        # first result for topic
        if ($qn != $oldqn0) {
            if ($oldqn0 && ($oldrank0<MAXRTCNT || $qn>$oldqn0+1)) {
                my $sc2=$oldsc0;
                if ($qn>$oldqn0+1) {
                    for (my $qn0=$oldqn0+1; $qn0<$qn; $qn0++) {
                        print LOG "!!Warning: $qn0 has 0 lines.\n";
                    }
                }
                else {
                    print LOG "!!Warning: $oldqn0 has only $oldrank0 lines\n";
                }

            } #end-if ($oldqn0)

            %docs=();

        } #end-if ($qn)

        $docs{$docn}=1;

        if ($rnk<=MAXRTCNT) {
            push(@results,"$qn $docn $rnk $score $runname");
            $oldsc0=$score;
            $oldqn0=$qn;
            $oldrank0=$rnk;
        }
        else { next; }

    }
    close(IN);


    %docs=();
    my($oldqn,$oldsc,$rnk,%dcnt)=(0);

    print LOG "Writing to $outf\n\n";
    open(OUT,">$outf") || die "can't write to $outf";
    foreach (@results) {
        ($qn,$docn,$rnk,$score,$runname)=split/ /;

        die "!!Error: $qn is a invalid topic number\n" if (!$qns{$qn});
        $dcnt{$qn}++;
        
        # first result for topic
        if ($qn != $oldqn) {
            print LOG "!Warning: suspect rank in input file\n".
                    "  qn=$qn, rank=$rnk, $docn $score\n" if ($rnk!=1);
            die "!!Error: topic number out of sequence: oldqn=$oldqn\n".
                "  qn=$qn, rank=$rnk, $docn $score\n" if ($qn<=$oldqn);
            $rank=0;
            %docs=();
        }
        elsif ($oldqn) {
            die "!!Error: topic number out of sequence: oldqn=$oldqn\n".
                "  qn=$qn, rank=$rnk, $docn $score\n" if ($qn!=$oldqn);
            die "!!Error: suspect score: oldsc=$oldsc\n".
                "  qn=$qn, rank=$rnk, $docn $score\n" if ($score>$oldsc || $score<=0);
        }

        $rank++;

        die "!!Error: duplicate $docn in topic $qn\n".
            "  $docs{$docn}\n  $rank $score\n" if (exists($docs{$docn}));

        $docs{$docn}="$rank $score";

        next if ($rank>MAXRTCNT);

        print LOG "!Warning: suspect input rank\n  qn=$qn, rank=$rnk:$rank, $docn $score\n" if ($rnk!=$rank);

        select(OUT);
        $~= "RDLIST";
        write; 

        $oldsc=$score;
        $oldqn=$qn;

    }

    close(OUT);
    select(STDOUT);

    foreach my $qn(sort keys %qns) {
        print LOG "!Warning: topic $qn has only $dcnt{$qn} results\n" if ($dcnt{$qn}<MAXRTCNT);
    }
    print LOG "\n";

}

    
# ------------------------------------------------
# end program
# ------------------------------------------------

if ($log) { &end_log($pdir,$logd,$filemode,@start_time); }

# notify author of program completion
#&notify($sfx,$author);



############################################
# subroutines & print formats
############################################

BEGIN { print STDOUT "\n"; }
END { print STDOUT "\n"; }

# ------------------------------------------------
# Print format for TREC results
# ------------------------------------------------
             
format RDLIST =
@<<<  @<<  @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<  @######   @###.######  @<<<<<<<<<<<<
$qn, 'Q0', $docn, $rank, $score, $runname
.


