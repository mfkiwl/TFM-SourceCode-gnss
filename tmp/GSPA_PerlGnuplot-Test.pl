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
  PlotConstellationAvailability($ref_gen_conf, $sat_sys, $inp_path, $out_path);

# ****************************** #
#    1.b Satellite elevation     #
# ****************************** #
  PlotSatelliteElevation($ref_gen_conf, $sat_sys, $inp_path, $out_path);

# ******************* #
#    1.c Sky plot:    #
# ******************* #
  PlotSatelliteSkyPath($ref_gen_conf, $sat_sys, $inp_path, $out_path);

# ---------------------------------------------------------------------------- #
# 2. Receiver Position plots:
# ---------------------------------------------------------------------------- #
# ******************************************************** #
#    2.a Easting/Northing point densisty plot:             #
#    2.b Upping plot:                                      #
#    2.c Easting/Northing/Upping point density 3D plot:    #
# ******************************************************** #
  PlotReceiverPositions($ref_gen_conf, $ref_obs_data, $inp_path, $out_path);

# ---------------------------------------------------------------------------- #
# 3. Ex-post Dilution of Precission:
# ---------------------------------------------------------------------------- #
# ************************ #
#    3.a ECEF frame DOP:   #
#    3.b ENU frame DOP:    #
# ************************ #
  PlotDilutionOfPrecission($ref_gen_conf, $inp_path, $out_path);

# ---------------------------------------------------------------------------- #
# 4. Least Squeares Estimation plots:
# ---------------------------------------------------------------------------- #
# *********************************************** #
#    4.a Number of iterations                     #
#    4.b Ex-post Standard Deviation Estimator     #
#    4.c Delta Parameter estimation               #
# *********************************************** #
  PlotLSQEpochEstimation($ref_gen_conf, $inp_path, $out_path);

# ********************************* #
#    4.d Residuals by satellite:    #
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
# ************************************************* #
  PlotSatelliteIonosphereDelay($ref_gen_conf, $sat_sys, $inp_path, $out_path);

# ************************************************** #
#    5.b Troposphere Computed delay by satellite:    #
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

sub PlotReceiverPositions {
  my ($ref_gen_conf, $ref_obs_data, $inp_path, $out_path) = @_;

  # Select receiver position dumper file:
  my $rec_marker_name = $ref_obs_data->{HEAD}{MARKER_NAME};
  my $ref_file_layout =
     GetFileLayout($inp_path."/$rec_marker_name-xyz.out", 8,
                   $ref_gen_conf->{DATA_DUMPER}{DELIMITER});

  my $pdl_rec_xyz = pdl( LoadFileByLayout($ref_file_layout) );

  # Observation epochs:
  my $pdl_epochs = $pdl_rec_xyz($ref_file_layout->{ITEMS}{Epoch}{INDEX});

  my $ini_epoch = min($pdl_epochs);
  my $end_epoch = max($pdl_epochs);

  # Retrieve Easting and Northing values:
  my $pdl_rec_easting  = $pdl_rec_xyz($ref_file_layout->{ITEMS}{REF_IE}{INDEX});
  my $pdl_rec_northing = $pdl_rec_xyz($ref_file_layout->{ITEMS}{REF_IN}{INDEX});
  my $pdl_rec_upping   = $pdl_rec_xyz($ref_file_layout->{ITEMS}{REF_IU}{INDEX});

  # Build polar coordinates from easting and northing coordinate
  # components:
  my $pdl_rec_azimut = pi/2 - atan2($pdl_rec_northing, $pdl_rec_easting);
  my $pdl_rec_distance = ($pdl_rec_easting**2 + $pdl_rec_northing**2)**.5;

  # Create EN chart object:
  my $chart_en =
    Chart::Gnuplot->new(
                          output => $out_path."/$rec_marker_name-EN-plot.png",
                          title  => "Receiver '$rec_marker_name' EN",
                          border => undef,
                          xtics  => undef,
                          ytics  => undef,
                          timestamp =>  {
                                          fmt  => '%d/%m/%y %H:%M',
                                          font => "Helvetica :Italic",
                                        },
                        );

  # Set chart polar properties:
  $chart_en->set(
                  size   => "square",
                  polar  => "",
                  grid   => "polar",
                  angle  => "radians",
                  theta  => "top clockwise",
                  trange => "[0:2*pi]",
                  rtics  => "0.5",
                  ttics  => 'add ("N" 0, "E" 90, "S" 180, "W" 270) font ":Bold"',
                  colorbox => "",
                );

  # Set point style properties:
  $chart_en->set(
                  style => "fill transparent solid 0.04 noborder",
                  style => "circle radius 0.04",
                );

  # Create U chart object:
  my $chart_u =
    Chart::Gnuplot->new(
                          output => $out_path."/$rec_marker_name-U-plot.png",
                          title  => "Receiver '$rec_marker_name' U",
                          grid   => "on",
                          xlabel => "Observation Epochs [HH::MM]",
                          ylabel => "Upping [m]",
                          xrange => [$ini_epoch, $end_epoch],
                          timeaxis => "x",
                          xtics => { labelfmt => "%H:%M" },
                          timestamp =>  {
                                          fmt  => '%d/%m/%y %H:%M',
                                          font => "Helvetica :Italic",
                                        },
                        );

  # Create ENU chart object:
  my $chart_enu =
    Chart::Gnuplot->new(
                          output => $out_path."/$rec_marker_name-ENU-plot.png",
                          title  => "Receiver '$rec_marker_name' ENU",
                          grid   => "on",
                          xlabel => "Easting [m]",
                          ylabel => "Northing [m]",
                          zlabel => "Upping [m]",
                          timestamp =>  {
                                          fmt  => '%d/%m/%y %H:%M',
                                          font => "Helvetica :Italic",
                                        },
                        );

  # Build receiver EN positions dataset:
  my $rec_en_dataset =
    Chart::Gnuplot::DataSet->new(
                                  xdata => unpdl($pdl_rec_azimut->flat),
                                  ydata => unpdl($pdl_rec_distance->flat),
                                  zdata => unpdl($pdl_epochs->flat),
                                  style => "circles linecolor pal z",
                                  fill => { density => 0.8 },
                                );

  # Build receiver U positions dataset:
  my $rec_u_dataset =
    Chart::Gnuplot::DataSet->new(
                                  xdata => unpdl($pdl_epochs->flat),
                                  ydata => unpdl($pdl_rec_upping->flat),
                                  zdata => unpdl($pdl_epochs->flat),
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
  $chart_u   -> plot2d( $rec_u_dataset   );
  $chart_en  -> plot2d( $rec_en_dataset  );
  $chart_enu -> plot3d( $rec_enu_dataset );

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

sub PlotLSQEpochEstimation {}

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

  # Set chart object:
  my $chart =
    Chart::Gnuplot->new(
                          output => $out_path."/$sat_sys-residuals.png",
                          title  => "Satellite '$sat_sys' Residuals",
                          grid   => "on",
                          xlabel => "Observation Epochs [HH::MM]",
                          ylabel => "Satellite PRN",
                          xrange => [$ini_epoch, $end_epoch],
                          timeaxis => "x",
                          xtics => { labelfmt => "%H:%M" },
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

  # Set chart object:
  my $chart =
    Chart::Gnuplot->new(
                          output => $out_path."/$sat_sys-iono-delay.png",
                          title  => "Satellite '$sat_sys' Ionospheric Correction",
                          grid   => "on",
                          xlabel => "Observation Epochs [HH::MM]",
                          ylabel => "Satellite PRN",
                          xrange => [$ini_epoch, $end_epoch],
                          timeaxis => "x",
                          xtics => { labelfmt => "%H:%M" },
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

  # Set chart object:
  my $chart =
    Chart::Gnuplot->new(
                          output => $out_path."/$sat_sys-tropo-delay.png",
                          title  => "Satellite '$sat_sys' Tropospheric Correction",
                          grid   => "on",
                          xlabel => "Observation Epochs [HH::MM]",
                          ylabel => "Satellite PRN",
                          xrange => [$ini_epoch, $end_epoch],
                          timeaxis => "x",
                          xtics => { labelfmt => "%H:%M" },
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
