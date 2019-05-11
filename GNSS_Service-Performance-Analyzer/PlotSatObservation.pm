#!/usr/bin/perl -w

# TODO: Package description goes here...

# Package declaration:
package PlotSatObservation;

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
  our @EXPORT_CONST = qw(  );

  # Define subroutines to export:
  our @EXPORT_SUB   = qw( &PlotSatelliteAvailability
                          &PlotSatelliteElevation
                          &PlotSatelliteSkyPath );

  # Merge constants and subroutines:
  our @EXPORT_OK = (@EXPORT_CONST, @EXPORT_SUB);

  # Define export tags:
  our %EXPORT_TAGS = ( ALL         => \@EXPORT_OK,
                       DEFAULT     => \@EXPORT,
                       CONSTANTS   => \@EXPORT_CONST,
                       SUBROUTINES => \@EXPORT_SUB );
}

# Import common perl modules:
# ---------------------------------------------------------------------------- #
use Carp;         # advanced warning and failure raise...
use strict;       # strict syntax and common mistakes advisory...

use Data::Dumper;       # var pretty print...
use feature qq(say);    # print adding line jump...
use feature qq(switch); # advanced switch statement...

# Load special tool modules:
# ---------------------------------------------------------------------------- #
# Perl Data Language (PDL) modules:
use PDL;
use PDL::NiceSlice;
use Math::Trig qq(pi);

# Perl-Gnuplot conection module:
use Chart::Gnuplot;

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

# Load general configuration and interfaces module:
# ---------------------------------------------------------------------------- #
use lib $ENV{ SRC_ROOT };
use GeneralConfiguration qq(:ALL);


# ---------------------------------------------------------------------------- #
# Subroutines:
# ---------------------------------------------------------------------------- #

# Public Subroutines: #
# ............................................................................ #
sub PlotSatelliteAvailability {
  my ($ref_gen_conf, $inp_path, $out_path, $sat_sys, $marker_name) = @_;

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

  # Chart's title:
  my $date = ( split(' ', BuildDateString(GPS2Date($ini_epoch))) )[0];
  my $chart_title =
    SAT_SYS_ID_TO_NAME->{$sat_sys}.
    " Satellite Availability from $marker_name station on $date";

  # Chart's grid:
  my $set_grid_cmm = "grid front";

  # Create chart object:
  my $chart =
    Chart::Gnuplot->new (
      terminal => 'pngcairo size 874,540',
      output => $out_path."/$sat_sys-sat-availability.png",
      title  => {
        text => $chart_title,
        font => ":Bold",
      },
      $set_grid_cmm  => "",
      ylabel => "Number of satellites",
      xrange => [$ini_epoch, $end_epoch],
      yrange => [5, $max_num_sat + 2],
      timeaxis => "x",
      xtics => { labelfmt => "%H:%M" },
      timestamp =>  {
        fmt => 'Created on %d/%m/%y %H:%M:%S',
        font => "Helvetica Italic, 10",
      },
    );

  # Configure datasets:
  my $num_avail_sat_dataset =
    Chart::Gnuplot::DataSet->new(
      xdata => unpdl($pdl_epochs->flat),
      ydata => unpdl($pdl_num_avail_sat->flat),
      style => "filledcurve y=0",
      color => "#9400D3",
      fill => { density => 0.3 },
      timefmt => "%s",
      title => "Available"
    );

  my $num_valid_obs_sat_dataset =
    Chart::Gnuplot::DataSet->new(
      xdata => unpdl($pdl_epochs->flat),
      ydata => unpdl($pdl_num_valid_obs_sat->flat),
      style => "filledcurve y=0",
      color => "#009E73",
      fill => { density => 0.4 },
      timefmt => "%s",
      title => "No-NULL Observation"
    );

  my $num_valid_nav_sat_dataset =
    Chart::Gnuplot::DataSet->new(
      xdata => unpdl($pdl_epochs->flat),
      ydata => unpdl($pdl_num_valid_nav_sat->flat),
      style => "filledcurve y=0",
      color => "#56B4E9",
      fill => { density => 0.5 },
      timefmt => "%s",
      title => "Valid Navigation"
    );

  my $num_valid_lsq_sat_dataset =
    Chart::Gnuplot::DataSet->new(
      xdata => unpdl($pdl_epochs->flat),
      ydata => unpdl($pdl_num_valid_lsq_sat->flat),
      style => "filledcurve y=0",
      color => "#E69F00",
      fill => { density => 0.6 },
      timefmt => "%s",
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
  my ($ref_gen_conf, $inp_path, $out_path, $sat_sys, $marker_name) = @_;

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

  # Chart's title:
  my $date = ( split(' ', BuildDateString(GPS2Date($ini_epoch))) )[0];
  my $chart_title =
    SAT_SYS_ID_TO_NAME->{$sat_sys}.
    " Satellite Observed Elevation from $marker_name station on $date";

  # Create plot object:
  my $chart =
    Chart::Gnuplot->new (
      terminal => 'pngcairo size 874,540',
      output => $out_path."/$sat_sys-sat-elevation.png",
      title  => {
        text => $chart_title,
        font => ':Bold',
      },
      grid   => "on",
      ylabel => "Elevation [deg]",
      xrange => [$ini_epoch, $end_epoch],
      yrange => [0, 90],
      timeaxis => "x",
      xtics => { labelfmt => "%H:%M" },
      legend => {
        position => "outside top",
      },
      timestamp =>  {
        fmt => 'Created on %d/%m/%y %H:%M:%S',
        font => "Helvetica Italic, 10",
      },
    );

  # Satellite mask dataset:
  my $pdl_sat_mask =
     $pdl_sat_elevation($ref_file_layout->{ITEMS}{SatMask}{INDEX});

  my $sat_mask_dataset =
    Chart::Gnuplot::DataSet->new(
      xdata => unpdl($pdl_epochs->flat),
      ydata => unpdl($pdl_sat_mask->flat),
      style => "filledcurve y=0",
      color => "#99555753",
      timefmt => "%s",
      title => "Mask",
    );

  # Init array to store dataset objects:
  my @elevation_datasets;

  for my $sat (sort @avail_sats)
  {
    # Retrieve elevation values:
    my $pdl_elevation =
       $pdl_sat_elevation($ref_file_layout->{ITEMS}{$sat}{INDEX});

    # Set elevations dataset:
    my $dataset =
      Chart::Gnuplot::DataSet->new(
        xdata => unpdl($pdl_epochs->flat),
        ydata => unpdl($pdl_elevation->flat),
        style => "linespoints pointinterval 50 ".
                 "pointsize 0.75",
        width => 2,
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
  my ($ref_gen_conf, $inp_path, $out_path, $sat_sys, $marker_name) = @_;

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

  my ($num_epoch_records, $num_epochs) = dims($pdl_epochs);

  # Retrieve days's 00:00:00 in GPS epoch format:
  my $ini_day_epoch = Date2GPS( (GPS2Date($ini_epoch))[0..2], 0, 0, 0 );
  my $pdl_epoch_day_hour = ($pdl_epochs - $ini_day_epoch)/SECONDS_IN_HOUR;

  # Retrieve observed satellites from input file header:
  my @avail_sats =
    grep( /^$sat_sys\d{2}$/, (keys %{ $ref_azimut_file_layout->{ITEMS} }) );

  # Chart's title:
  my $date = ( split(' ', BuildDateString(GPS2Date($ini_epoch))) )[0];
  my $chart_title =
    SAT_SYS_ID_TO_NAME->{$sat_sys}.
    " Satellite Sky-Plot from $marker_name station on $date";

  # Palette configuration:
  my $palette_color_cmm =
    'palette defined (0 0 0 0, 1 0 0 1, 3 0 1 0, 4 1 0 0, 6 1 1 1)';
  my $palette_label_cmm =
    'cblabel "Osbervation Epoch [h]"';

  # Set chart object:
  my $chart =
    Chart::Gnuplot->new (
    terminal => 'pngcairo size 874,874',
    output => $out_path."/$sat_sys-sat-sky-plot.png",
    title  => {
      text => $chart_title,
      font => ':Bold',
    },
    border => undef,
    xtics  => undef,
    ytics  => undef,
    cbtics => 0.25,
    legend => {
      position => "top left",
    },
    $palette_color_cmm => "",
    $palette_label_cmm => "",
    timestamp =>  {
      fmt  => 'Created on %d/%m/%y %H:%M:%S',
      font => "Helvetica Italic, 10",
    },
  );

  # Set polar options:
  $chart->set(
    size   => "0.9, 0.9",
    origin => "0.085, 0.06",
    polar  => "",
    grid   => "polar front",
    'border polar' => '',
    angle  => "degrees",
    theta  => "top clockwise",
    trange => "[0:360]",
    rrange => "[90:0]",
    rtics  => "15",
    ttics  => 'add ("N" 0, "NE" 45, "E" 90, "SE" 135, '.
                   '"S" 180, "SW" 225, "W" 270, "NW" 315)',
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
      style => "filledcurve y=0",
      title => "Mask",
      color => "#99555753",
    );

  # Init array to hold satellite sky path datasets:
  my @sat_datasets;

  for my $sat (sort @avail_sats)
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
        zdata => unpdl($pdl_epoch_day_hour->flat),
        style => "lines linecolor pal z",
        width => 5,
      );

    # Retrieve median azimut and elevation values:
    my ( $med_azimut, $med_elevation ) =
      RetrieveMedianValues( NULL_DATA,
                            unpdl($pdl_azimut->flat),
                            unpdl($pdl_elevation->flat) );

    # Watch for undef values:
    $med_azimut    = NULL_DATA unless (defined $med_azimut);
    $med_elevation = NULL_DATA unless (defined $med_elevation);

    # Dataset for labelling the satellites:
    my $label_dataset =
      Chart::Gnuplot::DataSet->new(
        xdata => [$med_azimut],
        ydata => [$med_elevation],
        zdata => [$sat],
        style => "labels font \"Ubuntu,10\"",
      );

    push(@sat_datasets, $dataset, $label_dataset);
  }

  $chart->plot2d((
    @sat_datasets,
    $sat_mask_dataset
  ));

  return TRUE;
}

# Private Subroutines: #
# ............................................................................ #
sub RetrieveMedianValues {
  my ($null_value, @array_ref_list) = @_;

  # Init median values to return:
  my @median_values_list;

  # Iterate over the input array references:
  for my $ref_array (@array_ref_list)
  {
    # De-reference array:
    my @array = @{ $ref_array };

    # Filter no-valid values:
    @array = grep{ $_ ne $null_value } @array;

    # Compute array size after filtering:
    my $arr_size = scalar(@array);

    # Median value corresponds to middle values in the array:
    # NOTE: median index is "floored"
    my $median_value = $array[ int($arr_size/2) ];

    push(@median_values_list, $median_value);
  }

  return @median_values_list;
}


TRUE;
