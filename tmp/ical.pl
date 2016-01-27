#!/usr/bin/perl 

use strict;
use warnings;

sub timeformat($$){
my $dm=shift;
my $dd=shift;
my $t=shift;
 $dm=sprintf('%02d',$dm);
 $dd=sprintf('%02d',$dd);
my $mm=sprintf('%02d',$t%60);
my $hh=sprintf('%02d',($t-$mm)/60);
return "2000$dm$dd"."T"."$hh$mm"."00";
}

sub printevent($$){
my $summary=shift;
my $starttime=shift;
my $endtime=shift;

print "BEGIN:VEVENT\n";
print "DTSTART;TZID=Asia/Qatar:$starttime\n";
print "DTEND;TZID=Asia/Qatar:$endtime\n";
print "RRULE:FREQ=YEARLY\n";
print "DTSTAMP:$starttime\n";
print "CREATED:$starttime\n";
print "LAST-MODIFIED:$starttime\n";
print "SEQUENCE:1\n";
print "STATUS:CONFIRMED\n";
print "SUMMARY:$summary\n";
print "END:VEVENT\n";



}

print <<here;
BEGIN:VCALENDAR
PRODID:-//Google Inc//Google Calendar 70.9054//EN
VERSION:2.0
CALSCALE:GREGORIAN
METHOD:PUBLISH

X-WR-TIMEZONE:Asia/Qatar
BEGIN:VTIMEZONE
TZID:Asia/Qatar
X-LIC-LOCATION:Asia/Qatar
BEGIN:STANDARD
TZOFFSETFROM:+0300
TZOFFSETTO:+0300
TZNAME:AST
DTSTART:19700101T000000
END:STANDARD
END:VTIMEZONE

here

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

next if($i==1);

&printevent("Athan ".$prayers[$i],&timeformat($datemonth,$dateday,$time),&timeformat($datemonth,$dateday,$time+2));
&printevent("Prayer ".$prayers[$i],&timeformat($datemonth,$dateday,$time+$iqama[$i]),&timeformat($datemonth,$dateday,$time+$iqama[$i]+$length[$i]-1));

        $i++;
    }

#    print join('*',@line),"\n";
}
close $tt;

print "END:VCALENDAR\n";
