#!/usr/bin/perl -w

# -----------------------------------------------------------------
# Name:      mkfnrefall.pl
# Author:    Kiduk Yang, 6/25/2006
#             modifed 5/23/2007
#             modifed 5/30/2008
#             $Id: mkfnrefall.pl,v 1.1 2008/06/27 00:42:57 kiyang Exp $
# -----------------------------------------------------------------
# Description:
#   1. make FNREF for all the files in all subdirectories
# -----------------------------------------------------------------
# Arguments: arg1 = run mode (1 to run)
# Input:     $ddir/YYYYMMDD/fnref1, nulldoc0, nulldoc, nulldocx, ,nonEdoc0, nonEdoc
# Output:    $ddir/fnref1
#                FileNum FilePath DocCount DocXCount
#            $ddir/$arg2/$prog        -- program     (optional)
#            $ddir/$arg2/$prog.log    -- program log (optional)
# -----------------------------------------------------------------
# NOTE:
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

if (@ARGV<1) { die "arg1= run mode (1 to run)\n"; }


#------------------------
# global variables
#------------------------

my $wpdir=  "/u0/widit/prog";           # widit program directory
my $tpdir=  "$wpdir/trec08";            # TREC program directory
my $pdir=   "$tpdir/blog";              # Blog track program directory
my $ddir=   "/u3/trec/blog08";          # TREC index directory

my $outf= "$ddir/fnref1";

require "$wpdir/logsub2.pl";   # subroutine library
require "$tpdir/indxsub.pl";  # indexing subroutine library


#-------------------------------------------------
# start program log
#-------------------------------------------------

$sfx= "";              # program log file suffix
$noargp=1;             # if 1, do not print arguments to log
$append=0;             # log append flag

if ($log) {
    @start_time= &begin_log($ddir,$filemode,$sfx,$noargp,$append);
    print LOG "IND = $ddir/YYYYMMDD\n",
              "OUTF= $outf\n\n";
}


#-------------------------------------------------
# aggregate info from YYYYMMDD/fnref
#-------------------------------------------------

opendir(DIR,"$ddir") || die "can't opendir $ddir";
my @dirs = readdir(DIR);
closedir(DIR);

open(OUT,">$outf") || die "can't write to $outf";

my ($fileN,$dN,$dxN)=(0,0,0);

# for each date subdirectory
foreach my $yymmdd(@dirs) {

    next if ($yymmdd !~ /^\d{8}$/);

    my $indir= "$ddir/$yymmdd";      # data directory
    my $nonEdoc0="$indir/nonEdoc0";  # list of non-English blogs (by feed)
    my $nonEdoc="$indir/nonEdoc";    # list of non-English blogs
    my $nulldoc0="$indir/nulldoc0";  # list of null content blogs (by feed)
    my $nulldoc="$indir/nulldoc";    # list of null content blogs
    my $nulldocx="$indir/nulldocx";  # list of null content blogs after noise exclusion
    my $fnref= "$indir/fnref1";      # fileN to filename mapping

    my (%nonE,%null,%nullx);

    open(NE,"$nonEdoc0") || die "can't read $nonEdoc0";
    while(<NE>) {
        my($n,$id)=split/ /;
        $nonE{$id}++;
    }
    close NE;

    open(NE,"$nonEdoc") || die "can't read $nonEdoc";
    while(<NE>) {
        my($n,$id)=split/ /;
        $nonE{$id}++;
    }
    close NE;

    open(NL,"$nulldoc0") || die "can't read $nulldoc0";
    while(<NL>) {
        my($n,$id)=split/ /;
        $null{$id}++;
    }
    close NL;

    open(NL,"$nulldoc") || die "can't read $nulldoc";
    while(<NL>) {
        my($n,$id)=split/ /;
        $null{$id}++;
    }
    close NL;

    open(NL,"$nulldocx") || die "can't read $nulldocx";
    while(<NL>) {
        my($n,$id)=split/ /;
        $nullx{$id}++;
    }
    close NL;

    open(IN,"$fnref") || die "can't read $fnref";
    while(<IN>) {
        $fileN++;
        chomp;
        my($n,$file,$fdn,$ldn)=split/ /;
        $file=~m|/(200\d+)/permalinks(-\d{3})|;
        my $file2= "$1$2";
        my ($nonEn,$nulln,$nullxn)=(0,0,0);
        foreach my $id(keys %nonE) {  $nonEn++ if ($id=~/$file2/); }
        foreach my $id(keys %null) {  $nulln++ if ($id=~/$file2/); }
        foreach my $id(keys %nullx) {  $nullxn++ if ($id=~/$file2/); }
        my $dcnt= $ldn-$fdn+1-$nulln-$nonEn;
        my $dxcnt= $dcnt-$nullxn;
        print OUT "$fileN $file2 $dcnt $dxcnt\n";
        $dN += $dcnt;
        $dxN += $dxcnt;
    }

}

close OUT;


#-------------------------------------------------
# end program
#-------------------------------------------------

print LOG "\nProcessed $fileN files ($dN docs, $dxN docx)\n";

&end_log($pdir,$ddir,$filemode,@start_time) if ($log);

# notify author of program completion
#&notify($sfx,$author);


##############################################
# SUBROUTINES
##############################################

BEGIN { print STDOUT "\n"; }
END { print STDOUT "\n"; }

