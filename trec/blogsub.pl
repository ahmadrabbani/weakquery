#-----------------------------------------------------------
# parse_html:   extract title & body text from HTML
# parse_html2:  extract title & body text from HTML
# parse_body:   delete tags, long & nonE words from body text
# parse_body2:  delete tags, long & nonE words from body text
# doctype:      flag empty & non-English documents
# parse_blog2:  extract blog content while excluding noise
# parse_blog3:  extract blog posting & comment while excluding noise
# noiseX2:      delete noise text in a blog
# noiseX3:      delete noise text in a blog
# getdoc:       extract a blog document from a blog file into a string
# getdocs:      extract blog documents from a blog file into an array
# getblog0:     get url, title, and body of blogs from permalink files
# getblog1:     get posting/comment of blogs from permalink files
# getblog:      get blog title and body of blogs from pml files
# getblogs:     return array of blogs from a pml file
# mkHFhash:     make HF hash from HF lex file
# mkIUhash:     make IU hash from IU lex file
# mkLFhash1:    make LF hash from LF regex file
# mkLFhash2:    make LF hash from LF lex file
# mkAChash:     make acronym hash from AC lex file
# preptext0:    proprocess blog text (negation, repeat-char)
# preptext:     proprocess blog text (query match, negation, repeat-char)
# polSC:        compute opinion polarity score
# updatelex:    add repeat-char compressed words to lexicon hash
# swinprox:     match all query words in sliding window (from rerankrt13.pl)
# calrrSC:      compute rerank scores
# calrrSCall:   compute rerank scores for all queries
# caltpSCall:   compute topic scores for all queries
# calopSCall:   compute opinion scores for all queries
# calrrSCall2:  compute rerank scores for all queries (addes idist measure, 4/08)
# caltpSCall2:  compute topic scores for all queries
# calopSCall2:  compute opinion scores for all queries
# calopSC:      compute opinion scores (new implementation)
# calopSC2:     compute opinion scores (modified calrrsc of rerankrt13.pl): Do not use (CPU hog)
# opSC:         compute opinion scores by lexicon (used by calopSC2)
# opSC2:        compute opinion scores by regex (used by calopSC2)
# opSC3:        compute opinion scores by word pair (IU phrase) (used by calopSC2)
# PHsc:         compute phrase opinion score
# HFsc:         compute HF opinion score
# IUsc:         compute IU opinion score
# LFsc:         compute LF opinion score
# HFsc2:        compute HF opinion score (used by calopSC)
# IUsc2:        compute IU opinion score (used by calopSC)
# LFsc2:        compute LF opinion score (used by calopSC)
# HFsc3:        compute HF opinion score for all queries (used by calopSCall)
# IUsc3:        compute IU opinion score for all queries (used by calopSCall)
# LFsc3:        compute LF opinion score for all queries (used by calopSCall)
# wekaDsc:      compute weka opinion score
# build_ad_v:   build the ad_v module
#-----------------------------------------------------------

use HTML::TokeParser;
use HTML::TreeBuilder;
use HTML::Entities qw(decode_entities);
use Encode;

use strict;

use Sentry;

no warnings 'recursion';


#-----------------------------------------------------------
#   parse html
#     1. extract title
#     2. delete script & style text
#-----------------------------------------------------------
#   arg1 = pointer to html string
#   r.v. = (title, body text)
#-----------------------------------------------------------
sub parse_html {
    my ($sptr)=@_;
    my ($title,$body);

    # extract title
    if ($$sptr=~m|<title.*?>(.+?)</title>|is) {
        $title=$1;
	$title=~s/&[a-zA-Z0-9#]{1,5};/ /g;
        # compress white space
        $title=~s/\s+/ /gs;
    }
    else { $title=""; }

    # body text
    if ($$sptr=~m|<body.*?>(.+?)$|is) {
        $body=$1;
    }
    elsif ($$sptr=~m|</head>(.+?)$|is) {
        $body=$1;
    }
    else {
        $body=$$sptr;
    }

    # eliminate script & style texts
    $body=~s!<(script|style).*?>.*?</\1>!!gis;

    # handle special characters.
    $body=~s/&[a-zA-Z0-9#]{1,5};/ /g;

    # remove tags from title
    $title=~s/<.+?>//g;

    return ($title,$body);

} #endsub parse_html


#-----------------------------------------------------------
# parse html text
#   1. extract title
#   2. delete script & style text
# Note: modified parse_html, 5/30/08
#-----------------------------------------------------------
#   arg1 = pointer to html string
#   r.v. = (title, body text as HTML, body text)
#-----------------------------------------------------------
sub parse_html2 {
    my ($sptr)=@_;
    my ($p,$title,$body,$body1);

    my $tree= HTML::TreeBuilder->new();
    $tree->ignore_ignorable_whitespace(0);
    $$sptr=decode_utf8($$sptr) if (!utf8::decode($$sptr)); 
    $tree->parse_content($$sptr);

    my $sentry= Sentry->new($tree);

    # extract title
    if ($p=$tree->find_by_tag_name('title')) {
        $title= $p->as_text();
        # remove tags from title
        $title=~s/<.+?>/ /gs;
    }   
    elsif ($$sptr=~m|<title.*?>(.+?)</title>|is) {
        $title=$1;
        # remove tags from title
        $title=~s/<.+?>/ /g;
        # handle special characters.
	decode_entities($title);
    }   
    else { $title=""; }

    # body text
    if ($p=$tree->find_by_tag_name('body')) {
        $body= $p->as_HTML();
        $body1= $p->as_text();
    }   
    else {
        if ($$sptr=~m|(<body.*?>.+?)$|is) {
            $body=$1;
        }
        elsif ($$sptr=~m|</head>(.+?)$|is) {
            $body="<body>$1";
        }
        else {
            $body=$$sptr;
        }
        # eliminate script & style texts
        $body=~s!<(script|style).*?>.*?</\1>!!gis;
        # handle special characters.
        $body=~s/&lt;|&gt;/ /gi;
        decode_entities($body);
        $body1= &parse_body2($body);
    }   

    #$tree->delete;

    foreach ($title,$body,$body1) {
        # compress white space
        #  - newlines get deleted
        s/[\|\s]+/ /gs;
        # delete leading & trailing blanks
        s/^\s*(.+?)\s*$/$1/s;
    }

    return ($title,$body,$body1);

} #endsub parse_html2


#-----------------------------------------------------------
# parse body text
#  1. delete tags from body text
#  2. delete long words
#  3. delete words w/ non-English characters
#  (05/18/2007): tag elimination bug fixed
#-----------------------------------------------------------
#  arg1 = body text
#  r.v. = parsed body text
#-----------------------------------------------------------
sub parse_body {
    my ($body)=@_;

    my $debug=0;

    # eliminate comment tags
    if ($debug) {
        my @tmp= $body=~m|(<!--.+?-->)|gs;
        print join("\n\n\n",@tmp),"\n\n\n";
    }
    $body=~s|<!--.+?-->| |gs; 

    # eliminate HTML tags
    if ($debug) {
        my @tmp2= $body=~m|<.+?>|gs;
        print "!!-----------!!\n";
        print join("\n\n\n",@tmp2),"\n\n\n";
    }
    $body=~s|<.+?>| |gs;

    # compress white space
    #  - newlines get deleted
    $body=~s/[\|\s]+/ /gs;

    # delete leading & trailing blanks
    $body=~s/^\s*(.+?)\s*$/$1/s;

    return $body;

} #endsub parse_body


#-----------------------------------------------------------
# parse body text
#  1. delete tags from body text
#  2. delete long words
#  3. delete words w/ non-English characters
# Note: modified parse_body, 5/30/08
#-----------------------------------------------------------
#  arg1 = body text
#  r.v. = parsed body text
#-----------------------------------------------------------
sub parse_body2 {
    my ($body)=@_;

    my $debug=0;

    my $tree= HTML::TreeBuilder->new();
    $tree->ignore_ignorable_whitespace(0);
    utf8::decode($body) if (utf8::is_utf8($body));
    #$body=decode_utf8($body);
    $tree->parse_content($body);

    my $sentry= Sentry->new($tree);

    if (my $p= $tree->find_by_tag_name('body')) {
        $body= $p->as_text();
    }

    else {
        # eliminate comment tags
        if ($debug) {
            my @tmp= $body=~m|(<!--.+?-->)|gs;
            print join("\n\n\n",@tmp),"\n\n\n";
        }
        $body=~s|<!--.+?-->| |gs; 

        # eliminate HTML tags
        if ($debug) {
            my @tmp2= $body=~m|<.+?>|gs;
            print "!!-----------!!\n";
            print join("\n\n\n",@tmp2),"\n\n\n";
        }
        $body=~s|<.+?>| |gs;
    }

    #$tree->delete;

    # compress white space
    #  - newlines get deleted
    $body=~s/[\|\s]+/ /gs;

    # delete leading & trailing blanks
    $body=~s/^\s*(.+?)\s*$/$1/s;

    return $body;

} #endsub parse_body2


#-----------------------------------------------------------
# flag empty & non-English documents
#  - 5/18/2007: flag values changed to finer granulaty
#       1 = empty doc
#       2 = 404 not found doc
#       3 = one or less word after deleting numeric & nonE tokens
#       4+ = nonEdoc
#-----------------------------------------------------------
#   arg1 = body text
#   r.v. = flag (1=nulldoc, 2=nonEdoc)
#-----------------------------------------------------------
sub doctype {
    my ($body,$title)=@_;
    my $debug=0;

    #--------------------------------------
    # flag null content docs
    #   - (5/18/2007) 404 doc flag added
    #--------------------------------------
    if ($body=~/^\s*$/) { return 1; }
    elsif ($title=~/(404|object|document|page).+?not found/i) { return 2; }
    elsif ($body!~/\s/) { return 3; }  # single word doc


    #--------------------------------------
    # flag non-English docs
    #--------------------------------------

    # delete numbers
    print "DOCTYPE: delete numbers\n" if ($debug);
    $body=~s/\s\d+\s/ /g;

    # flag nonEword in body
    print "DOCTYPE: flag nonEword\n" if ($debug);
    my @hits;
    while($body=~/(\S+[^\n\x20-\x80]\S*)/g) {
        my $hit=$1;
	if ($hit!~/[^\n\x20-\x80]s$/i) {
	    push(@hits,$hit);
	}
    }
    print "DOCTYPE: nonEword flagged\n" if ($debug);

    # nonEdoc if nonEword in body
    #  - 50% threshold
    #  w/ nonE-stopword OR
    #  w/ less than 10 E-stopwords
    if (@hits) {

        print "DOCTYPE: get wordcnt\n" if ($debug);
        my @wds= $body=~/\s+/g;

        if ($debug) {
            my $hitN=@hits;  my $wdN=@wds;
            print "DOCTYPE: hitN=$hitN, wdN=$wdN\n";
        }

        if ((@hits/@wds)>0.5) { 
            print "DOCTYPE: nonE over 50%\n" if ($debug);
            # anomaly?
            # 1. non-English doc w/ many stopwords: BLOG06-20051206-000-0000340444
            #   - override by nonE stopwords
            # 2. English doc w/ non-E chars: BLOG06-20051206-000-0000827380, BLOG06-20051206-000-0001020440
            #   - override by high stopwd freq
            if ($body=~/\b(een|heeft|hij|ik|je|niet|zei|zij)\b/i) {
                return 4;
            }
            else {
                my @stops= ($body=~/\b(although|always|and|are|aren't|because|but|from|his|how|however|isn't|less|my|never|none|not|often|or|our|she|that|the|their|they|this|though|to|too|wasn't|we|were|weren't|what|when|where|who|why|with|within|without|you|your)\b/ig);
                if (@stops<=10) { return 5; }
            }
        }

        # when less than 50% nonEword, count E-stopwords
        else {

            print "DOCTYPE: nonE under 50%\n" if ($debug);
            my @stops= ($body=~/\b(although|always|and|are|aren't|because|but|from|his|how|however|isn't|less|my|never|none|not|often|or|our|she|that|the|their|they|this|though|to|too|wasn't|we|were|weren't|what|when|where|who|why|with|within|without|you|your)\b/ig);

            # nonEdoc if no E-stopword found
            if (!@stops) { return 6; }

            # nonEdoc if under 10 E-stopwords and 2% of text
            elsif (@stops<=10 && (@stops/@wds)<0.02) { return 7; }

            # nonEdoc if under 20 E-stopwords and 1% of text in a long doc
            elsif (@stops<=20 && @wds>1000 && (@stops/@wds)<0.01) { return 8; }

        }

    } #endif (@hits)

    return 0;

} # endsub doctype


#-----------------------------------------------------------
# parse out blog content
#  1. identify blog segment
#     a. look for post & comment tags
#     b. if no post/comment tag, look for content tag
#     c. if none, use the entire body text
#  2. exclude noise text
#     - e.g. sidebar, navigation, profile, etc.
# NOTE: updated, 5/30/08 (old version renamed as parse_blog2old)
#-----------------------------------------------------------
#  arg1 = pointer to body text
#-----------------------------------------------------------
sub parse_blog2 {
    my $sptr=shift;

    my $debug=0;

    #--------------------------------------------------
    # extract blog using start/end post & comment tags
    #--------------------------------------------------
    my @blog;
    while ( $$sptr=~/<!-- *(beginn?|start) +[^>]?(post|comment|blog|content)[^>]{0,3}-->(.+?)<!-- *end +.?\2[^>]*?-->/isg ) {
        my($tag,$type,$instr,$before,$after,$matched)=($1,$2,$3,$`,$',$&);
        # exclude poster tags
        if ($matched !~ /^<!-- *(beginn?|start) +.?poster/is) {
            push(@blog,$instr);
            print "PARSE_BLOG 1: TAG=$tag type=$type\n!!SAVED=$instr\n\n" if ($debug);
            $$sptr= "$before $after";
        }
    }

    #--------------------------------------------------
    # extract blog using embedded (e.g. div) post & comment tags
    #--------------------------------------------------
    while ($$sptr=~m!<(div|p|span|table|td|th)[^>]+?(post|comment|blog|content|title|body)[^>]*>!is) {
        my($tagN,$tag,$type,$before,$after)=(1,$1,$2,$`,$');
	print "PARSE_BLOG 2a: TAG=$tag type=$type\n" if ($debug);
	print "!!AFTER=$after\n\n" if ($debug>1);

        while ($after=~m!(</?$tag[^>]*>)!is) {
            my($tag2,$before2,$after2)=($1,$`,$');
            push(@blog,$before2);
            $after=$after2;
            if ($tag2=~m!<$tag!i) {
                $tagN++;
            }
            else {
                $tagN--;
            }
            print "PARSE_BLOG 2b: TAG2= $tag2, $tagN\n!!SAVED=$before2\n\n" if ($debug);
            last if (!$tagN);
        }

        print "PARSE_BLOG 2c: ST1=$$sptr\n" if ($debug>1);
        $$sptr= "$before $after";
        print "PARSE_BLOG 2d: ST2=$$sptr\n\n" if ($debug>1);

    }

    my $blog;
    if (@blog) {
        $blog= join(" ",@blog);
        print "PARSE_BLOG 3: SAVED_ALL=$blog\n\n" if ($debug);
    }

    # exclude form, sidebar, navigations, ads, etc.
    print "PARSE_BLOG 4a: Before NoiseX\n$$sptr\n\n" if ($debug);
    &noiseX2($sptr);
    print "PARSE_BLOG 4b: After NoiseX\n$$sptr\n\n" if ($debug);

    $$sptr= "$blog $$sptr" if ($blog);

} #endsub parse_blog2


#-----------------------------------------------------------
# parse out blog content
#  1. identify blog segment
#     a. look for post & comment tags
#  2. exclude embedded noise text
#     - e.g. sidebar, navigation, profile, etc.
#-----------------------------------------------------------
#  arg1 = pointer to body text
#-----------------------------------------------------------
sub parse_blog3 {
    my $sptr=shift;

    my $debug=0;

    #--------------------------------------------------
    # extract blog using start/end post & comment tags
    #--------------------------------------------------
    my @blog;
    while ( $$sptr=~/<!-- *(beginn?|start) +[^>]?(post|comment|blog|content)[^>]{0,3}-->(.+?)<!-- *end +.?\2[^>]*?-->/isg ) {
        my($tag,$type,$instr,$before,$after,$matched)=($1,$2,$3,$`,$',$&);
        # exclude poster tags
        if ($matched !~ /^<!-- *(beginn?|start) +.?poster/is) {
            push(@blog,$instr);
            print "PARSE_BLOG 1: TAG=$tag type=$type\n!!SAVED=$instr\n\n" if ($debug);
            $$sptr= "$before $after";
        }
    }

    #--------------------------------------------------
    # extract blog using embedded (e.g. div) post & comment tags
    #--------------------------------------------------
    while ($$sptr=~m!<(div|p|span|table|td|th)[^>]+?(post|comment|blog|content|title|body)[^>]*>!is) {
        my($tagN,$tag,$type,$before,$after)=(1,$1,$2,$`,$');
	print "PARSE_BLOG 2a: TAG=$tag type=$type\n" if ($debug);
	print "!!AFTER=$after\n\n" if ($debug>1);

        while ($after=~m!(</?$tag[^>]*>)!is) {
            my($tag2,$before2,$after2)=($1,$`,$');
            push(@blog,$before2);
            $after=$after2;
            if ($tag2=~m!<$tag!i) {
                $tagN++;
            }
            else {
                $tagN--;
            }
            print "PARSE_BLOG 2b: TAG2= $tag2, $tagN\n!!SAVED=$before2\n\n" if ($debug);
            last if (!$tagN);
        }

        print "PARSE_BLOG 2c: ST1=$$sptr\n" if ($debug>1);
        $$sptr= "$before $after";
        print "PARSE_BLOG 2d: ST2=$$sptr\n\n" if ($debug>1);

    }

    my $blog;
    if (@blog) {
        $blog= join(" ",@blog);
        print "PARSE_BLOG 3: SAVED_ALL=$blog\n\n" if ($debug);
        # exclude form, sidebar, navigations, ads, etc.
        print "PARSE_BLOG 4a: Before NoiseX\n$blog\n\n" if ($debug);
        &noiseX2(\$blog);
        print "PARSE_BLOG 4b: After NoiseX\n$blog\n\n" if ($debug);
    }

    $$sptr= $blog;

} #endsub parse_blog3


#---------------------------------------
# delete noise text
#  - form content, sidebar, footer, etc.
#---------------------------------------
#  arg1= pointer to string
#---------------------------------------
sub noiseX2 {
    my $sptr=shift;
    my $debug=0;

    # delete form content
    while ($$sptr=~m|<form.+?>.+?</form>|isg) {
        my ($matched,$before,$after)=($&,$`,$');
        if ($matched =~ /type="?submit"?/is) {
            $$sptr= "$before $after";
            print "NOISEX 1: FORM\n!!DELETED=$matched\n\n" if ($debug);
        }
    }

    # delete sidebar, footer, etc. w/ begin & end comment tags
    while ($$sptr=~/<!-- *(beginn?|start)[^>]+?(footer|profile|shoutbox|side|nav|archive|copyright|advertise|sponsor)[^>]*?-->.+?<!-- *end[^>}*?\2[^>]*?-->/is) {
        my ($tag,$name,$matched,$before,$after)=($1,$2,$&,$`,$');
        $$sptr= "$before $after";
        print "NOISEX 2: TAG=$tag, $name\nDELETED=$matched\n\n" if ($debug);
    }

    # delete embedded sidebar, footer, etc.
    while ($$sptr=~m!<(div|p|span|table|td|th|ul|ol)[^>]+?="?(footer|profile|shoutbox|side|nav|archive|copyright|advertise|sponsor)[^>]*>!is) {
        my($tagN,$tag,$type,$before,$after)=(1,$1,$2,$`,$');
        print "NOISEX 3a: TAG=$tag type=$type\n" if ($debug);
        print "!!AFTER=\n$after\n\n" if ($debug>1);
        
        while ($after=~m!(</?$tag[^>]*>)!is) {
            my($tag2,$before2,$after2)=($1,$`,$');
            $after=$after2;
            if ($tag2=~m!<$tag!i) {
                $tagN++;
            }
            else {
                $tagN--;
            }
            print "NOISEX 3b: TAG2=$tag2, $tagN\n!!DELETED=\n$before2 $tag2\n\n" if ($debug);
            last if (!$tagN);
        }
        
        print "NOISEX 3c: ST1=\n$$sptr\n" if ($debug);
        $$sptr= "$before $after";
        print "NOISEX 3d: ST2=\n$$sptr\n\n" if ($debug);
    
    }

} #ensub noiseX2


#---------------------------------------
# delete noise text
#  - form content, sidebar, footer, etc.
# Note: updated version of noiseX2, 5/30/08
#---------------------------------------
#  arg1= pointer to string
#---------------------------------------
sub noiseX3 {
    my $sptr=shift;
    my $debug=0;

    no warnings "recursion";

    my $tree= HTML::TreeBuilder->new();
    $tree->ignore_ignorable_whitespace(0);
    $$sptr=decode_utf8($$sptr) if (!utf8::decode($$sptr)); 
    $tree->parse_content($$sptr);

    my $sentry= Sentry->new($tree);

    foreach my $d($tree->look_down(
      sub {
          # delete form content
          return 1 if ($_[0]->tag eq 'form');
          return 1 if ($_[0]->tag eq 'script');
          # delete sidebar
          return 1 if ($_[0]->attr('class') && $_[0]->attr('class')=~/menu|footer|profile|shoutbox|side|nav|archive|copyright|advertise|sponsor/i);
          return 1 if ($_[0]->attr('id') && $_[0]->attr('id')=~/menu|footer|profile|shoutbox|side|nav|archive|copyright|advertise|sponsor/i);
          return 0;
      }
    )) {
        $d->delete;
    }

    $$sptr= $tree->as_HTML();
    #$tree->delete;

    # delete form content
    while ($$sptr=~m|<form.+?>.+?</form>|isg) {
        my ($matched,$before,$after)=($&,$`,$');
        if ($matched =~ /type="?submit"?/is) {
            $$sptr= "$before $after";
            print "NOISEX 1: FORM\n!!DELETED=$matched\n\n" if ($debug);
        }
    }

    # delete sidebar, footer, etc. w/ begin & end comment tags
    while ($$sptr=~/<!-- *(beginn?|start)[^>]+?(footer|profile|shoutbox|side|nav|archive|copyright|advertise|sponsor)[^>]*?-->.+?<!-- *end[^>}*?\2[^>]*?-->/is) {
        my ($tag,$name,$matched,$before,$after)=($1,$2,$&,$`,$');
        $$sptr= "$before $after";
        print "NOISEX 2: TAG=$tag, $name\nDELETED=$matched\n\n" if ($debug);
    }

    # delete embedded sidebar, footer, etc.
    while ($$sptr=~m!<(div|p|span|table|td|th|ul|ol)[^>]+?="?(footer|profile|shoutbox|side|nav|archive|copyright|advertise|sponsor)[^>]*>!is) {
        my($tagN,$tag,$type,$before,$after)=(1,$1,$2,$`,$');
        print "NOISEX 3a: TAG=$tag type=$type\n" if ($debug);
        print "!!AFTER=\n$after\n\n" if ($debug>1);
        
        while ($after=~m!(</?$tag[^>]*>)!is) {
            my($tag2,$before2,$after2)=($1,$`,$');
            $after=$after2;
            if ($tag2=~m!<$tag!i) {
                $tagN++;
            }
            else {
                $tagN--;
            }
            print "NOISEX 3b: TAG2=$tag2, $tagN\n!!DELETED=\n$before2 $tag2\n\n" if ($debug);
            last if (!$tagN);
        }
        
        print "NOISEX 3c: ST1=\n$$sptr\n" if ($debug);
        $$sptr= "$before $after";
        print "NOISEX 3d: ST2=\n$$sptr\n\n" if ($debug);
    
    }

} #ensub noiseX3


#-----------------------------------------------------------
# return a blog from input file
#   - for extremely long input file, process line by line
#-----------------------------------------------------------
#   arg1 = input file
#   arg2 = blogID
#   r.v. = blog content string
#-----------------------------------------------------------
sub getdoc {
    my($in,$docID)=@_;

    my (@lines,@docs);
   
    my ($lcnt)= split(/ /,`wc -l $in`);

    if ($lcnt<10**6) {
        open(IN,$in) || die "can't read $in";
        @lines=<IN>;
        close IN;
        @docs= split(/<\/DOC>/,join(" ",@lines));
        delete($docs[-1]);  # delete null element
    }

    else {
        open(IN,$in) || die "can't read $in";
        while(<IN>) {
            if (/^<\/DOC>/) {
                push(@docs,join(" ",@lines));
                @lines=();
            }
            else {
                push(@lines,$_);
            }
        }
    }

    foreach my $doc(@docs) {
        return $doc if ($doc=~m|<DOCNO>$docID</DOCNO>|);
    }

} #endsub getdoc


#-----------------------------------------------------------
# return array of blogs from input file
#   - for extremely long input file, process line by line
#-----------------------------------------------------------
#   arg1 = input file
#   arg2 = pointer to doc array
#-----------------------------------------------------------
sub getdocs {
    my($in,$lp)=@_;
    my @lines;
   
    my ($lcnt)= split(/ /,`wc -l $in`);

    if ($lcnt<10**6) {
        open(IN,$in) || die "can't read $in";
        @lines=<IN>;
        close IN;
        @$lp= split(/<\/DOC>/,join(" ",@lines));
        delete($$lp[-1]);  # delete null element
    }

    else {
        open(IN,$in) || die "can't read $in";
        while(<IN>) {
            if (/^<\/DOC>/) {
                push(@$lp,join(" ",@lines));
                @lines=();
            }
            else {
                push(@lines,$_);
            }
        }
    }

} #endsub getdocs


#------------------------------------------------------------
# get blog documents content from permalink files
#  - returns HTML text
#------------------------------------------------------------
# arg1= data directory
# arg2= pointer to docno array (input)
# arg3= pointer to document hash (output)
#       k=docno, v=pointer to hash
#           k=type (url,title,body)
#           v=text string
#------------------------------------------------------------
sub getblog0 {
    my ($dir,$lp,$hp)=@_;
    my ($debug,%files,%dns);

    # max docsize: 10M bytes
    my $maxbytes=10**6;

    foreach my $dn(@$lp) {
        my($b,$subd,$fn)=split/-/,$dn;
        $files{"$subd-$fn"}=1;
        $dns{"$dn"}=1;
    }

    foreach my $file(keys %files) {

        my($subd,$fn)=split/-/,$file;
        my $in="$dir/$subd/permalinks-$fn";
        print STDOUT "processing $in\n" if ($debug);

        my @docs;
        &getdocs($in,\@docs);

        foreach my $doc(@docs) {

            my ($docno,$feedno,$bhpno,$url,$html)=($1,$2,$3,$4,$5)
                if ($doc=~m|<DOCNO>(.+?)</DOCNO>.+?<FEEDNO>(.+?)</FEEDNO>.+?<BLOGHPNO>(.*?)</BLOGHPNO>.+?<PERMALINK>(.+?)</PERMALINK>.+?</DOCHDR>\n(.+)$|s);

            next if (!exists($dns{$docno}));

            # truncate extremely long documents to first 10M characters
            if (length($html)>$maxbytes) {
                $html= substr($html,0,$maxbytes)."</body></html>";
                print "!Warning: Long Doc! $docno truncated to 10M bytes.\n";
            }

	    # parse body text
	    my ($title,$body)=&parse_html(\$html);
            $body= &parse_body($body);

            $$hp{$docno}={ 'url'=> "$url", 'title'=>"$title", 'body'=>"$body" };
        }
    }

} #endsub getblog0


#------------------------------------------------------------
# get blog posting/comment from permalink files
#------------------------------------------------------------
# arg1= data directory
# arg2= pointer to docno array (input)
# arg3= pointer to document hash (output)
#       k=docno, v=pointer to hash
#           k=type (url,title,body)
#           v=text string
#------------------------------------------------------------
sub getblog1 {
    my ($dir,$lp,$hp)=@_;
    my ($debug,%files,%dns);

    # max docsize: 10M bytes
    my $maxbytes=10**6;

    foreach my $dn(@$lp) {
        my($b,$subd,$fn)=split/-/,$dn;
        $files{"$subd-$fn"}=1;
        $dns{"$dn"}=1;
    }

    foreach my $file(keys %files) {

        my($subd,$fn)=split/-/,$file;
        my $in="$dir/$subd/permalinks-$fn";
        print STDOUT "processing $in\n" if ($debug);

        my @docs;
        &getdocs($in,\@docs);

        foreach my $doc(@docs) {

            my ($docno,$feedno,$bhpno,$url,$html)=($1,$2,$3,$4,$5)
                if ($doc=~m|<DOCNO>(.+?)</DOCNO>.+?<FEEDNO>(.+?)</FEEDNO>.+?<BLOGHPNO>(.*?)</BLOGHPNO>.+?<PERMALINK>(.+?)</PERMALINK>.+?</DOCHDR>\n(.+)$|s);

            next if (!exists($dns{$docno}));

            # truncate extremely long documents to first 10M characters
            if (length($html)>$maxbytes) {
                $html= substr($html,0,$maxbytes)."</body></html>";
                print "!Warning: Long Doc! $docno truncated to 10M bytes.\n";
            }

	    # parse body text
	    my ($title,$body)=&parse_html(\$html);

	    # parse out blog content
            &parse_blog3(\$body);

            # delete tags
            my $blog;
            $blog=&parse_body($body) if ($body);

            # delete nonE & long words
            $blog=~s/\S+[^\n\x20-\x80]\S*/ /g;
            $blog=~s/\b[^ ]{25,}\b//g;

            $$hp{$docno}={ 'url'=> "$url", 'title'=>"$title", 'body'=>"$blog" };
        }
    }

} #endsub getblog1


#------------------------------------------------------------
# get blog documents
#------------------------------------------------------------
# arg1= data directory
# arg2= document directory
# arg3= pointer to docno array (input)
# arg4= pointer to document hash (output)
#       k=docno, v=pointer to hash
#           k=type (title,body)
#           v=text string
#------------------------------------------------------------
sub getblog {
    my ($dir,$docd,$lp,$hp)=@_;
    my ($debug,%files,%dns);

    foreach my $dn(@$lp) {
        my($b,$subd,$fn)=split/-/,$dn;
        $files{"$subd-$fn"}=1;
        $dns{"$dn"}=1;
    }

    foreach my $file(keys %files) {

        my($subd,$fn)=split/-/,$file;

        my $in="$dir/$subd/$docd/pml$fn";
        print STDOUT "processing $in\n" if ($debug);

        open(IN,$in) || die "can't read $in";
        my @lines=<IN>;
        close IN;

        my @docs= split(/<\/doc>/,join("",@lines));
        delete($docs[-1]);  # delete the last null split

        foreach my $doc(@docs) {
            my ($docno,$title,$body)=($1,$2,$3) if ($doc=~m|<docno>(.+?)</docno>.+?<ti>(.*?)</ti>.*?<body>(.*?)</body>|s);
            next if (!exists($dns{$docno}));
            $$hp{$docno}={ 'title'=>"$title", 'body'=>"$body" };
        }
    }

} #endsub getblog


#------------------------------------------------------------
# return array of blogs from input file
#-----------------------------------------------------------
#   arg1 = input file
#   arg2 = pointer to doc array
#-----------------------------------------------------------
sub getblogs {
    my($in,$lp)=@_;

    open(IN,$in) || die "can't read $in";
    my @lines=<IN>;
    close IN;

    @$lp= split(/<\/doc>/,join("",@lines));
    delete($$lp[-1]);  # delete the last null split

} #endsub getblogs


#------------------------------------------------------------
# make HF hash from HF lexicon file
#-----------------------------------------------------------
#   arg1 = HF lexicon file
#   arg2 = pointer to HF lexicon hash
#          key: term
#          val: polarity score (p1..p3,n1..n3,m1..m3)
#   arg3 = score boost flag
#            1: map (1, 2, 3) to (1, 2, 4)
#            2: map (1, 2, 3) to (1, 3, 6)
#            3: map (1, 2, 3) to (1, 4, 10)
#   arg4 = no term compression flag (optional: default=compress)
#-----------------------------------------------------------
sub mkHFhash {
    my($inf,$lexhp,$emf,$nocmf)=@_;
    my $debug=0;

    my %em1= (1=>1, 2=>2, 3=>4);
    my %em2= (1=>1, 2=>3, 3=>6);
    my %em3= (1=>1, 2=>4, 3=>10);
    my %em;
    if ($emf && $emf==1) { %em=%em1; }
    elsif ($emf && $emf==2) { %em=%em2; }
    elsif ($emf && $emf==3) { %em=%em3; }

    open(IN,$inf) || die "can't read $inf";
    my @lines=<IN>;
    close IN;
    chomp @lines;

    foreach (@lines) {
        my($str,$sc)=split/:/;
        if ($emf) {
            my($pol,$sc2)=split//,$sc;
            if ($sc2<4) { $sc2= $em{$sc2} }
            else { $sc2 += $em{3}; }
            $sc= $pol.$sc2;
        }
        $str=~tr/A-Z/a-z/;  # conver to lowercase
        if ($str=~/,/) {
            my @wds=split/,/,$str;
            foreach my $wd(@wds) {
                $lexhp->{$wd}=$sc; 
                if ($wd=~/-/) {
                    $wd=~s/-//g;
                    $lexhp->{$wd}=$sc; 
                }
            }
        }
        elsif ($str=~s/\(v\)//) {
            my($past,$ing,$now3);
            if ($str=~/^(.+?)e$/) {
                $ing=$1."ing"; 
                $past=$str."d"; 
            }
            else {
                $ing=$str."ing"; 
                $past=$str."ed"; 
            }
            # third person singular
            if ($str=~/(s|ch)$/) { $now3=$str."es";  }
            elsif ($str=~/^(.+[^aieou])y$/) { $now3=$1."ies";  }
            else { $now3=$str."s"; }
            $lexhp->{$str}=$sc; 
            $lexhp->{$past}=$sc;
            $lexhp->{$ing}=$sc;
            $lexhp->{$now3}=$sc;
        }
        elsif ($str=~s/\(n\)//) {
            $lexhp->{$str}=$sc;
            # plural
            if ($str=~/s$/) { $str .= "es";  }
            elsif ($str=~/^(.+[^aieou])y$/) { $str=$1."ies";  }
            else { $str .= "s"; }
            $lexhp->{$str}=$sc;
        }
        else {
            $lexhp->{$str}=$sc;
            # compress hyphens
            if ($str=~/-/) {
                $str=~s/-//g;
                $lexhp->{$str}=$sc; 
            }
        }
    }

    # compress embedded repeat characters
    #  - exception: e, o
    if (!$nocmf) {
        foreach my $wd(keys %{$lexhp}) {
            my $sc=$lexhp->{$wd};
            print "mkHFhash: $wd=$sc\n" if ($debug);
            if ($wd=~/([a-cdf-np-z])\1+\B/) {
                $wd=~s/([a-cdf-np-z])\1+\B/$1/g;
                $lexhp->{$wd}=$sc; 
                print "    wd2=$wd\n" if ($debug);
            }
        }
    }

} #endsub mkHFhash

# handle prob. lex weights
sub mkHFhh {
    my($inf,$lexhp,$emf,$nocmf)=@_;
    my $debug=0;

    my %em1= (1=>1, 2=>2, 3=>4);
    my %em2= (1=>1, 2=>3, 3=>6);
    my %em3= (1=>1, 2=>4, 3=>10);
    my %em;
    if ($emf && $emf==1) { %em=%em1; }
    elsif ($emf && $emf==2) { %em=%em2; }
    elsif ($emf && $emf==3) { %em=%em3; }

    open(IN,$inf) || die "can't read $inf";
    my @lines=<IN>;
    close IN;
    chomp @lines;

    foreach (@lines) {
        my($str,$scM,$scC,$scP)=split/:/;
        if ($emf) {
            foreach my $sc($scM,$scC,$scP) {
                my($pol,$sc2)=split//,$sc,2;
                $sc2 *= $em{3}; 
                $sc= $pol.$sc2;
            }
        }
        $str=~tr/A-Z/a-z/;  # conver to lowercase
        if ($str=~/,/) {
            my @wds=split/,/,$str;
            foreach my $wd(@wds) {
                $lexhp->{$wd}{'man'}=$scM; 
                $lexhp->{$wd}{'combo'}=$scC; 
                $lexhp->{$wd}{'prob'}=$scP; 
                if ($wd=~/-/) {
                    $wd=~s/-//g;
                    $lexhp->{$wd}{'man'}=$scM; 
                    $lexhp->{$wd}{'combo'}=$scC; 
                    $lexhp->{$wd}{'prob'}=$scP; 
                }
            }
        }
        elsif ($str=~s/\(v\)//) {
            my($past,$ing,$now3);
            if ($str=~/^(.+?)e$/) {
                $ing=$1."ing"; 
                $past=$str."d"; 
            }
            else {
                $ing=$str."ing"; 
                $past=$str."ed"; 
            }
            # third person singular
            if ($str=~/(s|ch)$/) { $now3=$str."es";  }
            elsif ($str=~/^(.+[^aieou])y$/) { $now3=$1."ies";  }
            else { $now3=$str."s"; }
            $lexhp->{$str}{'man'}=$scM; 
            $lexhp->{$past}{'man'}=$scM;
            $lexhp->{$ing}{'man'}=$scM;
            $lexhp->{$now3}{'man'}=$scM;
            $lexhp->{$str}{'combo'}=$scC; 
            $lexhp->{$past}{'combo'}=$scC;
            $lexhp->{$ing}{'combo'}=$scC;
            $lexhp->{$now3}{'combo'}=$scC;
            $lexhp->{$str}{'prob'}=$scP; 
            $lexhp->{$past}{'prob'}=$scP;
            $lexhp->{$ing}{'prob'}=$scP;
            $lexhp->{$now3}{'prob'}=$scP;
        }
        elsif ($str=~s/\(n\)//) {
            $lexhp->{$str}{'man'}=$scM;
            $lexhp->{$str}{'combo'}=$scC; 
            $lexhp->{$str}{'prob'}=$scP; 
            # plural
            if ($str=~/s$/) { $str .= "es";  }
            elsif ($str=~/^(.+[^aieou])y$/) { $str=$1."ies";  }
            else { $str .= "s"; }
            $lexhp->{$str}{'man'}=$scM;
            $lexhp->{$str}{'combo'}=$scC; 
            $lexhp->{$str}{'prob'}=$scP; 
        }
        else {
            $lexhp->{$str}{'man'}=$scM;
            $lexhp->{$str}{'combo'}=$scC; 
            $lexhp->{$str}{'prob'}=$scP; 
            # compress hyphens
            if ($str=~/-/) {
                $str=~s/-//g;
                $lexhp->{$str}{'man'}=$scM;
                $lexhp->{$str}{'combo'}=$scC; 
                $lexhp->{$str}{'prob'}=$scP; 
            }
        }
    }

    # compress embedded repeat characters
    #  - exception: e, o
    if (!$nocmf) {
        foreach my $wd(keys %{$lexhp}) {
            my $scM=$lexhp->{$wd}{'man'};
            my $scC=$lexhp->{$wd}{'combo'};
            my $scP=$lexhp->{$wd}{'prob'};
            print "mkHFhash: $wd=$scM\n" if ($debug);
            if ($wd=~/([a-cdf-np-z])\1+\B/) {
                $wd=~s/([a-cdf-np-z])\1+\B/$1/g;
                $lexhp->{$wd}{'man'}=$scM;
                $lexhp->{$wd}{'combo'}=$scC; 
                $lexhp->{$wd}{'prob'}=$scP; 
                print "    wd2=$wd\n" if ($debug);
            }
        }
    }

} #endsub mkHFhh


#------------------------------------------------------------
# make IU hash from lexicon file
#-----------------------------------------------------------
#   arg1 = lexicon file
#   arg2 = pointer to IU lexicon hash
#          key: I, me
#          val: pointer to term-polarity hash (k=term, v=polarity score)
#   arg3 = optional flag to keep the original IU values in hash key 
#          e.g., key: I, my, I'm, me
#   arg4 = optional score boost flag
#            1: map (1, 2, 3) to (1, 2, 4)
#            2: map (1, 2, 3) to (1, 3, 6)
#            3: map (1, 2, 3) to (1, 4, 10)
#   arg5 = no term compression flag (optional: default=compress)
#-----------------------------------------------------------
sub mkIUhash {
    my($inf,$lexhp,$flag,$emf,$nocmf)=@_;
    my $debug=0;

    my %em1= (1=>1, 2=>2, 3=>4);
    my %em2= (1=>1, 2=>3, 3=>6);
    my %em3= (1=>1, 2=>4, 3=>10);
    my %em;
    if ($emf && $emf==1) { %em=%em1; }
    elsif ($emf && $emf==2) { %em=%em2; }
    elsif ($emf && $emf==3) { %em=%em3; }

    open(IN,$inf) || die "can't read $inf";
    my @lines=<IN>;
    close IN;
    chomp @lines;

    foreach (@lines) {
        my($iu,$sc)=split/:/;
        my($pol,$sc2);
        if ($emf) {
            $sc=~/^(.)(.+)$/;
            ($pol,$sc2)=($1,$2);
            if ($sc2<4) { $sc2= $em{$sc2} }
            else { $sc2 += $em{3}; }
            $sc= $pol.$sc2;
        }
        $iu=~tr/A-Z/a-z/;   # convert to lowercase
        if ($iu=~/^I (.+)$/i) {
            my $term=$1;
            if ($term=~/,/) {
                my($now,$past,$ing)=split/,/,$term;
                $$lexhp{'I'}{$now}=$sc; 
                $$lexhp{'I'}{$past}=$sc;
                $$lexhp{'I'}{$ing}=$sc;
            }
            else {
                my($past,$ing);
                if ($term=~/^(.+?)e$/) {
                    $ing=$1."ing"; 
                    $past=$term."d"; 
                }
                else {
                    $ing=$term."ing"; 
                    $past=$term."ed"; 
                }
                $$lexhp{'I'}{$term}=$sc; 
                $$lexhp{'I'}{$past}=$sc;
                $$lexhp{'I'}{$ing}=$sc;
            }
        }
        elsif ($iu=~/^I'm ([^ ]+)/i) {
            my $key;
            if ($flag) { $key="I'm"; }
            else { $key="I"; }
            $$lexhp{$key}{$1}=$sc; 
        }
        elsif ($iu=~/^my (.+)$/i) {
            my $term=$1;
            # plural
            my $terms;
            if ($term=~/s$/) { $terms=$term."es";  }
            elsif ($term=~/^(.+[^aieou])y$/) { $terms=$1."ies";  }
            else { $terms=$1."s"; }
            $$lexhp{'my'}{$term}=$sc; 
            $$lexhp{'my'}{$terms}=$sc; 
        }
        elsif ($iu=~/^(.+) me$/i) {
            my $term=$1;
            if ($term=~/^(.+?) for$/) {
                $$lexhp{'me'}{$1}=$sc; 
            }
            else {
                $term=~s/ ([a-z]+)$//;
                if ($term=~/,/) {
                    my($now,$past,$ing)=split/,/,$term;
                    # third person singular
                    my $now3;
                    if ($now=~/(s|ch)$/) { $now3=$now."es";  }
                    elsif ($now=~/^(.+[^aieou])y$/) { $now3=$1."ies";  }
                    else { $now3=$now."s"; }
                    $$lexhp{'me'}{$now}=$sc; 
                    $$lexhp{'me'}{$past}=$sc;
                    $$lexhp{'me'}{$ing}=$sc;
                    $$lexhp{'me'}{$now3}=$sc;
                }
                else {
                    # third person singular
                    my $now3;
                    if ($term=~/(s|ch)$/) { $now3=$term."es";  }
                    elsif ($term=~/^(.+[^aieou])y$/) { $now3=$1."ies";  }
                    else { $now3=$term."s"; }
                    my($past,$ing);
                    if ($term=~/^(.+?)e$/) {
                        $ing=$1."ing"; 
                        $past=$term."d"; 
                    }
                    else {
                        $ing=$term."ing"; 
                        $past=$term."ed"; 
                    }
                    $$lexhp{'me'}{$term}=$sc; 
                    $$lexhp{'me'}{$past}=$sc;
                    $$lexhp{'me'}{$ing}=$sc;
                    $$lexhp{'me'}{$now3}=$sc;
                }
            }
        }
    }

    # compress embedded repeat characters
    #  - exception: e, o
    if (!$nocmf) {
        foreach my $iu(keys %{$lexhp}) {
            foreach my $wd(keys %{$lexhp->{$iu}}) {
                my $sc=$lexhp->{$iu}{$wd};
                print "mkIUhash: iu=$iu, $wd=$sc\n" if ($debug);
                if ($wd=~/([a-cdf-np-z])\1+\B/) {
                    $wd=~s/([a-cdf-np-z])\1+\B/$1/g;
                    $lexhp->{$iu}{$wd}=$sc; 
                    print "    wd2=$wd\n" if ($debug);
                }
            }
        }
    }

} #endsub mkIUhash

sub mkIUhh {
    my($inf,$lexhp,$flag,$emf,$nocmf)=@_;
    my $debug=0;

    my %em1= (1=>1, 2=>2, 3=>4);
    my %em2= (1=>1, 2=>3, 3=>6);
    my %em3= (1=>1, 2=>4, 3=>10);
    my %em;
    if ($emf && $emf==1) { %em=%em1; }
    elsif ($emf && $emf==2) { %em=%em2; }
    elsif ($emf && $emf==3) { %em=%em3; }

    open(IN,$inf) || die "can't read $inf";
    my @lines=<IN>;
    close IN;
    chomp @lines;

    foreach (@lines) {
        my($iu,$scM,$scC,$scP)=split/:/;
        if ($emf) {
            foreach my $sc($scM,$scC,$scP) {
                my($pol,$sc2)=split//,$sc,2;
                $sc2 *= $em{3}; 
                $sc= $pol.$sc2;
            }
        }
        $iu=~tr/A-Z/a-z/;   # convert to lowercase
        if ($iu=~/^I (.+)$/i) {
            my $term=$1;
            if ($term=~/,/) {
                my($now,$past,$ing)=split/,/,$term;
                $lexhp->{'I'}{$now}{'man'}=$scM; 
                $lexhp->{'I'}{$past}{'man'}=$scM;
                $lexhp->{'I'}{$ing}{'man'}=$scM;
                $lexhp->{'I'}{$now}{'combo'}=$scC; 
                $lexhp->{'I'}{$past}{'combo'}=$scC;
                $lexhp->{'I'}{$ing}{'combo'}=$scM;
                $lexhp->{'I'}{$now}{'prob'}=$scP; 
                $lexhp->{'I'}{$past}{'prob'}=$scP;
                $lexhp->{'I'}{$ing}{'prob'}=$scP;
            }
            else {
                my($past,$ing);
                if ($term=~/^(.+?)e$/) {
                    $ing=$1."ing"; 
                    $past=$term."d"; 
                }
                else {
                    $ing=$term."ing"; 
                    $past=$term."ed"; 
                }
                $lexhp->{'I'}{$term}{'man'}=$scM; 
                $lexhp->{'I'}{$past}{'man'}=$scM;
                $lexhp->{'I'}{$ing}{'man'}=$scM;
                $lexhp->{'I'}{$term}{'combo'}=$scC; 
                $lexhp->{'I'}{$past}{'combo'}=$scC;
                $lexhp->{'I'}{$ing}{'combo'}=$scM;
                $lexhp->{'I'}{$term}{'prob'}=$scP; 
                $lexhp->{'I'}{$past}{'prob'}=$scP;
                $lexhp->{'I'}{$ing}{'prob'}=$scP;
            }
        }
        elsif ($iu=~/^I'm ([^ ]+)/i) {
            my $key;
            if ($flag) { $key="I'm"; }
            else { $key="I"; }
            $lexhp->{$key}{$1}{'man'}=$scM; 
            $lexhp->{$key}{$1}{'combo'}=$scC; 
            $lexhp->{$key}{$1}{'prob'}=$scP; 
        }
        elsif ($iu=~/^my (.+)$/i) {
            my $term=$1;
            # plural
            my $terms;
            if ($term=~/s$/) { $terms=$term."es";  }
            elsif ($term=~/^(.+[^aieou])y$/) { $terms=$1."ies";  }
            else { $terms=$1."s"; }
            $lexhp->{'my'}{$term}{'man'}=$scM; 
            $lexhp->{'my'}{$terms}{'man'}=$scM; 
            $lexhp->{'my'}{$term}{'combo'}=$scC; 
            $lexhp->{'my'}{$terms}{'combo'}=$scC; 
            $lexhp->{'my'}{$term}{'prob'}=$scP; 
            $lexhp->{'my'}{$terms}{'prob'}=$scP; 
        }
        elsif ($iu=~/^(.+) me$/i) {
            my $term=$1;
            if ($term=~/^(.+?) for$/) {
                $lexhp->{'me'}{$1}{'man'}=$scM; 
                $lexhp->{'me'}{$1}{'combo'}=$scC; 
                $lexhp->{'me'}{$1}{'prob'}=$scP; 
            }
            else {
                $term=~s/ ([a-z]+)$//;
                if ($term=~/,/) {
                    my($now,$past,$ing)=split/,/,$term;
                    # third person singular
                    my $now3;
                    if ($now=~/(s|ch)$/) { $now3=$now."es";  }
                    elsif ($now=~/^(.+[^aieou])y$/) { $now3=$1."ies";  }
                    else { $now3=$now."s"; }
                    $lexhp->{'me'}{$now}{'man'}=$scM; 
                    $lexhp->{'me'}{$now3}{'man'}=$scM; 
                    $lexhp->{'me'}{$past}{'man'}=$scM;
                    $lexhp->{'me'}{$ing}{'man'}=$scM;
                    $lexhp->{'me'}{$now}{'combo'}=$scC; 
                    $lexhp->{'me'}{$now3}{'combo'}=$scC; 
                    $lexhp->{'me'}{$past}{'combo'}=$scC;
                    $lexhp->{'me'}{$ing}{'combo'}=$scM;
                    $lexhp->{'me'}{$now}{'prob'}=$scP; 
                    $lexhp->{'me'}{$now3}{'prob'}=$scP; 
                    $lexhp->{'me'}{$past}{'prob'}=$scP;
                    $lexhp->{'me'}{$ing}{'prob'}=$scP;
                }
                else {
                    # third person singular
                    my $now3;
                    if ($term=~/(s|ch)$/) { $now3=$term."es";  }
                    elsif ($term=~/^(.+[^aieou])y$/) { $now3=$1."ies";  }
                    else { $now3=$term."s"; }
                    my($past,$ing);
                    if ($term=~/^(.+?)e$/) {
                        $ing=$1."ing"; 
                        $past=$term."d"; 
                    }
                    else {
                        $ing=$term."ing"; 
                        $past=$term."ed"; 
                    }
                    $lexhp->{'me'}{$term}{'man'}=$scM; 
                    $lexhp->{'me'}{$now3}{'man'}=$scM; 
                    $lexhp->{'me'}{$past}{'man'}=$scM;
                    $lexhp->{'me'}{$ing}{'man'}=$scM;
                    $lexhp->{'me'}{$term}{'combo'}=$scC; 
                    $lexhp->{'me'}{$now3}{'combo'}=$scC; 
                    $lexhp->{'me'}{$past}{'combo'}=$scC;
                    $lexhp->{'me'}{$ing}{'combo'}=$scM;
                    $lexhp->{'me'}{$term}{'prob'}=$scP; 
                    $lexhp->{'me'}{$now3}{'prob'}=$scP; 
                    $lexhp->{'me'}{$past}{'prob'}=$scP;
                    $lexhp->{'me'}{$ing}{'prob'}=$scP;
                }
            }
        }
    }

    # compress embedded repeat characters
    #  - exception: e, o
    if (!$nocmf) {
        foreach my $iu(keys %{$lexhp}) {
            foreach my $wd(keys %{$lexhp->{$iu}}) {
                my $scM=$lexhp->{$iu}{$wd}{'man'};
                my $scC=$lexhp->{$iu}{$wd}{'combo'};
                my $scP=$lexhp->{$iu}{$wd}{'prob'};
                print "mkIUhash: iu=$iu, $wd=$scM\n" if ($debug);
                if ($wd=~/([a-cdf-np-z])\1+\B/) {
                    $wd=~s/([a-cdf-np-z])\1+\B/$1/g;
                    $lexhp->{$iu}{$wd}{'man'}=$scM; 
                    $lexhp->{$iu}{$wd}{'combo'}=$scC; 
                    $lexhp->{$iu}{$wd}{'prob'}=$scP; 
                    print "    wd2=$wd\n" if ($debug);
                }
            }
        }
    }

} #endsub mkIUhh


#------------------------------------------------------------
# make LF hash from regex file
#-----------------------------------------------------------
#   arg1 = LF regex file
#   arg2 = pointer to LF regex hash
#   arg3 = pointer to LF regex array (optional)
#   arg4 = pointer to LF regex score array (optional)
#          key: regex
#          val: polarity score (p1..p3,n1..n3,m1..m3)
#   arg5 = score boost flag
#            1: map (1, 2, 3) to (1, 2, 4)
#            2: map (1, 2, 3) to (1, 3, 6)
#            3: map (1, 2, 3) to (1, 4, 10)
#-----------------------------------------------------------
sub mkLFhash1 {
    my($inf,$rgxhp,$rgxlp,$sclp,$emf)=@_;
    my $debug=0;

    my %em1= (1=>1, 2=>2, 3=>4);
    my %em2= (1=>1, 2=>3, 3=>6);
    my %em3= (1=>1, 2=>4, 3=>10);
    my %em;
    if ($emf && $emf==1) { %em=%em1; }
    elsif ($emf && $emf==2) { %em=%em2; }
    elsif ($emf && $emf==3) { %em=%em3; }

    open(IN,$inf) || die "can't read $inf";
    my @lines=<IN>;
    close IN;
    chomp @lines;

    foreach (@lines) {
        my($rgx,$sc)=split/ +/;
        my($pol,$sc2);
        if ($emf) {
            $sc=~/^(.)(.+)$/;
            ($pol,$sc2)=($1,$2);
            if ($sc2<4) { $sc2= $em{$sc2} }
            else { $sc2 += $em{3}; }
            $sc= $pol.$sc2;
        }
        $rgxhp->{"$rgx"}="$sc";
    }

    # create an array of regex & corresponding array of scores
    # by character sort of rgx by descending score
    #  - order = polarity (p, n, m), then polarity strength (3, 2, 1) 
    #    (to ensure strongest match, stop after first hit)
    if ($rgxlp) {
        foreach my $rgx(sort {$rgxhp->{$b} cmp $rgxhp->{$a}} keys %{$rgxhp}) {
            push(@{$rgxlp},$rgx);
            push(@{$sclp},$rgxhp->{$rgx});
        }
    }

} #endsub mkLFhash1

sub mkLFhh1 {
    my($inf,$rgxhp,$rgxlp,$scMlp,$scClp,$scPlp,$emf)=@_;
    my $debug=0;

    my %em1= (1=>1, 2=>2, 3=>4);
    my %em2= (1=>1, 2=>3, 3=>6);
    my %em3= (1=>1, 2=>4, 3=>10);
    my %em;
    if ($emf && $emf==1) { %em=%em1; }
    elsif ($emf && $emf==2) { %em=%em2; }
    elsif ($emf && $emf==3) { %em=%em3; }

    open(IN,$inf) || die "can't read $inf";
    my @lines=<IN>;
    close IN;
    chomp @lines;

    foreach (@lines) {
        my($rgx,$scM,$scC,$scP)=split/ +/;
        if ($emf) {
            foreach my $sc($scM,$scC,$scP) {
                my($pol,$sc2)=split//,$sc,2;
                $sc2 *= $em{3}; 
                $sc= $pol.$sc2;
            }
        }
        $rgxhp->{"$rgx"}{'man'}=$scM;
        $rgxhp->{"$rgx"}{'combo'}=$scC;
        $rgxhp->{"$rgx"}{'prob'}=$scP;
    }

    # create an array of regex & corresponding array of scores
    # by character sort of rgx by descending score
    #  - order = polarity (p, n, m), then polarity strength (3, 2, 1) 
    #    (to ensure strongest match, stop after first hit)
    if ($rgxlp) {
        foreach my $rgx(sort {$rgxhp->{$b}{'man'} cmp $rgxhp->{$a}{'man'}} keys %{$rgxhp}) {
            push(@{$rgxlp},$rgx);
            push(@{$scMlp},$rgxhp->{$rgx}{'man'});
            push(@{$scClp},$rgxhp->{$rgx}{'combo'});
            push(@{$scPlp},$rgxhp->{$rgx}{'prob'});
        }
    }

} #endsub mkLFhh


#------------------------------------------------------------
# make LF hash from LF lexicon file
#-----------------------------------------------------------
#   arg1 = LF lexicon file
#   arg2 = pointer to LF lexicon hash
#          key: LF term
#          val: polarity score (p1..p3,n1..n3,m1..m3)
#   arg3 = score boost flag
#            1: map (1, 2, 3) to (1, 2, 4)
#            2: map (1, 2, 3) to (1, 3, 6)
#            3: map (1, 2, 3) to (1, 4, 10)
#-----------------------------------------------------------
sub mkLFhash2 {
    my($inf,$lexhp,$emf)=@_;
    my $debug=0;

    my %em1= (1=>1, 2=>2, 3=>4);
    my %em2= (1=>1, 2=>3, 3=>6);
    my %em3= (1=>1, 2=>4, 3=>10);
    my %em;
    if ($emf && $emf==1) { %em=%em1; }
    elsif ($emf && $emf==2) { %em=%em2; }
    elsif ($emf && $emf==3) { %em=%em3; }

    open(IN,$inf) || die "can't read $inf";
    my @lines=<IN>;
    close IN;
    chomp @lines;

    foreach (@lines) {
        my($wd,$sc)=split/:/;
        my($pol,$sc2);
        if ($emf) {
            $sc=~/^(.)(.+)$/;
            ($pol,$sc2)=($1,$2);
            if ($sc2<4) { $sc2= $em{$sc2} }
            else { $sc2 += $em{3}; }
            $sc= $pol.$sc2;
        }
        $lexhp->{"\L$wd"}="$sc";  # convert to lowercase
    }

} #endsub mkLFhash2

sub mkLFhh2 {
    my($inf,$lexhp,$emf)=@_;
    my $debug=0;

    my %em1= (1=>1, 2=>2, 3=>4);
    my %em2= (1=>1, 2=>3, 3=>6);
    my %em3= (1=>1, 2=>4, 3=>10);
    my %em;
    if ($emf && $emf==1) { %em=%em1; }
    elsif ($emf && $emf==2) { %em=%em2; }
    elsif ($emf && $emf==3) { %em=%em3; }

    open(IN,$inf) || die "can't read $inf";
    my @lines=<IN>;
    close IN;
    chomp @lines;

    foreach (@lines) {
        my($wd,$scM,$scC,$scP)=split/:/;
        if ($emf) {
            foreach my $sc($scM,$scC,$scP) {
                my($pol,$sc2)=split//,$sc,2;
                $sc2 *= $em{3}; 
                $sc= $pol.$sc2;
            }
        }
        $lexhp->{"\L$wd"}{'man'}=$scM;
        $lexhp->{"\L$wd"}{'combo'}=$scC;
        $lexhp->{"\L$wd"}{'prob'}=$scP;
    }

} #endsub mkLFhash2


#------------------------------------------------------------
# make AC hash from acronym file
#-----------------------------------------------------------
#   arg1 = acronym file
#   arg2 = pointer to AC hash
#          key: acronyms, expanded phrase
#          val: polarity score (p1..p3,n1..n3,m1..m3)
#-----------------------------------------------------------
sub mkAChash {
    my($inf,$lexhp)=@_;

    open(IN,$inf) || die "can't read $inf";
    my @lines=<IN>;
    close IN;
    chomp @lines;

    foreach (@lines) {
        my($str,$sc)=split/:/;
        $str=~tr/A-Z/a-z/;  # convert to lowercase
        $str=~/^(.+?)\((.+)\)$/;
        my($wd,$ph)=($1,$2);
        $lexhp->{"$wd"}="$sc";
        $lexhp->{"$ph"}="$sc";
    }

} #endsub mkAChash

sub mkAChh {
    my($inf,$lexhp)=@_;

    open(IN,$inf) || die "can't read $inf";
    my @lines=<IN>;
    close IN;
    chomp @lines;

    foreach (@lines) {
        my($str,$scM,$scC,$scP)=split/:/;
        $str=~tr/A-Z/a-z/;  # convert to lowercase
        $str=~/^(.+?)\((.+)\)$/;
        my($wd,$ph)=($1,$2);
        $lexhp->{"$wd"}{'man'}=$scM;
        $lexhp->{"$ph"}{'man'}=$scM;
        $lexhp->{"$wd"}{'combo'}=$scC;
        $lexhp->{"$ph"}{'combo'}=$scC;
        $lexhp->{"$wd"}{'prob'}=$scP;
        $lexhp->{"$ph"}{'prob'}=$scP;
    }

} #endsub mkAChh


#-----------------------------------------------------------
# create lexicon hash from Wilson's subjective terms
#-----------------------------------------------------------
#   arg1 = input file
#   arg2 = pointer to lexicon hash
#            k = term  (lowercase) 
#            v = score ($polarity$strength)
#   arg3 = score boost flag (optional)
#            1: map (1, 2, 3) to (1, 2, 4)
#            2: map (1, 2, 3) to (1, 3, 6)
#            3: map (1, 2, 3) to (1, 4, 10)
#   arg4 = no term compression flag (optional: default=compress)
#   arg5 = score (optional: e.g. m1)
#            for term list without scores
#-----------------------------------------------------------
sub mkWhash {
    my($in,$lexhp,$emf,$nocmf,$score)=@_;

    my %em1= (1=>1, 2=>2, 3=>4);
    my %em2= (1=>1, 2=>3, 3=>6);
    my %em3= (1=>1, 2=>4, 3=>10);
    my %em;
    if ($emf && $emf==1) { %em=%em1; }
    elsif ($emf && $emf==2) { %em=%em2; }
    elsif ($emf && $emf==3) { %em=%em3; }

    open(IN,$in) || die "can't read $in";
    while(<IN>) {
        chomp;
        my($term,$sc)=split/:/; 
        if ($score) {
            $lexhp->{lc($term)}=$score;
        }
        else {
            $lexhp->{lc($term)}=$sc;
        }
    }            
    close IN;
        
    # add compressed terms
    &updatelex($lexhp) if (!$nocmf); 
        
} #endsub mkWhash      

sub mkWhh {
    my($in,$lexhp,$emf,$nocmf)=@_;

    my %em1= (1=>1, 2=>2, 3=>4);
    my %em2= (1=>1, 2=>3, 3=>6);
    my %em3= (1=>1, 2=>4, 3=>10);
    my %em;
    if ($emf && $emf==1) { %em=%em1; }
    elsif ($emf && $emf==2) { %em=%em2; }
    elsif ($emf && $emf==3) { %em=%em3; }

    open(IN,$in) || die "can't read $in";
    while(<IN>) {
        chomp;
        my($term,$scM,$scC,$scP)=split/:/;
        if ($emf) {
            foreach my $sc($scM,$scC,$scP) {
                my($pol,$sc2)=split//,$sc,2;
                $sc2 *= $em{3}; 
                $sc= $pol.$sc2;
            }
        }
        $lexhp->{"\L$term"}{'man'}=$scM;
        $lexhp->{"\L$term"}{'combo'}=$scC;
        $lexhp->{"\L$term"}{'prob'}=$scP;
    }            
    close IN;
        
    # add compressed terms
    &updatelex2($lexhp) if (!$nocmf); 
        
} #endsub mkWhh      

sub mkWhash2 {
    my($in,$lexhp,$emf,$nocmf,$score)=@_;

    my %em1= (1=>1, 2=>2, 3=>4);
    my %em2= (1=>1, 2=>3, 3=>6);
    my %em3= (1=>1, 2=>4, 3=>10);
    my %em;
    if ($emf && $emf==1) { %em=%em1; }
    elsif ($emf && $emf==2) { %em=%em2; }
    elsif ($emf && $emf==3) { %em=%em3; }

    open(IN,$in) || die "can't read $in";
    while(<IN>) {
        chomp;
        my($term,$value)=split/ /; 
        if ($score) {
            $lexhp->{lc($term)}=$score;
        }
        else {
            my($pol,$sc);
            if ($value=~/pos/) { $pol='p'; }
            elsif ($value=~/neg/) { $pol='n'; }
            else { $pol='m'; }
            if ($value=~/strong/) { $sc=3; }
            elsif ($value=~/weak/) { $sc=1; }
            else { $sc=2; }  
            $sc= $em{$sc} if ($emf);
            $lexhp->{lc($term)}="$pol$sc";
        }
    }            
    close IN;
        
    # add compressed terms
    &updatelex($lexhp) if (!$nocmf); 
        
} #endsub mkWhash      


#------------------------------------------------------------
# preprocess blog text for opinion scoring
#   1. replace negation words w/ placeholder
#   2. make spell-correction (e.g. repeated characters)
#-----------------------------------------------------------
#   arg2 = text to process
#   arg4 = negation placeholder    (e.g., MM--negstr--MM)
#   r.v. = (processed text)
#-----------------------------------------------------------
sub preptext0 {
    my($text,$NOT)=@_;
    my $debug=0;

    $text=~s/<.+?>/ /gs;
    $text=~s/\s+/ /gs;

    print "PrepText0: T1=$text\n" if ($debug);

    # expand contractions
    $text=~s/I'm\b/I am/gi;
    $text=~s/\b(he|she|that|it)'s\b/$1 is/gi;
    $text=~s/'re\b/ are/gi;
    $text=~s/'ve\b/ have/gi;
    $text=~s/'ll\b/ will/gi;

    # replace negations
    $text=~s/\b(cannot|can not|can't|could not|couldn't|will not|won't|would not|wouldn't|shall not|shan't|should not|shouldn't|must not|mustn't|does not|doesn't|do not|don't|did not|didn't|may not|might not|is not|isn't|am not|was not|wasn't|are not|aren't|were not|weren't|have not|haven't|had not|hadn't|need not|needn't)\b/ $NOT /gi;
    $text=~s/\b(hardly|hardly ever|never|barely|scarcely)\s+(can|could|will|would|shall|should|must|does|do|did|may|might|is|am|was|are|were|have to|had to|have|had|need)\b/ $NOT /gi;
    $text=~s/\b(can|could|will|would|shall|should|must|does|do|did|may|might|is|am|was|are|were|have to|had to|have|had|need)\s+(hardly|hardly ever|never|barely|scarcely|no)\b/ $NOT /gi;

    # compress embedded triple repeat chars to double chars
    foreach my $c('b','c','d','e','f','g','l','n','o','p','r','s','t','z') {
        $text=~s/\B$c$c$c\B/$c$c/ig;
    }

    print "PrepText0: T2=$text\n" if ($debug);

    return($text);

} #endsub preptext0


#------------------------------------------------------------
# preprocess blog text for opinion scoring
#   1. replace exact match of query string w/ placeholder
#   2. replace negation words w/ placeholder
#   3. make spell-correction (e.g. repeated characters)
#-----------------------------------------------------------
#   arg1 = query title string
#   arg2 = text to process
#   arg3 = query match placeholder (e.g., MM--qxmatch--MM)
#   arg4 = negation placeholder    (e.g., MM--negstr--MM)
#   r.v. = (number of query string match, processed text)
#-----------------------------------------------------------
sub preptext {
    my($qti,$text,$QTM,$NOT)=@_;
    my $debug=0;

    $text=~s/<.+?>/ /gs;
    $text=~s/\s+/ /gs;

    print "PrepText: T1=$text\n" if ($debug);

    # replace query strings
    my $qtmcnt=0;
    while ($text=~/\b$qti/ig) {
        $text=~s/\b$qti/ $QTM /i;
        $qtmcnt++;
    }

    # expand contractions
    $text=~s/I'm\b/I am/gi;
    $text=~s/\b(he|she|that|it)'s\b/$1 is/gi;
    $text=~s/'re\b/ are/gi;
    $text=~s/'ve\b/ have/gi;
    $text=~s/'ll\b/ will/gi;

    # replace negations
    # !! add 'nothing': e.g. 'nothing bad'
    $text=~s/\b(cannot|can not|can't|could not|couldn't|will not|won't|would not|wouldn't|shall not|shan't|should not|shouldn't|must not|mustn't|does not|doesn't|do not|don't|did not|didn't|may not|might not|is not|isn't|am not|was not|wasn't|are not|aren't|were not|weren't|have not|haven't|had not|hadn't|need not|needn't)\b/ $NOT /gi;
    $text=~s/\b(hardly|hardly ever|never|barely|scarcely)\s+(can|could|will|would|shall|should|must|does|do|did|may|might|is|am|was|are|were|have to|had to|have|had|need)\b/ $NOT /gi;
    $text=~s/\b(can|could|will|would|shall|should|must|does|do|did|may|might|is|am|was|are|were|have to|had to|have|had|need)\s+(hardly|hardly ever|never|barely|scarcely|no)\b/ $NOT /gi;

    # compress embedded triple repeat chars to double chars
    foreach my $c('b','c','d','e','f','g','l','n','o','p','r','s','t','z') {
        $text=~s/\B$c$c$c\B/$c$c/ig;
    }

    print "PrepText: mcnt=$qtmcnt, T2=$text\n" if ($debug);

    return($qtmcnt,$text);

} #endsub preptext


#------------------------------------------------------------
# compute opinion polarity score 
#   - no proximity match scores
#-----------------------------------------------------------
#   arg1 = polarity (p,n)
#   arg2 = polarity score
#   arg3 = preceding word
#   arg4 = pre-preceding word
#   arg5 = pre-pre-preceding word
#   arg6 = pointer to negation hash
#          key: term, val: 1
#   arg7 = negation flag
#   r.v. = (Psc, Nsc)
#-----------------------------------------------------------
sub polSC0 {
    my($pol,$sc,$pwd,$ppwd,$pppwd,$neghp,$negflag)=@_;
    my $debug=0;

    my($p2,$n2)=(0,0);

    # preceding word is a negation: e.g. 'not good', 'not so good', 'isn't really very good'
    if ( ($pwd && $neghp->{$pwd}) || ($ppwd && $neghp->{$ppwd}) || ($pppwd && $neghp->{$pppwd}) || $negflag ) {
        if ($pol eq 'n') { 
            $p2 = $sc; 
        }
        elsif ($pol eq 'p') { 
            $n2 = $sc; 
        }
    }
    else {
        if ($pol eq 'p') { 
            $p2 = $sc; 
        }
        elsif ($pol eq 'n') { 
            $n2 = $sc; 
        }
    }

    print "polSC: pol=$pol, sc=$sc, p2=$p2, n2=$n2\n" if ($debug);

    return ($p2,$n2);

} #endsub polSC0


#------------------------------------------------------------
# compute opinion polarity score
#-----------------------------------------------------------
#   arg1 = polarity (p,n)
#   arg2 = polarity score
#   arg3 = preceding word
#   arg4 = pre-preceding word
#   arg5 = pre-pre-preceding word
#   arg6 = pointer to negation hash
#          key: term 
#          val: 1
#   arg7 = proximity match flag
#   arg8 = negation flag
#   r.v. = (prox_Psc, Psc, prox_Nsc, Nsc)
#-----------------------------------------------------------
sub polSC {
    my($pol,$sc,$pwd,$ppwd,$pppwd,$neghp,$proxM,$negflag)=@_;
    my $debug=0;

    my($p1,$p2,$n1,$n2)=(0,0,0,0);

    # preceding word is a negation: e.g. 'not good', 'not so good', 'isn't really very good'
    if ( ($pwd && $neghp->{$pwd}) || ($ppwd && $neghp->{$ppwd}) || ($pppwd && $neghp->{$pppwd}) || $negflag ) {
        if ($pol eq 'n') { 
            $p2 = $sc; 
            $p1 = $sc if ($proxM);
        }
        elsif ($pol eq 'p') { 
            $n2 = $sc; 
            $n1 = $sc if ($proxM);
        }
    }
    else {
        if ($pol eq 'p') { 
            $p2 = $sc; 
            $p1 = $sc if ($proxM);
        }
        elsif ($pol eq 'n') { 
            $n2 = $sc; 
            $n1 = $sc if ($proxM);
        }
    }

    print "polSC: pol=$pol, prx=$proxM, sc=$sc, p1=$p1, p2=$p2, n1=$n1, n2=$n2\n" if ($debug);

    return ($p1,$p2,$n1,$n2);

} #endsub polSC


#------------------------------------------------------------
# add repeat-char compressed terms to lexicon hash
#-----------------------------------------------------------
# arg1 = pointer to lexicon hash
#          key: term, val: [pnm]N
#-----------------------------------------------------------
sub updatelex {
    my($lexhp)=@_;
    my $debug=0;

    # add to lexicon terms w/ compress embedded repeat characters
    #  - exception: e, o
    foreach my $wd(keys %{$lexhp}) {
        my $sc=$lexhp->{$wd};
        print "UpLex: $wd=$sc\n" if ($debug);
        if ($wd=~/([a-cdf-np-z])\1+\B/) {
            $wd=~s/([a-cdf-np-z])\1+\B/$1/g;
            $lexhp->{$wd}=$sc; 
            print "    $wd\n" if ($debug);
        }
    }

} #endsub updatelex

sub updatelex2 {
    my($lexhp)=@_;
    my $debug=0;

    # add to lexicon terms w/ compress embedded repeat characters
    #  - exception: e, o
    foreach my $wd(keys %{$lexhp}) {
        my $scM=$lexhp->{$wd}{'man'};
        my $scC=$lexhp->{$wd}{'combo'};
        my $scP=$lexhp->{$wd}{'prob'};
        print "UpLex: $wd=$scM\n" if ($debug);
        if ($wd=~/([a-cdf-np-z])\1+\B/) {
            $wd=~s/([a-cdf-np-z])\1+\B/$1/g;
            $lexhp->{$wd}{'man'}=$scM; 
            $lexhp->{$wd}{'combo'}=$scC; 
            $lexhp->{$wd}{'prob'}=$scP; 
            print "    $wd\n" if ($debug);
        }
    }

} #endsub updatelex


#------------------------------------------------------------
# compute reranking scores
#   - use length-normalized match count
#-----------------------------------------------------------
# arg1 = document title text
# arg2 = document body text
# arg3 = query length (s, m, l)
# arg3 = query title text
# arg4 = query title text (stopped & stemmed)
# arg5 = query description text (stopped & stemmed)
# arg6 = pointer to noun phrase hash
#          k=noun-phrase, v=freq
# arg7 = pointer to nonrel phrase hash
#          k=noun-phrase, v=freq
# arg8 = pointer to nonrel noun hash
# arg9 = pointer to reranking score hash
#          k= score name, v= score
#          onTopic key values: ti, bd, tix, bdx, bdx2, ph, nrph, nrn
#             ti   - exact match of query title in doc title
#             bd   - exact match of query title in doc body
#             tix  - proximity match of query title in doc title
#             bdx  - proximity match of query title in doc body
#             bdx2 - proximity match of query description in doc body
#             ph   - query phrase match in doc title + body
#             nrph - query non-relevant phrase match in doc title + body
#             nrn  - query non-relevant noun match in doc title + body
#          opinion key values: iu[x][NP],hf[x][NP],lf[x][NP],ac[x][NP],w1[x][NP],w2[x][NP],e[x][NP]
#             e.g  iu   - IU simple match score
#                  iuP  - IU simple positive poloarity match score
#                  iuN  - IU simple negative poloarity match score
#                  iux  - IU proximity match score
#                  iuxP - IU proximity positive polarity match score
#                  iuxN - IU proximity negative polarity match score
#          misc. key values: tlen, iucnt, iucnt2
#                  tlen   - text length in word count
#                  iucnt  - number of I, my, me
#                  iucnt2 - number of you, we, your, our, us
# arg10 = pointer to AC hash
# arg11 = pointer to HF hash
# arg12 = pointer to IU hash
# arg13 = pointer to LF hash
# arg14 = pointer to LF regex hash
# arg15 = pointer to LF regex array
# arg16 = pointer to LF regex score array
# arg17 = pointer to LF morph regex hash
# arg18 = pointer to LF morph regex array
# arg19 = pointer to LF morph regex score array
# arg20 = pointer to Wilson's strong subj hash
# arg21 = pointer to Wilson's weak subj hash
# arg22 = pointer to Wilson's emphasis  hash
# arg23 = flag to select opinion module (optional: default=calopSC)
#-----------------------------------------------------------
# NOTE:  
#   1. phrases are hyphenated 
#   2. compressed form of lexicon terms are not checked for
#   3. hyphens are not compressed
#-----------------------------------------------------------
sub calrrSC {
    my($ti,$bd,$qlen,$qti,$qti2,$qdesc2,$php,$nrphp,$nrnp,$schp,
       $achp,$hfhp,$iuhp,$lfhp,$lfxhp,$lfxlp,$lfxsclp,$lfmhp,$lfmlp,$lfmsclp,$w1hp,$w2hp,$emphp,$opmf)=@_;
    my $debug=0;

    my $QTM='MM--qxmatch--MM',   # query string match placeholder
    my $NOT='MM--negstr--MM';    # negation placeholder
    my $prxwsize=10;             # proximity match window

    # accomodate changes in indexing module (7/20/2007)
    #   - $qti2: words after comma (,) = alternate wordform of special query terms
    $qti2=$1 if ($qti2=~/^(.+?)\s+,/);

    my $text= "$ti $bd";
    my $qlong=1;
    $qlong=0 if ($qlen eq 's');

    my %len;
    # get text length
    #  -%len: k=(ti|bd|qti|qt2|qdesc2), v=token count
    my %hash=('ti'=>$ti,'bd'=>$bd,'qti'=>$qti,'qti2'=>$qti2,'qdesc2'=>$qdesc2);
    foreach my $name(keys %hash) {
        my $var= $hash{$name};
        print "calrrSC: name=$name, var=$var\n" if ($debug);
        if ($var) {
            my @wds= ($var=~/\s+/g);
            $len{$name}= @wds+1;
        }
        else { $len{$name}=0; }
    }

    # $qti: comma (,) = Boolean OR
    #   - convert to rgext OR
    if ($qti=~/^(.+?)\s+OR\b/) {
        my $var=$1; # for qry length
        my @wds= ($var=~/\s+/g);
        $len{'qti'}= @wds+1;
        $qti=~s/\s*OR\s*/|/g;
    }

    my (@wdcnt);
    @wdcnt= ($text=~/\s+/sg);
    $len{'text'}= @wdcnt+1;
    $schp->{'tlen'}= @wdcnt+1;

    # do not compute reranking scores for short documents: !!check!!
    return if ($len{'bd'}<=10);

    # allow for plurals
    $qti .= 's' if ($qti!~/s$/i);

    #------------------------------
    # compute exact match scores
    #   - proportion of match string
    #------------------------------
    # match in doc title
    if (my @hits= $ti=~/\b$qti?\b/ig) {
        if ($debug) { my$hit=@hits; print "calrrSC: tiH=$hit\n"; }
        $schp->{'ti'}= ($len{'qti'}*@hits / $len{'ti'});
    }
    # match in doc body
    #  - compute score only if multiple word query
    if ($qti=~/ /) {
        if (my @hits= $bd=~/\b$qti?\b/ig) {
            if ($debug) { my$hit=@hits; print "calrrSC: bdH=$hit\n"; }
            $schp->{'bd'}= ($len{'qti'}*@hits / $len{'bd'});
        }
    }

    #------------------------------
    # compute proximity match scores of query title
    #  - using stopped & stemmed title text
    #  - proportion of match string
    #------------------------------
    # multiple word query only
    if ($qti2=~/ /) {
        # match in doc title
        #  - allow avg. 2 words between query words
        my $hit1= &swinprox($qti2,$ti,2);
        print "calrrSC: tixH=$hit1\n" if ($debug);
        $schp->{'tix'}= ($len{'qti2'}*$hit1 / $len{'ti'}) if ($hit1);
        # match in doc body
        #  - allow avg. 2 words between query words
        my $hit2= &swinprox($qti2,$bd,2);
        print "calrrSC: bdxH=$hit2\n" if ($debug);
        $schp->{'bdx'}= ($len{'qti2'}*$hit2 / $len{'bd'}) if ($hit2);
    }

    #------------------------------
    # compute proximity match score of query description
    #  - using stopped & stemmed description text
    #  - proportion of match string
    #------------------------------
    # multiple word query only
    if ($qlong && $qdesc2 && $qdesc2=~/ /) {
        # allow avg. 2 words between query words
        my $hit= &swinprox($qdesc2,$bd,2);
        print "calrrSC: bdx2H=$hit\n" if ($debug);
        $schp->{'bdx2'}= ($len{'qdesc2'}*$hit / $len{'bd'}) if ($hit);
    }

    #------------------------------
    # compute phrase match scores
    #  - length-normalized
    #------------------------------
    if ($qlong && $php) {
        foreach my $ph(sort keys %$php) {
            my $phfreq= $$php{$ph};
            
            my @wd=split(/-/,$ph);
            
            # bigram
            if (@wd==2) {
                # allow for plurals
                $wd[0] .= 's' if ($wd[0]!~/s$/i);
                $wd[1] .= 's' if ($wd[1]!~/s$/i);
                if (my @hits= ($text=~/\b$wd[0]? $wd[1]?\b/ig)) {
                    if ($debug) { my$hit=@hits; print "calrrSC: phH1=$hit\n"; } 
                    $schp->{'ph'} += (@hits*$phfreq / $len{'text'});  # phrase wt = qtf
                }
            }
            
            # 3 or more words: exact match except for the last word plural
            else {
                $ph=~s/\-/ /g;
                $ph .= 's' if ($ph!~/s$/i);
                if (my @hits= ($text=~/\b$ph?\b/ig)) {
                    if ($debug) { my$hit=@hits; print "calrrSC: phH2=$hit\n"; } 
                    $schp->{'ph'} += (@hits*$phfreq / $len{'text'});  # phrase wt = qtf
                }
            }
        
        } #end-foreach
    } #end-if ($php)

    #------------------------------
    # compute nonrel phrase scores
    #  - length-normalized
    #------------------------------
    if ($qlong && $nrphp) { 
        foreach my $ph(sort keys %$nrphp) {
            my $phfreq= $$nrphp{$ph};

            my @wd=split(/-/,$ph);

            # bigram
            if (@wd==2) {
                # allow for plurals
                $wd[0] .= 's' if ($wd[0]!~/s$/i);
                $wd[1] .= 's' if ($wd[1]!~/s$/i);
                if (my @hits= $text=~/\b$wd[0]? $wd[1]?\b/ig) {
                    if ($debug) { my$hit=@hits; print "calrrSC: nrphH1=$hit\n"; }
                    $schp->{'nrph'} += (@hits*$phfreq / $len{'text'});  # phrase wt = qtf
                }
            }

            # 3 or more words: exact match except for the last word plural
            else {
                $ph=~s/\-/ /g;
                $ph .= 's' if ($ph!~/s$/i);
                if (my @hits= $text=~/\b$ph?\b/ig) {
                    if ($debug) { my$hit=@hits; print "calrrSC: nrphH2=$hit\n"; }
                    $schp->{'nrph'} += (@hits*$phfreq / $len{'text'});  # phrase wt = qtf
                }
            }

        } #end-foreach
    } #end-if ($nrphp)

    #------------------------------
    # compute nonrel noun scores
    #  - length-normalized
    #------------------------------
    if ($qlong && $nrnp) {
        foreach my $nrn(sort keys %$nrnp) {
            my $nrnfreq= $$nrnp{$nrn};
            $nrn .= 's' if ($nrn!~/s$/i);
            if (my @hits= $text=~/\b$nrn?\b/ig) {
                if ($debug) { my$hit=@hits; print "calrrSC: nrnH=$hit\n"; }
                $schp->{'nrn'} += (@hits*$nrnfreq / $len{'text'});
            }
        }   
    } #end-if ($nrnp)


    #-----------------------------------------------------
    # compute opinion scores
    #  - NOTE: NOT length-normalized (i.e., match count)
    #-----------------------------------------------------
    my ($qtmcnt,$text2)=&preptext($qti,$text,$QTM,$NOT);
    if ($opmf) {
        &calopSC2($text2,$NOT,$QTM,$qtmcnt,$prxwsize,$schp,$achp,$hfhp,$iuhp,$lfhp,$lfxhp,$lfmhp,$w1hp,$w2hp,$emphp);
    }
    else {
        &calopSC($text2,$NOT,$QTM,$qtmcnt,$prxwsize,$schp,
                  $achp,$hfhp,$iuhp,$lfhp,$lfxlp,$lfxsclp,$lfmlp,$lfmsclp,$w1hp,$w2hp,$emphp);
    }


} #endsub calrrSC


#------------------------------------------------------------
# compute reranking scores
#   - use length-normalized match count
#-----------------------------------------------------------
# arg1 = document title text
# arg2 = document body text
# arg3 = pointer to query title hash
#          k= QN, v=title
# arg4 = pointer to query title text (stopped & stemmed)
#          k= QN, v=title2
# arg5 = pointer to query description text (stopped & stemmed)
#          k= QN, v=desc2
# arg6 = pointer to noun phrase hash
#          k1= QN, v= hash pointer
#              k2= phrase, v2= freq
# arg7 = pointer to nonrel phrase hash
#          k1= QN, v= hash pointer
#              k2= nonrel-phrase, v2= freq
# arg8 = pointer to nonrel noun hash
#          k1= QN, v= hash pointer
#              k2= nonrel-noun, v2= freq
# arg9 = pointer to reranking score hash
#          k1= QN (NOTE: 0= query independent scores)
#          v1= hash pointer
#              k2= score name
#              v2= score
#                  onTopic key values: 
#                     ti   - exact match of query title in doc title
#                     bd   - exact match of query title in doc body
#                     tix  - proximity match of query title in doc title
#                     bdx  - proximity match of query title in doc body
#                     bdx2 - proximity match of query description in doc body
#                     ph   - query phrase match in doc title + body
#                     nrph - query non-relevant phrase match in doc title + body
#                     nrn  - query non-relevant noun match in doc title + body
#                  opinion key values (QN=0):  iu[NP],hf[NP],lf[NP],w1[NP],w2[NP],e[NP]
#                  opinion key values (QN!=0): iux[NP],hfx[NP],lfx[NP],w1x[NP],w2x[NP],ex[NP]
#                  e.g iu   - IU simple match score
#                      iuP  - IU simple positive poloarity match score
#                      iuN  - IU simple negative poloarity match score
#                      iux  - IU proximity match score
#                      iuxP - IU proximity positive polarity match score
#                      iuxN - IU proximity negative polarity match score
#                  misc. key values: 
#                      tl   - text length in word count
#                      in1  - number of I, my, me
#                      in2 - number of you, we, your, our, us
# arg10 = pointer to AC hash
# arg11 = pointer to HF hash
# arg12 = pointer to IU hash
# arg13 = pointer to LF hash
# arg14 = pointer to LF regex array
# arg15 = pointer to LF regex score array
# arg16 = pointer to LF morph regex array
# arg17 = pointer to LF morph regex score array
# arg18 = pointer to Wilson's strong subj hash
# arg19 = pointer to Wilson's weak subj hash
# arg20 = pointer to Wilson's emphasis  hash
# arg21 = optional maxwdcnt
# arg22 = optional no term morphing flag
#-----------------------------------------------------------
# NOTE:  
#   1. bdx2, ph, nrph, nrn scores should not be used for short query results
#-----------------------------------------------------------
sub calrrSCall {
    my($ti,$bd,$qtihp,$qti2hp,$qdesc2hp,$phhp,$nrphhp,$nrnhp,$schp,
       $achp,$hfhp,$iuhp,$lfhp,$lfxlp,$lfxsclp,$lfmlp,$lfmsclp,$w1hp,$w2hp,$emphp,$maxwdcnt2,$nomrpf)=@_;
    my $debug=0;

    my $QTM='MM--qxmatch--MM',   # query string match placeholder
    my $NOT='MM--negstr--MM';    # negation placeholder
    my $prxwsize=10;             # proximity match window

    my $minwdcnt=10;             # min. doclen (wdcnt) for processing
    my $maxwdcnt=5000;           # max. number of words to process

    $maxwdcnt=$maxwdcnt2 if ($maxwdcnt2);

    #chomp($bd);

    # do not compute reranking scores for short documents (less than 10 word)
    my @wdcnt= $bd=~/\s+/g;
    return if (@wdcnt+1<=$minwdcnt);

    # truncate long documents to 5000 words
    if (@wdcnt>$maxwdcnt) {
        my @wds;
        @wds[0..$maxwdcnt-1]=split/ +/,$bd;
        $bd= join(" ",@wds);
    }

    my $text= "$ti $bd";
    #-----------------------------------------------------
    # 1. compute topic scores
    #  - NOTE: length-normalized
    # 2. return text tagged with exact query match
    #  - e.g. 'token1 token2$QTM$qn token3 token4$QTM$qn'
    #-----------------------------------------------------
    my $textM=&caltpSCall($ti,$bd,$text,$qtihp,$QTM,$qti2hp,$qdesc2hp,$phhp,$nrphhp,$nrnhp,$schp);

    #-----------------------------------------------------
    # compute opinion scores
    #  - NOTE: NOT length-normalized (i.e., match count)
    #-----------------------------------------------------
    my ($text2)=&preptext0($text,$NOT);
    &calopSCall($text2,$textM,$qtihp,$NOT,$QTM,$prxwsize,$schp,
                $achp,$hfhp,$iuhp,$lfhp,$lfxlp,$lfxsclp,$lfmlp,$lfmsclp,$w1hp,$w2hp,$emphp,$nomrpf);


} #endsub calrrSCall


#------------------------------------------------------------
# compute reranking scores
#   - use length-normalized match count
#-----------------------------------------------------------
# arg1 = document title text
# arg2 = document body text
# arg3 = pointer to query title hash
#          k= QN, v=title
# arg4 = pointer to query title text (stopped & stemmed)
#          k= QN, v=title2
# arg5 = pointer to query description text (stopped & stemmed)
#          k= QN, v=desc2
# arg6 = pointer to noun phrase hash
#          k1= QN, v= hash pointer
#              k2= phrase, v2= freq
# arg7 = pointer to noun phrase hash from web-expanded query
#          k1= QN, v= hash pointer
#              k2= phrase, v2= weight
# arg8 = pointer to nonrel phrase hash
#          k1= QN, v= hash pointer
#              k2= nonrel-phrase, v2= freq
# arg9 = pointer to nonrel noun hash
#          k1= QN, v= hash pointer
#              k2= nonrel-noun, v2= freq
# arg10 = pointer to reranking score hash
#          k1= QN (NOTE: 0= query independent scores)
#          v1= hash pointer
#              k2= score name
#              v2= score
#                  onTopic key values: 
#                     ti   - exact match of query title in doc title
#                     bd   - exact match of query title in doc body
#                     tix  - proximity match of query title in doc title
#                     bdx  - proximity match of query title in doc body
#                     bdx2 - proximity match of query description in doc body
#                     ph   - query phrase match in doc title + body
#                     ph2  - expanded query phrase match in doc title + body
#                     nrph - query non-relevant phrase match in doc title + body
#                     nrn  - query non-relevant noun match in doc title + body
#                  opinion key values (QN=0):  iu[NP],hf[NP],lf[NP],w1[NP],w2[NP],e[NP]
#                  opinion key values (QN!=0): iux[NP],hfx[NP],lfx[NP],w1x[NP],w2x[NP],ex[NP]
#                  opinion key values (QN!=0): iud[NP],hfd[NP],lfd[NP],w1d[NP],w2d[NP],ed[NP]
#                  e.g iu   - IU simple match score
#                      iuP  - IU simple positive poloarity match score
#                      iuN  - IU simple negative poloarity match score
#                      iux  - IU proximity match score
#                      iuxP - IU proximity positive polarity match score
#                      iuxN - IU proximity negative polarity match score
#                      iud  - IU idist match score
#                      iudP - IU idist positive polarity match score
#                      iudN - IU idist negative polarity match score
#                  misc. key values: 
#                      tl   - text length in word count
#                      in1  - number of I, my, me
#                      in2 - number of you, we, your, our, us
# arg10 = pointer to AC hash
# arg11 = pointer to HF hash
# arg12 = pointer to IU hash
# arg13 = pointer to LF hash
# arg14 = pointer to LF regex array
# arg15 = pointer to LF regex score array
# arg16 = pointer to LF morph regex array
# arg17 = pointer to LF morph regex score array
# arg18 = pointer to Wilson's strong subj hash
# arg19 = pointer to Wilson's weak subj hash
# arg20 = pointer to Wilson's emphasis  hash
# arg21 = optional maxwdcnt
# arg22 = optional no term morphing flag
#-----------------------------------------------------------
# NOTE:  
#   1. bdx2, ph, nrph, nrn scores should not be used for short query results
#-----------------------------------------------------------
sub calrrSCall2 {
    my($ti,$bd,$qtihp,$qti2hp,$qdesc2hp,$phhp,$ph2hp,$nrphhp,$nrnhp,$schp,
       $achp,$hfhp,$iuhp,$lfhp,$lfxlp,$lfxsclp,$lfmlp,$lfmsclp,$w1hp,$w2hp,$emphp,$maxwdcnt2,$nomrpf)=@_;
    my $debug=0;

    my $QTM='MM--qxmatch--MM',   # query string match placeholder
    my $NOT='MM--negstr--MM';    # negation placeholder
    my $prxwsize=10;             # proximity match window
    my $maxwdist=20;             # max. word distance for idist score

    my $minwdcnt=10;             # min. doclen (wdcnt) for processing
    my $maxwdcnt=5000;           # max. number of words to process

    $maxwdcnt=$maxwdcnt2 if ($maxwdcnt2);

    #chomp($bd);

    # do not compute reranking scores for short documents (less than 10 word)
    my @wdcnt= $bd=~/\s+/g;
    return if (@wdcnt+1<=$minwdcnt);

    # truncate long documents to 5000 words
    if (@wdcnt>$maxwdcnt) {
        my @wds;
        @wds[0..$maxwdcnt-1]=split/ +/,$bd;
        $bd= join(" ",@wds);
    }

    my $text= "$ti $bd";

    #-----------------------------------------------------
    # 1. compute topic scores
    #  - NOTE: length-normalized
    # 2. return text tagged with exact query match
    #  - e.g. 'token1 token2$QTM$qn token3 token4$QTM$qn'
    #-----------------------------------------------------
    my $textM=&caltpSCall2($ti,$bd,$text,$qtihp,$QTM,$qti2hp,$qdesc2hp,$phhp,$ph2hp,$nrphhp,$nrnhp,$schp);

    #-----------------------------------------------------
    # compute opinion scores
    #  - NOTE: NOT length-normalized (i.e., match count)
    #-----------------------------------------------------
    my ($text2)=&preptext0($text,$NOT);
    &calopSCall2($text2,$textM,$qtihp,$NOT,$QTM,$maxwdist,$prxwsize,$schp,
                $achp,$hfhp,$iuhp,$lfhp,$lfxlp,$lfxsclp,$lfmlp,$lfmsclp,$w1hp,$w2hp,$emphp,$nomrpf);


} #endsub calrrSCall2


# %qti3hp: qn => term => 1
sub calrrSCall3 {
    my($ti,$bd,$qtihp,$qti2hp,$qti3hp,$qdesc2hp,$phhp,$ph2hp,$nrphhp,$nrnhp,$schp,
       $achp,$hfhp,$iuhp,$lfhp,$lfxlp,$lfxsclp,$lfmlp,$lfmsclp,$w1hp,$w2hp,$emphp,$maxwdcnt2,$nomrpf)=@_;
    my $debug=0;

    my $QTM='MM--qxmatch--MM',   # query string match placeholder
    my $QTM2='MM--qxmatch2--MM', # query word match placeholder
    my $NOT='MM--negstr--MM';    # negation placeholder
    my $prxwsize=10;             # proximity match window
    my $maxwdist=20;             # max. word distance for idist score

    my $minwdcnt=10;             # min. doclen (wdcnt) for processing
    my $maxwdcnt=5000;           # max. number of words to process

    $maxwdcnt=$maxwdcnt2 if ($maxwdcnt2);

    #chomp($bd);

    # do not compute reranking scores for short documents (less than 10 word)
    my @wdcnt= $bd=~/\s+/g;
    return if (@wdcnt+1<=$minwdcnt);

    # truncate long documents to 5000 words
    if (@wdcnt>$maxwdcnt) {
        my @wds;
        @wds[0..$maxwdcnt-1]=split/ +/,$bd;
        $bd= join(" ",@wds);
    }

    my $text= "$ti $bd";

    #-----------------------------------------------------
    # 1. compute topic scores
    #  - NOTE: length-normalized
    # 2. return text tagged with exact query match
    #  - e.g. 'token1 token2$QTM$qn token3 token4$QTM$qn'
    #-----------------------------------------------------
    my $textM=&caltpSCall3($ti,$bd,$text,$QTM,$QTM2,$qtihp,$qti2hp,$qti3hp,$qdesc2hp,$phhp,$ph2hp,$nrphhp,$nrnhp,$schp);

    #-----------------------------------------------------
    # compute opinion scores
    #  - NOTE: NOT length-normalized (i.e., match count)
    #-----------------------------------------------------
    my ($text2)=&preptext0($text,$NOT);
    &calopSCall3($text2,$textM,$QTM,$QTM2,$NOT,$maxwdist,$qtihp,$prxwsize,$schp,
                $achp,$hfhp,$iuhp,$lfhp,$lfxlp,$lfxsclp,$lfmlp,$lfmsclp,$w1hp,$w2hp,$emphp,$nomrpf);

    return $textM;

} #endsub calrrSCall3


# AV score added
sub calrrSCall4 {
    my($ti,$bd,$qtihp,$qti2hp,$qti3hp,$qdesc2hp,$phhp,$ph2hp,$nrphhp,$nrnhp,$schp,
       $achp,$hfhp,$iuhp,$lfhp,$lfxlp,$lfxsclp,$lfmlp,$lfmsclp,$w1hp,$w2hp,$emphp,$pavhp,$navhp,
       $maxwdcnt2,$nomrpf)=@_;
    my $debug=0;

    my $QTM='MM--qxmatch--MM',   # query string match placeholder
    my $QTM2='MM--qxmatch2--MM', # query word match placeholder
    my $NOT='MM--negstr--MM';    # negation placeholder
    my $prxwsize=10;             # proximity match window
    my $maxwdist=20;             # max. word distance for idist score

    my $minwdcnt=10;             # min. doclen (wdcnt) for processing
    my $maxwdcnt=5000;           # max. number of words to process

    $maxwdcnt=$maxwdcnt2 if ($maxwdcnt2);

    #chomp($bd);

    # do not compute reranking scores for short documents (less than 10 word)
    my @wdcnt= $bd=~/\s+/g;
    return if (@wdcnt+1<=$minwdcnt);

    # truncate long documents to 5000 words
    if (@wdcnt>$maxwdcnt) {
        my @wds;
        @wds[0..$maxwdcnt-1]=split/ +/,$bd;
        $bd= join(" ",@wds);
    }

    my $text= "$ti $bd";

    #-----------------------------------------------------
    # 1. compute topic scores
    #  - NOTE: length-normalized
    # 2. return text tagged with exact query match
    #  - e.g. 'token1 token2$QTM$qn token3 token4$QTM$qn'
    #-----------------------------------------------------
    my $textM=&caltpSCall3($ti,$bd,$text,$QTM,$QTM2,$qtihp,$qti2hp,$qti3hp,$qdesc2hp,$phhp,$ph2hp,$nrphhp,$nrnhp,$schp);

    #-----------------------------------------------------
    # compute opinion scores
    #  - NOTE: NOT length-normalized (i.e., match count)
    #-----------------------------------------------------
    my ($text2)=&preptext0($text,$NOT);
    &calopSCall4($text2,$textM,$QTM,$QTM2,$NOT,$maxwdist,$qtihp,$prxwsize,$schp,
                $achp,$hfhp,$iuhp,$lfhp,$lfxlp,$lfxsclp,$lfmlp,$lfmsclp,$w1hp,$w2hp,$emphp,$pavhp,$navhp,$nomrpf);

    return $textM;

} #endsub calrrSCall4


# multiple weights per term: manual, combo, probabilistic
sub calrrSCall7 {
    my($ti,$bd,$qtihp,$qti2hp,$qti3hp,$qdesc2hp,$phhp,$ph2hp,$nrphhp,$nrnhp,$schp,$achp,$hfhp,$iuhp,$lfhp,
       $lfxlp,$lfxsclpM,$lfxsclpC,$lfxsclpP,$lfmlp,$lfmsclpM,$lfmsclpC,$lfmsclpP,
       $w1hp,$w2hp,$emphp,$pavhp,$navhp,$maxwdcnt2,$nomrpf)=@_;
    my $debug=0;

    my $QTM='MM--qxmatch--MM',   # query string match placeholder
    my $QTM2='MM--qxmatch2--MM', # query word match placeholder
    my $NOT='MM--negstr--MM';    # negation placeholder
    my $prxwsize=10;             # proximity match window
    my $maxwdist=20;             # max. word distance for idist score

    my $minwdcnt=10;             # min. doclen (wdcnt) for processing
    my $maxwdcnt=5000;           # max. number of words to process

    $maxwdcnt=$maxwdcnt2 if ($maxwdcnt2);

    #chomp($bd);

    # do not compute reranking scores for short documents (less than 10 word)
    my @wdcnt= $bd=~/\s+/g;
    return if (@wdcnt+1<=$minwdcnt);

    # truncate long documents to 5000 words
    if (@wdcnt>$maxwdcnt) {
        my @wds;
        @wds[0..$maxwdcnt-1]=split/ +/,$bd;
        $bd= join(" ",@wds);
    }

    my $text= "$ti $bd";

    #-----------------------------------------------------
    # 1. compute topic scores
    #  - NOTE: length-normalized
    # 2. return text tagged with exact query match
    #  - e.g. 'token1 token2$QTM$qn token3 token4$QTM$qn'
    #-----------------------------------------------------
    my $textM=&caltpSCall3($ti,$bd,$text,$QTM,$QTM2,$qtihp,$qti2hp,$qti3hp,$qdesc2hp,$phhp,$ph2hp,$nrphhp,$nrnhp,$schp);

    #-----------------------------------------------------
    # compute opinion scores
    #  - NOTE: NOT length-normalized (i.e., match count)
    #-----------------------------------------------------
    my ($text2)=&preptext0($text,$NOT);
    &calopSCall7($text2,$textM,$QTM,$QTM2,$NOT,$maxwdist,$qtihp,$prxwsize,$schp,$achp,$hfhp,$iuhp,$lfhp,
                $lfxlp,$lfxsclpM,$lfxsclpC,$lfxsclpP,$lfmlp,$lfmsclpM,$lfmsclpC,$lfmsclpP,
                $w1hp,$w2hp,$emphp,$pavhp,$navhp,$nomrpf);

    return $textM;

} #endsub calrrSCall7



# multiple weights per term: manual, combo, probabilistic
## changes from calrrSCall7, 11/16/2008
#  - prxwsize & maxwdist increased from 10, 20 to 30, 60
#  - caltpSCall4: added $schp->{$qn}{'qtixm'}: 1 if exact title string found in body, 0 otherwise
#  - calopScall8: added 'nothing' to %negwds
sub calrrSCall8 {
    my($ti,$bd,$qtihp,$qti2hp,$qti3hp,$qdesc2hp,$phhp,$ph2hp,$nrphhp,$nrnhp,$schp,$achp,$hfhp,$iuhp,$lfhp,
       $lfxlp,$lfxsclpM,$lfxsclpC,$lfxsclpP,$lfmlp,$lfmsclpM,$lfmsclpC,$lfmsclpP,
       $w1hp,$w2hp,$emphp,$pavhp,$navhp,$maxwdcnt2,$nomrpf)=@_;
    my $debug=0;

    my $QTM='MM--qxmatch--MM',   # query string match placeholder
    my $QTM2='MM--qxmatch2--MM', # query word match placeholder
    my $NOT='MM--negstr--MM';    # negation placeholder
    my $prxwsize=30;             # proximity match window
    my $maxwdist=60;             # max. word distance for idist score

    my $minwdcnt=10;             # min. doclen (wdcnt) for processing
    my $maxwdcnt=5000;           # max. number of words to process

    $maxwdcnt=$maxwdcnt2 if ($maxwdcnt2);

    #chomp($bd);

    # do not compute reranking scores for short documents (less than 10 word)
    my @wdcnt= $bd=~/\s+/g;
    return if (@wdcnt+1<=$minwdcnt);

    # truncate long documents to 5000 words
    if (@wdcnt>$maxwdcnt) {
        my @wds;
        @wds[0..$maxwdcnt-1]=split/ +/,$bd;
        $bd= join(" ",@wds);
    }

    my $text= "$ti $bd";

    #-----------------------------------------------------
    # 1. compute topic scores
    #  - NOTE: length-normalized
    # 2. return text tagged with exact query match
    #  - e.g. 'token1 token2$QTM$qn token3 token4$QTM$qn'
    #-----------------------------------------------------
    my $textM=&caltpSCall4($ti,$bd,$text,$QTM,$QTM2,$qtihp,$qti2hp,$qti3hp,$qdesc2hp,$phhp,$ph2hp,$nrphhp,$nrnhp,$schp);

    #-----------------------------------------------------
    # compute opinion scores
    #  - NOTE: NOT length-normalized (i.e., match count)
    #-----------------------------------------------------
    my ($text2)=&preptext0($text,$NOT);
    &calopSCall8($text2,$textM,$QTM,$QTM2,$NOT,$maxwdist,$qtihp,$prxwsize,$schp,$achp,$hfhp,$iuhp,$lfhp,
                $lfxlp,$lfxsclpM,$lfxsclpC,$lfxsclpP,$lfmlp,$lfmsclpM,$lfmsclpC,$lfmsclpP,
                $w1hp,$w2hp,$emphp,$pavhp,$navhp,$nomrpf);

    return $textM;

} #endsub calrrSCall8



#------------------------------------------------------------
# compute topic reranking scores for all queries
#   - use length-normalized match count
#-----------------------------------------------------------
# arg1 = document title text
# arg2 = document body text
# arg3 = pointer to query title text hash
#          k= QN, v= query title
# arg4 = pointer to query title text hash (stopped & stemmed)
#          k= QN, v= query title
# arg5 = pointer to query description text hash (stopped & stemmed)
#          k= QN, v= query title
# arg6 = pointer to noun phrase hash
#          k1= QN, v1= hash pointer
#              k2= phrase, v2= freq
# arg7 = pointer to nonrel phrase hash
#          k1= QN, v1= hash pointer
#              k2= nonrel_phrase, v2= freq
# arg8 = pointer to nonrel noun hash
#          k1= QN, v1= hash pointer
#              k2= nonrel_noun, v2= freq
# arg9 = pointer to reranking score hash
#          k1= QN (NOTE: 0= query independent scores)
#          v1= hash pointer
#              k2= score name, v= score
#              onTopic key values: 
#                ti   - exact match of query title in doc title
#                bd   - exact match of query title in doc body
#                tix  - proximity match of query title in doc title
#                bdx  - proximity match of query title in doc body
#                bdx2 - proximity match of query description in doc body
#                ph   - query phrase match in doc title + body
#                nrph - query non-relevant phrase match in doc title + body
#                nrn  - query non-relevant noun match in doc title + body
#              misc. key values: tl
#                tl   - text length in word count
#-----------------------------------------------------------
# NOTE:  
#   1. bdx2, ph, nrph, nrn scores should not be used for short query results
#-----------------------------------------------------------
sub caltpSCall {
    my($ti,$bd,$text,$qtihp,$QTM,$qti2hp,$qdesc2hp,$phhp,$nrphhp,$nrnhp,$schp)=@_;
    my $debug=0;

    my ($ti2,$bd2)=($ti,$bd);  # for marking query matches

    my %len0;
    # get document text lengths
    #  -%len0: k=(ti|bd|text), v=token count
    my %hash=('ti'=>$ti,'bd'=>$bd,'text'=>$text);
    foreach my $name(keys %hash) {
        my $var= $hash{$name};
        print "caltpSCall: name=$name, var=$var\n" if ($debug);
        if ($var) {
            my @wds= ($var=~/\s+/g);
            $len0{$name}= @wds+1;
        }
        else { $len0{$name}=0; }
    }
    $schp->{0}{'tl'}= $len0{'text'};

    #--------------------------------------
    # compute topic scores for each query
    #--------------------------------------
    foreach my $qn(keys %$qtihp) {

        # %qtihp,%qti2hp,%qds2hp: k(QN) = v(text)
        # %phhp,%nrphhp,%nrnhp:   k(QN -> term) = v(freq)
        my ($qti,$qti2,$qdesc2)=($qtihp->{$qn},$qti2hp->{$qn},$qdesc2hp->{$qn});
        my ($php,$nrphp,$nrnp)=($phhp->{$qn},$nrphhp->{$qn},$nrnhp->{$qn});

        # accomodate changes in indexing module (7/20/2007)
        #   - $qti2: words after comma (,) = alternate wordform of special query terms
        # NOTE: should be handled in the calling program (e.g. rerankrt13new.pl)
        #$qti2=$1 if ($qti2=~/^(.+?)\s+,/);

        my %len;
        # get query text lengths
        #  -%len: k=(qti|qt2|qdesc2), v=token count
        my %hash=('qti'=>$qti,'qti2'=>$qti2,'qdesc2'=>$qdesc2);
        foreach my $name(keys %hash) {
            my $var= $hash{$name};
            print "caltpSCall: name=$name, var=$var\n" if ($debug);
            if ($var) {
                my @wds= ($var=~/\s+/g);
                $len{$name}= @wds+1;
            }
            else { $len{$name}=0; }
        }

        # allow for plurals
        $qti .= 's' if ($qti!~/s$/i);

        #------------------------------
        # compute exact match scores
        #   - proportion of match string
        #------------------------------
        # match in doc title
        if (my @hits= $ti=~/\b$qti?\b/ig) {
            $ti2=~s/\b($qti?($QTM\d+)*)\b/$1$QTM$qn/ig; 
            if ($debug) { my$hit=@hits; print "caltpSCall: tiH=$hit\n"; }
            $schp->{$qn}{'ti'}= ($len{'qti'}*@hits / $len0{'ti'});
        }
        # match in doc body
        #  - compute score only if multiple word query
        if ($qti=~/ /) {
            if (my @hits= $bd=~/\b$qti?\b/ig) {
                $bd2=~s/\b($qti?($QTM\d+)*)\b/$1$QTM$qn/ig;  
                if ($debug) { my$hit=@hits; print "caltpSCall: bdH=$hit\n"; }
                $schp->{$qn}{'bd'}= ($len{'qti'}*@hits / $len0{'bd'});
            }
        }

        #------------------------------
        # compute proximity match scores of query title
        #  - using stopped & stemmed title text
        #  - proportion of match string
        #------------------------------
        # multiple word query only
        if ($qti2=~/ /) {
            # match in doc title
            #  - allow avg. 2 words between query words
            my $hit1= &swinprox($qti2,$ti,2);
            print "caltpSCall: tixH=$hit1\n" if ($debug);
            $schp->{$qn}{'tix'}= ($len{'qti2'}*$hit1 / $len0{'ti'}) if ($hit1);
            # match in doc body
            #  - allow avg. 2 words between query words
            my $hit2= &swinprox($qti2,$bd,2);
            print "caltpSCall: bdxH=$hit2\n" if ($debug);
            $schp->{$qn}{'bdx'}= ($len{'qti2'}*$hit2 / $len0{'bd'}) if ($hit2);
        }

        #------------------------------
        # compute proximity match score of query description
        #  - using stopped & stemmed description text
        #  - proportion of match string
        #------------------------------
        # multiple word query only
        if ($qdesc2 && $qdesc2=~/ /) {
            # allow avg. 2 words between query words
            my $hit= &swinprox($qdesc2,$bd,2);
            print "caltpSCall: bdx2H=$hit\n" if ($debug);
            $schp->{$qn}{'bdx2'}= ($len{'qdesc2'}*$hit / $len0{'bd'}) if ($hit);
        }

        #------------------------------
        # compute phrase match scores
        #  - length-normalized
        #------------------------------
        if ($php) {
            foreach my $ph(sort keys %$php) {
                my $phfreq= $php->{$ph};
                
                my @wd=split(/-/,$ph);
                
                # bigram
                if (@wd==2) {
                    # allow for plurals
                    $wd[0] .= 's' if ($wd[0]!~/s$/i);
                    $wd[1] .= 's' if ($wd[1]!~/s$/i);
                    if (my @hits= ($text=~/\b$wd[0]? $wd[1]?\b/ig)) {
                        if ($debug) { my$hit=@hits; print "caltpSCall: phH1=$hit\n"; } 
                        $schp->{$qn}{'ph'} += (@hits*$phfreq / $len0{'text'});  # phrase wt = qtf
                    }
                }
                
                # 3 or more words: exact match except for the last word plural
                else {
                    $ph=~s/\-/ /g;
                    $ph .= 's' if ($ph!~/s$/i);
                    if (my @hits= ($text=~/\b$ph?\b/ig)) {
                        if ($debug) { my$hit=@hits; print "caltpSCall: phH2=$hit\n"; } 
                        $schp->{$qn}{'ph'} += (@hits*$phfreq / $len0{'text'});  # phrase wt = qtf
                    }
                }
            
            } #end-foreach
        } #end-if ($php)

        #------------------------------
        # compute nonrel phrase scores
        #  - length-normalized
        #------------------------------
        if ($nrphp) { 
            foreach my $ph(sort keys %$nrphp) {
                my $phfreq= $nrphp->{$ph};

                my @wd=split(/-/,$ph);

                # bigram
                if (@wd==2) {
                    # allow for plurals
                    $wd[0] .= 's' if ($wd[0]!~/s$/i);
                    $wd[1] .= 's' if ($wd[1]!~/s$/i);
                    if (my @hits= $text=~/\b$wd[0]? $wd[1]?\b/ig) {
                        if ($debug) { my$hit=@hits; print "caltpSCall: nrphH1=$hit\n"; }
                        $schp->{$qn}{'nrph'} += (@hits*$phfreq / $len0{'text'});  # phrase wt = qtf
                    }
                }

                # 3 or more words: exact match except for the last word plural
                else {
                    $ph=~s/\-/ /g;
                    $ph .= 's' if ($ph!~/s$/i);
                    if (my @hits= $text=~/\b$ph?\b/ig) {
                        if ($debug) { my$hit=@hits; print "caltpSCall: nrphH2=$hit\n"; }
                        $schp->{$qn}{'nrph'} += (@hits*$phfreq / $len0{'text'});  # phrase wt = qtf
                    }
                }

            } #end-foreach
        } #end-if ($nrphp)

        #------------------------------
        # compute nonrel noun scores
        #  - length-normalized
        #------------------------------
        if ($nrnp) {
            foreach my $nrn(sort keys %$nrnp) {
                my $nrnfreq= $nrnp->{$nrn};
                $nrn .= 's' if ($nrn!~/s$/i);
                if (my @hits= $text=~/\b$nrn?\b/ig) {
                    if ($debug) { my$hit=@hits; print "caltpSCall: nrnH=$hit\n"; }
                    $schp->{$qn}{'nrn'} += (@hits*$nrnfreq / $len0{'text'});
                }
            }   
        } #end-if ($nrnp)

    } #end-foreach $qn

    my $text2= "$ti2 $bd2";  # for opinion scoring proximity match

    return $text2;

} #endsub caltpSCall


#------------------------------------------------------------
# compute topic reranking scores for all queries
#   - use length-normalized match count
#-----------------------------------------------------------
# arg1 = document title text
# arg2 = document body text
# arg3 = document title + body 
# arg4 = query match string
# arg5 = pointer to query title text hash
#          k= QN, v= query title
# arg6 = pointer to query title text hash (stopped & stemmed)
#          k= QN, v= query title
# arg7 = pointer to query description text hash (stopped & stemmed)
#          k= QN, v= query title
# arg8 = pointer to noun phrase hash
#          k1= QN, v1= hash pointer
#              k2= phrase, v2= freq
# arg9 = pointer to expanded noun phrase hash
#          k1= QN, v1= hash pointer
#              k2= noun_phrase, v2= weigh
# arg10 = pointer to nonrel phrase hash
#          k1= QN, v1= hash pointer
#              k2= nonrel_phrase, v2= freq
# arg11 = pointer to nonrel noun hash
#          k1= QN, v1= hash pointer
#              k2= nonrel_noun, v2= freq
# arg12 = pointer to reranking score hash
#          k1= QN (NOTE: 0= query independent scores)
#          v1= hash pointer
#              k2= score name, v= score
#              onTopic key values: 
#                ti   - exact match of query title in doc title
#                bd   - exact match of query title in doc body
#                tix  - proximity match of query title in doc title
#                bdx  - proximity match of query title in doc body
#                bdx2 - proximity match of query description in doc body
#                ph   - query phrase match in doc title + body
#                nrph - query non-relevant phrase match in doc title + body
#                nrn  - query non-relevant noun match in doc title + body
#              misc. key values: tl
#                tl   - text length in word count
#-----------------------------------------------------------
# NOTE:  
#   1. bdx2, ph, nrph, nrn scores should not be used for short query results
#-----------------------------------------------------------
sub caltpSCall2 {
    my($ti,$bd,$text,$qtihp,$QTM,$qti2hp,$qdesc2hp,$phhp,$ph2hp,$nrphhp,$nrnhp,$schp)=@_;
    my $debug=0;

    my ($ti2,$bd2)=($ti,$bd);  # for marking query matches

    my %len0;
    # get document text lengths
    #  -%len0: k=(ti|bd|text), v=token count
    my %hash=('ti'=>$ti,'bd'=>$bd,'text'=>$text);
    foreach my $name(keys %hash) {
        my $var= $hash{$name};
        print "caltpSCall2: name=$name, var=$var\n" if ($debug);
        if ($var) {
            my @wds= ($var=~/\s+/g);
            $len0{$name}= @wds+1;
        }
        else { $len0{$name}=0; }
    }
    $schp->{0}{'tl'}= $len0{'text'};

    #--------------------------------------
    # compute topic scores for each query
    #--------------------------------------
    foreach my $qn(keys %$qtihp) {

        # %qtihp,%qti2hp,%qds2hp: k(QN) = v(text)
        # %phhp,%nrphhp,%nrnhp:   k(QN -> term) = v(freq)
        my ($qti,$qti2,$qdesc2)=($qtihp->{$qn},$qti2hp->{$qn},$qdesc2hp->{$qn});
        my ($php,$ph2p,$nrphp,$nrnp)=($phhp->{$qn},$ph2hp->{$qn},$nrphhp->{$qn},$nrnhp->{$qn});

        # accomodate changes in indexing module (7/20/2007)
        #   - $qti2: words after comma (,) = alternate wordform of special query terms
        # NOTE: should be handled in the calling program (e.g. rerankrt13new.pl)
        #$qti2=$1 if ($qti2=~/^(.+?)\s+,/);

        my %len;
        # get query text lengths
        #  -%len: k=(qti|qt2|qdesc2), v=token count
        my %hash=('qti'=>$qti,'qti2'=>$qti2,'qdesc2'=>$qdesc2);
        foreach my $name(keys %hash) {
            my $var= $hash{$name};
            print "caltpSCall2: name=$name, var=$var\n" if ($debug);
            if ($var) {
                my @wds= ($var=~/\s+/g);
                $len{$name}= @wds+1;
            }
            else { $len{$name}=0; }
        }

        # allow for plurals
        $qti .= 's' if ($qti!~/s$/i);

        #------------------------------
        # compute exact match scores
        #   - proportion of match string
        #------------------------------
        # match in doc title
        if (my @hits= $ti=~/\b$qti?\b/ig) {
            $ti2=~s/\b($qti?($QTM\d+)*)\b/$1$QTM$qn/ig;
            if ($debug) { my$hit=@hits; print "caltpSCall2: tiH=$hit\n"; }
            $schp->{$qn}{'ti'}= ($len{'qti'}*@hits / $len0{'ti'});
        }
        # match in doc body
        #  - compute score only if multiple word query
        if ($qti=~/ /) {
            if (my @hits= $bd=~/\b$qti?\b/ig) {
                $bd2=~s/\b($qti?($QTM\d+)*)\b/$1$QTM$qn/ig;
                if ($debug) { my$hit=@hits; print "caltpSCall2: bdH=$hit\n"; }
                $schp->{$qn}{'bd'}= ($len{'qti'}*@hits / $len0{'bd'});
            }
        }

        #------------------------------
        # compute proximity match scores of query title
        #  - using stopped & stemmed title text
        #  - proportion of match string
        #------------------------------
        # multiple word query only
        if ($qti2=~/ /) {
            # match in doc title
            #  - allow avg. 2 words between query words
            my $hit1= &swinprox($qti2,$ti,2);
            print "caltpSCall2: tixH=$hit1\n" if ($debug);
            $schp->{$qn}{'tix'}= ($len{'qti2'}*$hit1 / $len0{'ti'}) if ($hit1);
            # match in doc body
            #  - allow avg. 2 words between query words
            my $hit2= &swinprox($qti2,$bd,2);
            print "caltpSCall2: bdxH=$hit2\n" if ($debug);
            $schp->{$qn}{'bdx'}= ($len{'qti2'}*$hit2 / $len0{'bd'}) if ($hit2);
        }

        #------------------------------
        # compute proximity match score of query description
        #  - using stopped & stemmed description text
        #  - proportion of match string
        #------------------------------
        # multiple word query only
        if ($qdesc2 && $qdesc2=~/ /) {
            # allow avg. 2 words between query words
            my $hit= &swinprox($qdesc2,$bd,2);
            print "caltpSCall2: bdx2H=$hit\n" if ($debug);
            $schp->{$qn}{'bdx2'}= ($len{'qdesc2'}*$hit / $len0{'bd'}) if ($hit);
        }

        #------------------------------
        # compute phrase match scores
        #  - length-normalized
        #------------------------------
        if ($php) {
            foreach my $ph(sort keys %$php) {
                my $phfreq= $php->{$ph};
                
                my @wd=split(/-/,$ph);
                
                # bigram
                if (@wd==2) {
                    # allow for plurals
                    $wd[0] .= 's' if ($wd[0]!~/s$/i);
                    $wd[1] .= 's' if ($wd[1]!~/s$/i);
                    if (my @hits= ($text=~/\b$wd[0]? $wd[1]?\b/ig)) {
                        if ($debug) { my$hit=@hits; print "caltpSCall2: phH1=$hit\n"; } 
                        $schp->{$qn}{'ph'} += (@hits*$phfreq / $len0{'text'});  # phrase wt = qtf
                    }
                }
                
                # 3 or more words: exact match except for the last word plural
                else {
                    $ph=~s/\-/ /g;
                    $ph .= 's' if ($ph!~/s$/i);
                    if (my @hits= ($text=~/\b$ph?\b/ig)) {
                        if ($debug) { my$hit=@hits; print "caltpSCall2: phH2=$hit\n"; } 
                        $schp->{$qn}{'ph'} += (@hits*$phfreq / $len0{'text'});  # phrase wt = qtf
                    }
                }
            
            } #end-foreach
        } #end-if ($php)

        #------------------------------
        # compute expanded phrase match scores
        #  - length-normalized
        #------------------------------
        if ($ph2p) {
            foreach my $ph(sort keys %$ph2p) {
                my $phwt= $ph2p->{$ph};
                
                my @wd=split(/-/,$ph);
                
                # bigram
                if (@wd==2) {
                    # allow for plurals
                    $wd[0] .= 's' if ($wd[0]!~/s$/i);
                    $wd[1] .= 's' if ($wd[1]!~/s$/i);
                    if (my @hits= ($text=~/\b$wd[0]? $wd[1]?\b/ig)) {
                        if ($debug) { my$hit=@hits; print "caltpSCall2: ph2H1=$hit\n"; } 
                        $schp->{$qn}{'ph2'} += (@hits*$phwt / $len0{'text'});  
                    }
                }
                
            } #end-foreach
        } #end-if ($ph2p)

        #------------------------------
        # compute nonrel phrase scores
        #  - length-normalized
        #------------------------------
        if ($nrphp) { 
            foreach my $ph(sort keys %$nrphp) {
                my $phfreq= $nrphp->{$ph};

                my @wd=split(/-/,$ph);

                # bigram
                if (@wd==2) {
                    # allow for plurals
                    $wd[0] .= 's' if ($wd[0]!~/s$/i);
                    $wd[1] .= 's' if ($wd[1]!~/s$/i);
                    if (my @hits= $text=~/\b$wd[0]? $wd[1]?\b/ig) {
                        if ($debug) { my$hit=@hits; print "caltpSCall2: nrphH1=$hit\n"; }
                        $schp->{$qn}{'nrph'} += (@hits*$phfreq / $len0{'text'});  # phrase wt = qtf
                    }
                }

                # 3 or more words: exact match except for the last word plural
                else {
                    $ph=~s/\-/ /g;
                    $ph .= 's' if ($ph!~/s$/i);
                    if (my @hits= $text=~/\b$ph?\b/ig) {
                        if ($debug) { my$hit=@hits; print "caltpSCall2: nrphH2=$hit\n"; }
                        $schp->{$qn}{'nrph'} += (@hits*$phfreq / $len0{'text'});  # phrase wt = qtf
                    }
                }

            } #end-foreach
        } #end-if ($nrphp)

        #------------------------------
        # compute nonrel noun scores
        #  - length-normalized
        #------------------------------
        if ($nrnp) {
            foreach my $nrn(sort keys %$nrnp) {
                my $nrnfreq= $nrnp->{$nrn};
                $nrn .= 's' if ($nrn!~/s$/i);
                if (my @hits= $text=~/\b$nrn?\b/ig) {
                    if ($debug) { my$hit=@hits; print "caltpSCall2: nrnH=$hit\n"; }
                    $schp->{$qn}{'nrn'} += (@hits*$nrnfreq / $len0{'text'});
                }
            }   
        } #end-if ($nrnp)

    } #end-foreach $qn

    my $text2= "$ti2 $bd2";  # for opinion scoring proximity match

    return $text2;

} #endsub caltpSCall2


sub caltpSCall3 {
    my($ti,$bd,$text,$QTM,$QTM2,$qtihp,$qti2hp,$qti3hp,$qdesc2hp,$phhp,$ph2hp,$nrphhp,$nrnhp,$schp)=@_;
    my $debug=0;

    my ($ti2,$bd2)=($ti,$bd);  # for marking query matches

    my %len0;
    # get document text lengths
    #  -%len0: k=(ti|bd|text), v=token count
    my %hash=('ti'=>$ti,'bd'=>$bd,'text'=>$text);
    foreach my $name(keys %hash) {
        my $var= $hash{$name};
        print "caltpSCall2: name=$name, var=$var\n" if ($debug);
        if ($var) {
            my @wds= ($var=~/\s+/g);
            $len0{$name}= @wds+1;
        }
        else { $len0{$name}=0; }
    }
    $schp->{0}{'tl'}= $len0{'text'};

    #--------------------------------------
    # compute topic scores for each query
    #--------------------------------------
    foreach my $qn(keys %$qtihp) {

        # %qtihp,%qti2hp,%qds2hp: k(QN) = v(text)
        # %phhp,%nrphhp,%nrnhp:   k(QN -> term) = v(freq)
        my ($qti,$qti2,$qdesc2)=($qtihp->{$qn},$qti2hp->{$qn},$qdesc2hp->{$qn});
        my ($php,$ph2p,$nrphp,$nrnp)=($phhp->{$qn},$ph2hp->{$qn},$nrphhp->{$qn},$nrnhp->{$qn});

        # accomodate changes in indexing module (7/20/2007)
        #   - $qti2: words after comma (,) = alternate wordform of special query terms
        # NOTE: should be handled in the calling program (e.g. rerankrt13new.pl)
        #$qti2=$1 if ($qti2=~/^(.+?)\s+,/);

        my %len;
        # get query text lengths
        #  -%len: k=(qti|qt2|qdesc2), v=token count
        my %hash=('qti'=>$qti,'qti2'=>$qti2,'qdesc2'=>$qdesc2);
        foreach my $name(keys %hash) {
            my $var= $hash{$name};
            print "caltpSCall2: name=$name, var=$var\n" if ($debug);
            if ($var) {
                my @wds= ($var=~/\s+/g);
                $len{$name}= @wds+1;
            }
            else { $len{$name}=0; }
        }

        # allow for plurals
        $qti .= 's' if ($qti!~/s$/i);

        #------------------------------
        # compute exact match scores of title string
        #   - proportion of match string
        #------------------------------
        # match in doc title
        if (my @hits= $ti=~/\b$qti?\b/ig) {
            $ti2=~s/\b($qti?($QTM\d+)*)\b/$1$QTM$qn/ig;
            if ($debug) { my$hit=@hits; print "caltpSCall2: tiH=$hit\n"; }
            $schp->{$qn}{'ti'}= ($len{'qti'}*@hits / $len0{'ti'});
        }
        # match in doc body
        #  - compute score only if multiple word query
        #  - !!! consider doing it for single term query as well
        if ($qti=~/ /) {
            if (my @hits= $bd=~/\b$qti?\b/ig) {
                $bd2=~s/\b($qti?($QTM\d+)*)\b/$1$QTM$qn/ig;
                if ($debug) { my$hit=@hits; print "caltpSCall2: bdH=$hit\n"; }
                $schp->{$qn}{'bd'}= ($len{'qti'}*@hits / $len0{'bd'});
            }
        }

        #------------------------------
        # compute exact match scores of title words: !!! added 4/26
        #   - proportion of match string
        #------------------------------
        # match in doc title
        my ($ti2hit,$bd2hit)=(0,0);
        foreach my $wd(keys %{$qti3hp->{$qn}}) {
            if (my @hits= $ti=~/\b$wd\b/ig) {
                $ti2=~s/\b($wd($QTM2\d+)*)\b/$1$QTM2$qn/ig;
                if ($debug) { my$hit=@hits; print "caltpSCall3: tiH=$hit\n"; }
                $ti2hit += @hits;
            }
            # match in doc body
            if (my @hits= $bd=~/\b$wd\b/ig) {
                $bd2=~s/\b($qti?($QTM2\d+)*)\b/$1$QTM2$qn/ig;
                if ($debug) { my$hit=@hits; print "caltpSCall3: bdH=$hit\n"; }
                $bd2hit += @hits;
            }
        }
        $schp->{$qn}{'bd2'}= ($bd2hit / $len{'qti'}*$len0{'bd'});
        $schp->{$qn}{'ti2'}= ($ti2hit / $len{'qti'}*$len0{'ti'});

        #------------------------------
        # compute proximity match scores of query title
        #  - using stopped & stemmed title text
        #  - proportion of match string
        #------------------------------
        # multiple word query only
        if ($qti2=~/ /) {
            # match in doc title
            #  - allow avg. 2 words between query words
            my $hit1= &swinprox($qti2,$ti,2);
            print "caltpSCall2: tixH=$hit1\n" if ($debug);
            $schp->{$qn}{'tix'}= ($len{'qti2'}*$hit1 / $len0{'ti'}) if ($hit1);
            # match in doc body
            #  - allow avg. 2 words between query words
            my $hit2= &swinprox($qti2,$bd,2);
            print "caltpSCall2: bdxH=$hit2\n" if ($debug);
            $schp->{$qn}{'bdx'}= ($len{'qti2'}*$hit2 / $len0{'bd'}) if ($hit2);
        }

        #------------------------------
        # compute proximity match score of query description
        #  - using stopped & stemmed description text
        #  - proportion of match string
        #------------------------------
        # multiple word query only
        if ($qdesc2 && $qdesc2=~/ /) {
            # allow avg. 2 words between query words
            my $hit= &swinprox($qdesc2,$bd,2);
            print "caltpSCall2: bdx2H=$hit\n" if ($debug);
            $schp->{$qn}{'bdx2'}= ($len{'qdesc2'}*$hit / $len0{'bd'}) if ($hit);
        }

        #------------------------------
        # compute phrase match scores
        #  - length-normalized
        #------------------------------
        if ($php) {
            foreach my $ph(sort keys %$php) {
                my $phfreq= $php->{$ph};
                
                my @wd=split(/-/,$ph);
                
                # bigram
                if (@wd==2) {
                    # allow for plurals
                    $wd[0] .= 's' if ($wd[0]!~/s$/i);
                    $wd[1] .= 's' if ($wd[1]!~/s$/i);
                    if (my @hits= ($text=~/\b$wd[0]? $wd[1]?\b/ig)) {
                        if ($debug) { my$hit=@hits; print "caltpSCall2: phH1=$hit\n"; } 
                        $schp->{$qn}{'ph'} += (@hits*$phfreq / $len0{'text'});  # phrase wt = qtf
                    }
                }
                
                # 3 or more words: exact match except for the last word plural
                else {
                    $ph=~s/\-/ /g;
                    $ph .= 's' if ($ph!~/s$/i);
                    if (my @hits= ($text=~/\b$ph?\b/ig)) {
                        if ($debug) { my$hit=@hits; print "caltpSCall2: phH2=$hit\n"; } 
                        $schp->{$qn}{'ph'} += (@hits*$phfreq / $len0{'text'});  # phrase wt = qtf
                    }
                }
            
            } #end-foreach
        } #end-if ($php)

        #------------------------------
        # compute expanded phrase match scores
        #  - length-normalized
        #------------------------------
        if ($ph2p) {
            foreach my $ph(sort keys %$ph2p) {
                my $phwt= $ph2p->{$ph};
                
                my @wd=split(/-/,$ph);
                
                # bigram
                if (@wd==2) {
                    # allow for plurals
                    $wd[0] .= 's' if ($wd[0]!~/s$/i);
                    $wd[1] .= 's' if ($wd[1]!~/s$/i);
                    if (my @hits= ($text=~/\b$wd[0]? $wd[1]?\b/ig)) {
                        if ($debug) { my$hit=@hits; print "caltpSCall2: ph2H1=$hit\n"; } 
                        $schp->{$qn}{'ph2'} += (@hits*$phwt / $len0{'text'});  
                    }
                }
                
            } #end-foreach
        } #end-if ($ph2p)

        #------------------------------
        # compute nonrel phrase scores
        #  - length-normalized
        #------------------------------
        if ($nrphp) { 
            foreach my $ph(sort keys %$nrphp) {
                my $phfreq= $nrphp->{$ph};

                my @wd=split(/-/,$ph);

                # bigram
                if (@wd==2) {
                    # allow for plurals
                    $wd[0] .= 's' if ($wd[0]!~/s$/i);
                    $wd[1] .= 's' if ($wd[1]!~/s$/i);
                    if (my @hits= $text=~/\b$wd[0]? $wd[1]?\b/ig) {
                        if ($debug) { my$hit=@hits; print "caltpSCall2: nrphH1=$hit\n"; }
                        $schp->{$qn}{'nrph'} += (@hits*$phfreq / $len0{'text'});  # phrase wt = qtf
                    }
                }

                # 3 or more words: exact match except for the last word plural
                else {
                    $ph=~s/\-/ /g;
                    $ph .= 's' if ($ph!~/s$/i);
                    if (my @hits= $text=~/\b$ph?\b/ig) {
                        if ($debug) { my$hit=@hits; print "caltpSCall2: nrphH2=$hit\n"; }
                        $schp->{$qn}{'nrph'} += (@hits*$phfreq / $len0{'text'});  # phrase wt = qtf
                    }
                }

            } #end-foreach
        } #end-if ($nrphp)

        #------------------------------
        # compute nonrel noun scores
        #  - length-normalized
        #------------------------------
        if ($nrnp) {
            foreach my $nrn(sort keys %$nrnp) {
                my $nrnfreq= $nrnp->{$nrn};
                $nrn .= 's' if ($nrn!~/s$/i);
                if (my @hits= $text=~/\b$nrn?\b/ig) {
                    if ($debug) { my$hit=@hits; print "caltpSCall2: nrnH=$hit\n"; }
                    $schp->{$qn}{'nrn'} += (@hits*$nrnfreq / $len0{'text'});
                }
            }   
        } #end-if ($nrnp)

    } #end-foreach $qn

    my $text2= "$ti2\n$bd2";  # for opinion scoring proximity match

    return $text2;

} #endsub caltpSCall3


# changes from caltpSCall3, 11/16/2008
#  - added $schp->{$qn}{'qtixm'}: 1 if exact title string found in body, 0 otherwise
sub caltpSCall4 {
    my($ti,$bd,$text,$QTM,$QTM2,$qtihp,$qti2hp,$qti3hp,$qdesc2hp,$phhp,$ph2hp,$nrphhp,$nrnhp,$schp)=@_;
    my $debug=0;

    my ($ti2,$bd2)=($ti,$bd);  # for marking query matches

    my %len0;
    # get document text lengths
    #  -%len0: k=(ti|bd|text), v=token count
    my %hash=('ti'=>$ti,'bd'=>$bd,'text'=>$text);
    foreach my $name(keys %hash) {
        my $var= $hash{$name};
        print "caltpSCall2: name=$name, var=$var\n" if ($debug);
        if ($var) {
            my @wds= ($var=~/\s+/g);
            $len0{$name}= @wds+1;
        }
        else { $len0{$name}=0; }
    }
    $schp->{0}{'tl'}= $len0{'text'};

    #--------------------------------------
    # compute topic scores for each query
    #--------------------------------------
    foreach my $qn(keys %$qtihp) {

        # %qtihp,%qti2hp,%qds2hp: k(QN) = v(text)
        # %phhp,%nrphhp,%nrnhp:   k(QN -> term) = v(freq)
        my ($qti,$qti2,$qdesc2)=($qtihp->{$qn},$qti2hp->{$qn},$qdesc2hp->{$qn});
        my ($php,$ph2p,$nrphp,$nrnp)=($phhp->{$qn},$ph2hp->{$qn},$nrphhp->{$qn},$nrnhp->{$qn});

        # accomodate changes in indexing module (7/20/2007)
        #   - $qti2: words after comma (,) = alternate wordform of special query terms
        # NOTE: should be handled in the calling program (e.g. rerankrt13new.pl)
        #$qti2=$1 if ($qti2=~/^(.+?)\s+,/);

        my %len;
        # get query text lengths
        #  -%len: k=(qti|qt2|qdesc2), v=token count
        my %hash=('qti'=>$qti,'qti2'=>$qti2,'qdesc2'=>$qdesc2);
        foreach my $name(keys %hash) {
            my $var= $hash{$name};
            print "caltpSCall2: name=$name, var=$var\n" if ($debug);
            if ($var) {
                my @wds= ($var=~/\s+/g);
                $len{$name}= @wds+1;
            }
            else { $len{$name}=0; }
        }

        # allow for plurals
        $qti .= 's' if ($qti!~/s$/i);

        # flag if exact query title string occurs in body text
        if ($bd=~/\b$qti?\b/i) { $schp->{$qn}{'qtixm'}=1; }
        else { $schp->{$qn}{'qtixm'}=0; }

        #------------------------------
        # compute exact match scores of title string
        #   - proportion of match string
        #------------------------------
        # match in doc title
        if (my @hits= $ti=~/\b$qti?\b/ig) {
            $ti2=~s/\b($qti?($QTM\d+)*)\b/$1$QTM$qn/ig;
            if ($debug) { my$hit=@hits; print "caltpSCall2: tiH=$hit\n"; }
            $schp->{$qn}{'ti'}= ($len{'qti'}*@hits / $len0{'ti'});
        }
        # match in doc body
        #  - compute score only if multiple word query
        #  - !!! consider doing it for single term query as well
        if ($qti=~/ /) {
            if (my @hits= $bd=~/\b$qti?\b/ig) {
                $bd2=~s/\b($qti?($QTM\d+)*)\b/$1$QTM$qn/ig;
                if ($debug) { my$hit=@hits; print "caltpSCall2: bdH=$hit\n"; }
                $schp->{$qn}{'bd'}= ($len{'qti'}*@hits / $len0{'bd'});
            }
        }

        #------------------------------
        # compute exact match scores of title words: !!! added 4/26
        #   - proportion of match string
        #------------------------------
        # match in doc title
        my ($ti2hit,$bd2hit)=(0,0);
        foreach my $wd(keys %{$qti3hp->{$qn}}) {
            if (my @hits= $ti=~/\b$wd\b/ig) {
                $ti2=~s/\b($wd($QTM2\d+)*)\b/$1$QTM2$qn/ig;
                if ($debug) { my$hit=@hits; print "caltpSCall3: tiH=$hit\n"; }
                $ti2hit += @hits;
            }
            # match in doc body
            if (my @hits= $bd=~/\b$wd\b/ig) {
                $bd2=~s/\b($qti?($QTM2\d+)*)\b/$1$QTM2$qn/ig;
                if ($debug) { my$hit=@hits; print "caltpSCall3: bdH=$hit\n"; }
                $bd2hit += @hits;
            }
        }
        $schp->{$qn}{'bd2'}= ($bd2hit / $len{'qti'}*$len0{'bd'});
        $schp->{$qn}{'ti2'}= ($ti2hit / $len{'qti'}*$len0{'ti'});

        #------------------------------
        # compute proximity match scores of query title
        #  - using stopped & stemmed title text
        #  - proportion of match string
        #------------------------------
        # multiple word query only
        if ($qti2=~/ /) {
            # match in doc title
            #  - allow avg. 2 words between query words
            my $hit1= &swinprox($qti2,$ti,2);
            print "caltpSCall2: tixH=$hit1\n" if ($debug);
            $schp->{$qn}{'tix'}= ($len{'qti2'}*$hit1 / $len0{'ti'}) if ($hit1);
            # match in doc body
            #  - allow avg. 2 words between query words
            my $hit2= &swinprox($qti2,$bd,2);
            print "caltpSCall2: bdxH=$hit2\n" if ($debug);
            $schp->{$qn}{'bdx'}= ($len{'qti2'}*$hit2 / $len0{'bd'}) if ($hit2);
        }

        #------------------------------
        # compute proximity match score of query description
        #  - using stopped & stemmed description text
        #  - proportion of match string
        #------------------------------
        # multiple word query only
        if ($qdesc2 && $qdesc2=~/ /) {
            # allow avg. 2 words between query words
            my $hit= &swinprox($qdesc2,$bd,2);
            print "caltpSCall2: bdx2H=$hit\n" if ($debug);
            $schp->{$qn}{'bdx2'}= ($len{'qdesc2'}*$hit / $len0{'bd'}) if ($hit);
        }

        #------------------------------
        # compute phrase match scores
        #  - length-normalized
        #------------------------------
        if ($php) {
            foreach my $ph(sort keys %$php) {
                my $phfreq= $php->{$ph};
                
                my @wd=split(/-/,$ph);
                
                # bigram
                if (@wd==2) {
                    # allow for plurals
                    $wd[0] .= 's' if ($wd[0]!~/s$/i);
                    $wd[1] .= 's' if ($wd[1]!~/s$/i);
                    if (my @hits= ($text=~/\b$wd[0]? $wd[1]?\b/ig)) {
                        if ($debug) { my$hit=@hits; print "caltpSCall2: phH1=$hit\n"; } 
                        $schp->{$qn}{'ph'} += (@hits*$phfreq / $len0{'text'});  # phrase wt = qtf
                    }
                }
                
                # 3 or more words: exact match except for the last word plural
                else {
                    $ph=~s/\-/ /g;
                    $ph .= 's' if ($ph!~/s$/i);
                    if (my @hits= ($text=~/\b$ph?\b/ig)) {
                        if ($debug) { my$hit=@hits; print "caltpSCall2: phH2=$hit\n"; } 
                        $schp->{$qn}{'ph'} += (@hits*$phfreq / $len0{'text'});  # phrase wt = qtf
                    }
                }
            
            } #end-foreach
        } #end-if ($php)

        #------------------------------
        # compute expanded phrase match scores
        #  - length-normalized
        #------------------------------
        if ($ph2p) {
            foreach my $ph(sort keys %$ph2p) {
                my $phwt= $ph2p->{$ph};
                
                my @wd=split(/-/,$ph);
                
                # bigram
                if (@wd==2) {
                    # allow for plurals
                    $wd[0] .= 's' if ($wd[0]!~/s$/i);
                    $wd[1] .= 's' if ($wd[1]!~/s$/i);
                    if (my @hits= ($text=~/\b$wd[0]? $wd[1]?\b/ig)) {
                        if ($debug) { my$hit=@hits; print "caltpSCall2: ph2H1=$hit\n"; } 
                        $schp->{$qn}{'ph2'} += (@hits*$phwt / $len0{'text'});  
                    }
                }
                
            } #end-foreach
        } #end-if ($ph2p)

        #------------------------------
        # compute nonrel phrase scores
        #  - length-normalized
        #------------------------------
        if ($nrphp) { 
            foreach my $ph(sort keys %$nrphp) {
                my $phfreq= $nrphp->{$ph};

                my @wd=split(/-/,$ph);

                # bigram
                if (@wd==2) {
                    # allow for plurals
                    $wd[0] .= 's' if ($wd[0]!~/s$/i);
                    $wd[1] .= 's' if ($wd[1]!~/s$/i);
                    if (my @hits= $text=~/\b$wd[0]? $wd[1]?\b/ig) {
                        if ($debug) { my$hit=@hits; print "caltpSCall2: nrphH1=$hit\n"; }
                        $schp->{$qn}{'nrph'} += (@hits*$phfreq / $len0{'text'});  # phrase wt = qtf
                    }
                }

                # 3 or more words: exact match except for the last word plural
                else {
                    $ph=~s/\-/ /g;
                    $ph .= 's' if ($ph!~/s$/i);
                    if (my @hits= $text=~/\b$ph?\b/ig) {
                        if ($debug) { my$hit=@hits; print "caltpSCall2: nrphH2=$hit\n"; }
                        $schp->{$qn}{'nrph'} += (@hits*$phfreq / $len0{'text'});  # phrase wt = qtf
                    }
                }

            } #end-foreach
        } #end-if ($nrphp)

        #------------------------------
        # compute nonrel noun scores
        #  - length-normalized
        #------------------------------
        if ($nrnp) {
            foreach my $nrn(sort keys %$nrnp) {
                my $nrnfreq= $nrnp->{$nrn};
                $nrn .= 's' if ($nrn!~/s$/i);
                if (my @hits= $text=~/\b$nrn?\b/ig) {
                    if ($debug) { my$hit=@hits; print "caltpSCall2: nrnH=$hit\n"; }
                    $schp->{$qn}{'nrn'} += (@hits*$nrnfreq / $len0{'text'});
                }
            }   
        } #end-if ($nrnp)

    } #end-foreach $qn

    my $text2= "$ti2\n$bd2";  # for opinion scoring proximity match

    return $text2;

} #endsub caltpSCall3


#------------------------------------------------------------
# compute opinion scores
#   - new version, but takes too long
#-----------------------------------------------------------
# arg1 = text to be scored
# arg2 = negation placeholder
# arg3 = query title match placeholder
# arg4 = query title match count
# arg5 = proximity window size
# arg6 = pointer to opinon score hash
#          k= score name 
#             (iu[x][NP],hf[x][NP],lf[x][NP],w1[x][NP],w2[x][NP],e[x][NP])
#             e.g  iu   - IU simple match score
#                  iuP  - IU simple positive poloarity match score
#                  iuN  - IU simple negative poloarity match score
#                  iux  - IU proximity match score
#                  iuxP - IU proximity positive polarity match score
#                  iuxN - IU proximity negative polarity match score
#          v= score
# arg7 = pointer to IU hash
# arg8 = pointer to HF hash
# arg9 = pointer to LF hash
# arg10 = pointer to LF regex array
# arg11 = pointer to LF regex score array
# arg12 = pointer to LF morph regex array
# arg13 = pointer to LF morph regex score array
# arg14 = pointer to AC hash
# arg15 = pointer to Wilson's strong subj hash
# arg16 = pointer to Wilson's weak subj hash
# arg17 = pointer to Wilson's emphasis  hash
#-----------------------------------------------------------
# NOTE:  
#   1. input text should be prepped w/ preptext
#-----------------------------------------------------------
sub calopSC {
    my($text,$NOT,$QTM,$qtmcnt,$prxwsize,$schp,$achp,$hfhp,$iuhp,$lfhp,$lfxlp,$lfxsclp,$lfmlp,$lfmsclp,$w1hp,$w2hp,$emphp)=@_;
    my $debug=0;

    my %negwds=("not"=>1,"never"=>1,"no"=>1,"without"=>1,"hardly"=>1,"barely"=>1,"scarcely"=>1,
                "$NOT"=>1,"I-NOT"=>1,"ME-NOT"=>1,"MY-NOT"=>1);

    # IU anchor cnt
    my ($iucnt,$iucnt2,@iucnt,@iucnt2)=(0,0); 
    @iucnt= $text=~/\b(I|my|me)\b/gi;
    @iucnt2= $text=~/\b(you|we|your|our|us)\b/gi;
    $iucnt=@iucnt;
    $iucnt2=@iucnt2;
    $schp->{'iucnt'} += $iucnt;
    $schp->{'iucnt2'} += $iucnt2;

    # convert opinion phrase to acronyms:
    #   e.g. 'in my humble opinion' to 'imho'
    foreach my $str(keys %{$achp}) {
        next if ($str !~ / /);  # phrases only
        my $ac= lc(join("",$str=~/\b([A-Za-z])/g));
        $str=~s/I'm/I am/;
        $text=~s/($str)/ $ac $1 /ig if ($text=~/$str/i);
    }   

    print "calopSC: TEXT1=\n$text\n\n" if ($debug);

    #-------------------------------------------------------------------------
    # Normalize IU phrase:
    #  NOTE: some opinion terms can be compressed w/ this normalization
    #-------------------------------------------------------------------------

    # compress select prepositions, conjunctions, articles: for proximity match
    $text=~s/\s+(for|to|over|on|upon|in|with|of|and|or|a|an|the)\s+/ /gi;

    # e.g., 'cannot ever really be truly and completely satisfying to me' to 'every really be truly satisfying ME-NOT'
    $text=~s/\b($NOT\s+([A-Za-z]+\s+){0,6})(me|you|us)\b/$1ME-NOT/gi;

    # e.g., 'cannot really ever truly and unconditionally have my' to 'really ever truly unconditionally have MY-NOT'
    $text=~s/\b($NOT\s+([A-Za-z]+\s+){0,6})(my|your|our)\b/$1MY-NOT/gi;

    # e.g., 'my total and undying support of him really and truly cannot' to 'MY-NOT total undying support really truly cannot'
    $text=~s/\b(my|your|our)\s+(([A-Za-z]+\s+){0,6}$NOT)\s+/MY-NOT $2 /gi;

    # e.g., 'I truly and seriously cannot' to 'I-NOT'
    $text=~s/\b(I|you|we)\s+([A-Za-z]+\s+){0,2}$NOT\s+/I-NOT /gi;

    # e.g., 'I very likely will' to 'I '
    $text=~s/\b(I|you|we)\s+([A-Za-z]+\s+){0,2}(can|could|will|would|shall|should|must|do|did|may|might|am|was|are|were|have to|had to|have|had|need)\s+/I /gi;

    print "calopSC: TEXT2=\n$text\n\n" if ($debug);

    my @wds=split(/[^a-z!\-]+/,lc($text));  # words are converted to lowercase

    my $wdcnt=@wds;

    for(my $i=0; $i<$wdcnt; $i++) {
        next if ($wds[$i]=~/^\s*$/);

        my $word=$wds[$i];

        # compress hyphens
        my $wordh;
        if ($word=~/\-/) {
            # delete leading/trailing hyphen 
            $word=~s/^\-?(.+?)\-?$/$1/;
            $wordh=$word;
            $wordh=~s/\-+//g;
        }

        my ($emp,$emp2)=(0,0);

        # words ending w/ !
        $emp=1 if ($word=~s/!$//);

        # words w/ 3+ repeat characters
        $emp2=1 if ($word=~/([a-z])\1{2,}/i);

        # compress embedded repeat characters
        #  - exception: e, o
        my $wordc;
        if ($word=~/([a-cdf-np-z])\1+\B/) {
            $wordc=$word;
            $wordc=~s/([a-cdf-np-z])\1+\B/$1/g;
        }

        # flag proximity match
        my $prxmatch=0;
        if ($qtmcnt) {
            my $minI=$i-$prxwsize;
            my $maxI=$i+$prxwsize;
            $minI=0 if ($minI<0);
            $maxI=$#wds if ($maxI>$#wds);
            my $proxstr= join(' ',@wds[$minI..$maxI]);
            $prxmatch=1 if ($proxstr=~/$QTM/i);
        }

        # get preceding words (for catching negations)
        my($pwd,$ppwd,$pppwd);  # preceding words
        if ($i>2) { ($pppwd,$ppwd,$pwd)=($wds[$i-3],$wds[$i-2],$wds[$i-1]); }
        elsif ($i>1) { ($ppwd,$pwd)=($wds[$i-2],$wds[$i-1]); }
        elsif ($i>0) { $pwd=$wds[$i-1]; }
        foreach my $wd2($pwd,$ppwd,$pppwd) {
            next if (!$wd2);
            # delete leading/trailing hyphen
            $wd2=~s/^\-?(.+?)\-?$/$1/ if ($wd2=~/\-/);
        }

        print "calopSC: word=$word, emp=$emp, emp2=$emp2, prxm=$prxmatch\n" if ($debug>2);

        #-----------------------------------------
        # flag IU phrase and get adjacent terms

        my ($neg,$iu,$iu2)=(0);
        my ($wd1,$wd2,$wd3,$wd1b,$wd2b,$wd3b);

        if ($word=~/^(I|we|I-NOT)$/i) {
            $neg=1 if ($1=~/\-NOT/i);
            $iu='I';
            # allow for up to 2 words in-between
            #  e.g., "I truly seriously believe",
            if ($i+3 < $wdcnt) { ($wd1,$wd2,$wd3)=($wds[$i+1],$wds[$i+2],$wds[$i+3]); }
            elsif ($i+2 < $wdcnt) { ($wd1,$wd2)=($wds[$i+1],$wds[$i+2]); }
            elsif ($i+1 < $wdcnt) { $wd1=$wds[$i+1]; }
        }

        elsif ($word=~/^(my|your|our|MY-NOT)$/i) {
            $neg=1 if ($1=~/\-NOT/i);
            $iu='my';
            # allow for up to 2 words in-between
            #  e.g., "I truly seriously believe",
            if ($i+3 < $wdcnt) { ($wd1,$wd2,$wd3)=($wds[$i+1],$wds[$i+2],$wds[$i+3]); }
            elsif ($i+2 < $wdcnt) { ($wd1,$wd2)=($wds[$i+1],$wds[$i+2]); }
            elsif ($i+1 < $wdcnt) { $wd1=$wds[$i+1]; }
        }

        elsif ($word=~/^(me|us|ME-NOT)$/i) {
            $neg=1 if ($1=~/\-NOT/i);
            $iu='me';
            # allow for up to 2 words in-between
            #  e.g. "impressed the hell out of me"
            #  NOTE: 'the' & 'of' are already compressed
            if ($i > 2) { ($wd1,$wd2,$wd3)=($wds[$i-1],$wds[$i-2],$wds[$i-3]); }
            elsif ($i > 1) { ($wd1,$wd2)=($wds[$i-1],$wds[$i-2]); }
            elsif ($i > 0) { $wd1=$wds[$i-1]; }
        }

        # NOTE: 'you believe' or 'impressed you'
        elsif ($word=~/^you$/i) {
            $iu='I';
            # allow for up to 2 words in-between
            #  e.g., "you truly seriously believe",
            if ($i+3 < $wdcnt) { ($wd1,$wd2,$wd3)=($wds[$i+1],$wds[$i+2],$wds[$i+3]); }
            elsif ($i+2 < $wdcnt) { ($wd1,$wd2)=($wds[$i+1],$wds[$i+2]); }
            elsif ($i+1 < $wdcnt) { $wd1=$wds[$i+1]; }
            $iu2='me';
            # allow for up to 2 words in-between
            #  e.g. "impressed the hell out of you"
            #  NOTE: 'the' & 'of' are already compressed
            if ($i > 2) { ($wd1b,$wd2b,$wd3b)=($wds[$i-1],$wds[$i-2],$wds[$i-3]); }
            elsif ($i > 1) { ($wd1b,$wd2b)=($wds[$i-1],$wds[$i-2]); }
            elsif ($i > 0) { $wd1b=$wds[$i-1]; }
        }

        # get preceding words (for $iu='me')
        my (@iuwds,%pwds);
        if ($iu) {
            @iuwds= ($wd1,$wd2,$wd3,$wd1b,$wd2b,$wd3b);
            for my $k(0,1,2) {
                my($pwd,$ppwd,$pppwd);  # preceding words
                if ($i>3) {
                    ($pppwd,$ppwd,$pwd)=($wds[$i-3-$k],$wds[$i-2-$k],$wds[$i-1-$k]);
                }
                elsif ($i>2) {
                    ($ppwd,$pwd)=($wds[$i-2-$k],$wds[$i-1-$k]);
                }
                elsif ($i>1) {
                    $pwd=$wds[$i-1-$k];
                }
                foreach my $wd2($pwd,$ppwd,$pppwd) {
                    next if (!$wd2);
                    # delete leading/trailing hyphen
                    $wd2=~s/^\-?(.+?)\-?$/$1/ if ($wd2=~/\-/);
                }
                $pwds{$k}=[$pwd,$ppwd,$pppwd];
            }

            # compute IU opinion scores for each term
            #  - IU anchors need to be matched w/ original only
            my %sc= &IUsc2($word,$emp,$emp2,$prxmatch,$iuhp,\%negwds,$pwd,$ppwd,$pppwd,\%pwds,\@iuwds,$iu,$iu2,$neg);

            # increment opinion scores
            #   %sc key = sc, scP, scN, scx, scxP,scxN
            foreach my $name(keys %sc) {
                my $name2=$name;
                $name2=~s/sc/iu/;
                $schp->{$name2} += $sc{$name};
            }

        }


        #------------------------------------------------------------
        # compute opinion scores for each word form
        #   - original, repeat-char compressed, hyphen compressed
        #   - search is stopped at first match for each opinion module
        #------------------------------------------------------------

        my %found;
        foreach my $wd($word,$wordc,$wordh) {
            next if (!$wd);

            print "calopSC: wd=$wd\n" if ($debug>2);

            if (!$found{'ac'}) {
                my %sc= &HFsc2($wd,$emp,$emp2,$prxmatch,$achp,\%negwds,$pwd,$ppwd,$pppwd);
                # increment opinion scores
                #   %sc key = sc, scP, scN, scx, scxP,scxN
                foreach my $name(keys %sc) {
                    my $name2=$name;
                    $name2=~s/sc/ac/;
                    $schp->{$name2} += $sc{$name};
                }
                # stop when correct wordform is matched
                $found{'ac'}=1 if ($sc{'sc'});  
            }

            if (!$found{'hf'}) {
                my %sc= &HFsc2($wd,$emp,$emp2,$prxmatch,$hfhp,\%negwds,$pwd,$ppwd,$pppwd);
                # increment opinion scores
                #   %sc key = sc, scP, scN, scx, scxP,scxN
                foreach my $name(keys %sc) {
                    my $name2=$name;
                    $name2=~s/sc/hf/;
                    $schp->{$name2} += $sc{$name};
                }
                # stop when correct wordform is matched
                $found{'hf'}=1 if ($sc{'sc'});  
            }

            if (!$found{'lf'}) {
                my %sc= &LFsc2($wd,$emp,$emp2,$prxmatch,$lfhp,$lfxlp,$lfxsclp,$lfmlp,$lfmsclp,\%negwds,$pwd,$ppwd,$pppwd);
                # increment opinion scores
                #   %sc key = sc, scP, scN, scx, scxP,scxN
                foreach my $name(keys %sc) {
                    my $name2=$name;
                    $name2=~s/sc/lf/;
                    $schp->{$name2} += $sc{$name};
                }
                # stop when correct wordform is matched
                $found{'lf'}=1 if ($sc{'sc'});  
            }

            if (!$found{'w1'}) {
                my %sc= &HFsc2($wd,$emp,$emp2,$prxmatch,$w1hp,\%negwds,$pwd,$ppwd,$pppwd);
                # increment opinion scores
                #   %sc key = sc, scP, scN, scx, scxP,scxN
                foreach my $name(keys %sc) {
                    my $name2=$name;
                    $name2=~s/sc/w1/;
                    $schp->{$name2} += $sc{$name};
                }
                # stop when correct wordform is matched
                $found{'w1'}=1 if ($sc{'sc'});  
            }

            if (!$found{'w2'}) {
                my %sc= &HFsc2($wd,$emp,$emp2,$prxmatch,$w2hp,\%negwds,$pwd,$ppwd,$pppwd);
                # increment opinion scores
                #   %sc key = sc, scP, scN, scx, scxP,scxN
                foreach my $name(keys %sc) {
                    my $name2=$name;
                    $name2=~s/sc/w2/;
                    $schp->{$name2} += $sc{$name};
                }
                # stop when correct wordform is matched
                $found{'w2'}=1 if ($sc{'sc'});  
            }

            if (!$found{'emp'}) {
                my %sc= &HFsc2($wd,$emp,$emp2,$prxmatch,$emphp,\%negwds,$pwd,$ppwd,$pppwd);
                # increment opinion scores
                #   %sc key = sc, scP, scN, scx, scxP,scxN
                foreach my $name(keys %sc) {
                    my $name2=$name;
                    $name2=~s/sc/e/;
                    $schp->{$name2} += $sc{$name};
                }
                # stop when correct wordform is matched
                $found{'emp'}=1 if ($sc{'sc'});  
            }

        } #end-foreach my $wd($word,$wordc,$wordh) 

    } #end-for(my $i=0; $i<$wdcnt; $i++) 

} #endsub calopSC


#------------------------------------------------------------
# compute opinion scores for all queries
#-----------------------------------------------------------
# arg1 = text to be scored
# arg2 = text tagged for query match
# arg3 = pointer to query title hash
#          k= QN, v= query title
# arg4 = negation placeholder
# arg5 = query title match placeholder
# arg6 = proximity window size
# arg7 = pointer to opinon score hash
#          k1= QN (NOTE: 0= query independent scores)
#          v1= hash pointer
#              k2= score name 
#              v2= score
#                  opinion key values (QN=0):  iu[NP],hf[NP],lf[NP],w1[NP],w2[NP],e
#                  opinion key values (QN!=0): iux[NP],hfx[NP],lfx[NP],w1x[NP],w2x[NP],ex
#                  e.g iu   - IU simple match score
#                      iuP  - IU simple positive poloarity match score
#                      iuN  - IU simple negative poloarity match score
#                      iux  - IU proximity match score
#                      iuxP - IU proximity positive polarity match score
#                      iuxN - IU proximity negative polarity match score
#                  misc. key values: 
#                      in1  - number of I, my, me
#                      in2  - number of you, we, your, our, us
# arg8 = pointer to IU hash
# arg9 = pointer to HF hash
# arg10 = pointer to LF hash
# arg11 = pointer to LF regex array
# arg12 = pointer to LF regex score array
# arg13 = pointer to LF morph regex array
# arg14 = pointer to LF morph regex score array
# arg15 = pointer to AC hash
# arg16 = pointer to Wilson's strong subj hash
# arg17 = pointer to Wilson's weak subj hash
# arg18 = pointer to Wilson's emphasis  hash
# arg19 = optional no term morphing flag
#-----------------------------------------------------------
# NOTE:  
#   1. $textM is marked w/ query match
#      - e.g. 'token1 token2$QTM$qn token3 token4$QTM$qn'
#   2. $text should be prepped w/ preptext0
#-----------------------------------------------------------
sub calopSCall {
    my($text,$textM,$qthp,$NOT,$QTM,$prxwsize,$schp,
       $achp,$hfhp,$iuhp,$lfhp,$lfxlp,$lfxsclp,$lfmlp,$lfmsclp,$w1hp,$w2hp,$emphp,$nomrpf)=@_;
    my $debug=0;

    my %negwds=("not"=>1,"never"=>1,"no"=>1,"without"=>1,"hardly"=>1,"barely"=>1,"scarcely"=>1,
                "$NOT"=>1,"I-NOT"=>1,"ME-NOT"=>1,"MY-NOT"=>1);

    # IU anchor cnt
    my ($iucnt,$iucnt2,@iucnt,@iucnt2)=(0,0); 
    @iucnt= $text=~/\b(I|my|me)\b/gi;
    @iucnt2= $text=~/\b(you|we|your|our|us)\b/gi;
    $iucnt=@iucnt;
    $iucnt2=@iucnt2;
    $schp->{0}{'in1'} += $iucnt;
    $schp->{0}{'in2'} += $iucnt2;

    # convert opinion phrase to acronyms:
    #   e.g. 'in my humble opinion' to 'imho in my humble opinion'
    foreach my $str(keys %{$achp}) {
        next if ($str !~ / /);  # phrases only
        my $ac= lc(join("",$str=~/\b([A-Za-z])/g));
        $str=~s/I'm/I am/;
        $text=~s/($str)/ $ac $1 /ig if ($text=~/$str/i);
    }   

    print "calopSCall: TEXT1=\n$text\n\n" if ($debug);

    #-------------------------------------------------------------------------
    # Normalize IU phrase:
    #  NOTE: some opinion terms can be compressed w/ this normalization
    #-------------------------------------------------------------------------

    # compress select prepositions, conjunctions, articles: for proximity match
    $text=~s/\s+(for|to|over|on|upon|in|with|of|and|or|a|an|the)\s+/ /gi;

    # e.g., 'cannot ever really be truly and completely satisfying to me' to 'every really be truly satisfying ME-NOT'
    $text=~s/\b($NOT\s+([A-Za-z]+\s+){0,6})(me|you|us)\b/$1ME-NOT/gi;

    # e.g., 'cannot really ever truly and unconditionally have my' to 'really ever truly unconditionally have MY-NOT'
    $text=~s/\b($NOT\s+([A-Za-z]+\s+){0,6})(my|your|our)\b/$1MY-NOT/gi;

    # e.g., 'my total and undying support of him really and truly cannot' to 'MY-NOT total undying support really truly cannot'
    $text=~s/\b(my|your|our)\s+(([A-Za-z]+\s+){0,6}$NOT)\s+/MY-NOT $2 /gi;

    # e.g., 'I truly and seriously cannot' to 'I-NOT'
    $text=~s/\b(I|you|we)\s+([A-Za-z]+\s+){0,2}$NOT\s+/I-NOT /gi;

    # e.g., 'I very likely will' to 'I '
    $text=~s/\b(I|you|we)\s+([A-Za-z]+\s+){0,2}(can|could|will|would|shall|should|must|do|did|may|might|am|was|are|were|have to|had to|have|had|need)\s+/I /gi;

    print "calopSCall: TEXT2=\n$text\n\n" if ($debug);

    # $textM QTM markup has trailing numbers ($qn)
    #   - e.g. 'token1 token2$QTM$qn token3 token4$QTM$qn'
    my @wdsM0=split(/[^a-z!\-\d]+/,lc($textM));
    my @wdsM;

    # exclude non-letter tokens without QTM markup
    #  - to line up @wdsM with @wds
    my %qtmcnt;
    foreach my $wd(@wdsM0) {
        if ($wd=~/\d/) {
            if (my @qns= $wd=~/$QTM(\d+)/ig) {
                foreach my $qn(@qns) { $qtmcnt{$qn}++; }
                push(@wdsM,$wd);
            }   
        }   
        else { push(@wdsM,$wd); }
    }

    # words are converted to lowercase
    my @wds0=split(/[^a-z!\-\d]+/,lc($text));
    my @wds;

    # exclude non-letter tokens
    foreach my $wd(@wds0) {
        next if ($wd=~/\d/);
        push(@wds,$wd); 
    }

    if ($debug) {
        foreach my $qn(sort keys %qtmcnt) { print "calopSCall: QTM $qn match = $qtmcnt{$qn}\n"; }
        for(my $i=0;$i<@wds;$i++) { print "calopSCall: ($i) wd=$wds[$i], wdM=$wdsM[$i]\n"; }
    }

    my $wdcnt=@wds;

    for(my $i=0; $i<$wdcnt; $i++) {
        next if ($wds[$i]=~/^\s*$/);

        my $word=$wds[$i];

        # compress hyphens
        my $wordh;
        if (!$nomrpf && $word=~/\-/) {
            # delete leading/trailing hyphen 
            $word=~s/^\-?(.+?)\-?$/$1/;
            $wordh=$word;
            $wordh=~s/\-+//g;
        }

        my ($emp,$emp2)=(0,0);

        # words ending w/ !
        $emp=1 if ($word=~s/!$//);

        # words w/ 3+ repeat characters
        $emp2=1 if ($word=~/([a-z])\1{2,}/i);

        # compress embedded repeat characters
        #  - exception: e, o
        my $wordc;
        if (!$nomrpf && $word=~/([a-cdf-np-z])\1+\B/) {
            $wordc=$word;
            $wordc=~s/([a-cdf-np-z])\1+\B/$1/g;
        }

        # flag proximity match
        #  - %prxm: k=QN, v=0,1
        my %prxm;
        foreach my $qn(keys %$qthp) {
            my $prxmatch=0;
            # replace query strings
            if ($qtmcnt{$qn}) {
                my $minI=$i-$prxwsize;
                my $maxI=$i+$prxwsize;
                $minI=0 if ($minI<0);
                $maxI=$#wds if ($maxI>$#wds);
                my $proxstr= join(' ',@wdsM[$minI..$maxI]);
                #!!! BUG corrected: 4/21/2008
                # - old code below can match wrong query string
                #$prxmatch=1 if ($proxstr=~/$QTM/i);
                $prxmatch=1 if ($proxstr=~/$QTM$qn/i);
            }
            $prxm{$qn}=$prxmatch;
        }

        # get preceding words (for catching negations)
        my($pwd,$ppwd,$pppwd);  # preceding words
        if ($i>2) { ($pppwd,$ppwd,$pwd)=($wds[$i-3],$wds[$i-2],$wds[$i-1]); }
        elsif ($i>1) { ($ppwd,$pwd)=($wds[$i-2],$wds[$i-1]); }
        elsif ($i>0) { $pwd=$wds[$i-1]; }
        foreach my $wd2($pwd,$ppwd,$pppwd) {
            next if (!$wd2);
            # delete leading/trailing hyphen
            $wd2=~s/^\-?(.+?)\-?$/$1/ if ($wd2=~/\-/);
        }

        print "calopSCall: word=$word, emp=$emp, emp2=$emp2\n" if ($debug>2);

        #-----------------------------------------
        # flag IU phrase and get adjacent terms

        my ($neg,$iu,$iu2)=(0);
        my ($wd1,$wd2,$wd3,$wd1b,$wd2b,$wd3b);

        if ($word=~/^(I|we|I-NOT)$/i) {
            $neg=1 if ($1=~/\-NOT/i);
            $iu='I';
            # allow for up to 2 words in-between
            #  e.g., "I truly seriously believe",
            if ($i+3 < $wdcnt) { ($wd1,$wd2,$wd3)=($wds[$i+1],$wds[$i+2],$wds[$i+3]); }
            elsif ($i+2 < $wdcnt) { ($wd1,$wd2)=($wds[$i+1],$wds[$i+2]); }
            elsif ($i+1 < $wdcnt) { $wd1=$wds[$i+1]; }
        }

        elsif ($word=~/^(my|your|our|MY-NOT)$/i) {
            $neg=1 if ($1=~/\-NOT/i);
            $iu='my';
            # allow for up to 2 words in-between
            #  e.g., "I truly seriously believe",
            if ($i+3 < $wdcnt) { ($wd1,$wd2,$wd3)=($wds[$i+1],$wds[$i+2],$wds[$i+3]); }
            elsif ($i+2 < $wdcnt) { ($wd1,$wd2)=($wds[$i+1],$wds[$i+2]); }
            elsif ($i+1 < $wdcnt) { $wd1=$wds[$i+1]; }
        }

        elsif ($word=~/^(me|us|ME-NOT)$/i) {
            $neg=1 if ($1=~/\-NOT/i);
            $iu='me';
            # allow for up to 2 words in-between
            #  e.g. "impressed the hell out of me"
            #  NOTE: 'the' & 'of' are already compressed
            if ($i > 2) { ($wd1,$wd2,$wd3)=($wds[$i-1],$wds[$i-2],$wds[$i-3]); }
            elsif ($i > 1) { ($wd1,$wd2)=($wds[$i-1],$wds[$i-2]); }
            elsif ($i > 0) { $wd1=$wds[$i-1]; }
        }

        # NOTE: 'you believe' or 'impressed you'
        elsif ($word=~/^you$/i) {
            $iu='I';
            # allow for up to 2 words in-between
            #  e.g., "you truly seriously believe",
            if ($i+3 < $wdcnt) { ($wd1,$wd2,$wd3)=($wds[$i+1],$wds[$i+2],$wds[$i+3]); }
            elsif ($i+2 < $wdcnt) { ($wd1,$wd2)=($wds[$i+1],$wds[$i+2]); }
            elsif ($i+1 < $wdcnt) { $wd1=$wds[$i+1]; }
            $iu2='me';
            # allow for up to 2 words in-between
            #  e.g. "impressed the hell out of you"
            #  NOTE: 'the' & 'of' are already compressed
            if ($i > 2) { ($wd1b,$wd2b,$wd3b)=($wds[$i-1],$wds[$i-2],$wds[$i-3]); }
            elsif ($i > 1) { ($wd1b,$wd2b)=($wds[$i-1],$wds[$i-2]); }
            elsif ($i > 0) { $wd1b=$wds[$i-1]; }
        }

        # get preceding words (for $iu='me')
        my (@iuwds,%pwds);
        if ($iu) {
            @iuwds= ($wd1,$wd2,$wd3,$wd1b,$wd2b,$wd3b);
            for my $k(0,1,2) {
                my($pwd,$ppwd,$pppwd);  # preceding words
                if ($i>3) {
                    ($pppwd,$ppwd,$pwd)=($wds[$i-3-$k],$wds[$i-2-$k],$wds[$i-1-$k]);
                }
                elsif ($i>2) {
                    ($ppwd,$pwd)=($wds[$i-2-$k],$wds[$i-1-$k]);
                }
                elsif ($i>1) {
                    $pwd=$wds[$i-1-$k];
                }
                foreach my $wd2($pwd,$ppwd,$pppwd) {
                    next if (!$wd2);
                    # delete leading/trailing hyphen
                    $wd2=~s/^\-?(.+?)\-?$/$1/ if ($wd2=~/\-/);
                }
                $pwds{$k}=[$pwd,$ppwd,$pppwd];
            }

            #----------------------------------------------------
            # compute IU opinion scores for each term
            #  - IU anchors need to be matched w/ original only
            #----------------------------------------------------

            my %sc= &IUsc3($word,$emp,$emp2,\%prxm,$iuhp,\%negwds,$pwd,$ppwd,$pppwd,\%pwds,\@iuwds,$iu,$iu2,$neg,$nomrpf);

            # increment opinion scores
            #   %sc key1  = QN
            #       key2a = sc,  scP,  scN  (when QN=0: query-independent socres)
            #       key2b = scx, scxP, scxN (when QN!=0: query-dependent socres)
            foreach my $qn(keys %sc) {
                foreach my $name(keys %{$sc{$qn}}) {
                    my $name2=$name;
                    $name2=~s/sc/iu/;
                    $schp->{$qn}{$name2} += $sc{$qn}{$name};
                }
            }

        }


        #------------------------------------------------------------
        # compute opinion scores for each word form
        #   - original, repeat-char compressed, hyphen compressed
        #   - search is stopped at first match for each opinion module
        #------------------------------------------------------------

        my %found;
        foreach my $wd($word,$wordc,$wordh) {
            next if (!$wd);

            print "calopSCall: wd=$wd\n" if ($debug>2);

            if (!$found{'ac'}) {
                my %sc= &HFsc3($wd,$emp,$emp2,\%prxm,$achp,\%negwds,$pwd,$ppwd,$pppwd);
                # increment opinion scores
                #   %sc key1  = QN
                #       key2a = sc,  scP,  scN  (when QN=0: query-independent socres)
                #       key2b = scx, scxP, scxN (when QN!=0: query-dependent socres)
                foreach my $qn(keys %sc) {
                    foreach my $name(keys %{$sc{$qn}}) {
                        my $name2=$name;
                        $name2=~s/sc/ac/;
                        $schp->{$qn}{$name2} += $sc{$qn}{$name};
                    }
                }
                # stop when correct wordform is matched
                $found{'ac'}=1 if ($sc{'sc'});  
            }

            if (!$found{'hf'}) {
                my %sc= &HFsc3($wd,$emp,$emp2,\%prxm,$hfhp,\%negwds,$pwd,$ppwd,$pppwd);
                # increment opinion scores
                #   %sc key1  = QN
                #       key2a = sc,  scP,  scN  (when QN=0: query-independent socres)
                #       key2b = scx, scxP, scxN (when QN!=0: query-dependent socres)
                foreach my $qn(keys %sc) {
                    foreach my $name(keys %{$sc{$qn}}) {
                        my $name2=$name;
                        $name2=~s/sc/hf/;
                        $schp->{$qn}{$name2} += $sc{$qn}{$name};
                        #print "wd=$wd, qn=$qn, name=$name, name2=$name2, sc=$sc{$qn}{$name}\n";
                    }
                }
                # stop when correct wordform is matched
                $found{'hf'}=1 if ($sc{'sc'});  
            }

            if (!$found{'lf'}) {
                my %sc= &LFsc3($wd,$emp,$emp2,\%prxm,$lfhp,$lfxlp,$lfxsclp,$lfmlp,$lfmsclp,\%negwds,$pwd,$ppwd,$pppwd);
                # increment opinion scores
                #   %sc key1  = QN
                #       key2a = sc,  scP,  scN  (when QN=0: query-independent socres)
                #       key2b = scx, scxP, scxN (when QN!=0: query-dependent socres)
                foreach my $qn(keys %sc) {
                    foreach my $name(keys %{$sc{$qn}}) {
                        my $name2=$name;
                        $name2=~s/sc/lf/;
                        $schp->{$qn}{$name2} += $sc{$qn}{$name};
                    }
                }
                # stop when correct wordform is matched
                $found{'lf'}=1 if ($sc{'sc'});  
            }

            if (!$found{'w1'}) {
                my %sc= &HFsc3($wd,$emp,$emp2,\%prxm,$w1hp,\%negwds,$pwd,$ppwd,$pppwd);
                # increment opinion scores
                #   %sc key1  = QN
                #       key2a = sc,  scP,  scN  (when QN=0: query-independent socres)
                #       key2b = scx, scxP, scxN (when QN!=0: query-dependent socres)
                foreach my $qn(keys %sc) {
                    foreach my $name(keys %{$sc{$qn}}) {
                        my $name2=$name;
                        $name2=~s/sc/w1/;
                        $schp->{$qn}{$name2} += $sc{$qn}{$name};
                    }
                }
                # stop when correct wordform is matched
                $found{'w1'}=1 if ($sc{'sc'});  
            }

            if (!$found{'w2'}) {
                my %sc= &HFsc3($wd,$emp,$emp2,\%prxm,$w2hp,\%negwds,$pwd,$ppwd,$pppwd);
                # increment opinion scores
                #   %sc key1  = QN
                #       key2a = sc,  scP,  scN  (when QN=0: query-independent socres)
                #       key2b = scx, scxP, scxN (when QN!=0: query-dependent socres)
                foreach my $qn(keys %sc) {
                    foreach my $name(keys %{$sc{$qn}}) {
                        my $name2=$name;
                        $name2=~s/sc/w2/;
                        $schp->{$qn}{$name2} += $sc{$qn}{$name};
                    }
                }
                # stop when correct wordform is matched
                $found{'w2'}=1 if ($sc{'sc'});  
            }

            if (!$found{'emp'}) {
                my %sc= &HFsc3($wd,$emp,$emp2,\%prxm,$emphp,\%negwds,$pwd,$ppwd,$pppwd);
                # increment opinion scores
                #   %sc key1  = QN
                #       key2a = sc  (when QN=0: query-independent socres)
                #       key2b = scx (when QN!=0: query-dependent socres)
                foreach my $qn(keys %sc) {
                    foreach my $name(keys %{$sc{$qn}}) {
                        my $name2=$name;
                        $name2=~s/sc/e/;
                        $schp->{$qn}{$name2} += $sc{$qn}{$name};
                    }
                }
                # stop when correct wordform is matched
                $found{'emp'}=1 if ($sc{'sc'});  
            }

        } #end-foreach my $wd($word,$wordc,$wordh) 

    } #end-for(my $i=0; $i<$wdcnt; $i++) 

} #endsub calopSCall


#------------------------------------------------------------
# compute opinion scores for all queries
#-----------------------------------------------------------
# arg1 = text to be scored
# arg2 = text tagged for query match
# arg3 = pointer to query title hash
#          k= QN, v= query title
# arg4 = negation placeholder
# arg5 = query title match placeholder
# arg6 = proximity window size
# arg7 = pointer to opinon score hash
#          k1= QN (NOTE: 0= query independent scores)
#          v1= hash pointer
#              k2= score name 
#              v2= score
#                  opinion key values (QN=0):  iu[NP],hf[NP],lf[NP],w1[NP],w2[NP],e
#                  opinion key values (QN!=0): iux[NP],hfx[NP],lfx[NP],w1x[NP],w2x[NP],ex
#                  opinion key values (QN!=0): iud[NP],hfd[NP],lfd[NP],w1d[NP],w2d[NP],ed
#                  e.g iu   - IU simple match score
#                      iuP  - IU simple positive poloarity match score
#                      iuN  - IU simple negative poloarity match score
#                      iux  - IU proximity match score
#                      iuxP - IU proximity positive polarity match score
#                      iuxN - IU proximity negative polarity match score
#                      iud  - IU idist match score
#                      iudP - IU idist positive polarity match score
#                      iudN - IU idist negative polarity match score
#                  misc. key values: 
#                      in1  - number of I, my, me
#                      in2  - number of you, we, your, our, us
# arg8 = pointer to IU hash
# arg9 = pointer to HF hash
# arg10 = pointer to LF hash
# arg11 = pointer to LF regex array
# arg12 = pointer to LF regex score array
# arg13 = pointer to LF morph regex array
# arg14 = pointer to LF morph regex score array
# arg15 = pointer to AC hash
# arg16 = pointer to Wilson's strong subj hash
# arg17 = pointer to Wilson's weak subj hash
# arg18 = pointer to Wilson's emphasis  hash
# arg19 = optional no term morphing flag
#-----------------------------------------------------------
# NOTE:  
#   1. $textM is marked w/ query match
#      - e.g. 'token1 token2$QTM$qn token3 token4$QTM$qn'
#   2. $text should be prepped w/ preptext0
#-----------------------------------------------------------
sub calopSCall2 {
    my($text,$textM,$qthp,$NOT,$QTM,$maxwdist,$prxwsize,$schp,
       $achp,$hfhp,$iuhp,$lfhp,$lfxlp,$lfxsclp,$lfmlp,$lfmsclp,$w1hp,$w2hp,$emphp,$nomrpf)=@_;
    my $debug=0;

    my %negwds=("not"=>1,"never"=>1,"no"=>1,"without"=>1,"hardly"=>1,"barely"=>1,"scarcely"=>1,
                "$NOT"=>1,"I-NOT"=>1,"ME-NOT"=>1,"MY-NOT"=>1);

    # IU anchor cnt
    my ($iucnt,$iucnt2,@iucnt,@iucnt2)=(0,0); 
    @iucnt= $text=~/\b(I|my|me)\b/gi;
    @iucnt2= $text=~/\b(you|we|your|our|us)\b/gi;
    $iucnt=@iucnt;
    $iucnt2=@iucnt2;
    $schp->{0}{'in1'} += $iucnt;
    $schp->{0}{'in2'} += $iucnt2;

    # convert opinion phrase to acronyms:
    #   e.g. 'in my humble opinion' to 'imho in my humble opinion'
    foreach my $str(keys %{$achp}) {
        next if ($str !~ / /);  # phrases only
        my $ac= lc(join("",$str=~/\b([A-Za-z])/g));
        $str=~s/I'm/I am/;
        $text=~s/($str)/ $ac $1 /ig if ($text=~/$str/i);
    }   

    print "calopSCall2: TEXT1=\n$text\n\n" if ($debug);

    #-------------------------------------------------------------------------
    # Normalize IU phrase:
    #  NOTE: some opinion terms can be compressed w/ this normalization
    #-------------------------------------------------------------------------

    # compress select prepositions, conjunctions, articles: for proximity match
    $text=~s/\s+(for|to|over|on|upon|in|with|of|and|or|a|an|the)\s+/ /gi;

    # e.g., 'cannot ever really be truly and completely satisfying to me' to 'every really be truly satisfying ME-NOT'
    $text=~s/\b($NOT\s+([A-Za-z]+\s+){0,6})(me|you|us)\b/$1ME-NOT/gi;

    # e.g., 'cannot really ever truly and unconditionally have my' to 'really ever truly unconditionally have MY-NOT'
    $text=~s/\b($NOT\s+([A-Za-z]+\s+){0,6})(my|your|our)\b/$1MY-NOT/gi;

    # e.g., 'my total and undying support of him really and truly cannot' to 'MY-NOT total undying support really truly cannot'
    $text=~s/\b(my|your|our)\s+(([A-Za-z]+\s+){0,6}$NOT)\s+/MY-NOT $2 /gi;

    # e.g., 'I truly and seriously cannot' to 'I-NOT'
    $text=~s/\b(I|you|we)\s+([A-Za-z]+\s+){0,2}$NOT\s+/I-NOT /gi;

    # e.g., 'I very likely will' to 'I '
    $text=~s/\b(I|you|we)\s+([A-Za-z]+\s+){0,2}(can|could|will|would|shall|should|must|do|did|may|might|am|was|are|were|have to|had to|have|had|need)\s+/I /gi;

    print "calopSCall2: TEXT2=\n$text\n\n" if ($debug);

    # $textM QTM markup has trailing numbers ($qn)
    #   - e.g. 'token1 token2$QTM$qn token3 token4$QTM$qn'
    my @wdsM0=split(/[^a-z!\-\d]+/,lc($textM));
    my @wdsM;

    # exclude non-letter tokens without QTM markup
    #  - to line up @wdsM with @wds
    my %qtmcnt;
    my %qwpos;  # k=QN, v=arry of term positions
    my $pos=0;
    foreach my $wd(@wdsM0) {
        if ($wd=~/\d/) {
            if (my @qns= $wd=~/$QTM(\d+)/ig) {
                foreach my $qn(@qns) { 
                    $qtmcnt{$qn}++; 
                    push(@{$qwpos{$qn}},$pos);
                }
                push(@wdsM,$wd);
                $pos++;
            }   
        }   
        else { 
            push(@wdsM,$wd); 
            $pos++;
        }
    }

    # words are converted to lowercase
    my @wds0=split(/[^a-z!\-\d]+/,lc($text));
    my @wds;

    # exclude non-letter tokens
    foreach my $wd(@wds0) {
        next if ($wd=~/\d/);
        push(@wds,$wd); 
    }

    if ($debug) {
        foreach my $qn(sort keys %qtmcnt) { print "calopSCall2: QTM $qn match = $qtmcnt{$qn}\n"; }
        for(my $i=0;$i<@wds;$i++) { print "calopSCall2: ($i) wd=$wds[$i], wdM=$wdsM[$i]\n"; }
    }

    my $wdcnt=@wds;

    for(my $i=0; $i<$wdcnt; $i++) {
        next if ($wds[$i]=~/^\s*$/);

        my $word=$wds[$i];

        # compress hyphens
        my $wordh;
        if (!$nomrpf && $word=~/\-/) {
            # delete leading/trailing hyphen 
            $word=~s/^\-?(.+?)\-?$/$1/;
            $wordh=$word;
            $wordh=~s/\-+//g;
        }

        my ($emp,$emp2)=(0,0);

        # words ending w/ !
        $emp=1 if ($word=~s/!$//);

        # words w/ 3+ repeat characters
        $emp2=1 if ($word=~/([a-z])\1{2,}/i);

        # compress embedded repeat characters
        #  - exception: e, o
        my $wordc;
        if (!$nomrpf && $word=~/([a-cdf-np-z])\1+\B/) {
            $wordc=$word;
            $wordc=~s/([a-cdf-np-z])\1+\B/$1/g;
        }

        # flag proximity match !
        #  - %prxm: k=QN, v=0,1
        # compute word distance between current word and query match string
        #  - %wdist: k=QN, v=word distance
        my (%wdist,%prxm);
        foreach my $qn(keys %$qthp) {
            my $mindist=1000;
            my $prxmatch=0;
            my $text2=$text;
            # replace query strings
            if ($qtmcnt{$qn}) {
                my $minI=$i-$prxwsize;
                my $maxI=$i+$prxwsize;
                $minI=0 if ($minI<0);
                $maxI=$#wds if ($maxI>$#wds);
                my $proxstr= join(' ',@wdsM[$minI..$maxI]);
                $prxmatch=1 if ($proxstr=~/$QTM$qn/i);
                $mindist= &minDist($i,$qwpos{$qn});
            }
            $prxm{$qn}=$prxmatch;
            $wdist{$qn}=$mindist;
        }

        # get preceding words (for catching negations)
        my($pwd,$ppwd,$pppwd);  # preceding words
        if ($i>2) { ($pppwd,$ppwd,$pwd)=($wds[$i-3],$wds[$i-2],$wds[$i-1]); }
        elsif ($i>1) { ($ppwd,$pwd)=($wds[$i-2],$wds[$i-1]); }
        elsif ($i>0) { $pwd=$wds[$i-1]; }
        foreach my $wd2($pwd,$ppwd,$pppwd) {
            next if (!$wd2);
            # delete leading/trailing hyphen
            $wd2=~s/^\-?(.+?)\-?$/$1/ if ($wd2=~/\-/);
        }

        print "calopSCall2: word=$word, emp=$emp, emp2=$emp2\n" if ($debug>2);

        #-----------------------------------------
        # flag IU phrase and get adjacent terms

        my ($neg,$iu,$iu2)=(0);
        my ($wd1,$wd2,$wd3,$wd1b,$wd2b,$wd3b);

        if ($word=~/^(I|we|I-NOT)$/i) {
            $neg=1 if ($1=~/\-NOT/i);
            $iu='I';
            # allow for up to 2 words in-between
            #  e.g., "I truly seriously believe",
            if ($i+3 < $wdcnt) { ($wd1,$wd2,$wd3)=($wds[$i+1],$wds[$i+2],$wds[$i+3]); }
            elsif ($i+2 < $wdcnt) { ($wd1,$wd2)=($wds[$i+1],$wds[$i+2]); }
            elsif ($i+1 < $wdcnt) { $wd1=$wds[$i+1]; }
        }

        elsif ($word=~/^(my|your|our|MY-NOT)$/i) {
            $neg=1 if ($1=~/\-NOT/i);
            $iu='my';
            # allow for up to 2 words in-between
            #  e.g., "I truly seriously believe",
            if ($i+3 < $wdcnt) { ($wd1,$wd2,$wd3)=($wds[$i+1],$wds[$i+2],$wds[$i+3]); }
            elsif ($i+2 < $wdcnt) { ($wd1,$wd2)=($wds[$i+1],$wds[$i+2]); }
            elsif ($i+1 < $wdcnt) { $wd1=$wds[$i+1]; }
        }

        elsif ($word=~/^(me|us|ME-NOT)$/i) {
            $neg=1 if ($1=~/\-NOT/i);
            $iu='me';
            # allow for up to 2 words in-between
            #  e.g. "impressed the hell out of me"
            #  NOTE: 'the' & 'of' are already compressed
            if ($i > 2) { ($wd1,$wd2,$wd3)=($wds[$i-1],$wds[$i-2],$wds[$i-3]); }
            elsif ($i > 1) { ($wd1,$wd2)=($wds[$i-1],$wds[$i-2]); }
            elsif ($i > 0) { $wd1=$wds[$i-1]; }
        }

        # NOTE: 'you believe' or 'impressed you'
        elsif ($word=~/^you$/i) {
            $iu='I';
            # allow for up to 2 words in-between
            #  e.g., "you truly seriously believe",
            if ($i+3 < $wdcnt) { ($wd1,$wd2,$wd3)=($wds[$i+1],$wds[$i+2],$wds[$i+3]); }
            elsif ($i+2 < $wdcnt) { ($wd1,$wd2)=($wds[$i+1],$wds[$i+2]); }
            elsif ($i+1 < $wdcnt) { $wd1=$wds[$i+1]; }
            $iu2='me';
            # allow for up to 2 words in-between
            #  e.g. "impressed the hell out of you"
            #  NOTE: 'the' & 'of' are already compressed
            if ($i > 2) { ($wd1b,$wd2b,$wd3b)=($wds[$i-1],$wds[$i-2],$wds[$i-3]); }
            elsif ($i > 1) { ($wd1b,$wd2b)=($wds[$i-1],$wds[$i-2]); }
            elsif ($i > 0) { $wd1b=$wds[$i-1]; }
        }

        # get preceding words (for $iu='me')
        my (@iuwds,%pwds);
        if ($iu) {
            @iuwds= ($wd1,$wd2,$wd3,$wd1b,$wd2b,$wd3b);
            for my $k(0,1,2) {
                my($pwd,$ppwd,$pppwd);  # preceding words
                if ($i>3) {
                    ($pppwd,$ppwd,$pwd)=($wds[$i-3-$k],$wds[$i-2-$k],$wds[$i-1-$k]);
                }
                elsif ($i>2) {
                    ($ppwd,$pwd)=($wds[$i-2-$k],$wds[$i-1-$k]);
                }
                elsif ($i>1) {
                    $pwd=$wds[$i-1-$k];
                }
                foreach my $wd2($pwd,$ppwd,$pppwd) {
                    next if (!$wd2);
                    # delete leading/trailing hyphen
                    $wd2=~s/^\-?(.+?)\-?$/$1/ if ($wd2=~/\-/);
                }
                $pwds{$k}=[$pwd,$ppwd,$pppwd];
            }

            #----------------------------------------------------
            # compute IU opinion scores for each term
            #  - IU anchors need to be matched w/ original only
            #----------------------------------------------------

            my %sc= &IUsc4($word,$emp,$emp2,\%prxm,\%wdist,$iuhp,\%negwds,$pwd,$ppwd,$pppwd,\%pwds,\@iuwds,$iu,$iu2,$neg,$nomrpf);

            # increment opinion scores
            #   %sc key1  = QN
            #       key2a = sc,  scP,  scN  (when QN=0: query-independent socres)
            #       key2b = scx, scxP, scxN (when QN!=0: query-dependent socres)
            foreach my $qn(keys %sc) {
                foreach my $name(keys %{$sc{$qn}}) {
                    my $name2=$name;
                    $name2=~s/sc/iu/;
                    $schp->{$qn}{$name2} += $sc{$qn}{$name};
                }
            }

        }


        #------------------------------------------------------------
        # compute opinion scores for each word form
        #   - original, repeat-char compressed, hyphen compressed
        #   - search is stopped at first match for each opinion module
        #------------------------------------------------------------

        my %found;
        foreach my $wd($word,$wordc,$wordh) {
            next if (!$wd);

            print "calopSCall2: wd=$wd\n" if ($debug>2);

            if (!$found{'ac'}) {
                my %sc= &HFsc4($wd,$emp,$emp2,\%prxm,\%wdist,$maxwdist,$achp,\%negwds,$pwd,$ppwd,$pppwd);
                # increment opinion scores
                #   %sc key1  = QN
                #       key2a = sc,  scP,  scN  (when QN=0: query-independent socres)
                #       key2b = scx, scxP, scxN (when QN!=0: query-dependent socres)
                foreach my $qn(keys %sc) {
                    foreach my $name(keys %{$sc{$qn}}) {
                        my $name2=$name;
                        $name2=~s/sc/ac/;
                        $schp->{$qn}{$name2} += $sc{$qn}{$name};
                    }
                }
                # stop when correct wordform is matched
                $found{'ac'}=1 if ($sc{'sc'});  
            }

            if (!$found{'hf'}) {
                my %sc= &HFsc4($wd,$emp,$emp2,\%prxm,\%wdist,$maxwdist,$hfhp,\%negwds,$pwd,$ppwd,$pppwd);
                # increment opinion scores
                #   %sc key1  = QN
                #       key2a = sc,  scP,  scN  (when QN=0: query-independent socres)
                #       key2b = scx, scxP, scxN (when QN!=0: query-dependent socres)
                foreach my $qn(keys %sc) {
                    foreach my $name(keys %{$sc{$qn}}) {
                        my $name2=$name;
                        $name2=~s/sc/hf/;
                        $schp->{$qn}{$name2} += $sc{$qn}{$name};
                        #print "wd=$wd, qn=$qn, name=$name, name2=$name2, sc=$sc{$qn}{$name}\n";
                    }
                }
                # stop when correct wordform is matched
                $found{'hf'}=1 if ($sc{'sc'});  
            }

            if (!$found{'lf'}) {
                my %sc= &LFsc4($wd,$emp,$emp2,\%prxm,\%wdist,$maxwdist,$lfhp,$lfxlp,$lfxsclp,$lfmlp,$lfmsclp,\%negwds,$pwd,$ppwd,$pppwd);
                # increment opinion scores
                #   %sc key1  = QN
                #       key2a = sc,  scP,  scN  (when QN=0: query-independent socres)
                #       key2b = scx, scxP, scxN (when QN!=0: query-dependent socres)
                foreach my $qn(keys %sc) {
                    foreach my $name(keys %{$sc{$qn}}) {
                        my $name2=$name;
                        $name2=~s/sc/lf/;
                        $schp->{$qn}{$name2} += $sc{$qn}{$name};
                    }
                }
                # stop when correct wordform is matched
                $found{'lf'}=1 if ($sc{'sc'});  
            }

            if (!$found{'w1'}) {
                my %sc= &HFsc4($wd,$emp,$emp2,\%prxm,\%wdist,$maxwdist,$w1hp,\%negwds,$pwd,$ppwd,$pppwd);
                # increment opinion scores
                #   %sc key1  = QN
                #       key2a = sc,  scP,  scN  (when QN=0: query-independent socres)
                #       key2b = scx, scxP, scxN (when QN!=0: query-dependent socres)
                foreach my $qn(keys %sc) {
                    foreach my $name(keys %{$sc{$qn}}) {
                        my $name2=$name;
                        $name2=~s/sc/w1/;
                        $schp->{$qn}{$name2} += $sc{$qn}{$name};
                    }
                }
                # stop when correct wordform is matched
                $found{'w1'}=1 if ($sc{'sc'});  
            }

            if (!$found{'w2'}) {
                my %sc= &HFsc4($wd,$emp,$emp2,\%prxm,\%wdist,$maxwdist,$w2hp,\%negwds,$pwd,$ppwd,$pppwd);
                # increment opinion scores
                #   %sc key1  = QN
                #       key2a = sc,  scP,  scN  (when QN=0: query-independent socres)
                #       key2b = scx, scxP, scxN (when QN!=0: query-dependent socres)
                foreach my $qn(keys %sc) {
                    foreach my $name(keys %{$sc{$qn}}) {
                        my $name2=$name;
                        $name2=~s/sc/w2/;
                        $schp->{$qn}{$name2} += $sc{$qn}{$name};
                    }
                }
                # stop when correct wordform is matched
                $found{'w2'}=1 if ($sc{'sc'});  
            }

            if (!$found{'emp'}) {
                my %sc= &HFsc4($wd,$emp,$emp2,\%prxm,\%wdist,$maxwdist,$emphp,\%negwds,$pwd,$ppwd,$pppwd);
                # increment opinion scores
                #   %sc key1  = QN
                #       key2a = sc  (when QN=0: query-independent socres)
                #       key2b = scx (when QN!=0: query-dependent socres)
                foreach my $qn(keys %sc) {
                    foreach my $name(keys %{$sc{$qn}}) {
                        my $name2=$name;
                        $name2=~s/sc/e/;
                        $schp->{$qn}{$name2} += $sc{$qn}{$name};
                    }
                }
                # stop when correct wordform is matched
                $found{'emp'}=1 if ($sc{'sc'});  
            }

        } #end-foreach my $wd($word,$wordc,$wordh) 

    } #end-for(my $i=0; $i<$wdcnt; $i++) 

} #endsub calopSCall2


sub calopSCall3 {
    my($text,$textM,$QTM,$QTM2,$NOT,$maxwdist,$qthp,$prxwsize,$schp,
       $achp,$hfhp,$iuhp,$lfhp,$lfxlp,$lfxsclp,$lfmlp,$lfmsclp,$w1hp,$w2hp,$emphp,$nomrpf)=@_;
    my $debug=0;

    my %negwds=("not"=>1,"never"=>1,"no"=>1,"without"=>1,"hardly"=>1,"barely"=>1,"scarcely"=>1,
                "$NOT"=>1,"I-NOT"=>1,"ME-NOT"=>1,"MY-NOT"=>1);

    # IU anchor cnt
    my ($iucnt,$iucnt2,@iucnt,@iucnt2)=(0,0); 
    @iucnt= $text=~/\b(I|my|me)\b/gi;
    @iucnt2= $text=~/\b(you|we|your|our|us)\b/gi;
    $iucnt=@iucnt;
    $iucnt2=@iucnt2;
    $schp->{0}{'in1'} += $iucnt;
    $schp->{0}{'in2'} += $iucnt2;

    # convert opinion phrase to acronyms:
    #   e.g. 'in my humble opinion' to 'imho in my humble opinion'
    foreach my $str(keys %{$achp}) {
        next if ($str !~ / /);  # phrases only
        my $ac= lc(join("",$str=~/\b([A-Za-z])/g));
        $str=~s/I'm/I am/;
        $text=~s/($str)/ $ac $1 /ig if ($text=~/$str/i);
    }   

    print "calopSCall2: TEXT1=\n$text\n\n" if ($debug);

    #-------------------------------------------------------------------------
    # Normalize IU phrase:
    #  NOTE: some opinion terms can be compressed w/ this normalization
    #-------------------------------------------------------------------------

    # compress select prepositions, conjunctions, articles: for proximity match
    $text=~s/\s+(for|to|over|on|upon|in|with|of|and|or|a|an|the)\s+/ /gi;

    # e.g., 'cannot ever really be truly and completely satisfying to me' to 'every really be truly satisfying ME-NOT'
    $text=~s/\b($NOT\s+([A-Za-z]+\s+){0,6})(me|you|us)\b/$1ME-NOT/gi;

    # e.g., 'cannot really ever truly and unconditionally have my' to 'really ever truly unconditionally have MY-NOT'
    $text=~s/\b($NOT\s+([A-Za-z]+\s+){0,6})(my|your|our)\b/$1MY-NOT/gi;

    # e.g., 'my total and undying support of him really and truly cannot' to 'MY-NOT total undying support really truly cannot'
    $text=~s/\b(my|your|our)\s+(([A-Za-z]+\s+){0,6}$NOT)\s+/MY-NOT $2 /gi;

    # e.g., 'I truly and seriously cannot' to 'I-NOT'
    $text=~s/\b(I|you|we)\s+([A-Za-z]+\s+){0,2}$NOT\s+/I-NOT /gi;

    # e.g., 'I very likely will' to 'I '
    $text=~s/\b(I|you|we)\s+([A-Za-z]+\s+){0,2}(can|could|will|would|shall|should|must|do|did|may|might|am|was|are|were|have to|had to|have|had|need)\s+/I /gi;

    print "calopSCall2: TEXT2=\n$text\n\n" if ($debug);

    # $textM QTM markup has trailing numbers ($qn)
    #   - e.g. 'token1 token2$QTM$qn token3 token4$QTM$qn'
    my @wdsM0=split(/[^a-z!\-\d]+/,lc($textM));
    my @wdsM;

    # exclude non-letter tokens without QTM markup
    #  - to line up @wdsM with @wds
    my %qtmcnt;
    my %qtm2cnt;
    my %qwpos;  # k=QN, v=arry of term positions for whole query string
    my %qwpos2;  # k=QN, v=arry of term positions for query word
    my $pos=0;
    foreach my $wd(@wdsM0) {
        if ($wd=~/\d/) {
            my $added=0;
            if (my @qns= $wd=~/$QTM(\d+)/ig) {
                foreach my $qn(@qns) { 
                    $qtmcnt{$qn}++; 
                    push(@{$qwpos{$qn}},$pos);
                }
                push(@wdsM,$wd);
                $pos++;
                $added=1;
            }   
            if (my @qns= $wd=~/$QTM2(\d+)/ig) {
                foreach my $qn(@qns) { 
                    $qtm2cnt{$qn}++; 
                    push(@{$qwpos2{$qn}},$pos);
                }
                if (!$added) {
                    push(@wdsM,$wd);
                    $pos++;
                }
            }   
        }   
        else { 
            push(@wdsM,$wd); 
            $pos++;
        }
    }

    # words are converted to lowercase
    my @wds0=split(/[^a-z!\-\d]+/,lc($text));
    my @wds;

    # exclude non-letter tokens
    foreach my $wd(@wds0) {
        next if ($wd=~/\d/);
        push(@wds,$wd); 
    }

    if ($debug) {
        foreach my $qn(sort keys %qtmcnt) { print "calopSCall2: QTM $qn match = $qtmcnt{$qn}\n"; }
        for(my $i=0;$i<@wds;$i++) { print "calopSCall2: ($i) wd=$wds[$i], wdM=$wdsM[$i]\n"; }
    }

    my $wdcnt=@wds;

    for(my $i=0; $i<$wdcnt; $i++) {
        next if ($wds[$i]=~/^\s*$/);

        my $word=$wds[$i];

        # compress hyphens
        my $wordh;
        if (!$nomrpf && $word=~/\-/) {
            # delete leading/trailing hyphen 
            $word=~s/^\-?(.+?)\-?$/$1/;
            $wordh=$word;
            $wordh=~s/\-+//g;
        }

        my ($emp,$emp2)=(0,0);

        # words ending w/ !
        $emp=1 if ($word=~s/!$//);

        # words w/ 3+ repeat characters
        $emp2=1 if ($word=~/([a-z])\1{2,}/i);

        # compress embedded repeat characters
        #  - exception: e, o
        my $wordc;
        if (!$nomrpf && $word=~/([a-cdf-np-z])\1+\B/) {
            $wordc=$word;
            $wordc=~s/([a-cdf-np-z])\1+\B/$1/g;
        }

        # flag proximity match !
        #  - %prxm: k=QN, v=0,1
        # compute word distance between current word and query string
        #  - %wdist: k=QN, v=word distance
        # compute word distance between current word and query word
        #  - %wdist2: k=QN, v=word distance
        my (%wdist,%wdist2,%prxm);
        foreach my $qn(keys %$qthp) {
            my $mindist=1000;
            my $mindist2=1000;
            my $prxmatch=0;
            my $text2=$text;
            # replace query strings
            if ($qtmcnt{$qn}) {
                my $minI=$i-$prxwsize;
                my $maxI=$i+$prxwsize;
                $minI=0 if ($minI<0);
                $maxI=$#wds if ($maxI>$#wds);
                my $proxstr= join(' ',@wdsM[$minI..$maxI]);
                $prxmatch=1 if ($proxstr=~/$QTM$qn/i);
                $mindist= &minDist($i,$qwpos{$qn});
                $mindist2= &minDist($i,$qwpos2{$qn});
            }
            $prxm{$qn}=$prxmatch;
            $wdist{$qn}=$mindist;
            $wdist2{$qn}=$mindist2;
        }

        # get preceding words (for catching negations)
        my($pwd,$ppwd,$pppwd);  # preceding words
        if ($i>2) { ($pppwd,$ppwd,$pwd)=($wds[$i-3],$wds[$i-2],$wds[$i-1]); }
        elsif ($i>1) { ($ppwd,$pwd)=($wds[$i-2],$wds[$i-1]); }
        elsif ($i>0) { $pwd=$wds[$i-1]; }
        foreach my $wd2($pwd,$ppwd,$pppwd) {
            next if (!$wd2);
            # delete leading/trailing hyphen
            $wd2=~s/^\-?(.+?)\-?$/$1/ if ($wd2=~/\-/);
        }

        print "calopSCall2: word=$word, emp=$emp, emp2=$emp2\n" if ($debug>2);

        #-----------------------------------------
        # flag IU phrase and get adjacent terms

        my ($neg,$iu,$iu2)=(0);
        my ($wd1,$wd2,$wd3,$wd1b,$wd2b,$wd3b);

        if ($word=~/^(I|we|I-NOT)$/i) {
            $neg=1 if ($1=~/\-NOT/i);
            $iu='I';
            # allow for up to 2 words in-between
            #  e.g., "I truly seriously believe",
            if ($i+3 < $wdcnt) { ($wd1,$wd2,$wd3)=($wds[$i+1],$wds[$i+2],$wds[$i+3]); }
            elsif ($i+2 < $wdcnt) { ($wd1,$wd2)=($wds[$i+1],$wds[$i+2]); }
            elsif ($i+1 < $wdcnt) { $wd1=$wds[$i+1]; }
        }

        elsif ($word=~/^(my|your|our|MY-NOT)$/i) {
            $neg=1 if ($1=~/\-NOT/i);
            $iu='my';
            # allow for up to 2 words in-between
            #  e.g., "I truly seriously believe",
            if ($i+3 < $wdcnt) { ($wd1,$wd2,$wd3)=($wds[$i+1],$wds[$i+2],$wds[$i+3]); }
            elsif ($i+2 < $wdcnt) { ($wd1,$wd2)=($wds[$i+1],$wds[$i+2]); }
            elsif ($i+1 < $wdcnt) { $wd1=$wds[$i+1]; }
        }

        elsif ($word=~/^(me|us|ME-NOT)$/i) {
            $neg=1 if ($1=~/\-NOT/i);
            $iu='me';
            # allow for up to 2 words in-between
            #  e.g. "impressed the hell out of me"
            #  NOTE: 'the' & 'of' are already compressed
            if ($i > 2) { ($wd1,$wd2,$wd3)=($wds[$i-1],$wds[$i-2],$wds[$i-3]); }
            elsif ($i > 1) { ($wd1,$wd2)=($wds[$i-1],$wds[$i-2]); }
            elsif ($i > 0) { $wd1=$wds[$i-1]; }
        }

        # NOTE: 'you believe' or 'impressed you'
        elsif ($word=~/^you$/i) {
            $iu='I';
            # allow for up to 2 words in-between
            #  e.g., "you truly seriously believe",
            if ($i+3 < $wdcnt) { ($wd1,$wd2,$wd3)=($wds[$i+1],$wds[$i+2],$wds[$i+3]); }
            elsif ($i+2 < $wdcnt) { ($wd1,$wd2)=($wds[$i+1],$wds[$i+2]); }
            elsif ($i+1 < $wdcnt) { $wd1=$wds[$i+1]; }
            $iu2='me';
            # allow for up to 2 words in-between
            #  e.g. "impressed the hell out of you"
            #  NOTE: 'the' & 'of' are already compressed
            if ($i > 2) { ($wd1b,$wd2b,$wd3b)=($wds[$i-1],$wds[$i-2],$wds[$i-3]); }
            elsif ($i > 1) { ($wd1b,$wd2b)=($wds[$i-1],$wds[$i-2]); }
            elsif ($i > 0) { $wd1b=$wds[$i-1]; }
        }

        # get preceding words (for $iu='me')
        my (@iuwds,%pwds);
        if ($iu) {
            @iuwds= ($wd1,$wd2,$wd3,$wd1b,$wd2b,$wd3b);
            for my $k(0,1,2) {
                my($pwd,$ppwd,$pppwd);  # preceding words
                if ($i>3) {
                    ($pppwd,$ppwd,$pwd)=($wds[$i-3-$k],$wds[$i-2-$k],$wds[$i-1-$k]);
                }
                elsif ($i>2) {
                    ($ppwd,$pwd)=($wds[$i-2-$k],$wds[$i-1-$k]);
                }
                elsif ($i>1) {
                    $pwd=$wds[$i-1-$k];
                }
                foreach my $wd2($pwd,$ppwd,$pppwd) {
                    next if (!$wd2);
                    # delete leading/trailing hyphen
                    $wd2=~s/^\-?(.+?)\-?$/$1/ if ($wd2=~/\-/);
                }
                $pwds{$k}=[$pwd,$ppwd,$pppwd];
            }

            #----------------------------------------------------
            # compute IU opinion scores for each term
            #  - IU anchors need to be matched w/ original only
            #----------------------------------------------------

            my %sc= &IUsc5($word,$emp,$emp2,\%prxm,\%wdist,\%wdist2,$maxwdist,$iuhp,\%negwds,$pwd,$ppwd,$pppwd,\%pwds,\@iuwds,$iu,$iu2,$neg,$nomrpf);

            # increment opinion scores
            #   %sc key1  = QN
            #       key2a = sc,  scP,  scN  (when QN=0: query-independent socres)
            #       key2b = scx, scxP, scxN (when QN!=0: query-dependent socres)
            foreach my $qn(keys %sc) {
                foreach my $name(keys %{$sc{$qn}}) {
                    my $name2=$name;
                    $name2=~s/sc/iu/;
                    $schp->{$qn}{$name2} += $sc{$qn}{$name};
                }
            }

        }


        #------------------------------------------------------------
        # compute opinion scores for each word form
        #   - original, repeat-char compressed, hyphen compressed
        #   - search is stopped at first match for each opinion module
        #------------------------------------------------------------

        my %found;
        foreach my $wd($word,$wordc,$wordh) {
            next if (!$wd);

            print "calopSCall2: wd=$wd\n" if ($debug>2);

            if (!$found{'ac'}) {
                my %sc= &HFsc5($wd,$emp,$emp2,\%prxm,\%wdist,\%wdist2,$maxwdist,$achp,\%negwds,$pwd,$ppwd,$pppwd);
                # increment opinion scores
                #   %sc key1  = QN
                #       key2a = sc,  scP,  scN  (when QN=0: query-independent socres)
                #       key2b = scx, scxP, scxN (when QN!=0: query-dependent socres)
                foreach my $qn(keys %sc) {
                    foreach my $name(keys %{$sc{$qn}}) {
                        my $name2=$name;
                        $name2=~s/sc/ac/;
                        $schp->{$qn}{$name2} += $sc{$qn}{$name};
                    }
                }
                # stop when correct wordform is matched
                $found{'ac'}=1 if ($sc{'sc'});  
            }

            if (!$found{'hf'}) {
                my %sc= &HFsc5($wd,$emp,$emp2,\%prxm,\%wdist,\%wdist2,$maxwdist,$hfhp,\%negwds,$pwd,$ppwd,$pppwd);
                # increment opinion scores
                #   %sc key1  = QN
                #       key2a = sc,  scP,  scN  (when QN=0: query-independent socres)
                #       key2b = scx, scxP, scxN (when QN!=0: query-dependent socres)
                foreach my $qn(keys %sc) {
                    foreach my $name(keys %{$sc{$qn}}) {
                        my $name2=$name;
                        $name2=~s/sc/hf/;
                        $schp->{$qn}{$name2} += $sc{$qn}{$name};
                        #print "wd=$wd, qn=$qn, name=$name, name2=$name2, sc=$sc{$qn}{$name}\n";
                    }
                }
                # stop when correct wordform is matched
                $found{'hf'}=1 if ($sc{'sc'});  
            }

            if (!$found{'lf'}) {
                my %sc= &LFsc5($wd,$emp,$emp2,\%prxm,\%wdist,\%wdist2,$maxwdist,$lfhp,$lfxlp,$lfxsclp,$lfmlp,$lfmsclp,\%negwds,$pwd,$ppwd,$pppwd);
                # increment opinion scores
                #   %sc key1  = QN
                #       key2a = sc,  scP,  scN  (when QN=0: query-independent socres)
                #       key2b = scx, scxP, scxN (when QN!=0: query-dependent socres)
                foreach my $qn(keys %sc) {
                    foreach my $name(keys %{$sc{$qn}}) {
                        my $name2=$name;
                        $name2=~s/sc/lf/;
                        $schp->{$qn}{$name2} += $sc{$qn}{$name};
                    }
                }
                # stop when correct wordform is matched
                $found{'lf'}=1 if ($sc{'sc'});  
            }

            if (!$found{'w1'}) {
                my %sc= &HFsc5($wd,$emp,$emp2,\%prxm,\%wdist,\%wdist2,$maxwdist,$w1hp,\%negwds,$pwd,$ppwd,$pppwd);
                # increment opinion scores
                #   %sc key1  = QN
                #       key2a = sc,  scP,  scN  (when QN=0: query-independent socres)
                #       key2b = scx, scxP, scxN (when QN!=0: query-dependent socres)
                foreach my $qn(keys %sc) {
                    foreach my $name(keys %{$sc{$qn}}) {
                        my $name2=$name;
                        $name2=~s/sc/w1/;
                        $schp->{$qn}{$name2} += $sc{$qn}{$name};
                    }
                }
                # stop when correct wordform is matched
                $found{'w1'}=1 if ($sc{'sc'});  
            }

            if (!$found{'w2'}) {
                my %sc= &HFsc5($wd,$emp,$emp2,\%prxm,\%wdist,\%wdist2,$maxwdist,$w2hp,\%negwds,$pwd,$ppwd,$pppwd);
                # increment opinion scores
                #   %sc key1  = QN
                #       key2a = sc,  scP,  scN  (when QN=0: query-independent socres)
                #       key2b = scx, scxP, scxN (when QN!=0: query-dependent socres)
                foreach my $qn(keys %sc) {
                    foreach my $name(keys %{$sc{$qn}}) {
                        my $name2=$name;
                        $name2=~s/sc/w2/;
                        $schp->{$qn}{$name2} += $sc{$qn}{$name};
                    }
                }
                # stop when correct wordform is matched
                $found{'w2'}=1 if ($sc{'sc'});  
            }

            if (!$found{'emp'}) {
                my %sc= &HFsc5($wd,$emp,$emp2,\%prxm,\%wdist,\%wdist2,$maxwdist,$emphp,\%negwds,$pwd,$ppwd,$pppwd);
                # increment opinion scores
                #   %sc key1  = QN
                #       key2a = sc  (when QN=0: query-independent socres)
                #       key2b = scx (when QN!=0: query-dependent socres)
                foreach my $qn(keys %sc) {
                    foreach my $name(keys %{$sc{$qn}}) {
                        my $name2=$name;
                        $name2=~s/sc/e/;
                        $schp->{$qn}{$name2} += $sc{$qn}{$name};
                    }
                }
                # stop when correct wordform is matched
                $found{'emp'}=1 if ($sc{'sc'});  
            }

        } #end-foreach my $wd($word,$wordc,$wordh) 

    } #end-for(my $i=0; $i<$wdcnt; $i++) 

} #endsub calopSCall3


# AVsc added
sub calopSCall4 {
    my($text,$textM,$QTM,$QTM2,$NOT,$maxwdist,$qthp,$prxwsize,$schp,
       $achp,$hfhp,$iuhp,$lfhp,$lfxlp,$lfxsclp,$lfmlp,$lfmsclp,$w1hp,$w2hp,$emphp,$pavhp,$navhp,$nomrpf)=@_;
    my $debug=0;

    my %negwds=("not"=>1,"never"=>1,"no"=>1,"without"=>1,"hardly"=>1,"barely"=>1,"scarcely"=>1,
                "$NOT"=>1,"I-NOT"=>1,"ME-NOT"=>1,"MY-NOT"=>1);

    # IU anchor cnt
    my ($iucnt,$iucnt2,@iucnt,@iucnt2)=(0,0); 
    @iucnt= $text=~/\b(I|my|me)\b/gi;
    @iucnt2= $text=~/\b(you|we|your|our|us)\b/gi;
    $iucnt=@iucnt;
    $iucnt2=@iucnt2;
    $schp->{0}{'in1'} += $iucnt;
    $schp->{0}{'in2'} += $iucnt2;

    # convert opinion phrase to acronyms:
    #   e.g. 'in my humble opinion' to 'imho in my humble opinion'
    foreach my $str(keys %{$achp}) {
        next if ($str !~ / /);  # phrases only
        my $ac= lc(join("",$str=~/\b([A-Za-z])/g));
        $str=~s/I'm/I am/;
        $text=~s/($str)/ $ac $1 /ig if ($text=~/$str/i);
    }   

    print "calopSCall2: TEXT1=\n$text\n\n" if ($debug);

    #-------------------------------------------------------------------------
    # Normalize IU phrase:
    #  NOTE: some opinion terms can be compressed w/ this normalization
    #-------------------------------------------------------------------------

    # compress select prepositions, conjunctions, articles: for proximity match
    $text=~s/\s+(for|to|over|on|upon|in|with|of|and|or|a|an|the)\s+/ /gi;

    # e.g., 'cannot ever really be truly and completely satisfying to me' to 'every really be truly satisfying ME-NOT'
    $text=~s/\b($NOT\s+([A-Za-z]+\s+){0,6})(me|you|us)\b/$1ME-NOT/gi;

    # e.g., 'cannot really ever truly and unconditionally have my' to 'really ever truly unconditionally have MY-NOT'
    $text=~s/\b($NOT\s+([A-Za-z]+\s+){0,6})(my|your|our)\b/$1MY-NOT/gi;

    # e.g., 'my total and undying support of him really and truly cannot' to 'MY-NOT total undying support really truly cannot'
    $text=~s/\b(my|your|our)\s+(([A-Za-z]+\s+){0,6}$NOT)\s+/MY-NOT $2 /gi;

    # e.g., 'I truly and seriously cannot' to 'I-NOT'
    $text=~s/\b(I|you|we)\s+([A-Za-z]+\s+){0,2}$NOT\s+/I-NOT /gi;

    # e.g., 'I very likely will' to 'I '
    $text=~s/\b(I|you|we)\s+([A-Za-z]+\s+){0,2}(can|could|will|would|shall|should|must|do|did|may|might|am|was|are|were|have to|had to|have|had|need)\s+/I /gi;

    print "calopSCall2: TEXT2=\n$text\n\n" if ($debug);

    # $textM QTM markup has trailing numbers ($qn)
    #   - e.g. 'token1 token2$QTM$qn token3 token4$QTM$qn'
    my @wdsM0=split(/[^a-z!\-\d]+/,lc($textM));
    my @wdsM;

    # exclude non-letter tokens without QTM markup
    #  - to line up @wdsM with @wds
    my %qtmcnt;
    my %qtm2cnt;
    my %qwpos;  # k=QN, v=arry of term positions for whole query string
    my %qwpos2;  # k=QN, v=arry of term positions for query word
    my $pos=0;
    foreach my $wd(@wdsM0) {
        if ($wd=~/\d/) {
            my $added=0;
            if (my @qns= $wd=~/$QTM(\d+)/ig) {
                foreach my $qn(@qns) { 
                    $qtmcnt{$qn}++; 
                    push(@{$qwpos{$qn}},$pos);
                }
                push(@wdsM,$wd);
                $pos++;
                $added=1;
            }   
            if (my @qns= $wd=~/$QTM2(\d+)/ig) {
                foreach my $qn(@qns) { 
                    $qtm2cnt{$qn}++; 
                    push(@{$qwpos2{$qn}},$pos);
                }
                if (!$added) {
                    push(@wdsM,$wd);
                    $pos++;
                }
            }   
        }   
        else { 
            push(@wdsM,$wd); 
            $pos++;
        }
    }

    # words are converted to lowercase
    my @wds0=split(/[^a-z!\-\d]+/,lc($text));
    my @wds;

    # exclude non-letter tokens
    foreach my $wd(@wds0) {
        next if ($wd=~/\d/);
        push(@wds,$wd); 
    }

    if ($debug) {
        foreach my $qn(sort keys %qtmcnt) { print "calopSCall2: QTM $qn match = $qtmcnt{$qn}\n"; }
        for(my $i=0;$i<@wds;$i++) { print "calopSCall2: ($i) wd=$wds[$i], wdM=$wdsM[$i]\n"; }
    }

    my $wdcnt=@wds;

    for(my $i=0; $i<$wdcnt; $i++) {
        next if ($wds[$i]=~/^\s*$/);

        my $word=$wds[$i];

        # compress hyphens
        my $wordh;
        if (!$nomrpf && $word=~/\-/) {
            # delete leading/trailing hyphen 
            $word=~s/^\-?(.+?)\-?$/$1/;
            $wordh=$word;
            $wordh=~s/\-+//g;
        }

        my ($emp,$emp2)=(0,0);

        # words ending w/ !
        $emp=1 if ($word=~s/!$//);

        # words w/ 3+ repeat characters
        $emp2=1 if ($word=~/([a-z])\1{2,}/i);

        # compress embedded repeat characters
        #  - exception: e, o
        my $wordc;
        if (!$nomrpf && $word=~/([a-cdf-np-z])\1+\B/) {
            $wordc=$word;
            $wordc=~s/([a-cdf-np-z])\1+\B/$1/g;
        }

        # flag proximity match !
        #  - %prxm: k=QN, v=0,1
        # compute word distance between current word and query string
        #  - %wdist: k=QN, v=word distance
        # compute word distance between current word and query word
        #  - %wdist2: k=QN, v=word distance
        my (%wdist,%wdist2,%prxm);
        foreach my $qn(keys %$qthp) {
            my $mindist=1000;
            my $mindist2=1000;
            my $prxmatch=0;
            my $text2=$text;
            # replace query strings
            if ($qtmcnt{$qn}) {
                my $minI=$i-$prxwsize;
                my $maxI=$i+$prxwsize;
                $minI=0 if ($minI<0);
                $maxI=$#wds if ($maxI>$#wds);
                my $proxstr= join(' ',@wdsM[$minI..$maxI]);
                $prxmatch=1 if ($proxstr=~/$QTM$qn/i);
                $mindist= &minDist($i,$qwpos{$qn});
                $mindist2= &minDist($i,$qwpos2{$qn});
            }
            $prxm{$qn}=$prxmatch;
            $wdist{$qn}=$mindist;
            $wdist2{$qn}=$mindist2;
        }

        # get preceding words (for catching negations)
        my($pwd,$ppwd,$pppwd);  # preceding words
        if ($i>2) { ($pppwd,$ppwd,$pwd)=($wds[$i-3],$wds[$i-2],$wds[$i-1]); }
        elsif ($i>1) { ($ppwd,$pwd)=($wds[$i-2],$wds[$i-1]); }
        elsif ($i>0) { $pwd=$wds[$i-1]; }
        foreach my $wd2($pwd,$ppwd,$pppwd) {
            next if (!$wd2);
            # delete leading/trailing hyphen
            $wd2=~s/^\-?(.+?)\-?$/$1/ if ($wd2=~/\-/);
        }

        print "calopSCall2: word=$word, emp=$emp, emp2=$emp2\n" if ($debug>2);

        #-----------------------------------------
        # flag IU phrase and get adjacent terms

        my ($neg,$iu,$iu2)=(0);
        my ($wd1,$wd2,$wd3,$wd1b,$wd2b,$wd3b);

        if ($word=~/^(I|we|I-NOT)$/i) {
            $neg=1 if ($1=~/\-NOT/i);
            $iu='I';
            # allow for up to 2 words in-between
            #  e.g., "I truly seriously believe",
            if ($i+3 < $wdcnt) { ($wd1,$wd2,$wd3)=($wds[$i+1],$wds[$i+2],$wds[$i+3]); }
            elsif ($i+2 < $wdcnt) { ($wd1,$wd2)=($wds[$i+1],$wds[$i+2]); }
            elsif ($i+1 < $wdcnt) { $wd1=$wds[$i+1]; }
        }

        elsif ($word=~/^(my|your|our|MY-NOT)$/i) {
            $neg=1 if ($1=~/\-NOT/i);
            $iu='my';
            # allow for up to 2 words in-between
            #  e.g., "I truly seriously believe",
            if ($i+3 < $wdcnt) { ($wd1,$wd2,$wd3)=($wds[$i+1],$wds[$i+2],$wds[$i+3]); }
            elsif ($i+2 < $wdcnt) { ($wd1,$wd2)=($wds[$i+1],$wds[$i+2]); }
            elsif ($i+1 < $wdcnt) { $wd1=$wds[$i+1]; }
        }

        elsif ($word=~/^(me|us|ME-NOT)$/i) {
            $neg=1 if ($1=~/\-NOT/i);
            $iu='me';
            # allow for up to 2 words in-between
            #  e.g. "impressed the hell out of me"
            #  NOTE: 'the' & 'of' are already compressed
            if ($i > 2) { ($wd1,$wd2,$wd3)=($wds[$i-1],$wds[$i-2],$wds[$i-3]); }
            elsif ($i > 1) { ($wd1,$wd2)=($wds[$i-1],$wds[$i-2]); }
            elsif ($i > 0) { $wd1=$wds[$i-1]; }
        }

        # NOTE: 'you believe' or 'impressed you'
        elsif ($word=~/^you$/i) {
            $iu='I';
            # allow for up to 2 words in-between
            #  e.g., "you truly seriously believe",
            if ($i+3 < $wdcnt) { ($wd1,$wd2,$wd3)=($wds[$i+1],$wds[$i+2],$wds[$i+3]); }
            elsif ($i+2 < $wdcnt) { ($wd1,$wd2)=($wds[$i+1],$wds[$i+2]); }
            elsif ($i+1 < $wdcnt) { $wd1=$wds[$i+1]; }
            $iu2='me';
            # allow for up to 2 words in-between
            #  e.g. "impressed the hell out of you"
            #  NOTE: 'the' & 'of' are already compressed
            if ($i > 2) { ($wd1b,$wd2b,$wd3b)=($wds[$i-1],$wds[$i-2],$wds[$i-3]); }
            elsif ($i > 1) { ($wd1b,$wd2b)=($wds[$i-1],$wds[$i-2]); }
            elsif ($i > 0) { $wd1b=$wds[$i-1]; }
        }

        # get preceding words (for $iu='me')
        my (@iuwds,%pwds);
        if ($iu) {
            @iuwds= ($wd1,$wd2,$wd3,$wd1b,$wd2b,$wd3b);
            for my $k(0,1,2) {
                my($pwd,$ppwd,$pppwd);  # preceding words
                if ($i>3) {
                    ($pppwd,$ppwd,$pwd)=($wds[$i-3-$k],$wds[$i-2-$k],$wds[$i-1-$k]);
                }
                elsif ($i>2) {
                    ($ppwd,$pwd)=($wds[$i-2-$k],$wds[$i-1-$k]);
                }
                elsif ($i>1) {
                    $pwd=$wds[$i-1-$k];
                }
                foreach my $wd2($pwd,$ppwd,$pppwd) {
                    next if (!$wd2);
                    # delete leading/trailing hyphen
                    $wd2=~s/^\-?(.+?)\-?$/$1/ if ($wd2=~/\-/);
                }
                $pwds{$k}=[$pwd,$ppwd,$pppwd];
            }

            #----------------------------------------------------
            # compute IU opinion scores for each term
            #  - IU anchors need to be matched w/ original only
            #----------------------------------------------------

            my %sc= &IUsc5($word,$emp,$emp2,\%prxm,\%wdist,\%wdist2,$maxwdist,$iuhp,\%negwds,$pwd,$ppwd,$pppwd,\%pwds,\@iuwds,$iu,$iu2,$neg,$nomrpf);

            # increment opinion scores
            #   %sc key1  = QN
            #       key2a = sc,  scP,  scN  (when QN=0: query-independent socres)
            #       key2b = scx, scxP, scxN (when QN!=0: query-dependent socres)
            foreach my $qn(keys %sc) {
                foreach my $name(keys %{$sc{$qn}}) {
                    my $name2=$name;
                    $name2=~s/sc/iu/;
                    $schp->{$qn}{$name2} += $sc{$qn}{$name};
                }
            }

        }


        #------------------------------------------------------------
        # compute opinion scores for each word form
        #   - original, repeat-char compressed, hyphen compressed
        #   - search is stopped at first match for each opinion module
        #------------------------------------------------------------

        my %found;
        foreach my $wd($word,$wordc,$wordh) {
            next if (!$wd);

            print "calopSCall2: wd=$wd\n" if ($debug>2);

            if (!$found{'av'}) {  ##!!!!
                my %sc= &AVsc($wd,\%prxm,$pavhp,$navhp);
                # increment opinion scores
                #   %sc key1  = QN or 0
                #       key2a = psc,  nsc,  (when QN=0: query-independent socres)
                #       key2b = pscx, nscx  (when QN!=0: query-dependent socres)
                foreach my $qn(keys %sc) {
                    foreach my $name(keys %{$sc{$qn}}) {
                        my $name2=$name;
                        $name2=~s/sc/av/;
                        $schp->{$qn}{$name2} += $sc{$qn}{$name};
                    }
                }
                # stop when correct wordform is matched
                $found{'av'}=1 if ($sc{'sc'});  
            }

            if (!$found{'ac'}) {
                my %sc= &HFsc5($wd,$emp,$emp2,\%prxm,\%wdist,\%wdist2,$maxwdist,$achp,\%negwds,$pwd,$ppwd,$pppwd);
                # increment opinion scores
                #   %sc key1  = QN
                #       key2a = sc,  scP,  scN  (when QN=0: query-independent socres)
                #       key2b = scx, scxP, scxN (when QN!=0: query-dependent socres)
                foreach my $qn(keys %sc) {
                    foreach my $name(keys %{$sc{$qn}}) {
                        my $name2=$name;
                        $name2=~s/sc/ac/;
                        $schp->{$qn}{$name2} += $sc{$qn}{$name};
                    }
                }
                # stop when correct wordform is matched
                $found{'ac'}=1 if ($sc{'sc'});  
            }

            if (!$found{'hf'}) {
                my %sc= &HFsc5($wd,$emp,$emp2,\%prxm,\%wdist,\%wdist2,$maxwdist,$hfhp,\%negwds,$pwd,$ppwd,$pppwd);
                # increment opinion scores
                #   %sc key1  = QN
                #       key2a = sc,  scP,  scN  (when QN=0: query-independent socres)
                #       key2b = scx, scxP, scxN (when QN!=0: query-dependent socres)
                foreach my $qn(keys %sc) {
                    foreach my $name(keys %{$sc{$qn}}) {
                        my $name2=$name;
                        $name2=~s/sc/hf/;
                        $schp->{$qn}{$name2} += $sc{$qn}{$name};
                        #print "wd=$wd, qn=$qn, name=$name, name2=$name2, sc=$sc{$qn}{$name}\n";
                    }
                }
                # stop when correct wordform is matched
                $found{'hf'}=1 if ($sc{'sc'});  
            }

            if (!$found{'lf'}) {
                my %sc= &LFsc5($wd,$emp,$emp2,\%prxm,\%wdist,\%wdist2,$maxwdist,$lfhp,$lfxlp,$lfxsclp,$lfmlp,$lfmsclp,\%negwds,$pwd,$ppwd,$pppwd);
                # increment opinion scores
                #   %sc key1  = QN
                #       key2a = sc,  scP,  scN  (when QN=0: query-independent socres)
                #       key2b = scx, scxP, scxN (when QN!=0: query-dependent socres)
                foreach my $qn(keys %sc) {
                    foreach my $name(keys %{$sc{$qn}}) {
                        my $name2=$name;
                        $name2=~s/sc/lf/;
                        $schp->{$qn}{$name2} += $sc{$qn}{$name};
                    }
                }
                # stop when correct wordform is matched
                $found{'lf'}=1 if ($sc{'sc'});  
            }

            if (!$found{'w1'}) {
                my %sc= &HFsc5($wd,$emp,$emp2,\%prxm,\%wdist,\%wdist2,$maxwdist,$w1hp,\%negwds,$pwd,$ppwd,$pppwd);
                # increment opinion scores
                #   %sc key1  = QN
                #       key2a = sc,  scP,  scN  (when QN=0: query-independent socres)
                #       key2b = scx, scxP, scxN (when QN!=0: query-dependent socres)
                foreach my $qn(keys %sc) {
                    foreach my $name(keys %{$sc{$qn}}) {
                        my $name2=$name;
                        $name2=~s/sc/w1/;
                        $schp->{$qn}{$name2} += $sc{$qn}{$name};
                    }
                }
                # stop when correct wordform is matched
                $found{'w1'}=1 if ($sc{'sc'});  
            }

            if (!$found{'w2'}) {
                my %sc= &HFsc5($wd,$emp,$emp2,\%prxm,\%wdist,\%wdist2,$maxwdist,$w2hp,\%negwds,$pwd,$ppwd,$pppwd);
                # increment opinion scores
                #   %sc key1  = QN
                #       key2a = sc,  scP,  scN  (when QN=0: query-independent socres)
                #       key2b = scx, scxP, scxN (when QN!=0: query-dependent socres)
                foreach my $qn(keys %sc) {
                    foreach my $name(keys %{$sc{$qn}}) {
                        my $name2=$name;
                        $name2=~s/sc/w2/;
                        $schp->{$qn}{$name2} += $sc{$qn}{$name};
                    }
                }
                # stop when correct wordform is matched
                $found{'w2'}=1 if ($sc{'sc'});  
            }

            if (!$found{'emp'}) {
                my %sc= &HFsc5($wd,$emp,$emp2,\%prxm,\%wdist,\%wdist2,$maxwdist,$emphp,\%negwds,$pwd,$ppwd,$pppwd);
                # increment opinion scores
                #   %sc key1  = QN
                #       key2a = sc  (when QN=0: query-independent socres)
                #       key2b = scx (when QN!=0: query-dependent socres)
                foreach my $qn(keys %sc) {
                    foreach my $name(keys %{$sc{$qn}}) {
                        my $name2=$name;
                        $name2=~s/sc/e/;
                        $schp->{$qn}{$name2} += $sc{$qn}{$name};
                    }
                }
                # stop when correct wordform is matched
                $found{'emp'}=1 if ($sc{'sc'});  
            }

        } #end-foreach my $wd($word,$wordc,$wordh) 

    } #end-for(my $i=0; $i<$wdcnt; $i++) 

} #endsub calopSCall4

# multiple lex weights
sub calopSCall7 {
    my($text,$textM,$QTM,$QTM2,$NOT,$maxwdist,$qthp,$prxwsize,$schp,$achp,$hfhp,$iuhp,$lfhp,
       $lfxlp,$lfxsclpM,$lfxsclpC,$lfxsclpP,$lfmlp,$lfmsclpM,$lfmsclpC,$lfmsclpP,
       $w1hp,$w2hp,$emphp,$pavhp,$navhp,$nomrpf)=@_;
    my $debug=0;

    # !! add 'nothing': e.g. 'nothing bad'
    my %negwds=("not"=>1,"never"=>1,"no"=>1,"without"=>1,"hardly"=>1,"barely"=>1,"scarcely"=>1,
                "$NOT"=>1,"I-NOT"=>1,"ME-NOT"=>1,"MY-NOT"=>1);

    # IU anchor cnt
    my ($iucnt,$iucnt2,@iucnt,@iucnt2)=(0,0); 
    @iucnt= $text=~/\b(I|my|me)\b/gi;
    @iucnt2= $text=~/\b(you|we|your|our|us)\b/gi;
    $iucnt=@iucnt;
    $iucnt2=@iucnt2;
    $schp->{0}{'in1'} += $iucnt;
    $schp->{0}{'in2'} += $iucnt2;

    # convert opinion phrase to acronyms:
    #   e.g. 'in my humble opinion' to 'imho in my humble opinion'
    foreach my $str(keys %{$achp}) {
        next if ($str !~ / /);  # phrases only
        my $ac= lc(join("",$str=~/\b([A-Za-z])/g));
        $str=~s/I'm/I am/;
        $text=~s/($str)/ $ac $1 /ig if ($text=~/$str/i);
    }   

    print "calopSCall2: TEXT1=\n$text\n\n" if ($debug);

    #-------------------------------------------------------------------------
    # Normalize IU phrase:
    #  NOTE: some opinion terms can be compressed w/ this normalization
    #-------------------------------------------------------------------------

    # compress select prepositions, conjunctions, articles: for proximity match
    $text=~s/\s+(for|to|over|on|upon|in|with|of|and|or|a|an|the)\s+/ /gi;

    # e.g., 'cannot ever really be truly and completely satisfying to me' to 'every really be truly satisfying ME-NOT'
    $text=~s/\b($NOT\s+([A-Za-z]+\s+){0,6})(me|you|us)\b/$1ME-NOT/gi;

    # e.g., 'cannot really ever truly and unconditionally have my' to 'really ever truly unconditionally have MY-NOT'
    $text=~s/\b($NOT\s+([A-Za-z]+\s+){0,6})(my|your|our)\b/$1MY-NOT/gi;

    # e.g., 'my total and undying support of him really and truly cannot' to 'MY-NOT total undying support really truly cannot'
    $text=~s/\b(my|your|our)\s+(([A-Za-z]+\s+){0,6}$NOT)\s+/MY-NOT $2 /gi;

    # e.g., 'I truly and seriously cannot' to 'I-NOT'
    $text=~s/\b(I|you|we)\s+([A-Za-z]+\s+){0,2}$NOT\s+/I-NOT /gi;

    # e.g., 'I very likely will' to 'I '
    $text=~s/\b(I|you|we)\s+([A-Za-z]+\s+){0,2}(can|could|will|would|shall|should|must|do|did|may|might|am|was|are|were|have to|had to|have|had|need)\s+/I /gi;

    print "calopSCall2: TEXT2=\n$text\n\n" if ($debug);

    # $textM QTM markup has trailing numbers ($qn)
    #   - e.g. 'token1 token2$QTM$qn token3 token4$QTM$qn'
    my @wdsM0=split(/[^a-z!\-\d]+/,lc($textM));
    my @wdsM;

    # exclude non-letter tokens without QTM markup
    #  - to line up @wdsM with @wds
    my %qtmcnt;
    my %qtm2cnt;
    my %qwpos;  # k=QN, v=arry of term positions for whole query string
    my %qwpos2;  # k=QN, v=arry of term positions for query word
    my $pos=0;
    foreach my $wd(@wdsM0) {
        if ($wd=~/\d/) {
            my $added=0;
            if (my @qns= $wd=~/$QTM(\d+)/ig) {
                foreach my $qn(@qns) { 
                    $qtmcnt{$qn}++; 
                    push(@{$qwpos{$qn}},$pos);
                }
                push(@wdsM,$wd);
                $pos++;
                $added=1;
            }   
            if (my @qns= $wd=~/$QTM2(\d+)/ig) {
                foreach my $qn(@qns) { 
                    $qtm2cnt{$qn}++; 
                    push(@{$qwpos2{$qn}},$pos);
                }
                if (!$added) {
                    push(@wdsM,$wd);
                    $pos++;
                }
            }   
        }   
        else { 
            push(@wdsM,$wd); 
            $pos++;
        }
    }

    # words are converted to lowercase
    my @wds0=split(/[^a-z!\-\d]+/,lc($text));
    my @wds;

    # exclude non-letter tokens
    foreach my $wd(@wds0) {
        next if ($wd=~/\d/);
        push(@wds,$wd); 
    }

    if ($debug) {
        foreach my $qn(sort keys %qtmcnt) { print "calopSCall2: QTM $qn match = $qtmcnt{$qn}\n"; }
        for(my $i=0;$i<@wds;$i++) { print "calopSCall2: ($i) wd=$wds[$i], wdM=$wdsM[$i]\n"; }
    }

    my $wdcnt=@wds;

    for(my $i=0; $i<$wdcnt; $i++) {
        next if ($wds[$i]=~/^\s*$/);

        my $word=$wds[$i];

        # compress hyphens
        my $wordh;
        if (!$nomrpf && $word=~/\-/) {
            # delete leading/trailing hyphen 
            $word=~s/^\-?(.+?)\-?$/$1/;
            $wordh=$word;
            $wordh=~s/\-+//g;
        }

        my ($emp,$emp2)=(0,0);

        # words ending w/ !
        $emp=1 if ($word=~s/!$//);

        # words w/ 3+ repeat characters
        $emp2=1 if ($word=~/([a-z])\1{2,}/i);

        # compress embedded repeat characters
        #  - exception: e, o
        my $wordc;
        if (!$nomrpf && $word=~/([a-cdf-np-z])\1+\B/) {
            $wordc=$word;
            $wordc=~s/([a-cdf-np-z])\1+\B/$1/g;
        }

        # flag proximity match !
        #  - %prxm: k=QN, v=0,1
        # compute word distance between current word and query string
        #  - %wdist: k=QN, v=word distance
        # compute word distance between current word and query word
        #  - %wdist2: k=QN, v=word distance
        my (%wdist,%wdist2,%prxm);
        foreach my $qn(keys %$qthp) {
            my $mindist=1000;
            my $mindist2=1000;
            my $prxmatch=0;
            my $text2=$text;
            # replace query strings
            if ($qtmcnt{$qn}) {
                my $minI=$i-$prxwsize;
                my $maxI=$i+$prxwsize;
                $minI=0 if ($minI<0);
                $maxI=$#wds if ($maxI>$#wds);
                my $proxstr= join(' ',@wdsM[$minI..$maxI]);
                $prxmatch=1 if ($proxstr=~/$QTM$qn/i);
                $mindist= &minDist($i,$qwpos{$qn});
                $mindist2= &minDist($i,$qwpos2{$qn});
            }
            $prxm{$qn}=$prxmatch;
            $wdist{$qn}=$mindist;
            $wdist2{$qn}=$mindist2;
        }

        # get preceding words (for catching negations)
        my($pwd,$ppwd,$pppwd);  # preceding words
        if ($i>2) { ($pppwd,$ppwd,$pwd)=($wds[$i-3],$wds[$i-2],$wds[$i-1]); }
        elsif ($i>1) { ($ppwd,$pwd)=($wds[$i-2],$wds[$i-1]); }
        elsif ($i>0) { $pwd=$wds[$i-1]; }
        foreach my $wd2($pwd,$ppwd,$pppwd) {
            next if (!$wd2);
            # delete leading/trailing hyphen
            $wd2=~s/^\-?(.+?)\-?$/$1/ if ($wd2=~/\-/);
        }

        print "calopSCall2: word=$word, emp=$emp, emp2=$emp2\n" if ($debug>2);

        #-----------------------------------------
        # flag IU phrase and get adjacent terms

        my ($neg,$iu,$iu2)=(0);
        my ($wd1,$wd2,$wd3,$wd1b,$wd2b,$wd3b);

        if ($word=~/^(I|we|I-NOT)$/i) {
            $neg=1 if ($1=~/\-NOT/i);
            $iu='I';
            # allow for up to 2 words in-between
            #  e.g., "I truly seriously believe",
            if ($i+3 < $wdcnt) { ($wd1,$wd2,$wd3)=($wds[$i+1],$wds[$i+2],$wds[$i+3]); }
            elsif ($i+2 < $wdcnt) { ($wd1,$wd2)=($wds[$i+1],$wds[$i+2]); }
            elsif ($i+1 < $wdcnt) { $wd1=$wds[$i+1]; }
        }

        elsif ($word=~/^(my|your|our|MY-NOT)$/i) {
            $neg=1 if ($1=~/\-NOT/i);
            $iu='my';
            # allow for up to 2 words in-between
            #  e.g., "I truly seriously believe",
            if ($i+3 < $wdcnt) { ($wd1,$wd2,$wd3)=($wds[$i+1],$wds[$i+2],$wds[$i+3]); }
            elsif ($i+2 < $wdcnt) { ($wd1,$wd2)=($wds[$i+1],$wds[$i+2]); }
            elsif ($i+1 < $wdcnt) { $wd1=$wds[$i+1]; }
        }

        elsif ($word=~/^(me|us|ME-NOT)$/i) {
            $neg=1 if ($1=~/\-NOT/i);
            $iu='me';
            # allow for up to 2 words in-between
            #  e.g. "impressed the hell out of me"
            #  NOTE: 'the' & 'of' are already compressed
            if ($i > 2) { ($wd1,$wd2,$wd3)=($wds[$i-1],$wds[$i-2],$wds[$i-3]); }
            elsif ($i > 1) { ($wd1,$wd2)=($wds[$i-1],$wds[$i-2]); }
            elsif ($i > 0) { $wd1=$wds[$i-1]; }
        }

        # NOTE: 'you believe' or 'impressed you'
        elsif ($word=~/^you$/i) {
            $iu='I';
            # allow for up to 2 words in-between
            #  e.g., "you truly seriously believe",
            if ($i+3 < $wdcnt) { ($wd1,$wd2,$wd3)=($wds[$i+1],$wds[$i+2],$wds[$i+3]); }
            elsif ($i+2 < $wdcnt) { ($wd1,$wd2)=($wds[$i+1],$wds[$i+2]); }
            elsif ($i+1 < $wdcnt) { $wd1=$wds[$i+1]; }
            $iu2='me';
            # allow for up to 2 words in-between
            #  e.g. "impressed the hell out of you"
            #  NOTE: 'the' & 'of' are already compressed
            if ($i > 2) { ($wd1b,$wd2b,$wd3b)=($wds[$i-1],$wds[$i-2],$wds[$i-3]); }
            elsif ($i > 1) { ($wd1b,$wd2b)=($wds[$i-1],$wds[$i-2]); }
            elsif ($i > 0) { $wd1b=$wds[$i-1]; }
        }

        # get preceding words (for $iu='me')
        my (@iuwds,%pwds);
        if ($iu) {
            @iuwds= ($wd1,$wd2,$wd3,$wd1b,$wd2b,$wd3b);
            for my $k(0,1,2) {
                my($pwd,$ppwd,$pppwd);  # preceding words
                if ($i>3) {
                    ($pppwd,$ppwd,$pwd)=($wds[$i-3-$k],$wds[$i-2-$k],$wds[$i-1-$k]);
                }
                elsif ($i>2) {
                    ($ppwd,$pwd)=($wds[$i-2-$k],$wds[$i-1-$k]);
                }
                elsif ($i>1) {
                    $pwd=$wds[$i-1-$k];
                }
                foreach my $wd2($pwd,$ppwd,$pppwd) {
                    next if (!$wd2);
                    # delete leading/trailing hyphen
                    $wd2=~s/^\-?(.+?)\-?$/$1/ if ($wd2=~/\-/);
                }
                $pwds{$k}=[$pwd,$ppwd,$pppwd];
            }

            #----------------------------------------------------
            # compute IU opinion scores for each term
            #  - IU anchors need to be matched w/ original only
            #----------------------------------------------------

            my %sc= &IUsc7($word,$emp,$emp2,\%prxm,\%wdist,\%wdist2,$maxwdist,$iuhp,\%negwds,$pwd,$ppwd,$pppwd,\%pwds,\@iuwds,$iu,$iu2,$neg,$nomrpf);

            # increment opinion scores
            #   %sc key1  = QN
            #       key2a = sc,  scP,  scN  (when QN=0: query-independent socres)
            #       key2b = scx, scxP, scxN (when QN!=0: query-dependent socres)
            foreach my $qn(keys %sc) {
                foreach my $name(keys %{$sc{$qn}}) {
                    my $name2=$name;
                    $name2=~s/sc/iu/;
                    foreach my $wname('man','combo','prob') {
                        $schp->{$qn}{$name2}{$wname} += $sc{$qn}{$name}{$wname};
                    }
                }
            }

        }


        #------------------------------------------------------------
        # compute opinion scores for each word form
        #   - original, repeat-char compressed, hyphen compressed
        #   - search is stopped at first match for each opinion module
        #------------------------------------------------------------

        my %found;
        foreach my $wd($word,$wordc,$wordh) {
            next if (!$wd);

            print "calopSCall7: wd=$wd\n" if ($debug>2);

            if (!$found{'av'}) {  ##!!!!
                my %sc= &AVsc($wd,\%prxm,$pavhp,$navhp);
                # increment opinion scores
                #   %sc key1  = QN or 0
                #       key2a = psc,  nsc,  (when QN=0: query-independent socres)
                #       key2b = pscx, nscx  (when QN!=0: query-dependent socres)
                foreach my $qn(keys %sc) {
                    foreach my $name(keys %{$sc{$qn}}) {
                        my $name2=$name;
                        $name2=~s/sc/av/;
                        $schp->{$qn}{$name2} += $sc{$qn}{$name};
                    }
                }
                # stop when correct wordform is matched
                $found{'av'}=1 if ($sc{'sc'});  
            }

            if (!$found{'ac'}) {
                print "calling AC-HFsc7\n" if ($debug>3); ##!!
                my %sc= &HFsc7($wd,$emp,$emp2,\%prxm,\%wdist,\%wdist2,$maxwdist,$achp,\%negwds,$pwd,$ppwd,$pppwd);
                # increment opinion scores
                #   %sc key1  = QN
                #       key2a = sc,  scP,  scN  (when QN=0: query-independent socres)
                #       key2b = scx, scxP, scxN (when QN!=0: query-dependent socres)
                foreach my $qn(keys %sc) {
                    foreach my $name(keys %{$sc{$qn}}) {
                        my $name2=$name;
                        $name2=~s/sc/ac/;
                        foreach my $wname('man','combo','prob') {
                            $schp->{$qn}{$name2}{$wname} += $sc{$qn}{$name}{$wname};
                        }
                    }
                }
                # stop when correct wordform is matched
                $found{'ac'}=1 if ($sc{'sc'});  
            }

            if (!$found{'hf'}) {
                print "calling HF-HFsc7\n" if ($debug>3); ##!!
                my %sc= &HFsc7($wd,$emp,$emp2,\%prxm,\%wdist,\%wdist2,$maxwdist,$hfhp,\%negwds,$pwd,$ppwd,$pppwd);
                # increment opinion scores
                #   %sc key1  = QN
                #       key2a = sc,  scP,  scN  (when QN=0: query-independent socres)
                #       key2b = scx, scxP, scxN (when QN!=0: query-dependent socres)
                foreach my $qn(keys %sc) {
                    foreach my $name(keys %{$sc{$qn}}) {
                        my $name2=$name;
                        $name2=~s/sc/hf/;
                        foreach my $wname('man','combo','prob') {
                            $schp->{$qn}{$name2}{$wname} += $sc{$qn}{$name}{$wname};
                        }
                        #print "wd=$wd, qn=$qn, name=$name, name2=$name2, sc=$sc{$qn}{$name}\n";
                    }
                }
                # stop when correct wordform is matched
                $found{'hf'}=1 if ($sc{'sc'});  
            }

            if (!$found{'lf'}) {
                print "calling LF-HFsc7\n" if ($debug>3); ##!!
                my %sc= &LFsc7($wd,$emp,$emp2,\%prxm,\%wdist,\%wdist2,$maxwdist,$lfhp,
                                $lfxlp,$lfxsclpM,$lfxsclpC,$lfxsclpP,$lfmlp,$lfmsclpM,$lfmsclpC,$lfmsclpP,
                                \%negwds,$pwd,$ppwd,$pppwd);
                # increment opinion scores
                #   %sc key1  = QN
                #       key2a = sc,  scP,  scN  (when QN=0: query-independent socres)
                #       key2b = scx, scxP, scxN (when QN!=0: query-dependent socres)
                foreach my $qn(keys %sc) {
                    foreach my $name(keys %{$sc{$qn}}) {
                        my $name2=$name;
                        $name2=~s/sc/lf/;
                        foreach my $wname('man','combo','prob') {
                            $schp->{$qn}{$name2}{$wname} += $sc{$qn}{$name}{$wname};
                        }
                    }
                }
                # stop when correct wordform is matched
                $found{'lf'}=1 if ($sc{'sc'});  
            }

            if (!$found{'w1'}) {
                print "calling W1-HFsc7\n" if ($debug>3); ##!!
                my %sc= &HFsc7($wd,$emp,$emp2,\%prxm,\%wdist,\%wdist2,$maxwdist,$w1hp,\%negwds,$pwd,$ppwd,$pppwd);
                # increment opinion scores
                #   %sc key1  = QN
                #       key2a = sc,  scP,  scN  (when QN=0: query-independent socres)
                #       key2b = scx, scxP, scxN (when QN!=0: query-dependent socres)
                foreach my $qn(keys %sc) {
                    foreach my $name(keys %{$sc{$qn}}) {
                        my $name2=$name;
                        $name2=~s/sc/w1/;
                        foreach my $wname('man','combo','prob') {
                            $schp->{$qn}{$name2}{$wname} += $sc{$qn}{$name}{$wname};
                        }
                    }
                }
                # stop when correct wordform is matched
                $found{'w1'}=1 if ($sc{'sc'});  
            }

            if (!$found{'w2'}) {
                print "calling W2-HFsc7\n" if ($debug>3); ##!!
                my %sc= &HFsc7($wd,$emp,$emp2,\%prxm,\%wdist,\%wdist2,$maxwdist,$w2hp,\%negwds,$pwd,$ppwd,$pppwd);
                # increment opinion scores
                #   %sc key1  = QN
                #       key2a = sc,  scP,  scN  (when QN=0: query-independent socres)
                #       key2b = scx, scxP, scxN (when QN!=0: query-dependent socres)
                foreach my $qn(keys %sc) {
                    foreach my $name(keys %{$sc{$qn}}) {
                        my $name2=$name;
                        $name2=~s/sc/w2/;
                        foreach my $wname('man','combo','prob') {
                            $schp->{$qn}{$name2}{$wname} += $sc{$qn}{$name}{$wname};
                        }
                    }
                }
                # stop when correct wordform is matched
                $found{'w2'}=1 if ($sc{'sc'});  
            }

            if (!$found{'emp'}) {
                print "calling EMP-HFsc7\n" if ($debug>3); ##!!
                my %sc= &HFsc7($wd,$emp,$emp2,\%prxm,\%wdist,\%wdist2,$maxwdist,$emphp,\%negwds,$pwd,$ppwd,$pppwd);
                # increment opinion scores
                #   %sc key1  = QN
                #       key2a = sc  (when QN=0: query-independent socres)
                #       key2b = scx (when QN!=0: query-dependent socres)
                foreach my $qn(keys %sc) {
                    foreach my $name(keys %{$sc{$qn}}) {
                        my $name2=$name;
                        $name2=~s/sc/e/;
                        foreach my $wname('man','combo','prob') {
                            $schp->{$qn}{$name2}{$wname} += $sc{$qn}{$name}{$wname};
                        }
                    }
                }
                # stop when correct wordform is matched
                $found{'emp'}=1 if ($sc{'sc'});  
            }

        } #end-foreach my $wd($word,$wordc,$wordh) 

    } #end-for(my $i=0; $i<$wdcnt; $i++) 

} #endsub calopSCall7


# multiple lex weights
## changes from calopSCall7
#   - added 'nothing' to %negwds
sub calopSCall8 {
    my($text,$textM,$QTM,$QTM2,$NOT,$maxwdist,$qthp,$prxwsize,$schp,$achp,$hfhp,$iuhp,$lfhp,
       $lfxlp,$lfxsclpM,$lfxsclpC,$lfxsclpP,$lfmlp,$lfmsclpM,$lfmsclpC,$lfmsclpP,
       $w1hp,$w2hp,$emphp,$pavhp,$navhp,$nomrpf)=@_;
    my $debug=0;

    # !! add 'nothing': e.g. 'nothing bad'
    my %negwds=("not"=>1,"never"=>1,"no"=>1,"without"=>1,"hardly"=>1,"barely"=>1,"scarcely"=>1,"nothing"=>1,
                "$NOT"=>1,"I-NOT"=>1,"ME-NOT"=>1,"MY-NOT"=>1);

    # IU anchor cnt
    my ($iucnt,$iucnt2,@iucnt,@iucnt2)=(0,0); 
    @iucnt= $text=~/\b(I|my|me)\b/gi;
    @iucnt2= $text=~/\b(you|we|your|our|us)\b/gi;
    $iucnt=@iucnt;
    $iucnt2=@iucnt2;
    $schp->{0}{'in1'} += $iucnt;
    $schp->{0}{'in2'} += $iucnt2;

    # convert opinion phrase to acronyms:
    #   e.g. 'in my humble opinion' to 'imho in my humble opinion'
    foreach my $str(keys %{$achp}) {
        next if ($str !~ / /);  # phrases only
        my $ac= lc(join("",$str=~/\b([A-Za-z])/g));
        $str=~s/I'm/I am/;
        $text=~s/($str)/ $ac $1 /ig if ($text=~/$str/i);
    }   

    print "calopSCall2: TEXT1=\n$text\n\n" if ($debug);

    #-------------------------------------------------------------------------
    # Normalize IU phrase:
    #  NOTE: some opinion terms can be compressed w/ this normalization
    #-------------------------------------------------------------------------

    # compress select prepositions, conjunctions, articles: for proximity match
    $text=~s/\s+(for|to|over|on|upon|in|with|of|and|or|a|an|the)\s+/ /gi;

    # e.g., 'cannot ever really be truly and completely satisfying to me' to 'every really be truly satisfying ME-NOT'
    $text=~s/\b($NOT\s+([A-Za-z]+\s+){0,6})(me|you|us)\b/$1ME-NOT/gi;

    # e.g., 'cannot really ever truly and unconditionally have my' to 'really ever truly unconditionally have MY-NOT'
    $text=~s/\b($NOT\s+([A-Za-z]+\s+){0,6})(my|your|our)\b/$1MY-NOT/gi;

    # e.g., 'my total and undying support of him really and truly cannot' to 'MY-NOT total undying support really truly cannot'
    $text=~s/\b(my|your|our)\s+(([A-Za-z]+\s+){0,6}$NOT)\s+/MY-NOT $2 /gi;

    # e.g., 'I truly and seriously cannot' to 'I-NOT'
    $text=~s/\b(I|you|we)\s+([A-Za-z]+\s+){0,2}$NOT\s+/I-NOT /gi;

    # e.g., 'I very likely will' to 'I '
    $text=~s/\b(I|you|we)\s+([A-Za-z]+\s+){0,2}(can|could|will|would|shall|should|must|do|did|may|might|am|was|are|were|have to|had to|have|had|need)\s+/I /gi;

    print "calopSCall2: TEXT2=\n$text\n\n" if ($debug);

    # $textM QTM markup has trailing numbers ($qn)
    #   - e.g. 'token1 token2$QTM$qn token3 token4$QTM$qn'
    my @wdsM0=split(/[^a-z!\-\d]+/,lc($textM));
    my @wdsM;

    # exclude non-letter tokens without QTM markup
    #  - to line up @wdsM with @wds
    my %qtmcnt;
    my %qtm2cnt;
    my %qwpos;  # k=QN, v=arry of term positions for whole query string
    my %qwpos2;  # k=QN, v=arry of term positions for query word
    my $pos=0;
    foreach my $wd(@wdsM0) {
        if ($wd=~/\d/) {
            my $added=0;
            if (my @qns= $wd=~/$QTM(\d+)/ig) {
                foreach my $qn(@qns) { 
                    $qtmcnt{$qn}++; 
                    push(@{$qwpos{$qn}},$pos);
                }
                push(@wdsM,$wd);
                $pos++;
                $added=1;
            }   
            if (my @qns= $wd=~/$QTM2(\d+)/ig) {
                foreach my $qn(@qns) { 
                    $qtm2cnt{$qn}++; 
                    push(@{$qwpos2{$qn}},$pos);
                }
                if (!$added) {
                    push(@wdsM,$wd);
                    $pos++;
                }
            }   
        }   
        else { 
            push(@wdsM,$wd); 
            $pos++;
        }
    }

    # words are converted to lowercase
    my @wds0=split(/[^a-z!\-\d]+/,lc($text));
    my @wds;

    # exclude non-letter tokens
    foreach my $wd(@wds0) {
        next if ($wd=~/\d/);
        push(@wds,$wd); 
    }

    if ($debug) {
        foreach my $qn(sort keys %qtmcnt) { print "calopSCall2: QTM $qn match = $qtmcnt{$qn}\n"; }
        for(my $i=0;$i<@wds;$i++) { print "calopSCall2: ($i) wd=$wds[$i], wdM=$wdsM[$i]\n"; }
    }

    my $wdcnt=@wds;

    for(my $i=0; $i<$wdcnt; $i++) {
        next if ($wds[$i]=~/^\s*$/);

        my $word=$wds[$i];

        # compress hyphens
        my $wordh;
        if (!$nomrpf && $word=~/\-/) {
            # delete leading/trailing hyphen 
            $word=~s/^\-?(.+?)\-?$/$1/;
            $wordh=$word;
            $wordh=~s/\-+//g;
        }

        my ($emp,$emp2)=(0,0);

        # words ending w/ !
        $emp=1 if ($word=~s/!$//);

        # words w/ 3+ repeat characters
        $emp2=1 if ($word=~/([a-z])\1{2,}/i);

        # compress embedded repeat characters
        #  - exception: e, o
        my $wordc;
        if (!$nomrpf && $word=~/([a-cdf-np-z])\1+\B/) {
            $wordc=$word;
            $wordc=~s/([a-cdf-np-z])\1+\B/$1/g;
        }

        # flag proximity match !
        #  - %prxm: k=QN, v=0,1
        # compute word distance between current word and query string
        #  - %wdist: k=QN, v=word distance
        # compute word distance between current word and query word
        #  - %wdist2: k=QN, v=word distance
        my (%wdist,%wdist2,%prxm);
        foreach my $qn(keys %$qthp) {
            my $mindist=1000;
            my $mindist2=1000;
            my $prxmatch=0;
            my $text2=$text;
            # replace query strings
            if ($qtmcnt{$qn}) {
                my $minI=$i-$prxwsize;
                my $maxI=$i+$prxwsize;
                $minI=0 if ($minI<0);
                $maxI=$#wds if ($maxI>$#wds);
                my $proxstr= join(' ',@wdsM[$minI..$maxI]);
                $prxmatch=1 if ($proxstr=~/$QTM$qn/i);
                $mindist= &minDist($i,$qwpos{$qn});
                $mindist2= &minDist($i,$qwpos2{$qn});
            }
            $prxm{$qn}=$prxmatch;
            $wdist{$qn}=$mindist;
            $wdist2{$qn}=$mindist2;
        }

        # get preceding words (for catching negations)
        my($pwd,$ppwd,$pppwd);  # preceding words
        if ($i>2) { ($pppwd,$ppwd,$pwd)=($wds[$i-3],$wds[$i-2],$wds[$i-1]); }
        elsif ($i>1) { ($ppwd,$pwd)=($wds[$i-2],$wds[$i-1]); }
        elsif ($i>0) { $pwd=$wds[$i-1]; }
        foreach my $wd2($pwd,$ppwd,$pppwd) {
            next if (!$wd2);
            # delete leading/trailing hyphen
            $wd2=~s/^\-?(.+?)\-?$/$1/ if ($wd2=~/\-/);
        }

        print "calopSCall2: word=$word, emp=$emp, emp2=$emp2\n" if ($debug>2);

        #-----------------------------------------
        # flag IU phrase and get adjacent terms

        my ($neg,$iu,$iu2)=(0);
        my ($wd1,$wd2,$wd3,$wd1b,$wd2b,$wd3b);

        if ($word=~/^(I|we|I-NOT)$/i) {
            $neg=1 if ($1=~/\-NOT/i);
            $iu='I';
            # allow for up to 2 words in-between
            #  e.g., "I truly seriously believe",
            if ($i+3 < $wdcnt) { ($wd1,$wd2,$wd3)=($wds[$i+1],$wds[$i+2],$wds[$i+3]); }
            elsif ($i+2 < $wdcnt) { ($wd1,$wd2)=($wds[$i+1],$wds[$i+2]); }
            elsif ($i+1 < $wdcnt) { $wd1=$wds[$i+1]; }
        }

        elsif ($word=~/^(my|your|our|MY-NOT)$/i) {
            $neg=1 if ($1=~/\-NOT/i);
            $iu='my';
            # allow for up to 2 words in-between
            #  e.g., "I truly seriously believe",
            if ($i+3 < $wdcnt) { ($wd1,$wd2,$wd3)=($wds[$i+1],$wds[$i+2],$wds[$i+3]); }
            elsif ($i+2 < $wdcnt) { ($wd1,$wd2)=($wds[$i+1],$wds[$i+2]); }
            elsif ($i+1 < $wdcnt) { $wd1=$wds[$i+1]; }
        }

        elsif ($word=~/^(me|us|ME-NOT)$/i) {
            $neg=1 if ($1=~/\-NOT/i);
            $iu='me';
            # allow for up to 2 words in-between
            #  e.g. "impressed the hell out of me"
            #  NOTE: 'the' & 'of' are already compressed
            if ($i > 2) { ($wd1,$wd2,$wd3)=($wds[$i-1],$wds[$i-2],$wds[$i-3]); }
            elsif ($i > 1) { ($wd1,$wd2)=($wds[$i-1],$wds[$i-2]); }
            elsif ($i > 0) { $wd1=$wds[$i-1]; }
        }

        # NOTE: 'you believe' or 'impressed you'
        elsif ($word=~/^you$/i) {
            $iu='I';
            # allow for up to 2 words in-between
            #  e.g., "you truly seriously believe",
            if ($i+3 < $wdcnt) { ($wd1,$wd2,$wd3)=($wds[$i+1],$wds[$i+2],$wds[$i+3]); }
            elsif ($i+2 < $wdcnt) { ($wd1,$wd2)=($wds[$i+1],$wds[$i+2]); }
            elsif ($i+1 < $wdcnt) { $wd1=$wds[$i+1]; }
            $iu2='me';
            # allow for up to 2 words in-between
            #  e.g. "impressed the hell out of you"
            #  NOTE: 'the' & 'of' are already compressed
            if ($i > 2) { ($wd1b,$wd2b,$wd3b)=($wds[$i-1],$wds[$i-2],$wds[$i-3]); }
            elsif ($i > 1) { ($wd1b,$wd2b)=($wds[$i-1],$wds[$i-2]); }
            elsif ($i > 0) { $wd1b=$wds[$i-1]; }
        }

        # get preceding words (for $iu='me')
        my (@iuwds,%pwds);
        if ($iu) {
            @iuwds= ($wd1,$wd2,$wd3,$wd1b,$wd2b,$wd3b);
            for my $k(0,1,2) {
                my($pwd,$ppwd,$pppwd);  # preceding words
                if ($i>3) {
                    ($pppwd,$ppwd,$pwd)=($wds[$i-3-$k],$wds[$i-2-$k],$wds[$i-1-$k]);
                }
                elsif ($i>2) {
                    ($ppwd,$pwd)=($wds[$i-2-$k],$wds[$i-1-$k]);
                }
                elsif ($i>1) {
                    $pwd=$wds[$i-1-$k];
                }
                foreach my $wd2($pwd,$ppwd,$pppwd) {
                    next if (!$wd2);
                    # delete leading/trailing hyphen
                    $wd2=~s/^\-?(.+?)\-?$/$1/ if ($wd2=~/\-/);
                }
                $pwds{$k}=[$pwd,$ppwd,$pppwd];
            }

            #----------------------------------------------------
            # compute IU opinion scores for each term
            #  - IU anchors need to be matched w/ original only
            #----------------------------------------------------

            my %sc= &IUsc7($word,$emp,$emp2,\%prxm,\%wdist,\%wdist2,$maxwdist,$iuhp,\%negwds,$pwd,$ppwd,$pppwd,\%pwds,\@iuwds,$iu,$iu2,$neg,$nomrpf);

            # increment opinion scores
            #   %sc key1  = QN
            #       key2a = sc,  scP,  scN  (when QN=0: query-independent socres)
            #       key2b = scx, scxP, scxN (when QN!=0: query-dependent socres)
            foreach my $qn(keys %sc) {
                foreach my $name(keys %{$sc{$qn}}) {
                    my $name2=$name;
                    $name2=~s/sc/iu/;
                    foreach my $wname('man','combo','prob') {
                        $schp->{$qn}{$name2}{$wname} += $sc{$qn}{$name}{$wname};
                    }
                }
            }

        }


        #------------------------------------------------------------
        # compute opinion scores for each word form
        #   - original, repeat-char compressed, hyphen compressed
        #   - search is stopped at first match for each opinion module
        #------------------------------------------------------------

        my %found;
        foreach my $wd($word,$wordc,$wordh) {
            next if (!$wd);

            print "calopSCall7: wd=$wd\n" if ($debug>2);

            if (!$found{'av'}) {  ##!!!!
                my %sc= &AVsc($wd,\%prxm,$pavhp,$navhp);
                # increment opinion scores
                #   %sc key1  = QN or 0
                #       key2a = psc,  nsc,  (when QN=0: query-independent socres)
                #       key2b = pscx, nscx  (when QN!=0: query-dependent socres)
                foreach my $qn(keys %sc) {
                    foreach my $name(keys %{$sc{$qn}}) {
                        my $name2=$name;
                        $name2=~s/sc/av/;
                        $schp->{$qn}{$name2} += $sc{$qn}{$name};
                    }
                }
                # stop when correct wordform is matched
                $found{'av'}=1 if ($sc{'sc'});  
            }

            if (!$found{'ac'}) {
                print "calling AC-HFsc7\n" if ($debug>3); ##!!
                my %sc= &HFsc7($wd,$emp,$emp2,\%prxm,\%wdist,\%wdist2,$maxwdist,$achp,\%negwds,$pwd,$ppwd,$pppwd);
                # increment opinion scores
                #   %sc key1  = QN
                #       key2a = sc,  scP,  scN  (when QN=0: query-independent socres)
                #       key2b = scx, scxP, scxN (when QN!=0: query-dependent socres)
                foreach my $qn(keys %sc) {
                    foreach my $name(keys %{$sc{$qn}}) {
                        my $name2=$name;
                        $name2=~s/sc/ac/;
                        foreach my $wname('man','combo','prob') {
                            $schp->{$qn}{$name2}{$wname} += $sc{$qn}{$name}{$wname};
                        }
                    }
                }
                # stop when correct wordform is matched
                $found{'ac'}=1 if ($sc{'sc'});  
            }

            if (!$found{'hf'}) {
                print "calling HF-HFsc7\n" if ($debug>3); ##!!
                my %sc= &HFsc7($wd,$emp,$emp2,\%prxm,\%wdist,\%wdist2,$maxwdist,$hfhp,\%negwds,$pwd,$ppwd,$pppwd);
                # increment opinion scores
                #   %sc key1  = QN
                #       key2a = sc,  scP,  scN  (when QN=0: query-independent socres)
                #       key2b = scx, scxP, scxN (when QN!=0: query-dependent socres)
                foreach my $qn(keys %sc) {
                    foreach my $name(keys %{$sc{$qn}}) {
                        my $name2=$name;
                        $name2=~s/sc/hf/;
                        foreach my $wname('man','combo','prob') {
                            $schp->{$qn}{$name2}{$wname} += $sc{$qn}{$name}{$wname};
                        }
                        #print "wd=$wd, qn=$qn, name=$name, name2=$name2, sc=$sc{$qn}{$name}\n";
                    }
                }
                # stop when correct wordform is matched
                $found{'hf'}=1 if ($sc{'sc'});  
            }

            if (!$found{'lf'}) {
                print "calling LF-HFsc7\n" if ($debug>3); ##!!
                my %sc= &LFsc7($wd,$emp,$emp2,\%prxm,\%wdist,\%wdist2,$maxwdist,$lfhp,
                                $lfxlp,$lfxsclpM,$lfxsclpC,$lfxsclpP,$lfmlp,$lfmsclpM,$lfmsclpC,$lfmsclpP,
                                \%negwds,$pwd,$ppwd,$pppwd);
                # increment opinion scores
                #   %sc key1  = QN
                #       key2a = sc,  scP,  scN  (when QN=0: query-independent socres)
                #       key2b = scx, scxP, scxN (when QN!=0: query-dependent socres)
                foreach my $qn(keys %sc) {
                    foreach my $name(keys %{$sc{$qn}}) {
                        my $name2=$name;
                        $name2=~s/sc/lf/;
                        foreach my $wname('man','combo','prob') {
                            $schp->{$qn}{$name2}{$wname} += $sc{$qn}{$name}{$wname};
                        }
                    }
                }
                # stop when correct wordform is matched
                $found{'lf'}=1 if ($sc{'sc'});  
            }

            if (!$found{'w1'}) {
                print "calling W1-HFsc7\n" if ($debug>3); ##!!
                my %sc= &HFsc7($wd,$emp,$emp2,\%prxm,\%wdist,\%wdist2,$maxwdist,$w1hp,\%negwds,$pwd,$ppwd,$pppwd);
                # increment opinion scores
                #   %sc key1  = QN
                #       key2a = sc,  scP,  scN  (when QN=0: query-independent socres)
                #       key2b = scx, scxP, scxN (when QN!=0: query-dependent socres)
                foreach my $qn(keys %sc) {
                    foreach my $name(keys %{$sc{$qn}}) {
                        my $name2=$name;
                        $name2=~s/sc/w1/;
                        foreach my $wname('man','combo','prob') {
                            $schp->{$qn}{$name2}{$wname} += $sc{$qn}{$name}{$wname};
                        }
                    }
                }
                # stop when correct wordform is matched
                $found{'w1'}=1 if ($sc{'sc'});  
            }

            if (!$found{'w2'}) {
                print "calling W2-HFsc7\n" if ($debug>3); ##!!
                my %sc= &HFsc7($wd,$emp,$emp2,\%prxm,\%wdist,\%wdist2,$maxwdist,$w2hp,\%negwds,$pwd,$ppwd,$pppwd);
                # increment opinion scores
                #   %sc key1  = QN
                #       key2a = sc,  scP,  scN  (when QN=0: query-independent socres)
                #       key2b = scx, scxP, scxN (when QN!=0: query-dependent socres)
                foreach my $qn(keys %sc) {
                    foreach my $name(keys %{$sc{$qn}}) {
                        my $name2=$name;
                        $name2=~s/sc/w2/;
                        foreach my $wname('man','combo','prob') {
                            $schp->{$qn}{$name2}{$wname} += $sc{$qn}{$name}{$wname};
                        }
                    }
                }
                # stop when correct wordform is matched
                $found{'w2'}=1 if ($sc{'sc'});  
            }

            if (!$found{'emp'}) {
                print "calling EMP-HFsc7\n" if ($debug>3); ##!!
                my %sc= &HFsc7($wd,$emp,$emp2,\%prxm,\%wdist,\%wdist2,$maxwdist,$emphp,\%negwds,$pwd,$ppwd,$pppwd);
                # increment opinion scores
                #   %sc key1  = QN
                #       key2a = sc  (when QN=0: query-independent socres)
                #       key2b = scx (when QN!=0: query-dependent socres)
                foreach my $qn(keys %sc) {
                    foreach my $name(keys %{$sc{$qn}}) {
                        my $name2=$name;
                        $name2=~s/sc/e/;
                        foreach my $wname('man','combo','prob') {
                            $schp->{$qn}{$name2}{$wname} += $sc{$qn}{$name}{$wname};
                        }
                    }
                }
                # stop when correct wordform is matched
                $found{'emp'}=1 if ($sc{'sc'});  
            }

        } #end-foreach my $wd($word,$wordc,$wordh) 

    } #end-for(my $i=0; $i<$wdcnt; $i++) 

} #endsub calopSCall7


#------------------------------------------------------------
# compute opinion scores for a sinlge lexicon term
#-----------------------------------------------------------
# arg1 = text to be scored
# arg2 = lexicon term
# arg3 = term polarity (n,p,m)
# arg4 = term score
# arg5 = query title match placeholder
# arg6 = query title match count
# arg7 = negation placeholder
# arg8 = proximity window size
# r.v. = (sc, scP, scN, prx_sc, prx_scP, prx_scN)
#-----------------------------------------------------------
sub opSC {
    my($text,$wd,$pol,$sc,$QTM,$qtmcnt,$NOT,$prxwsize)=@_;
    my $debug=0;

    print "opSC: wd=$wd\ntext=$text\n\n" if ($debug);

    my ($hsc,$hscp,$hscn)=(0,0,0);
    my ($hsc2,$hscp2,$hscn2)=(0,0,0);

    return ($hsc,$hscp,$hscn,$hsc2,$hscp2,$hscn2) if ($text !~ /\b$wd\b/i);

    # count match score
    while ($text=~/\b(([a-z\-]+\s+){0,3})($wd)\b(.?)/ig) {
        my($pwds,$hit,$punc,$sc2)=($1,$3,$4,$sc);
        print "opSCa: hit=$hit, punc=$punc, pwds=$pwds\n" if ($debug);
        $sc2++ if ($punc && $punc=~/!/); # words ending w/ !
        $hsc += $sc2;
        if ($pol=~/[np]/) {
            if ($pwds=~/\b(not|never|no|without|hardly|barely|scarcely|$NOT|I-NOT|ME-NOT|MY-NOT)\b/i) {
                if ($pol eq 'n') { $hscp += $sc2; }
                elsif ($pol eq 'p') { $hscn += $sc2; }
            }
            else {
                if ($pol eq 'p') { $hscp += $sc2; }
                elsif ($pol eq 'n') { $hscn += $sc2; }
            }
        }
    }
    print "opSC: hsc=$hsc, hscp=$hscp, hscn=$hscn\n" if ($debug);

    # count proximity match if query match & lexicon match
    if ($qtmcnt && $hsc) {
        while ($text=~/\b(([a-z\-]+\s+){0,3})\b$QTM\s+?(.*?)\s+?($wd)\b(.?)/ig) {
            my ($pwds2,$window,$hit,$punc,$sc2)=($1,$3,$4,$5,$sc);
            print "opSCb: punc=$punc, hit=$hit, win=$window\n" if ($debug);
            $sc2++ if ($punc && $punc=~/!/); # words ending w/ !
            $hsc2 += $sc2 if ((my@hit2=($window=~/\s+/g))<$prxwsize);
            if ($pol=~/[np]/) {
                my $pwds;
                if ($window && $window=~/(([a-z\-]+\s+){0,3})$/) { $pwds=$1; }
                else { $pwds=$pwds2; }
                if ($pwds=~/\b(not|never|no|without|hardly|barely|scarcely|$NOT|I-NOT|ME-NOT|MY-NOT)\b/i) {
                    if ($pol eq 'n') { $hscp2 += $sc2; }
                    elsif ($pol eq 'p') { $hscn2 += $sc2; }
                }
                else {
                    if ($pol eq 'p') { $hscp2 += $sc2; }
                    elsif ($pol eq 'n') { $hscn2 += $sc2; }
                }
            }
        }
        #!! avoid double counting here
        if (!$hsc2) {
            while ($text=~/\b(([a-z\-]+\s+){0,3})($wd)\b(.?)\s+?(.*?)\s+?$QTM\b/ig) {
                my ($pwds,$hit,$punc,$window,$sc2)=($1,$3,$4,$5,$sc);
                print "opSCc: pwds=$pwds, punc=$punc, hit=$hit, win=$window\n" if ($debug);
                $sc2++ if ($punc && $punc=~/!/); # words ending w/ !
                $hsc2 += $sc2 if ((my@hit2=($window=~/\s+/g))<$prxwsize);
                if ($pol=~/[np]/) {
                    if ($pwds=~/\b(not|never|no|without|hardly|barely|scarcely|$NOT|I-NOT|ME-NOT|MY-NOT)\b/i) {
                        if ($pol eq 'n') { $hscp2 += $sc2; }
                        elsif ($pol eq 'p') { $hscn2 += $sc2; }
                    }
                    else {
                        if ($pol eq 'p') { $hscp2 += $sc2; }
                        elsif ($pol eq 'n') { $hscn2 += $sc2; }
                    }
                }
            }
        }
    }
    print "opSC: hxsc=$hsc2, hxscp=$hscp2, hxscn=$hscn2\n" if ($debug);

    return ($hsc,$hscp,$hscn,$hsc2,$hscp2,$hscn2);

} #endsub opSC


#------------------------------------------------------------
# compute opinion scores for a sinlge regular expression
#  - difference w/ opSC: regex/word is not matched at \b
#-----------------------------------------------------------
# arg1 = text to be scored
# arg2 = regex
# arg3 = term polarity (n,p,m)
# arg4 = term score
# arg5 = query title match placeholder
# arg6 = query title match count
# arg7 = negation placeholder
# arg8 = proximity window size
# arg9 = flag to match on repeat-char words only
# r.v. = (sc, scP, scN, prx_sc, prx_scP, prx_scN)
#-----------------------------------------------------------
sub opSC2 {
    my($text,$rgx,$pol,$sc,$QTM,$qtmcnt,$NOT,$prxwsize,$mrpflag)=@_;
    my $debug=0;

    print "opSC2: rgx=$rgx\ntext=$text\n\n" if ($debug);

    my ($hsc,$hscp,$hscn)=(0,0,0);
    my ($hsc2,$hscp2,$hscn2)=(0,0,0);

    return ($hsc,$hscp,$hscn,$hsc2,$hscp2,$hscn2) if ($text !~ /$rgx/i);

    # count match score
    while ($text=~/\b(([a-z\-]+\s+){0,3})($rgx)(.?)/ig) {
        my($pwds,$hit,$punc,$sc2)=($1,$3,$4,$sc);
        next if ($mrpflag && $hit!~/([a-z])\1{2,}/i);  # match repeat-char words
        print "opSC2a: hit=$hit, punc=$punc, pwds=$pwds\n" if ($debug);
        $sc2++ if ($punc && $punc=~/!/); # words ending w/ !
        $hsc += $sc2;
        if ($pol=~/[np]/) {
            if ($pwds=~/\b(not|never|no|without|hardly|barely|scarcely|$NOT|I-NOT|ME-NOT|MY-NOT)\b/i) {
                if ($pol eq 'n') { $hscp += $sc2; }
                elsif ($pol eq 'p') { $hscn += $sc2; }
            }
            else {
                if ($pol eq 'p') { $hscp += $sc2; }
                elsif ($pol eq 'n') { $hscn += $sc2; }
            }
        }
    }
    print "opSC2: hsc=$hsc, hscp=$hscp, hscn=$hscn\n" if ($debug);

    # count proximity match if query match & lexicon match
    if ($qtmcnt && $hsc) {
        while ($text=~/\b(([a-z\-]+\s+){0,3})\b$QTM\s+?(.*?)\s+?($rgx)(.?)/ig) {
            my ($pwds2,$window,$hit,$punc,$sc2)=($1,$3,$4,$5,$sc);
            next if ($mrpflag && $hit!~/([a-z])\1{2,}/i);  # match repeat-char words
            print "opSC2b: punc=$punc, hit=$hit, win=$window\n" if ($debug);
            $sc2++ if ($punc && $punc=~/!/); # words ending w/ !
            $hsc2 += $sc2 if ((my@hit2=($window=~/\s+/g))<$prxwsize);
            if ($pol=~/[np]/) {
                my $pwds;
                if ($window && $window=~/(([a-z\-]+\s+){0,3})$/) { $pwds=$1; }
                else { $pwds=$pwds2; }
                if ($pwds=~/\b(not|never|no|without|hardly|barely|scarcely|$NOT|I-NOT|ME-NOT|MY-NOT)\b/i) {
                    if ($pol eq 'n') { $hscp2 += $sc2; }
                    elsif ($pol eq 'p') { $hscn2 += $sc2; }
                }
                else {
                    if ($pol eq 'p') { $hscp2 += $sc2; }
                    elsif ($pol eq 'n') { $hscn2 += $sc2; }
                }
            }
        }
        #!! avoid double counting here
        if (!$hsc2) {
            while ($text=~/\b(([a-z\-]+\s+){0,3})($rgx)(.?)\s+?(.*?)\s+?$QTM\b/ig) {
                my ($pwds,$hit,$punc,$window,$sc2)=($1,$3,$4,$5,$sc);
                next if ($mrpflag && $hit!~/([a-z])\1{2,}/i);  # match repeat-char words
                print "opSC2c: pwds=$pwds, punc=$punc, hit=$hit, win=$window\n" if ($debug);
                $sc2++ if ($punc && $punc=~/!/); # words ending w/ !
                $hsc2 += $sc2 if ((my@hit2=($window=~/\s+/g))<$prxwsize);
                if ($pol=~/[np]/) {
                    if ($pwds=~/\b(not|never|no|without|hardly|barely|scarcely|$NOT|I-NOT|ME-NOT|MY-NOT)\b/i) {
                        if ($pol eq 'n') { $hscp2 += $sc2; }
                        elsif ($pol eq 'p') { $hscn2 += $sc2; }
                    }
                    else {
                        if ($pol eq 'p') { $hscp2 += $sc2; }
                        elsif ($pol eq 'n') { $hscn2 += $sc2; }
                    }
                }
            }
        }
    }
    print "opSC2: hxsc=$hsc2, hxscp=$hscp2, hxscn=$hscn2\n" if ($debug);

    return ($hsc,$hscp,$hscn,$hsc2,$hscp2,$hscn2);

} #endsub opSC2


#------------------------------------------------------------
# compute opinion scores for a paire of words (IU phrase)
#-----------------------------------------------------------
# arg1 = text to be scored
# arg2 = first word in word pair
# arg3 = second word in word pair
# arg4 = term polarity (n,p,m)
# arg5 = term score
# arg6 = query title match placeholder
# arg7 = query title match count
# arg8 = negation placeholder
# arg9 = proximity window size
# arg10 = flag to match on repeat-char words only
# r.v. = (sc, scP, scN, prx_sc, prx_scP, prx_scN)
#-----------------------------------------------------------
# NOTE: 
#   1. incoming text must be prepped w/ preptext sub
#   2. regex is rather delicate for precision.
#      to relax it, replace [a-z\-] with .
#-----------------------------------------------------------
sub opSC3 {
    my($text,$wd1,$wd2,$pol,$sc,$QTM,$qtmcnt,$NOT,$prxwsize,$mrpflag)=@_;
    my $debug=0;

    print "opSC3: wd1=$wd1, wd2=$wd2\ntext=$text\n\n" if ($debug);

    # expand IU anchor
    if ($wd1=~/I/) { $wd1='I|you|we|I-NOT'; }
    elsif ($wd1=~/my/) { $wd1='my|your|our|MY-NOT'; }
    elsif ($wd2=~/me/) { $wd1='me|you|us|ME-NOT'; }

    my ($hsc,$hscp,$hscn)=(0,0,0);
    my ($hsc2,$hscp2,$hscn2)=(0,0,0);

    return ($hsc,$hscp,$hscn,$hsc2,$hscp2,$hscn2) if (!($text=~/\b$wd1\b/i && $text=~/\b$wd2\b/i));

    # count match score
    # allow up to 3 words inbetween phrase words
    while ($text=~/\b(([a-z\-]+\s+){0,3})\b($wd1)\s+(([a-z\-]+\s+){0,3})($wd2)\b(.?)/ig) {
        my($pwds,$hit1,$buffer,$hit2,$punc,$sc2)=($1,$3,$4,$6,$7,$sc);
        my $negf=0;
        $negf=1 if ($hit1=~/\-NOT/i || $hit2=~/\-NOT/i);
        print "opSC3a: pwds=$pwds, h1=$hit1, btw=$buffer, h2=$hit2, punc=$punc, btw=$buffer\n" if ($debug);
        $sc2++ if ($punc && $punc=~/!/); # words ending w/ !
        $hsc += $sc2;
        if ($pol=~/[np]/) {
            if ( ($negf || $pwds=~/\b(not|never|no|without|hardly|barely|scarcely|$NOT|I-NOT|ME-NOT|MY-NOT)\b/i) ||
                 ($buffer=~/\b(not|never|no|without|hardly|barely|scarcely|$NOT|I-NOT|ME-NOT|MY-NOT)\b/i) ) {
                if ($pol eq 'n') { $hscp += $sc2; }
                elsif ($pol eq 'p') { $hscn += $sc2; }
            }
            else {
                if ($pol eq 'p') { $hscp += $sc2; }
                elsif ($pol eq 'n') { $hscn += $sc2; }
            }
        }
    }
    print "opSC3b: hsc=$hsc, hscp=$hscp, hscn=$hscn\n" if ($debug);

    # count proximity match if query match & lexicon match
    if ($qtmcnt && $hsc) {
        while ($text=~/\b(([a-z\-]+\s+){0,3})\b$QTM\s+?(.*?)\s+?($wd1)\s+(([a-z\-]+\s+){0,3})($wd2)\b(.?)/ig) {
            my ($pwds2,$window,$hit1,$buffer,$hit2,$punc,$sc2)=($1,$3,$4,$5,$7,$8,$sc);
            my $negf=0;
            $negf=1 if ($hit1=~/\-NOT/i || $hit2=~/\-NOT/i);
            print "opSC3(prx1): neg=$negf, pwd=$pwds2, h1=$hit1, btw=$buffer, h2=$hit2, punc=$punc, win=$window\n" if ($debug);
            $sc2++ if ($punc && $punc=~/!/); # words ending w/ !
            $hsc2 += $sc2 if ((my@hit2=($window=~/\s+/g))<$prxwsize);
            if ($pol=~/[np]/) {
                my $pwds;
                if ($window && $window=~/(([a-z\-]+\s+){0,3})$/) { $pwds=$1; }
                else { $pwds=$pwds2; }
                if ( ($negf || $pwds=~/\b(not|never|no|without|hardly|barely|scarcely|$NOT|I-NOT|ME-NOT|MY-NOT)\b/i) ||
                     ($buffer=~/\b(not|never|no|without|hardly|barely|scarcely|$NOT|I-NOT|ME-NOT|MY-NOT)\b/i) ) {
                    if ($pol eq 'n') { $hscp2 += $sc2; }
                    elsif ($pol eq 'p') { $hscn2 += $sc2; }
                }
                else {
                    if ($pol eq 'p') { $hscp2 += $sc2; }
                    elsif ($pol eq 'n') { $hscn2 += $sc2; }
                }
            }
        }
        # avoid double counting here
        if (!$hsc2) {
            while ($text=~/\b(([a-z\-]+\s+){0,3})($wd1)\s+?(([a-z\-]+\s+){0,3})($wd2)\b(.?)\s+?(.*?)\s+?$QTM\b/ig) {
                my ($pwds,$hit1,$buffer,$hit2,$punc,$window,$sc2)=($1,$3,$4,$6,$7,$8,$sc);
                my $negf=0;
                $negf=1 if ($hit1=~/\-NOT/i || $hit2=~/\-NOT/i);
                print "opSC2c(prx2): neg=$negf, pwd=$pwds, h1=$hit1, btw=$buffer, h2=$hit2, punc=$punc, win=$window\n" if ($debug);
                $sc2++ if ($punc && $punc=~/!/); # words ending w/ !
                $hsc2 += $sc2 if ((my@hit2=($window=~/\s+/g))<$prxwsize);
                if ($pol=~/[np]/) {
                    if ( ($negf || $pwds=~/\b(not|never|no|without|hardly|barely|scarcely|$NOT|I-NOT|ME-NOT|MY-NOT)\b/i) ||
                        ($buffer=~/\b(not|never|no|without|hardly|barely|scarcely|$NOT|I-NOT|ME-NOT|MY-NOT)\b/i) ) {
                        if ($pol eq 'n') { $hscp2 += $sc2; }
                        elsif ($pol eq 'p') { $hscn2 += $sc2; }
                    }
                    else {
                        if ($pol eq 'p') { $hscp2 += $sc2; }
                        elsif ($pol eq 'n') { $hscn2 += $sc2; }
                    }
                }
            }
        }
    }
    print "opSC3: hxsc=$hsc2, hxscp=$hscp2, hxscn=$hscn2\n" if ($debug);

    return ($hsc,$hscp,$hscn,$hsc2,$hscp2,$hscn2);

} #endsub opSC3


#------------------------------------------------------------
# compute opinion scores
#   - modified version of calrrsc sub in rerankrt13.pl
#-----------------------------------------------------------
# arg1 = text to be scored
# arg2 = negation placeholder
# arg3 = query title match placeholder
# arg4 = query title match count
# arg5 = proximity window size
# arg6 = pointer to opinon score hash
#          k= score name 
#             (iu[x][NP],hf[x][NP],lf[x][NP],ac[x][NP],w1[x][NP],w2[x][NP],e[x][NP])
#             e.g  iu   - IU simple match score
#                  iuP  - IU simple positive poloarity match score
#                  iuN  - IU simple negative poloarity match score
#                  iux  - IU proximity match score
#                  iuxP - IU proximity positive polarity match score
#                  iuxN - IU proximity negative polarity match score
#          v= score
# arg7 = pointer to IU hash
# arg8 = pointer to HF hash
# arg9 = pointer to LF hash
# arg10 = pointer to LF regex
# arg11 = pointer to LF morph regex
# arg12 = pointer to AC hash
# arg13 = pointer to Wilson's strong subj hash
# arg14 = pointer to Wilson's weak subj hash
# arg15 = pointer to Wilson's emphasis  hash
#-----------------------------------------------------------
# NOTE:  
#   1. phrases are hyphenated 
#   2. compressed form of lexicon terms are not checked for
#   3. hyphens are not compressed
#-----------------------------------------------------------
sub calopSC2 {
    my($text,$NOT,$QTM,$qtmcnt,$prxwsize,$schp,$achp,$hfhp,$iuhp,$lfhp,$lfxhp,$lfmhp,$w1hp,$w2hp,$emphp)=@_;
    my $debug=0;

    my %negwds=("not"=>1,"never"=>1,"no"=>1,"without"=>1,"hardly"=>1,"barely"=>1,"scarcely"=>1,
                "$NOT"=>1,"I-NOT"=>1,"ME-NOT"=>1,"MY-NOT"=>1);

    # convert opinion phrase to acronyms:
    #   e.g. 'in my humble opinion' to 'imho'
    foreach my $str(keys %{$achp}) {
        next if ($str !~ / /);  # phrases only
        my $ac= lc(join("",$str=~/\b([A-Za-z])/g));
        $str=~s/I'm/I am/;
        $text=~s/($str)/ $ac $1 /ig if ($text=~/$str/i);
    }   

    print "calopSC2: TEXT1=\n$text\n\n" if ($debug>1);

    # IU anchor cnt
    my ($iucnt,$iucnt2,@iucnt,@iucnt2)=(0,0); 
    @iucnt= $text=~/\b(I|my|me)\b/gi;
    @iucnt2= $text=~/\b(you|we|your|our|us)\b/gi;
    $iucnt=@iucnt;
    $iucnt2=@iucnt2;
    $schp->{'iucnt'} += $iucnt;
    $schp->{'iucnt2'} += $iucnt2;

    #-------------------------------------------------------------------------
    # Normalize IU phrase:
    #  NOTE: some opinion terms can be compressed w/ this normalization
    #-------------------------------------------------------------------------

    # compress select prepositions, conjunctions, articles: for proximity match
    $text=~s/\s+(for|to|over|on|upon|in|with|of|and|or|a|an|the)\s+/ /gi;

    # e.g., 'cannot ever really be truly and completely satisfying to me' to 'every really be truly satisfying ME-NOT'
    $text=~s/\b($NOT\s+([A-Za-z]+\s+){0,6})(me|you|us)\b/$1ME-NOT/gi;

    # e.g., 'cannot really ever truly and unconditionally have my' to 'really ever truly unconditionally have MY-NOT'
    $text=~s/\b($NOT\s+([A-Za-z]+\s+){0,6})(my|your|our)\b/$1MY-NOT/gi;

    # e.g., 'my total and undying support of him really and truly cannot' to 'MY-NOT total undying support really truly cannot'
    $text=~s/\b(my|your|our)\s+(([A-Za-z]+\s+){0,6}$NOT)\s+/MY-NOT $2 /gi;

    # e.g., 'I truly and seriously cannot' to 'I-NOT'
    $text=~s/\b(I|you|we)\s+([A-Za-z]+\s+){0,2}$NOT\s+/I-NOT /gi;

    # e.g., 'I very likely will' to 'I '
    $text=~s/\b(I|you|we)\s+([A-Za-z]+\s+){0,2}(can|could|will|would|shall|should|must|do|did|may|might|am|was|are|were|have to|had to|have|had|need)\s+/I /gi;

    print "calopSC2: TEXT2=\n$text\n\n" if ($debug>1);

    #------------------------------
    # compute HF match scores
    #------------------------------
    foreach my $wd(keys %$hfhp) {

        $hfhp->{$wd}=~/^(.)(\d)/;
        my($pol,$sc)=($1,$2);

        # compute opinion scores
        my($hsc,$hscP,$hscN,$hscx,$hscxP,$hscxN)=&opSC($text,$wd,$pol,$sc,$QTM,$qtmcnt,$NOT,$prxwsize);
        print "calopSC2(hf): h=$hsc, hp=$hscP, hn=$hscN, hx=$hscx, hxp=$hscxP, hxn=$hscxN\n" if ($debug);

        $schp->{'hf'} += $hsc;
        $schp->{'hfP'} += $hscP;
        $schp->{'hfN'} += $hscN;
        $schp->{'hfx'} += $hscx;
        $schp->{'hfxP'} += $hscxP;
        $schp->{'hfxN'} += $hscxN;

    }

    #------------------------------
    # compute W1 match scores
    #  - Wilson's strong subjective terms
    #------------------------------
    foreach my $wd(keys %$w1hp) {

        $w1hp->{$wd}=~/^(.)(\d)/;
        my($pol,$sc)=($1,$2);

        # compute opinion scores
        my($hsc,$hscP,$hscN,$hscx,$hscxP,$hscxN)=&opSC($text,$wd,$pol,$sc,$QTM,$qtmcnt,$NOT,$prxwsize);
        print "calopSC2(w1): h=$hsc, hp=$hscP, hn=$hscN, hx=$hscx, hxp=$hscxP, hxn=$hscxN\n" if ($debug);

        $schp->{'w1'} += $hsc;
        $schp->{'w1P'} += $hscP;
        $schp->{'w1N'} += $hscN;
        $schp->{'w1x'} += $hscx;
        $schp->{'w1xP'} += $hscxP;
        $schp->{'w1xN'} += $hscxN;

    }

    #------------------------------
    # compute W2 match scores
    #  - Wilson's weak subjective terms
    #------------------------------
    foreach my $wd(keys %$w2hp) {

        $w2hp->{$wd}=~/^(.)(\d)/;
        my($pol,$sc)=($1,$2);

        # compute opinion scores
        my($hsc,$hscP,$hscN,$hscx,$hscxP,$hscxN)=&opSC($text,$wd,$pol,$sc,$QTM,$qtmcnt,$NOT,$prxwsize);
        print "calopSC2(w2): h=$hsc, hp=$hscP, hn=$hscN, hx=$hscx, hxp=$hscxP, hxn=$hscxN\n" if ($debug);

        $schp->{'w2'} += $hsc;
        $schp->{'w2P'} += $hscP;
        $schp->{'w2N'} += $hscN;
        $schp->{'w2x'} += $hscx;
        $schp->{'w2xP'} += $hscxP;
        $schp->{'w2xN'} += $hscxN;

    }

    #------------------------------
    # compute Emp match scores
    #  - Wilson's emphasis terms
    #------------------------------
    foreach my $wd(keys %$emphp) {

        $emphp->{$wd}=~/^(.)(\d)/;
        my($pol,$sc)=($1,$2);

        # compute opinion scores
        my($hsc,$hscP,$hscN,$hscx,$hscxP,$hscxN)=&opSC($text,$wd,$pol,$sc,$QTM,$qtmcnt,$NOT,$prxwsize);
        print "calopSC2(e): h=$hsc, hp=$hscP, hn=$hscN, hx=$hscx, hxp=$hscxP, hxn=$hscxN\n" if ($debug);

        $schp->{'e'} += $hsc;
        $schp->{'eP'} += $hscP;
        $schp->{'eN'} += $hscN;
        $schp->{'ex'} += $hscx;
        $schp->{'exP'} += $hscxP;
        $schp->{'exN'} += $hscxN;

    }

    #------------------------------
    # compute AC scores
    #   - opinion acronyms: e.g. imho
    #------------------------------
    foreach my $wd(keys %$achp) {

        $achp->{$wd}=~/^(.)(\d)/;
        my($pol,$sc)=($1,$2);

        # compute opinion scores
        my($hsc,$hscP,$hscN,$hscx,$hscxP,$hscxN)=&opSC($text,$wd,$pol,$sc,$QTM,$qtmcnt,$NOT,$prxwsize);
        print "calopSC2(ac): h=$hsc, hp=$hscP, hn=$hscN, hx=$hscx, hxp=$hscxP, hxn=$hscxN\n" if ($debug);

        $schp->{'ac'} += $hsc;
        $schp->{'acP'} += $hscP;
        $schp->{'acN'} += $hscN;
        $schp->{'acx'} += $hscx;
        $schp->{'acxP'} += $hscxP;
        $schp->{'acxN'} += $hscxN;

    }

    #------------------------------
    # compute LF scores
    #------------------------------
    foreach my $wd(keys %$lfhp) {

        $lfhp->{$wd}=~/^(.)(\d)/;
        my($pol,$sc)=($1,$2);

        # compute opinion scores
        my($hsc,$hscP,$hscN,$hscx,$hscxP,$hscxN)=&opSC($text,$wd,$pol,$sc,$QTM,$qtmcnt,$NOT,$prxwsize);
        print "calopSC2(lf): h=$hsc, hp=$hscP, hn=$hscN, hx=$hscx, hxp=$hscxP, hxn=$hscxN\n" if ($debug);

        $schp->{'lf'} += $hsc;
        $schp->{'lfP'} += $hscP;
        $schp->{'lfN'} += $hscN;
        $schp->{'lfx'} += $hscx;
        $schp->{'lfxP'} += $hscxP;
        $schp->{'lfxN'} += $hscxN;

    }

    foreach my $rgx(keys %$lfxhp) {

        $lfxhp->{$rgx}=~/^(.)(\d)/;
        my($pol,$sc)=($1,$2);

        # compute opinion scores
        my($hsc,$hscP,$hscN,$hscx,$hscxP,$hscxN)=&opSC2($text,$rgx,$pol,$sc,$QTM,$qtmcnt,$NOT,$prxwsize);
        print "calopSC2(lfx): h=$hsc, hp=$hscP, hn=$hscN, hx=$hscx, hxp=$hscxP, hxn=$hscxN\n" if ($debug);

        $schp->{'lf'} += $hsc;
        $schp->{'lfP'} += $hscP;
        $schp->{'lfN'} += $hscN;
        $schp->{'lfx'} += $hscx;
        $schp->{'lfxP'} += $hscxP;
        $schp->{'lfxN'} += $hscxN;

    }

    # count morph regex match only if repeat-char word
    foreach my $rgx(keys %$lfmhp) {

        $lfmhp->{$rgx}=~/^(.)(\d)/;
        my($pol,$sc)=($1,$2);

        # compute opinion scores
        my($hsc,$hscP,$hscN,$hscx,$hscxP,$hscxN)=&opSC2($text,$rgx,$pol,$sc,$QTM,$qtmcnt,$NOT,$prxwsize,1);
        print "calopSC2(lfx): h=$hsc, hp=$hscP, hn=$hscN, hx=$hscx, hxp=$hscxP, hxn=$hscxN\n" if ($debug);

        $schp->{'lf'} += $hsc;
        $schp->{'lfP'} += $hscP;
        $schp->{'lfN'} += $hscN;
        $schp->{'lfx'} += $hscx;
        $schp->{'lfxP'} += $hscxP;
        $schp->{'lfxN'} += $hscxN;

    }

    #-------------------------------------------
    # compute IU scores
    #   - %$iuhp: k=I,me,my, v= (wd-polsc)
    #-------------------------------------------
    foreach my $iu(keys %$iuhp) {

        foreach my $wd(keys %{$iuhp->{$iu}}) {

            $iuhp->{$iu}{$wd}=~/^(.)(\d)/;
            my($pol,$sc)=($1,$2);

            my($wd1,$wd2);
            if ($iu=~/I|my/) { $wd1=$iu; $wd2=$wd; }
            elsif ($iu=~/me/) { $wd2=$iu; $wd1=$wd; }
            else { die "calopSC2(iu): unaccounted for IU anchor = $iu\n"; }

            # compute opinion scores
            my($hsc,$hscP,$hscN,$hscx,$hscxP,$hscxN)=&opSC3($text,$wd1,$wd2,$pol,$sc,$QTM,$qtmcnt,$NOT,$prxwsize);
            print "calopSC2(iu): h=$hsc, hp=$hscP, hn=$hscN, hx=$hscx, hxp=$hscxP, hxn=$hscxN\n" if ($debug);

            $schp->{'iu'} += $hsc;
            $schp->{'iuP'} += $hscP;
            $schp->{'iuN'} += $hscN;
            $schp->{'iux'} += $hscx;
            $schp->{'iuxP'} += $hscxP;
            $schp->{'iuxN'} += $hscxN;

        }
    }

} #endsub calopSC2


#------------------------------------------------------------
# match all query words in sliding window
#------------------------------------------------------------
#   arg1= query string
#   arg2= target string
#   arg3= number of words between query terms
#   r.v.= number of "all the word" matches
#------------------------------------------------------------
sub swinprox {
    my($qstr,$tstr,$wspan)=@_;

    my @qwd=split(/ +/,$qstr);
    my ($qwdn,%qwd);
    foreach my $wd(@qwd) {
        # allow for plurals
        $wd .= 's' if ($wd!~/s$/i);
        $qwd{$wd}++;
        $qwdn++;
    }

    # window size
    #  - allow avg. 2 words between query words
    my $wdwin= $wspan*($qwdn-1) + $qwdn;

    # check for all word match in sliding window
    my @bwd=split(/\s+/,$tstr);
    my $hit=0;

    if (@bwd<=$wdwin) {
        # each sliding window
        my $txt= join(" ",@bwd);
        my $wn=0;
        foreach my $wd(keys %qwd) {
            if ($txt=~/$wd?/i) {
                $wn++;
                $txt=~s/\b$wd?\b/#!$wn!#/ig;
            }
        }
        # all the words are found
        if ($txt=~/#!$qwdn!#/) {
            $hit++;
        }
    }

    else {
        for(my $i=0; $i<@bwd; $i++) {

            my $i2= $i+$wdwin;

            last if ($i2>=@bwd);

            # each sliding window
            my $txt= join(" ",@bwd[$i..$i2]);
            my $wn=0;
            foreach my $wd(keys %qwd) {
                if ($txt=~/$wd?/i) {
                    $wn++;
                    $txt=~s/\b$wd?\b/#!$wn!#/ig;
                }
            }
            # all the words are found
            if ($txt=~/#!$qwdn!#/) {
                $hit++;
                $i=$i2; # check rest of target text
            }
        }
    } #end-else

    return $hit;

} #endsub swinprox


#------------------------------------------------------------
# compute opinion score of phrase matches
#   - length-normalized match count
#-----------------------------------------------------------
# arg1 = text to be scored (qtitle match converted to placeholder)
# arg2 = text length
# arg3 = pointer to phrase hash
#          key: phrase string
#          val: [pnm]N
# arg4 = negation placeholder 
# arg5 = query title match placeholder 
# arg6 = query title match count
# arg7 = proximity window size 
# arg8 = flag to return raw match count
# r.v. = (sc1, sc2, sc1p, sc2p, sc1n, sc2n)
#         sc1 - proximity match score
#         sc2 - simple match score
#         sc1p - proximity positive polarity match score
#         sc2p - simple positive poloarity match score
#         sc1n - proximity negative polarity match score
#         sc2n - simple negative poloarity match score
#-----------------------------------------------------------
# NOTE:  
#   1. phrases are hyphenated 
#   2. compressed form of lexicon terms are not checked for
#   3. hyphens are not compressed
#-----------------------------------------------------------
sub PHsc {
    my($text,$tlen,$lexhp,$NOT,$QTM,$qtmcnt,$proxwinsize,$flag)=@_;
    my $debug=0;

    my ($sc1,$sc2,$sc1p,$sc2p,$sc1n,$sc2n)=(0,0,0,0,0,0);
    my %negwds=("not"=>1,"never"=>1,"no"=>1,"without"=>1,"hardly"=>1,"barely"=>1,"scarcely"=>1,"$NOT"=>1);
    my $MATCH='MM-phstr--MM';

    # convert matched phrases to hyphenated words
    foreach my $str(keys %{$lexhp}) {
        my $str2=$str;
        $str2=~s/-+/ /g;
        $text=~s/$str2/ $str /ig if ($text=~/$str2/i);
    }

    # compress select prepositions, conjunctions, articles: for proximity match
    $text=~s/\s+(for|to|over|on|upon|in|with|of|and|or|a|an|the)\s+/ /gi;

    my @wds=split(/[^A-Za-z!\-]+/,$text);

    for(my $i=0; $i<@wds; $i++) {

        my $wd=$wds[$i];

        # delete leading/trailing hyphen 
        $wd=~s/^\-?(.+?)\-?$/$1/;

        # words ending w/ !
        my $emp=0;
        $emp=1 if ($wd=~s/!$//);

        # convert to lowercase
        $wd=~tr/A-Z/a-z/;

        print "PHsc1: wd=$wd, emp=$emp\n" if ($debug);

        if ($lexhp->{$wd}) {

            $lexhp->{$wd}=~/^(.)(\d)/;
            my($pol,$sc)=($1,$2);
            $sc++ if ($emp);

            print "PHsc2: $wds[$i]=$lexhp->{$wd}, pol=$pol, sc=$sc\n" if ($debug);

            # increment opinion score
            $sc2 += $sc;

            # flag proximity match
            my $proxMatch=0;
            if ($qtmcnt) {
                my $minI=$i-$proxwinsize;
                my $maxI=$i+$proxwinsize;
                $minI=0 if ($minI<0);
                $maxI=$#wds if ($maxI>$#wds);
                my $proxstr= join(' ',@wds[$minI..$maxI]);
                if ($proxstr=~/$QTM/) {
                    $proxMatch=1;
                    $sc1 += $sc;
                }
                print "PHsc3: wd=$wds[$i], sc=$sc, pmatch=$proxMatch, proxstr=$proxstr\n" if ($debug);
            }

            # polarity score
            if ($pol=~/[np]/) {
                my($pwd,$ppwd,$pppwd);  # preceding words
                if ($i>2) {
                    ($pppwd,$ppwd,$pwd)=($wds[$i-3],$wds[$i-2],$wds[$i-1]);
                }
                elsif ($i>1) {
                    ($ppwd,$pwd)=($wds[$i-2],$wds[$i-1]);
                }
                elsif ($i>0) {
                    $pwd=$wds[$i-1];
                }
                foreach my $wd2($pwd,$ppwd,$pppwd) {
                    next if (!$wd2);
                    # delete leading/trailing hyphen
                    $wd2=~s/^\-?(.+?)\-?$/$1/;
                    # convert to lowcase
                    $wd2=~tr/A-Z/a-z/;
                }
                my($p1,$p2,$n1,$n2)=&polSC($pol,$sc,$pwd,$ppwd,$pppwd,\%negwds,$proxMatch);
                $sc2p += $p2 if ($p2);
                $sc1p += $p1 if ($p1);
                $sc2n += $n2 if ($n2);
                $sc1n += $n1 if ($n1);

                print "PHsc4: wd=$wd, pol=$pol, p1=$p1, p2=$p2, n1=$n1, n2=$n2\n" if ($debug);

            } #end-if ($pol=~/[np]/) 

        } #end-if ($lexhp->{$wd})

    } #end-for(my $i=0; $i<@wds; $i++) 

    print "PHsc5: tlen=$tlen, s1=$sc1, s2=$sc2, s1p=$sc1p, s2p=$sc2p, s1n=$sc1n, s2n=$sc2n\n" if ($debug);

    if (!$flag) {   
        foreach my$sc($sc1,$sc2,$sc1p,$sc2p,$sc1n,$sc2n) {
            $sc /= $tlen if ($sc);
        }
    }          

    return ($sc1,$sc2,$sc1p,$sc2p,$sc1n,$sc2n);

} #endsub PHsc


#------------------------------------------------------------
# compute HF opinion score
#   - length-normalized match count
#-----------------------------------------------------------
# arg1 = text to be scored (qtitle match converted to placeholder)
# arg2 = text length
# arg3 = pointer to HF lexicon hash
#          key: term 
#          val: [pnm]N
# arg4 = negation placeholder 
# arg5 = query title match placeholder 
# arg6 = query title match count
# arg7 = proximity window size 
# arg8 = flag to return raw match count
# r.v. = (sc1, sc2, sc1p, sc2p, sc1n, sc2n)
#         sc1 - proximity match score
#         sc2 - simple match score
#         sc1p - proximity positive polarity match score
#         sc2p - simple positive poloarity match score
#         sc1n - proximity negative polarity match score
#         sc2n - simple negative poloarity match score
#-----------------------------------------------------------
# NOTE: 
#   1. repeated characters are compressed if word not found  in lexicon
#      - lexicon should contain repeat-compressed words as well as original
#-----------------------------------------------------------
sub HFsc {
    my($text,$tlen,$lexhp,$NOT,$QTM,$qtmcnt,$proxwinsize,$flag)=@_;
    my $debug=0;

    my ($sc1,$sc2,$sc1p,$sc2p,$sc1n,$sc2n)=(0,0,0,0,0,0);
    my %negwds=("not"=>1,"never"=>1,"no"=>1,"without"=>1,"hardly"=>1,"barely"=>1,"scarcely"=>1,"$NOT"=>1);

    # compress select prepositions, conjunctions, articles: for proximity match
    $text=~s/\s+(for|to|over|on|upon|in|with|of|and|or|a|an|the)\s+/ /gi;

    my @wds=split(/[^A-Za-z!\-]+/,$text);

    for(my $i=0; $i<@wds; $i++) {

        my $word=$wds[$i];

        # delete leading/trailing hyphen 
        $word=~s/^\-?(.+?)\-?$/$1/;

        my ($emp,$emp2)=(0,0);

        # words ending w/ !
        $emp=1 if ($word=~s/!$//);

        # words w/ 3+ repeat characters
        $emp2=1 if ($word=~/([a-z])\1{2,}/i);

        # convert to lowercase
        $word=~tr/A-Z/a-z/;

        # compress embedded repeat characters
        #  - exception: e, o
        my $wordc;
        if ($word=~/([a-cdf-np-z])\1+\B/) {
            $wordc=$word;
            $wordc=~s/([a-cdf-np-z])\1+\B/$1/g;
        }

        # compress hyphens
        my $wordh;
        if ($word=~/\-/) {
            $wordh=$word;
            $wordh=~s/\-+//g;
        }

        print "HFsc1: word=$word, emp=$emp, emp2=$emp2\n" if ($debug);

        foreach my $wd($word,$wordc,$wordh) {
            next if (!$wd);

            print "HFsc2: wd=$wd\n" if ($debug);

            if ($lexhp->{$wd}) {

                $lexhp->{$wd}=~/^(.)(\d)/;
                my($pol,$sc)=($1,$2);
                $sc++ if ($emp);
                $sc++ if ($emp2);

                print "HFsc3: $wds[$i]=$lexhp->{$wd}, pol=$pol, sc=$sc\n" if ($debug);

                # increment opinion score
                $sc2 += $sc;

                # flag proximity match
                my $proxMatch=0;
                if ($qtmcnt) {
                    my $minI=$i-$proxwinsize;
                    my $maxI=$i+$proxwinsize;
                    $minI=0 if ($minI<0);
                    $maxI=$#wds if ($maxI>$#wds);
                    my $proxstr= join(' ',@wds[$minI..$maxI]);
                    if ($proxstr=~/$QTM/) {
                        $proxMatch=1;
                        $sc1 += $sc;
                    }
                    print "HFsc4: wd=$wds[$i], sc=$sc, pmatch=$proxMatch, proxstr=$proxstr\n" if ($debug);
                }

                # polarity score
                if ($pol=~/[np]/) {
                    my($pwd,$ppwd,$pppwd);  # preceding words
                    if ($i>2) {
                        ($pppwd,$ppwd,$pwd)=($wds[$i-3],$wds[$i-2],$wds[$i-1]);
                    }
                    elsif ($i>1) {
                        ($ppwd,$pwd)=($wds[$i-2],$wds[$i-1]);
                    }
                    elsif ($i>0) {
                        $pwd=$wds[$i-1];
                    }
                    foreach my $wd2($pwd,$ppwd,$pppwd) {
                        next if (!$wd2);
                        # delete leading/trailing hyphen
                        $wd2=~s/^\-?(.+?)\-?$/$1/;
                        # convert to lowcase
                        $wd2=~tr/A-Z/a-z/;
                    }
                    my($p1,$p2,$n1,$n2)=&polSC($pol,$sc,$pwd,$ppwd,$pppwd,\%negwds,$proxMatch);
                    $sc2p += $p2 if ($p2);
                    $sc1p += $p1 if ($p1);
                    $sc2n += $n2 if ($n2);
                    $sc1n += $n1 if ($n1);

                    print "HFsc5: wd=$wd, pol=$pol, p1=$p1, p2=$p2, n1=$n1, n2=$n2\n" if ($debug);

                } #end-if ($pol=~/[np]/) 

                last;

            } #end-if ($lexhp->{$wd})

        } #end-foreach my $wd($word,$wordc,$wordh) 

    } #end-for(my $i=0; $i<@wds; $i++) 

    print "HFsc6: tlen=$tlen, s1=$sc1, s2=$sc2, s1p=$sc1p, s2p=$sc2p, s1n=$sc1n, s2n=$sc2n\n" if ($debug);

    if (!$flag) {   
        foreach my$sc($sc1,$sc2,$sc1p,$sc2p,$sc1n,$sc2n) {
            $sc /= $tlen if ($sc);
        }
    }          

    return ($sc1,$sc2,$sc1p,$sc2p,$sc1n,$sc2n);

} #endsub HFsc


#------------------------------------------------------------
# compute HF opinion scoring of a term
#-----------------------------------------------------------
# arg1 = word to be scored
# arg2 = emphasis flag
# arg3 = emphasis flag 2
# arg4 = proximity match flag
# arg5 = pointer to HF lexicon hash
#          key: term, val: [pnm]N
# arg6 = pointer to negation hash
# arg7 = preceding word
# arg8 = pre-preceding word
# arg9 = pre-pre-preceding word
# r.v. = score hash
#          key: score name 
#               hf   - simple match score
#               hfP  - simple positive poloarity match score
#               hfN  - simple negative poloarity match score
#               hfx  - proximity match score
#               hfxP - proximity positive polarity match score
#               hfxN - proximity negative polarity match score
#          val: score
#-----------------------------------------------------------
# NOTE: 
#   1. repeated characters are compressed if word not found  in lexicon
#      - lexicon should contain repeat-compressed words as well as original
#-----------------------------------------------------------
sub HFsc2 {
    my($wd,$emp,$emp2,$prxmatch,$lexhp,$neghp,$pwd,$ppwd,$pppwd)=@_;
    my $debug=0;

    my %sc;

    if ($lexhp->{$wd}) {

        $lexhp->{$wd}=~/^(.)(\d)/;
        my($pol,$sc)=($1,$2);
        $sc++ if ($emp);
        $sc++ if ($emp2);

        # opinion score
        $sc{'sc'} = $sc;

        # prox. match score
        $sc{'scx'} = $sc if ($prxmatch);

        # polarity score
        if ($pol=~/[np]/) {
            my($xp,$p,$xn,$n)=&polSC($pol,$sc,$pwd,$ppwd,$pppwd,$neghp,$prxmatch);
            $sc{'scxP'} = $xp if ($xp);
            $sc{'scP'} = $p if ($p);
            $sc{'scxN'} = $xn if ($xn);
            $sc{'scN'} = $n if ($n);
            print "HFsc2: wd=$wd, pol=$pol, xp=$xp, p=$p, xn=$xn, n=$n\n" if ($debug);
        } 

    } #end-if ($lexhp->{$wd})

    return (%sc);

} #endsub HFsc2


#------------------------------------------------------------
# compute HF opinion scoring of a term for a set of queries
#-----------------------------------------------------------
# arg1 = word to be scored
# arg2 = emphasis flag
# arg3 = emphasis flag 2
# arg4 = pointer to proximity match hash
#          key: QN, val: 1,0
# arg5 = pointer to HF lexicon hash
#          key: term, val: [pnm]N
# arg6 = pointer to negation hash
# arg7 = preceding word
# arg8 = pre-preceding word
# arg9 = pre-pre-preceding word
# r.v. = score hash
#        k1= QN (NOTE: 0= query independent scores)
#        v1= hash pointer
#            k2: score name
#                sc   - simple match score
#                scP  - simple positive poloarity match score
#                scN  - simple negative poloarity match score
#                scx  - proximity match score
#                scxP - proximity positive polarity match score
#                scxN - proximity negative polarity match score
#            v2: score
#-----------------------------------------------------------
# NOTE: 
#   1. repeated characters are compressed if word not found  in lexicon
#      - lexicon should contain repeat-compressed words as well as original
#-----------------------------------------------------------
sub HFsc3 {
    my($wd,$emp,$emp2,$prxhp,$lexhp,$neghp,$pwd,$ppwd,$pppwd)=@_;
    my $debug=0;

    my %sc;

    if ($lexhp->{$wd}) {

        $lexhp->{$wd}=~/^(.)(\d)/;
        my($pol,$sc)=($1,$2);
        $sc++ if ($emp);
        $sc++ if ($emp2);

        # opinion score
        $sc{0}{'sc'} = $sc;

        # polarity score
        my($p,$n)=(0,0);
        if ($pol=~/[np]/) {
            ($p,$n)=&polSC0($pol,$sc,$pwd,$ppwd,$pppwd,$neghp);
            $sc{0}{'scP'} = $p;
            $sc{0}{'scN'} = $n;
            print "HFsc3(q0): wd=$wd, pol=$pol, scp=$p, scn=$n\n" if ($debug);
        }

        # prox. match score
        foreach my $qn(keys %$prxhp) {
            my $prxmatch= $prxhp->{$qn};
            ($sc{$qn}{'scxP'},$sc{$qn}{'scxN'})=(0,0);

            if ($prxmatch) {
                $sc{$qn}{'scx'} = $sc;
                # polarity score
                if ($pol=~/[np]/) {
                    $sc{$qn}{'scxP'} = $p;
                    $sc{$qn}{'scxN'} = $n;
                } 
                print "HFsc3-prxm(q$qn): scx=$sc{$qn}{'scx'}, scxp=$sc{$qn}{'scxP'}, scxn=$sc{$qn}{'scxN'}\n" if ($debug);
            } 
        } 

    } #end-if ($lexhp->{$wd})

    return (%sc);

} #endsub HFsc3


#------------------------------------------------------------
# compute HF opinion scoring of a term for a set of queries
#  - idist score computation added
#-----------------------------------------------------------
# arg1 = word to be scored
# arg2 = emphasis flag
# arg3 = emphasis flag 2
# arg4 = pointer to proximity match hash
#          key: QN, val: 1,0
# arg5 = pointer to word distance hash
#          key: QN, val: min. distance between word and query match
# arg6 = pointer to HF lexicon hash
#          key: term, val: [pnm]N
# arg7 = pointer to negation hash
# arg8 = preceding word
# arg9 = pre-preceding word
# arg10 = pre-pre-preceding word
# r.v. = score hash
#        k1= QN (NOTE: 0= query independent scores)
#        v1= hash pointer
#            k2: score name
#                sc   - simple match score
#                scP  - simple positive poloarity match score
#                scN  - simple negative poloarity match score
#                scx  - proximity match score
#                scxP - proximity positive polarity match score
#                scxN - proximity negative polarity match score
#                scd  - distance match score
#                scdP - distance positive polarity match score
#                scdN - distance negative polarity match score
#            v2: score
#-----------------------------------------------------------
# NOTE: 
#   1. repeated characters are compressed if word not found  in lexicon
#      - lexicon should contain repeat-compressed words as well as original
#-----------------------------------------------------------
sub HFsc4 {
    my($wd,$emp,$emp2,$prxhp,$dsthp,$maxwdist,$lexhp,$neghp,$pwd,$ppwd,$pppwd)=@_;
    my $debug=0;

    my %sc;

    if ($lexhp->{$wd}) {

        $lexhp->{$wd}=~/^(.)(\d)/;
        my($pol,$sc)=($1,$2);
        $sc++ if ($emp);
        $sc++ if ($emp2);

        # opinion score
        $sc{0}{'sc'} = $sc;

        # polarity score
        my($p,$n)=(0,0);
        if ($pol=~/[np]/) {
            ($p,$n)=&polSC0($pol,$sc,$pwd,$ppwd,$pppwd,$neghp);
            $sc{0}{'scP'} = $p;
            $sc{0}{'scN'} = $n;
            print "HFsc4(q0): wd=$wd, pol=$pol, scp=$p, scn=$n\n" if ($debug);
        }

        # prox. match score
        foreach my $qn(keys %$prxhp) {
            my $prxmatch= $prxhp->{$qn};
            ($sc{$qn}{'scx'},$sc{$qn}{'scxP'},$sc{$qn}{'scxN'})=(0,0,0);

            if ($prxmatch) {
                $sc{$qn}{'scx'} = $sc;
                # polarity score
                if ($pol=~/[np]/) {
                    $sc{$qn}{'scxP'} = $p;
                    $sc{$qn}{'scxN'} = $n;
                } 
                print "HFsc4-prxm(q$qn): scx=$sc{$qn}{'scx'}, scxp=$sc{$qn}{'scxP'}, scxn=$sc{$qn}{'scxN'}\n" if ($debug);
            } 
        } 

        # dist. match score !
        foreach my $qn(keys %$dsthp) {
            my $wdist= $dsthp->{$qn};
            ($sc{$qn}{'scd'},$sc{$qn}{'scdP'},$sc{$qn}{'scdN'})=(0,0,0);

            if ($wdist<$maxwdist) {  # max. word distance
                my $idist=1/log($wdist+2);
                $sc{$qn}{'scd'} = sprintf("%.4f",$sc*$idist);
                # polarity score
                if ($pol=~/[np]/) {
                    $sc{$qn}{'scdP'} = sprintf("%.4f",$p*$idist);
                    $sc{$qn}{'scdN'} = sprintf("%.4f",$n*$idist);
                } 
            } 
            print "HFsc4-dist(q$qn): scd=$sc{$qn}{'scd'}, scdp=$sc{$qn}{'scdP'}, scdn=$sc{$qn}{'scdN'}\n" if ($debug);
        } 

    } #end-if ($lexhp->{$wd})

    return (%sc);

} #endsub HFsc4


sub HFsc5 {
    my($wd,$emp,$emp2,$prxhp,$dsthp,$dst2hp,$maxwdist,$lexhp,$neghp,$pwd,$ppwd,$pppwd)=@_;
    my $debug=0;

    my %sc;

    if ($lexhp->{$wd}) {

        $lexhp->{$wd}=~/^(.)(\d)/;
        my($pol,$sc)=($1,$2);
        $sc++ if ($emp);
        $sc++ if ($emp2);

        # opinion score
        $sc{0}{'sc'} = $sc;

        # polarity score
        my($p,$n)=(0,0);
        if ($pol=~/[np]/) {
            ($p,$n)=&polSC0($pol,$sc,$pwd,$ppwd,$pppwd,$neghp);
            $sc{0}{'scP'} = $p;
            $sc{0}{'scN'} = $n;
            print "HFsc4(q0): wd=$wd, pol=$pol, scp=$p, scn=$n\n" if ($debug);
        }

        # prox. match score
        foreach my $qn(keys %$prxhp) {
            my $prxmatch= $prxhp->{$qn};
            ($sc{$qn}{'scx'},$sc{$qn}{'scxP'},$sc{$qn}{'scxN'})=(0,0,0);

            if ($prxmatch) {
                $sc{$qn}{'scx'} = $sc;
                # polarity score
                if ($pol=~/[np]/) {
                    $sc{$qn}{'scxP'} = $p;
                    $sc{$qn}{'scxN'} = $n;
                } 
                print "HFsc4-prxm(q$qn): scx=$sc{$qn}{'scx'}, scxp=$sc{$qn}{'scxP'}, scxn=$sc{$qn}{'scxN'}\n" if ($debug);
            } 
        } 

        # dist. match score !
        foreach my $qn(keys %$dsthp) {
            my $wdist= $dsthp->{$qn};
            ($sc{$qn}{'scd'},$sc{$qn}{'scdP'},$sc{$qn}{'scdN'})=(0,0,0);

            if ($wdist<$maxwdist) {  # max. word distance
                my $idist=1/log($wdist+2);
                $sc{$qn}{'scd'} = sprintf("%.4f",$sc*$idist);
                # polarity score
                if ($pol=~/[np]/) {
                    $sc{$qn}{'scdP'} = sprintf("%.4f",$p*$idist);
                    $sc{$qn}{'scdN'} = sprintf("%.4f",$n*$idist);
                } 
            } 
            print "HFsc4-dist(q$qn): scd=$sc{$qn}{'scd'}, scdp=$sc{$qn}{'scdP'}, scdn=$sc{$qn}{'scdN'}\n" if ($debug);
        } 
        foreach my $qn(keys %$dst2hp) {
            my $wdist= $dst2hp->{$qn};
            ($sc{$qn}{'scd2'},$sc{$qn}{'scd2P'},$sc{$qn}{'scd2N'})=(0,0,0);

            if ($wdist<$maxwdist) {  # max. word distance
                my $idist=1/log($wdist+2);
                $sc{$qn}{'scd2'} = sprintf("%.4f",$sc*$idist);
                # polarity score
                if ($pol=~/[np]/) {
                    $sc{$qn}{'scd2P'} = sprintf("%.4f",$p*$idist);
                    $sc{$qn}{'scd2N'} = sprintf("%.4f",$n*$idist);
                } 
            } 
            print "HFsc4-dist2(q$qn): scd=$sc{$qn}{'scd2'}, scdp=$sc{$qn}{'scd2P'}, scdn=$sc{$qn}{'scd2N'}\n" if ($debug);
        } 

    } #end-if ($lexhp->{$wd})

    return (%sc);

} #endsub HFsc5


sub HFsc7 {
    my($wd,$emp,$emp2,$prxhp,$dsthp,$dst2hp,$maxwdist,$lexhp,$neghp,$pwd,$ppwd,$pppwd)=@_;
    my $debug=0;

    my %sc;

    if ($lexhp->{$wd}) {

        foreach my $wname('man','combo','prob') {

            my $lexsc= $lexhp->{$wd}{$wname};

            print "lexsc=$lexsc, name=$wname\n" if ($debug>3);  ##!!
            my($pol,$sc)=split//,$lexsc,2;
            $sc++ if ($emp);
            $sc++ if ($emp2);

            # opinion score
            $sc{0}{'sc'}{$wname} = $sc;

            # polarity score
            my($p,$n)=(0,0);
            if ($pol=~/[np]/) {
                ($p,$n)=&polSC0($pol,$sc,$pwd,$ppwd,$pppwd,$neghp);
                $sc{0}{'scP'}{$wname} = $p;
                $sc{0}{'scN'}{$wname} = $n;
                print "HFsc4(q0): wd=$wd, pol=$pol, scp=$p, scn=$n\n" if ($debug);
            }

            # prox. match score
            foreach my $qn(keys %$prxhp) {
                my $prxmatch= $prxhp->{$qn};
                ($sc{$qn}{'scx'}{$wname},$sc{$qn}{'scxP'}{$wname},$sc{$qn}{'scxN'}{$wname})=(0,0,0);

                if ($prxmatch) {
                    $sc{$qn}{'scx'}{$wname} = $sc;
                    # polarity score
                    if ($pol=~/[np]/) {
                        $sc{$qn}{'scxP'}{$wname} = $p;
                        $sc{$qn}{'scxN'}{$wname} = $n;
                    } 
                    print "HFsc4-prxm(q$qn): scx=$sc{$qn}{'scx'}, scxp=$sc{$qn}{'scxP'}, scxn=$sc{$qn}{'scxN'}\n" if ($debug);
                } 
            } 

            # dist. match score !
            foreach my $qn(keys %$dsthp) {
                my $wdist= $dsthp->{$qn};
                ($sc{$qn}{'scd'}{$wname},$sc{$qn}{'scdP'}{$wname},$sc{$qn}{'scdN'}{$wname})=(0,0,0);

                if ($wdist<$maxwdist) {  # max. word distance
                    my $idist=1/log($wdist+2);
                    $sc{$qn}{'scd'}{$wname} = sprintf("%.4f",$sc*$idist);
                    # polarity score
                    if ($pol=~/[np]/) {
                        $sc{$qn}{'scdP'}{$wname} = sprintf("%.4f",$p*$idist);
                        $sc{$qn}{'scdN'}{$wname} = sprintf("%.4f",$n*$idist);
                    } 
                } 
                print "HFsc4-dist(q$qn): scd=$sc{$qn}{'scd'}, scdp=$sc{$qn}{'scdP'}, scdn=$sc{$qn}{'scdN'}\n" if ($debug);
            } 
            foreach my $qn(keys %$dst2hp) {
                my $wdist= $dst2hp->{$qn};
                ($sc{$qn}{'scd2'}{$wname},$sc{$qn}{'scd2P'}{$wname},$sc{$qn}{'scd2N'}{$wname})=(0,0,0);

                if ($wdist<$maxwdist) {  # max. word distance
                    my $idist=1/log($wdist+2);
                    print "qn=$qn, wname=$wname, sc=$sc, idist=$idist\n" if ($debug>3);  ##!!
                    $sc{$qn}{'scd2'}{$wname} = sprintf("%.4f",$sc*$idist);
                    # polarity score
                    if ($pol=~/[np]/) {
                        $sc{$qn}{'scd2P'}{$wname} = sprintf("%.4f",$p*$idist);
                        $sc{$qn}{'scd2N'}{$wname} = sprintf("%.4f",$n*$idist);
                    } 
                } 
                print "HFsc4-dist2(q$qn): scd=$sc{$qn}{'scd2'}, scdp=$sc{$qn}{'scd2P'}, scdn=$sc{$qn}{'scd2N'}\n" if ($debug);
            } 

        } 

    } #end-if ($lexhp->{$wd})

    return (%sc);

} #endsub HFsc7


sub AVsc {
    my($wd,$prxhp,$plexhp,$nlexhp)=@_;
    my $debug=0;

    my %sc;
    $sc{0}{'psc'} = 0;
    $sc{0}{'nsc'} = 0;

    if ($plexhp->{$wd}) {

        # opinion score
        $sc{0}{'psc'} = 1;

        # prox. match score
        foreach my $qn(keys %$prxhp) {
            my $prxmatch= $prxhp->{$qn};
            if ($prxmatch) { $sc{$qn}{'pscx'} = 1; } 
            else { $sc{$qn}{'pscx'} = 0; } 
        } 


    } #end-if ($lexhp->{$wd})

    elsif ($nlexhp->{$wd}) {

        # opinion score
        $sc{0}{'nsc'} = 1;

        # prox. match score
        foreach my $qn(keys %$prxhp) {
            my $prxmatch= $prxhp->{$qn};
            if ($prxmatch) { $sc{$qn}{'nscx'} = 1; } 
            else { $sc{$qn}{'nscx'} = 0; } 
        } 


    } #end-if ($lexhp->{$wd})

    return (%sc);

} #endsub AVsc



#------------------------------------------------------------
# compute IU opinion score
#   - length-normalized match count
#-----------------------------------------------------------
# arg1 = text to be scored
# arg2 = text length
# arg3 = pointer to IU lexicon hash
#          key: I, I'm, my, me
#          val: pointer to term-polarity hash (k=term, v=polarity score)
# arg4 = negation placeholder 
# arg5 = query title match placeholder 
# arg6 = query title match count
# arg7 = proximity window size 
# arg8 = flag to return raw match count
# r.v. = (sc1, sc2, sc1p, sc2p, sc1n, sc2n)
#         sc1 - proximity match score
#         sc2 - simple match score
#         sc1p - proximity polarity match score
#         sc2p - simple poloarity match score
#         sc1n - proximity negative polarity match score
#         sc2n - simple negative poloarity match score
#-----------------------------------------------------------
# NOTE: 
#   1. repeated characters are compressed if word not found  in lexicon
#      - lexicon should contain repeat-compressed words as well as original
#   2. count strong IU patterns?
#      e.g., I'm, I am, I think, for me, imho, etc.
#-----------------------------------------------------------
sub IUsc {
    my($text,$tlen,$lexhp,$NOT,$QTM,$qtmcnt,$proxwinsize,$flag)=@_;
    my $debug=0;

    my %negwds=("not"=>1,"never"=>1,"no"=>1,"without"=>1,"hardly"=>1,"barely"=>1,"scarcely"=>1,"$NOT"=>1);
    my ($sc1,$sc2,$sc1p,$sc2p,$sc1n,$sc2n)=(0,0,0,0,0,0);

    print "IUsc: TEXT1=\n$text\n\n" if ($debug>1);

    #-----------------------------
    # normalize IU phrase: 
    #-----------------------------

    # compress select prepositions, conjunctions, articles
    $text=~s/\s+(for|to|over|on|upon|in|with|of|and|or|a|an|the)\s+/ /gi;

    # e.g., 'cannot ever really be truly and completely satisfying to me' to 'every really be truly satisfying ME-NOT'
    $text=~s/\b($NOT\s+([A-Za-z]+\s+){0,6})(me|you|us)\b/$1ME-NOT/gi;

    # e.g., 'cannot really ever truly and unconditionally have my' to 'really ever truly unconditionally have MY-NOT'
    $text=~s/\b($NOT\s+([A-Za-z]+\s+){0,6})(my|your|our)\b/$1MY-NOT/gi;

    # e.g., 'my total and undying support of him really and truly cannot' to 'MY-NOT total undying support really truly cannot'
    $text=~s/\b(my|your|our)\s+(([A-Za-z]+\s+){0,6}$NOT)\s+/MY-NOT $2 /gi;

    # e.g., 'I truly and seriously cannot' to 'I-NOT'
    $text=~s/\b(I|you|we)\s+([A-Za-z]+\s+){0,2}$NOT\s+/I-NOT /gi;

    # e.g., 'I very likely will' to 'I '
    $text=~s/\b(I|you|we)\s+([A-Za-z]+\s+){0,2}(can|could|will|would|shall|should|must|do|did|may|might|am|was|are|were|have to|had to|have|had|need)\s+/I /gi;

    print "IUsc: TEXT2=\n$text\n\n" if ($debug>1);

    my @wds=split(/[^a-zA-Z!\-]+/,$text);

    for(my $i=0; $i<@wds; $i++) {

        # delete leading/trailing hyphen
        $wds[$i]=~s/^\-?(.+?)\-?$/$1/;

        my ($emp,$emp2)=(0,0);        

        # words ending w/ !
        $emp=1 if ($wds[$i]=~s/!$//);

        # words w/ 3+ repeat characters
        $emp2=1 if ($wds[$i]=~/([a-z])\1{2,}/i);

        my ($neg,$iu,$iu2)=(0);
        my ($wd1,$wd2,$wd3,$wd1b,$wd2b,$wd3b);

        #-----------------------------------------
        # flag IU phrase and get adjacent terms

        if ($wds[$i]=~/^(I|we|I-NOT)$/i) {
            $neg=1 if ($1=~/\-NOT/);
            $iu='I';
            # allow for up to 2 words in-between
            #  e.g., "I truly seriously believe",
            if ($i+3 < @wds) { ($wd1,$wd2,$wd3)=($wds[$i+1],$wds[$i+2],$wds[$i+3]); }
            elsif ($i+2 < @wds) { ($wd1,$wd2)=($wds[$i+1],$wds[$i+2]); }
            elsif ($i+1 < @wds) { $wd1=$wds[$i+1]; }
        }

        elsif ($wds[$i]=~/^(my|your|our|MY-NOT)$/i) {
            $neg=1 if ($1=~/\-NOT/);
            $iu='my';
            # allow for up to 2 words in-between
            #  e.g., "I truly seriously believe",
            if ($i+3 < @wds) { ($wd1,$wd2,$wd3)=($wds[$i+1],$wds[$i+2],$wds[$i+3]); }
            elsif ($i+2 < @wds) { ($wd1,$wd2)=($wds[$i+1],$wds[$i+2]); }
            elsif ($i+1 < @wds) { $wd1=$wds[$i+1]; }
        }

        elsif ($wds[$i]=~/^(me|us|ME-NOT)$/i) {
            $neg=1 if ($1=~/\-NOT/);
            $iu='me';
            # allow for up to 2 words in-between
            #  e.g. "impressed the hell out of me"
            #  NOTE: 'the' & 'of' are already compressed
            if ($i > 2) { ($wd1,$wd2,$wd3)=($wds[$i-1],$wds[$i-2],$wds[$i-3]); }
            elsif ($i > 1) { ($wd1,$wd2)=($wds[$i-1],$wds[$i-2]); }
            elsif ($i > 0) { $wd1=$wds[$i-1]; }
        }

        # NOTE: 'you believe' or 'impressed you'
        elsif ($wds[$i]=~/^you$/i) {
            $iu='I';
            # allow for up to 2 words in-between
            #  e.g., "you truly seriously believe",
            if ($i+3 < @wds) { ($wd1,$wd2,$wd3)=($wds[$i+1],$wds[$i+2],$wds[$i+3]); }
            elsif ($i+2 < @wds) { ($wd1,$wd2)=($wds[$i+1],$wds[$i+2]); }
            elsif ($i+1 < @wds) { $wd1=$wds[$i+1]; }
            $iu2='me';
            # allow for up to 2 words in-between
            #  e.g. "impressed the hell out of you"
            #  NOTE: 'the' & 'of' are already compressed
            if ($i > 2) { ($wd1b,$wd2b,$wd3b)=($wds[$i-1],$wds[$i-2],$wds[$i-3]); }
            elsif ($i > 1) { ($wd1b,$wd2b)=($wds[$i-1],$wds[$i-2]); }
            elsif ($i > 0) { $wd1b=$wds[$i-1]; }
        }

        #-----------------------------------------
        # compute IU opinion scores

        my $forI=0;
        foreach my $word($wd1,$wd2,$wd3,$wd1b,$wd2b,$wd3b) {

            $forI++;
            next if (!$word);

            my $fI= $forI%3;

            # delete leading/trailing hyphen
            $word=~s/^\-?(.+?)\-?$/$1/;

            # words ending w/ !
            $emp=1 if ($word=~s/!$//);

            # words w/ 3+ repeat characters
            $emp2=1 if ($word=~/([a-z])\1{2,}/i);

            # convert to lowcase
            $word=~tr/A-Z/a-z/;

            $iu=$iu2 if ($forI>3);

            print "IUsca: iu=$iu, word=$word, emp=$emp, emp2=$emp2\n" if ($debug);

            # compress repeat characters
            #  - exception: e, o
            my $wordc;
            if ($word=~/([a-cdf-np-z])\1+\B/) {
                $wordc=$word;
                $wordc=~s/([a-cdf-np-z])\1+\B/$1/g;
            }

            # compress hyphens
            my $wordh;
            if ($word=~/\-/) {
                $wordh=$word;
                $wordh=~s/\-+//g;
            }

            foreach my $wd($word,$wordc,$wordh) {
                next if (!$wd);

                print "IUscb: wd=$wd\n" if ($debug);

                if ($lexhp->{$iu}->{$wd}) {

                    $lexhp->{$iu}->{$wd}=~/^(.)(\d)/;
                    my($pol,$sc)=($1,$2);
                    $sc++ if ($emp);
                    $sc++ if ($emp2);
                            
                    print "IUscc: FOUND wd=$wd, iu=$iu, sc=$sc, pol=$pol\n" if ($debug);

                    # increment opinion score
                    $sc2 += $sc;
                            
                    # flag proximity match
                    my $proxMatch=0;
                    if ($qtmcnt) {
                        my $minI=$i-$proxwinsize;
                        my $maxI=$i+$proxwinsize;
                        $minI=0 if ($minI<0);
                        $maxI=$#wds if ($maxI>$#wds);
                        my $proxstr= join(' ',@wds[$minI..$maxI]);
                        if ($proxstr=~/$QTM/) {
                            $proxMatch=1;
                            $sc1 += $sc;
                        }
                        print "IUscd: iu=$iu, wd=$wd, pmatch=$proxMatch, proxstr=$proxstr\n" if ($debug);
                    }

                    # polarity score
                    if ($pol=~/[np]/) {

                        my($pwd,$ppwd,$pppwd);  # preceding words
                        if ($iu eq 'my') {
                            # e.g. 'HARDLY ever gets my'
                            #      (compressed to 'HARDLY make strong impression me')
                            if ($i>2) {
                                ($pppwd,$ppwd,$pwd)=($wds[$i-3],$wds[$i-2],$wds[$i-1]);
                            }
                            elsif ($i>1) {
                                ($ppwd,$pwd)=($wds[$i-2],$wds[$i-1]);
                            }
                            elsif ($i>0) {
                                $pwd=$wds[$i-1];
                            }
                        }
                        elsif ($iu eq 'me') {
                            # e.g. 'hardly make a strong impression on me'
                            #      (compressed to 'HARDLY make strong impression me')
                            if ($i>3) {
                                ($pppwd,$ppwd,$pwd)=($wds[$i-3-$fI],$wds[$i-2-$fI],$wds[$i-1-$fI]);
                            }
                            elsif ($i>2) {
                                ($ppwd,$pwd)=($wds[$i-2-$fI],$wds[$i-1-$fI]);
                            }
                            elsif ($i>1) {
                                $pwd=$wds[$i-1-$fI];
                            }
                        }

                        foreach my $wd2($pwd,$ppwd,$pppwd) {
                            next if (!$wd2);
                            # delete leading/trailing hyphen
                            $wd2=~s/^\-?(.+?)\-?$/$1/;
                            # convert to lowcase
                            $wd2=~tr/A-Z/a-z/;
                        }

                        my($p1,$p2,$n1,$n2)=&polSC($pol,$sc,$pwd,$ppwd,$pppwd,\%negwds,$proxMatch,$neg);
                        $sc2p += $p2 if ($p2);
                        $sc1p += $p1 if ($p1);
                        $sc2n += $n2 if ($n2);
                        $sc1n += $n1 if ($n1);

                        print "IUsce: iu=$iu, wd=$wd, pol=$pol, p1=$p1, p2=$p2, n1=$n1, n2=$n2\n" if ($debug);

                    } #end-if ($pol=~/[np]/) 

                    last;

                } #end-if ($wd && $lexhp->{$iu}->{$wd}) 

            } #end-foreach my $wd($word,$wordc,$wordh) 

        } #end-foreach my $wd($wd1,$wd2,$wd3,$wd1b,$wd2b,$wd3b) 

    } #end-for(my $i=0; $i<@wds; $i++) 

    print "IUscf: tlen=$tlen, s1=$sc1, s2=$sc2, s1p=$sc1p, s2p=$sc2p, s1n=$sc1n, s2n=$sc2n\n" if ($debug);

    if (!$flag) {
        foreach my$sc($sc1,$sc2,$sc1p,$sc2p,$sc1n,$sc2n) {
            $sc /= ($tlen/2) if ($sc);  # use half doclen since IU is bigram at the least
        }
    }

    return ($sc1,$sc2,$sc1p,$sc2p,$sc1n,$sc2n);

} #endsub IUsc


#------------------------------------------------------------
# compute IU opinion scoring of a term
#-----------------------------------------------------------
# arg1 = word to be scored
# arg2 = emphasis flag
# arg3 = emphasis flag 2
# arg4 = proximity match flag
# arg5 = pointer to IU lexicon hash
#          key: term, val: [pnm]N
# arg6 = pointer to negation hash
# arg7 = preceding word
# arg8 = pre-preceding word
# arg9 = pre-pre-preceding word
# arg10 = pointer to preceding word hash for iu=me
#           k=0,1,2;  v= [pwd,ppwd,pppwd]
# arg11 = pointer to adjacent IU words list
# arg12 = iu anchor 1
# arg13 = iu anchor 2
# arg14 = negation flag
# r.v. = score hash
#          key: score name
#               hf   - simple match score
#               hfP  - simple positive poloarity match score
#               hfN  - simple negative poloarity match score
#               hfx  - proximity match score
#               hfxP - proximity positive polarity match score
#               hfxN - proximity negative polarity match score
#          val: score
#-----------------------------------------------------------
# NOTE:
#   1. repeated characters are compressed if word not found  in lexicon
#      - lexicon should contain repeat-compressed words as well as original
#-----------------------------------------------------------
sub IUsc2 {
    my($wd,$emp,$emp2,$prxmatch,$lexhp,$neghp,$pwd,$ppwd,$pppwd,$pwdhp,$iuwdlp,$iu,$iu2,$neg)=@_;
    my $debug=0;

    print "IUsc2a: wd=$wd, iu=$iu, p1=$pwd, p2=$ppwd, p3=$pppwd, iuwds=@{$iuwdlp}\n" if ($debug);

    my %sc;

    my $forI=0;

    # search adjacent terms to IU anchor for lexicon match
    DONE: foreach my $word(@{$iuwdlp}) {

        $forI++;
        next if (!$word);

        my $fI= $forI%3;

        # compress hyphens
        my $wordh;
        if ($word=~/\-/) {
            # delete leading/trailing hyphen
            $word=~s/^\-?(.+?)\-?$/$1/;
            $wordh=$word;
            $wordh=~s/\-+//g;
        }

        # words ending w/ !
        $emp=1 if ($word=~s/!$//);

        # words w/ 3+ repeat characters
        $emp2=1 if ($word=~/([a-z])\1{2,}/i);

        $iu=$iu2 if ($forI>3);

        # compress repeat characters
        #  - exception: e, o
        my $wordc;
        if ($word=~/([a-cdf-np-z])\1+\B/) {
            $wordc=$word;
            $wordc=~s/([a-cdf-np-z])\1+\B/$1/g;
        }

        print "IUsc2b: iu=$iu, word=$word, emp=$emp, emp2=$emp2, forI=$forI, fI=$fI\n" if ($debug);

        foreach my $wd($word,$wordc,$wordh) {
            next if (!$wd);

            print "IUsc2c: wd=$wd\n" if ($debug);

            if ($lexhp->{$iu}{$wd}) {

                $lexhp->{$iu}{$wd}=~/^(.)(\d)/;
                my($pol,$sc)=($1,$2);
                $sc++ if ($emp);
                $sc++ if ($emp2);
                        
                print "IUsc2e: FOUND wd=$wd, iu=$iu, sc=$sc, pol=$pol\n" if ($debug);

                # increment opinion score
                $sc{'sc'} += $sc;
                        
                # prox. match score
                $sc{'scx'} += $sc if ($prxmatch);

                # polarity score
                if ($pol=~/[np]/) {

                    my($xp,$p,$xn,$n);

                    if ($iu eq 'I') {
                        ($pwd,$ppwd,$pppwd)= ();
                    }
                    elsif ($iu eq 'me') {
                        # e.g. 'hardly make a strong impression on me'
                        #      (compressed to 'HARDLY make strong impression me')
                        ($pwd,$ppwd,$pppwd)= ($pwdhp->{$fI}[0],$pwdhp->{$fI}[1],$pwdhp->{$fI}[2]);
                    }

                    ($xp,$p,$xn,$n)=&polSC($pol,$sc,$pwd,$ppwd,$pppwd,$neghp,$prxmatch,$neg);
                    $sc{'scxP'} += $xp if ($xp);
                    $sc{'scP'} += $p if ($p);
                    $sc{'scxN'} += $xn if ($xn);
                    $sc{'scN'} += $n if ($n);
                    print "IUsc2f: wd=$wd, pol=$pol, xp=$xp, p=$p, xn=$xn, n=$n\n" if ($debug);

                } #end-if ($pol=~/[np]/) 

                # stop searching adjacent terms at first match
                last DONE;

            } #end-if ($wd && $lexhp->{$iu}->{$wd}) 

        } #end-foreach my $wd($word,$wordc,$wordh) 

    } #end-foreach my $word(@$iuwdhp)

    return (%sc);

} #endsub IUsc2


#------------------------------------------------------------
# compute IU opinion scoring of a term
#-----------------------------------------------------------
# arg1 = word to be scored
# arg2 = emphasis flag
# arg3 = emphasis flag 2
# arg4 = pointer to proximity match hash
#          key: QN, val: 1,0
# arg5 = pointer to IU lexicon hash
#          key: term, val: [pnm]N
# arg6 = pointer to negation hash
# arg7 = preceding word
# arg8 = pre-preceding word
# arg9 = pre-pre-preceding word
# arg10 = pointer to preceding word hash for iu=me
#           k=0,1,2;  v= [pwd,ppwd,pppwd]
# arg11 = pointer to adjacent IU words list
# arg12 = iu anchor 1
# arg13 = iu anchor 2
# arg14 = negation flag
# arg15 = optional no term morph flag
# r.v. = score hash
#        k1= QN (NOTE: 0= query independent scores)
#        v1= hash pointer
#            k2: score name
#                sc   - simple match score
#                scP  - simple positive poloarity match score
#                scN  - simple negative poloarity match score
#                scx  - proximity match score
#                scxP - proximity positive polarity match score
#                scxN - proximity negative polarity match score
#            v2: score
#-----------------------------------------------------------
# NOTE:
#   1. repeated characters are compressed if word not found  in lexicon
#      - lexicon should contain repeat-compressed words as well as original
#-----------------------------------------------------------
sub IUsc3 {
    my($wd,$emp,$emp2,$prxhp,$lexhp,$neghp,$pwd,$ppwd,$pppwd,$pwdhp,$iuwdlp,$iu,$iu2,$neg,$nomrpf)=@_;
    my $debug=0;

    print "IUsc3a: wd=$wd, iu=$iu, p1=$pwd, p2=$ppwd, p3=$pppwd, iuwds=@{$iuwdlp}\n" if ($debug);

    my %sc;

    my $forI=0;

    # search adjacent terms to IU anchor for lexicon match
    DONE: foreach my $word(@{$iuwdlp}) {

        $forI++;
        next if (!$word);

        my $fI= $forI%3;

        # compress hyphens
        my $wordh;
        if (!$nomrpf && $word=~/\-/) {
            # delete leading/trailing hyphen
            $word=~s/^\-?(.+?)\-?$/$1/;
            $wordh=$word;
            $wordh=~s/\-+//g;
        }

        # words ending w/ !
        $emp=1 if ($word=~s/!$//);

        # words w/ 3+ repeat characters
        $emp2=1 if ($word=~/([a-z])\1{2,}/i);

        $iu=$iu2 if ($forI>3);

        # compress repeat characters
        #  - exception: e, o
        my $wordc;
        if (!$nomrpf && $word=~/([a-cdf-np-z])\1+\B/) {
            $wordc=$word;
            $wordc=~s/([a-cdf-np-z])\1+\B/$1/g;
        }

        print "IUsc3b: iu=$iu, word=$word, emp=$emp, emp2=$emp2, forI=$forI, fI=$fI\n" if ($debug);

        foreach my $wd($word,$wordc,$wordh) {
            next if (!$wd);

            print "IUsc3c: wd=$wd\n" if ($debug);

            if ($lexhp->{$iu}{$wd}) {

                $lexhp->{$iu}{$wd}=~/^(.)(\d)/;
                my($pol,$sc)=($1,$2);
                $sc++ if ($emp);
                $sc++ if ($emp2);
                        
                print "IUsc3e: FOUND wd=$wd, iu=$iu, sc=$sc, pol=$pol\n" if ($debug);

                # opinion score
                $sc{0}{'sc'} = $sc;
                        
                # polarity score
                my($p,$n)=(0,0);
                if ($pol=~/[np]/) {
                    ($p,$n)=&polSC0($pol,$sc,$pwd,$ppwd,$pppwd,$neghp,$neg);
                    $sc{0}{'scP'} = $p;
                    $sc{0}{'scN'} = $n;
                    if ($iu eq 'I') {
                        ($pwd,$ppwd,$pppwd)= ();
                    }
                    elsif ($iu eq 'me') {
                        # e.g. 'hardly make a strong impression on me'
                        #      (compressed to 'HARDLY make strong impression me')
                        ($pwd,$ppwd,$pppwd)= ($pwdhp->{$fI}[0],$pwdhp->{$fI}[1],$pwdhp->{$fI}[2]);
                    }
                    print "IUsc3f(q0): wd=$wd, pol=$pol, scp=$p, scn=$n\n" if ($debug);
                }

                # prox. match score
                foreach my $qn(keys %$prxhp) {
                    my $prxmatch= $prxhp->{$qn};
                    ($sc{$qn}{'scxP'},$sc{$qn}{'scxN'})=(0,0);

                    if ($prxmatch) {
                        $sc{$qn}{'scx'} = $sc;
                        # polarity score
                        if ($pol=~/[np]/) {
                            $sc{$qn}{'scxP'} = $p;
                            $sc{$qn}{'scxN'} = $n;
                        }
                        print "IUsc3g-prxm(q$qn): scx=$sc{$qn}{'scx'}, scxp=$sc{$qn}{'scxP'}, scxn=$sc{$qn}{'scxN'}\n" if ($debug);
                    }

                } #end-foreach $qn

                # stop searching adjacent terms at first match
                last DONE;

            } #end-if ($wd && $lexhp->{$iu}->{$wd}) 

        } #end-foreach my $wd($word,$wordc,$wordh) 

    } #end-foreach my $word(@$iuwdhp)

    return (%sc);

} #endsub IUsc3


#------------------------------------------------------------
# compute IU opinion scoring of a term for a set of queries
#  - idist score computation added
#-----------------------------------------------------------
# arg1 = word to be scored
# arg2 = emphasis flag
# arg3 = emphasis flag 2
# arg4 = pointer to proximity match hash
#          key: QN, val: 1,0
# arg5 = pointer to word distance hash
#          key: QN, val: min. distance between word and query match
# arg6 = pointer to IU lexicon hash
#          key: term, val: [pnm]N
# arg7 = pointer to negation hash
# arg8 = preceding word
# arg9 = pre-preceding word
# arg10 = pre-pre-preceding word
# arg11 = pointer to preceding word hash for iu=me
#           k=0,1,2;  v= [pwd,ppwd,pppwd]
# arg12 = pointer to adjacent IU words list
# arg13 = iu anchor 1
# arg14 = iu anchor 2
# arg15 = negation flag
# arg16 = optional no term morph flag
# r.v. = score hash
#        k1= QN (NOTE: 0= query independent scores)
#        v1= hash pointer
#            k2: score name
#                sc   - simple match score
#                scP  - simple positive poloarity match score
#                scN  - simple negative poloarity match score
#                scx  - proximity match score
#                scxP - proximity positive polarity match score
#                scxN - proximity negative polarity match score
#                scd  - distance match score
#                scdP - distance positive polarity match score
#                scdN - distance negative polarity match score
#            v2: score
#-----------------------------------------------------------
# NOTE:
#   1. repeated characters are compressed if word not found  in lexicon
#      - lexicon should contain repeat-compressed words as well as original
#-----------------------------------------------------------
sub IUsc4 {
    my($wd,$emp,$emp2,$prxhp,$dsthp,$maxwdist,$lexhp,$neghp,$pwd,$ppwd,$pppwd,$pwdhp,$iuwdlp,$iu,$iu2,$neg,$nomrpf)=@_;
    my $debug=0;

    print "IUsc4a: wd=$wd, iu=$iu, p1=$pwd, p2=$ppwd, p3=$pppwd, iuwds=@{$iuwdlp}\n" if ($debug);

    my %sc;

    my $forI=0;

    # search adjacent terms to IU anchor for lexicon match
    DONE: foreach my $word(@{$iuwdlp}) {

        $forI++;
        next if (!$word);

        my $fI= $forI%3;

        # compress hyphens
        my $wordh;
        if (!$nomrpf && $word=~/\-/) {
            # delete leading/trailing hyphen
            $word=~s/^\-?(.+?)\-?$/$1/;
            $wordh=$word;
            $wordh=~s/\-+//g;
        }

        # words ending w/ !
        $emp=1 if ($word=~s/!$//);

        # words w/ 3+ repeat characters
        $emp2=1 if ($word=~/([a-z])\1{2,}/i);

        $iu=$iu2 if ($forI>3);

        # compress repeat characters
        #  - exception: e, o
        my $wordc;
        if (!$nomrpf && $word=~/([a-cdf-np-z])\1+\B/) {
            $wordc=$word;
            $wordc=~s/([a-cdf-np-z])\1+\B/$1/g;
        }

        print "IUsc4b: iu=$iu, word=$word, emp=$emp, emp2=$emp2, forI=$forI, fI=$fI\n" if ($debug);

        foreach my $wd($word,$wordc,$wordh) {
            next if (!$wd);

            print "IUsc4c: wd=$wd\n" if ($debug);

            if ($lexhp->{$iu}{$wd}) {

                $lexhp->{$iu}{$wd}=~/^(.)(\d)/;
                my($pol,$sc)=($1,$2);
                $sc++ if ($emp);
                $sc++ if ($emp2);
                        
                print "IUsc4e: FOUND wd=$wd, iu=$iu, sc=$sc, pol=$pol\n" if ($debug);

                # opinion score
                $sc{0}{'sc'} = $sc;
                        
                # polarity score
                my($p,$n)=(0,0);
                if ($pol=~/[np]/) {
                    ($p,$n)=&polSC0($pol,$sc,$pwd,$ppwd,$pppwd,$neghp,$neg);
                    $sc{0}{'scP'} = $p;
                    $sc{0}{'scN'} = $n;
                    if ($iu eq 'I') {
                        ($pwd,$ppwd,$pppwd)= ();
                    }
                    elsif ($iu eq 'me') {
                        # e.g. 'hardly make a strong impression on me'
                        #      (compressed to 'HARDLY make strong impression me')
                        ($pwd,$ppwd,$pppwd)= ($pwdhp->{$fI}[0],$pwdhp->{$fI}[1],$pwdhp->{$fI}[2]);
                    }
                    print "IUsc4f(q0): wd=$wd, pol=$pol, scp=$p, scn=$n\n" if ($debug);
                }

                # prox. match score
                foreach my $qn(keys %$prxhp) {
                    my $prxmatch= $prxhp->{$qn};
                    ($sc{$qn}{'scx'},$sc{$qn}{'scxP'},$sc{$qn}{'scxN'})=(0,0,0);

                    if ($prxmatch) {
                        $sc{$qn}{'scx'} = $sc;
                        # polarity score
                        if ($pol=~/[np]/) {
                            $sc{$qn}{'scxP'} = $p;
                            $sc{$qn}{'scxN'} = $n;
                        }
                        print "IUsc4g-prxm(q$qn): scx=$sc{$qn}{'scx'}, scxp=$sc{$qn}{'scxP'}, scxn=$sc{$qn}{'scxN'}\n" if ($debug);
                    }

                } #end-foreach $qn

                # dist. match score !
                foreach my $qn(keys %$dsthp) {
                    my $wdist= $dsthp->{$qn};
                    ($sc{$qn}{'scd'},$sc{$qn}{'scdP'},$sc{$qn}{'scdN'})=(0,0,0);

                    if ($wdist<$maxwdist) {  # max. word distance
                        my $idist=1/log($wdist+2);
                        $sc{$qn}{'scd'} = sprintf("%.4f",$sc*$idist);
                        # polarity score
                        if ($pol=~/[np]/) {
                            $sc{$qn}{'scdP'} = sprintf("%.4f",$p*$idist);
                            $sc{$qn}{'scdN'} = sprintf("%.4f",$n*$idist);
                        }
                    }
                    print "IUsc4-dist(q$qn): scd=$sc{$qn}{'scd'}, scdp=$sc{$qn}{'scdP'}, scdn=$sc{$qn}{'scdN'}\n" if ($debug);
                }

                # stop searching adjacent terms at first match
                last DONE;

            } #end-if ($wd && $lexhp->{$iu}->{$wd}) 

        } #end-foreach my $wd($word,$wordc,$wordh) 

    } #end-foreach my $word(@$iuwdhp)

    return (%sc);

} #endsub IUsc4


sub IUsc5 {
    my($wd,$emp,$emp2,$prxhp,$dsthp,$dst2hp,$maxwdist,$lexhp,$neghp,$pwd,$ppwd,$pppwd,$pwdhp,$iuwdlp,$iu,$iu2,$neg,$nomrpf)=@_;
    my $debug=0;

    print "IUsc4a: wd=$wd, iu=$iu, p1=$pwd, p2=$ppwd, p3=$pppwd, iuwds=@{$iuwdlp}\n" if ($debug);

    my %sc;

    my $forI=0;

    # search adjacent terms to IU anchor for lexicon match
    DONE: foreach my $word(@{$iuwdlp}) {

        $forI++;
        next if (!$word);

        my $fI= $forI%3;

        # compress hyphens
        my $wordh;
        if (!$nomrpf && $word=~/\-/) {
            # delete leading/trailing hyphen
            $word=~s/^\-?(.+?)\-?$/$1/;
            $wordh=$word;
            $wordh=~s/\-+//g;
        }

        # words ending w/ !
        $emp=1 if ($word=~s/!$//);

        # words w/ 3+ repeat characters
        $emp2=1 if ($word=~/([a-z])\1{2,}/i);

        $iu=$iu2 if ($forI>3);

        # compress repeat characters
        #  - exception: e, o
        my $wordc;
        if (!$nomrpf && $word=~/([a-cdf-np-z])\1+\B/) {
            $wordc=$word;
            $wordc=~s/([a-cdf-np-z])\1+\B/$1/g;
        }

        print "IUsc4b: iu=$iu, word=$word, emp=$emp, emp2=$emp2, forI=$forI, fI=$fI\n" if ($debug);

        foreach my $wd($word,$wordc,$wordh) {
            next if (!$wd);

            print "IUsc4c: wd=$wd\n" if ($debug);

            if ($lexhp->{$iu}{$wd}) {

                $lexhp->{$iu}{$wd}=~/^(.)(\d)/;
                my($pol,$sc)=($1,$2);
                $sc++ if ($emp);
                $sc++ if ($emp2);
                        
                print "IUsc4e: FOUND wd=$wd, iu=$iu, sc=$sc, pol=$pol\n" if ($debug);

                # opinion score
                $sc{0}{'sc'} = $sc;
                        
                # polarity score
                my($p,$n)=(0,0);
                if ($pol=~/[np]/) {
                    ($p,$n)=&polSC0($pol,$sc,$pwd,$ppwd,$pppwd,$neghp,$neg);
                    $sc{0}{'scP'} = $p;
                    $sc{0}{'scN'} = $n;
                    if ($iu eq 'I') {
                        ($pwd,$ppwd,$pppwd)= ();
                    }
                    elsif ($iu eq 'me') {
                        # e.g. 'hardly make a strong impression on me'
                        #      (compressed to 'HARDLY make strong impression me')
                        ($pwd,$ppwd,$pppwd)= ($pwdhp->{$fI}[0],$pwdhp->{$fI}[1],$pwdhp->{$fI}[2]);
                    }
                    print "IUsc4f(q0): wd=$wd, pol=$pol, scp=$p, scn=$n\n" if ($debug);
                }

                # prox. match score
                foreach my $qn(keys %$prxhp) {
                    my $prxmatch= $prxhp->{$qn};
                    ($sc{$qn}{'scx'},$sc{$qn}{'scxP'},$sc{$qn}{'scxN'})=(0,0,0);

                    if ($prxmatch) {
                        $sc{$qn}{'scx'} = $sc;
                        # polarity score
                        if ($pol=~/[np]/) {
                            $sc{$qn}{'scxP'} = $p;
                            $sc{$qn}{'scxN'} = $n;
                        }
                        print "IUsc4g-prxm(q$qn): scx=$sc{$qn}{'scx'}, scxp=$sc{$qn}{'scxP'}, scxn=$sc{$qn}{'scxN'}\n" if ($debug);
                    }

                } #end-foreach $qn

                # dist. match score !
                foreach my $qn(keys %$dsthp) {
                    my $wdist= $dsthp->{$qn};
                    ($sc{$qn}{'scd'},$sc{$qn}{'scdP'},$sc{$qn}{'scdN'})=(0,0,0);

                    if ($wdist<$maxwdist) {  # max. word distance
                        my $idist=1/log($wdist+2);
                        $sc{$qn}{'scd'} = sprintf("%.4f",$sc*$idist);
                        # polarity score
                        if ($pol=~/[np]/) {
                            $sc{$qn}{'scdP'} = sprintf("%.4f",$p*$idist);
                            $sc{$qn}{'scdN'} = sprintf("%.4f",$n*$idist);
                        }
                    }
                    print "IUsc4-dist(q$qn): scd=$sc{$qn}{'scd'}, scdp=$sc{$qn}{'scdP'}, scdn=$sc{$qn}{'scdN'}\n" if ($debug);
                }
                foreach my $qn(keys %$dst2hp) {
                    my $wdist= $dst2hp->{$qn};
                    ($sc{$qn}{'scd2'},$sc{$qn}{'scd2P'},$sc{$qn}{'scd2N'})=(0,0,0);

                    if ($wdist<$maxwdist) {  # max. word distance
                        my $idist=1/log($wdist+2);
                        $sc{$qn}{'scd2'} = sprintf("%.4f",$sc*$idist);
                        # polarity score
                        if ($pol=~/[np]/) {
                            $sc{$qn}{'scd2P'} = sprintf("%.4f",$p*$idist);
                            $sc{$qn}{'scd2N'} = sprintf("%.4f",$n*$idist);
                        } 
                    } 
                    print "IUsc4-dist2(q$qn): scd=$sc{$qn}{'scd2'}, scdp=$sc{$qn}{'scd2P'}, scdn=$sc{$qn}{'scd2N'}\n" if ($debug);
                } 

                # stop searching adjacent terms at first match
                last DONE;

            } #end-if ($wd && $lexhp->{$iu}->{$wd}) 

        } #end-foreach my $wd($word,$wordc,$wordh) 

    } #end-foreach my $word(@$iuwdhp)

    return (%sc);

} #endsub IUsc5

sub IUsc7 {
    my($wd,$emp,$emp2,$prxhp,$dsthp,$dst2hp,$maxwdist,$lexhp,$neghp,$pwd,$ppwd,$pppwd,$pwdhp,$iuwdlp,$iu,$iu2,$neg,$nomrpf)=@_;
    my $debug=0;

    print "IUsc4a: wd=$wd, iu=$iu, p1=$pwd, p2=$ppwd, p3=$pppwd, iuwds=@{$iuwdlp}\n" if ($debug);

    my %sc;

    my $forI=0;

    # search adjacent terms to IU anchor for lexicon match
    DONE: foreach my $word(@{$iuwdlp}) {

        $forI++;
        next if (!$word);

        my $fI= $forI%3;

        # compress hyphens
        my $wordh;
        if (!$nomrpf && $word=~/\-/) {
            # delete leading/trailing hyphen
            $word=~s/^\-?(.+?)\-?$/$1/;
            $wordh=$word;
            $wordh=~s/\-+//g;
        }

        # words ending w/ !
        $emp=1 if ($word=~s/!$//);

        # words w/ 3+ repeat characters
        $emp2=1 if ($word=~/([a-z])\1{2,}/i);

        $iu=$iu2 if ($forI>3);

        # compress repeat characters
        #  - exception: e, o
        my $wordc;
        if (!$nomrpf && $word=~/([a-cdf-np-z])\1+\B/) {
            $wordc=$word;
            $wordc=~s/([a-cdf-np-z])\1+\B/$1/g;
        }

        print "IUsc4b: iu=$iu, word=$word, emp=$emp, emp2=$emp2, forI=$forI, fI=$fI\n" if ($debug);

        foreach my $wd($word,$wordc,$wordh) {
            next if (!$wd);

            print "IUsc4c: wd=$wd\n" if ($debug);

            if ($lexhp->{$iu}{$wd}) {

                foreach my $wname('man','combo','prob') {

                    my $lexsc= $lexhp->{$iu}{$wd}{$wname};

                    my($pol,$sc)=split//,$lexsc,2;
                    $sc++ if ($emp);
                    $sc++ if ($emp2);
                        
                    print "IUsc4e: FOUND wd=$wd, iu=$iu, sc=$sc, pol=$pol\n" if ($debug);

                    # opinion score
                    $sc{0}{'sc'}{$wname} = $sc;
                            
                    # polarity score
                    my($p,$n)=(0,0);
                    if ($pol=~/[np]/) {
                        ($p,$n)=&polSC0($pol,$sc,$pwd,$ppwd,$pppwd,$neghp,$neg);
                        $sc{0}{'scP'}{$wname} = $p;
                        $sc{0}{'scN'}{$wname} = $n;
                        if ($iu eq 'I') {
                            ($pwd,$ppwd,$pppwd)= ();
                        }
                        elsif ($iu eq 'me') {
                            # e.g. 'hardly make a strong impression on me'
                            #      (compressed to 'HARDLY make strong impression me')
                            ($pwd,$ppwd,$pppwd)= ($pwdhp->{$fI}[0],$pwdhp->{$fI}[1],$pwdhp->{$fI}[2]);
                        }
                        print "IUsc4f(q0): wd=$wd, pol=$pol, scp=$p, scn=$n\n" if ($debug);
                    }

                    # prox. match score
                    foreach my $qn(keys %$prxhp) {
                        my $prxmatch= $prxhp->{$qn};
                        ($sc{$qn}{'scx'}{$wname},$sc{$qn}{'scxP'}{$wname},$sc{$qn}{'scxN'}{$wname})=(0,0,0);

                        if ($prxmatch) {
                            $sc{$qn}{'scx'}{$wname} = $sc;
                            # polarity score
                            if ($pol=~/[np]/) {
                                $sc{$qn}{'scxP'}{$wname} = $p;
                                $sc{$qn}{'scxN'}{$wname} = $n;
                            }
                            print "IUsc4g-prxm(q$qn): scx=$sc{$qn}{'scx'}, scxp=$sc{$qn}{'scxP'}, scxn=$sc{$qn}{'scxN'}\n" if ($debug);
                        }

                    } #end-foreach $qn

                    # dist. match score !
                    foreach my $qn(keys %$dsthp) {
                        my $wdist= $dsthp->{$qn};
                        ($sc{$qn}{'scd'}{$wname},$sc{$qn}{'scdP'}{$wname},$sc{$qn}{'scdN'}{$wname})=(0,0,0);

                        if ($wdist<$maxwdist) {  # max. word distance
                            my $idist=1/log($wdist+2);
                            $sc{$qn}{'scd'}{$wname} = sprintf("%.4f",$sc*$idist);
                            # polarity score
                            if ($pol=~/[np]/) {
                                $sc{$qn}{'scdP'}{$wname} = sprintf("%.4f",$p*$idist);
                                $sc{$qn}{'scdN'}{$wname} = sprintf("%.4f",$n*$idist);
                            }
                        }
                        print "IUsc4-dist(q$qn): scd=$sc{$qn}{'scd'}, scdp=$sc{$qn}{'scdP'}, scdn=$sc{$qn}{'scdN'}\n" if ($debug);
                    }
                    foreach my $qn(keys %$dst2hp) {
                        my $wdist= $dst2hp->{$qn};
                        ($sc{$qn}{'scd2'}{$wname},$sc{$qn}{'scd2P'}{$wname},$sc{$qn}{'scd2N'}{$wname})=(0,0,0);

                        if ($wdist<$maxwdist) {  # max. word distance
                            my $idist=1/log($wdist+2);
                            $sc{$qn}{'scd2'}{$wname} = sprintf("%.4f",$sc*$idist);
                            # polarity score
                            if ($pol=~/[np]/) {
                                $sc{$qn}{'scd2P'}{$wname} = sprintf("%.4f",$p*$idist);
                                $sc{$qn}{'scd2N'}{$wname} = sprintf("%.4f",$n*$idist);
                            } 
                        } 
                        print "IUsc4-dist2(q$qn): scd=$sc{$qn}{'scd2'}, scdp=$sc{$qn}{'scd2P'}, scdn=$sc{$qn}{'scd2N'}\n" if ($debug);
                    } 

                } 

                # stop searching adjacent terms at first match
                last DONE;

            } #end-if ($wd && $lexhp->{$iu}->{$wd}) 

        } #end-foreach my $wd($word,$wordc,$wordh) 

    } #end-foreach my $word(@$iuwdhp)

    return (%sc);

} #endsub IUsc7


#------------------------------------------------------------
# compute LF opinion score
#   - length-normalized match count
#-----------------------------------------------------------
# arg1 = text to be scored
# arg2 = text length
# arg3 = pointer to LF lexicon hash
#          key: term, val: [pnm]N
# arg4 = pointer to LF regex hash
#          key: regex, val: [pnm]N
# arg5 = pointer to LF repeat-char morph regex hash
#          key: regex, val: [pnm]N
# arg6 = pointer to opinion acronym (AC) hash
#          key: acronym|phrase, val: [pnm]N
# arg7 = negation placeholder 
# arg8 = query title match placeholder 
# arg9 = query title match count
# arg10 = proximity window size 
# arg11 = flag to return raw match count
# r.v. = (sc1, sc2, sc1p, sc2p)
#         sc1 - proximity match score
#         sc2 - simple match score
#         sc1p - proximity polarity match score
#         sc2p - simple poloarity match score
#         sc1n - proximity negative polarity match score
#         sc2n - simple negative poloarity match score
#-----------------------------------------------------------
# NOTE: 
#   1. IU contractions should be converted as done in preprocessing
#      - e.g., 'I'm' to 'I am'
#-----------------------------------------------------------
sub LFsc {
    my($text,$tlen,$lexhp,$rgxhp,$mrphp,$achp,$NOT,$QTM,$qtmcnt,$proxwinsize,$flag)=@_;
    my $debug=0;

    my %negwds=("not"=>1,"never"=>1,"no"=>1,"without"=>1,"hardly"=>1,"barely"=>1,"scarcely"=>1,"$NOT"=>1);
    my ($sc1,$sc2,$sc1p,$sc2p,$sc1n,$sc2n)=(0,0,0,0,0,0);

    print "LFsc: TEXT1=\n$text\n\n" if ($debug>1);

    # convert opinion phrase to acronyms: 
    #   e.g. 'in my humble opinion' to 'imho'
    foreach my $str(keys %{$achp}) {
        next if ($str !~ / /);  # phrases only
        my $ac= lc(join("",$str=~/\b([A-Za-z])/g));
        $str=~s/I'm/I am/;
        $text=~s/$str/ $ac /ig if ($text=~/$str/i);
    }

    # compress select prepositions, conjunctions, articles: for proximity match
    $text=~s/\s+(for|to|over|on|upon|in|with|of|and|or|a|an|the)\s+/ /gi;

    my @wds=split(/[^A-Za-z!\-]+/,$text);

    for(my $i=0; $i<@wds; $i++) {

        my $word=$wds[$i];

        # delete leading/trailing hyphen
        $word=~s/^\-?(.+?)\-?$/$1/;

        my ($emp,$emp2)=(0,0);

        # words ending w/ !
        $emp=1 if ($word=~s/!$//);

        # words w/ 3+ repeat characters
        $emp2=1 if ($word=~/([a-z])\1{2,}/i);

        # convert to lowercase
        $word=~tr/A-Z/a-z/;

        # compress embedded repeat characters
        #  - exception: e, o
        my $wordc;
        if ($word=~/([a-cdf-np-z])\1+\B/) {
            $wordc=$word;
            $wordc=~s/([a-cdf-np-z])\1+\B/$1/g;
        }

        # compress hyphens
        my $wordh;
        if ($word=~/\-/) {
            $wordh=$word;
            $wordh=~s/\-+//g;
        }

        print "LFsc-1: word=$word, emp=$emp, emp2=$emp2\n" if ($debug);

        my $found=0;
        foreach my $wd($word,$wordc,$wordh) {
            next if (!$wd);

            print "LFsc-2: wd=$wd\n" if ($debug);

            my ($pol,$sc);

            #----------------------------
            # matches in AC lexicon
            if ($achp->{$wd}) {
                $found=1;

                $achp->{$wd}=~/^(.)(\d)/;
                ($pol,$sc)=($1,$2);
                $sc++ if ($emp);
                $sc++ if ($emp2);

                print "LFsc-2(ac): $word=$achp->{$wd}, pol=$pol, sc=$sc\n" if ($debug);

                # increment opinion score
                $sc2 += $sc;

            } #end-if ($lexhp->{$wd}) 

            #----------------------------
            # matches in LF lexicon
            elsif ($lexhp->{$wd}) {
                $found=1;

                $lexhp->{$wd}=~/^(.)(\d)/;
                ($pol,$sc)=($1,$2);
                $sc++ if ($emp);
                $sc++ if ($emp2);

                print "LFsc-2(lex): $word=$lexhp->{$wd}, pol=$pol, sc=$sc\n" if ($debug);

                # increment opinion score
                $sc2 += $sc;

            } #end-if ($lexhp->{$wd}) 

            #----------------------------
            # matches in LF regex
            #  - check morph regex if repeat-char word
            else {

                # rsortbyval: match order of polP, polN, polM, and then by value within polarity group
                foreach my $rgx(sort {$rgxhp->{$b} cmp $rgxhp->{$a}} keys %{$rgxhp}) {

                    if($wd=~/$rgx/i) {
                        $found=1;

                        $rgxhp->{$rgx}=~/^(.)(\d)/;
                        ($pol,$sc)=($1,$2);
                        $sc++ if ($emp);
                        $sc++ if ($emp2);

                        print "LFsc-3(rgx): rgx=$rgx, $word=$rgxhp->{$rgx}, pol=$pol, sc=$sc\n" if ($debug);

                        # increment opinion score
                        $sc2 += $sc;

                        last;  # stop at the first regex match

                    } #end-if($wd=~/$rgx/i) 

                } #end-foreach my $rgx(sort {$rgxhp->{$b} cmp $rgxhp->{$a}} keys %{$rgxhp}) 

                if (!$found && $wd=~/([a-z])\1{2,}/i) {
                    foreach my $rgx(sort {$mrphp->{$b} cmp $mrphp->{$a}} keys %{$mrphp}) {

                        if($wd=~/$rgx/i) {
                            $found=1;

                            $mrphp->{$rgx}=~/^(.)(\d)/;
                            ($pol,$sc)=($1,$2);
                            $sc++ if ($emp);
                            $sc++ if ($emp2);

                            print "LFsc-3(mrp): rgx=$rgx, $word=$mrphp->{$rgx}, pol=$pol, sc=$sc\n" if ($debug);

                            # increment opinion score
                            $sc2 += $sc;

                            last;  # stop at the first regex match

                        } #end-if($wd=~/$rgx/i) 

                    } #end-foreach my $rgx(sort {$rgxhp->{$b} cmp $rgxhp->{$a}} keys %{$rgxhp}) 
                } #end-if (!$found && $wd=~/([a-z])\1{2,}/i))

            } #end-else

            if ($found) {

                # flag proximity match
                my $proxMatch=0;
                if ($qtmcnt) {
                    my $minI=$i-$proxwinsize;
                    my $maxI=$i+$proxwinsize;
                    $minI=0 if ($minI<0);
                    $maxI=$#wds if ($maxI>$#wds);
                    my $proxstr= join(' ',@wds[$minI..$maxI]);
                    if ($proxstr=~/$QTM/) {
                        $proxMatch=1;
                        $sc1 += $sc;
                    }
                    print "LFsc-4: wd=$wds[$i], sc=$sc, pmatch=$proxMatch, proxstr=$proxstr\n" if ($debug);
                }

                # polarity score
                if ($pol=~/[np]/) {
                    my($pwd,$ppwd,$pppwd);  # preceding words
                    if ($i>2) {
                        ($pppwd,$ppwd,$pwd)=($wds[$i-3],$wds[$i-2],$wds[$i-1]);
                    }
                    elsif ($i>1) {
                        ($ppwd,$pwd)=($wds[$i-2],$wds[$i-1]);
                    }
                    elsif ($i>0) {
                        $pwd=$wds[$i-1];
                    }
                    foreach my $wd2($pwd,$ppwd,$pppwd) {
                        next if (!$wd2);
                        # delete leading/trailing hyphen
                        $wd2=~s/^\-?(.+?)\-?$/$1/;
                        # convert to lowcase
                        $wd2=~tr/A-Z/a-z/;
                    }
                    my($p1,$p2,$n1,$n2)=&polSC($pol,$sc,$pwd,$ppwd,$pppwd,\%negwds,$proxMatch);
                    $sc2p += $p2 if ($p2);
                    $sc1p += $p1 if ($p1);
                    $sc2n += $n2 if ($n2);
                    $sc1n += $n1 if ($n1);

                    print "LFsc5: wd=$wd, pol=$pol, p1=$p1, p2=$p2, n1=$n1, n2=$n2\n" if ($debug);

                } #end-if ($pol=~/[np]/)

                last;  # stop when correct wordform is matched

            } #end-if ($found)

        } #end-foreach my $wd($word,$wordc,$wordh) 

    } #end-for(my $i=0; $i<@wds; $i++) 

    print "LFsc-6: tlen=$tlen, s1=$sc1, s2=$sc2, s1p=$sc1p, s2p=$sc2p, s1n=$sc1n, s2n=$sc2n\n" if ($debug);

    if (!$flag) {
        foreach my$sc($sc1,$sc2,$sc1p,$sc2p,$sc1n,$sc2n) {
            $sc /= $tlen if ($sc);  
        }
    }

    return ($sc1,$sc2,$sc1p,$sc2p,$sc1n,$sc2n);

} #endsub LFsc


#------------------------------------------------------------
# compute LF opinion scoring of a term
#-----------------------------------------------------------
# arg1 = word to be scored
# arg2 = emphasis flag
# arg3 = emphasis flag 2
# arg4 = proximity match flag
# arg5 = pointer to LF lexicon hash
#          key: term, val: [pnm]N
# arg6 = pointer to LF regex array
# arg7 = pointer to LF regex score array
# arg8 = pointer to LF repeat-char morph regex array
# arg9 = pointer to LF repeat-char morph regex score array
# arg10 = pointer to negation hash
# arg11 = preceding word
# arg12 = pre-preceding word
# arg13 = pre-pre-preceding word
# r.v. = score hash
#          key: score name
#               lf   - simple match score
#               lfP  - simple positive poloarity match score
#               lfN  - simple negative poloarity match score
#               lfx  - proximity match score
#               lfxP - proximity positive polarity match score
#               lfxN - proximity negative polarity match score
#          val: score
#-----------------------------------------------------------
# NOTE: 
#   1. search multiple sources, stop at first match
#   seach order = lexicon, regex, repeat-char morph regex
#-----------------------------------------------------------
sub LFsc2 {
    my($wd,$emp,$emp2,$prxmatch,$lexhp,$rgxlp,$rgxsclp,$mrplp,$mrpsclp,$neghp,$pwd,$ppwd,$pppwd)=@_;
    my $debug=0;

    print "LFsc2-0: wd=$wd, emp=$emp, emp2=$emp2, prxm=$prxmatch, pws=",join(" ",($pppwd,$ppwd,$pwd)),"\n" if ($debug>1);

    my %sc;
    my ($found,$pol,$sc)=(0);

    #----------------------------
    # matches in LF lexicon
    if ($lexhp->{$wd}) {
        $found=1;

        $lexhp->{$wd}=~/^(.)(\d)/;
        ($pol,$sc)=($1,$2);
        $sc++ if ($emp);
        $sc++ if ($emp2);

        # increment opinion score
        $sc{'sc'} = $sc;

        print "LFsc2-1(lex): wd=$wd, pol=$pol, sc=$sc\n" if ($debug);

    } 

    #----------------------------
    # matches in LF regex
    else {

        # alread sorted in the match order of polarity-strength: p,n,m then 3,2,1
        #  - avoids sorting hash for each word
        my $index=0;
        foreach my $rgx(@{$rgxlp}) {

            if($wd=~/$rgx/i) {
                $found=1;

                $rgxsclp->[$index]=~/^(.)(\d)/;
                ($pol,$sc)=($1,$2);
                $sc++ if ($emp);
                $sc++ if ($emp2);

                # increment opinion score
                $sc{'sc'} = $sc;

                print "LFsc2-2(rgx): rgx=$rgx, wd=$wd, pol=$pol, sc=$sc\n" if ($debug);

                last;  # stop at the first regex match

            } #end-if($wd=~/$rgx/i) 

            $index++;

        } #end-foreach 

        #  - check morph regex if repeat-char word
        if (!$found && $wd=~/([a-z])\1{2,}/i) {

            # alread sorted in the match order of polarity-strength: p,n,m then 3,2,1
            #  - avoids sorting hash for each word
            $index=0;
            foreach my $rgx(@{$mrplp}) {

                if($wd=~/$rgx/i) {
                    $found=1;

                    $mrpsclp->[$index]=~/^(.)(\d)/;
                    ($pol,$sc)=($1,$2);
                    $sc++ if ($emp);
                    $sc++ if ($emp2);

                    # increment opinion score
                    $sc{'sc'} = $sc;

                    print "LFsc2-3(mrp): rgx=$rgx, wd=$wd, pol=$pol, sc=$sc\n" if ($debug);

                    last;  # stop at the first regex match

                } #end-if($wd=~/$rgx/i) 

                $index++;

            } #end-foreach

        } #end-if (!$found && $wd=~/([a-z])\1{2,}/i))

    } #end-else

    if ($found) {

        # prox. match score
        $sc{'scx'} = $sc if ($prxmatch);

        # polarity score
        if ($pol=~/[np]/) {
            my($xp,$p,$xn,$n)=&polSC($pol,$sc,$pwd,$ppwd,$pppwd,$neghp,$prxmatch);
            $sc{'scxP'} = $xp if ($xp);
            $sc{'scP'} = $p if ($p);
            $sc{'scxN'} = $xn if ($xn);
            $sc{'scN'} = $n if ($n);
            print "LFsc2-4(pol): wd=$wd, pol=$pol, xp=$xp, p=$p, xn=$xn, n=$n\n" if ($debug);
        } 

    } #end-if ($found)

    return (%sc);

} #endsub LFsc2


#------------------------------------------------------------
# compute LF opinion scoring of a term
#-----------------------------------------------------------
# arg1 = word to be scored
# arg2 = emphasis flag
# arg3 = emphasis flag 2
# arg4 = pointer to proximity match hash
#          key: QN, val: 1,0
# arg5 = pointer to LF lexicon hash
#          key: term, val: [pnm]N
# arg6 = pointer to LF regex array
# arg7 = pointer to LF regex score array
# arg8 = pointer to LF repeat-char morph regex array
# arg9 = pointer to LF repeat-char morph regex score array
# arg10 = pointer to negation hash
# arg11 = preceding word
# arg12 = pre-preceding word
# arg13 = pre-pre-preceding word
# r.v. = score hash
#        k1= QN (NOTE: 0= query independent scores)
#        v1= hash pointer
#            k2: score name
#                sc   - simple match score
#                scP  - simple positive poloarity match score
#                scN  - simple negative poloarity match score
#                scx  - proximity match score
#                scxP - proximity positive polarity match score
#                scxN - proximity negative polarity match score
#            v2: score
#-----------------------------------------------------------
# NOTE: 
#   1. search multiple sources, stop at first match
#   seach order = lexicon, regex, repeat-char morph regex
#-----------------------------------------------------------
sub LFsc3 {
    my($wd,$emp,$emp2,$prxhp,$lexhp,$rgxlp,$rgxsclp,$mrplp,$mrpsclp,$neghp,$pwd,$ppwd,$pppwd)=@_;
    my $debug=0;

    print "LFsc3a: wd=$wd, emp=$emp, emp2=$emp2, pws=",join(" ",($pppwd,$ppwd,$pwd)),"\n" if ($debug>1);

    my %sc;
    my ($found,$pol,$sc)=(0);

    #----------------------------
    # matches in LF lexicon
    if ($lexhp->{$wd}) {
        $found=1;

        $lexhp->{$wd}=~/^(.)(\d)/;
        ($pol,$sc)=($1,$2);
        $sc++ if ($emp);
        $sc++ if ($emp2);

        print "LFsc3b(lex): wd=$wd, pol=$pol, sc=$sc\n" if ($debug);

    } 

    #----------------------------
    # matches in LF regex
    else {

        # alread sorted in the match order of polarity-strength: p,n,m then 3,2,1
        #  - avoids sorting hash for each word
        my $index=0;
        foreach my $rgx(@{$rgxlp}) {

            if($wd=~/$rgx/i) {
                $found=1;

                $rgxsclp->[$index]=~/^(.)(\d)/;
                ($pol,$sc)=($1,$2);
                $sc++ if ($emp);
                $sc++ if ($emp2);

                print "LFsc3c(rgx): rgx=$rgx, wd=$wd, pol=$pol, sc=$sc\n" if ($debug);

                last;  # stop at the first regex match

            } #end-if($wd=~/$rgx/i) 

            $index++;

        } #end-foreach 

        #  - check morph regex if repeat-char word
        if (!$found && $wd=~/([a-z])\1{2,}/i) {

            # alread sorted in the match order of polarity-strength: p,n,m then 3,2,1
            #  - avoids sorting hash for each word
            $index=0;
            foreach my $rgx(@{$mrplp}) {

                if($wd=~/$rgx/i) {
                    $found=1;

                    $mrpsclp->[$index]=~/^(.)(\d)/;
                    ($pol,$sc)=($1,$2);
                    $sc++ if ($emp);
                    $sc++ if ($emp2);

                    print "LFsc3c(mrp): rgx=$rgx, wd=$wd, pol=$pol, sc=$sc\n" if ($debug);

                    last;  # stop at the first regex match

                } #end-if($wd=~/$rgx/i) 

                $index++;

            } #end-foreach

        } #end-if (!$found && $wd=~/([a-z])\1{2,}/i))

    } #end-else

    if ($found) {

        # opinion score
        $sc{0}{'sc'} = $sc;
                
        # polarity score
        my($p,$n)=(0,0);
        if ($pol=~/[np]/) {
            ($p,$n)=&polSC0($pol,$sc,$pwd,$ppwd,$pppwd,$neghp);
            $sc{0}{'scP'} = $p;
            $sc{0}{'scN'} = $n;
            print "LFsc3(q0): wd=$wd, pol=$pol, scp=$p, scn=$n\n" if ($debug);
        }

        # prox. match score
        foreach my $qn(keys %$prxhp) {
            my $prxmatch= $prxhp->{$qn};
            ($sc{$qn}{'scxP'},$sc{$qn}{'scxN'})=(0,0);

            if ($prxmatch) {
                $sc{$qn}{'scx'} = $sc;
                # polarity score
                if ($pol=~/[np]/) {
                    $sc{$qn}{'scxP'} = $p;
                    $sc{$qn}{'scxN'} = $n;
                }
                print "LFsc3d-prxm(q$qn): scx=$sc{$qn}{'scx'}, scxp=$sc{$qn}{'scxP'}, scxn=$sc{$qn}{'scxN'}\n" if ($debug);
            }
        }

    } #end-if ($found)

    return (%sc);

} #endsub LFsc3


#------------------------------------------------------------
# compute LF opinion scoring of a term for a set of queries
#  - idist score computation added
#-----------------------------------------------------------
# arg1 = word to be scored
# arg2 = emphasis flag
# arg3 = emphasis flag 2
# arg4 = pointer to proximity match hash
#          key: QN, val: 1,0
# arg5 = pointer to word distance hash
#          key: QN, val: min. distance between word and query match
# arg6 = pointer to LF lexicon hash
#          key: term, val: [pnm]N
# arg7 = pointer to LF regex array
# arg8 = pointer to LF regex score array
# arg9 = pointer to LF repeat-char morph regex array
# arg10 = pointer to LF repeat-char morph regex score array
# arg11 = pointer to negation hash
# arg12 = preceding word
# arg13 = pre-preceding word
# arg14 = pre-pre-preceding word
# r.v. = score hash
#        k1= QN (NOTE: 0= query independent scores)
#        v1= hash pointer
#            k2: score name
#                sc   - simple match score
#                scP  - simple positive poloarity match score
#                scN  - simple negative poloarity match score
#                scx  - proximity match score
#                scxP - proximity positive polarity match score
#                scxN - proximity negative polarity match score
#                scd  - distance match score
#                scdP - distance positive polarity match score
#                scdN - distance negative polarity match score
#            v2: score
#-----------------------------------------------------------
# NOTE: 
#   1. search multiple sources, stop at first match
#   seach order = lexicon, regex, repeat-char morph regex
#-----------------------------------------------------------
sub LFsc4 {
    my($wd,$emp,$emp2,$prxhp,$dsthp,$maxwdist,$lexhp,$rgxlp,$rgxsclp,$mrplp,$mrpsclp,$neghp,$pwd,$ppwd,$pppwd)=@_;
    my $debug=0;

    print "LFsc4a: wd=$wd, emp=$emp, emp2=$emp2, pws=",join(" ",($pppwd,$ppwd,$pwd)),"\n" if ($debug>1);

    my %sc;
    my ($found,$pol,$sc)=(0);

    #----------------------------
    # matches in LF lexicon
    if ($lexhp->{$wd}) {
        $found=1;

        $lexhp->{$wd}=~/^(.)(\d)/;
        ($pol,$sc)=($1,$2);
        $sc++ if ($emp);
        $sc++ if ($emp2);

        print "LFsc4b(lex): wd=$wd, pol=$pol, sc=$sc\n" if ($debug);

    } 

    #----------------------------
    # matches in LF regex
    else {

        # alread sorted in the match order of polarity-strength: p,n,m then 3,2,1
        #  - avoids sorting hash for each word
        my $index=0;
        foreach my $rgx(@{$rgxlp}) {

            if($wd=~/$rgx/i) {
                $found=1;

                $rgxsclp->[$index]=~/^(.)(\d)/;
                ($pol,$sc)=($1,$2);
                $sc++ if ($emp);
                $sc++ if ($emp2);

                print "LFsc4c(rgx): rgx=$rgx, wd=$wd, pol=$pol, sc=$sc\n" if ($debug);

                last;  # stop at the first regex match

            } #end-if($wd=~/$rgx/i) 

            $index++;

        } #end-foreach 

        #  - check morph regex if repeat-char word
        if (!$found && $wd=~/([a-z])\1{2,}/i) {

            # alread sorted in the match order of polarity-strength: p,n,m then 3,2,1
            #  - avoids sorting hash for each word
            $index=0;
            foreach my $rgx(@{$mrplp}) {

                if($wd=~/$rgx/i) {
                    $found=1;

                    $mrpsclp->[$index]=~/^(.)(\d)/;
                    ($pol,$sc)=($1,$2);
                    $sc++ if ($emp);
                    $sc++ if ($emp2);

                    print "LFsc4c(mrp): rgx=$rgx, wd=$wd, pol=$pol, sc=$sc\n" if ($debug);

                    last;  # stop at the first regex match

                } #end-if($wd=~/$rgx/i) 

                $index++;

            } #end-foreach

        } #end-if (!$found && $wd=~/([a-z])\1{2,}/i))

    } #end-else

    if ($found) {

        # opinion score
        $sc{0}{'sc'} = $sc;
                
        # polarity score
        my($p,$n)=(0,0);
        if ($pol=~/[np]/) {
            ($p,$n)=&polSC0($pol,$sc,$pwd,$ppwd,$pppwd,$neghp);
            $sc{0}{'scP'} = $p;
            $sc{0}{'scN'} = $n;
            print "LFsc4(q0): wd=$wd, pol=$pol, scp=$p, scn=$n\n" if ($debug);
        }

        # prox. match score
        foreach my $qn(keys %$prxhp) {
            my $prxmatch= $prxhp->{$qn};
            ($sc{$qn}{'scx'},$sc{$qn}{'scxP'},$sc{$qn}{'scxN'})=(0,0,0);

            if ($prxmatch) {
                $sc{$qn}{'scx'} = $sc;
                # polarity score
                if ($pol=~/[np]/) {
                    $sc{$qn}{'scxP'} = $p;
                    $sc{$qn}{'scxN'} = $n;
                }
                print "LFsc4d-prxm(q$qn): scx=$sc{$qn}{'scx'}, scxp=$sc{$qn}{'scxP'}, scxn=$sc{$qn}{'scxN'}\n" if ($debug);
            }
        }

        # dist. match score !
        foreach my $qn(keys %$dsthp) {
            my $wdist= $dsthp->{$qn};
            ($sc{$qn}{'scd'},$sc{$qn}{'scdP'},$sc{$qn}{'scdN'})=(0,0,0);

            if ($wdist<$maxwdist) {  # max. word distance
                my $idist=1/log($wdist+2);
                $sc{$qn}{'scd'} = sprintf("%.4f",$sc*$idist);
                # polarity score
                if ($pol=~/[np]/) {
                    $sc{$qn}{'scdP'} = sprintf("%.4f",$p*$idist);
                    $sc{$qn}{'scdN'} = sprintf("%.4f",$n*$idist);
                }
            }
            print "LFsc4-dist(q$qn): scd=$sc{$qn}{'scd'}, scdp=$sc{$qn}{'scdP'}, scdn=$sc{$qn}{'scdN'}\n" if ($debug);
        }

    } #end-if ($found)

    return (%sc);

} #endsub LFsc4


sub LFsc5 {
    my($wd,$emp,$emp2,$prxhp,$dsthp,$dst2hp,$maxwdist,$lexhp,$rgxlp,$rgxsclp,$mrplp,$mrpsclp,$neghp,$pwd,$ppwd,$pppwd)=@_;
    my $debug=0;

    print "LFsc4a: wd=$wd, emp=$emp, emp2=$emp2, pws=",join(" ",($pppwd,$ppwd,$pwd)),"\n" if ($debug>1);

    my %sc;
    my ($found,$pol,$sc)=(0);

    #----------------------------
    # matches in LF lexicon
    if ($lexhp->{$wd}) {
        $found=1;

        $lexhp->{$wd}=~/^(.)(\d)/;
        ($pol,$sc)=($1,$2);
        $sc++ if ($emp);
        $sc++ if ($emp2);

        print "LFsc4b(lex): wd=$wd, pol=$pol, sc=$sc\n" if ($debug);

    } 

    #----------------------------
    # matches in LF regex
    else {

        # alread sorted in the match order of polarity-strength: p,n,m then 3,2,1
        #  - avoids sorting hash for each word
        my $index=0;
        foreach my $rgx(@{$rgxlp}) {

            if($wd=~/$rgx/i) {
                $found=1;

                $rgxsclp->[$index]=~/^(.)(\d)/;
                ($pol,$sc)=($1,$2);
                $sc++ if ($emp);
                $sc++ if ($emp2);

                print "LFsc4c(rgx): rgx=$rgx, wd=$wd, pol=$pol, sc=$sc\n" if ($debug);

                last;  # stop at the first regex match

            } #end-if($wd=~/$rgx/i) 

            $index++;

        } #end-foreach 

        #  - check morph regex if repeat-char word
        if (!$found && $wd=~/([a-z])\1{2,}/i) {

            # alread sorted in the match order of polarity-strength: p,n,m then 3,2,1
            #  - avoids sorting hash for each word
            $index=0;
            foreach my $rgx(@{$mrplp}) {

                if($wd=~/$rgx/i) {
                    $found=1;

                    $mrpsclp->[$index]=~/^(.)(\d)/;
                    ($pol,$sc)=($1,$2);
                    $sc++ if ($emp);
                    $sc++ if ($emp2);

                    print "LFsc4c(mrp): rgx=$rgx, wd=$wd, pol=$pol, sc=$sc\n" if ($debug);

                    last;  # stop at the first regex match

                } #end-if($wd=~/$rgx/i) 

                $index++;

            } #end-foreach

        } #end-if (!$found && $wd=~/([a-z])\1{2,}/i))

    } #end-else

    if ($found) {

        # opinion score
        $sc{0}{'sc'} = $sc;
                
        # polarity score
        my($p,$n)=(0,0);
        if ($pol=~/[np]/) {
            ($p,$n)=&polSC0($pol,$sc,$pwd,$ppwd,$pppwd,$neghp);
            $sc{0}{'scP'} = $p;
            $sc{0}{'scN'} = $n;
            print "LFsc4(q0): wd=$wd, pol=$pol, scp=$p, scn=$n\n" if ($debug);
        }

        # prox. match score
        foreach my $qn(keys %$prxhp) {
            my $prxmatch= $prxhp->{$qn};
            ($sc{$qn}{'scx'},$sc{$qn}{'scxP'},$sc{$qn}{'scxN'})=(0,0,0);

            if ($prxmatch) {
                $sc{$qn}{'scx'} = $sc;
                # polarity score
                if ($pol=~/[np]/) {
                    $sc{$qn}{'scxP'} = $p;
                    $sc{$qn}{'scxN'} = $n;
                }
                print "LFsc4d-prxm(q$qn): scx=$sc{$qn}{'scx'}, scxp=$sc{$qn}{'scxP'}, scxn=$sc{$qn}{'scxN'}\n" if ($debug);
            }
        }

        # dist. match score !
        foreach my $qn(keys %$dsthp) {
            my $wdist= $dsthp->{$qn};
            ($sc{$qn}{'scd'},$sc{$qn}{'scdP'},$sc{$qn}{'scdN'})=(0,0,0);

            if ($wdist<$maxwdist) {  # max. word distance
                my $idist=1/log($wdist+2);
                $sc{$qn}{'scd'} = sprintf("%.4f",$sc*$idist);
                # polarity score
                if ($pol=~/[np]/) {
                    $sc{$qn}{'scdP'} = sprintf("%.4f",$p*$idist);
                    $sc{$qn}{'scdN'} = sprintf("%.4f",$n*$idist);
                }
            }
            print "LFsc4-dist(q$qn): scd=$sc{$qn}{'scd'}, scdp=$sc{$qn}{'scdP'}, scdn=$sc{$qn}{'scdN'}\n" if ($debug);
        }
        # dist. match score !
        foreach my $qn(keys %$dst2hp) {
            my $wdist= $dst2hp->{$qn};
            ($sc{$qn}{'scd2'},$sc{$qn}{'scd2P'},$sc{$qn}{'scd2N'})=(0,0,0);

            if ($wdist<$maxwdist) {  # max. word distance
                my $idist=1/log($wdist+2);
                $sc{$qn}{'scd2'} = sprintf("%.4f",$sc*$idist);
                # polarity score
                if ($pol=~/[np]/) {
                    $sc{$qn}{'scd2P'} = sprintf("%.4f",$p*$idist);
                    $sc{$qn}{'scd2N'} = sprintf("%.4f",$n*$idist);
                }
            }
            print "LFsc4-dist(q$qn): scd=$sc{$qn}{'scd'}, scdp=$sc{$qn}{'scdP'}, scdn=$sc{$qn}{'scdN'}\n" if ($debug);
        }

    } #end-if ($found)

    return (%sc);

} #endsub LFsc5

sub LFsc7 {
    my($wd,$emp,$emp2,$prxhp,$dsthp,$dst2hp,$maxwdist,$lexhp,
        $rgxlp,$rgxsclpM,$rgxsclpC,$rgxsclpP,$mrplp,$mrpsclpM,$mrpsclpC,$mrpsclpP,
        $neghp,$pwd,$ppwd,$pppwd)=@_;
    my $debug=0;

    print "LFsc4a: wd=$wd, emp=$emp, emp2=$emp2, pws=",join(" ",($pppwd,$ppwd,$pwd)),"\n" if ($debug>1);

    my (%sc0,%sc);
    my ($found,$pol,$sc)=(0);

    #----------------------------
    # matches in LF lexicon
    if ($lexhp->{$wd}) {
        $found=1;

        foreach my $wname('man','combo','prob') {
            
            my $lexsc= $lexhp->{$wd}{$wname};

            ($pol,$sc)=split//,$lexsc,2;

            $sc++ if ($emp);
            $sc++ if ($emp2);

            $sc0{$wname}=$sc;

            print "LFsc4b(lex): wd=$wd, pol=$pol, sc=$sc\n" if ($debug);

        } 
    } 

    #----------------------------
    # matches in LF regex
    else {

        # alread sorted in the match order of polarity-strength: p,n,m then 3,2,1
        #  - avoids sorting hash for each word
        my $index=0;
        foreach my $rgx(@{$rgxlp}) {

            if($wd=~/$rgx/i) {
                $found=1;

                ($pol,$sc)=split//,$rgxsclpM->[$index],2;
                $sc++ if ($emp);
                $sc++ if ($emp2);
                $sc0{'man'}=$sc;

                ($pol,$sc)=split//,$rgxsclpC->[$index],2;
                $sc++ if ($emp);
                $sc++ if ($emp2);
                $sc0{'combo'}=$sc;

                ($pol,$sc)=split//,$rgxsclpP->[$index],2;
                $sc++ if ($emp);
                $sc++ if ($emp2);
                $sc0{'prob'}=$sc;

                print "LFsc4c(rgx): rgx=$rgx, wd=$wd, pol=$pol, sc=$sc\n" if ($debug);

                last;  # stop at the first regex match

            } #end-if($wd=~/$rgx/i) 

            $index++;

        } #end-foreach 

        #  - check morph regex if repeat-char word
        if (!$found && $wd=~/([a-z])\1{2,}/i) {

            # alread sorted in the match order of polarity-strength: p,n,m then 3,2,1
            #  - avoids sorting hash for each word
            $index=0;
            foreach my $rgx(@{$mrplp}) {

                if($wd=~/$rgx/i) {
                    $found=1;

                    ($pol,$sc)=split//,$mrpsclpM->[$index],2;
                    $sc++ if ($emp);
                    $sc++ if ($emp2);
                    $sc0{'man'}=$sc;

                    ($pol,$sc)=split//,$mrpsclpC->[$index],2;
                    $sc++ if ($emp);
                    $sc++ if ($emp2);
                    $sc0{'combo'}=$sc;

                    ($pol,$sc)=split//,$mrpsclpP->[$index],2;
                    $sc++ if ($emp);
                    $sc++ if ($emp2);
                    $sc0{'prob'}=$sc;

                    print "LFsc4c(mrp): rgx=$rgx, wd=$wd, pol=$pol, sc=$sc\n" if ($debug);

                    last;  # stop at the first regex match

                } #end-if($wd=~/$rgx/i) 

                $index++;

            } #end-foreach

        } #end-if (!$found && $wd=~/([a-z])\1{2,}/i))

    } #end-else

    if ($found) {

        foreach my $wname('man','combo','prob') {
                    
            # opinion score
            $sc{0}{'sc'}{$wname} = $sc0{$wname};
                    
            # polarity score
            my($p,$n)=(0,0);
            if ($pol=~/[np]/) {
                ($p,$n)=&polSC0($pol,$sc0{$wname},$pwd,$ppwd,$pppwd,$neghp);
                $sc{0}{'scP'}{$wname} = $p;
                $sc{0}{'scN'}{$wname} = $n;
                print "LFsc4(q0): wd=$wd, pol=$pol, scp=$p, scn=$n\n" if ($debug);
            }

            # prox. match score
            foreach my $qn(keys %$prxhp) {
                my $prxmatch= $prxhp->{$qn};
                ($sc{$qn}{'scx'}{$wname},$sc{$qn}{'scxP'}{$wname},$sc{$qn}{'scxN'}{$wname})=(0,0,0);

                if ($prxmatch) {
                    $sc{$qn}{'scx'}{$wname} = $sc;
                    # polarity score
                    if ($pol=~/[np]/) {
                        $sc{$qn}{'scxP'}{$wname} = $p;
                        $sc{$qn}{'scxN'}{$wname} = $n;
                    }
                    print "LFsc4d-prxm(q$qn): scx=$sc{$qn}{'scx'}, scxp=$sc{$qn}{'scxP'}, scxn=$sc{$qn}{'scxN'}\n" if ($debug);
                }
            }

            # dist. match score !
            foreach my $qn(keys %$dsthp) {
                my $wdist= $dsthp->{$qn};
                ($sc{$qn}{'scd'}{$wname},$sc{$qn}{'scdP'}{$wname},$sc{$qn}{'scdN'}{$wname})=(0,0,0);

                if ($wdist<$maxwdist) {  # max. word distance
                    my $idist=1/log($wdist+2);
                    $sc{$qn}{'scd'}{$wname} = sprintf("%.4f",$sc*$idist);
                    # polarity score
                    if ($pol=~/[np]/) {
                        $sc{$qn}{'scdP'}{$wname} = sprintf("%.4f",$p*$idist);
                        $sc{$qn}{'scdN'}{$wname} = sprintf("%.4f",$n*$idist);
                    }
                }
                print "LFsc4-dist(q$qn): scd=$sc{$qn}{'scd'}, scdp=$sc{$qn}{'scdP'}, scdn=$sc{$qn}{'scdN'}\n" if ($debug);
            }
            # dist. match score !
            foreach my $qn(keys %$dst2hp) {
                my $wdist= $dst2hp->{$qn};
                ($sc{$qn}{'scd2'}{$wname},$sc{$qn}{'scd2P'}{$wname},$sc{$qn}{'scd2N'}{$wname})=(0,0,0);

                if ($wdist<$maxwdist) {  # max. word distance
                    my $idist=1/log($wdist+2);
                    $sc{$qn}{'scd2'}{$wname} = sprintf("%.4f",$sc*$idist);
                    # polarity score
                    if ($pol=~/[np]/) {
                        $sc{$qn}{'scd2P'}{$wname} = sprintf("%.4f",$p*$idist);
                        $sc{$qn}{'scd2N'}{$wname} = sprintf("%.4f",$n*$idist);
                    }
                }
                print "LFsc4-dist(q$qn): scd=$sc{$qn}{'scd'}, scdp=$sc{$qn}{'scdP'}, scdn=$sc{$qn}{'scdN'}\n" if ($debug);
            }
        }

    } #end-if ($found)

    return (%sc);

} #endsub LFsc7


#------------------------------------------------------------
# compute Weka opinion score (documen)
#-----------------------------------------------------------
#   arg1 = text to be scored
#   arg2 = filter model
#   r.v. = (class,sc)
#-----------------------------------------------------------
sub wekaDsc {
    my($qti,$text,$tlen,$lexhp1,$lexhp2)=@_;
    my $debug=0;

} #endsub wekaDsc


#-----------------------------------------------------------
#  compute term distance
#-----------------------------------------------------------
#  arg1 = position of wd1
#  arg2 = pointer to array of wd2 positions
#  r.v. = minimum number of words between wd1 & wd2
#-----------------------------------------------------------
sub minDist {
    my($pos,$poslp)=@_;

    my $min=10**3;

    foreach my $pos2(@$poslp) {
        my $diff=($pos-$pos2);
        if (abs($diff)<$min) {
            $min=abs($diff);
            last if ($diff<0);
        }
        elsif ($diff<0) { last; }
    }

    return $min;
}

#--------------------------------------------
# build the ad_v module
#--------------------------------------------
#   arg1 = reference to PSE hash
#   r.v. = updated PSE hash
#--------------------------------------------
sub build_ad_v{
    my ($mdir,$pseHash, $npseHash)=@_;
    #$mdir = "/u2/home/nyu/BLOG06/ad_v_Model/newLexicon"; #model directory
    #create hash for the ad_v lexicon
    my $file1 = "$mdir/PSE_clean.list"; #PSE file
    my $file2 = "$mdir/nonPSE_2.list"; #non-PSE file
    open(IN,$file1)||die "can't open file $file1\n";
    my @lines = <IN>;
    chomp@lines;
    close(IN);
    foreach (@lines){
       next if(/^[#|!]/);
       next if(/^\s*$/);
       #my($pse, $weight)= split($sep, $_);
       #$$pseHash{$_} = $weight;#we are not going to use this weight
       $$pseHash{$_} = 1;
    }

    open(IN,$file2)||die "can't open file $file2\n";
    @lines = <IN>;
    chomp@lines;
    close(IN);
    foreach (@lines){
       next if(/^[#|!]/);
       next if(/^\s*$/);
       #my($pse, $weight)= split($sep, $_);
       #$$npseHash{$_} = $weight;#we are not going to use this weight
       $$npseHash{$_} = 1;
    }
}#end of sub build_ad_v



1
