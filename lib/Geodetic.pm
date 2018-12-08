#!/usr/bin/perl -w

# Package declaration:
package Geodetic;

# Import useful modules:
use strict;      # enables strict syntax...

use Data::Dumper;

use Math::Trig;      # trigonometry functions...
use feature qq(say); # same as print but adding a carriage jump...

# Set package exportation properties:
# ---------------------------------------------------------------------------- #
BEGIN {
  # Load export module:
  require Exporter;

  # Set package version:
  our $VERSION = 1.0;

  # Inherit from Exporter to export subs and constants:
  our @ISA = qq(Exporter);

  # Default export:
  our @EXPORT = ();

  # Define constants to export:
  our @EXPORT_CONST = qw( &SPEED_OF_LIGHT
                          &GRAV_CONSTANT
                          &EARTH_MASS
                          &EARTH_GRAV_CONST
                          &EARTH_MEAN_RADIUS
                          &EARTH_ANGULAR_SPEED
                          &ELIPSOID_DATABASE );

  # Define subroutines to export:
  our @EXPORT_SUB   = qw( &ModulusNth
                          &Venu2AzZeDs
                          &Venu2Vxyz
                          &Vxyz2Venu
                          &Geodetic2ECEF
                          &ECEF2Geodetic );

  # Merge constants and subroutines:
  our @EXPORT_OK = (@EXPORT_CONST, @EXPORT_SUB);

  # Define export tags:
  our %EXPORT_TAGS = ( ALL         => \@EXPORT_OK,
                       DEFAULT     => \@EXPORT,
                       CONSTANTS   => \@EXPORT_CONST,
                       SUBROUTINES => \@EXPORT_SUB );
}

# ---------------------------------------------------------------------------- #
# Preliminary subroutine:
# ---------------------------------------------------------------------------- #
sub LoadElipsoidEntries {
  # Init master elipsoid hash:
  my %elip_entries; my $ref_elip_entries;

  # Set elipsoid base parameters --> Semi-major axis and flattening factor:
  # WGS84:
  my %wgs84 = ( SEMIMAJOR_AXIS => 6378137.000,
                FLATTENING     => 1/298.2572235630 );

  # GRS80:
  my %grs80 = ( SEMIMAJOR_AXIS => 6378137.000,
                FLATTENING     => 1/298.2572221010 );


  # Hayford:
  my %hayford = ( SEMIMAJOR_AXIS => 6378388.000,
                  FLATTENING     => 1/297.000 );


  # Add entries to elipsoid dicctionary:
  $ref_elip_entries->{WGS84}   = \%wgs84;
  $ref_elip_entries->{GRS80}   = \%grs80;
  $ref_elip_entries->{HAYFORD} = \%hayford;

  # Compute rest of elipsoid parameters for all entries:
  for my $elip (keys $ref_elip_entries)
  {
    my ($a, $f) =
       ($ref_elip_entries->{$elip}{SEMIMAJOR_AXIS},
        $ref_elip_entries->{$elip}{FLATTENING});

    # Semi-minor axis:
    my $b = $a - ($f*$a);
    $ref_elip_entries->{$elip}{SEMIMINOR_AXIS} = $b;

    # First eccentricity:
    my $e_first = (($a**2 - $b**2)**0.5)/$a;
    $ref_elip_entries->{$elip}{FIRST_ECCENTRICITY} = $e_first;

    # Second eccentricity:
    my $e_second = (($a**2 - $b**2)**0.5)/$b;
    $ref_elip_entries->{$elip}{SECOND_ECCENTRICITY} = $e_second;
  }

  # Return elipsoid dicctionary:
  return $ref_elip_entries;
}


# ---------------------------------------------------------------------------- #
# Constants:
# ---------------------------------------------------------------------------- #
# Astronomical parameters:
use constant SPEED_OF_LIGHT => 299792458.0; # [m/s]
use constant GRAV_CONSTANT  => 6.674e-11;   # [N*m2/kg2]

# Earth properties:
use constant EARTH_ANGULAR_SPEED => 7.2921151467e-5; # [rad/s]
use constant EARTH_MEAN_RADIUS   => 6371000.0;       # [m]
use constant EARTH_MASS          => 5.9736e24;       # [kg]
use constant EARTH_GRAV_CONST    => 3.986005e+14;    # TODO:??
use constant ELIPSOID_DATABASE   => LoadElipsoidEntries();


# ---------------------------------------------------------------------------- #
# Subroutines:
# ---------------------------------------------------------------------------- #
sub ModulusNth {
  my @vector = @_;

  # Init variable to hold the squared summatory:
  my $square_sum  = 0;
     $square_sum += $_**2 for (@vector);

  # Return the square root of the summatory:
  return $square_sum**0.5;
}

sub ECEF2Geodetic {
  my ($x, $y, $z, $elip, $iter) = @_;

  # Default iterations are set to 10 unless specified in the arguments:
  $iter = 10 unless $iter;

  # Load elipsoid parameters:
  my $ref_elip_prm = &ELIPSOID_DATABASE->{$elip};
  my ( $a2, $b2, $e2) =
     ( $ref_elip_prm->{SEMIMAJOR_AXIS}**2,
       $ref_elip_prm->{SEMIMINOR_AXIS}**2,
       $ref_elip_prm->{FIRST_ECCENTRICITY}**2 );

  # Init geodetic coorinates to return:
  my ($lat, $lon, $h); # latitude, longitude and elipsoidal height...

  # Computation sequence:
    # Longitude is computed as:
    $lon = atan2($y, $x);

    # Modulus over equatorial plane (auxiliar variable):
    my $p = ($x**2 + $y**2)**0.5;

    # Latitude and height are computed using an iterative process:
    $lat = atan( ($z/$p)*(1/(1 - $e2)) ); # first value...
    for (1..$iter) {
      my $n    = $a2/( $a2*cos($lat)**2 + $b2*sin($lat)**2 )**0.5;
         $h    = ($p/cos($lat)) - $n;
         $lat  = atan( ($z/$p)*(1/(1 - $e2*( $n/($n + $h) ))) );
    }

  # Return geodetic coordinates:
  return ($lat, $lon, $h);
}

sub Geodetic2ECEF {
  my ($lat, $lon, $h, $elip) = @_;

  # Init ECEF coordintes to return:
  my ($x, $y, $z);

  # Load elipsoid parameters:
  my $ref_elip_prm = &ELIPSOID_DATABASE->($elip);
  my ($a, $b) = ($ref_elip_prm->{SEMIMAJOR_AXIS},
                 $ref_elip_prm->{SEMIMINOR_AXIS});

  # Computation sequence:
    # Get prime's vertical curvature radius:
    my $nu = PrimeVerticalRadius($lat, $elip);

    # Coordinates are computed as follows:
    $x = ($nu + $h)*cos($lat)*cos($lon);
    $y = ($nu + $h)*cos($lat)*sin($lon);
    $z = ($nu*($b**2/$a**2) + $h)*sin($lat);

  # Return ECEF coordinates:
  return ($x, $y, $z);
}

sub Vxyz2Venu {
  my ($ix, $iy, $iz, $lat, $lon) = @_;

  # ECEF vector transofmation to a gedetic position is computed as follows:
  my ( $ie, $in, $iu ) =
     ( -1*$ix*sin($lon)           + $iy*cos($lon),
       -1*$ix*sin($lat)*cos($lon) - $iy*sin($lat)*sin($lon) + $iz*cos($lat),
          $ix*cos($lat)*cos($lon) + $iy*cos($lat)*sin($lon) + $iz*sin($lat) );

  # Return local vector components:
  return ($ie, $in, $iu);
}

# TODO: Vector transformation from local (lat, lon) to ECEF....
sub Venu2Vxyz {}

sub Venu2AzZeDs {
  my ($ie, $in, $iu) = @_;

  # Azimut:
  my $azimut  = pi/2 - atan2($in, $ie);
     $azimut += 2*pi if $azimut < 0;

  # Geometric distance and ortonormal distance (proyected distance over the
  # local plane):
  my $geom_dist = ModulusNth($ie, $in, $iu);
  my $orto_dist = ModulusNth($ie, $in);

  # Zenital angle:
  my $zenital = pi/2 - atan($iu/$orto_dist);

  # Return parameters:
  return ($azimut, $zenital, $geom_dist);
}

sub PrimeVerticalRadius {
  my ($lat, $elip) = @_;

  # TODO: Check elipsoid argument

  # Load elipsoid parameters:
  my $ref_elip_prm = &ELIPSOID_DATABASE->{$elip};
  my ($a, $e2) =
     ($ref_elip_prm->{SEMIMAJOR_AXIS},
      $ref_elip_prm->{FIRST_ECCENTRICITY}**2);

  # Prime's vertical radius is computed as follows:
  my $nu = ( $a/(1 - $e2*(sin($lat))**2)**0.5 );

  # Return prime's vertical curvature radius:
  return $nu;
}

1;
