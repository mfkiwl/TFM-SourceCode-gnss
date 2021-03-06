#!/usr/bin/perl -w

# TODO: SCRIPT DESCRIPTION GOES HERE:

# Package declaration:
package GeneralConfiguration;

# ---------------------------------------------------------------------------- #
# Set package exportation properties:

BEGIN {
  # Load export package:
  require Exporter;

  # Set package version:
  our $VERSION = 1.0;

  # Inherit from Exporter to export subs and constants:
  our @ISA = qq(Exporter);

  # Default export:
  our @EXPORT = ();

  # Define constants to export:
  our @EXPORT_CONST = qw( &RINEX_GPS_ID
                          &RINEX_GAL_ID
                          &SAT_SYS_ID_TO_NAME
                          &SAT_SYS_OBS_TO_NAME
                          &GPS_NAV_MSG_SOURCE_ID
                          &GPS_L1_FREQ
                          &GPS_L2_FREQ
                          &GPS_L5_FREQ
                          &GAL_E1_FREQ
                          &GAL_E5_FREQ
                          &GAL_E5a_FREQ
                          &GAL_E5b_FREQ
                          &NULL_DATA
                          &SUPPORTED_SAT_SYS
                          &ACCEPTED_SAT_SYS
                          &NONE_IONO_MODEL
                          &NEQUICK_IONO_MODEL
                          &KLOBUCHAR_IONO_MODEL
                          &SUPPORTED_IONO_MODELS
                          &NONE_TROPO_MODEL
                          &SAASTAMOINEN_TROPO_MODEL
                          &SUPPORTED_TROPO_MODELS
                          &GPS_EPOCH_FORMAT
                          &DATE_EPOCH_FORMAT
                          &GPS_WEEK_EPOCH_FORMAT
                          &DATE_STRING_EPOCH_FORMAT
                          &REF_EPOCH_SUB_CONF
                          &REF_ANGLE_SUB_CONF
                          &IGS_STATIC_MODE
                          &MEAN_STATIC_MODE
                          &MANUAL_STATIC_MODE
                          &WARN_NOT_SUPPORTED_SAT_SYS );

  # Define subroutines to export:
  our @EXPORT_SUB   = qw( &LoadConfiguration
                          &CheckConfigurationFile );

  # Merge constants and subroutines:
  our @EXPORT_OK = (@EXPORT_CONST, @EXPORT_SUB);

  # Define export tags:
  our %EXPORT_TAGS = ( ALL         => \@EXPORT_OK,
                       DEFAULT     => \@EXPORT,
                       CONSTANTS   => \@EXPORT_CONST,
                       SUBROUTINES => \@EXPORT_SUB );
}

# ---------------------------------------------------------------------------- #
# Load bash enviroments:

use lib $ENV{ ENV_ROOT };
use Enviroments qq(:CONSTANTS);

# ---------------------------------------------------------------------------- #
# Import Modules:

use Carp; # advanced exception raise...
use strict; # enables strict syntax...

use feature qq(say);    # same as print.$text.'\n'...
use feature qq(switch); # load perl switch method...

use Math::Trig;   # loads trigonometry methods...
use Data::Dumper; # enables pretty print...
use Scalar::Util qq(looks_like_number); # scalar utility...

# Import dedicated libraries:
use lib LIB_ROOT_PATH;
use MyUtil   qq(:ALL);
use MyMath   qq(:ALL);
use MyPrint  qq(:ALL);
use TimeGNSS qq(:ALL);
use Geodetic qq(:ALL);

# ---------------------------------------------------------------------------- #
# Prelimnary Subroutine --> Load IGS reference station coordinates

use constant IGS_REF_STATIONS_FILE_NAME     => qq(ITRF2008-2014_R.CRD);
use constant IGS_REF_STATIONS_LINE_TEMPLATE => 'A3A6A10x4A13x2A13x2A13x4A5';
use constant IGS_REF_STATIONS_END_OF_HEADER => 11;

sub LoadIGSReferenceStations {

  my $ref_igs_stations = {};

  # IGS reference stations path:
  my $igs_file_path =
    join('/', DAT_ROOT_PATH, "igs", IGS_REF_STATIONS_FILE_NAME);

  # Open file:
  my $fh; open($fh, '<', $igs_file_path) or die $!;

  # Skip file header:
  SkipLines( $fh, IGS_REF_STATIONS_END_OF_HEADER );

  # Read IGS file and store in a dedicated hash the
  # reference coordinates:
  while ( my $line = <$fh> ) {
    # Remove carriage jumps from line:
    chomp $line;

    # Identify line elements:
    my ( $num, $name, $id,
         $x, $y, $z, $flag ) = map{ PurgeExtraSpaces($_) }
                                unpack(IGS_REF_STATIONS_LINE_TEMPLATE, $line);

    # Build hash:
    $ref_igs_stations->{$name}{FLAG} = $id;
    $ref_igs_stations->{$name}{FLAG} = $flag;
    $ref_igs_stations->{$name}{ECEF} = [$x, $y, $z];
  }

  # Close file:
  close($fh);

  return $ref_igs_stations;
}

# ---------------------------------------------------------------------------- #
# Constants

# Satellite systems IDs:
use constant {
  RINEX_GPS_ID   => 'G',
  RINEX_GAL_ID   => 'E',
  RINEX_GLO_ID   => 'R',
  RINEX_BEI_ID   => 'C',
  RINEX_SBAS_ID  => 'S',
  RINEX_QZSS_ID  => 'J',
  RINEX_IRNSS_ID => 'I',
};

# Satellite system ID to name hash:
use constant
  SAT_SYS_ID_TO_NAME => { G => 'GPS',
                          E => 'GALILEO',
                          R => 'GLONASS',
                          C => 'BEIDOU',
                          S => 'SBAS',
                          J => 'QZSS' };

use constant
  SAT_SYS_OBS_TO_NAME => {
    G => {
      C1 => 'C/A',
      C2 => 'L2C',
      C5 => 'L5',
    },
    E => {
      C1 => 'E1',
      C5 => 'E5a',
      C7 => 'E5b',
      C8 => 'E5',
    },
  };

# GPS legacy navigation message data channel ID:
use constant GPS_NAV_MSG_SOURCE_ID => 1;

# Satellite system signal frequencies:
# GPS signal frequencies:
use constant {
  GPS_L1_FREQ => 1575.420e6, # [Hz]
  GPS_L2_FREQ => 1227.600e6, # [Hz]
  GPS_L5_FREQ => 1176.450e6, # [Hz]
};
# GALILEO signal frequencies
use constant {
  GAL_E1_FREQ  => 1575.420e6, # [Hz]
  GAL_E5_FREQ  => 1191.795e6, # [Hz]
  GAL_E5a_FREQ => 1176.450e6, # [Hz]
  GAL_E5b_FREQ => 1207.140e6, # [Hz]
  GAL_E6_FREQ  => 1278.750e6, # [Hz]
};

# Accepted and Supported satellite systems:
use constant SUPPORTED_SAT_SYS => qw(G E);
use constant ACCEPTED_SAT_SYS  => qw(G E R C S J I);

# Supported satellite signals:
# GPS pseudorange signals:
use constant SUPPORTED_GPS_SIGNALS => qw( C1C C1S C1L C1X C1P
                                          C2C C2D C2S C2L C2X C2P C2W
                                          C5I C5Q C5X );
# GALILEO pseudorange signals:
use constant SUPPORTED_GAL_SIGNALS => qw( C1C C1A C1B C1X C1Z
                                          C5I C5Q C5X
                                          C7I C7Q C7X );

# NULL data constant:
use constant NULL_DATA => 'NaN';

# Supported atmospheric correction models:
use constant {
  NONE_IONO_MODEL      => qq(none),
  NEQUICK_IONO_MODEL   => qq(nequick),
  KLOBUCHAR_IONO_MODEL => qq(klobuchar),
};

use constant {
  NONE_TROPO_MODEL         => qq(none),
  SAASTAMOINEN_TROPO_MODEL => qq(saastamoinen),
};

use constant SUPPORTED_IONO_MODELS  => ( NONE_IONO_MODEL,
                                         KLOBUCHAR_IONO_MODEL );

use constant SUPPORTED_TROPO_MODELS => ( NONE_TROPO_MODEL,
                                         SAASTAMOINEN_TROPO_MODEL );

# Supported elipsoids:
use constant SUPPORTED_ELIPSOIDS => qw(WGS84 GRS80 HAYFORD);

# Supported static reference modes:
use constant {
  IGS_STATIC_MODE    => qq(igs),
  MEAN_STATIC_MODE   => qq(mean),
  MANUAL_STATIC_MODE => qq(manual),
};

# List of supported static modes:
use constant SUPPORTED_STATIC_MODES => ( IGS_STATIC_MODE,
                                         MEAN_STATIC_MODE,
                                         MANUAL_STATIC_MODE );

# Hash to store IGS reference stations coordinates:
use constant REF_IGS_REFERENCE_STATIONS => LoadIGSReferenceStations();

# Supported epoch formats:
use constant {
  GPS_EPOCH_FORMAT         => qq(gps),
  DATE_EPOCH_FORMAT        => qq(date),
  GPS_WEEK_EPOCH_FORMAT    => qq(gps_week),
  DATE_STRING_EPOCH_FORMAT => qq(date_string),
};

use constant SUPPORTED_EPOCH_FORMATS => ( GPS_EPOCH_FORMAT,
                                          DATE_EPOCH_FORMAT,
                                          GPS_WEEK_EPOCH_FORMAT,
                                          DATE_STRING_EPOCH_FORMAT );

use constant
  REF_EPOCH_SUB_CONF => { &GPS_EPOCH_FORMAT         => \&DummySub,
                          &DATE_EPOCH_FORMAT        => \&GPS2Date,
                          &GPS_WEEK_EPOCH_FORMAT    => \&GPS2ToW,
                          &DATE_STRING_EPOCH_FORMAT => \&GPS2DateString };

# Supported angle formats:
use constant {
  RADIAN_ANGLE_FORMAT => qq(rad),
  DEGREE_ANGLE_FORMAT => qq(deg),
};

# Angle-Subroutine configuration:
use constant REF_ANGLE_SUB_CONF => { &RADIAN_ANGLE_FORMAT => \&DummySub,
                                     &DEGREE_ANGLE_FORMAT => \&Rad2Deg, };

use constant SUPPORTED_ANGLE_FORMATS => ( RADIAN_ANGLE_FORMAT,
                                          DEGREE_ANGLE_FORMAT );

# Class private Error and Warning codes:
# Errors:
use constant {
  ERR_CANNOT_READ_FILE       => 30401,
  ERR_CANNOT_WRITE_FILE      => 30402,
  ERR_OPTION_NOT_SUPPORTED   => 30403,
  ERR_SIGNAL_NOT_SUPPORTED   => 30404,
  ERR_MODEL_NOT_SUPPORTED    => 30405,
  ERR_ELIPSOID_NOT_SUPPORTED => 30406,
  ERR_OPTION_IS_NOT_NUMERIC  => 30407,
  ERR_OPTION_IS_NOT_BOOLEAN  => 30408,
  ERR_NO_SAT_SYS_CONFIGURED  => 30409,
  ERR_IGS_STATION_NOT_FOUND  => 30411,
  ERR_NOT_VALID_CONF_FILE    => 30412,
  ERR_STATIC_MODE_NOT_SUPPORTED => 30410,
};
# Warnings:
use constant {
  WARN_NOT_SUPPORTED_SAT_SYS => 90401,
};


# ---------------------------------------------------------------------------- #
# Public Subroutines:

sub LoadConfiguration {
  my ($file_path, $fh_log) = @_;

  # Init hash to hold the configuration parameters:
  my %config_hash;
  my $ref_config_hash = \%config_hash;

  # Load configuration file into scalar variable:
  my $fh; open($fh, '<', $file_path) or die $!;
    my @config_lines; push(@config_lines, $_) while (<$fh>);
  close($fh);

  # Remove comments and blank lines:
  @config_lines = grep(!/^#/, @config_lines);
  @config_lines = grep(!/^\s+$/, @config_lines);

  # Save vonfiguration content in a scalar variable:
  my $config_content = join('',  @config_lines);

  # ****************************** #
  # Read configuration parameters: #
  # ****************************** #

  # TODO: Module this crazy sub!

  # General section:
    # Verbosity:
    if ( $config_content =~ /^verbosity +: +(.+)$/im ) {
      my $verbosity_conf = ReadBoolean($1);
      if (defined $verbosity_conf) {
        $ref_config_hash->{VERBOSITY} = $verbosity_conf;
      } else {
        RaiseError(*STDOUT, ERR_OPTION_IS_NOT_BOOLEAN,
          "Unrecognized option for Verbosity parameter",
          "Please, indicate one of the following: \'TRUE\' or \'FALSE\'");
        return KILLED;
      }
    }

    # Processing tag:
    if ($config_content =~ /^Processing Tag +: +"(.+)"$/im) {
      my $tag = eval "qq#$1#"; # NOTE: be aware of eval usage
      $ref_config_hash->{TAG} = $tag;
    }

    # Satellite systems to process:
    if ( $config_content =~ /^Satellite Systems +: +(.+)$/im ) {
      my @sel_sat_sys;
      for my $sat_sys (split(/[\s,;]+/, $1)) {
        if (grep(/^$sat_sys$/, SUPPORTED_SAT_SYS)) {
          push(@sel_sat_sys, $sat_sys);
        } else {
          RaiseWarning(*STDOUT, WARN_NOT_SUPPORTED_SAT_SYS,
            "Satellite system \'$sat_sys\' is not supported",
            "The observations from this constellation will be ignored!",
            "Supported constellations are: ".join(', ', SUPPORTED_SAT_SYS));
        }
      }
      if (scalar(@sel_sat_sys)) {
        $ref_config_hash->{SELECTED_SAT_SYS} = \@sel_sat_sys;
      } else {
        RaiseError(*STDOUT, ERR_NO_SAT_SYS_CONFIGURED,
          "No supported satellite system was configured!");
        return KILLED;
      }
    }

    # Input sub-section (check file existence on each one):
    if ( $config_content =~ /^RINEX Observation path +: +(.+)$/im ) {
      my $rinex_obs_path = $1;
      if (-r $rinex_obs_path) {
        $ref_config_hash->{RINEX_OBS_PATH} = $rinex_obs_path;
      } else {
        RaiseError(*STDOUT, ERR_CANNOT_READ_FILE,
        "File \'$rinex_obs_path\' either cannot be read or does not exist");
        return KILLED;
      }
    }
    if ( $config_content =~ /^RINEX Navigation GPS path +: +(.+)$/im ) {
      my $rinex_g_nav_path = $1;
      if (-r $rinex_g_nav_path) {
        $ref_config_hash->{RINEX_NAV_PATH}{&RINEX_GPS_ID} = $rinex_g_nav_path;
      } else {
        RaiseError(*STDOUT, ERR_CANNOT_READ_FILE,
        "File \'$rinex_g_nav_path\' either cannot be read or does not exist");
        return KILLED;
      }
    }
    if ( $config_content =~ /^RINEX Navigation GAL path +: +(.+)$/im ) {
      my $rinex_e_nav_path = $1;
      if (-r $rinex_e_nav_path) {
        $ref_config_hash->{RINEX_NAV_PATH}{&RINEX_GAL_ID} = $rinex_e_nav_path;
      } else {
        RaiseError(*STDOUT, ERR_CANNOT_READ_FILE,
        "File \'$rinex_e_nav_path\' either cannot be read or does not exist");
        return KILLED;
      }
    }

    # Output sub-section:
    if ( $config_content =~ /^GRPP Output path +: +(.+)$/im ) {
      my $output_path = $1;
      if (-w $output_path) {
        $ref_config_hash->{OUTPUT_PATH}{GRPP} = $output_path;
      } else {
        RaiseError(*STDOUT, ERR_CANNOT_WRITE_FILE,
          "Current user ".$ENV{USER}." does not have write permissions at ".
          "\'$output_path\' or the provided path does not exist.");
        return KILLED;
      }
    }
    if ( $config_content =~ /^GSPA Output path +: +(.+)$/im ) {
      my $output_path = $1;
      if (-w $output_path) {
        $ref_config_hash->{OUTPUT_PATH}{GSPA} = $output_path;
      } else {
        RaiseError(*STDOUT, ERR_CANNOT_WRITE_FILE,
          "Current user ".$ENV{USER}." does not have write permissions at ".
          "\'$output_path\' or the provided path does not exist.");
        return KILLED;
      }
    }
    if ( $config_content =~ /^Log File +: +(.+)$/im ) {
      my $log_file_path = $1;
      # Remove file name from path to check write permissions:
      my @path_elements = split(/\//, $log_file_path);
      my $log_path = join('/', @path_elements[0..$#path_elements - 1]);
      if (-w $log_path) {
        $ref_config_hash->{LOG_FILE_PATH} = $log_file_path;
      } else {
        RaiseError(*STDOUT, ERR_CANNOT_WRITE_FILE,
          "Current user \'".$ENV{USER}."\' does not have write permissions at ".
          "\'$log_path\' or the provided path does not exist.");
        return KILLED;
      }
    }

  # Processing parameters section:
    # Time parameter sub-section:
    if ( $config_content =~ /^Ini Epoch \[GPS\] +: +(.+)$/im ) {
      my $ini_epoch = $1;
      # Check date format:
      if ($ini_epoch =~ m!\d{4}/\d{2}/\d{2} \d{2}:\d{2}:\d{2}!) {
        # Convert date and time in GPS time format:
        my ($date, $time) = split(/\s+/, $ini_epoch);
        $ref_config_hash->{INI_EPOCH} =
          Date2GPS(split(/\//, $date), split(/:/, $time));
      } else {
        RaiseError(*STDOUT, ERR_OPTION_NOT_SUPPORTED,
          "Date format is erroneous at \'Ini Epoch [GPS]  :  $ini_epoch\'",
          "Please provide a valid date in the format of yyyy/mm/dd hh:mi:ss");
        return KILLED;
      }
    }
    if ( $config_content =~ /^End Epoch \[GPS\] +: +(.+)$/im ) {
      my $end_epoch = $1;
      # Check date format:
      if ($end_epoch =~ m!\d{4}/\d{2}/\d{2} \d{2}:\d{2}:\d{2}!) {
        # Convert date and time in GPS time format:
        my ($date, $time) = split(/\s+/, $end_epoch);
        $ref_config_hash->{END_EPOCH} =
          Date2GPS(split(/\//, $date), split(/:/, $time));
      } else {
        RaiseError(*STDOUT, ERR_OPTION_NOT_SUPPORTED,
          "Date format is erroneous at \'End Epoch [GPS]  :  $end_epoch\'",
          "Please provide a valid date in the format of yyyy/mm/dd hh:mi:ss");
        return KILLED;
      }
    }
    if ( $config_content =~ /^Interval \[seconds\] +: +(.+)$/im ) {
      my $interval = $1;
      if (looks_like_number($interval)) {
        $ref_config_hash->{INTERVAL} = $interval;
      } else {
        RaiseError(*STDOUT, ERR_OPTION_IS_NOT_NUMERIC,
          "Retrieved interval \'$interval\' is not numeric");
        return KILLED;
      }
    }

    # Observation configuration sub-section:
    if ( grep(/^${\RINEX_GPS_ID}$/, @{$ref_config_hash->{SELECTED_SAT_SYS}}) ) {
      if ( $config_content =~ /^GPS Signal Observation +: +(.+)$/im ) {
        my $gps_signal = $1;
        if ( grep(/^$gps_signal$/, SUPPORTED_GPS_SIGNALS) ) {
          $ref_config_hash ->
            {SELECTED_SIGNALS}{&RINEX_GPS_ID} = $gps_signal;
          $ref_config_hash ->
            {CARRIER_FREQUENCY}{&RINEX_GPS_ID}{F1} = GPS_L1_FREQ;
          $ref_config_hash ->
            {CARRIER_FREQUENCY}{&RINEX_GPS_ID}{F2} =
              GetCarrierFrequency( &RINEX_GPS_ID, $gps_signal );
        } else {
          RaiseError(*STDOUT, ERR_SIGNAL_NOT_SUPPORTED,
          "GPS signal \'$gps_signal\' is not supported",
          "Supported GPS signals are: ".join(', ', SUPPORTED_GPS_SIGNALS));
          return KILLED;
        }
      }
    }
    if ( grep(/^${\RINEX_GAL_ID}$/, @{$ref_config_hash->{SELECTED_SAT_SYS}}) ) {
      if ( $config_content =~ /^GAL Signal Observation +: +(.+)$/im ) {
        my $gal_signal = $1;
        if ( grep(/^$gal_signal$/, SUPPORTED_GAL_SIGNALS) ) {
          $ref_config_hash ->
            {SELECTED_SIGNALS}{&RINEX_GAL_ID} = $gal_signal;
          $ref_config_hash ->
            {CARRIER_FREQUENCY}{&RINEX_GAL_ID}{F1} = GAL_E1_FREQ;
          $ref_config_hash ->
            {CARRIER_FREQUENCY}{&RINEX_GAL_ID}{F2} =
              GetCarrierFrequency( &RINEX_GPS_ID, $gal_signal );
        } else {
          RaiseError(*STDOUT, ERR_SIGNAL_NOT_SUPPORTED,
          "GALILEO signal \'$gal_signal\' is not supported",
          "Supported GALILEO signals are: ".join(', ', SUPPORTED_GAL_SIGNALS));
          return KILLED;
        }
      }
    }
    if ( grep(/^${\RINEX_GPS_ID}$/, @{$ref_config_hash->{SELECTED_SAT_SYS}}) ) {
      if ($config_content =~ /^GPS Mean Observation Error \[m\] +: +(.+)$/im) {
        my $gps_mean_obs_err = $1;
        if ( looks_like_number($gps_mean_obs_err) ) {
          $ref_config_hash->{OBS_MEAN_ERR}{&RINEX_GPS_ID} = $gps_mean_obs_err;
        } else {
          RaiseError(*STDOUT, ERR_OPTION_IS_NOT_NUMERIC,
            "GPS Mean Observation Error \'$gps_mean_obs_err\' is not a ".
            "numeric value!");
          return KILLED;
        }
      }
    }
    if ( grep(/^${\RINEX_GAL_ID}$/, @{$ref_config_hash->{SELECTED_SAT_SYS}}) ) {
      if ($config_content =~ /^GAL Mean Observation Error \[m\] +: +(.+)$/im) {
        my $gal_mean_obs_err = $1;
        if ( looks_like_number($gal_mean_obs_err) ) {
          $ref_config_hash->{OBS_MEAN_ERR}{&RINEX_GAL_ID} = $gal_mean_obs_err;
        } else {
          RaiseError(*STDOUT, ERR_OPTION_IS_NOT_NUMERIC,
            "GAL Mean Observation Error \'$gal_mean_obs_err\' is not a ".
            "numeric value!");
          return KILLED;
        }
      }
    }
    if ( $config_content =~ /^Satellite Mask \[degrees\] +: +(.+)$/im ) {
      my $sat_mask = $1;
      if ( looks_like_number($sat_mask) ) {
        $ref_config_hash->{SAT_MASK} = deg2rad($sat_mask); # saved in radians...
      } else {
        RaiseError(*STDOUT, ERR_OPTION_IS_NOT_NUMERIC,
          "Satellite Mask \'$sat_mask\' is not a numeric value!");
        return KILLED;
      }
    }
    # GPS satellites to discard:
    if ( grep(/^${\RINEX_GPS_ID}$/, @{$ref_config_hash->{SELECTED_SAT_SYS}}) ) {
      if ($config_content =~ /^GPS Satellites to Discard +: +(.+)$/im) {
        my @sat_to_discard;
        for my $sat (split(/[\s,;]+/, $1)) {
          if (substr($sat, 0, 1) eq &RINEX_GPS_ID) {
            push(@sat_to_discard, $sat);
          } else {
            RaiseWarning(*STDOUT, WARN_NOT_SUPPORTED_SAT_SYS,
              "GPS Satellite to discard '$sat', does not belong to GPS ".
              "constellation.", "Satellite will not be included in the list.");
          }
        }
        $ref_config_hash->{SAT_TO_DISCARD}{&RINEX_GPS_ID} = \@sat_to_discard;
      }
    }
    # GALILEO satellites to discard:
    if ( grep(/^${\RINEX_GAL_ID}$/, @{$ref_config_hash->{SELECTED_SAT_SYS}}) ) {
      if ($config_content =~ /^GAL Satellites to Discard +: +(.+)$/im) {
        my @sat_to_discard;
        for my $sat (split(/[\s,;]+/, $1)) {
          if (substr($sat, 0, 1) eq &RINEX_GAL_ID) {
            push(@sat_to_discard, $sat);
          } else {
            RaiseWarning(*STDOUT, WARN_NOT_SUPPORTED_SAT_SYS,
              "GAL Satellite to discard '$sat', does not belong to GALILEO ".
              "constellation.", "Satellite will not be included in the list.");
          }
        }
        $ref_config_hash->{SAT_TO_DISCARD}{&RINEX_GAL_ID} = \@sat_to_discard;
      }
    }

    # Satellite Navigation sub-section:
    if ( $config_content =~ /^Ephemerid Time Threshold \[h\] +: +(.+)$/im ) {
      my $eph_time_threshold = $1;
      if ( looks_like_number($eph_time_threshold) ) {
        $ref_config_hash ->
          {EPH_TIME_THRESHOLD} = $eph_time_threshold * SECONDS_IN_HOUR;
      } else {
        RaiseError(*STDOUT, ERR_OPTION_IS_NOT_NUMERIC,
          "Ephemerid time threshold \'$eph_time_threshold\' ".
          "is not a numeric value!");
        return KILLED;
      }
    }

    # Atmosphere model sub-section:
    if ( grep(/^${\RINEX_GPS_ID}$/, @{$ref_config_hash->{SELECTED_SAT_SYS}}) ) {
      if ($config_content =~ /^Ionosphere Model GPS +: +(.+)$/im) {
        my $gps_iono_model = lc $1;
        if ( grep(/^$gps_iono_model$/i, SUPPORTED_IONO_MODELS) ) {
          $ref_config_hash->{IONOSPHERE_MODEL}{&RINEX_GPS_ID} = $gps_iono_model;
        } else {
          RaiseError(*STDOUT, ERR_MODEL_NOT_SUPPORTED,
            "GPS Ionospheric Model \'$gps_iono_model\' is not supported",
            "Supported models are: ".join(', ', SUPPORTED_IONO_MODELS));
          return KILLED;
        }
      }
    }
    if ( grep(/^${\RINEX_GAL_ID}$/, @{$ref_config_hash->{SELECTED_SAT_SYS}}) ) {
      if ($config_content =~ /^Ionosphere Model GAL +: +(.+)$/im) {
        my $gal_iono_model = lc $1;
        if ( grep(/^$gal_iono_model$/i, SUPPORTED_IONO_MODELS) ) {
          $ref_config_hash->{IONOSPHERE_MODEL}{&RINEX_GAL_ID} = $gal_iono_model;
        } else {
          RaiseError(*STDOUT, ERR_MODEL_NOT_SUPPORTED,
            "GALILEO Ionospheric Model \'$gal_iono_model\' is not supported",
            "Supported models are: ".join(', ', SUPPORTED_IONO_MODELS));
          return KILLED;
        }
      }
    }
    if ($config_content =~ /^Troposphere Model +: +(.+)$/im) {
      my $tropo_model = $1;
      if (grep(/^$tropo_model$/i, SUPPORTED_TROPO_MODELS)) {
        $ref_config_hash->{TROPOSPHERE_MODEL} = lc $tropo_model;
      } else {
        RaiseError(*STDOUT, ERR_MODEL_NOT_SUPPORTED,
          "Troposphere model \'$tropo_model\' is not supported",
          "Supported models are: ".join(', ', SUPPORTED_TROPO_MODELS));
        return KILLED;
      }
    }

    # Elipsoid:
    if ($config_content =~ /^Elipsoid Model +: +(.+)$/im) {
      my $elip = uc $1;
      if ( grep(/^$elip$/, SUPPORTED_ELIPSOIDS) ) {
        $ref_config_hash->{ELIPSOID} = $elip;
      } else {
        RaiseError(*STDOUT, ERR_ELIPSOID_NOT_SUPPORTED,
          "Elipsoid \'$elip\' is not supported",
          "Supported elipsoids are: ".join(', ', SUPPORTED_ELIPSOIDS));
        return KILLED;
      }
    }

    # Position convergenece sub-section:
    if ($config_content =~ /^LSQ Maximum Number Iterations +: +(.+)$/im) {
      my $max_num_iter = $1;
      if (looks_like_number($max_num_iter)) {
        $ref_config_hash->{LSQ_MAX_NUM_ITER} = $max_num_iter;
      } else {
        RaiseError(*STDOUT, ERR_OPTION_IS_NOT_NUMERIC,
          "Maximum-Number-Iterations parameter \'$max_num_iter\' ".
          "is not numeric type!");
        return KILLED;
      }
    }
    if ($config_content =~ /^LSQ Convergence Threshold +: +(.+)$/im) {
      my $convergence_threshold = $1;
      if ( looks_like_number($convergence_threshold) ) {
        $ref_config_hash->{CONVERGENCE_THRESHOLD} = $convergence_threshold;
      } else {
        RaiseError(*STDOUT, ERR_OPTION_IS_NOT_NUMERIC,
          "Convergece-Threhold parameter \'$convergence_threshold\' is not ".
          "numberic type!");
        return KILLED;
      }
    }

  # Accuracy configuration section:
    # Vertical sigma scale factor:
    if ($config_content =~ /^Vertical Sigma Scale Factor \(1D\) +: +(.+)$/im) {
      my $vertical_sigma_factor = $1;
      if (looks_like_number($vertical_sigma_factor)) {
        $ref_config_hash->
          {ACCURACY}{VERTICAL}{SIGMA_FACTOR} = $vertical_sigma_factor*1;
      } else {
        RaiseError(*STDOUT, ERR_OPTION_IS_NOT_NUMERIC,
          "Vertical Sigma Scale Factor parameter '$vertical_sigma_factor' ".
          "is not numeric type!");
        return KILLED;
      }
    }

    # Horizontal sigma scale factor:
    if ($config_content =~ /^Horizontal Sigma Scale Factor \(2D\) +: +(.+)$/im) {
      my $horizontal_sigma_factor = $1;
      if (looks_like_number($horizontal_sigma_factor)) {
        $ref_config_hash->
          {ACCURACY}{HORIZONTAL}{SIGMA_FACTOR} = $horizontal_sigma_factor*1;
      } else {
        RaiseError(*STDOUT, ERR_OPTION_IS_NOT_NUMERIC,
          "Horizontal Sigma Scale Factor parameter '$horizontal_sigma_factor' ".
          "is not numeric type!");
        return KILLED;
      }
    }

  # Static mode section:
    # Static mode activated?
    if ($config_content =~ /^Static Mode +: +(.+)$/im) {
      my $static_status = ReadBoolean($1);
      if (defined $static_status) {
        $ref_config_hash->{STATIC}{STATUS} = $static_status;
      } else {
        RaiseError(*STDOUT, ERR_OPTION_IS_NOT_BOOLEAN,
          "Unrecognized option for 'Static Mode' parameter",
          "Please, indicate one of the following: \'TRUE\' or \'FALSE\'");
        return KILLED;
      }
    }

    # Only if static mode has been activated:
    if ($ref_config_hash->{STATIC}{STATUS}) {

      # Reference mode:
      if ($config_content =~ /^Reference Mode +: +(.+)$/im) {
        my $reference_mode = lc $1;
        if (grep(/^$reference_mode$/, SUPPORTED_STATIC_MODES)) {
          $ref_config_hash->{STATIC}{REFERENCE_MODE} = $reference_mode;
        } else {
          RaiseError(*STDOUT, ERR_STATIC_MODE_NOT_SUPPORTED,
            "Static Mode \'$reference_mode\' is not supported",
            "Supported elipsoids are: ".join(', ', SUPPORTED_STATIC_MODES));
          return KILLED;
        }
      }

      # Reference selection switch statement:
      given ( $ref_config_hash->{STATIC}{REFERENCE_MODE} ) {

        when ($_ eq &IGS_STATIC_MODE) {
          # Read reference station:
          if ($config_content =~ /^IGS Reference Station +: +(.+)$/im) {
            my $selected_station = $1;
            $ref_config_hash->{STATIC}{IGS_STATION} = $selected_station;
            if (defined REF_IGS_REFERENCE_STATIONS->{$selected_station}) {
              $ref_config_hash->{STATIC}{REFERENCE} =
                REF_IGS_REFERENCE_STATIONS->{$selected_station}{ECEF};
            } else {
              RaiseError(*STDOUT, ERR_IGS_STATION_NOT_FOUND,
                "IGS station '$selected_station' could not be found.");
              return KILLED;
            }
          }
        } # end when (igs)

        when ($_ eq &MANUAL_STATIC_MODE) {
          # Read reference coordinates:
          if ($config_content =~ /^Reference ECEF X, Y, Z +: +(.+)$/im ) {
            my @ecef_xyz = split(/[\s,;]+/, $1);
            for my $coordinate (@ecef_xyz) {
              unless (looks_like_number($coordinate)) {
                RaiseError(*STDOUT, ERR_OPTION_IS_NOT_NUMERIC,
                  "Reference coordinate '$coordinate' is not numeric type".
                  "at 'Reference ECEF X, Y, Z' parameter");
                return KILLED;
              }
            }
            $ref_config_hash->{STATIC}{REFERENCE} = \@ecef_xyz;
          }
        } # end when (manual)

        when ($_ eq &MEAN_STATIC_MODE){
          # Reference will be computed when all positions
          # are available:
          $ref_config_hash->{STATIC}{REFERENCE} = undef;
        } # end when (mean)

      } # end given static_reference_mode

    } # end if static mode activated

  # Integrity mode section:
  # Static mode activated?
  if ($config_content =~ /^Integrity Mode +: +(.+)$/im) {
    my $integrity_status = ReadBoolean($1);
    if (defined $integrity_status) {
      $ref_config_hash->{INTEGRITY}{STATUS} = $integrity_status;
    } else {
      RaiseError(*STDOUT, ERR_OPTION_IS_NOT_BOOLEAN,
        "Unrecognized option for 'Integrity Mode' parameter",
        "Please, indicate one of the following: \'TRUE\' or \'FALSE\'");
      return KILLED;
    }
  }

  # Only if integrity mode activated:
  if ($ref_config_hash->{INTEGRITY}{STATUS}) {

    # Vertical alert limit:
    if ($config_content =~ /^Vertical Alert Limit +: +(.+)$/im) {
      my $vertical_alert = $1;
      if (looks_like_number($vertical_alert)) {
        $ref_config_hash->
          {INTEGRITY}{VERTICAL}{ALERT_LIMIT} = $vertical_alert*1;
      } else {
        RaiseError(*STDOUT, ERR_OPTION_IS_NOT_NUMERIC,
          "Vertical Alert Limit parameter '$vertical_alert' ".
          "is not numeric type!");
        return KILLED;
      }
    }

    # Horizontal alert limit:
    if ($config_content =~ /^Horizontal Alert Limit +: +(.+)$/im) {
      my $horizontal_alert = $1;
      if (looks_like_number($horizontal_alert)) {
        $ref_config_hash->
          {INTEGRITY}{HORIZONTAL}{ALERT_LIMIT} = $horizontal_alert*1;
      } else {
        RaiseError(*STDOUT, ERR_OPTION_IS_NOT_NUMERIC,
          "Horizontal Alert Limit parameter '$horizontal_alert' ".
          "is not numeric type!");
        return KILLED;
      }
    }

  }

  # Data Dumper configuration section:
    # File delimiter:
    if ($config_content =~ /^Delimiter +: +"(.+)"$/im) {
      my $delimiter = eval "qq#$1#"; # NOTE: be aware of eval usage
      $ref_config_hash->{DATA_DUMPER}{DELIMITER} = $delimiter;
    }

    # Epoch format:
    if ($config_content =~ /^Epoch Format +: +(.+)$/im) {
      my $epoch_format = lc $1;
      if (grep(/^$epoch_format$/, SUPPORTED_EPOCH_FORMATS)) {
        $ref_config_hash->{DATA_DUMPER}{EPOCH_FORMAT} = $epoch_format;
      } else {
        RaiseError(*STDOUT, ERR_OPTION_NOT_SUPPORTED,
          "Epoch format '$epoch_format' is note supported.".
          "Please, indicate one of the following: ".
          join(', ', SUPPORTED_EPOCH_FORMATS));
        return KILLED;
      }
    }

    # Angle format:
    if ($config_content =~ /^Angle Format +: +(.+)$/im) {
      my $angle_format = lc $1;
      if (grep(/^$angle_format$/, SUPPORTED_ANGLE_FORMATS)) {
        $ref_config_hash->{DATA_DUMPER}{ANGLE_FORMAT} = $angle_format;
      } else {
        RaiseError(*STDOUT, ERR_OPTION_NOT_SUPPORTED,
          "Anlge format '$angle_format' is not supported.".
          "Please indicate one of the following: ".
          join(', ', SUPPORTED_ANGLE_FORMATS));
        return KILLED;
      }
    }

    # Receiver sigma scale factor:
    if ($config_content =~ /^Sigma Scale Factor +: +(.+)$/im) {
      my $sigma_factor = $1;
      if (looks_like_number($sigma_factor)) {
        $ref_config_hash->{DATA_DUMPER}{SIGMA_FACTOR} = $sigma_factor;
      } else {
        RaiseError(*STDOUT, ERR_OPTION_IS_NOT_NUMERIC,
          "Sigma scale factor '$sigma_factor' is not numeric type!");
        return KILLED;
      }
    }

  return $ref_config_hash;
}

sub CheckConfigurationFile {
  my ($cfg_file_path) = @_;

  # Check if configuration file:
  # a. Exists
    unless ( -e $cfg_file_path ) {
      RaiseError( *STDOUT,
                  ERR_NOT_VALID_CONF_FILE,
                  "Configuration file does not exists",
                  "Provided file: '$cfg_file_path'" );
      return FALSE;
    }
  # b. Is a plain text file
    unless (-f $cfg_file_path) {
      RaiseError( *STDOUT,
                  ERR_NOT_VALID_CONF_FILE,
                  "Configuration file is not plain text",
                  "Provided file: '$cfg_file_path'" );
      return FALSE;
    }
  # c. Can be read by effective uid/gid
    unless (-r $cfg_file_path) {
      RaiseError( *STDOUT,
                  ERR_NOT_VALID_CONF_FILE,
                  "Configuration file could not be read by effective user: ".
                  $ENV{ USER },
                  "Provided file: '$cfg_file_path'" );
      return FALSE;
    }

  return TRUE;
}

# ---------------------------------------------------------------------------- #
# Private Subroutines:

sub GetCarrierFrequency {
  my ($sat_sys, $obs_code) = @_;

  # Init var to store selected carrier frequency:
  my $carrier_freq;

  # Decompose observation info:
  my ($obs_type, $obs_channel, $obs_track) = split(//, $obs_code);

  # Switch case for GPS and GALILEO obs:
  given ($sat_sys) {

    # ******************************* #
    # GPS carrier frequency selection #
    # ******************************* #
    when (&RINEX_GPS_ID) {
      given ($obs_channel) {
        when (1) { $carrier_freq = GPS_L1_FREQ; }
        when (2) { $carrier_freq = GPS_L2_FREQ; }
        when (5) { $carrier_freq = GPS_L5_FREQ; }
        default  { $carrier_freq = GPS_L1_FREQ; }
      } # end given $obs_channel
    } # end when RINEX_GPS_ID

    # *********************************** #
    # GALILEO carrier frequency selection #
    # *********************************** #
    when (&RINEX_GAL_ID) {
      given ($obs_channel) {
        when (1) { $carrier_freq = GAL_E1_FREQ;  }
        when (5) { $carrier_freq = GAL_E5a_FREQ; }
        when (7) { $carrier_freq = GAL_E5b_FREQ; }
        when (8) { $carrier_freq = GAL_E5_FREQ;  }
        default  { $carrier_freq = GAL_E1_FREQ;  }
      } # end given $obs_channel
    } # end when RINEX_GAL_ID

  } # end given $sat_sys

  # If no frequency from those above is selected,
  # the returned value will be undef:
  return $carrier_freq;
}

TRUE;
