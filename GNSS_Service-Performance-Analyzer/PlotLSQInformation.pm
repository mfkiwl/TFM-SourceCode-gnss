#!/usr/bin/perl -w

# TODO: Package description goes here...

# Package declaration:
package PlotLSQInformation;

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
  our @EXPORT_SUB   = qw( &PlotLSQEpochEstimation );

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

sub PlotLSQEpochEstimation {
  my ($ref_gen_conf, $inp_path, $out_path, $marker_name) = @_;

  # Load dumper file:
  my $ref_file_layout =
    GetFileLayout( join('/', ($inp_path, "LSQ-epoch-report-info.out")),
                   3, $ref_gen_conf->{DATA_DUMPER}{DELIMITER} );

  # Make piddle from loaded file:
  my $pdl_lsq_info = pdl( LoadFileByLayout($ref_file_layout) );

  # Load epochs:
  my $pdl_epochs = $pdl_lsq_info($ref_file_layout->{ITEMS}{EpochGPS}{INDEX});

  # First and last observation epochs:
  my $ini_epoch = min($pdl_epochs);
  my $end_epoch = max($pdl_epochs);

  # Retrieve the following LSQ info:
    # Number of iterations:
    my $pdl_num_iter =
       $pdl_lsq_info($ref_file_layout->{ITEMS}{NumIter}{INDEX});

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

    # Retrieve max number of observations:
    my $max_deg_of_free = max($pdl_deg_of_freedom);

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

  # Set's chart titles:
  # Get initial epoch date in 'yyyy/mo/dd' format:
  my $date = ( split(' ', BuildDateString(GPS2Date($ini_epoch))) )[0];
  my $chart_lsq_rpt_title = "LSQ routine report from $marker_name on $date";
  my $chart_x_title  = "LSQ ECEF X parameter report from $marker_name on $date";
  my $chart_y_title  = "LSQ ECEF Y parameter report from $marker_name on $date";
  my $chart_z_title  = "LSQ ECEF Z parameter report from $marker_name on $date";
  my $chart_dt_title = "LSQ DT parameter report from $marker_name on $date";

  # Set chart objects:
    # LSQ report:
    my $chart_lsq_rpt =
      Chart::Gnuplot->new(
        terminal => 'pngcairo size 874,540',
        output => $out_path."/LSQ-report.png",
        title  => {
          text => $chart_lsq_rpt_title,
          font => ':Bold',
        },
        grid   => "on",
        xlabel => "Observation Epochs [HH::MM]",
        xrange => [$ini_epoch, $end_epoch],
        timeaxis => "x",
        xtics => { labelfmt => "%H:%M" },
        yrange => [0, $max_deg_of_free + 1],
        legend => {
          position => "inside top",
          order => "horizontal",
          align => "center",
          sample   => {
               length => 2,
           },
        },
        timestamp =>  {
          fmt  => 'Created on %d/%m/%y %H:%M:%S',
          font => "Helvetica Italic, 10",
        },
      );

    # Approximate parameter report (multiplot):
    # Parent charts. One per parameter:
    my $chart_parameter_x =
      Chart::Gnuplot->new(
        terminal => 'pngcairo size 874,540',
        output => $out_path."/LSQ-X-parameter-report.png",
        title  => $chart_x_title,
        timestamp =>  {
          fmt  => 'Created on %d/%m/%y %H:%M:%S',
          font => "Helvetica Italic, 10",
        },
      );
    my $chart_parameter_y =
      Chart::Gnuplot->new(
        terminal => 'pngcairo size 874,540',
        output => $out_path."/LSQ-Y-parameter-report.png",
        title  => $chart_y_title,
        timestamp =>  {
          fmt  => 'Created on %d/%m/%y %H:%M:%S',
          font => "Helvetica Italic, 10",
        },
      );
    my $chart_parameter_z =
      Chart::Gnuplot->new(
        terminal => 'pngcairo size 874,540',
        output => $out_path."/LSQ-Z-parameter-report.png",
        title  => $chart_z_title,
        timestamp =>  {
          fmt  => 'Created on %d/%m/%y %H:%M:%S',
          font => "Helvetica Italic, 10",
        },
      );
    my $chart_parameter_dt =
      Chart::Gnuplot->new(
        terminal => 'pngcairo size 874,540',
        output => $out_path."/LSQ-DT-parameter-report.png",
        title  => $chart_dt_title,
        timestamp =>  {
          fmt  => 'Created on %d/%m/%y %H:%M:%S',
          font => "Helvetica Italic, 10",
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

      # For Y, Z, and DT parameters, copy from X parameter objects:
      my $chart_y_parameter        = $chart_x_parameter       -> copy;
      my $chart_delta_y_parameter  = $chart_delta_x_parameter -> copy;
      my $chart_z_parameter        = $chart_x_parameter       -> copy;
      my $chart_delta_z_parameter  = $chart_delta_x_parameter -> copy;
      my $chart_dt_parameter       = $chart_x_parameter       -> copy;
      my $chart_delta_dt_parameter = $chart_delta_x_parameter -> copy;

  # Set dataset objects:

    # *********************** #
    # LSQ general information #
    # *********************** #

    # LSQ status:
    my $lsq_st_dataset =
      Chart::Gnuplot::DataSet->new(
        xdata => unpdl($pdl_epochs->flat),
        ydata => unpdl($pdl_lsq_st->flat),
        style => "filledcurve y=0",
        color => "#22729FCF",
        timefmt => "%s",
        title => "LSQ Status",
      );
    # Convergence flag:
    my $convergence_st_dataset =
      Chart::Gnuplot::DataSet->new(
        xdata => unpdl($pdl_epochs->flat),
        ydata => unpdl($pdl_convergence_st->flat),
        style => "points pt 5 ps 0.5",
        color => "#009E73",
        timefmt => "%s",
        title => "Convergence",
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
        title => "Num. of Obs.",
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
        style => "filledcurve y=0",
        color => "#99F0E442",
        width => 3,
        timefmt => "%s",
        title => "Deg. of Free.",
      );
    # Ex-post standard deviation estimator:
    my $std_dev_est_dataset =
      Chart::Gnuplot::DataSet->new(
        xdata => unpdl($pdl_epochs->flat),
        ydata => unpdl($pdl_std_dev_est->flat),
        style => "lines",
        color => "#EF2929",
        width => 3,
        timefmt => "%s",
        title => "Ex-Post STD",
      );

    # ************************* #
    # LSQ parameter information #
    # ************************* #

    # ECEF X parameter estimation:
    my $est_x_parameter_dataset =
      Chart::Gnuplot::DataSet->new(
        xdata => unpdl($pdl_epochs->flat),
        ydata => unpdl($pdl_est_x->flat),
        style => "points pt 5 ps 0.2",
        width => 2,
        timefmt => "%s",
        title => "Estimated X",
      );
    my $apx_x_parameter_dataset =
      Chart::Gnuplot::DataSet->new(
        xdata => unpdl($pdl_epochs->flat),
        ydata => unpdl($pdl_apx_x->flat),
        style => "points pt 7 ps 0.2",
        width => 2,
        timefmt => "%s",
        title => "Approximate X",
      );
    my $delta_x_parameter_dataset =
      Chart::Gnuplot::DataSet->new(
        xdata => unpdl($pdl_epochs->flat),
        ydata => unpdl($pdl_delta_x->flat),
        zdata => unpdl($pdl_std_dev_est->flat),
        style => "lines pal z",
        width => 2,
        timefmt => "%s",
      );
    # ECEF Y parameter estimation:
    my $est_y_parameter_dataset =
      Chart::Gnuplot::DataSet->new(
        xdata => unpdl($pdl_epochs->flat),
        ydata => unpdl($pdl_est_y->flat),
        style => "points pt 5 ps 0.2",
        width => 2,
        timefmt => "%s",
        title => "Estimated Y",
      );
    my $apx_y_parameter_dataset =
      Chart::Gnuplot::DataSet->new(
        xdata => unpdl($pdl_epochs->flat),
        ydata => unpdl($pdl_apx_y->flat),
        style => "points pt 7 ps 0.2",
        width => 2,
        timefmt => "%s",
        title => "Approximate Y",
      );
    my $delta_y_parameter_dataset =
      Chart::Gnuplot::DataSet->new(
        xdata => unpdl($pdl_epochs->flat),
        ydata => unpdl($pdl_delta_y->flat),
        zdata => unpdl($pdl_std_dev_est->flat),
        style => "lines pal z",
        width => 2,
        timefmt => "%s",
      );
    # ECEF Z parameter estimation:
    my $est_z_parameter_dataset =
      Chart::Gnuplot::DataSet->new(
        xdata => unpdl($pdl_epochs->flat),
        ydata => unpdl($pdl_est_z->flat),
        style => "points pt 5 ps 0.2",
        width => 2,
        timefmt => "%s",
        title => "Estimated Z",
      );
    my $apx_z_parameter_dataset =
      Chart::Gnuplot::DataSet->new(
        xdata => unpdl($pdl_epochs->flat),
        ydata => unpdl($pdl_apx_z->flat),
        style => "points pt 7 ps 0.2",
        width => 2,
        timefmt => "%s",
        title => "Approximate Z",
      );
    my $delta_z_parameter_dataset =
      Chart::Gnuplot::DataSet->new(
        xdata => unpdl($pdl_epochs->flat),
        ydata => unpdl($pdl_delta_z->flat),
        zdata => unpdl($pdl_std_dev_est->flat),
        style => "lines pal z",
        width => 2,
        timefmt => "%s",
      );
    # Receiver clock (DT) parameter estimation:
    my $est_dt_parameter_dataset =
      Chart::Gnuplot::DataSet->new(
        xdata =>
          unpdl($pdl_epochs->flat->slice("1:$t_1")),
        ydata =>
          unpdl($pdl_est_dt->flat->slice("1:$t_1")),
        style => "points pt 5 ps 0.2",
        width => 2,
        timefmt => "%s",
        title => "Estimated DT",
      );
    my $apx_dt_parameter_dataset =
      Chart::Gnuplot::DataSet->new(
        xdata =>
          unpdl($pdl_epochs->flat->slice("1:$t_1")),
        ydata =>
          unpdl($pdl_apx_dt->flat->slice("1:$t_1")),
        style => "points pt 7 ps 0.2",
        width => 2,
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
        width => 2,
        timefmt => "%s",
      );

  # Plot datsets in their respective charts:
    # LSQ report plot:
    $chart_lsq_rpt->plot2d((
      $deg_of_free_dataset,
      $lsq_st_dataset,
      $convergence_st_dataset,
      $num_iter_dataset,
      $std_dev_est_dataset,
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

TRUE;
