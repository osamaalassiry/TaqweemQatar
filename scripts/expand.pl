#!/usr/bin/perl 
#===============================================================================
#
#         FILE: expand.pl
#
#        USAGE: ./expand.pl  
#
#  DESCRIPTION: Expend taqweem.dat
#
#      OPTIONS: ---
# REQUIREMENTS: ---
#         BUGS: ---
#        NOTES: ---
#       AUTHOR: YOUR NAME (), 
#      COMPANY: 
#      VERSION: 1.0
#      CREATED: 27/01/16 17:41:25
#     REVISION: ---
#===============================================================================

use strict;
use warnings;

sub timeformat($$){
my $t=shift;
my $mm=sprintf('%02d',$t%60);
my $hh=sprintf('%02d',($t-$mm)/60);
return "$hh:$mm";
}

my @prayers=('Fajr','Sunrise','Dhuhr','Asr','Maghrib','Isha');
my @iqama=(25,0,20,25,10,20);
my @length=(2*2,0*2,2*4,2*4,2*3,2*4);
open my $tt,'<','taqweem.dat';
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
    while( my $time=pop @line){

        print"$dateday/$datemonth,",$prayers[$i],": Athan,",&timeformat($time),",",&timeformat($time+2),"\n";
        print"$dateday/$datemonth,",$prayers[$i],": Prayers,",&timeformat($time+$iqama[$i]),",",&timeformat($time+$iqama[$i]+$length[$i]-1),"\n";
        $i++;
    }

#    print join('*',@line),"\n";
}
close $tt;
