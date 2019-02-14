#!/usr/bin/perl -w

# Package declaration:
package DataDumper;


# TODO: SCRIPT DESCRIPTION GOES HERE:
# TODO: New dumper for LSQ specific obs info! (or merge with LSQ_info dumper)

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
      push(@header_items, ($_, "$_-NumSat")) for (@sat_sys_obs);

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
            push(@line_items, ($ref_epoch_data->{SAT_OBS}{$sat}{$_},
                               $ref_epoch_data->{NUM_OBS_SAT}{$sat_sys}{$_}));
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
      say $fh sprintf("# > Receiver-Satellite '$sat_sys' Line of Sight data.\n".
                      "# > Observation epoch status info:\n".
                      "#   0   --> OK\n".
                      "#   1-6 --> NOK\n".
                      "# > Reference system for ECEF coordinates : %s\n".
                      "# > Created : %s",
                      $ref_gen_conf->{ELIPSOID}, GetPrettyLocalDate());

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
                        qw(Iteration Status NumObs NumParameter DegOfFree
                           StdDevEstimator ConvergenceFlag) );

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
                           $ref_iter_data->{NUM_OBSERVATION},
                           $ref_iter_data->{NUM_PARAMETER},
                           $ref_iter_data->{DEGREES_OF_FREEDOM},
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
                      "# > Reference system for ECEF coordinates : %s\n".
                      "# > Created  : %s",
                      $ref_gen_conf->{ELIPSOID}, GetPrettyLocalDate());

    # 3. Write header line:
      my @header_items = ( SetEpochHeaderItems( $epoch_format ),
                           qw( ObsStatus NumNavSat SatID SatNavStatus
                               NavX NavY NavZ SatClockBias
                               RecepX RecepY RecepZ
                               NavLat NavLon NavElipHeight
                               RecepLat RecepLon RecepElipHeight ) );

      say $fh "#".join($delimiter, @header_items);

    # 4. Write Line of Sight data:
      # Go through the observations epochs:
      for (my $i = 0; $i < scalar(@{ $ref_obs_data->{BODY} }); $i += 1)
      {
        # Save observation epoch status:
        my $obs_status = $ref_obs_data->{BODY}[$i]{STATUS};

        # Epoch is transformed according to configuration:
        my @epoch = &{ $ref_epoch_sub }( $ref_obs_data->{BODY}[$i]{EPOCH} );

        # Retrieve number of satellites with valid navigation data:
        my $num_sat = $ref_obs_data->{BODY}[$i]{NUM_NAV_SAT}{$sat_sys};

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
                            $obs_status, $num_sat, $sat, $sat_status,
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
                    "# > NumSat  : satellites used in LSQ estimation\n".
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
                         qw(Status NumSat
                            ECEF_X ECEF_Y ECEF_Z ClkBias
                            Sigma_X Sigma_Y Sigma_Z Sigma_ClkBias
                            Sigma_E Sigma_N Sigma_U
                            GEO_Lat GEO_Lon GEO_ElipHeight) );

    # ENU increments header items:
    if ($static_mode) {
      push( @header_items, $_ ) for qw(Easting Northing Upping);
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
      my $num_sat = $ref_obs_data->{BODY}[$i]{NUM_LSQ_SAT}{ALL};

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

TRUE;
