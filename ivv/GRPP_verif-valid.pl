#!/usr/bin/perl -w

## TODO: SCRIPT DESCRIPTION GOES HERE ##

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
use MyUtil   qq(:ALL);
use MyMath   qq(:ALL);
use MyPrint  qq(:ALL);
use Geodetic qq(:ALL);
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
use DataDumper  qq(:ALL);

# ============================================================================ #

PrintTitle1( *STDOUT, "Script $0 has started" );

# Prelimary:
  # Init script clock:
  my $script_start = [gettimeofday];

  # Init memory usage report:
  our $MEM_USAGE = Memory::Usage->new();
      $MEM_USAGE->record('-> Imports');

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

  ReportElapsedTime([gettimeofday],
                    $ini_rinex_obs_time_stamp, "ReadObservationRinex()");
  $MEM_USAGE->record('-> ReadObsRinex');

# Compute satellite positions:
  my $ini_rinex_nav_time_stamp = [gettimeofday];

  PrintTitle2($FH_LOG, "Reading RINEX navigation data");
  my $ref_gps_nav_rinex = ComputeSatPosition( $ref_gen_conf,
                                              $ref_obs_data,
                                              $FH_LOG );

  ReportElapsedTime([gettimeofday],
                    $ini_rinex_nav_time_stamp, "ComputeSatPosition()");
  $MEM_USAGE->record('-> ComputeSatPosition');

# Compute Receiver positions:
  my $ini_rec_position_time_stamp = [gettimeofday];

  PrintTitle2($FH_LOG, "Computing Receiver positions");
  my $rec_position_status = ComputeRecPosition( $ref_gen_conf,
                                                $ref_obs_data,
                                                $ref_gps_nav_rinex,
                                                $FH_LOG );

  ReportElapsedTime([gettimeofday],
                    $ini_rec_position_time_stamp, "ComputeRecPosition()");
  $MEM_USAGE->record('-> ComputeRecPosition');

  # Print position solutions for validating GRPP functionality:
  PrintTitle3(*STDOUT, "Position solutions. ",
                       "first 4 and last 4 observation epochs:");
  for (0..3, -4..-1) {
    PrintComment( *STDOUT, "Observation epoch : ".
      BuildDateString(GPS2Date($ref_obs_data->{BODY}[$_]{EPOCH})) );
    PrintBulletedInfo(*STDOUT, "  - ",
      "Status = ".
      ($ref_obs_data->{BODY}[$_]{POSITION_SOLUTION}{STATUS} ? "TRUE":"FALSE"),
      "|  X |  Y |  Z =".
        join(' | ',
          sprintf( " %12.3f |" x 3,
                   @{$ref_obs_data->
                      {BODY}[$_]{POSITION_SOLUTION}{XYZDT}}[0..2] )
        ),
      "| sX | sY | sZ =".
        join(' | ',
          sprintf(" %12.3f |" x 3,
                  @{$ref_obs_data->
                      {BODY}[$_]{POSITION_SOLUTION}{SIGMA_XYZDT}}[0..2])
        )
      );

    say "[...]\n" if ($_ == 3);
  }


# Data Dumper -> Set dumper configuration:
# TODO: put this configuration in cfg file?
  my %dump_conf = ( SEPARATOR        => "\t",
                    EPOCH_FORMAT     => \&DummySub,
                    ANGLE_FORMAT     => \&Rad2Deg,
                    SAT_POS_FORMAT   => \&DummySub,
                    REC_POS_FORMAT   => \&ECEF2Geodetic,
                    SIGMA_FACTOR     => 1 );

# Dump processed data:
  PrintTitle2($FH_LOG, "Dumping GRPP data:");
  my $ini_time_dump_data = [gettimeofday];

  PrintTitle3($FH_LOG, "Dumping Satellite Observation Data:");
  DumpSatObsData( \%dump_conf,
                  $ref_gen_conf,
                  $ref_obs_data, [], # no sats to ignore
                  [ $ref_gen_conf->{SELECTED_SIGNALS}{G} ],
                  $ref_gen_conf->{OUTPUT_PATH}, $FH_LOG );

  ReportElapsedTime([gettimeofday],
                    $ini_time_dump_data, "DumpSatObsData()");
  $MEM_USAGE->record('-> DumpObsData');

  $ini_time_dump_data = [gettimeofday];

  PrintTitle3($FH_LOG, "Dumping Satellite-Receiver LoS Data:");
  DumpRecSatLoSData( \%dump_conf,
                     $ref_gen_conf,
                     $ref_obs_data, [], # no sats to ignore
                     $ref_gen_conf->{OUTPUT_PATH}, $FH_LOG );

  ReportElapsedTime([gettimeofday],
                    $ini_time_dump_data, "DumpRecSatLoSData()");
  $MEM_USAGE->record('-> DumpRecSatLoSData');

  $ini_time_dump_data = [gettimeofday];

  PrintTitle3($FH_LOG, "Dumping Leas Squares report:");
  DumpLSQReport( \%dump_conf,
                 $ref_gen_conf,
                 $ref_obs_data,
                 $ref_gen_conf->{OUTPUT_PATH}, $FH_LOG );

  ReportElapsedTime([gettimeofday],
                    $ini_time_dump_data, "DumpLSQReport()");
  $MEM_USAGE->record('-> DumpLSQReport');

  $ini_time_dump_data = [gettimeofday];

  PrintTitle3($FH_LOG, "Dumping Satellite XYZ & clock bias:");
  DumpSatPosition( \%dump_conf,
                   $ref_gen_conf,
                   $ref_obs_data, [], # no sats to ignore...
                   $ref_gen_conf->{OUTPUT_PATH}, $FH_LOG );

  ReportElapsedTime([gettimeofday],
                    $ini_time_dump_data, "DumpSatPosition()");
  $MEM_USAGE->record('-> DumpSatPosition');

  $ini_time_dump_data = [gettimeofday];

  PrintTitle3($FH_LOG, "Dumping Receiver position & clock bias:");
  DumpRecPosition( \%dump_conf,
                   $ref_gen_conf,
                   $ref_obs_data,
                   $ref_gen_conf->{OUTPUT_PATH}, $FH_LOG );

  ReportElapsedTime([gettimeofday],
                    $ini_time_dump_data, "DumpRecPosition()");
  $MEM_USAGE->record('-> DumpRecPosition');

# Terminal:
  # Close output log file:
    close($FH_LOG);

  # Report memory usage:
  PrintTitle2(*STDOUT, 'Memory Usage report:');
  $MEM_USAGE->dump();

  # Stop script clock and report elapsed time:
  my $script_stop  = [gettimeofday];
  my $elapsed_time = tv_interval($script_start, $script_stop);

  say ""; PrintTitle2( *STDOUT, sprintf("Elapsed script time : %.2f seconds",
                                        $elapsed_time) ); say "";

PrintTitle1( *STDOUT, "Script $0 has finished" );


sub ReportElapsedTime {
  my ($current_time_stamp, $ref_time_stamp, $label) = @_;

  say "";
    PrintTitle2( *STDOUT, sprintf("Elapsed time for $label %.2f seconds",
                          tv_interval($ref_time_stamp, $current_time_stamp)) );
  say "";
}
