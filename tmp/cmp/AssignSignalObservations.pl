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
# Script: AssignSignalObservations.pl
# ============================================================================ #
# Purpose: Sets signal obsertvations RINEX codes for each station, date and
#          signal combination.
#          The singal observations are manually set trough the script in the
#          SIGNAL_OBS entry for each station and date pair. A relation between
#          signal and rinex code observation shall be specified as indicated in
#          the following example:
#          SIGNAL_OBS => {
#            CA => C1C,
#            E1 => C1X,
#            # More signals
#          }
#
# ============================================================================ #
# Usage:
# ============================================================================ #
#  ./AssignSignalObservations.pl <cmp_root_path> <station_date_hash_bin>
#
# * NOTE:
#    - Station-date hash configuration must be in binary format
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

# Retrive absolute paths:
my $tmp_root_path = abs_path( join('/', $cmp_root_path, 'tmp') );

# Load satation-date hash configuration:
my $ref_cmp_cfg = retrieve($cmp_cfg_hash_path);

# Assign observation codes for station-date pair:
my ($station, $date);

# KIRU:
for $station (qw(KIRU)) {
  for $date  (qw(DATE_1 DATE_2 DATE_3)) {
    $ref_cmp_cfg->{$station}{$date}{SIGNAL_OBS}{ CA  } = 'C1C';
    $ref_cmp_cfg->{$station}{$date}{SIGNAL_OBS}{ L2C } = 'C2L';
    $ref_cmp_cfg->{$station}{$date}{SIGNAL_OBS}{ E1  } = 'C1C';
    $ref_cmp_cfg->{$station}{$date}{SIGNAL_OBS}{ E5B } = 'C7Q';
  }
}

# TASH:
for $station (qw(TASH)) {
  for $date  (qw(DATE_1 DATE_2)) {
    $ref_cmp_cfg->{$station}{$date}{SIGNAL_OBS}{ CA  } = 'C1C';
    $ref_cmp_cfg->{$station}{$date}{SIGNAL_OBS}{ L2C } = 'C2X';
    $ref_cmp_cfg->{$station}{$date}{SIGNAL_OBS}{ E1  } = 'C1X';
    $ref_cmp_cfg->{$station}{$date}{SIGNAL_OBS}{ E5B } = 'C5X';
  }
}

# OWMG:
for $station (qw(OWMG)) {
  for $date  (qw(DATE_1 DATE_2)) {
    $ref_cmp_cfg->{$station}{$date}{SIGNAL_OBS}{ CA  } = 'C1C';
    $ref_cmp_cfg->{$station}{$date}{SIGNAL_OBS}{ L2C } = 'C2X';
    $ref_cmp_cfg->{$station}{$date}{SIGNAL_OBS}{ E1  } = 'C1X';
    $ref_cmp_cfg->{$station}{$date}{SIGNAL_OBS}{ E5B } = 'C7X';
  }
}

# KOKV:
for $station (qw(KOKV)) {
  for $date  (qw(DATE_1 DATE_2 DATE_3)) {
    $ref_cmp_cfg->{$station}{$date}{SIGNAL_OBS}{ CA  } = 'C1C';
    $ref_cmp_cfg->{$station}{$date}{SIGNAL_OBS}{ L2C } = 'C2X';
    $ref_cmp_cfg->{$station}{$date}{SIGNAL_OBS}{ E1  } = 'C1X';
    $ref_cmp_cfg->{$station}{$date}{SIGNAL_OBS}{ E5B } = 'C7X';
  }
}

# ABMF:
for $station (qw(ABMF)) {
  for $date  (qw(DATE_1 DATE_2)) {
    $ref_cmp_cfg->{$station}{$date}{SIGNAL_OBS}{ CA  } = 'C1C';
    $ref_cmp_cfg->{$station}{$date}{SIGNAL_OBS}{ L2C } = 'C2W';
    $ref_cmp_cfg->{$station}{$date}{SIGNAL_OBS}{ E1  } = 'C1C';
    $ref_cmp_cfg->{$station}{$date}{SIGNAL_OBS}{ E5B } = 'C7Q';
  }
}

# FAIR:
for $station (qw(FAIR)) {
  for $date  (qw(DATE_3)) {
    $ref_cmp_cfg->{$station}{$date}{SIGNAL_OBS}{ CA  } = 'C1C';
    $ref_cmp_cfg->{$station}{$date}{SIGNAL_OBS}{ L2C } = 'C2W';
    $ref_cmp_cfg->{$station}{$date}{SIGNAL_OBS}{ E1  } = 'C1';
    $ref_cmp_cfg->{$station}{$date}{SIGNAL_OBS}{ E5B } = 'C5';
  }
}

# MAJU:
for $station (qw(MAJU)) {
  for $date  (qw(DATE_3)) {
    $ref_cmp_cfg->{$station}{$date}{SIGNAL_OBS}{ CA  } = 'C1C';
    $ref_cmp_cfg->{$station}{$date}{SIGNAL_OBS}{ L2C } = 'C2L';
    $ref_cmp_cfg->{$station}{$date}{SIGNAL_OBS}{ E1  } = 'C1C';
    $ref_cmp_cfg->{$station}{$date}{SIGNAL_OBS}{ E5B } = 'C7Q';
  }
}

# KOUG:
for $station (qw(KOUG)) {
  for $date  (qw(DATE_3)) {
    $ref_cmp_cfg->{$station}{$date}{SIGNAL_OBS}{ CA  } = 'C1C';
    $ref_cmp_cfg->{$station}{$date}{SIGNAL_OBS}{ L2C } = 'C2L';
    $ref_cmp_cfg->{$station}{$date}{SIGNAL_OBS}{ E1  } = 'C1C';
    $ref_cmp_cfg->{$station}{$date}{SIGNAL_OBS}{ E5B } = 'C7Q';
  }
}

# Show configured observations:
for $station (keys %{ $ref_cmp_cfg }) {
  say "$station";
  for $date   (keys %{ $ref_cmp_cfg->{$station} }) {
    say "\t$date";
    for my $signal (keys %{ $ref_cmp_cfg->{$station}{$date}{SIGNAL_OBS} }) {
      my $obs = $ref_cmp_cfg->{$station}{$date}{SIGNAL_OBS}{$signal};
      say "\t\t$signal -> $obs";
    }
    say "";
  }
  say "";
}

# Save hash configuration adding signal observation configuration:
my $new_cmp_hash_file = 'ref_station_date_index_obs.hash';
store( $ref_cmp_cfg, join('/', $tmp_root_path, $new_cmp_hash_file) );


# ---------------------------------------------------------------------------- #
# END OF SCRIPT
