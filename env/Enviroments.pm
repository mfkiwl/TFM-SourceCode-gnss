#!/usr/bin/perl

package Enviroments;

# Built-in modules
# ---------------------------------------------------------------------------- #
use Carp;
use strict;
use Data::Dumper;
use feature qq(say);

# Package properties
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
  our @EXPORT_CONST = qw( &SRC_ROOT_PATH
                          &LIB_ROOT_PATH
                          &DAT_ROOT_PATH
                          &UTIL_ROOT_PATH
                          &GRPP_ROOT_PATH
                          &GSPA_ROOT_PATH
                          &GRPP
                          &GSPA_SOLE
                          &GSPA_DUAL
                          &NEQUICK_DAT_PATH );

  # Define subroutines to export:
  our @EXPORT_SUB   = qw(  );

  # Merge constants and subroutines:
  our @EXPORT_OK = (@EXPORT_CONST, @EXPORT_SUB);

  # Define export tags:
  our %EXPORT_TAGS = ( ALL         => \@EXPORT_OK,
                       DEFAULT     => \@EXPORT,
                       CONSTANTS   => \@EXPORT_CONST,
                       SUBROUTINES => \@EXPORT_SUB );
}


# Define bash enviromets as perl constants:
# ---------------------------------------------------------------------------- #
use constant {
  SRC_ROOT_PATH  => $ENV{ SRC_ROOT  },
  LIB_ROOT_PATH  => $ENV{ LIB_ROOT  },
  DAT_ROOT_PATH  => $ENV{ DAT_ROOT  },
  UTIL_ROOT_PATH => $ENV{ UTIL_ROOT },
  GRPP_ROOT_PATH => $ENV{ GRPP_ROOT },
  GSPA_ROOT_PATH => $ENV{ GSPA_ROOT },
  GRPP           => $ENV{ GRPP      },
  GSPA_SOLE      => $ENV{ GSPA_SOLE },
  GSPA_DUAL      => $ENV{ GSPA_DUAL },
};

use constant {
  NEQUICK_DAT_PATH => DAT_ROOT_PATH.qq(/nequick/),
};

1;
