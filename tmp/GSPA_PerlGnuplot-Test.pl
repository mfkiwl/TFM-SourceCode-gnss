#!/usr/bin/perl -w

use Carp;
use strict;

use Storable;
use Data::Dumper;
use feature qq(say);
use feature qq(switch);

use PDL;
use Chart::Gnuplot;

# Load enviroments:
use lib $ENV{ ENV_ROOT };
use Enviroments qq(:CONSTANTS);

# Load common modules:
use lib LIB_ROOT_PATH;
# Common tools:
use MyUtil   qq(:ALL); # useful subs and constants...
use MyPrint  qq(:ALL); # print and warning/failure utilities...
# GNSS dedicated tools:
use Geodetic qq(:ALL); # geodetic toolbox...
use TimeGNSS qq(:ALL); # GNSS time transforming utilities..

# ============================================================================ #
# Main Routine:                                                                #
# ============================================================================ #

# Preliminary:
#  - Identify script arguments:
#    $1 --> satellite system
#    $2 --> raw_data input path
#    $3 --> plots output path

if ( scalar(@ARGV) == 0 || scalar(@ARGV) > 3 ) {
  croak "Bad script argument provision";
}

my ( $sat_sys, $inp_path, $out_path ) = @ARGV;

$out_path = "." unless $out_path;

unless (-d $inp_path) { croak "Input path '$inp_path' is not a directory"; }
unless (-d $out_path) { croak "Output path '$out_path' is not a directory"; }

# Load hash references from input folder:
my $ref_gen_conf = retrieve("$inp_path/ref_gen_conf.hash");
my $ref_obs_data = retrieve("$inp_path/ref_obs_data.hash");

# ---------------------------------------------------------------------------- #
# 1. Satellite system plots:
# ---------------------------------------------------------------------------- #

# ************************************** #
#    1.a Constellation availability:     #
# ************************************** #

  PlotConstellationAvailability($ref_gen_conf, $inp_path, $sat_sys);


# ******************* #
#    1.c Sky plot:    #
# ******************* #

# ---------------------------------------------------------------------------- #
# 2. Receiver Position plots:
# ---------------------------------------------------------------------------- #

# *********************************************** #
#    2.a Easting/Northing point densisty plot:
# *********************************************** #

#    2.b Upping plot:
#    2.c Easting/Northing/Upping point density 3D plot:


# 3. Ex-post Dilution of Precission:
#    3.a ECEF frame DOP:
#    3.b ENU frame DOP:


# 4. Least Squeares Estimation plots:
#    4.a Number of iterations:
#    4.b Ex-post Standard Deviation Estimator:
#    4.c Delta Parameter estimation:
#    4.d Residuals by satellite:
#    4.e Elevation by satellite (same as 1.b plot)


# 5. Ionosphere and Troposphere Delay Estimation plots:
#    5.a Ionosphere Computed Delay by satellite:
#    5.b Troposphere Computed delay by satellite:
#    5.c Elevation by satellite (same as 1.b plot)


# ============================================================================ #
# Private Functions:                                                           #
# ============================================================================ #
sub PlotConstellationAvailability {
  my ($ref_gen_conf, $inp_path, $sat_sys ) = @_;

  # Select dumper file:
  my $ref_file_layout =
    GetFileLayout($inp_path."/$sat_sys-num-sat-info.out", 4, ";");

  my $ref_num_sat_info =
    GetFileColumn( $ref_file_layout->{FILE}{PATH},
                   $ref_file_layout->{FILE}{HEAD},
                   $ref_gen_conf->{DATA_DUMPER}{DELIMITER} );


  # For each epoch Retrieve:
    # Epochs in time format:

    # Num available satellites:
    my $pdl_num_sat_info = pdl($ref_num_sat_info);

    print $pdl_num_sat_info;

    # Num valid observation satellites:

    # Num valid navigation satellites:

    # Num

}

sub GetFileLayout {
  my ($file_path, $head_line, $delimiter) = @_;

  my $ref_file_layout = {};

  $ref_file_layout->{FILE}{PATH} = $file_path;
  $ref_file_layout->{FILE}{HEAD} = $head_line;

  my $fh; open($fh, '<', $file_path) or die "Could not open $!";

  while (my $line = <$fh>) {
    if ($. == $head_line) {
      my @head_items = split(/[\s$delimiter]+/, $line);
      for my $index (keys @head_items) {
        $ref_file_layout->{ITEMS}{$head_items[$index]}{INDEX} = $index;
      }
    }
  }

  close($fh);

  return $ref_file_layout;
}

sub GetFileColumn {
  my ($file_path, $head, $delimiter) = @_;

  my $ref_column_array = [];

  my $fh; open($fh, '<', $file_path) or die "Could not open $!";

    SkipLines($fh, $head);

    while (my $line = <$fh>) {
      push( @{$ref_column_array}, [split(/[\s$delimiter]/, $line)] );
    }

  close($fh);

  return $ref_column_array;
}
