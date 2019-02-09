#!/usr/bin/perl -w

# Built-in modules:
# ---------------------------------------------------------------------------- #
use Carp;
use strict;
use Data::Dumper;
use feature qq(say);

# Script timestamps and memory usage:
use Memory::Usage;
use Time::HiRes qw(gettimeofday tv_interval);

# Init script clock:
  my $script_start = [gettimeofday];

# Init memory usage report:
  our $MEM_USAGE = Memory::Usage->new();
      $MEM_USAGE->record('-> Init');

# Load enviroments:
# ---------------------------------------------------------------------------- #
use lib $ENV{ ENV_ROOT };
use Enviroments qq(:CONSTANTS);

  my $timestamp_after_import_env = [gettimeofday];
  $MEM_USAGE->record('-> Import Enviroments');

# Load NeQuickMode Module:
# ---------------------------------------------------------------------------- #
use lib GRPP_ROOT_PATH;
use NeQuickMode qq(:ALL);
use ErrorSource qq(:ALL);

# Measure time to import NeQuickMode module:
  my $timestamp_after_import_nequick = [gettimeofday];
  $MEM_USAGE->record('-> Import NeQuickMode');

# Load common libraries:
# ---------------------------------------------------------------------------- #
use lib LIB_ROOT_PATH;
use MyUtil   qq(:ALL); # useful subs and constants...
use MyMath   qq(:ALL); # useful mathematical methods...
use MyPrint  qq(:ALL); # print error and warning methods...
use TimeGNSS qq(:ALL); # GNSS time transforming utilities...
use Geodetic qq(:ALL); # geodetic toolbox for coordinate transformation...

# Measure time to import library modules:
  my $timestamp_after_import_lib = [gettimeofday];
  $MEM_USAGE->record('-> Import Library Modules');


# Validation routine:
# ---------------------------------------------------------------------------- #
PrintTitle0(*STDOUT, "Launching validation script $0");

# ************************** #
# Dumper print of CCIR hash: #
# ************************** #
  PrintTitle1(*STDOUT, "Testing Load of CCIR files:");

  my $month = 3;
  my @months = MONTH_NAMES;

  PrintComment(*STDOUT,
    "CCIR file extract for month: ".$months[$month - 1]." ($month)\n");

  my $ref_ccir_f2  = REF_CCIR_HASH->{$month}{F2};
  my $ref_ccir_fm3 = REF_CCIR_HASH->{$month}{FM3};

  PrintTitle2(*STDOUT, "CCIR F2 values:");
  my $i_dim =
    scalar(@{ $ref_ccir_f2 });
  for (my $i = 0; $i < $i_dim; $i += 1) {
    my $j_dim =
      scalar(@{ $ref_ccir_f2->[$i] });
    for (my $j = 0; $j < $j_dim; $j += 1) {
      my $k_dim =
        scalar(@{ $ref_ccir_f2->[$i][$j] });
      for (my $k = 0; $k < $k_dim; $k += 1) {

        if ( $i == 0 &&
            ($j < 3 || $j > $j_dim - 3) &&
            ($k < 3 || $k > $k_dim - 3) ) {
          say "F2[$i][$j][$k] = ".$ref_ccir_f2->[$i][$j][$k];
        }

      }
    }
  }
  say "";

  PrintTitle2(*STDOUT, "CCIR FM3 values:");
  my $i_dim =
    scalar(@{ $ref_ccir_fm3 });
  for (my $i = 0; $i < $i_dim; $i += 1) {
    my $j_dim =
      scalar(@{ $ref_ccir_fm3->[$i] });
    for (my $j = 0; $j < $j_dim; $j += 1) {
      my $k_dim =
        scalar(@{ $ref_ccir_fm3->[$i][$j] });
      for (my $k = 0; $k < $k_dim; $k += 1) {

        if ( $i == 0 &&
            ($j < 3 || $j > $j_dim - 3) &&
            ($k < 3 || $k > $k_dim - 3) ) {
          say "FM3[$i][$j][$k] = ".$ref_ccir_fm3->[$i][$j][$k];
        }

      }
    }
  }
  say "";


# **************************** #
# Dumper print of MODIP array: #
# **************************** #
  PrintTitle1(*STDOUT, "Testing Load of MODIP file:");
  for (my $i = 0; $i < scalar(@{ &REF_MODIP_MAP }); $i += 1) {
    for my $j (0..4) {
      print sprintf("%5.3f", REF_MODIP_MAP->[$i][$j]), " ";
    }
    print "... ";
    for my $j (-5..-1) {
      print sprintf("%5.3f", REF_MODIP_MAP->[$i][$j]), " ";
    }
    print "--> ".scalar(@{ REF_MODIP_MAP->[$i] }), "\n";
  }
  say "";

# ****************** #
# MODIP computation: #
# ****************** #
  PrintTitle1(*STDOUT, "Testing ComputeMODIP() public sub:");

  my ($test_lat, $test_lon) = ( 39.25, 3.145 );

  my ( $modip ) = ComputeMODIP( $test_lat*DEGREE_TO_RADIANS,
                                $test_lon*DEGREE_TO_RADIANS );

  PrintComment(*STDOUT,
    "MODIP (lat = $test_lat; lon = $test_lon) = ".$modip*RADIANS_TO_DEGREE);
  say "";

# *************************************** #
# Effective Ionisation Level computation: #
# *************************************** #
  PrintTitle1(*STDOUT, "Testing ComputeEffectiveIonisationLevel() sub:");

  # Hardcoded GAL iono coefficients for medium solar activity:
  my $ref_iono_coeff_1 = [ 121.129893, 0.351254133, 0.0134635348 ];

  my ( $eff_iono_level ) =
    ComputeEffectiveIonisationLevel( $ref_iono_coeff_1, $modip );

  PrintComment(*STDOUT, "EffIonoLevel (Az) = $eff_iono_level"); say "";


# Report time stamps:
# ---------------------------------------------------------------------------- #
  ReportElapsedTime( $timestamp_after_import_nequick,
                     $timestamp_after_import_env,
                     "Import NeQuickMode" );

  ReportElapsedTime( $timestamp_after_import_lib,
                     $timestamp_after_import_nequick,
                     "Import library modules" );

# Dumper memory usage report:
# ---------------------------------------------------------------------------- #
  PrintTitle2(*STDOUT, 'Memory Usage report:');
  $MEM_USAGE->dump(); say "";


PrintTitle0(*STDOUT, "Validation script $0 is over");
# end of script

# Private subroutines:
# ---------------------------------------------------------------------------- #
sub ReportElapsedTime {
  my ($current_time_stamp, $ref_time_stamp, $label) = @_;

  say "";
    PrintTitle2( *STDOUT, sprintf("Elapsed time for $label %.2f seconds",
                          tv_interval($ref_time_stamp, $current_time_stamp)) );
  say "";
}
