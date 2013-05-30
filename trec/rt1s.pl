#!/usr/bin/perl -w

# -----------------------------------------------------------------
# Name:      rt1.pl
# Author:    Kiduk Yang, 07/02/2005
#              modified trec04/rt1.pl (06/2004)
#            $Id: rt1.pl,v 1.8 2005/11/12 16:07:08 kiyang Exp $
# -----------------------------------------------------------------
# Description:  execute batch retreival of TREC data
#   1. retrieve from each subcollection using whole collection weights
#      -- data is split into subcollections, but
#         whole collection-based weights have been computed.
#   2. merge subcollection results by document scores
#      Note: same as rt1.pl except it restricts by qry number
# -----------------------------------------------------------------
# ARGUMENTS: arg1 -- run mode (0 for test, 1 for real)
#            arg2 -- TREC track (i.e. hard, spam)
#            arg3 -- query type (i.e. t for training, e evaluation topics)
#            arg4 -- query subdirectory (e.g. s0, s1, s2)
#            arg5 -- retrieval type (i.e. vsm, okapi)
#            arg6 -- query prefix 
#            arg7 -- starting query number
#            arg8 -- okap k3 value (optional)
#            arg9 -- index type (optional: body, head, anchor)
# INPUT:     $idir/$subd/*                        -- index data
#            $idir/query/$qtype/q$qlen$qform$qn   -- stemmed queries
# OUTPUT:    $idir/results/$qtype/$arg4/$subd/q$qlen$qform$qn/*
#                -- subcollection retrieval files
#            $idir/results/$qtype/$arg4/all/qs$qform$qn.$iter
#                -- merged ranked list (whole collection)
#            $idir/$prog               -- program     (optional)
#            $idir/$prog.log           -- program log (optional)
#            NOTE: $qn    = query numbers 
#                  $subd  = subcollection directory
#                  $qlen  = query length (s=short, m=medium, l=long)
#                  $qform = query format (a=acronym, n=noun, z=all)
#                  $iter  = retrieval iteration
# -----------------------------------------------------------------
# NOTES:     
#   1. executes subcollection retrievals using whole collection stats.
#   2. calls sr_all.out & qidx0_all.out
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
$tpdir=  "$wpdir/trec05";            # TREC program directory
$idir=   "/u0/trec/2005";            # index directory

$killrt_c = "kill_sr.out";            # retrieval stop module


# collection subdirectories
@hard_subd= ("APW","NYT1","NYT2","XIE");
@hardt_subd= ("FBIS","FR94","FT","LATIMES");
#@hardm_subd= ("AFE","APE","CNE","LAT","NYT","SLN","UME","XIE");

# program parameters
$maxrank=1000;       # max. number of docs to retrieve
$maxpn=0;            # number of phrase terms
$ptn=10;             # number of positive weight terms to use
$ntn=2;              # number of negative weight terms to use

# query type
%qtype= ("e"=>"test","t"=>"train","e0"=>"test0","t0"=>"train0");   

# query length
#%qlen= ("s"=>"short","m"=>"medium","l"=>"long");   

# query form
#%qform= ("a"=>"acronym","n"=>"noun", "z"=>"all");

require "$wpdir/logsub.pl";   # general subroutine library


#------------------------
# program arguments
#------------------------
$prompt=
"arg1= run mode (0 for test, 1 for real)\n".
"arg2= track name (i.e. hard, spam)\n".
"arg3= query type (i.e. t for training, e for evaluation)\n".
"arg4= query subdirectory (e.g. s0, s1, s2)\n".
"arg5= retrieval type (i.e. vsm, okapi)\n".
"arg6= query prefix\n".
"arg7= starting query number\n".
"arg8= okapi k3 value (optional)\n".
"arg9= index type (optional: body, head, anchor)\n";

%valid_args= (
0 => " 0 1 ",
1 => " hard ",
2 => " t e t0 e0 ",
3 => " s0* s1* s2* f* cf nl* wx* ",
4 => " okapi vsm ",
);

($arg_err,$run_mode,$dname,$qtype,$qsubd,$rtype,$qpfx,$fqnum,$K3,$itype)= chkargs($prompt,\%valid_args,7);
die "$arg_err\n" if ($arg_err);

# for HARD2005, use the same queries but different doc collections
#  - train: 2005 test topics;  2004 robust collection
#  - test:  2005 test topics;  2005 HARD collection
if (($dname eq 'hard') && ($qtype=~/^t/)) { 
    $dname2= $dname.$qtype; 
    if ($qtype eq 't') { $qtype2= $qtype{'e'}; }
    elsif ($qtype eq 't0') { $qtype2= $qtype{'e0'}; }
}
else { 
    $dname2= $dname; 
    $qtype2= $qtype{$qtype};
}

$ddir= "$idir/$dname2";                       # index directory
$qdir= "$idir/$dname/query/$qtype2/$qsubd";   # query directory
$rdir= "$ddir/results";                       # result directory

$logdir= "$ddir/rtlog";
if (!-e $logdir) {
    my @errs=&makedir($logdir,$dirmode,$group);
    print LOG "\n",@errs,"\n\n" if (@errs);
}

if ($rtype eq "vsm") {
    $rt_c     = "sr_all.out";             # retrieval module
    $qidx_cc  = "qidx0_all.out";          # query conversion module
    $slope    = "0.3";                    # slope for Lnu weight
}
elsif ($rtype eq "okapi") {
    $rt_c     = "sr_all2.out";             # retrieval module
    $qidx_cc  = "qidx0_all2.out";          # query conversion module
    $k1       = "1.2";                     # BM25 parameter
    $b        = "0.75";                    # BM25 parameter
    $k3       = "7";                       # BM25 parameter
}


#-------------------------------------------------
# start program log
#-------------------------------------------------

$sfx= $rtype."-$qtype$qsubd"; # program log file suffix
$sfx .= $itype if ($itype);
$argp=0;                      # if 1, do not print arguments to log
$append=0;                    # log append flag

if ($K3) {
    $k3=$K3;
    if ($K3 ne '7') {
	$sfx .= "_$K3";
	$odir= "$rdir/$qtype{$qtype}/$rtype$K3/$qsubd";  # output directory
    }
    else {
	$odir= "$rdir/$qtype{$qtype}/$rtype/$qsubd";  # output directory
    }
}
else {
    $odir= "$rdir/$qtype{$qtype}/$rtype/$qsubd";  # output directory
}

if ($log) { 
    @start_time= &begin_log($logdir,$filemode,$sfx,$argp,$append);
    if ($rtype eq 'vsm') { print LOG "VSM: slope=$slope\n\n"; }
    elsif ($rtype eq 'okapi') { print LOG "OKAPI: k1=$k1, b=$b, k3=$k3\n\n"; }
    print LOG "Index Directory  = $ddir\n",
              "Query Directory  = $qdir\n",
              "Result Directory = $odir\n",
              '  - Subcollection results in $subd/q$qlen$qform$qn/',"\n",
              '  - Whole collection results in all/q$qlen$qform$qn.$iter',"\n",
              "  where \$subd  = subcollection directory\n",
              "        \$qlen  = query length (s, m, l)\n",
              "        \$qform = query form (a=acronym, n=noun, z=all)\n",
              "        \$iter  = retrieval iteration\n";
}

if (!-e $odir) { 
    my @errs=&makedir($odir,$dirmode,$group); 
    print LOG "\n",@errs,"\n\n" if (@errs);
}


#-------------------------------------------------
# get collection specific subdirectories
#-------------------------------------------------

if ($dname2 eq "hard") {
    @subd= @hard_subd;
    $subdn= @hard_subd;
}
elsif ($dname2 eq "hardt") {
    @subd= @hardt_subd;
    $subdn= @hardt_subd;
}


#-------------------------------------------------
# execute batch retrieval
#-------------------------------------------------

# get total number of indexed documents
$maxdnall= `tail -1 $ddir/maxdocno`;
chomp $maxdnall;

# get a list of queries
opendir(QD,$qdir) || die "can't opendir $qdir";
@qrys=readdir(QD);
closedir QD;

# execute subcollection retrievals in sequence  
#  -- use whole collection stats (i.e. doc_norm_all) so that
#     retrieval results can simply be merged later by doc. scores
$dcnt=0;
foreach $subd(@subd) {

    last if ($run_mode==0 && ++$dcnt>1);

    local ($indir,$outdir);

    $indir="$ddir/$subd";
    $outdir="$odir/$subd";

    $FIFO  = "$indir/SRSTAT";

    # create output directories
    if (!(-e "$outdir")) { &makedir($outdir,$dirmode,$group); }
    
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
    foreach $qry(@qrys) {
    
        if ($qpfx && $qry!~/^$qpfx/) { next; }

        next if (-d "$qdir/$qry");

        $qry=~/(\d+)$/;
	my $qnum=$1;
        if ($qnum && $qnum<$fqnum) { next; }

        #next if ($qry!~/^q[sdml]/);

	# for eval topics, run only long queries 
        #next if (($dname ne 'web') && $qtype=~/^e$/ && $qry!~/^ql/);

	last if ($run_mode==0 && $qcnt>3);

        $qin  = "$qdir/$qry";       # input query
        $udir = "$outdir/$qry";     # user directory
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
	    $ec= system("$tpdir/$qidx_cc $qin $qout $indir $k3");
	    if ($ec) { die "!!Error: $ec= $qidx_cc $qin $qout $indir $k3\n"; }
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

$alldir= "$odir/all";  # whole collection result

foreach $qry(@qrys) {
    
    if ($qpfx && $qry!~/^$qpfx/) { next; }
    next if (-d "$qdir/$qry");

    $qry=~/(\d+)$/;
    my $qnum=$1;
    if ($qnum && $qnum<$fqnum) { next; }

    #next if ($qry!~/^q[sdml]/);

    # for eval topics, run only long queries 
    #next if (($dname ne 'web') && $qtype=~/^e$/ && $qry!~/^ql/);

    %rtdoc=();

    # merge subcollection results
    foreach $subd(@subd) {
	my $rd;
	if ($dname eq 'web') {
	    $rd = "$odir/$subd/$itype/$qry/RD1";
	}
	else {
	    $rd = "$odir/$subd/$qry/RD1";
	}
	open(RD,"$rd") || die "can't read $rd";
	while(<RD>) {
	    s/^\s+//;
	    my ($rank,$dn,$score) = split(/\s+/,$_);       
	    $rtdoc{"$dn-$subd"}= $score;
	}
	close(RD);
    }

    $qry=~m|(q[a-z]+?)\d+$|;
    my $qsubdir= "$1";
    my $alld= "$alldir/$qsubdir";
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

if ($log) { &end_log($tpdir,$ddir,$filemode,@start_time); }


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
