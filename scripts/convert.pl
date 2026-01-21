#!/usr/bin/perl
#===============================================================================
#
#         FILE: convert.pl
#
#        USAGE: ./convert.pl [input_file] > taqweem.dat
#                ./convert.pl                    # uses taqweem.txt by default
#
#  DESCRIPTION: Converts prayer times from text format to encoded DAT format.
#               Input: Text file with month headers and space-separated times
#               Output: CSV with encoded date and time values (minutes)
#
#       AUTHOR: Osama Al Assiry
#      CREATED: 2016-01-27
#     REVISION: 2.0 - Added error handling and validation
#
#===============================================================================

use strict;
use warnings;

# Configuration
my @MONTHS = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);
my %MONTH_MAP = map { $MONTHS[$_] => $_ + 1 } 0..$#MONTHS;

# Parse command line arguments
my $input_file = shift @ARGV // 'taqweem.txt';

# Validate input file exists
die "Error: Input file '$input_file' not found\n" unless -f $input_file;

# Open input file
open my $fh, '<', $input_file
    or die "Error: Cannot open '$input_file': $!\n";

my $month = 0;
my $day = 0;
my $line_num = 0;
my $entry_count = 0;

while (my $line = <$fh>) {
    $line_num++;
    chomp $line;

    # Skip empty lines
    next if $line =~ /^\s*$/;

    # Check for month header
    if (exists $MONTH_MAP{$line}) {
        $month = $MONTH_MAP{$line};
        $day = 1;
        next;
    }

    # Process data lines (start with digit)
    next unless $line =~ /^\d/;

    # Validate we have a month set
    die "Error: Data found before month header at line $line_num\n"
        unless $month > 0;

    # Split into time components
    my @parts = split /\s+/, $line;

    # Validate we have exactly 12 values (6 times × 2 components)
    if (@parts != 12) {
        die "Error: Expected 12 values at line $line_num, got " .
            scalar(@parts) . ": $line\n";
    }

    # Validate all parts are numeric
    for my $i (0..$#parts) {
        die "Error: Non-numeric value '$parts[$i]' at line $line_num\n"
            unless $parts[$i] =~ /^\d+$/;
    }

    # Convert times to minutes since midnight
    # Input order: Isha, Maghrib, Asr, Dhuhr, Sunrise, Fajr (PM times need +12)
    my @times;
    for my $i (0..5) {
        my $hours = $parts[$i * 2];
        my $minutes = $parts[$i * 2 + 1];

        # Add 12 hours to PM times (Isha, Asr, Dhuhr are PM)
        $hours += 12 if $i == 0 || $i == 2 || $i == 3;

        # Validate time ranges
        die "Error: Invalid hours '$hours' at line $line_num\n"
            unless $hours >= 0 && $hours < 24;
        die "Error: Invalid minutes '$minutes' at line $line_num\n"
            unless $minutes >= 0 && $minutes < 60;

        $times[$i] = $hours * 60 + $minutes;
    }

    # Reverse order: Fajr, Sunrise, Dhuhr, Asr, Maghrib, Isha
    @times = reverse @times;

    # Encode date: (day-1) + (month-1) * 31
    my $encoded_date = ($day - 1) + ($month - 1) * 31;

    # Output encoded line
    print "$encoded_date," . join(',', @times) . "\n";

    $day++;
    $entry_count++;
}

close $fh;

# Validate we processed expected number of entries
if ($entry_count != 365) {
    warn "Warning: Expected 365 entries, processed $entry_count\n";
}

exit 0;
