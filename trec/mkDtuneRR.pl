#!/usr/bin/perl -w

# -----------------------------------------------------------------
# Name:      mkDtuneRR.pl
# Author:    Kiduk Yang, 4/24/2008
#              modified, mkEvalDisplay.pl (07/2007)
#              modified, mkDtune1.pl, 7/2/2008
# -----------------------------------------------------------------
# Description:  create dynamic tuning homepage for blog reranking optimization
# -----------------------------------------------------------------
# ARGUMENTS: arg1 -- query type (t, e, tx, ex)
#            arg2 -- rerank subdirectory
# Input:     $idir/$arg1/results/$qtype/trecfmt[x]/$arg2/*
# Output:    $twdir/blog/DTuning/$arg2/dtuneOP_$arg1.htm
#            $twdir/blog/DTuning/$arg2/$prog     -- program     (optional)
#            $twdir/blog/DTuning/$arg2/$prog.log  -- program log (optional)
#            NOTE: $qtype   = query type (train|test)
# -----------------------------------------------------------------
# NOTES:    original code in /u0/widit/htdocs2/TREC/blog/resultsDsp/
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

print "$debug,$filemode,$filemode2,$dirmode,$dirmode2,$author,$group\n" if ($debug);


#------------------------
# global variables
#------------------------

my $wpdir=  "/u0/widit/prog";           # widit program directory
my $pdir=  "$wpdir/trec08/blog";        # TREC program directory
my $twdir=  "/u0/widit/htdocs2/TREC";    # TREC web directory
my $rdir=   "/u3/trec/blog08/results";  # blog result directory

my $cgi= "../dtuning2aRR.cgi";

# query type
my %qtypes= ("e"=>"test/trecfmt","t"=>"train/trecfmt",'ex'=>'test/trecfmtx','tx'=>'train/trecfmtx');

require "$wpdir/logsub2.pl";          # general subroutine library


#------------------------
# program arguments
#------------------------
my $prompt= 
"arg1= query type (t, e, tx, ex)\n".
"arg2= rerank subdirectory (s0baseR)\n";


my %valid_args= (
0 => " t e tx ex ",
1 => " s0* ",
);

my ($arg_err,$qtype,$rsubd)= chkargs($prompt,\%valid_args);
die "$arg_err\n" if ($arg_err);
die "Invalid rerank directory: $rsubd\n" if ($rsubd !~ /R/);

# TREC format result directory
my $ind= "$rdir/$qtypes{$qtype}/$rsubd";

# output file
my $outd= "$twdir/blog/DTuning/$rsubd";
my $outf= "$outd/dtuneOP_$qtype.htm";

`mkdir -p $outd` if (!-e $outd);


#-------------------------------------------------
# start program log
#-------------------------------------------------

$sfx= "$qtype$rsubd";         # program log file suffix
$noargp=0;              # if 1, do not print arguments to log
$append=0;              # log append flag

if ($log) { 
    @start_time= &begin_log($outd,$filemode,$sfx,$noargp,$append); 
    print LOG "InD  = $ind/*\n",
              "OutF = $outf\n\n";
}


#-------------------------------------------------
# 1. read in result file names
# 2. group them by category
# 3. create HTML file to display the result list
#-------------------------------------------------


my %resultf;

# get the list of result files
opendir(IND,$ind) || die "can't opendir $ind";
my @files= readdir IND;
closedir IND;

# add result file to %resultf
foreach my $fname(@files) {

    next if ($fname !~ /\.r([12])$/);
    my $rtype=$1;

    my $ftype;

    # reranking directory
    if ($rtype==1) {
        $ftype="topic";
    }
    else {
        $ftype="opinion";
    }

    my $fpath= "$qtypes{$qtype}/$rsubd/$fname";
    $resultf{$qtype}{$ftype}{$fname}=$fpath;
}


&print_html($outf,$cgi,$qtype,$rsubd,\%resultf);


# ------------------------------------------------
# end program
# ------------------------------------------------

if ($log) { 
    print LOG "\n";
    &end_log($pdir,$outd,$filemode,@start_time); 
}

# notify author of program completion
#&notify($sfx,$author);


###############################
# SUBROUTINES
###############################

#---------------------- -----------------------------
# pad string with &nbsp; until $arg1 length is reached
# arg1= string
# arg2= target length
# arg3= leading padding flag (optional)
# r.v.= padded string
#---------------------- -----------------------------
sub sprf {
    my($str,$tlen,$lp)=@_;

    my $len=length($str);
    my ($sps,@sps);
    for(my$i=1;$i<=$tlen-$len;$i++) {
        push(@sps,"&nbsp;");
    }
    $sps= join(" ",@sps);
    if ($lp) { return "$sps $str"; }
    else { return "$str $sps"; }
}


sub print_block {
    my ($btype,$cspan,$qt,$rfhp)=@_;

    $cspan=1 if (!$cspan);

    print OUT "<td colspan=$cspan valign='top' align='center'><blockquote>\n";
    foreach my $fname(sort keys %{$rfhp->{$qtype}{$btype}}) {
        my $fname2= &sprf($fname,16);
        my $fpath= $rfhp->{$qt}{$btype}{$fname};
        print OUT "<input name='rfile' type='radio' value='$fpath'>$fname2<br>\n";
    }
    print OUT "</blockquote></td>\n";

} #endsub print_block


sub print_html {
    my($of,$cgif,$qt,$rsubd,$rfhp)=@_;

    open(OUT,">$of") || die "can't write to $of";

    my $topic_type= $qtypes{$qt};
    my $title= "WIDIT Dynamic Tuning: Blog 2008 Results: \U$topic_type\E topics, $rsubd";

print OUT<<EOP;
    <html>
    <head>
    <title>$title</title>
    </head>

    <body>
    <table border="1" align="center">
    <form action="$cgif">
    <input type='hidden' name='qt' value='$qt'>
    <input type='hidden' name='rsubd' value='$rsubd'>
    <tr><th colspan="2"><font size=+2>$title</font></th></tr>
EOP

    &print_submit;
    print OUT "<tr><td align='center'><strong>--- Topic Reranking ---</strong></td>\n";
    print OUT "    <td align='center'><strong>--- Opinion Reranking ---</strong></td>\n";
    print OUT "<tr>\n";
    &print_block("topic",1,$qt,$rfhp);
    &print_block("opinion",1,$qt,$rfhp);
    print OUT "</tr>\n";
    &print_submit;

    print OUT "
    </form>
    </table>
    </body>
    </html>";

} #endsub print_html

sub print_submit {

print OUT<<EOP;
    <tr>
        <td align="center"><input type="submit" name="SUBMIT" value="submit"></td>
        <td align="center"><input type="reset" name="CLEAR"></td>
    </tr>
EOP

} #endsub print_html
