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
use File::Temp qw(tempfile);

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
        print "# Line " . ($i+1) . ": Fajr ($fajr) outside expected range (3:10-5:30)\n"
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
        print "# Line " . ($i+1) . ": Maghrib ($maghrib) outside expected range (16:30-19:00)\n"
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

    my (undef, $jan1_isha, $jan1_maghrib, $jan1_asr, $jan1_dhuhr) =
        split /,/, $csv_lines[0];
    my (undef, $dat_isha, $dat_maghrib, $dat_asr, $dat_dhuhr) =
        split /,/, $dat_lines[0];

    is($dat_isha, _to_minutes($jan1_isha), "DAT Jan 1 Isha matches CSV");
    is($dat_maghrib, _to_minutes($jan1_maghrib), "DAT Jan 1 Maghrib matches CSV");
    is($dat_asr, _to_minutes($jan1_asr), "DAT Jan 1 Asr matches CSV");
    is($dat_dhuhr, _to_minutes($jan1_dhuhr), "DAT Jan 1 Dhuhr matches CSV");

    # Check iCalendar leap-day events use Feb 28 times
    my @ical_lines;
    my $ical_cmd = "$^X $script_dir/ical.pl --input $dat_file --year 2028 2>/dev/null";
    if (open my $ical_fh, "$ical_cmd |") {
        @ical_lines = <$ical_fh>;
        close $ical_fh;
    }

    my %starts_by_summary;
    my $current_start;
    for my $line (@ical_lines) {
        chomp $line;
        if ($line =~ /^DTSTART;TZID=Asia\/Qatar:(\d{8}T\d{6})$/) {
            $current_start = $1;
        } elsif ($line =~ /^SUMMARY:(.+)$/ && defined $current_start) {
            push @{ $starts_by_summary{$1} }, $current_start;
            undef $current_start;
        }
    }

    my @feb29_starts = grep { /^20280229T/ }
        map { @$_ } values %starts_by_summary;
    is(scalar(@feb29_starts), 10, "ICS has 10 February 29 events for leap year 2028");

    my $leap_day_errors = 0;
    for my $summary (keys %starts_by_summary) {
        my %seen = map { $_ => 1 } @{ $starts_by_summary{$summary} };
        for my $start (grep { /^20280229T/ } @{ $starts_by_summary{$summary} }) {
            my $feb28_start = $start;
            $feb28_start =~ s/^20280229/20280228/;
            if (!$seen{$feb28_start}) {
                $leap_day_errors++;
                print "# Missing matching Feb 28 event for $summary at $start\n"
                    if $leap_day_errors <= 3;
            }
        }
    }

    ok($leap_day_errors == 0, "ICS February 29 events match February 28 times ($leap_day_errors errors)");
    my $feb29_rrules = 0;
    for my $event (split /BEGIN:VEVENT\n/, join('', @ical_lines)) {
        next unless $event =~ /^DTSTART;TZID=Asia\/Qatar:20280229T/m;
        $feb29_rrules++ if $event =~ /^RRULE:/m;
    }
    is($feb29_rrules, 0, "ICS February 29 fallback events are not yearly recurring");
    my %jan1_seen = map { $_ => 1 }
        map { @$_ } @starts_by_summary{'Athan Fajr', 'Athan Isha'};
    ok($jan1_seen{'20280101T045700'}, "ICS Jan 1 Athan Fajr matches CSV");
    ok($jan1_seen{'20280101T182700'}, "ICS Jan 1 Athan Isha matches CSV");
} else {
    ok(1, "DAT file not generated yet (skip)");
    ok(1, "DAT entries check (skip)");
    ok(1, "ICS February 29 event count check (skip)");
    ok(1, "ICS February 29 time match check (skip)");
    ok(1, "ICS February 29 RRULE check (skip)");
    ok(1, "ICS Jan 1 Athan Fajr check (skip)");
    ok(1, "ICS Jan 1 Athan Isha check (skip)");
}

# Test 11: expand.pl preserves a prayer exactly at midnight
my ($midnight_fh, $midnight_file) = tempfile(
    'expand-midnight-XXXX',
    DIR    => "$script_dir/..",
    UNLINK => 1,
);
print {$midnight_fh} "0,300,240,180,0,60,10\n";
close $midnight_fh;

my @midnight_output;
my $expand_status = 1;
if (open my $expand_fh, '-|', $^X, "$script_dir/expand.pl", '--input', $midnight_file) {
    @midnight_output = <$expand_fh>;
    $expand_status = close($expand_fh) ? 0 : ($? || 1);
}

ok($expand_status == 0, "expand.pl runs with synthetic midnight DAT input");
is(scalar(@midnight_output), 11, "expand.pl prints all athan events and non-sunrise prayer events");
like(join('', @midnight_output), qr/^1\/1,Dhuhr: Athan,00:00,00:02$/m,
    "expand.pl prints the midnight prayer");
like(join('', @midnight_output), qr/^1\/1,Isha: Athan,05:00,05:02$/m,
    "expand.pl continues after the midnight prayer");

# Test 12: convert.pl exits nonzero for incomplete input
my ($short_fh, $short_file) = tempfile(
    'convert-short-XXXX',
    DIR    => "$script_dir/..",
    UNLINK => 1,
);
print {$short_fh} "Jan\n6 27 4 57 2 36 11 37 6 20 4 57\n";
close $short_fh;

my $convert_output = "$short_file.dat";
my $convert_status = system("$^X '$script_dir/convert.pl' '$short_file' > '$convert_output' 2>/dev/null");
unlink $convert_output;
ok($convert_status != 0, "convert.pl exits nonzero for incomplete input");

# Test 13: json_export.pl escapes JSON control characters
my ($json_fh, $json_input) = tempfile(
    'json-control-XXXX',
    DIR    => "$script_dir/..",
    UNLINK => 1,
);
print {$json_fh} "1/1,18:27,16:57,14:36,11:37,6:20,4:57\t\n";
close $json_fh;

my $json_output = "$json_input.out";
my $json_status = system("$^X '$script_dir/json_export.pl' --input '$json_input' > '$json_output' 2>/dev/null");
my $json_decode_status = system("$^X -MJSON::PP -e 'local \$/; decode_json(<STDIN>)' < '$json_output' 2>/dev/null");
unlink $json_output;
ok($json_status == 0 && $json_decode_status == 0, "json_export.pl emits valid JSON for control characters");

# Test 14: json_export.pl skips non-numeric dates
my ($bad_date_fh, $bad_date_input) = tempfile(
    'json-bad-date-XXXX',
    DIR    => "$script_dir/..",
    UNLINK => 1,
);
print {$bad_date_fh} "abc/1,18:27,16:57,14:36,11:37,6:20,4:57\n";
close $bad_date_fh;

my $bad_date_output = "$bad_date_input.out";
my $bad_date_err = "$bad_date_input.err";
my $bad_date_status = system("$^X '$script_dir/json_export.pl' --input '$bad_date_input' > '$bad_date_output' 2> '$bad_date_err'");
open my $bad_date_out_fh, '<', $bad_date_output;
my $bad_date_json = do { local $/; <$bad_date_out_fh> };
close $bad_date_out_fh;
open my $bad_date_err_fh, '<', $bad_date_err;
my $bad_date_warning = do { local $/; <$bad_date_err_fh> };
close $bad_date_err_fh;
unlink $bad_date_output, $bad_date_err;
ok($bad_date_status == 0 && $bad_date_json !~ /"day":0/ && $bad_date_warning =~ /Invalid date/,
    "json_export.pl skips non-numeric date fields with a warning");

# Test 15: json_export.pl skips out-of-range numeric dates
my ($bad_date_range_fh, $bad_date_range_input) = tempfile(
    'json-bad-date-range-XXXX',
    DIR    => "$script_dir/..",
    UNLINK => 1,
);
print {$bad_date_range_fh} "99/88,18:27,16:57,14:36,11:37,6:20,4:57\n";
close $bad_date_range_fh;

my $bad_date_range_output = "$bad_date_range_input.out";
my $bad_date_range_err = "$bad_date_range_input.err";
my $bad_date_range_status = system("$^X '$script_dir/json_export.pl' --input '$bad_date_range_input' > '$bad_date_range_output' 2> '$bad_date_range_err'");
open my $bad_date_range_out_fh, '<', $bad_date_range_output;
my $bad_date_range_json = do { local $/; <$bad_date_range_out_fh> };
close $bad_date_range_out_fh;
open my $bad_date_range_err_fh, '<', $bad_date_range_err;
my $bad_date_range_warning = do { local $/; <$bad_date_range_err_fh> };
close $bad_date_range_err_fh;
unlink $bad_date_range_output, $bad_date_range_err;
ok($bad_date_range_status == 0 && $bad_date_range_json !~ /"day":99/ && $bad_date_range_json !~ /"month":88/ && $bad_date_range_warning =~ /Invalid date/,
    "json_export.pl skips out-of-range numeric date fields with a warning");

# Test 16: json_export.pl and ical.pl exit nonzero for malformed rows
my ($bad_json_fh, $bad_json_input) = tempfile(
    'json-bad-row-XXXX',
    DIR    => "$script_dir/..",
    UNLINK => 1,
);
print {$bad_json_fh} "1/1,18:27\n";
close $bad_json_fh;
my $bad_json_status = system("$^X '$script_dir/json_export.pl' --input '$bad_json_input' > /dev/null 2>/dev/null");
ok($bad_json_status != 0, "json_export.pl exits nonzero for malformed row field count");

my ($bad_ical_fh, $bad_ical_input) = tempfile(
    'ical-bad-row-XXXX',
    DIR    => "$script_dir/..",
    UNLINK => 1,
);
print {$bad_ical_fh} "0,1107\n";
close $bad_ical_fh;
my $bad_ical_status = system("$^X '$script_dir/ical.pl' --input '$bad_ical_input' > /dev/null 2>/dev/null");
ok($bad_ical_status != 0, "ical.pl exits nonzero for malformed row field count");

# Test 16: CLI scripts support --help
for my $script (qw(expand.pl ical.pl json_export.pl convert.pl)) {
    my $help_status = system("$^X '$script_dir/$script' --help > /dev/null 2>/dev/null");
    ok($help_status == 0, "$script --help exits 0");
}

# Test 17: ical.pl rolls late-night events to the next date
my ($late_fh, $late_input) = tempfile(
    'ical-late-XXXX',
    DIR    => "$script_dir/..",
    UNLINK => 1,
);
print {$late_fh} "0,0,0,0,0,0,1463\n";
close $late_fh;
my $late_output = `$^X '$script_dir/ical.pl' --input '$late_input' --year 2026 --no-prayer 2>/dev/null`;
like($late_output, qr/UID:athan-fajr-0101\@taqweem\.qa\nDTSTART;TZID=Asia\/Qatar:20260102T002300/,
    "ical.pl rolls minutes >= 1440 to the next date");

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
