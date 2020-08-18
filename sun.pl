#!/usr/bin/perl -w

use strict;
use warnings;
use diagnostics;
use POSIX qw(floor ceil);
use Math::Trig qw(asin acos atan tan deg2rad rad2deg);
use Math::Trig ':pi';
use Scalar::Util qw(looks_like_number);
no if ($] >= 5.018), 'warnings' => 'experimental';

# constants
my $pi = pi;                  # pi (3.14159265358...)
my $doublepi = pi2;           # 2*pi
my $halfcircle = 180;         # half a circle in degrees
my $fullcircle = 360;         # full circle in degrees
my $deltaLong = 15;           # longitude difference between timezones
my $d2r = $pi/$halfcircle;    # conversion factor degrees -> radian
my $r2d = $halfcircle/$pi;    # conversion factor radian -> degrees
my $hSun = (-50/60)*$d2r;     # height at sunrise/sunset (-0°50'0") in radian
my $hDawnC = -6*$d2r;         # height at civil dawn (-6°0'0") in radian
my $hDawnN = -12*$d2r;        # height at nautical dawn (-12°0'0") in radian
my $hDawnA = -18*$d2r;        # height at astronomical dawn (-18°0'0") in radian

# check number of arguments
if ($#ARGV != 4){
	printExit();
}

# check if arguments are numeric
foreach my $nrarg (0..$#ARGV) {
	if(!looks_like_number(join('',$ARGV[$nrarg]))){
		print "Arguments have to be numeric\n";
		printExit();
	}
}

my ($day, $month, $year, $hour, $minute) = @ARGV;

# minima and maxima for certain levels
my %min = (
	"day" => 1,
	"month" => 1,
	"year" => 2000,
	"hour" => 0,
	"minute" => 0
);
my %max = (
	"day" => (
		1 => 31,
		2 => {
			0 => 28,
			1 => 29
		},
		3 => 31,
		4 => 30,
		5 => 31,
		6 => 30,
		7 => 31,
		8 => 31,
		9 => 30,
		10 => 31,
		11 => 30,
		12 => 31
	),
	"month" => 12,
	"hour" => 23,
	"minute" => 59,
);

# check if time is sensible
if ($minute < $min{minute} or $minute > $max{minute}){
	printNotSensible();
}
if ($hour < $min{hour} or $hour > $max{hour}){
	printNotSensible();
}

# check if date is sensible and computable
if ($year < $min{year}){
	printNotSensible();
}
my $leap = leapyear($year);
if ($month < $min{month} or $month > $max{month}){
	printNotSensible();
}
if ($month != 2){
	if ($day < $min{day} or $day > $max{day}{$month}){
		printNotSensible();
	}
} else {
	if ($day < $min{day} or $day > $max{day}{$month}{$leap}){
		printNotSensible();
	}
}

# read parameters from file
my ($latitude, $longitude, $timezone) = readParameters();
my $B = $latitude*$d2r;                              # latitude in radian
my $hours = calcHours($hour, $minute, $timezone);    # hours since 00 utc
my $T = yearday($day, $month, $year, $hours);        # Julian days since Jan 1, 2000, 12:00 UT
my $L = 280.460 + 0.9856474 * $T;                    # mean ecliptic longitude in degrees
my $Ln = normalizeDeg($L);                           # bring it to range [0°;360°]
my $g = 357.528 + 0.9856003 * $T;                    # mean anomaly
my $gn = normalizeDeg($g);                           # bring it to range [0°;360°]
my $e = $d2r*(23.43929111 - 0.0000004 * $T);         # numerical eccentricity
my $Lambda = ((sin($d2r*$gn))*1.915+$Ln) + 0.020*sin(2*$d2r*$gn); # ecliptic longitude of sun (in degrees)
my $CosLambda = cos($d2r*$Lambda);                   # cosine of ecliptic longitude (to define the quadrant)
my $declination = asin(sin($e)*sin($d2r*$Lambda));   # declination (equatorial coordinate system) in radian
my $rightAscension = atan(tan($d2r*$Lambda)*cos($e)); # right ascension (equatorial coordinate system) in radian
$rightAscension += $pi if ($CosLambda < 0);          # bring right ascension to correct quadrant (arctan not unique)

# horizontal coordinates of the sun
my $TMidnight = yearday($day,$month,$year,0);        # number of Julian days at midnight of the day
my $TMidnightNorm = ($TMidnight/36525);              # number of Julian centuries
my $theta_GH = 6.697376 + 2400.05134*$TMidnightNorm + 1.002738*$hours;    # mean Greenwich sidereal time
my $theta_G = $deltaLong * $theta_GH;                # Greenwich hour angle of the primary equinox (in degrees)
my $theta = $theta_G + $longitude;                   # hour angle of the primary equinox (in degrees)
my $theta_rad = $d2r * $theta;                       # hour angle of the primary equinox (in radian)
my $tau = $theta_rad - $rightAscension;              # hour angle of the specified place
my $denominator = (cos($tau)*sin($B)-(tan($declination)*cos($B)));
my $azimuth = atan(sin($tau)/$denominator);           # preliminary azimuthal angle
$azimuth += $pi if ($denominator < 0);                # bring it to the correct quadrant
$azimuth -= $doublepi if ($azimuth > $pi);            # bring it to the range [-π;+π]
$azimuth += $doublepi if ($azimuth < (-1*$pi));
my $height = asin(cos($declination)*cos($tau)*cos($B) + (sin($declination)*sin($B)));  # uncorrected height (in radian)
my $azimuth_deg = $r2d*$azimuth;                      # azimuth in degrees
my $height_deg = $r2d*$height;                        # height in degrees

# correction due to refraction in the atmosphere
my $refraction = 1.02 / tan($d2r * ($height_deg + (10.3/($height_deg + 5.11))));    # mean refraction (in arcminutes) for 1010 mbar and 10°C/50°F
my $correctedHeight = $height_deg + $refraction/60;                                 # corrected height (in degrees)

# prepare output
my $lat = degMinSec($latitude);
my $lon = degMinSec($longitude);
my $datetime = sprintf("%02u.%02u.%4u, %02u:%02u Ortszeit UTC%+4.1f",$day,$month,$year,$hour,$minute,$timezone);


sub printExit {
	print "Usage: ./sun <day> <month> <year> <hour> <minute>\n";
	exit;
}


sub printNotSensible {
	print "Argument values not sensible\n";
	printExit();
}


sub leapyear {
	my $y = shift;
	return 1 if ($y % 400 == 0);
	return 1 if ($y % 4 == 0 && $y % 100 != 0);
	return 0;
}


sub readParameters {
	my %parameters;
	open(FILE, "sun.dat") || die "cannot open parameter file";
	while (my $line = <FILE>){
		my @temp = split(/ [\t]/,$line);
		$parameters{$temp[0]} = $temp[1];
	}
	close(FILE);
	return ($parameters{latitude}, $parameters{longitude}, $parameters{timezone});
}


sub calcHours {
	my ($h, $m, $tz) = @_;
	my $res = 0;
	$res += ($h - $tz);
	$res += ($m/60);
	return $res;
}


sub yearday {
	my ($d, $m, $y, $h) = @_;
	my $numdays = 0;
	foreach my $yr (2000..($y-1)) {
		my $add = leapyear($yr) == 1 ? 366 : 365;
		$numdays += $add;
	}
	my $ly = leapyear($y);
	my $addm = 0;
	foreach my $mth (1..($m-1)) {
		$addm = 31 if ($mth ~~ [1,3,5,7,8,10,12]);
		$addm = 30 if ($mth ~~ [4,6,9,11]);
		$addm = 29 if ($mth == 2 and $ly == 1);
		$addm = 28 if ($mth == 2 and $ly == 0);
		$numdays += $addm;
	}
	$numdays += ($d - 1);
	my $fraction = ($h - 12)/24;
	my $result = $numdays + $fraction;
	return $result;
}


sub normalizeDeg {
	my $l = shift;
	while ($l < 0) {
		$l += $fullcircle;
	}
	while ($l > $fullcircle) {
		$l -= $fullcircle;
	}
	return $l;
}


sub minu {
	my $value = shift;
	return $value < 10 ? "0$value" : "$value";
}