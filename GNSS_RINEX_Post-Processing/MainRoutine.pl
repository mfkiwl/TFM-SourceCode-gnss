#!/usr/bin/perl -w

# TODO: SCRIPT DESCRIPTION GOES HERE:

# Import common perl modules:
# ---------------------------------------------------------------------------- #
use Cwd qw(abs_path);    # directory path...
use Carp;   # advanced STDERR...
use strict; # enables strict syntax...

use Storable;           # save vars...
use File::Copy;         # copy files...
use Data::Dumper;       # var pretty print...
use feature qq(say);    # print adding line jump...
use feature qq(switch); # advanced switch statement...

# Precise time lapses:
use Time::HiRes qw(gettimeofday tv_interval);

# Load bash enviroments:
# ---------------------------------------------------------------------------- #
use lib $ENV{ ENV_ROOT };
use Enviroments qq(:CONSTANTS);

# Load dedicated libraries:
# ---------------------------------------------------------------------------- #
use lib $ENV{ LIB_ROOT };
use MyUtil   qq(:ALL); # ancillary utilities...
use MyMath   qq(:ALL); # dedicated math toolbox...
use MyPrint  qq(:ALL); # plain text print layouts...
use TimeGNSS qq(:ALL); # GNSS time conversion tools...
use Geodetic qq(:ALL); # dedicated geodesy utilities...

# Load tool's modules:
# ---------------------------------------------------------------------------- #
# Configuration:
use lib $ENV{ SRC_ROOT };
use GeneralConfiguration qq(:ALL);

# Tool classes:
use lib $ENV{ GRPP_ROOT };
use RinexReader qq(:ALL);
use SatPosition qq(:ALL);
use ErrorSource qq(:ALL);
use RecPosition qq(:ALL);
use DataDumper  qq(:ALL);

# Script constants:
# ---------------------------------------------------------------------------- #
use constant ERR_GRPP_READ_CONF => 000001;

# ============================================================================ #


# 1. Read tool configuration:
# ---------------------------------------------------------------------------- #
  # Script arguments:
  #   1. Configuration file
  my ($cfg_file_path) = @ARGV;

  # Check if configuration file:
  my $cfg_file_status = CheckConfigurationFile( $cfg_file_path );

  # Exit if configuration file could not be read:
  unless ($cfg_file_status) {
    croak "Configuration file reading error";
  }

  # Read configuration:
  my $ref_tool_cfg = LoadConfiguration( $cfg_file_path, *STDOUT );

  # Exit if configuration was not loaded properly:
  if ($ref_tool_cfg == KILLED) {
    croak "Configuration file loading error";
  }

  # Copy configuration file in output path:
  CopyConfigurationFile($cfg_file_path, $ref_tool_cfg);

  # Open tool's log file:
  my $fh_log; open($fh_log, '>', $ref_tool_cfg->{LOG_FILE_PATH}) or croak $!;

  # Welcome message on log file:
  PrintWelcomeMessage($fh_log);

  # Print basic configuration:
  PrintBasicConfiguration($ref_tool_cfg, $fh_log);


# 2. Rinex data processing routine:
# ---------------------------------------------------------------------------- #
  my ($proc_status) = RinexDataProcessing();


# 3. Data dumping routine:
# ---------------------------------------------------------------------------- #
  my ($dump_status) = DataDumping();



# ============================================================================ #

# Script subroutines:
# ---------------------------------------------------------------------------- #
sub CheckConfigurationFile {
  my ($cfg_file_path) = @_;

  # Init subroutine status:
  my $status = TRUE;

  # Check if configuration file:
  # a. Exists
    unless ( -e $cfg_file_path ) {
      RaiseError( *STDOUT,
                  ERR_GRPP_READ_CONF,
                  "Configuration file does not exists",
                  "Provided file: '$cfg_file_path'" );
      $status = FALSE;
    }
  # b. Is a plain text file
    unless (-f $cfg_file_path) {
      RaiseError( *STDOUT,
                  ERR_GRPP_READ_CONF,
                  "Configuration file is not plain text",
                  "Provided file: '$cfg_file_path'" );
      $status = FALSE;
    }
  # c. Can be read by effective uid/gid
    unless (-r $cfg_file_path) {
      RaiseError( *STDOUT,
                  ERR_GRPP_READ_CONF,
                  "Configuration file could not be read by effective user: ".
                  $ENV{ USER },
                  "Provided file: '$cfg_file_path'" );
      $status = FALSE;
    }

  return $status;
}

sub CopyConfigurationFile {
  my ($cfg_file_path, $ref_tool_cfg) = @_;

  my $destination = join('/', ($ref_tool_cfg->{OUTPUT_PATH}, "grpp_config.cfg"));
  copy($cfg_file_path, $destination);

  return TRUE;
}

sub PrintWelcomeMessage {
  my ($fh_log) = @_;

  my $msg1 = "Welcome to GNSS Rinex Post-Processing tool";
  my $msg2 = "Script was called from  : '".abs_path($0)."'";
  my $msg3 = "Configuration file used : '".abs_path($cfg_file_path)."'";

  my @streams = ( $fh_log, *STDOUT );

  for (@streams) {
    print $_ "\n" x 2;
    PrintTitle0  ($_, $msg1);
    PrintComment ($_, $msg2);
    PrintComment ($_, $msg3);
  }

  return TRUE;
}

sub PrintBasicConfiguration {
  my ($ref_tool_cfg, $fh_log) = @_;

  # Retrieve configuration:
  my @selected_sat_sys = @{ $ref_tool_cfg->{SELECTED_SAT_SYS} };
  my $obs_rinex = ( split('/', $ref_tool_cfg->{RINEX_OBS_PATH}) )[-1];

  # Contens:
  # Header:
  my $head = "Configuration brief:";

  # Satellite system configuration:
  my $s1 = "Selected Satellyte Systems and Observation";
  my @sat_sys_info;

  for (@selected_sat_sys) {
    my $obs = $ref_tool_cfg->{SELECTED_SIGNALS}{$_};
    my $msg = SAT_SYS_ID_TO_NAME->{$_}." ($_) -> ".
              SAT_SYS_OBS_TO_NAME->{$_}{substr($obs, 0, 2)}." ($obs)";
    push(@sat_sys_info, $msg);
  }

  # Rinex input files:
  my $s2 = "Rinex Input files";

  my @rinex_info = ( "Observation Rinex : $obs_rinex" );
  for (@selected_sat_sys) {
    my $nav_rinex = ( split('/', $ref_tool_cfg->{RINEX_NAV_PATH}{$_}) )[-1];
    my $msg = SAT_SYS_ID_TO_NAME->{$_}." Navigation Rinex : $nav_rinex";
    push(@rinex_info, $msg);
  }

  # Processing time parameters:
  my $s3 = "Processing time window";

  my ( $ini_time,
       $end_time,
       $interval ) = ( $ref_tool_cfg->{INI_EPOCH},
                       $ref_tool_cfg->{END_EPOCH},
                       $ref_tool_cfg->{INTERVAL} );

  my @time_info =
    ( "Start time = ".BuildDateString(GPS2Date($ini_time)).
      " (GPS time = $ini_time)",
      "End time   = ".BuildDateString(GPS2Date($end_time)).
      " (GPS time = $end_time)",
      "Interval   = $interval [sec]\n",
      "Number of epochs = ".(int(($end_time - $ini_time)/$interval) + 1) );

  # Mask configuration info:
  my $s4 = "Satellite Mask configuration";
  my @mask_info = ( "Elevation threshold = ".
                    $ref_tool_cfg->{SAT_MASK}*RADIANS_TO_DEGREE." [deg]" );

  for (@selected_sat_sys) {
    my $sat = join(', ', @{ $ref_tool_cfg->{SAT_TO_DISCARD}{$_} });
       $sat = "None" unless $sat;
    my $msg = "Discarded ".SAT_SYS_ID_TO_NAME->{$_}." satellites : $sat";
    push(@mask_info, $msg);
  }

  # Error source models:
  my $s5 = "Error Source Models";
  my @error_info =
    ("Troposphere model : ".ucfirst $ref_tool_cfg->{TROPOSPHERE_MODEL});

  for (@selected_sat_sys) {
    my $msg = SAT_SYS_ID_TO_NAME->{$_}." Ionosphere model : ".
              ucfirst $ref_tool_cfg->{IONOSPHERE_MODEL}{$_};
    push(@error_info, $msg);
  }


  # Static configuration:
  # NOTE: will only be reported if static mode is activated!
  my $s6; my @static_info;
  if ($ref_tool_cfg->{STATIC}{STATUS}) {
    $s6 = "Static Mode Configuration";
    push(@static_info,
      "Static mode : ". uc $ref_tool_cfg->{STATIC}{REFERENCE_MODE});

    if ($ref_tool_cfg->{STATIC}{REFERENCE_MODE} eq &IGS_STATIC_MODE) {
      push(@static_info, "IGS station : ".$ref_tool_cfg->{STATIC}{IGS_STATION});
    }

    my @ecef_xyz = @{ $ref_tool_cfg->{STATIC}{REFERENCE} };
    push(@static_info,
         "Reference ECEF (X, Y, Z) = ".sprintf("%12.3f " x 3, @ecef_xyz));

    my ($lat, $lon, $helip) =
      ECEF2Geodetic( @ecef_xyz, $ref_tool_cfg->{ELIPSOID} );

    push(@static_info,
         "Reference Geodetic (lat, lon, h) = ".
         sprintf("%5.7f %5.7f %5.3f",
         $lat*RADIANS_TO_DEGREE, $lon*RADIANS_TO_DEGREE, $helip));
  }

  # Select streams to report the info:
  my @streams = ( $fh_log, *STDOUT );

  # Report batch information:
  for (@streams) {
    print $_ "\n" x 2;
    PrintTitle1  ($_, $head);
    PrintTitle2  ($_, $s1);
    PrintComment ($_, @sat_sys_info);
    print $_ "\n" x 1;
    PrintTitle1  ($_, $s4);
    PrintComment ($_, @mask_info);
    print $_ "\n" x 1;
    PrintTitle1  ($_, $s5);
    PrintComment ($_, @error_info);
    print $_ "\n" x 1;
    PrintTitle1  ($_, $s2);
    PrintComment ($_, @rinex_info);
    print $_ "\n" x 1;
    PrintTitle1  ($_, $s3);
    PrintComment ($_, @time_info);
    if ($ref_tool_cfg->{STATIC}{STATUS}) {
      print $_ "\n" x 1;
      PrintTitle1  ($_, $s6);
      PrintComment ($_, @static_info);
    }
  }

  return TRUE;
}

sub RinexDataProcessing {}

sub DataDumping {}


# ============================================================================ #
# END OF SCRIPT
