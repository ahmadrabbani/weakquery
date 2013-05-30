#!/usr/bin/perl -w

# -----------------------------------------------------------------
# Name:      indxblog1.pl
# Author:    Kiduk Yang, 6/11/2006
#             modifed 5/22/2007
#             modifed 5/28/2008
#             $Id: indxblog1.pl,v 1.2 2008/06/27 00:42:09 kiyang Exp $
# -----------------------------------------------------------------
# Description:  INDEXING STEP 1 for Blog track
#   1. create DNREF file that relates WIDIT doc# with TREC doc# & URL
#   2. create FNREF file that relates filenames with WIDIT doc#'s
#   3. create files to be stopped and stemmed.
#      - strip HTML tags & exclude style and script text
#      - for each file, extract title & body text
#   4. create NULLDOC file that lists empty pre-processed docs
#   5. create NONEDOC file that lists non-English docs
# -----------------------------------------------------------------
# Arguments: arg1 = run mode (0 for test, 1 for real)
#            arg2 = collection subdirectory (YYYYMMDD)
# Input:     $idir/$arg2/permalinks-nnn  -- Raw files to be indexed
#            $idir/$arg2/nonEdoc0        -- nonEdoc flagged by feed
#            $idir/$arg2/nulldoc0        -- nulldoc flagged by feed
# Output:    $odir/$arg2/docs/pml$nnn -- processsed body text files
#            $odir/$arg2/docx/pml$nnn -- processsed body text files after noise reduction
#            $odir/$arg2/dnref1       -- WIDIT to TREC doc number mapping
#                WIDIT_DOCN TREC_DOCN (per line)
#            $odir/$arg2/fnref1  -- File to WIDIT doc number mapping
#                FileNum FilePath first_WIDIT_DOCN last_WIDIT_DOCN (per line)
#            $odir/$arg2/longdoc      -- list of long docs
#            $odir/$arg2/nulldoc      -- list of null docs
#            $odir/$arg2/nulldocx     -- list of null docs after noise reduction
#                WIDIT_DOCN TREC_DOCN URL (per line)
#            $odir/$arg2/nonEdoc      -- list of non-English docs
#                WIDIT_DOCN TREC_DOCN URL (per line)
#            $odir/$arg2/$prog        -- program     (optional)
#            $odir/$arg2/$prog.log    -- program log (optional)
# -----------------------------------------------------------------
# OUTPUT file format
#  <doc>
#    <docno>$trec_docn</docno>
#    <url>$url</url>
#    <feedno>FEEDNO</feedno>
#    <bhpno>BLOGHPNO</bhpno>
#    <head>
#      <ti>$title</ti>
#    </head>
#    <body>
#      $word $word ...
#    </body>
#  </doc>
# -----------------------------------------------------------------
# NOTE:
#   1. processes permalinks only
#       - extremely long docs are truncated (maxlen= 10M bytes)
#   2. creates a subcollection in each subdirectory ($arg2)
#   3. multiple documents per input/output file
#   4. as a general strategy, as much of the raw data are kept intact
#      as much as possible.  Files will be more flexible this way,
#      and can be used for display in interactive system.
#      Different types of indexes can be created by adjusting
#      indexing parameters in later modules
#      (e.g. special character handling, field inclusion/exclusion)
# -----------------------------------------------------------------

use strict;
use Data::Dumper;
$Data::Dumper::Purity=1;

no warnings "recursion";

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

use constant MAXBYTES => 10**6;

my $wpdir=  "/u0/widit/prog";           # widit program directory
my $tpdir=  "$wpdir/trec08";            # TREC program directory
my $pdir=   "$tpdir/blog";              # Blog track program directory
my $idir=   "/u2/trec/blog06";          # TREC raw data directory
my $odir=   "/u3/trec/blog08";          # TREC index directory

require "$wpdir/logsub2.pl";
require "$pdir/blogsub.pl";


#------------------------
# program arguments
#------------------------
my $prompt=
"arg1= run mode (0 for test, 1 for real)\n".
"arg2= subdirectory (yyyymmdd, e.g. 20051206)\n";

my %valid_args= (
0 => " 0 1 ",
);

my ($arg_err,$run_mode,$subd)= chkargs($prompt,\%valid_args,2);
die "$arg_err\n" if ($arg_err);

my $indir=  "$idir/$subd";        # raw data directory
my $outdir= "$odir/$subd";        # processed data directory

# document directory
my ($docdir,$docxdir);
if ($run_mode==0) {
    $docdir= "$outdir/docsT";
    $docxdir= "$outdir/docxT";
}
else {
    $docdir= "$outdir/docs";
    $docxdir= "$outdir/docx";
}

my $nulldoc0="$outdir/nulldoc0";    # list of null content blogs by FEED
my $nonEdoc0="$outdir/nonEdoc0";    # list of non-English blogs by FEED

my $nulldoc="$outdir/nulldoc";    # list of null content blogs
my $nonEdoc="$outdir/nonEdoc";    # list of non-English blogs
my $nulldocx="$outdir/nulldocx";  # list of null content blogs w/ noise reduction
my $longdoc="$outdir/longdoc";    # list of long documents

my $dnref= "$outdir/dnref1";
my $fnref= "$outdir/fnref1";


#-------------------------------------------------
# start program log
#-------------------------------------------------

# program log file suffix
if ($run_mode==0) { $sfx= "T"; }
else { $sfx= ""; }

$noargp=1;             # if 1, do not print arguments to log
$append=0;             # log append flag

# create output directory if needed
foreach my $dir($docdir,$docxdir) {
    if (!-e $dir) {
	my @errs= &makedir($dir,$dirmode,$group);
	print "\n",@errs,"\n\n" if (@errs);
    }
}

if ($log) {
    @start_time= &begin_log($outdir,$filemode,$sfx,$noargp,$append);
    print LOG "IND = $indir\n",
              "OUTF= $outdir/dnref1, fnref1, nulldoc, nulldocx, nonEdoc\n",
              "      $docdir/pml\$n\n\n";
}


#--------------------------------------------------------------------
# 1. Create DNREF file that relates WIDIT doc# with TREC doc# & URL
#     - WIDIT_DOCN TREC_DOCN per line
# 2. Create FNREF file that relates filenames with WIDIT doc#'s
#     -- FileN FilePath first_WIDIT_DOCN last_WIDIT_DOCN
# 3. Create %dnref
#     - key = TREC_DOCN, value = WIDIT_DOCN
#--------------------------------------------------------------------

open(DNREF,">$dnref") || die "can't write to $dnref";
open(FNREF,">$fnref") || die "can't write to $fnref";

my @files= (split/\n/,`ls $indir/permalinks-* | sort`);

my ($docn,$filen,%dnref)=(0,0);

foreach my $file(sort @files) {

    # grep DOCNOs only
    open(IN,"grep '<DOCNO>' $file |") || die "can't read $file";
    my @lines= <IN>;
    close IN;

    my $fdocn= $docn+1;    # first doc# in a file
    $filen++;
    print FNREF "$filen $file $fdocn";

    foreach my $line(@lines) {
	$line=~ m|^<DOCNO>(.+)</DOCNO>|;
	$docn++;
	$dnref{$1}= $docn;
	print DNREF "$docn $1\n";
    }

    print FNREF " $docn\n";

} # end-foreach $file

close DNREF;
close FNREF;


#--------------------------------------------------------------------
# 1. Create %nulldoc0: 404.htm flagged by FEED
# 2. Create %nonEdoc0: nonEdoc flagged by FEED
#--------------------------------------------------------------------

my %nulldoc0;
open(NL,"$nulldoc0") || die "can't read $nulldoc0";
while(<NL>) {
    my($id,$docno)=split/ /;
    $nulldoc0{$docno}=1;
}
close NL;

my %nonEdoc0;
open(NE,"$nonEdoc0") || die "can't read $nonEdoc0";
while(<NE>) {
    my($id,$docno)=split/ /;
    $nonEdoc0{$docno}=1;
}
close NE;


#--------------------------------------------------------------------
#   Create files to be stopped and stemmed.
#     - parse out HTML tags
#     - exclude script and style text
#--------------------------------------------------------------------

my $dcnt=0;  # doc count
my $fcnt=0;  # file count

my %nulldoc=(); # empty documents
my %nulldocx=(); # empty documents
my %nonEdoc=(); # non-English documents
my %longdoc=(); # long documents

foreach my $inf(sort @files) {

    last if (($run_mode==0) && ($fcnt > 2));  #!! for testing

    $inf=~m|$indir/permalinks-(\d+)$|;
    my $outf= "$docdir/pml$1";
    my $outf2= "$docxdir/pml$1";

    # process files
    my $cnt= &index1($inf,$outf,$outf2,\%nulldoc,\%nulldocx,\%nonEdoc,\%dnref,\%nulldoc0,\%nonEdoc0,\%longdoc);
    print LOG "Processed $cnt docs in $inf\n";

    $fcnt++;
    $dcnt += $cnt;

} # end-foreach $file(sort @files)

# output a list of documents w/ empty content
open(OUT,">$nulldoc") || die "can't write to $nulldoc";
my $nullcnt=0;
foreach my $k(sort {$a<=>$b} keys %nulldoc) {
    print OUT "$k $nulldoc{$k}\n";
    $nullcnt++;
}
close OUT;

# output a list of documents w/ empty content
open(OUT,">$nulldocx") || die "can't write to $nulldocx";
my $nullxcnt=0;
foreach my $k(sort {$a<=>$b} keys %nulldocx) {
    print OUT "$k $nulldocx{$k}\n";
    $nullxcnt++;
}
close OUT;

# output a list of non-English documents
open(OUT,">$nonEdoc") || die "can't write to $nonEdoc";
my $nonEcnt=0;
foreach my $k(sort {$a<=>$b} keys %nonEdoc) {
    print OUT "$k $nonEdoc{$k}\n";
    $nonEcnt++;
}
close OUT;

# output a list of very long documents
open(OUT,">$longdoc") || die "can't write to $longdoc";
my $longcnt=0;
foreach my $k(sort {$a<=>$b} keys %longdoc) {
    print OUT "$k $longdoc{$k}\n";
    $longcnt++;
}
close OUT;


#-------------------------------------------------
# end program
#-------------------------------------------------

print LOG "\nProcessed $fcnt files ($dcnt docs: $nullcnt nulldocs, $nonEcnt non-English docs, $nullxcnt nullxdocs, $longcnt longdocs)\n";

# copy subroutines to output directory
my $ec= system "cp $pdir/blogsub.pl $outdir";
if ($ec) { print LOG "!Warning ($ec): cp $pdir/blogsub.pl $outdir\n"; }
else { system "chmod $filemode2 $outdir/blogsub.pl"; }

&end_log($pdir,$outdir,$filemode,@start_time) if ($log);

# notify author of program completion
#&notify($sfx,$author);



##############################################
# SUBROUTINES
##############################################

BEGIN { print STDOUT "\n"; }
END { print STDOUT "\n"; }

#-----------------------------------------------------------
#   process TREC documents
#     1. eliminate tags
#     2. flag null docs (%nulldoc)
#-----------------------------------------------------------
#   arg1 = infile
#   arg2 = outfile w/ noise data
#   arg3 = outfile w/o noise data
#   arg4 = pointer to nulldoc hash
#   arg5 = pointer to nulldocx hash
#   arg6 = pointer to nonEdoc hash
#   arg7 = pointer to dnref hash
#   arg8 = pointer to nulldoc0 hash
#   arg9 = pointer to nonEdoc0 hash
#   arg10 = pointer to longdoc hash
#   r.v. = number of docs
#-----------------------------------------------------------
sub index1 {
    my ($in,$out,$out2,$nlhp,$nxhp,$nehp,$dnlp,$nl0hp,$ne0hp,$llhp)=@_;

    my @times= &start_clock("SUBROUTINE INDEX1 \#$fcnt") if ($log==2);

    my @docs;
    &getdocs($in,\@docs);

    # output file
    open(OUT,">$out") || die "can't write to $out";
    open(OUT2,">$out2") || die "can't write to $out2";
    binmode(OUT,":utf8");
    binmode(OUT2,":utf8");

    my $cnt=0;
    foreach my $doc(@docs) {

        my ($docno,$feedno,$bhpno,$url,$html)=($1,$2,$3,$4,$5)
	    if ($doc=~m|<DOCNO>(.+?)</DOCNO>.+?<FEEDNO>(.+?)</FEEDNO>.+?<BLOGHPNO>(.*?)</BLOGHPNO>.+?<PERMALINK>(.+?)</PERMALINK>.+?</DOCHDR>\n(.+)$|s);

	# exclude extremely long documents (more than 1M characters)
        #  - modified from truncation to exclusion: 5/31/08
        #    -- truncated doc included in docs, but excluded in docx (noiseReduction)

        my ($longdoc,$ltype,$dlen)=(0,0,-1);

        if (length($html)>MAXBYTES) {
            $ltype++;
            if ($html=~/^(.+?<\/html>)/is) {
                $html=$1;
                $ltype++;
            }
            if ($html=~m|^(.+?)<b>Warning</b>:.+?\.php</b> on line <b>\d|s) {
                $html= $1;
                $ltype+=2;
            }
            $html=~s/ +/ /g;
            $dlen=length($html);
            if ($dlen>MAXBYTES) {
                $llhp->{$dnlp->{$docno}}= "$docno $url";
                $longdoc=1;
                #$html= substr($html,0,MAXBYTES)."</body></html>";
            }
            #print LOG "  !Warning: Long Doc! $docno truncated to ", MAXBYTES, " chars (type=$ltype, Tlen=$dlen).\n";
        }

        if (0) {
            print "$cnt=$docno\n";
            open(F,">tmpf") || die "can't write to tmpf";
            print F $html;
        }

        $cnt++;

        #  - modified to exclude longdocs from both docs & docx to speed up indexing, 6/12/08
        if ($longdoc) {
            print LOG "  !Warning: Long Doc! $docno (type=$ltype, Tlen=$dlen) excluded.\n";
            next;
        }

        # parse body text
        my ($title,$body,$body1)=&parse_html2(\$html);

        # flag nonEdocs
        my $flag=&doctype($body1,$title);

        # null content docs
        #  (5/18/07) changed to reflect modified flag values in doctype subroutine
        if (1<=$flag && $flag<=3) { $nlhp->{$dnlp->{$docno}}= "$docno $url"; }

        # non-English docs
        #  (5/18/07) changed to reflect modified flag values in doctype subroutine
        elsif ($flag>=4) { $nehp->{$dnlp->{$docno}}= "$docno $url"; }

	# delete non-English words
        $title=~s/\S+[^\n\x20-\x80]\S*/ /g;
	$body1=~s/\S+[^\n\x20-\x80]\S*/ /g;

	# delete long words
	$body1=~s/\b[^ ]{25,}\b//g;

        print OUT "<doc>\n<docno>$docno</docno>\n<url>$url</url>\n<feedno>$feedno</feedno>\n<bphno>$bhpno</bhpno>\n".
                  "<head>\n<ti>$title</ti>\n</head>\n<body>\n$body1\n</body>\n</doc>\n";

        # parse out blog content
        #  - skip if nulldoc, nonEdoc, or longdoc
        if (!$flag && !($ne0hp->{$docno}) && !($nl0hp->{$docno})) {

	    # eliminate noise text
	    &noiseX3(\$body);

	    # delete tags
	    my $blog=&parse_body2($body); 

	    # delete nonE & long words
	    $blog=~s/\S+[^\n\x20-\x80]\S*/ /g;
	    $blog=~s/\b[^ ]{25,}\b//g;

	    # null content docs after noise reduction
	    if ($blog=~/^\s*$/) { $nxhp->{$dnlp->{$docno}}= "$docno $url"; }
            else {
		print OUT2 "<doc>\n<docno>$docno</docno>\n<url>$url</url>\n<feedno>$feedno</feedno>\n<bphno>$bhpno</bhpno>\n".
  			   "<head>\n<ti>$title</ti>\n</head>\n<body>\n$blog\n</body>\n</doc>\n";
	    }
	}

    }

    close OUT;
    close OUT2;

    return $cnt;

} #endsub index1

