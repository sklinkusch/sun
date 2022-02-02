# sun

This Perl script shows relevant data for the sun path, sunrise, sunset, and
twilight at a certain place, given by its decimal geocoordinates and its
timezone.

## Files

This script suite consists of the following files:

- `sun.pl`: the executable Perl script
- `sun.dat`: an example parameter file containing the geocoordinates and the
  timezone

### Structure of the parameter file

This is an example for a parameter file. The geocoordinates are for the
[Brandenburg Gate in Berlin](https://en.wikipedia.org/wiki/Brandenburg_Gate),
the timezone is the Central European Summer Time (UTC+2.00)

```
latitude  52.516389
longitude 13.377778
timezone  Europe/Berlin
```

The order of the three items is arbitrary. Each line has to begin with one of
the three keywords (latitude, longitude, and timezone), then comes a whitespace
(or several ones or tabs), and finally the **decimal** value for the
geocoordinates. The latitude is positive for the northern hemisphere, negative
for the southern hemisphere. The longitude is positive for all places to the
east of the Greenwich meridian and negative for all places to the west. The
timezone is defined according to the tz database. A list of timezones is given
[here](https://en.wikipedia.org/wiki/List_of_tz_database_time_zones).

# Usage

The script is called by the command

```
sun.pl sun.dat 21 08 2020 14 47
```

## Parameters

- **sun.dat** is the path to the parameter file
- **21** is the day
- **08** is the month (_August_), not necessarily with a leading zero (8 is
  correct, too)
- **2020** is the year (must be greater or equal to 2000)
- **14** is the hour
- **47** is the minute

## Output

The output for the example parameter file and the command as given above is as follows:

```
Data for 21.08.2020, 14:47 Local Time(UTC+2.00)
Latitude: +52° 30' 59.0"
Longitude: +13° 22' 40.0"
Timezone: UTC+2.00
Azimuth: +34° 44' 16.6"
Height: +44° 51' 46.3"
Astronomical morning dawn at: 03:34
Nautical morning dawn at: 04:30
Civil morning dawn at: 05:17
Sunrise at: 05:55
Sunset at: 20:13
Civil evening dawn at: 20:51
Nautical evening dawn at: 21:38
Astronomical evening dawn at: 22:34
```

The first four lines repeat the parameters read from the file and the input.
**_Azimuth_** is the angle from where the sun is shining (0° is in the South,
-90° is in the East, +90° is in the West). **_Height_** is the angle with
respect to the ground (0° is at the horizontal level, 90° is when the sun is in
the zenith). For the three different dawns (astronomical, nautical, and civil),
please refer to [this Wikipedia article](https://en.wikipedia.org/wiki/Twilight).
