#!/usr/bin/perl -X

# Perl modules:
# ---------------------------------------------------------------------------- #
use Carp;
use strict;

use Data::Dumper;
use feature qq(say);
use Cwd qq(abs_path);

# Own modules:
# ---------------------------------------------------------------------------- #
use lib $ENV{ ENV_ROOT };
use Enviroments qq(:CONSTANTS);

use lib SRC_ROOT_PATH;
use GeneralConfiguration qq(:ALL);

use lib LIB_ROOT_PATH;
use MyUtil  qq(:ALL);
use MyPrint qq(:ALL);

# ---------------------------------------------------------------------------- #
# SCRIPT:
# TODO: add help entry and STDOUT information
# Download NAV RINEX v303 from Bundesamt für Kartographie und Geodäsie (BKG)
# file repository.
# ---------------------------------------------------------------------------- #

# Script arguments:
# - $1 -> Satellite system (G, E, R, B, ...)
# - $2 -> Year
# - $3 -> Day of year
# - $4 -> station (Site or Site ID)
# - $5 -> storage path

# TODO: Add consistency check for input arguments:
my ($sat_sys, $year, $doy, $station, $storage_path) = @ARGV;

# Default value for storage path:
$storage_path = "./" unless $storage_path;

# Day of Year is formated with 3 leading zeros:
$doy = sprintf("%03d", $doy);

# Station ID is uppercased just in case:
$station = uc $station;

# Define parent BKG url, and reach corresponding year and day URL:
my $ftp_parent   = 'ftp://igs.bkg.bund.de/IGS/obs/';
my $ftp_year_doy = $ftp_parent."$year/$doy/";

# Define navigation rinex pattern and download URL:
my $rinex_pattern = $station.'*'.$year.$doy.'*'.$sat_sys.'N.rnx.gz';
my $rinex_url = join('/', ($ftp_year_doy, $rinex_pattern));

# Download RINEX using bash 'wget' command:
qx{wget $rinex_url};

# Get navigation rinex file name:
my $rinex_ls   = qx{ls $rinex_pattern}; chomp $rinex_ls;
my @rinex_list = split("\n", $rinex_ls);

# Move the downloaded files to storage path if defined:
qx{mv $_ $storage_path} for @rinex_list;
