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
#   $1 -> Campaign root path
#   $2 -> Station-Date hash configuration (binary hash)
my ($dat_root_path, $cmp_cfg_hash_path) = @ARGV;

# Set absolute path for campaign root:
$dat_root_path = abs_path($dat_root_path);

# Load satation-date hash configuration:
my $ref_cmp_cfg = retrieve($cmp_cfg_hash_path);

# Create index path:
my $index_path = join('/', $dat_root_path, "index", "");
qx{mkdir $index_path} unless (-e $index_path);

# Iterate over stations and dates:
for my $station (keys %{ $ref_cmp_cfg }) {
  for my $date (keys %{ $ref_cmp_cfg->{$station} }) {

    # Retrieve station-date absolute path whhere rinex data is stored:
    my $station_date_data_path = join('/', $dat_root_path, $station, $date);

    # Find observation file:
    my $obs_file_path = qx{ls $station_date_data_path/*MO.rnx};
    chomp $obs_file_path;
    say $obs_file_path;

    # Find GPS navigation file:
    my $gps_nav_file_path = qx{ls $station_date_data_path/*GN.rnx};
    chomp $gps_nav_file_path;
    say $gps_nav_file_path;

    # Find GAL navigation file:
    my $gal_nav_file_path = qx{ls $station_date_data_path/*EN.rnx};
    chomp $gal_nav_file_path;
    say $gal_nav_file_path;

    # Build synbolic links in index path:
    my $obs_link_name     = join('_', $station, $date, "OBS");
    my $gps_nav_link_name = join('_', $station, $date, "GPS-NAV");
    my $gal_nav_link_name = join('_', $station, $date, "GAL-NAV");

    my $obs_link_path     = join('/', $index_path, $obs_link_name);
    my $gps_nav_link_path = join('/', $index_path, $gps_nav_link_name);
    my $gal_nav_link_path = join('/', $index_path, $gal_nav_link_name);

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

print Dumper $ref_cmp_cfg;
store($ref_cmp_cfg, "ref_station_date_link_cfg.hash");

# ---------------------------------------------------------------------------- #
# END OF SCRIPT
