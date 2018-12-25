#!/usr/bin/perl -w

# Package declaration:
package RecPosition;


# NOTE: SCRIPT DESCRIPTION GOES HERE:


# Import Modules:
# ---------------------------------------------------------------------------- #
use strict;   # enables strict syntax...

use PDL;                                # loads Perl Data Language extension...
use PDL::Constants qw(PI);
use Scalar::Util qq(looks_like_number); # scalar utility...

use feature qq(say);    # print adding carriage return...
use feature qq(switch); # switch functionality...
use Data::Dumper;       # enables pretty print...

# Import configuration and common interface module:
use lib qq(/home/ppinto/TFM/src/); # TODO: this should be an enviroment!
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

# Module specific warning codes:
use constant {
  WARN_OBS_NOT_VALID                 => 90301,
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

    # Ionosphere model switch case:
    my %sub_iono; my $ref_sub_iono = \%sub_iono;

    for my $sat_sys ( @{$ref_gen_conf->{SELECTED_SAT_SYS}} ) {
      given ( $ref_gen_conf->{IONOSPHERE_MODEL}{$sat_sys} ) {
        when ( /nequick/i   )
          { $ref_sub_iono->{$sat_sys} = \&ComputeIonoNeQuickDelay;   }
        when ( /klobuchar/i )
          { $ref_sub_iono->{$sat_sys} = \&ComputeIonoKlobucharDelay; }
      }
    }

  # **************************** #
  # Position estimation routine: #
  # **************************** #

    # Init first succesfully estimated epoch flag:
    my $first_solution_flag = FALSE;

    # Iterate over the observation epochs:
    for (my $i = 0; $i < scalar(@{$ref_rinex_obs->{BODY}}); $i += 1)
    {
      #
      my $ref_epoch_info = $ref_rinex_obs->{BODY}[$i];

      # Init receiver position solution info in observation hash:
      $ref_epoch_info->{POSITION_SOLUTION}{ STATUS      } = FALSE;
      $ref_epoch_info->{POSITION_SOLUTION}{ XYZDT       } = undef;
      $ref_epoch_info->{POSITION_SOLUTION}{ APX_XYZDT   } = undef;
      $ref_epoch_info->{POSITION_SOLUTION}{ SIGMA_XYZDT } = undef;

      # Init references to hold estimated position and associated
      # variances:
      my ($ref_rec_est_xyzdt, $ref_rec_var_xyzdt);

      # Save epoch and observation health status:
      my ($epoch, $epoch_status) = ($ref_epoch_info->{EPOCH},
                                    $ref_epoch_info->{STATUS});

      # Discard invalid epochs:
      if ( $epoch_status == HEALTHY_OBSERVATION_BLOCK )
      {
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

          # Fill approximate parameters in epoch info hash:
          $ref_epoch_info->{POSITION_SOLUTION}{APX_XYZDT} = \@rec_apx_xyzdt;

          # Init LSQ matrix system as arrays:
          my @design_matrix; my @weight_vector; my @ind_term_vector;

          # Build LSQ matrix system array references:
          my ( $ref_design_matrix,
               $ref_weight_vector,
               $ref_ind_term_vector ) = ( \@design_matrix,
                                          \@weight_vector,
                                          \@ind_term_vector );

          # Iterate over the observed satellites:
          for my $sat (keys %{$ref_epoch_info->{SAT_OBS}})
          {
            # Identify GNSS constellation:
            my $sat_sys = substr($sat, 0, 1);

            # Get receiver-satellite observation measurement:
            my $signal  = $ref_gen_conf->{SELECTED_SIGNALS}{$sat_sys};
            my $raw_obs = $ref_epoch_info->{SAT_OBS}{$sat}{$signal};

            # Discard NULL observations:
            unless ( $raw_obs eq NULL_OBSERVATION )
            {
              # Save satellite coordinates:
              my @sat_xyztc = @{ $ref_epoch_info->{SAT_NAV}{$sat} };

              # ************************************ #
              # Build pseudorange equation sequence: #
              # ************************************ #

              # 1. Retrieve satellite and receiver clock corrections:
              my ( $sat_clk_bias,
                   $rec_clk_bias ) = ( $sat_xyztc[3], $rec_apx_xyzdt[3] );

              # 2. Propagate satellite position to the epoch when the receiver
              #    started to receive its signal
              my @sat_xyz_recep =
                 SatPositionFromEmission2Reception( $sat_xyztc     [0],
                                                    $sat_xyztc     [1],
                                                    $sat_xyztc     [2],
                                                    $rec_apx_xyzdt [0],
                                                    $rec_apx_xyzdt [1],
                                                    $rec_apx_xyzdt [2], );

              # 3. Receiver-Satellite line of sight:
              my ($rec_lat, # REC geodetic coordinates
                  $rec_lon,
                  $rec_helip,
                  $rec_sat_ix, # REC-SAT ECEF vector
                  $rec_sat_iy,
                  $rec_sat_iz,
                  $rec_sat_azimut, # REC-SAT polar coordiantes
                  $rec_sat_zenital,
                  $rec_sat_distance) = ReceiverSatelliteLoS( $ref_gen_conf,
                                                             \@rec_apx_xyzdt,
                                                             \@sat_xyz_recep );

              # Elevation angle is computed as follows:
              my $rec_sat_elevation = PI/2 - $rec_sat_zenital;

              # 4. Mask filtering:
              if ( $rec_sat_elevation >= $ref_gen_conf->{SAT_MASK} )
              {
                # 5. Tropospheric delay correction:
                my $troposhpere_corr =
                  &{$ref_sub_troposphere}( $rec_sat_zenital, $rec_helip );

                # 6. Ionospheric delay correction:
                # TODO: NAV RINEX V3 does not include IONO_ALPHA and IONO_BETA
                #       parametes. Furthermore, it depends if they sat is
                #       GAL or GPS
                my ($ionosphere_corr, $ionosphere_corr_l2) =
                  &{$ref_sub_iono->{$sat_sys}}
                    ( $epoch,
                      $rec_lat, $rec_lon,
                      $rec_sat_azimut, $rec_sat_elevation,
                      $ref_sat_sys_nav->{$sat_sys}{HEAD}{ ION_ALPHA },
                      $ref_sat_sys_nav->{$sat_sys}{HEAD}{ ION_BETA  } );

                # 7. Set pseudorange equation:
                SetPseudorangeEquation( # Inputs:
                                        $raw_obs,
                                        $rec_sat_ix,
                                        $rec_sat_iy,
                                        $rec_sat_iz,
                                        $sat_clk_bias,
                                        $rec_clk_bias,
                                        $ionosphere_corr,
                                        $troposhpere_corr,
                                        $rec_sat_distance,
                                        $rec_sat_elevation,
                                        # Outputs:
                                        $ref_design_matrix,
                                        $ref_weight_vector,
                                        $ref_ind_term_vector );

              } # end if $elevation >= mask
            } # end unless obs eq NULL
          } # end for $sat

          # ************************ #
          # LSQ position estimation: #
          # ************************ #
          my ( $lsq_status,
               $pdl_parameter_vector,
               $pdl_residual_vector,
               $pdl_covariance_matrix,
               $pdl_variance_estimator ) = SolveWeightedLSQ (
                                             $ref_design_matrix,
                                             $ref_weight_vector,
                                             $ref_ind_term_vector
                                           );

          # Check for successful LSQ estimation:
          if ( $lsq_status )
          {
            # Update iteration status:
            $iter_status = TRUE;

            # Set Receiver's approximate parameters as PDL piddle:
            my $pdl_rec_apx_xyzdt = pdl @rec_apx_xyzdt;

            # Get estimated receiver position and solution variances:
            ( $ref_rec_est_xyzdt,
              $ref_rec_var_xyzdt ) = GetReceiverPositionSolution(
                                        $pdl_rec_apx_xyzdt,
                                        $pdl_parameter_vector,
                                        $pdl_covariance_matrix
                                      );

            # Save iteration solution:
            $iter_solution[$iteration] = $ref_rec_est_xyzdt;

            # Update number of elapsed iterations:
            $iteration += 1;

            # Check for convergence criteria:
            $convergence_flag =
              CheckConvergenceCriteria($ref_rec_var_xyzdt->[0],
                                       $ref_rec_var_xyzdt->[1],
                                       $ref_rec_var_xyzdt->[2],
                                       $ref_gen_conf->{CONVERGENCE_THRESHOLD});

          } else {

            # If LSQ estimation was not successful, raise a warning and last
            # the iteration loop, so the next epoch can be processed:
            RaiseWarning($fh_log, WARN_NOT_SUCCESSFUL_LSQ_ESTIMATION,
              "Least squeares estimation routine was not successful at ".
              "observation epoch $epoch",
              "This is most likely due to a non-redundant LSQ matrix system, ".
              "where the number of observations are equal or less than the ".
              "number of parameters to be estimated.");

            # Set iteration status and exit the iteration loop:
            $iter_status = FALSE; last;

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

          # Compute standard deviations:
          # NOTE: 68% reliability percentile
          my @rec_sigma = map{ $_**0.5 } @{$ref_rec_var_xyzdt};

          # Store receiver position solution and standard deviations in
          # observation rinex hash:
          # NOTE: receiver solution and standard deviations come from last
          #       iteration solution
          $ref_epoch_info->{POSITION_SOLUTION}{ STATUS } = TRUE;
          $ref_epoch_info->{POSITION_SOLUTION}{ XYZDT  } = $ref_rec_est_xyzdt;
          $ref_epoch_info->{POSITION_SOLUTION}{ SIGMA_XYZDT } = \@rec_sigma;

        } # end if $iter_status

      } # end if $epoch_status == HEALTHY_OBSERVATION_BLOCK
    } # end for $i

  # If the subroutine was successful, it will answer with TRUE boolean:
  return TRUE;
}

# Private Subroutines:                                                         #
# ............................................................................ #
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
              {BODY}[$epoch_index - $count]{POSITION_SOLUTION}{STATUS})
      { $count += 1; }

      # Set found position solution as approximate parameters:
      @rec_apx_xyzdt =
        @{ $ref_rinex_obs ->
            {BODY}[$epoch_index - $count]{POSITION_SOLUTION}{XYZDT} };

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

  return ( $rec_lat, $rec_lon, $rec_helip,
           $rec_sat_ix, $rec_sat_iy, $rec_sat_iz,
           $rec_sat_azimut, $rec_sat_zenital, $rec_sat_distance );
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

sub SetPseudorangeEquation {
  my ( # Inputs:
        $raw_obs,
        $ix, $iy, $iz,
        $sat_clk_bias, $rec_clk_bias,
        $ionosphere_corr, $troposhpere_corr,
        $rec_sat_distance, $rec_sat_elevation,
       # Outputs:
        $ref_design_matrix, $ref_weight_vector, $ref_ind_term_vector ) = @_;

  # 1. Design matrix row elements:
  my @design_row = ( -1*($ix/$rec_sat_distance),
                     -1*($iy/$rec_sat_distance),
                     -1*($iz/$rec_sat_distance),
                      1 );

  # 2. Weight term row element:
  my $ep2 = 1.5*0.3; # TODO: Review Hofmann et al. 2008
                     # Seems like a coeficient for P2 observable
  my @weight_row = ( sin($rec_sat_elevation)**2/$ep2**2 );

  # 3. Independent term row elements:
  my @ind_term_row = ( $raw_obs - $rec_sat_distance -
                       $rec_clk_bias + SPEED_OF_LIGHT*$sat_clk_bias -
                       $troposhpere_corr - $ionosphere_corr );

  # Append to matrix references:
    push(@{$ref_design_matrix}  , \@design_row);
    push(@{$ref_weight_vector}  , \@weight_row);
    push(@{$ref_ind_term_vector}, \@ind_term_row);

}

sub GetReceiverPositionSolution {
  my ($pdl_apx_parameters, $pdl_parameter_vector, $pdl_covar_matrix ) = @_;

  my @rec_est_xyzdt =
    list($pdl_apx_parameters + transpose($pdl_parameter_vector));

  # Retrieve estimated parameter variances from covariance matrix:
  my @rec_var_xyzdt = ( list($pdl_covar_matrix->slice('0,0')),
                        list($pdl_covar_matrix->slice('1,1')),
                        list($pdl_covar_matrix->slice('2,2')),
                        list($pdl_covar_matrix->slice('3,3')) );

  return (\@rec_est_xyzdt, \@rec_var_xyzdt);
}

sub CheckConvergenceCriteria {
  my ($var_x, $var_y, $var_z, $threshold) = @_;

  # Declare boolean answer:
  my $status;

  # Determine convergence criteria by computing the square root sumatory:
  $status = ( ($var_x + $var_y + $var_z)**0.5 <= $threshold ) ? TRUE : FALSE;

  # Return boolean answer:
  return $status;
}


TRUE;
