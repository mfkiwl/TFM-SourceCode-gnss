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
#   $1 -> Station-Date hash configuration (binary hash)
my ($cmp_cfg_hash_path) = @ARGV;

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

# KITG:
for $station (qw(KITG)) {
  for $date  (qw(DATE_1 DATE_2)) {
    $ref_cmp_cfg->{$station}{$date}{SIGNAL_OBS}{ CA  } = 'C1C';
    $ref_cmp_cfg->{$station}{$date}{SIGNAL_OBS}{ L2C } = 'C2L';
    $ref_cmp_cfg->{$station}{$date}{SIGNAL_OBS}{ E1  } = 'C1C';
    $ref_cmp_cfg->{$station}{$date}{SIGNAL_OBS}{ E5B } = 'C7Q';
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

# Save hash configuration:
print Dumper $ref_cmp_cfg;
store($ref_cmp_cfg, "ref_station_date_link_obs.hash");


# ---------------------------------------------------------------------------- #
# END OF SCRIPT
