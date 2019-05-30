
# ---------------------------------------------------------------------------- #
# General configuration hash:                                                  #
# ---------------------------------------------------------------------------- #

%gen_conf_hash = (
  # Input/Output configuration:
  VERBOSITY        => $verbosity_configuration,
  SELECTED_SAT_SYS => \@selected_sat_sys,
  RINEX_OBS_PATH   => $path_to_obs_file,
  RINEX_NAV_PATH   => \%nav_rinex_paths,
  OUTPUT_PATH      => $path_to_output_directory,
  LOG_FILE_PATH    => $path_to_execution_log_file,

  # Time selection:
  INI_EPOCH => $start_processing_epoch,
  END_EPOCH => $end_processing_epoch,
  INTERVAL  => $processing_interval,

  # Observation configuration:
  SELECTED_SIGNALS  => \%selected_signals,
  OBS_MEAN_ERROR    => \%sat_sys_obs_mean_err,
  CARRIER_FREQUENCY => \%sat_sys_carrier_freq, # filled according to selected
                                               # observations
  SAT_MASK          => $satellite_mask,
  SAT_TO_DISCARD    => \%sat_sys_sat_discard,

  # Navigation selection:
  EPH_TIME_THRESHOLD => $ephemerids_selection_threshold,

  # Correction models:
  TROPOSPHERE_MODEL => $selected_trophosphere_model,
  IONOSPHERE_MODEL  => \%selected_iono_models,

  # Reference system:
  ELIPSOID => $selected_elipsoid,

  # LSQ configuration:
  LSQ_MAX_NUM_ITER      => $max_num_of_iterations,
  CONVERGENCE_THRESHOLD => $convergence_threshold,

  # Satic mode configuration:
  STATIC => \%static_mode,

  # Integrity parameters:
  INTEGRITY => \%integrity_mode,

  # Plot configuration:
  PLOT => \%plot_configuration, # TODO: leave this here?

  # Dumper configuration:
  DATA_DUMPER => \%data_dumper_conf,
);

# Constellation configurations:
@selected_sat_sys     = ( 'G',
                          'E' ); # supported satelite systems
%nav_rinex_paths      = (  G => $path_to_gps_nav_file,
                           E => $path_to_gal_nav_file );
%selected_signals     = (  G => $selected_gps_signal,
                           E => $selected_gal_signal );
%sat_sys_obs_mean_err = (  G => $obs_mean_error,
                           E => $obs_mean_error );
%sat_sys_carrier_freq = (  G => \%carrier_freq,
                           E => \%carrier_freq );
%sat_sys_sat_discard  = (  G => \@sats_to_discard,
                           E => \@sats_to_discard );
%selected_iono_models = (  G => $gps_iono_model,
                           E => $gal_iono_model );

# Carrier frequency selection hash:
%carrier_freq = ( F1 => $f1_carrier_frequency,
                  F2 => $f2_carrier_frequency );

# Static configuration:
%static_mode = ( STATUS => $boolean_status,
                 # Flollowing parameters are only filled if static mode status
                 # is TRUE:
                 REFERENCE_MODE => $reference_mode,
                 IGS_STATION => $igs_station_marker,
                 REFERENCE => \@reference_ecef_coordinates );

@reference_ecef_coordinates = ($x_ecef, $y_ecef, $z_ecef);

# Integrity configuration parameters:
%integrity_mode = (
  STATUS => $boolean_status,
  HORIZONTAL => \%integrity_parameter,
  VERTICAL   => \%integrity_parameter,
);

%integrity_parameter = (
  ALERT_LIMIT => $alert_bound,
  SIGMA_FACTOR => $gaussian_dist_critical_value,
);

# Plot configuration:
%plot_configuration = 'TBD'; # TODO!


# ---------------------------------------------------------------------------- #
# Data Daumper configuration:                                                  #
# ---------------------------------------------------------------------------- #
%data_dumper_conf = (
  DELIMITER      => $text_delimiter,
  EPOCH_FORMAT   => $epoch_format,
  ANGLE_FORMAT   => $angle_format,
  SIGMA_FACTOR   => $sigma_confidence_level_scale_factor,
  SAT_SYS_OBS_NAME      => $file_base_name, # TODO!
  REC_POSITION_NAME     => $file_base_name, # TODO!
  LSQ_REPORT_INFO_NAME  => $file_base_name, # TODO!
  SAT_SYS_POSITION_NAME => $file_base_name, # TODO!
  REC_SAT_LOS_DATA_NAME => $file_base_name, # TODO!
);



# ---------------------------------------------------------------------------- #
# GNSS RINEX Post-Processor:                                                   #
# ---------------------------------------------------------------------------- #

# Observation data:
# ............................................................................ #
%obs_data_hash = (

  HEAD => (
    # File info:
    TYPE          => $obs_rinex_type,
    VERSION       => $rinex_version,
    END_OF_HEADER => $number_of_header_lines,
    # Receiver info:
    MARKER_NAME  => $marker_name,
    ANTENNA_HNE  => \@anntena_hne,
    APX_POSITION => \@approximate_receiver_position,
    # Time information:
    INTERVAL       => $observation_interval,
    TIME_LAST_OBS  => $time_last_observation,
    TIME_FIRST_OBS => $time_first_obs,
    # Constellation observations:
    SYS_OBS_TYPES => \%sat_sys_obs_types,
    # Leap seconds info:
    LEAP_SECONDS => $num_leap_seconds
  ),

  BODY => ( \%obs_epoch, '[...]' ) # not fixed length

);


# Constellation observations types and information:
%sat_sys_obs_types = ( G => \%gps_obs_info );
%gps_obs_info      = ( NUM_OBS => $num_gps_obs, # length of @gps_signals
                       OBS     => \@gps_signals );
@gps_signals       = ( $signal_id, '[...]' ); # not fixed length

# Anntena delta displacements:
@anntena_hne = ( $height_delta, $northing_delta, $easting_delta );

# Receiver's approcimate position:
@approximate_receiver_position = ( $x_ecef, $y_ecef, $z_ecef);

# Observation epoch data:
%obs_epoch = (
  STATUS  => $obs_epoch_status,
  EPOCH   => $observation_epoch,
  NUM_SAT_INFO => \%num_sat_hash,
  SAT_OBS => \%sat_obs,
  SAT_LOS => \%line_of_sight_info, # filled after ComputeRecPosition
  LSQ_INFO => \@lsq_info,
  SAT_POSITION => \%sat_xyztc,
  REC_POSITION => \%position_parameters, # filled after ComputeRecPosition
  INTEGRITY_INFO => \%integrity_info,
);

# Satellite's raw measurements:
%sat_obs = ( $sat_id => \%signal_raw_measurements, '[...]' ); # not fixed length
%signal_raw_measurements = ( $signal_id => $signal_raw_measurement,
                             '[...]' ); # keys are @gps_signals items

# Satellite's number info hash:
%num_sat_hash = ( G   => \%sat_sys_num_sat,
                  E   => \%sat_sys_num_sat,
                  '[...]', # ACCEPTED_SAT_SYS
                  ALL     => \%sat_sys_num_sat,
                  UNKNOWN => \%sat_sys_num_sat  );

%sat_sys_num_sat = ( AVAIL_OBS => \%num_sat_info,
                     VALID_NAV => \%num_sat_info,
                     VALID_LSQ => \%num_sat_info,
                     VALID_OBS => \%num_sat_info_obs, );

%num_sat_info_obs = ( C1C => %num_sat_info,
                      C8Q => %num_sat_info, '[...]' );
                      # keys are the available observations for each
                      # constellation

%num_sat_info = ( NUM_SAT => $number_of_satellites,
                  SAT_IDS => \@satellite_id_list );

# Satellite's navigation parameters:
%sat_xyztc = ( $sat_id = ( # navigation coordinates at observation epoch
                           NAV => ( STATUS => $boolean_status,
                                    XYZ_TC => \@sat_position_parameters ),
                           # reception coordinates at observation epoch
                           RECEP => \@sat_position_parameters  ),
               '[...]' ); # not fixed length

@sat_position_parameters = ( $x_ecef, $y_ecef, $z_ecef, $sat_clk_bias );

# Satellite's line of sight data:
%line_of_sight_info = ( $sat_id => \%rec_sat_los_data,
                        '[...]' ); # not fixed length
%rec_sat_los_data = ( AZIMUT      => $rec_to_sat_azimut,
                      ZENITAL     => $rec_to_sat_zenital,
                      DISTANCE    => $rec_to_sat_distance,
                      ELEVATION   => $rec_to_sat_elevation,
                      IONO_CORR   => $ionosphere_los_delay,
                      TROPO_CORR  => $troposphere_los_delay,
                      ENU_VECTOR  => \@rec_to_sat_enu_vector,
                      ECEF_VECTOR => \@rec_to_sat_ecef_vector );

@rec_to_sat_enu_vector  = ( $e_enu, $n_enu, $u_enu );
@rec_to_sat_ecef_vector = ( $x_ecef, $y_ecef, $z_ecef );

# LSQ information:
@lsq_info = ( \%iteration_info, '[...]' ); # not fixed length

%iteration_info = ( STATUS => $boolean_status,
                    CONVERGENCE   => $boolean_status,
                    SAT_TO_LSQ    => \@sat_to_lsq_list,
                    NUM_PARAMETER      => $num_parameter,
                    NUM_OBSERVATION    => $num_obs,
                    DEGREES_OF_FREEDOM =>  $num_obs - $num_parameter,
                    APX_PARAMETER => \@rec_parameters,
                    PARAMETER_VECTOR => \@rec_delta_parameters,
                    RESIDUAL_VECTOR  => \@residuals,
                    SAT_RESIDUALS    => \%sat_residuals,
                    VARIANCE_ESTIMATOR => $variance_estimator )

@residuals            = ( $res_sat_obs, '[...]' );
@rec_parameters       = ( $x_ecef, $y_ecef, $z_ecef, $rec_clk_bias );
@rec_delta_parameters = ( $d_x_ecef, $d_y_ecef, $d_z_ecef, $d_rec_clk_bias );

%sat_residuals = ( $sat_id => $sat_residual,
                   '[...]' ); # hash keys must be all @sat_to_lsq_list

# Position solution parameters:
%position_parameters = ( STATUS => $position_estimation_status,
                         XYZ => \@ecef_position, # ECEF coordinates
                         CLK => $rec_clk_bias,   # Clock bias
                         VAR_XYZ => \@variance_ecef,   # ECEF variances
                         VAR_CLK => $rec_clk_variance, # Clock variance
                         VAR_ENU => \@variance_enu);   # ENU variance

@enu_position  = ($easting, $northing, $uping);
@ecef_position = ($x_ecef,  $y_ecef,  $z_ecef);
@variance_ecef = ($x_var, $y_var, $z_var);

# Integrity information per epoch:
%integrity_info = (
  HORIZONTAL => (
    ERROR      => $positioning_error,
    PRECISION  => $postioning_precision,
    MI_FLAG    => $misleading_info_flag,
    HMI_FLAG   => $hazardous_misleading_info_flag,
    AVAIL_FLAG => $availability_boolean,
  ),
  VERTICAL   => (
    ERROR      => $positioning_error,
    PRECISION  => $postioning_precision,
    MI_FLAG    => $misleading_info_flag,
    HMI_FLAG   => $hazardous_misleading_info_flag,
    AVAIL_FLAG => $availability_boolean,
  ),
);

# For horizontal component:
# ERROR = ((Erec - Eref)**2 + (Nrec - Nref)**2)**0.5
# PRECISION = HDOP * H_SIGMA_FACTOR;
# MI_FLAG  = ( ERROR > PRECISION && ERROR <= H_ALERT_LIMIT ) ? 1 : 0;
# HMI_FLAG = ( ERROR > PRECISION && ERROR  > H_ALERT_LIMIT ) ? 1 : 0;
# AVAIL_FLAG = ( PRECISION > H_ALERT_LIMIT ) ? 1 : 0;


# Navigation data:
# ............................................................................ #

# Satellite system navigation data:
%sat_sys_nav_data = ( G => \%nav_data_hash,
                      E => \%nav_data_hash );

# Navigation data:
%nav_data_hash = (

  # TODO: check for rinex v3 different configuration
  HEAD => (
    # File information:
    TYPE          => $nav_rinex_type,
    VERSION       => $rinex_version,
    END_OF_HEADER => $number_of_header_lines,
    # Ionosphere parameters:
    ION_ALPHA => \@iono_alpha_parameters,
    ION_BETA  => \@iono_beta_parameters,
    # Time syncro parameters:
    DELTA_UTC    => \%delta_utc_parameters,
    LEAP_SECONDS => $num_leap_seconds,
  ),

  BODY => ( $sat_id => \%sat_ephemerids, '[...]'  ), # not fixed length

);

# Ionosphere correction parameters:
@iono_alpha_parameters = ( 1.397e-08, 0, -5.96e-08, 5.96e-08 );
@iono_beta_parameters  = ( 110600, -32770, -262100, 196600 );

# UTC time syncrhronization parameters:
%delta_utc_parameters  = ( W => 1625,
                           T => 319488,
                           A1 => 0,
                           A0 => -9.31322574616e-10 );

# Ephemerids information:
%sat_ephemerids  = ( $epoch => (
                        $source => \%ephemerids_data, '[...]',
                        $source => \%ephemerids_data, '[...]',
                     ),
                     '[...]',
                    ); # not fixed length
%ephemerids_data = (
  # Satellite's cock parameters:
  SV_CLK_BIAS  => $sv_clock_bias,  # satellite's clock bias [s]
  SV_CLK_DRIFT => $sv_clock_drift, # satellite's clock drift [s/s]
  SV_CLK_RATE  => $sv_clock_rate,  # satellite's clock drift rate [s/s^2]

  # Issues of data:
  IODE => $iode, # issue of data (ephemerids) [N/A]
  IODC => $iodc, # issue of data (clock corrections) [N/A], only for GPS

  # Ephemerid's epochs:
  TOE => $toe,
    # time of ephemerids (usually same as transmission time) [gps week seconds]
  TRANS_TIME => $transmission_time,
    # ephemerids transmission time (usually same as TOE) [gps week seconds]
  GPS_WEEK => $gps_week
    # number of gps week [N/A], only for GPS
  GAL_WEEK => $gal_week,
    # number of gps week [N/A], only for GAL
  FIT_INTERVAL => $fit_interval,
    # ephemerid's curve fit interval (0 = 4h, 1 > 4h) [hours], only for GPS

  # Orbital parameters:
    ECCENTRICITY => $eccentricity, # orbit's eccentricity [N/A]

    # "Omega" parameters:
    OMEGA_0   => $omega_0,   # node's longitude at t0 [rad]
    OMEGA     => $omega,   # perigee's argument [rad]
    OMEGA_DOT => $omega_dot, # ascension's change rate [rad/s]

    # Anomaly parameters:
    MO      => $mo,      # mean anomaly at TOE [rad]
    DELTA_N => $delta_n, # mean movement difference [rad/s]

    # Orbit's radius corrections:
    CRS    => $crs,    # radius correction (sinus component) [m]
    CRC    => $crc,    # radius correction (cosine component) [m]
    SQRT_A => $sqrt_a, # orbit's semi-major axis square root [m^1/2]

    # Orbit's latitude corrections:
    CUS => $cus, # latitude correction (sinus component) [rad]
    CUC => $cuc, # latitude correction (cosine component) [rad]

    # Orbit's inclination corrections:
    IO   => $io,   # orbit's initial inclination [rad]
    CIS  => $cis,  # inclination correction (sinus component) [rad]
    CIC  => $cic,  # inclination correction (cosine component) [rad]
    IDOT => $idot, # orbit's inclination rate [rad/s]

  # Satellite and signal indicators:
  SV_HEALTH => $sv_health_status, # satellite's health status (0 = OK) [N/A]

  # For GPS:
  TGD             => $tgd,             # total group delay [s]
  SV_ACC          => $sv_accuaracy,    # satellite's ephemerids accuaracy [m]
  L2_P_FLAG       => $l2_p_flag,       # L2 P code flag (0 = OK) [N/A]
  L2_CODE_CHANNEL => $l2_code_channel, # number of codes in L2 channel [N/A]

  # For GALILEO:
  SISA => $sisa,              # Signal in space accuracy [m]
  BGD_E5A_E1  => $bdg_e5a_e1, # broadcast group delay for E5a,E1 [s]
  BGD_E5B_E1  => $bdg_e5b_e1, # broadcast group delay for E5a,E1 [s]

  # GAL data source info:
  DATA_SOURCE => {
    INT => $int_data_source, # integer coded data source info
    BIT => $bit_data_source, # decoded bit string from int data source info
    SERVICE => {
      C1 => $boolean_status, # = CORRECTION->E5B_E1
      C5 => $boolean_status, # = CORRECTION->EAB_E1
      C7 => $boolean_status, # = CORRECTION->E5B_E1
    },
    SOURCE => {
      INAV_E1_B  => $boolean_status,
      FNAV_E5A_I => $boolean_status,
      INAV_E5B_I => $boolean_status,
    }, # NOTE: Sum of SOURCE_INFO flags must be > 0 && < 3
    CORRECTION => {
      E5A_E1  => $boolean_status,
      E5B_E1  => $boolean_status,
    }, # NOTE: Sum of CORR_INFO flags must be 1
  },
);

# NeQuick Ionospheric model parameters:
# ............................................................................ #
my %nequick_model_parameters = (
  E_LAYER  => \%iono_layer_parameters,
  F1_LAYER => \%iono_layer_parameters,
  F2_LAYER => \%iono_layer_parameters,
  SHAPE_PARAMETER => $shape_parameter,
  TOPSIDE_THICKNESS => $topside_thick,
);

my %iono_layer_parameters = (
  #
  CRITICAL_FREQ => $critical_freq,
  #
  MAX_DENSITY        => $max_density,
  MAX_DENSITY_HEIGHT => $max_density_height,
  #
  TRANSMISSION_FACTOR => $trans_fact, # only for F2 layer
  #
  BOT_THICKNESS => $bot_thick,
  TOP_THICKNESS => $top_thick, # not for F2 layer
  #
  AMPLITUDE => $amplitude,
);
