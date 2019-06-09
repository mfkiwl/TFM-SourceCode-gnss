#!/usr/bin/perl -w

# NOTE: SCRIPT DESCRIPTION GOES HERE:

# Package declaration:
package SatPosition;

# ---------------------------------------------------------------------------- #
# Set package exportation properties:

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

# ---------------------------------------------------------------------------- #
# Load bash enviroments:

use lib $ENV{ ENV_ROOT };
use Enviroments qq(:CONSTANTS);

# ---------------------------------------------------------------------------- #
# Import Modules:

use strict; # enables strict syntax...

use Math::Trig; # load trigonometry methods...
use Scalar::Util qq(looks_like_number); # scalar utility...

use Data::Dumper; # enables pretty print...
use feature qq(say); # print adding carriage return...
use feature qq(switch); # switch method...

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
# Contants:

use constant INVALID_EPH_EPOCH => -1;

# Sat sys hash holding the sub reference for selecting the ehemerids block:
use constant
  REF_SUB_SELECT_EPHEMERIDS => {
    &RINEX_GPS_ID => \&SelectGPSEphemerids,
    &RINEX_GAL_ID => \&SelectGALEphemerids,
  };

# Sat sys hash holding sub reference for computing satellite coordinates
use constant
  REF_SUB_SAT_POSITION => {
    &RINEX_GPS_ID => \&ComputeGPSSatelliteCoordinates,
    &RINEX_GAL_ID => \&ComputeGALSatelliteCoordinates,
  };

# Module specific warning codes:
use constant {
  WARN_OBS_NOT_VALID     => 90301,
  WARN_NO_SAT_NAVIGATION => 90303,
  WARN_NO_SAT_EPH_FOUND  => 90304,
  WARN_SAT_POSITION_NOT_AVAILABLE => 90306,
  ERR_WRONG_SAT_POSITION_CODE => 30301,
  ERR_BAD_SAT_POSITION => 90305,
};


# ---------------------------------------------------------------------------- #
# Public Subroutines:

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

  # *************************** #
  # Compute satellite position: #
  # *************************** #

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

      # Init satelite navigation data to fill in hash:
      my $sat_status     = FALSE;
      my $sat_eph_source = FALSE;
      my $sat_eph_epoch  = INVALID_EPH_EPOCH;
      my @sat_coord      = (NULL_DATA, NULL_DATA, NULL_DATA, NULL_DATA);

      # Look for this constellation in the navigation hash:
      if (grep(/^$sat_sys$/, keys %{$ref_sat_sys_nav}))
      {
        # Save constellation navigation data:
        my $ref_nav_head = $ref_sat_sys_nav->{$sat_sys}{HEAD};
        my $ref_nav_body = $ref_sat_sys_nav->{$sat_sys}{BODY};

        # Check that the navigation data is available for the selected
        # satellite:
        unless (exists $ref_nav_body->{$sat}) {

          # Raise warning and skip code to next satellite:
          RaiseWarning($fh_log, WARN_NO_SAT_NAVIGATION,
            "Navigation ephemerids for satellite \'$sat\' could not be found");

        } else { # If satellite navigation data is available:

          # Determine best ephemerids to compute satellite coordinates:
          ($sat_eph_epoch, $sat_eph_source) =
             &{ REF_SUB_SELECT_EPHEMERIDS->{$sat_sys} }
              ( $ref_gen_conf, $obs_epoch, $sat, $ref_nav_body);

          # Check that the ephemerids have been selected:
          if ($sat_eph_epoch == INVALID_EPH_EPOCH) {

            # Raise a warning and go to the next satellite:
            RaiseWarning($fh_log, WARN_NO_SAT_EPH_FOUND,
              "No navigation ephemerids were selected for satellite \'$sat\', ".
              "at observation epoch: ".BuildDateString(GPS2Date($obs_epoch)));

          } else { # If satellite ephemerids have been selected:

            # Save the ephemerid parameters for computing the satellite
            # coordinates:
            my $ref_sat_eph =
               $ref_nav_body->{$sat}{$sat_eph_epoch}{$sat_eph_source};

            # Retrieve observation measurement:
            my $signal = $ref_gen_conf->{SELECTED_SIGNALS}{$sat_sys};
            my $obs_meas = $ref_epoch_data->{SAT_OBS}{$sat}{$signal};

            # Do not compute satellite coordinates if the observation is not
            # valid:
            unless ($obs_meas eq NULL_OBSERVATION) {

              # Observation epoch is trasnformed into time of week format:
              # NOTE: it is assumed that obervation epoch is given in GPST
              my ($gps_week, $gps_dow, $gps_tow) = GPS2ToW( $obs_epoch );

              # Navigation ephemerids epoch is also transofmed into ToW
              # format:
              my ($nav_week, $nav_dow, $nav_tow) = GPS2ToW( $sat_eph_epoch );

              # Retrieve carrier frequencies:
              my ( $carrier_freq_f1, $carrier_freq_f2 ) =
                 ( $ref_gen_conf->{CARRIER_FREQUENCY}{$sat_sys}{F1},
                   $ref_gen_conf->{CARRIER_FREQUENCY}{$sat_sys}{F2} );

              # Compute satellite coordinates for observation epoch:
              ($sat_status, @sat_coord) =
                &{ REF_SUB_SAT_POSITION->{$sat_sys} }
                  ( $ref_nav_head, $ref_sat_eph,
                    $gps_tow, $nav_tow, $obs_meas,
                    $carrier_freq_f1, $carrier_freq_f2 );

              # Raise error in case of killed coordinate computation:
              if ( $sat_status == KILLED )  {

                RaiseError($fh_log, ERR_BAD_SAT_POSITION,
                  "Satellite '$sat' coordinates and clock correction, ".
                  "could not be properly computed.",
                  "Common reasons for this issue are:",
                  "\tUnrecognized satellite system.",
                  "\tNecessary 'TIME SYSTEM CORR' parameters are not present ".
                  "in the navigation file header.");

                # ComputeSatPosition sub is aborted:
                return KILLED;
              }

            } else {

              RaiseWarning($fh_log, WARN_SAT_POSITION_NOT_AVAILABLE,
                "On $obs_epoch --> ".BuildDateString(GPS2Date($obs_epoch)),
                "Satellite position for sat ID '$sat', could not be computed ".
                "due to NULL_OBSERVATION entry from observation data.");

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
        $ref_epoch_data->{SAT_POSITION}{$sat}{ EPOCH  } = $sat_eph_epoch;
        $ref_epoch_data->{SAT_POSITION}{$sat}{ SOURCE } = $sat_eph_source;

      } # end if grep($sat, SUPPORTED_SAT_SYS)

    } # end for $sat
  } # end for $i

  # Return contellation navigation data hash:
  return $ref_sat_sys_nav;
}

# ---------------------------------------------------------------------------- #
# Private Subroutines:

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

sub SelectGPSEphemerids {
  my ($ref_gen_conf, $obs_epoch, $sat, $ref_nav_body) = @_;

  # Init ephemerids epoch and source to be returned:
  # NOTE: epoch is init to invalid in case no valid ephemerids are found
  # NOTE: GPS ephemerids source will always be '1' (ñegacy navigation msg):
  my $eph_epoch  = INVALID_EPH_EPOCH;
  my $eph_source = GPS_NAV_MSG_SOURCE_ID;

  # Retrieve from configuration, the ephemerids time threshold:
  my $time_threshold = $ref_gen_conf->{EPH_TIME_THRESHOLD};

  # Iterate over the available ephemerid epochs:
  for my $nav_epoch ( sort(keys(%{ $ref_nav_body->{$sat} })) ) {
    # Check only for time threshold criteria:
    if ( abs($obs_epoch - $nav_epoch) < $time_threshold ) {
      $eph_epoch = $nav_epoch;
      last; # once valid ephemerids are found, the loop is broken...
    }
  }

  return ($eph_epoch, $eph_source);
}

sub SelectGALEphemerids {
  my ($ref_gen_conf, $obs_epoch, $sat, $ref_nav_body) = @_;

  # Init ephemerids epoch and source to be returned:
  # NOTE: epoch and source is init to invalid in case no valid
  #       ephemerids are found
  my $eph_epoch  = INVALID_EPH_EPOCH;
  my $eph_source = FALSE;

  # Retrieve from configuration: ephemerids time threshold and selected GAL
  # signal:
  # NOTE: signal obs is trimmed until second character
  my $time_threshold =
     $ref_gen_conf->{EPH_TIME_THRESHOLD};
  my $target_signal =
     substr($ref_gen_conf->{SELECTED_SIGNALS}{&RINEX_GAL_ID}, 0, 2);

  # Iterate over the available ephemerid epochs and its different sources:
  for my $nav_epoch (sort(keys(%{$ref_nav_body->{$sat}}))) { NAV_EPOCH_FOR: {
    for my $nav_source (keys(%{$ref_nav_body->{$sat}{$nav_epoch}})) {

      # Retrieve ephemerids signal service boolean:
      my $signal_service =
         $ref_nav_body->{$sat}{$nav_epoch}{$nav_source}
                        {DATA_SOURCE}{SERVICE}{$target_signal};

      # Check for time threshold criteria and GAL data source:
      if ( $signal_service &&
          (abs($obs_epoch - $nav_epoch) < $time_threshold) ) {
        $eph_epoch  = $nav_epoch;
        $eph_source = $nav_source;
        # Once valid ephemerids are found, the outerloop is broken...
        last NAV_EPOCH_FOR;
      }

    } # end for $nav_source
  }} # end for $nav_epoch

  return ($eph_epoch, $eph_source);
}

sub ComputeGPSSatelliteCoordinates {
  my ($ref_nav_head, $ref_eph,
      $obs_tow, $eph_toc, $obs_meas, $freq1, $freq2) = @_;

  # Init status:
  my $status = FALSE;

  # ************************** #
  # Emission time computation: #
  # ************************** #
    # Retrieve from satellite ephemerids, the ToE and SV clock
    # parameters:
    my $toe = $ref_eph->{TOE};
    my ( $a0, $a1, $a2 ) = ( $ref_eph->{ SV_CLK_BIAS  },
                             $ref_eph->{ SV_CLK_DRIFT },
                             $ref_eph->{ SV_CLK_RATE  } );

    # Reception time is at observation epoch:
    my $time_recp = $obs_tow;

    # TODO: build for with two iterations
    # First emission time and clock correction estimation:
    my $time_emis1 = ComputeEmissionTime( $time_recp, $obs_meas, $toe, 0 );
       $time_emis1 = TimeOfWeekInterpProtection( $time_emis1 );

    my $time_corr1 =
       ComputeSatClockCorrection( $a0, $a1, $a2, $time_emis1, 0 );

    # Second iteration for emission and clock correction:
    my $time_emis2 = $time_emis1 - $time_corr1;
       $time_emis2 = TimeOfWeekInterpProtection( $time_emis2 );

    my $time_corr2 =
       ComputeSatClockCorrection( $a0, $a1, $a2, $time_emis2, 0 );

    # Final emission time is computed using second time correction:
    my $time_emis = $time_emis2 - $time_corr2;
       $time_emis = TimeOfWeekInterpProtection( $time_emis );

  # ******************************************* #
  # Satellite coordinates computation sequence: #
  # ******************************************* #

    my ( $x_sat, $y_sat, $z_sat, $ecc_anomaly ) =
        ComputeSatelliteCoordinatesFromEphemerids( $time_emis, $ref_eph );

  # ********************** #
  # Final time correction: #
  # ********************** #

    # Aplly: relativistic effect and total group delay:
    my $time_corr = $time_corr2 -
                    ComputeGPSGroupDelay( $freq1, $freq2, $ref_eph ) +
                    ComputeRelativisticEffect( $ref_eph, $ecc_anomaly );

    # Assign time correction to sat time correction:
    my $sat_clk_corr = $time_corr;

  # Update final status:
  $status = TRUE;

  # TODO: need status var?
  return ($status, $x_sat, $y_sat, $z_sat, $sat_clk_corr);
}

sub ComputeGALSatelliteCoordinates {
  my ($ref_nav_head, $ref_eph,
      $obs_tow, $eph_toc, $obs_meas, $freq1, $freq2) = @_;

  # Init status:
  my $status = FALSE;

  # *************************** #
  # GPS to GAL time correction: #
  # *************************** #
    # Check GPS to GAL time system correction parameters:
    unless (defined $ref_nav_head->{GPGA}) {
      return KILLED;
    } else {

      my $gps_to_gal_time_corr =
        ComputeSatSysTimeCorrection( $obs_tow,
                                     $ref_eph->{GAL_WEEK},
                                     $ref_nav_head->{GPGA}{ A0 },
                                     $ref_nav_head->{GPGA}{ A1 },
                                     $ref_nav_head->{GPGA}{  T },
                                     $ref_nav_head->{GPGA}{  W }, );

      $obs_tow = $obs_tow + $gps_to_gal_time_corr;
    }


  # ************************** #
  # Emission time computation: #
  # ************************** #
    # Retrieve from satellite ephemerids, the ToE and SV clock
    # parameters:
    my $toe = $ref_eph->{TOE};
    my ( $a0, $a1, $a2 ) = ( $ref_eph->{ SV_CLK_BIAS  },
                             $ref_eph->{ SV_CLK_DRIFT },
                             $ref_eph->{ SV_CLK_RATE  } );

    # Reception time is at observation epoch:
    my $time_recp = $obs_tow;

    # TODO: build for with two iterations
    # First emission time and clock correction estimation:
    my $time_emis1 = ComputeEmissionTime( $time_recp, $obs_meas, $toe, 0 );
       $time_emis1 = TimeOfWeekInterpProtection( $time_emis1 );

    my $time_corr1 =
       ComputeSatClockCorrection( $a0, $a1, $a2, $time_emis1, 0 );

    # Second iteration for emission and clock correction:
    my $time_emis2 = $time_emis1 - $time_corr1;
       $time_emis2 = TimeOfWeekInterpProtection( $time_emis2 );

    my $time_corr2 =
       ComputeSatClockCorrection( $a0, $a1, $a2, $time_emis2, 0 );

    # Final emission time is computed using second time correction:
    my $time_emis = $time_emis2 - $time_corr2;
       $time_emis = TimeOfWeekInterpProtection( $time_emis );

  # ******************************************* #
  # Satellite coordinates computation sequence: #
  # ******************************************* #

    my ( $x_sat, $y_sat, $z_sat, $ecc_anomaly ) =
        ComputeSatelliteCoordinatesFromEphemerids( $time_emis, $ref_eph );

  # ********************** #
  # Final time correction: #
  # ********************** #

    # Aplly: relativistic effect and total group delay:
    my $time_corr = $time_corr2 -
                    ComputeGALGroupDelay( $freq1, $freq2, $ref_eph ) +
                    ComputeRelativisticEffect( $ref_eph, $ecc_anomaly );

  # *************************** #
  # GAL to GPS time correction: #
  # *************************** #

  # Apply GALILEO to GPS time correction to GAL SV clock correction:
  my $gps_to_gal_time_corr =
    ComputeSatSysTimeCorrection( $time_corr,
                                 $ref_eph->{GAL_WEEK},
                                 $ref_nav_head->{GPGA}{ A0 },
                                 $ref_nav_head->{GPGA}{ A1 },
                                 $ref_nav_head->{GPGA}{  T },
                                 $ref_nav_head->{GPGA}{  W }, );

  my $sat_clk_corr = $time_corr - $gps_to_gal_time_corr;

  # Update final status:
  $status = TRUE;

  return ($status, $x_sat, $y_sat, $z_sat, $sat_clk_corr);
}

sub ComputeSatelliteCoordinatesFromEphemerids {
  my ($time_emis, $ref_eph) = @_;

  # Iinit satellite position parameters to be returned:
  my ($x_sat, $y_sat, $z_sat, $ecc_anomaly);

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
    my $phi0 = $v + $ref_eph->{OMEGA};

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
    my $omega = $ref_eph->{OMEGA_0} +
               ($ref_eph->{OMEGA_DOT} - EARTH_ANGULAR_SPEED)*$time_emis -
                EARTH_ANGULAR_SPEED*$ref_eph->{TOE};

    # Satellite coordinates:
    my ( $x_sat,
         $y_sat,
         $z_sat ) = ( $x_op*cos($omega) - $y_op*cos($inc)*sin($omega),
                      $x_op*sin($omega) + $y_op*cos($inc)*cos($omega),
                      $y_op*sin($inc) );

    # Assign eccentricity anomaly:
    $ecc_anomaly = $e;

  # Return satellite parameters:
  return ($x_sat, $y_sat, $z_sat, $ecc_anomaly);
}

sub ComputeEmissionTime {
  my ( $time_recp, $obs_meas, $toe, $time_corr ) = @_;

  # Compute emission time:
  # NOTE: Reception time, ToE and correction time are given in ToW format.
  #       Thus, emission time is computed in ToW as well.
  my $time_emis = $time_recp - ($obs_meas/SPEED_OF_LIGHT) - $toe - $time_corr;

  return $time_emis;
}

sub ComputeRelativisticEffect {
  my ($ref_eph, $ecc_anomaly) = @_;

  my $delta_rel_efffect;

  # Retrieve orbit's semimajor axis:
  my $a = ($ref_eph->{SQRT_A})**2;

  # Compute relativistic effect correction:
  $delta_rel_efffect =
    -2*( ((EARTH_GRAV_CONST*$a)**0.5)/(SPEED_OF_LIGHT**2) )*
    $ref_eph->{ECCENTRICITY}*sin($ecc_anomaly);

  return $delta_rel_efffect;
}

sub ComputeSatClockCorrection {
  my ( $a0, $a1, $a2, $time_emis, $toc ) = @_;

  # NOTE: Emission time and ToC is given in ToW format.
  #       Thus, correction time will be computed in ToW as well.
  my $aux = ($time_emis - $toc);
  my $time_corr = $a0 + $a1*$aux + $a2*$aux**2;

  return $time_corr;
}

sub ComputeGPSGroupDelay {
  my ($freq1, $freq2, $ref_eph) = @_;

  my $delta_group_delay = ( ($freq1/$freq2)**2 )*$ref_eph->{TGD};

  return $delta_group_delay;
}

sub ComputeGALGroupDelay {
  my ($freq1, $freq2, $ref_eph) = @_;

  # Init group delay correction:
  my $delta_group_delay;

  # Select brodcast group delay based on selected frequency 2:
  my $bgd; # init broadcast group delay
  given ($freq2) {
    when( $_ eq GAL_E1_FREQ  ) { $bgd = $ref_eph->{BGD_E5B_E1}; }
    when( $_ eq GAL_E5b_FREQ ) { $bgd = $ref_eph->{BGD_E5B_E1}; }
    when( $_ eq GAL_E5a_FREQ ) { $bgd = $ref_eph->{BGD_E5A_E1}; }
    default                    { $bgd = 0;                      }
  }

  # Compute group delay correction:
  $delta_group_delay = ( ($freq1/$freq2)**2 )*$bgd;

  return $delta_group_delay;
}

TRUE;
