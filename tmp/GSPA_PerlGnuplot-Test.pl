#!/usr/bin/perl -w

use Carp;
use strict;

use Storable;
use Data::Dumper;
use feature qq(say);
use feature qq(switch);

use PDL;
use PDL::NiceSlice;
use Chart::Gnuplot;
use Math::Trig qq(pi);

# Load enviroments:
use lib $ENV{ ENV_ROOT };
use Enviroments qq(:CONSTANTS);

# Load common modules:
use lib LIB_ROOT_PATH;
# Common tools:
use MyUtil   qq(:ALL); # useful subs and constants...
use MyPrint  qq(:ALL); # print and warning/failure utilities...
# GNSS dedicated tools:
use Geodetic qq(:ALL); # geodetic toolbox...
use TimeGNSS qq(:ALL); # GNSS time transforming utilities..

# ============================================================================ #
# Main Routine:                                                                #
# ============================================================================ #

# Preliminary:
#  - Identify script arguments:
#    $1 --> satellite system
#    $2 --> raw_data input path
#    $3 --> plots output path

if ( scalar(@ARGV) == 0 || scalar(@ARGV) > 3 ) {
  croak "Bad script argument provision";
}

my ( $sat_sys, $inp_path, $out_path ) = @ARGV;

$out_path = "." unless $out_path;

unless (-d $inp_path) { croak "Input path '$inp_path' is not a directory"; }
unless (-d $out_path) { croak "Output path '$out_path' is not a directory"; }

# Load hash references from input folder:
my $ref_gen_conf = retrieve("$inp_path/ref_gen_conf.hash");
my $ref_obs_data = retrieve("$inp_path/ref_obs_data.hash");

# ---------------------------------------------------------------------------- #
# 1. Satellite system plots:
# ---------------------------------------------------------------------------- #
# ************************************** #
#    1.a Constellation availability:     #
# ************************************** #
  # TODO:
  #   - Set transparent fills
  PlotConstellationAvailability($ref_gen_conf, $sat_sys, $inp_path, $out_path);

# ****************************** #
#    1.b Satellite elevation     #
# ****************************** #
  # TODO:
  #   - Avoid same colors for two sats
  #   - New style for mask dataset (dashed grey line with transparent fill)
  PlotSatelliteElevation($ref_gen_conf, $sat_sys, $inp_path, $out_path);

# ******************* #
#    1.c Sky plot:    #
# ******************* #
  # TODO:
  #   - Palette epoch values (hours intead of GPS epochs)
  #   - Offset in pallete
  #   - Label satellites
  #   - *change palette colors (more colors)
  #   - Move title top left
  PlotSatelliteSkyPath($ref_gen_conf, $sat_sys, $inp_path, $out_path);

# ---------------------------------------------------------------------------- #
# 2. Receiver Position plots:
# ---------------------------------------------------------------------------- #
# ******************************************************** #
#    2.a Easting/Northing point densisty plot:             #
#    TODO:
#       - Move title top left
#       - Offset in palette
#       - Change palette variable for U
#       - Set transparent fill for points
#    2.b Upping plot:                                      #
#    TODO:
#       - Change palette variables for STD DEV of each ENU component
#       - Add E and N
#       - Set multiplot (3x1)
#       - Add dashed line indicating reference station position
#    2.c Easting/Northing/Upping point density 3D plot:    #
#    TODO:
#       - Delete plot? --> NOT YET
#       - Move axis to 0,0,0
#       - Try to use pallete to color points (use PDOP value)
# ******************************************************** #
  PlotReceiverPosition($ref_gen_conf, $ref_obs_data, $inp_path, $out_path);

# ---------------------------------------------------------------------------- #
# 3. Ex-post Dilution of Precission:
# ---------------------------------------------------------------------------- #
# ************************ #
#    3.a ECEF frame DOP:   #
#    TODO:
#       - Include 2.5 overbound (set fill transparent)
#    3.b ENU frame DOP:    #
#    TODO:
#       - Include 2.5 overbound (set fill transparent)
# ************************ #
  PlotDilutionOfPrecission($ref_gen_conf, $inp_path, $out_path);

# ---------------------------------------------------------------------------- #
# 4. Least Squeares Estimation plots:
# ---------------------------------------------------------------------------- #
# *********************************************** #
#    4.a LSQ info (iter, convergence, ... )       #
#    4.b Apx parameter + Delta parameter          #
# *********************************************** #
  PlotLSQEpochEstimation($ref_gen_conf, $inp_path, $out_path);

# ********************************* #
#    4.d Residuals by satellite:    #
#    TODO:
#       - Move pelette to chart bottom
#       - Set Satellite IDs in Y axis
# ********************************* #
  PlotSatelliteResiduals($ref_gen_conf, $sat_sys, $inp_path, $out_path);

# **************************************************** #
#    4.e Elevation by satellite (same as 1.b plot):    #
# **************************************************** #


# ---------------------------------------------------------------------------- #
# 5. Ionosphere and Troposphere Delay Estimation plots:
# ---------------------------------------------------------------------------- #
# ************************************************* #
#    5.a Ionosphere Computed Delay by satellite:    #
#    TODO:
#       - Move pelette to chart bottom
#       - Set Satellite IDs in Y axis
# ************************************************* #
  PlotSatelliteIonosphereDelay($ref_gen_conf, $sat_sys, $inp_path, $out_path);

# ************************************************** #
#    5.b Troposphere Computed delay by satellite:    #
#    TODO:
#       - Move pelette to chart bottom
#       - Set Satellite IDs in Y axis
# ************************************************** #
  PlotSatelliteTroposphereDelay($ref_gen_conf, $sat_sys, $inp_path, $out_path);

# **************************************************** #
#    5.c Elevation by satellite (same as 1.b plot):    #
# **************************************************** #


# ============================================================================ #
# First level subroutines:                                                     #
# ============================================================================ #
sub PlotConstellationAvailability {
  my ($ref_gen_conf, $sat_sys, $inp_path, $out_path) = @_;

  # Select dumper file:
  my $ref_file_layout =
     GetFileLayout($inp_path."/$sat_sys-num-sat-info.out", 4,
                   $ref_gen_conf->{DATA_DUMPER}{DELIMITER});

  # Load file as a PDL piddle:
  my $pdl_num_sat_info = pdl( LoadFileByLayout($ref_file_layout) );

  # Retrieve in PDL piddles:
    # Observation epochs:
    my $pdl_epochs =
       $pdl_num_sat_info($ref_file_layout->{ITEMS}{Epoch}{INDEX});

    # Num available satellites:
    my $pdl_num_avail_sat =
       $pdl_num_sat_info($ref_file_layout->{ITEMS}{AvailSat}{INDEX});

    # Num valid observation satellites:
    my $pdl_num_valid_obs_sat =
       $pdl_num_sat_info($ref_file_layout->{ITEMS}{ValidObs}{INDEX});

    # Num valid navigation satellites:
    my $pdl_num_valid_nav_sat =
       $pdl_num_sat_info($ref_file_layout->{ITEMS}{ValidNav}{INDEX});

    # Num valid LSQ satellites:
    my $pdl_num_valid_lsq_sat =
       $pdl_num_sat_info($ref_file_layout->{ITEMS}{ValidLSQ}{INDEX});

  # Retrieve some statistics for chart configuration:
  my $ini_epoch   = min($pdl_epochs);
  my $end_epoch   = max($pdl_epochs);
  my $max_num_sat = max($pdl_num_avail_sat);

  # Create chart object:
  my $chart =
    Chart::Gnuplot->new (
                          output => $out_path."/$sat_sys-availability.png",
                          title  => "Satellite System '$sat_sys' Availability",
                          grid   => "on",
                          xlabel => "Observation Epochs",
                          ylabel => "Number of satellites",
                          xrange => [$ini_epoch, $end_epoch],
                          yrange => [5, $max_num_sat + 2],
                          timeaxis => "x",
                          xtics => { labelfmt => "%H:%M" },
                          timestamp =>  {
                                          fmt  => '%d/%m/%y %H:%M',
                                          font => "Helvetica :Italic",
                                        },
                        );

  # Configure datasets:
  my $num_avail_sat_dataset =
    Chart::Gnuplot::DataSet->new(
                                  xdata => unpdl($pdl_epochs->flat),
                                  ydata => unpdl($pdl_num_avail_sat->flat),
                                  style => "filledcurve y=0",
                                  timefmt => "%s",
                                  fill => { density => 0.3 },
                                  title => "Available"
                                );

  my $num_valid_obs_sat_dataset =
    Chart::Gnuplot::DataSet->new(
                                  xdata => unpdl($pdl_epochs->flat),
                                  ydata => unpdl($pdl_num_valid_obs_sat->flat),
                                  style => "filledcurve y=0",
                                  timefmt => "%s",
                                  fill => { density => 0.4 },
                                  title => "No-NULL Observation"
                                );

  my $num_valid_nav_sat_dataset =
    Chart::Gnuplot::DataSet->new(
                                  xdata => unpdl($pdl_epochs->flat),
                                  ydata => unpdl($pdl_num_valid_nav_sat->flat),
                                  style => "filledcurve y=0",
                                  timefmt => "%s",
                                  fill => { density => 0.5 },
                                  title => "Valid Navigation"
                                );

  my $num_valid_lsq_sat_dataset =
    Chart::Gnuplot::DataSet->new(
                                  xdata => unpdl($pdl_epochs->flat),
                                  ydata => unpdl($pdl_num_valid_lsq_sat->flat),
                                  style => "filledcurve y=0",
                                  timefmt => "%s",
                                  fill => { density => 0.6 },
                                  title => "Valid for LSQ routine"
                                );


  # Plot satellite number datasets:
  $chart->plot2d(
                  $num_avail_sat_dataset,
                  $num_valid_obs_sat_dataset,
                  $num_valid_nav_sat_dataset,
                  $num_valid_lsq_sat_dataset
                );

  return TRUE;
}

sub PlotSatelliteElevation {
  my ($ref_gen_conf, $sat_sys, $inp_path, $out_path) = @_;

  # Select dumper file:
  my $ref_file_layout =
     GetFileLayout($inp_path."/$sat_sys-sat-elevation.out", 5,
                   $ref_gen_conf->{DATA_DUMPER}{DELIMITER});

  # Load dumper file as a PDL piddle:
  my $pdl_sat_elevation = pdl( LoadFileByLayout($ref_file_layout) );

  # Observation of epochs:
  my $pdl_epochs =
     $pdl_sat_elevation($ref_file_layout->{ITEMS}{Epoch}{INDEX});

  # Retrieve fist and last epochs:
  my $ini_epoch = min($pdl_epochs);
  my $end_epoch = max($pdl_epochs);

  # Retrieve observed satellites from input file header:
  my @avail_sats =
    grep( /^$sat_sys\d{2}$/, (keys %{ $ref_file_layout->{ITEMS} }) );

  # Create plot object:
  my $chart =
    Chart::Gnuplot->new (
                          output => $out_path."/$sat_sys-elevation.png",
                          title  => "Satellite System '$sat_sys' Elevation",
                          xlabel => "Observation Epochs",
                          ylabel => "Elevation [deg]",
                          xrange => [$ini_epoch, $end_epoch],
                          yrange => [0, 90],
                          grid   => "on",
                          timeaxis => "x",
                          xtics => { labelfmt => "%H:%M" },
                          timestamp =>  {
                                          fmt  => '%d/%m/%y %H:%M',
                                          font => "Helvetica :Italic",
                                        },
                        );

  # Satellite mask dataset:
  my $pdl_sat_mask =
     $pdl_sat_elevation($ref_file_layout->{ITEMS}{SatMask}{INDEX});

  my $sat_mask_dataset =
    Chart::Gnuplot::DataSet->new(
                                  xdata => unpdl($pdl_epochs->flat),
                                  ydata => unpdl($pdl_sat_mask->flat),
                                  style => "lines",
                                  timefmt => "%s",
                                  title => "Mask",
                                  width => 5,
                                  linetype => 8
                                );

  # Init array to store elevation dataset objects:
  my @elevation_datasets;

  for my $sat (@avail_sats) {

    # Retrieve elevation values:
    my $pdl_elevation =
       $pdl_sat_elevation($ref_file_layout->{ITEMS}{$sat}{INDEX});

    # Set elevations dataset:
    my $dataset =
      Chart::Gnuplot::DataSet->new(
                                    xdata => unpdl($pdl_epochs->flat),
                                    ydata => unpdl($pdl_elevation->flat),
                                    style => "lines",
                                    timefmt => "%s",
                                    title => "$sat"
                                  );

    push(@elevation_datasets, $dataset);

  }

  # Plot elevation and mask datasets:
  $chart->plot2d((
                   @elevation_datasets,
                   $sat_mask_dataset
                 ));

  return TRUE;
}

sub PlotSatelliteSkyPath {
  my ($ref_gen_conf, $sat_sys, $inp_path, $out_path) = @_;

  # Select dumper files:
  my $ref_azimut_file_layout =
     GetFileLayout($inp_path."/$sat_sys-sat-azimut.out", 5,
                   $ref_gen_conf->{DATA_DUMPER}{DELIMITER});
  my $ref_elevation_file_layout =
     GetFileLayout($inp_path."/$sat_sys-sat-elevation.out", 5,
                   $ref_gen_conf->{DATA_DUMPER}{DELIMITER});

  my $pdl_sat_azimut    = pdl( LoadFileByLayout($ref_azimut_file_layout) );
  my $pdl_sat_elevation = pdl( LoadFileByLayout($ref_elevation_file_layout) );

  # Observation epochs:
  my $pdl_epochs =
     $pdl_sat_elevation($ref_azimut_file_layout->{ITEMS}{Epoch}{INDEX});

  my $ini_epoch = min($pdl_epochs);
  my $end_epoch = max($pdl_epochs);

  # Retrieve observed satellites from input file header:
  my @avail_sats =
    grep( /^$sat_sys\d{2}$/, (keys %{ $ref_azimut_file_layout->{ITEMS} }) );

  # Set chart object:
  my $chart =
    Chart::Gnuplot->new (
                          output => $out_path."/$sat_sys-sky-plot.png",
                          title  => "Satellite System '$sat_sys' Sky Plot",
                          border => undef,
                          xtics  => undef,
                          ytics  => undef,
                          timestamp =>  {
                                          fmt  => '%d/%m/%y %H:%M',
                                          font => "Helvetica :Italic",
                                        },
                        );

  # Set polar options:
  $chart->set(
                size   => "square",
                polar  => "",
                grid   => "polar",
                angle  => "degrees",
                theta  => "top clockwise",
                trange => "[0:360]",
                rrange => "[90:0]",
                rtics  => "30",
                ttics  => 'add ("N" 0, "E" 90, "S" 180, "W" 270) font ":Bold"',
                colorbox => "",
              );

  # Set mask datset:
  my $pdl_sat_mask =
     $pdl_sat_elevation($ref_elevation_file_layout->{ITEMS}{SatMask}{INDEX});

  # Build azimut and satellite mask polar ranges:
  my @azimut; push(@azimut, $_) for (0..360);
  my @mask;   push(@mask, sclr($pdl_sat_mask)) for (0..360);

  # Satellite mask polar dataset:
  my $sat_mask_dataset =
    Chart::Gnuplot::DataSet->new(
                                  xdata => \@azimut,
                                  ydata => \@mask,
                                  style => "lines",
                                  title => "Mask",
                                  width => 5,
                                  linetype => 8
                                );

  # Init array to hold satellite sky path datasets:
  my @sat_datasets;

  for my $sat (@avail_sats)
  {
    # Get satellite azmiut and elevation values:
    my $pdl_azimut =
      $pdl_sat_azimut($ref_azimut_file_layout->{ITEMS}{$sat}{INDEX});
    my $pdl_elevation =
       $pdl_sat_elevation($ref_elevation_file_layout->{ITEMS}{$sat}{INDEX});

    my $dataset =
      Chart::Gnuplot::DataSet->new(
                                    xdata => unpdl($pdl_azimut->flat),
                                    ydata => unpdl($pdl_elevation->flat),
                                    zdata => unpdl($pdl_epochs->flat),
                                    style => "lines linecolor pal z",
                                    # title => "$sat",
                                    width => 3
                                  );

    push(@sat_datasets, $dataset);
  }

  $chart->plot2d((
                    @sat_datasets,
                    $sat_mask_dataset
                ));

  return TRUE;
}

sub PlotReceiverPosition {
  my ($ref_gen_conf, $ref_obs_data, $inp_path, $out_path) = @_;

  # Select receiver position dumper file:
  my $marker_name = $ref_obs_data->{HEAD}{MARKER_NAME};
  my $ref_file_layout =
     GetFileLayout($inp_path."/$marker_name-xyz.out", 8,
                   $ref_gen_conf->{DATA_DUMPER}{DELIMITER});

  my $pdl_rec_xyz = pdl( LoadFileByLayout($ref_file_layout) );

  # Observation epochs:
  my $pdl_epochs = $pdl_rec_xyz($ref_file_layout->{ITEMS}{Epoch}{INDEX});

  # Get first and last observation epochs:
  my $ini_epoch = min($pdl_epochs);
  my $end_epoch = max($pdl_epochs);

  # Retrieve Easting and Northing values:
  my $pdl_rec_easting =
     $pdl_rec_xyz($ref_file_layout->{ITEMS}{REF_IE}{INDEX});
  my $pdl_rec_northing =
     $pdl_rec_xyz($ref_file_layout->{ITEMS}{REF_IN}{INDEX});
  my $pdl_rec_upping =
     $pdl_rec_xyz($ref_file_layout->{ITEMS}{REF_IU}{INDEX});

  # Retrieve standard deviations for ENU coordinates:
  my $pdl_std_easting =
     $pdl_rec_xyz($ref_file_layout->{ITEMS}{Sigma_E}{INDEX});
  my $pdl_std_northing =
     $pdl_rec_xyz($ref_file_layout->{ITEMS}{Sigma_N}{INDEX});
  my $pdl_std_upping =
     $pdl_rec_xyz($ref_file_layout->{ITEMS}{Sigma_U}{INDEX});

  # Retrieve receiver clock bias estimation and associated error:
  my $pdl_rec_clk_bias =
     $pdl_rec_xyz($ref_file_layout->{ITEMS}{ClkBias}{INDEX});
  my $pdl_std_clk_bias =
     $pdl_rec_xyz($ref_file_layout->{ITEMS}{Sigma_ClkBias}{INDEX});

  # Build polar coordinates from easting and northing components:
  my $pdl_rec_azimut = pi/2 - atan2($pdl_rec_northing, $pdl_rec_easting);
  my $pdl_rec_distance = ($pdl_rec_easting**2 + $pdl_rec_northing**2)**.5;

  # Create EN chart object:
  my $chart_en_polar =
    Chart::Gnuplot->new(
                          output => $out_path."/$marker_name-EN-plot.png",
                          title  => "Receiver '$marker_name' EN",
                          border => undef,
                          xtics  => undef,
                          ytics  => undef,
                          timestamp =>  {
                                          fmt  => '%d/%m/%y %H:%M',
                                          font => "Helvetica :Italic",
                                        },
                        );
  # Set chart polar properties:
    $chart_en_polar->set(
                        size   => "square",
                        polar  => "",
                        grid   => "polar",
                        angle  => "radians",
                        theta  => "top clockwise",
                        trange => "[0:2*pi]",
                        rtics  => "0.5",
                        ttics  => 'add ("N" 0, "E" 90, "S" 180, "W" 270) '.
                                  'font ":Bold"',
                        colorbox => "",
                      );
  # Set point style properties:
    $chart_en_polar->set(
                        style => "fill transparent solid 0.04 noborder",
                        style => "circle radius 0.04",
                      );

  # Create parent object for ENU multiplot:
  my $chart_enu =
    Chart::Gnuplot->new(
                          output => $out_path."/$marker_name-ENU-plot.png",
                          title  => "Receiver '$marker_name' ENU",
                          timestamp =>  {
                                          fmt  => '%d/%m/%y %H:%M',
                                          font => "Helvetica :Italic",
                                        },
                        );
  # ENU individual charts for multiplot:
  my $chart_e =
    Chart::Gnuplot->new(
                          grid => "on",
                          ylabel => "Easting [m]",
                          xrange => [$ini_epoch, $end_epoch],
                          timeaxis => "x",
                          xtics => { labelfmt => "%H:%M" },
                       );
  my $chart_n =
    Chart::Gnuplot->new(
                          grid => "on",
                          ylabel => "Northing [m]",
                          xrange => [$ini_epoch, $end_epoch],
                          timeaxis => "x",
                          xtics => { labelfmt => "%H:%M" },
                       );
  my $chart_u =
    Chart::Gnuplot->new(
                          grid => "on",
                          xlabel => "Observation Epochs [HH::MM]",
                          ylabel => "Upping [m]",
                          xrange => [$ini_epoch, $end_epoch],
                          timeaxis => "x",
                          xtics => { labelfmt => "%H:%M" },
                       );

  # Create chart object for receiver clock bias:
  my $chart_clk_bias =
    Chart::Gnuplot->new(
                          grid => "on",
                          output => $out_path."/$marker_name-clk-bias-plot.png",
                          title  => "Receiver '$marker_name' Clock Bias",
                          xlabel => "Observation Epochs [HH::MM]",
                          ylabel => "Clock Bias [m]",
                          xrange => [$ini_epoch, $end_epoch],
                          timeaxis => "x",
                          xtics => { labelfmt => "%H:%M" },
                          timestamp =>  {
                                          fmt  => '%d/%m/%y %H:%M',
                                          font => "Helvetica :Italic",
                                        },
                        );

  # Create 3D ENU chart object:
  my $chart_enu_3d =
    Chart::Gnuplot->new(
                          output => $out_path."/$marker_name-ENU-3D-plot.png",
                          title  => "Receiver '$marker_name' ENU",
                          grid   => "on",
                          xlabel => "Easting [m]",
                          ylabel => "Northing [m]",
                          zlabel => "Upping [m]",
                          timestamp =>  {
                                          fmt  => '%d/%m/%y %H:%M',
                                          font => "Helvetica :Italic",
                                        },
                        );

  # Build EN polar dataset:
  my $rec_en_polar_dataset =
    Chart::Gnuplot::DataSet->new(
                                  xdata => unpdl($pdl_rec_azimut->flat),
                                  ydata => unpdl($pdl_rec_distance->flat),
                                  zdata => unpdl($pdl_rec_upping->flat),
                                  style => "circles linecolor pal z",
                                  fill => { density => 0.8 },
                                );

  # Build receiver E positions dataset:
  my $rec_e_dataset =
    Chart::Gnuplot::DataSet->new(
                                  xdata => unpdl($pdl_epochs->flat),
                                  ydata => unpdl($pdl_rec_easting->flat),
                                  zdata => unpdl($pdl_std_easting->flat),
                                  style => "lines linecolor pal z",
                                  width => 3,
                                  timefmt => "%s",
                                );
  # Build receiver N positions dataset:
  my $rec_n_dataset =
    Chart::Gnuplot::DataSet->new(
                                  xdata => unpdl($pdl_epochs->flat),
                                  ydata => unpdl($pdl_rec_northing->flat),
                                  zdata => unpdl($pdl_std_northing->flat),
                                  style => "lines linecolor pal z",
                                  width => 3,
                                  timefmt => "%s",
                                );
  # Build receiver U positions dataset:
  my $rec_u_dataset =
    Chart::Gnuplot::DataSet->new(
                                  xdata => unpdl($pdl_epochs->flat),
                                  ydata => unpdl($pdl_rec_upping->flat),
                                  zdata => unpdl($pdl_std_upping->flat),
                                  style => "lines linecolor pal z",
                                  width => 3,
                                  timefmt => "%s",
                                );
  # Build receiver clock bias dataset:
  my $rec_clk_bias_dataset =
    Chart::Gnuplot::DataSet->new(
                                  xdata => unpdl($pdl_epochs->flat),
                                  ydata => unpdl($pdl_rec_clk_bias->flat),
                                  zdata => unpdl($pdl_std_clk_bias->flat),
                                  style => "lines linecolor pal z",
                                  width => 3,
                                  timefmt => "%s",
                                );

  # Build receiver ENU positions dataset:
  my $rec_enu_dataset =
    Chart::Gnuplot::DataSet->new(
                                  xdata => unpdl($pdl_rec_easting->flat),
                                  ydata => unpdl($pdl_rec_northing->flat),
                                  zdata => unpdl($pdl_rec_upping->flat),
                                  style => "points",
                                );

  # Plot the datasets on their respectives graphs:

  # ENU multiplot:
    # Add datasets to their respective charts:
    $chart_e->add2d( $rec_e_dataset );
    $chart_n->add2d( $rec_n_dataset );
    $chart_u->add2d( $rec_u_dataset );

    # And set plot matrix in parent chart object:
    $chart_enu->multiplot([ [$chart_e],
                            [$chart_n],
                            [$chart_u] ]);

  # Receiver clock bias plot:
  $chart_clk_bias->plot2d((
                            $rec_clk_bias_dataset
                         ));

  # ENU 3D plot:
  $chart_enu_3d->plot3d( $rec_enu_dataset      );

  # EN 2D polar plot:
  $chart_en_polar->plot2d( $rec_en_polar_dataset );

  return TRUE;
}

sub PlotDilutionOfPrecission {
  my ($ref_gen_conf, $inp_path,$out_path) = @_;

  # Load dumper file:
  my $ref_file_layout =
    GetFileLayout( join('/', ($inp_path, "DOP-info.out")), 5,
                   $ref_gen_conf->{DATA_DUMPER}{DELIMITER} );

  my $pdl_dop_info = pdl( LoadFileByLayout($ref_file_layout) );

  my $pdl_epochs =
    $pdl_dop_info($ref_file_layout->{ITEMS}{EpochGPS}{INDEX});

  my $ini_epoch = min($pdl_epochs);
  my $end_epoch = max($pdl_epochs);

  my $pdl_gdop = $pdl_dop_info( $ref_file_layout->{ITEMS}{GDOP}{INDEX} );
  my $pdl_pdop = $pdl_dop_info( $ref_file_layout->{ITEMS}{PDOP}{INDEX} );
  my $pdl_tdop = $pdl_dop_info( $ref_file_layout->{ITEMS}{TDOP}{INDEX} );
  my $pdl_hdop = $pdl_dop_info( $ref_file_layout->{ITEMS}{HDOP}{INDEX} );
  my $pdl_vdop = $pdl_dop_info( $ref_file_layout->{ITEMS}{VDOP}{INDEX} );

  # Create chart for ECEF frame DOP:
  my $chart_ecef =
    Chart::Gnuplot->new(
                          output => $out_path."/DOP-ECEF.png",
                          title  => "Ex-post DOP: ECEF Reference Frame",
                          grid   => "on",
                          xlabel => "Observation Epochs [HH::MM]",
                          ylabel => "DOP [m]",
                          xrange => [$ini_epoch, $end_epoch],
                          timeaxis => "x",
                          xtics => { labelfmt => "%H:%M" },
                          timestamp =>  {
                                          fmt  => '%d/%m/%y %H:%M',
                                          font => "Helvetica :Italic",
                                        },
                       );

  # Create chart for ENU frame DOP:
  my $chart_enu =
    Chart::Gnuplot->new(
                          output => $out_path."/DOP-ENU.png",
                          title  => "Ex-post DOP: ENU Reference Frame",
                          grid   => "on",
                          xlabel => "Observation Epochs [HH::MM]",
                          ylabel => "DOP [m]",
                          xrange => [$ini_epoch, $end_epoch],
                          timeaxis => "x",
                          xtics => { labelfmt => "%H:%M" },
                          timestamp =>  {
                                          fmt  => '%d/%m/%y %H:%M',
                                          font => "Helvetica :Italic",
                                        },
                       );

  # Create DOP datasets:
  my $gdop_dataset =
    Chart::Gnuplot::DataSet->new(
                                  xdata => unpdl($pdl_epochs->flat),
                                  ydata => unpdl($pdl_gdop->flat),
                                  style => "lines",
                                  width => 3,
                                  timefmt => "%s",
                                  title => "GDOP",
                                );
  my $pdop_dataset =
    Chart::Gnuplot::DataSet->new(
                                  xdata => unpdl($pdl_epochs->flat),
                                  ydata => unpdl($pdl_pdop->flat),
                                  style => "lines",
                                  width => 3,
                                  timefmt => "%s",
                                  title => "PDOP",
                                );
  my $tdop_dataset =
    Chart::Gnuplot::DataSet->new(
                                  xdata => unpdl($pdl_epochs->flat),
                                  ydata => unpdl($pdl_tdop->flat),
                                  style => "lines",
                                  width => 3,
                                  timefmt => "%s",
                                  title => "TDOP",
                                );
  my $hdop_dataset =
    Chart::Gnuplot::DataSet->new(
                                  xdata => unpdl($pdl_epochs->flat),
                                  ydata => unpdl($pdl_hdop->flat),
                                  style => "lines",
                                  width => 3,
                                  timefmt => "%s",
                                  title => "HDOP",
                                );
  my $vdop_dataset =
    Chart::Gnuplot::DataSet->new(
                                  xdata => unpdl($pdl_epochs->flat),
                                  ydata => unpdl($pdl_vdop->flat),
                                  style => "lines",
                                  width => 3,
                                  timefmt => "%s",
                                  title => "VDOP",
                                );

  # Plot datasets on their respective chart:
  $chart_ecef -> plot2d((
                          $gdop_dataset,
                          $pdop_dataset,
                          $tdop_dataset
                        ));
  $chart_enu  -> plot2d((
                          $hdop_dataset,
                          $vdop_dataset,
                          $tdop_dataset
                        ));

  return TRUE;
}

sub PlotLSQEpochEstimation {
  my ($ref_gen_conf, $inp_path, $out_path) = @_;

  # Load dumper file:
  my $ref_file_layout =
    GetFileLayout( join('/', ($inp_path, "LSQ-epoch-report-info.out")),
                   3, $ref_gen_conf->{DATA_DUMPER}{DELIMITER} );

  my $pdl_lsq_info = pdl( LoadFileByLayout($ref_file_layout) );

  # Load epochs:
  my $pdl_epochs = $pdl_lsq_info($ref_file_layout->{ITEMS}{EpochGPS}{INDEX});

  # First and last observation epochs:
  my $ini_epoch = min($pdl_epochs);
  my $end_epoch = max($pdl_epochs);

  # Retrieve the following from LSQ info:
    # Number of iterations:
    my $pdl_num_iter = $pdl_lsq_info($ref_file_layout->{ITEMS}{NumIter}{INDEX});

    # LSQ and Convergence status:
    my $pdl_lsq_st =
       $pdl_lsq_info($ref_file_layout->{ITEMS}{LSQ_Status}{INDEX});
    my $pdl_convergence_st =
       $pdl_lsq_info($ref_file_layout->{ITEMS}{ConvergenceFlag}{INDEX});

    # Number of observations, parameters and degrees of freedom:
    my $pdl_num_obs =
       $pdl_lsq_info($ref_file_layout->{ITEMS}{NumObs}{INDEX});
    my $pdl_num_parameter =
       $pdl_lsq_info($ref_file_layout->{ITEMS}{NumParameter}{INDEX});
    my $pdl_deg_of_freedom =
       $pdl_lsq_info($ref_file_layout->{ITEMS}{DegOfFree}{INDEX});

    # Ex-post standard deviation estimator:
    my $pdl_std_dev_est =
       $pdl_lsq_info($ref_file_layout->{ITEMS}{StdDevEstimator}{INDEX});

    # Approximate XYZ and DT:
    my $pdl_apx_x =
       $pdl_lsq_info($ref_file_layout->{ITEMS}{ApxX}{INDEX});
    my $pdl_apx_y =
       $pdl_lsq_info($ref_file_layout->{ITEMS}{ApxY}{INDEX});
    my $pdl_apx_z =
       $pdl_lsq_info($ref_file_layout->{ITEMS}{ApxZ}{INDEX});
    my $pdl_apx_dt =
       $pdl_lsq_info($ref_file_layout->{ITEMS}{ApxDT}{INDEX});

    # Delta XYZ and DT:
    my $pdl_delta_x =
       $pdl_lsq_info($ref_file_layout->{ITEMS}{dX}{INDEX});
    my $pdl_delta_y =
       $pdl_lsq_info($ref_file_layout->{ITEMS}{dY}{INDEX});
    my $pdl_delta_z =
       $pdl_lsq_info($ref_file_layout->{ITEMS}{dZ}{INDEX});
    my $pdl_delta_dt =
       $pdl_lsq_info($ref_file_layout->{ITEMS}{dDT}{INDEX});

    # Compute estimated parameter piddles:
    my $pdl_est_x  = $pdl_apx_x  + $pdl_delta_x;
    my $pdl_est_y  = $pdl_apx_y  + $pdl_delta_y;
    my $pdl_est_z  = $pdl_apx_z  + $pdl_delta_z;
    my $pdl_est_dt = $pdl_apx_dt + $pdl_delta_dt;

    # For DT, since its init to 0, the first records will be removed.
    # Compute number of epochs minus 1 for slicing DT records:
    my ($num_epochs, undef) = dims($pdl_epochs->flat);
    my $t_1 = $num_epochs - 1;

  # Set chart objects:
    # LSQ report:
    my $chart_lsq_rpt =
      Chart::Gnuplot->new(
                            output => $out_path."/LSQ-report.png",
                            title  => "LSQ estimation report",
                            grid   => "on",
                            xlabel => "Observation Epochs [HH::MM]",
                            xrange => [$ini_epoch, $end_epoch],
                            timeaxis => "x",
                            xtics => { labelfmt => "%H:%M" },
                            timestamp =>  {
                                            fmt  => '%d/%m/%y %H:%M',
                                            font => "Helvetica :Italic",
                                          },
                         );

    # Approximate parameter report (multiplot):
    # Parent charts. One per parameter:
    my $chart_parameter_x =
      Chart::Gnuplot->new(
                            output => $out_path."/LSQ-X-parameter-report.png",
                            title  => "LSQ X parameter estimation report",
                            timestamp =>  {
                                            fmt  => '%d/%m/%y %H:%M',
                                            font => "Helvetica :Italic",
                                          },
                         );
    my $chart_parameter_y =
      Chart::Gnuplot->new(
                            output => $out_path."/LSQ-Y-parameter-report.png",
                            title  => "LSQ Y parameter estimation report",
                            timestamp =>  {
                                            fmt  => '%d/%m/%y %H:%M',
                                            font => "Helvetica :Italic",
                                          },
                         );
    my $chart_parameter_z =
      Chart::Gnuplot->new(
                            output => $out_path."/LSQ-Z-parameter-report.png",
                            title  => "LSQ Z parameter estimation report",
                            timestamp =>  {
                                            fmt  => '%d/%m/%y %H:%M',
                                            font => "Helvetica :Italic",
                                          },
                         );
    my $chart_parameter_dt =
      Chart::Gnuplot->new(
                            output => $out_path."/LSQ-DT-parameter-report.png",
                            title  => "LSQ DT parameter estimation report",
                            timestamp =>  {
                                            fmt  => '%d/%m/%y %H:%M',
                                            font => "Helvetica :Italic",
                                          },
                         );

    # Child charts. Two per parameter:
      my $chart_x_parameter =
        Chart::Gnuplot->new(
                              grid => "on",
                              xlabel => "Observation Epochs [HH::MM]",
                              ylabel => "Parameter value [m]",
                              xrange => [$ini_epoch, $end_epoch],
                              timeaxis => "x",
                              xtics => { labelfmt => "%H:%M" },
                           );
      my $chart_delta_x_parameter =
        Chart::Gnuplot->new(
                              grid => "on",
                              xlabel => "Observation Epochs [HH::MM]",
                              ylabel => "Delta correction [m]",
                              xrange => [$ini_epoch, $end_epoch],
                              timeaxis => "x",
                              xtics => { labelfmt => "%H:%M" },
                           );
      my $chart_y_parameter        = $chart_x_parameter       -> copy;
      my $chart_delta_y_parameter  = $chart_delta_x_parameter -> copy;
      my $chart_z_parameter        = $chart_x_parameter       -> copy;
      my $chart_delta_z_parameter  = $chart_delta_x_parameter -> copy;
      my $chart_dt_parameter       = $chart_x_parameter       -> copy;
      my $chart_delta_dt_parameter = $chart_delta_x_parameter -> copy;


  # Set dataset objects:
    # LSQ status:
    my $lsq_st_dataset =
      Chart::Gnuplot::DataSet->new(
                                    xdata => unpdl($pdl_epochs->flat),
                                    ydata => unpdl($pdl_lsq_st->flat),
                                    style => "filledcurve y=0",
                                    timefmt => "%s",
                                    fill => { density => 0.3 },
                                    title => "LSQ Status",
                                 );
    # Convergence flag:
    my $convergence_st_dataset =
      Chart::Gnuplot::DataSet->new(
                                    xdata => unpdl($pdl_epochs->flat),
                                    ydata => unpdl($pdl_convergence_st->flat),
                                    style => "filledcurve y=0",
                                    timefmt => "%s",
                                    fill => { density => 0.3 },
                                    title => "Convergence Flag",
                                 );
    # Number of iterations:
    my $num_iter_dataset =
      Chart::Gnuplot::DataSet->new(
                                    xdata => unpdl($pdl_epochs->flat),
                                    ydata => unpdl($pdl_num_iter->flat),
                                    style => "lines",
                                    width => 3,
                                    timefmt => "%s",
                                    title => "Iterations",
                                 );
    # Number of observations:
    my $num_obs_dataset =
      Chart::Gnuplot::DataSet->new(
                                    xdata => unpdl($pdl_epochs->flat),
                                    ydata => unpdl($pdl_num_obs->flat),
                                    style => "lines",
                                    width => 3,
                                    timefmt => "%s",
                                    title => "Observations",
                                 );
    # Parameters to estimate:
    my $num_parameter_dataset =
      Chart::Gnuplot::DataSet->new(
                                    xdata => unpdl($pdl_epochs->flat),
                                    ydata => unpdl($pdl_num_parameter->flat),
                                    style => "lines",
                                    width => 3,
                                    timefmt => "%s",
                                    title => "Parameters to Estimate",
                                 );
    # Degrees of freedom:
    my $deg_of_free_dataset =
      Chart::Gnuplot::DataSet->new(
                                    xdata => unpdl($pdl_epochs->flat),
                                    ydata => unpdl($pdl_deg_of_freedom->flat),
                                    style => "lines",
                                    width => 3,
                                    timefmt => "%s",
                                    title => "Degrees of Freedom",
                                 );
    # Ex-post standard deviation estimator:
    my $std_dev_est_dataset =
      Chart::Gnuplot::DataSet->new(
                                    xdata => unpdl($pdl_epochs->flat),
                                    ydata => unpdl($pdl_std_dev_est->flat),
                                    style => "lines",
                                    width => 3,
                                    timefmt => "%s",
                                    title => "STD-DEV estimator",
                                 );

    # ECEF X parameter estimation:
    my $est_x_parameter_dataset =
      Chart::Gnuplot::DataSet->new(
                                    xdata => unpdl($pdl_epochs->flat),
                                    ydata => unpdl($pdl_est_x->flat),
                                    style => "lines",
                                    width => 3,
                                    timefmt => "%s",
                                    title => "Estimated X",
                                 );
    my $apx_x_parameter_dataset =
      Chart::Gnuplot::DataSet->new(
                                    xdata => unpdl($pdl_epochs->flat),
                                    ydata => unpdl($pdl_apx_x->flat),
                                    style => "lines",
                                    width => 3,
                                    timefmt => "%s",
                                    title => "Approximate X",
                                 );
    my $delta_x_parameter_dataset =
      Chart::Gnuplot::DataSet->new(
                                    xdata => unpdl($pdl_epochs->flat),
                                    ydata => unpdl($pdl_delta_x->flat),
                                    zdata => unpdl($pdl_std_dev_est->flat),
                                    style => "lines pal z",
                                    width => 3,
                                    timefmt => "%s",
                                 );
    # ECEF Y parameter estimation:
    my $est_y_parameter_dataset =
      Chart::Gnuplot::DataSet->new(
                                    xdata => unpdl($pdl_epochs->flat),
                                    ydata => unpdl($pdl_est_y->flat),
                                    style => "lines",
                                    width => 3,
                                    timefmt => "%s",
                                    title => "Estimated Y",
                                 );
    my $apx_y_parameter_dataset =
      Chart::Gnuplot::DataSet->new(
                                    xdata => unpdl($pdl_epochs->flat),
                                    ydata => unpdl($pdl_apx_y->flat),
                                    style => "lines",
                                    width => 3,
                                    timefmt => "%s",
                                    title => "Approximate Y",
                                 );
    my $delta_y_parameter_dataset =
      Chart::Gnuplot::DataSet->new(
                                    xdata => unpdl($pdl_epochs->flat),
                                    ydata => unpdl($pdl_delta_y->flat),
                                    zdata => unpdl($pdl_std_dev_est->flat),
                                    style => "lines pal z",
                                    width => 3,
                                    timefmt => "%s",
                                 );
    # ECEF Z parameter estimation:
    my $est_z_parameter_dataset =
      Chart::Gnuplot::DataSet->new(
                                    xdata => unpdl($pdl_epochs->flat),
                                    ydata => unpdl($pdl_est_z->flat),
                                    style => "lines",
                                    width => 3,
                                    timefmt => "%s",
                                    title => "Estimated Z",
                                 );
    my $apx_z_parameter_dataset =
      Chart::Gnuplot::DataSet->new(
                                    xdata => unpdl($pdl_epochs->flat),
                                    ydata => unpdl($pdl_apx_z->flat),
                                    style => "lines",
                                    width => 3,
                                    timefmt => "%s",
                                    title => "Approximate Z",
                                 );
    my $delta_z_parameter_dataset =
      Chart::Gnuplot::DataSet->new(
                                    xdata => unpdl($pdl_epochs->flat),
                                    ydata => unpdl($pdl_delta_z->flat),
                                    zdata => unpdl($pdl_std_dev_est->flat),
                                    style => "lines pal z",
                                    width => 3,
                                    timefmt => "%s",
                                 );
    # Receiver clock (DT) parameter estimation:
    my $est_dt_parameter_dataset =
      Chart::Gnuplot::DataSet->new(
                                    xdata =>
                                      unpdl($pdl_epochs->flat->slice("1:$t_1")),
                                    ydata =>
                                      unpdl($pdl_est_dt->flat->slice("1:$t_1")),
                                    style => "lines",
                                    width => 3,
                                    timefmt => "%s",
                                    title => "Estimated DT",
                                 );
    my $apx_dt_parameter_dataset =
      Chart::Gnuplot::DataSet->new(
                                    xdata =>
                                      unpdl($pdl_epochs->flat->slice("1:$t_1")),
                                    ydata =>
                                      unpdl($pdl_apx_dt->flat->slice("1:$t_1")),
                                    style => "lines",
                                    width => 3,
                                    timefmt => "%s",
                                    title => "Approximate DT",
                                 );
    my $delta_dt_parameter_dataset =
      Chart::Gnuplot::DataSet->new(
                                    xdata =>
                                      unpdl($pdl_epochs->flat->slice("1:$t_1")),
                                    ydata =>
                                      unpdl($pdl_delta_dt->flat->slice("1:$t_1")),
                                    zdata =>
                                      unpdl($pdl_std_dev_est->flat->slice("1:$t_1")),
                                    style => "lines pal z",
                                    width => 3,
                                    timefmt => "%s",
                                 );

  # Plot datsets in their respective charts:
    # LSQ report plot:
    $chart_lsq_rpt->plot2d((
                              $lsq_st_dataset,
                              $convergence_st_dataset,
                              $num_iter_dataset,
                              $num_obs_dataset,
                              $num_parameter_dataset,
                              $deg_of_free_dataset,
                              $std_dev_est_dataset
                           ));

    # Parameter estaimtion report:
      # Add plots to their respective sub-charts:
      $chart_x_parameter       -> add2d( $apx_x_parameter_dataset   );
      $chart_x_parameter       -> add2d( $est_x_parameter_dataset   );
      $chart_delta_x_parameter -> add2d( $delta_x_parameter_dataset );

      $chart_y_parameter       -> add2d( $apx_y_parameter_dataset   );
      $chart_y_parameter       -> add2d( $est_y_parameter_dataset   );
      $chart_delta_y_parameter -> add2d( $delta_y_parameter_dataset );

      $chart_z_parameter       -> add2d( $apx_z_parameter_dataset   );
      $chart_z_parameter       -> add2d( $est_z_parameter_dataset   );
      $chart_delta_z_parameter -> add2d( $delta_z_parameter_dataset );

      $chart_dt_parameter       -> add2d( $apx_dt_parameter_dataset   );
      $chart_dt_parameter       -> add2d( $est_dt_parameter_dataset   );
      $chart_delta_dt_parameter -> add2d( $delta_dt_parameter_dataset );

      # Plot matrix:
      $chart_parameter_x->multiplot([ [$chart_x_parameter],
                                      [$chart_delta_x_parameter] ]);
      $chart_parameter_y->multiplot([ [$chart_y_parameter],
                                      [$chart_delta_y_parameter] ]);
      $chart_parameter_z->multiplot([ [$chart_z_parameter],
                                      [$chart_delta_z_parameter] ]);
      $chart_parameter_dt->multiplot([ [$chart_dt_parameter],
                                       [$chart_delta_dt_parameter] ]);


  return TRUE;
}

sub PlotSatelliteResiduals {
  my ($ref_gen_conf, $sat_sys, $inp_path, $out_path) = @_;

  # Load dumper file:
  my $ref_file_layout =
    GetFileLayout( join('/', ($inp_path, "$sat_sys-sat-residuals.out")), 7,
                   $ref_gen_conf->{DATA_DUMPER}{DELIMITER} );

  my $pdl_residuals = pdl( LoadFileByLayout($ref_file_layout) );

  # Load epochs:
  my $pdl_epochs = $pdl_residuals($ref_file_layout->{ITEMS}{EpochGPS}{INDEX});

  my $ini_epoch = min($pdl_epochs);
  my $end_epoch = max($pdl_epochs);

  # Retrieve observed satellites:
  my @avail_sats =
    sort( grep(/^$sat_sys\d{2}$/, (keys %{$ref_file_layout->{ITEMS}})) );
  # Retrieve command for adding satellite ID tics on Y axis:
  my $sat_id_ytics_cmm = RetrieveSatYTicsCommand(@avail_sats);

  # Set chart object:
  my $chart =
    Chart::Gnuplot->new(
                          output => $out_path."/$sat_sys-residuals.png",
                          title  => "Satellite '$sat_sys' Residuals",
                          grid   => "on",
                          xlabel => "Observation Epochs [HH::MM]",
                          ylabel => "Satellite PRN",
                          xrange => [$ini_epoch, $end_epoch],
                          yrange => [0, scalar(@avail_sats) + 1],
                          timeaxis => "x",
                          xtics => { labelfmt => "%H:%M" },
                          $sat_id_ytics_cmm => "",
                          timestamp =>  {
                                          fmt  => '%d/%m/%y %H:%M',
                                          font => "Helvetica :Italic",
                                        },
                       );

  my @datasets;

  for my $i (keys @avail_sats)
  {
    my $sat = $avail_sats[$i];

    # Retrieve satellite residuals:
    my $pdl_sat_residuals =
       $pdl_residuals($ref_file_layout->{ITEMS}{$sat}{INDEX});

    # Buidl PDL piddle with the same dimension as residuals and epochs
    # and with the satellite index value:
    my (undef, $num_epochs) = dims( $pdl_epochs );
    my $pdl_sat_index = ones($num_epochs) + $i;

    # Set dataset object:
    my $sat_dataset =
      Chart::Gnuplot::DataSet->new(
                                    xdata => unpdl($pdl_epochs->flat),
                                    ydata => unpdl($pdl_sat_index->flat),
                                    zdata => unpdl($pdl_sat_residuals->flat),
                                    style => "lines linecolor pal z",
                                    width => 10,
                                    timefmt => "%s",
                                  );

    push(@datasets, $sat_dataset);
  }

  # Plot datasets on chart:
  $chart->plot2d(@datasets);

  return TRUE;
}

sub PlotSatelliteIonosphereDelay {
  my ($ref_gen_conf, $sat_sys, $inp_path, $out_path) = @_;

  # Load dumper file:
  my $ref_file_layout =
    GetFileLayout( join('/', ($inp_path, "$sat_sys-sat-iono-delay.out")), 5,
                   $ref_gen_conf->{DATA_DUMPER}{DELIMITER} );

  my $pdl_iono_delay = pdl( LoadFileByLayout($ref_file_layout) );

  # Load epochs:
  my $pdl_epochs =
     $pdl_iono_delay($ref_file_layout->{ITEMS}{EpochGPS}{INDEX});

  my $ini_epoch = min($pdl_epochs);
  my $end_epoch = max($pdl_epochs);

  # Retrieve observed satellites:
  my @avail_sats =
    sort( grep(/^$sat_sys\d{2}$/, (keys %{$ref_file_layout->{ITEMS}})) );
  # Retrieve command for adding satellite ID tics on Y axis:
  my $sat_id_ytics_cmm = RetrieveSatYTicsCommand(@avail_sats);

  # Set chart object:
  my $chart =
    Chart::Gnuplot->new(
                          output => $out_path."/$sat_sys-iono-delay.png",
                          title  => "Satellite '$sat_sys' Ionospheric Correction",
                          grid   => "on",
                          xlabel => "Observation Epochs [HH::MM]",
                          ylabel => "Satellite PRN",
                          xrange => [$ini_epoch, $end_epoch],
                          yrange => [0, scalar(@avail_sats) + 1],
                          timeaxis => "x",
                          xtics => { labelfmt => "%H:%M" },
                          $sat_id_ytics_cmm => "",
                          timestamp =>  {
                                          fmt  => '%d/%m/%y %H:%M',
                                          font => "Helvetica :Italic",
                                        },
                       );

  my @datasets;

  for my $i (keys @avail_sats)
  {
    my $sat = $avail_sats[$i];

    # Retrieve satellite residuals:
    my $pdl_sat_iono =
       $pdl_iono_delay($ref_file_layout->{ITEMS}{$sat}{INDEX});

    # Buidl PDL piddle with the same dimension as residuals and epochs
    # and with the satellite index value:
    my (undef, $num_epochs) = dims( $pdl_epochs );
    my $pdl_sat_index = ones($num_epochs) + $i;

    # Set dataset object:
    my $sat_dataset =
      Chart::Gnuplot::DataSet->new(
                                    xdata => unpdl($pdl_epochs->flat),
                                    ydata => unpdl($pdl_sat_index->flat),
                                    zdata => unpdl($pdl_sat_iono->flat),
                                    style => "lines linecolor pal z",
                                    width => 10,
                                    timefmt => "%s",
                                  );

    push(@datasets, $sat_dataset);
  }

  # Plot datasets on chart:
  $chart->plot2d(@datasets);

  return TRUE;
}

sub PlotSatelliteTroposphereDelay {
  my ($ref_gen_conf, $sat_sys, $inp_path, $out_path) = @_;

  # Load dumper file:
  my $ref_file_layout =
    GetFileLayout( join('/', ($inp_path, "$sat_sys-sat-tropo-delay.out")), 5,
                   $ref_gen_conf->{DATA_DUMPER}{DELIMITER} );

  my $pdl_tropo_delay = pdl( LoadFileByLayout($ref_file_layout) );

  # Load epochs:
  my $pdl_epochs =
     $pdl_tropo_delay($ref_file_layout->{ITEMS}{EpochGPS}{INDEX});

  my $ini_epoch = min($pdl_epochs);
  my $end_epoch = max($pdl_epochs);

  # Retrieve observed satellites:
  my @avail_sats =
    sort( grep(/^$sat_sys\d{2}$/, (keys %{$ref_file_layout->{ITEMS}})) );
  # Retrieve command for adding satellite ID tics on Y axis:
  my $sat_id_ytics_cmm = RetrieveSatYTicsCommand(@avail_sats);

  # Set chart object:
  my $chart =
    Chart::Gnuplot->new(
                          output => $out_path."/$sat_sys-tropo-delay.png",
                          title  => "Satellite '$sat_sys' Tropospheric Correction",
                          grid   => "on",
                          xlabel => "Observation Epochs [HH::MM]",
                          ylabel => "Satellite PRN",
                          xrange => [$ini_epoch, $end_epoch],
                          yrange => [0, scalar(@avail_sats) + 1],
                          timeaxis => "x",
                          xtics => { labelfmt => "%H:%M" },
                          $sat_id_ytics_cmm => "",
                          timestamp =>  {
                                          fmt  => '%d/%m/%y %H:%M',
                                          font => "Helvetica :Italic",
                                        },
                       );

  my @datasets;

  for my $i (keys @avail_sats)
  {
    my $sat = $avail_sats[$i];

    # Retrieve satellite residuals:
    my $pdl_sat_tropo =
       $pdl_tropo_delay($ref_file_layout->{ITEMS}{$sat}{INDEX});

    # Buidl PDL piddle with the same dimension as residuals and epochs
    # and with the satellite index value:
    my (undef, $num_epochs) = dims( $pdl_epochs );
    my $pdl_sat_index = ones($num_epochs) + $i;

    # Set dataset object:
    my $sat_dataset =
      Chart::Gnuplot::DataSet->new(
                                    xdata => unpdl($pdl_epochs->flat),
                                    ydata => unpdl($pdl_sat_index->flat),
                                    zdata => unpdl($pdl_sat_tropo->flat),
                                    style => "lines linecolor pal z",
                                    width => 10,
                                    timefmt => "%s",
                                  );

    push(@datasets, $sat_dataset);
  }

  # Plot datasets on chart:
  $chart->plot2d(@datasets);

  return TRUE;
}

# ============================================================================ #
# Second level subroutines:                                                    #
# ============================================================================ #

sub GetFileLayout {
  my ($file_path, $head_line, $delimiter) = @_;

  my $ref_file_layout = {};

  $ref_file_layout->{FILE}{ PATH      } = $file_path;
  $ref_file_layout->{FILE}{ HEAD      } = $head_line;
  $ref_file_layout->{FILE}{ DELIMITER } = $delimiter;

  my $fh; open($fh, '<', $file_path) or die "Could not open $!";

  while (my $line = <$fh>) {
    if ($. == $head_line) {

      my @head_items = split(/[\s$delimiter]+/, $line);

      for my $index (keys @head_items) {
        $ref_file_layout->{ITEMS}{$head_items[$index]}{INDEX} = $index;
      }

      last;

    }
  }

  close($fh);

  return $ref_file_layout;
}

sub LoadFileByLayout {
  my ($ref_file_layout) = @_;

  # Retrieve file properties:
  my ( $file_path,
       $head_line,
       $delimiter ) = ( $ref_file_layout->{FILE}{PATH},
                        $ref_file_layout->{FILE}{HEAD},
                        $ref_file_layout->{FILE}{DELIMITER} );

  my $ref_array = [];

  my $fh; open($fh, '<', $file_path) or die "Could not open $!";

  SkipLines($fh, $head_line);

  while (my $line = <$fh>) {
    push( @{$ref_array}, [split(/$delimiter/, $line)] );
  }

  close($fh);

  return $ref_array;
}

sub RetrieveSatYTicsCommand {
  my @sat_list = @_;

  # Init array to store satellite ID and index pair:
  my @sat_values;

  # Build satellite ID and datellite index value pair:
  for (my $i = 0; $i < scalar(@sat_list); $i += 1) {
    my $sat = $sat_list[$i];
    my $sat_index = $i + 1;
    push(@sat_values, "\"$sat\" $sat_index");
  }

  # Write command:
  # example: 'add ("N" 0, "E" 90, "S" 180, "W" 270) font ":Bold"'
  my $command = 'ytics add ("" 0,'.join(', ', @sat_values).') font ":Bold"';

  # Return command:
  return $command;
}
