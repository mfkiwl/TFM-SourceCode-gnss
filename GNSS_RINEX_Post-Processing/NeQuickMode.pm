#!/usr/bin/perl -w

# Package declaration:
package NeQuickMode;


# SCRIPT DESCRIPTION GOES HERE:

# Load bash enviroments:
# ---------------------------------------------------------------------------- #
use lib $ENV{ ENV_ROOT };
use Enviroments qq(:CONSTANTS);

# Import Modules:
# ---------------------------------------------------------------------------- #
use Carp;
use strict; # enables strict syntax...

use PDL;
use PDL::Constants qw(PI);
use Scalar::Util qq(looks_like_number); # scalar utility...

use feature qq(say); # print adding carriage return...
use Data::Dumper;    # enables pretty print...

# Import configuration and common interface module:
use lib SRC_ROOT_PATH;
use GeneralConfiguration qq(:ALL);

# Import dedicated libraries:
use lib LIB_ROOT_PATH;
use MyUtil   qq(:ALL); # useful subs and constants...
use MyMath   qq(:ALL); # useful mathematical methods...
use MyPrint  qq(:ALL); # error and warning utilities...
use Geodetic qq(:ALL); # geodesy methods and constants...
use TimeGNSS qq(:ALL); # GNSS time transforming utilities...

# Set package exportation properties:
# ---------------------------------------------------------------------------- #
BEGIN {
  # Load export module:
  require Exporter;

  # Set package version:
  our $VERSION = 1.0;

  # Inherit from Exporter to export subs and constants:
  our @ISA = qq(Exporter);

  # Default export:
  our @EXPORT = ();

  # Define constants to export:
  our @EXPORT_CONST = qw( &REF_CCIR_HASH
                          &REF_MODIP_MAP );

  # Define subroutines to export:
  our @EXPORT_SUB   = qw( &ComputeMODIP
                          &ComputeEffectiveIonisationLevel
                          &ComputeNeQuickModelParameters
                          &IntegrateNeQuickSlantTEC
                          &IntegrateNeQuickVerticalTEC );

  # Merge constants$rec_lon subroutines:
  our @EXPORT_OK = (@EXPORT_CONST, @EXPORT_SUB);

  # Define export tags:
  our %EXPORT_TAGS = ( ALL         => \@EXPORT_OK,
                       DEFAULT     => \@EXPORT,
                       CONSTANTS   => \@EXPORT_CONST,
                       SUBROUTINES => \@EXPORT_SUB );

}

# ---------------------------------------------------------------------------- #
# Preliminary MODIP & CCIR file mapping:
# ---------------------------------------------------------------------------- #

# File configuration:
use constant MODIP_FILE_PATH     => NEQUICK_DAT_PATH.qq(modipNeQG_wrapped.txt);
use constant CCIR_BASE_FILE_NAME => qq(ccir);
use constant CCIR_FILE_EXTENSION => qq(.txt);

# CCIR line template:
use constant CCIR_LINE_TEMPLEATE => 'A16'x4;

# CCIR array arrangement:
use constant {
  CCIR_F2_ROW_DIM  => 2,
  CCIR_F2_COL_DIM  => 76,
  CCIR_F2_DEP_DIM  => 13,
  CCIR_FM3_ROW_DIM => 2,
  CCIR_FM3_COL_DIM => 49,
  CCIR_FM3_DEP_DIM => 9,
};

# MODIP array arrangement:
use constant {
  MODIP_ROW_DIM => 39,
  MODIP_COL_DIM => 39,
};

sub LoadMODIPFile {
  my ($modip_file_path) = @_;

  # Init array reference for storing MODIP map matrix:
  my $ref_modip_map = [];

  # Open file:
  my $fh; open($fh, '<', $modip_file_path) or croak $!;

  my @modip_array;
  while (my $line = <$fh>) {
    chomp $line;
    push( @modip_array, split(/ +/, PurgeExtraSpaces($line)) );
  }

  # Close file:
  close($fh);

  # Build up MODIP map:
  for (my $i = 0; $i < MODIP_ROW_DIM; $i += 1) {
    for (my $j = 0; $j < MODIP_COL_DIM; $j += 1) {
      $ref_modip_map->[$i][$j] = shift @modip_array;
    }
  }

  return $ref_modip_map;
}

sub LoadCCIRFiles {
  my ($ccir_data_path) = @_;

  # Init CCIR hash to be returned:
  my $ref_ccir_hash = {};

  # Iterate over all year months:
  for my $month (1..12) {

    # Set CCIR hash entry for month:
    $ref_ccir_hash->{$month}{ F2  } = [];
    $ref_ccir_hash->{$month}{ FM3 } = [];

    # Build file path:
    my $ccir_file_path =
       NEQUICK_DAT_PATH.CCIR_BASE_FILE_NAME.(10 + $month).CCIR_FILE_EXTENSION;

    # Open CCIR month file:
    my $fh; open($fh, '<', $ccir_file_path) or croak $!;

    # Load file in memory as single line string:
    # TODO: consider constants for CCIR file format
    my @ccir_array;
    while (my $line = <$fh>) {
      chomp $line;
      push( @ccir_array,
            map { PurgeExtraSpaces($_) } unpack(CCIR_LINE_TEMPLEATE, $line) );
    }

    # Close CCIR month file:
    close($fh);

    # Build up F2 matrix from CCIR array:
    for (my $i = 0; $i < CCIR_F2_ROW_DIM; $i += 1) {
      for (my $j = 0; $j < CCIR_F2_COL_DIM; $j += 1) {
        for (my $k = 0; $k < CCIR_F2_DEP_DIM; $k += 1) {
          $ref_ccir_hash->{$month}{F2}[$i][$j][$k] = shift @ccir_array;
        }
      }
    }

    # Build up FM3 matrix from CCIR array:
    for (my $i = 0; $i < CCIR_FM3_ROW_DIM; $i += 1) {
      for (my $j = 0; $j < CCIR_FM3_COL_DIM; $j += 1) {
        for (my $k = 0; $k < CCIR_FM3_DEP_DIM; $k += 1) {
          $ref_ccir_hash->{$month}{FM3}[$i][$j][$k] = shift @ccir_array;
        }
      }
    }

  } # end for $month

  return $ref_ccir_hash;
}


# ---------------------------------------------------------------------------- #
# Constants:
# ---------------------------------------------------------------------------- #
use constant
    ZENIT_ANGLE_DAY_NIGHT_TRANSITION => 86.23292796211615*DEGREE_TO_RADIANS;

use constant REF_CCIR_HASH => LoadCCIRFiles( DAT_ROOT_PATH   );
use constant REF_MODIP_MAP => LoadMODIPFile( MODIP_FILE_PATH );

# ---------------------------------------------------------------------------- #
# Subroutines:
# ---------------------------------------------------------------------------- #

# Public Subroutines: #
# ............................................................................ #

sub ComputeMODIP {
  my ($lat, $lon) = @_;

  # Preliminary --> Transform latitude and longitude to degree format:
  $lat *= RADIANS_TO_DEGREE;
  $lon *= RADIANS_TO_DEGREE;

  # Init MODIP value to be returned:
  my $modip;

  # Latitude extreme cases:
  if      ( $lat ==  90 ) {
    $modip =  90;
  } elsif ( $lat == -90 ) {
    $modip = -90;
  } else { # For the rest of the cases, MODIP interpolation is performed:

    # Longitude grid index:
    my $lon_index  = int( ($lon + 180)/10 ) - 2;
       $lon_index += 36 if $lon_index < 0;
       $lon_index -= 36 if $lon_index > 33;

    # Tipificate latitude point to interpolate:
    my $aux1 = ($lat + 90)/5 + 1;
    my $x    = $aux1 - int($aux1);

    # Latitude grid index:
    my $lat_index = int($aux1) - 2;

    # Build buffer grid
    my $ref_modip_buffer_grid = [];

    for my $k (0..3) {
      for my $j (0..3) {
        $ref_modip_buffer_grid->[$j][$k] =
          REF_MODIP_MAP->[$lat_index + $j][$lon_index + $k];
      }
    }

    # Interpolate on latitude grid buffer:
    my @z_interpolated_lat;
    for my $k (0..3) {
      push ( @z_interpolated_lat,
             ThirdOrderInterpolation($ref_modip_buffer_grid->[0][$k],
                                     $ref_modip_buffer_grid->[1][$k],
                                     $ref_modip_buffer_grid->[2][$k],
                                     $ref_modip_buffer_grid->[3][$k], $x) );
    }

    # Tipificate longitude point to interpolate:
    my $aux2 = ($lon + 180)/10;
    my $y    = $aux2 - int($aux2);

    # Interpolate on longitude grid buffer in order to retrive MODIP:
    $modip = ThirdOrderInterpolation( @z_interpolated_lat, $y );

  }

  # MODIP is returned in radians:
  return $modip*DEGREE_TO_RADIANS;
}

sub ComputeEffectiveIonisationLevel {}

sub ComputeNeQuickModelParameters {}

sub IntegrateNeQuickSlantTEC {}

sub IntegrateNeQuickVerticalTEC {}


# Private Subroutines: #
# ............................................................................ #

# ************************************************** #
# First Level Subroutines:                           #
#   Subroutines called from main public subroutines. #
# ************************************************** #

# ******************************************************** #
# Second Level Subroutines:                                #
#   Subroutines called from 1st level private subroutines. #
# ******************************************************** #

# ******************************************************** #
# Third Level Subroutines:                                 #
#   Subroutines called from 2nd level private subroutines. #
# ******************************************************** #

# ******************************************************** #
# Forth Level Subroutines:                                 #
#   Subroutines called from 3rd level private subroutines. #
# ******************************************************** #

TRUE;
