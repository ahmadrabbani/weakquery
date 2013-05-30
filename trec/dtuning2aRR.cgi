#!/usr/bin/perl

# -----------------------------------------------------------------
# Name:  dtuning2aRR.cgi
#        Kiduk Yang, 4/22/2008
#            modified dtuning2a.cgi (7/2007)
#            modified dtuning2a_qe.cgi, 7/2/2008
#  - modified to handle idist and wqx phrase scores
# -----------------------------------------------------------------
# Description:
#   display the main page with left frame for topic list and 
#   right frame for results list
# -----------------------------------------------------------------          
# NOTE:
# ------------------------------------------------------------------------

use CGI qw(:standard -debug);
use CGI::Carp (fatalsToBrowser);


#------------------------
# global variables
#------------------------

# get the parameter values from the form
$rfile=param("rfile");  # results file:  e.g. results/test/trecfmtx/s0R/okapi_qln.r2
$rsubd=param("rsubd");     # query type: t=train, e=test
$qt=param("qt");     # query type: t=train, e=test

$indexf="dtuneOP_$qt.htm";

$odir = "/u0/widit/htdocs2/TREC/blog/DTuning/$rsubd";
`mkdir -p $odir/RDpages` if (!-e "$odir/RDpages");
    
$cgi="dtuning2bRR.cgi";

# query type
%qtypes= ("test"=>"e","train"=>"t");

#-------------------------------------------------
# process form input from the mail entry page
#-------------------------------------------------
if ($qt=~/^e/) {
    $qtype="test";
}
elsif ($qt=~/^t/) {
    $qtype="train";
}

@topics = ();
if($qtype eq 'train'){
  @topics = (851..950);
}
else{
  @topics = (1001..1050);
}

#create the left and right frames
$rfile=~m|/([^/]+)$|;
$src = "$qt$rsubd-$1";
$srcL = 'RDpages/'.$src.'L.htm';
$srcR = 'RDpages/'.$src.'R.htm';

   open(RF, ">$odir/$srcR")||die"can't write to $odir/$srcR";
   print RF "
      <html>\n
      <body>\n
      <h3>Blog Track Result Index</h3>\n
      <h2>\U$qtype\E: $rfile</h2>\n
      </body>\n
      </htm>
   ";
   close(RF);

   $rfile=~m|/trecfmt(x)?/s.R?/(.+)$|;  
   $run= "$2$1";
   $run=~s/(.)(kapi|sm)_/$1/;
   open(LF, ">$odir/$srcL")||die"can't write to $odir/$srcL";
   print LF "
      <html>\n
      <head>\n
      <script>\n
      <!--\n
      function wopen(url, name, w, h)
      {
     // Fudge factors for window decoration space.
     // In my tests these work well on all platforms & browsers.
     w += 32\;
     h += 96\;
     var win = window.open(url,
     name,
     'width=' + w + ', height=' + h + ', ' +
     'location=no, menubar=no, ' +
     'status=no, toolbar=no, scrollbars=no, resizable=yes')\;
     win.resizeTo(w, h)\;
     win.focus()\;
     }
    // -->
     </script>
      </head>\n
      <body>\n
      <a href=\"../$indexf\" target=_parent>Index</a><br>\n
   ";
   if(@topics){
       foreach(@topics){
          print LF "<a href=\"../../$cgi?rsubd=$rsubd&rfile=$rfile&qt=$qtype&qn=$_\" target=main><font size=-2>$_</font></a> \n";
          print LF "<a href=\"../../$cgi?rsubd=$rsubd&rfile=$rfile&qt=$qtype&qn=$_&relonly=1&submit=submit\" target=main><font size=-2>r</font></a> \n";
          print LF "<a href=\"../../$cgi?rsubd=$rsubd&rfile=$rfile&qt=$qtype&qn=$_&relonly0=1&submit=submit\" target=main><font size=-2>n</font></a> \n";
          #print LF "<a href=\"../../$cgi?rsubd=$rsubd&qt=$qtype&qn=$_&dsptype=topic\" target=new><font size=-3>T</font></a>\n";
          $tlink = "../../$cgi?rsubd=$rsubd&qt=$qtype&qn=$_&dsptype=topic";
          print LF "<a href=\"$tlink\" target=\"popup\" onClick=\"wopen('$tlink', 'popup', 500, 400)\; return false\;\"><font size=-1>T</font></a>\n";
          #if not fusion run, show the query
          if($rfile !~ /f$/){
             $qlink = "../../$cgi?rsubd=$rsubd&rfile=$rfile&qt=$qtype&qn=$_&dsptype=query";
             print LF "<a href=\"$qlink\" target=\"popup\" onClick=\"wopen('$qlink', 'popup', 400, 1000)\; return false\;\"><font size=-3>Q</font></a>\n";
          }
          print LF "<br>";
       }
   }
   else{
       print LF "error! find no topics for $qtype<br>\n";
   }
   print LF "<p>$run\n";
   print LF "</body>\n</html>";

   close(LF);

print header();
print"
   <html>
   <head><title>BLOG08 Dynamic Tuning Interface</title></head>
    <FRAMESET cols=\"120,*\" frameborder=0>\n
        <FRAME src= \"$rsubd/$srcL\" name=\"nav\" scrolling=yes>\n
        <FRAME SRC =\"$rsubd/$srcR\" name=\"main\">\n
    </FRAMESET>\n
   </html>
";
