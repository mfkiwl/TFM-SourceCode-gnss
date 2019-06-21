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
# Script: GetGalNavBrdm.pl
# ============================================================================ #
# Purpose: Downloads from BKG repository, brdm navigation files for the
#          configured dates. Then, gfzrnx tool is runned over them in order
#          to filter only GALILEO navigation.
#
# ============================================================================ #
# Usage:
# ============================================================================ #
#  ./GetGalNavBrdm.pl <station_date_hash>
#
# * NOTE:
#    - Station-date hash must have the following format, e.g.:
#      {
#        KIRU => {
#          DATE_1 => {
#           YY_MO_DD => [$year, $month, $day],
#           INI_TIME => [$hour, $minute, $second],
#           END_TIME => [$hour, $minute, $second],
#          },
#          # More dates
#        },
#        # More stations
#      }
#
# ============================================================================ #
# Script arguments:
# ============================================================================ #
#  - $1 -> Station-Date configuration hash (plain text)
#
EOF
print $script_description;

# 1. Load info containing stations and date information:
# Script argument is expected to be the hash station-date configuration:
my ($cmp_hash_cfg_path) = @ARGV;

# Load hash configuration:
my $ref_cmp_cfg = do $cmp_hash_cfg_path;

# 2. Download and treat data:
# Set bkg repository path:
my $bkg_brdm_root = 'ftp://igs.bkg.bund.de/MGEX/BRDC_v3/';

# Set gfzrnx path:
my $gfzrnx_path = '/home/ppinto/WorkArea/util/gfzrnx_lx';

for my $sta (keys %{ $ref_cmp_cfg }) {
  for my $date (keys %{ $ref_cmp_cfg->{$sta} }) {

    # Retrieve year and compute day of year:
    my $ref_date_yy_mm_dd = $ref_cmp_cfg->{$sta}{$date}{YY_MO_DD};
    my $year = $ref_date_yy_mm_dd->[0];
    my $doy  = Date2DoY( @{ $ref_date_yy_mm_dd }, 0, 0, 0 );

    # Format DoY:
    $doy = sprintf("%03d", $doy);
    # Two last year digits:
    my $yy = substr($year, 2, 2);

    # BRDM files:
    my $brdm_name = join('', 'brdm', $doy, '0.', $yy, 'p', '.Z');
    my $brdm_file = join('/', $bkg_brdm_root, $year, $doy, $brdm_name);
    PrintComment(*STDOUT,
      "Downloading brdm for $year-$doy : '$brdm_file'");

    # Download brdm file:
    qx{wget $brdm_file} unless (-e $brdm_name);

    # Uncompress it:
    qx{uncompress $brdm_name};

    my $brdm_name_uncomp = join('', 'brdm', $doy, '0.', $yy, 'p');

    # Pass gfzrnx:
    qx{$gfzrnx_path -finp $brdm_name_uncomp -fout ::RX3:: -satsys E};

  } # end for $date
} # end for $sta


# ---------------------------------------------------------------------------- #
# END OF SCRIPT
