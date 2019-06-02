#!/usr/bin/perl -w

# Package declaration:
package ErrorSource;


# SCRIPT DESCRIPTION GOES HERE:

# Load bash enviroments:
# ---------------------------------------------------------------------------- #
use lib $ENV{ ENV_ROOT };
use Enviroments qq(:CONSTANTS);

# Import Modules:
# ---------------------------------------------------------------------------- #
use strict;   # enables strict syntax...

use Math::Trig qq(pi);
use Scalar::Util qq(looks_like_number); # scalar utility...

use PDL;
use PDL::GSL::INTERP;

use feature qq(say); # print adding carriage return...
use Data::Dumper;    # enables pretty print...

# Import configuration and common interface module:
use lib SRC_ROOT_PATH;
use GeneralConfiguration qq(:ALL);

# Import dedicated libraries:
use lib LIB_ROOT_PATH;
use MyUtil   qq(:ALL); # useful subs and constants...
use MyMath   qq(:ALL); # useful mathematical methods...
use MyPrint  qq(:ALL); # error and warning utilities...
use Geodetic qq(:ALL); # geodesy methods and constants...
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
  our @EXPORT_SUB   = qw( &NullIonoDelay
                          &NullTropoDelay
                          &ComputeTropoSaastamoinenDelay
                          &ComputeIonoKlobucharDelay
                          &ComputeIonoNeQuickDelay );

  # Merge constants$rec_lon subroutines:
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

# Saastamoinen's B values:
use constant SAASTAMOINEN_B_DOMAIN =>
  [0.0e3, 0.5e3, 1.0e3, 1.5e3, 2.0e3, 2.5e3, 3.0e3, 4.0e3, 5.0e3]; # [m]
use constant SAASTAMOINEN_B_RANGE  =>
  [1.156, 1.079, 1.006, 0.938, 0.874, 0.813, 0.757, 0.654, 0.563]; # [m]

# Threshold for computing NeQuick ionophere correction as a vertical or slant
# ray approach:
use constant NEQUICK_SLANT_VERTICAL_THRESHOLD => 0.1e3; # [m]

# ---------------------------------------------------------------------------- #
# Subroutines:
# ---------------------------------------------------------------------------- #

# Public Subroutines: #
# ............................................................................ #
sub NullTropoDelay { return 0;      }

sub NullIonoDelay  { return (0, 0); }

sub ComputeTropoSaastamoinenDelay {
  my ($zenital, $height) = @_; # [rad], [m]

  # Height consistency check:
  # NOTE: ABMF's patch for negative heights:
  #  - Negative elipsoidal heights are considered 0
  #  - Heights above B range are considered as maximum B value
  $height = 0     if $height < 0;
  $height = 5.0e3 if $height > 5.0e3;

  # Computation sequence:
    # Temperature estimation [K]:
    my $temp = 291.15 - 0.0065*$height;

    # Pressure estimation [mb]:
    my $press = 1013.25*(1 - 0.000065*$height)**(5.225);

    # Humidity estimation [%]:
    my $humd = 50*exp(-1*0.0006396*$height);

    # Partial pressure of water vapor [mb]:
    my $pwv = ($humd*0.01)*exp(-37.2465 + 0.213166 - (0.000256908*$temp**2));

    # Interpolation of 'B' [m] --> correction acounting for elipsoidal height:
      # Define as PDL piddles B parameter's domain and range
      my $pdl_b_range  = pdl SAASTAMOINEN_B_RANGE;
      my $pdl_b_domain = pdl SAASTAMOINEN_B_DOMAIN;

      # Define B interpolation function (linear interpolation):
      my $pdl_interp_func = PDL::GSL::INTERP->init('linear',
                                                   $pdl_b_domain,
                                                   $pdl_b_range);

      # Interpolate B parameter:
      my $b_prm = $pdl_interp_func->eval($height);

  # Troposhperic delay correction is computed as followsx
    # Auxiliar variables:
    my $aux1 = (0.002277/cos($zenital));
    my $aux2 = (1255/$temp) + 0.05;
    # Computed delay:
    my $dtropo = $aux1*($press + $aux2*$pwv - $b_prm*(tan($zenital))**2);

  # Return tropospheric delay:
  # NOTE: apply piddle to scalar transformation
  return sclr($dtropo); # [m]
}

sub ComputeIonoKlobucharDelay {
  my ( $gps_epoch,
       $leap_sec,
       $ref_sat_xyz,
       $ref_rec_lat_lon_h,
       $azimut, $elevation,
       $ref_iono_alpha, $ref_iono_beta,
       $carrier_freq_f1, $carrier_freq_f2, $elip ) = @_;

  # say '$gps_epoch,
  #      $leap_sec,
  #      $ref_sat_xyz,
  #      $ref_rec_lat_lon_h,
  #      $azimut, $elevation,
  #      $ref_iono_alpha, $ref_iono_beta,
  #      $carrier_freq_f1, $carrier_freq_f2, $elip';
  #
  # print Dumper \@_;

  # De-reference input arguments:
    # GPS Alpha and Beta coefficients:
    my @iono_alpha_prm = @{ $ref_iono_alpha };
    my @iono_beta_prm  = @{ $ref_iono_beta  };

    # Receiver's geodetic position:
    my ($rec_lat, $rec_lon, $rec_helip) = @{ $ref_rec_lat_lon_h };

  # Preliminary steps:
    # Elevation from [rad] --> [semicircles]:
    $elevation /= pi;

    # Receiver latitude and longitude: [rad] --> [semicircles]
    $rec_lat /= pi; $rec_lon /= pi;

    # Time transfomation: GPS --> Num_week, Num_day, ToW [s]
    my ($week, $day, $tow) = GPS2ToW($gps_epoch);

  # Computation sequence:
    # Compute earth center angle [semicircles]:
    my $earth_center_angle = (0.0137/($elevation + 0.11)) - 0.022;

    # Compute IPP's geodetic coordinates:
      # IPP's latitude [semicircles]:
      my $ipp_lat = $rec_lat + $earth_center_angle*cos($azimut);

        # Latitude boundary protection:
        $ipp_lat =    0.416 if ($ipp_lat >    0.416);
        $ipp_lat = -1*0.416 if ($ipp_lat < -1*0.416);

      # IPP's longitude [semicircles]:
      # NOTE: Cosine's argument is transformaed [semicircles] --> [rad]
      my $ipp_lon =
         $rec_lon + ( $earth_center_angle*sin($azimut) )/( cos($ipp_lat*pi) );

      # IPP's geomagnetic latitude [semicircles]:
      # NOTE: Sinus's argument is transformed [semicircles] --> [rad]
      my $geomag_lat_ipp = $ipp_lat + 0.064*cos( ($ipp_lon - 1.617)*pi );

      # Local time at IPP [s]:
      my $ipp_time  = SECONDS_IN_DAY/2 * $ipp_lon + $tow;
         $ipp_time -= SECONDS_IN_DAY if ($ipp_time >= SECONDS_IN_DAY);
         $ipp_time += SECONDS_IN_DAY if ($ipp_time < 0.0 );

    # Compute ionospheric delay amplitude [s]:
    my $iono_amplitude  = 0;
       $iono_amplitude += $iono_alpha_prm[$_]*($geomag_lat_ipp**$_) for (0..3);
       $iono_amplitude  = 0 if ($iono_amplitude < 0);

    # Compute ionospheric delay period [s]:
    my $iono_period  = 0;
       $iono_period += $iono_beta_prm[$_]*$geomag_lat_ipp**$_ for (0..3);
       $iono_period  = 72000 if ($iono_period < 72000);

    # Compute ionospheric delay phase [rad]:
    my $iono_phase = ( 2*pi*($ipp_time - 50400) ) / $iono_period;

    # Compute slant factor delay [m¿?]:
    my $slant_fact = 1.0 + 16.0*(0.53 - $elevation)**3;

    # Compute ionospheric time delay for standard frequency [m]:
    my $iono_delay_f1;
    # Depending of the absolue magnitude of the phase delay, delay for L1 signal
    # is computed as:
    if ( abs($iono_phase) <= 1.57 ) {
      my $aux1       = 1 - ($iono_phase**2/2) + ($iono_phase**4/24);
      $iono_delay_f1 = ( 5e-9 + $iono_amplitude*$aux1 )*$slant_fact;
    } elsif ( abs($iono_phase) >= 1.57 ) {
      $iono_delay_f1 = 5e-9*$slant_fact;
    }

    # Transform ionospheric time delay into meters:
    $iono_delay_f1 *= SPEED_OF_LIGHT;

    # Compute ionospheric time delay for configured frequency [m]:
    my $iono_delay_f2 =
      ( ($carrier_freq_f1/$carrier_freq_f2)**2 )*$iono_delay_f1;

    # PrintTitle3(*STDOUT, "Ionosphere Klobuchar computed parameters:");
    # PrintBulletedInfo(*STDOUT, "\t\t - ",
    #   "Earth center angle = $earth_center_angle",
    #   "IPP's lat    = $ipp_lat",
    #   "IPP's lon    = $ipp_lon",
    #   "IPP's GM lat = $geomag_lat_ipp",
    #   "Iono delay amplitude = $iono_amplitude",
    #   "Iono delay period    = $iono_period",
    #   "Iono delay phase     = $iono_phase",
    #   "Slant factor         = $slant_fact",
    #   "Aux -> $aux1 = 1 - ($iono_phase**2/2) + ($iono_phase**4/24)",
    #   "Iono delay [s] -> ".$iono_delay_f1/SPEED_OF_LIGHT." = ( 5e-9 + $iono_amplitude*$aux1 )*$slant_fact",
    #   "Iono delay at F1     = $iono_delay_f1",
    #   "Iono delay at F2     = $iono_delay_f2");

  # Return ionospheric delays for both frequencies:
  return ($iono_delay_f1, $iono_delay_f2)
} # end sub ComputeIonoKlobucharDelay

sub ComputeIonoNeQuickDelay {
  my ( $gps_epoch,
       $leap_sec,
       $ref_sat_xyz,
       $ref_rec_lat_lon_h,
       $azimut, $elevation,
       $ref_iono_coeff, $ref_null_coeff,
       $carrier_freq_f1, $carrier_freq_f2, $elip ) = @_;

  # ***************** #
  # Preliminary steps #
  # ***************** #

    # De-reference input arguments:
    my ( $sat_x,   $sat_y,   $sat_z     ) = @{ $ref_sat_xyz       };
    my ( $rec_lat, $rec_lon, $rec_helip ) = @{ $ref_rec_lat_lon_h };

    # Retrieve Hour and Month from UTC time:
    my ( $year, $month, $day,
         $hour, $min,   $sec ) = GPS2Date( $gps_epoch - $leap_sec );

    # Retrieve universal time:
    my $ut_time = Date2UniversalTime( $year, $month, $day,
                                      $hour, $min,   $sec );

    # Compute local time:
    my $local_time = UniversalTime2LocalTime( $rec_lon, $ut_time );

    # Compute geodetic coordinates for satellite:
    my ( $sat_lat,
         $sat_lon,
         $sat_helip ) = ECEF2Geodetic( $sat_x, $sat_y, $sat_z, $elip );

    # Compute receiver-satellite spherical distance:
    my $rec_sat_sphere_dist = ComputeSphericalDistance( $rec_lat, $rec_lon,
                                                        $sat_lat, $sat_lon,
                                                        EARTH_MEAN_RADIUS );

  # ********************************* #
  # NeQuick delay computation routine #
  # ********************************* #

    # ***************************************** #
    # 1. MODIP computation at receiver location #
    # ***************************************** #
      my $modip = # [rad]
         ComputeMODIP( $rec_lat, $rec_lon );

    # **************************************** #
    # 2. Effective Ionisation Level &          #
    #    Effective Sunspot Number computation: #
    # **************************************** #
      my ($eff_iono_level, $eff_sunspot_number) = # [SFU], [n/a]
         ComputeEffectiveIonisationLevel( $ref_iono_coeff, $modip );

    # ************************************ #
    # 3. Obtain necessary Model Parameters #
    # ************************************ #
      my $ref_model_parameters = # [HASH]
         ComputeNeQuickModelParameters( $rec_lat, $rec_lon, $modip,
                                        $month, $ut_time, $local_time,
                                        $eff_iono_level, $eff_sunspot_number );

    # ********************************** #
    # 4. NeQuick G Slant TEC integration #
    # ********************************** #
      my $total_electron_content;

      if ( $rec_sat_sphere_dist > NEQUICK_SLANT_VERTICAL_THRESHOLD ) {
        $total_electron_content = # [TECU]
          IntegrateNeQuickSlantTEC(  );
      } else {
        $total_electron_content = # [TECU]
          IntegrateNeQuickVerticalTEC(  );
      }

    # *********************************************** #
    # 5. Delay computation for configured observation #
    # *********************************************** #
      my $nequick_iono_delay_f1 =
        ( 40.3/($carrier_freq_f1)**2 )*$total_electron_content;

      my $nequick_iono_delay_f2 =
        ( 40.3/($carrier_freq_f2)**2 )*$total_electron_content;


  return ($nequick_iono_delay_f1, $nequick_iono_delay_f2);
} # end sub ComputeIonoNeQuickDelay


# Private Subroutines: #
# ............................................................................ #


TRUE;
