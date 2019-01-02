#!/usr/bin/perl -w

# Package declaration:
package GeneralConfiguration;


# SCRIPT DESCRIPTION GOES HERE:

# Import Modules:
# ---------------------------------------------------------------------------- #
use strict; # enables strict syntax...

use feature qq(say);    # same as print.$text.'\n'...
use feature qq(switch); # load perl switch method...

use Math::Trig;   # loads trigonometry methods...
use Data::Dumper; # enables pretty print...
use Scalar::Util qq(looks_like_number); # scalar utility...

# Import dedicated libraries:
use lib qq(/home/ppinto/TFM/src/lib/); # TODO: this should be an enviroment!

use MyUtil   qq(:ALL); # useful subs and constants...
use MyPrint  qq(:ALL); # error and warning utilities...
use TimeGNSS qq(:ALL); # GNSS time transforming utilities...

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
  our @EXPORT_CONST = qw( &RINEX_GPS_ID
                          &RINEX_GAL_ID
                          &GPS_L1_FREQ
                          &GPS_L2_FREQ
                          &GPS_L5_FREQ
                          &GAL_E1_FREQ
                          &GAL_E5_FREQ
                          &GAL_E5a_FREQ
                          &GAL_E5b_FREQ
                          &SUPPORTED_SAT_SYS
                          &ACCEPTED_SAT_SYS
                          &WARN_NOT_SUPPORTED_SAT_SYS );

  # Define subroutines to export:
  our @EXPORT_SUB   = qw( &LoadConfiguration );

  # Merge constants and subroutines:
  our @EXPORT_OK = (@EXPORT_CONST, @EXPORT_SUB);

  # Define export tags:
  our %EXPORT_TAGS = ( ALL         => \@EXPORT_OK,
                       DEFAULT     => \@EXPORT,
                       CONSTANTS   => \@EXPORT_CONST,
                       SUBROUTINES => \@EXPORT_SUB );
}


# ---------------------------------------------------------------------------- #
# Constants
# ---------------------------------------------------------------------------- #
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

# Satellite system signal frequencies:
# GPS signal frequencies:
use constant {
  GPS_CA_FREQ =>    1.023e6, # [Hz]
  GPS_P_FREQ  =>   10.230e6, # [Hz]
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
use constant ACCEPTED_SAT_SYS  => qw(R C S J I);

# Supported satellite signals:
# GPS pseudorange signals:
use constant SUPPORTED_GPS_SIGNALS => qw( C1C C1S C1L C1X C1P
                                          C2C C2D C2S C2L C2X C2P C2W
                                          C5I C5Q C5X );
# GALILEO pseudorange signals:
use constant SUPPORTED_GAL_SIGNALS => qw( C1C C1A C1B
                                          C5I C5Q C5X
                                          C7I C7Q C7X
                                          C8I C8Q C8X );

# Supported time formats:
use constant SUPPORTED_TIME_FORMATS => qw( GPS GPS_WEEK DATE );

# Supported atmospheric correction models:
use constant SUPPORTED_IONO_MODELS  => qw(Klobuchar NeQuick);
use constant SUPPORTED_TROPO_MODELS => qw(Saastamoinen);

# Supported elipsoids:
use constant SUPPORTED_ELIPSOIDS => qw(WGS84 GRS80 HAYFORD);

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
};
# Warnings:
use constant {
  WARN_NOT_SUPPORTED_SAT_SYS => 90401,
};


# ---------------------------------------------------------------------------- #
# Subroutines:
# ---------------------------------------------------------------------------- #

# Public Subroutines: #
# ............................................................................ #
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

  # print $config_content; # testing...

  # ****************************** #
  # Read configuration parameters: #
  # ****************************** #

  # General section:
    # Verbosity:
    if ( $config_content =~ /^verbosity +: +(.+)$/gim ) {
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

    # Satellite systems to process:
    if ( $config_content =~ /^Satellite Systems +: +(.+)$/gim ) {
      my @sel_sat_sys;
      for my $sat_sys (split(/[\s,;]+/, $1)) {
        unless (grep(/^$sat_sys$/, SUPPORTED_SAT_SYS)) {
          RaiseWarning(*STDOUT, WARN_NOT_SUPPORTED_SAT_SYS,
            "Satellite system \'$sat_sys\' is not supported",
            "The observations from this constellation will be ignored!",
            "Supported constellations are: ".join(', ', SUPPORTED_SAT_SYS));
          @sel_sat_sys = grep {$_ ne $sat_sys} @sel_sat_sys;
        } else {
          push(@sel_sat_sys, $sat_sys);
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
    if ( $config_content =~ /^RINEX Observation path +: +(.+)$/gim ) {
      my $rinex_obs_path = $1;
      if (-r $rinex_obs_path) {
        $ref_config_hash->{RINEX_OBS_PATH} = $rinex_obs_path;
      } else {
        RaiseError(*STDOUT, ERR_CANNOT_READ_FILE,
        "File \'$rinex_obs_path\' either cannot be read or does not exist");
        return KILLED;
      }
    }
    if ( grep(/^${\RINEX_GPS_ID}$/, @{$ref_config_hash->{SELECTED_SAT_SYS}}) ) {
      if ( $config_content =~ /^RINEX Navigation GPS path +: +(.+)$/gim ) {
        my $rinex_g_nav_path = $1;
        if (-r $rinex_g_nav_path) {
          $ref_config_hash->{RINEX_NAV_PATH}{&RINEX_GPS_ID} = $rinex_g_nav_path;
        } else {
          RaiseError(*STDOUT, ERR_CANNOT_READ_FILE,
          "File \'$rinex_g_nav_path\' either cannot be read or does not exist");
          return KILLED;
        }
      }
    }
    if ( grep(/^${\RINEX_GAL_ID}$/, @{$ref_config_hash->{SELECTED_SAT_SYS}}) ) {
      if ( $config_content =~ /^RINEX Navigation GAL path +: +(.+)$/gim ) {
        my $rinex_e_nav_path = $1;
        if (-r $rinex_e_nav_path) {
          $ref_config_hash->{RINEX_NAV_PATH}{&RINEX_GAL_ID} = $rinex_e_nav_path;
        } else {
          RaiseError(*STDOUT, ERR_CANNOT_READ_FILE,
          "File \'$rinex_e_nav_path\' either cannot be read or does not exist");
          return KILLED;
        }
      }
    }


    # Output sub-section:
    if ( $config_content =~ /^Output path +: +(.+)$/gim ) {
      my $output_path = $1;
      if (-w $output_path) {
        $ref_config_hash->{OUTPUT_PATH} = $output_path;
      } else {
        RaiseError(*STDOUT, ERR_CANNOT_WRITE_FILE,
          "Current user ".$ENV{USER}." does not have write permissions at ".
          "\'$output_path\' or the provided path does not exist.");
        return KILLED;
      }
    }
    if ( $config_content =~ /^Log File +: +(.+)$/gim ) {
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
    if ( $config_content =~ /^Ini Epoch \[GPS\] +: +(.+)$/gim ) {
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
    if ( $config_content =~ /^End Epoch \[GPS\] +: +(.+)$/gim ) {
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
    if ( $config_content =~ /^Interval \[seconds\] +: +(.+)$/gim ) {
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
    # TODO: set frequencies for signals!
    if ( grep(/^${\RINEX_GPS_ID}$/, @{$ref_config_hash->{SELECTED_SAT_SYS}}) ) {
      if ( $config_content =~ /^GPS Signal Observation +: +(.+)$/gim ) {
        my $gps_signal = $1;
        if ( grep(/^$gps_signal$/, SUPPORTED_GPS_SIGNALS) ) {
          $ref_config_hash->{SELECTED_SIGNALS}{&RINEX_GPS_ID} = $gps_signal;
        } else {
          RaiseError(*STDOUT, ERR_SIGNAL_NOT_SUPPORTED,
          "GPS signal \'$gps_signal\' is not supported",
          "Supported GPS signals are: ".join(', ', SUPPORTED_GPS_SIGNALS));
          return KILLED;
        }
      }
    }
    if ( grep(/^${\RINEX_GAL_ID}$/, @{$ref_config_hash->{SELECTED_SAT_SYS}}) ) {
      if ( $config_content =~ /^GAL Signal Observation +: +(.+)$/gim ) {
        my $gal_signal = $1;
        if ( grep(/^$gal_signal$/, SUPPORTED_GAL_SIGNALS) ) {
          $ref_config_hash->{SELECTED_SIGNALS}{&RINEX_GAL_ID} = $gal_signal;
        } else {
          RaiseError(*STDOUT, ERR_SIGNAL_NOT_SUPPORTED,
          "GALILEO signal \'$gal_signal\' is not supported",
          "Supported GALILEO signals are: ".join(', ', SUPPORTED_GAL_SIGNALS));
          return KILLED;
        }
      }
    }
    if ( $config_content =~ /^Satellite Mask \[degrees\] +: +(.+)$/gim ) {
      my $sat_mask = $1;
      if ( looks_like_number($sat_mask) ) {
        $ref_config_hash->{SAT_MASK} = deg2rad($sat_mask); # saved in radians...
      } else {
        RaiseError(*STDOUT, ERR_OPTION_IS_NOT_NUMERIC,
          "Satellite Mask \'$sat_mask\' is not a numeric value!");
        return KILLED;
      }
    }

    # Satellite Navigation sub-section:
    if ( $config_content =~ /^Ephemerid Time Threshold \[h\] +: +(.+)$/gim ) {
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
      if ( $config_content =~ /^Ionosphere Model GPS +: +(.+)$/gim ) {
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
      if ( $config_content =~ /^Ionosphere Model GAL +: +(.+)$/gim ) {
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
    if ( $config_content =~ /^Troposphere Model +: +(.+)$/gim ) {
      my $tropo_model = $1;
      if ( grep(/^$tropo_model$/i, SUPPORTED_TROPO_MODELS) ) {
        $ref_config_hash->{TROPOSPHERE_MODEL} = lc $tropo_model;
      } else {
        RaiseError(*STDOUT, ERR_MODEL_NOT_SUPPORTED,
          "Troposphere model \'$tropo_model\' is not supported",
          "Supported models are: ".join(', ', SUPPORTED_TROPO_MODELS));
        return KILLED;
      }
    }

    # Elipsoid:
    if ( $config_content =~ /^Elipsoid Model +: +(.+)$/gim ) {
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
    if ( $config_content =~ /^LSQ Maximum Number Iterations +: +(.+)$/gim ) {
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
    if ( $config_content =~ /^LSQ Convergence Threshold +: +(.+)$/gim ) {
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

  # Plot diagrams section:
    # Satellite information sub-section:
    if ( $config_content =~ /^Satellite Observations +: +(.+)$/gim ) {
      my $plot_sat_obs = ReadBoolean($1);
      if (defined $plot_sat_obs) {
        $ref_config_hash->{PLOT}{SAT_OBSERVATIONS} = $plot_sat_obs;
      } else {
        RaiseError(*STDOUT, ERR_OPTION_IS_NOT_BOOLEAN,
          "Unrecognized option for Plot Satellite Observations parameter",
          "Please, indicate one of the following: \'TRUE\' or \'FALSE\'");
        return KILLED;
      }
    }
    if ( $config_content =~ /^Satellite Positions +: +(.+)$/gim ) {
      my $plot_sat_pos = ReadBoolean($1);
      if (defined $plot_sat_pos) {
        $ref_config_hash->{PLOT}{SAT_POSITIONS} = $plot_sat_pos;
      } else {
        RaiseError(*STDOUT, ERR_OPTION_IS_NOT_BOOLEAN,
          "Unrecognized option for Plot Satellite Positions parameter",
          "Please, indicate one of the following: \'TRUE\' or \'FALSE\'");
        return KILLED;
      }
    }
    if ( $config_content =~ /^Satellite Clocks +: +(.+)$/gim ) {
      my $plot_sat_clk = ReadBoolean($1);
      if (defined $plot_sat_clk) {
        $ref_config_hash->{PLOT}{SAT_CLOCK} = $plot_sat_clk;
      } else {
        RaiseError(*STDOUT, ERR_OPTION_IS_NOT_BOOLEAN,
          "Unrecognized option for Plot Satellite Clock parameter",
          "Please, indicate one of the following: \'TRUE\' or \'FALSE\'");
        return KILLED;
      }
    }

    # Signal error sub-section:
    if ( $config_content =~ /^Tropospheric Correction +: +(.+)$/gim ) {
      my $plot_tropo_corr = ReadBoolean($1);
      if (defined $plot_tropo_corr) {
        $ref_config_hash->{PLOT}{TROPOSPHERE_CORRECTION} = $plot_tropo_corr;
      } else {
        RaiseError(*STDOUT, ERR_OPTION_IS_NOT_BOOLEAN,
          "Unrecognized option for Plot Troposphere Correction parameter",
          "Please, indicate one of the following: \'TRUE\' or \'FALSE\'");
        return KILLED;
      }
    }
    if ( $config_content =~ /^Ionospheric Correction +: +(.+)$/gim ) {
      my $plot_iono_corr = ReadBoolean($1);
      if (defined $plot_iono_corr) {
        $ref_config_hash->{PLOT}{IONOSPHERE_CORRECTION} = $plot_iono_corr;
      } else {
        RaiseError(*STDOUT, ERR_OPTION_IS_NOT_BOOLEAN,
          "Unrecognized option for Plot Ionosphere Correction parameter",
          "Please, indicate one of the following: \'TRUE\' or \'FALSE\'");
        return KILLED;
      }
    }

    # Receiver position sub-section:
    if ( $config_content =~ /^Receiver Position EN +: +(.+)$/gim ) {
      my $plot_rec_pos_en = ReadBoolean($1);
      if (defined $plot_rec_pos_en) {
        $ref_config_hash->{PLOT}{REC_POSITION_EN} = $plot_rec_pos_en;
      } else {
        RaiseError(*STDOUT, ERR_OPTION_IS_NOT_BOOLEAN,
          "Unrecognized option for Plot Receiver Position EN parameter",
          "Please, indicate one of the following: \'TRUE\' or \'FALSE\'");
        return KILLED;
      }
    }
    if ( $config_content =~ /^Receiver Position U +: +(.+)$/gim ) {
      my $plot_rec_pos_u = ReadBoolean($1);
      if (defined $plot_rec_pos_u) {
        $ref_config_hash->{PLOT}{REC_POSITION_U} = $plot_rec_pos_u;
      } else {
        RaiseError(*STDOUT, ERR_OPTION_IS_NOT_BOOLEAN,
          "Unrecognized option for Plot Receiver Position U parameter",
          "Please, indicate one of the following: \'TRUE\' or \'FALSE\'");
        return KILLED;
      }
    }
    if ( $config_content =~ /^Receiver Residuals +: +(.+)$/gim ) {
      my $plot_rec_res = ReadBoolean($1);
      if (defined $plot_rec_res) {
        $ref_config_hash->{PLOT}{REC_RESIDUALS} = $plot_rec_res;
      } else {
        RaiseError(*STDOUT, ERR_OPTION_IS_NOT_BOOLEAN,
          "Unrecognized option for Plot Receiver Residuals parameter",
          "Please, indicate one of the following: \'TRUE\' or \'FALSE\'");
        return KILLED;
      }
    }

  # TODO: Data Dumper configuration:

  return $ref_config_hash;
}


TRUE;
