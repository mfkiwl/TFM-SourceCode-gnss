#!/usr/bin/perl -w

# Package declaration:
package RecPosition;


# NOTE: SCRIPT DESCRIPTION GOES HERE:

# Load bash enviroments:
# ---------------------------------------------------------------------------- #
use lib $ENV{ ENV_ROOT };
use Enviroments qq(:CONSTANTS);

# Import Modules:
# ---------------------------------------------------------------------------- #
use strict;   # enables strict syntax...

use PDL::Core;  # loads Perl Data Language extension...
use PDL::Basic;
use Math::Trig;

use Scalar::Util qq(looks_like_number); # scalar utility...

use feature qq(say);    # print adding carriage return...
use feature qq(switch); # switch functionality...
use Data::Dumper;       # enables pretty...

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
  our @EXPORT_CONST = qw( &NUM_PARAMETERS_TO_ESTIMATE );

  # Define subroutines to export:
  our @EXPORT_SUB   = qw( &ComputeRecPosition );

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

# Number of position parameters to estimate with LSQ algorithm:
use constant NUM_PARAMETERS_TO_ESTIMATE => 4;

# Module specific warning codes:
use constant {
  WARN_OBS_NOT_VALID                 => 90301,
  WARN_IONO_COEFF_NOT_SELECTED       => 90302,
  WARN_NOT_SUCCESSFUL_LSQ_ESTIMATION => 90305,
};

# ---------------------------------------------------------------------------- #
# Subroutines:
# ---------------------------------------------------------------------------- #

# Public Subroutines:                                                          #
# ............................................................................ #
sub ComputeRecPosition {
  my ($ref_gen_conf, $ref_rinex_obs, $ref_sat_sys_nav, $fh_log) = @_;

  # ************************* #
  # Input consistency checks: #
  # ************************* #

    # Reference to general configuration must be hash type:
    unless ( ref($ref_gen_conf) eq 'HASH' ) {
      RaiseError($fh_log, ERR_WRONG_HASH_REF,
        ("Input argument \'$ref_gen_conf\' is not HASH type"));
      return KILLED;
    }

    # Reference to RINEX observation must be hash type:
    unless (ref($ref_rinex_obs) eq 'HASH') {
      RaiseError($fh_log, ERR_WRONG_HASH_REF,
        ("Input argument reference: \'$ref_rinex_obs\' is not HASH type"));
      return KILLED;
    }

    # Reference to satellite system RINEX navigation must be hash type:
    unless (ref($ref_sat_sys_nav) eq 'HASH') {
      RaiseError($fh_log, ERR_WRONG_HASH_REF,
        ("Input argument reference: \'$ref_sat_sys_nav\' is not HASH type"));
      return KILLED;
    }

  # ***************************************** #
  # Set atmosphere models from configuration: #
  # ***************************************** #
    # Troposphere model switch case:
    my $ref_sub_troposphere;
    given ( $ref_gen_conf->{TROPOSPHERE_MODEL} ) {
      when ( /saastamoinen/i )
        { $ref_sub_troposphere = \&ComputeTropoSaastamoinenDelay; }
    }

    # Ionosphere model configuration. Assessed with dedicated sub:
    my ( $conf_iono_status, $warn_msg,
         $ref_sub_iono, $ref_iono_coeff ) =
      ConfigureIonosphereInfo( $ref_gen_conf->{RINEX_NAV_PATH},
                               $ref_gen_conf->{SELECTED_SAT_SYS},
                               $ref_gen_conf->{IONOSPHERE_MODEL} );

    # Raise warning if the iono configuration is not successfull:
    unless($conf_iono_status) {
      RaiseWarning($fh_log, WARN_IONO_COEFF_NOT_SELECTED,
                   $warn_msg, "Ionosphere delay may not be properly computed!");
    }


  # **************************** #
  # Position estimation routine: #
  # **************************** #

    # Init first succesfully estimated epoch flag:
    my $first_solution_flag = FALSE;

    # Iterate over the observation epochs:
    for (my $i = 0; $i < scalar(@{$ref_rinex_obs->{BODY}}); $i += 1)
    {
      # Set reference pointing to epoch information hash:
      my $ref_epoch_info = $ref_rinex_obs->{BODY}[$i];

      # Init epoch hash for computed data:
      InitEpochInfoHash($ref_epoch_info);

      # Init references to hold estimated position and associated
      # variances:
      my ($ref_rec_est_xyz, $rec_est_clk,
          $ref_rec_var_xyz, $rec_var_clk, $ref_rec_var_enu);

      # Save observation epoch:
      my $epoch = $ref_epoch_info->{EPOCH};

      # Discard invalid epochs:
      if ( $ref_epoch_info->{STATUS} == HEALTHY_OBSERVATION_BLOCK )
      {
        # Build list of satellites to enter LSQ algorithm:
        my @sat_to_lsq = SelectSatForLSQ( $ref_gen_conf,
                                          $ref_epoch_info,
                                          $first_solution_flag,
                                          $ref_rinex_obs, $i );

        # Init iteration information:
        my @iter_solution; # 2D matrix to save the iteration solutions...
        my ($iteration, $iter_status, $convergence_flag) = (0, FALSE, FALSE);

        # Iterate until convergence criteria is reached or until the maximum
        # iterations allowed:
        until ( $convergence_flag ||
                $iteration == $ref_gen_conf->{LSQ_MAX_NUM_ITER} )
        {
          # Select approximate parameters:
          my @rec_apx_xyzdt =
            SelectApproximateParameters( $first_solution_flag,
                                         $ref_rinex_obs, $i,
                                         \@iter_solution, $iteration );

          # Set number of observations and parameters to estimate:
          # NOTE: as far as only one observation types is processed,
          #       number of observations for LSQ is equal to the number
          #       of satellites selected for the LSQ routine
          my ( $num_obs,
               $num_parameter ) = ( scalar(@sat_to_lsq),
                                    NUM_PARAMETERS_TO_ESTIMATE );

          # Initialize LSQ matrix system:
          my ( $ref_design_matrix,
               $ref_weight_matrix,
               $ref_ind_term_matrix ) = InitLSQ( $num_obs,
                                                 $num_parameter );

          # Build up LSQ matrix system:
          BuildLSQMatrixSystem (
            $ref_gen_conf,
            $ref_iono_coeff,
            $epoch, $ref_epoch_info,
            \@rec_apx_xyzdt, \@sat_to_lsq,
            $ref_sub_iono, $ref_sub_troposphere,
            $ref_rinex_obs->{HEAD}{LEAP_SECONDS},
            $ref_design_matrix, $ref_weight_matrix, $ref_ind_term_matrix
          );

          # ************************ #
          # LSQ position estimation: #
          # ************************ #
          my ( $lsq_status,
               $pdl_parameter_vector,
               $pdl_residual_vector,
               $pdl_covariance_matrix,
               $pdl_variance_estimator ) = SolveWeightedLSQ (
                                             $ref_design_matrix,
                                             $ref_weight_matrix,
                                             $ref_ind_term_matrix
                                           );
          # Update iteration status:
          $iter_status = $lsq_status;

          # Check for successful LSQ estimation.
          # If so, retrieve and save position solution:
          if ( $lsq_status )
          {
            # Set Receiver's approximate parameters as PDL piddle:
            my $pdl_rec_apx_xyzdt = pdl @rec_apx_xyzdt;

            # Get estimated receiver position and solution variances:
            ( $ref_rec_est_xyz, $rec_est_clk,
              $ref_rec_var_xyz, $rec_var_clk, $ref_rec_var_enu ) =
                GetReceiverPositionSolution ( $pdl_rec_apx_xyzdt,
                                              $pdl_parameter_vector,
                                              $pdl_covariance_matrix,
                                              $ref_gen_conf->{ELIPSOID} );

            # Save iteration solution:
            $iter_solution[$iteration] = [ @{$ref_rec_est_xyz}, $rec_est_clk ];

            # Update number of elapsed iterations:
            $iteration += 1;

            # Check for convergence criteria:
            $convergence_flag =
              CheckConvergenceCriteria($pdl_parameter_vector,
                                       $ref_gen_conf->{CONVERGENCE_THRESHOLD});

            # Fill LSQ computation info.
            # NOTE: (iteration - 1) since it has been already increased:
            FillLSQInfo( $ref_epoch_info, $iteration - 1,
                         $lsq_status, $convergence_flag,
                         $num_obs, $num_parameter,
                         \@rec_apx_xyzdt, $pdl_parameter_vector,
                         $pdl_residual_vector, $pdl_variance_estimator );

          } else {

            # If LSQ estimation was not successful, raise a warning and last
            # the iteration loop, so the next epoch can be processed:
            RaiseWarning($fh_log, WARN_NOT_SUCCESSFUL_LSQ_ESTIMATION,
              "Least squeares estimation routine was not successful at ".
              "observation epoch $epoch",
              "This is most likely due to a non-redundant LSQ matrix system, ".
              "where the number of observations are equal or less than the ".
              "number of parameters to be estimated.");

            # Fill LSQ information with NULL content:
            FillLSQInfo( $ref_epoch_info, $iteration,
                         $lsq_status, FALSE,
                         $num_obs, $num_parameter,
                         \@rec_apx_xyzdt, $pdl_parameter_vector,
                         $pdl_residual_vector, $pdl_variance_estimator );

            # Fill position solution hash with null info:
            FillSolutionDataHash( $ref_epoch_info, $iter_status,
                                  [0, 0, 0], 0, [0, 0, 0], 0, [0, 0, 0] );

            # Exit iteration loop:
            last;

          } # end if defined $pdl_parameter_vector
        } # end until $convergence_flag or $iteration == MAX_NUM_ITER

        # ******************************** #
        # Save Receiver Position Solution: #
        # ******************************** #
        if ($iter_status)
        {
          # Update first solution flag:
          # NOTE: This means that a solution which has acomplished the number
          #       of iterations or the convergence criteria, has been produced!
          $first_solution_flag = TRUE;

          # Store receiver position solution and standard deviations in
          # observation rinex hash:
          # NOTE: receiver solution and standard deviations come from last
          #       iteration solution
          FillSolutionDataHash( $ref_epoch_info, $iter_status,
                                $ref_rec_est_xyz, $rec_est_clk,
                                $ref_rec_var_xyz, $rec_var_clk,
                                $ref_rec_var_enu );

        } # end if $iter_status

      } # end if $epoch_status == HEALTHY_OBSERVATION_BLOCK
    } # end for $i

  # If the subroutine was successful, it will answer with TRUE boolean:
  return TRUE;
}

# Private Subroutines:                                                         #
# ............................................................................ #

# ************************************************************** #
# First Level Subroutines:                                       #
#   Subroutines called from main public sub: ComputeRecPosition. #
# ************************************************************** #

sub ConfigureIonosphereInfo {
  my ( $ref_nav_path,
       $ref_selected_sat_sys,
       $ref_sat_sys_iono_model ) = @_;

  # Init dummy array.
  # This array is used for filling empty info in hashes:
  my @dummy_array;

  # Init sub's status and warn mesage in case of error:
  my ($status, $warn_msg) = (TRUE, '');

  # Init hashes references to save iono model subroutine and proper
  # coefficients:
  my %sub_iono;   my $ref_sub_iono   = \%sub_iono;
  my %iono_coeff; my $ref_iono_coeff = \%iono_coeff;

  # Iterate over each selected constellation:
  for my $sat_sys ( @{$ref_selected_sat_sys} ) { SAT_SYS_FOR:{
    given ( $ref_sat_sys_iono_model->{$sat_sys} ) { IONO_MODEL_SWITCH:{

      # ************************ #
      # NeQuick Ionosphere model #
      # ************************ #
      when ( /nequick/i )
      {
        # Set subroutine reference for NeQuick model:
        $ref_sub_iono->{$sat_sys} = \&ComputeIonoNeQuickDelay;

        # Set ionosphere coefficients. NeQuick model uses GAL ones:
        my ($ref_coeff_1, $ref_coeff_2);
        my $ref_nav_head =
           ReadNavigationRinexHeader( $ref_nav_path->{&RINEX_GAL_ID}, *STDOUT );

        # Check if GALILEO nav file has been configured:
        unless($ref_nav_head) {
          $warn_msg = FillMissingRinexWarning( $sat_sys, 'NeQuick', 'GALILEO');
          $status = FALSE; last SAT_SYS_FOR;
        }

        # Check for RINEX navigation version:
        my $rinex_nav_version = int( $ref_nav_head->{VERSION} );

        # Switch among navgation RINEX version:
        given( $rinex_nav_version ) {

          # ******************** #
          # GALILEO RINEX NAV V2 #
          # ******************** #
          when ( 2 ) {
            # Ionosphere coefficients for GALILEO are not defined in RINEX V2
            # navigation file:
            $warn_msg = "Sorry, but RINEX V2 navigation file, does not ".
                        "include ionosphere coefficients for GALILEO ".
                        "constellation. Try to download RINEX V3 GALILEO ".
                        "navigation file.";
            $status = FALSE; last SAT_SYS_FOR;
          } # end when 2

          # ******************** #
          # GALILEO RINEX NAV V3 #
          # ******************** #
          when ( 3 ) {
            if ( defined $ref_nav_head->{ &ION_GAL_V3 } ) {
              ( $ref_coeff_1,
                $ref_coeff_2 ) = ( $ref_nav_head->{ &ION_GAL_V3 },
                                   \@dummy_array );
            } else {
              $warn_msg =
              FillIonoCoefficientWarning($sat_sys,
                                         $rinex_nav_version, ION_GAL_V3);
              $status = FALSE; last SAT_SYS_FOR;
            } # end if defined
          } # end when 3

        } # end given

        # Save ionosphere coefficients:
        $ref_iono_coeff->{$sat_sys}{IONO_COEFF_1} = $ref_coeff_1;
        $ref_iono_coeff->{$sat_sys}{IONO_COEFF_2} = $ref_coeff_2;

      } # end when /nequick/


      # ************************** #
      # Klobuchar Ionosphere model #
      # ************************** #
      when ( /klobuchar/i )
      {
        # Set subroutine reference for Klobuchar model:
        $ref_sub_iono->{$sat_sys} = \&ComputeIonoKlobucharDelay;

        # Set ionosphere coefficients. Klobuchar model uses GPS_A and GPS_B
        # ones:
        my ($ref_coeff_1, $ref_coeff_2);
        my $ref_nav_head =
           ReadNavigationRinexHeader( $ref_nav_path->{&RINEX_GPS_ID}, *STDOUT );

        # Check if GPS nav file has been configured:
        unless($ref_nav_head) {
          $warn_msg = FillMissingRinexWarning( $sat_sys, 'Klobuchar', 'GPS' );
          $status = FALSE; last SAT_SYS_FOR;
        }

        # Check for RINEX navigation version:
        my $rinex_nav_version = int( $ref_nav_head->{VERSION} );

        # Switch among navgation RINEX version:
        given( $rinex_nav_version ) {

          # **************** #
          # GPS RINEX NAV V2 #
          # **************** #
          when ( 2 ) {
            # First, check that both coefficients exist since these are optional
            # parameters in the navigation RINEX:
            if ( defined $ref_nav_head->{ ION_ALPHA } &&
                 defined $ref_nav_head->{ ION_BETA  } ) {
              ( $ref_coeff_1,
                $ref_coeff_2 ) = ( $ref_nav_head->{ ION_ALPHA },
                                   $ref_nav_head->{ ION_BETA  } );
            } else {
              $warn_msg =
                FillIonoCoefficientWarning( $sat_sys, $rinex_nav_version,
                                            ION_ALPHA_V2, ION_BETA_V2 );
              $status = FALSE; last SAT_SYS_FOR;
            } # end if defined
          } # end when 2

          # **************** #
          # GPS RINEX NAV V3 #
          # **************** #
          when ( 3 ) {
            # First, check that both coefficients exist since these are optional
            # parameters in the navigation RINEX:
            if ( defined $ref_nav_head->{ &ION_ALPHA_V3 } &&
                 defined $ref_nav_head->{ &ION_BETA_V3  } ) {
              ( $ref_coeff_1,
                $ref_coeff_2 ) = ( $ref_nav_head->{ &ION_ALPHA_V3 },
                                   $ref_nav_head->{ &ION_BETA_V3  } );
            } else {
              $warn_msg =
                FillIonoCoefficientWarning( $sat_sys, $rinex_nav_version,
                                            ION_ALPHA_V3, ION_BETA_V3 );
              $status = FALSE; last SAT_SYS_FOR;
            } # end if defined
          } # end when 3

        } # end given rinex version

        # Save ionosphere coefficients:
        $ref_iono_coeff->{$sat_sys}{IONO_COEFF_1} = $ref_coeff_1;
        $ref_iono_coeff->{$sat_sys}{IONO_COEFF_2} = $ref_coeff_2;

      } # end when /klobuchar/

    }} # end given $iono_model
  }} # end for $sat_sys

  # Arguments to return for ConfigureIonosphereInfo sub:
  return ($status, $warn_msg, $ref_sub_iono, $ref_iono_coeff);
}

sub InitEpochInfoHash {
  my ($ref_epoch_info) = @_;

  my @array_dummy;

  $ref_epoch_info->{ SAT_LOS  } = undef;
  $ref_epoch_info->{ LSQ_INFO } = \@array_dummy;
  $ref_epoch_info->{ REC_POSITION }{ STATUS  } = FALSE;
  $ref_epoch_info->{ REC_POSITION }{ XYZ     } = undef;
  $ref_epoch_info->{ REC_POSITION }{ CLK     } = undef;
  $ref_epoch_info->{ REC_POSITION }{ VAR_XYZ } = undef;
  $ref_epoch_info->{ REC_POSITION }{ VAR_CLK } = undef;
  $ref_epoch_info->{ REC_POSITION }{ VAR_ENU } = undef;

  return TRUE;
}

sub SelectSatForLSQ {
  my ($ref_gen_conf, $ref_epoch_info,
      $first_solution_flag, $ref_rinex_obs, $i, ) = @_;

  # Init arrays for storing selected and non-selected satellites for LSQ
  # algorithm:
  my @sat_to_lsq;
  my @sat_not_to_lsq;

  # Init satellite counter in observation hash:
  InitLSQSatelliteCounter( $ref_epoch_info,
                           $ref_gen_conf->{SELECTED_SAT_SYS} );

  # Iterate over observed satellites:
  for my $sat (keys %{$ref_epoch_info->{SAT_OBS}})
  {
    # Select only satellites with available navigation data:
    if ($ref_epoch_info->{SAT_POSITION}{$sat}{NAV}{STATUS}) {
      # Get constellation:
      my $sat_sys = substr($sat, 0, 1);

      # Get receiver-satellite observation measurement:
      my $signal  = $ref_gen_conf   -> {SELECTED_SIGNALS}{$sat_sys};
      my $raw_obs = $ref_epoch_info -> {SAT_OBS}{$sat}{$signal};

      # Discard NULL observations:
      unless ( $raw_obs eq NULL_OBSERVATION )
      {
        # Save satellite navigation coordinates:
        my @sat_xyztc = @{$ref_epoch_info->{SAT_POSITION}{$sat}{NAV}{XYZ_TC}};

        # Select aproximate recevier position:
        # NOTE: possible approximate parameters come from RINEX
        #       header or from previous iteration:
        my @rec_apx_xyzdt =
          SelectApproximateParameters( $first_solution_flag,
                                       $ref_rinex_obs, $i,
                                       undef, FALSE );

        # Propagate satellite coordinates due to the signal flight time:
        my @sat_xyz_recep =
          SatPositionFromEmission2Reception( $sat_xyztc     [0],
                                             $sat_xyztc     [1],
                                             $sat_xyztc     [2],
                                             $rec_apx_xyzdt [0],
                                             $rec_apx_xyzdt [1],
                                             $rec_apx_xyzdt [2] );

        # Save propagated coordinates in epoch info hash:
        $ref_epoch_info->{SAT_POSITION}{$sat}{RECEP} = [ @sat_xyz_recep,
                                                         $sat_xyztc[3] ];

        # Compute Rec-Sat LoS info:
        my ($rec_lat, # REC geodetic coordinates
            $rec_lon,
            $rec_helip,
            $rec_sat_ix, # REC-SAT ECEF vector
            $rec_sat_iy,
            $rec_sat_iz,
            $rec_sat_ie, # REC-SAT ENU vector
            $rec_sat_in,
            $rec_sat_iu,
            $rec_sat_azimut, # REC-SAT polar coordiantes
            $rec_sat_zenital,
            $rec_sat_distance,
            $rec_sat_elevation) = ReceiverSatelliteLoS( $ref_gen_conf,
                                                       \@rec_apx_xyzdt,
                                                       \@sat_xyz_recep );

        # Update LoS hash info:
        # NOTE: ionosphere and troposphere corrections are set to undefined.
        #       They will be filled after when building the observation
        #       equation.
        FillLoSDataHash( $ref_epoch_info, $sat,
                         $rec_sat_azimut, $rec_sat_zenital,
                         $rec_sat_distance, $rec_sat_elevation,
                                     undef,              undef,
                         [$rec_sat_ix, $rec_sat_iy, $rec_sat_iz],
                         [$rec_sat_ie, $rec_sat_in, $rec_sat_iu] );

        # 3. Determine if sat accomplishes selection criteria.
        #    Mask criteria is only assumed:
        if ($rec_sat_elevation >= $ref_gen_conf->{SAT_MASK}) {
          push(@sat_to_lsq, $sat);
          # Count LSQ satellites to enter LSQ algorithm:
          CountValidSatForLSQ($sat_sys, $sat, $ref_epoch_info->{NUM_SAT_INFO});
        } else {
          push(@sat_not_to_lsq, $sat);
        }
      } # end unless $raw_obs eq NULL_OBSERVATION
    } # end if status
  } # end for $sat

  # Return list of selected satellites:
  return @sat_to_lsq;
}

sub InitLSQ {
  my ($num_obs, $num_prm, $init_value) = @_;

  # Default fill value:
  $init_value = 0 unless $init_value;

  # Deisgn Matrix [ nobs x nprm ]:
  my $ref_design_matrix = [];
  for (my $i = 0; $i < $num_obs; $i += 1) {
    for (my $j = 0; $j < $num_prm; $j += 1) {
      $ref_design_matrix->[$i][$j] = $init_value;
    }
  }

  # Weight matrix [ nobs x nobs ]:
  my $ref_weight_matrix = [];
  for (my $i = 0; $i < $num_obs; $i += 1) {
    for (my $j = 0; $j < $num_obs; $j += 1) {
      $ref_weight_matrix->[$i][$j] = $init_value;
    }
  }

  # Independent term matrix [ nobs x 1 ]:
  my $ref_ind_term_matrix = [];
  for (my $i = 0; $i < $num_obs; $i += 1) {
    for (my $j = 0; $j < 1; $j += 1) {
      $ref_ind_term_matrix->[$i][$j] = $init_value;
    }
  }

  # Return marix references:
  return ( $ref_design_matrix, $ref_weight_matrix, $ref_ind_term_matrix );
}

sub BuildLSQMatrixSystem {
  my (# General configuration:
      $ref_gen_conf,
      $ref_iono_coeff,
      # Epoch info:
      $epoch, $ref_epoch_info,
      # Approximate position & SV list fo LSQ:
      $ref_rec_apx_xyzdt, $ref_sat_to_lsq,
      # Tropo, Iono delays & leap seconds:
      $ref_sub_iono, $ref_sub_troposphere, $leap_sec,
      # LSQ matrix system references:
      $ref_design_matrix, $ref_weight_matrix, $ref_ind_term_matrix) = @_;

  # De-reference input arguments:
  my @sat_to_lsq    = @{ $ref_sat_to_lsq    };
  my @rec_apx_xyzdt = @{ $ref_rec_apx_xyzdt };

  # Iterate over the selected satellites for LSQ:
  for (my $j = 0; $j < scalar(@sat_to_lsq); $j += 1)
  {
    # Identify satellite ID and constellation:
    my $sat = $sat_to_lsq[$j];
    my $sat_sys = substr($sat, 0, 1);

    # Get receiver-satellite observation measurement:
    my $signal  = $ref_gen_conf   -> {SELECTED_SIGNALS}{$sat_sys};
    my $raw_obs = $ref_epoch_info -> {SAT_OBS}{$sat}{$signal};

    # Discard NULL observations:
    unless ( $raw_obs eq NULL_OBSERVATION )
    {
      # Save navigation satellite coordinates:
      my @sat_xyztc = @{ $ref_epoch_info->{SAT_POSITION}{$sat}{NAV}{XYZ_TC} };

      # ************************************ #
      # Build pseudorange equation sequence: #
      # ************************************ #

      # 0. Propagate satellite's position to the signal reception time:
      my @sat_xyz_recep =
        SatPositionFromEmission2Reception( $sat_xyztc     [0],
                                           $sat_xyztc     [1],
                                           $sat_xyztc     [2],
                                           $rec_apx_xyzdt [0],
                                           $rec_apx_xyzdt [1],
                                           $rec_apx_xyzdt [2] );

      # 1. Retrieve satellite and receiver clock corrections:
      my ( $sat_clk_bias,
           $rec_clk_bias ) = ( $sat_xyztc[3], $rec_apx_xyzdt[3] );

      # *Update satellite reception coordinates in epoch hash:
      $ref_epoch_info->{SAT_POSITION}{$sat}{RECEP} = [ @sat_xyz_recep,
                                                       $sat_clk_bias ];

      # 2. Receiver-Satellite line of sight treatment:
      my ($rec_lat, # REC geodetic coordinates
          $rec_lon,
          $rec_helip,
          $rec_sat_ix, # REC-SAT ECEF vector
          $rec_sat_iy,
          $rec_sat_iz,
          $rec_sat_ie, # REC-SAT ECEF vector
          $rec_sat_in,
          $rec_sat_iu,
          $rec_sat_azimut, # REC-SAT polar coordiantes
          $rec_sat_zenital,
          $rec_sat_distance,
          $rec_sat_elevation) = ReceiverSatelliteLoS( $ref_gen_conf,
                                                      \@rec_apx_xyzdt,
                                                      \@sat_xyz_recep );

      # 3. Tropospheric delay correction:
      #    NOTE: only Saastamoinen model available
      my $troposhpere_corr =
        &{$ref_sub_troposphere}( $rec_sat_zenital, $rec_helip );

      # 4. Ionospheric delay correction:
      #    NOTE: Klobuchar & NeQuick models available
      my ($ionosphere_corr_f1, $ionosphere_corr_f2) =
        &{$ref_sub_iono->{$sat_sys}} (
          $epoch,
          $leap_sec,
          \@sat_xyz_recep,
          [$rec_lat, $rec_lon, $rec_helip],
          $rec_sat_azimut, $rec_sat_elevation,
          $ref_iono_coeff->{$sat_sys}{ IONO_COEFF_1 },
          $ref_iono_coeff->{$sat_sys}{ IONO_COEFF_2 },
          $ref_gen_conf->{CARRIER_FREQUENCY}{$sat_sys}{F1},
          $ref_gen_conf->{CARRIER_FREQUENCY}{$sat_sys}{F2},
          $ref_gen_conf->{ELIPSOID},
        );

      # Fill LoS data in epoch info hash:
      FillLoSDataHash( $ref_epoch_info, $sat,
                       $rec_sat_azimut, $rec_sat_zenital,
                       $rec_sat_distance, $rec_sat_elevation,
                       $ionosphere_corr_f2, $troposhpere_corr,
                       [$rec_sat_ix, $rec_sat_iy, $rec_sat_iz],
                       [$rec_sat_ie, $rec_sat_in, $rec_sat_iu] );

      # Retrieve configured observation mean error:
      my $obs_err = $ref_gen_conf->{OBS_MEAN_ERR}{$sat_sys};

      # 5. Set pseudorange equation:
      SetPseudorangeEquation( # Inputs:
                              $j,
                              $raw_obs,
                              $obs_err,
                              $rec_sat_ix,
                              $rec_sat_iy,
                              $rec_sat_iz,
                              $sat_clk_bias,
                              $rec_clk_bias,
                              $ionosphere_corr_f2,
                              $troposhpere_corr,
                              $rec_sat_distance,
                              $rec_sat_elevation,
                              # Outputs:
                              $ref_design_matrix,
                              $ref_weight_matrix,
                              $ref_ind_term_matrix );

    } # end unless obs eq NULL
  } # end for $sat

  return TRUE;
}

sub FillLSQInfo {
  my ( $ref_epoch_info, $iter,
       $lsq_status, $conv_flag,
       $num_obs, $num_parameter,
       $ref_apx_prm, $pdl_parameter_vector,
       $pdl_residual_vector, $pdl_var_estimator ) = @_;

  # Build perl arrays from input piddles:
  my @prm_vector    = list( $pdl_parameter_vector );
  my @res_vector    = list( $pdl_residual_vector  );
  my $var_estimator = sclr( $pdl_var_estimator    );

  # Compute degrees of freedom:
  my $deg_of_free = $num_obs - $num_parameter;

  # Fill hash with retrieved data:
  $ref_epoch_info->{LSQ_INFO}[$iter]{ STATUS             } = $lsq_status;
  $ref_epoch_info->{LSQ_INFO}[$iter]{ CONVERGENCE        } = $conv_flag;
  $ref_epoch_info->{LSQ_INFO}[$iter]{ NUM_PARAMETER      } = $num_parameter;
  $ref_epoch_info->{LSQ_INFO}[$iter]{ NUM_OBSERVATION    } = $num_obs;
  $ref_epoch_info->{LSQ_INFO}[$iter]{ DEGREES_OF_FREEDOM } = $deg_of_free;
  $ref_epoch_info->{LSQ_INFO}[$iter]{ APX_PARAMETER      } = $ref_apx_prm;
  $ref_epoch_info->{LSQ_INFO}[$iter]{ PARAMETER_VECTOR   } = \@prm_vector;
  $ref_epoch_info->{LSQ_INFO}[$iter]{ RESIDUAL_VECTOR    } = \@res_vector;
  $ref_epoch_info->{LSQ_INFO}[$iter]{ VARIANCE_ESTIMATOR } = $var_estimator;
}

sub GetReceiverPositionSolution {
  my ($pdl_apx_parameters,
      $pdl_parameter_vector,
      $pdl_covar_matrix, $elipsoid ) = @_;

  # Receiver estimated position --> X = aX + dX:
  my @rec_est_xyzdt =
    list($pdl_apx_parameters + transpose($pdl_parameter_vector)->flat);

  # Split ECEF XYZ coordinate and receiver clock bias:
  my @rec_est_xyz = @rec_est_xyzdt[0..2];
  my $rec_est_clk = $rec_est_xyzdt[3];

  # Retrieve estimated parameter variances from covariance matrix:
  my @rec_var_xyz = (sclr( $pdl_covar_matrix->slice('0,0') ),
                     sclr( $pdl_covar_matrix->slice('1,1') ),
                     sclr( $pdl_covar_matrix->slice('2,2') ));
  my $rec_var_clk =  sclr( $pdl_covar_matrix->slice('3,3') );

  # Compute local ENU variances:
    # Get receiver geodetic coordinates:
    my ($lat, $lon, $helip) = ECEF2Geodetic( @rec_est_xyz, $elipsoid );

    # Slice Covaraicne matrix in order to trim the clock elements:
    my $pdl_ecef_covar_matrix = $pdl_covar_matrix->slice('0:2', '0:2');

    # Compute ENU covariance matrix:
    my $pdl_enu_covar_matrix =
      VarianceVxyz2Venu($lat, $lon, $pdl_ecef_covar_matrix);

    # Finally, retrieve ENU variances from computed matrix:
    my @rec_var_enu = ( sclr($pdl_enu_covar_matrix->slice('0,0')) ,
                        sclr($pdl_enu_covar_matrix->slice('1,1')) ,
                        sclr($pdl_enu_covar_matrix->slice('2,2'))  );

  return (\@rec_est_xyz, $rec_est_clk,
          \@rec_var_xyz, $rec_var_clk, \@rec_var_enu);
}

sub CheckConvergenceCriteria {
  my ($pdl_parameter_vector, $threshold) = @_;

  # Declare boolean answer:
  my $status;

  # Un-piddle parameter vector to array reference:
  my $ref_delta_parameters = unpdl(transpose($pdl_parameter_vector)->flat);

  # Retrieve delta parameters components:
  my ( $delta_x,
       $delta_y,
       $delta_z,
       $delta_clk ) = ( $ref_delta_parameters->[0],
                        $ref_delta_parameters->[1],
                        $ref_delta_parameters->[2],
                        $ref_delta_parameters->[3] );

  # Determine convergence criteria by computing the square root sumatory:
  $status = ( ModulusNth($delta_x, $delta_y, $delta_z) <= $threshold ) ?
            TRUE : FALSE;

  # Return boolean answer:
  return $status;
}

sub FillSolutionDataHash {
  my ($ref_epoch_info, $status,
      $ref_rec_est_xyz, $rec_est_clk,
      $ref_rec_var_xyz, $rec_var_clk, $ref_rec_var_enu) = @_;

  $ref_epoch_info->{REC_POSITION}{ STATUS  } = $status;
  $ref_epoch_info->{REC_POSITION}{ XYZ     } = $ref_rec_est_xyz;
  $ref_epoch_info->{REC_POSITION}{ CLK     } = $rec_est_clk;
  $ref_epoch_info->{REC_POSITION}{ VAR_XYZ } = $ref_rec_var_xyz;
  $ref_epoch_info->{REC_POSITION}{ VAR_CLK } = $rec_var_clk;
  $ref_epoch_info->{REC_POSITION}{ VAR_ENU } = $ref_rec_var_enu;


  return TRUE;
}

# ************************************************** #
# Second Level Subroutines:                          #
#   Subrotuines that are called from 1st level subs. #
# ************************************************** #

sub FillMissingRinexWarning {
  my ($sat_sys, $iono_model, $rinex_sat_sys) = @_;

  my $msg = "Selected ionosphere model for $sat_sys was $iono_model, ".
            "meaning that ionosphere coefficients must be retrieved ".
            "from a $rinex_sat_sys RINEX navigation file. However, ".
            "seems like no such file has been specified. Please, ".
            "double-check your configuration.";

  return $msg;
}

sub FillIonoCoefficientWarning {
  my ($sat_sys, $rinex_nav_version, @iono_coeffs) = @_;

  my $coeff_list = join(', ', @iono_coeffs);

  return "Could not find ionosphere coefficients: $coeff_list, for ".
         "constellation '$sat_sys' in RINEX NAV V$rinex_nav_version file.";
}

sub InitLSQSatelliteCounter {
  my ($ref_epoch_info, $ref_selected_sat_sys) = @_;

  for my $entry (@{ $ref_selected_sat_sys }, 'ALL') {
    $ref_epoch_info->{NUM_SAT_INFO}{$entry}{VALID_LSQ}{NUM_SAT} = 0;
    $ref_epoch_info->{NUM_SAT_INFO}{$entry}{VALID_LSQ}{SAT_IDS} = [];
  }

  return TRUE;
}

sub CountValidSatForLSQ {
  my ($sat_sys, $sat_id, $ref_num_sat_info) = @_;

  for my $entry ($sat_sys, 'ALL') {
    $ref_num_sat_info->{$entry}{VALID_LSQ}{NUM_SAT} += 1;
    PushUnique( $ref_num_sat_info->{$entry}{VALID_LSQ}{SAT_IDS}, $sat_id);
  }

  return TRUE;
}

sub SelectApproximateParameters {
  my ( $first_solution_flag,
       $ref_rinex_obs, $epoch_index,
       $ref_iter_solution, $iter ) = @_;

  # Init aproximate position parameters:
  my @rec_apx_xyzdt;

  # Selection of approximate position parameters:
  if ( $iter == 0 )
  {
    # Approximate parametrs are extracted from a previous epoch or from
    # the rinex header:
    if ( $first_solution_flag ) {
      # Count back until a valid position solution is found:
      my $count = 1;
      until ($ref_rinex_obs ->
              {BODY}[$epoch_index - $count]{REC_POSITION}{STATUS})
      { $count += 1; }

      # Set found position solution as approximate parameters:
      # Build array with receiver ECEF coordinates and clock bias
      @rec_apx_xyzdt =
        ( @{ $ref_rinex_obs->
              {BODY}[$epoch_index - $count]{REC_POSITION}{XYZ} },
             $ref_rinex_obs->
              {BODY}[$epoch_index - $count]{REC_POSITION}{CLK} );

    } else {
      # Approximate position parameters come from RINEX header:
      # NOTE: Receiver clock bias is init to 0:
      @rec_apx_xyzdt = (@{$ref_rinex_obs->{HEAD}{APX_POSITION}}, 0);
    } # end if ($first_solution_flag)

  } else {
    # Approximate position parameters come from previous iteration:
    @rec_apx_xyzdt = @{$ref_iter_solution->[$iter - 1]};
  } # end if ($iteration == 0)

  return @rec_apx_xyzdt;
}

sub SatPositionFromEmission2Reception {
  my ($sat_x, $sat_y, $sat_z, $rec_x, $rec_y, $rec_z) = @_;

  # Compute signal travelling time from satellite to receiver:
  my $time_to_recep = ModulusNth( ($rec_x - $sat_x),
                                  ($rec_y - $sat_y),
                                  ($rec_z - $sat_z) ) / SPEED_OF_LIGHT;

  # Elapsed earth's rotation during signla travelling:
  my $earth_rotation = EARTH_ANGULAR_SPEED * $time_to_recep; # [rad]

  # Return propagated satellite coordinates at signal reception:
  # NOTE: Apply Z's rotation matrix in ECEF Z axis:
  return (    $sat_x*cos($earth_rotation) + $sat_y*sin($earth_rotation),
           -1*$sat_x*sin($earth_rotation) + $sat_y*cos($earth_rotation),
                                                                $sat_z);
}

sub ReceiverSatelliteLoS {
  my ( $ref_gen_conf, $ref_rec_xyz, $ref_sat_xyz ) = @_;

  # Retrieve satellite coordinates:
  my ( $sat_x, $sat_y, $sat_z ) =
     ( $ref_sat_xyz->[0], $ref_sat_xyz->[1], $ref_sat_xyz->[2] );
  my ( $rec_x, $rec_y, $rec_z ) =
     ( $ref_rec_xyz->[0], $ref_rec_xyz->[1], $ref_rec_xyz->[2] );

  # Receiver-Satellite ECEF vector:
  my ( $rec_sat_ix,
       $rec_sat_iy,
       $rec_sat_iz ) = ( $sat_x - $rec_x,
                         $sat_y - $rec_y,
                         $sat_z - $rec_z );

  # Receiver's ECEF to Geodetic coordinate transformation:
  my ( $rec_lat,
       $rec_lon,
       $rec_helip ) = ECEF2Geodetic( $rec_x,
                                     $rec_y,
                                     $rec_z,
                                     $ref_gen_conf->{ELIPSOID} );

  # Receiver-Satellite: azimut, elevation and distance
  # Vector transformation ECEF to ENU (geocentric cartesian
  # vector to receiver's local vector):
  my ( $rec_sat_ie,
       $rec_sat_in,
       $rec_sat_iu ) = Vxyz2Venu( $rec_sat_ix,
                                  $rec_sat_iy,
                                  $rec_sat_iz,
                                  $rec_lat, $rec_lon );

  # Compute Rec-Sat azimut, zenital angle and distance:
  my ( $rec_sat_azimut,
       $rec_sat_zenital,
       $rec_sat_distance ) = Venu2AzZeDs( $rec_sat_ie,
                                          $rec_sat_in,
                                          $rec_sat_iu );

  # Rec-Sat elevation is computed as follows:
  my $rec_sat_elevation = pi/2 - $rec_sat_zenital;

  return ( $rec_lat, $rec_lon, $rec_helip,
           $rec_sat_ix, $rec_sat_iy, $rec_sat_iz,
           $rec_sat_ie, $rec_sat_in, $rec_sat_iu,
           $rec_sat_azimut, $rec_sat_zenital,
           $rec_sat_distance, $rec_sat_elevation );
}

sub SetPseudorangeEquation {
  my ( # Inputs:
        $iobs, # observation index
        $raw_obs, # raw REC-SV observation
        $obs_mean_err, # configured observation mean error
        $ix, $iy, $iz, # REC-SV ECEF vector components
        $sat_clk_bias, $rec_clk_bias, # SV & REC clock biases
        $ionosphere_corr, $troposhpere_corr, # tropo & iono LoS delays
        $rec_sat_distance, $rec_sat_elevation, # REC-SV distance & elevation
       # Outputs -> LSQ matrix references:
        $ref_design_matrix, $ref_weight_matrix, $ref_ind_term_matrix ) = @_;

  # 1. Design matrix row terms:
  $ref_design_matrix->[$iobs][0] = -1*($ix/$rec_sat_distance);
  $ref_design_matrix->[$iobs][1] = -1*($iy/$rec_sat_distance);
  $ref_design_matrix->[$iobs][2] = -1*($iz/$rec_sat_distance);
  $ref_design_matrix->[$iobs][3] =  1;

  # 2. Observation weight term:
    # Factor for accounting the observation mean precision:
    # NOTE: the observation mean error is scaled 1.5 times in order to
    #       account for the maximum tolerance
    my $aux_fact = 1.5*$obs_mean_err;
    # Compute weight term:
    $ref_weight_matrix->[$iobs][$iobs] = (sin($rec_sat_elevation)/$aux_fact)**2;

  # 3. Observation Independent term -> GNSS pseudorange equation:
  $ref_ind_term_matrix->[$iobs][0] =
    ( $raw_obs - $rec_sat_distance - $rec_clk_bias +
      SPEED_OF_LIGHT*$sat_clk_bias - $troposhpere_corr - $ionosphere_corr );
}

sub FillLoSDataHash {
  my ( $ref_epoch_info, $sat,
       $rec_sat_azimut, $rec_sat_zenital,
       $rec_sat_distance, $rec_sat_elevation,
       $ionosphere_corr, $troposphere_corr,
       $ref_rec_sat_ecef_vector, $ref_rec_sat_enu_vector ) = @_;

  $ref_epoch_info->{SAT_LOS}{$sat}->{ AZIMUT      } = $rec_sat_azimut;
  $ref_epoch_info->{SAT_LOS}{$sat}->{ ZENITAL     } = $rec_sat_zenital;
  $ref_epoch_info->{SAT_LOS}{$sat}->{ DISTANCE    } = $rec_sat_distance;
  $ref_epoch_info->{SAT_LOS}{$sat}->{ ELEVATION   } = $rec_sat_elevation;
  $ref_epoch_info->{SAT_LOS}{$sat}->{ IONO_CORR   } = $ionosphere_corr;
  $ref_epoch_info->{SAT_LOS}{$sat}->{ TROPO_CORR  } = $troposphere_corr;
  $ref_epoch_info->{SAT_LOS}{$sat}->{ ENU_VECTOR  } = $ref_rec_sat_enu_vector;
  $ref_epoch_info->{SAT_LOS}{$sat}->{ ECEF_VECTOR } = $ref_rec_sat_ecef_vector;

  return TRUE;
}


TRUE;
