#!/usr/bin/perl -w

# -----------------------------------------------------------------
# Name:      mkfnsubf0.pl
# Author:    Kiduk Yang, 5/30/2008
#             $Id: mkfnsubf0.pl,v 1.1 2008/06/27 00:43:09 kiyang Exp $
# -----------------------------------------------------------------
# Description:
#   1. make fnref subfiles to be read in for indexing modules
#      - fnsub= list of files to be grouped in an indexing subdirectory
#   (Note: copy files from 2007 fnsub3 directory)
# -----------------------------------------------------------------
# Arguments: arg1 = number of documents per subdirectory (min=50k)
# Input:     $ddir/fnref1
#            $ddir0/fnsub3/N
# Output:    $ddir/fnsub/N
#                FileNum FilePath DocCount DocXCount
#            $ddir/$arg2/$prog        -- program     (optional)
#            $ddir/$arg2/$prog.log    -- program log (optional)
# -----------------------------------------------------------------
# NOTE: uses fnref1 created by mkfnrefall.pl
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

use constant MINSIZE => 50000;

my $wpdir=  "/u0/widit/prog";           # widit program directory
my $tpdir=  "$wpdir/trec08";            # TREC program directory
my $pdir=   "$tpdir/blog";              # Blog track program directory
my $ddir=   "/u3/trec/blog08";          # TREC index directory

my $inf= "$ddir/fnref1";
my $ind=  "/u3/trec/blog07/fnsub3";    
my $outd= "$ddir/fnsub";

my $maxsubN=54;

require "$wpdir/logsub2.pl";   # subroutine library
require "$tpdir/indxsub.pl";   # indexing subroutine library


#------------------------
# program arguments
#------------------------
my $prompt=
"arg1= directory size (min=50k docs)\n";

my %valid_args= (
);

my ($arg_err,$dsize)= chkargs($prompt,\%valid_args,1);
die "$arg_err\n" if ($arg_err);

$dsize=MINSIZE if ($dsize<MINSIZE);


#-------------------------------------------------
# start program log
#-------------------------------------------------

$sfx= "";              # program log file suffix
$noargp=0;             # if 1, do not print arguments to log
$append=0;             # log append flag

if ($log) {
    @start_time= &begin_log($ddir,$filemode,$sfx,$noargp,$append);
    print LOG "IND = $ddir/fnref1\n",
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
# create fnsub files
#-------------------------------------------------


open(IN,"$inf") || die "can't read $inf";
my %fref;
while(<IN>) {
    chomp;
    my($n,$file,$dn,$dxn)=split/ /;
    $fref{$file}="$dn $dxn";
}
close IN;

my ($fN,$dN,$dxN)=(0,0,0);

for (my $subdN=1;$subdN<=$maxsubN;$subdN++) {

    open(IN,"$ind/$subdN") || die "can't read $ind/$subdN";
    open(OUT,">$outd/$subdN") || die "can't write to $outd/$subdN";

    my ($dcnt,$dxcnt,$tfcnt)=(0,0);

    while(<IN>) {
        chomp;
        my($fcnt,$file)=split/ /;
        my($dn,$dxn)=split/ /,$fref{$file};
        $fN++;
        $dcnt += $dn;
        $dxcnt += $dxn;
        $dN += $dn;
        $dxN += $dxn;
        $tfcnt += $fcnt;
        print OUT "$fcnt $file $dn $dxn\n";
    }
    close IN;
    close OUT;
    print LOG "fnsub$subdN: $tfcnt files, $dcnt docs, $dxcnt docx\n";
    print LOG " Doc count > $dsize\n" if ($dcnt>=$dsize);
    
}
close OUT;


#-------------------------------------------------
# end program
#-------------------------------------------------

print LOG "\nProcessed $maxsubN fnsubs, ($fN files, $dN docs, $dxN docx)\n";

&end_log($pdir,$ddir,$filemode,@start_time) if ($log);

# notify author of program completion
#&notify($sfx,$author);


##############################################
# SUBROUTINES
##############################################

BEGIN { print STDOUT "\n"; }
END { print STDOUT "\n"; }

