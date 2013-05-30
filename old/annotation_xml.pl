use XML::LibXML;
use strict;
use warnings;

# XML document must have one, only one, root such as <webtrack2009>, <topic> is not document root but an element, 
# so they have to be wrapped into a root element such as <topics>

my $file = "/home/huizhang/Desktop/dissertation/data/topics/wt09.topics.full.xml";
my $output = "/home/huizhang/Desktop/dissertation/data/topics/wt09.topics.full.annotation";
#my $parser = XML::LibXML->new();
#my $tree = $parser->parse_file($file);
#my $root = $tree->getDocumentElement;
#my @topics = $root->getElementsByTagName('topic');
#
#foreach my $topic (@topics){
#
#}

my @tags= ('query','description','narr');
my %tags= (
'query'=>'Qitle',
'description'=>'Description',
'narr'=>'Narrative'
);

my @lines;

open(IN, "<$file") || die "cannot open $file\n";
while(<IN>){
	chomp;
    next if (/^\s*$/);
	push (@lines, $_);
}
close (IN);

my $big_str = join(" ", @lines);
@lines = split(/<\/topic>/, $big_str);

my $qcnt = 0;
my $acnt = 0;
open (OUT, ">$output") || die "cannot write to $output\n";
foreach (@lines) {

    my $qn;
    
    my $flag = 1;

    s/\s+/ /g;

    my @topic=();
    push(@topic,"<topic>");

    # get query number
    #if (m|<num>.+?(\d+).*?</num>|) {
	#	$qn= $1; 
		$qcnt++;
    #    push(@topic,$&);
    #}
    #else {
    #    print "$qcnt: missing QN\n";
    #    next;
    #}

    # get query title
    if (m|<query> *(.+?) *</query>|) {
		my $str= $1; 
        print "Q$qn: missing title\n" if ($str=~/^\s*$/);
        push(@topic,"<query>$str</query>");
        my @str = split(/ /, $str);
        if (scalar@str > 1){
        	push(@topic,"<query_annotate>$str</query_annotate>");
    	}
    	else {
    		$flag = 0;
    	}	
	}

    # get query desc
    if (m|<description> *(.+?) *</description> *(.*?) *<subtopic number="1" type="nav">|s) {
		my $str= $1; 
		print "desc: $str\n"; 
		my $str2= $2; 
        $str=~s/$tags{'description'}:? *//;
        if ($str=~/^\s*$/) {
            if ($str2=~/^\s*$/) {
                print "Q$qn: missing description\n";
            }
            else {
                print "Q$qn: missing description CORRECTED\n";
                print " - $str2\n\n";
                push(@topic,"<description>\n$str2\n</description>");
            }
        }
        else {
            push(@topic,"<description>\n$str\n</description>");
        }
    }

    # get query narrative
    if (m|<narr> *(.+?) *</narr> *(.*?) *$|s) {
		my $str= $1; 
		my $str2= $2; 
		my $str3= $&; 
        $str=~s/$tags{'narr'}:? *//;
        if ($str=~/^\s*$/) {
            if ($str2=~/^\s*$/) {
                print "Q$qn: missing narrative\n";
            }
            else {
                print "Q$qn: missing narrative CORRECTED\n";
                print " - $str2\n\n";
                push(@topic,"<narr>\n$str2\n</narr>");
            }
        }
        else {
            push(@topic,"<narr>\n$str\n</narr>");
        }
    }

    push(@topic,"</topic>");
    
    if ($flag){
    	print OUT join("\n", @topic), "\n";
    	$acnt++;
    }
    
}# endforeach

print "qcnt: $qcnt\n";
print "acnt: $acnt\n";

