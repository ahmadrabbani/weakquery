# -----------------------------------------------------------------
# Name:      LOGSUB.PL
# Author:    Kiduk Yang, 01/22/98
#              modified, 06/15/2004
# -----------------------------------------------------------------
# Description:
#    routines to write program logs
# -----------------------------------------------------------------
# bynumber:       sort by number
# rbynumber:      reverse sort by number
# znum:           put leading zeros
# time2str:       convert seconds to datetime string
# timestamp:      return timestamp
# weekday:        return day of the week from date (mm,dd,yy)
# timediff:       convert time differentials to seconds
# filename:       split filepath to directory and filename
# filestem:       parse filename stem from full path
# pnamepfx:       return current program name prefix
# logfile:        construct the name of logfile
# begin_log:      begin program log
# end_log:        end program log
# start_clock:    start system clock
# stop_clock:     stop system clock
# notify:         notify job completion via email
# makedir:        make a directory (and all its parent directories)
# chkargs:        check program arguments
# mkdbmf:         create a DBM file for hash from a file (KEY VAL per line)
# dircnt:         count the number of subdirectories
# getfiles:       get files in a directory
# readfile:       read a file and returns an array of lines
# min:            return the minimum value of an array
# max:            return the maximum value of an array
# file2hash:      create a hash from a file
# printHash:      print hash key & value to a file
# printHashVal:   print hash values to a file
# -----------------------------------------------------------------


# ------------------------------------------------
# SUBROUTINE BYNUMBER:
#   sort by numeric value
# ------------------------------------------------
sub bynumber {$a <=> $b;}
sub rbynumber {$b <=> $a;}


#---------------------------------------------------------
# put leading zeros
#---------------------------------------------------------
# arg1 = input number
# arg2 = number of digits for padded number
# r.v. = number padded with leading zeros
#---------------------------------------------------------
sub znum {
   my ($n,$width)=@_;
   $width=2 if (!$width);
   my($num,$dec)=split(/\./,$n);
   my $n2= sprintf("%0${width}d",$num);
   $n2 .= ".$dec" if ($dec);
   return $n2;
}


#------------------------------
# convert epoch seconds to datetime string
#------------------------------
#  arg1= seconds
#  r.v.= (YYYY,MM,DD,HR,MN,SS);
#------------------------------
sub time2str {
    my $time=shift;
    local ($ss,$mn,$hh,$dd,$mm,$yy)= localtime($time);
    $yy += 1900;
    my $mm2= sprintf("%02d",++$mm);
    foreach $name('dd','hh','mn','ss') {
        ${$name."2"}= sprintf("%02d",${$name});
    }
    
    return ($yy,$mm2,$dd2,$hh2,$mn2,$ss2);
}


#-------------------------------------
# get timestamp  
#-------------------------------------
#   arg1 = output format
#   arg2 = 0 for today, n for n week from today
#   r.v. = "HH:MN:SS, MM-DD-YY"
#-------------------------------------
sub timestamp {
    my ($fmt,$wk,$sep2)=@_;

    $fmt=0 if (!$fmt);
    $wk=0 if (!$wk);

    $time= time + 60*60*24*7*$wk;
    my ($ss,$mn,$hh,$dd,$mm,$yy,$wkd,$yrd,$isdl) = localtime($time);
    $mm= $mm+1;
    my $yy2= $yy+1900;
    foreach ($ss,$mn,$hh,$dd,$mm) { $_= znum($_); }

    my $wday= weekday($mm,$dd,$yy);
    my $tstr;
    if ($fmt==-1) { $tstr= "$yy2$sep2$mm$sep2$dd$sep2$wday"; }
    elsif ($fmt==1) { $tstr= "$yy$mm$dd"; }
    elsif ($fmt==2) { $tstr= "$mm$dd"; }
    elsif ($fmt==3) { $tstr= "$yy$mm$dd$hh"; }
    elsif ($fmt==4) { $tstr= "$yy$mm$dd$mn"; }
    elsif ($fmt==5) { $tstr= "$yy$mm$dd$ss"; }
    elsif ($fmt==6) { $tstr= "$yy$mm$dd$hh$mn$ss"; }
    elsif ($fmt==7) { $tstr= "$mm-$dd-$yy2"; }
    elsif ($fmt==8) { $tstr= "$hh:$mn:$ss, $yy2-$mm-$dd"; }
    elsif ($fmt==9) { $tstr= "$yy2-$mm-$dd"; }
    else { $tstr= "$hh:$mn:$ss, $mm-$dd-$yy2"; }
    return $tstr;
}


#------------------------------
# get Day of the Week from date
#------------------------------
# args = MM, DD, YY
# r.v. = Day of Week
#------------------------------
sub weekday {
    my ($mm,$dd,$yy)= @_;

    use Time::Local; 

    $mm -=1;  # month goes from 0 to 11;

    my $newtime= timelocal(0,0,0,$dd,$mm,$yy);

    my $wday= (Sun,Mon,Tue,Wed,Thu,Fri,Sat)[(localtime($newtime))[6]];

    return $wday;
}


#-----------------------------------------------------------
# convert time differentials to seconds
#-----------------------------------------------------------
#  args   = ($ssdiff,$mndiff,$hhdiff,$dddiff,$mmdiff,$yydiff)
#      where $??diff are computed from two timestamps in
#            hh:mn:ss, mm-dd-yyyy format
#  r.v.   = ($totsec,$hour,$min,$sec)
#      where $totsec = total elapsed time in seconds,
#            $day, $hour, $min, $sec are $totsec converted
#-----------------------------------------------------------
sub timediff {
    my (@diff)=@_;

    my %monthdays = (1=>31,2=>28,3=>31,4=>30,5=>31,6=>30,7=>31,8=>31,9=>30,10=>31,11=>30,12=>31);
    if ($yy1%4 == 0) { $monthdays{2}=29; }
    my @unit= (1,60,60,24,$monthdays{$mm1},12);

    #-----------------------------------------------
    # convert time differentials to seconds
    #-----------------------------------------------
    my $insec=1;
    my $totsec=0;
    my $i;
    for($i=0;$i<=$#diff;$i++) {
        if ($diff[$i]<0) {
            $diff[$i]= $unit[$i+1]+$diff[$i];
            $diff[$i+1]--;
        }
        $insec = $insec*$unit[$i];
        $totsec += $insec*$diff[$i];
    }

    #-----------------------------------------------
    # convert seconds to day, hour, minute, second
    #-----------------------------------------------
    $insec= 60*60*24;
    my $sec= $totsec;
    my ($day,$hour,$min)= (0,0,0);
    if ($sec>$insec) {
        $day= int($totsec/$insec);
        $sec= $sec%$insec;
    }
    $insec= 60*60;
    if ($sec>$insec) {
        $hour= int($sec/$insec);
        $sec= $sec%$insec;
    }
    $insec= 60;
    if ($sec>$insec) {
        $min= int($sec/$insec);
        $sec= $sec%$insec;
    }

    return ($totsec,$day,$hour,$min,$sec);

} # ensub-timediff



#-------------------------------------
# split full filepath to directory and filename
#   - trailing / removed from directory name
#-------------------------------------
#   arg1 = full file path
#   r.v. = (filename, directory)
#-------------------------------------
sub filename {
    my $path= $_[0];
    my ($file,$dir);

    if ($path =~ m|^(.*?)/?([^/]+)$|) {
        $dir=$1;
        $file=$2;
    }

    return ($file,$dir);
}



#-------------------------------------
# parse file name stem from full path
#-------------------------------------
#   arg1 = full file path
#   r.v. = filename stem (before .ext)
#-------------------------------------
sub filestem {
    my $path= $_[0];
    my $stem;

    if ($path =~ m|^.*/(\w+)\.\w+$|) {
        $stem=$1;
    }

    return $stem;
}


#-------------------------------------
# return the current program name prefix
#-------------------------------------
#   r.v. = program name without extension
#-------------------------------------
sub pnamepfx {
    $0=~m|.+/(.+)\.\w+$|;
    return $1;
}


#-------------------------------------
# construct the name of logfile
#-------------------------------------
#   arg1 = log directory
#   arg2 = logfile name prefix
#   arg3 = logfile name suffix (optional)
#   r.v. = full file path
#-------------------------------------
sub logfname {
    my ($dir,$name,$sfx) = @_;
    my $logf;

    if ($sfx) { $logf = "$dir/$name"."_$sfx.log"; }
    else { $logf = "$dir/$name.log"; }

    return $logf;
}


#-------------------------------------
# Subroutine BEGIN_LOG
#   -- begin writing the program log
#-------------------------------------
#   arg1 = log directory
#   arg2 = logfile permission (OCT)
#   arg3 = logfile suffix
#   arg4 = do not print arguments if 1
#   arg5 = append to log if 1
#   arg6 = (optional) input directory
#   arg7 = (optional) output directory
#   r.v. = (usertime,systime,time())
#-------------------------------------
sub begin_log {
    my ($ldir,$fm,$suffix,$noarg,$append,$ind,$outd) = @_;

    my $pdir= `pwd`; chomp $pdir;
    my ($pname) = filename($0);

    my $logfile = logfname($ldir,$pname,$suffix);
    if ($append) {
	open(LOG,">>$logfile") || die "LOG: can't append to $logfile";
	print LOG "\n-------------------------------------------------\n";
    }
    else {
	open(LOG,">$logfile") || die "LOG: can't open $logfile";
    }
    open(STDERR,">>&LOG") || die "STDERR: can't open $logfile";
    chmod($fm,"$logfile");

    select(LOG);
    $|=1;

    print LOG "PERL PROGRAM LOG: $pdir/$pname\n";
    if (!$noarg) {
	my $i;
	for($i=0;$i<=$#ARGV;$i++) {
	    print LOG "  arg$i = $ARGV[$i]\n";
	}
    }
    print LOG "\nStarting $pname --- ", timestamp(0), "\n\n";
    print STDOUT "Program log written to $logfile\n";

    print LOG "IND = $ind\n" if ($ind);
    print LOG "OUTD = $outd\n" if ($outd);
    print LOG "\n" if ($ind || $outd);

    my ($ut,$st)=times();
    return ($ut,$st,time());

}  # endsub begin_log


#-------------------------------------
# Subroutine END_LOG
#   -- finish writing the program log
#-------------------------------------
sub end_log {
    my ($pdir,$ldir,$fm,$sut,$sst,$begt) = @_;

    my ($pname) = filename($0);

    my ($eut,$est)=times;
    my $endt=time();
    my $difft=$endt-$begt;
    my $sec= ($difft%60);  my $min= int($difft/60);
    my $hr= int($min/60);  $min= ($min%60);

    print LOG "\nEnding $pname --- ", timestamp(0), "\n\n";
    printf LOG "  CPU seconds = %4.3f (UT),  %4.3f (ST)\n",
                $eut-$sut,$est-$sst;
    print LOG "  REAL TIME   = $hr:$min:$sec (hh:mn:ss)\n\n";
    close(LOG);

    if ($pdir ne $ldir) {
	$pname=~s/out$/pl/;
	system ("cp $pdir/$pname $ldir/$pname");
	chmod ($fm,"$ldir/$pname");
    }

}  # endsub end_log


#-------------------------------------
# Subroutine START_CLOCK
#   -- start system clock
#-------------------------------------
# r.v. = (user-time, system-time, time)
#-------------------------------------
sub start_clock {
    my ($pname) = filename($0);
    my $name = $_[0];

    my ($ut,$st)=times;
    print LOG "  -- Starting $name -- ", timestamp(0), "\n";

    return ($ut,$st,time());
} # endsub start_clock


#-------------------------------------
# Subroutine STOP_CLOCK
#   -- end system clock
#-------------------------------------
sub stop_clock {
    my ($name,$name2,$sut,$sst,$begt)=@_;
    my ($sec,$min,$hr);

    my ($eut,$est)=times;
    my $endt=time();
    my $difft=$endt-$begt;
    $sec= ($difft%60);  $min= int($difft/60);
    $hr= int($min/60);  $min= ($min%60);
    printf LOG "      $name2 took %4.3f (UT) & %4.3f (ST) CPU seconds\n",
                $eut-$sut,$est-$sst;
    print LOG "           $hr Hours $min Minutes $sec Seconds REAL TIME.\n";
    print LOG "  -- Ending $name -- ", timestamp(0), "\n\n";

} # endsub stop_clock


#-----------------------------------------------------------
# subroutine NOTIFY
#   -- notify end of job via email
#-----------------------------------------------------------
sub notify {
    my ($suffix,@users) = @_;

    my ($pname) = filename($0);
    if ($suffix) { $pname .= "_$suffix"; }

    my $users= join(",",@users);
    open(MAIL,"| mail -s '$pname' $users");
    print MAIL "$pname ENDED --- ", timestamp(0), "\n\n";
    close MAIL;

} # endsub notify


#--------------------------------------------------------------
# Subroutine makedir
#   -- make a target directory and all directories in its path
#--------------------------------------------------------------
# arg1 = directory name
# arg2 = file permission (octal)
# arg3 = group name (optional)
# r.v. = array of error messages
#--------------------------------------------------------------
sub makedir {
    my ($newd,$fm,$grp)= @_;     

    # arg1 must be full path
    if ($newd !~ m|^/|) {  
        die "!!ERROR!! arg1 must start with '/'\n", 
            "  arg1=$newd";
    }
   
    $newd= substr($newd,1);    
    my @dirs=split(m|/|,$newd);  

    my ($i,$newd2,@errmsg);   
    for($i=0;$i<=$#dirs;$i++) {      
        $newd2 .= "/$dirs[$i]";   
        if (!-e $newd2) { 
            mkdir($newd2,$fm); 
            chmod($fm,$newd2);  # override umask if needed
            if ($grp) {
		my $rc= system "chown :$grp $newd2";
		if ($rc) { push(@errmsg,"!!ERROR ($rc): chown :$grp $newd2\n"); }
		my $rc2= system "chmod g+s $newd2";
		if ($rc2) { push(@errmsg,"!!ERROR ($rc2): chmod g+s $newd2\n"); }
            }
        }   
        elsif (!-d $newd2) { die "!!ERROR!! $newd2 is not a directory\n"; } 
    }

    return (@errmsg);
 
}


#--------------------------------------------------------------
# check program arguments
#--------------------------------------------------------------
# arg1 = argument prompt
# arg2 = pointer to valid argument hash
#        (key= arg#, val= valid value string)
# arg3 = minimum number of arguments 
#        (optional: default= arg2 hash size)
# r.v. = error message (empty if valid)
#--------------------------------------------------------------
sub chkargs {
    my ($msg,$hashp,$argn)= @_;     

    $argn= keys %$hashp if (!$argn);
    my $msg2;

    if (@ARGV<$argn) {
	return $msg;
    }
    else {
        my $i;
        for($i=0;$i<$argn;$i++) {
	    my $valid=$$hashp{$i};
	    next if (!exists($$hashp{$i}));
	    my $goodarg=0;
	    my @valids=();
	    if (@valids= $valid=~/(\w+)\*/g) {
	        foreach $valid2(@valids) {
		    $goodarg=1 if ($ARGV[$i]=~/^$valid2/);
		}
	    }
	    if (@valids= $valid=~/\*(\w+)/g) {
	        foreach $valid2(@valids) {
		    $goodarg=1 if ($ARGV[$i]=~/$valid2$/);
		}
	    }
            if (!$goodarg && $valid && $valid!~/\b $ARGV[$i] \b/x) {
                my $j= $i+1;
                $msg=~s/arg$j/ARG$j/;
                $msg2= $msg;
            }
        }
    }

    return ($msg2,@ARGV);

}


#--------------------------------------------------------------
# Create a DBM file from a sorted text file of key & value per line
#--------------------------------------------------------------
# arg1= input file
# arg2= key-val reverse flag (1=reverse key-val)
# arg3= overwrite flag (1=overwrite, 0=keep)
# OUTPUT:    $arg1_dbm.pag
#            $arg1_dbm.dir
#--------------------------------------------------------------
sub mkdbmf {
    my ($inf,$flip,$flag)=@_;
    my %out;

    my $outf= $inf."_dbm";

    return 1 if (!$flag && (-e "$outf.dir"));

    open(IN,$inf) || die "can't read $inf";
    dbmopen(%out,$outf,0750) || die "can't dbmopen $outf";

    # make a random access file of key-value pair (associative array)
    while(<IN>) {
        chomp;
	my ($key,$val)=split/\s+/;
	$val=1 if (length($val)<1);
	if ($flip) { $out{$val}= $key; }
	else { $out{$key}=$val; }
    }
    close(IN);
    dbmclose(%out);

} #endsub mkdbmf


#--------------------------------------------------------------
# Count subdirectories w/ a given prefix
#--------------------------------------------------------------
# arg1= parent directory
# arg2= subdirectory prefix
# r.v.= subdirectory count
#--------------------------------------------------------------
sub dircnt {
    my ($ind,$pfx)=@_;

    opendir(IND,$ind) || die "can't opendir $ind: $!";
    my @files=readdir(IND);
    closedir IND;

    my $cnt=0;
    foreach (@files) {
        next if (!/^$pfx/);
	$cnt++ if (-d "$ind/$_");
    }

    return $cnt;

} #endsub dircnt


#--------------------------------------------------------------
# get files in a directory
#--------------------------------------------------------------
# arg1= directory
# arg2= file name string (optional)
# arg3= file inclusion flag (optional: 0=exclude, 1=include)
# arg4= name string type (optional: 0=prefix, 1=suffix)
# r.v.= array of filenames
#--------------------------------------------------------------
sub getfiles {
    my ($ind,$fstr,$inc,$stype)=@_;

    opendir(IND,$ind) || die "can't opendir $ind: $!";
    my @files=readdir(IND);
    closedir IND;

    my @list;
    foreach (@files) {
        next if (/^\./);
	# file suffix
	if ($stype) { 
	    # include files w/ $fstr suffix
	    if ($inc) { 
		next if (!/$fstr$/); 
	    }
	    # exclude files w/ $fstr suffix
	    else { 
	        next if ($fstr && /$fstr$/); 
	    }
	}
	# file prefix
	else {
	    # include files w/ $fstr prefix
	    if ($inc) { 
		next if (!/^$fstr/); 
	    }
	    # exclude files w/ $fstr prefix
	    else { 
	        next if ($fstr && /^$fstr/); 
	    }
	}
	push(@list,$_);
    }

    return @list;

} #endsub getfiles


#--------------------------------
# 1. read in a file
# 2. return an array of lines
#--------------------------------
#   arg1 = file name
#   arg2 = pointer to text array
#   arg3 = log flag
#--------------------------------
sub readfile {
    my ($inf,$listp,$log)= @_;

    print LOG "- Reading $inf\n" if ($log);

    open(IN,$inf) || die "can't read $inf";
    @{$listp}=<IN>;
    close IN;
}


#--------------------------------------------------------------
# return the minimum value
#--------------------------------------------------------------
# args= list of numeric values
# r.v.= minimum value
#--------------------------------------------------------------
sub min {
    my @list=@_;
    my @list2= sort {$a<=>$b} @list;
    return $list2[0];
}

#--------------------------------------------------------------
# return the maximum value
#--------------------------------------------------------------
# args= list of numeric values
# r.v.= maximum value
#--------------------------------------------------------------
sub max {
    my @list=@_;
    my @list2= sort {$b<=>$a} @list;
    return $list2[0];
}


#--------------------------------------------------------------
# make a hash from a file
#--------------------------------------------------------------
# arg1= input file
# arg2= pointer to hash to be created
# arg3= seperator for fields in file
# arg4= index for key field (0..n)
# arg5= index for value field (0..n)
#--------------------------------------------------------------
sub file2hash {
    my ($file,$hp,$sep,$kn,$vn)=@_;

    open(IN,$file) || die "can't read $file";
    my @lines=<IN>;
    close IN;
    chomp @lines;

    foreach (@lines) {
        my @flds= split/$sep/;
        my($key,$val)=($flds[$kn],$flds[$vn]);
        $hp->{$key}=$val;
    }
}


#--------------------------------------------
# print hash key & value to a file
#--------------------------------------------
#  arg1 = output file
#  arg2 = pointer to hash
#  arg3 = field seperator (optional: default=' ')
#  arg4 = sort type (optional: default=bykey, no=nosort)
#         char sort: k=bykey, rk=rbykey, v=byval, rv=rbyval
#         num sort: nk=bykey, rnk=rbykey, nv=byval, rnv=rbyval
#  r.v. = number of hash elements
#--------------------------------------------
sub printHash {
    my($outf,$hp,$sep,$sort)=@_;

    $sep=' ' if (!defined $sep);
    $sort='k' if (!defined $sort);

    open(OUT,">$outf") || die "can't write to $outf";
    my $cnt=0;

    if ($sort eq 'k') {
        foreach my $k(sort keys %$hp) {
            print OUT "$k$sep$hp->{$k}\n";
            $cnt++;
        }
    }
    elsif ($sort eq 'no') {
        foreach my $k(keys %$hp) {
            print OUT "$k$sep$hp->{$k}\n";
            $cnt++;
        }
    }
    elsif ($sort eq 'nv') {
        foreach my $k(sort {$hp->{$a}<=>$hp->{$b}} keys %$hp) {
            print OUT "$k$sep$hp->{$k}\n";
            $cnt++;
        }
    }
    elsif ($sort eq 'rnv') {
        foreach my $k(sort {$hp->{$b}<=>$hp->{$a}} keys %$hp) {
            print OUT "$k$sep$hp->{$k}\n";
            $cnt++;
        }
    }
    elsif ($sort eq 'nk') {
        foreach my $k(sort {$a<=>$b} keys %$hp) {
            print OUT "$k$sep$hp->{$k}\n";
            $cnt++;
        }
    }
    elsif ($sort eq 'rnk') {
        foreach my $k(sort {$b<=>$a} keys %$hp) {
            print OUT "$k$sep$hp->{$k}\n";
            $cnt++;
        }
    }
    elsif ($sort eq 'v') {
        foreach my $k(sort {$hp->{$a} cmp $hp->{$b}} keys %$hp) {
            print OUT "$k$sep$hp->{$k}\n";
            $cnt++;
        }
    }
    elsif ($sort eq 'rv') {
        foreach my $k(sort {$hp->{$b} cmp $hp->{$a}} keys %$hp) {
            print OUT "$k$sep$hp->{$k}\n";
            $cnt++;
        }
    }
    elsif ($sort eq 'rk') {
        foreach my $k(sort {$b cmp $a} keys %$hp) {
            print OUT "$k$sep$hp->{$k}\n";
            $cnt++;
        }
    }
    else {
        foreach my $k(sort keys %$hp) {
            print OUT "$k$sep$hp->{$k}\n";
            $cnt++;
        }
    }

    close OUT;

    return $cnt;
}


#--------------------------------------------
# print hash values to a file
#--------------------------------------------
#  arg1 = output file
#  arg2 = pointer to hash
#  r.v. = number of hash elements
#--------------------------------------------
sub printHashVal {
    my($outf,$hp)=@_;

    open(OUT,">$outf") || die "can't write to $outf";
    my $cnt;
    foreach my $k(sort keys %$hp) {
        print OUT $hp->{$k},"\n";
        $cnt++;
    }
    close OUT;

    return $cnt;
}


#--------------------------------------
# print variable values
#--------------------------------------
# arg1= pointer to variable
# arg2= variable name
#--------------------------------------
sub pdump {
    my ($ptr,$name)=@_;
    print "\n";
    my $var= "*$name";
    print Data::Dumper->Dump([$ptr], ["*$name"]); 
    print "\n";
}


return 1;
