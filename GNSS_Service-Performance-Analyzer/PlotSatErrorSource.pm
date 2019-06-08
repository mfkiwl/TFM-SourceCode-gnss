#!/usr/bin/perl -w

# TODO: Package description goes here...

# Package declaration:
package PlotSatErrorSource;

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
  our @EXPORT_SUB   = qw( &PlotSatelliteResiduals
                          &PlotSatelliteIonosphereDelay
                          &PlotSatelliteTroposphereDelay );

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
# Public Subroutines:

sub PlotSatelliteResiduals {
  my ($ref_gen_conf, $inp_path, $out_path, $sat_sys, $marker_name) = @_;

  # Load dumper file:
  my $ref_file_layout =
    GetFileLayout( join('/', ($inp_path, "$sat_sys-sat-residuals.out")), 7,
                   $ref_gen_conf->{DATA_DUMPER}{DELIMITER} );

  my $pdl_residuals = pdl( LoadFileByLayout($ref_file_layout) );

  # Retrieve maximum absolute residual value:
  my $max_residual = max($pdl_residuals->slice("3:"));
  my $min_residual = min($pdl_residuals->slice("3:"));

  my $max_abs_residual = max( pdl [abs($max_residual), abs($min_residual)] );

  PrintComment(*STDOUT,
    "Max res = $max_residual",
    "Min res = $min_residual",
    "Max abs res = $max_abs_residual");

  # Load epochs:
  my $pdl_epochs = $pdl_residuals($ref_file_layout->{ITEMS}{EpochGPS}{INDEX});

  my $ini_epoch = min($pdl_epochs);
  my $end_epoch = max($pdl_epochs);

  # Retrieve observed satellites:
  my @avail_sats =
    sort( grep(/^$sat_sys\d{2}$/, (keys %{$ref_file_layout->{ITEMS}})) );
  # Retrieve command for adding satellite ID tics on Y axis:
  my $sat_id_ytics_cmm = RetrieveSatYTicsCommand(@avail_sats);

  # Set chart's title:
  my $chart_title =
    SetReportTitle("Satellite Computed Residuals",
                   $ref_gen_conf, $marker_name, $ini_epoch);

  # Set commands for color palette:
  my $palette_color_cmm = 'palette rgb 33,13,10';
  my $palette_label_cmm = 'cblabel "Residual [m]"';
  my $palette_range_cmm = "cbrange [-$max_abs_residual:$max_abs_residual]";

  PrintComment(*STDOUT, $palette_range_cmm);

  # Set chart object:
  my $chart =
    Chart::Gnuplot->new(
      terminal => 'pngcairo size 874,540',
      output => $out_path."/$sat_sys-sat-residuals.png",
      title  => {
        text => $chart_title,
        font => ':Bold',
      },
      grid   => "on",
      xlabel => "Observation Epochs [HH::MM]",
      ylabel => "Satellite PRN",
      xrange => [$ini_epoch, $end_epoch],
      yrange => [0, scalar(@avail_sats) + 1],
      timeaxis => "x",
      xtics => { labelfmt => "%H:%M" },
      $sat_id_ytics_cmm => "",
      $palette_label_cmm => "",
      $palette_color_cmm => "",
      # $palette_range_cmm => "",
      timestamp =>  {
        fmt => 'Created on %d/%m/%y %H:%M:%S',
        font => "Helvetica Italic, 10",
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
  my ($ref_gen_conf, $inp_path, $out_path, $sat_sys, $marker_name) = @_;

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

  # Set chart's title:
  my $chart_title =
    SetReportTitle("Satellite Computed Ionosphere Delay",
                   $ref_gen_conf, $marker_name, $ini_epoch);

  # Set commands for color palette:
  my $palette_color_cmm = 'palette rgb 30,31,32';
  my $palette_label_cmm = 'cblabel "Delay [m]"';

  # Set chart object:
  my $chart =
    Chart::Gnuplot->new(
      terminal => 'pngcairo size 874,540',
      output => $out_path."/$sat_sys-sat-iono-delay.png",
      title  => {
        text => $chart_title,
        font => ':Bold',
      },
      grid   => "on",
      xlabel => "Observation Epochs [HH::MM]",
      ylabel => "Satellite PRN",
      xrange => [$ini_epoch, $end_epoch],
      yrange => [0, scalar(@avail_sats) + 1],
      timeaxis => "x",
      xtics => { labelfmt => "%H:%M" },
      $sat_id_ytics_cmm => "",
      $palette_color_cmm => "",
      $palette_label_cmm => "",
      timestamp =>  {
        fmt => 'Created on %d/%m/%y %H:%M:%S',
        font => "Helvetica Italic, 10",
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
  my ($ref_gen_conf, $inp_path, $out_path, $sat_sys, $marker_name) = @_;

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

  # Set commands for color palette:
  my $palette_color_cmm = 'palette rgb 30,31,32';
  my $palette_label_cmm = 'cblabel "Delay [m]"';

  # Set chart's title:
  my $date = ( split(' ', BuildDateString(GPS2Date($ini_epoch))) )[0];
  my $chart_title =
    SetReportTitle("Satellite Computed Troposphere Delay",
                   $ref_gen_conf, $marker_name, $ini_epoch);

  # Set chart object:
  my $chart =
    Chart::Gnuplot->new(
      terminal => 'pngcairo size 874,540',
      output => $out_path."/$sat_sys-sat-tropo-delay.png",
      title  => {
        text => $chart_title,
        font => ':Bold',
      },
      grid   => "on",
      xlabel => "Observation Epochs [HH::MM]",
      ylabel => "Satellite PRN",
      xrange => [$ini_epoch, $end_epoch],
      yrange => [0, scalar(@avail_sats) + 1],
      timeaxis => "x",
      xtics => { labelfmt => "%H:%M" },
      $sat_id_ytics_cmm => "",
      $palette_color_cmm => "",
      $palette_label_cmm => "",
      timestamp =>  {
        fmt => 'Created on %d/%m/%y %H:%M:%S',
        font => "Helvetica Italic, 10",
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

# ---------------------------------------------------------------------------- #
# Private Subroutines: #

sub RetrieveSatYTicsCommand {
  my @sat_list = @_;

  # Init array to store satellite ID and index pair:
  my @sat_values;

  # Write empty value at first record:
  my $first_record_index = 0;
  push(@sat_values, "\"\" $first_record_index");

  # Build satellite ID and datellite index value pair:
  for (my $i = 0; $i < scalar(@sat_list); $i += 1) {
    my $sat = $sat_list[$i];
    my $sat_index = $i + 1;
    push(@sat_values, "\"$sat\" $sat_index");
  }

  # Write empty value at last record:
  my $last_record_index = scalar(@sat_list) + 1;
  push(@sat_values, "\"\" $last_record_index");

  # Write command:
  # example: 'ytics add ("N" 0, "E" 90, "S" 180, "W" 270) font ":Bold"'
  my $command = 'ytics add ('.join(', ', @sat_values).')';

  # Return command:
  return $command;
}

TRUE;
