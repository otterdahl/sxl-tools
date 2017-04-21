#!/usr/bin/perl -w
# sxlcheck.pl [SXL in xlsx-format]
# Outputs basic SXL information
# Requires Spreadsheet::XLSX (sudo apt-get install libspreadsheet-xlsx-perl)

# TODO: Test for spaces before or after
# TODO: Test for incorrect cId matches between single and grouped objects
# TODO: Sheet 'Object types'
# TODO: Sheet 'Aggregated status'

use strict;
use Spreadsheet::XLSX;
use Getopt::Long;

my @files = @ARGV;
my $fname;
my $sheet;

foreach $fname (@files) {
	read_sxl($fname);
}

sub read_sxl {
	my $fname = shift;
	my $workbook = Spreadsheet::XLSX->new($fname);
	foreach $sheet (@{$workbook->{Worksheet}}) {
		if($sheet->{Name} eq "Version") {
			print_version($sheet);
		} elsif($sheet->{Name} eq "Object types") {
			# STUB
		} elsif($sheet->{Name} eq "Aggregated status") {
			# STUB
		} elsif($sheet->{Name} eq "Alarms") {
			print_alarms($sheet);
		} elsif($sheet->{Name} eq "Status") {
			print_status($sheet);
		} elsif($sheet->{Name} eq "Commands") {
			print_commands($sheet);
		} else { # Objects
			print_objects($sheet);
		}
	}
}

sub print_version {
	my $sheet = shift;
	printf("# Signal Exchange List\n");

	cprint($sheet, 3, 1, "Plant Id");
	cprint($sheet, 5, 1, "Plant Name");
	cprint($sheet, 9, 1, "Constructor");
	cprint($sheet, 11,1, "Reviewed");
	cprint($sheet, 14,1, "Approved");
	cprint($sheet, 17,1, "Created date");
	cprint($sheet, 20,1, "SXL revision");
	cprint($sheet, 20,2, "Revision date");
	cprint($sheet, 25,1, "RSMP version");
}

sub print_alarms {
	my $sheet = shift;
	printf("\n# Alarms\n");
	
	my $noReturnValues = get_no_return_values($sheet, 6);

	# Print header
	my $i;
	printf "| ObjectType | Object (optional) | alarmCodeId | Description | externalAlarmCodeId | externalNtsAlarmCodeId | Priority | Category |";
	for($i=0; $i<$noReturnValues; $i++) {
		printf "|Name|Type|Value|Comment|";
	}
	print "\n";
	printf "| ---------- | ----------------- |:-----------:| ----------- | ------------------- | ---------------------- |:--------:|:--------:|";
	for($i=0; $i<$noReturnValues; $i++) {
		printf "|----|----|-----|-------|";
	}
	print "\n";

	# Print alarms
	my $y = 6;
	while (test($sheet, $y, 7)) {
		aprint($sheet, $y, 8, 4, 2);
		$y++;
	}
}

sub print_status {
	my $sheet = shift;
	printf("\n# Status\n");

	my $noReturnValues = get_no_return_values($sheet, 6);

	# Print header
	my $i;
	printf "| ObjectType | Object (optional) | statusCodeId | Description |";
	for($i=0; $i<$noReturnValues; $i++) {
		printf "|Name|Type|Value|Comment|";
	}
	print "\n";
	printf "| ---------- | ----------------- |:-----------:| ----------- |";
	for($i=0; $i<$noReturnValues; $i++) {
		printf "|----|----|-----|-------|";
	}
	print "\n";
	
	# Print status
	my $y = 6;
	while (test($sheet, $y, 7)) {
		aprint($sheet, $y, 4, 4, 2);
		$y++;
	}
}

sub print_commands {
	my $sheet = shift;
	printf("\n# Commands\n");

	my $sec;
	my $y;
	my @sections = command_section($sheet);

	# Find max number of return values in each section
	my $noReturnValues = 0;
	foreach $sec (@sections) {
		$y = $sec;
		if(get_no_return_values($sheet, $y) > $noReturnValues) {
			$noReturnValues = get_no_return_values($sheet, $y);
		}
	}

	# Print header
	my $i;
	printf "| ObjectType | Object (optional) | commandCodeId | Description |";
	for($i=0; $i<$noReturnValues; $i++) {
		printf "|Name|Command|Type|Value|Comment|";
	}
	print "\n";
	printf "| ---------- | ----------------- |:-----------:| ----------- |";
	for($i=0; $i<$noReturnValues; $i++) {
		printf "|----|----|----|------|-------|";
	}
	print "\n";

	foreach $sec (@sections) {
		# Need to check each command section
		$y = $sec;

		# Print command
		while (test($sheet, $y, 7)) {
			aprint($sheet, $y, 4, 5, 3);
			$y++;
		}
	}
	print "\n";
}

sub print_objects {
	my $sheet = shift;
	# Object sheet
	printf("\nObjects\n");
	printf("=======\n");
	cprint($sheet, 1,1, "SiteId:");
	cprint($sheet, 1,2, "Description:");

	# Print all grouped objects
	printf "\nGrouped objects\n";
	printf "---------------\n";
	printf "|ObjectType|Object|componentId|NTSObjectId|externalNtsId|Description|\n";
	printf "|----------|------|-----------|-----------|-------------|-----------|\n";
	my $y = 6;
	while (test($sheet, $y, 0)) {
		oprint($sheet, $y);
		$y++;
	}

	# Print all single objects
	printf "\nSingle objects\n";
	printf "--------------\n";
	printf "|ObjectType|Object|componentId|NTSObjectId|externalNtsId|Description|\n";
	printf "|----------|------|-----------|-----------|-------------|-----------|\n";
	$y = 24;
	while (test($sheet, $y, 0)) {
		oprint($sheet, $y);
		$y++;
	}
}

# Cell print
sub cprint {
	my $sheet = shift;
	my $y = shift;
	my $x = shift;
	my $text = shift;
	my $val = $sheet->{Cells}[$y][$x]->{Val};

	unless(defined($val)) {
		# Warning: value not defined"
		$val = " ";
	}
        $val =~ s/%/%%/g; # Needed for printf()
	printf "**$text**: $val  \n";
}

# Print object
sub oprint {
	my $sheet = shift;
	my $y = shift;

	# Object, componentId, NTSObjectId
	my $object = $sheet->{Cells}[$y][1]->{Val};
	my $cId = $sheet->{Cells}[$y][2]->{Val};
	my $ntsoId = $sheet->{Cells}[$y][3]->{Val};
	my $externalNtsId = $sheet->{Cells}[$y][4]->{Val};

	unless (defined($object) and defined($cId) and defined($ntsoId)) {
		print STDERR "WARNING: row $y incomplete\n";
	} else {
		printf "|$object|$cId|$ntsoId|\n";
	}
}

# Print alarm/status/commands
sub aprint {
	my $sheet = shift;
	my $y = shift;  # Start row
	my $col_length = shift; # 8 for alarms, 4 for status and commands
	my $return_value_col_length = shift; # 4 for alarm and status, 5 for commands
	my $value_list_col = shift; # this column of return values/arguments should be split into bullet list, 2 for alarm and status, 3 for commands

	# Get values for a row
	my $i;
	my $x = 0;
	my @val;
	for($i = 0; $i < $col_length; $i++) {
		$val[$i] = $sheet->{Cells}[$y][$x++]->{Val};

		unless(defined($val[$i])) {
			$val[$i] = "";
		}
	}

	# Print row
	print "|";
	for($i = 0; $i < $col_length; $i++) {
		$val[$i] =~ s/\r//g;
		$val[$i] =~ s/\n/<br>/g;
		print "$val[$i]|";
	}

	# return values
	while(test($sheet, $y, $x)) {
		# Get values for a row
		$col_length = $return_value_col_length;
		for($i = 0; $i < $col_length; $i++) {
			$val[$i] = $sheet->{Cells}[$y][$x++]->{Val};
			unless(defined($val[$i])) {
				$val[$i] = "";
			}
		}

		# Check for semicolon in the "Comment" field, which is the last one
		semi_check($sheet, $x, $y);

		# Print row
		print "|";
		for($i = 0; $i < $col_length; $i++) {
			# 'Value' should be split into bullet list (HTML)
			$val[$i] =~ s/-//g;	# Remove '-'
			if($i == $value_list_col) {
				# Find line breaks and convert to them to bullet list in HTML
				if($val[$i] =~ /\r\n/) {
					$val[$i] =~ s/\r//g;
					my @list = split("\n", $val[$i]);
					my $v;
					$val[$i] = "<ul>";
					foreach $v (@list) {
						$val[$i] = $val[$i]."<li>$v</li>";
					}
					$val[$i] = $val[$i]."</ul>";
				}
			}
			else {
				# Remove line breaks
				$val[$i] =~ s/\r//g;
				$val[$i] =~ s/\n/<br>/g;
			}
			print "$val[$i]|";
		}
	}
	print "\n";
}

# Find command section
# Return a list of y-positions for the start of each section
sub command_section {
	my $sheet = shift;
	my $y = 4; # Section won't start before row 4
	my @list;
	my $text;
	while ($y<100) {
		$text = "";
		$text = $sheet->{Cells}[$y][0]->{Val} if(test($sheet, $y, 0));

		# We're adding +2 because that's where the actual command starts
		if($text =~ /Functional position/) {
			push @list, $y+2;
		} elsif( $text =~ /Functional state/) {
			push @list, $y+2;
		} elsif($text =~ /Manouver/) {
			push @list, $y+2;
		} elsif($text =~ /Parameter/) {
			push @list, $y+2;
			return @list;
		} else {
		}
		$y++;
	}
	print "Error: did not find all command sections\n";
	return;
}

# Semicolon check
sub semi_check {
	my $sheet = shift;
	my $x = shift;
	my $y = shift;
	my $comment = $sheet->{Cells}[$y][$x]->{Val};
	if(defined($comment)) {
		printf STDERR "WARNING: Found semicolon in comment field: $comment\n" if ($comment =~ /;/);
	}
}

# Test for contens if the first column
sub test {
	my $sheet = shift;
	my $y = shift;
	my $x = shift;
	return defined($sheet->{Cells}[$y][$x]->{Val});
}

# Get max number of arguments/return values
sub get_no_return_values {
	my $sheet = shift;
	my $y = shift; # start row, alarms, status: 6, commands: variable

	my $noReturnValues = 0;
	my $x = 8; # first return value
	while (test($sheet, $y, 7)) {
		while(test($sheet, $y, $x)) {
			$noReturnValues++;
			$x += 4;
		}
		$y++
	}
	return $noReturnValues;
}
