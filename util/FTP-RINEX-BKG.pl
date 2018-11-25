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
my %rinex_list;

foreach my $station (@stations_list) {
  # Get RINEX name:
  my $rinex      = $station.'*'.$year.$doy.'*O.crx.gz';
  my $rinex_url  = $ftp_rinex.$rinex;

  # Download RINEX using bash 'wget' command:
  qx(wget $rinex_url);

  # Fill file status hash:
  $rinex_list{$station."-OBS"} =
    (-e $rinex) ? qw(DOWNLOADED) : qw(NOT DOWNLOADED);

  # Move the downloaded files to storage path if defined:
  qx(mv $rinex $storage_path) if $storage_path;
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
      qx(wget $rinex_url);

      # Fill file status hash:
      $rinex_list{join('-', ($station, $sat_sys, "NAV"))} =
        (-e $rinex) ? qw(DOWNLOADED) : qw(NOT DOWNLOADED);

      # Move the downloaded files to storage path if defined:
      qx(mv $rinex $storage_path) if $storage_path;
    }
  }

} else {

}

# Print the status of the requested files:
say ""; print Dumper \%rinex_list; say "";

# Print the storage output if defined:
say " > Downloaded RINEX are available in $storage_path \n" if $storage_path;
