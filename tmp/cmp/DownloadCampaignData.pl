#!/usr/bin/perl -w

# ---------------------------------------------------------------------------- #
# Load perl modules:

use Carp;
use strict;

use Storable;
use Data::Dumper;
use feature qq(say);
use Cwd qq(abs_path);


# ---------------------------------------------------------------------------- #
# Load dedicated modules:

use lib $ENV{ ENV_ROOT };
use Enviroments qq(:ALL);

use lib SRC_ROOT_PATH;
use GeneralConfiguration qq(:ALL);

use lib LIB_ROOT_PATH;
use MyUtil qq(:ALL);
use MyPrint qq(:ALL);
use TimeGNSS qq(:ALL);


# ---------------------------------------------------------------------------- #
# Main Routine:

# Configuration flags:
my $download_data_flag = FALSE;

# 1. Load info containing stations and date information:
# Script argument is expected to be the hash station-date configuration:
my ($dat_root_path, $cmp_hash_cfg_path) = @ARGV;

$dat_root_path = abs_path($dat_root_path);
my $ref_cmp_cfg = do $cmp_hash_cfg_path;

# 2. Download rinex data:
# Define source codes to download scripts:
my $down_obs_rinex_path =
  join('/', UTIL_ROOT_PATH, "DownloadRinexObsFromFTP-BKG.pl");
my $down_nav_rinex_path =
  join('/', UTIL_ROOT_PATH, "DownloadRinexNavFromFTP-BKG.pl");


my @station_list = keys %{ $ref_cmp_cfg };

for my $sta (@station_list) {

  my @date_list = keys %{ $ref_cmp_cfg->{$sta} };

  for my $date (@date_list) {

    # Retrieve year and compute day of year:
    my $ref_date_yy_mm_dd = $ref_cmp_cfg->{$sta}{$date}{YY_MO_DD};
    my $year = $ref_date_yy_mm_dd->[0];
    my $doy  = Date2DoY( @{ $ref_date_yy_mm_dd }, 0, 0, 0 );

    # Append DoY to station-date hash:
    $ref_cmp_cfg->{$sta}{$date}{DOY} = $doy;

    # Define path to sotre rinex data:
    my $dat_path = join('/', $dat_root_path, $sta, $date, '');

    unless(-e $dat_path) { qx{mkdir -p $dat_path}; }

    # De-refernece date info:
    # Rinex observation files:
    qx{$down_obs_rinex_path $year $doy $sta $dat_path} if $download_data_flag;

    # Rinex navigation files:
    for my $sat_sys (&RINEX_GPS_ID, &RINEX_GAL_ID) {
      qx{$down_nav_rinex_path $sat_sys $year $doy $sta $dat_path} if $download_data_flag;
    } # end for $sat_sys

  } # end for $date
} # end for $sta

print Dumper $ref_cmp_cfg;
store($ref_cmp_cfg, 'ref_station_date_cfg.hash');

# ---------------------------------------------------------------------------- #
# END OF SCRIPT
