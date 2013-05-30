#!/usr/bin/perl -w

# -----------------------------------------------------------------
# Name:      mklex1.pl
# Author:    Kiduk Yang, 6/6/2007
#            modified 6/24/08
#             - uses 2007 qrels
#             - uses 2007 index
#             $Id: mklex1.pl,v 1.1 2008/06/27 00:42:25 kiyang Exp $
# -----------------------------------------------------------------
# Description:  extract training data from blog collection
#   1. identify positive and negative training blogIDs from qrels file
#   2. create blog subcollection of training data
#      a. raw data
#      b. processed data
# -----------------------------------------------------------------
# Argument:  arg1= t or e
# Input:     
#   /u1/trec/qrels/07.qrels.opinion - qrels file
#   $idir/YYYYMMDD/
#     nonEdoc0  -- nonEdoc identified from feed
#     nulldoc0  -- 404 nulldoc identified from feed
#     nonEdoc  -- nonEdoc identified from blog
#     nulldoc  -- nulldoc before NR identified from blog
#     nulldocx -- nulldoc after NR identified from blog
#   $ddir/YYYYMMDD/permalinks-nnn
# Output:    
#   $idir/trainData/dnref_op(2) - docID to blogID mapping (opinion blog)
#       DOCN TREC_DOCN REL WDCNT (per line)
#   $idir/trainData/dnref_nop(2)- docID to blogID mapping (non-opinion blog)
#       DOCN TREC_DOCN REL WDCNT (per line)
#   $idir/trainData/op(2)/raw/$docn  - raw opinion blog file (HTML)
#   $idir/trainData/op(2)/docs/$docn - processed opinion blog file
#   $idir/trainData/op(2)/docx/$docn - processed opinion blog file (after NR)
#   $idir/trainData/nop(2)/raw/$docn  - raw non-opinion blog file (HTML)
#   $idir/trainData/nop(2)/docs/$docn - processed non-opinion blog file
#   $idir/trainData/nop(2)/docx/$docn - processed non-opinion blog file (after NR)
#   $idir/trainData/$prog        -- program     (optional)
#   $idir/trainData/$prog.log    -- program log (optional)
# -----------------------------------------------------------------
# NOTE:
#   1. nonEdocs & nulldocs are excluded from qrels IDs
#   2. documents with more than 10000 words are excluded
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

use constant MAXBYTES => 10**5;
use constant MAXWDCNT => 5*10**4;

my $wpdir=  "/u0/widit/prog";           # widit program directory
my $tpdir=  "$wpdir/trec08";            # TREC program directory
my $pdir=   "$tpdir/blog";              # Blog track program directory
my $ddir=   "/u2/trec/blog06";          # TREC raw data directory
my $idir=   "/u3/trec/blog07";          # TREC index directory

my $odir= "$idir/trainData";

require "$wpdir/logsub2.pl";   # subroutine library
require "$pdir/blogsub.pl";   # blog subroutine library


#------------------------
# program arguments
#------------------------
my $prompt=
"arg1= t for train, e for test data\n";

my %valid_args= (
0 => " t e ",
);

my ($arg_err,$qtype)= chkargs($prompt,\%valid_args,1);
die "$arg_err\n" if ($arg_err);

my ($opdir,$nopdir,$opdnref,$nopdnref,$qrelf);

if ($qtype eq 'e') {
    $opdir= "$odir/op2";
    $nopdir= "$odir/nop2";
    $opdnref = "$odir/dnref_op2";          # opinion dnref (docID to blogID mapping)
    $nopdnref= "$odir/dnref_nop2";         # non-opinion dnref (docID to blogID mapping)
    $qrelf=  "/u1/trec/qrels/07.qrels.opinion";

}
else {
    $opdir= "$odir/op";
    $nopdir= "$odir/nop";
    $opdnref = "$odir/dnref_op";          # opinion dnref (docID to blogID mapping)
    $nopdnref= "$odir/dnref_nop";         # non-opinion dnref (docID to blogID mapping)
    $qrelf=  "/u1/trec/qrels/qrels.blog06";
}

my $oprd= "$opdir/raw";
my $opdd= "$opdir/docs";
my $opxd= "$opdir/docx";
my $noprd= "$nopdir/raw";
my $nopdd= "$nopdir/docs";
my $nopxd= "$nopdir/docx";

foreach my $dir($oprd,$opdd,$opxd,$noprd,$nopdd,$nopxd) {
    `mkdir -p $dir` if (!-e $dir);
}



#-------------------------------------------------
# start program log
#-------------------------------------------------

$sfx= $qtype;              # program log file suffix
$noargp=1;             # if 1, do not print arguments to log
$append=0;             # log append flag

if ($log) {
    @start_time= &begin_log($odir,$filemode,$sfx,$noargp,$append);
    print LOG "INF = $qrelf\n",
              "      $idir/YYMMDD/nonEdoc0, nulldoc0, nonEdoc, nulldoc, nulldocx\n",
              "      $ddir/YYMMDD/permalinks-nnn\n",
              "OUTF= $opdnref\n",
              "      $nopdnref\n",
              "      $opdir/(raw|docs|docx)/\$docN\n",
              "      $nopdir/(raw|docs|docx)/\$docN\n\n";
}


#--------------------------------------------------------------------
# process each blog subdirctory         
#--------------------------------------------------------------------

opendir(DIR,"$idir") || die "can't opendir $idir";        
my @dirs = readdir(DIR);
closedir(DIR);                                     

my %nrdoc;
foreach my $yymmdd(@dirs) {

    next if ($yymmdd !~ /^\d{8}$/);

    # from feed files
    my $nef0= "$idir/$yymmdd/nonEdoc0";
    my $nlf0= "$idir/$yymmdd/nulldoc0";   # 404 nulldoc

    # from permalink files
    my $nef1= "$idir/$yymmdd/nonEdoc";
    my $nlf1= "$idir/$yymmdd/nulldoc";
    my $nxf1= "$idir/$yymmdd/nulldocx";

    foreach my $nrf($nef0,$nlf0,$nef1,$nlf1,$nxf1) {
        open(IN,$nrf) || die "can't read $nrf";
        while(<IN>) {
            my($n,$id)=split/ /;
            $nrdoc{$id}++;
        }
        close IN;
    }

} #endfor $yymmdd


#-------------------------------------------------
# read in qrels file to create %qrels
#   k=blogID, v=highest nonzero value
#-------------------------------------------------
# add to %ops if rel_sc>1:
# add to %nops if rel_sc=1:
#   -1: not judged
#    0: not relevant
#    1: on-topic only
#    2: on-topic & negative opinion
#    3: on-topic & mixed opinion
#    4: on-topic & postive opinion
#-------------------------------------------------
open(IN,$qrelf) || die "can't read $qrelf";
my @lines=<IN>;
close IN;
chomp @lines;

my (%ops,%nops,%opx,%nopx,%cnt,@IDs);
foreach (@lines) {
    my($qn,$dummy,$id,$rel)=split/ +/;
    if ($rel==1) {
        if ($nrdoc{$id}) {
            if (!$nopx{$id}) {
                $cnt{'nrdN0'}++;
                $cnt{'nrdN'}++;
            }
            $nopx{$id}=1;
        }
        else {
            push(@IDs,$id);
            if (!$nops{$id}) {
                $cnt{'dN0'}++;
                $cnt{'dN'}++;
            }
            $nops{$id}=1;
        }
    }
    elsif ($rel>1) {
        if ($nrdoc{$id}) {
            if (!$opx{$id}) {
                $cnt{'nrdN1'}++;
                $cnt{'nrdN'}++;
            }
            $opx{$id}=1;
        }
        else {
            push(@IDs,$id);
            if (!$ops{$id}) {
                $cnt{'dN1'}++;
                $cnt{'dN'}++;
            }
            $ops{$id}=$rel;
        }
    }
}


#-------------------------------------------------
# extract blog data of training IDs: 1 blog per file
#  - raw data from permalinks-nnn
#  - processed (docs & docx) data from pmlnnn
#-------------------------------------------------

my %files;
foreach my $id(@IDs) {
    my($b,$subd,$fn)=split/-/,$id;
    $files{"$subd-$fn"}=1;
}

my ($opdn,$nopdn)=(0,0);
my ($ldcnt1,$ldcnt0)=(0,0);
my (%opref,%nopref);

foreach my $file(keys %files) {

    my($subd,$fn)=split/-/,$file;
    my $in1="$ddir/$subd/permalinks-$fn";
    my $in2="$idir/$subd/docs/pml$fn";
    my $in3="$idir/$subd/docx/pml$fn";

    print STDOUT "processing $in1\n" if ($debug);

    # output processed & noise-reduced blog contents to files
    my ($cnt1,$cnt0,%idref)= &get_blogdoc2($in3,$opdir,$nopdir,'docx',\$opdn,\$nopdn,\%ops,\%nops,\%opref,\%nopref);
    $ldcnt1 += $cnt1;
    $ldcnt0 += $cnt0;

    # output processed blog contents to files
    &get_blogdoc($in2,$opdir,$nopdir,'docs',\%ops,\%nops,\%idref);

    # output raw blog HTMLs to files
    &get_blograw($in1,$opdir,$nopdir,\%ops,\%nops,\%idref);

} #endforeach $file

# output DNREF files
my $opcnt=&printHash($opdnref,\%opref,' ','nk');
my $nopcnt=&printHash($nopdnref,\%nopref,' ','nk');

print LOG "\n";
if ($opcnt!=$opdn || $nopdn!=$nopcnt) {
    print LOG "ERROR: check DNREF files (opdn=$opdn, opcnt=$opcnt;  nopdn=$nopdn, nopcnt=$nopcnt)\n\n";
}

my $ldcnt= $ldcnt1+$ldcnt0;
my $dNcnt= $cnt{'dN'}-$ldcnt;
my $dN1cnt= $cnt{'dN1'}-$ldcnt1;
my $dN0cnt= $cnt{'dN0'}-$ldcnt0;

print LOG "$dNcnt training docs ($dN1cnt opinion, $dN0cnt non-opinion)\n".
          " -- Excluded NR docs: $cnt{'nrdN'} training docs ($cnt{'nrdN1'} opinion, $cnt{'nrdN0'} non-opinion)\n".
          " -- Excluded long docs: $ldcnt training docs ($ldcnt1 opinion, $ldcnt0 non-opinion)\n";


#-------------------------------------------------
# end program
#-------------------------------------------------

&end_log($pdir,$odir,$filemode,@start_time) if ($log);

# notify author of program completion
#&notify($sfx,$author);


##############################################
# SUBROUTINES
##############################################

BEGIN { print STDOUT "\n"; }
END { print STDOUT "\n"; }

#--------------------------------------------
# 1. extract blog HTML data from permalinks
# 2. output each blog to a file
#--------------------------------------------
#  arg1 = permalink file
#  arg2 = output directory
#  arg3 = pointer to opinion hash
#           k=blodID, v=rel (2..4)
#  arg4 = pointer to non-opinion hash
#           k=blodID, v=rel (1)
#  arg5 = pointer to blogID hash
#           k=blogID, v=docN
#--------------------------------------------
sub get_blograw {
    my ($inf,$opd,$nopd,$ohp,$nhp,$idhp)=@_;

    my @docs;
    &getdocs($inf,\@docs);

    foreach my $doc(@docs) {

        my ($docno,$feedno,$bhpno,$url,$html)=($1,$2,$3,$4,$5)
            if ($doc=~m|<DOCNO>(.+?)</DOCNO>.+?<FEEDNO>(.+?)</FEEDNO>.+?<BLOGHPNO>(.*?)</BLOGHPNO>.+?<PERMALINK>(.+?)</PERMALINK>.+?</DOCHDR>\n(.+)$|s);

        next if (!exists($idhp->{$docno}));

        my $outf;
        if (exists($ohp->{$docno})) {
            my $dn= $idhp->{$docno};
            $outf= "$opd/raw/$dn";
        }
        elsif (exists($nhp->{$docno})) {
            # truncate long documents
            my $dn= $idhp->{$docno};
            $outf= "$nopd/raw/$dn";
        }

        open(OUT,">$outf") || die "can't write to $outf";
        print OUT "<!-- $docno -->\n",$html;
        close OUT;

    } #endforeach $doc

} #endsub get_blograw


#--------------------------------------------
# 1. extract processed blog content from pml file
# 2. output each blog to a file
#--------------------------------------------
#  arg1 = pml file
#  arg2 = output directory
#  arg3 = document subdirectory name (i.e. docs, docx)
#  arg4 = pointer to opinion hash
#           k=blodID, v=rel (2..4)
#  arg5 = pointer to non-opinion hash
#           k=blodID, v=rel (1)
#  arg6 = pointer to blogID hash
#           k=blogID, v=docN
#--------------------------------------------
sub get_blogdoc {
    my ($in,$opd,$nopd,$docd,$ohp,$nhp,$idhp)=@_;

    open(IN,$in) || die "can't read $in";
    my @lines=<IN>;
    close IN;

    my @docs= split(/<\/doc>/,join("",@lines));
    delete($docs[-1]);  # delete the last null split

    foreach my $doc(@docs) {

        my ($docno,$title,$body)=($1,$2,$3) if ($doc=~m|<docno>(.+?)</docno>.+?<ti>(.*?)</ti>.*?<body>(.*?)</body>|s);

        next if (!exists($idhp->{$docno}));

        my $outf;
        if (exists($ohp->{$docno})) {
            my $dn= $idhp->{$docno};
            $outf= "$opd/$docd/$dn";
        }
        elsif (exists($nhp->{$docno})) {
            my $dn= $idhp->{$docno};
            $outf= "$nopd/$docd/$dn";
        }

        open(OUT,">$outf") || die "can't write to $outf";
        print OUT "<docno>$docno</docno>\n<title>$title</title>\n<body>$body</body>";
        close OUT;

    } #end-foreach $doc

} #endsub get_blogdoc


#--------------------------------------------
# 1. extract processed blog content from pml file
#     - exclude docs w/ 1000+ words
# 2. output each blog to a file
#--------------------------------------------
#  arg1 = pml file
#  arg2 = output directory
#  arg3 = document subdirectory name (i.e. docs, docx)
#  arg4 = pointer to opinion docN variable
#  arg5 = pointer to non-opinion docN variable
#  arg6 = pointer to opinion hash
#           k=blodID, v=rel (2..4)
#  arg7 = pointer to non-opinion hash
#           k=blodID, v=rel (1)
#  arg8 = pointer to opinion dnref hash
#           k=docN, v=blogID rel
#  arg9 = pointer to non-opinion dnref hash
#           k=docN, v=blogID rel
#  r.v. = (opinion_longdoc_cnt, non-opinion_longdoc_cnt,blogID hash)
#           k=blogID, v=docN
#--------------------------------------------
sub get_blogdoc2 {
    my ($in,$opd,$nopd,$docd,$odnp,$ndnp,$ohp,$nhp,$orfhp,$nrfhp)=@_;

    open(IN,$in) || die "can't read $in";
    my @lines=<IN>;
    close IN;

    my @docs= split(/<\/doc>/,join("",@lines));
    delete($docs[-1]);  # delete the last null split

    my %idref;
    my ($lcnt1,$lcnt0)=(0,0);

    foreach my $doc(@docs) {

        my ($docno,$title,$body)=($1,$2,$3) if ($doc=~m|<docno>(.+?)</docno>.+?<ti>(.*?)</ti>.*?<body>(.*?)</body>|s);

        my $outf;
        my $wdcnt;
        if (exists($ohp->{$docno})) {
            # exclude long documents
            my @wdcnt= $body=~/ +/g;
            $wdcnt=@wdcnt+1;
            if ($wdcnt>=MAXWDCNT) {
                print "!LongDoc exclusion (",MAXWDCNT,"+ words): R$ohp->{$docno} $docno\n";
                $lcnt1++;
                next;
            }
            $$odnp++;
            $orfhp->{$$odnp}="$docno $ohp->{$docno} $wdcnt";
            $outf= "$opd/$docd/$$odnp";
            $idref{$docno}=$$odnp;
        }
        elsif (exists($nhp->{$docno})) {
            # exclude long documents
            my @wdcnt= $body=~/ +/g;
            $wdcnt=@wdcnt+1;
            if ($wdcnt>=MAXWDCNT) {
                print "!LongDoc exclusion (",MAXWDCNT,"+ words): R1 $docno\n";
                $lcnt0++;
                next;
            }
            $$ndnp++;
            $nrfhp->{$$ndnp}="$docno 1 $wdcnt";
            $outf= "$nopd/$docd/$$ndnp";
            $idref{$docno}=$$ndnp;
        }
        else {
            next;
        }

        open(OUT,">$outf") || die "can't write to $outf";
        print OUT "<docno>$docno</docno>\n<title>$title</title>\n<body>$body</body>";
        close OUT;

    } #end-foreach $doc

    return ($lcnt1,$lcnt0,%idref);

} #endsub get_blogdoc2
