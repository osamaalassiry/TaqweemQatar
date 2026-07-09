#!/usr/bin/perl
#===============================================================================
#
#         FILE: test_taqweem_module.pl
#
#        USAGE: ./test_taqweem_module.pl
#               perl test_taqweem_module.pl
#
#  DESCRIPTION: Unit tests for TaqweemQatar.pm public API.
#               Tests constructor, prayer time lookups, iqama calculations,
#               search capabilities, and error handling.
#
#       AUTHOR: Osama Al Assiry
#      CREATED: 2025-01-21
#
#===============================================================================

use strict;
use warnings;
use Cwd qw(getcwd);
use File::Basename;
use File::Temp qw(tempdir tempfile);

# Load the module under test
use lib dirname(__FILE__) . '/../lib';
use TaqweemQatar;

# Test counters
my $tests_run    = 0;
my $tests_passed = 0;
my $tests_failed = 0;

#-------------------------------------------------------------------------------
# Test helpers (same TAP-style pattern as test_taqweem.pl)
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

print "# TaqweemQatar Module Test Suite\n";
print "# ==============================\n\n";

#------------------------------------------------------------------------------
# Constructor tests
#------------------------------------------------------------------------------

print "### Constructor\n";

# Default constructor
my $tq;
eval { $tq = TaqweemQatar->new() };
ok(!$@ && defined $tq, "Default constructor succeeds");
ok(ref($tq) eq 'TaqweemQatar', "Object is a TaqweemQatar instance");

# Lazy loading
my $lazy;
eval { $lazy = TaqweemQatar->new(lazy => 1) };
ok(!$@ && defined $lazy, "Lazy constructor (lazy => 1) succeeds");

# Without lazy, data is loaded on construction
ok($tq->{_loaded}, "Default constructor loads data eagerly");

# With lazy, data is NOT loaded immediately
ok(!$lazy->{_loaded}, "Lazy constructor defers data loading");

# Data auto-loads on first query after lazy construction
my $lazy_times = $lazy->get_times(1, 1);
ok(defined $lazy_times, "Lazy instance loads data on first query");
ok($lazy->{_loaded}, "Lazy instance marks data as loaded after query");

my ($malformed_fh, $malformed_file) = tempfile(
    'taqweem-malformed-XXXX',
    DIR    => dirname(__FILE__) . '/..',
    UNLINK => 1,
);
print {$malformed_fh} "1/1,18:27,16:57,14:36,11:37,6:20,4:57\n";
print {$malformed_fh} "bad,row\n";
close $malformed_fh;

my $warning = '';
{
    local $SIG{__WARN__} = sub { $warning .= join('', @_); };
    my $malformed_tq = TaqweemQatar->new(data_file => $malformed_file);
    ok($malformed_tq->{_loaded}, "Constructor loads file with malformed rows");
}
like($warning, qr/skipping malformed line/, "Malformed rows produce a warning");

my $orig_cwd = getcwd();
my $decoy_dir = tempdir('taqweem-decoy-XXXX', TMPDIR => 1, CLEANUP => 1);
open my $decoy_fh, '>', "$decoy_dir/taqweem.csv"
    or die "Cannot create decoy CSV: $!";
print {$decoy_fh} "1/1,0:06,0:05,0:04,0:03,0:02,0:01\n";
close $decoy_fh;

my $decoy_tq;
eval {
    chdir $decoy_dir or die "Cannot chdir to decoy dir: $!";
    $decoy_tq = TaqweemQatar->new();
    1;
} or do {
    my $err = $@;
    chdir $orig_cwd;
    die $err;
};
chdir $orig_cwd or die "Cannot restore cwd: $!";
is($decoy_tq->get_prayer(1, 1, 'fajr'), "4:57", "Default constructor ignores CWD decoy taqweem.csv");

#------------------------------------------------------------------------------
# get_times tests
#------------------------------------------------------------------------------

print "\n### get_times\n";

# Known date: January 1 (1/1)
# CSV line: 1/1,18:27,16:57,14:36,11:37,6:20,4:57
# CSV order: date, isha, maghrib, asr, dhuhr, sunrise, fajr
my $jan1 = $tq->get_times(1, 1);
ok(defined $jan1, "get_times(1, 1) returns data");
is($jan1->{date}, "1/1", "Date key is 1/1");
is($jan1->{day}, 1, "Day field is 1");
is($jan1->{month}, 1, "Month field is 1");
is($jan1->{fajr},    "4:57", "Fajr on Jan 1 is 4:57");
is($jan1->{sunrise}, "6:20", "Sunrise on Jan 1 is 6:20");
is($jan1->{dhuhr},   "11:37", "Dhuhr on Jan 1 is 11:37");
is($jan1->{asr},     "14:36", "Asr on Jan 1 is 14:36");
is($jan1->{maghrib}, "16:57", "Maghrib on Jan 1 is 16:57");
is($jan1->{isha},    "18:27", "Isha on Jan 1 is 18:27");

# Known date: December 31 (31/12)
# CSV line: 31/12,18:26,16:56,14:35,11:37,6:19,4:56
my $dec31 = $tq->get_times(31, 12);
ok(defined $dec31, "get_times(31, 12) returns data");
is($dec31->{fajr},    "4:56", "Fajr on Dec 31 is 4:56");
is($dec31->{sunrise}, "6:19", "Sunrise on Dec 31 is 6:19");
is($dec31->{dhuhr},   "11:37", "Dhuhr on Dec 31 is 11:37");
is($dec31->{asr},     "14:35", "Asr on Dec 31 is 14:35");
is($dec31->{maghrib}, "16:56", "Maghrib on Dec 31 is 16:56");
is($dec31->{isha},    "18:26", "Isha on Dec 31 is 18:26");

# Known date: March 15 (15/3)
# CSV line: 15/3,19:15,17:45,15:08,11:43,5:43,4:26
my $mar15 = $tq->get_times(15, 3);
ok(defined $mar15, "get_times(15, 3) returns data");
is($mar15->{fajr},    "4:26", "Fajr on Mar 15 is 4:26");
is($mar15->{sunrise}, "5:43", "Sunrise on Mar 15 is 5:43");
is($mar15->{dhuhr},   "11:43", "Dhuhr on Mar 15 is 11:43");
is($mar15->{asr},     "15:08", "Asr on Mar 15 is 15:08");
is($mar15->{maghrib}, "17:45", "Maghrib on Mar 15 is 17:45");
is($mar15->{isha},    "19:15", "Isha on Mar 15 is 19:15");

# Leap day: Feb 29 should fall back to Feb 28 times
my $feb28 = $tq->get_times(28, 2);
my $feb29 = $tq->get_times(29, 2);
ok(defined $feb29, "get_times(29, 2) returns data (leap day fallback)");
is($feb29->{date},  "29/2", "Date key is 29/2");
is($feb29->{day},   29, "Day field is 29");
is($feb29->{month}, 2, "Month field is 2");
is($feb29->{fajr},    $feb28->{fajr},    "Feb 29 Fajr equals Feb 28 Fajr");
is($feb29->{sunrise}, $feb28->{sunrise}, "Feb 29 Sunrise equals Feb 28 Sunrise");
is($feb29->{dhuhr},   $feb28->{dhuhr},   "Feb 29 Dhuhr equals Feb 28 Dhuhr");
is($feb29->{asr},     $feb28->{asr},     "Feb 29 Asr equals Feb 28 Asr");
is($feb29->{maghrib}, $feb28->{maghrib}, "Feb 29 Maghrib equals Feb 28 Maghrib");
is($feb29->{isha},    $feb28->{isha},    "Feb 29 Isha equals Feb 28 Isha");

#------------------------------------------------------------------------------
# get_prayer tests
#------------------------------------------------------------------------------

print "\n### get_prayer\n";

is($tq->get_prayer(1, 1, 'fajr'),   "4:57", "get_prayer(1, 1, 'fajr') returns 4:57");
is($tq->get_prayer(1, 1, 'isha'),   "18:27", "get_prayer(1, 1, 'isha') returns 18:27");
is($tq->get_prayer(31, 12, 'dhuhr'), "11:37", "get_prayer(31, 12, 'dhuhr') returns 11:37");
is($tq->get_prayer(15, 3, 'asr'),   "15:08", "get_prayer(15, 3, 'asr') returns 15:08");

# Prayer name should be case-insensitive
is($tq->get_prayer(1, 1, 'FAJR'), "4:57", "get_prayer with uppercase 'FAJR' works");
is($tq->get_prayer(1, 1, 'Fajr'), "4:57", "get_prayer with mixed-case 'Fajr' works");

#------------------------------------------------------------------------------
# get_times_with_iqama tests
#------------------------------------------------------------------------------

print "\n### get_times_with_iqama\n";

my $jan1_iqama = $tq->get_times_with_iqama(1, 1);
ok(defined $jan1_iqama, "get_times_with_iqama(1, 1) returns data");

# Base prayer times should be preserved
is($jan1_iqama->{fajr}, "4:57", "Base fajr time preserved in iqama result");

# Iqama offsets: fajr=25, dhuhr=20, asr=25, maghrib=10, isha=20 (minutes)
# sunrise has no iqama.
#
# fajr:   4:57 + 25 = 5:22
# dhuhr: 11:37 + 20 = 11:57
# asr:   14:36 + 25 = 15:01
# maghrib: 16:57 + 10 = 17:07
# isha:  18:27 + 20 = 18:47
is($jan1_iqama->{fajr_iqama},    "5:22", "Fajr iqama: 4:57 + 25 min = 5:22");
is($jan1_iqama->{dhuhr_iqama},   "11:57", "Dhuhr iqama: 11:37 + 20 min = 11:57");
is($jan1_iqama->{asr_iqama},     "15:01", "Asr iqama: 14:36 + 25 min = 15:01");
is($jan1_iqama->{maghrib_iqama}, "17:07", "Maghrib iqama: 16:57 + 10 min = 17:07");
is($jan1_iqama->{isha_iqama},    "18:47", "Isha iqama: 18:27 + 20 min = 18:47");

# Sunrise should NOT have an iqama time
ok(!exists $jan1_iqama->{sunrise_iqama}, "Sunrise has no iqama (skipped as documented)");

#------------------------------------------------------------------------------
# get_all_days tests
#------------------------------------------------------------------------------

print "\n### get_all_days\n";

my $all_days = $tq->get_all_days();
ok(defined $all_days, "get_all_days returns defined value");
is(scalar(@$all_days), 366, "get_all_days returns 366 days (including leap day fallback)");
is($tq->get_all_days(), $all_days, "get_all_days returns cached arrayref on repeat calls");

is($all_days->[0]->{date},  "1/1", "First entry in get_all_days is January 1");
is($all_days->[-1]->{date}, "31/12", "Last entry in get_all_days is December 31");

# Every entry has all prayer fields
my $missing_fields = 0;
for my $d (@$all_days) {
    for my $p (qw(fajr sunrise dhuhr asr maghrib isha)) {
        $missing_fields++ unless defined $d->{$p};
    }
}
is($missing_fields, 0, "All 366 entries have all 6 prayer times");

# Feb 29 should be included in get_all_days
my $has_feb29 = grep { $_->{date} eq '29/2' } @$all_days;
ok($has_feb29, "February 29 appears in get_all_days results");

#------------------------------------------------------------------------------
# prayer_names tests
#------------------------------------------------------------------------------

print "\n### prayer_names\n";

my @names = TaqweemQatar::prayer_names();
is(scalar(@names), 6, "prayer_names returns 6 prayer names");
is($names[0], "fajr", "First prayer is fajr");
is($names[1], "sunrise", "Second prayer is sunrise");
is($names[5], "isha", "Last prayer is isha");

my @names_ar = TaqweemQatar::prayer_names_arabic();
is(scalar(@names_ar), 6, "prayer_names_arabic returns 6 names");
ok(defined $names_ar[0] && length($names_ar[0]) > 0, "First Arabic prayer name is defined and non-empty");

#------------------------------------------------------------------------------
# search_by_time tests
#------------------------------------------------------------------------------

print "\n### search_by_time\n";

# Fajr on Jan 1 is exactly 4:57 — exact match at 0 tolerance
my $matches = $tq->search_by_time('fajr', '4:57', 0);
ok(defined $matches, "search_by_time returns defined result");
ok(scalar(@$matches) >= 1, "search_by_time('fajr', '4:57', 0) finds at least one match");

my $found_jan1 = grep { $_->{date} eq '1/1' } @$matches;
ok($found_jan1, "January 1 appears in search results for fajr at 4:57");

# No match — search for fajr at 12:00 with 0 tolerance should return nothing
my $no_matches = $tq->search_by_time('fajr', '12:00', 0);
ok(defined $no_matches, "search_by_time for non-matching time returns defined");
is(scalar(@$no_matches), 0, "No dates found for fajr at 12:00");

# Default tolerance (5 min)
my $fuzzy = $tq->search_by_time('fajr', '5:00', 3);
ok(scalar(@$fuzzy) >= 1, "Fuzzy search (tolerance=3) finds matches near 5:00");

my ($wrap_fh, $wrap_file) = tempfile(
    'taqweem-wrap-XXXX',
    DIR    => dirname(__FILE__) . '/..',
    UNLINK => 1,
);
open my $source_fh, '<', dirname(__FILE__) . '/../taqweem.csv'
    or die "Cannot open source CSV for wraparound test: $!";
my $source_line = 0;
while (my $line = <$source_fh>) {
    $source_line++;
    if ($source_line == 1) {
        print {$wrap_fh} "1/1,23:58,16:57,14:36,11:37,6:20,4:57\n";
    } else {
        print {$wrap_fh} $line;
    }
}
close $source_fh;
close $wrap_fh;

my $wrap_tq = TaqweemQatar->new(data_file => $wrap_file);
my $wrap_matches = $wrap_tq->search_by_time('isha', '0:01', 5);
ok(scalar(@$wrap_matches) == 1, "search_by_time matches across midnight wraparound");

#------------------------------------------------------------------------------
# Error handling (croak paths)
#------------------------------------------------------------------------------

print "\n### Error handling\n";

# Day > 31
my $err;
eval { $tq->get_times(32, 1) };
$err = $@;
ok($err, "get_times croaks on day 32 (day > 31)");
like($err, qr/Day must be between 1 and 31/i, "...message mentions valid day range");

# Day < 1
eval { $tq->get_times(0, 1) };
$err = $@;
ok($err, "get_times croaks on day 0 (day < 1)");
like($err, qr/Day must be between 1 and 31/i, "...message mentions valid day range");

# Month > 12
eval { $tq->get_times(1, 13) };
$err = $@;
ok($err, "get_times croaks on month 13 (month > 12)");
like($err, qr/Month must be between 1 and 12/i, "...message mentions valid month range");

# Month < 1
eval { $tq->get_times(1, 0) };
$err = $@;
ok($err, "get_times croaks on month 0 (month < 1)");
like($err, qr/Month must be between 1 and 12/i, "...message mentions valid month range");

# Missing day argument
eval { $tq->get_times() };
$err = $@;
ok($err, "get_times croaks when day is missing");
like($err, qr/Day is required/i, "...message says 'Day is required'");

# Missing month argument (day provided, month omitted)
eval { $tq->get_times(1) };
$err = $@;
ok($err, "get_times croaks when month is missing");
like($err, qr/Month is required/i, "...message says 'Month is required'");

# Invalid prayer name in get_prayer
eval { $tq->get_prayer(1, 1, 'invalid_prayer') };
$err = $@;
ok($err, "get_prayer croaks on invalid prayer name");
like($err, qr/Invalid prayer name/i, "...message says 'Invalid prayer name'");

# Missing prayer name in get_prayer
eval { $tq->get_prayer(1, 1) };
$err = $@;
ok($err, "get_prayer croaks when prayer name is missing");
like($err, qr/Prayer name is required/i, "...message says 'Prayer name is required'");

# Invalid prayer name in search_by_time
eval { $tq->search_by_time('invalid_prayer', '12:00') };
$err = $@;
ok($err, "search_by_time croaks on invalid prayer name");
like($err, qr/Invalid prayer name/i, "...message says 'Invalid prayer name'");

# Missing prayer name in search_by_time
eval { $tq->search_by_time() };
$err = $@;
ok($err, "search_by_time croaks when prayer name is missing");
like($err, qr/Prayer name is required/i, "...message says 'Prayer name is required'");

# Missing time in search_by_time
eval { $tq->search_by_time('fajr') };
$err = $@;
ok($err, "search_by_time croaks when time is missing");
like($err, qr/Time is required/i, "...message says 'Time is required'");

# Malformed time in search_by_time
eval { $tq->search_by_time('fajr', 'notatime') };
$err = $@;
ok($err, "search_by_time croaks when time format is malformed");
like($err, qr/Invalid time format/i, "...message says 'Invalid time format'");

# Out-of-range time in search_by_time
eval { $tq->search_by_time('fajr', '99:88') };
$err = $@;
ok($err, "search_by_time croaks when time value is out of range");
like($err, qr/Invalid time format/i, "...message says 'Invalid time format'");

#-------------------------------------------------------------------------------
# Summary
#-------------------------------------------------------------------------------

print "\n# Summary\n";
print "# -------\n";
print "# Tests run: $tests_run\n";
print "# Passed: $tests_passed\n";
print "# Failed: $tests_failed\n";

exit($tests_failed > 0 ? 1 : 0);
