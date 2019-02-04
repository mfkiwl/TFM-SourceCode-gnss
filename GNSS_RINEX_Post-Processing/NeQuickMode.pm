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
  our @EXPORT_CONST = qw(  );

  # Define subroutines to export:
  our @EXPORT_SUB   = qw(  );

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
use constant MODIP_FILE_PATH     => DAT_ROOT_PATH.qq(modipNeQG_wrapped.txt);
use constant CCIR_BASE_FILE_NAME => qq(ccir);
use constant CCIR_FILE_EXTENSION => qq(.txt);

sub LoadMODIPFile {
  my ($modip_file_path) = @_;

  # Init array reference for storing MODIP map matrix:
  my $ref_modip_map = [];

  # Open file:
  my $fh; open($fh, '<', $modip_file_path) or croak $!;

  # Read file and store data in map:
  while (my $line = <$fh>) {

  }

  # Close file:
  close($fh);

  return $ref_modip_map;
}

sub LoadCCIRFiles {
  my ($ccir_data_path) = @_;

  # Init CCIR hash to be returned:
  my $ref_ccir_hash = {};

  # Iterate over all year months:
  for my $month (1..12) {

    # Set CCIR hash entry for month:
    $ref_ccir_hash->{$month} = [];

    # Build file path:
    my $ccir_file_path =
       DAT_ROOT_PATH.CCIR_BASE_FILE_NAME.(10 + $month).CCIR_FILE_EXTENSION;

    # Open CCIR month file:
    my $fh; open($fh, '<', $ccir_file_path) or croak $!;

    # Read file and store data:
    while ( my $line = <$fh> ) {

    }

    # Close CCIR month file:
    close($fh);

  } # end for $month

  return $ref_ccir_hash;
}


# ---------------------------------------------------------------------------- #
# Constants:
# ---------------------------------------------------------------------------- #
use constant
    ZENIT_ANGLE_DAY_NIGHT_TRANSITION => 86.23292796211615 * DEGREE_TO_RADIANS;

use constant REF_CCIR_HASH => LoadCCIRFiles( DAT_ROOT_PATH   );
use constant REF_MODIP_MAP => LoadMODIPFile( MODIP_FILE_PATH );

# ---------------------------------------------------------------------------- #
# Subroutines:
# ---------------------------------------------------------------------------- #

# Public Subroutines: #
# ............................................................................ #

sub ComputeMODIP {}

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
