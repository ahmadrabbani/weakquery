#!/usr/bin/perl -w
#
# 1. get runtime from log files
# 2. create a shell script that runs indexing for all directories
#   Kiduk, 6/20/06
#   modified, 6/11/08 (runtime2.pl renamed)

if (@ARGV<3) { 
    die "arg1=number of job streams\n".
        "arg2=key variable (1=time, 2=docN, 3=fileN)\n".
        "arg3=shell script type (1=indx1, 2=indx2, 3=indx3, 123=indx123)\n";
}
($strN,$vtype,$stype)=@ARGV;
$strN=10 if (!$strN);

$logs= "/u3/trec/blog07/200*/indxblog1.pl.log";
$div= "#-----------------------------------------";

$outf= "indx$stype"."all.sh";

open(OUT,">$outf") || die "can't write to $outf";
$head=&head("indxblog$stype");
print OUT "$head\n";

# get runtime from log files
open(IN,"grep REAL $logs |") || die "can't grep REAL $logs\n";
$totsec=0;
while(<IN>) {
    /(200\d+).+?REAL TIME\s+= (\d+):(\d+):(\d+)/;
    my $sec= $2*60*60 + $3*60 +$4;
    $runtime{$1}= $sec;
    $totsec += $sec;
}
$interval1= int($totsec/$strN);

open(IN,"grep -B5 REAL $logs | grep Processed |") || die "can't grep REAL | Processed $logs\n";
($totf,$totd)=(0,0);
while(<IN>) {
    m|(200\d+)/.+?Processed (\d+) files .(\d+) docs: (\d+) nulldocs, (\d+) non-Eng|;
    $fcnt{$1}= $2;
    $dcnt{$1}= $3-$5;
    $totf += $2;
    $totd += $3-$5;
}
$interval2= int($totd/$strN);
$interval3= int($totf/$strN);


if ($vtype==1) {
    print "Ideal Jobstream = $interval1 seconds\n\n";
    $interval=$interval1;
    &group_job($interval,%runtime);
}
elsif ($vtype==2) {
    print "Ideal Jobstream = $interval2 docs\n\n";
    $interval=$interval2;
    &group_job($interval,%dcnt);
}
elsif ($vtype==3) {
    print "Ideal Jobstream = $interval3 files\n\n";
    $interval=$interval3;
    &group_job($interval,%fcnt);
}


for($jn=1;$jn<=$strN;$jn++) {
    print OUT "\n$div\n{\n";
    ($fcnt,$dcnt,$time)=(0,0.0);
    foreach $k(@{"job$jn"}) {
	my $sec=$runtime{$k};
	my $hr=int($sec/3600);
	my $mn=int(($sec%3600)/60);
	my $ss=($sec%60);
	my $fn=$fcnt{$k};
	my $dn=$dcnt{$k};
	printf "$k runtime = %02d:%02d:%02d,  file=%3d,  doc=%6d\n",$hr,$mn,$ss,$fn,$dn;
	print OUT "nohup indxblog1.pl 1 $k\n".
		  "  echo \"indx1: $k started\" >> \$logf\n" if ($stype=~/1/);
	print OUT "nohup indxblog2.pl 1 $k\n".
		  "  echo \"indx2: $k started\" >> \$logf\n" if ($stype=~/2/);
	print OUT "nohup ../indx3.pl 1 \$dir/$k\n".
		  "  echo \"indx3: $k started\" >> \$logf\n" if ($stype=~/3/);
        print OUT "\n" if ($stype=~/\d\d/);
	$time += $sec;
	$fcnt += $fn;
	$dcnt += $dn;
    }
    print "Jobstream #$jn = $time seconds, $fcnt files, $dcnt docs\n\n";
    print OUT "  echo \"Done: jobstream $jn\" >> \$logf\n  date >> \$logf\n\}&\n";
}

$tail=&tail;
print OUT "$div\n\n$tail";
close OUT;


#------------------------
# group jobs evenly
#------------------------
sub group_job {
    my ($interval,%job)=@_;
    my (@job,%mintime,%time,%doneJN);

    for($jn=1;$jn<=$strN;$jn++) {
	$mintime{$jn}= $interval*10;
	$time{$jn}= 0;
	$doneJN{$jn}= 0;
    }

    while (%job) {
	for($jn=1;$jn<=$strN;$jn++) {
	    foreach $k(sort {$job{$b}<=>$job{$a}} keys %job) {
		my $sec=$job{$k};
		if ($time{$jn}+$sec < $interval) {
		    push(@{"job$jn"},$k);
		    $time{$jn} += $sec;
		    delete($job{$k});
		    last;
		}
	    }
	}
	for($jn=1;$jn<=$strN;$jn++) {
	    next if ($doneJN{$jn});
	    foreach $k(sort {$job{$b}<=>$job{$a}} keys %job) {
		my $sec=$job{$k};
		if ($time{$jn}+$sec >= $interval) {
		    my $time2= $time{$jn}+$sec;
		    if ($time2<$mintime{$jn}) {
			$mintime{$jn}=$time2;
			$minjob{$jn}=$k;
		    }
		}
	    }
	    if ($mintime{$jn} < $interval*10) {
		push(@{"job$jn"},$minjob{$jn});
		$time{$jn} = $mintime{$jn};
		delete($job{$minjob{$jn}});
		$doneJN{$jn}=1;
	    }
	}
    }

    for($jn=1;$jn<=$strN;$jn++) {
	print "job $jn = $time{$jn}\n";
    }
    print "\n";

} #endsub group_job


#------------------------
sub head {
    my $prog=shift;

my $str= 
"#!/bin/sh\n\n".
"# run $prog.pl on all blog directories\n#   created by $0\n\n". 
'case $# in
0)
   echo
   echo "arg1= 1 to run"
   echo
   exit;;
esac

prog=${0:2}        # script name
logf=$prog.log     # script log

dir=/u3/trec/blog08

echo -ne "$prog started:\t\t" > $logf
start_time=`date`
date >> $logf
echo >> $logf'.
"\n\n";

    return $str;

} #endsub head
#------------------------


#------------------------
sub tail {

$str=qq(

wait

echo >> \$logf
echo -ne "\$prog finished:\\t" >> \$logf
date >> \$logf
end_time=`date`

# send completion notification via email
notify=yes
if [[ \$notify = "yes" ]]; then
    to=kiyang\@indiana.edu
    echo "\$prog is done!" > tmpf
    echo "   Start Time: \$start_time">> tmpf
    echo "   End   Time: \$end_time">> tmpf
    mail -s '\$prog' \$to < tmpf
fi
);

    return $str;

} #endsub tail
#------------------------
