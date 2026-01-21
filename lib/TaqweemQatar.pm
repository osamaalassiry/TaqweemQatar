package TaqweemQatar;
#===============================================================================
#
#       MODULE: TaqweemQatar
#
#        USAGE: use TaqweemQatar;
#               my $tq = TaqweemQatar->new();
#               my $times = $tq->get_times(15, 3);  # March 15
#
#  DESCRIPTION: Perl module for accessing Qatar prayer times data.
#               Provides an easy-to-use API for querying prayer times.
#
#       AUTHOR: Osama Al Assiry
#      CREATED: 2025-01-21
#      VERSION: 1.0
#
#===============================================================================

use strict;
use warnings;
use Carp;
use File::Basename;
use File::Spec;

our $VERSION = '1.0';

# Prayer names
our @PRAYERS = qw(fajr sunrise dhuhr asr maghrib isha);
our @PRAYERS_AR = ('الفجر', 'الشروق', 'الظهر', 'العصر', 'المغرب', 'العشاء');

# Iqama times (minutes after athan)
our @IQAMA = (25, 0, 20, 25, 10, 20);

#-------------------------------------------------------------------------------
# Constructor
#-------------------------------------------------------------------------------

sub new {
    my ($class, %args) = @_;

    my $self = {
        data_file => $args{data_file} || _find_data_file(),
        _cache    => {},
        _loaded   => 0,
    };

    bless $self, $class;

    # Auto-load data unless lazy loading requested
    $self->_load_data() unless $args{lazy};

    return $self;
}

#-------------------------------------------------------------------------------
# Public methods
#-------------------------------------------------------------------------------

sub get_times {
    my ($self, $day, $month) = @_;

    croak "Day is required" unless defined $day;
    croak "Month is required" unless defined $month;
    croak "Day must be between 1 and 31" unless $day >= 1 && $day <= 31;
    croak "Month must be between 1 and 12" unless $month >= 1 && $month <= 12;

    $self->_load_data() unless $self->{_loaded};

    my $key = "$day/$month";
    my $data = $self->{_cache}{$key};

    croak "No data found for $key" unless $data;

    # CSV order is reverse: isha, maghrib, asr, dhuhr, sunrise, fajr
    return {
        date    => $key,
        day     => $day,
        month   => $month,
        fajr    => $data->[5],
        sunrise => $data->[4],
        dhuhr   => $data->[3],
        asr     => $data->[2],
        maghrib => $data->[1],
        isha    => $data->[0],
    };
}

sub get_times_with_iqama {
    my ($self, $day, $month) = @_;

    my $times = $self->get_times($day, $month);

    # Add iqama times
    for my $i (0..$#PRAYERS) {
        my $prayer = $PRAYERS[$i];
        next if $prayer eq 'sunrise';  # No iqama for sunrise

        my $athan_time = $times->{$prayer};
        my ($h, $m) = split /:/, $athan_time;
        my $total_mins = $h * 60 + $m + $IQAMA[$i];

        my $iqama_h = int($total_mins / 60) % 24;
        my $iqama_m = $total_mins % 60;

        $times->{"${prayer}_iqama"} = sprintf("%d:%02d", $iqama_h, $iqama_m);
    }

    return $times;
}

sub get_prayer {
    my ($self, $day, $month, $prayer) = @_;

    croak "Prayer name is required" unless $prayer;

    $prayer = lc($prayer);
    croak "Invalid prayer name: $prayer" unless grep { $_ eq $prayer } @PRAYERS;

    my $times = $self->get_times($day, $month);
    return $times->{$prayer};
}

sub get_all_days {
    my ($self) = @_;

    $self->_load_data() unless $self->{_loaded};

    my @days;
    for my $month (1..12) {
        my $days_in_month = _days_in_month($month);
        for my $day (1..$days_in_month) {
            my $key = "$day/$month";
            next unless exists $self->{_cache}{$key};
            push @days, $self->get_times($day, $month);
        }
    }

    return \@days;
}

sub search_by_time {
    my ($self, $prayer, $time, $tolerance) = @_;

    $tolerance //= 5;  # Default 5 minute tolerance

    croak "Prayer name is required" unless $prayer;
    croak "Time is required" unless $time;

    $prayer = lc($prayer);
    croak "Invalid prayer name: $prayer" unless grep { $_ eq $prayer } @PRAYERS;

    my ($search_h, $search_m) = split /:/, $time;
    my $search_mins = $search_h * 60 + $search_m;

    my @matches;
    my $all_days = $self->get_all_days();

    for my $day_data (@$all_days) {
        my $day_time = $day_data->{$prayer};
        my ($h, $m) = split /:/, $day_time;
        my $day_mins = $h * 60 + $m;

        if (abs($day_mins - $search_mins) <= $tolerance) {
            push @matches, $day_data;
        }
    }

    return \@matches;
}

sub prayer_names {
    return @PRAYERS;
}

sub prayer_names_arabic {
    return @PRAYERS_AR;
}

#-------------------------------------------------------------------------------
# Private methods
#-------------------------------------------------------------------------------

sub _load_data {
    my ($self) = @_;

    return if $self->{_loaded};

    my $file = $self->{data_file};
    croak "Data file not found: $file" unless -f $file;

    open my $fh, '<', $file
        or croak "Cannot open '$file': $!";

    while (my $line = <$fh>) {
        chomp $line;
        next if $line =~ /^\s*$/;

        my @fields = split /,/, $line;
        next unless @fields == 7;

        my ($date, @times) = @fields;
        $self->{_cache}{$date} = \@times;
    }

    close $fh;

    $self->{_loaded} = 1;

    return 1;
}

sub _find_data_file {
    # Try to find taqweem.csv relative to module location
    my $module_dir = dirname(__FILE__);

    my @search_paths = (
        File::Spec->catfile($module_dir, '..', 'taqweem.csv'),
        File::Spec->catfile($module_dir, '..', '..', 'taqweem.csv'),
        'taqweem.csv',
        '/usr/share/taqweem/taqweem.csv',
    );

    for my $path (@search_paths) {
        return $path if -f $path;
    }

    croak "Cannot find taqweem.csv data file";
}

sub _days_in_month {
    my ($month) = @_;
    my @days = (31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31);
    return $days[$month - 1];
}

1;

__END__

=head1 NAME

TaqweemQatar - Perl module for Qatar prayer times

=head1 SYNOPSIS

    use TaqweemQatar;

    # Create instance
    my $tq = TaqweemQatar->new();

    # Get prayer times for a specific date
    my $times = $tq->get_times(15, 3);  # March 15
    print "Fajr: $times->{fajr}\n";
    print "Dhuhr: $times->{dhuhr}\n";

    # Get times with iqama (congregation prayer times)
    my $full = $tq->get_times_with_iqama(15, 3);
    print "Fajr Iqama: $full->{fajr_iqama}\n";

    # Get specific prayer time
    my $fajr = $tq->get_prayer(15, 3, 'fajr');
    print "Fajr on March 15: $fajr\n";

    # Search for dates when Fajr is around 4:30
    my $matches = $tq->search_by_time('fajr', '4:30', 5);

=head1 DESCRIPTION

TaqweemQatar provides access to Qatar's perpetual prayer times data
from Qatar Calendar House. It offers an easy-to-use API for querying
prayer times for any day of the year.

=head1 METHODS

=head2 new(%options)

Creates a new TaqweemQatar instance.

Options:
    data_file => '/path/to/taqweem.csv'  # Custom data file path
    lazy      => 1                        # Don't load data until first query

=head2 get_times($day, $month)

Returns a hashref with all prayer times for the specified date.

=head2 get_times_with_iqama($day, $month)

Returns prayer times including iqama (congregation) times.

=head2 get_prayer($day, $month, $prayer)

Returns a single prayer time for the specified date.

=head2 get_all_days()

Returns an arrayref of all 365 days with prayer times.

=head2 search_by_time($prayer, $time, $tolerance)

Finds dates where the specified prayer occurs within tolerance minutes.

=head1 AUTHOR

Osama Al Assiry

=head1 LICENSE

MIT License

=cut
