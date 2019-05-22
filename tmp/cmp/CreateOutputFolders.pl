#!/usr/bin/perl -X

# ---------------------------------------------------------------------------- #
# Load Perl modules:

use Carp;
use strict;

use Storable;
use Data::Dumper;
use feature qq(say);
use Cwd qq(abs_path);


# ---------------------------------------------------------------------------- #
# Load dedicated modules:

use lib $ENV{ ENV_ROOT };
use Enviroments qq(:CONSTANTS);

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
# Script: CreateOutputFolders.pl
# ============================================================================ #
# Purpose: Sets signal obsertvations RINEX codes for each station, date and
#          signal combination.
#          The output directories are created in $cmp_root_path/rpt structured
#          as $station/$date/$signal/GRPP and $station/$date/$signal/GSPA.
#
# ============================================================================ #
# Usage:
# ============================================================================ #
#  ./CreateOutputFolders.pl <cmp_root_path> <station_date_hash_bin>
#
# * NOTE:
#    - Station-date hash configuration must be in binary format
#    - Station-date hash must contain SIGNAL_OBS entry for every station and
#      date entry
#
# ============================================================================ #
# Script arguments:
# ============================================================================ #
#  - $1 -> Campaign root path
#  - $2 -> Station-Date configuration hash (Storable binary)
#
EOF
print $script_description;

# Read script arguments:
my ($cmp_root_path, $cmp_cfg_hash_path) = @ARGV;

# Retrieve absolute paths:
my $rpt_root_path = abs_path( join('/', $cmp_root_path, 'rpt') );

# Load satation-date hash configuration:
my $ref_cmp_cfg = retrieve($cmp_cfg_hash_path);

for my $station (keys %{$ref_cmp_cfg}) {
  for my $date (keys %{$ref_cmp_cfg->{$station}}) {
    for my $signal (keys %{$ref_cmp_cfg->{$station}{$date}{SIGNAL_OBS}}) {

      # Set output paths:
      my $rpt_grpp_path =
        join('/', $rpt_root_path, $station, $date, $signal, "GRPP");
      my $rpt_gspa_path =
        join('/', $rpt_root_path, $station, $date, $signal, "GSPA");

      say "Creating: $rpt_grpp_path ";
      qx{mkdir -p $rpt_grpp_path} unless (-e $rpt_grpp_path);

      say "Creating: $rpt_gspa_path ";
      qx{mkdir -p $rpt_gspa_path} unless (-e $rpt_gspa_path);

    } # end for $signal
  } # end for $date
} # end for $station


# ---------------------------------------------------------------------------- #
# END OF SCRIPT
