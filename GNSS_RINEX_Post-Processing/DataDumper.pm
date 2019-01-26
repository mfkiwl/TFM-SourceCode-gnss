#!/usr/bin/perl -w

# Package declaration:
package DataDumper;


# TODO: SCRIPT DESCRIPTION GOES HERE:
# TODO: Review headers!
# TODO: implement dumper configuration as part of general configuration
# TODO: New dumper for LSQ specific obs info! (or merge with LSQ_info dumper)

# Import modules:
# ---------------------------------------------------------------------------- #
use Carp;         # enables advanced warning and failure raise...
use strict;       # enables strict syntax and common mistakes advisory...
use Data::Dumper; # enables nested struct pretty print...

use feature      qq(say);               # same as print.$text.'\n'...
use feature      qq(switch);            # switch functionality...
use Scalar::Util qq(looks_like_number); # scalar utility...

# Import configuration and common interfaces module:
use lib qq(/home/ppinto/TFM/src/); # TODO: set enviroment variable!
use GeneralConfiguration qq(:ALL);

# Import dedicated libraries:
use lib qq(/home/ppinto/TFM/src/lib/); # TODO: this should be an enviroment!
# Common tools:
use MyUtil   qq(:ALL); # useful subs and constants...
use MyPrint  qq(:ALL); # print and warning/failure utilities...
# GNSS dedicated tools:
use Geodetic qq(:ALL); # geodetic toolbox...
use TimeGNSS qq(:ALL); # GNSS time transforming utilities...

# Import dependent modules:
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
  my ( $ref_dump_conf, $ref_gen_conf, $ref_obs_data,
       $ref_sats_to_ignore, $ref_selected_obs, $output_path, $fh_log ) = @_;

  # TODO: singular behaviour for each sat_sys or flexible enough for all?

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

  # Dumper configuration must be hash type:
  unless (ref($ref_dump_conf) eq 'HASH') {
    RaiseError($fh_log, ERR_WRONG_HASH_REF,
      "Input argument \'$ref_dump_conf\' is not HASH type");
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

  # Satellites to discard must be array type:
  unless (ref($ref_sats_to_ignore) eq 'ARRAY') {
    RaiseError($fh_log, ERR_WRONG_ARRAY_REF,
      "Input argument \'$ref_sats_to_ignore\' is not ARRAY type");
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
  my @sats_to_ignore = @{ $ref_sats_to_ignore };

  # Save dumper useful configuration:
  my $separator     = $ref_dump_conf->{ SEPARATOR    };
  my $ref_epoch_sub = $ref_dump_conf->{ EPOCH_FORMAT };

  # Dump the data for each selected GNSS constellation:
  for my $sat_sys (@{$ref_gen_conf->{SELECTED_SAT_SYS}})
  {
    # 1. Open dumper file at output path:
      my $file_path = join('/', ($output_path, "$sat_sys-sat_obs_data.out"));
      my $fh; open($fh, '>', $file_path) or croak "Could not create $!";

    # 2. Write title line:
      say $fh sprintf("# > Satellite system: $sat_sys, RINEX observations.\n".
                      "# > Created : %s \n".
                      "# > Observation epoch status info:\n".
                      "#   0   --> OK\n".
                      "#   1-6 --> NOK",
                      GetPrettyLocalDate());

    # 3. Write header:
      # Check for constellation available observations:
      my @sat_sys_obs;
      my @avail_obs = @{ $ref_obs_data->{HEAD}{SYS_OBS_TYPES}{$sat_sys}{OBS} };

      # Filter available observations by the selected ones:
      for my $obs (sort @avail_obs) {
        if (grep(/^$obs$/, @selected_obs)) { push(@sat_sys_obs, $obs); }
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
      my @header_items = qw(Epoch Status SatID);
      push(@header_items, "$_") for (@sat_sys_obs);

      # Write header:
      say $fh "#".join($separator, @header_items);

    # 4. Dump satellite observations:
      for (my $i = 0; $i < scalar(@{$ref_obs_data->{BODY}}); $i += 1)
      {
        # Save epoch data reference:
        my $ref_epoch_data =
           $ref_obs_data->{BODY}[$i];

        # Save observation epoch status:
        my $status =
           $ref_epoch_data->{STATUS};

        # Epoch is transformed according to configuration:
        my @epoch =
           &{$ref_dump_conf->{EPOCH_FORMAT}}( $ref_epoch_data->{EPOCH} );

        # Write observation data:
        for my $sat (sort ( keys %{$ref_epoch_data->{SAT_OBS}} )) {
          unless (grep(/^$sat$/, @sats_to_ignore)) {

            # Set line elements:
            my @line_items = (@epoch, $status, $sat);

            # Include selected observations:
            push(@line_items,
                 $ref_epoch_data->{SAT_OBS}{$sat}{$_}) for (@sat_sys_obs);

            # Dump observation data:
            say $fh join($separator, @line_items);

          } # end unless $sat
        } # end for my $sat

      } # end for $i

    # 5. Close dumper file:
      close($fh);

  } # end for $sat_sys

  # Sub's answer is TRUE if successfull:
  return TRUE;
}

sub DumpRecSatLoSData {
  my ($ref_dump_conf, $ref_gen_conf,
      $ref_obs_data, $ref_sats_to_ignore, $output_path, $fh_log) = @_;

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

  # Dumper configuration must be hash type:
  unless (ref($ref_dump_conf) eq 'HASH') {
    RaiseError($fh_log, ERR_WRONG_HASH_REF,
      "Input argument \'$ref_dump_conf\' is not HASH type");
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

  # Satellites to discard must be array type:
  unless (ref($ref_sats_to_ignore) eq 'ARRAY') {
    RaiseError($fh_log, ERR_WRONG_ARRAY_REF,
      "Input argument \'$ref_sats_to_ignore\' is not ARRAY type");
    return KILLED;
  }

  # ************************************** #
  # Receiver-Satellite LoS dumper routine: #
  # ************************************** #

  # De-reference array inputs:
  my @sats_to_ignore = @{ $ref_sats_to_ignore };

  # Save dumper useful configuration:
  my $separator     = $ref_dump_conf->{ SEPARATOR    };
  my $ref_epoch_sub = $ref_dump_conf->{ EPOCH_FORMAT };
  my $ref_angle_sub = $ref_dump_conf->{ ANGLE_FORMAT };

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
      my @header_items = qw( Epoch Status SatID TropoCorr IonoCorr
                             Azimut Zenital Elevation Distance
                             ECEF_IX ECEF_IY ECEF_IZ );

      say $fh "#".join($separator, @header_items);

    # 4. Write Line of Sight data:
      # Go through the observations epochs:
      for (my $i = 0; $i < scalar(@{ $ref_obs_data->{BODY} }); $i += 1)
      {
        # Save observation epoch status:
        my $status =
           $ref_obs_data->{BODY}[$i]{STATUS};
        # Epoch is transformed according to configuration:
        my @epoch =
           &{ $ref_epoch_sub }( $ref_obs_data->{BODY}[$i]{EPOCH} );

        # Go through available satellites in LoS-Data hash:
        for my $sat (keys %{ $ref_obs_data->{BODY}[$i]{SAT_LOS} })
        {
          # Discard specified satellites:
          unless (grep(/^$sat$/, @sats_to_ignore))
          {
            # Save LoS data reference:
            my $ref_sat_los_data = $ref_obs_data->{BODY}[$i]{SAT_LOS}{$sat};

            # Angle data is transformed according to configuration:
            my @angle_data =
              &{ $ref_angle_sub }( $ref_sat_los_data->{ AZIMUT    },
                                   $ref_sat_los_data->{ ZENITAL   },
                                   $ref_sat_los_data->{ ELEVATION } );

            # Save line items:
            my @line_items = ( @epoch, $status, $sat,
                               $ref_sat_los_data->{ TROPO_CORR },
                               $ref_sat_los_data->{ IONO_CORR  },
                               @angle_data,
                               $ref_sat_los_data->{ DISTANCE    },
                               $ref_sat_los_data->{ ECEF_VECTOR }[0],
                               $ref_sat_los_data->{ ECEF_VECTOR }[1],
                               $ref_sat_los_data->{ ECEF_VECTOR }[2] );

            # Write line:
            say $fh join($separator, @line_items);

          } # end unless $sat
        } # end for $sat
      } # end for $i

    # 5. Close dumper file:
    close($fh);

  } # end for $sat_sys

  # Sub's answer is TRUE if successfull:
  return TRUE;
}

sub DumpLSQReport {
  my ( $ref_dump_conf, $ref_gen_conf,
       $ref_obs_data, $output_path, $fh_log ) = @_;

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

  # Dumper configuration must be hash type:
  unless (ref($ref_dump_conf) eq 'HASH') {
    RaiseError($fh_log, ERR_WRONG_HASH_REF,
      "Input argument \'$ref_dump_conf\' is not HASH type");
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
  my $separator     = $ref_dump_conf->{ SEPARATOR    };
  my $ref_epoch_sub = $ref_dump_conf->{ EPOCH_FORMAT };

  # 1. Open dumper file at output path:
    my $file_path = join('/', ($output_path, "lsq_report_info.out"));
    my $fh; open($fh, '>', $file_path) or croak "Could not create $!";

  # 2. Write title line:
    say $fh sprintf("# > Least Squares Report.\n".
                    "# > Created : %s",
                    GetPrettyLocalDate());

  # 3. Write header line:
    my @header_items =
      qw( Epoch Iteration Status StdDevEstimator ConvergenceFlag );

    # Insert number of apx parameters:
    push(@header_items,
         "ApprxParameter[$_]") for (0..NUM_PARAMETERS_TO_ESTIMATE - 1);
    push(@header_items,
         "DeltaParameter[$_]") for (0..NUM_PARAMETERS_TO_ESTIMATE - 1);

    say $fh "#".join($separator, @header_items);

  # 4. Write Line of Sight data:
    # Go through the observations epochs:
    for (my $i = 0; $i < scalar(@{ $ref_obs_data->{BODY} }); $i += 1)
    {
      # Epoch is transformed according to configuration:
      my @epoch =
         &{ $ref_epoch_sub }( $ref_obs_data->{BODY}[$i]{EPOCH} );

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
        say $fh join($separator, @line_items);

      } # end for $iter
    } # end for $i

  # 5. Close dumper file:
  close($fh);

  # Sub's answer is TRUE if successfull:
  return TRUE;
}

sub DumpSatPosition {
  my ( $ref_dump_conf, $ref_gen_conf,
       $ref_obs_data, $ref_sats_to_ignore, $output_path, $fh_log ) = @_;

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

  # Dumper configuration must be hash type:
  unless (ref($ref_dump_conf) eq 'HASH') {
   RaiseError($fh_log, ERR_WRONG_HASH_REF,
     "Input argument \'$ref_dump_conf\' is not HASH type");
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

  # Satellites to discard must be array type:
  unless (ref($ref_sats_to_ignore) eq 'ARRAY') {
   RaiseError($fh_log, ERR_WRONG_ARRAY_REF,
     "Input argument \'$ref_sats_to_ignore\' is not ARRAY type");
   return KILLED;
  }

  # ********************************** #
  # Satellite position dumper routine: #
  # ********************************** #

  # De-reference array inputs:
  my @sats_to_ignore = @{ $ref_sats_to_ignore };

  # Save dumper useful configuration:
  my $separator     = $ref_dump_conf->{ SEPARATOR      };
  my $ref_angle_sub = $ref_dump_conf->{ ANGLE_FORMAT   };
  my $ref_epoch_sub = $ref_dump_conf->{ EPOCH_FORMAT   };

  for my $sat_sys (@{ $ref_gen_conf->{SELECTED_SAT_SYS} })
  {
    # 1. Open dumper file at output path:
      my $file_path = join('/', ($output_path, "$sat_sys-sat-xyz.out"));
      my $fh; open($fh, '>', $file_path) or croak "Could not create $!";

    # 2. Write title line:
      say $fh sprintf("# > Satellite System: $sat_sys, navigation positions.\n".
                      "# > Created  : %s \n".
                      "# > Observation epoch status info:\n".
                      "#   0   --> OK\n".
                      "#   1-6 --> NOK\n".
                      "# > Reference system for ECEF coordinates : %s",
                      GetPrettyLocalDate(), $ref_gen_conf->{ELIPSOID});

    # 3. Write header line:
      my @header_items = qw( Epoch Obs-Status SatID Sat-Status
                             Sat-ECEF_X Sat-ECEF_Y Sat-ECEF_Z SatClockBias
                             Sat-GEO_Lat Sat-GEO_Lon Sat-GEO_ElipHeight );

      say $fh "#".join($separator, @header_items);

    # 4. Write Line of Sight data:
      # Go through the observations epochs:
      for (my $i = 0; $i < scalar(@{ $ref_obs_data->{BODY} }); $i += 1)
      {
        # Save observation epoch status:
        my $status =
           $ref_obs_data->{BODY}[$i]{STATUS};
        # Epoch is transformed according to configuration:
        my @epoch =
           &{ $ref_epoch_sub }( $ref_obs_data->{BODY}[$i]{EPOCH} );

        # Go through available satellites in SAT_XYZTC hash:
        for my $sat (keys %{ $ref_obs_data->{BODY}[$i]{SAT_XYZTC} })
        {
          # Ignore specified satellites:
          unless (grep(/^$sat$/, @sats_to_ignore))
          {
            # Save satellite position data reference:
            my $ref_sat_xyz_data = $ref_obs_data->{BODY}[$i]{SAT_XYZTC}{$sat};

            # ECEF satellite coordinates and clock bias:
            my $sat_status = $ref_sat_xyz_data->{NAV}{STATUS};

            # TODO: Temporary patch:
            my @sat_xyz_clkbias;
            eval {
               @sat_xyz_clkbias = @{ $ref_sat_xyz_data->{NAV}{XYZTC} };
            } or do {
              next;
            };

            # Geodetic satellite coordinates:
            my ( $sat_lat, $sat_lon, $sat_helip );

            if ( $sat_status ) {
              ($sat_lat, $sat_lon, $sat_helip) =
               ECEF2Geodetic(@sat_xyz_clkbias[0..2], $ref_gen_conf->{ELIPSOID});
            } else {
              @sat_xyz_clkbias = (0, 0, 0, 0);
              ($sat_lat, $sat_lon, $sat_helip) = (0, 0, 0);
            }

            # Latitude and longitude are transformed according to configuration:
            my @geodetic_angles = &{ $ref_angle_sub }( $sat_lat, $sat_lon );

            # Save line items:
            my @line_items = ( @epoch, $status, $sat, $sat_status,
                               @sat_xyz_clkbias, @geodetic_angles, $sat_helip );

            # Write data line:
            say $fh join($separator, @line_items);

          } # end unless $sat
        } # end for $sat
      } # end for $i

    # 5. Close dumper file:
    close($fh);

  } # end for $sat_sys

  # Sub's answer is TRUE if successfull:
  return TRUE;
}

sub DumpRecPosition {
  my ( $ref_dump_conf, $ref_gen_conf,
       $ref_obs_data, $output_path, $fh_log ) = @_;

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

  # Dumper configuration must be hash type:
  unless (ref($ref_dump_conf) eq 'HASH') {
   RaiseError($fh_log, ERR_WRONG_HASH_REF,
     "Input argument \'$ref_dump_conf\' is not HASH type");
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
  my $separator          = $ref_dump_conf->{ SEPARATOR      };
  my $ref_epoch_sub      = $ref_dump_conf->{ EPOCH_FORMAT   };
  my $ref_angle_sub      = $ref_dump_conf->{ ANGLE_FORMAT   };
  my $sigma_factor       = $ref_dump_conf->{ SIGMA_FACTOR   };
  my $ref_rec_xyz_format = $ref_dump_conf->{ REC_POS_FORMAT };

  # 1. Open dumper file at output path:
    my $rec_name = $ref_obs_data->{HEAD}{MARKER_NAME};
    my $file_path = join('/', ($output_path, "$rec_name-xyz.out"));
    my $fh; open($fh, '>', $file_path) or croak "Could not create $!";

  # 2. Write title line:
    say $fh sprintf("# > Receiver: $rec_name adjusted coordinates.\n".
                    "# > Created  : %s \n".
                    "# > Observation epoch status info:\n".
                    "#   0   --> OK\n".
                    "#   1-6 --> NOK\n".
                    "# > Reference system for ECEF coordinates : %s",
                    GetPrettyLocalDate(), $ref_gen_conf->{ELIPSOID});

  # 3. Write header line:
    my @header_items = qw( Epoch Status
                           Rec-ECEF_X Rec-ECEF_Y Rec-ECEF_Z RecClkBias
                           Rec-Sigma_X Rec-Sigma_Y Rec-Sigma_Z Rec-Sigma_ClkBias
                           Rec-GEO_Lat Rec-GEO_Lon Rec-GEO_ElipHeight );

    say $fh "#".join($separator, @header_items);

  # 4. Write Receiver position data:
    for (my $i = 0; $i < scalar(@{ $ref_obs_data->{BODY} }); $i += 1)
    {
      # Save reference to receiver position hash:
      my $ref_rec_xyz_data =
         $ref_obs_data->{BODY}[$i]{POSITION_SOLUTION};

      # Epoch is transformed according to configuration:
      my @epoch =
         &{ $ref_epoch_sub }( $ref_obs_data->{BODY}[$i]{EPOCH} );

      # Receiver position is transformed according to configuration:
      my @rec_xyz =
         @{ $ref_rec_xyz_data->{XYZDT} };

      # Apply sigma factor:
      my @rec_xyz_sigma =
         map {$_*$sigma_factor} @{ $ref_rec_xyz_data->{SIGMA_XYZDT} };

      # Geodetic receiver coordinates:
      my ($rec_lat, $rec_lon, $rec_helip) =
         ECEF2Geodetic( @rec_xyz[0..2], $ref_gen_conf->{ELIPSOID} );

      # Latitude & Longitude are transformed according to configuration:
      my @geodetic_angles =
         &{ $ref_angle_sub }( $rec_lat, $rec_lon );

      # Set data items:
      my @line_items = ( @epoch, $ref_rec_xyz_data->{STATUS},
                         @rec_xyz, @rec_xyz_sigma,
                         @geodetic_angles, $rec_helip );

      # Write data line:
      say $fh join($separator, @line_items);

    } # end for $i

  # 5. Close dumper file:
  close($fh);

  # Sub's answer is TRUE if successfull:
  return TRUE;
}


TRUE;
