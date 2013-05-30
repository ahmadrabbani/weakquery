#!/usr/bin/perl -w

# -----------------------------------------------------------------------------
# Name:      mkabbrlist2.pl
# Author:    Kiduk Yang, 7/15/2007
#              modified ../trec04/mkabbrlist.pl (6/2004)
#              $Id: mkabbrlist2.pl,v 1.1 2007/07/15 17:19:22 kiyang Exp $
# -----------------------------------------------------------------------------
# Description:  
#   generate abbr. text file from http://csob.berry.edu/faculty/jgrout/acronym.html
# -----------------------------------------------------------------------------
# Arguments: arg1 = run mode (0 for test, 1 for real)
# Input:     http://csob.berry.edu/faculty/jgrout/acronym.html
# Output:    $tpdir/$prog.out
#            $tpdir/$prog.log -- program log (optional)
# -----------------------------------------------------------------------------
# NOTE:
# -----------------------------------------------------------------------------


$log=1;                              # program log flag
$debug=0;                            # debug flag
$filemode= 0640;                     # to use w/ perl chmod
$filemode2= 640;                     # to use w/ system chmod
$dirmode= 0750;                      # to use w/ perl mkdir
$dirmode2= 750;                      # to use w/ system chmod (directory)
$author= "kiyang\@indiana.edu";      # author's email

print "$debug,$filemode,$filemode2,$dirmode,$dirmode2,$author\n" if ($debug);


#------------------------
# global variables
#------------------------

use LWP::Simple;
use IO::Socket;

$wpdir=  "/u0/widit/prog";           # widit program directory
$tpdir=  "$wpdir/trec07";            # TREC program directory

require "$tpdir/logsub2.pl";         # general subroutine library
#require "/u0/widit/spider/sub.pl";  # spider subroutine library

$pname= &pnamepfx;
$outf=   "$tpdir/$pname.out";        # candidate acronym/abbreviation list

# acronym server
$url= "http://csob.berry.edu/faculty/jgrout/acronym.html";


#------------------------
# program arguments
#------------------------
if (@ARGV<1) {
    die "arg1= run mode (0 for test, 1 for real)\n";
}
($run_mode) = @ARGV;

exit if ($run_mode==0);

#-------------------------------------------------
# start program log
#-------------------------------------------------

$sfx="";
$argp=0;                      # if 1, do not print arguments to log
$append=0;                    # log append flag

if ($log) {
    @start_time= &begin_log($tpdir,$filemode,$sfx,$argp,$append) if ($log);
    print LOG "In  = $url\n",
            "Out = $outf\n\n";
}


#-------------------------------------------------
# fetch webpage
#-------------------------------------------------

$body=get($url);

open(OUT,">$outf") || die "can't write to $outf";
$cnt=0;
while($body=~/<LI>\s*([A-Z]+)\s+(.+)\n/g) {
    my($acr,$str)=($1,$2);
    $str=~s/\s+$//;
    print OUT "$acr $str\n";
    $cnt++;
}
close OUT;


#-------------------------------------------------
# end program
#-------------------------------------------------

print LOG "$cnt acronyms fetched\n";

&end_log($tpdir,$tpdir,$filemode,@start_time) if ($log);

# notify author of program completion
#&notify($sfx,$author);


