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
my $hours = calcHours($hour, $minute, $timezone);    # hours since 12 utc


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