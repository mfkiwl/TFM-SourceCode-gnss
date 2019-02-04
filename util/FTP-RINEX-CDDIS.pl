#!/usr/bin/perl

use strict;
use warnings;
use diagnostics;

use feature qw(say);
use Data::Dumper;

# ---------------------------------------------------------------------------- #
# SCRIPT:
# Download RINEX v211 from Crustal Dynamics Data Information Systems (CDDIS)
# file repository.
# ---------------------------------------------------------------------------- #

# Script arguments:
# - $1 -> Year
# - $2 -> Day of year
# - $3 -> file containing the stations
# - $4 -> storage path

my ($year, $doy_raw, $stations_file_path, $storage_path) = @ARGV;

# ---------------------------------------------------------------------------- #

# Main variables:
my $yy  = substr($year, 2, 2);       # last two digits of year...
my $doy = sprintf("%03d", $doy_raw); # day of year (3 leading zeros format)...
my $yyo = $yy."o";                   # target rinex extension...

# CDDIS ftp path:
my $ftp_parent = qw(ftp://ftp.cddis.eosdis.nasa.gov/pub/gnss/data/daily);
my $ftp_rinex = $ftp_parent."/$year/$doy/$yyo/";


# Get station list:
# ---------------------------------------------------------------------------- #
# Open stations file:
my $fh; open($fh, "<", $stations_file_path) or die $!;

# Store file content in internal variable:
my $stations_content;
while (my $line = <$fh>) { $stations_content.= $line; }

# Close stations file:
close($fh);

# Split station content into internal array:
my @stations = split(/\s+|\t\s*|,\s*|\n\s*/,  $stations_content);

# Stations names to lower case:
@stations = map(lc, @stations);


# Download RINEXs:
# ---------------------------------------------------------------------------- #
my %rinex_list;

foreach my $station (@stations) {
  # Get RINEX name:
  my $rinex = $station.$doy."0.".$yyo.".Z";

  # Download RINEX:
  qx(wget $ftp_rinex.$rinex);

  # Fill file status hash:
  my $rinex_status;
  if (-e $rinex) { $rinex_status = qw(DOWNLOADED);     }
  else           { $rinex_status = qw(NOT DOWNLOADED); }

  $rinex_list{$rinex} = $rinex_status;

  # Move the downloaded files to storage path if defined:
  qx(mv $rinex $storage_path) if $storage_path;
}

# Print the status of the requested files:
print Dumper \%rinex_list;

# Print the storage output if defined:
if ($storage_path) {
  say "Downloaded files are available in path :\n", say $storage_path;
}

# ---------------------------------------------------------------------------- #
# End of Script
