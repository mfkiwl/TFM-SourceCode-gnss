#!/usr/bin/perl -w

# Package declaration:
package DataDumper;


# TODO: SCRIPT DESCRIPTION GOES HERE:
# TODO: Review headers!
# TODO: implement dumper configuration as part of general configuration
# TODO: New dumper for LSQ specific obs info! (or merge with LSQ_info dumper)
# TODO: would be great to have the following information
#       - Reference coordinates from station --> extract from IGS file?
#       - ENU position and sigma for receiver position
#       - ...

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
  our @EXPORT_SUB   = qw( &DumpLSQReport
                          &DumpSatObsData
                          &DumpSatPosition
                          &DumpRecPosition
                          &DumpRecSatLoSData );

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
      my $file_path = join('/', ($output_path, "$sat_sys-sat_obs_data.out"));
      my $fh; open($fh, '>', $file_path) or die "Could not create $!";

    # 2. Write title line:
      say $fh sprintf("# > Satellite system: $sat_sys, RINEX observations.\n".
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
                           qw(Status SatID) );
      push(@header_items, "$_") for (@sat_sys_obs);

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

          # Set line elements:
          my @line_items = (@epoch, $status, $sat);

          # Include selected observations:
          push(@line_items,
               $ref_epoch_data->{SAT_OBS}{$sat}{$_}) for (@sat_sys_obs);

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
      my $file_path = join('/', ($output_path, "$sat_sys-los-data.out"));
      my $fh; open($fh, '>', $file_path) or croak "Could not create $!";

    # 2. Write title line:
      say $fh sprintf("# > Receiver-Satellite ($sat_sys) Line of Sight data.\n".
                      "# > Created : %s \n".
                      "# > Observation epoch status info:\n".
                      "#   0   --> OK\n".
                      "#   1-6 --> NOK\n".
                      "# > Reference system for ECEF coordinates : %s",
                      GetPrettyLocalDate(), $ref_gen_conf->{ELIPSOID});

    # 3. Write header line:
      my @header_items = ( SetEpochHeaderItems( $epoch_format ),
                          qw(ObsStatus SatID TropoCorr IonoCorr
                             Azimut Zenital Elevation Distance
                             ECEF_IX ECEF_IY ECEF_IZ) );

      say $fh "#".join($delimiter, @header_items);

    # 4. Write Line of Sight data:
      # Go through the observations epochs:
      for (my $i = 0; $i < scalar(@{ $ref_obs_data->{BODY} }); $i += 1)
      {
        # Save observation epoch status:
        my $status = $ref_obs_data->{BODY}[$i]{STATUS};

        # Epoch is transformed according to configuration:
        my @epoch = &{ $ref_epoch_sub }( $ref_obs_data->{BODY}[$i]{EPOCH} );

        # Go through available satellites in LoS-Data hash:
        for my $sat (keys %{ $ref_obs_data->{BODY}[$i]{SAT_LOS} })
        {
          # Save LoS data reference:
          my $ref_sat_los_data = $ref_obs_data->{BODY}[$i]{SAT_LOS}{$sat};

          # Angle data is transformed according to configuration:
          my ($azimut, $zenital, $elev) =
            &{ $ref_angle_sub }( $ref_sat_los_data->{ AZIMUT    },
                                 $ref_sat_los_data->{ ZENITAL   },
                                 $ref_sat_los_data->{ ELEVATION } );

          # Save line items:
          my @line_items = ( @epoch, $status, $sat,
                             $ref_sat_los_data->{ TROPO_CORR },
                             $ref_sat_los_data->{ IONO_CORR  },
                             $azimut, $zenital, $elev,
                             $ref_sat_los_data->{ DISTANCE    },
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
    my $file_path = join('/', ($output_path, "lsq_report_info.out"));
    my $fh; open($fh, '>', $file_path) or die "Could not create $!";

  # 2. Write title line:
    say $fh sprintf("# > Least Squares Report.\n".
                    "# > Created : %s",
                    GetPrettyLocalDate());

  # 3. Write header line:
    my @header_items =( SetEpochHeaderItems( $epoch_format ),
                        qw(Iteration Status StdDevEstimator ConvergenceFlag) );

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
        my @line_items = ( @epoch, $iter,
                           $ref_iter_data->{STATUS},
                           $ref_iter_data->{VARIANCE_ESTIMATOR}**(0.5),
                           $ref_iter_data->{CONVERGENCE},
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
      say $fh sprintf("# > Constellation '$sat_sys' navigation positions.\n".
                      "# > Observation epoch status info:\n".
                      "#   0   --> OK\n".
                      "#   1-6 --> NOK\n".
                      "# > Reference system for ECEF coordinates : %s".
                      "# > Created  : %s \n",
                      $ref_gen_conf->{ELIPSOID}, GetPrettyLocalDate());

    # 3. Write header line:
      my @header_items = ( SetEpochHeaderItems( $epoch_format ),
                           qw( ObsStatus SatID SatNavStatus
                               ECEF_X ECEF_Y ECEF_Z SatClockBias
                               GEO_Lat GEO_Lon GEO_ElipHeight ) );

      say $fh "#".join($delimiter, @header_items);

    # 4. Write Line of Sight data:
      # Go through the observations epochs:
      for (my $i = 0; $i < scalar(@{ $ref_obs_data->{BODY} }); $i += 1)
      {
        # Save observation epoch status:
        my $obs_status = $ref_obs_data->{BODY}[$i]{STATUS};
        # Epoch is transformed according to configuration:
        my @epoch = &{ $ref_epoch_sub }( $ref_obs_data->{BODY}[$i]{EPOCH} );

        # Go through available satellites in SAT_XYZTC hash:
        for my $sat (keys %{ $ref_obs_data->{BODY}[$i]{SAT_XYZTC} })
        {
          # Save satellite position data reference:
          my $ref_sat_xyz_data = $ref_obs_data->{BODY}[$i]{SAT_XYZTC}{$sat};

          # Retrieve satellite navigation status:
          my $sat_status = $ref_sat_xyz_data->{NAV}{STATUS};

          # Satellite ECEF coordinates and clock bias:
          my @sat_xyz_clkbias = @{ $ref_sat_xyz_data->{NAV}{XYZTC} };

          # Init ECEF and Geodetic satellite coordinates and clock bias:
          my ($sat_lat, $sat_lon, $sat_helip);

          # Coodinates selction based on satellite navigation status:
          if ($sat_status) {
            # Compute geodetic coordinates:
            ($sat_lat, $sat_lon, $sat_helip) =
              ECEF2Geodetic(@sat_xyz_clkbias[0..2], $ref_gen_conf->{ELIPSOID});
          } else {
            # Set null information for invalid navigation status:
            ($sat_lat, $sat_lon, $sat_helip) = (0, 0, 0);
          }

          # Latitude and longitude are transformed according to configuration:
          ($sat_lat, $sat_lon) = &{ $ref_angle_sub } ($sat_lat, $sat_lon);

          # Save line items:
          my @line_items = (@epoch, $obs_status, $sat, $sat_status,
                            @sat_xyz_clkbias, $sat_lat, $sat_lon, $sat_helip);

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

sub DumpRecPosition {
  my ( $ref_gen_conf, $ref_obs_data, $output_path, $fh_log ) = @_;

  # TODO: include static reference information

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

  # Retrieve dumper configuration:
  my $delimiter    = $ref_gen_conf->{DATA_DUMPER}{ DELIMITER      };
  my $epoch_format = $ref_gen_conf->{DATA_DUMPER}{ EPOCH_FORMAT   };
  my $angle_format = $ref_gen_conf->{DATA_DUMPER}{ ANGLE_FORMAT   };
  my $sigma_factor = $ref_gen_conf->{DATA_DUMPER}{ SIGMA_FACTOR   };

  # Set epoch and angle subroutine references:
  my $ref_epoch_sub = REF_EPOCH_SUB_CONF->{$epoch_format};
  my $ref_angle_sub = REF_ANGLE_SUB_CONF->{$angle_format};

  # 1. Open dumper file at output path:
    my $rec_name = $ref_obs_data->{HEAD}{MARKER_NAME};
    my $file_path = join('/', ($output_path, "$rec_name-xyz.out"));
    my $fh; open($fh, '>', $file_path) or die "Could not create $!";

  # 2. Write title line:
    say $fh sprintf("# > Receiver marker '$rec_name' adjusted coordinates.\n".
                    "# > NumSat  : satellites used in LSQ estimation\n".
                    "# > Reference system for ECEF coordinates : %s\n".
                    "# > Created : %s ",
                    $ref_gen_conf->{ELIPSOID}, GetPrettyLocalDate());

  # 3. Write header line:
    my @header_items = ( SetEpochHeaderItems( $epoch_format ),
                         qw(Status NumSat
                            ECEF_X ECEF_Y ECEF_Z ClkBias
                            Sigma_X Sigma_Y Sigma_Z Sigma_ClkBias
                            GEO_Lat GEO_Lon GEO_ElipHeight) );

    say $fh "#".join($delimiter, @header_items);

  # 4. Write Receiver position data:
    for (my $i = 0; $i < scalar(@{ $ref_obs_data->{BODY} }); $i += 1)
    {
      # Save reference to receiver position hash:
      my $ref_xyz_data = $ref_obs_data->{BODY}[$i]{POSITION_SOLUTION};

      # Epoch is transformed according to configuration:
      my @epoch = &{ $ref_epoch_sub }( $ref_obs_data->{BODY}[$i]{EPOCH} );

      # Number of satellites:
      my $num_sat = $ref_obs_data->{BODY}[$i]{NUM_LSQ_SAT}{ALL};

      # Position estimation status:
      my $status = $ref_xyz_data->{STATUS};

      # ECEF receiver coordinates:
      my @rec_xyz = @{ $ref_xyz_data->{XYZDT} };

      # ECEF coordinates related sigma error.
      # NOTE: sclaing factor is applied:
      my @rec_xyz_sigma =
        map {$_*$sigma_factor} @{ $ref_xyz_data->{SIGMA_XYZDT} };

      # Geodetic receiver coordinates:
      my ($rec_lat, $rec_lon, $rec_helip);

      if ($status) {
        ($rec_lat,
         $rec_lon,
         $rec_helip) = ECEF2Geodetic( @rec_xyz[0..2],
                                      $ref_gen_conf->{ELIPSOID} );
      } else {
        ($rec_lat, $rec_lon, $rec_helip) = (0, 0, 0);
      }

      # Trasform angle measurments accoring to configuration:
      ($rec_lat, $rec_lon) = &{ $ref_angle_sub }( $rec_lat, $rec_lon );

      # Set data items:
      my @line_items = (@epoch,
                        $status, $num_sat,
                        @rec_xyz, @rec_xyz_sigma,
                        $rec_lat, $rec_lon, $rec_helip);

      # Write data line:
      say $fh join($delimiter, @line_items);

    } # end for $i

  # 5. Close dumper file:
  close($fh);

  # Sub's answer is TRUE if successfull:
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



TRUE;
