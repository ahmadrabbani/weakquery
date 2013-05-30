###########################################################
# subroutines for web spidering
#   - Kiduk Yang, 4/2008
#----------------------------------------------------------
# Mget:            query a web server
# queryGoogle:     query Google
# queryWikipedia:  query Wikipedia
# fetchHTML:       fetch webpages
###########################################################

use WWW::Mechanize;
use HTML::TreeBuilder;
use HTML::TokeParser;
use HTML::Element;
use URI::URL;
use Encode;

use Sentry;

#-----------------------------------------------------
# query a web server
#-----------------------------------------------------
#  arg1 = URL
#  arg2 = Mechanize object
#-----------------------------------------------------
sub Mget {
    my ($url0,$mech)=@_;

    my $TIMEOUT = 15;

    my $url= URI::URL->new($url0);

    $mech->parse_head(0);
    $mech->add_header(
        "User-Agent" =>
        "Mozilla/5.0 (Macintosh; U; PPC Mac OS X Mach-O; en-US; rv:1.8.0.3) Gecko/20060426 Firefox/1.5.0.3",
        "Accept" =>
        "text/xml,application/xml,application/xhtml+xml,text/html;q=0.9,text/plain;q=0.8,image/png,*/*;q=0.5",
        "Accept-Language" => "en-us,en;q=0.7,bn;q=0.3",
        "Accept-Charset"  => "ISO-8859-1,utf-8;q=0.7,*;q=0.7",
        "Keep-Alive"      => "300",
        "Cache-Control"   => "max-age=0"
    );

    eval {
        local $SIG{ALRM} = sub { die "Alarm\n" };
        alarm($TIMEOUT);
        #$mech->get(encode_utf8($url));
        $mech->get($url);
        alarm(0);

    };
    if ($@) {
        if ($@=~/Alarm/) { print "!Mech->get TimeOut: $@"; }
        else { print "!!Mech->get Exception: $@"; }
        return 0;
    }

    return 1;

} #endsub Mget


#-----------------------------------------------------
# query google
#  - based on /u2/home/glakshmi/google.pl by Lakshminarayanan
#-----------------------------------------------------
#  arg1 = query string
#  arg2 = output directory
#  arg3 = filename suffix (e.g. query number)
#-----------------------------------------------------
#  OUTPUT:
#    $arg2/rs$arg3.htm - result page
#    $arg2/lk$arg3 - hit URLs
#    $arg2/ti$arg3 - hit titles
#    $arg2/sn$arg3 - hit snippets
#-----------------------------------------------------
sub queryGoogle {
    my ($qstr,$outd,$qn)=@_;

    my $outf= "$outd/rs$qn.htm";
    my $linkf= "$outd/lk$qn";
    my $tif= "$outd/ti$qn";
    my $snipf= "$outd/sn$qn";

    my $url= "http://www.google.com/search?hl=en&q=$qstr&btnG=Google+Search&num=100";
    #my $url= "http://www.google.com/search?hl=en&q=$qstr+filetype:htm&btnG=Google+Search&num=100";
    #my $url= "http://www.google.com/search?hl=en&q=$qstr+filetype:html&btnG=Google+Search&num=100";

    my $mech = WWW::Mechanize->new( autocheck => 1 );

    print "Searching Google (q$qn=$qstr)\n";

    # terminate if fetch failure
    return if (!&Mget($url,$mech));

    my $text= decode_utf8($mech->content());

    open (OUT, ">$outf") || die "can't write to $outf";
    print OUT $text;
    close(OUT); 

    my $tree= HTML::TreeBuilder->new;
    $tree->parse_file($outf);

    my $sentry= Sentry->new($tree);

    # extract search result URLs & anchor texts
    my @elements = $tree->look_down(
    '_tag'=>'a',
    'class'=>'l'
    );

    # extract search result snippets
    my @divs = $tree->look_down(
        '_tag' => 'div',
        'class'=> 'std'
    );

    print " -- extracting links\n";
    open(LINKSET, ">$linkf") || die "can't write to $linkf";
    open(TITLESET,">$tif") || die "can't write to $tif";

    foreach my $link(@elements) {
        print LINKSET $link->attr_get_i("href")."\n";
        print TITLESET $link->as_text."\n";
    }
    close(LINKSET);
    close(TITLESET);

    print " -- extracting snippets\n";
    open(SNIPPETSET,">$snipf") || die "can't write to $snipf";

    foreach my $k(@divs) {
        my ($str)= split /<span class/,$k->as_HTML;
        $str=~s/<.+?>//g;
        print SNIPPETSET "$str\n";
    }
    close(SNIPPETSET);

} #endsub queryGoogle


#-----------------------------------------------------
# query google
#  - query until N HTML pages are retrieved
#-----------------------------------------------------
#  arg1 = query string
#  arg2 = output directory
#  arg3 = filename suffix (e.g. query number)
#  arg4 = number of HTML documents to retrieve
#  r.v. = number of HTML documents fetched
#-----------------------------------------------------
#  OUTPUT:
#    $arg2/rs$arg3.htm - result page
#    $arg2/lk$arg3 - hit URLs
#    $arg2/ti$arg3 - hit titles
#    $arg2/sn$arg3 - hit snippets
#-----------------------------------------------------
sub queryGoogle2 {
    my ($qstr,$outd,$qn,$maxdN)=@_;

    print "Searching Google (q$qn=$qstr)\n";

    my $linkf= "$outd/lk$qn";
    my $tif= "$outd/ti$qn";
    my $snipf= "$outd/sn$qn";

    # initialize output files for appending
    foreach my $file($linkf,$tif,$snipf) {
        open(OUT,">$file") || die "can't write to $file";
        close OUT;
    }

    my $scnt=0; # search count
    my $hcnt=0; # HTML count

    while ($hcnt<=$maxdN) { 

        my $mech = WWW::Mechanize->new(autocheck=>1);

        my $start=$scnt*100;  # get next 100 results

        my $url= "http://www.google.com/search?hl=en&q=$qstr&btnG=Google+Search&start=$start&num=100";

        # terminate if fetch failure
        return $hcnt if (!&Mget($url,$mech));

        my $text= decode_utf8($mech->content());

        my $outf= "$outd/rs$qn.htm$scnt";
        open (OUT, ">$outf") || die "can't write to $outf";
        binmode(OUT,":utf8");
        print OUT $text;
        close(OUT); 

        # first result number
        my $fnum=$1 if ($text=~m|Results.+?<b>(\d+)</b>|);

        # not enough results returned
        return $hcnt if ($fnum && $fnum<$start);

        my $tree= HTML::TreeBuilder->new;
        $tree->parse_file($outf);

        my $sentry= Sentry->new($tree);

        # extract search result URLs & anchor texts
        my @elements = $tree->look_down(
        '_tag'=>'a',
        'class'=>'l'
        );

        # extract search result snippets
        my @divs = $tree->look_down(
            '_tag' => 'div',
            'class'=> 'std'
        );

        print " -- extracting links & snippets\n";
        open(LINKSET, ">>$linkf") || die "can't write to $linkf";
        open(TITLESET,">>$tif") || die "can't write to $tif";
        open(SNIPPETSET,">>$snipf") || die "can't write to $snipf";

        for(my $i=0; $i<@elements; $i++) {

            # exclude non-HTML
            my $link=$elements[$i]->attr_get_i("href");
            next if ($link !~ /html?$/i); 

            # extract result number
            my $tmp=$elements[$i]->attr_get_i("onmousedown");
            my $rnum=$1 if $tmp=~/'(\d+)'/;

            # not enough results returned
            return $hcnt if ($rnum && $rnum<$start);

            if ($divs[$i]) {
                my ($str)= split /<span class/,$divs[$i]->as_HTML;
                $str=~s/<.+?>//g;
                print SNIPPETSET "$str\n";
            }
            else {
                print "!!snippet for result $rnum NOT FOUND!!\n";
            }

            print TITLESET $elements[$i]->as_text."\n";
            print LINKSET "$rnum: $link\n";

            $hcnt++;  # increment HTML count
        }

        print "    $hcnt HTMLs found so far\n";
        close(LINKSET);
        close(TITLESET);
        close(SNIPPETSET);

        $scnt++;  

    } #end-while ($hcnt<=$maxdN) 

    return $hcnt;

} #endsub queryGoogle2


#-----------------------------------------------------
# query Wikipedia
#-----------------------------------------------------
#  arg1 = query string
#  arg2 = output directory
#  arg3 = filename suffix (e.g. query number)
#  r.v. = status string 
#          SUCCESS if entry page
#          DISAMBIGUATE if disambiguation page
#          SEARCH if fulltext search page
#          NORESULT if no result is found
#          ERROR if content parse error
#-----------------------------------------------------
#  OUTPUT:
#    $arg2/rs$arg3.htm - result page
#    $arg2/tx$arg3 - main content text (line1= status)
#-----------------------------------------------------
sub queryWikipedia {
    my ($qstr,$outd,$qn)=@_;

    $qstr=~s/^"(.+)"$/$1/;

    my $outf= "$outd/rs$qn.htm";
    my $outf2= "$outd/tx$qn";

    my $url= "http://en.wikipedia.org/wiki/Special:Search?search=$qstr";

    my $mech = WWW::Mechanize->new(autocheck=>1);

    print "Searching Wikipedia (q$qn=$qstr)\n";

    # terminate if fetch failure
    return if (!&Mget($url,$mech)); 

    my $text= decode_utf8($mech->content());

    open (OUT,">$outf") || die "can't write to $outf";
    binmode(OUT,":utf8");
    print OUT $text;
    close(OUT); 

    $text=~s/>/> /g; # compensate of as_text error for list item concatenaton

    my ($title)= split/ -/,&getTitle(\$text);
    print "  - TITLE: $title\n";

    # check "redirected from" message
    if ($text=~m|<div id="contentSub">(.+Redirected.+?)</div>|) {
        my $stream= HTML::TokeParser->new(\$1) || die "TokeParser failure: $1\n";
        my $a=$stream->get_tag('a');
        print "  - REDIRECT: from ", $a->[1]{'href'}, ", ", $stream->get_text(),"\n";
    }

    my $begT='<!-- start content -->';
    my $endT1='<table id="toc" class="toc" summary="Contents">';
    my $endT2='<a name="Notes" id="Notes">';
    my $endT3='<a name="References" id="References">';
    my $endT4='<a name="External_links" id="External_links">';
    my $endT='<!-- end content -->';

    my $begTa='can refer to any of the following:';
    my $endTa='<div class="notice metadata" id="disambig">';
    my $begTb="$qstr.+?may refer to";
    my $endTb='<div class="notice metadata.*?" id="disambig">';
    my $begTa2='can also refer to any of the following:';
    my $endTa2='<div class="notice metadata" id="disambig">';
    my $begTb2="$qstr.+?may also refer to";
    my $endTb2='<div class="notice metadata.*?" id="disambig">';

    my $orphC= 'metadata plainlinks ambox';

    my $body;
    if ($text=~/$begT(.+?)$endT1/is) { $body=$1; }
    elsif ($text=~/$begT(.+?)$endT2/is) { $body=$1; }
    elsif ($text=~/$begT(.+?)$endT3/is) { $body=$1; }
    elsif ($text=~/$begT(.+?)$endT4/is) { $body=$1; }

    # disambiguation page found
    elsif ($text=~/$begTa(.+?)$endTa/is) {
        &getwkBody2($outf2,$title,\$1,"2a");
        print "  - STATUS: Disambiguation Type 1 Page\n";
        return "DISAMBIGUATE1";
    }

    # disambiguation page found
    elsif ($text=~/$begTb(.+?)$endTb/is) {
        &getwkBody2($outf2,$title,\$1,"2b");
        print "  - STATUS: Disambiguation Type 2 Page\n";
        return "DISAMBIGUATE2";
    }

    elsif ($text=~/$begTa2(.+?)$endTa2/is) {
        &getwkBody2($outf2,$title,\$1,"2a");
        print "  - STATUS: Disambiguation Type 1b Page\n";
        return "DISAMBIGUATE1";
    }

    # disambiguation page found
    elsif ($text=~/$begTb2(.+?)$endTb2/is) {
        &getwkBody2($outf2,$title,\$1,"2b");
        print "  - STATUS: Disambiguation Type 2b Page\n";
        return "DISAMBIGUATE2";
    }

    elsif ($text=~m|$begT.+?(There is no page titled.+?$qstr)(.+?)$endT|is) {

        my($nohit,$rest)=($1,$2);

        # full-text search result
        if ($rest=~/Showing below results(.+)$/is) {
            &getwkBody3($outf2,\$1,"3");
            print "  - STATUS: Search Result\n";
            return "SEARCH";
        }

        # no result found
        else {
            print "  - STATUS: $1\n";
            return "NO_RESULT";
        }
    }

    # parse error: main content not found
    else {
        print "  - STATUS: !!!Content not found (parse ERROR)\n";
        return "PARSE ERROR";
    }

    # exclude "Orphaned page" message
    if ($body=~/$orphC/) {
        $body=~s|<table[^>].+$orphC.+?>.+</table>||gs;
    }

    # get content of the entry page
    &getwkBody1($outf2,$title,\$body,"1");

    print "  -  STATUS: Entry Page\n";
    return "SUCCESS";


} #endsub queryWikipedia


#-----------------------------------------------------
# extract title text
#-----------------------------------------------------
#  arg1 = HTML string
#  r.v. = title string
#-----------------------------------------------------
sub getTitle {
    my $text=shift;
    
    my $p= HTML::TokeParser->new($text) || die "TokeParser failure\n";
    
    if ($p->get_tag("title")) {
        return $p->get_trimmed_text;
    }

} #endsub getTitle


#-----------------------------------------------------
# extract main content text
#-----------------------------------------------------
#  arg1 = output file
#  arg2 = HTML title string
#  arg3 = HTML content string
#  arg4 = page type (to print in line1)
#-----------------------------------------------------
sub getwkBody1 {
    my ($outf,$ti,$text,$ptype)=@_;
    
    my $stream= HTML::TokeParser->new($text) || die "TokeParser failure\n";
    
    open(OUT,">$outf") || die "can't write to $outf";
    binmode(OUT,":utf8");
    print OUT "$ptype\n";
    print OUT "$ti\n\n";
    print OUT $stream->get_trimmed_text('External links');
    close OUT;

} #endsub getwkBody1


#-----------------------------------------------------
# extract list of links from wiki disambiguation result
#-----------------------------------------------------
#  arg1 = output file
#  arg2 = HTML title string
#  arg3 = HTML content string
#  arg4 = page type (to print in line1)
#-----------------------------------------------------
sub getwkBody2 {
    my ($outf,$ti,$text,$ptype)=@_;

    my $tree= HTML::TreeBuilder->new();
    $tree->parse_content($text);

    my $sentry= Sentry->new($tree);

    # extract body content
    my @list= $tree->look_down(
        '_tag' => 'li',
    );

    open(OUT,">$outf") || die "can't write to $outf";
    binmode(OUT,":utf8");
    print OUT "$ptype\n";
    print OUT "$ti\n";
    foreach my $li(@list) {
        my $href= $li->look_down('_tag'=>'a');
        if ($href) {
            print OUT "TITLE: ", $href->attr_get_i('title')."\n";
            print OUT "URL: ", $href->attr_get_i('href')."\n";
        }
        print OUT "TEXT: ", $li->as_text."\n\n" if ($li);
    }
    close OUT;

} #endsub getwkBody2


#-----------------------------------------------------
# extract list of links from wiki full-text search result
#-----------------------------------------------------
#  arg1 = output file
#  arg2 = HTML content string
#  arg3 = page type (to print in line1)
#-----------------------------------------------------
sub getwkBody3 {
    my ($outf,$text,$ptype)=@_;
    
    my $tree= HTML::TreeBuilder->new();
    $tree->parse_content($text);
    
    my $sentry= Sentry->new($tree);

    # extract search result
    my $hit= $tree->look_down('_tag'=>'ul', 'class'=>'mw-search-results');
    my @list= $hit->look_down(
        '_tag' => 'li',
    );
    
    open(OUT,">$outf") || die "can't write to $outf";
    binmode(OUT,":utf8");
    print OUT "$ptype\n";
    foreach my $li(@list) {
        my $href= $li->look_down('_tag'=>'a');
        my $snip= $li->look_down('_tag'=>'div', 'class'=>'searchresult');
        print OUT "TITLE: ", $href->attr_get_i('title')."\n";
        print OUT "URL: ", $href->attr_get_i('href')."\n";
        print OUT "TEXT: ", $snip->as_text."\n\n";
    }
    close OUT;

} #endsub getwkBody3



#-----------------------------------------------------
# Fetch webpages
#  - based on /u2/home/glakshmi/google.pl by Lakshminarayanan
#-----------------------------------------------------
#  arg1 = URL to fetch
#  arg2 = fetch number (optional)
#  r.v. = ($html, $title, $body)
#-----------------------------------------------------
sub fetchHTML {
    my ($url,$fn)=@_;

    if ($fn) { print " -- fetch #$fn: $url\n"; }
    else { print " -- fetching $url\n"; }

    my $mech = WWW::Mechanize->new(autocheck=>1, parse_head=>0);

    # terminate if fetch failure
    return if (!&Mget($url,$mech));

    my $htm= $mech->content();
    my $htm2= decode_utf8($htm);

    $htm2=~s/>/> /g; # compensate of as_text error for list item concatenaton

    my $tree = HTML::TreeBuilder->new();
    $tree->parse($htm2);
    
    my $sentry= Sentry->new($tree);

    my $ti= $tree->look_down('_tag'=>'title');
    my $bd= $tree->look_down('_tag'=>'body');

    my ($title,$body);
    $title= $ti->as_text if ($ti);
    $body= $bd->as_text if ($bd);

    return ($htm,$title,$body);
    
} #endsub fetchHTML

1
