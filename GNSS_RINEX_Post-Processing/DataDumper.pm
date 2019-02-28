#!/usr/bin/perl -w

# Package declaration:
package DataDumper;


# TODO: SCRIPT DESCRIPTION GOES HERE:
# TODO: New dumper for satellite residual from LSQ info (by sat_sys/by epoch)
#       \_ Include this in already existing LSQ_info dumper
# TODO: New dumper file with LSQ info per epoch!

# Load bash enviroments:
# ---------------------------------------------------------------------------- #
use lib $ENV{ ENV_ROOT };
use Enviroments qq(:CONSTANTS);

# Import modules:
# ---------------------------------------------------------------------------- #
use Carp;         # enables advanced warning and failure raise...
use strict;       # enables strict syntax and common mistakes advisory...
use Data::Dumper; # enables nested struct pretty print...

use feature      qq(say);               # same as print.$text.'\n'...
use feature      qq(switch);            # switch functionality...
use Scalar::Util qq(looks_like_number); # scalar utility...

# Import configuration and common interfaces module:
use lib SRC_ROOT_PATH;
use GeneralConfiguration qq(:ALL);

# Import dedicated libraries:
use lib LIB_ROOT_PATH;
# Common tools:
use MyUtil   qq(:ALL); # useful subs and constants...
use MyPrint  qq(:ALL); # print and warning/failure utilities...
# GNSS dedicated tools:
use Geodetic qq(:ALL); # geodetic toolbox...
use TimeGNSS qq(:ALL); # GNSS time transforming utilities...

# Import dependent modules:
use lib GRPP_ROOT_PATH;
use RinexReader qq(:ALL);
use ErrorSource qq(:ALL);
use SatPosition qq(:ALL);
use RecPosition qq(:ALL);

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
  our @EXPORT_SUB   = qw( &DumpSatObsData
                          &DumpSatPosition
                          &DumpRecSatLoSData
                          &DumpLSQReport
                          &DumpRecPosition
                          &DumpNumValidSat
                          &DumpEpochDOP
                          &DumpAzimutBySat
                          &DumpElevationBySat
                          &DumpIonoCorrBySat
                          &DumpTropoCorrBySat
                          &DumpResidualsBySat );

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
# NULL data constant:
use constant NULL_DATA => 'NULL';

use constant {
  WARN_NO_SELECTED_OBS => 90101,
};

# ---------------------------------------------------------------------------- #
# Subroutines:
# ---------------------------------------------------------------------------- #

# Public Subroutines: #
# ............................................................................ #
sub DumpSatObsData {
  my ( $ref_gen_conf, $ref_obs_data,
       $ref_selected_obs, $output_path, $fh_log ) = @_;

  # Default input values if not defined:
  $fh_log = *STDOUT unless $fh_log;

  # ************************* #
  # Input consistency cehcks: #
  # ************************* #

  # Output path must exist and have write permissions:
  unless (-w $output_path) {
    RaiseError($fh_log, ERR_WRITE_PERMISSION_DENIED,
      "User '".$ENV{USER}."' does not have write permissions at $output_path");
    return KILLED;
  }

  # General configuration must be hash type:
  unless (ref($ref_gen_conf) eq 'HASH') {
    RaiseError($fh_log, ERR_WRONG_HASH_REF,
      "Input argument \'$ref_gen_conf\' is not HASH type");
    return KILLED;
  }

  # Observation data must be hash type:
  unless (ref($ref_obs_data) eq 'HASH') {
    RaiseError($fh_log, ERR_WRONG_HASH_REF,
      "Input argument \'$ref_obs_data\' is not HASH type");
    return KILLED;
  }

  # Selected observations must be array type:
  unless (ref($ref_selected_obs) eq 'ARRAY') {
    RaiseError($fh_log, ERR_WRONG_ARRAY_REF,
      "Input argument \'$ref_selected_obs\' is not ARRAY type");
    return KILLED;
  }

  # ******************************************* #
  # Satellite Observations data dumper routine: #
  # ******************************************* #

  # De-reference array inputs:
  my @selected_obs   = @{ $ref_selected_obs   };

  # Save dumper useful configuration:
  my $delimiter    = $ref_gen_conf->{DATA_DUMPER}{ DELIMITER    };
  my $epoch_format = $ref_gen_conf->{DATA_DUMPER}{ EPOCH_FORMAT };

  my $ref_epoch_sub = REF_EPOCH_SUB_CONF->{$epoch_format};

  # Dump the data for each selected GNSS constellation:
  for my $sat_sys (@{$ref_gen_conf->{SELECTED_SAT_SYS}})
  {
    # 1. Open dumper file at output path:
      my $file_path = join('/', ($output_path, "$sat_sys-sat-obs-data.out"));
      my $fh; open($fh, '>', $file_path) or die "Could not create $!";

    # 2. Write title line:
      say $fh sprintf("# > Constellation '$sat_sys' acquired observations.\n".
                      "# > Observation epoch status info:\n".
                      "#   0   --> OK\n".
                      "#   1-6 --> NOK\n".
                      "# > Created : %s",
                      GetPrettyLocalDate());

    # 3. Write header:
      # Check for constellation available observations:
      my @sat_sys_obs;
      my @avail_obs = @{ $ref_obs_data->{HEAD}{SYS_OBS_TYPES}{$sat_sys}{OBS} };

      # Filter available observations by the selected ones:
      for my $obs (sort @avail_obs) {
        push(@sat_sys_obs, $obs) if (grep(/^$obs$/, @selected_obs));
      }

      # Raise Warning if no observations are left:
      unless( @sat_sys_obs ) {
        RaiseWarning($fh_log, WARN_NO_SELECTED_OBS,
          "No observations for constellation '$sat_sys' have been selected.\n".
          "Please, reconsider the following configuration: \n".
          "  - Available observations : ".join(', ', @avail_obs)."\n".
          "  - Selected  observations : ".join(', ', @selected_obs));
      }

      # Header line items:
      my @header_items = ( SetEpochHeaderItems($epoch_format),
                           qw(ObsStatus SatID) );
      push(@header_items, ($_, "$_-NumValidSat")) for (@sat_sys_obs);

      # Write header:
      say $fh "#".join($delimiter, @header_items);

    # 4. Dump satellite observations:
      for (my $i = 0; $i < scalar(@{$ref_obs_data->{BODY}}); $i += 1)
      {
        # Save epoch data reference:
        my $ref_epoch_data = $ref_obs_data->{BODY}[$i];

        # Save observation epoch status:
        my $status = $ref_epoch_data->{STATUS};

        # Epoch is transformed according to configuration:
        my @epoch = &{$ref_epoch_sub}( $ref_epoch_data->{EPOCH} );

        # Write observation data:
        for my $sat (sort ( keys %{$ref_epoch_data->{SAT_OBS}} )) {

          # Identify constellation:
          my $sat_sys = substr($sat, 0, 1);

          # Set line elements:
          my @line_items = (@epoch, $status, $sat);

          # Include selected observations:
          for (@sat_sys_obs) {
            push( @line_items,
                  ($ref_epoch_data->{SAT_OBS}{$sat}{$_},
                   $ref_epoch_data->{NUM_SAT_INFO}{$sat_sys}
                                    {VALID_OBS}{$_}{NUM_SAT}) );
          }

          # Dump observation data:
          say $fh join($delimiter, @line_items);

        } # end for my $sat

      } # end for $i

    # 5. Close dumper file:
      close($fh);

  } # end for $sat_sys

  # Sub's answer is TRUE if successfull:
  return TRUE;
}

sub DumpSatPosition {
  my ( $ref_gen_conf, $ref_obs_data, $output_path, $fh_log ) = @_;

  # Default input values if not defined:
  $fh_log = *STDOUT unless $fh_log;

  # ************************* #
  # Input consistency cehcks: #
  # ************************* #

  # Output path must exist and have write permissions:
  unless (-w $output_path) {
   RaiseError($fh_log, ERR_WRITE_PERMISSION_DENIED,
     "User '".$ENV{USER}."' does not have write permissions at $output_path");
   return KILLED;
  }

  # General configuration must be hash type:
  unless (ref($ref_gen_conf) eq 'HASH') {
   RaiseError($fh_log, ERR_WRONG_HASH_REF,
     "Input argument \'$ref_gen_conf\' is not HASH type");
   return KILLED;
  }

  # Observation data must be hash type:
  unless (ref($ref_obs_data) eq 'HASH') {
   RaiseError($fh_log, ERR_WRONG_HASH_REF,
     "Input argument \'$ref_obs_data\' is not HASH type");
   return KILLED;
  }


  # ********************************** #
  # Satellite position dumper routine: #
  # ********************************** #

  # Save dumper useful configuration:
  my $delimiter    = $ref_gen_conf->{DATA_DUMPER}{ DELIMITER    };
  my $epoch_format = $ref_gen_conf->{DATA_DUMPER}{ EPOCH_FORMAT };
  my $angle_format = $ref_gen_conf->{DATA_DUMPER}{ ANGLE_FORMAT };

  my $ref_epoch_sub = REF_EPOCH_SUB_CONF->{$epoch_format};
  my $ref_angle_sub = REF_ANGLE_SUB_CONF->{$angle_format};

  for my $sat_sys (@{ $ref_gen_conf->{SELECTED_SAT_SYS} })
  {
    # 1. Open dumper file at output path:
      my $file_path = join('/', ($output_path, "$sat_sys-sat-xyz.out"));
      my $fh; open($fh, '>', $file_path) or die "Could not create $!";

    # 2. Write title line:
      say $fh sprintf("# > Constellation '$sat_sys' navigation data.\n".
                      "# > Reference system for ECEF coordinates : %s\n".
                      "# > Created  : %s",
                      $ref_gen_conf->{ELIPSOID}, GetPrettyLocalDate());

    # 3. Write header line:
      my @header_items = ( SetEpochHeaderItems( $epoch_format ),
                           qw( NumSatValidNav SatID SatNavStatus
                               NavX NavY NavZ SatClockBias
                               RecepX RecepY RecepZ
                               NavLat NavLon NavElipHeight
                               RecepLat RecepLon RecepElipHeight ) );

      say $fh "#".join($delimiter, @header_items);

    # 4. Write Line of Sight data:
      # Go through the observations epochs:
      for (my $i = 0; $i < scalar(@{ $ref_obs_data->{BODY} }); $i += 1)
      {
        # Epoch is transformed according to configuration:
        my @epoch = &{ $ref_epoch_sub }( $ref_obs_data->{BODY}[$i]{EPOCH} );

        # Retrieve number of satellites with valid navigation data:
        my $num_sat =
          $ref_obs_data->{BODY}[$i]{NUM_SAT_INFO}{$sat_sys}{VALID_NAV}{NUM_SAT};

        # Go through available satellites in hash:
        for my $sat (sort (keys %{ $ref_obs_data->{BODY}[$i]{SAT_POSITION} }))
        {
          # Save satellite position data reference:
          my $ref_sat_position = $ref_obs_data->{BODY}[$i]{SAT_POSITION}{$sat};

          # Retrieve satellite navigation status:
          my $sat_status = $ref_sat_position->{NAV}{STATUS};

          # Satellite ECEF coordinates and clock bias:
          my @sat_xyz_clkbias = @{ $ref_sat_position->{NAV}{XYZ_TC} };

          # Init ECEF and Geodetic satellite coordinates and clock bias:
          my @sat_recep_xyz;
          my ($sat_lat, $sat_lon, $sat_helip);
          my ($recep_lat, $recep_lon, $recep_helip);

          # Set reception and geodetic coordinates if valid navigation data is
          # available:
          if ($sat_status) {

            # Retrieve reception ECEF coordinates:
            @sat_recep_xyz = @{ $ref_sat_position->{RECEP} }[0..2];

            # Compute geodetic navigation coordinates:
            ($sat_lat, $sat_lon, $sat_helip) =
              ECEF2Geodetic(@sat_xyz_clkbias[0..2], $ref_gen_conf->{ELIPSOID});

            # Compute geodetic reception  coordinates:
            ($recep_lat, $recep_lon, $recep_helip) =
              ECEF2Geodetic(@sat_recep_xyz, $ref_gen_conf->{ELIPSOID});

          } else {
            # Set null information for invalid navigation status:
            @sat_recep_xyz = (0, 0, 0);
            ($sat_lat, $sat_lon, $sat_helip) = (0, 0, 0);
            ($recep_lat, $recep_lon, $recep_helip) = (0, 0, 0);
          }

          # Latitude and longitude are transformed according to configuration:
          ($sat_lat, $sat_lon,
           $recep_lat, $recep_lon) = &{$ref_angle_sub}($sat_lat, $sat_lon,
                                                       $recep_lat, $recep_lon);

          # Save line items:
          my @line_items = (@epoch,
                            $num_sat, $sat, $sat_status,
                            @sat_xyz_clkbias, @sat_recep_xyz,
                            $sat_lat, $sat_lon, $sat_helip,
                            $recep_lat, $recep_lon, $recep_helip );

          # Write data line:
          say $fh join($delimiter, @line_items);

        } # end for $sat
      } # end for $i

    # 5. Close dumper file:
    close($fh);

  } # end for $sat_sys

  # Sub's answer is TRUE if successfull:
  return TRUE;
}

sub DumpRecSatLoSData {
  my ($ref_gen_conf, $ref_obs_data, $output_path, $fh_log) = @_;

  # Default input values if not defined:
  $fh_log = *STDOUT unless $fh_log;

  # ************************* #
  # Input consistency cehcks: #
  # ************************* #

  # Output path must exist and have write permissions:
  unless (-w $output_path) {
    RaiseError($fh_log, ERR_WRITE_PERMISSION_DENIED,
      "User '".$ENV{USER}."' does not have write permissions at $output_path");
    return KILLED;
  }

  # General configuration must be hash type:
  unless (ref($ref_gen_conf) eq 'HASH') {
    RaiseError($fh_log, ERR_WRONG_HASH_REF,
      "Input argument \'$ref_gen_conf\' is not HASH type");
    return KILLED;
  }

  # Observation data must be hash type:
  unless (ref($ref_obs_data) eq 'HASH') {
    RaiseError($fh_log, ERR_WRONG_HASH_REF,
      "Input argument \'$ref_obs_data\' is not HASH type");
    return KILLED;
  }

  # ************************************** #
  # Receiver-Satellite LoS dumper routine: #
  # ************************************** #

  # Save dumper useful configuration:
  my $delimiter    = $ref_gen_conf->{DATA_DUMPER}{ DELIMITER    };
  my $epoch_format = $ref_gen_conf->{DATA_DUMPER}{ EPOCH_FORMAT };
  my $angle_format = $ref_gen_conf->{DATA_DUMPER}{ ANGLE_FORMAT };

  my $ref_epoch_sub = REF_EPOCH_SUB_CONF->{$epoch_format};
  my $ref_angle_sub = REF_ANGLE_SUB_CONF->{$angle_format};

  # Create file for each selected constellation:
  for my $sat_sys (@{ $ref_gen_conf->{SELECTED_SAT_SYS} })
  {
    # 1. Open dumper file at output path:
      my $file_path = join('/', ($output_path, "$sat_sys-LoS-data.out"));
      my $fh; open($fh, '>', $file_path) or croak "Could not create $!";

    # 2. Write title line:
      my $rec_name = $ref_obs_data->{HEAD}{MARKER_NAME};
      say $fh sprintf("# > Constellation '$sat_sys' Line of Sight data ".
                      "from '$rec_name' receiver\n".
                      "# > Reference system for ECEF coordinates : %s\n".
                      "# > Created : %s",
                      $ref_gen_conf->{ELIPSOID}, GetPrettyLocalDate());

    # 3. Write header line:
      my @header_items = ( SetEpochHeaderItems( $epoch_format ),
                          qw(SatID TropoCorr IonoCorr
                             Azimut Zenital Elevation Distance
                             ENU_IE ENU_IN ENU_IU
                             ECEF_IX ECEF_IY ECEF_IZ) );

      say $fh "#".join($delimiter, @header_items);

    # 4. Write Line of Sight data:
      # Go through the observations epochs:
      for (my $i = 0; $i < scalar(@{ $ref_obs_data->{BODY} }); $i += 1)
      {
        # Epoch is transformed according to configuration:
        my @epoch = &{ $ref_epoch_sub }( $ref_obs_data->{BODY}[$i]{EPOCH} );

        # Go through available satellites in LoS-Data hash:
        for my $sat (sort (keys %{ $ref_obs_data->{BODY}[$i]{SAT_LOS} }))
        {
          # Save LoS data reference:
          my $ref_sat_los_data = $ref_obs_data->{BODY}[$i]{SAT_LOS}{$sat};

          # Angle data is transformed according to configuration:
          my ($azimut, $zenital, $elev) =
            &{ $ref_angle_sub }( $ref_sat_los_data->{ AZIMUT    },
                                 $ref_sat_los_data->{ ZENITAL   },
                                 $ref_sat_los_data->{ ELEVATION } );

          # Save line items:
          my @line_items = ( @epoch, $sat,
                             $ref_sat_los_data->{ TROPO_CORR },
                             $ref_sat_los_data->{ IONO_CORR  },
                             $azimut, $zenital, $elev,
                             $ref_sat_los_data->{ DISTANCE    },
                             $ref_sat_los_data->{ ENU_VECTOR  }[0],
                             $ref_sat_los_data->{ ENU_VECTOR  }[1],
                             $ref_sat_los_data->{ ENU_VECTOR  }[2],
                             $ref_sat_los_data->{ ECEF_VECTOR }[0],
                             $ref_sat_los_data->{ ECEF_VECTOR }[1],
                             $ref_sat_los_data->{ ECEF_VECTOR }[2] );

          # Write line:
          say $fh join($delimiter, @line_items);


        } # end for $sat
      } # end for $i

    # 5. Close dumper file:
    close($fh);

  } # end for $sat_sys

  # Sub's answer is TRUE if successfull:
  return TRUE;
}

sub DumpLSQReport {
  my ( $ref_gen_conf, $ref_obs_data, $output_path, $fh_log ) = @_;

  # Default input values if not defined:
  $fh_log = *STDOUT unless $fh_log;

  # ************************* #
  # Input consistency cehcks: #
  # ************************* #

  # Output path must exist and have write permissions:
  unless (-w $output_path) {
    RaiseError($fh_log, ERR_WRITE_PERMISSION_DENIED,
      "User '".$ENV{USER}."' does not have write permissions at $output_path");
    return KILLED;
  }

  # General configuration must be hash type:
  unless (ref($ref_gen_conf) eq 'HASH') {
    RaiseError($fh_log, ERR_WRONG_HASH_REF,
      "Input argument \'$ref_gen_conf\' is not HASH type");
    return KILLED;
  }

  # Observation data must be hash type:
  unless (ref($ref_obs_data) eq 'HASH') {
    RaiseError($fh_log, ERR_WRONG_HASH_REF,
      "Input argument \'$ref_obs_data\' is not HASH type");
    return KILLED;
  }

  # ************************************** #
  # Receiver-Satellite LoS dumper routine: #
  # ************************************** #

  # Save dumper useful configuration:
  my $delimiter    = $ref_gen_conf->{DATA_DUMPER}{ DELIMITER    };
  my $epoch_format = $ref_gen_conf->{DATA_DUMPER}{ EPOCH_FORMAT };

  my $ref_epoch_sub = REF_EPOCH_SUB_CONF->{$epoch_format};

  # 1. Open dumper file at output path:
    my $file_path = join('/', ($output_path, "LSQ-report-info.out"));
    my $fh; open($fh, '>', $file_path) or die "Could not create $!";

  # 2. Write title line:
    say $fh sprintf("# > Least Squares Report.\n".
                    "# > Created : %s",
                    GetPrettyLocalDate());

  # 3. Write header line:
    my @header_items =( SetEpochHeaderItems( $epoch_format ),
                        qw(Iteration LSQ_Status ConvergenceFlag
                           NumObs NumParameter DegOfFree StdDevEstimator) );

    # Insert number of apx parameters:
    push(@header_items,
         "ApprxParameter[$_]") for (0..NUM_PARAMETERS_TO_ESTIMATE - 1);
    push(@header_items,
         "DeltaParameter[$_]") for (0..NUM_PARAMETERS_TO_ESTIMATE - 1);

    say $fh "#".join($delimiter, @header_items);

  # 4. Write Line of Sight data:
    # Go through the observations epochs:
    for (my $i = 0; $i < scalar(@{ $ref_obs_data->{BODY} }); $i += 1)
    {
      # Epoch is transformed according to configuration:
      my @epoch = &{ $ref_epoch_sub }( $ref_obs_data->{BODY}[$i]{EPOCH} );

      # Go trhough available iterations:
      for my $iter (keys @{ $ref_obs_data->{BODY}[$i]{LSQ_INFO} }) {

        # Save iteration data reference:
        my $ref_iter_data = $ref_obs_data->{BODY}[$i]{LSQ_INFO}[$iter];

        # Save line items to print:
        # NOTE: dumping std deviation estimator
        my @line_items = ( @epoch, $iter,
                           $ref_iter_data->{STATUS},
                           $ref_iter_data->{CONVERGENCE},
                           $ref_iter_data->{NUM_OBSERVATION},
                           $ref_iter_data->{NUM_PARAMETER},
                           $ref_iter_data->{DEGREES_OF_FREEDOM},
                           $ref_iter_data->{VARIANCE_ESTIMATOR}**(0.5),
                           @{ $ref_iter_data->{APX_PARAMETER} },
                           @{ $ref_iter_data->{PARAMETER_VECTOR} } );

        # Write LSQ line data:
        say $fh join($delimiter, @line_items);

      } # end for $iter
    } # end for $i

  # 5. Close dumper file:
  close($fh);

  # Sub's answer is TRUE if successfull:
  return TRUE;
}

sub DumpRecPosition {
  my ( $ref_gen_conf, $ref_obs_data, $output_path, $fh_log ) = @_;

  # Default input values if not defined:
  $fh_log = *STDOUT unless $fh_log;

  # ************************* #
  # Input consistency cehcks: #
  # ************************* #

  # Output path must exist and have write permissions:
  unless (-w $output_path) {
   RaiseError($fh_log, ERR_WRITE_PERMISSION_DENIED,
     "User '".$ENV{USER}."' does not have write permissions at $output_path");
   return KILLED;
  }

  # General configuration must be hash type:
  unless (ref($ref_gen_conf) eq 'HASH') {
   RaiseError($fh_log, ERR_WRONG_HASH_REF,
     "Input argument \'$ref_gen_conf\' is not HASH type");
   return KILLED;
  }

  # Observation data must be hash type:
  unless (ref($ref_obs_data) eq 'HASH') {
   RaiseError($fh_log, ERR_WRONG_HASH_REF,
     "Input argument \'$ref_obs_data\' is not HASH type");
   return KILLED;
  }

  # ********************************* #
  # Receiver Position dumper routine: #
  # ********************************* #

  # Retrieve dumper configuration:
  my $delimiter    = $ref_gen_conf->{DATA_DUMPER}{ DELIMITER      };
  my $epoch_format = $ref_gen_conf->{DATA_DUMPER}{ EPOCH_FORMAT   };
  my $angle_format = $ref_gen_conf->{DATA_DUMPER}{ ANGLE_FORMAT   };
  my $sigma_factor = $ref_gen_conf->{DATA_DUMPER}{ SIGMA_FACTOR   };

  # Set epoch and angle subroutine references:
  my $ref_epoch_sub = REF_EPOCH_SUB_CONF->{$epoch_format};
  my $ref_angle_sub = REF_ANGLE_SUB_CONF->{$angle_format};

  # Static mode parameters:
  my $static_mode = $ref_gen_conf->{STATIC}{STATUS};

  # Init reference position:
  my ($ref_x, $ref_y, $ref_z);
  my ($ref_lat, $ref_lon, $ref_helip);

  # Set static reference position:
  if ($static_mode) {

    # Set ECEF coordinates
    ($ref_x, $ref_y, $ref_z) =
      SetStaticReference( $ref_gen_conf, $ref_obs_data );

    # Compute geodetic coordinates:
    ($ref_lat, $ref_lon, $ref_helip) =
      ECEF2Geodetic( $ref_x, $ref_y, $ref_z, $ref_gen_conf->{ELIPSOID} );

  } # end if $static_mode

  # 1. Open dumper file at output path:
    my $rec_name = $ref_obs_data->{HEAD}{MARKER_NAME};
    my $file_path = join('/', ($output_path, "$rec_name-xyz.out"));
    my $fh; open($fh, '>', $file_path) or die "Could not create $!";

  # 2.a. Write title line:
    say $fh sprintf("# > Receiver marker '$rec_name' adjusted coordinates.\n".
                    "# > NumObs: number of satellite observations used in ".
                    "LSQ estimation\n".
                    "# > Reference system for ECEF coordinates : %s\n".
                    "# > Created : %s ",
                    $ref_gen_conf->{ELIPSOID}, GetPrettyLocalDate());

  # 2.b. Write reference coordinates if static mode is activated:
  if ($static_mode) {
    # Header:
    my @ref_head_items =
      qw(ECEF_X ECEF_Y ECEF_Z GEO_Lat GEO_Lon GEO_ElipHeight);

    # Trasnform geodetic angles:
    my ($ref_lat_print,
        $ref_lon_print) = &{ $ref_angle_sub }( $ref_lat, $ref_lon );

    # Reference coordinates to be printed:
    my @ref_line_items =
      ($ref_x, $ref_y, $ref_z, $ref_lat_print, $ref_lon_print, $ref_helip);

    # Print information:
    say $fh "# > Reference coordinates from static mode '".
            $ref_gen_conf->{STATIC}{REFERENCE_MODE}."'";
    say $fh "#".join($delimiter, @ref_head_items);
    say $fh join($delimiter, @ref_line_items);
  }

  # 3. Write header line:
    my @header_items = ( SetEpochHeaderItems( $epoch_format ),
                         qw(Status NumObs
                            ECEF_X ECEF_Y ECEF_Z ClkBias
                            Sigma_X Sigma_Y Sigma_Z Sigma_ClkBias
                            Sigma_E Sigma_N Sigma_U
                            GEO_Lat GEO_Lon GEO_ElipHeight) );

    # ENU increments header items:
    if ($static_mode) {
      push( @header_items, $_ ) for qw(REF_IE REF_IN REF_IU);
    }

    say $fh "#".join($delimiter, @header_items);

  # 4. Write Receiver position data:
    for (my $i = 0; $i < scalar(@{ $ref_obs_data->{BODY} }); $i += 1)
    {
      # Save reference to receiver position hash:
      my $ref_xyz_data = $ref_obs_data->{BODY}[$i]{REC_POSITION};

      # Epoch is transformed according to configuration:
      my @epoch = &{ $ref_epoch_sub }( $ref_obs_data->{BODY}[$i]{EPOCH} );

      # Number of satellites:
      my $num_sat =
        $ref_obs_data->{BODY}[$i]{NUM_SAT_INFO}{ALL}{VALID_LSQ}{NUM_SAT};

      # Position estimation status:
      my $status = $ref_xyz_data->{STATUS};

      # ECEF receiver coordinates anc clock bias:
      my ($rec_x, $rec_y, $rec_z) = @{ $ref_xyz_data->{XYZ} };
      my $rec_clk = $ref_xyz_data->{CLK};

      # ECEF coordinates related sigma error.
      # NOTE: sclaing factor is applied:
      my @rec_xyz_sigma =
        map {($_**0.5)*$sigma_factor} @{ $ref_xyz_data->{VAR_XYZ} };

      # ENU sigma:
      my @rec_enu_sigma =
        map {($_**0.5)*$sigma_factor} @{ $ref_xyz_data->{VAR_ENU} };

      # Clock bias sigma:
      my $rec_clk_sigma = ($ref_xyz_data->{VAR_CLK}**0.5)*$sigma_factor;

      # Geodetic receiver coordinates:
      my ( $rec_lat, $rec_lon,  $rec_helip );
      my ( $easting, $northing, $upping    );

      if ($status) {
        ($rec_lat, $rec_lon, $rec_helip) =
          ECEF2Geodetic( $rec_x, $rec_y, $rec_z, $ref_gen_conf->{ELIPSOID} );
        ($easting, $northing, $upping) =
          Vxyz2Venu( $rec_x - $ref_x,
                     $rec_y - $ref_y,
                     $rec_z - $ref_z, $ref_lat, $ref_lon ) if $static_mode;
      } else {
        ( $rec_lat, $rec_lon,  $rec_helip ) = (0, 0, 0);
        ( $easting, $northing, $upping    ) = (0, 0, 0) if $static_mode;
      }

      # Trasform angle measurments accoring to configuration:
      ($rec_lat, $rec_lon) = &{ $ref_angle_sub }( $rec_lat, $rec_lon );

      # Set data items:
      my @line_items = (@epoch,
                        $status, $num_sat,
                        $rec_x, $rec_y, $rec_z, $rec_clk,
                        @rec_xyz_sigma, $rec_clk_sigma,
                        @rec_enu_sigma, $rec_lat, $rec_lon, $rec_helip);

      # Append ENU increments:
      if ($static_mode) {
        push(@line_items, $_) for ($easting, $northing, $upping);
      }

      # Write data line:
      say $fh join($delimiter, @line_items);

    } # end for $i

  # 5. Close dumper file:
  close($fh);

  # Sub's answer is TRUE if successfull:
  return TRUE;
}

sub DumpNumValidSat {
  my ( $ref_gen_conf, $ref_obs_data, $output_path, $fh_log ) = @_;

  # Default input values if not defined:
  $fh_log = *STDOUT unless $fh_log;

  # ************************* #
  # Input consistency cehcks: #
  # ************************* #
  # Output path must exist and have write permissions:
  unless (-w $output_path) {
   RaiseError($fh_log, ERR_WRITE_PERMISSION_DENIED,
     "User '".$ENV{USER}."' does not have write permissions at $output_path");
   return KILLED;
  }

  # General configuration must be hash type:
  unless (ref($ref_gen_conf) eq 'HASH') {
   RaiseError($fh_log, ERR_WRONG_HASH_REF,
     "Input argument \'$ref_gen_conf\' is not HASH type");
   return KILLED;
  }

  # Observation data must be hash type:
  unless (ref($ref_obs_data) eq 'HASH') {
   RaiseError($fh_log, ERR_WRONG_HASH_REF,
     "Input argument \'$ref_obs_data\' is not HASH type");
   return KILLED;
  }

  # ********************************* #
  # Receiver Position dumper routine: #
  # ********************************* #

  # Retrieve dumper configuration:
  my $delimiter    = $ref_gen_conf->{DATA_DUMPER}{ DELIMITER      };
  my $epoch_format = $ref_gen_conf->{DATA_DUMPER}{ EPOCH_FORMAT   };

  # Set epoch and angle subroutine references:
  my $ref_epoch_sub = REF_EPOCH_SUB_CONF->{$epoch_format};

  # Produce an output for each selected constellation and for the sum of
  # all of them:
  for my $sat_sys (@{ $ref_gen_conf->{SELECTED_SAT_SYS} }, 'ALL') {

    # 1. Open dumper file at output path:
      my $file_path = join('/', ($output_path, "$sat_sys-num-sat-info.out"));
      my $fh; open($fh, '>', $file_path) or die "Could not create $!";

    # 2.a. Write title line:
      # Retrieve selected observations for
      # information purposes:
      my $selected_obs_info =
        WriteSelecetedObsInfo ( $sat_sys, $ref_gen_conf->{SELECTED_SIGNALS} );

      say $fh sprintf("# > Satellite system '$sat_sys' ".
                      "number of valid satellites.\n".
                      $selected_obs_info.
                      "# > Created : %s ", GetPrettyLocalDate());

    # 3. Write header line:
      my @header_items = ( SetEpochHeaderItems( $epoch_format ),
                           'AvailSat', 'ValidObs', 'ValidNav', 'ValidLSQ' );
      say $fh "#".join($delimiter, @header_items);

    # 4. Write Num satellites info:
      # Iterate over observation epochs:
      for (my $i = 0; $i < scalar(@{ $ref_obs_data->{BODY} }); $i += 1) {

        # Set reference to number of satellites info:
        my $ref_num_sat_info = $ref_obs_data->{BODY}[$i]{NUM_SAT_INFO};

        # Get epoch:
        my @epoch =
          &{ $ref_epoch_sub }($ref_obs_data->{BODY}[$i]{EPOCH});

        # Retrieve number of available satellites in epoch:
        my $num_sat_avail_obs =
           $ref_num_sat_info->{$sat_sys}{AVAIL_OBS}{NUM_SAT};

        # Retrieve number of satellites with no null observation:
        my $num_sat_valid_obs;

        # 'ALL' entry is treated as the sum of the available satellites with the
        # corresponding observation for each constellation:
        if ($sat_sys eq 'ALL') {

          for my $obs_id (values %{ $ref_gen_conf->{SELECTED_SIGNALS} }) {
            $num_sat_valid_obs +=
              $ref_num_sat_info->{$sat_sys}{VALID_OBS}{$obs_id}{NUM_SAT};
          }

        } else {

          my $obs_id = $ref_gen_conf->{SELECTED_SIGNALS}{$sat_sys};
          $num_sat_valid_obs =
            $ref_num_sat_info->{$sat_sys}{VALID_OBS}{$obs_id}{NUM_SAT};

        }

        # Retrieve number of satellites with valid computed navigation:
        my $num_sat_valid_nav =
           $ref_num_sat_info->{$sat_sys}{VALID_NAV}{NUM_SAT};

        # Retrieve number of satellites to enter LSQ algorithm:
        my $num_sat_valid_lsq =
           $ref_num_sat_info->{$sat_sys}{VALID_LSQ}{NUM_SAT};

        # Write data line:
        my @line_items = ( @epoch,
                           $num_sat_avail_obs,
                           $num_sat_valid_obs,
                           $num_sat_valid_nav,
                           $num_sat_valid_lsq );

        say $fh join($delimiter, @line_items);

      } # end for $i

    # 5. Close dumper file:
    close($fh);

  } # end for $sat_sys

  # Subroutine's answer is TRUE if the
  # information has been successfully dumped:
  return TRUE;
}

sub DumpEpochDOP {
  my ( $ref_gen_conf, $ref_obs_data, $output_path, $fh_log ) = @_;

  # Default input values if not defined:
  $fh_log = *STDOUT unless $fh_log;

  # ************************* #
  # Input consistency cehcks: #
  # ************************* #

  # Output path must exist and have write permissions:
  unless (-w $output_path) {
   RaiseError($fh_log, ERR_WRITE_PERMISSION_DENIED,
     "User '".$ENV{USER}."' does not have write permissions at $output_path");
   return KILLED;
  }

  # General configuration must be hash type:
  unless (ref($ref_gen_conf) eq 'HASH') {
   RaiseError($fh_log, ERR_WRONG_HASH_REF,
     "Input argument \'$ref_gen_conf\' is not HASH type");
   return KILLED;
  }

  # Observation data must be hash type:
  unless (ref($ref_obs_data) eq 'HASH') {
   RaiseError($fh_log, ERR_WRONG_HASH_REF,
     "Input argument \'$ref_obs_data\' is not HASH type");
   return KILLED;
  }

  # ********************************* #
  # Receiver Position dumper routine: #
  # ********************************* #

  # Retrieve dumper configuration:
  my $delimiter    = $ref_gen_conf->{DATA_DUMPER}{ DELIMITER      };
  my $epoch_format = $ref_gen_conf->{DATA_DUMPER}{ EPOCH_FORMAT   };

  # Set epoch and angle subroutine references:
  my $ref_epoch_sub = REF_EPOCH_SUB_CONF->{$epoch_format};

  # 1. Open dumper file:
    my $file_path = join('/', ($output_path, "DOP-info.out"));
    my $fh; open($fh, '>', $file_path) or die "Could not create $!";

  # 2. Write title line:
    say $fh sprintf("# > Dilution of Precission report.\n".
                    "# > Reference ECEF frame : %s\n".
                    "# > Reference ENU  frame : Local receiver position\n".
                    "# > Created : %s ",
                    $ref_gen_conf->{ELIPSOID}, GetPrettyLocalDate());

  # 3. Write header items:
    my @header_items = ( SetEpochHeaderItems($epoch_format),
                         'Status', 'GDOP', 'PDOP', 'TDOP', 'HDOP', 'VDOP' );

    say $fh "#".join($delimiter, @header_items);

  # 4. Write DOP data:
    # Ierate over observation epochs:
    for (my $i = 0; $i < scalar(@{ $ref_obs_data->{BODY} }); $i += 1) {

      # Set reference to receiver position information:
      my $ref_rec_position = $ref_obs_data->{BODY}[$i]{REC_POSITION};

      # Get epoch:
      my @epoch = &{ $ref_epoch_sub }( $ref_obs_data->{BODY}[$i]{EPOCH} );

      # Retrieve receiver position status:
      my $status = $ref_rec_position->{STATUS};

      # Init DOP items:
      my ($gdop, $pdop, $tdop, $hdop, $vdop);

      # DOP info is computed for those epochs where the receiever position
      # estimation routine has been successfull:
      if ($status) {

        # Retrieve variances:
        my ($sum_var_xyz, $sum_var_en) = (0, 0);
        $sum_var_xyz += $_ for (@{ $ref_rec_position->{VAR_XYZ} });
        $sum_var_en  += $_ for ( $ref_rec_position->{VAR_ENU}[0],
                                 $ref_rec_position->{VAR_ENU}[1] );
        my $var_clk   = $ref_rec_position->{VAR_CLK};
        my $var_u     = $ref_rec_position->{VAR_ENU}[2];

         ( $gdop,
           $pdop,
           $tdop,
           $hdop,
           $vdop ) = (( $sum_var_xyz + $var_clk )**0.5,  # GDOP
                      ( $sum_var_xyz +        0 )**0.5,  # PDOP
                      (            0 + $var_clk )**0.5,  # TDOP
                      (  $sum_var_en +        0 )**0.5,  # HDOP
                      (            0 +   $var_u )**0.5); # VDOP

      } else {

        # If receiver position status is not TRUE, set DOP info to 0:
        ($gdop, $pdop, $tdop, $hdop, $vdop) = (0, 0, 0, 0, 0);

      }

      # Set data line items:
      my @line_items = (@epoch, $status, $gdop, $pdop, $tdop, $hdop, $vdop);

      say $fh join($delimiter, @line_items);

    } # end for $i

  # 5. Close dumper file:
    close($fh);

  # Subroutine's answer is true
  # if the DOP data has been successfully dumped:
  return TRUE;
}

sub DumpAzimutBySat {
  my ($ref_gen_conf, $ref_obs_data, $output_path, $fh_log) = @_;

  # Default input values if not defined:
  $fh_log = *STDOUT unless $fh_log;

  # ************************* #
  # Input consistency cehcks: #
  # ************************* #

  # Output path must exist and have write permissions:
  unless (-w $output_path) {
   RaiseError($fh_log, ERR_WRITE_PERMISSION_DENIED,
     "User '".$ENV{USER}."' does not have write permissions at $output_path");
   return KILLED;
  }

  # General configuration must be hash type:
  unless (ref($ref_gen_conf) eq 'HASH') {
   RaiseError($fh_log, ERR_WRONG_HASH_REF,
     "Input argument \'$ref_gen_conf\' is not HASH type");
   return KILLED;
  }

  # Observation data must be hash type:
  unless (ref($ref_obs_data) eq 'HASH') {
   RaiseError($fh_log, ERR_WRONG_HASH_REF,
     "Input argument \'$ref_obs_data\' is not HASH type");
   return KILLED;
  }

  # ********************************* #
  # Receiver Position dumper routine: #
  # ********************************* #

  # Retrieve dumper configuration:
  my $delimiter    = $ref_gen_conf->{DATA_DUMPER}{ DELIMITER      };
  my $epoch_format = $ref_gen_conf->{DATA_DUMPER}{ EPOCH_FORMAT   };
  my $angle_format = $ref_gen_conf->{DATA_DUMPER}{ ANGLE_FORMAT   };

  # Set epoch and angle subroutine references:
  my $ref_epoch_sub = REF_EPOCH_SUB_CONF->{$epoch_format};
  my $ref_angle_sub = REF_ANGLE_SUB_CONF->{$angle_format};

  # Iterate over selected constellations:
  for my $sat_sys (@{ $ref_gen_conf->{SELECTED_SAT_SYS} })
  {
    # 1. Open dumper file at output path:
      my $file_path = join('/', ($output_path, "$sat_sys-sat-azimut.out"));
      my $fh; open($fh, '>', $file_path) or die "Could not create $!";

    # 2. Write title line:
      say $fh sprintf("# > Receiver-Satellite '$sat_sys' azimut.\n".
                      "# > Azimut values are given in [%s] format\n".
                      "# > 'Status' refers to receiver position estimation\n".
                      "# > Created : %s ",
                      $angle_format, GetPrettyLocalDate());

    # 3. Write header line:
      # Retrieve all observed satellites:
      my @all_obs_sat = GetAllObservedSats( $sat_sys, $ref_obs_data );

      my @header_items = ( SetEpochHeaderItems($epoch_format),
                           'Status', @all_obs_sat);

      say $fh "#".join($delimiter, @header_items);

    # 4. Write data:
      # Iterate over observation epoch:
      for (my $i = 0; $i < scalar(@{ $ref_obs_data->{BODY} }); $i += 1) {

        # Set references to receiver position and LineOfSight info:
        my $ref_sat_los_data = $ref_obs_data->{BODY}[$i]{SAT_LOS};
        my $ref_rec_position = $ref_obs_data->{BODY}[$i]{REC_POSITION};

        # Get epoch:
        my @epoch = &{ $ref_epoch_sub }($ref_obs_data->{BODY}[$i]{EPOCH});

        # Get receiver position estimation status:
        my $status = $ref_rec_position->{STATUS};

        # Init array to store elevation per sat:
        my @azimut_by_sat;

        # Iterate over available satellites:
        for my $sat (@all_obs_sat) {

          # Init azimut value:
          my $sat_azimut;

          # Check if sat is defined in LoS data:
          # NOTE: if satellite has line of sight data,
          #       azimut angle is transformed according to configuration
          if (defined $ref_sat_los_data->{$sat}) {
            $sat_azimut =
              ( &{ $ref_angle_sub }($ref_sat_los_data->{$sat}{AZIMUT}) )[0];
          } else {
            $sat_azimut = NULL_DATA;
          }

          # Push azimut value:
          push(@azimut_by_sat, $sat_azimut);

        } # end for $sat

        # Set line items and write them in dumper:
        my @line_items = (@epoch, $status, @azimut_by_sat);
        say $fh join($delimiter, @line_items);

      } # end for $i

    # 5. Close file:
      close($fh);
  }

  # Subroutine's answer is true
  # if the data has been successfully dumped:
  return TRUE;
}

sub DumpElevationBySat {
  my ($ref_gen_conf, $ref_obs_data, $output_path, $fh_log) = @_;

  # Default input values if not defined:
  $fh_log = *STDOUT unless $fh_log;

  # ************************* #
  # Input consistency cehcks: #
  # ************************* #

  # Output path must exist and have write permissions:
  unless (-w $output_path) {
   RaiseError($fh_log, ERR_WRITE_PERMISSION_DENIED,
     "User '".$ENV{USER}."' does not have write permissions at $output_path");
   return KILLED;
  }

  # General configuration must be hash type:
  unless (ref($ref_gen_conf) eq 'HASH') {
   RaiseError($fh_log, ERR_WRONG_HASH_REF,
     "Input argument \'$ref_gen_conf\' is not HASH type");
   return KILLED;
  }

  # Observation data must be hash type:
  unless (ref($ref_obs_data) eq 'HASH') {
   RaiseError($fh_log, ERR_WRONG_HASH_REF,
     "Input argument \'$ref_obs_data\' is not HASH type");
   return KILLED;
  }

  # ********************************* #
  # Receiver Position dumper routine: #
  # ********************************* #

  # Retrieve dumper configuration:
  my $delimiter    = $ref_gen_conf->{DATA_DUMPER}{ DELIMITER      };
  my $epoch_format = $ref_gen_conf->{DATA_DUMPER}{ EPOCH_FORMAT   };
  my $angle_format = $ref_gen_conf->{DATA_DUMPER}{ ANGLE_FORMAT   };

  # Set epoch and angle subroutine references:
  my $ref_epoch_sub = REF_EPOCH_SUB_CONF->{$epoch_format};
  my $ref_angle_sub = REF_ANGLE_SUB_CONF->{$angle_format};

  # Iterate over selected constellations:
  for my $sat_sys (@{ $ref_gen_conf->{SELECTED_SAT_SYS} })
  {
    # 1. Open dumper file at output path:
      my $file_path = join('/', ($output_path, "$sat_sys-sat-elevation.out"));
      my $fh; open($fh, '>', $file_path) or die "Could not create $!";

    # 2. Write title line:
      say $fh sprintf("# > Receiver-Satellite '$sat_sys' elevation.\n".
                      "# > Configured elevation mask [%s] = %.3f \n".
                      "# > 'Status' refers to receiver position estimation\n".
                      "# > Created : %s ",
                      $angle_format,
                      &{$ref_angle_sub}($ref_gen_conf->{SAT_MASK}),
                      GetPrettyLocalDate());

    # 3. Write header line:
      # Retrieve all observed satellites:
      my @all_obs_sat = GetAllObservedSats( $sat_sys, $ref_obs_data );

      # Retrieve configured satellite mask:
      my $sat_mask = ( &{$ref_angle_sub}($ref_gen_conf->{SAT_MASK}) )[0];

      my @header_items = ( SetEpochHeaderItems($epoch_format),
                           'Status', 'SatMask', @all_obs_sat);

      say $fh "#".join($delimiter, @header_items);

    # 4. Write data:
      # Iterate over observation epoch:
      for (my $i = 0; $i < scalar(@{ $ref_obs_data->{BODY} }); $i += 1) {

        # Set references to receiver position and LineOfSight info:
        my $ref_sat_los_data = $ref_obs_data->{BODY}[$i]{SAT_LOS};
        my $ref_rec_position = $ref_obs_data->{BODY}[$i]{REC_POSITION};

        # Get epoch:
        my @epoch = &{ $ref_epoch_sub }($ref_obs_data->{BODY}[$i]{EPOCH});

        # Get receiver position estimation status:
        my $status = $ref_rec_position->{STATUS};

        # Init array to store elevation per sat:
        my @elevation_by_sat;

        # Iterate over available satellites:
        for my $sat (@all_obs_sat) {

          # Init elevation value:
          my $sat_elevation;

          # Check if sat is defined in LoS data:
          # NOTE: if satellite has line of sight data,
          #       elevation angle is transformed according to configuration
          if (defined $ref_sat_los_data->{$sat}) {
            $sat_elevation =
              ( &{ $ref_angle_sub }($ref_sat_los_data->{$sat}{ELEVATION}) )[0];
          } else {
            $sat_elevation = NULL_DATA;
          }

          # Push elevation value:
          push(@elevation_by_sat, $sat_elevation);

        } # end for $sat

        # Set line items and write them in dumper:
        my @line_items = (@epoch, $status, $sat_mask, @elevation_by_sat);
        say $fh join($delimiter, @line_items);

      } # end for $i

    # 5. Close file:
      close($fh);
  }

  # Subroutine's answer is true
  # if the data has been successfully dumped:
  return TRUE;
}

sub DumpIonoCorrBySat {
  my ($ref_gen_conf, $ref_obs_data, $output_path, $fh_log) = @_;

  # Default input values if not defined:
  $fh_log = *STDOUT unless $fh_log;

  # ************************* #
  # Input consistency cehcks: #
  # ************************* #

  # Output path must exist and have write permissions:
  unless (-w $output_path) {
   RaiseError($fh_log, ERR_WRITE_PERMISSION_DENIED,
     "User '".$ENV{USER}."' does not have write permissions at $output_path");
   return KILLED;
  }

  # General configuration must be hash type:
  unless (ref($ref_gen_conf) eq 'HASH') {
   RaiseError($fh_log, ERR_WRONG_HASH_REF,
     "Input argument \'$ref_gen_conf\' is not HASH type");
   return KILLED;
  }

  # Observation data must be hash type:
  unless (ref($ref_obs_data) eq 'HASH') {
   RaiseError($fh_log, ERR_WRONG_HASH_REF,
     "Input argument \'$ref_obs_data\' is not HASH type");
   return KILLED;
  }

  # ********************************* #
  # Receiver Position dumper routine: #
  # ********************************* #

  # Retrieve dumper configuration:
  my $delimiter    = $ref_gen_conf->{DATA_DUMPER}{ DELIMITER      };
  my $epoch_format = $ref_gen_conf->{DATA_DUMPER}{ EPOCH_FORMAT   };

  # Set epoch and angle subroutine references:
  my $ref_epoch_sub = REF_EPOCH_SUB_CONF->{$epoch_format};

  # Iterate over selected constellations:
  for my $sat_sys (@{ $ref_gen_conf->{SELECTED_SAT_SYS} })
  {
    # 1. Open dumper file at output path:
      my $file_path = join('/', ($output_path, "$sat_sys-sat-iono-delay.out"));
      my $fh; open($fh, '>', $file_path) or die "Could not create $!";

    # 2. Write title line:
      say $fh sprintf("# > Receiver-Satellite '$sat_sys' ionosphere delay.\n".
                      "# > Model for ionosphere correction -> %s \n".
                      "# > 'Status' refers to receiver position estimation\n".
                      "# > Created : %s ",
                      $ref_gen_conf->{IONOSPHERE_MODEL}{$sat_sys},
                      GetPrettyLocalDate());

    # 3. Write header line:
      # Retrieve all observed satellites:
      my @all_obs_sat = GetAllObservedSats( $sat_sys, $ref_obs_data );

      # Retrieve configured satellite mask:
      my @header_items = ( SetEpochHeaderItems($epoch_format),
                           'Status', @all_obs_sat);

      say $fh "#".join($delimiter, @header_items);

    # 4. Write data:
      # Iterate over observation epoch:
      for (my $i = 0; $i < scalar(@{ $ref_obs_data->{BODY} }); $i += 1) {

        # Set references to receiver position and LineOfSight info:
        my $ref_sat_los_data = $ref_obs_data->{BODY}[$i]{SAT_LOS};
        my $ref_rec_position = $ref_obs_data->{BODY}[$i]{REC_POSITION};

        # Get epoch:
        my @epoch = &{ $ref_epoch_sub }($ref_obs_data->{BODY}[$i]{EPOCH});

        # Get receiver position estimation status:
        my $status = $ref_rec_position->{STATUS};

        # Init array to store ionosphere correction per sat:
        my @iono_corr_by_sat;

        # Iterate over available satellites:
        for my $sat (@all_obs_sat) {

          # Init ionosphere delay value:
          my $sat_iono_corr;

          # Check if sat is defined in LoS data:
          if (defined $ref_sat_los_data->{$sat}) {
            $sat_iono_corr = $ref_sat_los_data->{$sat}{IONO_CORR};
          } else {
            $sat_iono_corr = NULL_DATA;
          }

          # Push ionosphere delay value:
          push(@iono_corr_by_sat, $sat_iono_corr);

        } # end for $sat

        # Set line items and write them in dumper:
        my @line_items = (@epoch, $status, @iono_corr_by_sat);
        say $fh join($delimiter, @line_items);

      } # end for $i

    # 5. Close file:
      close($fh);
  }

  # Subroutine's answer is true
  # if the data has been successfully dumped:
  return TRUE;
}


sub DumpTropoCorrBySat {
  my ($ref_gen_conf, $ref_obs_data, $output_path, $fh_log) = @_;

  # Default input values if not defined:
  $fh_log = *STDOUT unless $fh_log;

  # ************************* #
  # Input consistency cehcks: #
  # ************************* #

  # Output path must exist and have write permissions:
  unless (-w $output_path) {
   RaiseError($fh_log, ERR_WRITE_PERMISSION_DENIED,
     "User '".$ENV{USER}."' does not have write permissions at $output_path");
   return KILLED;
  }

  # General configuration must be hash type:
  unless (ref($ref_gen_conf) eq 'HASH') {
   RaiseError($fh_log, ERR_WRONG_HASH_REF,
     "Input argument \'$ref_gen_conf\' is not HASH type");
   return KILLED;
  }

  # Observation data must be hash type:
  unless (ref($ref_obs_data) eq 'HASH') {
   RaiseError($fh_log, ERR_WRONG_HASH_REF,
     "Input argument \'$ref_obs_data\' is not HASH type");
   return KILLED;
  }

  # ********************************* #
  # Receiver Position dumper routine: #
  # ********************************* #

  # Retrieve dumper configuration:
  my $delimiter    = $ref_gen_conf->{DATA_DUMPER}{ DELIMITER      };
  my $epoch_format = $ref_gen_conf->{DATA_DUMPER}{ EPOCH_FORMAT   };

  # Set epoch and angle subroutine references:
  my $ref_epoch_sub = REF_EPOCH_SUB_CONF->{$epoch_format};

  # Iterate over selected constellations:
  for my $sat_sys (@{ $ref_gen_conf->{SELECTED_SAT_SYS} })
  {
    # 1. Open dumper file at output path:
      my $file_path = join('/', ($output_path, "$sat_sys-sat-tropo-delay.out"));
      my $fh; open($fh, '>', $file_path) or die "Could not create $!";

    # 2. Write title line:
      say $fh sprintf("# > Receiver-Satellite '$sat_sys' troposphere delay.\n".
                      "# > Model for troposphere correction -> %s \n".
                      "# > 'Status' refers to receiver position estimation\n".
                      "# > Created : %s ",
                      $ref_gen_conf->{TROPOSPHERE_MODEL},
                      GetPrettyLocalDate());

    # 3. Write header line:
      # Retrieve all observed satellites:
      my @all_obs_sat = GetAllObservedSats( $sat_sys, $ref_obs_data );

      # Retrieve configured satellite mask:
      my @header_items = ( SetEpochHeaderItems($epoch_format),
                           'Status', @all_obs_sat);

      say $fh "#".join($delimiter, @header_items);

    # 4. Write data:
      # Iterate over observation epoch:
      for (my $i = 0; $i < scalar(@{ $ref_obs_data->{BODY} }); $i += 1) {

        # Set references to receiver position and LineOfSight info:
        my $ref_sat_los_data = $ref_obs_data->{BODY}[$i]{SAT_LOS};
        my $ref_rec_position = $ref_obs_data->{BODY}[$i]{REC_POSITION};

        # Get epoch:
        my @epoch = &{$ref_epoch_sub}($ref_obs_data->{BODY}[$i]{EPOCH});

        # Get receiver position estimation status:
        my $status = $ref_rec_position->{STATUS};

        # Init array to store troposphere correction per sat:
        my @tropo_corr_by_sat;

        # Iterate over available satellites:
        for my $sat (@all_obs_sat) {

          # Init troposphere delay value:
          my $sat_tropo_corr;

          # Check if sat is defined in LoS data:
          if (defined $ref_sat_los_data->{$sat}) {
            $sat_tropo_corr = $ref_sat_los_data->{$sat}{TROPO_CORR};
          } else {
            $sat_tropo_corr = NULL_DATA;
          }

          # Push troposphere delay value:
          push(@tropo_corr_by_sat, $sat_tropo_corr);

        } # end for $sat

        # Set line items and write them in dumper:
        my @line_items = (@epoch, $status, @tropo_corr_by_sat);
        say $fh join($delimiter, @line_items);

      } # end for $i

    # 5. Close file:
      close($fh);
  }

  # Subroutine's answer is true
  # if the data has been successfully dumped:
  return TRUE;
}


sub DumpResidualsBySat {
  my ($ref_gen_conf, $ref_obs_data, $output_path, $fh_log) = @_;

  # Default input values if not defined:
  $fh_log = *STDOUT unless $fh_log;

  # ************************* #
  # Input consistency cehcks: #
  # ************************* #

  # Output path must exist and have write permissions:
  unless (-w $output_path) {
   RaiseError($fh_log, ERR_WRITE_PERMISSION_DENIED,
     "User '".$ENV{USER}."' does not have write permissions at $output_path");
   return KILLED;
  }

  # General configuration must be hash type:
  unless (ref($ref_gen_conf) eq 'HASH') {
   RaiseError($fh_log, ERR_WRONG_HASH_REF,
     "Input argument \'$ref_gen_conf\' is not HASH type");
   return KILLED;
  }

  # Observation data must be hash type:
  unless (ref($ref_obs_data) eq 'HASH') {
   RaiseError($fh_log, ERR_WRONG_HASH_REF,
     "Input argument \'$ref_obs_data\' is not HASH type");
   return KILLED;
  }

  # ********************************* #
  # Receiver Position dumper routine: #
  # ********************************* #

  # Retrieve dumper configuration:
  my $delimiter    = $ref_gen_conf->{DATA_DUMPER}{ DELIMITER      };
  my $epoch_format = $ref_gen_conf->{DATA_DUMPER}{ EPOCH_FORMAT   };

  # Set epoch and angle subroutine references:
  my $ref_epoch_sub = REF_EPOCH_SUB_CONF->{$epoch_format};

  # Iterate over selected constellations:
  for my $sat_sys (@{ $ref_gen_conf->{SELECTED_SAT_SYS} })
  {
    # 1. Open dumper file at output path:
      my $file_path = join('/', ($output_path, "$sat_sys-sat-residuals.out"));
      my $fh; open($fh, '>', $file_path) or die "Could not create $!";

    # 2. Write title line:
      say $fh sprintf("# > Receiver-Satellite '$sat_sys' LSQ residuals.\n".
                      "# > Selected observation for '$sat_sys' -> %s\n".
                      "# > Configured mean_obs_err for '$sat_sys' -> %.3f\n".
                      "# > 'Status' refers to receiver position estimation\n".
                      "# > Resiudals are refered to last LSQ iteration\n".
                      "# > Created : %s ",
                      $ref_gen_conf->{ SELECTED_SIGNALS }{$sat_sys},
                      $ref_gen_conf->{ OBS_MEAN_ERR     }{$sat_sys},
                      GetPrettyLocalDate());

    # 3. Write header line:
      # Retrieve all observed satellites:
      my @all_obs_sat = GetAllObservedSats( $sat_sys, $ref_obs_data );

      # Retrieve configured satellite mask:
      my @header_items = ( SetEpochHeaderItems($epoch_format),
                           'Status', 'NumIterLSQ', @all_obs_sat);

      say $fh "#".join($delimiter, @header_items);

    # 4. Write data:
      # Iterate over observation epoch:
      for (my $i = 0; $i < scalar(@{ $ref_obs_data->{BODY} }); $i += 1) {

        # Set references to receiver position and LSQ info (last iteration):
        my $ref_lsq_last_iter = $ref_obs_data->{BODY}[$i]{LSQ_INFO}[-1];
        my $ref_rec_position  = $ref_obs_data->{BODY}[$i]{REC_POSITION};

        # Get epoch:
        my @epoch = &{$ref_epoch_sub}($ref_obs_data->{BODY}[$i]{EPOCH});

        # Get receiver position estimation status:
        my $status = $ref_rec_position->{STATUS};

        # Retrieve number of iterations pefromed by LSQ routine:
        my $num_lsq_iter = scalar(@{ $ref_obs_data->{BODY}[$i]{LSQ_INFO} });

        # Init array to store residuals per sat:
        my @residuals_by_sat;

        # Iterate over available satellites:
        for my $sat (@all_obs_sat) {

          # Init troposphere delay value:
          my $sat_residual;

          # Check if sat is defined in LSQ data:
          if (defined $ref_lsq_last_iter->{SAT_RESIDUALS}{$sat}) {
            $sat_residual = $ref_lsq_last_iter->{SAT_RESIDUALS}{$sat};
          } else {
            $sat_residual = NULL_DATA;
          }

          # Push residual value:
          push(@residuals_by_sat, $sat_residual);

        } # end for $sat

        # Set line items and write them in dumper:
        my @line_items = (@epoch, $status, $num_lsq_iter, @residuals_by_sat);
        say $fh join($delimiter, @line_items);

      } # end for $i

    # 5. Close file:
      close($fh);
  }

  # Subroutine's answer is true
  # if the data has been successfully dumped:
  return TRUE;
}


# Private Subrutines:
# ............................................................................ #
sub SetEpochHeaderItems {
  my ($epoch_format) = @_;

  # Init header items array to be returned:
  my @head_items;

  # Switch case for epoch format:
  given ($epoch_format) {
    when ($_ eq &GPS_EPOCH_FORMAT) {
      @head_items = qw(EpochGPS);
    }
    when ($_ eq &DATE_EPOCH_FORMAT) {
      @head_items = qw(Year Month Day Hour Minute Second);
    }
    when ($_ eq &GPS_WEEK_EPOCH_FORMAT) {
      @head_items = qw(WeekNum DayNum TimeOfWeek);
    }
  }

  return @head_items;
}

sub SetStaticReference {
  my ($ref_gen_conf, $ref_obs_data) = @_;

  # Init reference position to be returned:
  my @ref_ecef_xyz;

  # Set reference position:
  given ($ref_gen_conf->{STATIC}{REFERENCE_MODE}) {
    when ($_ eq &MEAN_STATIC_MODE) {
      @ref_ecef_xyz = ComputeMeanRecPosition( $ref_obs_data );
    }
    when ($_ eq &IGS_STATIC_MODE || $_ eq &MANUAL_STATIC_MODE) {
      @ref_ecef_xyz = @{ $ref_gen_conf->{STATIC}{REFERENCE} };
    }
  } # end given $reference_mode


  return @ref_ecef_xyz;
}

sub GetAllObservedSats {
  my ($sat_sys, $ref_obs_data) = @_;

  # Init array to hold all observed satellites:
  my @avail_sat;

  # Iterate over the observation epochs:
  for (my $i = 0; $i < scalar(@{ $ref_obs_data->{BODY} }); $i += 1) {

    # Set reference to number fo satellites information:
    my $ref_num_sat_info = $ref_obs_data->{BODY}[$i]{NUM_SAT_INFO};

    # Push if not already, the observed satellites:
    PushUnique(\@avail_sat,
                @{ $ref_num_sat_info->{$sat_sys}{AVAIL_OBS}{SAT_IDS} });

  }

  # Return sorted available satellites:
  return sort @avail_sat;
}

sub ComputeMeanRecPosition {
  my ($ref_obs_data) = @_;

  # Init summatory  variables and counter:
  my $count_epoch = 0;
  my ($sum_x, $sum_y, $sum_z) = (0, 0, 0);

  # Go through all observation epochs:
  for (my $i = 0; $i < scalar(@{ $ref_obs_data->{BODY} }); $i += 1)
  {
    # Set receiver position reference:
    my $ref_rec_position =
       $ref_obs_data->{BODY}[$i]{REC_POSITION};

    # Check for receiver position status:
    if ($ref_rec_position->{STATUS}) {

      # Retrieve receiver ECEF coorindates:
      my ($rec_x, $rec_y, $rec_z) = @{ $ref_rec_position->{XYZ} };

      # Sum for each coordinate component:
      $sum_x += $rec_x; $sum_y += $rec_y; $sum_z += $rec_z;

      # Increment counter:
      $count_epoch += 1;

    } # end if STATUS

  } # end for $i


  # Compute mean position:
  my ( $mean_x,
       $mean_y,
       $mean_z ) = ( $sum_x/$count_epoch,
                     $sum_y/$count_epoch,
                     $sum_z/$count_epoch );

  return ($mean_x, $mean_y, $mean_z);
}

sub WriteSelecetedObsInfo {
  my ($sat_sys, $ref_sel_obs) = @_;

  # Init string to return:
  my $selected_obs_info = '';

  if ($sat_sys eq 'ALL') {
    for (keys %{ $ref_sel_obs }) {
      $selected_obs_info .=
        "# > Selected observation for $_ -> ".$ref_sel_obs->{$_}."\n";
    }
  } else {
    $selected_obs_info =
      "# > Selected observation for $sat_sys -> ".$ref_sel_obs->{$sat_sys}."\n";
  }

  return $selected_obs_info;
}

TRUE;
