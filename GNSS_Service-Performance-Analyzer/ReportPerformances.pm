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

# Load general configuration and interfaces module:
use lib SRC_ROOT_PATH;
use GeneralConfiguration qq(:ALL);

# Load common GSPA utils:
use lib GSPA_ROOT_PATH;
use CommonUtil qq(:ALL);

# ---------------------------------------------------------------------------- #
# Public Subroutines: #

sub ReportPositionAccuracy {
  my ($ref_gen_conf, $inp_path, $out_path, $marker_name) = @_;

  # Retrieve accuracy indicators from GRPP files:
  # Load dumper file:
  my $ref_file_layout =
     GetFileLayout( join('/', ($inp_path, "sigma-info.out")),
                    5, $ref_gen_conf->{DATA_DUMPER}{DELIMITER} );

  # Make piddle from loaded file:
  my $pdl_acc_info = pdl( LoadFileByLayout($ref_file_layout) );

  # Retrieve:
  #   Epochs
  #   Position status
  #   Horizontal Accuracy
  #   Vertical Accuracy
  #   Time accuracy
  my $pdl_epochs = $pdl_acc_info($ref_file_layout->{ITEMS}{ EpochGPS }{INDEX});
  my $pdl_status = $pdl_acc_info($ref_file_layout->{ITEMS}{ Status   }{INDEX});
  my $pdl_h_acc  = $pdl_acc_info($ref_file_layout->{ITEMS}{ SigmaH   }{INDEX});
  my $pdl_v_acc  = $pdl_acc_info($ref_file_layout->{ITEMS}{ SigmaV   }{INDEX});
  my $pdl_t_acc  = $pdl_acc_info($ref_file_layout->{ITEMS}{ SigmaT   }{INDEX});

  # Flat piddles:
  $pdl_epochs = $pdl_epochs -> flat();
  $pdl_status = $pdl_status -> flat();

  # Get number of valid/invalid epochs:
  my $num_epochs     = scalar( list($pdl_status) );
  my $num_ok_epochs  = sum($pdl_status);
  my $num_nok_epochs = $num_epochs - $num_ok_epochs;
  my $num_ok_ratio   = $num_ok_epochs/$num_epochs;

  # Flat and clear from NULL_DATA:
  $pdl_h_acc = ClearNullDataPiddle($pdl_h_acc)->flat();
  $pdl_v_acc = ClearNullDataPiddle($pdl_v_acc)->flat();
  $pdl_t_acc = ClearNullDataPiddle($pdl_t_acc)->flat();

  # Apply sigma scale factors on accaracy indicators:
  my $sigma_factor_1d = $ref_gen_conf->{ACCURACY}{ VERTICAL   }{SIGMA_FACTOR};
  my $sigma_factor_2d = $ref_gen_conf->{ACCURACY}{ HORIZONTAL }{SIGMA_FACTOR};

  $pdl_h_acc *= $sigma_factor_2d;
  $pdl_v_acc *= $sigma_factor_1d;
  $pdl_t_acc *= $sigma_factor_1d;

  # Compute position accuracy indicator:
  my $pdl_p_acc = ($pdl_h_acc**2 + $pdl_v_acc**2)**0.5;

  # Compute statistics over accuracy indicators:
  # NOTE: info will be arranged in a hash
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
  # Set title:
  my $title = SetReportTitle("Position accuracy report",
                             $ref_gen_conf, $marker_name, min($pdl_epochs));

  # Arrange file:
  #           1         2         3         4         5         6         7
  # 0123456789012345678901234567890123456789012345678901234567890123456789012
  # Component   NumEpochs NumOKEpochs    %  SigmaFactor  MinAcc  MaxAcc  RMSAcc
  # Vertical       000000      000000 000%        00.00  000.00  000.00  000.00
  # Horizontal     000000      000000 000%        00.00  000.00  000.00  000.00
  # Position       000000      000000 000%        00.00  000.00  000.00  000.00
  # Time           000000      000000 000%        00.00  000.00  000.00  000.00

  # Arrange header:
  my $header =
    sprintf("# %10s %9s %11s %5s %11s %9s %9s %9s",
            'Component', 'NumEpochs', 'NumOkEpochs', '%',
            'SigmaFactor', 'MinAcc', 'RMSAcc', 'MaxAcc', );

  # Arrange vertical
  my $vertical_info =
    sprintf("> %10s %9d %11d %5.1f %11.2f %9.2f %9.2f %9.2f",
            'Vertical', $num_epochs, $num_ok_epochs,
            $num_ok_ratio*100, $sigma_factor_1d,
            $ref_acc_info->{VERTICAL}{MIN},
            $ref_acc_info->{VERTICAL}{RMS},
            $ref_acc_info->{VERTICAL}{MAX});

  # Arrange horizontal component info:
  my $horizontal_info =
    sprintf("> %10s %9d %11d %5.1f %11.2f %9.2f %9.2f %9.2f",
            'Horizontal', $num_epochs, $num_ok_epochs,
            $num_ok_ratio*100, $sigma_factor_2d,
            $ref_acc_info->{HORIZONTAL}{MIN},
            $ref_acc_info->{HORIZONTAL}{RMS},
            $ref_acc_info->{HORIZONTAL}{MAX});

  # Arrange position component info:
  my $position_info =
    sprintf("> %10s %9d %11d %5.1f %11.2f %9.2f %9.2f %9.2f",
            'Position', $num_epochs, $num_ok_epochs,
            $num_ok_ratio*100, ($sigma_factor_1d**2 + $sigma_factor_2d**2)**.5,
            $ref_acc_info->{POSITION}{MIN},
            $ref_acc_info->{POSITION}{RMS},
            $ref_acc_info->{POSITION}{MAX});

  # Arrange time component info:
  my $time_info =
    sprintf("> %10s %9d %11d %5.1f %11.2f %9.2f %9.2f %9.2f",
            'Time', $num_epochs, $num_ok_epochs,
            $num_ok_ratio*100, $sigma_factor_1d,
            $ref_acc_info->{TIME}{MIN},
            $ref_acc_info->{TIME}{RMS},
            $ref_acc_info->{TIME}{MAX});

  # Open file in output directory:
  my $fh; open($fh, '>', join('/', $out_path, 'accuracy_report.txt'));

  say $fh "";
  PrintTitle2($fh, $title);
  say $fh $header;
  say $fh $vertical_info;
  say $fh $horizontal_info;
  say $fh $position_info;
  say $fh $time_info;
  say $fh "";

  # Close file:
  close($fh);

  return TRUE;
}

sub ReportPositionError {
  my ($ref_gen_conf, $inp_path, $out_path, $marker_name) = @_;

  # Retrieve data from GRPP files:
  # Load dumper file:
  my $ref_file_layout =
     GetFileLayout( join('/', ($inp_path, "$marker_name-xyz.out")),
                    8, $ref_gen_conf->{DATA_DUMPER}{DELIMITER} );

  # Make piddle from loaded file:
  my $pdl_err_info = pdl( LoadFileByLayout($ref_file_layout) );

  # Retrieve:
  #   Epochs
  #   Position status
  #   Easting error
  #   Northing error
  #   Upping error
  my $pdl_epochs = $pdl_err_info($ref_file_layout->{ITEMS}{ EpochGPS }{INDEX});
  my $pdl_status = $pdl_err_info($ref_file_layout->{ITEMS}{ Status   }{INDEX});
  my $pdl_e_err  = $pdl_err_info($ref_file_layout->{ITEMS}{ REF_IE   }{INDEX});
  my $pdl_n_err  = $pdl_err_info($ref_file_layout->{ITEMS}{ REF_IN   }{INDEX});
  my $pdl_u_err  = $pdl_err_info($ref_file_layout->{ITEMS}{ REF_IU   }{INDEX});

  # Flat piddles:
  $pdl_epochs = $pdl_epochs -> flat();
  $pdl_status = $pdl_status -> flat();

  # Get number of valid/invalid epochs:
  my $num_epochs     = scalar( list($pdl_status) );
  my $num_ok_epochs  = sum($pdl_status);
  my $num_nok_epochs = $num_epochs - $num_ok_epochs;
  my $num_ok_ratio   = $num_ok_epochs/$num_epochs;

  # Flat and clear from NULL_DATA piddles:
  $pdl_e_err  = ClearNullDataPiddle($pdl_e_err)->flat();
  $pdl_n_err  = ClearNullDataPiddle($pdl_n_err)->flat();
  $pdl_u_err  = ClearNullDataPiddle($pdl_u_err)->flat();

  # Compute horitzontal error component:
  my $pdl_h_err = ($pdl_e_err**2 + $pdl_n_err**2)**.5;
  # Compute position error component:
  my $pdl_p_err = ($pdl_e_err**2 + $pdl_n_err**2 + $pdl_u_err**2)**.5;

  # Compute statistics over error indicators:
  # NOTE: info will be arranged in a hash
  my $ref_err_info = {
    HORIZONTAL => {
      RMS => ( sum($pdl_h_err**2)/$num_ok_epochs )**0.5,
      MAX => max($pdl_h_err),
      MIN => min($pdl_h_err),
    },
    VERTICAL => {
      RMS => ( sum($pdl_u_err**2)/$num_ok_epochs )**0.5,
      MAX => max($pdl_u_err),
      MIN => min($pdl_u_err),
    },
    POSITION => {
      RMS => ( sum($pdl_p_err**2)/$num_ok_epochs )**0.5,
      MAX => max($pdl_p_err),
      MIN => min($pdl_p_err),
    },
  };

  # Report on dedicated file:
  # Set title:
  my $title = SetReportTitle("Position actual error report",
                             $ref_gen_conf, $marker_name, min($pdl_epochs));

  # Arrange file:
  #           1         2         3         4         5         6         7
  # 0123456789012345678901234567890123456789012345678901234567890123456789012
  # Component   NumEpochs NumOKEpochs    %    MinAcc   MaxAcc   RMSAcc
  # Vertical       000000      000000 000%    000.00   000.00   000.00
  # Horizontal     000000      000000 000%    000.00   000.00   000.00
  # Position       000000      000000 000%    000.00   000.00   000.00

    # Arrange header:
    my $header =
      sprintf("# %10s %9s %11s %5s %9s %9s %9s",
              'Component', 'NumEpochs', 'NumOkEpochs', '%',
              'MinErr', 'RMSErr', 'MaxErr', );

    # Arrange vertical
    my $vertical_info =
      sprintf("> %10s %9d %11d %5.1f %9.2f %9.2f %9.2f",
              'Vertical', $num_epochs, $num_ok_epochs,
              $num_ok_ratio*100,
              $ref_err_info->{VERTICAL}{MIN},
              $ref_err_info->{VERTICAL}{RMS},
              $ref_err_info->{VERTICAL}{MAX});

    # Arrange horizontal component info:
    my $horizontal_info =
      sprintf("> %10s %9d %11d %5.1f %9.2f %9.2f %9.2f",
              'Horizontal', $num_epochs, $num_ok_epochs,
              $num_ok_ratio*100,
              $ref_err_info->{HORIZONTAL}{MIN},
              $ref_err_info->{HORIZONTAL}{RMS},
              $ref_err_info->{HORIZONTAL}{MAX});

    # Arrange position component info:
    my $position_info =
      sprintf("> %10s %9d %11d %5.1f %9.2f %9.2f %9.2f",
              'Position', $num_epochs, $num_ok_epochs,
              $num_ok_ratio*100,
              $ref_err_info->{POSITION}{MIN},
              $ref_err_info->{POSITION}{RMS},
              $ref_err_info->{POSITION}{MAX});

  # Open file in output directory:
  my $fh; open($fh, '>', join('/', $out_path, 'error_report.txt'));

  say $fh "";
  PrintTitle2($fh, $title);
  say $fh $header;
  say $fh $vertical_info;
  say $fh $horizontal_info;
  say $fh $position_info;
  say $fh "";

  # Close file:
  close($fh);

  return TRUE;
}

sub ReportPositionIntegrity {
  my ($ref_gen_conf, $inp_path, $out_path, $marker_name) = @_;

  # Retrieve integrity indicators from GRPP files:
  # Load dumper file:
  my $ref_file_layout;

  # Horizontal integrity:
  $ref_file_layout =
     GetFileLayout( join('/', ($inp_path, "integrity-horizontal.out")),
                    4, $ref_gen_conf->{DATA_DUMPER}{DELIMITER} );

  # Make piddle from loaded file:
  my $pdl_int_h = pdl( LoadFileByLayout($ref_file_layout) );

  # Vertical integrity:
  $ref_file_layout =
     GetFileLayout( join('/', ($inp_path, "integrity-vertical.out")),
                    4, $ref_gen_conf->{DATA_DUMPER}{DELIMITER} );

  # Make piddle from loaded file:
  my $pdl_int_v = pdl( LoadFileByLayout($ref_file_layout) );

  # Retrieve:
  #   Epochs
  #   Position status
  my $pdl_epochs = $pdl_int_h($ref_file_layout->{ITEMS}{ EpochGPS }{INDEX});
  my $pdl_status = $pdl_int_h($ref_file_layout->{ITEMS}{ Status   }{INDEX});

  # Flat piddles:
  $pdl_epochs = $pdl_epochs -> flat();
  $pdl_status = $pdl_status -> flat();

  # Get number of valid/invalid epochs:
  my $num_epochs     = scalar( list($pdl_status) );
  my $num_ok_epochs  = sum($pdl_status);
  my $num_nok_epochs = $num_epochs - $num_ok_epochs;
  my $num_ok_ratio   = $num_ok_epochs/$num_epochs;

  # Retrieve:
  #   Alert limit
  #   MI
  #   HMI
  #   SA (Sys Availavility)

  # Vertical component:
  my $pdl_v_mi  = $pdl_int_v($ref_file_layout->{ITEMS}{ MI        }{INDEX});
  my $pdl_v_hmi = $pdl_int_v($ref_file_layout->{ITEMS}{ HMI       }{INDEX});
  my $pdl_v_sa  = $pdl_int_v($ref_file_layout->{ITEMS}{ Available }{INDEX});

  # Horizontal component:
  my $pdl_h_mi  = $pdl_int_h($ref_file_layout->{ITEMS}{ MI        }{INDEX});
  my $pdl_h_hmi = $pdl_int_h($ref_file_layout->{ITEMS}{ HMI       }{INDEX});
  my $pdl_h_sa  = $pdl_int_h($ref_file_layout->{ITEMS}{ Available }{INDEX});

  # Flat and clear NULL_DATA:
  $pdl_v_mi  = ClearNullDataPiddle($pdl_v_mi )->flat();
  $pdl_v_hmi = ClearNullDataPiddle($pdl_v_hmi)->flat();
  $pdl_v_sa  = ClearNullDataPiddle($pdl_v_sa )->flat();
  $pdl_h_mi  = ClearNullDataPiddle($pdl_h_mi )->flat();
  $pdl_h_hmi = ClearNullDataPiddle($pdl_h_hmi)->flat();
  $pdl_h_sa  = ClearNullDataPiddle($pdl_h_sa )->flat();

  # Compute integrity info:
  # NOTE: integrity info will be arranged in a hash.
  # NOTE: sigma scale factor and alert limits are retrieved from configuration
  my $ref_int_info = {
    HORIZONTAL => {
      AL  => $ref_gen_conf->{ INTEGRITY }{HORIZONTAL}{ALERT_LIMIT},
      SSF => $ref_gen_conf->{ ACCURACY  }{HORIZONTAL}{SIGMA_FACTOR},
      MI  => sum($pdl_h_mi),
      HMI => sum($pdl_h_hmi),
      SA  => sum($pdl_h_sa),
    },
    VERTICAL => {
      AL  => $ref_gen_conf->{ INTEGRITY }{VERTICAL}{ALERT_LIMIT},
      SSF => $ref_gen_conf->{ ACCURACY  }{VERTICAL}{SIGMA_FACTOR},
      MI  => sum($pdl_v_mi),
      HMI => sum($pdl_v_hmi),
      SA  => sum($pdl_v_sa),
    },
  };

  # Arrange file:
  # Set title:
  my $title = SetReportTitle("Position integrity report",
                             $ref_gen_conf, $marker_name, min($pdl_epochs));

  #           1         2         3         4         5         6         7
  # 01234567890123456789012345678901234567890123456789012345678901234567890123
  # Component   NumEpochs NumOKEpochs    %  SigmaFactor AlertLimit     MI    %
  # Vertical       000000      000000 000%       000.00     000.00 000000 000%
  # Horizontal     000000      000000 000%       000.00     000.00 000000 000%

  # Arrange header:
  my $header =
    sprintf("# %10s %9s %11s %5s %11s %10s %6s %5s %6s %5s %6s %5s",
            'Component', 'NumEpochs', 'NumOkEpochs', '%',
            'SigmaFactor', 'AlertLimit', 'MI', '%', 'HMI', '%', 'SA', '%');

  # Arrange vertical info:
  my $vertical_info =
    sprintf("> %10s %9d %11d %5.1f %11.2f %10.2f %6d %5.1f %6d %5.1f %6d %5.1f",
            'Vertical', $num_epochs, $num_ok_epochs, $num_ok_ratio*100,
             $ref_int_info->{VERTICAL}{ SSF },
             $ref_int_info->{VERTICAL}{ AL  },
             $ref_int_info->{VERTICAL}{ MI  },
            ($ref_int_info->{VERTICAL}{ MI  }/$num_ok_epochs)*100,
             $ref_int_info->{VERTICAL}{ HMI },
            ($ref_int_info->{VERTICAL}{ HMI }/$num_ok_epochs)*100,
             $ref_int_info->{VERTICAL}{ SA  },
            ($ref_int_info->{VERTICAL}{ SA  }/$num_ok_epochs)*100);

  # Arrange horitzontal info:
  my $horizontal_info =
    sprintf("> %10s %9d %11d %5.1f %11.2f %10.2f %6d %5.1f %6d %5.1f %6d %5.1f",
            'Horizontal', $num_epochs, $num_ok_epochs, $num_ok_ratio*100,
             $ref_int_info->{HORIZONTAL}{ SSF },
             $ref_int_info->{HORIZONTAL}{ AL  },
             $ref_int_info->{HORIZONTAL}{ MI  },
            ($ref_int_info->{HORIZONTAL}{ MI  }/$num_ok_epochs)*100,
             $ref_int_info->{HORIZONTAL}{ HMI },
            ($ref_int_info->{HORIZONTAL}{ HMI }/$num_ok_epochs)*100,
             $ref_int_info->{HORIZONTAL}{ SA  },
            ($ref_int_info->{HORIZONTAL}{ SA  }/$num_ok_epochs)*100);

  # Open file in output directory:
  my $fh; open($fh, '>', join('/', $out_path, 'integrity_report.txt'));

  say $fh "";
  PrintTitle2($fh, $title);
  say $fh $header;
  say $fh $vertical_info;
  say $fh $horizontal_info;
  say $fh "";

  # Close file:
  close($fh);

  return TRUE;
}

# ---------------------------------------------------------------------------- #
# Private Subroutines: #

TRUE;
