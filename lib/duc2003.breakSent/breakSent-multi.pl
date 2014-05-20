#!/usr/bin/perl

# The purpose of this program is to take clean English ASCII text and
# break it into one sentence per line

use SDBM_File; # WARNING: SDBM disk hashes are not byte-order independent
               #          You may need to remake it.

@ARGV > 0 or die"Usage: breakSent-multi.pl file1 file2 ...\n";

$debug = 0;

my $project_dir = "/home/ankur/devbench/scientific/SciSWING";

#Abbreviations
my %abbrevs = ();
dbmopen(%abbrevs, $project_dir."/lib/duc2003.breakSent/abbrevs", 0666) or die "Can't open abbreviations diskhash: $!\n";

#Proper nouns
my %pnouns = ();
dbmopen(%pnouns, $project_dir."/lib/duc2003.breakSent/pnouns", 0666) or die "Can't open proper nouns diskhash: $!\n";

for my $infile (@ARGV) {

    ($outfile = `/bin/mktemp /tmp/toSEE.XXXXXX`) or
        die "Couldn't create temporary output file: $!\n";
    chomp $outfile;

    open(OUT, ">$outfile") || die "Cannot open $outfile: $!\n";

    open INFILE, "$infile" or die "Can't read from $infile: $!\n";
    
    $data = "";
    while ($line = <INFILE>)
    {
	$data .= $line;
    }

 
    print  OUT &markBreaks($data);

    close INFILE;
    close OUT;

    # Removes the input file and moves temp file to input file
     unlink $infile;
    
    (system(("/bin/mv", $outfile, $infile)) == 0)
        or die "Couldn't move $outfile to $infile: $!\n";
}



sub markBreaks {

    my($text) = @_;
    my $t ="";

    # move period, exclamation/question mark after following quote mark
    # and separate with blank. 
    $text =~ s/([\.\!\?]+)([\"\'\)]+) /$2$1 /g;

    # w+{ becomes w+ {   - peculiarity of some newspaper data
    #$text =~ s/(\w+)({)/$1 $2 /g;
    $text =~ s/(\w+)({)/$1/g;

    # remove ; following . ? ! (SJMN peculiarity)
    $text =~ s/([\.\!\?])( *;)/$1/g;
	
    # a series of whitespace chars becomes a space	     
    $text =~ s/\s+/ /g;

    # insert a space before each comma
    $text =~ s/,/ ,/g;

    # this loop handles periods and ellipsis as well as question and 
    # exclamation marks - finding and marking each sentence-ending 
    # instance by inserting an end-of-sentence marker (\n)
    # - $1 has ? to minimize its matching so $2 can match maxmimally
    # and recognize ...
    # - $3 needs to be able to contain / end with punctuation e.g.,
    # an abbreviation starting the next sentence

    while ($text =~ / (\S+?)(\.\.\.|\.|\?|\!) +(\S+)( .+)$/) {
       my $pre = $1; 
       my $delim = $2;
       my $post = $3; 
       my $rest = $4;
       my $skipped = substr($text,0,length($text)-1-length($1.$2.$3.$4));

       $fullpost = $post;
       if (substr($post,-1) eq ".") {
	   chop $post;
       }

       if ($debug) 
       {
	   print "TEXT+[$text]\n";
	   print "\nSKI=[$skipped]\nPRE=[$pre]\nDELIM=[$delim]\nPOS=[$post]\nRES=[$rest]\n";
	   if ($pre =~ /^\w+\.\w+/) {print "$pre WITHPERIOD\n";}
	   if ($abbrevs{$pre} == 1 || $abbrevs{$pre} == 2) {print "$pre ABBREVIATION\n";}
	   if ($pnouns{$post}) {print "$post PROPER\n";}
       }
       # if the word before the delimiter is an appreviation that can't
       # end a sentence, then continue the current sentence.

       # Else if the word before the delimiter can legitimately precede
       # the delimiter and the word after the delimiter
       # is usually capitalized or is lowercase then mark the
       # period/ellipsis as NOT ending a sentence; otherwise mark
       # it as ending a sentence.
       if ( 	    
            ($abbrevs{$pre} == 2)
	    ||
	    (
	      (
	       $pre =~ /^\w+\.\w+/ || ($abbrevs{$pre} == 1) || 
               $delim eq "..."     || $delim eq "?"  || $delim eq "!"
	      ) 
              &&       
	      ($pnouns{$post} || $post =~ /^[a-zß-ÿ0-9,;:\-\.]/)  
            )   
	  )    
       {  
	   # C o n t i n u e   c u r r e n t   s e n t e n c e
	   $t .= $skipped.$pre."$delim ";
	   $restoredspaces = " ";
       }
       else 
       {
	   # M a k e   t h i s   a   s e n t e n c e - f i n a l   p e r i o d
	   $t .= $skipped.$pre.$delim."\n";
	   # lack of in initial space prevents a sentence initial abbrev.
	   # from being interpreted as sentence-terminating - we want this
	   # though it means one word sentences will be concatenated with
	   # the following.
	   $restoredspaces = ""; 
       }
       $text = $restoredspaces.$fullpost.$rest;
   }# endwhile

   $text = $t . $text;

   $text =~ s/\. *$/ ./; # final period will be followed by exactly 1 space
   $text =~ s/ +/ /g; # multiple spaces become one
   $text =~ s/^ //g;  # leading space is removed
   $text =~ s/ $//g;  # trailing space is removed

   $text =~ s/ ,/,/g; # remove the (added) space before commas

   $text .= "\n" unless $text =~ /\n$/; 

   $textout = "";
   @sentlist = split /\n/,$text;
   foreach $s (@sentlist)
   {
        $textout .= "$s\n";
   }
   $textout =~ s/ \././;
   return $textout;
}
