#!/usr/bin/perl

# Package declaration:
package TimeGNSS;

# Import useful modules:
use Carp;
use strict;
use warnings;

use Time::Local;
use feature qq(say);

use Math::Trig;

# Set package exportation properties:
BEGIN {
  # Load export module:
  require Exporter;

  # Set package version:
  our $VERSION = 1.0;

  # Inherit from Exporter to export subs and constants:
  our @ISA = qq(Exporter);

  # Default export:
  our @EXPORT = ();

  # All subroutines and constats to export:
  our @EXPORT_OK = qw( &BuildDateString
                       &Date2DoY
                       &Date2GPS
                       &GPS2Date
                       &GPS2DateString
                       &GPS2ToW
                       &Date2UniversalTime
                       &UniversalTime2LocalTime
                       &ComputeSatSysTimeCorrection
                       &TimeOfWeekInterpProtection
                       &SECONDS_IN_DAY
                       &SECONDS_IN_HOUR
                       &SECONDS_IN_WEEK
                       &SECONDS_IN_MINUTE
                       &MINUTES_IN_HOUR
                       &MINUTES_IN_DAY
                       &MINUTES_IN_WEEK
                       &MONTH_NAMES
                       &WEEK_DAY_NAMES );

  # Define export tags:
  our %EXPORT_TAGS = ( DEFAULT => [],
                       ALL     => \@EXPORT_OK );
}


# Constants:
# ---------------------------------------------------------------------------- #
# Number of seconds in...
use constant {
  SECONDS_IN_MINUTE => 60,
  SECONDS_IN_HOUR   => 3600,   # = SECONDS_IN_MINUTE*60
  SECONDS_IN_DAY    => 86400,  # = SECONDS_IN_HOUR*24
  SECONDS_IN_WEEK   => 604800, # = SECONDS_IN_DAY*7
};

# Number of minutes in...
use constant {
  MINUTES_IN_HOUR => 60,
  MINUTES_IN_DAY  => 1440,  # = MINUTES_IN_HOUR*24
  MINUTES_IN_WEEK => 10080, # = MINUTES_IN_DAY*7
};

# Months and week names:
use constant MONTH_NAMES    =>
  qw(Jan Feb Mar Apr May Jun Jul Agu Sep Oct Nov Dec);
use constant WEEK_DAY_NAMES =>
  qw(Monday Thuesday Wednesday Thursday Friday Saturday Sunday);

# Unix to GPS offset:
use constant UNIX_GPS_OFFSET => 315964800;


# Subroutines:
# ---------------------------------------------------------------------------- #
sub BuildDateString {
  my ($yyyy, $mo, $dd, $hh, $mi, $ss) = @_;

  my $date = sprintf( "%04d/%02d/%02d %02d:%02d:%02d",
                      $yyyy, $mo, $dd, $hh, $mi, $ss );

  return $date;
}

sub Date2DoY {
  my ($yyyy, $mo, $dd, $hh, $mi, $ss) = @_;

  # Retrive unix posix time from the begining of the year. This is
  # the first of January (month 0). Then, retrieve the unix posix
  # time from the input date:
  my $year_t0_time = timegm( 00,  00,  00,   1,       0, $yyyy);
  my $current_time = timegm($ss, $mi, $hh, $dd, $mo - 1, $yyyy);

  # Compute elapsed seconds:
  my $time_diff = $current_time - $year_t0_time;

  # Add 1 to day of year since day 0 (01/01) is day 1:
  return int( $time_diff/SECONDS_IN_DAY ) + 1;
}

sub Date2GPS {
  my ($yyyy, $mo, $dd, $hh, $mi, $ss) = @_;

  # 'timegm' method in scalar context returns the POSIX timestamp. This is the
  # number of elapsed seconds since 1970/01/01 (UNIX time):
  my $unix_time = timegm($ss, $mi, $hh, $dd, $mo - 1, $yyyy);

  # To convert POSIX timestamp into GPS time format, the offset between UNIX
  # and GPS time must be substracted:
  return $unix_time - UNIX_GPS_OFFSET;
}

sub GPS2Date {
  my ($gps_time) = @_;

  # 'gmtime' method returns GM time using UNIX reference. This is the
  # 1970/01/01. In order to provide the GPS time, the UNIX to GPS offset must
  # be added:
  my ( $sec, $min, $hour,
       $day, $mon, $year,
       $wday, $yday, $isdst ) = gmtime($gps_time + UNIX_GPS_OFFSET);

  # 'gmtime' method returns the year offset since 1900 and the months numerated
  # from 0 to 11:
  return ($year + 1900, $mon + 1, $day, $hour, $min, $sec);
}

sub GPS2DateString {
  my ($gps_time) = @_;
  return BuildDateString(GPS2Date($gps_time));
}

sub GPS2ToW {
  my ($gps_time) = @_;

  # Compute the elapsed weeks and days using the GPS time which is the number of
  # elpased seconds since GPS reference -> 1980/01/06 00:00:00:
  my $elapsed_weeks = $gps_time/SECONDS_IN_WEEK;
  my $elpased_days  = $gps_time/SECONDS_IN_DAY;

  my ($week_number, $day_number, $time_of_week);
  # The integer part of the previous division is the number of elapsed weeks,
  # the decimal part corresponds to the number of elapsed seconds in the week:
  $week_number  = int( $elapsed_weeks );
  $day_number   = int( $elpased_days  );
  $time_of_week = ( $elapsed_weeks - $week_number ) * SECONDS_IN_WEEK;

  # Returned values are the week number and the time of week (ToW):
  return ($week_number, $day_number, $time_of_week);
}

sub Date2UniversalTime {
  my ($yyyy, $mo, $dd, $hh, $mi, $ss) = @_;

  # NOTE: year, month and day are not relevant in subroutine. However, they
  #       are kept for interface consistency

  return $hh + $mi/MINUTES_IN_HOUR + $ss/SECONDS_IN_HOUR;
}

sub UniversalTime2LocalTime {
  my ( $longitude, $universal_time ) = @_;

  # NOTE: $longitude must be in radians!
  #       $universal_time must be hour decimal format! --> hh.dddd

  # Longitude is transformed to degrees:
  $longitude *= 180/pi;

  # Magic number '15' is the degree arc resulting from dividing 360º (whole
  # earth's circumference) between 24 hours:
  return $universal_time + $longitude/15; # [hour decimal]
}

sub ComputeSatSysTimeCorrection {
  my ($tow, $week, $a0, $a1, $tow_0, $week_0) = @_;

  my $time_corr = $a0 + $a1*($tow - $tow_0 + SECONDS_IN_WEEK*($week - $week_0));

  return $time_corr;
}

sub TimeOfWeekInterpProtection {
  my ($tow) = @_;

  if    ($tow >  1*SECONDS_IN_WEEK/2) { $tow -= SECONDS_IN_WEEK; }
  elsif ($tow < -1*SECONDS_IN_WEEK/2) { $tow += SECONDS_IN_WEEK; }

  return $tow;
}

1;
