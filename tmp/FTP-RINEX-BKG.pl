#!/usr/bin/perl

use strict;
use warnings;

use feature qw(say);
use Data::Dumper;

# ---------------------------------------------------------------------------- #
# SCRIPT:
# Download RINEX v303 from Bundesamt für Kartographie und Geodäsie (BKG)
# file repository.
# ---------------------------------------------------------------------------- #

# Script arguments:
# - $1 -> Year
# - $2 -> Day of year
# - $3 -> file containing the stations
# - $4 -> storage path

my ($year, $doy_raw, $stations_file_path, $storage_path) = @ARGV;

# Default value for storage path:
$storage_path = "./" unless $storage_path;

# ---------------------------------------------------------------------------- #

# Main variables:
my $yy  = substr($year, 2, 2);       # last two digits of year...
my $doy = sprintf("%03d", $doy_raw); # day of year (3 leading zeros format)...
my $yyo = $yy."o";                   # target rinex extension...

# CDDIS ftp path:
my $ftp_parent = qq(ftp://igs.bkg.bund.de/IGS/obs/);
my $ftp_rinex = $ftp_parent."$year/$doy/";


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
# Content is split by any combination of: \n, \t, ' ', ','...
my @stations_list = split(/\s+|,\s*/,  $stations_content);

# Stations names to upper case:
@stations_list = map(uc, @stations_list);


# Download Observation RINEXs:
# ---------------------------------------------------------------------------- #
my $ref_rinex_list = {};

foreach my $station (@stations_list) {
  # Get RINEX name:
  my $rinex      = $station.'*'.$year.$doy.'*MO.crx.gz';
  my $rinex_url  = $ftp_rinex.$rinex;

  # Download RINEX using bash 'wget' command:
  qx{wget $rinex_url};
  my $rinex_name = qx{ls $rinex}; chomp $rinex_name;

  # Move the downloaded files to storage path if defined:
  qx{mv $rinex_name $storage_path};

  # Fill file status hash:
  my $rinex_path = join('/', ($storage_path, $rinex_name));

  my $status =
    (-e join('/', ($storage_path, $rinex_name))) ? "DOWNLOADED" : "NOT DOWNLOADED";
  $ref_rinex_list->{join('-', ($station, "OBS"))} = $status;
}


# Download Navigation RINEXs:
# ---------------------------------------------------------------------------- #
my $nav_file_input = '';

until ($nav_file_input =~ /yes/i || $nav_file_input =~ /no/i) {
  say "Would you like to download navigation files as well? (yes/no)";
  $nav_file_input = <STDIN>; chomp $nav_file_input;
}

if ( $nav_file_input =~ /yes/i )
{
  # Ask for satellite systems:
  say "Please provide the constellations from which you would like the ".
      "navigation data (G/E/R): ";
  my $sat_sys_input = <STDIN>; chomp $sat_sys_input;

  # Get satellite system array list:
  my @sat_sys_list = split(/[\s,;]+/, $sat_sys_input);

  # Iterate over satellite system and station:
  for my $sat_sys (@sat_sys_list) {
    for my $station (@stations_list) {
      my $rinex      = $station.'*'.$year.$doy.'*'.$sat_sys.'N.rnx.gz';
      my $rinex_url  = $ftp_rinex.$rinex;

      # Download RINEX using bash 'wget' command:
      qx{wget $rinex_url};

      # Get navigation rinex file name:
      my $rinex_name = qx{ls $rinex};

      # Move the downloaded files to storage path if defined:
      qx{mv $rinex $storage_path};

      # Fill file status hash:
      my $status =
        (-e join('/', ($storage_path, $rinex_name))) ?
          "DOWNLOADED" : "NOT DOWNLOADED";
      $ref_rinex_list->{join('-', ($station, $sat_sys, "NAV"))} = $status;
    }
  }

} else {

  say "RINEX navigaton files will not be downlowaded";

}

# Print the status of the requested files:
say ""; print Dumper $ref_rinex_list; say "";

# Print the storage output if defined:
say " > Downloaded RINEX are available in $storage_path \n" if $storage_path;
