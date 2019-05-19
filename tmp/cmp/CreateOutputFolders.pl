#!/usr/bin/perl -w

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

# Read script argument:
#   $1 -> Report root path
#   $2 -> Station-Date hash configuration (binary hash)
my ($rpt_root_path, $cmp_cfg_hash_path) = @ARGV;

$rpt_root_path = abs_path($rpt_root_path);

# Load satation-date hash configuration:
my $ref_cmp_cfg = retrieve($cmp_cfg_hash_path);

for my $station (keys %{$ref_cmp_cfg}) {
  for my $date (keys %{$ref_cmp_cfg->{$station}}) {
    for my $signal (keys %{$ref_cmp_cfg->{$station}{$date}{SIGNAL_OBS}}) {

      my $rpt_grpp_path =
        join('/', $rpt_root_path, $station, $date, $signal, "GRPP");
      my $rpt_gspa_path =
        join('/', $rpt_root_path, $station, $date, $signal, "GSPA");

      qx{mkdir -p $rpt_grpp_path} unless (-e $rpt_grpp_path);
      qx{mkdir -p $rpt_gspa_path} unless (-e $rpt_gspa_path);

    }
  }
}



# ---------------------------------------------------------------------------- #
# END OF SCRIPT
