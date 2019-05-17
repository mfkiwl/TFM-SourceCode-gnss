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

# Read script argument:
#   $1 -> Configuration root path
#   $2 -> Station-Date hash configuration (binary hash)
my ($cfg_root_path, $ref_station_date_hash_path) = @ARGV;

# Set absolute path:
$cfg_root_path = abs_path($cfg_root_path);

# Load satation-date hash configuration:
my $ref_station_date_cfg = retrieve($ref_station_date_hash_path);

# Set PutConfiguration scrip path:
my $set_cfg_script =
  '/home/ppinto/WorkArea/src/tmp/cmp/PutProcessingConfiguration.sh';

for my $station (keys %{$ref_station_date_cfg}) {
  for my $date (keys %{$ref_station_date_cfg->{$station}}) {

    # Set processing start and end times:
    my $ini =
       BuildDateString(@{ $ref_station_date_cfg->{$station}{$date}{YY_MO_DD} },
                       @{ $ref_station_date_cfg->{$station}{$date}{INI_TIME} });

    my $end =
       BuildDateString(@{ $ref_station_date_cfg->{$station}{$date}{YY_MO_DD} },
                       @{ $ref_station_date_cfg->{$station}{$date}{END_TIME} });

    for my $signal (keys %{$ref_station_date_cfg->{$station}{$date}{SIGNAL_OBS}}) {

      # Retreve observation:
      my $obs =
         $ref_station_date_cfg->{$station}{$date}{SIGNAL_OBS}{$signal};

      # Copy template:
      my $temp_file_path =
         join('/', $cfg_root_path, "temp", "station_date_$signal.cfg");
      my $cfg_file_path =
         join('/', $cfg_root_path, join('_', $station, $date, $signal).".cfg");

      qx{cp $temp_file_path $cfg_file_path};

      # Put configuration in template:
      qx{$set_cfg_script $cfg_file_path \"$station\" \"$date\" \"$ini\" \"$end\" \"$signal\" \"$obs\"};

      # Save configuration path in hash:
      $ref_station_date_cfg->{$station}{$date}{CFG_PATH}{$signal} = $cfg_file_path;

    }
  }
}

# Save hash configuration:
print Dumper $ref_station_date_cfg;
store($ref_station_date_cfg, "ref_station_date_link_obs_cfg.hash");


# ---------------------------------------------------------------------------- #
# END OF SCRIPT
