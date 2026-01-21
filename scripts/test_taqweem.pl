#!/usr/bin/perl
#===============================================================================
#
#         FILE: test_taqweem.pl
#
#        USAGE: ./test_taqweem.pl
#               perl test_taqweem.pl
#
#  DESCRIPTION: Test suite for TaqweemQatar data validation.
#               Validates CSV format, data completeness, and time ranges.
#
#       AUTHOR: Osama Al Assiry
#      CREATED: 2025-01-21
#
#===============================================================================

use strict;
use warnings;
use File::Basename;

# Configuration
my $script_dir = dirname(__FILE__);
my $csv_file = "$script_dir/../taqweem.csv";
my $dat_file = "$script_dir/../taqweem.dat";

# Test counters
my $tests_run = 0;
my $tests_passed = 0;
my $tests_failed = 0;

#-------------------------------------------------------------------------------
# Test helpers
#-------------------------------------------------------------------------------

sub ok {
    my ($condition, $name) = @_;
    $tests_run++;

    if ($condition) {
        print "ok $tests_run - $name\n";
        $tests_passed++;
        return 1;
    } else {
        print "not ok $tests_run - $name\n";
        $tests_failed++;
        return 0;
    }
}

sub is {
    my ($got, $expected, $name) = @_;
    my $pass = defined $got && defined $expected && $got eq $expected;

    if (!$pass) {
        print "# Expected: $expected\n" if defined $expected;
        print "# Got: $got\n" if defined $got;
    }

    return ok($pass, $name);
}

sub like {
    my ($got, $pattern, $name) = @_;
    my $pass = defined $got && $got =~ $pattern;

    if (!$pass) {
        print "# Pattern: $pattern\n";
        print "# Got: $got\n" if defined $got;
    }

    return ok($pass, $name);
}

#-------------------------------------------------------------------------------
# Tests
#-------------------------------------------------------------------------------

print "# TaqweemQatar Test Suite\n";
print "# ======================\n\n";

# Test 1: CSV file exists
ok(-f $csv_file, "CSV file exists: $csv_file");

# Test 2: Read CSV file
my @csv_lines;
if (open my $fh, '<', $csv_file) {
    @csv_lines = <$fh>;
    close $fh;
    ok(1, "CSV file is readable");
} else {
    ok(0, "CSV file is readable");
}

# Test 3: CSV has 365 entries
is(scalar(@csv_lines), 365, "CSV has exactly 365 entries");

# Test 4-5: Validate each CSV line format
my $format_errors = 0;
my $time_errors = 0;
my %dates_seen;
my $duplicate_dates = 0;

for my $i (0..$#csv_lines) {
    my $line = $csv_lines[$i];
    chomp $line;

    my @fields = split /,/, $line;

    # Check field count
    if (@fields != 7) {
        $format_errors++;
        print "# Line " . ($i+1) . ": Expected 7 fields, got " . scalar(@fields) . "\n";
        next;
    }

    my ($date, @times) = @fields;

    # Check date format
    unless ($date =~ /^\d{1,2}\/\d{1,2}$/) {
        $format_errors++;
        print "# Line " . ($i+1) . ": Invalid date format: $date\n";
    }

    # Check for duplicate dates
    if ($dates_seen{$date}++) {
        $duplicate_dates++;
        print "# Line " . ($i+1) . ": Duplicate date: $date\n";
    }

    # Check time formats
    for my $time (@times) {
        unless ($time =~ /^\d{1,2}:\d{2}$/) {
            $time_errors++;
            print "# Line " . ($i+1) . ": Invalid time format: $time\n";
            next;
        }

        my ($h, $m) = split /:/, $time;
        if ($h < 0 || $h > 23 || $m < 0 || $m > 59) {
            $time_errors++;
            print "# Line " . ($i+1) . ": Time out of range: $time\n";
        }
    }
}

ok($format_errors == 0, "All lines have correct format ($format_errors errors)");
ok($time_errors == 0, "All times are valid ($time_errors errors)");
ok($duplicate_dates == 0, "No duplicate dates ($duplicate_dates duplicates)");

# Test 6: First entry is January 1
like($csv_lines[0], qr/^1\/1,/, "First entry is January 1");

# Test 7: Last entry is December 31
like($csv_lines[-1], qr/^31\/12,/, "Last entry is December 31");

# Test 8: Prayer times are in logical order
# CSV order is reverse: isha, maghrib, asr, dhuhr, sunrise, fajr
# Chronological: Fajr < Sunrise < Dhuhr < Asr < Maghrib < Isha
my $order_errors = 0;

for my $i (0..$#csv_lines) {
    my $line = $csv_lines[$i];
    chomp $line;

    my (undef, $isha, $maghrib, $asr, $dhuhr, $sunrise, $fajr) = split /,/, $line;

    # Convert to minutes for comparison
    my $fajr_m = _to_minutes($fajr);
    my $sunrise_m = _to_minutes($sunrise);
    my $dhuhr_m = _to_minutes($dhuhr);
    my $asr_m = _to_minutes($asr);
    my $maghrib_m = _to_minutes($maghrib);
    my $isha_m = _to_minutes($isha);

    # Sunrise should be after Fajr
    if ($sunrise_m <= $fajr_m) {
        $order_errors++;
        print "# Line " . ($i+1) . ": Sunrise ($sunrise) should be after Fajr ($fajr)\n"
            if $order_errors <= 3;
    }

    # Dhuhr should be after Sunrise
    if ($dhuhr_m <= $sunrise_m) {
        $order_errors++;
        print "# Line " . ($i+1) . ": Dhuhr ($dhuhr) should be after Sunrise ($sunrise)\n"
            if $order_errors <= 3;
    }

    # Asr should be after Dhuhr
    if ($asr_m <= $dhuhr_m) {
        $order_errors++;
        print "# Line " . ($i+1) . ": Asr ($asr) should be after Dhuhr ($dhuhr)\n"
            if $order_errors <= 3;
    }

    # Maghrib should be after Asr
    if ($maghrib_m <= $asr_m) {
        $order_errors++;
        print "# Line " . ($i+1) . ": Maghrib ($maghrib) should be after Asr ($asr)\n"
            if $order_errors <= 3;
    }

    # Isha should be after Maghrib
    if ($isha_m <= $maghrib_m) {
        $order_errors++;
        print "# Line " . ($i+1) . ": Isha ($isha) should be after Maghrib ($maghrib)\n"
            if $order_errors <= 3;
    }
}

ok($order_errors == 0, "Prayer times in chronological order ($order_errors errors)");

# Test 9: Check reasonable time ranges for Qatar
my $range_errors = 0;

for my $i (0..$#csv_lines) {
    my $line = $csv_lines[$i];
    chomp $line;

    # CSV order is reverse: isha, maghrib, asr, dhuhr, sunrise, fajr
    my (undef, $isha, $maghrib, $asr, $dhuhr, $sunrise, $fajr) = split /,/, $line;

    # Fajr should be between 3:10 and 5:30 AM (summer Fajr is early in Qatar)
    my $fajr_m = _to_minutes($fajr);
    if ($fajr_m < 190 || $fajr_m > 330) {  # 3:10 - 5:30
        $range_errors++;
        print "# Line " . ($i+1) . ": Fajr ($fajr) outside expected range (3:30-5:30)\n"
            if $range_errors <= 3;
    }

    # Dhuhr should be between 11:00 and 12:30
    my $dhuhr_m = _to_minutes($dhuhr);
    if ($dhuhr_m < 660 || $dhuhr_m > 750) {  # 11:00 - 12:30
        $range_errors++;
        print "# Line " . ($i+1) . ": Dhuhr ($dhuhr) outside expected range (11:00-12:30)\n"
            if $range_errors <= 3;
    }

    # Maghrib should be between 16:30 and 19:00 (winter sunset is early in Qatar)
    my $maghrib_m = _to_minutes($maghrib);
    if ($maghrib_m < 990 || $maghrib_m > 1140) {  # 16:30 - 19:00
        $range_errors++;
        print "# Line " . ($i+1) . ": Maghrib ($maghrib) outside expected range (17:00-19:00)\n"
            if $range_errors <= 3;
    }
}

ok($range_errors == 0, "Prayer times within expected ranges ($range_errors errors)");

# Test 10: DAT file exists (if generated)
if (-f $dat_file) {
    ok(1, "DAT file exists");

    # Check DAT has 365 entries
    open my $fh, '<', $dat_file;
    my @dat_lines = <$fh>;
    close $fh;

    is(scalar(@dat_lines), 365, "DAT has 365 entries");
} else {
    ok(1, "DAT file not generated yet (skip)");
    ok(1, "DAT entries check (skip)");
}

#-------------------------------------------------------------------------------
# Summary
#-------------------------------------------------------------------------------

print "\n# Summary\n";
print "# -------\n";
print "# Tests run: $tests_run\n";
print "# Passed: $tests_passed\n";
print "# Failed: $tests_failed\n";

exit($tests_failed > 0 ? 1 : 0);

#-------------------------------------------------------------------------------
# Helper functions
#-------------------------------------------------------------------------------

sub _to_minutes {
    my ($time) = @_;
    my ($h, $m) = split /:/, $time;
    return $h * 60 + $m;
}
