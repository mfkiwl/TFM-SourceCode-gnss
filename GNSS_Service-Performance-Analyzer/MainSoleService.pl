#!/usr/bin/perl -w

# TODO: SCRIPT DESCRIPTION GOES HERE:

# ---------------------------------------------------------------------------- #
# Import common perl modules:

use Cwd qw(abs_path); # directory path...
use Carp;   # advanced STDERR...
use strict; # enables strict syntax...

use Storable;           # load vars...
use File::Copy;         # copy files...
use Data::Dumper;       # var pretty print...
use feature qq(say);    # print adding line jump...
use feature qq(switch); # advanced switch statement...

# Precise time lapses:
use Time::HiRes qw(gettimeofday tv_interval);

# ---------------------------------------------------------------------------- #
# Load bash enviroments:

use lib $ENV{ ENV_ROOT };
use Enviroments qq(:CONSTANTS);

# ---------------------------------------------------------------------------- #
# Load dedicated libraries:

use lib $ENV{ LIB_ROOT };
use MyUtil   qq(:ALL); # ancillary utilities...
use MyMath   qq(:ALL); # dedicated math toolbox...
use MyPrint  qq(:ALL); # plain text print layouts...
use TimeGNSS qq(:ALL); # GNSS time conversion tools...
use Geodetic qq(:ALL); # dedicated geodesy utilities...

# ---------------------------------------------------------------------------- #
# Load tool's modules:

# Configuration:
use lib $ENV{ SRC_ROOT };
use GeneralConfiguration qq(:ALL);

# Tool classes:
use lib $ENV{ GSPA_ROOT };
use PlotSatObservation qq(:ALL);
use PlotPosPerformance qq(:ALL);
use PlotSatErrorSource qq(:ALL);
use PlotLSQInformation qq(:ALL);
use ReportPerformances qq(:ALL);

# Script constants:
# ---------------------------------------------------------------------------- #
use constant {
  ERR_WRONG_INPUTS    => 30001,
  ERR_WRONG_DIRECTORY => 30002,
};

# ============================================================================ #
# Main routine:
# ============================================================================ #

# Init script clock:
my $ini_script_time = [gettimeofday];

# ---------------------------------------------------------------------------- #
# 1. Read script input arguments and check them

  my ( $input_status,
       $inp_path,
       $out_path,
       $ref_gen_conf, $ref_obs_data, $cfg_file ) = CheckInputArguments(@ARGV);

  # Exit script if inputs were not correctly provided:
  unless ($input_status) { croak "Wrong provision of inputs"; }

  # Open existing log file for appending GSPA events log:
  my $fh_log; open($fh_log, '>>', $ref_gen_conf->{LOG_FILE_PATH}) or croak $!;

  # Welcome message:
  PrintWelcomeMessage($inp_path, $cfg_file, *STDOUT, $fh_log);

# ---------------------------------------------------------------------------- #
# 2. Data plotting routine:



# ---------------------------------------------------------------------------- #
# 3. Performance reporting routine:



# Termination:
# ---------------------------------------------------------------------------- #
PrintGoodbyeMessage( $ref_gen_conf, $out_path, $fh_log,
                     $ini_script_time, [gettimeofday]);

# ============================================================================ #
# End of script
# ============================================================================ #

# ---------------------------------------------------------------------------- #
# Script subroutines:

# Script management subs:
sub CheckInputArguments {
  my @script_inputs = @_;

  # Init subroutine status:
  my $status = FALSE;

  # Init variable to hold input path, outpu path and reference to
  # configuration:
  my $ref_gen_conf = {};
  my $ref_obs_data = {};
  my ($inp_path, $out_path, $cfg_file);

  # Check the number of inputs provided:
  # Case 1: 2 inputs -> input_path and output_path:
  # Case 2: 3 inputs -> "" + configuration file path
  given (scalar(@script_inputs))
  {
    when ($_ == 2) {

      # Input and output are directly read:
      ($inp_path, $out_path) = @script_inputs;

      # Check input and output directories:
      $status = CheckDirectories($inp_path, $out_path);

      # General configuration is loaded from raw hash stored in input path:
      $cfg_file = join('/', ($inp_path, "ref_gen_conf.hash"));
      $ref_gen_conf = retrieve($cfg_file);

      # Observation data is loaded from raw hash:
      my $obs_data_raw = join('/', ($inp_path, "ref_obs_data.hash"));
      $ref_obs_data = retrieve($obs_data_raw);

      # Update sub status:
      $status *= TRUE;

    }

    when ($_ == 3)
    {
      # Input and output are directly read:
      ($inp_path, $out_path, $cfg_file) = @script_inputs;

      # Check input and output directories:
      $status = CheckDirectories($inp_path, $out_path);

      # Observation data is loaded from raw hash:
      my $obs_data_raw = join('/', ($inp_path, "ref_obs_data.hash"));
      $ref_obs_data = retrieve($obs_data_raw);

      # Check provided file:
      $status *= CheckConfigurationFile($cfg_file);

      # General configuration is loaded from provided file:
      $ref_gen_conf = LoadConfiguration( $cfg_file );

      # Update sub's status:
      $status *= ($ref_gen_conf != KILLED) ? TRUE : FALSE;

    } # end when 3

    default {

      RaiseError(*STDOUT, ERR_WRONG_INPUTS,
        "Script was fed with an invalid number of inputs.",
        "Number of inputs should be among 2 and 3.",
        "Number of inputs = $_ : '".join(', ', @script_inputs)."'");
      $status *= FALSE;

    } # end default

  } # end given

  return( $status,
          $inp_path, $out_path,
          $ref_gen_conf, $ref_obs_data, $cfg_file );
}

# Print subs:
sub PrintWelcomeMessage {
  my ($inp_path, $cfg_file, @streams) = @_;

  my $msg1 = "Welcome to GNSS Rinex Single Service Performance Analyzer tool";
  my $msg2 = "Script was called from    : '".abs_path($0)."'";
  my $msg3 = "GRPP data loaded from     : '".abs_path($inp_path)."'";
  my $msg4 = "Configuration loaded from : '".abs_path($cfg_file)."'";

  for (@streams) {
    print $_ "\n" x 1;
    PrintTitle0  ($_, $msg1);
    PrintComment ($_, $msg2);
    PrintComment ($_, $msg3);
    PrintComment ($_, $msg4);
    print $_ "\n" x 1;
  }

  return TRUE;
}

sub PrintGoodbyeMessage {
  my ($ref_gen_conf, $out_path, $fh_log, $ini_time, $end_time) = @_;

  for (*STDOUT, $fh_log) {
    print $_ "\n" x 1;
    PrintTitle1  ($_, "GNSS Rinex Single Service Performance ".
                      "Analyzer routine is over");
    PrintComment ($_, "Plots and reports are available at : '$out_path'");
    PrintComment ($_, "Log file is available at           : '".
                  $ref_gen_conf->{LOG_FILE_PATH}."'");
    print $_ "\n" x 1;
    ReportElapsedTime($ini_time, $end_time, "Single-GSPA script = ", $_);
    print $_ LEVEL_0_DELIMITER;
    print $_ "\n" x 2;
  }

  return TRUE;
}

# Ancillary subs:
sub CheckDirectories {
  my ($inp_path, $out_path) = @_;

  # Init status:
  my $status = TRUE;

  # Make temporal hash:
  my %tmp_hash = ( 'input' => $inp_path, 'output' => $out_path );

  while (my ($dir_type, $dir) = each %tmp_hash ) {
    unless ( -d $dir ) {
      RaiseError(*STDOUT, ERR_WRONG_DIRECTORY,
      ucfirst $dir_type." path is not a valid directory!",
      "Provided directory : '$dir'");
      $status *= FALSE;
    }
  }

  # Input dir must shall be readable:
  unless (-r $inp_path) {
    RaiseError(*STDOUT, ERR_WRONG_DIRECTORY,
      "Input directory has not read permissions by ".$ENV{ USER }." user",
      "Provided directory : $inp_path");
    $status *= FALSE;
  }

  # Output dir shall hasve write permissions:
  unless (-r $out_path) {
    RaiseError(*STDOUT, ERR_WRONG_DIRECTORY,
      "Output directory has not write permissions by ".$ENV{ USER }." user",
      "Provided directory : $out_path");
    $status *= FALSE;
  }

  return $status;
}

sub ReportElapsedTime {
  my ($ini_time, $end_time, $label, $fh) = @_;

  PrintTitle4( $fh,
               sprintf("Elapsed time for $label %.2f seconds",
               tv_interval($ini_time, $end_time)) );

  return TRUE;
}
