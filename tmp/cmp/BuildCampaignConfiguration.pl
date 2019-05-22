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

my $script_description = <<'EOF';
# ============================================================================ #
# Script: BuildCampaignConfiguration.pl
# ============================================================================ #
# Purpose: Sets configuration files based on the available templates in
#          $cmp_root_path/cfg/temp/_station_date_$signla.cfg
#
# ============================================================================ #
# Usage:
# ============================================================================ #
#  ./BuildCampaignConfiguration.pl <cmp_root_path> <station_date_hash_bin>
#
# * NOTE:
#    - Station-date hash configuration must be in binary format
#    - Station-date hash must have YY_MO_DD, INI_TIME and END_TIME
#      entries for each station date pair
#    - Station-date hash must have SIGNAL_OBS entry
#    - Configuration templates must be located at $cmp_root_path/cfg/temp
#
# ============================================================================ #
# Script arguments:
# ============================================================================ #
#  - $1 -> Campaign root path
#  - $2 -> Station-Date configuration hash (Storable binary)
#
EOF
print $script_description;

# Read script argument:
my ($cmp_root_path, $cmp_hash_cfg_path) = @ARGV;

# Retrieve absolute paths:
   $cmp_root_path = abs_path( $cmp_root_path );
my $cfg_root_path = abs_path( join('/', $cmp_root_path, 'cfg') );
my $tmp_root_path = abs_path( join('/', $cmp_root_path, 'tmp') );

# Load satation-date hash configuration:
my $ref_cmp_cfg = retrieve($cmp_hash_cfg_path);

# Set PutConfiguration scrip path:
my $set_cfg_script =
  join('/', SRC_ROOT_PATH, 'tmp', 'cmp', 'PutProcessingConfiguration.sh' );

for my $station (keys %{$ref_cmp_cfg}) {
  for my $date (keys %{$ref_cmp_cfg->{$station}}) {

    # Set processing start and end times:
    my $ini =
       BuildDateString(@{ $ref_cmp_cfg->{$station}{$date}{YY_MO_DD} },
                       @{ $ref_cmp_cfg->{$station}{$date}{INI_TIME} });

    my $end =
       BuildDateString(@{ $ref_cmp_cfg->{$station}{$date}{YY_MO_DD} },
                       @{ $ref_cmp_cfg->{$station}{$date}{END_TIME} });

    for my $signal (keys %{$ref_cmp_cfg->{$station}{$date}{SIGNAL_OBS}}) {

      # Retrieve observation RINEX code:
      my $obs = $ref_cmp_cfg->{$station}{$date}{SIGNAL_OBS}{$signal};

      # Copy template:
      my $temp_file_path =
         join('/', $cfg_root_path, "temp", "station_date_$signal.cfg");
      my $cfg_file_path =
         join('/', $cfg_root_path, join('_', $station, $date, $signal).".cfg");

      say "Copying: $temp_file_path -> $cfg_file_path";
      qx{cp $temp_file_path $cfg_file_path};

      # Put configuration in template:
      say "Putting configuration...";
      qx{$set_cfg_script $cfg_file_path \"$cmp_root_path\" \"$station\" \"$date\" \"$ini\" \"$end\" \"$signal\" \"$obs\"};

      # Save configuration path in hash:
      $ref_cmp_cfg->{$station}{$date}{CFG_PATH}{$signal} = $cfg_file_path;

    } # end for $signal
  } # end for $date
} # end for $station

# Save hash configuration adding configuration information:
my $new_cmp_hash_file = 'ref_station_date_index_obs_cfg.hash';
store( $ref_cmp_cfg, join('/', $tmp_root_path, $new_cmp_hash_file) );

# ---------------------------------------------------------------------------- #
# END OF SCRIPT
