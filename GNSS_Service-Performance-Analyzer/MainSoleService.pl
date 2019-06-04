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

  my ($plot_status) =
    PlotReportingRoutine( $ref_gen_conf, $ref_obs_data,
                          $inp_path, $out_path, $fh_log );

# ---------------------------------------------------------------------------- #
# 3. Performance reporting routine:

  my ($perfo_status) =
    PerformanceReportingRoutine( $ref_gen_conf, $ref_obs_data,
                                 $inp_path, $out_path, $fh_log );

# ---------------------------------------------------------------------------- #
# Termination:

PrintGoodbyeMessage( $ref_gen_conf, $out_path, $fh_log,
                     $ini_script_time, [gettimeofday]);

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

sub PlotReportingRoutine {
  my ($ref_gen_conf, $ref_obs_data, $inp_path, $out_path, $fh_log) = @_;

  # Init subroutine status:
  my $status = TRUE;

  # Init generic streams:
  my @streams = (*STDOUT, $fh_log);

  # Init var to hold satellite system ID:
  my $sat_sys;

  # Retrieve station marker name from observation hash:
  my $marker = $ref_obs_data->{HEAD}{MARKER_NAME};

  # Info message:
  for (@streams) {
    print $_ "\n" x 2;
    PrintTitle1($_, "Plot reporting routine has started");
  }

  # ********************************************************* #
  # Ploting satellite dependent data: observation information #
  # ********************************************************* #
  my $ini_sat_obs_info = [gettimeofday];

    for $sat_sys (@{ $ref_gen_conf->{SELECTED_SAT_SYS} })
    {
      # Literal satellite system:
      my $sat_sys_name = SAT_SYS_ID_TO_NAME->{$sat_sys};

      # Satellite availability plot:
      for (@streams) {
        print $_ "\n" x 1;
        PrintTitle3($_, "Ploting $sat_sys_name satellite availability");
      }

      $status *=
        PlotSatelliteAvailability( $ref_gen_conf, $inp_path,
                                   $out_path, $sat_sys, $marker );

      # Satellite observed elevation plot:
      for (@streams) {
        print $_ "\n" x 1;
        PrintTitle3($_, "Ploting $sat_sys_name observed elevation");
      }

      $status *=
        PlotSatelliteElevation( $ref_gen_conf, $inp_path,
                                $out_path, $sat_sys, $marker );

      # Satellite Sky Path:
      for (@streams) {
        print $_ "\n" x 1;
        PrintTitle3($_, "Ploting $sat_sys_name sky-path");
      }

      $status *=
        PlotSatelliteSkyPath( $ref_gen_conf, $inp_path,
                              $out_path, $sat_sys, $marker );

    } # end for $sat_sys

  my $end_sat_obs_info = [gettimeofday];

  # ******************************************************* #
  # Plot satellite dependent data: error source information #
  # ******************************************************* #
  my $ini_sat_error = [gettimeofday];

    for $sat_sys (@{ $ref_gen_conf->{SELECTED_SAT_SYS} })
    {
      # Literal satellite system:
      my $sat_sys_name = SAT_SYS_ID_TO_NAME->{$sat_sys};

      # Satellite residuals plot:
      for (@streams) {
        print $_ "\n" x 1;
        PrintTitle3($_, "Ploting $sat_sys_name satellite residuals");
      }

      $status *=
        PlotSatelliteResiduals( $ref_gen_conf, $inp_path,
                                $out_path, $sat_sys, $marker );

      # Satellite ionosphere delay plot:
      for (@streams) {
        print $_ "\n" x 1;
        PrintTitle3($_, "Ploting $sat_sys_name satellite ionosphere delay");
      }

      $status *=
        PlotSatelliteIonosphereDelay( $ref_gen_conf, $inp_path,
                                      $out_path, $sat_sys, $marker );

      # Satellite troposphere delay plot:
      for (@streams) {
        print $_ "\n" x 1;
        PrintTitle3($_, "Ploting $sat_sys_name satellite troposphere delay");
      }

      $status *=
        PlotSatelliteTroposphereDelay( $ref_gen_conf, $inp_path,
                                       $out_path, $sat_sys, $marker );

    } # end for $sat_sys

  my $end_sat_error = [gettimeofday];

  # ******************************** #
  # Plot LSQ estimation information: #
  # ******************************** #
  my $ini_lsq_info = [gettimeofday];

    for (@streams) {
      print $_ "\n" x 1;
      PrintTitle3($_, "Ploting LSQ estimation iformation");
    }

    $status *=
      PlotLSQEpochEstimation( $ref_gen_conf, $inp_path, $out_path, $marker );

    my $end_lsq_info = [gettimeofday];

  # *************************************** #
  # Plot receiver positioning performances: #
  # *************************************** #
  my $ini_pos_perfo = [gettimeofday];

    for (@streams) {
      print $_ "\n" x 1;
      PrintTitle3($_, "Ploting receiver position solutions");
    }

    $status *=
      PlotReceiverPosition( $ref_gen_conf, $inp_path, $out_path, $marker );

    for (@streams) {
      print $_ "\n" x 1;
      PrintTitle3($_, "Ploting accuracy performance results");
    }

    $status *=
      PlotDilutionOfPrecission( $ref_gen_conf, $inp_path, $out_path, $marker );

    for (@streams) {
      print $_ "\n" x 1;
      PrintTitle3($_, "Ploting integrity performance results");
    }

    # The integrity info is only reported if the static and integrity modes
    # are enabled:
    if ( $ref_gen_conf->{STATIC}{STATUS} &&
         $ref_gen_conf->{INTEGRITY}{STATUS} ) {

      # TODO: sub

    } else {
      for (*STDOUT, $fh_log) {
        print $_ "\n" x 1;
        PrintComment($_, "However, no integrity mode was configured...");
      }
    }

  my $end_pos_perfo = [gettimeofday];

  # Report elapsed times:
  for (@streams) {
    print $_ "\n" x 1;
    PrintTitle3($_, "Graphical report time lapses:");
    ReportElapsedTime( $ini_sat_obs_info, $end_sat_obs_info,
                       "ploting satellite observation data   = ", $_ );
    ReportElapsedTime( $ini_sat_error, $end_sat_error,
                       "ploting satellite error source data  = ", $_ );
    ReportElapsedTime( $ini_lsq_info, $end_lsq_info,
                       "ploting LSQ estimation information   = ", $_ );
    ReportElapsedTime( $ini_pos_perfo, $end_pos_perfo,
                       "ploting positioning performance data = ", $_ );
    print $_ "\n" x 1;
  }

  return ($status);
}

sub PerformanceReportingRoutine {
  my ( $ref_gen_conf, $ref_obs_data, $inp_path, $out_path, $fh_log ) = @_;

  # Init subroutine status:
  my $status = TRUE;

  # Init generic streams:
  my @streams = (*STDOUT, $fh_log);

  # Retrieve station marker name from observation hash:
  my $marker = $ref_obs_data->{HEAD}{MARKER_NAME};

  # Info message:
  for (@streams) {
    print $_ "\n" x 2;
    PrintTitle1($_, "Performance reporting routine has started");
  }

  # Accuracy performance report:
  my $ini_acc_perfo = [gettimeofday];

    for (@streams) {
      print $_ "\n" x 1;
      PrintTitle3($_, "Reporting position accuracy performance");
    }

    $status *=
      ReportPositionAccuracy( $ref_gen_conf, $inp_path, $out_path, $marker );

  my $end_acc_perfo = [gettimeofday];

  # Error position performance report:
  my $ini_err_perfo = [gettimeofday];

    # Error position performance only available when static mode has been
    # activated:
    if ($ref_gen_conf->{STATIC}{STATUS}) {

      for (@streams) {
        print $_ "\n" x 1;
        PrintTitle3($_, "Reporting position error performance");
      }

      $status *=
        ReportPositionError( $ref_gen_conf, $inp_path, $out_path, $marker );

    } else {
      for (*STDOUT, $fh_log) {
        print $_ "\n" x 1;
        PrintComment($_, "However, no static mode was configured...");
      }
    }

  my $end_err_perfo = [gettimeofday];

  # Integrity performance report:
  my $ini_int_perfo = [gettimeofday];

    # Integrity position performance only available when both static mode
    # and itegrity mode have bee activated:
    if ( $ref_gen_conf->{STATIC}{STATUS} &&
         $ref_gen_conf->{INTEGRITY}{STATUS} ) {

      for (@streams) {
        print $_ "\n" x 1;
        PrintTitle3($_, "Reporting position integrity performance");
      }

      $status *=
        ReportPositionIntegrity( $ref_gen_conf, $inp_path, $out_path, $marker );

    } else {
      for (*STDOUT, $fh_log) {
        print $_ "\n" x 1;
        PrintComment($_, "However, no integrity mode was configured...");
      }
    }

  my $end_int_perfo = [gettimeofday];

  # Report elapsed times:
  for (@streams) {
    print $_ "\n" x 1;
    PrintTitle3($_, "Numerical report time lapses:");
    ReportElapsedTime( $ini_acc_perfo, $end_acc_perfo,
                       "reporting accuracy performance   = ", $_ );
    ReportElapsedTime( $ini_err_perfo, $end_err_perfo,
                       "reporting error performance      = ", $_ );
    ReportElapsedTime( $ini_int_perfo, $end_int_perfo,
                       "reporting integrity performance  = ", $_ );
    print $_ "\n" x 1;
  }

  return $status;
}

# Print subs:
sub PrintWelcomeMessage {
  my ($inp_path, $cfg_file, @streams) = @_;

  my $msg1 = "Welcome to GNSS Rinex Service Performance Analyzer tool";
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
    PrintTitle1  ($_, "GNSS Service Performance Analyzer routine is over");
    PrintComment ($_, "Plots and reports are available at : '$out_path'");
    PrintComment ($_, "Log file is available at           : '".
                  $ref_gen_conf->{LOG_FILE_PATH}."'");
    print $_ "\n" x 1;
    ReportElapsedTime($ini_time, $end_time, "GSPA script = ", $_);
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
