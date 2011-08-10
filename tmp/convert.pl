#!/usr/bin/perl
open in,'taqweem.txt';
@months=(Jan,Feb,Mar,Apr,May,Jun,Jul,Aug,Sep,Oct,Nov,Dec);

while(<in>)
{
	chomp;
	$mmm=0;
	foreach $m (@months) {
		$mmm++;
		if ($_ eq $m){$dd=1; $mm=$mmm;}
	}
	if ($_=~/^\d.+/) {
	@t=split(/\s+/);
	$t[0]+=12;
	$t[2]+=12;
	$t[4]+=12;
	for ($p = 5; $p >= 0; $p--) {
		$tm[$p]=$t[$p*2]*60+$t[$p*2+1];
	}
	$times=join(',',@tm);
	$ddd= (($dd-1)+($mm-1)*31);
	print "$ddd,$times\n";
	$dd++;
	}
}
