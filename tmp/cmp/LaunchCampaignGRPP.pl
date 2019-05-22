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

my $script_description = <<'EOF';
# ============================================================================ #
# Script: LaunchCampaignGRPP.pl
# ============================================================================ #
# Purpose: Launches campaign GRPP commands. GRPP STDOUT of each command is
#          stored in $cmp_root_path/rpt/grpp_stdout/
#
# ============================================================================ #
# Usage:
# ============================================================================ #
#  ./LaunchCampaignGRPP.pl <cmp_root_path> <station_date_hash> @station_list
#
# * NOTE:
#    - Station-date hash configuration must be in binary format
#    - Station-date hash must have CFG_PATH entry
#    - Write 'ALL' in <station_list> for launching all campaign stations
#    - Write the station IDs separted by spaces for only launching GRPP on
#      the specified stations.
#
# ============================================================================ #
# Script arguments:
# ============================================================================ #
#  - $1 -> Campaign root path
#  - $2 -> Station-Date configuration hash (Storable binary)
#  - @  -> List of station (station ID in uppercase)
#
EOF
print $script_description;

# Read script arguments:
my ($cmp_root_path, $cmp_hash_cfg_path, @station_list) = @ARGV;

# Retrieve paths:
my $rpt_root_path = abs_path( join('/', $cmp_root_path, 'rpt') );

# Make directory for stdout:
my $stdout_root_path = join('/', $rpt_root_path, "stdout");
qx{mkdir $stdout_root_path} unless (-e $stdout_root_path);

# Load satation-date hash configuration:
my $ref_cmp_cfg = retrieve($cmp_hash_cfg_path);

# Set GRPP launch command:
my $grpp_launch = GRPP; # loaded from Enviroments.pm

# Select 'ALL' stations:
if ($station_list[0] eq 'ALL') {
  @station_list = keys %{ $ref_cmp_cfg };
}

# Inform about stations:
say "GRPP will be launched for : ", join(', ', @station_list);

for my $station (@station_list) {
  for my $date (keys %{ $ref_cmp_cfg->{$station} }) {
    for my $signal (keys %{ $ref_cmp_cfg->{$station}{$date}{CFG_PATH} }) {

      # Set stdout+stderr file:
      my $stdout_file =
        join( '/', $stdout_root_path,
          join('_', $station, $date, $signal).".stdout" );

      # Retrieve configuration file:
      my $grpp_config = $ref_cmp_cfg->{$station}{$date}{CFG_PATH}{$signal};

      # Launch command:
      say "Launching : $grpp_launch $grpp_config";
      say "   STDOUT : $stdout_file";
      qx{ $grpp_launch $grpp_config 1> $stdout_file 2>&1 };

    } # end for $signal
  } # end for $date
} # end for $station



# ---------------------------------------------------------------------------- #
# END OF SCRIPT
