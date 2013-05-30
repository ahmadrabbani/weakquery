#!/usr/bin/perl -w

# -----------------------------------------------------------------
# Name:      rt1sub.pl
# Author:    Kiduk Yang, 06/24/2008
#              modified trec07/rt1qesub2.pl
#            $Id: rt1qe.pl,v 1.3 2008/04/18 06:41:36 kiyang Exp kiyang $
# -----------------------------------------------------------------
# Description:  execute batch retreival of TREC data
#   1. retrieve from each subcollection using whole collection weights
#      -- data is split into subcollections, but
#         whole collection-based weights have been computed.
#   2. merge subcollection results by document scores
#  NOTE: uses input query list file to subset the queries to use 
#  NOTE: input query list file specifies files from multiple directories (inclues $qsubd)
# -----------------------------------------------------------------
# ARGUMENTS: arg1 -- run mode (0 for test, 1 for real)
#            arg2 -- subdirectory prefix (e.g., sub subx)
#            arg3 -- query type (i.e. t for training, e evaluation topics)
#            arg4 -- retrieval type (i.e. vsm, okapi)
#            arg5 -- input query list file
#            arg6 -- okap k3 value (optional)
# INPUT:     $idir/$subd/*              -- index data
#            $idir/query/$qtype/$arg4/* -- expandied queries
#                TERM WT per line
#            $pdir/qlist/$arg6 -- query list file
# OUTPUT:    $idir/results/$qtype/$arg5/arg4/$subd/qsx$qxTN$qn.$qxDN/*
#                -- subcollection retrieval files
#            $idir/results/$qtype/$arg5/$arg4/all/qsx$qxTN.$qxDN/qsx$arg6$qn.$iter
#                -- merged ranked list (whole collection)
#            $idir/rtlog/$prog               -- program     (optional)
#            $idir/rtlog/$prog.log           -- program log (optional)
#            NOTE: $qn    = query numbers 
#                  $subd  = subcollection directory
#                  $iter  = retrieval iteration
#                  $qxTN  = number of expansion term
#                  $qxDN  = number of feedback documents
# -----------------------------------------------------------------
# NOTES:     
#   1. executes subcollection retrievals using whole collection stats.
#   2. calls sr_all.out & qidx0_all3.out
# ------------------------------------------------------------------------


$log=1;                              # program log flag
$debug=0;                            # debug flag
$filemode= 0640;                     # to use w/ perl chmod
$filemode2= 640;                     # to use w/ system chmod
$dirmode= 0750;                      # to use w/ perl mkdir
$dirmode2= 750;                      # to use w/ system chmod (directory)
$group= "trec";                      # group ownership of files
$author= "kiyang\@indiana.edu";      # author's email

print "$debug,$filemode,$filemode2,$dirmode,$dirmode2,$author\n" if ($debug);


#------------------------
# global variables
#------------------------

$wpdir=  "/u0/widit/prog";           # widit program directory
$tpdir=  "$wpdir/trec08";            # TREC program directory
$ddir=   "/u3/trec/blog08";          # index directory

$qldir=  "$tpdir/blog/qlist";        # input query list directory

$maxdnf= "$ddir/maxdocno";
$maxdnxf= "$ddir/maxdocnoX";

$killrt_c = "kill_sr.out";            # retrieval stop module


# program parameters
$maxrank=5000;       # max. number of docs to retrieve
$maxpn=0;            # number of phrase terms
$ptn=10;             # number of positive weight terms to use
$ntn=2;              # number of negative weight terms to use

# query type
%qtype= ("e"=>"test","t"=>"train",'t2'=>'train2',"e2"=>"test2");

# retrieval type
%rtypes= ("okapi"=>"o","vsm"=>"v");  


require "$wpdir/logsub2.pl";   # general subroutine library


#------------------------
# program arguments
#------------------------
$prompt=
"arg1= run mode (0 for test, 1 for real)\n".
"arg2= data subdirectory prefix (e.g. sub, subx)\n".
"arg3= query type (i.e. t for training, e for evaluation)\n".
"arg4= retrieval type (i.e. vsm, okapi)\n".
"arg5= query input list file\n".
"arg6= okapi k3 value (optional)\n";

%valid_args= (
0 => " 0 1 ",
1 => " sub subx nsub nsubx ",
2 => " t e t2 e2 ",
3 => " okapi vsm ",
);

($arg_err,$run_mode,$subdpfx,$qtype,$rtype,$qlistf,$K3)= chkargs($prompt,\%valid_args,5);
die "$arg_err\n" if ($arg_err);

$qtype2= $qtype{$qtype};

$qdir0= "$ddir/query/$qtype2";   # query directory
$rdir= "$ddir/results";                # result directory

# input queries
my %qlist;
open(IN,"$qldir/$qlistf") || die "can't read $qldir/$qlistf";
while(<IN>) {
    chomp;
    $qlist{$_}=1;
}
close IN;



# if using new index (e.g. nsubN), output result to different directory (results_new)
if ($subdpfx=~/^n/) {
    $rdir .= "_new";
    $maxdnf .= "_new";
    $maxdnxf .= "_new";
}

$logdir= "$ddir/rtlog";
if (!-e $logdir) {
    my @errs=&makedir($logdir,$dirmode,$group);
    print LOG "\n",@errs,"\n\n" if (@errs);
}


if ($rtype eq "vsm") {
    $rt_c     = "sr_all.out";             # retrieval module
    $qidx_cc  = "qidx0_all1.out";          # query conversion module
    $slope    = "0.3";                    # slope for Lnu weight
}
elsif ($rtype eq "okapi") {
    $rt_c     = "sr_all2.out";             # retrieval module
    $qidx_cc  = "qidx0_all3.out";          # query conversion module
    $k1       = "1.2";                     # BM25 parameter
    $b        = "0.75";                    # BM25 parameter
    $k3       = "7";                       # BM25 parameter
}


#-------------------------------------------------
# start program log
#-------------------------------------------------

$sfx= $rtypes{$rtype}.$qtype;   # program log file suffix
$sfx .= 'x' if ($subdpfx=~/x$/);
$sfx .= "-$qlistf";

$argp=0;                      # if 1, do not print arguments to log
$append=0;                    # log append flag

if ($K3) {
    $k3=$K3;
    if ($K3 ne '7') {
	$sfx .= "_$K3";
	$odir0= "$rdir/$qtype2/$rtype$K3";  # output directory
    }
    else {
	$odir0= "$rdir/$qtype2/$rtype";  # output directory
    }
}
else {
    $odir0= "$rdir/$qtype2/$rtype";  # output directory
}

if ($log) { 
    @start_time= &begin_log($logdir,$filemode,$sfx,$argp,$append);
    if ($rtype eq 'vsm') { print LOG "VSM: slope=$slope\n\n"; }
    elsif ($rtype eq 'okapi') { print LOG "OKAPI: k1=$k1, b=$b, k3=$k3\n\n"; }
    print LOG "Index Directory  = $ddir\n",
              "Query Directory  = $qdir0\n",
              "Result Directory = $odir0\n",
              '  - Subcollection results in $subd/qsx$qxTN$qn.$qxDN/',"\n",
              '  - Whole collection results in all/qsx$qxTN.$qxDN/qsx$qxTN$qn.$iter',"\n",
              "  where \$subd  = subcollection directory\n",
              "        \$qxTN  = number of expansion terms\n",
              "        \$qxDN  = number of docs used in QE\n",
              "        \$iter  = retrieval iteration\n";
}

if (!-e $odir0) { 
    my @errs=&makedir($odir0,$dirmode,$group); 
    print LOG "\n",@errs,"\n\n" if (@errs);
}


#-------------------------------------------------
# get collection specific subdirectories
#-------------------------------------------------

opendir(IND,$ddir) || die "can't opendir $ddir";
my @files=readdir(IND);
closedir IND;
$subdn=0;
foreach (@files) {
    $subdn++ if (/^$subdpfx\d+$/);
}
for($i=1;$i<=$subdn;$i++) {
    push(@subd,"$subdpfx$i");
}     


#-------------------------------------------------
# execute batch retrieval
#-------------------------------------------------

# get total number of indexed documents
if ($subdpfx=~/x$/) {
    $maxdnall= `tail -1 $maxdnxf`;
}
else {
    $maxdnall= `tail -1 $maxdnf`;
}
chomp $maxdnall;

# get a list of queries
foreach $qry(sort keys %qlist) {
    push(@qrys,$qry);
}

# execute subcollection retrievals in sequence  
#  -- use whole collection stats (i.e. doc_norm_all) so that
#     retrieval results can simply be merged later by doc. scores
$dcnt=0;
foreach $subd(@subd) {

    last if ($run_mode==0 && ++$dcnt>2);
    #last if ($subd=~/subx5/);  #!!

    my $indir="$ddir/$subd";

    $FIFO  = "$indir/SRSTAT";

    # start the internal clock   
    if ($log) { @start_time2= &start_clock("Subcollection $subd"); }      
            
    # determine $maxdn and $maxtn
    $temp= `tail -1 $indir/dnf`;
    ($maxdn)= split(/ /,$temp);  
    $temp= `tail -1 $indir/tnf`;
    ($maxtn)= split(/ /,$temp);

    # start SR_ALL.OUT
    if ($rtype eq "vsm") {
	print LOG "  Starting $rt_c $indir $maxdn $maxtn $maxpn $ptn $ntn 1\n";
	$ec=system "$tpdir/$rt_c $indir $maxdn $maxtn $maxpn $ptn $ntn 1 &";
	if ($ec) { die "!!Error: $ec= $rt_c $indir $maxdn $maxtn $maxpn $ptn $ntn 1\n"; }
    }
    elsif ($rtype eq "okapi") {
	print LOG "  Starting $rt_c $indir $maxdn $maxtn $ptn $ntn $k1 $b\n";
	$ec=system "$tpdir/$rt_c $indir $maxdn $maxtn $ptn $ntn $k1 $b &";
	if ($ec) { die "!!Error: $ec= $rt_c $indir $maxdn $maxtn $ptn $ntn $k1 $b\n"; }
    }

    # give sr_all.out time to read inv_t into memory
    sleep 10;

    # execute search with each query
    $qcnt=0;
    foreach $qry0(@qrys) {
    
        my($qsubd,$qry)=split/\//,$qry0;

	last if ($run_mode==0 && $qcnt>2);

        $qin  = "$qdir0/$qsubd/$qry";       # input query
        $udir = "$odir0/$qsubd/$subd/$qry";     # user directory
        $qout = "$udir/Q1";         # query vector
    
        if (!(-e "$udir")) { &makedir($udir,$dirmode,$group); }

        # initialize retrieval status files.
        open(RTST,">$udir/RTSTAT") || die ("can't open $udir/RTSTAT");
        print RTST ("i");
        close(RTST);
    
        # create a query vector 
	if ($rtype eq "vsm") {
	    $ec= system("$tpdir/$qidx_cc $qin $qout $indir $maxdnall");
	    if ($ec) { die "!!Error: $ec= $qidx_cc $qin $qout $indir $maxdnall\n"; }
	}
	elsif ($rtype eq "okapi") {
	    $ec= system("$tpdir/$qidx_cc $qin $qout $indir");
	    if ($ec) { die "!!Error: $ec= $qidx_cc $qin $qout $indir\n"; }
	}
    
        # retrieve relevant documents
        &retrieve($udir,$indir,1);
    
        #system "chmod $filemode2 $udir/*";

	$qcnt++;

    } # end_foreach $qry(@qrys)
        
    # stop sr_all.out
    $ec=system "$tpdir/$killrt_c $indir";     
    print LOG "  Killing $rt_c $indir\n";
    if ($ec) { print LOG "!Warning: $ec= $killrt_c $indir!\n"; }

    # stop the internal clock
    if ($log) { &stop_clock("Subcollection $subd","",@start_time2); }
        
    sleep 5;

} # end-foreach $subd(@subd) {


#----------------------------------------------------
# create ranked lists for the whole collection
#----------------------------------------------------


$qcnt2=0;
foreach $qry0(@qrys) {
    
    my($qsubd,$qry)=split/\//,$qry0;

    next if (-d "$qdir0/$qsubd/$qry");

    last if ($run_mode==0 && $qcnt2++>2);

    %rtdoc=();

    # merge subcollection results
    my $dcnt=0;
    foreach $subd(@subd) {
	last if ($run_mode==0 && ++$dcnt>2);
	my $rd = "$odir0/$qsubd/$subd/$qry/RD1";
	open(RD,"$rd") || die "can't read $rd";
	while(<RD>) {
	    s/^\s+//;
	    my ($rank,$dn,$score) = split(/\s+/,$_);       
	    $rtdoc{"$dn-$subd"}= $score;
	}
	close(RD);
    }

    $qry=~m|^(q.+?)\d+(.*)$|;
    my $qsubdir= "$1$2";

    my $alld;
    if ($subdpfx=~/x$/) {
        $alld= "$odir0/$qsubd/allx/$qsubdir";  # whole collection result
    }
    else {
        $alld= "$odir0/$qsubd/all/$qsubdir";  # whole collection result
    }

    if (!-e $alld) { &makedir($alld,$dirmode,$group); }

    # output merged ranked list: sorted by score
    $rdout= "$alld/$qry.1";  # retrieval result
    print LOG "-- QN $qry result: $rdout\n";
    open(RDOUT,">$rdout") || die "can't write to $rdout";
    select(RDOUT);
    $~ = "RDLIST";
    $rank=0;
    foreach $dn(sort {$rtdoc{$b}<=>$rtdoc{$a}} keys %rtdoc) {
	$rank++; 
        $score= $rtdoc{$dn};
	last if ($rank>$maxrank);
	write;
    }
    close(RDOUT);
    select(STDOUT);

    #chmod($filemode,$rdout);

} # end_foreach $qry(@qrys)


# ------------------------------------------------
# end program
# ------------------------------------------------

# terminate any runaway processes
$tmp=`/bin/ps -f | grep $rt_c | grep $ddir | grep -v 'grep'`;
@lines=split(/\n/,$tmp);
foreach (@lines) {
    my ($user,$pid)=split/\s+/;
    $ec= system "kill -KILL $pid\n";
    if ($ec) { print "!!Warning: kill $pid ($rt_c) Error!!\n"; }
}

print LOG "\nTotal $qcnt queries retrieved\n\n";

if ($log) { &end_log($tpdir,$logdir,$filemode,@start_time); }


# notify author of program completion
&notify($sfx,$author);


# ------------------------------------------------
# Print formats
# ------------------------------------------------
             
format RDLIST =       
@>>>>>>   @>>>>>>>>>>>>>>> @####.#######
$rank, $dn, $score
.
        
        
#-------------------------------------
# Subroutine RETRIEVE
#   activate SR_ALL.C by setting status flags
#-------------------------------------
sub retrieve {

    local($dir,$rdir,$iter)=@_;

    # update SR status file to release SRCH_RANK module.
    $SIG{'PIPE'}='IGNORE';
    my $a=0;
    while ($a==0) {
        open (FIFO,">$FIFO") || die "can't open $FIFO";
        $a= print FIFO "$dir $iter\n";
        print LOG "  RETREIVE: $dir $iter\n";       
        if ($debug) { print STDOUT "retrieve: $dir $iter\n"; }
        close (FIFO);
    }        

    # check RT status file for the completion of SR_ALL.C
    my $rtstat="i";
    while($rtstat ne "d") {
        $rtstat= `cat $dir/RTSTAT`;
        if ($debug) { print STDOUT "retrieve: RTSTAT=$rtstat\n"; }
	my $tmp=`/bin/ps -f | grep $rt_c | grep $rdir`;
	my $pscnt=0;
	while ($tmp!~/$rt_c/ && $pscnt++>5) { 
	    $tmp=`/bin/ps -f | grep $rt_c | grep $rdir`;
	}
	if ($tmp!~/$rt_c/) { &restart_sr; }
    }
        
    # reset RT status flag
    open(RTST,">$dir/RTSTAT") || die ("can't open output file $dir/RTSTAT");
    print RTST "i";
    close(RTST);

} # endsub retrieve

                
#------------------------- 
# restart sr_all.out if dead
#  !! need to modify for okapi
#------------------------- 
sub restart_sr {
    system "$tpdir/$killrt_c $indir";     
    sleep 5;
    my $ec= system("$tpdir/$rt_c $indir $maxdn $maxtn $maxpn $ptn $ntn 1 &");
    print LOG "  !!$rt_c $indir restarted\n\n";
    if ($ec) { die "!!Error: $ec= $rt_c $indir restart\n"; }
    sleep 10;
}
