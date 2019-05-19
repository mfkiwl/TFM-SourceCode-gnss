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
#   $1 -> Campaign configuration hash (station, date, links, obs and cfg)
my ($cmp_hash_cfg_path, @station_list) = @ARGV;

# Load satation-date hash configuration:
my $ref_cmp_cfg = retrieve($cmp_hash_cfg_path);

# Select 'ALL' stations:
if ($station_list[0] eq 'ALL') {
  @station_list = keys %{ $ref_cmp_cfg };
}

for my $station (@station_list) {
  for my $date (keys %{ $ref_cmp_cfg->{$station} }) {
    for my $signal (keys %{ $ref_cmp_cfg->{$station}{$date}{CFG_PATH} }) {
      my $grpp_launch = GRPP;
      my $grpp_config = $ref_cmp_cfg->{$station}{$date}{CFG_PATH}{$signal};
      say "";
      say "$grpp_launch $grpp_config";
      say "";
      qx{ $grpp_launch $grpp_config > $station-$date-$signal.stdout };
    }
  }
}



# ---------------------------------------------------------------------------- #
# END OF SCRIPT
