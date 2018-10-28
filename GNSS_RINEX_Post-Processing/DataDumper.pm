#!/usr/bin/perl -w

# Package declaration:
package DataDumper;


# SCRIPT DESCRIPTION GOES HERE:

# Import modules:
# ---------------------------------------------------------------------------- #
use strict;      # enables strict syntax...

use feature      qq(say);               # same as print.$text.'\n'...
use feature      qq(switch);            # switch functionality...
use Scalar::Util qq(looks_like_number); # scalar utility...
use Data::Dumper;                       # enables pretty print...

# Import configuration and common interface module:
use lib qq(/home/ppinto/TFM/src/);
use GeneralConfiguration qq(:ALL);

# Import dedicated libraries:
use lib qq(/home/ppinto/TFM/src/lib/); # NOTE: this should be an enviroment!
use MyUtil   qq(:ALL); # useful subs and constants...
use MyPrint  qq(:ALL); # error and warning utilities...
use TimeGNSS qq(:ALL); # GNSS time transforming utilities...

# Import dependent modules:
use RinexReader qq(:ALL);
use ErrorSource qq(:ALL);
use PositionLSQ qq(:ALL);

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
  our @EXPORT_SUB   = qw( &DumpObservationData
                          &DumpReceiverPositions
                          &DumpSatellitePositions );

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


# ---------------------------------------------------------------------------- #
# Subroutines:
# ---------------------------------------------------------------------------- #

# Public Subroutines: #
# ............................................................................ #
sub DumpObservationData {
  my ( $file_path, $ref_obs_rinex, $ref_sat_sys,
       $delimiter, $epoch_format, $fh_log ) = @_;

  # Default input values if not defined:
  $fh_log       = *STDOUT unless $fh_log;
  $delimiter    = "\t"    unless $delimiter;
  $epoch_format = 'gps'   unless $epoch_format;

  # ************************* #
  # Input consistency cehcks: #
  # ************************* #

  # Path provided must exist and have write permissions:
  unless (-w $file_path) {
    RaiseError($fh_log, ERR_WRITE_PERMISSION_DENIED,
      "User does not have write permissions at $file_path");
    return KILLED;
  }

  # $ref_obs_rinex must be hash reference:
  unless (ref($ref_obs_rinex) eq 'HASH') {
    RaiseError($fh_log, ERR_WRONG_HASH_REF,
      "Input argument \'$ref_obs_rinex\' is not HASH type");
    return KILLED;
  }

  # $ref_sat_sys, must an array reference and its contellations must be a
  # supported one:
  my @sat_systems;
  unless (ref($ref_sat_sys) eq 'ARRAY') {
    RaiseError($fh_log, ERR_WRONG_ARRAY_REF,
      "Input argument \'$ref_sat_sys\' is not ARRAY type");
    return KILLED;
  } else {
    for my $sat_sys (@{$ref_sat_sys}) {
      unless (grep(/^$sat_sys$/, SUPPORTED_SAT_SYS)) {
        RaiseWarning($fh_log, WARN_NOT_SUPPORTED_SAT_SYS,
        "Satellite system \'$sat_sys\' is not supported. ".
        "This constellation will be ignored!");
      } else { push(@sat_systems, $sat_sys); }
    } # end for @{$ref_sat_sys}
  } # end unless ref()

  # $epoch_format must be one of following: [ gps, tow, date ]
  unless ( $epoch_format =~ /gps/i ||
           $epoch_format =~ /tow/i ||
           $epoch_format =~ /date/i )
  {
    RaiseError($fh_log, ERR_UNRECOGNIZED_INPUT,
      "Argument \'$epoch_format\' was not recognized for epoch format!");
    return KILLED;
  }

  # ******************************* #
  # Observation data dump sequence: #
  # ******************************* #

  # Open dumper file:
  my $fh; open($fh, '>', $file_path) or die $!;

  # Write title line:
  say $fh sprintf('> RINEX observation data. Created : %s', GetPrettyLocalDate);

  # Write header line indicating the parameters arranged by columns:
  # Retrieve from obseration rinex the observations for each constellation...
  my $sat_sys;
  my $header_falg = TRUE;
  for $sat_sys (@sat_systems)
  {
    # Observation identifiers:
    my @obs =
       @{$ref_obs_rinex->{OBS_HEADER}{SYS_OBS_TYPES}{$sat_sys}{OBS}};

    # Observations for each constellation:
    my $obs_string = "OBS-$sat_sys: ".join($delimiter, @obs);

    # Write header lines:
    if ($header_falg) {
      say $fh join($delimiter, (qw(Epoch Status Sat_PRN), $obs_string));
    } else {
      say $fh join($delimiter, ('', '', '', $obs_string));
    }

    # For the rest of the constellation, header flag is no longer needed:
    $header_falg = FALSE;
  }

  # Write observations for each constellation:
  for (my $i = 0; $i < scalar(@{$ref_obs_rinex->{OBSERVATION}}); $i++)
  {
    # Write epoch and measurements status only when a new epoch is selected:
    my $new_epoch_falg = TRUE;
    my ( $epoch, $satus ) =
       ( $ref_obs_rinex->{OBSERVATION}[$i]{EPOCH},
         $ref_obs_rinex->{OBSERVATION}[$i]{STATUS} );

    # Switch case for epoch format:
    given ($epoch_format) {
      when ( /gps/i  ) { $epoch = $epoch;                              }
      when ( /tow/i  ) { $epoch = join('-',        GPS2ToW($epoch) ); }
      when ( /date/i ) { $epoch = BuildDateString( GPS2Date($epoch) ); }
      default          { $epoch = $epoch;                              }
    }

    print $fh join($delimiter, ( $epoch, $satus ));

    for my $sat (keys $ref_obs_rinex->{OBSERVATION}[$i]{SAT_OBS})
    {
      # Retrieve contellation:
      my $sat_sys = substr($sat, 0, 1);

      # Write only those observations from the selected contellations,
      # at the input check:
      if ( grep(/^$sat_sys$/, @sat_systems) )
      {
        # Observations identifiers:
        my @obs =
          @{$ref_obs_rinex->{OBS_HEADER}{SYS_OBS_TYPES}{$sat_sys}{OBS}};

        # Array containing the satellite measurements:
        my @arranged_obs;
        push(@arranged_obs,
          $ref_obs_rinex->{OBSERVATION}[$i]{SAT_OBS}{$sat}{$_}) for (@obs);

        # Write measurments:
        if ( $new_epoch_falg ) {
          say $fh $delimiter, join($delimiter, ($sat, @arranged_obs));
        } else {
          say $fh join($delimiter, ('', '', $sat, @arranged_obs));
        }

        # For the rest of the satellites, new epoch flag is no longer needed:
        $new_epoch_falg = FALSE;

      } # end if grep($sat_sys)
    } # end for my $sat
  } # end for $i

  # Close dumper file:
  close($fh);

  # Subroutine returns TRUE if the dumping process was successful:
  return TRUE;
}

sub DumpReceiverPositions {}

sub DumpSatellitePositions {
  my () = @_;

}



TRUE;
