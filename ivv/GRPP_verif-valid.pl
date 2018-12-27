#!/usr/bin/perl -w

## SCRIPT DESCRIPTION GOES HERE ##

# ============================================================================ #

# Perl modules:
# ---------------------------------------------------------------------------- #
use Carp;            # enhanced user warning and error messages...
use strict;          # enables strict syntax...
use Data::Dumper;    # hash pretty print...
use feature qq(say); # print method adding carriage jump...

use Memory::Usage;
use Time::HiRes qw(gettimeofday tv_interval);

# Common modules:
# ---------------------------------------------------------------------------- #
use lib qq(/home/ppinto/TFM/src/lib/);
use MyUtil  qq(:ALL);
use MyPrint qq(:ALL);
use TimeGNSS qq(:ALL);

# Configuration and common interfaces module:
# ---------------------------------------------------------------------------- #
use lib qq(/home/ppinto/TFM/src/);
use GeneralConfiguration qq(:ALL);

# GRPP tool packages:
# ---------------------------------------------------------------------------- #
use lib qq(/home/ppinto/TFM/src/GNSS_RINEX_Post-Processing/);
use RinexReader qq(:ALL);
use SatPosition qq(:ALL);
use RecPosition qq(:ALL);

# ============================================================================ #

PrintTitle1( *STDOUT, "Script $0 has started" );

# Prelimary:
  # Init script clock:
  my $script_start = [gettimeofday];

  # Init memory usage report:
  our $MEM_USAGE = Memory::Usage->new();
      $MEM_USAGE->record('->Imports');

# ---------------------------------------------------------------------------- #

# Script inputs:
#   $1 --> path to configuration file
  my $path_conf_file = $ARGV[0];

# Load general configuration:
  my $ref_gen_conf = LoadConfiguration($path_conf_file);

  # print Dumper $ref_gen_conf;

  if ($ref_gen_conf == KILLED) {
    croak "*** ERROR *** Failed when reading configuration file: $path_conf_file"
  }

# Open output log file:
  our $FH_LOG; open($FH_LOG, '>', $ref_gen_conf->{LOG_FILE_PATH}) or croak $!;

  PrintTitle1($FH_LOG, "GRPP Verification-Validation Script");

# ---------------------------------------------------------------------------- #

# RINEX reading:
  my $ini_rinex_obs_time_stamp = [gettimeofday];

  PrintTitle2($FH_LOG, "Reading RINEX observation data");
  my $ref_obs_data = ReadObservationRinexV3( $ref_gen_conf,
                                              $FH_LOG );

  ReportElapsedTime([gettimeofday], $ini_rinex_obs_time_stamp, "OBS RINEX");
  $MEM_USAGE->record('->ReadObsRinex');

# Compute satellite positions:
  my $ini_rinex_nav_time_stamp = [gettimeofday];

  PrintTitle2($FH_LOG, "Reading RINEX navigation data");
  my $ref_gps_nav_rinex = ComputeSatPosition( $ref_gen_conf,
                                              $ref_obs_data,
                                              $FH_LOG );

  ReportElapsedTime([gettimeofday], $ini_rinex_nav_time_stamp, "NAV RINEX");
  $MEM_USAGE->record('->ComputeSatPosition');

# Compute Receiver positions:
  my $ini_rec_position_time_stamp = [gettimeofday];

  PrintTitle2($FH_LOG, "Computing Receiver positions");
  my $rec_position_status = ComputeRecPosition( $ref_gen_conf,
                                                $ref_obs_data,
                                                $ref_gps_nav_rinex,
                                                $FH_LOG );

  ReportElapsedTime([gettimeofday], $ini_rec_position_time_stamp, "REC POSITION");
  $MEM_USAGE->record('->ComputeRecPosition');

  # Print position solutions for validating GRPP functionality:
  PrintTitle2(*STDOUT, "Position solutions");
  for (0..3) {
    say "Observation epoch : ".
      BuildDateString(GPS2Date($ref_obs_data->{BODY}[$_]{EPOCH}));
    print Dumper $ref_obs_data->{BODY}[$_]{POSITION_SOLUTION};
  }

  say "\n[...]\n";

  for (-4..-1) {
    say "Observation epoch : ".
      BuildDateString(GPS2Date($ref_obs_data->{BODY}[$_]{EPOCH}));
    print Dumper $ref_obs_data->{BODY}[$_]{POSITION_SOLUTION};
  }


# Terminal:
  # Close output log file:
    close($FH_LOG);

  # Report memory usage:
  PrintTitle2(*STDOUT, 'Memory Usage report:');
  $MEM_USAGE->dump();

  # Stop script clock and report elapsed time:
  my $script_stop  = [gettimeofday];
  my $elapsed_time = tv_interval($script_start, $script_stop);

  say ""; PrintTitle3( *STDOUT, sprintf("Elapsed script time : %.2f seconds",
                                        $elapsed_time) ); say "";

PrintTitle1( *STDOUT, "Script $0 has finished" );


sub ReportElapsedTime {
  my ($current_time_stamp, $ref_time_stamp, $label) = @_;

  say "";
    PrintTitle3( *STDOUT, sprintf("Elapsed time for $label %.2f seconds",
                          tv_interval($ref_time_stamp, $current_time_stamp)) );
  say "";
}
