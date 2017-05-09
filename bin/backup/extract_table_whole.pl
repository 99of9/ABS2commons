#!/usr/bin/perl -w
use strict;
use Spreadsheet::ParseExcel;
use POSIX;

sub max ($$) { $_[$_[0] < $_[1]] }
sub min ($$) { $_[$_[0] > $_[1]] }

my $num_args = $#ARGV + 1;
if ($num_args != 6) {
  print "\nUsage: extract_table.pl tablenum worksheet firstcol lastcol startrow Name_w/o_Extension\n";
  exit;
}

#print "starting\n";

# usage: perl extract_table.pl tablenum worksheet firstcol lastcol startrow Name_w/o_Extension

my $tablenum=$ARGV[0];
my $ws=$ARGV[1]; #default 2
my $col1=$ARGV[2]; #excel numbering - year, default 1
my $col2=$ARGV[3]; #excel numbering, default 10
my $row_start=$ARGV[4]; #default 11
my $output_string = $ARGV[5]; #e.g. AustralianArrivals

$col1--;
$col2--;
$row_start--;
#my $filedate = '_dd.mm.yyyy.xls';
my $filedate = '';
my $w=0;


# create a lookup table of month abbreviations to month numbers
my %month_abbr_to_number_lkup = (
    Jan => 1,
    Feb => 2,
    Mar => 3,
    Apr => 4,
    May => 5,
    Jun => 6,
    Jul => 7,
    Aug => 8,
    Sep => 9,
    Oct => 10,
    Nov => 11,
    Dec => 12,
);

my $parser   = Spreadsheet::ParseExcel->new();



#GET ARRIVAL STATISTICS
my $workbook = $parser->parse($tablenum.'.xls'.$filedate);
if ( !defined $workbook ) {
	die $parser->error(), ".\n";
}


for my $worksheet ( $workbook->worksheets() ) {
	$w++;
	
	if ($w == $ws ) {

		open (MYFILE, '>'.$output_string.'.txt');

		my ( $row_min, $row_max ) = $worksheet->row_range();
		my ( $col_min, $col_max ) = $worksheet->col_range();
		
		for my $row ( $row_start .. $row_max ) {

			my $cell1 = $worksheet->get_cell( $row, $col1 );

			#date
			print MYFILE $month_abbr_to_number_lkup{substr($cell1->value(),0,3)}, "-", substr($cell1->value(),4,8);

			for my $col2 ( $col_min+1 .. $col_max ) {
				
				my $cell2 = $worksheet->get_cell( $row, $col2 );
				#next unless (isdigit $cell2->value());
				if ($cell2->value() eq "") {
					print MYFILE "\tNA";
				} else {
					print MYFILE "\t", $cell2->value();
				}
			}
			print MYFILE "\n";
		}
		close (MYFILE);
	}
}
