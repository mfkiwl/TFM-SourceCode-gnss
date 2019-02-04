#!/usr/bin/perl -w

# Load bash enviroments:
# ---------------------------------------------------------------------------- #
use lib $ENV{ ENV_ROOT };
use Enviroments qq(:CONSTANTS);

# Load built-in modules:
# ---------------------------------------------------------------------------- #
use Carp;
use strict;
use Data::Dumper;
use feature qq(say);

# Load custom modules:
# ---------------------------------------------------------------------------- #
use lib LIB_ROOT_PATH;
use MyUtil  qq(:ALL);
use MyPrint qq(:ALL);

use lib GRPP_ROOT_PATH;
use RinexReader qq(:ALL);

# Script arguments:
my ( $obs_rinex_path, @sat_sys ) = @ARGV;

my $flag_all_sat_sys = TRUE unless @sat_sys;

my $ref_obs_rinex_head =
  ReadObservationRinexHeader( $obs_rinex_path, *STDOUT );

print Dumper $ref_obs_rinex_head;

# Print available observations for each constellation:
