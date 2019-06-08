#!/usr/bin/perl -w

# TODO: Package description goes here...

# Package declaration:
package CommonUtil;

# ---------------------------------------------------------------------------- #
# Set package exportation properties:

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
  our @EXPORT_SUB   = qw( &SetReportTitle
                          &ClearNullDataPiddle );

  # Merge constants and subroutines:
  our @EXPORT_OK = (@EXPORT_CONST, @EXPORT_SUB);

  # Define export tags:
  our %EXPORT_TAGS = ( ALL         => \@EXPORT_OK,
                       DEFAULT     => \@EXPORT,
                       CONSTANTS   => \@EXPORT_CONST,
                       SUBROUTINES => \@EXPORT_SUB );
}

# ---------------------------------------------------------------------------- #
# Import common perl modules:

use Carp;         # advanced warning and failure raise...
use strict;       # strict syntax and common mistakes advisory...

use Data::Dumper;       # var pretty print...
use feature qq(say);    # print adding line jump...
use feature qq(switch); # advanced switch statement...

# Load perl data language:
use PDL;

# ---------------------------------------------------------------------------- #
# Load bash enviroments:

use lib $ENV{ ENV_ROOT };
use Enviroments qq(:CONSTANTS);

# ---------------------------------------------------------------------------- #
# Load dedicated libraries:

use lib LIB_ROOT_PATH;
use MyUtil   qq(:ALL); # ancillary utilities...
use MyMath   qq(:ALL); # dedicated math toolbox...
use MyPrint  qq(:ALL); # plain text print layouts...
use TimeGNSS qq(:ALL); # GNSS time conversion tools...
use Geodetic qq(:ALL); # dedicated geodesy utilities...

# ---------------------------------------------------------------------------- #
# Load general configuration and interfaces module:

use lib SRC_ROOT_PATH;
use GeneralConfiguration qq(:ALL);

# ---------------------------------------------------------------------------- #
# Constants: #



# ---------------------------------------------------------------------------- #
# Public Subroutines: #

sub SetReportTitle {
  my ($title_body, $ref_gen_conf, $marker, $gps_epoch) = @_;

  # Init title string:
  my $title = '';

  # Retrieve date in 'yyyy/mo/dd' format:
  my $date = ( split(' ', BuildDateString(GPS2Date($gps_epoch))) )[0];

  # Retrieve satellite system used:
  my @sat_sys = @{ $ref_gen_conf->{SELECTED_SAT_SYS} };

  # Init array to store each selected sat_sys-signal:
  my @signal_used;

  for (@sat_sys) {
    my $signal_id = substr($ref_gen_conf->{SELECTED_SIGNALS}{$_}, 0, 2);
    push(@signal_used,
      join('-', SAT_SYS_ID_TO_NAME->{$_},
                SAT_SYS_OBS_TO_NAME->{$_}{$signal_id})
    );
  }

  # Build string for every sat_sys-signal combination:
  my $signal_used_string = join(' + ', @signal_used);

  # Set title:
  $title =
    "$title_body from $marker on $date using $signal_used_string";

  # Return the title:
  return $title;
}

sub ClearNullDataPiddle {
  my ($pdl_array) = @_;

  $pdl_array = pdl(grep{ $_ ne NULL_DATA }( list($pdl_array) ));

  return $pdl_array;
}

TRUE;
