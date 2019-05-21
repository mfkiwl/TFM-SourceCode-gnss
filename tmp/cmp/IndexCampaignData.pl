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

my $script_description = <<'EOF';
# ============================================================================ #
# Script: IndexCampaignData.pl
# ============================================================================ #
# Purpose: Creates symbolic links to RINEX observation and navigaton data.
#
# ============================================================================ #
# Usage:
# ============================================================================ #
#  ./IndexCampaignData.pl <cmp_root_path> <station_date_hash_bin>
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

# Read script argument:
#   $1 -> Campaign root path
#   $2 -> Station-Date hash configuration (binary hash)
my ($cmp_root_path, $cmp_cfg_hash_path) = @ARGV;

# Retrieve absolute paths:
my $dat_root_path   = abs_path( join('/', $cmp_root_path, 'dat') );
my $tmp_root_path   = abs_path( join('/', $cmp_root_path, 'tmp') );
my $index_root_path = abs_path( join('/', $dat_root_path, 'index') );

# Load satation-date hash configuration:
my $ref_cmp_cfg = retrieve($cmp_cfg_hash_path);

# Create index path if not already:
qx{mkdir $index_root_path} unless (-e $index_root_path);

# Iterate over stations and dates:
for my $station (keys %{ $ref_cmp_cfg }) {
  for my $date (keys %{ $ref_cmp_cfg->{$station} }) {

    # Retrieve station-date absolute path whhere rinex data is stored:
    my $station_date_data_path = join('/', $dat_root_path, $station, $date);

    # Find observation file:
    my $obs_file_path = qx{ls $station_date_data_path/*MO.rnx};
    chomp $obs_file_path; say $obs_file_path;

    # Find GPS navigation file:
    my $gps_nav_file_path = qx{ls $station_date_data_path/*GN.rnx};
    chomp $gps_nav_file_path; say $gps_nav_file_path;

    # Find GAL navigation file:
    my $gal_nav_file_path = qx{ls $station_date_data_path/*EN.rnx};
    chomp $gal_nav_file_path; say $gal_nav_file_path;

    # Build synbolic links in index path:
    my $obs_link_name     = join('_', $station, $date, "OBS");
    my $gps_nav_link_name = join('_', $station, $date, "GPS-NAV");
    my $gal_nav_link_name = join('_', $station, $date, "GAL-NAV");

    my $obs_link_path     = join('/', $index_root_path, $obs_link_name);
    my $gps_nav_link_path = join('/', $index_root_path, $gps_nav_link_name);
    my $gal_nav_link_path = join('/', $index_root_path, $gal_nav_link_name);

    qx{ln -s $obs_file_path $obs_link_path};
    qx{ln -s $gps_nav_file_path $gps_nav_link_path};
    qx{ln -s $gal_nav_file_path $gal_nav_link_path};

    # TODO: Make some consistency checks

    # Append link information to station-date hash:
    my $ref_tmp = $ref_cmp_cfg->{$station}{$date};
    $ref_tmp->{OBS_PATH} = $obs_link_path;
    $ref_tmp->{NAV_PATH}{&RINEX_GPS_ID} = $gps_nav_link_path;
    $ref_tmp->{NAV_PATH}{&RINEX_GAL_ID} = $gal_nav_link_path;

  } # end for $date
} # end for $station

# print Dumper $ref_cmp_cfg;
store( $ref_cmp_cfg, join('/', $tmp_root_path, 'ref_station_date_index.hash') );

# ---------------------------------------------------------------------------- #
# END OF SCRIPT
