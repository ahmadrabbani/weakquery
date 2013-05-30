#!/usr/bin/perl -w

if (@ARGV<1) { die "arg1=train or test"; }

$qdir="/u3/trec/blog08/query/$ARGV[0]";

if ($ARGV[0] eq 'test') { $qt='E'; }
elsif ($ARGV[0] eq 'train') { $qt='T'; }

open(OUT,">qlist/qxall$qt") || die "can't write to qlist/qxall$qt";

foreach $qsubd(s0wk,s0gg,s0gg2,s0gg3,s0wg,s0wgx) {
     opendir(IND,"$qdir/$qsubd") || die "can't opendir $qdir/$qsubd";
     my @files=readdir IND;
     closedir IND;
     foreach $file(@files) {
         next if (-d "$qdir/$qsubd/$file");
         next if ($file !~ /^q/);
         print OUT "$qsubd/$file\n";
     }
}

close OUT;
