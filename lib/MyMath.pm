#!/usr/bin/perl -w

# Package declaration:
package MyMath;

# Import useful modules:
use Carp;     # traced warnings and errors...
use strict;   # enables perl strict syntax...

use feature qq(say);

use PDL; # loads Perl Data Language extension...
use PDL::Constants qq(PI);

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

  # All subroutines and constats to export:
  our @EXPORT_OK = qw( &DEGREE_TO_RADIANS
                       &RADIANS_TO_DEGREE
                       &Rad2Deg
                       &Deg2Rad
                       &SolveWeightedLSQ
                       &LinearInterpolationFromTable
                       &ThirdOrderInterpolation );

  # Define export tags:
  our %EXPORT_TAGS = ( DEFAULT => [],
                       ALL     => \@EXPORT_OK );
}


# Constants:
# ---------------------------------------------------------------------------- #
use constant DEGREE_TO_RADIANS => PI/180;
use constant RADIANS_TO_DEGREE => 180/PI;


# Subroutines:
# ---------------------------------------------------------------------------- #
sub Rad2Deg {
  return map {$_ * RADIANS_TO_DEGREE} @_;
}

sub Deg2Rad {
  return map {$_ * DEGREE_TO_RADIANS} @_;
}

sub LinearInterpolationFromTable {
  my ( $x, $ref_domain, $ref_range ) = @_;

  # De-reference domain and range arrays:
  my @domain = @{$ref_domain};
  my @range  = @{$ref_range};

  # Input checks:
    # Check that domain and range have the same length:
    return undef unless (scalar(@domain) == scalar(@range));
    # Check that 'x' value is within domain bounds:
    return undef if ( $x < $domain[0] || $x > $domain[-1] );

  # Init index for the value pair and first domain values:
  my $index = 0;
  my ($x1, $x2) = ($domain[$index], $domain[$index + 1]);

  # Until the value is within a domain pair:
  until ($x1 >= $x && $x2 <= $x) {
    $index += 1; ($x1, $x2) = ($domain[$index], $domain[$index + 1]);
  }

  # Save domain values for interpolation:
  my ($y1, $y2) = ($range[$index], $range[$index + 1]);

  # Return interpolated value:
  return ( ($y2 - $y1)/($x2 - $x1)*($x - $x1) + $y1 );
}

sub SolveWeightedLSQ {
  my ($ref_design_matrix, $ref_weight_matrix, $ref_ind_term_matrix) = @_;

  # A --> design matrix
  # W --> independent term matrix
  # P --> weight matrix

  # Set input references as PDL piddles:
    my $a = pdl $ref_design_matrix;
    my $p = pdl $ref_weight_matrix;
    my $w = pdl $ref_ind_term_matrix;

  # ********************* #
  # Prelimary operations: #
  # ********************* #

    # Retrieve A's dimensions:
    #  m --> number of observations
    #  n --> parameters to be estimated
    #  *(m - n) --> system's freedom degrees
    my ($n, $m) = dims($a);

    # For LSQ algorithm:
      #   Observations must be greater than parameters:
      #    - m > n
      return 0 unless ( $m > $n );
      #   Matrix domensions must be:
      #    - A(m,n) for design matrix
      #    - W(m,1) for weight matrix
      #    - P(m,m) for independent term matrix
      my ($nw, $mw) = dims($w); return 0 unless ($mw == $m || $nw ==  1);
      my ($np, $mp) = dims($p); return 0 unless ($mp == $m || $np == $m);


  # ************************************ #
  # Linear algebra computation sequence: #
  # ************************************ #

    # Co-factor matrix:
    # Qxx = (At.P.A)^(-1):
    my $qxx = inv(transpose($a) x $p x $a);

    # Estimated parameters vector:
    # X = (At.P.A)^(-1).At.P.W
    my $x = $qxx x transpose($a) x $p x $w;

    # Residuals vector:
    # R = A.X - W:
    my $r = $a x $x - $w;

    # Ex-post variance estimator:
    # S2_0 = (Rt.P.R) / (m - n):
    my $sigma2_0 = (transpose($r) x $p x $r) / ($m - $n);

    # Co-varince matrix:
    # Sxx = sigma0 * Qxx:
    my $sigma_xx = $sigma2_0 * $qxx;


  # Return: estimated parameters, observation residuals,
  #         co-variance matrix, ex-post variance estimator:
  return (1, $x, $r, $sigma_xx, $sigma2_0);
}

sub ThirdOrderInterpolation {
  my ($z1, $z2, $z3, $x) = @_;
  # NOTE: $x is assumed to be [0,1]

  # Init interpolated value:
  my $zx;

  # If value to be interpolated is non-significant, the interpolation is
  # assumed to be the second point.
  # Otherwise, the third order interpolation must be computed:
  if ( abs(2*$x) < 10e-10 ) {
    $zx = $z2;
  } else {
    my $delta = 2*$x - 1;

    my ( $g1, $g2,
         $g3, $g4 ) = ( $z3 + $z2,  $z3 - $z2,
                        $z4 + $z1, ($z4 - $z1)/3 );
    my ( $a0, $a1,
         $a2, $a3 ) = ( 9*$g1 - $g3, 9*$g2 - $g4,
                          $g3 - $g1,   $g4 - $g2 );

    $zx = (1/16)*($a0 + $a1*$delta + $a2*$delta**2 + $a3*$delta**3);
  }

  return $zx;
}

1;
