#!/usr/bin/perl -w

# -----------------------------------------------------------------
# Name:      mkfnsubf2.pl
# Author:    Kiduk Yang, 7/25/2006
#             modifed 5/29/2007
#             modifed 6/20/2008 - added arg2 & arg3
#             $Id: mkfnsubf2.pl,v 1.1 2008/06/27 00:43:13 kiyang Exp $
# -----------------------------------------------------------------
# Description:
#   1. remake fnref subfiles to be read in for indexing modules
#      by chopping up failed fnsub files created by mkfnsub.pl
#      - fnsub= list of files to be grouped in an indexing subdirectory
# -----------------------------------------------------------------
# Arguments: arg1 = number of documents per subdirectory 
#            arg2 = input fnsub directory
#            arg3 = output fnsub directory
# Input:     $ddir/$arg2/N
# Output:    $ddir/$arg3/N
#                FileNum FilePath DocCount DocXCount
#            $ddir/$prog        -- program     (optional)
#            $ddir/$prog.log    -- program log (optional)
# -----------------------------------------------------------------
# NOTE: 
#   1. fnsub/N created by mkfnsubf.pl 
#   2. regroups failed subdirectories identified by chklog_indx3.sh
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


#------------------------
# global variables
#------------------------

my $wpdir=  "/u0/widit/prog";           # widit program directory
my $tpdir=  "$wpdir/trec08";            # TREC program directory
my $pdir=   "$tpdir/blog";              # Blog track program directory
my $ddir=   "/u3/trec/blog08";          # TREC index directory

require "$wpdir/logsub.pl";   # subroutine library
require "$tpdir/indxsub.pl";  # indexing subroutine library


#------------------------
# program arguments
#------------------------
my $prompt=
"arg1= number of documents per directory\n".
"arg2= input fnsub directory\n".
"arg3= output fnsub directory\n";

my %valid_args= (
1 => " fnsub* ",
2 => " fnsub* ",
);

my ($arg_err,$dsize,$fnsubin,$fnsubout)= chkargs($prompt,\%valid_args,3);
die "$arg_err\n" if ($arg_err);

my $ind= "$ddir/$fnsubin";
my $outd= "$ddir/$fnsubout";


#-------------------------------------------------
# start program log
#-------------------------------------------------


$sfx= "";              # program log file suffix
$noargp=0;             # if 1, do not print arguments to log
$append=1;             # log append flag

if ($log) {
    @start_time= &begin_log($ddir,$filemode,$sfx,$noargp,$append);
    print LOG "IND = $ind/\n",
              "OUTD= $outd/\n\n";
}

# create output directory if needed
if (!-e $outd) {
    my @errs= &makedir($outd,$dirmode,$group);
    print "\n",@errs,"\n\n" if (@errs);
}
else {
    `rm -f $outd/*`;
}


#-------------------------------------------------
# main program
#-------------------------------------------------

# flag problem sub directories
open(IN,"grep -i error $ddir/sub*/indx3*log |") || die "grep failure";

my %pbsubn;
while (<IN>) {
    m|$ddir/subx?(\d+)|;
    $pbsubn{$1}++;
}
close IN;

print LOG "Problem subdirectories:\n";
foreach my $i(sort {$a<=>$b} keys %pbsubn) {
    my $cnt1= `grep Processing $ddir/sub$i/indxblog2*log |wc -l`;
    my $cnt2= `grep PROCESSING $ddir/sub$i/mkinvindx*log |wc -l`;
    $pbsubn{$i}= $cnt2-1;  # number of files processed before error
    my $misscnt= $cnt1-$cnt2+1;
    print LOG "  subd $i: $misscnt missing seqindx files\n";
}
print LOG "\n";

# read old fnsub files
opendir(IND,$ind) || die "can't opendir $ind";
my @files=readdir(IND);
closedir IND;

my ($subdN,$fN,$dN,$dxN)=(0,0,0,0);

# @fnpb: list of files to be distributed in new fnsub files
#  - n fileref dcnt dxcnt
my @fnpb;

foreach my $fileN(@files) {
    next if ($fileN!~/^\d+$/);

    $subdN++;  # number of fnsub files

    my $inf="$ind/$fileN";
    my $outf="$outd/$fileN";
    open(IN,$inf) || die "can't read $inf";
    open(OUT,">$outf") || die "can't write to $outf";

    # copy fnsub files:
    #  if problem file,
    #  - output max. lines ($dsize)
    #  - put remaining lines in @fnpb
    my ($fcnt,$dcnt,$dxcnt)=(0,0,0);
    while(<IN>) {
        chomp;
        my($n,$file,$dn,$dxn)=split/ /;
        if (exists($pbsubn{$fileN}) && $fcnt>=$pbsubn{$fileN}) {
            push(@fnpb,"$file $dn $dxn");
        }
        else {
            $fcnt++;               # number of pml files in fnsub file
            $dcnt += $dn;          # number of docs in fnsub file
            $dxcnt += $dxn;        # number of docx in fnsub file
            $fN++;                 # total number of pml files
            $dN += $dn;            # total number of docs
            $dxN += $dxn;          # total number of docx
            print OUT "$fcnt $file $dn $dxn\n";
        }
    }
    close IN;
    close OUT;

    print LOG "fnsub$fileN: $fcnt files, $dcnt docs, $dxcnt docx\n";

}


# create fnsub files
$subdN++;
open(OUT,">$outd/$subdN") || die "can't write to $outd/$subdN";

my ($fcnt,$dcnt,$dxcnt)=(0,0,0);
foreach (@fnpb) {
    my($file,$dn,$dxn)=split/ /;
    $fcnt++;
    $dcnt += $dn;
    $dxcnt += $dxn;
    $fN++;
    $dN += $dn;
    $dxN += $dxn;
    print OUT "$fcnt $file $dn $dxn\n";
    if ($dcnt>=$dsize) {
        print LOG "fnsub$subdN: $fcnt files, $dcnt docs, $dxcnt docx\n";
        close OUT;
	$subdN++;
        open(OUT,">$outd/$subdN") || die "can't write to $outd/$subdN";
        ($fcnt,$dcnt,$dxcnt)=(0,0,0);
    }
}
print LOG "fnsub$subdN: $fcnt files, $dcnt docs, $dxcnt docx\n";

close OUT;


#-------------------------------------------------
# end program
#-------------------------------------------------

print LOG "\nProcessed $subdN fnsubs, ($fN files, $dN docs, $dxN docx)\n";

&end_log($pdir,$ddir,$filemode,@start_time) if ($log);

# notify author of program completion
#&notify($sfx,$author);


##############################################
# SUBROUTINES
##############################################

BEGIN { print STDOUT "\n"; }
END { print STDOUT "\n"; }

