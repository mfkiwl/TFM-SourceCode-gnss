#!/usr/bin/perl -X

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

my $script_description = <<'EOF';
# ============================================================================ #
# Script: DownloadCampaignData.pl
# ============================================================================ #
# Purpose: Downloads from BKG repository, RINEX observation and navigation data.
#          The data is downloaded in $cmp_root_path/dat/ and structured by
#          station and date.
#
# ============================================================================ #
# Usage:
# ============================================================================ #
#  ./DownloadCampaignData.pl <cmp_root_path> <station_date_hash> <download_flag>
#
# * NOTE:
#    - Station-date hash must have the following format, e.g.:
#      {
#        KIRU => {
#          DATE_1 => { YY_MO_DD => [], INI_TIME => [], END_TIME => [],  },
#          ...
#        },
#        ...
#      }
#
# ============================================================================ #
# Script arguments:
# ============================================================================ #
#  - $1 -> Campaign root path
#  - $2 -> Station-Date configuration hash (plain text)
#  - $3 -> Download data flag (1 for TRUE, 0 for FALSE)
#
EOF

print $script_description;


# 1. Load info containing stations and date information:
# Script argument is expected to be the hash station-date configuration:
my ($cmp_root_path, $cmp_hash_cfg_path, $download_data_flag) = @ARGV;

# Define RINEX data and temporal absolute paths:
my $dat_root_path = abs_path( join('/', $cmp_root_path, 'dat') );
my $tmp_root_path = abs_path( join('/', $cmp_root_path, 'tmp') );

# Load hash configuration:
my $ref_cmp_cfg = do $cmp_hash_cfg_path;

# 2. Download rinex data:
# Define download scripts:
my $down_obs_rinex_path =
  join('/', UTIL_ROOT_PATH, "DownloadRinexObsFromFTP-BKG.pl");
my $down_nav_rinex_path =
  join('/', UTIL_ROOT_PATH, "DownloadRinexNavFromFTP-BKG.pl");

for my $sta (keys %{ $ref_cmp_cfg }) {
  for my $date (keys %{ $ref_cmp_cfg->{$sta} }) {

    # Retrieve year and compute day of year:
    my $ref_date_yy_mm_dd = $ref_cmp_cfg->{$sta}{$date}{YY_MO_DD};
    my $year = $ref_date_yy_mm_dd->[0];
    my $doy  = Date2DoY( @{ $ref_date_yy_mm_dd }, 0, 0, 0 );

    # Append DoY to station-date hash:
    $ref_cmp_cfg->{$sta}{$date}{DOY} = $doy;

    # Define path to sotre rinex data:
    my $dat_path = join('/', $dat_root_path, $sta, $date, '');

    # Make station directory:
     qx{mkdir -p $dat_path} unless(-e $dat_path);

    # De-refernece date info:
    if ($download_data_flag) {

      # Rinex observation files:
      qx{$down_obs_rinex_path $year $doy $sta $dat_path};

      # Rinex navigation files:
      for my $sat_sys (&RINEX_GPS_ID, &RINEX_GAL_ID) {
        qx{$down_nav_rinex_path $sat_sys $year $doy $sta $dat_path};
      } # end for $sat_sys

    } # end if $download_data_flag

  } # end for $date
} # end for $sta

print Dumper $ref_cmp_cfg;
store( $ref_cmp_cfg, join('/', $tmp_root_path, 'ref_station_date.hash') );

# ---------------------------------------------------------------------------- #
# END OF SCRIPT
