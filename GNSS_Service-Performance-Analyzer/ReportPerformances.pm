#!/usr/bin/perl -w

# TODO: Package description goes here...

# Package declaration:
package ReportPerformances;

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
  our @EXPORT_SUB   = qw( &ReportPositionError
                          &ReportPositionAccuracy
                          &ReportPositionIntegrity );

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

# ---------------------------------------------------------------------------- #
# Load special tool modules:

# Perl Data Language (PDL) modules:
use PDL;
use PDL::NiceSlice;
use Math::Trig qq(pi);

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

# ---------------------------------------------------------------------------- #
# Load general configuration and interfaces module:

use lib SRC_ROOT_PATH;
use GeneralConfiguration qq(:ALL);

# ---------------------------------------------------------------------------- #
# Public Subroutines: #

sub ReportPositionAccuracy {
  my ($ref_gen_conf, $inp_path, $out_path, $marker_name) = @_;

  # Retrieve accuracy indicators from GRPP files:

  # Load dumper file:
  my $ref_file_layout =
     GetFileLayout( join('/', ($inp_path, "DOP-info.out")),
                    5, $ref_gen_conf->{DATA_DUMPER}{DELIMITER} );

  # Make piddle from loaded file:
  my $pdl_acc_info = pdl( LoadFileByLayout($ref_file_layout) );

  # Retrieve:
  #   Epochs
  #   Horizontal Accuracy
  #   Vertical Accuracy
  #   Time accuracy
  my $pdl_epochs = $pdl_acc_info($ref_file_layout->{ITEMS}{ EpochGPS }{INDEX});
  my $pdl_status = $pdl_acc_info($ref_file_layout->{ITEMS}{ Status   }{INDEX});
  my $pdl_h_acc  = $pdl_acc_info($ref_file_layout->{ITEMS}{ HDOP     }{INDEX});
  my $pdl_v_acc  = $pdl_acc_info($ref_file_layout->{ITEMS}{ VDOP     }{INDEX});
  my $pdl_t_acc  = $pdl_acc_info($ref_file_layout->{ITEMS}{ TDOP     }{INDEX});

  # Flat all piddles for converting them into arrays:
  $pdl_epochs = $pdl_epochs -> flat();
  $pdl_status = $pdl_status -> flat();
  $pdl_h_acc  = $pdl_h_acc  -> flat();
  $pdl_v_acc  = $pdl_v_acc  -> flat();
  $pdl_t_acc  = $pdl_t_acc  -> flat();

  # Apply sigma scale factors on accaracy indicators:
  # TODO: include these in configuration!
  my $sigma_factor_1d = 1;
  my $sigma_factor_2d = 1;

  $pdl_h_acc *= $sigma_factor_2d;
  $pdl_v_acc *= $sigma_factor_1d;
  $pdl_t_acc *= $sigma_factor_1d;

  # Compute position accuracy indicator:
  my $pdl_p_acc = ($pdl_h_acc**2 + $pdl_v_acc**2)**0.5;

  # Get number of valid/invalid epochs:
  my $num_epochs     = dims($pdl_status);
  my $num_ok_epochs  = sum ($pdl_status);
  my $num_nok_epochs = $num_epochs - $num_ok_epochs;

  # Compute statistics over accuracy indicators:
  # NOTE: info will be arranged with a hash
  my $ref_acc_info = {
    HORIZONTAL => {
      RMS => ( sum($pdl_h_acc**2)/$num_ok_epochs )**0.5,
      MAX => max($pdl_h_acc),
      MIN => min($pdl_h_acc),
    },
    VERTICAL => {
      RMS => ( sum($pdl_v_acc**2)/$num_ok_epochs )**0.5,
      MAX => max($pdl_v_acc),
      MIN => min($pdl_v_acc),
    },
    POSITION => {
      RMS => ( sum($pdl_p_acc**2)/$num_ok_epochs )**0.5,
      MAX => max($pdl_p_acc),
      MIN => min($pdl_p_acc),
    },
    TIME => {
      RMS => ( sum($pdl_t_acc**2)/$num_ok_epochs )**0.5,
      MAX => max($pdl_t_acc),
      MIN => min($pdl_t_acc),
    },
  };

  # Report on dedicated file:


  # Retrieve date in 'yyyy/mo/dd' format:
  my $date    = ( split(' ', BuildDateString(GPS2Date(min($pdl_epochs)))) )[0];

  # Retrieve satellite system used:
  my @sat_sys = @{ $ref_gen_conf->{SELECTED_SAT_SYS} };

  my @signal_used;
  for (@sat_sys) {
    my $signal_id = substr($ref_gen_conf->{SELECTED_SIGNALS}{$_}, 0, 2);
    push(@signal_used,
      join('-', SAT_SYS_ID_TO_NAME->{$_},
                SAT_SYS_OBS_TO_NAME->{$_}{$signal_id})
    );
  }

  my $signal_used_string = join(' + ', @signal_used);

  # Set title:
  my $title =
    "Position accuracy report from $marker_name on $date ".
    "using $signal_used_string";

  say $title;

  # Open file in output directory:
  my $fh; open($fh, '>', 'accuracy_report.txt');

  # Close file:
  close($fh);


  return TRUE;
}

sub ReportPositionError {
  my () = @_;

  return TRUE;
}

sub ReportPositionIntegrity {
  my () = @_;



  return TRUE;
}

# ---------------------------------------------------------------------------- #
# Private Subroutines: #

TRUE;
