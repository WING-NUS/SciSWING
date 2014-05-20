#!/usr/bin/perl -w

use SDBM_File;

# Read the abbreviations list into a disk-based hash

open (ABBREVLIST,"abbreviations.list") or die;

my %abbrevs = ();  # initialize hash

dbmopen(%abbrevs, "./abbrevs", 0666) or die;

$i = 0;
while ($line = <ABBREVLIST>) 
{
 ($item,$val) = split(/\s+/,$line);
 $abbrevs{$item} = $val;   # 1 -> abbrev.can end a sentence, 2 ->. can't
 $i++;
 print "$i $item\n";
}

dbmclose (%abbrevs);
close ABBREVLIST;


 
