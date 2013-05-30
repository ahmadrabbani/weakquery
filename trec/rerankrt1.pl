#!/usr/bin/perl -w

# -----------------------------------------------------------------
# Name:      rerankrt1.pl
# Author:    Kiduk Yang, 07/20/2007
#              $Id: rerankrt1.pl,v 1.1 2008/06/27 00:43:33 kiyang Exp kiyang $
# -----------------------------------------------------------------
# Description:  
#   1. output individual document text to files to speed up reranking runs
# -----------------------------------------------------------------
# ARGUMENT:  
#   arg1= runmode (0 to get counts only, 1 to extract)
#   arg2= query type (t, tx, e, ex)
#   arg3= result subdirectory (e.g. s0)
#   arg4= runname filter (optional: e.g. _q)
#   arg5= log append flag (optional: 1 to overwrite log)
#   arg6= file overwrite flag (optional: 1 to overwrite files)
# INPUT:  
#   $ddir/results/$arg2/docs|docx/YYYYMMDD/$fn-$offset  
#     -- existing individual doc files
#   $ddir/YYYYMMDD/doc(x)/pmlN  -- processed blog data
# OUTPUT:    
#   $ddir/results/$arg2/docs|docx.list
#   $ddir/results/$arg2/docs|docx/YYYYMMDD/$fn-$offset  
#     -- new individual doc files
#     <ti>$title</ti>
#     <body>$title</body>
#   $ddir/rrlog/$prog      -- program     (optional)
#   $ddir/rrlog/$prog.log  -- program log (optional)
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

use constant MAXRTCNT => 1000;

my $wpdir=  "/u0/widit/prog";           # widit program directory
my $tpdir=  "$wpdir/trec08";            # TREC program directory
my $pdir=   "$tpdir/blog";              # TREC program directory
my $ddir=   "/u3/trec/blog07";          # index directory
my $ddir2=   "/u3/trec/blog08";          # index directory
my $logdir= "$ddir2/rrlog";              # log directory

require "$wpdir/logsub2.pl";

# query type
my %qtype= (
"t"=>"results/train/trecfmt", 
"tx"=>"results/train/trecfmtx",
"tn"=>"results_new/train/trecfmt",
"tnx"=>"results_new/train/trecfmtx",
"t2"=>"results/train2/trecfmt",
"tx2"=>"results/train2/trecfmtx",
"e"=>"results/test/trecfmt",
"ex"=>"results/test/trecfmtx", 
"en"=>"results_new/test/trecfmt",
"enx"=>"results_new/test/trecfmtx",
"e2"=>"results/test2/trecfmt",
"ex2"=>"results/test2/trecfmtx",
);


#------------------------
# program arguments
#------------------------
my $prompt=
"arg1= runmode (0 to get counts only, 1 to extract)\n".
"arg2= query type (t, tx, e, ex)\n".
"arg3= result subdirectory (e.g. s0)\n".
"arg4= runname filter (optional: _q)\n".
"arg5= log append flag (optional: 1 to overwrite log)\n".
"arg6= file overwrite flag (optional: 1 to overwrite file)\n";

my %valid_args= (
0 => " 0 1 ",
1 => " t tx e ex t2 tx2 e2 ex2 ",
2 => " s0* ",
);

my ($arg_err,$runmode,$qtype,$rsubd,$runfx,$apf,$newf)= chkargs($prompt,\%valid_args,3);
die "$arg_err\n" if ($arg_err);

my ($dname,$dname2);
if ($qtype=~/x/) { 
    $dname="docx"; 
    $dname2="docs"; 
}
else { 
    $dname="docs"; 
    $dname2="docx"; 
}

my $resultd= "$ddir/$qtype{$qtype}/$rsubd";
$resultd=~s/blog07/blog08/;

my $rsubd2='s0';
if ($rsubd=~/^(s\d)/) { $rsubd2=$1; }
else { die "$rsubd is invalid\n"; }

my $outd= "$ddir/results/$rsubd2/$dname";


#-------------------------------------------------
# start program log
#-------------------------------------------------

$sfx= $qtype;        # program log file suffix
$noargp=0;              # if 1, do not print arguments to log
$append=1;              # log append flag
$append=0 if ($apf);

if ($log) {
    @start_time= &begin_log($logdir,$filemode,$sfx,$noargp,$append);
    print LOG "InF  = $ddir/YYYYMMDD/$dname/pmlN\n",
              "     = $resultd/*\n",
              "OutD = $outd\n\n";
}


#-------------------------------------------------
# read in existing individual blog files
#-------------------------------------------------

my %dlist0;
my $dcnt0=0;   # count of existing blog files

opendir(D1,$outd) || die "can't opendir $outd";
my @subds=readdir(D1);
closedir D1;

foreach my $ymd(@subds) {
    next if ($ymd!~/^200/);

    my $ind2= "$outd/$ymd";
    opendir(D2,$ind2) || die "can't opendir $ind2";
    my @files=readdir(D2);
    closedir D2;

    foreach my $file(@files) {
        next if ($file!~/^\d{3}-\d+$/);
        $dlist0{"BLOG06-$ymd-$file"}=1;
        $dcnt0++;
    }
}

print LOG "Existing blog files = $dcnt0\n";
print LOG "Existing files will be overwritten (arg6=$newf)\n\n" if ($newf);


#-------------------------------------------------
# 1. get blogIDs from result files
# 2. identify files to extract
#-------------------------------------------------

my %dlist;
my %files;

opendir(IND,$resultd) || die "can't opendir $resultd";
my @files=readdir(IND);
closedir IND;

foreach my $file(@files) {
    my $inf= "$resultd/$file";

    next if ($file=~/\./ || (-d $inf));
    next if ($runfx && $file!~/$runfx/);

    print LOG "Processing result file $inf\n";

    open(IN,"$inf") || die "can't read $inf";
    while(<IN>) {
        my ($qn,$docID,$rank);
        if (/^(\d+).+(BLOG06-200\d+-\d{3}-\d+)\s+(\d+)/) {
            ($qn,$docID,$rank)=($1,$2,$3);
        }
        else {
            print LOG "  !!Error: Problem result file: $inf\n";
        }
        next if ($rank>MAXRTCNT);
        if ($newf || !exists($dlist0{$docID})) {
            my($b,$subd,$fn,$offset)=split/-/,$docID;
            $files{"$subd-$fn"}++;
            $dlist{$docID}=1;
        }
        else { 
            $dlist{$docID}=0;
        }
    }
    close IN;

} #end-foreach


my $dcnt1=0;  # number of IDs to extract
my $dcnt2=0;  # number of IDs in result file
foreach my $id(keys %dlist) {
    $dcnt1++ if ($dlist{$id});
    $dcnt2++;
}
print LOG "\n$dcnt1 of $dcnt2 IDs to be extracted\n\n";

%files=() if (!$runmode);


#-------------------------------------------------
# extract individual files
#-------------------------------------------------

my $docn=0;
foreach my $file(keys %files) {

    my($subd,$fn)=split/-/,$file;

    my $in="$ddir/$subd/$dname/pml$fn";
    my $in2="$ddir/$subd/$dname2/pml$fn";
    my $docd= "$outd/$subd";

    `mkdir -p $docd` if (!-e "$docd");

    print LOG "Reading $in\n";
    
    open(IN,$in) || die "can't read $in";
    my @lines=<IN>;
    close IN;

    my @docs= split(/<\/doc>\n<doc>\n/,join("",@lines));
        
    foreach my $doc(@docs) {
        my ($docno,$title,$body);
        if ($doc=~m|<docno>(.+?)</docno>.+?<ti>(.*?)</ti>.*?<body>(.*?)</body>|s) {
            ($docno,$title,$body)=($1,$2,$3);
        }
        elsif ($doc=~m|<docno>(.+?)</docno>\n.+?\n<ti>(.*?)</ti>\n.*?\n<body>\n(.*?)\n</body>|s) {
            ($docno,$title,$body)=($1,$2,$3);
        }

        next if (!$dlist{$docno});  # skip IDs not in result file 

        print LOG "  - writing $docno\n";

        $docno=~/BLOG06-$subd-(.+)$/;
        my $out= "$docd/$1";
        open(OUT,">$out") || die "can't write to $out";
        flock(OUT,2);
        print OUT "<ti>$title</ti>\n<body>$body</body>";
        close OUT;

        $dlist{$docno}=0;

        $docn++;

    } #endforeach $doc

    open(IN,$in2) || die "can't read $in2";
    @lines=<IN>;
    close IN;

    @docs= split(/<\/doc>\n<doc>\n/,join("",@lines));
        
    foreach my $doc(@docs) {
        my ($docno,$title,$body);
        if ($doc=~m|<docno>(.+?)</docno>.+?<ti>(.*?)</ti>.*?<body>(.*?)</body>|s) {
            ($docno,$title,$body)=($1,$2,$3);
        }
        elsif ($doc=~m|<docno>(.+?)</docno>\n.+?\n<ti>(.*?)</ti>\n.*?\n<body>\n(.*?)\n</body>|s) {
            ($docno,$title,$body)=($1,$2,$3);
        }

        next if (!$dlist{$docno});  # skip IDs not in result file 

        print LOG "  - writing $docno\n";

        $docno=~/BLOG06-$subd-(.+)$/;
        my $out= "$docd/$1";
        open(OUT,">$out") || die "can't write to $out";
        flock(OUT,2);
        print OUT "<ti>$title</ti>\n<body>$body</body>";
        close OUT;

        $dlist{$docno}=-1;

        $docn++;

    } #endforeach $doc

} #endforeach $file

print LOG "\n$docn files successfully extracted\n";

print LOG "\nFiles not extracted:\n";
foreach my $docno(sort keys %dlist) {
    print LOG " - $docno\n" if ($dlist{$docno}>0);
}


#-------------------------------------------------
# end program
#-------------------------------------------------

&end_log($pdir,$logdir,$filemode,@start_time) if ($log);

# notify author of program completion
#&notify($sfx,$author);

#####################
# subroutines
#####################

BEGIN { print STDOUT "\n"; }
END { print STDOUT "\n"; }


