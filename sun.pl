#!/usr/bin/perl -w

use strict;
use warnings;
use diagnostics;
use DateTime;
use DateTime::TimeZone;
use POSIX qw(floor ceil);
use Math::Trig qw(asin acos atan tan deg2rad rad2deg);
use Math::Trig ':pi';
use Cwd 'abs_path';
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
if ($#ARGV != 5){
	printExit();
}

my $parameterfile = abs_path(join('',$ARGV[0]));
my @numargs = @ARGV[1..5];

# check if arguments are numeric
foreach my $nrarg (0..$#numargs) {
	if(!looks_like_number(join('',$numargs[$nrarg]))){
		print "Arguments have to be numeric\n";
		printExit();
	}
}

my ($day, $month, $year, $hour, $minute) = formatData(@numargs);

# minima and maxima for certain levels
my %min = (
	"day" => 1,
	"month" => 1,
	"year" => 2000,
	"hour" => 0,
	"minute" => 0
);
my %max = (
	"day" => {
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
	},
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
my ($latitude, $longitude, $timezone) = readParameters($parameterfile);
chomp($timezone);
my $tz = DateTime::TimeZone->new(name => $timezone);
my $dt = DateTime->new(year => $year, month => $month, day => $day, hour => $hour, minute => $minute, second => 0);
my $tzRaw = $tz->offset_for_datetime($dt);
my $timezoneSign = $tzRaw < 0 ? "-" : "+";
my $absTimezone = abs($tzRaw) / 3600;
my $timezoneF = formatTime($absTimezone);
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
my $lat = geoDegMinSec($latitude, "lat");
my $lon = geoDegMinSec($longitude, "lon");
my $monthName = nameMonth($month);
my $datetime = sprintf("%02u %s %4u, %02u:%02u Local Time (UTC%1s%5s)",$day,$monthName,$year,$hour,$minute,$timezoneSign, $timezoneF);
my $azimuthFormatted = degMinSec($azimuth_deg);
my $heightFormatted = degMinSec($height_deg);

# mean right ascension
my $RAh = 24*$rightAscension/$doublepi;
my $Tn = $T / 36525;                                   # number of Julian centuries
my $meanRightAscension = 18.71506921 + 2400.0513369*$Tn + 0.000025862*$Tn**2 - 0.00000000172*$Tn**3;
my $quotient = integer($meanRightAscension/24);
$meanRightAscension -= 24*$quotient;

# time differences for the sun path
my $deltaSunriseSunset = deltat($hSun);                                   # time difference between sunrise and sunset
my $deltaCivilDawn = deltat($hDawnC);                                     # time difference for civil dawn
my $deltaNauticalDawn = deltat($hDawnN);                                  # time difference for nautical dawn
my $deltaAstronomicalDawn = deltat($hDawnA);                              # time difference for astronomical dawn

# time equation
my $lwtmlt = 1.0027379 * ($meanRightAscension - $RAh);

# calculation of times in local world time
my ($sunrise_lwt, $sunset_lwt) = lwt($deltaSunriseSunset);
my ($dawnMorningCivil_lwt, $dawnEveningCivil_lwt) = lwt($deltaCivilDawn);
my ($dawnMorningNautical_lwt, $dawnEveningNautical_lwt) = lwt($deltaNauticalDawn);
my ($dawnMorningAstronomical_lwt, $dawnEveningAstronomical_lwt) = lwt($deltaAstronomicalDawn);

# calculation of times in mean local time
my ($sunrise_mlt, $sunset_mlt) = mlt($sunrise_lwt, $sunset_lwt, $lwtmlt);
my ($dawnMorningCivil_mlt, $dawnEveningCivil_mlt) = mlt($dawnMorningCivil_lwt, $dawnEveningCivil_lwt, $lwtmlt);
my ($dawnMorningNautical_mlt, $dawnEveningNautical_mlt) = mlt($dawnMorningNautical_lwt, $dawnEveningNautical_lwt, $lwtmlt);
my ($dawnMorningAstronomical_mlt, $dawnEveningAstronomical_mlt) = mlt($dawnMorningAstronomical_lwt, $dawnEveningAstronomical_lwt, $lwtmlt);

# calculation of times in local time
my ($sunrise_lc, $sunset_lc) = lct($sunrise_mlt, $sunset_mlt, $timezone);
my ($dawnMorningCivil_lc, $dawnEveningCivil_lc) = lct($dawnMorningCivil_mlt, $dawnEveningCivil_mlt, $timezone);
my ($dawnMorningNautical_lc, $dawnEveningNautical_lc) = lct($dawnMorningNautical_mlt, $dawnEveningNautical_mlt, $timezone);
my ($dawnMorningAstronomical_lc, $dawnEveningAstronomical_lc) = lct($dawnMorningAstronomical_mlt, $dawnEveningAstronomical_mlt, $timezone);

# calculation with hours and minutes
my ($sunrise, $sunset) = ltime($sunrise_lc, $sunset_lc);
my ($dawnMorningCivil, $dawnEveningCivil) = ltime($dawnMorningCivil_lc, $dawnEveningCivil_lc);
my ($dawnMorningNautical, $dawnEveningNautical) = ltime($dawnMorningNautical_lc, $dawnEveningNautical_lc);
my ($dawnMorningAstronomical, $dawnEveningAstronomical) = ltime($dawnMorningAstronomical_lc, $dawnEveningAstronomical_lc);

# normalize times
my ($sunrise_norm, $sunset_norm) = norm($sunrise, $sunset);
my ($dawnMorningCivil_norm, $dawnEveningCivil_norm) = norm($dawnMorningCivil, $dawnEveningCivil);
my ($dawnMorningNautical_norm, $dawnEveningNautical_norm) = norm($dawnMorningNautical, $dawnEveningNautical);
my ($dawnMorningAstronomical_norm, $dawnEveningAstronomical_norm) = norm($dawnMorningAstronomical, $dawnEveningAstronomical);

# output
printf "Data for %s\n", $datetime;
printf "Latitude:                     %s\n", $lat;
printf "Longitude:                    %s\n", $lon;
printf "Timezone:                     UTC%1s%5s\n", $timezoneSign, $timezoneF;
printf "Azimuth:                      %s\n", $azimuthFormatted;
printf "Height:                       %s\n", $heightFormatted;
printf "Astronomical morning dawn at: %s\n", $dawnMorningAstronomical_norm;
printf "Nautical morning dawn at:     %s\n", $dawnMorningNautical_norm;
printf "Civil morning dawn at:        %s\n", $dawnMorningCivil_norm;
printf "Sunrise at:                   %s\n", $sunrise_norm;
printf "Sunset at:                    %s\n", $sunset_norm;
printf "Civil evening dawn at:        %s\n", $dawnEveningCivil_norm;
printf "Nautical evening dawn at:     %s\n", $dawnEveningNautical_norm;
printf "Astronomical evening dawn at: %s\n", $dawnEveningAstronomical_norm;


sub lct {
	my ($morning, $evening, $zone) = @_;
	my $mn = $morning - $longitude/$deltaLong + $zone;
	my $ev = $evening - $longitude/$deltaLong + $zone;
	return ($mn, $ev);
}


sub nameMonth {
	my $monthNumber = shift;
	return "January" if ($monthNumber == 1);
	return "February" if ($monthNumber == 2);
	return "March" if ($monthNumber == 3);
	return "April" if ($monthNumber == 4);
	return "May" if ($monthNumber == 5);
	return "June" if ($monthNumber == 6);
	return "July" if ($monthNumber == 7);
	return "August" if ($monthNumber == 8);
	return "September" if ($monthNumber == 9);
	return "October" if ($monthNumber == 10);
	return "November" if ($monthNumber == 11);
	return "December" if ($monthNumber == 12);
	return "$monthNumber";
}


sub formatTime {
	my $timeRaw = shift;
	my $hours = integer($timeRaw);
	my $minutes = 60 * ($timeRaw - $hours);
	my $timeFormatted = sprintf("%02u:%02u", $hours, $minutes);
	return $timeFormatted;
}


sub norm {
	my ($m, $e) = @_;
	my ($mh, $mm) = split(/:/,$m);
	my ($eh, $em) = split(/:/,$e);
	if(looks_like_number($mh) and looks_like_number($mm) and looks_like_number($eh) and looks_like_number($em)){
		$mh += 24 if ($mh < 0);
		$mh -= 24 if ($mh > 23);
		$eh += 24 if ($eh < 0);
		$eh -= 24 if ($eh > 23);
		my $mc = ($mh == $eh and $mm == $em) ? "--:--" : sprintf("%02u:%02u", $mh, $mm);
		my $ec = ($mh == $eh and $mm == $em) ? "--:--" : sprintf("%02u:%02u", $eh, $em);
		return ($mc, $ec);
	}
	return ($m, $e);
}


sub geoDegMinSec {
	my ($decimal, $dir) = @_;
	my $absDecimal = abs($decimal);
	my $grad = integer($absDecimal);
	my $rest = $absDecimal - $grad;
	my $arcminute = integer(60*$rest);
	my $remainder = abs(60*$rest - $arcminute);
	my $arcseconds = 60*$remainder;
	my $DIR;

	if ($decimal > 0){
		$DIR = $dir eq "lat" ? "N" : "E";
	} elsif ($decimal < 0){
		$DIR = $dir eq "lat" ? "S" : "W";
	} else {
		$DIR = " ";
	}
	my $returnvalue = sprintf("% 3d° %02d' %04.1f\" %1s", $grad, $arcminute, $arcseconds, $DIR);
}


sub degMinSec {
	my $decimal = shift;
	my $sign = $decimal < 0 ? "-" : "+";
	my $absDecimal = abs($decimal);
	my $grad = integer($absDecimal);
	my $rest = abs($absDecimal - $grad);
	my $arcminute = integer(60*$rest);
	my $remainder = abs(60*$rest - $arcminute);
	my $arcseconds = 60*$remainder;
	my $returnvalue = sprintf("%1s% 3u° %02d' %04.1f\"", $sign, $grad, $arcminute, $arcseconds);
}


sub formatData {
	my ($d, $mt, $y, $h, $m) = @_;
	my $day;
	my $month;
	if (length($d) == 2){
		my $leadingDay = substr($d,0,1);
		if($leadingDay eq "0"){
			$day = substr($d,1);
		} else {
			$day = $d;
		}
	} else {
		$day = $d;
	}
	if (length($mt) == 2){
		my $leadingMonth = substr($mt,0,1);
		if($leadingMonth eq "0"){
			$month = substr($mt,1);
		} else {
			$month = $mt;
		}
	} else {
		$month = $mt;
	}
	return ($day, $month, $y, $h, $m);
}


sub ltime {
	my ($morning, $evening) = @_;
	my %mtime;
	my %etime;
	$mtime{hour} = integer($morning);
	$etime{hour} = integer($evening);
	$mtime{minute} = integer(60*($morning - $mtime{hour}));
	$etime{minute} = integer(60*($evening - $etime{hour}));
	if($mtime{hour} == $etime{hour} and $mtime{minute} == $etime{minute}){
		return ("--:--", "--:--");
	} else {
		return (sprintf("%02u:%02u", $mtime{hour}, $mtime{minute}),sprintf("%02u:%02u", $etime{hour}, $etime{minute}));
	}
}


sub lwt {
	my $timeDifference = shift;
	my $morning = 12 - $timeDifference;
	my $evening = 12 + $timeDifference;
	return ($morning, $evening);
}


sub mlt {
	my ($morning_a, $evening_a, $add_ab) = @_;
	my $morning_b = $morning_a + $add_ab;
	my $evening_b = $evening_a + $add_ab;
	return ($morning_b, $evening_b);
}


sub printExit {
	print "Usage: ./sun <parameter file name> <day> <month> <year> <hour> <minute>\n";
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
	my $file = shift;
	my %parameters;
	open(FILE, $file) || die "cannot open parameter file";
	while (my $line = <FILE>){
		my @temp = split(/[ \t]+/,$line);
		$parameters{lc($temp[0])} = $temp[1];
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


sub integer {
	my $val = shift;
	return 0 if (!looks_like_number($val));
	if($val < 0){
		return ceil($val);
	} else {
		return floor($val);
	}
}


sub deltat {
	my $h = shift;
	my $res = 12*acos((sin($h)-(sin($B)*sin($declination)))/(cos($B)*cos($declination)))/$pi;
	return $res;
}
