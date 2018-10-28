#!/usr/bin/perl -w

# Package declaration:
package PositionLSQ;

# NOTE: SCRIPT DESCRIPTION GOES HERE:

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
use MyPrint  qq(:ALL); # print error and warning methods...
use TimeGNSS qq(:ALL); # GNSS time transforming utilities...
use Geodetic qq(:ALL); # geodetic toolbox for coordinate transformation...

# Import dependent modules:
use RinexReader qq(:ALL); # observation & navigation rinex parser...
use ErrorSource qq(:ALL); # ionosphere & troposphere correction models...


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
  our @EXPORT_SUB   = qw( &ComputeSatPosition
                          &ComputeRecPosition );

  # Merge constants and subroutines:
  our @EXPORT_OK = (@EXPORT_CONST, @EXPORT_SUB);

  # Define export tags:
  our %EXPORT_TAGS = ( ALL         => \@EXPORT_OK,
                       DEFAULT     => \@EXPORT,
                       CONSTANTS   => \@EXPORT_CONST,
                       SUBROUTINES => \@EXPORT_SUB );
}


# ---------------------------------------------------------------------------- #
# GLobal contants:
# ---------------------------------------------------------------------------- #

# Time threshold for selecting navigation ephemerids:
use constant TIME_THRESHOLD_NAV_EPH => (1.5 * SECONDS_IN_HOUR);

# Module specific warning codes:
use constant {
  WARN_OBS_NOT_VALID     => 90301,
  WARN_NO_SAT_NAVIGATION => 90303,
  WARN_NO_SAT_EPH_FOUND  => 90304,
};

# ---------------------------------------------------------------------------- #
# Subroutines:
# ---------------------------------------------------------------------------- #

# Public Subroutines: #
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
  my %sat_sys_nav; my $ref_sat_sys_nav = \%sat_sys_nav;

  # Read satellite navigation file and store its contents:
  for my $sat_sys (keys $ref_gen_conf->{RINEX_NAV_PATH})
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
  for (my $i = 0; $i < scalar(@{$ref_rinex_obs->{OBSERVATION}}); $i++)
  {
    # Save observation epoch:
    my $obs_epoch = $ref_rinex_obs->{OBSERVATION}[$i]{EPOCH};

    # Check observation health status:
    unless ( $ref_rinex_obs->{OBSERVATION}[$i]{STATUS} == 0 ) {
      # Raise warning and jump to the next epoch:
      RasieWarning($fh_log, WARN_OBS_NOT_VALID,
        ("Observations from epoch: ".BiuldDateString(GPS2Date($obs_epoch))." ".
         "are flaged as not valid.",
         "Satellite position will not be computed!"));
      next;
    }

    # Iterate over the observed satellites in the epoch:
    for my $sat (keys %{$ref_rinex_obs->{OBSERVATION}[$i]{SAT_OBS}})
    {
      # Save constellation:
      my $sat_sys = substr($sat, 0, 1);

      # Look for this constellation in the navigation hash:
      if (grep(/^$sat_sys$/, keys $ref_sat_sys_nav))
      {
        # Save constellation navigation data:
        my $ref_nav_body =
           $ref_sat_sys_nav->{$sat_sys}{NAVIGATION};

        # Check that the navigation data is available for the selected
        # satellite:
        unless (exists $ref_nav_body->{$sat}) {
          # Raise warning and go to the next satellite:
          RaiseWarning($fh_log, WARN_NO_SAT_NAVIGATION,
            "Navigation ephemerids for satellite $sat could not be found");
          next;
        }

        # Determine best ephemerids to compute satellite coordinates:
        my $sat_eph_epoch =
          SelectNavigationBlock($obs_epoch, sort( keys $ref_nav_body->{$sat} ));

        # Check that the ephemerids have been selected:
        unless ($sat_eph_epoch != FALSE) {
          # If not, raise a warning and go to the next satellite:
          RaiseWarning($fh_log, WARN_NO_SAT_EPH_FOUND,
            "No navigation ephemerids were selected for satellite $sat, ".
            "at observation epoch: ".BuildDateString(GPS2Date($obs_epoch)));
          next;
        }

        # Save the ephemerid parameters for computing the satellite
        # coordinates:
        my $ref_sat_eph = $ref_nav_body->{$sat}{$sat_eph_epoch};

        # TODO: Retrieve selected observation from configuration!
        # TODO: Discard null observations!
        my $obs_meas =
          $ref_rinex_obs->{OBSERVATION}[$i]{SAT_OBS}{$sat}{C1C};

        # Compute satellite coordinates for observation epoch:
        my @sat_coord =
          ComputeSatelliteCoordinates( $obs_epoch, $obs_meas,
                                       $sat, $ref_sat_eph );

        # Save the satellite position in the observation hash:
        $ref_rinex_obs->{OBSERVATION}[$i]{SAT_NAV}{$sat} = \@sat_coord;

      } # end if grep($sat, SUPPORTED_SAT_SYS)

    } # end for $sat
  } # end for $i

  # NOTE: Iterate over the satellites of the selected constellation from
  # $ref_sat_sys_list and those stored in the observation hash. For every
  # epoch and each satellite, the algorithm determines the most appropiate
  # ephemerids and from it computes the satellite coordinates for the
  # selected PRN, in the observation epoch.

  # NOTE: do we need the navigation data to be returned. Satellite positons are
  #       already in observation hash.
  return $ref_sat_sys_nav;
}

sub ComputeRecPosition {
  my ($ref_rinex_obs, $fh_log) = @_;

  # ************************* #
  # Input consistency checks: #
  # ************************* #
    # Reference to RINEX observation must be hash type:
    unless (ref($ref_rinex_obs) eq 'HASH') {
      RaiseError($fh_log, ERR_WRONG_HASH_REF,
        ("Input argument reference: \'$ref_rinex_obs\' is not HASH type"));
      return KILLED;
    }

  # ***************************************** #
  # Set estimation models from configuration: #
  # ***************************************** #
    # Troposphere model switch case:
    my $ref_sub_troposphere;

    # Ionosphere model switch case:
    my ($ref_sub_gps_ionosphere, $ref_sub_gal_ionosphere);


  # **************************** #
  # Position estimation routine: #
  # **************************** #

    # TODO: Init succesfully estimated epoch mask:
    my $first_solution_flag = FALSE;

    # Iterate over the observation epochs:
    for (my $i = 0; $i < scalar(@{$ref_rinex_obs->{OBSERVATION}}); $i += 1)
    {
      # Init receiver position solution info in observation hash:
      $ref_rinex_obs->{OBSERVATION}[$i]{POSITION_SOLUTION}{ XYZD  } = undef;
      $ref_rinex_obs->{OBSERVATION}[$i]{POSITION_SOLUTION}{ SIGMA } = undef;

      # Save epoch and observation health status:
      my ($epoch, $epoch_status) = ($ref_rinex_obs->{OBSERVATION}[$i]{EPOCH},
                                    $ref_rinex_obs->{OBSERVATION}[$i]{STATUS});

      # Discard invalid epochs:
      if ( $epoch_status == HEALTHY_OBSERVATION_BLOCK )
      {
        # Init solution convergence flag and iteration counter:
        my ($iteration, $convergence_flag) = (0, FALSE);

        # Init 2D matrix to save the iteration solutions:
        my @iter_solution;

        # Iterate until convergence criteria is reached or until the mixumum
        # iterations allowed. TODO: retrieve max num iter from configuration
        until ( $convergence_flag || $iteration == 6 )
        {
          # Declare aproximate position parameters:
          my @rec_apx_xyz;

          # Selection of approximate position parameters:
          if ( $iteration == 0 ) {

            if ( $first_solution_flag ) {
              # Approximate parameters come from previous epoch:
              # TODO: maybe the previous epoch was not successfully estimated
              #       --> apply while loop!
              @rec_apx_xyz =
              @{$ref_rinex_obs->{OBSERVATION}[$i - 1]{POSITION_SOLUTION}{XYZD}};
            } else {
              # Approximate parameters come from RINEX header:
              # NOTE: Receiver clock bias is init to 0:
              @rec_apx_xyz = (@{$ref_rinex_obs->{HEADER}{APX_POSITION}}, 0);
            }

          } else {
            # Approximate parameters come from previous iteration:
            @rec_apx_xyz = @{$iter_solution[$iteration - 1]};
          }

          # Initilize LSQ matrix system:
          my ($ref_design_matrix, $ref_ind_term_matrix, $ref_weight_matrix);

          # Iterate over the observed satellites:
          for my $sat (keys $ref_rinex_obs->{OBSERVATION}[$i]{SAT_OBS})
          {
            # Identify constellation:
            my $sat_sys = substr($sat, 0, 1);

            # Save receiver-satellite observation:
            my $obs_id; # TODO: retrieve observation ID from configuration
            my $raw_obs =
               $ref_rinex_obs->{OBSERVATION}[$i]{SAT_OBS}{$sat}{C1C};

            # Discard NULL observations:
            unless ( $raw_obs eq NULL_OBSERVATION )
            {
              # Save satellite coordinates:
              my @sat_xyz = @{$ref_rinex_obs->{OBSERVATION}[$i]{SAT_NAV}{$sat}};

              # Set pseudorange equation:
              SetPseudorangeEquation( $ref_design_matrix,
                                      $ref_ind_term_matrix,
                                      $ref_weight_matrix );

            } # end unless obs eq NULL
          } # end for $sat

          # LSQ position estimation:
          my ($ref_parameter_matrix, $ref_covar_matrix) = SolveWeightedLSQ();

          # Apply differential corrections:
          my @rec_est_xyz;

          # Save iteration solution:
          $iter_solution[$iteration] = @rec_est_xyz;

          # TODO: Check for convergence criteria:

          # Update number of elapsed iterations:
          $iteration += 1;

        } # end until $conv or $iter

        # If a solution was produced, update first solution flag:

        # Save receiver solution in observation hash:
        $ref_rinex_obs->{OBSERVATION}[$i]{POSITION_SOLUTION} = \$iter_solution[-1];

      } # end if $epoch_status
    } # end for $i

  # If the subroutine was successful, it will answer with TRUE status:
  return TRUE;
}


# Private Subrutines: #
# ............................................................................ #
sub SelectNavigationBlock {
  my ($obs_epoch, @sat_nav_epochs) = @_;

  # Init as undefined the selected navigation epoch:
  my $selected_nav_epoch;

  # Iterate over the ephemerids epochs:
  for my $nav_epoch (@sat_nav_epochs)
  {
    # The ephemerids epoch is selected if the time threshold is acomplished:
    if ( abs($obs_epoch - $nav_epoch) < TIME_THRESHOLD_NAV_EPH ) {
      return $nav_epoch;
    }
  }

  # If no ephemerids have met the condition,
  # the subroutine returns a negative answer:
  return FALSE;
}

sub ComputeSatelliteCoordinates {
  my ($epoch, $obs_meas, $sat, $ref_eph) = @_;

  # Transform target epoch into GPS time of week format:
  my ( $wn, $dn, $tow ) = GPS2ToW($epoch);

  # ********************************* #
  # Computation of the emission time: #
  # ********************************* #

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

  # ****************************************** #
  # Satellite coordinate computation sequence: #
  # ****************************************** #

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
    # Frequencies are selected based on... # NOTE: how to handle this?
    my ( $freq1, $freq2 ) = ( 1, 1 );
    my $delta_tgd = (($freq1/$freq2)**2)*$ref_eph->{TGD};
    $delta_tgd = 0; # WARNING: set to 0, peding to evalute method!

    # Compute final time correction:
    my $time_corr = $time_corr2 + $delta_trel + $delta_tgd;


  # Return final satellite coordinates and time correction:
  return  ($x_sat, $y_sat, $z_sat, $time_corr);
}

sub SatPositionFromEmission2Reception {
  my ($x_sat, $y_sat, $z_sat, $x_rec, $y_rec, $z_rec) = @_;

}

sub SetPseudorangeEquation {}

TRUE;
