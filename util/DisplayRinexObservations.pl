#!/usr/bin/perl -X

# Load bash enviroments:
# ---------------------------------------------------------------------------- #
use lib $ENV{ ENV_ROOT };
use Enviroments qq(:CONSTANTS);

# Load built-in modules:
# ---------------------------------------------------------------------------- #
use Carp;
use strict;
use Data::Dumper;
use feature qq(say);

# Load custom modules:
# ---------------------------------------------------------------------------- #
use lib LIB_ROOT_PATH;
use MyUtil  qq(:ALL);
use MyPrint qq(:ALL);

use lib GRPP_ROOT_PATH;
use RinexReader qq(:ALL);

# Some constants:
# ---------------------------------------------------------------------------- #
use constant SAT_SYS_ID_TO_NAME => { G => 'GPS',
                                     E => 'GALILEO',
                                     R => 'GLONASS',
                                     C => 'BEIDOU',
                                     S => 'SBAS',
                                     J => 'QZSS' };

# Script arguments:
# ---------------------------------------------------------------------------- #
my ( $obs_rinex_path, @input_sat_sys ) = @ARGV; say "";

my $flag_all_sat_sys = TRUE unless @input_sat_sys;

# Main routine:
# ---------------------------------------------------------------------------- #
# Read observation rinex header:
my $ref_obs_rinex_head =
  ReadObservationRinexHeader( $obs_rinex_path, *STDOUT );

# Print available observations for each constellation
# But first, select the constellations to print based on the script inputs:
my @print_sat_sys =
  ($flag_all_sat_sys) ?
    (keys %{$ref_obs_rinex_head->{SYS_OBS_TYPES}}) : @input_sat_sys;

# Go trough selected constellations to print:
for my $sat_sys (@print_sat_sys) {

  # First, check that the provided constellation exists on RINEX:
  if (defined $ref_obs_rinex_head->{SYS_OBS_TYPES}{$sat_sys} ){

    # List and sort the available observations:
    my @sat_sys_obs =
      sort @{ $ref_obs_rinex_head->{SYS_OBS_TYPES}{$sat_sys}{OBS} };

    PrintTitle3(*STDOUT,
      "Observations for ".SAT_SYS_ID_TO_NAME->{$sat_sys}." constellation");

    # Split observations by pseudorange, phase, doppler and signal strength:
    my @phase_obs   = grep { m/L\d./ } @sat_sys_obs;
    my @pseudo_obs  = grep { m/C\d./ } @sat_sys_obs;
    my @sigstr_obs  = grep { m/S\d./ } @sat_sys_obs;
    my @doppler_obs = grep { m/D\d./ } @sat_sys_obs;

    # And... print them!
    PrintComment(*STDOUT,
      "Pseudorange     : ".join(', ', @pseudo_obs)   ) if @pseudo_obs;
    PrintComment(*STDOUT,
      "Carrier Phase   : ".join(', ', @phase_obs)    ) if @phase_obs;
    PrintComment(*STDOUT,
      "Signal Strength : ".join(', ', @sigstr_obs)   ) if @sigstr_obs;
    PrintComment(*STDOUT,
      "Doppler         : ".join(', ', @doppler_obs)  ) if @doppler_obs;
    PrintComment(*STDOUT, "");

  } else { # If not, raise a warning and go to the next constellation:

    RaiseWarning(*STDOUT, 000001,
      "Constellation '$sat_sys' was not found at observation ".
      "RINEX '$obs_rinex_path'");
    next;

  } # end if defined $ref_sat_sys_obs

} # end for $sat_sys
