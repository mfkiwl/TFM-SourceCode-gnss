#!/usr/bin/perl -X

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
use constant WARN_MARKER_NAME_NOT_EQUAL => 90001;

# ============================================================================ #

# Init script clock:
my $ini_script_time = [gettimeofday];

# 1. Read tool configuration:
# ---------------------------------------------------------------------------- #

  # Script arguments:
  #   1. Configuration file
  my ($cfg_file_path) = @ARGV;

  # Welcome message on STDOUT:
  PrintWelcomeMessage($cfg_file_path, *STDOUT);

  # Check if configuration file:
  my $cfg_file_status = CheckConfigurationFile( $cfg_file_path );

  # Exit if configuration file could not be read:
  unless ($cfg_file_status) {
    croak "Configuration file reading error";
  }

  # Read configuration:
  my $ref_gen_conf = LoadConfiguration( $cfg_file_path, *STDOUT );

  # Exit if configuration was not loaded properly:
  if ($ref_gen_conf == KILLED) {
    croak "Configuration file loading error";
  }

  # Copy configuration file in output path:
  CopyConfigurationFile($cfg_file_path, $ref_gen_conf);

  # Open tool's log file:
  my $fh_log; open($fh_log, '>', $ref_gen_conf->{LOG_FILE_PATH}) or croak $!;

  # Welcome message on log file:
  PrintWelcomeMessage($cfg_file_path, $fh_log);

  # Print basic configuration:
  PrintBasicConfiguration($ref_gen_conf, $fh_log);


# 2. Rinex data processing routine:
# ---------------------------------------------------------------------------- #
  my ( $proc_status,
       $ref_obs_data,
       $ref_nav_data ) = DataProcessingRoutine($ref_gen_conf, $fh_log);

  if ($proc_status == FALSE) {
    croak "Data processing routine exited with error";
  }


# 3. Data dumping routine:
# ---------------------------------------------------------------------------- #
  my ($dump_status) = DataDumpingRoutine($ref_gen_conf, $ref_obs_data, $fh_log);

  if ($proc_status == FALSE) {
    croak "Data dumping routine exited with error";
  }


# 4. Script termination:
# ---------------------------------------------------------------------------- #
  PrintGoodbyeMessage($ref_gen_conf, $fh_log, $ini_script_time, [gettimeofday]);


# ============================================================================ #

# Script subroutines:
# ---------------------------------------------------------------------------- #

# Script management subs:
sub DataProcessingRoutine {
  my ($ref_gen_conf, $fh_log) = @_;

  # Init sub status:
  my $status = FALSE;

  for (*STDOUT, $fh_log) {
    print $_ "\n" x 2;
    PrintTitle1($_, "Data Processing routine has started");
    PrintTitle3($_, "Reading Observation Rinex...");
  }

  # Read observation rinex:
  my $ini_read_rinex = [gettimeofday];
    my $ref_obs_data = ReadObservationRinexV3($ref_gen_conf, $fh_log);
  my $end_read_rinex = [gettimeofday];

  if ($ref_gen_conf->{STATIC}{STATUS} &&
      $ref_gen_conf->{STATIC}{REFERENCE_MODE} eq &IGS_STATIC_MODE) {
    CheckMarkerName($ref_gen_conf, $ref_obs_data, $fh_log);
  }

  # Update sub status:
  $status += ($ref_obs_data != KILLED) ? TRUE : FALSE;

  for (*STDOUT, $fh_log) {
    print $_ "\n" x 1;
    PrintTitle3($_, "Computing satellite positions...");
  }

  # Compute satellite positions:
  my $ini_sat_position = [gettimeofday];
    my $ref_nav_data =
      ComputeSatPosition( $ref_gen_conf, $ref_obs_data, $fh_log );
  my $end_sat_position = [gettimeofday];

  # Update sub status:
  $status *= ($ref_nav_data != KILLED) ? TRUE : FALSE;

  for (*STDOUT, $fh_log) {
    print $_ "\n" x 1;
    PrintTitle3($_, "Computing receiver positions...");
  }

  # Compute receiver positons:
  my $ini_rec_position = [gettimeofday];
    my $rec_position_status =
      ComputeRecPosition($ref_gen_conf, $ref_obs_data, $ref_nav_data, $fh_log);
  my $end_rec_position = [gettimeofday];

  # Update sub status:
  $status *= ($rec_position_status != KILLED) ? TRUE : FALSE;

  # Report solution extract:
  PrintSolutionExtract($ref_obs_data, $fh_log);

  # Report elapsed times:
  for (*STDOUT, $fh_log) {
    print $_ "\n" x 1;
    PrintTitle3($_, "Data processing time lapses:");
    ReportElapsedTime( $ini_read_rinex, $end_read_rinex,
                       "reading observation RINEX     = ", $_ );
    ReportElapsedTime( $ini_sat_position, $end_sat_position,
                       "computing satellite positions = ", $_ );
    ReportElapsedTime( $ini_rec_position, $end_rec_position,
                       "computing receiver positions  = ", $_ );
    print $_ "\n" x 1;
  }

  return ($status, $ref_obs_data, $ref_nav_data);
}

sub DataDumpingRoutine {
  my ($ref_gen_conf, $ref_obs_data, $fh_log) = @_;

  # Init sub status:
  my $status = FALSE;

  # Also, init undef the subroutine generic status:
  my $sub_status;

  # Gather selected observations in array reference:
  my $ref_selected_obs = [];
  for (@{ $ref_gen_conf->{SELECTED_SAT_SYS} }) {
    push(@{ $ref_selected_obs }, $ref_gen_conf->{SELECTED_SIGNALS}{$_})
  }

  for (*STDOUT, $fh_log) {
    print $_ "\n" x 2;
    PrintTitle1($_, "Data Dumping routine has started");
    PrintTitle3($_, "Dumping satellite observation data...");
      PrintBulletedInfo($_, "\t- ",
        "Gathered satellite observations",
        "Number of valid satellites",
        "Satellite navigation positions");
  }

  my $ini_sat_obs_data = [gettimeofday];

    $sub_status = DumpSatObsData( $ref_gen_conf,
                                  $ref_obs_data,
                                  $ref_selected_obs,
                                  $ref_gen_conf->{OUTPUT_PATH}, $fh_log );
    # Update status:
    $status += ($sub_status != KILLED) ? TRUE : FALSE;

    $sub_status = DumpNumValidSat( $ref_gen_conf,
                                   $ref_obs_data,
                                   $ref_gen_conf->{OUTPUT_PATH}, $fh_log );
    # Update status:
    $status *= ($sub_status != KILLED) ? TRUE : FALSE;

    $sub_status = DumpSatPosition( $ref_gen_conf,
                                   $ref_obs_data,
                                   $ref_gen_conf->{OUTPUT_PATH}, $fh_log );
    # Update status:
    $status *= ($sub_status != KILLED) ? TRUE : FALSE;

  my $end_sat_obs_data = [gettimeofday];

  for (*STDOUT, $fh_log) {
    print $_ "\n" x 1;
    PrintTitle3($_, "Dumping satellite line of sight related data...");
    PrintBulletedInfo($_, "\t- ",
      "Elevation by satellite",
      "Azimut by satellite",
      "Line of sight information");
  }

  my $ini_los_data = [gettimeofday];

    $sub_status = DumpElevationBySat( $ref_gen_conf,
                                      $ref_obs_data,
                                      $ref_gen_conf->{OUTPUT_PATH}, $fh_log );
    # Update status:
    $status *= ($sub_status != KILLED) ? TRUE : FALSE;

    $sub_status = DumpAzimutBySat( $ref_gen_conf,
                                   $ref_obs_data,
                                   $ref_gen_conf->{OUTPUT_PATH}, $fh_log );
    # Update status:
    $status *= ($sub_status != KILLED) ? TRUE : FALSE;

    $sub_status = DumpRecSatLoSData( $ref_gen_conf,
                                     $ref_obs_data,
                                     $ref_gen_conf->{OUTPUT_PATH}, $fh_log );
    # Update status:
    $status *= ($sub_status != KILLED) ? TRUE : FALSE;

  my $end_los_data = [gettimeofday];

  for (*STDOUT, $fh_log) {
    print $_ "\n" x 1;
    PrintTitle3($_, "Dumping satellite error modelling related data...");
      PrintBulletedInfo($_, "\t- ",
        "Ionosphere delay by satellite",
        "Troposphere delay by satellite",
        "LSQ residuals by satellite");
  }

  my $ini_err_mod = [gettimeofday];

  $sub_status = DumpIonoCorrBySat( $ref_gen_conf,
                                     $ref_obs_data,
                                     $ref_gen_conf->{OUTPUT_PATH}, $fh_log );
    # Update status:
    $status *= ($sub_status != KILLED) ? TRUE : FALSE;

    $sub_status = DumpTropoCorrBySat( $ref_gen_conf,
                                      $ref_obs_data,
                                      $ref_gen_conf->{OUTPUT_PATH}, $fh_log );
    # Update status:
    $status *= ($sub_status != KILLED) ? TRUE : FALSE;

    $sub_status = DumpResidualsBySat( $ref_gen_conf,
                                      $ref_obs_data,
                                      $ref_gen_conf->{OUTPUT_PATH}, $fh_log );
    # Update status:
    $status *= ($sub_status != KILLED) ? TRUE : FALSE;

  my $end_err_mod = [gettimeofday];


  for (*STDOUT, $fh_log) {
    print $_ "\n" x 1;
    PrintTitle3($_, "Dumping LSQ related data...");
      PrintBulletedInfo($_, "\t- ",
        "LSQ report by performed iteration per epoch",
        "LSQ report per observation epoch (last performed iteration)");
  }

  my $ini_lsq_data = [gettimeofday];

    $sub_status = DumpLSQReportByIter( $ref_gen_conf,
                                       $ref_obs_data,
                                       $ref_gen_conf->{OUTPUT_PATH}, $fh_log );
    # Update status:
    $status *= ($sub_status != KILLED) ? TRUE : FALSE;

    $sub_status = DumpLSQReportByEpoch( $ref_gen_conf,
                                        $ref_obs_data,
                                        $ref_gen_conf->{OUTPUT_PATH}, $fh_log );
    # Update status:
    $status *= ($sub_status != KILLED) ? TRUE : FALSE;

  my $end_lsq_data = [gettimeofday];

  for (*STDOUT, $fh_log) {
    print $_ "\n" x 1;
    PrintTitle3($_, "Dumping receiver position related data...");
    PrintBulletedInfo($_, "\t- ",
      "Receiver position solutions in ECEF and ENU frames per epoch",
      "Dilution Of Precision in ECEF and ENU frames per epoch");
  }

  my $ini_rec_data = [gettimeofday];

    $sub_status = DumpRecPosition( $ref_gen_conf,
                                   $ref_obs_data,
                                   $ref_gen_conf->{OUTPUT_PATH}, $fh_log );
    # Update status:
    $status *= ($sub_status != KILLED) ? TRUE : FALSE;

    $sub_status = DumpEpochDOP( $ref_gen_conf,
                                $ref_obs_data,
                                $ref_gen_conf->{OUTPUT_PATH}, $fh_log );
    # Update status:
    $status *= ($sub_status != KILLED) ? TRUE : FALSE;

  my $end_rec_data = [gettimeofday];

  for (*STDOUT, $fh_log) {
    print $_ "\n" x 1;
    PrintTitle3($_, "Dumping raw configuration and data hashes...");
    PrintBulletedInfo($_, "\t- ",
      'Raw general configuration perl hash : "$ref_gen_conf"',
      'Raw observation data perl hash : "$ref_obs_data"');
  }

  my $ini_hash_data = [gettimeofday];

    # General configuration hash:
    $sub_status =
      store($ref_gen_conf, $ref_gen_conf->{OUTPUT_PATH}."/ref_gen_conf.hash");

    # Update status:
    $status *= (undef $sub_status) ? FALSE : TRUE;

    # Observation data:
    $sub_status =
      store($ref_obs_data, $ref_gen_conf->{OUTPUT_PATH}."/ref_obs_data.hash");

    # Update status:
    $status *= (undef $sub_status) ? FALSE : TRUE;

  my $end_hash_data = [gettimeofday];

  # Report elapsed times:
  for (*STDOUT, $fh_log) {
    print $_ "\n" x 1;
    PrintTitle3($_, "Data dumping time lapses:");
    ReportElapsedTime( $ini_sat_obs_data, $end_sat_obs_data,
                       "dumping satellite observation data      = ", $_ );
    ReportElapsedTime( $ini_los_data, $end_los_data,
                       "dumping line of sight related data      = ", $_ );
    ReportElapsedTime( $ini_err_mod, $end_err_mod,
                       "dumping satellite error modeling data   = ", $_ );
    ReportElapsedTime( $ini_lsq_data, $end_lsq_data,
                       "dumping least squares related data      = ", $_ );
    ReportElapsedTime( $ini_rec_data, $end_rec_data,
                       "dumping receiver position related data  = ", $_ );
    ReportElapsedTime( $ini_hash_data, $end_hash_data,
                       "dumping raw configuration and data hash = ", $_ );
    print $_ "\n" x 1;
  }

  return $status;
}

# Print and Report subs:
sub PrintWelcomeMessage {
  my ($cfg_file_path, @streams) = @_;

  my $msg1 = "Welcome to GNSS Rinex Post-Processing tool";
  my $msg2 = "Script was called from  : '".abs_path($0)."'";
  my $msg3 = "Configuration file used : '".abs_path($cfg_file_path)."'";

  for (@streams) {
    print $_ "\n" x 1;
    PrintTitle0  ($_, $msg1);
    PrintComment ($_, $msg2);
    PrintComment ($_, $msg3);
    print $_ "\n" x 1;

  }

  return TRUE;
}

sub PrintBasicConfiguration {
  my ($ref_gen_conf, $fh_log) = @_;

  # Retrieve configuration:
  my @selected_sat_sys = @{ $ref_gen_conf->{SELECTED_SAT_SYS} };
  my $obs_rinex = ( split('/', $ref_gen_conf->{RINEX_OBS_PATH}) )[-1];

  # Contens:
  # Header:
  my $head = "Configuration brief:";

  # Satellite system configuration:
  my $s1 = "Selected Satellyte Systems and Observation";
  my @sat_sys_info;

  for (@selected_sat_sys) {
    my $obs = $ref_gen_conf->{SELECTED_SIGNALS}{$_};
    my $msg = SAT_SYS_ID_TO_NAME->{$_}." ($_) -> ".
              SAT_SYS_OBS_TO_NAME->{$_}{substr($obs, 0, 2)}." ($obs)";
    push(@sat_sys_info, $msg);
  }

  # Rinex input files:
  my $s2 = "Rinex Input files";

  my @rinex_info = ( "Observation Rinex : $obs_rinex" );
  for (@selected_sat_sys) {
    my $nav_rinex = ( split('/', $ref_gen_conf->{RINEX_NAV_PATH}{$_}) )[-1];
    my $msg = SAT_SYS_ID_TO_NAME->{$_}." Navigation Rinex : $nav_rinex";
    push(@rinex_info, $msg);
  }

  # Processing time parameters:
  my $s3 = "Processing time window";

  my ( $ini_time,
       $end_time,
       $interval ) = ( $ref_gen_conf->{INI_EPOCH},
                       $ref_gen_conf->{END_EPOCH},
                       $ref_gen_conf->{INTERVAL} );

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
                    $ref_gen_conf->{SAT_MASK}*RADIANS_TO_DEGREE." [deg]" );

  for (@selected_sat_sys) {
    my $sat = join(', ', @{ $ref_gen_conf->{SAT_TO_DISCARD}{$_} });
       $sat = "None" unless $sat;
    my $msg = "Discarded ".SAT_SYS_ID_TO_NAME->{$_}." satellites : $sat";
    push(@mask_info, $msg);
  }

  # Error source models:
  my $s5 = "Error Source Models";
  my @error_info =
    ("Troposphere model : ".ucfirst $ref_gen_conf->{TROPOSPHERE_MODEL});

  for (@selected_sat_sys) {
    my $msg = SAT_SYS_ID_TO_NAME->{$_}." Ionosphere model : ".
              ucfirst $ref_gen_conf->{IONOSPHERE_MODEL}{$_};
    push(@error_info, $msg);
  }


  # Static configuration:
  # NOTE: will only be reported if static mode is activated!
  my $s6; my @static_info;
  if ($ref_gen_conf->{STATIC}{STATUS}) {
    $s6 = "Static Mode Configuration";
    push(@static_info,
      "Static mode : ". uc $ref_gen_conf->{STATIC}{REFERENCE_MODE});

    if ($ref_gen_conf->{STATIC}{REFERENCE_MODE} eq &IGS_STATIC_MODE) {
      push(@static_info, "IGS station : ".$ref_gen_conf->{STATIC}{IGS_STATION});
    }

    my @ecef_xyz = @{ $ref_gen_conf->{STATIC}{REFERENCE} };
    push(@static_info,
         "Reference ECEF (X, Y, Z) = ".sprintf("%12.3f " x 3, @ecef_xyz));

    my ($lat, $lon, $helip) =
      ECEF2Geodetic( @ecef_xyz, $ref_gen_conf->{ELIPSOID} );

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
    PrintTitle3  ($_, $s1);
    PrintBulletedInfo ($_, "\t- ", @sat_sys_info);
    print $_ "\n" x 1;
    PrintTitle3  ($_, $s4);
    PrintBulletedInfo ($_, "\t- ", @mask_info);
    print $_ "\n" x 1;
    PrintTitle3  ($_, $s5);
    PrintBulletedInfo ($_, "\t- ", @error_info);
    print $_ "\n" x 1;
    PrintTitle3  ($_, $s2);
    PrintBulletedInfo ($_, "\t- ", @rinex_info);
    print $_ "\n" x 1;
    PrintTitle3  ($_, $s3);
    PrintBulletedInfo ($_, "\t- ", @time_info);
    if ($ref_gen_conf->{STATIC}{STATUS}) {
      print $_ "\n" x 1;
      PrintTitle3  ($_, $s6);
      PrintBulletedInfo ($_, "\t- ", @static_info);
    }
  }

  return TRUE;
}

sub PrintSolutionExtract {
  my ($ref_obs_data, $fh_log) = @_;

  for my $fh (*STDOUT, $fh_log)
  {
    print $fh "\n" x 1;
    PrintTitle4($fh, "Receiver positions for first 4 and last epochs:");
    for (0..3, -4..-1) {
      PrintComment( $fh, "\tObservation epoch : ".
        BuildDateString(GPS2Date($ref_obs_data->{BODY}[$_]{EPOCH})).
        " -> Status = ".
        ($ref_obs_data->{BODY}[$_]{REC_POSITION}{STATUS} ? "OK":"NOK") );
      PrintBulletedInfo($fh, "\t",
        "|  X |  Y |  Z =".
          join(' | ',
            sprintf( " %12.3f |" x 3,
                     @{$ref_obs_data->
                        {BODY}[$_]{REC_POSITION}{XYZ}} )
          ),
        "| sX | sY | sZ =".
          join(' | ',
            sprintf(" %12.3f |" x 3,
                    map{$_**0.5} @{$ref_obs_data->
                                    {BODY}[$_]{REC_POSITION}{VAR_XYZ}})
          )
        );

      PrintBulletedInfo($fh, "\t", "[...]") if ($_ == 3);
    }
  }

  return TRUE;
}

sub PrintGoodbyeMessage {
  my ($ref_gen_conf, $fh_log, $ini_time, $end_time) = @_;

  for (*STDOUT, $fh_log) {
    print $_ "\n" x 2;
    PrintTitle1  ($_, "GNSS Rinex Post-Processing routine is over");
    PrintComment ($_, "Results are available at : ".
                  $ref_gen_conf->{OUTPUT_PATH});
    PrintComment ($_, "Log file is available at : ".
                  $ref_gen_conf->{LOG_FILE_PATH});
    print $_ "\n" x 1;
    ReportElapsedTime($ini_time, $end_time, "GRPP script = ", $_);
    print $_ LEVEL_0_DELIMITER;
    print $_ "\n" x 2;
  }

  return TRUE;
}

# Ancillary subs:
sub CopyConfigurationFile {
  my ($cfg_file_path, $ref_gen_conf) = @_;

  my $destination = join('/', ($ref_gen_conf->{OUTPUT_PATH}, "grpp_config.cfg"));
  copy($cfg_file_path, $destination);

  return TRUE;
}

sub CheckMarkerName {
  my ($ref_gen_conf, $ref_obs_data, $fh_log) = @_;

  my $static_marker_name = lc $ref_gen_conf->{STATIC}{IGS_STATION};
  my $rinex_marker_name  = lc $ref_obs_data->{HEAD}{MARKER_NAME};

  unless ($static_marker_name eq $rinex_marker_name) {
    RaiseWarning($fh_log, WARN_MARKER_NAME_NOT_EQUAL,
      "Station mismatch among static mode IGS station and observation ".
      "RINEX marker name:",
      "\tIGS station (static mode) : $static_marker_name",
      "\tRINEX marker name         : $rinex_marker_name");
  }

  return TRUE;
}

sub ReportElapsedTime {
  my ($ini_time, $end_time, $label, $fh) = @_;

  PrintTitle4( $fh,
               sprintf("Elapsed time for $label %.2f seconds",
               tv_interval($ini_time, $end_time)) );

  return TRUE;
}

# ============================================================================ #
# END OF SCRIPT
