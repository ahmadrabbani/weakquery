#!/usr/bin/perl -w

# -----------------------------------------------------------------
# Name:      chkindx1.pl
# Author:    Kiduk Yang, 5/28/2007
#              modified, 5/31/2008
#             $Id: chkindx1.pl,v 1.2 2007/05/29 20:42:20 kiyang Exp $
# -----------------------------------------------------------------
# Description:  post-indexing check
#   1. confirm docx blogIDs to be same as docs IDs sans NR
# -----------------------------------------------------------------
# Arguments: arg1 = run mode (0 for test, 1 for real)
# Input:     $rdir/YYYYMMDD/docs/pml$nnn  -- processed file
#            $rdir/YYYYMMDD/docx/pml$nnn  -- processed file w/ NR
# Output:    $odir/$prog.out    -- program     (optional)
#            $odir/$prog        -- program     (optional)
#            $odir/$prog.log    -- program log (optional)
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


#------------------------
# global variables
#------------------------

my $wpdir=  "/u0/widit/prog";           # widit program directory
my $tpdir=  "$wpdir/trec08";            # TREC program directory
my $pdir=   "$tpdir/blog";              # Blog track program directory
my $rdir=   "/u3/trec/blog08";          # TREC index directory

require "$wpdir/logsub2.pl";


#------------------------
# program arguments
#------------------------
my $prompt=
"arg1= run mode (0 for test, 1 for real)\n";

my %valid_args= (
0 => " 0 1 ",
);

my ($arg_err,$run_mode)= chkargs($prompt,\%valid_args,1);
die "$arg_err\n" if ($arg_err);


#-------------------------------------------------
# start program log
#-------------------------------------------------

$sfx= ""; 
$noargp=1;             # if 1, do not print arguments to log
$append=0;             # log append flag

my $outf= "$rdir/".filestem($0).".out"; # longdoc list

if ($log) {
    @start_time= &begin_log($rdir,$filemode,$sfx,$noargp,$append);
    print LOG "IND  = $rdir/YYYYMMDD/docs|docx/pml\$nnn\n".
              "OUTF = $rdir/$outf\n\n";
}


#--------------------------------------------------------------------
# get blodIDs from docs and docx directories
#--------------------------------------------------------------------

opendir(IND,$rdir) || die "can't opendir $rdir";
my @dirs=readdir(IND);
closedir IND;

my $dcnt=0;  # doc count
my $dxcnt=0;  # doc count after NR
my $NRcnt=0;  # NR count
my $misscnt=0;  # missing docx count
my %missing;

foreach my $dir(sort @dirs) {

    my $indir= "$rdir/$dir";
    next if (($dir !~ /^200/) || (!-d "$indir"));

    last if (($run_mode==0) && ($dir > 20051206));  #!! for testing

    my $docsdir= "$indir/docs";
    my $docxdir= "$indir/docx";

    my $nonE0f= "$indir/nonEdoc0";
    my $null0f= "$indir/nulldoc0";
    my $nonEf= "$indir/nonEdoc";
    my $nullf= "$indir/nulldoc";
    my $nullxf= "$indir/nulldocx";

    my $dn=0;  # doc count
    my $dxn=0; # doc count w/ NR
    my $NRn=0; # NR docs
    my $missn=0;

    my (%docs,%docx,%NR);

    open(IN,"grep '<docno>' $docsdir/pml* |") || die "can't grep '<docno>' $docsdir/pml*";
    while(<IN>) {
        /(pml\d+):<docno>(.+)<\/docno>/;
        $docs{$2}=$1;
        $dn++;
    }
    close IN;
    $dcnt += $dn;

    open(IN,"grep '<docno>' $docxdir/pml* |") || die "can't grep '<docno>' $docxdir/pml*";
    while(<IN>) {
        /(pml\d+):<docno>(.+)<\/docno>/;
        $docx{$2}=$1;
        $dxn++;
    }
    close IN;
    $dxcnt += $dxn;

    # get NR docs
    foreach my $file($nonE0f,$null0f,$nonEf,$nullf,$nullxf) {
        open(IN,$file) || die "can't read $file";
        while(<IN>) {
            my($n,$id)=split/ /;
            $NRn++ if (!$NR{$id});
            $NR{$id}++;
        }
        close IN;
    }
    $NRcnt += $NRn;

    foreach my $id(sort keys %docs) {
        if ($docx{$id}) { next; }
        elsif (!$NR{$id}) {
            $missing{$id}=1;
            $missn++;
        }
    }
    $misscnt += $missn;

    print LOG "$indir: $missn missing docs (docs=$dn, docx=$dxn, NR=$NRn)\n";


} # end-foreach $dir(sort @dirs)


print LOG "\nALL: $misscnt missing docs (docs=$dcnt, docx=$dxcnt, NR=$NRcnt)\n";

open(OUT,">$outf") || die "can't write to $outf";
foreach my $id(sort keys %missing) {
    print OUT "$id\n";
}
close OUT;


#-------------------------------------------------
# end program
#-------------------------------------------------

&end_log($pdir,$rdir,$filemode,@start_time) if ($log);

# notify author of program completion
#&notify($sfx,$author);



##############################################
# SUBROUTINES
##############################################

BEGIN { print STDOUT "\n"; }
END { print STDOUT "\n"; }
