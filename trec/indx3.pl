#!/usr/bin/perl -w

# -----------------------------------------------------------------------------
# Name:      indx3.pl
# Author:    Kiduk Yang, 6/21/2006
#              modified  trec05/indx3.pl (6/2005)
#              modified  5/30/2008
#              $Id: indx3.pl,v 1.1 2007/07/15 17:20:12 kiyang Exp $
# -----------------------------------------------------------------------------
# Description:  INDEXING STEP 3
#   1. create inverted index files from sequential indexes
# -----------------------------------------------------------------------------
# Arguments: arg1 = run mode (0 for test, 1 for real)
#            arg2 = data directory
#            arg3 = file prefix (optional)
# Input:     $arg2/seqindx/*  -- sequential index files
# Output:    $arg2/inv_t     -- inverted index
#            $arg2/tnt       -- term-to-term# mapping (unsorted)
#            $arg2/tnt2      -- term-to-term# mapping (sorted by term)
#            $arg2/tnf       -- term-df file
#            $arg2/dnf       -- doc-tf file
#            $arg2/ran_*     -- random access files
#            $arg2/$prog     -- program     (optional)
#            $arg2/$prog.log -- program log (optional)
# -----------------------------------------------------------------------------
# inverted index file format:
#   TN DN TF ... -1 (per line)
#   
#   where
#   TN = term number
#   DN = document number
#   TF = term frequency
# -----------------------------------------------------------------------------
# NOTE:
#   1. calls invindx.cc & mkrabf.cc in trec04 directory
# -----------------------------------------------------------------------------


$log=1;                              # program log flag
$debug=0;                            # debug flag
$filemode= 0640;                     # to use w/ perl chmod
$filemode2= 640;                     # to use w/ system chmod
$dirmode= 0750;                      # to use w/ perl mkdir
$dirmode2= 750;                      # to use w/ system chmod (directory)
$group= "trec";                      # group ownership of files
$author= "kiyang\@indiana.edu";      # author's email

print "$debug,$filemode,$filemode2,$dirmode,$dirmode2,$group,$author\n" if ($debug);


#------------------------
# global variables
#------------------------

$wpdir=  "/u0/widit/prog";           # widit program directory
$tpdir=  "$wpdir/trec08";            # TREC program directory

$ccpfx1= "mkinvindx";                # C++ program 1 prefix
$ccpfx2= "mkrabf";                   # C++ program 2 prefix
$delim= "\'<DN>\'";                  # document delimiter

# files created by invindx.cc
@inv_files= ("inv_t","dnf","tnf","tnt","tnt2","ran_tnf","ran_tnt2","ran_tntotn2");


#------------------------
# program arguments
#------------------------
if (@ARGV<2) {
    die "arg1= run mode (0 for test, 1 for real)\n",
        "arg2= data directory\n",
        "arg3= file prefix (optional)\n";
}
($run_mode,$ddir,$fpfx) = @ARGV;

if ($run_mode==0) {
    $ddir= "$ddir/test";     
    `mkdir $ddir` if (!-e $ddir);
}

# C++ program called by this script
$ccprog1= "$tpdir/$ccpfx1.cc";
$ccout1= "$tpdir/$ccpfx1.out";
$ccprog2= "$tpdir/$ccpfx2.cc";
$ccout2= "$tpdir/$ccpfx2.out";
@ccprogs=($ccprog1,$ccprog2);


#-------------------------------------------------
# start program log
#-------------------------------------------------

require "$wpdir/logsub.pl";   # general subroutine library
require "$tpdir/indxsub.pl";  # indexing subroutine library

$sfx= $fpfx;           # program log file suffix
$argp=0;               # if 1, do not print arguments to log
$append=0;             # log append flag

@start_time= &begin_log($ddir,$filemode,$sfx,$argp,$append) if ($log);


#-------------------------------------------------
# create the inverted index
#-------------------------------------------------

# determine total number of documents
$dnref="$ddir/dnref";
$maxdn= `cat $dnref | wc -l`;
chomp $maxdn;

# determine total number of files to process
$fnref="$ddir/fnref";
$maxfn= `cat $fnref | wc -l`;
chomp $maxfn;

if ($run_mode==0) {
    $maxfn= 2;
}

# call c++ module to create inverted index files
$elog1= "$ddir/$ccpfx1.cc.log";
$ec=system "$ccout1 $ddir $maxfn $delim >$elog1 2>&1";
print LOG "  CMD = $ccout1 $ddir $maxfn $delim > $elog1 2>&1\n";
print LOG "  !!ERROR!! return code = $ec\n" if ($ec);

# call c++ module to create RAB files
$elog2= "$ddir/$ccpfx2.cc.log";
$ec=system "$ccout2 $ddir >$elog2 2>&1";
print LOG "  CMD = $ccout2 $ddir\n";
print LOG "  !!ERROR!! return code = $ec\n" if ($ec);

# check the number of documents processed
$maxdn2= &chkdn("$ddir/dnf",$maxdn);


#--------------------------------
# copy C++ programs
#--------------------------------
foreach $prog(@ccprogs) {
    system "cp $prog $ddir";
}

$ccpr1= "$ddir/$ccpfx1.cc";
$ccpr2= "$ddir/$ccpfx2.cc";

#--------------------------------
# set output file permissions 
#--------------------------------
@errs=();
foreach $file($elog1,$elog2,$ccpr1,$ccpr2) {
    $rc= system "chmod $filemode2 $file";
    push(@errs,"!!ERROR ($rc): chmod $filemode2 $file") if ($rc);
}

foreach $file(@inv_files) {
    $rc= system "chmod $filemode2 $ddir/$file";
    push(@errs,"!!ERROR ($rc): chmod $filemode2 $ddir/$file") if ($rc);
}

if (@errs) {
    $errstr= join("\n",@errs);
    print LOG "\n\n$errstr\n\n";
}


#-------------------------------------------------
# end program
#-------------------------------------------------

print LOG "\nProcessed $maxfn files and $maxdn2 documents\n\n";

&end_log($tpdir,$ddir,$filemode,@start_time) if ($log);

# notify author of program completion
#&notify($sfx,$author);


###################################
# subroutines
###################################
            
BEGIN { print STDOUT "\n"; }
END { print STDOUT "\n"; }


#-----------------------------------------------------------
# check number of documents processed
#-----------------------------------------------------------
#  arg1   = input filename
#  arg2   = document count
#-----------------------------------------------------------
sub chkdn {
    my ($file,$cnt)=@_;
    open(IN,$file) || die "can't read $file";
    my @lines=<IN>;
    my $cnt2= @lines;
    if ($cnt !=$cnt2) {
        print LOG "    !!Warning: $file\n",
                  "      -- $cnt2 (inverted) VS. $cnt (sequential) documents.\n";
    }   
    return $cnt2;
}       
