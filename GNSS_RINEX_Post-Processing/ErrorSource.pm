#!/usr/bin/perl -w

# Package declaration:
package ErrorSource;


# SCRIPT DESCRIPTION GOES HERE:

# Import Modules:
# ---------------------------------------------------------------------------- #
use strict;   # enables strict syntax...

use Math::Trig;                         # load trigonometry methods...
use Scalar::Util qq(looks_like_number); # scalar utility...

use feature qq(say); # print adding carriage return...
use Data::Dumper;    # enables pretty print...

# Import configuration and common interface module:
use lib qq(/home/ppinto/TFM/src/);
use GeneralConfiguration qq(:ALL);

# Import dedicated libraries:
use lib qq(/home/ppinto/TFM/src/lib/); # TODO: this should be an enviroment!
use MyUtil   qq(:ALL); # useful subs and constants...
use MyMath   qq(:ALL); # useful mathematical methods...
use MyPrint  qq(:ALL); # error and warning utilities...
use TimeGNSS qq(:ALL); # GNSS time transforming utilities...

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
  our @EXPORT_CONST = qw(  );

  # Define subroutines to export:
  our @EXPORT_SUB   = qw( &ComputeTropoSaastamoinenDelay
                          &ComputeIonoKlobucharDelay
                          &ComputeIonoNeQuickDelay );

  # Merge constants and subroutines:
  our @EXPORT_OK = (@EXPORT_CONST, @EXPORT_SUB);

  # Define export tags:
  our %EXPORT_TAGS = ( ALL         => \@EXPORT_OK,
                       DEFAULT     => \@EXPORT,
                       CONSTANTS   => \@EXPORT_CONST,
                       SUBROUTINES => \@EXPORT_SUB );

}


# ---------------------------------------------------------------------------- #
# Constants:
# ---------------------------------------------------------------------------- #
use constant SAASTAMOINEN_B_DOMAIN =>
  [0.0e3, 0.5e3, 1.0e3, 1.5e3, 2.0e3, 2.5e3, 3.0e3, 4.0e3, 5.0e3]; # [m]
use constant SAASTAMOINEN_B_RANGE  =>
  [1.156, 1.079, 1.006, 0.938, 0.874, 0.813, 0.757, 0.654, 0.563]; # [m]

# ---------------------------------------------------------------------------- #
# Subroutines:
# ---------------------------------------------------------------------------- #

# Public Subroutines: #
# ............................................................................ #
sub ComputeTropoSaastamoinenDelay {
  my ($zenital, $height) = @_; # [rad], [m]

  # Computation seuquence:
    # Temperature estimation [K]:
    my $temp = 291.15 - 0.0065*$height;

    # Pressure estimation [mb]:
    my $press = 1013.25*(1 - 0.000065*$height)**(5.225);

    # Humidity estimation [%]:
    my $humd = 50*exp(-1*0.0006396*$height);

    # Partial pressure of water vapor [mb]:
    my $pwv = ($humd*0.01)*exp(-37.2465 + 0.213166 - (0.000256908*$temp**2));

    # Interpolation of 'B' [m] --> correction acounting for elipsoidal height:
    my $b_prm = LinearInterpolationFromTable( $height,
                                              SAASTAMOINEN_B_DOMAIN,
                                              SAASTAMOINEN_B_RANGE );

  # Troposhperic delay correction is computed as follows:
    # Auxiliar variables:
    my $aux1 = (0.002277/cos($zenital));
    my $aux2 = (1255/$temp) + 0.05;
    # Computed delay:
    my $dtropo = $aux1*($press + $aux2*$pwv - $b_prm*(tan($zenital))**2);

  # Return tropospheric delay:
  return $dtropo; # [m]
}

sub ComputeIonoKlobucharDelay {
  my ( $ref_iono_alpha, $ref_iono_beta,
       $ref_sat_position_ecef, $ref_rec_position_ecef, $gps_epoch ) = @_;

  # De-reference input arguments:
  my @iono_alpha_prm    = @{ $ref_iono_alpha        };
  my @iono_beta_prm     = @{ $ref_iono_beta         };
  my @sat_position_ecef = @{ $ref_sat_position_ecef };
  my @rec_position_ecef = @{ $ref_rec_position_ecef };

  # Preliminary steps:
    # Set elipsoid:
    my $elip = 'WGS84'; # TODO: retrieve elipsoid from configuration!

    # Receiver coordinate transformation: ECEF --> Geodetic
    # Latitude [rad], Longitude [rad] and Elipsoidal Height [m]:
    my ($lat_rec, $lon_rec, $h_rec) = ECEF2Geodetic(@rec_position_ecef, $elip);

    # Vector transformation: Rec-Sat ECEF --> Rec-Sat ENU [m]
    my ($ie, $in, $iu) =
       Vxyz2Venu(($rec_position_ecef[0] - $sat_position_ecef[0]),
                 ($rec_position_ecef[1] - $sat_position_ecef[1]),
                 ($rec_position_ecef[2] - $sat_position_ecef[2]),
                  $lat_rec, $lon_rec);

    # Vector transformation:
    #  Local ENU vector to Azimut [rad], Zenital [rad] and Distance [m]:
    my ($azimut, $zenital, $geom_dist) = Venu2AzZeDs($ie, $in, $iu);
    my $elevation = pi/2 - $zenital; # receiver-satellite elevation angle...

    # Elevation from rad to semicircles:
    $elevation /= pi;

    # Time transfomation: GPS --> Num_week, Num_day, ToW [s]
    my ($week, $day, $tow) = GPS2ToW($gps_epoch);

  # Computation sequence:
    # Necessary transformations:
      # Receiver latitude and longitude: [rad] --> [semicircles]
      $lat_rec /= pi; $lon_rec /= pi;

      # Receiver-Satellite elevation: [rad] --> [semicircles]
      $elevation /= pi;

    # Compute earth center angle [semicircles]:
    my $earth_center_angle = (0.0137/($elevation + 0.11)) - 0.022;

    # Compute IPP's geodetic coordinates:
      # IPP's latitude [semicircles]:
      my $lat_ipp = $lat_rec + $earth_center_angle*cos($azimut);

        # Latitude boundary protection:
        $lat_ipp =    0.416 if ($lat_ipp >    0.416);
        $lat_ipp = -1*0.416 if ($lat_ipp < -1*0.416);

      # IPP's longitude [semicircles]:
      # NOTE: Cosine's argument is transformaed [semicircles] --> [rad]
      my $lon_ipp =
         $lon_rec + ( $earth_center_angle*sin($azimut) )/( cos($lat_ipp*pi) );

      # IPP's geomagnetic latitude [semicircles]:
      # NOTE: Sinus's argument is transformed [semicircles] --> [rad]
      my $geomag_lat_ipp = $lat_ipp + 0.064*cos( ($lon_ipp - 1.617)*pi );

      # Local time at IPP [s]:
      my $time_ipp  = SECONDS_IN_DAY/2 * $lon_ipp + $tow;
         $time_ipp -= SECONDS_IN_DAY if ($time_ipp >= SECONDS_IN_DAY);
         $time_ipp += SECONDS_IN_DAY if ($time_ipp < 0.0 );

    # Compute ionospheric delay amplitude [s]:
    my $iono_amplitude  = 0;
       $iono_amplitude += $iono_alpha_prm[$_]*$geomag_lat_ipp**$_ for (0..3);
       $iono_amplitude  = 0 if ($iono_amplitude < 0);

    # Compute ionospheric delay period [s]:
    my $iono_period  = 0;
       $iono_period += $iono_beta_prm[$_]*$geomag_lat_ipp**$_ for (0..3);
       $iono_period  = 72000 if ($iono_period < 72000);

    # Compute ionospheric delay phase [rad]:
    my $iono_phase = ( 2*pi*($time_ipp - 50400) ) / $iono_period;

    # Compute slant factor delay [m¿?]:
    my $slant_fact = 1.0 + 16.0*(0.53 - $elevation)**3;

    # Compute ionospheric time delay for L1 [m]:
    my $iono_delay_l1;
    # Depending of the absolue magnitude of the phase delay, delay for L1 signal
    # is computed as:
    if ( abs($iono_phase) <= 1.57 ) {
      my $aux1       = 1 - ($iono_phase**2/2) + ($iono_phase**4/24);
      $iono_delay_l1 = ( 5.1e-9 + $iono_amplitude*$aux1 ) * $slant_fact;
    } elsif ( abs($iono_phase) >= 1.57 ) {
      $iono_delay_l1 = 5.1e-9 * $slant_fact;
    }

    # TODO: Compute ionospheric time delay for L2 [m]:
    my $iono_delay_l2;


  # Return ionospheric delays for both frequencies:
  return ($iono_delay_l1, $iono_delay_l2)
}

sub ComputeIonoNeQuickDelay {}

# Private Subroutines: #
# ............................................................................ #


TRUE;
