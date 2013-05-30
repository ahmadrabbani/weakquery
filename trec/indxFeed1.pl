#!/usr/bin/perl -w

# -----------------------------------------------------------------
# Name:      indxFeed1.pl
# Author:    Kiduk Yang, 4/14/2007
#              modified, 5/28/2008
#             $Id: indxFeed1.pl,v 1.1 2008/05/30 19:19:49 kiyang Exp $
# -----------------------------------------------------------------
# Description: extract permalink info from feeds
#   1. for each feed
#       - extract language
#   2. for each permalink in the feed
#       - title, category, description, content
#   3. flag nonEdocs and nulldocs (404 & empty)
# -----------------------------------------------------------------
# Arguments: arg1 = run mode (0 for test, 1 for real)
# Input:     $rdir/YYYYMMDD/feeds-*  -- Raw feed files
# Output:    $odir/YYYYMMDD/feeds/feedNNN -- feed files
#            $odir/YYYYMMDD/dnref0 -- permalink IDs from feeds
#            $odir/YYYYMMDD/nonEdoc0 -- nonEdoc identified from feeds
#            $odir/YYYYMMDD/nulldoc0 -- 404 nulldoc identified from feeds
#            $odir/YYYYMMDD/nulldocx0 -- nulldoc identified from feeds
#            $odir/$prog         -- program     (optional)
#            $odir/$prog.log     -- program log (optional)
# -----------------------------------------------------------------
# OUTPUT feed file format
#  <feed>
#      <feedID>FEEDNO</feedID>
#      <lang>$language</lang>
#      <blog>
#          <blogID>$trec_docn</blogID>
#          <cat>$categories</cat>
#          <ti>$blog_title</ti>
#          <desc>$blog_description</desc>
#          <cont>$content</cont>
#      </blog>
#  </feed>
# -----------------------------------------------------------------
# NOTE:  
# -----------------------------------------------------------------

use strict;
use Data::Dumper;
$Data::Dumper::Purity=1;

my ($debug,$filemode,$filemode2,$dirmode,$dirmode2,$author,$group);
my ($log,$logd,$sfx,$argp,$append,@start_time);

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
my $tpdir=  "$wpdir/trec07";            # TREC program directory
my $pdir=   "$tpdir/blog";              # track program directory
my $rdir=   "/u2/trec/blog06";          # raw data directory
my $odir=   "/u3/trec/blog08";          # index directory

require "$wpdir/logsub2.pl";   # subroutine library

use HTML::Entities;

my %pmlTags= (
'title'=>'ti',
'description'=>'desc',
'content'=>'cont',
'summary'=>'cont',
'category'=>'cat',
);


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

my $testflag=1 if ($run_mode==0);


#-------------------------------------------------
# start program log
#-------------------------------------------------

$sfx= "";              # program log file suffix
$argp=1;               # if 1, do not print arguments to log
$append=0;             # log append flag

if ($log) {
    @start_time= &begin_log($odir,$filemode,$sfx,$argp,$append);
    print LOG "Inf=  $rdir/yyyymmdd/feeds-nnn\n",
              "Outf= $odir/yyyymmdd/feeds/feedNNN\n",
              "Outf= $odir/yyyymmdd/dnref0, nonEdoc0, nulldoc0, nulldocx0\n\n";
}


#--------------------------------------------------------------------
# process each blog subdirctory
#--------------------------------------------------------------------

opendir(DIR,"$rdir") || die "can't opendir $rdir";        
my @dirs = readdir(DIR);                                     
closedir(DIR);                                             

my $fcnt=0;    # file count
my $NEcnt=0;    
my $nullcnt=0; 
my $nullxcnt=0; 
my $blogcnt=0;

# for each date subdirectory
foreach my $yymmdd(@dirs) {    

    next if ($yymmdd !~ /^\d{8}$/);

    my $pmlcnt=0;
    my (%dnref,%nonEdoc,%nulldoc,%nulldocx);

    my $ind= "$rdir/$yymmdd";   
    my $outd= "$odir/$yymmdd";   
    my $outd2= "$odir/$yymmdd/feeds";   

    # create output directory if needed
    &makedir($outd2,$dirmode,$group) if (!-e $outd2);

    my @files= (split/\n/,`ls $ind/feeds-*`);

    # for each feed file
    foreach my $file(@files) {

	last if ($testflag && $fcnt>1);

        $file=~/feeds-(\d+)/;
        my $fileID= "$yymmdd-f$1";
        my $outf= "$outd2/feed$1";

        open(OUT,">$outf") || die "can't write to $outf";

        my @lines;
        &readfile($file,\@lines,$log);
        chomp @lines;

	my $str=join(" ",@lines);
        $str=~s/\s+/ /g;

	my $begtag="<DOC>";
	my $endtag="</DOC>";

	my @docs= $str=~m|$begtag(.+?)$endtag|gi;
	
        foreach my $doc(@docs) {
            
            $doc=~m|<FEEDNO>(.+?)</FEEDNO>.+?<PERMALINKS>(.+?)</PERMALINKS>(.+?)</DOCHDR>(.+)$|i;
            my($feedno,$pml,$dochdr,$xml)=($1,$2,$3,$4);

            # extract language values
            my ($nonEdoc,@lang);
            push(@lang,$1) if ($dochdr=~/content-language: *([^ ]+)/i);
            push(@lang,$1) if ($xml=~m|<[^<>]language>(.+?)</[^<>]language>|i);
            if (@lang) {
                $nonEdoc=1;
                foreach my $lang(@lang) {
                    $nonEdoc=0 if ($lang=~/en/i);
                }
            }

            # %url2pml: k=URL, v=blogID
            my (%url2pml,%pml2url);

            # skip if permalinks info is missing
            if ($pml !~ /BLOG06-200/) {
                next;
            }
            else {
                while ($pml=~/(http.+?) (BLOG[\w\-]+)/g) {
                    my ($url,$id)=($1,$2);
                    $pml2url{$id}="$url";
                    $pmlcnt++;
                    $dnref{$id}="$pmlcnt $id";
                    # nonEdoc
                    if ($nonEdoc) {
                        $nonEdoc{$id}="$pmlcnt $id $url";
                        next;
                    }
                    # page not found
                    elsif ($url=~/\/404.htm/i) {
                        $nulldoc{$id}="$pmlcnt $id $url";
                        next;
                    }
                    my $url2=&urlNorm($url);
                    $url2pml{"\L$url2"}="$id";
                }
            }

            next if ($nonEdoc);

            print OUT "<feed>\n<feedID>$feedno</feedID>\n";
            print OUT "<lang>", join(" ",@lang), "</lang>\n" if (@lang);

            # extract permalink title, description, content, & categories
            my @items;
            if ($xml=~/<item/i) { @items= $xml=~m|<item[^>]*?>(.+?)</item>|ig; }
            elsif ($xml=~/<entry/i) { @items= $xml=~m|<entry[^>]*?>(.+?)</entry>|ig; }
            else {
                next;
            }

            # key=blogID, val= hashP
            #    k=field_name (ti,desc,cont,cat)
            #    v=field_value
            my %pmldata;

            foreach my $item(@items) {
                &get_pmldata($item,\%pmlTags,\%pmldata,\%url2pml);
            }

            # print out blog data
            foreach my $blogID(sort keys %pmldata) {
                if (!$pmldata{$blogID}{'desc'} && !$pmldata{$blogID}{'cont'}) {
                    $nulldocx{$blogID}="$pmlcnt $blogID $pml2url{$blogID}";
                    next;
                }
                print OUT "<blog>\n<blogID>$blogID</blogID>\n";
                my $hp= $pmldata{$blogID};
                foreach my $name('cat','ti','desc','cont') {
                    print OUT "<$name>",$hp->{"$name"},"</$name>\n" if (defined $hp->{"$name"});
                }
                print OUT "</blog>\n";
            }
            print OUT "</feed>\n";

        } #end-foreach $doc
    
	$fcnt++;

        close OUT;

    } #end-foreach $file

    my $outf= "$outd/dnref0";
    my $outf1= "$outd/nonEdoc0";
    my $outf2= "$outd/nulldoc0";
    my $outf3= "$outd/nulldocx0";
    my $cnt= &printHashVal($outf,\%dnref);
    my $cnt1= &printHashVal($outf1,\%nonEdoc);
    my $cnt2= &printHashVal($outf2,\%nulldoc);
    my $cnt3= &printHashVal($outf3,\%nulldocx);

    $blogcnt += $cnt;
    $NEcnt += $cnt1;
    $nullcnt += $cnt2;
    $nullxcnt += $cnt3;

} #endforeach $yymmdd


print LOG "\nprocessed $fcnt feed files.\n";
print LOG "$blogcnt blogs, $NEcnt nEdocs, $nullcnt nulldocs, $nullxcnt nullxdocs\n";


#-------------------------------------------------
# end program
#-------------------------------------------------
    
&end_log($pdir,$odir,$filemode,@start_time) if ($log);

# notify author of program completion
&notify($sfx,$author);



##############################################
# SUBROUTINES
##############################################

BEGIN { print STDOUT "\n--- $0 Start ---\n\n"; }
END { print STDOUT "\n--- $0 End ---\n\n"; }
        
#--------------------------------------------
# extract data from xml text
#--------------------------------------------
#   arg1 = text
#   arg2 = pointer to tag hash
#            k=tagName, v=tagKey for arg3
#   arg3 = pointer to data hash
#            k=blogID, v=pointer to hash
#              k=tagKey, v=tagVal
#   arg4 = pointer to ID hash
#            k=blogURL, v=blogID
#   arg5 = current file reference
#--------------------------------------------
sub get_pmldata {
    my($text,$taghp,$datahp,$urlhp)=@_;

    my (@urls,@url); 
    push(@urls,@url) if (@url= $text=~m|<guid>.*?(http.+?)[\]>]*?</guid>|ig);
    push(@urls,@url) if (@url= $text=~m|<link>.*?(http.+?)[\]>]*?</link>|ig);
    push(@urls,@url) if (@url= $text=~m|<link[^>]+?href="(http.+?)"|ig);
    if (@urls) {
        my ($id,$url);
        foreach (@urls) {
            $url=&urlNorm($_);
            last if ($id=$urlhp->{"\L$url"});
        } 
        if ($id) {
            ## extract data
            foreach my $tag(keys %$taghp) {
                my @data= $text=~m|<$tag[^>]*>(.+?)</$tag[^>]*>|gi;
                my $data= join(" ",@data);
                $data=~s/<!\[CDATA//ig;
                $data=~s/<.+?>//sg;
                $datahp->{$id}{$$taghp{$tag}}= $data;
            }
        }
    }

}


#--------------------------------------------
# HTML & URL decode string
#--------------------------------------------
#   arg1 = URL
#   r.v. = decoded URL
#--------------------------------------------
sub urlNorm {
    my $url=shift;

    $url=~s|(html?)\?.+$|$1|i;
    $url=~s|\s+$||;
    
    #HTML decode
    $url= decode_entities($url);
    
    #URL decode
    $url=~ s/%3E//gi;
    $url=~ s/\%([A-Fa-f0-9]{2})/pack('C', hex($1))/seg;
    
    $url=~s|#[^/]*$||;  # delete inpage ref.
    
    $url=~ s|index.php\?\w+=||i;
    $url=~ s|^http.+(http://.+)$|$1|i;
    #$url=~ s|:80/|/|;
    #$url=~ s|http://www.|http://|i;
    $url=~ s|/$||;

    $url=~s|(\d+)/|$1|g;
    $url=~s|\.\w+$||;
    my $file=$1 if ($url=~m|/([^/]+$)|);
    if ($url=~/livejournal/i) {
        $url=~s|^.+?/([^/]+)$|$1|;
    }
    elsif ($url=~/bizjournals.com/i) {
        $url=~s|^.+bizjournals.com(/.+)$|$1|i;
    }
    elsif ($url=~m|(\d{4,})$|) {
        $url=$1;
    }
    elsif ($url=~m|/[^/]*?(\?[^/]+$)|) {
        $url=$1;
        if (length($url)>20) {
            $url=~s/\w+=//g;
        }
    }
    elsif (defined($file) && length($file)>15) {
        $url=$file;
    }
    else {
        my @scnt= ($url=~m|[^/]/[^/]|g);
        if (@scnt>5) {
            $url=~s|^.+?(/[^/]+/[^/]+/[^/]+/[^/]+/[^/]+)$|$1|;
        }
        else {
            $url=~s|^http://[^/]+(/.+)$|$1|i;
        }
        $url=~s|\w+\.\w+\?|?|;
    }
    $url=substr($url,0,50) if (length($url)>50);

    return $url;
}

