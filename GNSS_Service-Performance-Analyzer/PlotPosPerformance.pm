#!/usr/bin/perl -w

# TODO: Package description goes here...

# Package declaration:
package PlotPosPerformance;

# ---------------------------------------------------------------------------- #
# Set package exportation properties:

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
  our @EXPORT_CONST = qw(  );

  # Define subroutines to export:
  our @EXPORT_SUB   = qw( &PlotReceiverPosition
                          &PlotDilutionOfPrecission );

  # Merge constants and subroutines:
  our @EXPORT_OK = (@EXPORT_CONST, @EXPORT_SUB);

  # Define export tags:
  our %EXPORT_TAGS = ( ALL         => \@EXPORT_OK,
                       DEFAULT     => \@EXPORT,
                       CONSTANTS   => \@EXPORT_CONST,
                       SUBROUTINES => \@EXPORT_SUB );
}

# ---------------------------------------------------------------------------- #
# Import common perl modules:

use Carp;         # advanced warning and failure raise...
use strict;       # strict syntax and common mistakes advisory...

use Data::Dumper;       # var pretty print...
use feature qq(say);    # print adding line jump...
use feature qq(switch); # advanced switch statement...

# Perl Data Language (PDL) modules:
use PDL;
use PDL::NiceSlice;
use Math::Trig qq(pi);

# Perl-Gnuplot conection module:
use Chart::Gnuplot;

# ---------------------------------------------------------------------------- #
# Load bash enviroments:

use lib $ENV{ ENV_ROOT };
use Enviroments qq(:CONSTANTS);

# ---------------------------------------------------------------------------- #
# Load dedicated libraries:

use lib LIB_ROOT_PATH;
use MyUtil   qq(:ALL); # ancillary utilities...
use MyMath   qq(:ALL); # dedicated math toolbox...
use MyPrint  qq(:ALL); # plain text print layouts...
use TimeGNSS qq(:ALL); # GNSS time conversion tools...
use Geodetic qq(:ALL); # dedicated geodesy utilities...

# Load general configuration and interfaces module:
use lib SRC_ROOT_PATH;
use GeneralConfiguration qq(:ALL);

# Load common GSPA utils:
use lib GSPA_ROOT_PATH;
use CommonUtil qq(:ALL);

# ---------------------------------------------------------------------------- #
# Public Subroutines: #

sub PlotReceiverPosition {
  my ($ref_gen_conf, $inp_path, $out_path, $marker_name) = @_;

  # Select receiver position dumper file:
  my $ref_file_layout =
     GetFileLayout($inp_path."/$marker_name-xyz.out", 8,
                   $ref_gen_conf->{DATA_DUMPER}{DELIMITER});

  my $pdl_rec_xyz = pdl( LoadFileByLayout($ref_file_layout) );

  # Observation epochs:
  my $pdl_epochs =
     $pdl_rec_xyz($ref_file_layout->{ITEMS}{Epoch}{INDEX});

  # Get first and last observation epochs:
  my $ini_epoch = min($pdl_epochs);
  my $end_epoch = max($pdl_epochs);

  # Retrieve days's 00:00:00 in GPS epoch format:
  my $ini_day_epoch = Date2GPS( (GPS2Date($ini_epoch))[0..2], 0, 0, 0 );
  my $pdl_epoch_day_hour = ($pdl_epochs - $ini_day_epoch)/SECONDS_IN_HOUR;

  # Retrieve Easting and Northing values:
  my $pdl_rec_easting =
     $pdl_rec_xyz($ref_file_layout->{ITEMS}{REF_IE}{INDEX});
  my $pdl_rec_northing =
     $pdl_rec_xyz($ref_file_layout->{ITEMS}{REF_IN}{INDEX});
  my $pdl_rec_upping =
     $pdl_rec_xyz($ref_file_layout->{ITEMS}{REF_IU}{INDEX});

  # Get maximum upping absolute value:
  my $max_upping     = max($pdl_rec_upping);
  my $min_upping     = min($pdl_rec_upping);
  my $max_abs_upping = max( pdl [abs($max_upping), abs($min_upping)] );

  # Retrieve standard deviations for ENU coordinates:
  # TODO: consider applying configured sigma scale factor
  my $pdl_std_easting =
     $pdl_rec_xyz($ref_file_layout->{ITEMS}{Sigma_E}{INDEX});
  my $pdl_std_northing =
     $pdl_rec_xyz($ref_file_layout->{ITEMS}{Sigma_N}{INDEX});
  my $pdl_std_upping =
     $pdl_rec_xyz($ref_file_layout->{ITEMS}{Sigma_U}{INDEX});

  # Compute horizontal standard deviation:
  my $pdl_std_en = ($pdl_std_easting**2 + $pdl_std_northing**2)**0.5;

  # Retrieve receiver clock bias estimation and associated error:
  my $pdl_rec_clk_bias =
     $pdl_rec_xyz($ref_file_layout->{ITEMS}{ClkBias}{INDEX});
  my $pdl_std_clk_bias =
     $pdl_rec_xyz($ref_file_layout->{ITEMS}{Sigma_ClkBias}{INDEX});

  # Build polar coordinates from easting and northing components:
  my ($pdl_rec_azimut, $pdl_rec_distance) =
    RecPolarCoordinates($pdl_rec_easting, $pdl_rec_northing);

  # Compute max rec distance for polar plot and add 1 meter.
  # This is for setting the polar plot bound on the ro domain:
  my $max_rec_distance = int(max($pdl_rec_distance)) + 1;

  # Set EN polar title:
  # Get initial epoch date in 'yyyy/mo/dd' format:
  my $chart_en_polar_hsigma_title =
    SetReportTitle("Receiver Easting, Northing and Sigma(H)",
                   $ref_gen_conf, $marker_name, $ini_epoch);
  my $palette_label_sigmah_cmm = 'cblabel "Horizontal Sigma [m]"';

  # Create polar plot object for plotting EN components:
  my $chart_en_polar_hsigma =
    Chart::Gnuplot->new(
      terminal => 'pngcairo size 874,874',
      output => $out_path."/$marker_name-rec-EN-SigmaH-polar.png",
      title  => {
        text => $chart_en_polar_hsigma_title,
        font => ':Bold',
      },
      border => undef,
      xtics  => undef,
      ytics  => undef,
      $palette_label_sigmah_cmm => '',
      timestamp =>  {
        fmt  => 'Created on %d/%m/%y %H:%M:%S',
        font => "Helvetica Italic, 10",
      },
    );
  # Set chart polar properties:
    $chart_en_polar_hsigma->set(
      size   => "0.9, 0.9",
      origin => "0.085, 0.06",
      polar  => "",
      grid   => "polar front",
      'border polar' => '',
      angle  => "radians",
      theta  => "top clockwise",
      trange => "[0:2*pi]",
      rrange => "[0:$max_rec_distance]",
      rtics  => "1",
      ttics  => 'add ("N" 0, "NE" 45, "E" 90, "SE" 135, '.
                     '"S" 180, "SW" 225, "W" 270, "NW" 315)',
      colorbox => "",
    );
  # Set point style properties:
    $chart_en_polar_hsigma->set(
      style => "fill transparent solid 0.04 noborder",
      style => "circle radius 0.05",
    );

  # Set polar EN plot with epoch in the Z domain:
  my $chart_en_epoch_polar_title =
    SetReportTitle("Receiver Easting, Northing and Epoch",
                   $ref_gen_conf, $marker_name, $ini_epoch);
  my $palette_label_epoch_cmm = 'cblabel "Epoch [h]"';
  my $palette_color_epoch_cmm =
    'palette defined (0 0 0 0, 1 0 0 1, 3 0 1 0, 4 1 0 0, 6 1 1 1)';

  my $chart_en_epoch_polar =
    Chart::Gnuplot->new(
      terminal => 'pngcairo size 874,874',
      output => $out_path."/$marker_name-rec-EN-Epoch-polar.png",
      title  => {
        text => $chart_en_epoch_polar_title,
        font => ':Bold',
      },
      border => undef,
      xtics  => undef,
      ytics  => undef,
      $palette_label_epoch_cmm => '',
      $palette_color_epoch_cmm => '',
      # $palette_range_epoch_cmm => '',
      timestamp =>  {
        fmt  => 'Created on %d/%m/%y %H:%M:%S',
        font => "Helvetica Italic, 10",
      },
    );
  # Set chart polar properties:
    $chart_en_epoch_polar->set(
      size   => "0.9, 0.9",
      origin => "0.085, 0.06",
      polar  => "",
      grid   => "polar front",
      'border polar' => '',
      angle  => "radians",
      theta  => "top clockwise",
      trange => "[0:2*pi]",
      rrange => "[0:$max_rec_distance]",
      rtics  => "1",
      ttics  => 'add ("N" 0, "NE" 45, "E" 90, "SE" 135, '.
                     '"S" 180, "SW" 225, "W" 270, "NW" 315)',
      cbtics => 0.25,
      colorbox => "",
    );
  # Set point style properties:
    $chart_en_epoch_polar->set(
      style => "fill transparent solid 0.04 noborder",
      style => "circle radius 0.05",
    );

  # Plor for polar EN and upping in Z domain:
  my $chart_enu_polar_title =
    SetReportTitle("Receiver Easting, Northing and Upping",
                   $ref_gen_conf, $marker_name, $ini_epoch);
  my $palette_label_upping_cmm = 'cblabel "Upping [m]"';
  my $palette_color_upping_cmm = 'palette rgb 33,13,10;';
  my $palette_range_upping_cmm = "cbrange [-$max_abs_upping:$max_abs_upping]";

  my $chart_enu_polar =
    Chart::Gnuplot->new(
      terminal => 'pngcairo size 874,874',
      output => $out_path."/$marker_name-rec-EN-Upping-polar.png",
      title  => {
        text => $chart_enu_polar_title,
        font => ':Bold',
      },
      border => undef,
      xtics  => undef,
      ytics  => undef,
      $palette_label_upping_cmm => '',
      $palette_color_upping_cmm => '',
      $palette_range_upping_cmm => '',
      timestamp =>  {
        fmt  => 'Created on %d/%m/%y %H:%M:%S',
        font => "Helvetica Italic, 10",
      },
    );
  # Set chart polar properties:
    $chart_enu_polar->set(
      size   => "0.9, 0.9",
      origin => "0.085, 0.06",
      polar  => "",
      grid   => "polar front",
      'border polar' => '',
      angle  => "radians",
      theta  => "top clockwise",
      trange => "[0:2*pi]",
      rrange => "[0:$max_rec_distance]",
      rtics  => "1",
      ttics  => 'add ("N" 0, "NE" 45, "E" 90, "SE" 135, '.
                     '"S" 180, "SW" 225, "W" 270, "NW" 315)',
      colorbox => "",
    );
  # Set point style properties:
    $chart_enu_polar->set(
      style => "fill transparent solid 0.04 noborder",
      style => "circle radius 0.05",
    );

  # Set ENU multiplot chart title:
  my $chart_enu_title =
    SetReportTitle("Receiver Easting, Northing and Upping",
                   $ref_gen_conf, $marker_name, $ini_epoch);

  # Create parent object for ENU multiplot:
  my $chart_enu =
    Chart::Gnuplot->new(
      terminal => 'pngcairo size 874,540',
      output => $out_path."/$marker_name-rec-ENU-plot.png",
      title => $chart_enu_title,
      # NOTE: this does not works properly
      timestamp => "on",
    );

  # ENU individual charts for multiplot:
  my $chart_e =
    Chart::Gnuplot->new(
      grid => "on",
      ylabel => "Easting [m]",
      xrange => [$ini_epoch, $end_epoch],
      cbtics => 1,
      timeaxis => "x",
      xtics => { labelfmt => "%H:%M" },
   );
  my $chart_n =
    Chart::Gnuplot->new(
      grid => "on",
      ylabel => "Northing [m]",
      xrange => [$ini_epoch, $end_epoch],
      cbtics => 1,
      timeaxis => "x",
      xtics => { labelfmt => "%H:%M" },
   );
  my $chart_u =
    Chart::Gnuplot->new(
      grid => "on",
      xlabel => "Observation Epochs [HH::MM]",
      ylabel => "Upping [m]",
      xrange => [$ini_epoch, $end_epoch],
      cbtics => 1,
      timeaxis => "x",
      xtics => { labelfmt => "%H:%M" },
   );

  my $chart_clk_bias_title =
    SetReportTitle("Receiver Clock Bias",
                   $ref_gen_conf, $marker_name, $ini_epoch);

  # Create chart object for receiver clock bias:
  my $palette_label_std_cmm = 'cblabel "STD (1 sigma) [m]"';
  my $chart_clk_bias =
    Chart::Gnuplot->new(
      terminal => 'pngcairo size 874,540',
      grid => "on",
      output => $out_path."/$marker_name-rec-clk-bias-plot.png",
      title  => {
        text => $chart_clk_bias_title,
        font => ':Bold',
      },
      xlabel => "Observation Epochs [HH::MM]",
      ylabel => "Clock Bias [m]",
      xrange => [$ini_epoch, $end_epoch],
      timeaxis => "x",
      xtics => { labelfmt => "%H:%M" },
      $palette_label_std_cmm => "",
      timestamp =>  {
        fmt  => 'Created on %d/%m/%y %H:%M:%S',
        font => "Helvetica Italic, 10",
      },
    );


  # Build EN polar datasets:
  # EN polar dataset with horizontal accuracy:
  my $rec_en_hdop_polar_dataset =
    Chart::Gnuplot::DataSet->new(
      xdata => unpdl($pdl_rec_azimut->flat),
      ydata => unpdl($pdl_rec_distance->flat),
      zdata => unpdl($pdl_std_en->flat),
      style => "circles linecolor pal z",
      fill => { density => 0.8 },
    );
  # EN polar dataset with upping component:
  my $rec_enu_polar_dataset =
    Chart::Gnuplot::DataSet->new(
      xdata => unpdl($pdl_rec_azimut->flat),
      ydata => unpdl($pdl_rec_distance->flat),
      zdata => unpdl($pdl_rec_upping->flat),
      style => "circles linecolor pal z",
      fill => { density => 0.8 },
    );
  my $rec_en_epoch_polar_dataset =
    Chart::Gnuplot::DataSet->new(
      xdata => unpdl($pdl_rec_azimut->flat),
      ydata => unpdl($pdl_rec_distance->flat),
      zdata => unpdl($pdl_epoch_day_hour->flat),
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
      width => 2,
      timefmt => "%s",
    );
  # Build receiver N positions dataset:
  my $rec_n_dataset =
    Chart::Gnuplot::DataSet->new(
      xdata => unpdl($pdl_epochs->flat),
      ydata => unpdl($pdl_rec_northing->flat),
      zdata => unpdl($pdl_std_northing->flat),
      style => "lines linecolor pal z",
      width => 2,
      timefmt => "%s",
    );
  # Build receiver U positions dataset:
  my $rec_u_dataset =
    Chart::Gnuplot::DataSet->new(
      xdata => unpdl($pdl_epochs->flat),
      ydata => unpdl($pdl_rec_upping->flat),
      zdata => unpdl($pdl_std_upping->flat),
      style => "lines linecolor pal z",
      width => 2,
      timefmt => "%s",
    );
  # Build receiver clock bias dataset:
  my $rec_clk_bias_dataset =
    Chart::Gnuplot::DataSet->new(
      xdata => unpdl($pdl_epochs->flat),
      ydata => unpdl($pdl_rec_clk_bias->flat),
      zdata => unpdl($pdl_std_clk_bias->flat),
      style => "points pointtype 7 ps 0.3 linecolor pal z",
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
  # TODO: add grey lines in each component for indicating reference position
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

    # EN 2D polar plot:
    $chart_en_polar_hsigma->plot2d( $rec_en_hdop_polar_dataset );
    $chart_en_epoch_polar->plot2d( $rec_en_epoch_polar_dataset );
    $chart_enu_polar->plot2d( $rec_enu_polar_dataset );

  return TRUE;
}

sub PlotDilutionOfPrecission {
  my ($ref_gen_conf, $inp_path, $out_path, $marker_name) = @_;

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

  # TODO: consider adding sigma scale factor for standard deviations indicators

  # Set chart's titles:
  my $chart_ecef_title =
    SetReportTitle("ECEF Frame Accuracy Performance",
                   $ref_gen_conf, $marker_name, $ini_epoch);
  my $chart_enu_title =
    SetReportTitle("ENU Frame Accuracy Performance",
                   $ref_gen_conf, $marker_name, $ini_epoch);

  # Create chart for ECEF frame DOP:
  my $chart_ecef =
    Chart::Gnuplot->new(
      terminal => 'pngcairo size 874,540',
      output => $out_path."/DOP-ECEF-plot.png",
      title  => {
        text => $chart_ecef_title,
        font => ':Bold',
      },
      grid   => "on",
      xlabel => "Observation Epochs [HH::MM]",
      ylabel => "Sigma [m]",
      xrange => [$ini_epoch, $end_epoch],
      timeaxis => "x",
      xtics => { labelfmt => "%H:%M" },
      timestamp =>  {
        fmt => 'Created on %d/%m/%y %H:%M:%S',
        font => "Helvetica Italic, 10",
      },
   );

  # Create chart for ENU frame DOP:
  my $chart_enu =
    Chart::Gnuplot->new(
      terminal => 'pngcairo size 874,540',
      output => $out_path."/DOP-ENU-plot.png",
      title  => {
        text => $chart_enu_title,
        font => ':Bold',
      },
      grid   => "on",
      xlabel => "Observation Epochs [HH::MM]",
      ylabel => "Sigma [m]",
      xrange => [$ini_epoch, $end_epoch],
      timeaxis => "x",
      xtics => { labelfmt => "%H:%M" },
      timestamp =>  {
        fmt => 'Created on %d/%m/%y %H:%M:%S',
        font => "Helvetica Italic, 10",
      },
   );

  # Create DOP datasets:
  my $gdop_dataset =
    Chart::Gnuplot::DataSet->new(
      xdata => unpdl($pdl_epochs->flat),
      ydata => unpdl($pdl_gdop->flat),
      style => "points pointtype 7 ps 0.3",
      width => 3,
      timefmt => "%s",
      title => "Geometric Sigma",
    );
  my $pdop_dataset =
    Chart::Gnuplot::DataSet->new(
      xdata => unpdl($pdl_epochs->flat),
      ydata => unpdl($pdl_pdop->flat),
      style => "points pointtype 7 ps 0.3",
      width => 3,
      timefmt => "%s",
      title => "Position Sigma",
    );
  my $tdop_dataset =
    Chart::Gnuplot::DataSet->new(
      xdata => unpdl($pdl_epochs->flat),
      ydata => unpdl($pdl_tdop->flat),
      style => "points pointtype 7 ps 0.3",
      width => 3,
      timefmt => "%s",
      title => "Time Sigma",
    );
  my $hdop_dataset =
    Chart::Gnuplot::DataSet->new(
      xdata => unpdl($pdl_epochs->flat),
      ydata => unpdl($pdl_hdop->flat),
      style => "points pointtype 7 ps 0.3",
      width => 3,
      timefmt => "%s",
      title => "Horizontal Sigma",
    );
  my $vdop_dataset =
    Chart::Gnuplot::DataSet->new(
      xdata => unpdl($pdl_epochs->flat),
      ydata => unpdl($pdl_vdop->flat),
      style => "points pointtype 7 ps 0.3",
      width => 3,
      timefmt => "%s",
      title => "Vertical Sigma",
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

# ---------------------------------------------------------------------------- #
# Private Subroutines: #

sub RecPolarCoordinates {
  my ($pdl_east, $pdl_north) = @_;

  # Distance is computed as:
  my $pdl_distance = ($pdl_east**2 + $pdl_north**2)**0.5;

  # Get array lsit from piddles:
  my @east  = list( $pdl_east  -> flat() );
  my @north = list( $pdl_north -> flat() );

  # Init azmiut array:
  my @azimut;

  for my $i (keys @east) {
    my ($az, $ze, $dist) = Venu2AzZeDs($east[$i], $north[$i], 1);
    push(@azimut, $az);
  }

  my $pdl_azimut = pdl(@azimut);

  return ($pdl_azimut, $pdl_distance);
}

TRUE;
