#!/usr/bin/perl
#===============================================================================
#
#         FILE: json_export.pl
#
#        USAGE: ./json_export.pl [options] > taqweem.json
#
#      OPTIONS: --input FILE    Input CSV file (default: ../taqweem.csv)
#               --pretty        Pretty-print JSON output
#               --compact       Compact JSON output (default)
#
#  DESCRIPTION: Exports prayer times data to JSON format.
#               Reads from CSV and outputs structured JSON.
#
#       AUTHOR: Osama Al Assiry
#      CREATED: 2025-01-21
#
#===============================================================================

use strict;
use warnings;
use Getopt::Long;

# Configuration
# CSV order is reverse: isha, maghrib, asr, dhuhr, sunrise, fajr
my @CSV_ORDER = qw(isha maghrib asr dhuhr sunrise fajr);
# Output in chronological order
my @PRAYER_NAMES = qw(fajr sunrise dhuhr asr maghrib isha);
my @PRAYER_ARABIC = ('الفجر', 'الشروق', 'الظهر', 'العصر', 'المغرب', 'العشاء');

# Parse command line options
my $input_file = '../taqweem.csv';
my $pretty = 0;

GetOptions(
    'input=s' => \$input_file,
    'pretty'  => \$pretty,
    'compact' => sub { $pretty = 0 },
) or die "Error: Invalid options\n";

# Validate input file
die "Error: Input file '$input_file' not found\n" unless -f $input_file;

#-------------------------------------------------------------------------------
# Helper functions
#-------------------------------------------------------------------------------

sub json_string {
    my ($str) = @_;
    $str =~ s/\\/\\\\/g;
    $str =~ s/"/\\"/g;
    return "\"$str\"";
}

sub indent {
    my ($level) = @_;
    return $pretty ? ("  " x $level) : "";
}

sub newline {
    return $pretty ? "\n" : "";
}

#-------------------------------------------------------------------------------
# Process data
#-------------------------------------------------------------------------------

open my $fh, '<', $input_file
    or die "Error: Cannot open '$input_file': $!\n";

my @entries;
my $line_num = 0;

while (my $line = <$fh>) {
    $line_num++;
    chomp $line;
    next if $line =~ /^\s*$/;

    my @fields = split /,/, $line;

    if (@fields != 7) {
        warn "Warning: Invalid line format at line $line_num, skipping\n";
        next;
    }

    my ($date, @times) = @fields;

    # Parse date
    my ($day, $month) = split /\//, $date;

    # Build entry
    my %entry = (
        date => $date,
        day => int($day),
        month => int($month),
    );

    # Map CSV order (reverse) to prayer names
    for my $i (0..5) {
        $entry{prayers}{$CSV_ORDER[$i]} = $times[$i];
    }

    push @entries, \%entry;
}

close $fh;

#-------------------------------------------------------------------------------
# Generate JSON output
#-------------------------------------------------------------------------------

print "{" . newline();
print indent(1) . json_string("metadata") . ":{" . newline();
print indent(2) . json_string("source") . ":" . json_string("Qatar Calendar House (Dar Al-Taqweem Al-Qatri)") . "," . newline();
print indent(2) . json_string("url") . ":" . json_string("http://www.qatarch.com/") . "," . newline();
print indent(2) . json_string("timezone") . ":" . json_string("Asia/Qatar") . "," . newline();
print indent(2) . json_string("utc_offset") . ":" . json_string("+03:00") . "," . newline();
print indent(2) . json_string("total_days") . ":" . scalar(@entries) . "," . newline();
print indent(2) . json_string("prayers") . ":[" . newline();

for my $i (0..5) {
    my $comma = ($i < 5) ? "," : "";
    print indent(3) . "{" . json_string("id") . ":" . json_string($PRAYER_NAMES[$i]) . ",";
    print json_string("name_ar") . ":" . json_string($PRAYER_ARABIC[$i]) . "}$comma" . newline();
}

print indent(2) . "]" . newline();
print indent(1) . "}," . newline();

print indent(1) . json_string("days") . ":[" . newline();

for my $i (0..$#entries) {
    my $entry = $entries[$i];
    my $comma = ($i < $#entries) ? "," : "";

    print indent(2) . "{" . newline();
    print indent(3) . json_string("date") . ":" . json_string($entry->{date}) . "," . newline();
    print indent(3) . json_string("day") . ":" . $entry->{day} . "," . newline();
    print indent(3) . json_string("month") . ":" . $entry->{month} . "," . newline();
    print indent(3) . json_string("prayers") . ":{" . newline();

    for my $j (0..5) {
        my $prayer = $PRAYER_NAMES[$j];
        my $time = $entry->{prayers}{$prayer};
        my $pcomma = ($j < 5) ? "," : "";
        print indent(4) . json_string($prayer) . ":" . json_string($time) . $pcomma . newline();
    }

    print indent(3) . "}" . newline();
    print indent(2) . "}$comma" . newline();
}

print indent(1) . "]" . newline();
print "}" . newline();

warn "Exported " . scalar(@entries) . " days to JSON\n";

exit 0;
