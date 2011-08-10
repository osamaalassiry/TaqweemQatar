TaqweemQatar
============
This is a set of data files for Qatar's prayer times based on the perpetual prayer times calendar from Qatar Calendar House http://www.qatarch.com/ (from http://www.qatarch.com/pdf/Al-Taqweem%20Al-Da_em.pdf )

taqweem.dat and taqweem.csv are CSV files that contain 7 fields per row, the date and 6 times (for the 5 prayers and the sunrise time).

taqweem.csv
===========
Date: dd/mm where dd is 1..31 and mm is 1..12!
The next 6 fields are times for
Fajr, Shurooq, Dhuhr, Asr, Maghrib, Isha as hh:mm where hh is 0..23 and mm is 0..59

taqweem.dat
===========
Date: (dd-1)+(mm-1)*31 where dd is 1..31 and mm is 1..12!
The next 6 fields are times for
Fajr, Shurooq, Dhuhr, Asr, Maghrib, Isha as hh*60+mm where hh is 0..23 and mm is 0..59

