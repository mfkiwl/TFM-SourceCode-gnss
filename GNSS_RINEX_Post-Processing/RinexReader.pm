#!/usr/bin/perl -w

# Package declaration:
package RinexReader;


# SCRIPT DESCRIPTION GOES HERE:

# Load bash enviroments:
# ---------------------------------------------------------------------------- #
use lib $ENV{ ENV_ROOT };
use Enviroments qq(:CONSTANTS);

# Import Modules:
# ---------------------------------------------------------------------------- #
use strict;      # enables strict syntax...

use feature      qq(say);               # same as print.$text.'\n'...
use Scalar::Util qq(looks_like_number); # scalar utility...
use Data::Dumper;                       # enables pretty print...

# Import configuration and common interface module:
use lib SRC_ROOT_PATH;
use GeneralConfiguration qq(:ALL);

# Import dedicated libraries:
use lib LIB_ROOT_PATH;
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
  our @EXPORT_CONST = qw( &OBSERVATION_RINEX
                          &NAVIGATION_RINEX
                          &NULL_OBSERVATION
                          &ION_GAL_V3
                          &ION_BETA_V2
                          &ION_BETA_V3
                          &ION_ALPHA_V2
                          &ION_ALPHA_V3
                          &HEALTHY_OBSERVATION_BLOCK
                          &OBS_MANDATORY_HEADER_PARAMETERS
                          &NAV_MANDATORY_HEADER_PARAMETERS
                          &OBS_OPTIONAL_HEADER_PARAMETERS
                          &NAV_OPTIONAL_HEADER_PARAMETERS );

  # Define subroutines to export:
  our @EXPORT_SUB   = qw( &ReadObservationRinexHeader
                          &ReadNavigationRinexHeader
                          &ReadObservationRinexV3
                          &ReadNavigationRinex
                          &ReadPreciseOrbitIGS
                          &ReadPreciseClockIGS
                          &CheckRinexHeaderMandatory
                          &CheckRinexHeaderOptional );

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
# RINEX file types:
use constant {
  OBSERVATION_RINEX => 'O',
  NAVIGATION_RINEX  => 'N'
};

# Observation RINEX mandatory labels:
use constant {
  END_OF_HEADER      => 'END OF HEADER',
  RINEX_VERSION_TYPE => 'RINEX VERSION / TYPE',
  PGM_RUNBY_DATE     => 'PGM / RUN BY / DATE',
  MARKER_NAME        => 'MARKER NAME',
  MARKER_NUMBER      => 'MARKER NUMBER',
  OBSERVER_AGENCY    => 'OBSERVER / AGENCY',
  REC_TYPE_VERSION   => 'REC # / TYPE / VERS',
  ANT_TYPE           => 'ANT # / TYPE',
  APROX_POSITION_XYZ => 'APPROX POSITION XYZ',
  ANNTENA_DELTA_HNE  => 'ANTENNA: DELTA H/E/N',
  SYS_NUM_OBSTYPES   => 'SYS / # / OBS TYPES',
  TIME_OF_FIRST_OBS  => 'TIME OF FIRST OBS'
};

# Observation RINEX optional labels:
use constant {
  INTERVAL         => 'INTERVAL',
  TIME_OF_LAST_OBS => 'TIME OF LAST OBS',
  SYS_SCALE_FACTOR => 'SYS / SCALE FACTOR',
  SYS_PHASE_SHIFTS => 'SYS / PHASE SHIFTS',
  LEAP_SECONDS     => 'LEAP SECONDS',
  NUM_SATELLITES   => '# OF STAELLITES',
  PRN_NUM_OBS      => 'PRN / # OF OBS'
};

# Navigation RINEX V2 optional labels:
use constant {
  ION_ALPHA_V2           => 'ION ALPHA',
  ION_BETA_V2            => 'ION BETA',
  DELTA_UTC_A0_A1_T_W_V2 => 'DELTA-UTC: A0,A1,T,W'
};

# Navigation RINEX V3 optional labels:
use constant {
  IONOSPHERIC_CORR_V3 => 'IONOSPHERIC CORR',
  TIME_SYSTEM_CORR_V3 => 'TIME SYSTEM CORR',
};

# Navigation RINEX 3 ionosphere coefficients keys:
use constant {
  ION_GAL_V3   => 'GAL',
  ION_BETA_V3  => 'GPSA',
  ION_ALPHA_V3 => 'GPSB',
};

# RINEX hash parameters constants:
use constant
  OBS_MANDATORY_HEADER_PARAMETERS => qw( VERSION
                                         TYPE
                                         MARKER_NAME
                                         APX_POSITION
                                         ANTENNA_HNE
                                         SYS_OBS_TYPES
                                         TIME_FIRST_OBS
                                         END_OF_HEADER );

use constant
  OBS_OPTIONAL_HEADER_PARAMETERS => qw( INTERVAL
                                        LEAP_SECONDS
                                        TIME_LAST_OBS
                                        NUM_OF_SV );

use constant
  NAV_MANDATORY_HEADER_PARAMETERS => qw( VERSION
                                         TYPE
                                         END_OF_HEADER );

use constant
  NAV_OPTIONAL_HEADER_PARAMETERS => qw( ION_ALPHA
                                        ION_BETA
                                        DELTA_UTC
                                        LEAP_SECONDS );

# Observation properties:
use constant {
  OBSERVATION_ID_LENGTH     =>   4,
  OBSERVATION_LENGTH        =>  16,
  RAW_OBSERVATION_LENGTH    =>  14,
  OBSERVATION_BLOCK_ID      => '>',
  NULL_OBSERVATION          => 'NULL',
  HEALTHY_OBSERVATION_BLOCK =>   0,
};

# Navigation properties:
use constant {
  LINES_IN_NAVIGATION_BLOCK        => 8,
  RINEX_NAV_V2_LINE_TEMPLATE       => 'x3A19A19A19A19',
  RINEX_NAV_V3_LINE_TEMPLATE       => 'x4A19A19A19A19',
  RINEX_NAV_V2_FIRST_LINE_TEMPLATE => 'A2x1A2x1A2x1A2x1A2x1A2A5A19A19A19',
  RINEX_NAV_V3_FIRST_LINE_TEMPLATE => 'A3x1A4x1A2x1A2x1A2x1A2x1A2A19A19A19',
};

# Keys for Delta UTC parameters of navigation header:
# TODO: Call constant properly (no UTC only)
use constant DELTA_UTC_KEYS => qw(A0 A1 T W);

# Navigation parameters per line:
# For GPS navigation rinex:
use constant NAV_GPS_PRM_LINE_1 => qw(SV_CLK_BIAS SV_CLK_DRIFT SV_CLK_RATE);
use constant NAV_GPS_PRM_LINE_2 => qw(IODE CRS DELTA_N MO);
use constant NAV_GPS_PRM_LINE_3 => qw(CUC ECCENTRICITY CUS SQRT_A);
use constant NAV_GPS_PRM_LINE_4 => qw(TOE CIC OMEGA_0 CIS);
use constant NAV_GPS_PRM_LINE_5 => qw(IO CRC OMEGA OMEGA_DOT);
use constant NAV_GPS_PRM_LINE_6 => qw(IDOT L2_CODE_CHANNEL GPS_WEEK L2_P_FLAG);
use constant NAV_GPS_PRM_LINE_7 => qw(SV_ACC SV_HEALTH TGD IODC);
use constant NAV_GPS_PRM_LINE_8 => qw(TRANS_TIME FIT_INTERVAL);
# For GAL navigation rinex:
use constant NAV_GAL_PRM_LINE_1 => qw(SV_CLK_BIAS SV_CLK_DRIFT SV_CLK_RATE);
use constant NAV_GAL_PRM_LINE_2 => qw(IODE CRS DELTA_N MO);
use constant NAV_GAL_PRM_LINE_3 => qw(CUC ECCENTRICITY CUS SQRT_A);
use constant NAV_GAL_PRM_LINE_4 => qw(TOE CIC OMEGA_0 CIS);
use constant NAV_GAL_PRM_LINE_5 => qw(IO CRC OMEGA OMEGA_DOT);
use constant NAV_GAL_PRM_LINE_6 => qw(IDOT DATA_SOURCE GAL_WEEK SPARE);
use constant NAV_GAL_PRM_LINE_7 => qw(SISA SV_HEALTH BGD_E5A_E1 BGD_E5B_E1);
use constant NAV_GAL_PRM_LINE_8 => qw(TRANS_TIME);

# Satellite system hash holding sub reference to read navigation block:
use constant REF_READ_EPH_BLOCK => {
  RINEX_GPS_ID => \&ReadGPSNavigationBlock,
  RINEX_GAL_ID => \&ReadGALNavigationBlock,
};

# Anciliary constants:
# RINEX properties:
use constant LINE_START             =>  0;
use constant RINEX_LABEL_PLACEMENT  => 60;
use constant MAX_OBS_IN_HEADER_LINE => 13;

# IGS precise orbits properties:
use constant {
  IGS_SP3_EOF => qq(EOF),
  IGS_SP3_EPOCH_RECORD_ID => qq(*),
  IGS_SP3_SAT_POSITION_RECORD => qq(P),
};

# ERROR and WARNING codes:
use constant {
  ERR_WRONG_RINEX_TYPE          => 30101,
  ERR_WRONG_RINEX_VERSION       => 30102,
  ERR_SELECTED_SIGNAL_NOT_FOUND => 30103,
  ERR_NO_EPOCHS_WERE_STORED     => 30104,
};
use constant {
  WARN_MISSING_MANDATORY_HEADER   => 90101,
  WARN_MISSING_OPTIONAL_HEADER    => 90102,
  WARN_NO_OBS_AFTER_END_OF_HEADER => 90103,
  WARN_NO_NAV_BLOCK_FOUND         => 90104,
  WARN_TIME_CONF_EXCEPTION        => 90105,
};


# ---------------------------------------------------------------------------- #
# Subroutines:
# ---------------------------------------------------------------------------- #

# Public Subroutines: #
# ............................................................................ #
sub ReadObservationRinexHeader {
  my ($file_path, $fh_log) = @_;

  # Init hash to store RINEX header parameters:
  my %rinex_header_hash;

  # In this hash, mandatory parameters are declared but not defined:
  for my $parameter ( OBS_MANDATORY_HEADER_PARAMETERS ) {
    $rinex_header_hash{$parameter} = undef;
  }

  # Open RINEX file:
  my $fh; open($fh, '<', $file_path) or die $!;

  # Init line buffer:
  my $line = '';

  # Retrieve header parameters until the end is reached:
  until ( index($line, END_OF_HEADER) == RINEX_LABEL_PLACEMENT )
  {
    # Read new line and remove any carrigae jumps:
    $line = <$fh>; chomp $line;

    # ********************* #
    # Mandatory parameters: #
    # ********************* #

    # Observation Rinex version:
    if (index($line, RINEX_VERSION_TYPE) == RINEX_LABEL_PLACEMENT) {
      my ($version, $type) = map {PurgeExtraSpaces($_)} unpack('A20A1', $line);
      # Check that Rinex file is observation type:
      unless ($type eq OBSERVATION_RINEX) {
        # Send error to log:
        RaiseError($fh_log, ERR_WRONG_RINEX_TYPE,
        ("Retrieved RINEX type: \'$type\' was not recognized at $file_path",
         "Observation type: \'".OBSERVATION_RINEX."\' was expected"));
        return KILLED;
      }
      # Fill Rinex header hash:
      $rinex_header_hash{ 'VERSION' } = $version;
      $rinex_header_hash{ 'TYPE'    } = $type;
    }

    # Station name:
    if (index($line, MARKER_NAME) == RINEX_LABEL_PLACEMENT) {
      $rinex_header_hash{MARKER_NAME} = unpack('A60', $line);
    }

    # Aproximate position of station:
    if (index($line, APROX_POSITION_XYZ) == RINEX_LABEL_PLACEMENT) {
      my @apx_pos = map{ $_*1 } unpack('A14A14A14', $line);
      $rinex_header_hash{APX_POSITION} = \@apx_pos;
    }

    # Anntena delta displacements:
    if (index($line, ANNTENA_DELTA_HNE) == RINEX_LABEL_PLACEMENT) {
      my @anntena_hne = map{ $_*1 } unpack('A14A14A14', $line);
      $rinex_header_hash{ANTENNA_HNE} = \@anntena_hne;
    }

    # Satellite system observations:
    if (index($line, SYS_NUM_OBSTYPES) == RINEX_LABEL_PLACEMENT)
    {
      # Unpack satellite system ID and number of observations:
      my ($sat_sys, $num_obs) = unpack('A1A5', $line);

      my @obs_index; # init array to store all observations IDs...

      # For each satellite system, loop over the number of observations:
      for (my $i = 0; $i < $num_obs; $i++)
      {
        # Maximum number of observations allowed in each Rinex line is 13. Thus,
        # any further observations are stored in the following line:
        if ($i >= MAX_OBS_IN_HEADER_LINE && $i % MAX_OBS_IN_HEADER_LINE == 0) {
          $line = <$fh>;
        }

        # The index from which the observation will be read. The maximum number
        # observations in each line are considered:
        # Magic number 6 is the number of characters until observations ID...
        my $index =
          6 + ($i - MAX_OBS_IN_HEADER_LINE*
                    int($i/MAX_OBS_IN_HEADER_LINE))*OBSERVATION_ID_LENGTH;

        push( @obs_index,
              PurgeExtraSpaces(substr($line, $index, OBSERVATION_ID_LENGTH)) );
      }

      # Temporal hash:
      my %tmp_hash = ( OBS     => \@obs_index,
                       NUM_OBS => $num_obs*1 );

      # Fill Rinex header hash with parameters:
      $rinex_header_hash{SYS_OBS_TYPES}{$sat_sys} = \%tmp_hash;

    } # end if SYS_NUM_OBSTYPES in $line

    # Time of first obsevation. The time is written in Gregorian date format and
    # saved in GPS time format:
    if (index($line, TIME_OF_FIRST_OBS) == RINEX_LABEL_PLACEMENT) {
      my @date = map{PurgeExtraSpaces($_)} unpack('A6A6A6A6A6A13', $line);
      $rinex_header_hash{TIME_FIRST_OBS} = Date2GPS(@date);
    }

    # Number of header lines:
    if (index($line, END_OF_HEADER) == RINEX_LABEL_PLACEMENT) {
      $rinex_header_hash{END_OF_HEADER} = $.;
    }

    # ******************** #
    # Optional parameters: #
    # ******************** #

    # Observation intervals:
    if (index($line, INTERVAL) == RINEX_LABEL_PLACEMENT) {
      my ($interval) = unpack('A10', $line);
      $rinex_header_hash{INTERVAL} = $interval*1;
    }

    # Time of last obsevation. The time is written in Gregorian date format and
    # saved in GPS time format:
    if (index($line, TIME_OF_LAST_OBS) == RINEX_LABEL_PLACEMENT) {
      my @date = map{PurgeExtraSpaces($_)} unpack('A6A6A6A6A6A13', $line);
      $rinex_header_hash{TIME_LAST_OBS} = Date2GPS(@date);
    }

    # Number of leap seconds:
    if (index($line, LEAP_SECONDS) == RINEX_LABEL_PLACEMENT) {
      my ($leap_sec, $future_past_ls, $week, $day) = unpack('A6A6A6A6', $line);
      $rinex_header_hash{LEAP_SECONDS} = $leap_sec*1;
    }

  } # end until END_OF_HEADER in $line


  # Close the Rinex file:
  close($fh);

  # Return hash reference with the retreived parameters:
  return \%rinex_header_hash;
}

sub ReadNavigationRinexHeader {
  my ($file_path, $fh_log) = @_;

  # Init Rinex navigation header hash:
  my %rinex_header_hash;

  # Mandatory parameters are initi as undef:
  for my $parameter ( NAV_MANDATORY_HEADER_PARAMETERS ) {
    $rinex_header_hash{$parameter} = undef;
  }

  # Open Navigation Rinex file:
  my $fh; open($fh, '<', $file_path) or die $!;

  # Init variables to read the file:
  my $line = '';

  # Read navigation header:
  until ( index($line, END_OF_HEADER) == RINEX_LABEL_PLACEMENT )
  {
    $line = <$fh>; chomp $line; # read new line and remove carriage jump...

    # ********************* #
    # Mandatory parameters: #
    # ********************* #

    # Rinex version and type:
    if (index($line, RINEX_VERSION_TYPE) == RINEX_LABEL_PLACEMENT) {
      my ($version, $type) = map {PurgeExtraSpaces($_)} unpack('A20A1', $line);
      # Check that Rinex is navigation type:
      unless ($type eq NAVIGATION_RINEX) {
        RaiseError($fh_log, ERR_WRONG_RINEX_TYPE,
        ("Retrieved RINEX type: \'$type\' was not recognized at $file_path",
         "Navigation type: \'".NAVIGATION_RINEX."\' was expected"));
        return KILLED;
      }
      # Fill rinex header hash:
      $rinex_header_hash{ VERSION } = $version;
      $rinex_header_hash{ TYPE    } = $type;
    }

    # Number of header lines:
    if (index($line, END_OF_HEADER) == RINEX_LABEL_PLACEMENT) {
      $rinex_header_hash{END_OF_HEADER} = $.;
    }

    # ******************** #
    # Optional parameters: #
    # ******************** #

    # Depending on RINEX version, optional parameters: ION_ALPHA, ION_BETA and
    # DELTA_UTC_A0_A1_T_W are changed:
    my $version = $rinex_header_hash{VERSION};
    if ( int($version) == 2 )
    {
      # Ion Alpha parameters:
      if (index($line, ION_ALPHA_V2) == RINEX_LABEL_PLACEMENT) {
        my ($empty, $ref_parameters)    = ReadIonParameters($line, $version);
        $rinex_header_hash{ION_ALPHA} = $ref_parameters;
      }

      # Ion Beta parameters:
      if (index($line, ION_BETA_V2) == RINEX_LABEL_PLACEMENT) {
        my ($empty, $ref_parameters)   = ReadIonParameters($line, $version);
        $rinex_header_hash{ION_BETA} = $ref_parameters;
      }

      # Delta UTC parameters:
      if (index($line, DELTA_UTC_A0_A1_T_W_V2) == RINEX_LABEL_PLACEMENT) {
        my ($empty, $ref_parameters)    = ReadTimeSystemCorr($line, $version);
        $rinex_header_hash{DELTA_UTC} = $ref_parameters;
      }
    } elsif ( int($version) == 3 )
    {
      # Ionospheric corrections:
      if (index($line, IONOSPHERIC_CORR_V3) == RINEX_LABEL_PLACEMENT) {
        my ($key, $ref_parameters) = ReadIonParameters($line, $version);
        $rinex_header_hash{$key}   = $ref_parameters;
      }

      # Time system corrections:
      if (index($line, TIME_SYSTEM_CORR_V3) == RINEX_LABEL_PLACEMENT) {
        my ($key, $ref_parameters) = ReadTimeSystemCorr($line, $version);
        $rinex_header_hash{$key}   = $ref_parameters;
      }

    } else
    {
      RaiseError($fh_log, ERR_WRONG_RINEX_VERSION,
      "RINEX file version \'$version\' was not recognized at $file_path");
      return KILLED;
    }

    # Leap seconds:
    if (index($line, LEAP_SECONDS) == RINEX_LABEL_PLACEMENT) {
      $rinex_header_hash{LEAP_SECONDS} = unpack('A6', $line)*1;
    }

  } # end until END_OF_HEADER in $line

  # Close Navigation Rinex file:
  close($fh);

  # Return reference to Rinex header hash:
  return \%rinex_header_hash;
}

sub ReadObservationRinexV3 {
  my ($ref_gen_conf, $fh_log)  = @_;

  # Check that reference to general configuration is a hash type:
  unless ( ref($ref_gen_conf) eq 'HASH' ) {
    RaiseError($fh_log, ERR_WRONG_HASH_REF,
      "Input argument reference: \'$ref_gen_conf\' is not HASH type!");
  }

  # Read and store header parameters:
  my $ref_rinex_header =
    ReadObservationRinexHeader($ref_gen_conf->{RINEX_OBS_PATH}, $fh_log);

  # Check Rinex version:
  unless ( int($ref_rinex_header->{VERSION}) == 3 ) {
    # Write ERROR to log and return negative signal:
    RaiseError($fh_log, ERR_WRONG_RINEX_VERSION,
      "RINEX file version: \'".$ref_rinex_header->{VERSION}."\'".
      " is not V3 at ".$ref_gen_conf->{RINEX_OBS_PATH});
    return KILLED;
  }

  # Check that selected signals from configuration are present in RINEX header
  for my $sat_sys (keys %{$ref_gen_conf->{SELECTED_SIGNALS}})
  {
    my $sel_signal    = $ref_gen_conf->{SELECTED_SIGNALS}{$sat_sys};
    my @avail_signals = @{$ref_rinex_header->{SYS_OBS_TYPES}{$sat_sys}{OBS}};

    # Raise error if the configured signal is not found:
    unless ( grep(/^$sel_signal$/, @avail_signals) ) {
      RaiseError($fh_log, ERR_SELECTED_SIGNAL_NOT_FOUND,
        "Signal \'$sel_signal\' for constellation \'$sat_sys\' could not be ".
        "found in RINEX header", "Please consider to change the $sat_sys ".
        "signal in configuration file for one of the following: ",
        "\t".join(', ', @avail_signals));
      return KILLED;
    }
  }

  # Check for time configuration against time intervals in rinex header:

  # Retrieve time parameters from user configuration:
  my ( $conf_ini_epoch,
       $conf_end_epoch,
       $conf_interval ) = ( $ref_gen_conf->{ INI_EPOCH },
                            $ref_gen_conf->{ END_EPOCH },
                            $ref_gen_conf->{ INTERVAL  } );

    # Time of first obs vs. Start time:
    my $rinex_time_first_obs = $ref_rinex_header->{TIME_FIRST_OBS};

    if ( $rinex_time_first_obs > $conf_ini_epoch ) {
      RaiseWarning($fh_log, WARN_TIME_CONF_EXCEPTION,
        "Configured intial epoch ($conf_ini_epoch) is older than the ".
        "first available observation.",
        "TIME_FIRST_OBS from RINEX header ($rinex_time_first_obs) ".
        "will be set.");
      $conf_ini_epoch = $rinex_time_first_obs;
    }

    # Time of last obs vs. End time:
    if (defined $ref_rinex_header->{TIME_LAST_OBS}) {
      my $rinex_time_last_obs = $ref_rinex_header->{TIME_LAST_OBS};
      if ( $rinex_time_last_obs < $conf_end_epoch ) {
        RaiseWarning($fh_log, WARN_TIME_CONF_EXCEPTION,
          "Configured end epoch ($conf_end_epoch) is greater than the ".
          "last available observation.",
          "TIME_LAST_OBS from RINEX header ($rinex_time_last_obs) will be set");
        $conf_end_epoch = $rinex_time_last_obs;
      }
    }

    # RINEX interval vs. configured interval:
    if (defined $ref_rinex_header->{INTERVAL}) {
      my $rinex_interval = $ref_rinex_header->{INTERVAL};
      if ( $rinex_interval > $conf_interval ) {
        RaiseWarning($fh_log, WARN_TIME_CONF_EXCEPTION,
          "Configured interval ($conf_interval) is lower than the ".
          "current observation interval.",
          "INTERVAL from RINEX header ($rinex_interval) will be set");
        $conf_interval = $rinex_interval;
      }
    }


  # Init array to store observations:
  my @rinex_obs_arr;

  # Open Rinex file:
  my $fh; open($fh, '<', $ref_gen_conf->{RINEX_OBS_PATH}) or die $!;

  # The header is skipped:
  SkipLines($fh, $ref_rinex_header->{END_OF_HEADER});

  # Read Rinex file:
  while (my $line = <$fh>)
  {
    # Identify if line is inidcating a new observation block:
    if (index($line, OBSERVATION_BLOCK_ID) == LINE_START)
    {
      # Init observation block hash:
      my $ref_obs_block;

      # Unpack the epoch and observation block elements:
      my ($obs_id, $yyyy, $mo, $dd, $hh, $mi, $ss, $epoch_status, $num_sat) =
        map {PurgeExtraSpaces($_)} unpack('A1A5A3A3A3A3A11A3A3', $line);

      # Compute epoch in GPS time scale:
      my $gps_epoch = Date2GPS( $yyyy, $mo, $dd, $hh, $mi, $ss );

      # Read epochs according to the time parameters from the general
      # configuration:
      if ( $gps_epoch >= $conf_ini_epoch &&
           $gps_epoch <= $conf_end_epoch &&
           $gps_epoch  % $conf_interval  == 0)
      {
        # Fill observation block hash:
        $ref_obs_block->{ EPOCH   } = $gps_epoch;
        $ref_obs_block->{ STATUS  } = $epoch_status;
        $ref_obs_block->{ NUM_SAT_INFO } = {};

        # Init observed satellite system counter:
        InitObservedSatSysCounter( $num_sat, $ref_obs_block->{NUM_SAT_INFO} );

        # Init hash counter for number of satellites with no-NULL observations:
        InitSatSysNoNullObsCounter( $ref_obs_block->{NUM_SAT_INFO},
                                    $ref_gen_conf->{SELECTED_SAT_SYS},
                                    $ref_rinex_header->{SYS_OBS_TYPES} );

        # Read the observations for each satellite:
        for (my $j = 0; $j < $num_sat; $j++)
        {
          # Read the observation line and remove any carriage jumps:
          $line = <$fh>; chomp $line;

          # Identify satellite and constellation:
          my $sat     = ConsistentSatID( unpack('A3', $line) );
          my $sat_sys = substr( $sat, 0, 1 );

          # Increment satellite system counter:
          CountObservedSatSysCounter( $sat_sys, $sat,
                                      $ref_obs_block->{NUM_SAT_INFO} );

          # Set flag for reading the selected constellations according to
          # configuration:
          my $selected_sat_sys_flag =
            ( grep(/^$sat_sys$/, @{$ref_gen_conf->{SELECTED_SAT_SYS}}) )
              ? TRUE : FALSE;

          # Set flag for discard the specified satellites accoring to
          # configuration:
          my $sat_to_discard_flag =
            ( grep(/^$sat$/, @{ $ref_gen_conf->{SAT_TO_DISCARD}{$sat_sys} }) )
              ? TRUE : FALSE;

          # Read satellites from configured constellations and not to be
          # discarded:
          if ( $selected_sat_sys_flag == TRUE &&
               $sat_to_discard_flag   == FALSE )
          {
            # Iterate over the number of observations of each constellation:
            my    $i;
            for ( $i = 0;
                  $i < $ref_rinex_header->{SYS_OBS_TYPES}{$sat_sys}{NUM_OBS};
                  $i += 1 )
            {
              # Observation ID:
              my $obs_id =
                 $ref_rinex_header->{SYS_OBS_TYPES}{$sat_sys}{OBS}[$i];

              # Retreive observation from Rinex file:
              # Magic number 3 is the length of the satellite ID at the begining
              # of each observation line...
              my $raw_obs;
              my $index = 3 + $i*OBSERVATION_LENGTH;

              # Certain satellites may not have some observations. If so, the
              # observation is flagged as NULL:
              eval {
                no warnings; # supress warnings when evaluating the statement...
                $raw_obs = substr($line, $index, RAW_OBSERVATION_LENGTH)*1;
              } or do {
                $raw_obs = NULL_OBSERVATION;
              };

              # Count no-null observation:
              unless( $raw_obs eq NULL_OBSERVATION ) {
                CountNoNullObservation( $sat_sys, $sat, $obs_id,
                                        $ref_obs_block->{NUM_SAT_INFO} );
              }

              # Fill observation block hash:
              $ref_obs_block->{SAT_OBS}{$sat}{$obs_id} = $raw_obs;
            } # end for $i ($num_obs)

          } # enf if $sat_sys in SUPPORTED_SAT_SYS
        } # end for $j ($num_sat)

        # Fill observation array:
        push(@rinex_obs_arr, $ref_obs_block);

      } else {
        # If the epoch is not stored, skip as many lines as observed
        # satellites in the epoch:
        SkipLines($fh, $num_sat);
      } # end if ($epoch >= $ref_gen_conf->{INI_EPOCH}...)

    } else {
      RaiseWarning($fh_log, WARN_NO_OBS_AFTER_END_OF_HEADER,
        "Observation Block was not found after END_OF_HEADER at ".
        $ref_gen_conf->{RINEX_OBS_PATH});
    } # end if (index($line, OBSERVATION_BLOCK_ID) ... )
  } # end while $line

  # Check if no epochs were read due to time configuration parameters:
  unless (scalar(@rinex_obs_arr)) {
    RaiseError($fh_log, ERR_NO_EPOCHS_WERE_STORED,
      "No epochs were stored since any of them has acomplished the time ".
      "parameter criteria", "Please, review time parameters in general ".
      "configuration", "Your time configuration for this execution was: ",
      "\tInit epoch = ".BuildDateString(GPS2Date($conf_ini_epoch)),
      "\tEnd  epoch = ".BuildDateString(GPS2Date($conf_end_epoch)),
      "\tInterval   = ".$conf_interval." seconds");
    return KILLED;
  }

  # Close Rinex file:
  close($fh);

  # Combine header and observation hashes:
  my %rinex_hash = ( HEAD => $ref_rinex_header,
                     BODY => \@rinex_obs_arr );

  return \%rinex_hash;
}

sub ReadNavigationRinex {
  my ($file_path, $sat_sys, $fh_log) = @_;

  # Init navigation body hash to fill:
  my %nav_body_hash; my $ref_nav_body = \%nav_body_hash;

  # Read navigation header:
  my $ref_nav_header = ReadNavigationRinexHeader($file_path, $fh_log);

  # Save Rinex version parameter:
  my $version = int($ref_nav_header->{VERSION});

  # Determine templates for navigation block based on the RINEX version:
  my ($check_nav_block_temp, $first_line_temp, $line_temp);
  if    ( $version == 3 )
  {
    $line_temp            = RINEX_NAV_V3_LINE_TEMPLATE;
    $first_line_temp      = RINEX_NAV_V3_FIRST_LINE_TEMPLATE;
    $check_nav_block_temp = 'x1A2';
  }
  elsif ( $version == 2 )
  {
    $line_temp            = RINEX_NAV_V2_LINE_TEMPLATE;
    $first_line_temp      = RINEX_NAV_V2_FIRST_LINE_TEMPLATE;
    $check_nav_block_temp = 'A2';
  }
  else {
    RaiseError($fh_log, ERR_WRONG_RINEX_VERSION,
    "RINEX file version \'$version\' was not recognized at $file_path");
    return KILLED;
  }

  # Open navigation file:
  my $fh; open($fh, '<', $file_path) or die $!;

  # Skip navigation header:
  SkipLines($fh, $ref_nav_header->{END_OF_HEADER});

  # Read navigation file:
  while ( eof($fh) != TRUE )
  {
    # Store the navigation block in a fixed 8 line buffer:
    my $buffer; $buffer .= <$fh> for (1..LINES_IN_NAVIGATION_BLOCK);

    # Check if the buffer is a navigation block:
    if ( looks_like_number(unpack($check_nav_block_temp, $buffer)) )
    {
      # Read navigation block:
      my ($epoch, $sat, $ref_nav_prm) =
        &{ REF_READ_EPH_BLOCK->{$sat_sys} }( $buffer,
                                             $first_line_temp, $line_temp );

      # Fill navigation body hash:
      $ref_nav_body->{$sat}{$epoch} = $ref_nav_prm;

    } else {
      # Raise warning to log:
      RaiseWarning($fh_log, WARN_NO_NAV_BLOCK_FOUND,
        ("Navigation block was not found after END_OF_HEADER or END_SAT_BLOCK".
         " at line $. of $file_path",
         "Satellite navigation data may not be stored!"));
      # Skip one line to look for the next satellite navigation block:
      my $line = <$fh>;
    }
  }

  # Close navigation file:
  close($fh);

  # Fill navigation hash with the header and body hashes:
  my %nav_hash = ( HEAD => $ref_nav_header,
                   BODY => $ref_nav_body );

  # Subroutine returns the reference to the navigation hash:
  return \%nav_hash;
}

# TODO:
sub ReadHeaderPreciseOrbitIGS {}

sub ReadPreciseOrbitIGS {
  my ($file_path, $fh_log) = @_;

  # Init hash to store IGS product information:
  my $ref_precise_orbit = {};

  # Read Precise Orbir header:
  $ref_precise_orbit->{HEAD} = ReadHeaderPreciseOrbitIGS($file_path, $fh_log);

  # Open file:
  my $fh; open($fh, '<', $file_path) or die "Could not open $!";

  # Init line and epoch variables:
  my ($line, $epoch) = ('', '');

  # Read file:
  until ( index($line, IGS_SP3_EOF) == LINE_START ) {

    # Read new line:
    $line = <$fh>;

    # Identify epoch header record:
    if ( index($line, IGS_SP3_EPOCH_RECORD_ID) == LINE_START ) {

      # Read epoch:
      $epoch = Date2GPS( unpack('x3A4x1A2x1A2x1A2x1A2x1A11', $line) );

    # Identify satellite position record:
    } elsif ( index($line, IGS_SP3_SAT_POSITION_RECORD) == LINE_START ) {

      # Read satellite position parameters:
      my ($sat,
          $sat_x,
          $sat_y,
          $sat_z,
          $sat_clk) = unpack('x1A3A14A14A14A14', $line);

      # Push info into hash:
      # NOTE: Last read epoch is used as key
      #       ECEF XYZ coordinates are given in km
      #       Clock bias is given in micro-seconds
      $ref_precise_orbit->{BODY}{$epoch}{$sat}{P} = [ $sat_x*1e3,
                                                      $sat_y*1e3,
                                                      $sat_z*1e3,
                                                      $sat_clk/1e6 ];

    }

  } # end until EOF

  # Close file:
  close($fh);

  # Return filled hash:
  return $ref_precise_orbit;
}

# TODO:
sub ReadHeaderPreciseClockIGS {}

# TODO:
sub ReadPreciseClockIGS {
  my ($file_path, $fh_log) = @_;

  # Init hash to store IGS product information:
  my $ref_precise_clock = {};


  return $ref_precise_clock;
}

# TODO: review this sub!
sub CheckRinexHeaderMandatory {
  my ($ref_rinex_header, $fh_log) = @_;

  # Init status:
  my $status = TRUE;

  # Check that all mandatory parameters are defined:
  for my $parameter ( keys %{$ref_rinex_header} ) {
    unless (defined $ref_rinex_header->{$parameter}) {
      # Raise warning into log file:
      $status = FALSE;
      RaiseWarning($fh_log, WARN_MISSING_MANDATORY_HEADER,
      "Mandatory parameter: \'$parameter\' in RINEX header was not defined");
    }
  }

  # Return the status of the check:
  return $status;
}

# TODO: review this sub!
sub CheckRinexHeaderOptional {
  my ($ref_rinex_header, $fh_log) = @_;

  # Determine parameters to check based on the Rinex type:
  my @parameters;
  if ($ref_rinex_header->{TYPE} eq OBSERVATION_RINEX) {
    @parameters = OBS_OPTIONAL_HEADER_PARAMETERS;
  } elsif ($ref_rinex_header->{TYPE} eq NAVIGATION_RINEX ) {
    @parameters = NAV_OPTIONAL_HEADER_PARAMETERS;
  }

  # Init status:
  my $status = TRUE;

  # Check that optional parameters exist:
  for my $parameter ( @parameters ) {
    unless (exists $ref_rinex_header->{$parameter}) {
      $status = FALSE;
      # Raise warning into log file:
      RaiseWarning($fh_log, WARN_MISSING_OPTIONAL_HEADER,
        "Optional parameter: \'$parameter\' in RINEX header was not read");
    }
  }

  # Return the status of the check:
  return $status;
}


# Private Subrutines: #
# ............................................................................ #
sub InitObservedSatSysCounter {
  my ($num_all_sat, $ref_num_sat_info) = @_;

  # ALL entry is updated with the observed satellites as specified in the
  # RINEX epoch record:
  $ref_num_sat_info->{ALL}{AVAIL_OBS}{SAT_IDS} = [];
  $ref_num_sat_info->{ALL}{AVAIL_OBS}{NUM_SAT} = $num_all_sat;

  # UNKNOWN entry is also initiallized for consistency reasons:
  $ref_num_sat_info->{UNKNOWN}{AVAIL_OBS}{NUM_SAT} = 0;
  $ref_num_sat_info->{UNKNOWN}{AVAIL_OBS}{SAT_IDS} = [];

  # Init to 0 all available constellations:
  for my $sat_sys ( SUPPORTED_SAT_SYS, ACCEPTED_SAT_SYS ) {
    $ref_num_sat_info->{$sat_sys}{AVAIL_OBS}{NUM_SAT} = 0;
    $ref_num_sat_info->{$sat_sys}{AVAIL_OBS}{SAT_IDS} = [];
  }

  return TRUE;
}

sub InitSatSysNoNullObsCounter {
  my ($ref_num_sat_info, $ref_selected_sat_sys, $ref_sat_sys_obs) = @_;

  # Init to 0 all counters and init an empty array to store the satellite IDs:
  for my $sat_sys (@{ $ref_selected_sat_sys }) {
    for my $sat_sys_obs (@{ $ref_sat_sys_obs->{$sat_sys}{OBS} }){

      # Init entries for each observation of each constellation:
      $ref_num_sat_info->{$sat_sys}{VALID_OBS}{$sat_sys_obs}{NUM_SAT} = 0;
      $ref_num_sat_info->{$sat_sys}{VALID_OBS}{$sat_sys_obs}{SAT_IDS} = [];

      # Init 'ALL' counter observation entry:
      $ref_num_sat_info->{ALL}{VALID_OBS}{$sat_sys_obs}{NUM_SAT} = 0;
      $ref_num_sat_info->{ALL}{VALID_OBS}{$sat_sys_obs}{SAT_IDS} = [];

    }
  }

  return TRUE;
}

sub ConsistentSatID {
  my ($sat) = @_;

  # Consistency check (YEBE SAT ID RINEX issue):
  if (index(' ', $sat) == -1) {
    $sat =~ s/ /0/g;
  }

  return $sat;
}

sub CountObservedSatSysCounter {
  my ($sat_sys, $sat_id, $ref_num_sat_info) = @_;

  # Count satellite if included in ACCEPTED_SAT_SYS.
  # Otherwise, increment satellite in UNKNOWN entry:
  if ( grep(/^$sat_sys$/, ACCEPTED_SAT_SYS)  ) {
    $ref_num_sat_info->{$sat_sys}{AVAIL_OBS}{NUM_SAT} += 1;
    PushUnique( $ref_num_sat_info->{ $sat_sys }{AVAIL_OBS}{SAT_IDS}, $sat_id );
    PushUnique( $ref_num_sat_info->{ ALL      }{AVAIL_OBS}{SAT_IDS}, $sat_id );
  } else {
    $ref_num_sat_info->{UNKNOWN}{AVAIL_OBS}{NUM_SAT} += 1;
    PushUnique( $ref_num_sat_info->{UNKNOWN}{AVAIL_OBS}{SAT_IDS}, $sat_id );
  }

  return TRUE;
}

sub CountNoNullObservation {
  my ($sat_sys, $sat_id, $obs_id, $ref_num_sat_info) = @_;

  # Account for constellation, satellite and observation id:
  $ref_num_sat_info->{$sat_sys}{VALID_OBS}{$obs_id}{NUM_SAT} += 1;
  PushUnique( $ref_num_sat_info->
                {$sat_sys}{VALID_OBS}{$obs_id}{SAT_IDS}, $sat_id );

  # Account for 'ALL' hash entry:
  $ref_num_sat_info->{ALL}{VALID_OBS}{$obs_id}{NUM_SAT} += 1;
  PushUnique( $ref_num_sat_info->
                {ALL}{VALID_OBS}{$obs_id}{SAT_IDS}, $sat_id );

  return TRUE;
}

sub ReadIonParameters {
  my ($line, $version) = @_;

  # Determine line template based on RINEX version number:
  my $template;
  if    ( int($version) == 2 ) { $template = 'A2A12A12A12A12'; }
  elsif ( int($version) == 3 ) { $template = 'A5A12A12A12A12'; }
  else                         { return KILLED;                }

  # First two characters are empty, the following number are the inospheric
  # parameters:
  my ($key, @parameters) = unpack($template, $line);

  PurgeExtraSpaces($_) for ($key);        # clean white spaces from keys...
  $_ =~ s/D/e/         for (@parameters); # to scientific notation...
  $_ *= 1              for (@parameters); # to decimal notation...

  # The return argument is the reference to the array containing the
  # parameters:
  return ($key, \@parameters);
}

sub ReadTimeSystemCorr {
  my ($line, $version) = @_;

  # Determine line template based on RINEX version number:
  my $template;
  if    ( int($version) == 2 ) { $template = 'A3A19A19A9A9'; }
  elsif ( int($version) == 3 ) { $template = 'A5A17A16A7A5'; }
  else                         { return KILLED;              }

  # Unpack the parameters:
  my ($key, $a0, $a1, $t, $w) = unpack($template, $line);

  PurgeExtraSpaces($_) for ($key);             # clean white spaces from key...
  $_ =~ s/D/e/         for ($a0, $a1);         # to scientific notation...
  $_ *= 1              for ($a0, $a1, $t, $w); # to decimal notation....

  # Fill navigation header hash:
  my %tmp_hash; @tmp_hash{&DELTA_UTC_KEYS} = ($a0, $a1, $t, $w);

  return ($key, \%tmp_hash);
}

sub ReadGPSNavigationBlock {
  my ($buffer, $first_line_temp, $line_temp) = @_;

  # Before reading the navigation bock, is necessary to convert the numbers
  # into scientific notation:
  $buffer =~ s/D/e/g;

  # Read navigation block:
  my @line_buffer = split(/\n/, $buffer);

 # First navigation line:
  my ($sat, $yyyy, $mm, $dd, $hh, $mi, $ss, $clk_bias, $clk_drift, $clk_rate)
                                    = unpack($first_line_temp, $line_buffer[0]);
  # Rest of navigation lines:
  my ($iode, $crs, $delta_n, $mo)       = unpack($line_temp, $line_buffer[1]);
  my ($cuc, $ecc, $cus, $sqrt_a)        = unpack($line_temp, $line_buffer[2]);
  my ($toe, $cic, $omega_0, $cis)       = unpack($line_temp, $line_buffer[3]);
  my ($cio, $crc, $omega, $omega_dot)   = unpack($line_temp, $line_buffer[4]);
  my ($idot, $l2_chn, $gps_w, $l2_flag) = unpack($line_temp, $line_buffer[5]);
  my ($sv_acc, $sv_health, $tgd, $iodc) = unpack($line_temp, $line_buffer[6]);
  my ($trans_time, $fit_inter, @empty)  = unpack($line_temp, $line_buffer[7]);

  # Fill hash:
  my %nav_prm_hash;

  @nav_prm_hash{&NAV_GPS_PRM_LINE_1} = ($clk_bias, $clk_drift, $clk_rate);
  @nav_prm_hash{&NAV_GPS_PRM_LINE_2} = ($iode, $crs, $delta_n, $mo);
  @nav_prm_hash{&NAV_GPS_PRM_LINE_3} = ($cuc, $ecc, $cus, $sqrt_a);
  @nav_prm_hash{&NAV_GPS_PRM_LINE_4} = ($toe, $cic, $omega_0, $cis);
  @nav_prm_hash{&NAV_GPS_PRM_LINE_5} = ($cio, $crc, $omega, $omega_dot);
  @nav_prm_hash{&NAV_GPS_PRM_LINE_6} = ($idot, $l2_chn, $gps_w, $l2_flag);
  @nav_prm_hash{&NAV_GPS_PRM_LINE_7} = ($sv_acc, $sv_health, $tgd, $iodc);
  @nav_prm_hash{&NAV_GPS_PRM_LINE_8} = ($trans_time, $fit_inter);

  # Determine satellite PRN:
  if (looks_like_number($sat)) { $sat = sprintf("%s%02d", $sat_sys, $sat); }

  # Determine epoch in GPS time format:
  if (length($yyyy) == 2) { $yyyy += ($yyyy < 80) ? 2000 : 1900; }
  my $epoch = Date2GPS($yyyy, $mm, $dd, $hh, $mi, $ss );

  # Return epoch, satellite PRN and hash with retreived parameters:
  return ($epoch, $sat, \%nav_prm_hash);
}

sub ReadGALNavigationBlock {
  my ($buffer, $first_line_temp, $line_temp) = @_;

  # Before reading the navigation bock, is necessary to convert the numbers
  # into scientific notation:
  $buffer =~ s/D/e/g;

  # Read navigation block:
  my @line_buffer = split(/\n/, $buffer);

 # First navigation line:
  my ($sat, $yyyy, $mm, $dd, $hh, $mi, $ss, $clk_bias, $clk_drift, $clk_rate)
                                    = unpack($first_line_temp, $line_buffer[0]);
  # Rest of navigation lines:
  my ($iode, $crs, $delta_n, $mo)        = unpack($line_temp, $line_buffer[1]);
  my ($cuc, $ecc, $cus, $sqrt_a)         = unpack($line_temp, $line_buffer[2]);
  my ($toe, $cic, $omega_0, $cis)        = unpack($line_temp, $line_buffer[3]);
  my ($cio, $crc, $omega, $omega_dot)    = unpack($line_temp, $line_buffer[4]);
  my ($idot, $dat_src, $week, undef)     = unpack($line_temp, $line_buffer[5]);
  my ($sisa, $sv_health, $bdg_1, $bdg_2) = unpack($line_temp, $line_buffer[6]);
  my ($trans_time, $fit_inter, @empty)   = unpack($line_temp, $line_buffer[7]);

  # Decode data source information:
  my $ref_dat_src = DecodeGALDataSources($dat_src*1);

  # Fill hash:
  my %nav_prm_hash;

  @nav_prm_hash{&NAV_GAL_PRM_LINE_1} = ($clk_bias, $clk_drift, $clk_rate);
  @nav_prm_hash{&NAV_GAL_PRM_LINE_2} = ($iode, $crs, $delta_n, $mo);
  @nav_prm_hash{&NAV_GAL_PRM_LINE_3} = ($cuc, $ecc, $cus, $sqrt_a);
  @nav_prm_hash{&NAV_GAL_PRM_LINE_4} = ($toe, $cic, $omega_0, $cis);
  @nav_prm_hash{&NAV_GAL_PRM_LINE_5} = ($cio, $crc, $omega, $omega_dot);
  @nav_prm_hash{&NAV_GAL_PRM_LINE_6} = ($idot, $ref_dat_src, $week, undef);
  @nav_prm_hash{&NAV_GAL_PRM_LINE_7} = ($sisa, $sv_health, $bdg_1, $bdg_2);
  @nav_prm_hash{&NAV_GAL_PRM_LINE_8} = ($trans_time);

  # Determine satellite PRN if sat ID is not provided:
  if (looks_like_number($sat)) { $sat = sprintf("%s%02d", $sat_sys, $sat); }

  # Determine epoch in GPS time format:
  if (length($yyyy) == 2) { $yyyy += ($yyyy < 80) ? 2000 : 1900; }
  my $epoch = Date2GPS($yyyy, $mm, $dd, $hh, $mi, $ss );

  # Return epoch, satellite PRN and hash with retreived parameters:
  return ($epoch, $sat, \%nav_prm_hash);
}

sub DecodeGALDataSources {
  my ($int_data_source) = @_;

  # Init hash to store data source info:
  my $ref_data_source = {
    INT => $int_data_source,
    CORR_E5A_E1  => FALSE,
    CORR_E5B_E1  => FALSE,
    SOURCE_INAV_E1_B  => FALSE,
    SOURCE_FNAV_E5A_I => FALSE,
    SOURCE_INAV_E5B_I => FALSE,
  };

  # Data source integer to bit string transformation:
  # NOTE: bit string is reversed to be aligned with array index order
  my @bit_array = split('', (reverse(sprintf("%b", $int_data_source))) );

  # Update status for data source information according to the bit
  # index of each parameter:
  $ref_data_source->{ SOURCE_INAV_E1_B  } = TRUE if $bit_array[0];
  $ref_data_source->{ SOURCE_FNAV_E5A_I } = TRUE if $bit_array[1];
  $ref_data_source->{ SOURCE_INAV_E5B_I } = TRUE if $bit_array[2];
  # rest of bits are reserved ...
  $ref_data_source->{ CORR_E5A_E1       } = TRUE if $bit_array[8];
  $ref_data_source->{ CORR_E5B_E1       } = TRUE if $bit_array[9];

  return $ref_data_source;
}

TRUE;
