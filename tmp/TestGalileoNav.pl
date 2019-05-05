#!/usr/bin/perl -X

use Carp;
use strict;

use Data::Dumper;
use feature qq(say);

# ---------------------------------------------------------------------------- #

use lib $ENV{ ENV_ROOT };
use Enviroments qq(:CONSTANTS);

use lib SRC_ROOT_PATH;
use GeneralConfiguration qq(:ALL);

use lib GRPP_ROOT_PATH;
use RinexReader qq(:ALL);

use lib LIB_ROOT_PATH;
use MyPrint qq(:ALL);
use TimeGNSS qq(:ALL);

# ---------------------------------------------------------------------------- #

my $rinex_nav_path =
  '/home/ppinto/WorkArea/dat/nav/gal/ABMF00GLP_R_20190510000_01D_EN.rnx';


my $ref_nav_rinex =
  ReadNavigationRinex($rinex_nav_path, RINEX_GAL_ID, *STDOUT);

# print Dumper $ref_nav_rinex->{HEAD};
print Dumper $ref_nav_rinex->{BODY}{E01};

exit 0;

# Bit activation for GAL data source:
  my $ref_gal_data_source_info = {
    0 => "I/NAV E1-B",
    1 => "F/NAV E5a-I",
    2 => "I/NAV E5b-I",
    8 => "af0-af2, Toc, SISA are for E5a,E1",
    9 => "af0-af2, Toc, SISA are for E5b,E1",
  };

# Iterate over GAL satellites:
for my $gal_sat ( 'E01', 'E02' ) {

  print "\n", LEVEL_2_DELIMITER, "\n";
  PrintComment(*STDOUT, "For GAL sat $gal_sat"); print "\n" x 1;

  # Iterate over ephemerids epochs:
  for my $eph_epoch ( sort (keys %{ $ref_nav_rinex->{BODY}{$gal_sat} }) ) {

    # Ephemerids issue of data:
    my $iod = $ref_nav_rinex->{BODY}{$gal_sat}{$eph_epoch}{IODE}*1;

    # SV clock parameters:
    my $ref_sv_clk_parameters = [
      $ref_nav_rinex->{BODY}{$gal_sat}{$eph_epoch}{ SV_CLK_BIAS  }*1,
      $ref_nav_rinex->{BODY}{$gal_sat}{$eph_epoch}{ SV_CLK_DRIFT }*1,
      $ref_nav_rinex->{BODY}{$gal_sat}{$eph_epoch}{ SV_CLK_RATE  }*1
    ];

    # Data source --> integer format:
    my $gal_data_source_int =
       $ref_nav_rinex->{BODY}{$gal_sat}{$eph_epoch}{L2_CODE_CHANNEL}*1;

    # Data source --> raw binary format:
    my $gal_data_source_bin = sprintf("%b", $gal_data_source_int);

    # Decode source --> bit format:
    # NOTE: bit are reversed to be stored in array index order
    my @bit_arr = reverse(split('', $gal_data_source_bin));

    # Decode information stored in bits:
    my @gal_data_source;
    for (0..2) {
      push(@gal_data_source, $ref_gal_data_source_info->{$_}) if $bit_arr[$_];
    }

    my @gal_clk_corr;
    for (8..9) {
      push(@gal_clk_corr, $ref_gal_data_source_info->{$_}) if $bit_arr[$_];
    }

    # Print decoded information for each ephemerids:
    # Only for data source: F/NAV E5a-I
    if (1) {
      PrintBulletedInfo(*STDOUT, '  - ',
        "Ephemerids Epoch      = $eph_epoch -> ".BuildDateString(GPS2Date($eph_epoch)),
        "Ephemerids IOD        = $iod",
        "SV clock (a0, a1, a2) = ".sprintf("%.11f, " x 3, @{ $ref_sv_clk_parameters }),
        "GAL Data source (int) = $gal_data_source_int",
        # "GAL Data source (bin) = $gal_data_source_bin",
        "GAL Data source (bit) = ". join('', @bit_arr),
        "            Bit order - ". join('', (0..9)),
        "Decoded Data source --> ".join(' + ', @gal_data_source),
        "Decoded Data corr   --> ".join(' + ', @gal_clk_corr) );
    }

  }

} # end for $gal_sat
