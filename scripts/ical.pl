#!/usr/bin/perl
#===============================================================================
#
#         FILE: ical.pl
#
#        USAGE: ./ical.pl [options] > taqweem.ics
#
#      OPTIONS: --year YYYY    Base year for calendar (default: current year)
#               --input FILE   Input DAT file (default: taqweem.dat)
#               --no-athan     Skip Athan (call to prayer) events
#               --no-prayer    Skip Prayer (congregation) events
#
#  DESCRIPTION: Generates iCalendar (.ics) file from prayer times data.
#               Creates recurring yearly events for each prayer time.
#
#       AUTHOR: Osama Al Assiry
#      CREATED: 2016-01-27
#     REVISION: 2.0 - Added year parameter, error handling, options
#
#===============================================================================

use strict;
use warnings;
use Getopt::Long;
use POSIX qw(strftime);
use Time::Local qw(timegm);
use File::Basename;
use File::Spec;

# Configuration
my @PRAYERS = qw(Fajr Sunrise Dhuhr Asr Maghrib Isha);
my @IQAMA   = (25, 0, 20, 25, 10, 20);  # Minutes after athan for congregation
my @LENGTH  = (4, 0, 8, 8, 6, 8);       # Prayer duration in minutes

sub usage_text {
    return "Usage: $0 [--year YYYY] [--input FILE] [--no-athan] [--no-prayer]\n";
}

# Parse command line options
my $year = (localtime)[5] + 1900;  # Current year
my $input_file = File::Spec->catfile(dirname(__FILE__), '..', 'taqweem.dat');
my $include_athan = 1;
my $include_prayer = 1;

GetOptions(
    'year=i'     => \$year,
    'input=s'    => \$input_file,
    'no-athan'   => sub { $include_athan = 0 },
    'no-prayer'  => sub { $include_prayer = 0 },
    'help|h'     => sub { print usage_text(); exit 0 },
) or die "Error: Invalid options\n";

# Validate input file
die "Error: Input file '$input_file' not found\n" unless -f $input_file;

# Validate year
die "Error: Invalid year '$year'\n" unless $year >= 1900 && $year <= 2100;

#-------------------------------------------------------------------------------
# Helper functions
#-------------------------------------------------------------------------------

sub format_datetime {
    my ($year, $month, $day, $minutes) = @_;

    my $epoch = timegm(0, 0, 0, $day, $month - 1, $year) + ($minutes * 60);
    my ($sec, $mins, $hours, $mday, $mon, $out_year) = gmtime($epoch);

    return sprintf("%04d%02d%02dT%02d%02d00",
        $out_year + 1900, $mon + 1, $mday, $hours, $mins);
}

sub generate_uid {
    my ($prayer, $month, $day) = @_;
    return sprintf("%s-%02d%02d\@taqweem.qa", lc($prayer), $month, $day);
}

sub is_leap_year {
    my ($year) = @_;
    return ($year % 4 == 0 && $year % 100 != 0) || ($year % 400 == 0);
}

sub next_leap_year {
    my ($year) = @_;
    $year++ until is_leap_year($year);
    return $year;
}

sub print_event {
    my ($summary, $start, $end, $uid, $yearly) = @_;
    $yearly //= 1;

    print "BEGIN:VEVENT\n";
    print "UID:$uid\n";
    print "DTSTART;TZID=Asia/Qatar:$start\n";
    print "DTEND;TZID=Asia/Qatar:$end\n";
    print "RRULE:FREQ=YEARLY\n" if $yearly;
    print "DTSTAMP:" . strftime("%Y%m%dT%H%M%SZ", gmtime()) . "\n";
    print "SUMMARY:$summary\n";
    print "DESCRIPTION:Qatar prayer times from Qatar Calendar House\n";
    print "STATUS:CONFIRMED\n";
    print "TRANSP:TRANSPARENT\n";
    print "END:VEVENT\n";
}

sub print_day_events {
    my ($event_year, $month, $day, $times_ref, $yearly) = @_;
    $yearly //= 1;
    my $event_count = 0;

    # Generate events for each prayer
    for my $i (0..5) {
        my $prayer = $PRAYERS[$i];
        my $time = $times_ref->[$i];

        # Skip sunrise (index 1) - not a prayer time
        next if $i == 1;

        # Generate Athan event
        if ($include_athan) {
            my $start = format_datetime($event_year, $month, $day, $time);
            my $end = format_datetime($event_year, $month, $day, $time + 2);
            my $uid = generate_uid("athan-$prayer", $month, $day);

            print_event("Athan $prayer", $start, $end, $uid, $yearly);
            $event_count++;
        }

        # Generate Prayer event
        if ($include_prayer && $IQAMA[$i] > 0) {
            my $prayer_start = $time + $IQAMA[$i];
            my $prayer_end = $prayer_start + $LENGTH[$i];

            my $start = format_datetime($event_year, $month, $day, $prayer_start);
            my $end = format_datetime($event_year, $month, $day, $prayer_end);
            my $uid = generate_uid("prayer-$prayer", $month, $day);

            print_event("Prayer $prayer", $start, $end, $uid, $yearly);
            $event_count++;
        }
    }

    return $event_count;
}

#-------------------------------------------------------------------------------
# Generate iCalendar header
#-------------------------------------------------------------------------------

my $timestamp = strftime("%Y%m%dT%H%M%SZ", gmtime());

print <<"HEADER";
BEGIN:VCALENDAR
PRODID:-//TaqweemQatar//Prayer Times Calendar//EN
VERSION:2.0
CALSCALE:GREGORIAN
METHOD:PUBLISH
X-WR-CALNAME:Qatar Prayer Times
X-WR-TIMEZONE:Asia/Qatar
BEGIN:VTIMEZONE
TZID:Asia/Qatar
X-LIC-LOCATION:Asia/Qatar
BEGIN:STANDARD
TZOFFSETFROM:+0300
TZOFFSETTO:+0300
TZNAME:+03
DTSTART:19700101T000000
END:STANDARD
END:VTIMEZONE
HEADER

#-------------------------------------------------------------------------------
# Process prayer times data
#-------------------------------------------------------------------------------

open my $fh, '<', $input_file
    or die "Error: Cannot open '$input_file': $!\n";

my $entry_count = 0;
my $event_count = 0;
my $invalid_lines = 0;
my @feb28_times;

while (my $line = <$fh>) {
    chomp $line;
    next if $line =~ /^\s*$/;

    my @fields = split /,/, $line;

    if (@fields != 7) {
        warn "Warning: Invalid line format, skipping: $line\n";
        $invalid_lines++;
        next;
    }

    my ($encoded_date, @times) = @fields;
    @times = reverse @times;

    # Decode date
    my $day = ($encoded_date % 31) + 1;
    my $month = int($encoded_date / 31) + 1;

    $entry_count++;
    @feb28_times = @times if $month == 2 && $day == 28;

    $event_count += print_day_events($year, $month, $day, \@times);
}

close $fh;

if (@feb28_times) {
    my $leap_year = next_leap_year($year);
    $event_count += print_day_events($leap_year, 2, 29, \@feb28_times, 0);
}

# Calendar footer
print "END:VCALENDAR\n";

# Summary to stderr
warn "Generated $event_count events from $entry_count days\n";

exit($invalid_lines ? 1 : 0);
