# TaqweemQatar

Perpetual Islamic prayer times dataset for Qatar, sourced from the official Qatar Calendar House (Dar Al-Taqweem Al-Qatri).

## Overview

This repository provides prayer times for all five daily Islamic prayers plus sunrise, for every day of the year. The data is sourced from Al-Taqweem Al-Da'em (The Perpetual Calendar) published by [Qatar Calendar House](http://www.qatarch.com/).

### Prayers Included

| Prayer | Arabic | Description |
|--------|--------|-------------|
| Fajr | الفجر | Dawn prayer, before sunrise |
| Sunrise | الشروق | Sun rises (not a prayer, marks end of Fajr window) |
| Dhuhr | الظهر | Noon prayer, when sun passes meridian |
| Asr | العصر | Afternoon prayer |
| Maghrib | المغرب | Sunset prayer, immediately after sunset |
| Isha | العشاء | Night prayer |

## Data Formats

### taqweem.csv (Human-readable)

Primary format with date and times in `HH:MM` format.

```csv
1/1,18:27,16:57,14:36,11:37,6:20,4:57
2/1,18:28,16:58,14:36,11:38,6:20,4:57
```

**Fields:** `day/month,isha,maghrib,asr,dhuhr,sunrise,fajr` (reverse chronological)

### taqweem.dat (Encoded)

Compact format for efficient processing. Times encoded as minutes since midnight.

```
0,297,380,697,876,1017,1107
1,297,380,698,876,1018,1108
```

**Fields:** `encoded_date,fajr,sunrise,dhuhr,asr,maghrib,isha` (chronological)

- Date encoding: `(day-1) + (month-1) × 31`
- Time encoding: `hours × 60 + minutes`

### taqweem.ics (iCalendar)

RFC 5545 compliant calendar file for Google Calendar, Apple Calendar, Outlook, etc.

- Includes both Athan (call to prayer) and Prayer (congregation) events
- Yearly recurring events
- Timezone: Asia/Qatar (UTC+3)

### taqweem.json (JSON)

Modern format for web applications and APIs.

```json
{
  "metadata": {
    "source": "Qatar Calendar House (Dar Al-Taqweem Al-Qatri)",
    "url": "http://www.qatarch.com/",
    "timezone": "Asia/Qatar",
    "utc_offset": "+03:00",
    "total_days": 365,
    "prayers": [
      {"id": "fajr", "name_ar": "الفجر"},
      {"id": "sunrise", "name_ar": "الشروق"},
      ...
    ]
  },
  "days": [
    {
      "date": "1/1",
      "day": 1,
      "month": 1,
      "prayers": {
        "fajr": "4:57",
        "sunrise": "6:20",
        "dhuhr": "11:37",
        "asr": "14:36",
        "maghrib": "16:57",
        "isha": "18:27"
      }
    }
  ]
}
```

## Installation

```bash
git clone https://github.com/osamaalassiry/TaqweemQatar.git
cd TaqweemQatar
```

## Usage

### Using the Perl Module

```perl
use lib 'lib';
use TaqweemQatar;

my $tq = TaqweemQatar->new();

# Get all prayer times for a date
my $times = $tq->get_times(15, 3);  # March 15
print "Fajr: $times->{fajr}\n";     # "4:26"
print "Dhuhr: $times->{dhuhr}\n";   # "11:43"

# Get times with iqama (congregation times)
my $full = $tq->get_times_with_iqama(15, 3);
print "Fajr Iqama: $full->{fajr_iqama}\n";  # "4:51"

# Get specific prayer
my $maghrib = $tq->get_prayer(15, 3, 'maghrib');  # "17:45"

# Find dates when Fajr is around 4:30 AM (±5 min tolerance)
my $matches = $tq->search_by_time('fajr', '4:30', 5);
```

### Import Calendar to Google Calendar

1. Open [Google Calendar](https://calendar.google.com)
2. Settings → Import & export → Import
3. Select `taqweem.ics`
4. Choose target calendar
5. Import

### Building Data Files

Use the Makefile to generate all formats from source:

```bash
# Build all formats
make all

# Build specific format
make json
make ics
make dat

# Run tests
make test

# Validate data
make validate

# Show statistics
make stats
```

## Scripts

Located in the `scripts/` directory:

| Script | Description |
|--------|-------------|
| `convert.pl` | Converts source text to encoded DAT format |
| `ical.pl` | Generates iCalendar (.ics) file |
| `json_export.pl` | Exports to JSON format |
| `expand.pl` | Decodes DAT to human-readable format |
| `test_taqweem.pl` | Test suite for data validation |

### Script Options

**ical.pl:**
```bash
./ical.pl --year 2025           # Set base year
./ical.pl --no-athan            # Skip athan events
./ical.pl --no-prayer           # Skip prayer events
```

**json_export.pl:**
```bash
./json_export.pl --pretty       # Pretty-print output
./json_export.pl --compact      # Compact output (default)
```

## Iqama Times

Default congregation (iqama) times after athan:

| Prayer | Iqama Delay |
|--------|-------------|
| Fajr | 25 minutes |
| Dhuhr | 20 minutes |
| Asr | 25 minutes |
| Maghrib | 10 minutes |
| Isha | 20 minutes |

## Data Source

- **Source:** Qatar Calendar House (Dar Al-Taqweem Al-Qatri)
- **Document:** Al-Taqweem Al-Da'em (Perpetual Calendar)
- **URL:** http://www.qatarch.com/
- **Coverage:** 365 days (perpetual, non-leap year)
- **Timezone:** Asia/Qatar (UTC+3, no DST)

## Notes

- This is a **perpetual calendar** - times repeat yearly based on solar position
- Qatar does not observe Daylight Saving Time
- For Ramadan fasting, Fajr marks the start (Imsak) and Maghrib marks Iftar
- Leap years: February 29 uses February 28 times

## Project Structure

```
TaqweemQatar/
├── taqweem.csv        # Main dataset (human-readable)
├── taqweem.dat        # Encoded dataset
├── taqweem.ics        # iCalendar format
├── taqweem.json       # JSON format
├── Makefile           # Build system
├── lib/
│   └── TaqweemQatar.pm  # Perl module
└── scripts/
    ├── taqweem.txt    # Original source data
    ├── convert.pl     # Text → DAT converter
    ├── ical.pl        # ICS generator
    ├── json_export.pl # JSON exporter
    ├── expand.pl      # DAT decoder
    └── test_taqweem.pl # Test suite
```

## Contributing

Contributions are welcome! Please ensure:

1. Data changes are validated with `make test`
2. All formats are regenerated with `make all`
3. Changes are documented

## License

MIT License - See [LICENSE](LICENSE) file for details.

## Acknowledgments

- [Qatar Calendar House](http://www.qatarch.com/) for the official prayer times data
