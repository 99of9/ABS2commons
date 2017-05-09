#!/usr/bin/perl -w
use strict;
use Spreadsheet::ParseExcel;
use POSIX;

sub max ($$) { $_[$_[0] < $_[1]] }
sub min ($$) { $_[$_[0] > $_[1]] }

my $num_args = $#ARGV + 1;
if ($num_args != 6) {
  print "\nUsage: extract_table.pl database fulltablenum worksheet startrow catalogue_num short_table_num\n";
  exit;
}

#print "starting\n";

# usage: perl extract_table.pl tablenum worksheet firstcol lastcol startrow Name_w/o_Extension

my $database=$ARGV[0];
my $tablenum=$ARGV[1]; #e.g. 320101
my $ws=$ARGV[2]; #default 2
my $row_start=$ARGV[3]; #default 11
my $catalogue_string = $ARGV[4]; #e.g. 3201.0
my $table_string = $ARGV[5]; #e.g. 1

#my $output_string = 'ABS-'.$catalogue_string.'-'.$table_string.'-';
my $output_string = 'ABS-'.$catalogue_string;

$row_start--;
#my $filedate = '_dd.mm.yyyy.xls';
my $filedate = '';
my $w=0;

my $col1=0; #date is always in the first column
my $col_final=0; #dummy starting value

my $table_title= " ";
my $catalogue_title= " ";
my $table_title_short = " ";
my $catalogue_title_short = " ";

my $cmd="";
my $duplicate=0;

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
    #sometimes the filenames don't follow convention... try this
    $tablenum = $table_string;
    $workbook = $parser->parse($tablenum.'.xls'.$filedate);
}

if ( !defined $workbook ) {
    #open (PLOTBATCH, '>plot_batch.sh');
    #print PLOTBATCH 'echo "unable to open file: '.$tablenum.'.xls ... skipping"'."\n";
    #close (PLOTBATCH);
    
    $cmd ='echo "unable to open file: '.$tablenum.'.xls ... skipping"' ;
    system($cmd);

    die $parser->error(), ".\n";
}

open (DESCRIPTIONS, '>>upload_files_and_descriptions.sh');
open (REUPLOAD, '>>reupload_files.sh');
open (FILENAMES, '>>files.txt');
open (DUPLICATES, '>>duplicates.txt');
#open (PLOTBATCH, '>plot_batch.sh');

for my $worksheet ( $workbook->worksheets() ) {
	$w++;
	
	if ($w == 1) {
		my $datatype_cell = $worksheet->get_cell(1,1);
		if ((!defined($datatype_cell))||($datatype_cell->value() ne "Time Series Workbook")) {
			#print PLOTBATCH 'echo "not a Time Series Workbook: '.$tablenum.'.xls ... skipping"'."\n";
			#close (PLOTBATCH);
			#die $parser->error(), ".\n";

			$cmd = 'echo "not a Time Series Workbook: '.$tablenum.'.xls ... skipping"'."\n";
			system($cmd);

			die;
		}
		#get overall title of table
		my $catalogue_cell = $worksheet->get_cell(4,1);
		my $table_cell = $worksheet->get_cell(5,1);
		$catalogue_title= $catalogue_cell->value();
		$table_title= $table_cell->value();

		print STDOUT $table_title."\n";

		#my @tabvalues = split(' ',$table_title,3);
		#$table_title_short = $tabvalues[2];
		my @tabvalues = split('[.:]',$table_title,2);
		$table_title_short = $tabvalues[1];


		my @tab_title_values = split(" ",$table_title_short);
		$table_title_short = "";
		foreach my $val (@tab_title_values) {
		    $table_title_short = $table_title_short.' '. ucfirst(lc($val));
		}

		$table_title_short =~ s/[^\x00-\x7f]//g; #non-wide characters only

		$table_title_short =~ s/_/ /g; #remove native underscores, there's probably no need for them (the one I found was silly)
		$table_title_short =~ s/ - /_/g; #important hyphens get to become underscores
		$table_title_short =~ s/\.//g;
		$table_title_short =~ s/\,//g;
		$table_title_short =~ s/\$//g;
		$table_title_short =~ s/\&//g;
		$table_title_short =~ s/\+//g;
		$table_title_short =~ s/\'//g;
		$table_title_short =~ s/\"//g;
		$table_title_short =~ s/\%//g;
		$table_title_short =~ s/\>//g;
		$table_title_short =~ s/\<//g;
		$table_title_short =~ s/\[//g;
		$table_title_short =~ s/\]//g;
		$table_title_short =~ s/The //g;
		$table_title_short =~ s/And //g;
		$table_title_short =~ s/Of //g;
		$table_title_short =~ s/Or //g;
		$table_title_short =~ s/To //g;
		$table_title_short =~ s/ the //g;
		$table_title_short =~ s/ and //g;
		$table_title_short =~ s/ of //g;
		$table_title_short =~ s/ or //g;
		$table_title_short =~ s/ to //g;
		$table_title_short =~ s/-//g; #any - left are in-word hyphens, remove
		$table_title_short =~ s/\(.*\)//g; #remove anything in parentheses
		$table_title_short =~ s/\s//g; #compress spaces since the catalogue title is usually in TitleCase the caps will stand out.
		$table_title_short =~ s/\///g; #treat this like an "Or" ... which got removed
		$table_title_short =~ s/\\/./g;
		$table_title_short =~ s/;/-/g;
		$table_title_short =~ s/:/-/g;

		$table_title_short =~ s/[^\--z\s]//g; #only characters between - and z on the ascii table

		$table_title_short = substr $table_title_short, 0, 100; #maximum of 100 characters from this part

		print STDOUT $table_title_short."\n";

		my @values = split(" ",$catalogue_title,2);
		$catalogue_title_short = $values[1];

		my @cat_title_values = split(" ",$catalogue_title_short);
		$catalogue_title_short = "";
		foreach my $val (@cat_title_values) {
		    $catalogue_title_short = $catalogue_title_short.' '. ucfirst(lc($val));
		}

		$catalogue_title_short =~ s/[^\x00-\x7f]//g; #non-wide characters only
		$catalogue_title_short =~ s/[^\--z\s]//g;  #only characters between - and z on the ascii table

		$catalogue_title_short =~ s/_//g; #remove native underscores, there's probably no need for them (the one I found was silly)
		$catalogue_title_short =~ s/ - /_/g; #important hyphens get to become underscores
		$catalogue_title_short =~ s/\.//g;
		$catalogue_title_short =~ s/\,//g;
		$catalogue_title_short =~ s/\$//g;
		$catalogue_title_short =~ s/\&//g;
		$catalogue_title_short =~ s/\+//g;
		$catalogue_title_short =~ s/\%//g;
		$catalogue_title_short =~ s/\>//g;
		$catalogue_title_short =~ s/\<//g;
		$catalogue_title_short =~ s/\'//g;
		$catalogue_title_short =~ s/\"//g;
		$catalogue_title_short =~ s/\[//g;
		$catalogue_title_short =~ s/\]//g;
		$catalogue_title_short =~ s/Qld /QLD /g;
		$catalogue_title_short =~ s/Nsw /NSW /g;
		$catalogue_title_short =~ s/Vic /VIC/g;
		$catalogue_title_short =~ s/Sa /SA /g;
		$catalogue_title_short =~ s/Act /ACT /g;
		$catalogue_title_short =~ s/Tas /TAS /g;
		$catalogue_title_short =~ s/Wa /WA /g;
		$catalogue_title_short =~ s/Nt /NT /g;
		$catalogue_title_short =~ s/The //g;
		$catalogue_title_short =~ s/And //g;
		$catalogue_title_short =~ s/Of //g;
		$catalogue_title_short =~ s/Or //g;
		$catalogue_title_short =~ s/To //g;
		$catalogue_title_short =~ s/ the //g;
		$catalogue_title_short =~ s/ and //g;
		$catalogue_title_short =~ s/ of //g;
		$catalogue_title_short =~ s/ or //g;
		$catalogue_title_short =~ s/ to //g;
		$catalogue_title_short =~ s/-//g; #any - left are in-word hyphens, remove
		$catalogue_title_short =~ s/\(.*\)//g; #remove anything in parentheses
		$catalogue_title_short =~ s/\s//g; #compress spaces since the catalogue title is usually in TitleCase the caps will stand out.
		$catalogue_title_short =~ s/\///g; #treat this like an "Or" ... which got removed
		$catalogue_title_short =~ s/\\/./g;
		$catalogue_title_short =~ s/;/-/g;
		$catalogue_title_short =~ s/:/-/g;

		$catalogue_title_short = substr $catalogue_title_short, 0, 100; #maximum of 100 characters from this part

	}

	if (($w == $ws)||($col_final==250)) {
		
		my ( $row_min, $row_max ) = $worksheet->row_range();
		my ( $col_min, $col_max ) = $worksheet->col_range();
		
		for my $col2 ( $col_min+1 .. $col_max ) {
			my $col_effective = $col2+($w-$ws)*250;

			my $cell_header = $worksheet->get_cell( 0, $col2 );
			my $cell_header_text = $cell_header->value();

			$cell_header_text =~ s/[^\x00-\x7f]//g; #non-wide characters only
			$cell_header_text =~ s/[^\--z\s]//g;  #only characters between - and z on the ascii table

			$cell_header_text =~ s/\.//g;
			$cell_header_text =~ s/\,//g;
			$cell_header_text =~ s/\$//g;
			$cell_header_text =~ s/\&//g;
			$cell_header_text =~ s/\%//g;
			$cell_header_text =~ s/\<//g;
			$cell_header_text =~ s/\>//g;
			$cell_header_text =~ s/\'//g;
			$cell_header_text =~ s/\+//g;
			$cell_header_text =~ s/\"//g;
			$cell_header_text =~ s/\[//g;
			$cell_header_text =~ s/\]//g;
			$cell_header_text =~ s/\(/ /g;
			$cell_header_text =~ s/\)//g;
			$cell_header_text =~ s/ - / _ /g;
			$cell_header_text =~ s/-/ /g; #remove source hyphens, because I'll use a hyphen for something else
			$cell_header_text =~ s/\// . /g;
			$cell_header_text =~ s/\\/ . /g;

			my @cell_header_values = split(" ",$cell_header_text);
			$cell_header_text = "";
			foreach my $val (@cell_header_values) {
				#$cell_header_text = $cell_header_text.' '. ucfirst(lc($val));
				$cell_header_text = $cell_header_text.' '. ucfirst(lc($val));
			}

			$cell_header_text =~ s/At End Of Period//g;
			$cell_header_text =~ s/During Period//g;
			$cell_header_text =~ s/The //g;
			$cell_header_text =~ s/And //g;
			$cell_header_text =~ s/Of //g;
			$cell_header_text =~ s/Or //g;
			$cell_header_text =~ s/To //g;
			$cell_header_text =~ s/Nsw /NSW /g; #recapitalize states
			$cell_header_text =~ s/Vic /VIC /g;
			$cell_header_text =~ s/Sa /SA /g;
			$cell_header_text =~ s/Nt /NT /g;
			$cell_header_text =~ s/Wa /WA /g;
			$cell_header_text =~ s/Act /ACT /g;
			$cell_header_text =~ s/Qld /QLD /g;
			$cell_header_text =~ s/Tas /TAS /g;
			$cell_header_text =~ s/\s//g;
			$cell_header_text =~ s/ //g;
			$cell_header_text =~ s/;/-/g;
			$cell_header_text =~ s/:/-/g;
			$cell_header_text =~ s/-+$//;


			my $series_ID = $worksheet->get_cell( 9, $col2 );

			my $cmd = "grep ".$series_ID->value()." ../*/files.txt";
			#print $series_ID->value()."\n";
			if (!system($cmd)) {
			    print ("found previous occurrence of series_ID ".$series_ID->value."\n");
			} else {
			
			    #my $filename_stem = $output_string.($col_effective+1).'-'.$catalogue_title_short.'-'.$table_title_short.'-'.$cell_header_text;
			    my $filename_stem = $output_string.'-'.$catalogue_title_short.'-'.$table_title_short.'-'.$cell_header_text;
			    $filename_stem = substr $filename_stem, 0, 226;
			    
			    $filename_stem = $filename_stem.'-'.$series_ID->value();
			    
			    my $nonzero = 0;
			    open (MYFILE, '>'.$filename_stem.'.txt');
			    for my $row ( $row_start .. $row_max ) {
				
				my $cell1 = $worksheet->get_cell( $row, $col1 );				
				my $cell2 = $worksheet->get_cell( $row, $col2 );
				
				#print STDOUT $w.' '.$row.' '.$col2."\n";
				
				#next unless (isdigit $cell2->value());
				if (defined($cell2)) {
				    if ($cell2->value() eq "") {
					#print MYFILE "\tNA";
				    } else {
					if ($cell2->value() != 0) {
					    $nonzero = $nonzero+1;
					}
					#the next clause removes leading zeroes even if the ABS put them in at the start of a series
					if ($nonzero > 0) {
					    #date
					    print MYFILE $month_abbr_to_number_lkup{substr($cell1->value(),0,3)}, "-", substr($cell1->value(),4,8),"\t";
					    #value
					    print MYFILE $cell2->value(),"\n";
					}
				    }
				} else {
				    #print MYFILE "\tNA";
				}
			    }
			    close (MYFILE);
			    
			    # the curve fitting requires at least four points, and I'm going to insist on at least four non-zero points
			    if ($nonzero>=4) {

				#print PLOTBATCH '../bin/plot_one_column.pl "'.$filename_stem.'.txt"'."\n";
				$cmd = '../bin/plot_one_column.pl "'.$filename_stem.'.txt"';
				system($cmd);

				#$cmd = 'md5sum "'.$filename_stem.'.svg">this_md5.txt';
				#system($cmd);

				$cmd = 'md5sum "'.$filename_stem.'.svg"';
				my $md5 = `$cmd 2>/dev/null`;
				$md5 = substr($md5,0,32);
				#print("this md5=".$md5." ");

				$cmd = "grep ".$md5." ../*/md5_list.txt";
				if (`$cmd`) {
				    #print ("found previous occurrence of this md5sum ".$md5."\n");
				    $duplicate=1;
				    print DUPLICATES "* [[:File:".$filename_stem.'.svg]]'."\n";
				} else {
				    #print ("didn't find previous occurrence of this md5sum ".$md5."\n");
				    $duplicate=0;
				    print FILENAMES "* [[:File:".$filename_stem.'.svg]]'."\n";
				}
				
				$cmd = 'md5sum "'.$filename_stem.'.svg">>md5_list.txt';
				system($cmd);

				if (!$duplicate) {
				    
				    my $column_title = $cell_header->value();
				    $column_title =~ s/[^\x00-\x7f]//g; #non-wide characters only
				    
				    
				    my $description_text = '"== {{int:filedesc}} =='."\n".'{{Information'."\n".'|Description={{en|'.$catalogue_title.'<br/>'.$table_title.'<br/>'.$column_title.' '.'{{AustralianBureauStatistics-header| 1=';
				    $cell_header = $worksheet->get_cell( 1, $col2 );
				    $description_text = $description_text.$cell_header->value().'| 2=';
				    $cell_header = $worksheet->get_cell( 2, $col2 );
				    $description_text = $description_text.ucfirst(lc($cell_header->value())).'| 3=';
				    $cell_header = $worksheet->get_cell( 3, $col2 );
				    $description_text = $description_text.ucfirst(lc($cell_header->value())).'| 4=';
				    $cell_header = $worksheet->get_cell( 4, $col2 );
				    $description_text = $description_text.ucfirst(lc($cell_header->value())).'| 5=';
				    $cell_header = $worksheet->get_cell( 5, $col2 );
				    $description_text = $description_text.$cell_header->value().'| 6=';
				    $cell_header = $worksheet->get_cell( 6, $col2 );
				    $description_text = $description_text.$cell_header->value().'}}.<br/>';
				    $description_text = $description_text.'The graph was plotted with [[w:gnuplot|gnuplot]], and shows both the raw data (black points), and a trend constructed from a weighted cubic spline with a weighting of 1e-22 (red line).}}'."\n".'|Source={{own}}'."\n".'{{AustralianBureauStatistics|1='.$series_ID->value().'|2='.($col2+1).'|3='.$tablenum.'|4='.$catalogue_string.'|5='.$database.'}}'."\n".'|Date=2012-06-01'."\n".'|Author=[[User:99of9|Toby Hudson]]'."\n".'|Permission='."\n".'|other_versions='."\n".'}}'."\n".'== {{int:license}} =='."\n".'{{self|cc-by-sa-3.0-au}}'."\n".'{{User:99of9/ABS-graph}}';

				    my $alldata_string = $column_title.' '.$table_title.' '.$catalogue_title.' ';

				    #Identify additional subject categories 


				    my $period="";
				    if ($alldata_string =~ m/Long-term/i) {
					$period="long-term ";
				    } elsif ($alldata_string =~ m/Short-term/i) {
					$period="short-term ";
				    } elsif ($alldata_string =~ m/Permanent/i) {
					$period="permanent ";
				    }

				    my $location="Australia";
				    #  CAPITAL CITIES AND STATES
				    if ($alldata_string =~ m/Sydney/) {
					$location="Sydney";
					#$description_text = $description_text."\n".'[[Category:Statistics of Sydney]]';
				    } elsif (($alldata_string =~ m/New South Wales/i)||($alldata_string =~ m/[^a-zA-Z]NSW[^a-zA-Z]/)||($alldata_string =~ m/ nsw /i)) {
					$location="New South Wales";
					#$description_text = $description_text."\n".'[[Category:Statistics of New South Wales]]';    
				    } 
				    if ($alldata_string =~ m/Brisbane/) {
					$location="Brisbane";
					#$description_text = $description_text."\n".'[[Category:Statistics of Brisbane]]';
				    } elsif (($alldata_string =~ m/Queensland/i)||($alldata_string =~ m/[^a-zA-Z]QLD[^a-zA-Z]/)||($alldata_string =~ m/ qld /i)) {
					$location="Queensland";
					#$description_text = $description_text."\n".'[[Category:Statistics of Queensland]]';    
				    } 
				    if ($alldata_string =~ m/Melbourne/) {
					$location="Melbourne";
					#$description_text = $description_text."\n".'[[Category:Statistics of Melbourne]]';
				    } elsif (($alldata_string =~ m/Victoria/i)||($alldata_string =~ m/[^a-zA-Z]VIC[^a-zA-Z]/)||($alldata_string =~ m/ vic /i)) {
					$location="Victoria";
					#$description_text = $description_text."\n".'[[Category:Statistics of Victoria]]';    
				    } 
				    if ($alldata_string =~ m/Hobart/) {
					$location="Hobart";
					#$description_text = $description_text."\n".'[[Category:Statistics of Hobart]]';
				    } elsif (($alldata_string =~ m/Tasmania/i)||($alldata_string =~ m/[^a-zA-Z]TAS[^a-zA-Z]/)||($alldata_string =~ m/ tas /i)) {
					$location="Tasmania";
					#$description_text = $description_text."\n".'[[Category:Statistics of Tasmania]]';    
				    } 
				    if ($alldata_string =~ m/Adelaide/) {
					$location="Adelaide";
					#$description_text = $description_text."\n".'[[Category:Statistics of Adelaide]]';
				    } elsif (($alldata_string =~ m/South Australia/i)||($alldata_string =~ m/[^a-zA-Z]SA[^a-zA-Z]/)||($alldata_string =~ m/ sa /i)) {
					$location="South Australia";
					#$description_text = $description_text."\n".'[[Category:Statistics of South Australia]]';    
				    } 
				    if ($alldata_string =~ m/Perth/) {
					$location="Perth";
					#$description_text = $description_text."\n".'[[Category:Statistics of Perth]]';
				    } elsif (($alldata_string =~ m/Western Australia/i)||($alldata_string =~ m/[^a-zA-Z]WA[^a-zA-Z]/)||($alldata_string =~ m/ wa /i)) {
					$location="Western Australia";
					#$description_text = $description_text."\n".'[[Category:Statistics of Western Australia]]';    
				    } 
				    if ($alldata_string =~ m/Canberra/) {
					$location="Canberra";
					#$description_text = $description_text."\n".'[[Category:Statistics of Canberra]]';
				    } elsif (($alldata_string =~ m/Australian Capital Territory/i)||($alldata_string =~ m/[^a-zA-Z]ACT[^a-zA-Z]/)||($alldata_string =~ m/ act /i)) {
					$location="the Australian Capital Territory";
					#$description_text = $description_text."\n".'[[Category:Statistics of the Australian Capital Territory]]';    
				    } 
				    if ($alldata_string =~ m/Darwin/) {
					$location="Darwin";
					#$description_text = $description_text."\n".'[[Category:Statistics of Darwin]]';
				    } elsif (($alldata_string =~ m/Northern Territory/i)||($alldata_string =~ m/[^a-zA-Z]NT[^a-zA-Z]/)||($alldata_string =~ m/ nt /i)) {
					$location="the Northern Territory";
					#$description_text = $description_text."\n".'[[Category:Statistics of the Northern Territory]]';    
				    } 


				    # BY SEX
				    my $sex="";
				    if (($alldata_string =~ m/Male/)||($alldata_string =~ m/ men /i)||($alldata_string =~ m/ boys /i)) {
					$sex="male";
					$description_text = $description_text."\n".'[[Category:Statistics about males in '.$location.']]';
				    }
				    if (($alldata_string =~ m/Female/)||($alldata_string =~ m/ women /i)||($alldata_string =~ m/ girls /i)) {
					$sex="female";
					$description_text = $description_text."\n".'[[Category:Statistics about females in '.$location.']]';
				    }

				    
				    #BY INDUSTRY
				    if ($alldata_string =~ m/Forestry/i) {
					$description_text = $description_text."\n".'[[Category:Statistics about forestry in '.$location.']]';
				    }
				    if (($alldata_string =~ m/Agricultur/i)||(($alldata_string =~ m/Farm/i)&&(!($alldata_string =~ m/Non?Farm/i)))) {
					$description_text = $description_text."\n".'[[Category:Statistics about agriculture in '.$location.']]';
				    }
				    if ($alldata_string =~ m/Mining/i) {
					$description_text = $description_text."\n".'[[Category:Statistics about mining in '.$location.']]';
				    }
				    if ($alldata_string =~ m/Fishing/i) {
					$description_text = $description_text."\n".'[[Category:Statistics about fishing in '.$location.']]';
				    }
				    if (($alldata_string =~ m/Defence/i)&&(!($alldata_string =~ m/Non?Defence/i))) {
					$description_text = $description_text."\n".'[[Category:Statistics about defence in '.$location.']]';
				    }
				    if ($alldata_string =~ m/Telecommunications/i) {
					$description_text = $description_text."\n".'[[Category:Statistics about telecommunications in '.$location.']]';
				    }
				    if ($alldata_string =~ m/ communications/i) {
					$description_text = $description_text."\n".'[[Category:Statistics about communication in '.$location.']]';
				    }
				    if ($alldata_string =~ m/Manufacturing/i) {
					$description_text = $description_text."\n".'[[Category:Statistics about manufacturing in '.$location.']]';
				    }
				    if (($alldata_string =~ m/Construction/i)||($alldata_string =~ m/Building /i)) {
					if ($alldata_string =~ m/Non-Residential Building/i) {
					    $description_text = $description_text."\n".'[[Category:Statistics about non-residential building in '.$location.']]';
					} elsif ($alldata_string =~ m/Residential Building/i) {
					    $description_text = $description_text."\n".'[[Category:Statistics about residential building in '.$location.']]';
					} else {
					    $description_text = $description_text."\n".'[[Category:Statistics about construction in '.$location.']]';
					}
					
					if ($alldata_string =~ m/Work Approved/i) {
					    $description_text = $description_text."\n".'[[Category:Statistics about construction approvals in '.$location.']]';
					}
					if ($alldata_string =~ m/In Pipeline/i) {
					    $description_text = $description_text."\n".'[[Category:Statistics about construction in the pipeline in '.$location.']]';
					}
					
					if ($alldata_string =~ m/Alterations/i) {
					    $description_text = $description_text."\n".'[[Category:Statistics about building alterations in '.$location.']]';
					}
					if ($alldata_string =~ m/Conversion/i) {
					    $description_text = $description_text."\n".'[[Category:Statistics about building conversions in '.$location.']]';
					}
					if ($alldata_string =~ m/ new /i) {
					    $description_text = $description_text."\n".'[[Category:Statistics about new buildings in '.$location.']]';
					}
					if ($alldata_string =~ m/Semi-detached/i) {
					    $description_text = $description_text."\n".'[[Category:Statistics about semi-detached buildings in '.$location.']]';
					}
					if ($alldata_string =~ m/Terrace/i) {
					    $description_text = $description_text."\n".'[[Category:Statistics about terrace buildings in '.$location.']]';
					}
					if ($alldata_string =~ m/Apartment/i) {
					    if ($alldata_string =~ m/one or two storeys/i) {
						$description_text = $description_text."\n".'[[Category:Statistics about one or two storey apartment buildings in '.$location.']]';
					    } elsif ($alldata_string =~ m/three storeys/i) {
						$description_text = $description_text."\n".'[[Category:Statistics about three storey apartment buildings in '.$location.']]';
					    } elsif ($alldata_string =~ m/four or more storeys/i) {
						$description_text = $description_text."\n".'[[Category:Statistics about four or more storey apartment buildings in '.$location.']]';
					    } else {
						$description_text = $description_text."\n".'[[Category:Statistics about apartment buildings in '.$location.']]';
					    }
					}
					if ($alldata_string =~ m/Warehouse/i) {
					    $description_text = $description_text."\n".'[[Category:Statistics about warehouses in '.$location.']]';
					}
					if ($alldata_string =~ m/Factories/i) {
					    $description_text = $description_text."\n".'[[Category:Statistics about factories in '.$location.']]';
					}
					if ($alldata_string =~ m/Offices/i) {
					    $description_text = $description_text."\n".'[[Category:Statistics about offices in '.$location.']]';
					}
					if ($alldata_string =~ m/Transport buildings/i) {
					    $description_text = $description_text."\n".'[[Category:Statistics about transport buildings in '.$location.']]';
					}
					if ($alldata_string =~ m/Aquacultural buidlings/i) {
					    $description_text = $description_text."\n".'[[Category:Statistics about aquacultural buildings in '.$location.']]';
					}
					if ($alldata_string =~ m/Educational/i) {
					    $description_text = $description_text."\n".'[[Category:Statistics about educational buildings in '.$location.']]';
					}
					if ($alldata_string =~ m/Aged Care Facilities/i) {
					    $description_text = $description_text."\n".'[[Category:Statistics about aged care facilities in '.$location.']]';
					}
					if ($alldata_string =~ m/Health Facilities/i) {
					    $description_text = $description_text."\n".'[[Category:Statistics about health facilities in '.$location.']]';
					}
					if ($alldata_string =~ m/Accommodation/i) {
					    $description_text = $description_text."\n".'[[Category:Statistics about accommodation buildings in '.$location.']]';
					}
					if ($alldata_string =~ m/Recreation/i) {
					    $description_text = $description_text."\n".'[[Category:Statistics about recreation facilities in '.$location.']]';
					}
					if ($alldata_string =~ m/Religious/i) {
					    $description_text = $description_text."\n".'[[Category:Statistics about religious buildings in '.$location.']]';
					}
				    }
				    if ($alldata_string =~ m/Business/i) {
					$description_text = $description_text."\n".'[[Category:Statistics about business in '.$location.']]';
				    }
				    if ($alldata_string =~ m/Holiday/i) {
					$description_text = $description_text."\n".'[[Category:Statistics about holidays in '.$location.']]';
				    }
				    if (($alldata_string =~ m/Health/i)||($alldata_string =~ m/Dental/i)) {
					$description_text = $description_text."\n".'[[Category:Statistics about health in '.$location.']]';
				    }
				    if ($alldata_string =~ m/Education/i) {
					$description_text = $description_text."\n".'[[Category:Statistics about education in '.$location.']]';
				    }
				    if ($alldata_string =~ m/Public administration/i) {
					$description_text = $description_text."\n".'[[Category:Statistics about public administration in '.$location.']]';
				    }
				    if (($alldata_string =~ m/Tourism/i)||($alldata_string =~ m/Tourist/i)) {
					$description_text = $description_text."\n".'[[Category:Statistics about tourism in '.$location.']]';
				    }
				    if ($alldata_string =~ m/Transport/i) {
					$description_text = $description_text."\n".'[[Category:Statistics about transport in '.$location.']]';
				    }
				    if (($alldata_string =~ m/Leisure/i)||($alldata_string =~ m/Recreation/i)) {
					$description_text = $description_text."\n".'[[Category:Statistics about leisure in '.$location.']]';
				    }
				    if ($alldata_string =~ m/Insurance/i) {
					$description_text = $description_text."\n".'[[Category:Statistics about insurance in '.$location.']]';
				    }
				    if ($alldata_string =~ m/Scientific/i) {
					$description_text = $description_text."\n".'[[Category:Statistics about science in '.$location.']]';
				    }
				    if ($alldata_string =~ m/Real Estate/i) {
					$description_text = $description_text."\n".'[[Category:Statistics about realty in '.$location.']]';
				    }
				    if ($alldata_string =~ m/Childcare/i) {
					$description_text = $description_text."\n".'[[Category:Statistics about childcare in '.$location.']]';
				    }
				    if ($alldata_string =~ m/Wholesale Trade/i) {
					$description_text = $description_text."\n".'[[Category:Statistics about wholesale trade in '.$location.']]';
				    }
				    if ($alldata_string =~ m/Retail Trade/i) {
					$description_text = $description_text."\n".'[[Category:Statistics about retail trade in '.$location.']]';
				    }

				    # BY INFRASTRUCTURE
				    if ($alldata_string =~ m/School/i) {
					$description_text = $description_text."\n".'[[Category:Statistics about schools in '.$location.']]';
				    }
				    if ($alldata_string =~ m/Restaurant/i) {
					$description_text = $description_text."\n".'[[Category:Statistics about restaurants in '.$location.']]';
				    }
				    if ($alldata_string =~ m/Hotel/i) {
					$description_text = $description_text."\n".'[[Category:Statistics about hotels in '.$location.']]';
				    }
				    if ($alldata_string =~ m/Motel/i) {
					$description_text = $description_text."\n".'[[Category:Statistics about motels in '.$location.']]';
				    }
				    if ($alldata_string =~ m/Serviced Apartments/i) {
					$description_text = $description_text."\n".'[[Category:Statistics about serviced apartments in '.$location.']]';
				    }
				    if ($alldata_string =~ m/Hospital/i) {
					$description_text = $description_text."\n".'[[Category:Statistics about hospitals in '.$location.']]';
				    }
				    if ($alldata_string =~ m/Bridge/i) {
					$description_text = $description_text."\n".'[[Category:Statistics about bridges in '.$location.']]';
				    }
				    if ($alldata_string =~ m/Railway/i) {
					$description_text = $description_text."\n".'[[Category:Statistics about railways in '.$location.']]';
				    }
				    if ($alldata_string =~ m/Sewerage/i) {
					$description_text = $description_text."\n".'[[Category:Statistics about sewerage in '.$location.']]';
				    }
				    if ($alldata_string =~ m/Pipeline/i) {
					$description_text = $description_text."\n".'[[Category:Statistics about pipelines in '.$location.']]';
				    }
				    if ($alldata_string =~ m/Harbour/i) {
					$description_text = $description_text."\n".'[[Category:Statistics about harbours in '.$location.']]';
				    }
				    if ($alldata_string =~ m/ Road/i) {
					$description_text = $description_text."\n".'[[Category:Statistics about roads in '.$location.']]';
				    }
				    if ($alldata_string =~ m/Water storage/i) {
					$description_text = $description_text."\n".'[[Category:Statistics about water storage in '.$location.']]';
				    } elsif ($alldata_string =~ m/Water/i) {
					$description_text = $description_text."\n".'[[Category:Statistics about water in '.$location.']]';
				    }



				    #BY PRODUCT
				    if ($alldata_string =~ m/Livestock slaughtered/i) {
					$description_text = $description_text."\n".'[[Category:Statistics about livestock slaughtered in '.$location.']]';
				    }
				    if ($alldata_string =~ m/Exports of live sheep and cattle/i) {
					$description_text = $description_text."\n".'[[Category:Statistics about exports of live sheep and cattle from '.$location.']]';
				    }

				    if ($alldata_string =~ m/Chemical/i) {
					$description_text = $description_text."\n".'[[Category:Statistics about chemicals in '.$location.']]';
				    }
				    if ($alldata_string =~ m/Polymer/i) {
					$description_text = $description_text."\n".'[[Category:Statistics about polymers in '.$location.']]';
				    }
				    if ($alldata_string =~ m/ wood /i) {
					$description_text = $description_text."\n".'[[Category:Statistics about wood in '.$location.']]';
				    }
				    if ($alldata_string =~ m/ glass /i) {
					$description_text = $description_text."\n".'[[Category:Statistics about glass in '.$location.']]';
				    }
				    if ($alldata_string =~ m/Rubber/i) {
					$description_text = $description_text."\n".'[[Category:Statistics about rubber in '.$location.']]';
				    }
				    if ($alldata_string =~ m/Printing/i) {
					$description_text = $description_text."\n".'[[Category:Statistics about printing in '.$location.']]';
				    }
				    if ($alldata_string =~ m/Textile/i) {
					$description_text = $description_text."\n".'[[Category:Statistics about textiles in '.$location.']]';
				    }
				    if ($alldata_string =~ m/Wool/i) {
					$description_text = $description_text."\n".'[[Category:Statistics about wool in '.$location.']]';
				    }
				    if ($alldata_string =~ m/ Beef/i) {
					$description_text = $description_text."\n".'[[Category:Statistics about beef in '.$location.']]';
				    }
				    if ($alldata_string =~ m/ Veal/i) {
					$description_text = $description_text."\n".'[[Category:Statistics about veal in '.$location.']]';
				    }
				    if ($alldata_string =~ m/ Mutton/i) {
					$description_text = $description_text."\n".'[[Category:Statistics about mutton in '.$location.']]';
				    }
				    if ($alldata_string =~ m/ Lamb /i) {
					$description_text = $description_text."\n".'[[Category:Statistics about lamb in '.$location.']]';
				    }
				    if ($alldata_string =~ m/ Pork /i) {
					$description_text = $description_text."\n".'[[Category:Statistics about pork in '.$location.']]';
				    }
				    if ($alldata_string =~ m/ Bacon /i) {
					$description_text = $description_text."\n".'[[Category:Statistics about bacon in '.$location.']]';
				    }
				    if ($alldata_string =~ m/ Ham /i) {
					$description_text = $description_text."\n".'[[Category:Statistics about ham in '.$location.']]';
				    }
				    if ($alldata_string =~ m/ Bulls/i) {
					$description_text = $description_text."\n".'[[Category:Statistics about bulls in '.$location.']]';
				    }
				    if ($alldata_string =~ m/ Bullocks/i) {
					$description_text = $description_text."\n".'[[Category:Statistics about bullocks in '.$location.']]';
				    }
				    if ($alldata_string =~ m/ Steers/i) {
					$description_text = $description_text."\n".'[[Category:Statistics about steers in '.$location.']]';
				    }
				    if ($alldata_string =~ m/ Sheep/i) {
					$description_text = $description_text."\n".'[[Category:Statistics about sheep in '.$location.']]';
				    }
				    if ($alldata_string =~ m/ Lambs/i) {
					$description_text = $description_text."\n".'[[Category:Statistics about lambs in '.$location.']]';
				    }
				    if (($alldata_string =~ m/ Calves/i)&&(!($alldata_string =~ m/Excl?Calves/i))&&(!($alldata_string =~ m/Excl. Calves/i))&&(!($alldata_string =~ m/Excluding calves/i))) {
					$description_text = $description_text."\n".'[[Category:Statistics about calves in '.$location.']]';
				    }
				    if ($alldata_string =~ m/ meat /i) {
					$description_text = $description_text."\n".'[[Category:Statistics about meat in '.$location.']]';
				    }
				    if ($alldata_string =~ m/ Pigs/i) {
					$description_text = $description_text."\n".'[[Category:Statistics about pigs in '.$location.']]';
				    }
				    if ($alldata_string =~ m/ Heifers/i) {
					$description_text = $description_text."\n".'[[Category:Statistics about heifers in '.$location.']]';
				    }
				    if (($alldata_string =~ m/ Cows/i)||($alldata_string =~ m/ Cattle/i)) {
					$description_text = $description_text."\n".'[[Category:Statistics about cattle in '.$location.']]';
				    }
				    if (($alldata_string =~ m/ Chicken/i)&&(!($alldata_string =~ m/Excl?Chicken/i))&&(!($alldata_string =~ m/Excluding Chicken/i))) {
					$description_text = $description_text."\n".'[[Category:Statistics about chickens in '.$location.']]';
				    }
				    if (($alldata_string =~ m/Sugar/i)&&(!($alldata_string =~ m/Excl?Sugar/i))) {
					$description_text = $description_text."\n".'[[Category:Statistics about sugar in '.$location.']]';
				    }
				    if ($alldata_string =~ m/Grain/i) {
					$description_text = $description_text."\n".'[[Category:Statistics about grain in '.$location.']]';
				    }
				    if (($alldata_string =~ m/Plasterboard/i)||($alldata_string =~ m/Plaster board/i)) {
					$description_text = $description_text."\n".'[[Category:Statistics about plaster board in '.$location.']]';
				    }
				    if ($alldata_string =~ m/Concrete/i) {
					$description_text = $description_text."\n".'[[Category:Statistics about concrete in '.$location.']]';
				    }
				    if ($alldata_string =~ m/Roofing/i) {
					$description_text = $description_text."\n".'[[Category:Statistics about roofing in '.$location.']]';
				    }
				    if ($alldata_string =~ m/Bricks/i) {
					$description_text = $description_text."\n".'[[Category:Statistics about bricks in '.$location.']]';
				    }
				    if ($alldata_string =~ m/Copper/i) {
					$description_text = $description_text."\n".'[[Category:Statistics about copper in '.$location.']]';
				    }
				    if ($alldata_string =~ m/Uranium/i) {
					$description_text = $description_text."\n".'[[Category:Statistics about uranium in '.$location.']]';
				    }
				    if ($alldata_string =~ m/Silver/i) {
					$description_text = $description_text."\n".'[[Category:Statistics about silver in '.$location.']]';
				    }
				    if ($alldata_string =~ m/Nickel/i) {
					$description_text = $description_text."\n".'[[Category:Statistics about nickel in '.$location.']]';
				    }
				    if ($alldata_string =~ m/Diamond/i) {
					$description_text = $description_text."\n".'[[Category:Statistics about diamonds in '.$location.']]';
				    }
				    if ($alldata_string =~ m/Cobalt/i) {
					$description_text = $description_text."\n".'[[Category:Statistics about cobalt in '.$location.']]';
				    }
				    if ($alldata_string =~ m/Zinc/i) {
					$description_text = $description_text."\n".'[[Category:Statistics about zinc in '.$location.']]';
				    }
				    if ($alldata_string =~ m/Mineral Sands/i) {
					$description_text = $description_text."\n".'[[Category:Statistics about mineral sands in '.$location.']]';
				    }
				    if ($alldata_string =~ m/Cobalt/i) {
					$description_text = $description_text."\n".'[[Category:Statistics about cobalt in '.$location.']]';
				    }
				    if ($alldata_string =~ m/ Drill/i) {
					$description_text = $description_text."\n".'[[Category:Statistics about drilling in '.$location.']]';
				    }
				    if ($alldata_string =~ m/Petroleum/i) {
					$description_text = $description_text."\n".'[[Category:Statistics about petroleum in '.$location.']]';
				    }
				    if ($alldata_string =~ m/Mineral/i) {
					$description_text = $description_text."\n".'[[Category:Statistics about minerals in '.$location.']]';
				    }
				    if ($alldata_string =~ m/ Metal/i) {
					$description_text = $description_text."\n".'[[Category:Statistics about metals in '.$location.']]';
				    }
				    if (($alldata_string =~ m/ Gold/i)&&(!($alldata_string =~ m/Non?Gold/i))&&(!($alldata_string =~ m/Excluding?Gold/i))) {
					$description_text = $description_text."\n".'[[Category:Statistics about gold in '.$location.']]';
				    }
				    if ($alldata_string =~ m/Steel/i) {
					$description_text = $description_text."\n".'[[Category:Statistics about steel in '.$location.']]';
				    }
				    if ($alldata_string =~ m/Electricity/i) {
					$description_text = $description_text."\n".'[[Category:Statistics about electricity in '.$location.']]';
				    }
				    if ($alldata_string =~ m/ Gas/i) {
					$description_text = $description_text."\n".'[[Category:Statistics about gas in '.$location.']]';
				    }
				    if ($alldata_string =~ m/ Oil/i) {
					$description_text = $description_text."\n".'[[Category:Statistics about oil in '.$location.']]';
				    }
				    if ($alldata_string =~ m/ Wine/i) {
					$description_text = $description_text."\n".'[[Category:Statistics about wine in '.$location.']]';
				    }
				    if ($alldata_string =~ m/ Milk/i) {
					$description_text = $description_text."\n".'[[Category:Statistics about milk in '.$location.']]';
				    }
				    if ($alldata_string =~ m/ Fuels/i) {
					$description_text = $description_text."\n".'[[Category:Statistics about fuels in '.$location.']]';
				    }
				    if ($alldata_string =~ m/ Clothing/i) {
					$description_text = $description_text."\n".'[[Category:Statistics about clothing in '.$location.']]';
				    }
				    if ($alldata_string =~ m/Department stores/i) {
					$description_text = $description_text."\n".'[[Category:Statistics about department stores in '.$location.']]';
				    }
				    if ($alldata_string =~ m/Book retailing/i) {
					$description_text = $description_text."\n".'[[Category:Statistics about book retailing in '.$location.']]';
				    }
				    if ($alldata_string =~ m/Recreational goods retailing/i) {
					$description_text = $description_text."\n".'[[Category:Statistics about recreational goods retailing in '.$location.']]';
				    }
				    if ($alldata_string =~ m/Pharmaceutical/i) {
					$description_text = $description_text."\n".'[[Category:Statistics about pharmaceuticals in '.$location.']]';
				    }
				    if ($alldata_string =~ m/Takeaway foods/i) {
					$description_text = $description_text."\n".'[[Category:Statistics about takeaway foods in '.$location.']]';
				    }
				    if ($alldata_string =~ m/Catering/i) {
					$description_text = $description_text."\n".'[[Category:Statistics about catering in '.$location.']]';
				    }
				    if ($alldata_string =~ m/Supermarket/i) {
					$description_text = $description_text."\n".'[[Category:Statistics about supermarkets in '.$location.']]';
				    }
				    if ($alldata_string =~ m/Liquor Retailing/i) {
					$description_text = $description_text."\n".'[[Category:Statistics about liquor retailing in '.$location.']]';
				    }
				    if ($alldata_string =~ m/Specialised food retailing/i) {
					$description_text = $description_text."\n".'[[Category:Statistics about specialised food retailing in '.$location.']]';
				    }
				    if ($alldata_string =~ m/Hardware/i) {
					$description_text = $description_text."\n".'[[Category:Statistics about hardware in '.$location.']]';
				    }
				    if ($alldata_string =~ m/Garden supplies/i) {
					$description_text = $description_text."\n".'[[Category:Statistics about garden supplies in '.$location.']]';
				    }
				    if ($alldata_string =~ m/Clothing retailing/i) {
					$description_text = $description_text."\n".'[[Category:Statistics about clothing retailing in '.$location.']]';
				    }
				    if ($alldata_string =~ m/ Food/i) {
					$description_text = $description_text."\n".'[[Category:Statistics about food in '.$location.']]';
				    }
				    if ($alldata_string =~ m/Footware/i) {
					$description_text = $description_text."\n".'[[Category:Statistics about footware in '.$location.']]';
				    }
				    if ($alldata_string =~ m/Furnishing/i) {
					$description_text = $description_text."\n".'[[Category:Statistics about furnishings in '.$location.']]';
				    }
				    if ($alldata_string =~ m/Infants/i) {
					$description_text = $description_text."\n".'[[Category:Statistics about infants in '.$location.']]';
				    }
				    if ($alldata_string =~ m/Tobacco/i) {
					$description_text = $description_text."\n".'[[Category:Statistics about tobacco in '.$location.']]';
				    }
				    if ($alldata_string =~ m/Beverage/i) {
					if (($alldata_string =~ m/Non-Alcoholic/i)||($alldata_string =~ m/Non Alcoholic/i)||($alldata_string =~ m/NonAlcoholic/i)) {
					    $description_text = $description_text."\n".'[[Category:Statistics about non-alcoholic beverages in '.$location.']]';
					} elsif ($alldata_string =~ m/Alcohol/i) {
					    $description_text = $description_text."\n".'[[Category:Statistics about alcoholic beverages in '.$location.']]';
					} else {
					    $description_text = $description_text."\n".'[[Category:Statistics about beverages in '.$location.']]';
					}
				    } elsif ($alldata_string =~ m/Alcohol/i) {
					$description_text = $description_text."\n".'[[Category:Statistics about alcohol in '.$location.']]';
				    }
				    if ($alldata_string =~ m/Computer/i) {
					$description_text = $description_text."\n".'[[Category:Statistics about computers in '.$location.']]';
				    }
				    if ($alldata_string =~ m/Machinery/i) {
					$description_text = $description_text."\n".'[[Category:Statistics about machinery in '.$location.']]';
				    }
				    if ($alldata_string =~ m/ books /i) {
					$description_text = $description_text."\n".'[[Category:Statistics about books in '.$location.']]';
				    }
				    if ($alldata_string =~ m/ paper/i) {
					$description_text = $description_text."\n".'[[Category:Statistics about paper in '.$location.']]';
				    }
				    if ($alldata_string =~ m/newspaper/i) {
					$description_text = $description_text."\n".'[[Category:Statistics about newspapers in '.$location.']]';
				    }
				    if ($alldata_string =~ m/aircraft/i) {
					$description_text = $description_text."\n".'[[Category:Statistics about aircrafts in '.$location.']]';
				    }


				    # BY ORGANIZATION
				    if ($alldata_string =~ m/Public sector/i) {
					$description_text = $description_text."\n".'[[Category:Statistics about the public sector in '.$location.']]';
				    }
				    if ($alldata_string =~ m/Private sector/i) {
					$description_text = $description_text."\n".'[[Category:Statistics about the private sector in '.$location.']]';
				    }
				    if ($alldata_string =~ m/ Household/i) {
					$description_text = $description_text."\n".'[[Category:Statistics about households in '.$location.']]';
				    }
				    if ($alldata_string =~ m/Pension Funds/i) {
					$description_text = $description_text."\n".'[[Category:Statistics about pension funds in '.$location.']]';
				    }
				    if ($alldata_string =~ m/Cash Management Trusts/i) {
					$description_text = $description_text."\n".'[[Category:Statistics about cash management trusts in '.$location.']]';
				    }
				    if ($alldata_string =~ m/Common Funds/i) {
					$description_text = $description_text."\n".'[[Category:Statistics about common funds in '.$location.']]';
				    }
				    if ($alldata_string =~ m/Friendly Societies/i) {
					$description_text = $description_text."\n".'[[Category:Statistics about friendly societies in '.$location.']]';
				    }
				    if ($alldata_string =~ m/Investment Managers/i) {
					$description_text = $description_text."\n".'[[Category:Statistics about investment managers in '.$location.']]';
				    }
				    if ($alldata_string =~ m/Public Unit Trusts/i) {
					$description_text = $description_text."\n".'[[Category:Statistics about public unit trusts in '.$location.']]';
				    }
				    if ($alldata_string =~ m/Superannuation/i) {
					$description_text = $description_text."\n".'[[Category:Statistics about superannuation in '.$location.']]';
				    }
				    if ($alldata_string =~ m/Summary Managed Funds/i) {
					$description_text = $description_text."\n".'[[Category:Statistics about managed funds in '.$location.']]';
				    }
				    if ($alldata_string =~ m/Life Insurance/i) {
					if ($alldata_string =~ m/Life Insurance Corporations/i) {
					    $description_text = $description_text."\n".'[[Category:Statistics about life insurance corporations in '.$location.']]';
					} else {
					    $description_text = $description_text."\n".'[[Category:Statistics about life insurance in '.$location.']]';
					}
				    }
				    if ($alldata_string =~ m/Central Borrowing Authorities/i) {
					$description_text = $description_text."\n".'[[Category:Statistics about central borrowing authorities in '.$location.']]';
				    }
				    if ($alldata_string =~ m/Investment funds/i) {
					$description_text = $description_text."\n".'[[Category:Statistics about investment funds in '.$location.']]';
				    }
				    if ($alldata_string =~ m/Securitisers/i) {
					$description_text = $description_text."\n".'[[Category:Statistics about securitisers in '.$location.']]';
				    }
				    if (($alldata_string =~ m/ Government/i)&&(!($alldata_string =~ m/Non?Government/i))) {
					$description_text = $description_text."\n".'[[Category:Statistics about governments in '.$location.']]';
				    }
				    if ($alldata_string =~ m/Industry/i) {
					$description_text = $description_text."\n".'[[Category:Statistics about industry in '.$location.']]';
				    }

				    # BY ASSET CLASS
				    if (($alldata_string =~ m/Equit/i)&&(!($alldata_string =~ m/Non?Equit/i))) {
					$description_text = $description_text."\n".'[[Category:Statistics about equities in '.$location.']]';
				    }
				    if ($alldata_string =~ m/Bonds/i) {
					$description_text = $description_text."\n".'[[Category:Statistics about bonds in '.$location.']]';
				    }
				    if ($alldata_string =~ m/Deposits/i) {
					$description_text = $description_text."\n".'[[Category:Statistics about deposits in '.$location.']]';
				    }
				    if ($alldata_string =~ m/Securities/i) {
					$description_text = $description_text."\n".'[[Category:Statistics about securities in '.$location.']]';
				    }


				    # BY ECONOMIC CATEGORY
				    if ($alldata_string =~ m/ rent/i) {
					$description_text = $description_text."\n".'[[Category:Statistics about rent in '.$location.']]';
				    }
				    if ($alldata_string =~ m/Intellectual Property/i) {
					$description_text = $description_text."\n".'[[Category:Statistics about intellectual property in '.$location.']]';
				    }

				    if (($alldata_string =~ m/ Loans/i)||($alldata_string =~ m/Lending/i)) {
					if (($alldata_string =~ m/ Automobiles/i)||($alldata_string =~ m/ Car /i)||($alldata_string =~ m/ Cars /i)||($alldata_string =~ m/Station Wagon/i)||($alldata_string =~ m/ Truck/i)||($alldata_string =~ m/ Vehicle/i)) {
					    $description_text = $description_text."\n".'[[Category:Statistics about automobile loans in '.$location.']]';
					} elsif ($alldata_string =~ m/Housing/i) {
					    $description_text = $description_text."\n".'[[Category:Statistics about housing loans in '.$location.']]';
					} elsif ($alldata_string =~ m/Plant equipment/i) {
					    $description_text = $description_text."\n".'[[Category:Statistics about plant equipment loans in '.$location.']]';
					}
					if ($alldata_string =~ m/Commercial/i) {
					    $description_text = $description_text."\n".'[[Category:Statistics about commercial loans in '.$location.']]';
					} elsif ($alldata_string =~ m/Personal/i) {
					    $description_text = $description_text."\n".'[[Category:Statistics about personal loans in '.$location.']]';
					} elsif ($alldata_string =~ m/Operating Lease Finance/i) {
					    $description_text = $description_text."\n".'[[Category:Statistics about operating lease finance in '.$location.']]';
					} elsif ($alldata_string =~ m/Lease Finance/i) {
					    $description_text = $description_text."\n".'[[Category:Statistics about lease finance in '.$location.']]';
					} else {
					    $description_text = $description_text."\n".'[[Category:Statistics about lending in '.$location.']]';
					}
				    } else {
					if (($alldata_string =~ m/ Automobiles/i)||($alldata_string =~ m/ Car /i)||($alldata_string =~ m/ Cars /i)||($alldata_string =~ m/Station Wagon/i)||($alldata_string =~ m/ Truck/i)||($alldata_string =~ m/ Vehicle/i)) {
					    $description_text = $description_text."\n".'[[Category:Statistics about automobiles in '.$location.']]';
					}
				    }


				    if (($alldata_string =~ m/ Bank/i)&&(!($alldata_string =~ m/Non?Bank/i))&&(!($alldata_string =~ m/NonBank/i))) {
					if (($alldata_string =~ m/ Loans/i)||($alldata_string =~ m/Lending/i)) {
					    $description_text = $description_text."\n".'[[Category:Statistics about bank lending in '.$location.']]';
					} else {
					    $description_text = $description_text."\n".'[[Category:Statistics about banks in '.$location.']]';
					}
				    }
				    if (($alldata_string =~ m/Nonbank/i)||($alldata_string =~ m/Non-Bank/i)) {
					if (($alldata_string =~ m/ Loans/i)||($alldata_string =~ m/Lending/i)) {
					    $description_text = $description_text."\n".'[[Category:Statistics about non-bank lending in '.$location.']]';
					}
				    }
				    
				    # BY INDEX
				    if ($alldata_string =~ m/Producer Price Index/i) {
					$description_text = $description_text."\n".'[[Category:Producer price indexes of '.$location.']]';
				    }
				    if ($alldata_string =~ m/Consumer Price Index/i) {
					$description_text = $description_text."\n".'[[Category:Consumer price indexes of '.$location.']]';
				    }
				    if ($alldata_string =~ m/House Price Index/i) {
					$description_text = $description_text."\n".'[[Category:House price indexes of '.$location.']]';
				    } elsif ((($alldata_string =~ m/Housing/i)||($alldata_string =~ m/House /i)||($alldata_string =~ m/Houses /i)||($alldata_string =~ m/Dwellings/i))&&(!($alldata_string =~ m/Excluding?Hous/i))&&(!($alldata_string =~ m/Non?Dwelling/i))) {
					$description_text = $description_text."\n".'[[Category:Statistics about housing in '.$location.']]';
				    }




				    # BY BILATERAL RELATIONSHIPS
				    if ($alldata_string =~ m/Albania/) {
					$description_text = $description_text."\n".'[[Category:Relations of Albania and Australia]]';
				    }
				    if ($alldata_string =~ m/Algeria/) {
					$description_text = $description_text."\n".'[[Category:Relations of Algeria and Australia]]';
				    }
				    if ($alldata_string =~ m/Argentina/) {
					$description_text = $description_text."\n".'[[Category:Relations of Argentina and Australia]]';
				    }
				    if ($alldata_string =~ m/Austria/) {
					$description_text = $description_text."\n".'[[Category:Relations of Australia and Austria]]';
				    }
				    if ($alldata_string =~ m/Azerbaijan/) {
					$description_text = $description_text."\n".'[[Category:Relations of Australia and Azerbaijan]]';
				    }
				    if ($alldata_string =~ m/Bahamas/) {
					$description_text = $description_text."\n".'[[Category:Relations of Australia and Bahamas]]';
				    }
				    if ($alldata_string =~ m/Bahrain/) {
					$description_text = $description_text."\n".'[[Category:Relations of Australia and Bahrain]]';
				    }
				    if ($alldata_string =~ m/Bangladesh/) {
					$description_text = $description_text."\n".'[[Category:Relations of Australia and Bangladesh]]';
				    }
				    if ($alldata_string =~ m/Belarus/) {
					$description_text = $description_text."\n".'[[Category:Relations of Australia and Belarus]]';
				    }
				    if ($alldata_string =~ m/Belgium/) {
					$description_text = $description_text."\n".'[[Category:Relations of Australia and Belgium]]';
				    }
				    if ($alldata_string =~ m/Belize/) {
					$description_text = $description_text."\n".'[[Category:Relations of Australia and Belize]]';
				    }
				    if ($alldata_string =~ m/Bermuda/) {
					$description_text = $description_text."\n".'[[Category:Relations of Australia and Bermuda]]';
				    }
				    if ($alldata_string =~ m/Bolivia/) {
					$description_text = $description_text."\n".'[[Category:Relations of Australia and Bolivia]]';
				    }
				    if ($alldata_string =~ m/Bosnia/) {
					$description_text = $description_text."\n".'[[Category:Relations of Australia and Bosnia and Herzegovina]]';
				    }
				    if ($alldata_string =~ m/Brazil/) {
					$description_text = $description_text."\n".'[[Category:Relations of Australia and Brazil]]';
				    }
				    if ($alldata_string =~ m/Brunei/) {
					$description_text = $description_text."\n".'[[Category:Relations of Australia and Brunei]]';
				    }
				    if ($alldata_string =~ m/Bulgaria/) {
					$description_text = $description_text."\n".'[[Category:Relations of Australia and Bulgaria]]';
				    }
				    if ($alldata_string =~ m/Burma/) {
					$description_text = $description_text."\n".'[[Category:Relations of Australia and Burma]]';
				    }
				    if ($alldata_string =~ m/Cambodia/) {
					$description_text = $description_text."\n".'[[Category:Relations of Australia and Cambodia]]';
				    }
				    if ($alldata_string =~ m/Canada/) {
					$description_text = $description_text."\n".'[[Category:Relations of Australia and Canada]]';
				    }
				    if ($alldata_string =~ m/Cayman Islands/) {
					$description_text = $description_text."\n".'[[Category:Relations of Australia and the Cayman Islands]]';
				    }
				    if ($alldata_string =~ m/Chile/) {
					$description_text = $description_text."\n".'[[Category:Relations of Australia and Chile]]';
				    }
				    if ($alldata_string =~ m/China/) {
					$description_text = $description_text."\n".'[[Category:Relations of Australia and China]]';
				    }
				    if ($alldata_string =~ m/Christmas Island/) {
					$description_text = $description_text."\n".'[[Category:Relations of Australia and Christmas Island]]';
				    }
				    if ($alldata_string =~ m/Cook Islands/) {
					$description_text = $description_text."\n".'[[Category:Relations of Australia and the Cook Islands]]';
				    }
				    if ($alldata_string =~ m/Colombia/) {
					$description_text = $description_text."\n".'[[Category:Relations of Australia and Colombia]]';
				    }
				    if ($alldata_string =~ m/Congo/) {
					$description_text = $description_text."\n".'[[Category:Relations of Australia and Congo]]';
				    }
				    if ($alldata_string =~ m/Cook Islands/) {
					$description_text = $description_text."\n".'[[Category:Relations of Australia and Cook Islands]]';
				    }
				    if ($alldata_string =~ m/Costa Rica/) {
					$description_text = $description_text."\n".'[[Category:Relations of Australia and Costa Rica]]';
				    }
				    if ($alldata_string =~ m/Cote d\'Ivoire/) {
					$description_text = $description_text."\n".'[[Category:Relations of Australia and Cote d\'Ivoire]]';
				    }
				    if ($alldata_string =~ m/Croatia/) {
					$description_text = $description_text."\n".'[[Category:Relations of Australia and Croatia]]';
				    }
				    if ($alldata_string =~ m/Cuba/) {
					$description_text = $description_text."\n".'[[Category:Relations of Australia and Cuba]]';
				    }
				    if ($alldata_string =~ m/Cyprus/) {
					$description_text = $description_text."\n".'[[Category:Relations of Australia and Cyprus]]';
				    }
				    if ($alldata_string =~ m/Czech Republic/) {
					$description_text = $description_text."\n".'[[Category:Relations of Australia and the Czech Republic]]';
				    }
				    if ($alldata_string =~ m/Denmark/) {
					$description_text = $description_text."\n".'[[Category:Relations of Australia and Denmark]]';
				    }
				    if ($alldata_string =~ m/Dominican Republic/) {
					$description_text = $description_text."\n".'[[Category:Relations of Australia and Dominican Republic]]';
				    }
				    if ($alldata_string =~ m/East Timor/) {
					$description_text = $description_text."\n".'[[Category:Relations of Australia and East Timor]]';
				    }
				    if ($alldata_string =~ m/Ecuador/) {
					$description_text = $description_text."\n".'[[Category:Relations of Australia and Ecuador]]';
				    }
				    if ($alldata_string =~ m/Egypt/) {
					$description_text = $description_text."\n".'[[Category:Relations of Australia and Egypt]]';
				    }
				    if ($alldata_string =~ m/El Salvadore/) {
					$description_text = $description_text."\n".'[[Category:Relations of Australia and El Salvadore]]';
				    }
				    if ($alldata_string =~ m/Estonia/) {
					$description_text = $description_text."\n".'[[Category:Relations of Australia and Estonia]]';
				    }
				    if ($alldata_string =~ m/Ethiopia/) {
					$description_text = $description_text."\n".'[[Category:Relations of Australia and Ethiopia]]';
				    }
				    if ($alldata_string =~ m/Euro/) {
					$description_text = $description_text."\n".'[[Category:Relations of Australia and the European Union]]';
				    }
				    if ($alldata_string =~ m/Fiji/) {
					$description_text = $description_text."\n".'[[Category:Relations of Australia and Fiji]]';
				    }
				    if ($alldata_string =~ m/Finland/) {
					$description_text = $description_text."\n".'[[Category:Relations of Australia and Finland]]';
				    }
				    if ($alldata_string =~ m/France/) {
					$description_text = $description_text."\n".'[[Category:Relations of Australia and France]]';
				    }
				    if ($alldata_string =~ m/French Polynesia/) {
					$description_text = $description_text."\n".'[[Category:Relations of Australia and French Polynesia]]';
				    }
				    if ($alldata_string =~ m/Gabon/) {
					$description_text = $description_text."\n".'[[Category:Relations of Australia and Gabon]]';
				    }
				    if ($alldata_string =~ m/Georgia/) {
					$description_text = $description_text."\n".'[[Category:Relations of Australia and Georgia]]';
				    }
				    if ($alldata_string =~ m/Germany/) {
					$description_text = $description_text."\n".'[[Category:Relations of Australia and Germany]]';
				    }
				    if ($alldata_string =~ m/Ghana/) {
					$description_text = $description_text."\n".'[[Category:Relations of Australia and Ghana]]';
				    }
				    if ($alldata_string =~ m/Greece/) {
					$description_text = $description_text."\n".'[[Category:Relations of Australia and Greece]]';
				    }
				    if ($alldata_string =~ m/Guatemala/) {
					$description_text = $description_text."\n".'[[Category:Relations of Australia and Guatemala]]';
				    }
				    if ($alldata_string =~ m/Guyana/) {
					$description_text = $description_text."\n".'[[Category:Relations of Australia and Guyana]]';
				    }
				    if ($alldata_string =~ m/Honduras/) {
					$description_text = $description_text."\n".'[[Category:Relations of Australia and Honduras]]';
				    }
				    if ($alldata_string =~ m/Hong Kong/) {
					$description_text = $description_text."\n".'[[Category:Relations of Australia and Hong Kong]]';
				    }
				    if ($alldata_string =~ m/Hungary/) {
					$description_text = $description_text."\n".'[[Category:Relations of Australia and Hungary]]';
				    }
				    if ($alldata_string =~ m/Iceland/) {
					$description_text = $description_text."\n".'[[Category:Relations of Australia and Iceland]]';
				    }
				    if ($alldata_string =~ m/India/) {
					$description_text = $description_text."\n".'[[Category:Relations of Australia and India]]';
				    }
				    if ($alldata_string =~ m/Indonesia/) {
					$description_text = $description_text."\n".'[[Category:Relations of Australia and Indonesia]]';
				    }
				    if ($alldata_string =~ m/Iran/) {
					$description_text = $description_text."\n".'[[Category:Relations of Australia and Iran]]';
				    }
				    if ($alldata_string =~ m/Iraq/) {
					$description_text = $description_text."\n".'[[Category:Relations of Australia and Iraq]]';
				    }
				    if ($alldata_string =~ m/Ireland/) {
					$description_text = $description_text."\n".'[[Category:Relations of Australia and Ireland]]';
				    }
				    if ($alldata_string =~ m/Israel/) {
					$description_text = $description_text."\n".'[[Category:Relations of Australia and Israel]]';
				    }
				    if ($alldata_string =~ m/Italy/) {
					$description_text = $description_text."\n".'[[Category:Relations of Australia and Italy]]';
				    }
				    if ($alldata_string =~ m/Japan/) {
					$description_text = $description_text."\n".'[[Category:Relations of Australia and Japan]]';
				    }
				    if ($alldata_string =~ m/Jordan/) {
					$description_text = $description_text."\n".'[[Category:Relations of Australia and Jordan]]';
				    }
				    if ($alldata_string =~ m/Kazakhstan/) {
					$description_text = $description_text."\n".'[[Category:Relations of Australia and Kazakhstan]]';
				    }
				    if ($alldata_string =~ m/Korea/) {
					$description_text = $description_text."\n".'[[Category:Relations of Australia and Korea]]';
				    }
				    if ($alldata_string =~ m/Kuwait/) {
					$description_text = $description_text."\n".'[[Category:Relations of Australia and Kuwait]]';
				    }
				    if ($alldata_string =~ m/Laos/) {
					$description_text = $description_text."\n".'[[Category:Relations of Australia and Laos]]';
				    }
				    if ($alldata_string =~ m/Latvia/) {
					$description_text = $description_text."\n".'[[Category:Relations of Australia and Latvia]]';
				    }
				    if ($alldata_string =~ m/Lebanon/) {
					$description_text = $description_text."\n".'[[Category:Relations of Australia and Lebanon]]';
				    }
				    if ($alldata_string =~ m/Libya/) {
					$description_text = $description_text."\n".'[[Category:Relations of Australia and Libya]]';
				    }
				    if ($alldata_string =~ m/Lithuania/) {
					$description_text = $description_text."\n".'[[Category:Relations of Australia and Lithuania]]';
				    }
				    if ($alldata_string =~ m/Luxembourg/) {
					$description_text = $description_text."\n".'[[Category:Relations of Australia and Luxembourg]]';
				    }
				    if ($alldata_string =~ m/Macau/) {
					$description_text = $description_text."\n".'[[Category:Relations of Australia and Macau]]';
				    }
				    if ($alldata_string =~ m/Macedonia/) {
					$description_text = $description_text."\n".'[[Category:Relations of Australia and Macedonia]]';
				    }
				    if ($alldata_string =~ m/Malawi/) {
					$description_text = $description_text."\n".'[[Category:Relations of Australia and Malawi]]';
				    }
				    if ($alldata_string =~ m/Malaysia/) {
					$description_text = $description_text."\n".'[[Category:Relations of Australia and Malaysia]]';
				    }
				    if ($alldata_string =~ m/Mali/) {
					$description_text = $description_text."\n".'[[Category:Relations of Australia and Mali]]';
				    }
				    if ($alldata_string =~ m/Malta/) {
					$description_text = $description_text."\n".'[[Category:Relations of Australia and Malta]]';
				    }
				    if ($alldata_string =~ m/Mauritius/) {
					$description_text = $description_text."\n".'[[Category:Relations of Australia and Mauritius]]';
				    }
				    if ($alldata_string =~ m/Mexico/) {
					$description_text = $description_text."\n".'[[Category:Relations of Australia and Mexico]]';
				    }
				    if ($alldata_string =~ m/Morocco/) {
					$description_text = $description_text."\n".'[[Category:Relations of Australia and Morocco]]';
				    }
				    if ($alldata_string =~ m/Mozambique/) {
					$description_text = $description_text."\n".'[[Category:Relations of Australia and Mozambique]]';
				    }
				    if ($alldata_string =~ m/Namibia/) {
					$description_text = $description_text."\n".'[[Category:Relations of Australia and Namibia]]';
				    }
				    if ($alldata_string =~ m/Nauru/) {
					$description_text = $description_text."\n".'[[Category:Relations of Australia and Nauru]]';
				    }
				    if ($alldata_string =~ m/Nepal/) {
					$description_text = $description_text."\n".'[[Category:Relations of Australia and Nepal]]';
				    }
				    if ($alldata_string =~ m/Netherlands/) {
					$description_text = $description_text."\n".'[[Category:Relations of Australia and the Netherlands]]';
				    }
				    if ($alldata_string =~ m/New Caledonia/) {
					$description_text = $description_text."\n".'[[Category:Relations of Australia and New Caledonia]]';
				    }
				    if ($alldata_string =~ m/New Zealand/) {
					$description_text = $description_text."\n".'[[Category:Relations of Australia and New Zealand]]';
				    }
				    if ($alldata_string =~ m/Nicaragua/) {
					$description_text = $description_text."\n".'[[Category:Relations of Australia and Nicaragua]]';
				    }
				    if ($alldata_string =~ m/Niger /) {
					$description_text = $description_text."\n".'[[Category:Relations of Australia and Niger]]';
				    }
				    if ($alldata_string =~ m/Nigeria/) {
					$description_text = $description_text."\n".'[[Category:Relations of Australia and Nigeria]]';
				    }
				    if ($alldata_string =~ m/Norfolk Island/) {
					$description_text = $description_text."\n".'[[Category:Relations of Australia and Norfolk Island]]';
				    }
				    if ($alldata_string =~ m/Norway/) {
					$description_text = $description_text."\n".'[[Category:Relations of Australia and Norway]]';
				    }
				    if ($alldata_string =~ m/Oman/) {
					$description_text = $description_text."\n".'[[Category:Relations of Australia and Oman]]';
				    }
				    if ($alldata_string =~ m/Pakistan/) {
					$description_text = $description_text."\n".'[[Category:Relations of Australia and Pakistan]]';
				    }
				    if ($alldata_string =~ m/Panama/) {
					$description_text = $description_text."\n".'[[Category:Relations of Australia and Panama]]';
				    }
				    if ($alldata_string =~ m/Papua New Guinea/) {
					$description_text = $description_text."\n".'[[Category:Relations of Australia and Papua New Guinea]]';
				    }
				    if ($alldata_string =~ m/Peru/) {
					$description_text = $description_text."\n".'[[Category:Relations of Australia and Peru]]';
				    }
				    if ($alldata_string =~ m/Philippines/) {
					$description_text = $description_text."\n".'[[Category:Relations of Australia and the Philippines]]';
				    }
				    if ($alldata_string =~ m/Poland/) {
					$description_text = $description_text."\n".'[[Category:Relations of Australia and Poland]]';
				    }
				    if ($alldata_string =~ m/Portugal/) {
					$description_text = $description_text."\n".'[[Category:Relations of Australia and Portugal]]';
				    }
				    if ($alldata_string =~ m/Puerto Rico/) {
					$description_text = $description_text."\n".'[[Category:Relations of Australia and Puerto Rico]]';
				    }
				    if ($alldata_string =~ m/Qatar/) {
					$description_text = $description_text."\n".'[[Category:Relations of Australia and Qatar]]';
				    }
				    if ($alldata_string =~ m/Romania/) {
					$description_text = $description_text."\n".'[[Category:Relations of Australia and Romania]]';
				    }
				    if ($alldata_string =~ m/Russian Federation/) {
					$description_text = $description_text."\n".'[[Category:Relations of Australia and the Russian Federation]]';
				    }
				    if ($alldata_string =~ m/Samoa/) {
					$description_text = $description_text."\n".'[[Category:Relations of Australia and Samoa]]';
				    }
				    if ($alldata_string =~ m/Saudi Arabia/) {
					$description_text = $description_text."\n".'[[Category:Relations of Australia and Saudi Arabia]]';
				    }
				    if ($alldata_string =~ m/Senegal/) {
					$description_text = $description_text."\n".'[[Category:Relations of Australia and Senegal]]';
				    }
				    if ($alldata_string =~ m/Serbia/) {
					$description_text = $description_text."\n".'[[Category:Relations of Australia and Serbia]]';
				    }
				    if ($alldata_string =~ m/Seychelles/) {
					$description_text = $description_text."\n".'[[Category:Relations of Australia and Seychelles]]';
				    }
				    if ($alldata_string =~ m/Sierra Leone/) {
					$description_text = $description_text."\n".'[[Category:Relations of Australia and Sierra Leone]]';
				    }
				    if ($alldata_string =~ m/Singapore/) {
					$description_text = $description_text."\n".'[[Category:Relations of Australia and Singapore]]';
				    }
				    if ($alldata_string =~ m/Slovak/) {
					$description_text = $description_text."\n".'[[Category:Relations of Australia and the Slovak Republic]]';
				    }
				    if ($alldata_string =~ m/Slovenia/) {
					$description_text = $description_text."\n".'[[Category:Relations of Australia and Slovenia]]';
				    }
				    if ($alldata_string =~ m/Solomon Islands/) {
					$description_text = $description_text."\n".'[[Category:Relations of Australia and the Solomon Islands]]';
				    }
				    if ($alldata_string =~ m/South Africa/) {
					$description_text = $description_text."\n".'[[Category:Relations of Australia and South Africa]]';
				    }
				    if ($alldata_string =~ m/Spain/) {
					$description_text = $description_text."\n".'[[Category:Relations of Australia and Spain]]';
				    }
				    if ($alldata_string =~ m/Sri Lanka/) {
					$description_text = $description_text."\n".'[[Category:Relations of Australia and Sri Lanka]]';
				    }
				    if ($alldata_string =~ m/Grenadines/) {
					$description_text = $description_text."\n".'[[Category:Relations of Australia and St Vincent and Grenadines]]';
				    }
				    if ($alldata_string =~ m/Sudan/) {
					$description_text = $description_text."\n".'[[Category:Relations of Australia and Sudan]]';
				    }
				    if ($alldata_string =~ m/Swaziland/) {
					$description_text = $description_text."\n".'[[Category:Relations of Australia and Swaziland]]';
				    }
				    if ($alldata_string =~ m/Sweden/) {
					$description_text = $description_text."\n".'[[Category:Relations of Australia and Sweden]]';
				    }
				    if ($alldata_string =~ m/Switzerland/) {
					$description_text = $description_text."\n".'[[Category:Relations of Australia and Switzerland]]';
				    }
				    if ($alldata_string =~ m/Syria/) {
					$description_text = $description_text."\n".'[[Category:Relations of Australia and Syria]]';
				    }
				    if ($alldata_string =~ m/Taiwan/) {
					$description_text = $description_text."\n".'[[Category:Relations of Australia and Taiwan]]';
				    }
				    if ($alldata_string =~ m/Tajikistan/) {
					$description_text = $description_text."\n".'[[Category:Relations of Australia and Tajikistan]]';
				    }
				    if ($alldata_string =~ m/Tanzania/) {
					$description_text = $description_text."\n".'[[Category:Relations of Australia and Tanzania]]';
				    }
				    if ($alldata_string =~ m/Thailand/) {
					$description_text = $description_text."\n".'[[Category:Relations of Australia and Thailand]]';
				    }
				    if ($alldata_string =~ m/Togo/) {
					$description_text = $description_text."\n".'[[Category:Relations of Australia and Togo]]';
				    }
				    if ($alldata_string =~ m/Tonga/) {
					$description_text = $description_text."\n".'[[Category:Relations of Australia and Tonga]]';
				    }
				    if ($alldata_string =~ m/Trinidad/) {
					$description_text = $description_text."\n".'[[Category:Relations of Australia and Trinidad and Tobago]]';
				    }
				    if ($alldata_string =~ m/Tunisia/) {
					$description_text = $description_text."\n".'[[Category:Relations of Australia and Tunisia]]';
				    }
				    if ($alldata_string =~ m/Turkey/) {
					$description_text = $description_text."\n".'[[Category:Relations of Australia and Turkey]]';
				    }
				    if ($alldata_string =~ m/Uganda/) {
					$description_text = $description_text."\n".'[[Category:Relations of Australia and Uganda]]';
				    }
				    if ($alldata_string =~ m/Ukraine/) {
					$description_text = $description_text."\n".'[[Category:Relations of Australia and Ukraine]]';
				    }
				    if (($alldata_string =~ m/United Arab Emirates/)||($alldata_string =~ m/[^a-z]UAE[^a-z]/i)) {
					$description_text = $description_text."\n".'[[Category:Relations of Australia and the United Arab Emirates]]';
				    }
				    if ($alldata_string =~ m/[^a-z]UK[^a-z]/i) {
					$description_text = $description_text."\n".'[[Category:Relations of Australia and the United Kingdom]]';
				    }
				    if (($alldata_string =~ m/United States of America/)||($alldata_string =~ m/[^a-zA-Z]USA[^a-zA-Z]/i)) {
					$description_text = $description_text."\n".'[[Category:Relations of Australia and the United States]]';
				    }
				    if ($alldata_string =~ m/Uruguay/) {
					$description_text = $description_text."\n".'[[Category:Relations of Australia and Uruguay]]';
				    }
				    if ($alldata_string =~ m/Vanuatu/) {
					$description_text = $description_text."\n".'[[Category:Relations of Australia and Vanuatu]]';
				    }
				    if ($alldata_string =~ m/Venezuela/) {
					$description_text = $description_text."\n".'[[Category:Relations of Australia and Venezuela]]';
				    }
				    if ($alldata_string =~ m/Vietnam/) {
					$description_text = $description_text."\n".'[[Category:Relations of Australia and Vietnam]]';
				    }
				    if ($alldata_string =~ m/Virgin Islands/) {
					$description_text = $description_text."\n".'[[Category:Relations of Australia and the British Virgin Islands]]';
				    }
				    if ($alldata_string =~ m/Yemen/) {
					$description_text = $description_text."\n".'[[Category:Relations of Australia and Yemen]]';
				    }
				    if ($alldata_string =~ m/Zambia/) {
					$description_text = $description_text."\n".'[[Category:Relations of Australia and Zambia]]';
				    }
				    if ($alldata_string =~ m/Zimbabwe/) {
					$description_text = $description_text."\n".'[[Category:Relations of Australia and Zimbabwe]]';
				    }




				    #travel stats
				    if (($table_title =~ m/settler/i)||($column_title =~ m/settler/i)) {
					$description_text = $description_text."\n".'[[Category:Statistics about immigration to Australia]]';
				    } elsif ($table_title =~ m/ arriv/i) {
					$description_text = $description_text."\n".'[[Category:Statistics about '.$period.'arrivals to '.$location.']]';
				    } elsif ($table_title =~ m/ depart/i) {
					$description_text = $description_text."\n".'[[Category:Statistics about '.$period.'departures from '.$location.']]';
				    } elsif ($alldata_string =~ m/ Migration/i) {
					$description_text = $description_text."\n".'[[Category:Statistics about migration in '.$location.']]';
				    }

				    #balance of payments and international investment position
				    if ($catalogue_title =~ m/Balance of Payments/i) {
					if ($table_title =~ m/International Investment/i) {
					    $description_text = $description_text."\n".'[[Category:Statistics about international investments of '.$location.']]';
					} elsif ($table_title =~ m/Merchandise exports/i) {
					    $description_text = $description_text."\n".'[[Category:Statistics about merchandise exports of '.$location.']]';
					} elsif ($table_title =~ m/Income/i) {
					    $description_text = $description_text."\n".'[[Category:Statistics about international income of '.$location.']]';
					} elsif ($table_title =~ m/Financial Account/i) {
					    $description_text = $description_text."\n".'[[Category:Statistics about the Financial Account of '.$location.']]';
					} elsif ($table_title =~ m/Foreign Debt/i) {
					    $description_text = $description_text."\n".'[[Category:Statistics about the foreign debt of '.$location.']]';
					} elsif ($table_title =~ m/Foreign Assets/i) {
					    $description_text = $description_text."\n".'[[Category:Statistics about the foreign assets of '.$location.']]';
					} elsif ($table_title =~ m/Foreign Liabilities/i) {
					    $description_text = $description_text."\n".'[[Category:Statistics about the foreign liabilities of '.$location.']]';
					} else {
					    $description_text = $description_text."\n".'[[Category:Statistics about the Balance of Payments and International Investment Position of Australia]]';
					}

					if ($alldata_string =~ m/Services/i) {
					    $description_text = $description_text."\n".'[[Category:Statistics about services in the Balance of Payments of '.$location.']]';
					}
					if ($alldata_string =~ m/Goods/i) {
					    $description_text = $description_text."\n".'[[Category:Statistics about goods in the Balance of Payments of '.$location.']]';
					}
				    } else {
					if ($alldata_string =~ m/Export/i) {
					    if ($alldata_string =~ m/Export price index/i) {
						$description_text = $description_text."\n".'[[Category:Statistics about the export price index of '.$location.']]';
					    } else {
						$description_text = $description_text."\n".'[[Category:Statistics about exports of '.$location.']]';
					    }
					}
				    }
				    if ($alldata_string =~ m/Import/i) {
					if ($alldata_string =~ m/Import price index/i) {
					    $description_text = $description_text."\n".'[[Category:Statistics about the import price index of '.$location.']]';
					} else {
					    $description_text = $description_text."\n".'[[Category:Statistics about imports in '.$location.']]';
					}
				    }
				    
				    if (($alldata_string =~ m/International Trade/i)&&(!(($alldata_string =~ m/Export/i)||($alldata_string =~ m/Import/i)))) {
					$description_text = $description_text."\n".'[[Category:Statistics about international trade of '.$location.']]';
				    }
				    

				    #national accounts
				    if ($alldata_string =~ m/State Accounts/i) {
					$description_text = $description_text."\n".'[[Category:Statistics about the State Accounts of '.$location.']]';
				    }
				    if ($table_title =~ m/National Accounts/i) {
					$description_text = $description_text."\n".'[[Category:Statistics about the National Accounts of Australia]]';
				    }
				    if ($table_title =~ m/Financial Accounts/i) {
					if ($alldata_string =~ m/Credit Market Outstanding/i) {
					    $description_text = $description_text."\n".'[[Category:Statistics about the credit market outstanding in the Financial Account of Australia]]';
					} elsif ($alldata_string =~ m/Demand for credit/i) {
					    $description_text = $description_text."\n".'[[Category:Statistics about the demand for credit in the Financial Account of Australia]]';
					} elsif ($alldata_string =~ m/Financial Assets and Liabilities/i) {
					    $description_text = $description_text."\n".'[[Category:Statistics about financial assets and liabilities in the Financial Account of Australia]]';
					} elsif ($alldata_string =~ m/Transferable deposits market/i) {
					    $description_text = $description_text."\n".'[[Category:Statistics about the transferable deposits market in the Financial Account of Australia]]';
					} elsif ($alldata_string =~ m/One name paper market/i) {
					    $description_text = $description_text."\n".'[[Category:Statistics about the one name paper market in the Financial Account of Australia]]';
					} elsif ($alldata_string =~ m/Long term placements market/i) {
					    $description_text = $description_text."\n".'[[Category:Statistics about the long term placements market in the Financial Account of Australia]]';
					} elsif ($alldata_string =~ m/ Listed Shares and Other Equity market/i) {
					    $description_text = $description_text."\n".'[[Category:Statistics about the listed shares and other equity market in the Financial Account of Australia]]';
					} elsif ($alldata_string =~ m/Unlisted Shares and Other Equity market/i) {
					    $description_text = $description_text."\n".'[[Category:Statistics about the listed shares and other equity market in the Financial Account of Australia]]';
					} elsif ($alldata_string =~ m/Accounts payable/i) {
					    $description_text = $description_text."\n".'[[Category:Statistics about the accounts payable in the Financial Account of Australia]]';
					} elsif ($alldata_string =~ m/Bonds market/i) {
					    $description_text = $description_text."\n".'[[Category:Statistics about the bonds market in the Financial Account of Australia]]';
					} else {
					    $description_text = $description_text."\n".'[[Category:Statistics about the Financial Account of Australia]]';
					}
				    }
				    if (($alldata_string =~ m/Gross Domestic Product/i)||($alldata_string =~ m/ GDP /i)) {
					$description_text = $description_text."\n".'[[Category:Statistics about the Gross Domestic Product of '.$location.']]';
				    }
				    if ($alldata_string =~ m/Consumption/i) {
					$description_text = $description_text."\n".'[[Category:Statistics about consumption in '.$location.']]';
				    }
				    if ($alldata_string =~ m/mortgage/i) {
					$description_text = $description_text."\n".'[[Category:Statistics about mortgages in '.$location.']]';
				    }
				    if ($alldata_string =~ m/ cash /i) {
					$description_text = $description_text."\n".'[[Category:Statistics about cash in '.$location.']]';
				    }
				    if ($alldata_string =~ m/long term securities/i) {
					$description_text = $description_text."\n".'[[Category:Statistics about long term securities in '.$location.']]';
				    }
				    if ($alldata_string =~ m/short term securities/i) {
					$description_text = $description_text."\n".'[[Category:Statistics about short term securities in '.$location.']]';
				    }
				    if ($alldata_string =~ m/credit card/i) {
					$description_text = $description_text."\n".'[[Category:Statistics about credit cards in '.$location.']]';
				    }
				    if ($alldata_string =~ m/Inventory/i) {
					$description_text = $description_text."\n".'[[Category:Statistics about inventories in '.$location.']]';
				    }
				    if ($table_title =~ m/National Income Account/i) {
					$description_text = $description_text."\n".'[[Category:Statistics about the National Income Account of Australia]]';
				    }
				    if ($table_title =~ m/National Capital Account/i) {
					$description_text = $description_text."\n".'[[Category:Statistics about the National Capital Account of Australia]]';
				    }
				    if ($table_title =~ m/External Account/i) {
					$description_text = $description_text."\n".'[[Category:Statistics about the External Account of Australia]]';
				    }
				    if ($table_title =~ m/Household Income Account/i) {
					$description_text = $description_text."\n".'[[Category:Statistics about the Household Income Account of Australia]]';
				    }
				    if ($table_title =~ m/General Government Income Account/i) {
					$description_text = $description_text."\n".'[[Category:Statistics about the General Government Income Account of Australia]]';
				    }
				    if ($alldata_string =~ m/Taxes/i) {
					$description_text = $description_text."\n".'[[Category:Statistics about taxes in '.$location.']]';
				    }
				    if ($alldata_string =~ m/Social Assistance/i) {
					$description_text = $description_text."\n".'[[Category:Statistics about social assistance in '.$location.']]';
				    }
				    if ($alldata_string =~ m/State Final Demand/i) {
					$description_text = $description_text."\n".'[[Category:Statistics about the state final demand in '.$location.']]';
				    }
				    if (($alldata_string =~ m/ wage[s ]/i)||($alldata_string =~ m/ salar[yi]/i)) {
					$description_text = $description_text."\n".'[[Category:Statistics about wages in '.$location.']]';
				    }
				    if ($alldata_string =~ m/ Labour cost/i) {
					$description_text = $description_text."\n".'[[Category:Statistics about labour costs in '.$location.']]';
				    }
				    if ($alldata_string =~ m/ Industrial Production/i) {
					$description_text = $description_text."\n".'[[Category:Statistics about industrial production in '.$location.']]';
				    }
				    if ($alldata_string =~ m/Capital Expenditure/i) {
					if ($alldata_string =~ m/Private/i) {
					    $description_text = $description_text."\n".'[[Category:Statistics about private capital expenditure in '.$location.']]';
					} else {
					    $description_text = $description_text."\n".'[[Category:Statistics about capital expenditure in '.$location.']]';
					}
				    }


				    if ($alldata_string =~ m/Profit/i) {
					if ($alldata_string =~ m/Company/i) {
					    $description_text = $description_text."\n".'[[Category:Statistics about company profits in '.$location.']]';
					} elsif ($alldata_string =~ m/business/i) {
					    $description_text = $description_text."\n".'[[Category:Statistics about business profits in '.$location.']]';
					} elsif ($alldata_string =~ m/unincorporated/i) {
					    $description_text = $description_text."\n".'[[Category:Statistics about unincorporated profits in '.$location.']]';
					} else {
					    $description_text = $description_text."\n".'[[Category:Statistics about profits in '.$location.']]';
					}
				    }
				    if (($alldata_string =~ m/Income/i)&&($alldata_string =~ m/Sales/i)) {
					$description_text = $description_text."\n".'[[Category:Statistics about sales income in '.$location.']]';
				    }

				    
				    if ($alldata_string =~ m/Industrial disputes/i) {
					$description_text = $description_text."\n".'[[Category:Statistics about industrial disputes in '.$location.']]';
				    }
				    if ($alldata_string =~ m/Job vacancies/i) {
					$description_text = $description_text."\n".'[[Category:Statistics about job vacancies in '.$location.']]';
				    }

				    if ($alldata_string =~ m/Participation rate/i) {
					$description_text = $description_text."\n".'[[Category:Statistics about the labour participation rate in '.$location.']]';
				    }
				    if ($alldata_string =~ m/Labour force/i) {
					$description_text = $description_text."\n".'[[Category:Statistics about the labour force in '.$location.']]';
				    }

				    if (($alldata_string =~ m/Unemployment/i)||($alldata_string =~ m/Unemployed/i)) {
					if ($sex=~ m/male/i) {
					    $description_text = $description_text."\n".'[[Category:Statistics about '.$sex.' unemployment in '.$location.']]';
					} else {
					    $description_text = $description_text."\n".'[[Category:Statistics about unemployment in '.$location.']]';
					}					
					if (($alldata_string =~ m/Full time/i)||($alldata_string =~ m/Full-time/i)) {
					    $description_text = $description_text."\n".'[[Category:Statistics about the unemployed looking for full-time work in '.$location.']]';
					}
					if (($alldata_string =~ m/part time/i)||($alldata_string =~ m/part-time/i)) {
					    $description_text = $description_text."\n".'[[Category:Statistics about the unemployed looking for full-time work in '.$location.']]';
					}
				    } elsif (($alldata_string =~ m/Employment/i)||($alldata_string =~ m/Employed/i)) {
					if ($sex=~ m/male/i) {
					    $description_text = $description_text."\n".'[[Category:Statistics about '.$sex.' employment in '.$location.']]';
					} else {
					    $description_text = $description_text."\n".'[[Category:Statistics about employment in '.$location.']]';
					}
					if (($alldata_string =~ m/Full time/i)||($alldata_string =~ m/Full-time/i)) {
					    $description_text = $description_text."\n".'[[Category:Statistics about full-time employment in '.$location.']]';
					}
					if (($alldata_string =~ m/part time/i)||($alldata_string =~ m/part-time/i)) {
					    $description_text = $description_text."\n".'[[Category:Statistics about part-time employment in '.$location.']]';
					}
      
				    }


				    #demography
				    if ($alldata_string =~ m/Population projection/i) {
					$description_text = $description_text."\n".'[[Category:Population projections of '.$location.']]';
				    } elsif ($alldata_string =~ m/Population/i) {
					$description_text = $description_text."\n".'[[Category:Temporal population graphs of '.$location.']]';
				    }
				    

				    $description_text = $description_text.'"'; #close double quotes around entire description
				    
				    
				    #$description_text =~ s/\\/\\\\/g; #  \ symbols need to be \\ so the upload script parameters don't get subst
				    $description_text =~ s/\$/\\\$/g; #  $ symbols need to be \$ so the upload script parameters don't get subst
				    $description_text =~ s/\`/\\\`/g; #  ` symbols need to be \` so the upload script parameters don't get subst
				    
				    
				    print DESCRIPTIONS 'python ../../../pywikipedia/upload.py -keep ';
				    print DESCRIPTIONS '-noverify ';
				    print DESCRIPTIONS $filename_stem.'.svg ';
				    print DESCRIPTIONS $description_text."\n";

				    print REUPLOAD 'python ../../../pywikipedia/reupload_tsh.py -keep ';
				    print REUPLOAD '-noverify ';
				    print REUPLOAD $filename_stem.'.svg ';
				    if ($nonzero==4) {
					print REUPLOAD $description_text."\n";
				    } else { 
					print REUPLOAD '"update"'."\n";
				    }

				    # if it was the first upload and only got the text "update" ... replace that with the proper description
				    print REUPLOAD 'python ../../../pywikipedia/replace.py -always -regex -page:File:';
				    print REUPLOAD $filename_stem.'.svg ';
				    print REUPLOAD '"update$" ';
				    print REUPLOAD $description_text."\n";
				    
				}
			    }
			    
			    $col_final = $col_max
			}
		}
	}
}
#close (PLOTBATCH);
close (DESCRIPTIONS);
close (FILENAMES);
close (DUPLICATES);
