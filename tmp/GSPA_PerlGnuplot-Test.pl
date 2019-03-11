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

# *********************************************** #
#    2.a Easting/Northing point densisty plot:
# *********************************************** #

#    2.b Upping plot:
#    2.c Easting/Northing/Upping point density 3D plot:


# 3. Ex-post Dilution of Precission:
#    3.a ECEF frame DOP:
#    3.b ENU frame DOP:


# 4. Least Squeares Estimation plots:
#    4.a Number of iterations:
#    4.b Ex-post Standard Deviation Estimator:
#    4.c Delta Parameter estimation:
#    4.d Residuals by satellite:
#    4.e Elevation by satellite (same as 1.b plot)


# 5. Ionosphere and Troposphere Delay Estimation plots:
#    5.a Ionosphere Computed Delay by satellite:
#    5.b Troposphere Computed delay by satellite:
#    5.c Elevation by satellite (same as 1.b plot)


# ============================================================================ #
# Private Functions:                                                           #
# ============================================================================ #
sub PlotConstellationAvailability {
  my ($ref_gen_conf, $sat_sys, $inp_path, $out_path) = @_;

  # Select dumper file:
  my $ref_file_layout =
     GetFileLayout($inp_path."/$sat_sys-num-sat-info.out", 4, ";");

  my $ref_num_sat_info = LoadFile( $ref_file_layout->{FILE}{PATH},
                                   $ref_file_layout->{FILE}{HEAD},
                                   $ref_gen_conf->{DATA_DUMPER}{DELIMITER} );

  my $pdl_num_sat_info = pdl($ref_num_sat_info);


  # For each epoch Retrieve:
    # Set of epochs:
    my $pdl_epochs =
       $pdl_num_sat_info($ref_file_layout->{ITEMS}{Epoch}{INDEX});
    # my ( $num_items, $num_epochs ) = $pdl_num_sat_info->dims;
    # my $pdl_epoch_sequence = sequence($num_epochs);

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

  # Retrieve some statistics for configuring properly the plot:
  my $max_num_sat = max($pdl_num_avail_sat);
  my $min_epoch = min($pdl_epochs);
  my $max_epoch = max($pdl_epochs);


  # Create plot object:
  my $chart =
    Chart::Gnuplot->new (
                          output => $out_path."/$sat_sys-availability.png",
                          title  => "Satellite System '$sat_sys' Availability",
                          xlabel => "Observation Epochs",
                          ylabel => "Number of satellites",
                          xrange => [$min_epoch, $max_epoch],
                          yrange => [5, $max_num_sat + 2],
                          grid   => "on",
                          timeaxis => "x",
                          xtics => { labelfmt => "%H:%M" },
                          timestamp =>  {
                                          fmt  => '%d/%m/%y %H:%M',
                                          font => "Helvetica :Italic",
                                        },
                        );

  # Configure datasets:
  my $num_avail_sat_dataset =
    Chart::Gnuplot::DataSet->new( xdata => unpdl($pdl_epochs->flat),
                                  ydata => unpdl($pdl_num_avail_sat->flat),
                                  style => "filledcurve y=0",
                                  timefmt => "%s",
                                  fill => { density => 0.3 },
                                  title => "Available" );

  my $num_valid_obs_sat_dataset =
    Chart::Gnuplot::DataSet->new( xdata => unpdl($pdl_epochs->flat),
                                  ydata => unpdl($pdl_num_valid_obs_sat->flat),
                                  style => "filledcurve y=0",
                                  timefmt => "%s",
                                  fill => { density => 0.4 },
                                  title => "No-NULL Observation" );

  my $num_valid_nav_sat_dataset =
    Chart::Gnuplot::DataSet->new( xdata => unpdl($pdl_epochs->flat),
                                  ydata => unpdl($pdl_num_valid_nav_sat->flat),
                                  style => "filledcurve y=0",
                                  timefmt => "%s",
                                  fill => { density => 0.5 },
                                  title => "Valid Navigation" );

  my $num_valid_lsq_sat_dataset =
    Chart::Gnuplot::DataSet->new( xdata => unpdl($pdl_epochs->flat),
                                  ydata => unpdl($pdl_num_valid_lsq_sat->flat),
                                  style => "filledcurve y=0",
                                  timefmt => "%s",
                                  fill => { density => 0.6 },
                                  title => "Valid for LSQ routine" );


  # Plot Datasets:
  $chart->plot2d(
                  $num_avail_sat_dataset,
                  $num_valid_obs_sat_dataset,
                  $num_valid_nav_sat_dataset,
                  $num_valid_lsq_sat_dataset
                );


}

sub PlotSatelliteElevation {
  my ($ref_gen_conf, $sat_sys, $inp_path, $out_path) = @_;

  # Select dumper file:
  my $ref_file_layout =
     GetFileLayout($inp_path."/$sat_sys-sat-elevation.out", 5, ";");

  my $ref_sat_elevation = LoadFile( $ref_file_layout->{FILE}{PATH},
                                   $ref_file_layout->{FILE}{HEAD},
                                   $ref_gen_conf->{DATA_DUMPER}{DELIMITER} );

  my $pdl_sat_elevation = pdl($ref_sat_elevation);


  # Set of epochs:
  my $pdl_epochs =
     $pdl_sat_elevation($ref_file_layout->{ITEMS}{Epoch}{INDEX});

  my $min_epoch = min($pdl_epochs);
  my $max_epoch = max($pdl_epochs);

  # Observed satellites:
  my @avail_sats =
    grep( /^$sat_sys\d{2}$/, (keys %{ $ref_file_layout->{ITEMS} }) );

  # Create plot object:
  my $chart =
    Chart::Gnuplot->new (
                          output => $out_path."/$sat_sys-elevation.png",
                          title  => "Satellite System '$sat_sys' Elevation",
                          xlabel => "Observation Epochs",
                          ylabel => "Elevation [deg]",
                          xrange => [$min_epoch, $max_epoch],
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
    Chart::Gnuplot::DataSet->new( xdata => unpdl($pdl_epochs->flat),
                                  ydata => unpdl($pdl_sat_mask->flat),
                                  style => "lines",
                                  timefmt => "%s",
                                  title => "Mask",
                                  width => 5,
                                  linetype => 8 );

  # Satellite elevation datasets:
  my @elevation_datasets;

  for my $sat (@avail_sats) {

    # Retrieve elevation values:
    my $pdl_elevation =
       $pdl_sat_elevation($ref_file_layout->{ITEMS}{$sat}{INDEX});

    # Set elevationd dataset:
    my $dataset =
      Chart::Gnuplot::DataSet->new( xdata => unpdl($pdl_epochs->flat),
                                    ydata => unpdl($pdl_elevation->flat),
                                    style => "lines",
                                    timefmt => "%s",
                                    title => "$sat" );

    push(@elevation_datasets, $dataset);

  }

  # Plot elevations:
  $chart->plot2d((@elevation_datasets, $sat_mask_dataset));


}

sub PlotSatelliteSkyPath {
  my ($ref_gen_conf, $sat_sys, $inp_path, $out_path) = @_;

  # Select dumper files:
  my $ref_azimut_file_layout =
     GetFileLayout($inp_path."/$sat_sys-sat-azimut.out", 5, ";");

  my $ref_elevation_file_layout =
     GetFileLayout($inp_path."/$sat_sys-sat-elevation.out", 5, ";");

  my $ref_sat_azimut =
    LoadFile( $ref_azimut_file_layout->{FILE}{PATH},
              $ref_azimut_file_layout->{FILE}{HEAD},
              $ref_gen_conf->{DATA_DUMPER}{DELIMITER} );
  my $ref_sat_elevation =
    LoadFile( $ref_elevation_file_layout->{FILE}{PATH},
              $ref_elevation_file_layout->{FILE}{HEAD},
              $ref_gen_conf->{DATA_DUMPER}{DELIMITER} );

  my $pdl_sat_azimut    = pdl($ref_sat_azimut);
  my $pdl_sat_elevation = pdl($ref_sat_elevation);

  # Set of epochs:
  my $pdl_epochs =
     $pdl_sat_elevation($ref_azimut_file_layout->{ITEMS}{Epoch}{INDEX});

  my $min_epoch = min($pdl_epochs);
  my $max_epoch = max($pdl_epochs);

  # Observed satellites:
  my @avail_sats =
    grep( /^$sat_sys\d{2}$/, (keys %{ $ref_azimut_file_layout->{ITEMS} }) );

  say join(', ', @avail_sats);

  # Set chart object:
  my $chart =
    Chart::Gnuplot->new (
                          output => $out_path."/$sat_sys-sky-plot.png",
                          title  => "Satellite System '$sat_sys' Sky Plot",
                          border => undef,
                          xtics => undef,
                          ytics => undef,
                          timestamp =>  {
                                          fmt  => '%d/%m/%y %H:%M',
                                          font => "Helvetica :Italic",
                                        },
                        );

  # Set polar options:
  $chart->set(
                size => "square",
                polar => "",
                grid => "polar",
                angle => "degrees",
                theta => "top clockwise",
                trange => "[0:360]",
                rrange => "[90:0]",
                rtics => "30",
                ttics => 'add ("N" 0, "E" 90, "S" 180, "W" 270) font ":Bold"',
                colorbox => "",
              );

  # Set mask datset:
  my $pdl_sat_mask =
    $pdl_sat_elevation($ref_elevation_file_layout->{ITEMS}{SatMask}{INDEX});

  my @azimut;
  my @mask;

  push(@azimut, $_) for (0..360);
  push(@mask, sclr($pdl_sat_mask)) for (0..360);

  my $sat_mask_dataset =
    Chart::Gnuplot::DataSet->new( xdata => \@azimut,
                                  ydata => \@mask,
                                  style => "lines",
                                  title => "Mask",
                                  width => 5,
                                  linetype => 8 );

  # Observed satellites:
  my @sat_datasets;

  for my $sat (@avail_sats) {
    my $pdl_azimut =
      $pdl_sat_azimut($ref_azimut_file_layout->{ITEMS}{$sat}{INDEX});

    my $pdl_elevation =
       $pdl_sat_elevation($ref_elevation_file_layout->{ITEMS}{$sat}{INDEX});

    my $dataset =
      Chart::Gnuplot::DataSet->new( xdata => unpdl($pdl_azimut->flat),
                                    ydata => unpdl($pdl_elevation->flat),
                                    zdata => unpdl($pdl_epochs->flat),
                                    style => "lines linecolor pal z",
                                    # title => "$sat",
                                    width => 3 );
    push(@sat_datasets, $dataset);
  }

  $chart->plot2d((@sat_datasets, $sat_mask_dataset));

}

sub GetFileLayout {
  my ($file_path, $head_line, $delimiter) = @_;

  my $ref_file_layout = {};

  $ref_file_layout->{FILE}{PATH} = $file_path;
  $ref_file_layout->{FILE}{HEAD} = $head_line;

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

sub LoadFile {
  my ($file_path, $head, $delimiter) = @_;

  my $ref_array = [];

  my $fh; open($fh, '<', $file_path) or die "Could not open $!";

    SkipLines($fh, $head);

    while (my $line = <$fh>) {
      push( @{$ref_array}, [split(/$delimiter/, $line)] );
    }

  close($fh);

  return $ref_array;
}
