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

# Load enviroments:
# ---------------------------------------------------------------------------- #
use lib $ENV{ ENV_ROOT };
use Enviroments qq(:CONSTANTS);

# Load NeQuickMode Module:
# ---------------------------------------------------------------------------- #
use lib GRPP_ROOT_PATH;
use NeQuickMode qq(:ALL);
use ErrorSource qq(:ALL);

# Load common libraries:
# ---------------------------------------------------------------------------- #
use lib LIB_ROOT_PATH;
use MyUtil   qq(:ALL); # useful subs and constants...
use MyMath   qq(:ALL); # useful mathematical methods...
use MyPrint  qq(:ALL); # print error and warning methods...
use TimeGNSS qq(:ALL); # GNSS time transforming utilities...
use Geodetic qq(:ALL); # geodetic toolbox for coordinate transformation...

# ---------------------------------------------------------------------------- #
# Validation routine:
# ---------------------------------------------------------------------------- #
PrintTitle0(*STDOUT, "Launching validation script $0");

# Init memory usage report:
  our $MEM_USAGE = Memory::Usage->new();
      $MEM_USAGE -> record('-> Init');

# Init script clock:
  my $tic_script = [gettimeofday];

# ************************** #
# Dumper print of CCIR hash: #
# ************************** #
  PrintTitle1(*STDOUT, "Testing Load of CCIR files:");

  my $month = 9; # September

  PrintComment(*STDOUT,
    "CCIR file extract for month: ".(MONTH_NAMES)[$month - 1]." ($month)\n");

  my $ref_ccir_f2  = REF_CCIR_HASH->{$month}{F2};
  my $ref_ccir_fm3 = REF_CCIR_HASH->{$month}{FM3};

  PrintTitle2(*STDOUT, "CCIR F2 values:");
  my $i_dim = scalar(@{ $ref_ccir_f2 });
  for (my $i = 0; $i < $i_dim; $i += 1) {
    my $j_dim = scalar(@{ $ref_ccir_f2->[$i] });
    for (my $j = 0; $j < $j_dim; $j += 1) {
      my $k_dim = scalar(@{ $ref_ccir_f2->[$i][$j] });
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
  my $i_dim = scalar(@{ $ref_ccir_fm3 });
  for (my $i = 0; $i < $i_dim; $i += 1) {
    my $j_dim = scalar(@{ $ref_ccir_fm3->[$i] });
    for (my $j = 0; $j < $j_dim; $j += 1) {
      my $k_dim = scalar(@{ $ref_ccir_fm3->[$i][$j] });
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

# **************** #
# Test parameters: #
# **************** #
  # Hardcoded GAL iono coefficients for medium solar activity:
  my $ref_iono_coeff_1 = [ 121.129893, 0.351254133, 0.0134635348 ];

  # Random position --> Northern hemisphere / Western hemisphere
  my ($test_lat,
      $test_lon) = ( 39.25*DEGREE_TO_RADIANS,
                     3.145*DEGREE_TO_RADIANS );

  # Time parameters:
  my $test_date = "2012/09/26 07:30:20";
  my ($yyyy, $mo, $dd, $hh, $mi, $ss) = split(/[\/: ]/, $test_date);

  $month = $mo; # September

  my $univr_time = Date2UniversalTime($yyyy, $month, $dd, $hh, $mi, $ss);
  my $local_time = UniversalTime2LocalTime($test_lon, $univr_time);

# ****************** #
# MODIP computation: #
# ****************** #
  PrintTitle1(*STDOUT, "Testing ComputeMODIP() public sub:");

  my $tic_compute_modip = [gettimeofday];

    my ($modip) = ComputeMODIP( $test_lat, $test_lon );

  my $toc_compute_modip = [gettimeofday];

  PrintComment(*STDOUT,
    "MODIP (lat = $test_lat; lon = $test_lon) = ".$modip*RADIANS_TO_DEGREE);
  say "";

# *************************************** #
# Effective Ionisation Level computation: #
# *************************************** #
  PrintTitle1(*STDOUT, "Testing ComputeEffectiveIonisationLevel() sub:");

  my $tic_compute_eff_iono_level = [gettimeofday];

    my ( $eff_iono_level, $eff_sunspot_number ) =
      ComputeEffectiveIonisationLevel( $ref_iono_coeff_1, $modip );

  my $toc_compute_eff_iono_level =  [gettimeofday];

  PrintComment(*STDOUT, "EffIonoLevel  (Az)  = $eff_iono_level");
  PrintComment(*STDOUT, "EffSunspotNum (AzR) = $eff_sunspot_number"); say "";

# ************************************* #
# NeQuick Model Parameters computation: #
# ************************************* #
  PrintTitle1(*STDOUT, "Testing ComputeNeQuickModelParameters() sub:");

  my $tic_compute_model_parameters = [gettimeofday];

    my $ref_nequick_model_parameters =
      ComputeNeQuickModelParameters( $test_lat, $test_lon, $modip,
                                     $month, $univr_time, $local_time,
                                     $eff_iono_level, $eff_sunspot_number );

  my $toc_compute_model_parameters = [gettimeofday];

  PrintComment(*STDOUT, "NeQuick Model parameters:");
  print Dumper $ref_nequick_model_parameters;
  say "";


# ---------------------------------------------------------------------------- #
# Report time stamps:
# ---------------------------------------------------------------------------- #
  ReportElapsedTime( $toc_compute_modip,
                     $tic_compute_modip,
                     "Compute MODIP" );

  ReportElapsedTime( $toc_compute_eff_iono_level,
                     $tic_compute_eff_iono_level,
                     "Compute Effective Ionisation Level" );

  ReportElapsedTime( $toc_compute_model_parameters,
                     $tic_compute_model_parameters,
                     "Compute NeQuick Model Parameters" );

# ---------------------------------------------------------------------------- #
# Dumper memory usage report:
# ---------------------------------------------------------------------------- #
  # Stop script clock:
  my $toc_script = [gettimeofday];

  # Report script memory usage:
  PrintTitle2(*STDOUT, 'Memory Usage Report:');
  $MEM_USAGE->dump(); say "";

  # Report elapsed script time:
  ReportElapsedTime( $tic_script, $toc_script, "$0");


PrintTitle0(*STDOUT, "Validation script $0 is over");

# END OF SCRIPT

# ---------------------------------------------------------------------------- #
# Private subroutines:
# ---------------------------------------------------------------------------- #
sub ReportElapsedTime {
  my ($current_time_stamp, $ref_time_stamp, $label) = @_;

  say "";
    PrintTitle2( *STDOUT, sprintf("Elapsed time for $label %.2f seconds",
                          tv_interval($ref_time_stamp, $current_time_stamp)) );
  say "";
}
