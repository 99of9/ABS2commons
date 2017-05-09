#!/usr/bin/perl
# Generate svg plot with GNUplot from Perl
# Author: Toby Hudson
# Usage: Give "data file" as an argument for script
use strict;
use warnings;
 
my $file = $ARGV[0];
my $shortfile = substr($file, 0, - 4);
my $lines=`wc -l < "$file"`;
my $bez_final = $lines-1;

# POSTSCRIPT
open (GNUPLOT, "|gnuplot");
print GNUPLOT <<EOPLOT;
set term svg size 1200,800 dynamic enhanced fname 'Calibri' fsize 20 butt solid
set object 1 rect from screen 0, 0, 0 to screen 1, 1, 0 behind
set object 1 rect fc  rgb "#f0f0f0"  fillstyle solid 1.0
set size 1 ,1
set key left top
set pointsize 0.3

set xdata time
set timefmt "%m-%Y"
#set xrange ["6-1971":]
set format x "%Y"
#set logscale y

set border lc rgb "black"
set grid back lc rgb "#777777"
#set xlabel "Year" font "Calibri,28" tc rgb "black"
#set ylabel "Monthly arrivals" font "Calibri,28" tc rgb "black"
set grid xtics ytics
set xtics 315576000
set mxtics 10
#set ytics 200000
#set mytics 2

set object 1 rect from screen 0, 0 to screen 1, 1 behind fc rgb "white" fillstyle solid 1.0

#unset logscale y
set pointsize 0.4

set output "$shortfile.svg"
plot  "$file" using 1:2:(1e-22) smooth acsplines lt 1 lw 8 lc rgb "#802020" t '', "$file" using 1:2 w lp pt 7 lt 1 lw 1 lc rgb "#000000" t ''

EOPLOT
close(GNUPLOT);
