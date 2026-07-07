#!/usr/bin/perl
#===============================================================================
#
#         FILE: expand.pl
#
#        USAGE: ./expand.pl [options]
#
#  DESCRIPTION: Expand taqweem.dat to human-readable format
#
#      OPTIONS: --input FILE   Input DAT file (default: taqweem.dat)
#
# REQUIREMENTS: ---
#         BUGS: ---
#        NOTES: ---
#       AUTHOR: Osama Al Assiry
#      COMPANY:
#      VERSION: 2.0
#      CREATED: 27/01/16 17:41:25
#     REVISION: 2025-01-21 - Added --input option and error handling
#===============================================================================

use strict;
use warnings;
use Getopt::Long;
use File::Basename;
use File::Spec;

sub timeformat {
my $t=shift;
my $mm=sprintf('%02d',$t%60);
my $hh=sprintf('%02d',($t-$mm)/60);
return "$hh:$mm";
}

sub usage_text {
    return "Usage: $0 [--input FILE]\n";
}

# Parse command line options
my $input_file = File::Spec->catfile(dirname(__FILE__), '..', 'taqweem.dat');
GetOptions(
    'input=s' => \$input_file,
    'help|h'  => sub { print usage_text(); exit 0 },
) or die "Error: Invalid options\n";

# Validate input file
die "Error: Input file '$input_file' not found\n" unless -f $input_file;

my @prayers=('Fajr','Sunrise','Dhuhr','Asr','Maghrib','Isha');
my @iqama=(25,0,20,25,10,20);
my @length=(2*2,0*2,2*4,2*4,2*3,2*4);
open my $tt,'<',$input_file or die "Error: Cannot open input file '$input_file': $!\n";
while(<$tt>){
    chomp;
    my @line=split /,/;
    @line=reverse @line;
    my $day=pop @line;
    my $dateday=$day % 31;
    my $datemonth=($day-$dateday)/31;
    $dateday++;$datemonth++;
    @line=reverse @line;
    my $i=0;
    while(@line){
        my $time=pop @line;

        print"$dateday/$datemonth,",$prayers[$i],": Athan,",timeformat($time),",",timeformat($time+2),"\n";
        if ($iqama[$i] > 0) {
            print"$dateday/$datemonth,",$prayers[$i],": Prayers,",timeformat($time+$iqama[$i]),",",timeformat($time+$iqama[$i]+$length[$i]-1),"\n";
        }
        $i++;
    }

#    print join('*',@line),"\n";
}
close $tt;
