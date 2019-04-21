#!/usr/bin/perl -w

# NOTE: SCRIPT DESCRIPTION GOES HERE:

# Package declaration:
package SatPosition;

# Set package exportation properties:
# ---------------------------------------------------------------------------- #
BEGIN {
  # Load export module:
  require Exporter;

  # Set version check:
  our $VERSION = 1.0;

  # Inherit from Exporter to export subs and constants:
  our @ISA = qq(Exporter);

  # Default export:
  our @EXPORT = ();

  # Define constants to export:
  our @EXPORT_CONST = qw();

  # Define subroutines to export:
  our @EXPORT_SUB   = qw( &ComputeSatPosition );

  # Merge constants and subroutines:
  our @EXPORT_OK = (@EXPORT_CONST, @EXPORT_SUB);

  # Define export tags:
  our %EXPORT_TAGS = ( ALL         => \@EXPORT_OK,
                       DEFAULT     => \@EXPORT,
                       CONSTANTS   => \@EXPORT_CONST,
                       SUBROUTINES => \@EXPORT_SUB );
}

# Load bash enviroments:
# ---------------------------------------------------------------------------- #
use lib $ENV{ ENV_ROOT };
use Enviroments qq(:CONSTANTS);

# Import Modules:
# ---------------------------------------------------------------------------- #
use strict;   # enables strict syntax...

use Math::Trig;                         # load trigonometry methods...
use Scalar::Util qq(looks_like_number); # scalar utility...

use feature qq(say); # print adding carriage return...
use Data::Dumper;    # enables pretty print...

# Import configuration and common interface module:
use lib SRC_ROOT_PATH;
use GeneralConfiguration qq(:ALL);

# Import dedicated libraries:
use lib LIB_ROOT_PATH;
use MyUtil   qq(:ALL); # useful subs and constants...
use MyMath   qq(:ALL); # useful mathematical methods...
use MyPrint  qq(:ALL); # print error and warning methods...
use TimeGNSS qq(:ALL); # GNSS time transforming utilities...
use Geodetic qq(:ALL); # geodetic toolbox for coordinate transformation...

# Import dependent modules:
use lib GRPP_ROOT_PATH;
use RinexReader qq(:ALL); # observation & navigation rinex parser...
use ErrorSource qq(:ALL); # ionosphere & troposphere correction models...



# ---------------------------------------------------------------------------- #
# GLobal contants:
# ---------------------------------------------------------------------------- #

# Module specific warning codes:
use constant {
  WARN_OBS_NOT_VALID     => 90301,
  WARN_NO_SAT_NAVIGATION => 90303,
  WARN_NO_SAT_EPH_FOUND  => 90304,
};


# ---------------------------------------------------------------------------- #
# Subroutines:
# ---------------------------------------------------------------------------- #

# Public Subroutines:                                                          #
# ............................................................................ #
sub ComputeSatPosition {
  my ($ref_gen_conf, $ref_rinex_obs, $fh_log) = @_;

  # ************************* #
  # Input consistency checks: #
  # ************************* #

  # Check that $ref_gen_conf is a hash:
  unless ( ref($ref_gen_conf) eq 'HASH' ) {
    RaiseError($fh_log, ERR_WRONG_HASH_REF,
      ("Input argument \'$ref_gen_conf\' is not HASH type"));
    return KILLED;
  }

  # Check that $ref_rinex_obs is a hash:
  unless ( ref($ref_rinex_obs) eq 'HASH' ) {
    RaiseError($fh_log, ERR_WRONG_HASH_REF,
      ("Input argument \'$ref_rinex_obs\' is not HASH type"));
    return KILLED;
  }


  # ******************* #
  # Preliminary steps : #
  # ******************* #

  # Init hash to store navigation contents:
  my $ref_sat_sys_nav = {};

  # Read satellite navigation file and store its contents:
  for my $sat_sys (keys %{$ref_gen_conf->{RINEX_NAV_PATH}})
  {
    # Read file and build navigation hash which stores the navigation data:
    $ref_sat_sys_nav->{$sat_sys} =
      ReadNavigationRinex( $ref_gen_conf->{RINEX_NAV_PATH}{$sat_sys},
                           $sat_sys, $fh_log );
  }


  # ****************************** #
  # Compute satellite coordinates: #
  # ****************************** #

  # Iterate over the observation epochs:
  for (my $i = 0; $i < scalar(@{$ref_rinex_obs->{BODY}}); $i++)
  {
    # Save reference to epoch info:
    my $ref_epoch_data = $ref_rinex_obs->{BODY}[$i];

    # Save observation epoch:
    my $obs_epoch = $ref_epoch_data->{EPOCH};

    # Init valid navigation satellite counter:
    InitValidNavSatCounter( $ref_epoch_data,
                            $ref_gen_conf->{SELECTED_SAT_SYS} );

    # Check observation health status:
    unless ( $ref_epoch_data->{STATUS} == HEALTHY_OBSERVATION_BLOCK )
    {
      # Raise warning and jump to the next epoch:
      RasieWarning($fh_log, WARN_OBS_NOT_VALID,
        ("Observations from epoch: ".BiuldDateString(GPS2Date($obs_epoch))." ".
         "are flaged as not valid.",
         "Satellite position will not be computed!"));
      next;
    }

    # Iterate over the observed satellites in the epoch:
    for my $sat (keys %{$ref_epoch_data->{SAT_OBS}})
    {
      # Save constellation:
      my $sat_sys = substr($sat, 0, 1);

      # Init satelite navigation data status and coordinate array:
      my $sat_status; my @sat_coord;

      # Look for this constellation in the navigation hash:
      if (grep(/^$sat_sys$/, keys %{$ref_sat_sys_nav}))
      {
        # Save constellation navigation data:
        my $ref_nav_body = $ref_sat_sys_nav->{$sat_sys}{BODY};

        # Check that the navigation data is available for the selected
        # satellite:
        unless (exists $ref_nav_body->{$sat}) {

          # Set invalid data for satellite:
          $sat_status = FALSE;
          @sat_coord  = (0, 0, 0, 0);

          # Raise warning and skip code to next satellite:
          RaiseWarning($fh_log, WARN_NO_SAT_NAVIGATION,
            "Navigation ephemerids for satellite \'$sat\' could not be found");

        } else { # If satellite navigation data is available:

          # Determine best ephemerids to compute satellite coordinates:
          my $sat_eph_epoch = SelectNavigationBlock(
                                $ref_gen_conf->{EPH_TIME_THRESHOLD},
                                $obs_epoch, sort(keys %{$ref_nav_body->{$sat}})
                              );

          # Check that the ephemerids have been selected:
          unless ($sat_eph_epoch != FALSE) {

            # Set invalid data for satellite:
            $sat_status = FALSE;
            @sat_coord  = (0, 0, 0, 0);

            # Raise a warning and go to the next satellite:
            RaiseWarning($fh_log, WARN_NO_SAT_EPH_FOUND,
              "No navigation ephemerids were selected for satellite \'$sat\', ".
              "at observation epoch: ".BuildDateString(GPS2Date($obs_epoch)));

          } else { # If satellite ephemerids have been selected:

            # Save the ephemerid parameters for computing the satellite
            # coordinates:
            my $ref_sat_eph = $ref_nav_body->{$sat}{$sat_eph_epoch};

            # Retrieve observation measurement:
            my $signal =
               $ref_gen_conf->{SELECTED_SIGNALS}{$sat_sys};
            my $obs_meas =
               $ref_epoch_data->{SAT_OBS}{$sat}{$signal};

            # Do not compute satellite coordinates if the observation is not
            # valid:
            unless ($obs_meas eq NULL_OBSERVATION) {
              # Retrieve carrier frequencies:
              my ( $carrier_freq_f1, $carrier_freq_f2 ) =
                 ( $ref_gen_conf->{CARRIER_FREQUENCY}{$sat_sys}{F1},
                   $ref_gen_conf->{CARRIER_FREQUENCY}{$sat_sys}{F2} );

              # Compute satellite coordinates for observation epoch:
              ($sat_status, @sat_coord) =
                ComputeSatelliteCoordinates($obs_epoch,
                                            $obs_meas, $sat, $ref_sat_eph,
                                            $carrier_freq_f1, $carrier_freq_f2);
            } else {
              # Satellite coordintes cannot be computed:
              $sat_status = FALSE;
              @sat_coord  = (0, 0, 0, 0);
            } # end unless $obs_meas eq NULL_OBSERVATION

          } # end unless ($sat_eph_epoch != FALSE)
        } # end unless (exists $ref_nav_body->{$sat})

        # If the navigation status is valid, account for valid navgation
        # number of satellites:

        if ( $sat_status ) {
          CountValidNavigationSat( $sat_sys, $sat,
                                   $ref_epoch_data->{NUM_SAT_INFO} );
        }

        # Save the satellite position in the observation hash:
        $ref_epoch_data->{SAT_POSITION}{$sat}{NAV}{STATUS} = $sat_status;
        $ref_epoch_data->{SAT_POSITION}{$sat}{NAV}{XYZ_TC} = \@sat_coord;

      } # end if grep($sat, SUPPORTED_SAT_SYS)

    } # end for $sat
  } # end for $i

  # Return contellation navigation data hash:
  return $ref_sat_sys_nav;
}

# Private Subroutines:                                                         #
# ............................................................................ #
sub InitValidNavSatCounter {
  my ($ref_epoch_info, $ref_selected_sat_sys) = @_;

  for my $entry (@{ $ref_selected_sat_sys }, 'ALL') {
    $ref_epoch_info->{NUM_SAT_INFO}{$entry}{VALID_NAV}{NUM_SAT} = 0;
    $ref_epoch_info->{NUM_SAT_INFO}{$entry}{VALID_NAV}{SAT_IDS} = [];
  }

  return TRUE;
}

sub CountValidNavigationSat {
  my ($sat_sys, $sat_id, $ref_num_sat_info) = @_;

  # Account for cosntellation and ALL hash entries:
  for my $entry ($sat_sys, 'ALL') {
    $ref_num_sat_info->{$entry}{VALID_NAV}{NUM_SAT} += 1;
    PushUnique( $ref_num_sat_info->{$entry}{VALID_NAV}{SAT_IDS}, $sat_id );
  }

  return TRUE;
}

sub SelectNavigationBlock {
  my ($time_threshold, $obs_epoch, @sat_nav_epochs) = @_;

  # Init as undefined the selected navigation epoch:
  my $selected_nav_epoch;

  # Iterate over the ephemerids epochs:
  for my $nav_epoch (@sat_nav_epochs)
  {
    # The ephemerids epoch is selected if the time threshold is acomplished:
    if ( abs($obs_epoch - $nav_epoch) < $time_threshold ) {
      return $nav_epoch;
    }
  }

  # If no ephemerids have met the condition,
  # the subroutine returns a negative answer:
  return FALSE;
}

sub ComputeSatelliteCoordinates {
  my ($epoch, $obs_meas, $sat, $ref_eph,
      $carrier_freq_f1, $carrier_freq_f2) = @_;

  # Init algorithm status:
  my $status = FALSE;

  # Transform target epoch into GPS time of week format:
  my ( $wn, $dn, $tow ) = GPS2ToW($epoch);

  # ************************** #
  # Emission time computation: #
  # ************************** #

    # First iteration:
    my $time_recp  = $tow;
    my $time_emis1 =
       ($time_recp - ($obs_meas/SPEED_OF_LIGHT) - $ref_eph->{TOE});

    # Correct possible jumps due to interpolation
    if    ($time_emis1 >  1*SECONDS_IN_WEEK/2) {$time_emis1 -= SECONDS_IN_WEEK;}
    elsif ($time_emis1 < -1*SECONDS_IN_WEEK/2) {$time_emis1 += SECONDS_IN_WEEK;}

    # First satellite clock estimation:
    my ($a0, $a1, $a2) = ( $ref_eph->{SV_CLOCK_BIAS},
                           $ref_eph->{SV_CLOCK_DRIFT},
                           $ref_eph->{SV_CLOCK_RATE} );

    my $time_corr1 = $a0 + $a1*$time_emis1 + $a2*$time_emis1**2;

    # Second iteration:
    my $time_emis2 = $time_emis1 - $time_corr1;

    # Correct possible jumps due to interpolation
    if    ($time_emis2 >  1*SECONDS_IN_WEEK/2) {$time_emis2 -= SECONDS_IN_WEEK;}
    elsif ($time_emis2 < -1*SECONDS_IN_WEEK/2) {$time_emis2 += SECONDS_IN_WEEK;}

    # Second satellite clock estimation:
    my $time_corr2 = $a0 + $a1*$time_emis2 + $a2*$time_emis2**2;

    # Final emission time:
    my $time_emis = $time_emis2 - $time_corr2;

    # Correct possible jumps due to interpolation
    if    ($time_emis >  1*SECONDS_IN_WEEK/2) {$time_emis -= SECONDS_IN_WEEK;}
    elsif ($time_emis < -1*SECONDS_IN_WEEK/2) {$time_emis += SECONDS_IN_WEEK;}

  # ******************************************* #
  # Satellite coordinates computation sequence: #
  # ******************************************* #

    # Orbit's semi-major axis:
    my $a = $ref_eph->{SQRT_A}**2;

    # Mean motion:
    my $n = ((EARTH_GRAV_CONST/$a**3))**0.5 + $ref_eph->{DELTA_N};

    # Mean anomaly:
    my $m = $ref_eph->{MO} + $n*$time_emis;

    # Eccentricity anomaly:
      # It is computed by an itertive process where in the first iteration, the
      # eccentrcity anomaly is equals to the mean anomaly.
      my $e = $m;
      my $e_new = $m + $ref_eph->{ECCENTRICITY}*sin($e);

      # The iteration process goes on until the difference is below the
      # threshold or if the process has performed 10 steps:
      my $iter = 0;
      while ( abs($e - $e_new) > 1.0e-12 ) {
        $iter++; last if ($iter >= 10);
        $e = $e_new; $e_new = $m + $ref_eph->{ECCENTRICITY}*sin($e);
      }

      # Last computed value is saved as the ecentricity anomaly:
      $e = $e_new;

    # True anomaly:
    my $v = atan2( sin($e)*(1 - $ref_eph->{ECCENTRICITY}**2)**0.5,
                   cos($e)    - $ref_eph->{ECCENTRICITY} );

    # Latitude argument:
    my $phi0 = $v + $ref_eph->{OMEGA_2}; # NOTE: OMEGA_1 or OMEGA_2 ?!

    # Orbital correction terms:
      # NOTE: what do they mean these terms? --> physical meaning...
      my ( $delta_u, $delta_r, $delta_i ) =
         ( $ref_eph->{CUS}*sin(2*$phi0) + $ref_eph->{CUC}*cos(2*$phi0),
           $ref_eph->{CRS}*sin(2*$phi0) + $ref_eph->{CRC}*cos(2*$phi0),
           $ref_eph->{CIS}*sin(2*$phi0) + $ref_eph->{CIC}*cos(2*$phi0) );

      # Apply corrections to: latitude argument, orbital radius and inclination:
      my $phi = $phi0 + $delta_u;
      my $rad = $a*(1 - $ref_eph->{ECCENTRICITY}*cos($e)) + $delta_r;
      my $inc = $ref_eph->{IO} + $delta_i + $ref_eph->{IDOT}*$time_emis;

    # Orbital plane position:
    my ( $x_op, $y_op ) = ( $rad*cos($phi), $rad*sin($phi) );

    # Corrected ascending node longitude:
    my $omega = $ref_eph->{OMEGA_1} +
               ($ref_eph->{OMEGA_DOT} - EARTH_ANGULAR_SPEED)*$time_emis -
                EARTH_ANGULAR_SPEED*$ref_eph->{TOE};

    # Satellite coordinates:
    my ( $x_sat,
         $y_sat,
         $z_sat ) = ( $x_op*cos($omega) - $y_op*cos($inc)*sin($omega),
                      $x_op*sin($omega) + $y_op*cos($inc)*cos($omega),
                      $y_op*sin($inc) );

  # ********************** #
  # Final time correction: #
  # ********************** #

    # Relativistic effect clock correction:
    my $delta_trel =
      -2*( ((EARTH_GRAV_CONST * $a)**0.5)/(SPEED_OF_LIGHT**2) )*
      $ref_eph->{ECCENTRICITY}*sin($e);

    # Total group delay correction:
    my $delta_tgd = (($carrier_freq_f1/$carrier_freq_f2)**2)*$ref_eph->{TGD};

    # Compute final time correction:
    my $time_corr = $time_corr2 + $delta_trel - $delta_tgd;

  # Update algorithm status:
  $status = TRUE;

  # Return final satellite coordinates and time correction:
  return  ($status, $x_sat, $y_sat, $z_sat, $time_corr);
}

TRUE;
