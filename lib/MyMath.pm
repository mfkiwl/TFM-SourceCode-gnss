#!/usr/bin/perl -w

# Package declaration:
package MyMath;

# Import useful modules:
use Carp;
use strict;
use warnings;

use feature qq(say); # print method adding a carriage return...

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
  our @EXPORT_OK = qw( SolveWeightedLSQ
                       LinearInterpolationFromTable );

  # Define export tags:
  our %EXPORT_TAGS = ( DEFAULT => [],
                       ALL     => \@EXPORT_OK );
}


# Constants:
# ---------------------------------------------------------------------------- #

# Subroutines:
# ---------------------------------------------------------------------------- #
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
  my ($a, $w, $p) = @_;

  # A --> design matrix
  # W --> independent term matrix
  # P --> weight matrix

  # ********************* #
  # Prelimary operations: #
  # ********************* #

    # Retrieve A's dimensions:
    #  m --> number of observations
    #  n --> parameters to be estimated
    #  *(m - n) --> system's freedom degrees
    my ($n, $m) = dims($a);

    # Dimension checks:
    # For LSQ algorithm, matrixes must be:
    #  - A(m,n)
    #  - W(m,1)
    #  - P(m,m)
    my ($nw, $mw) = dims($w); return KILLED unless ($mw == $m || $nw ==  1);
    my ($np, $mp) = dims($p); return KILLED unless ($mp == $m || $np == $m);


  # ************************************ #
  # Linear algebra computation sequence: #
  # ************************************ #

    # Co-factor matrix:
    # Qxx = (At.P.A)^(-1):
    my $qxx = inv(transpose($a) x $p x $a);

    # Estimated parameter vector:
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
  return ($x, $r, $sigma_xx, $sigma2_0);
}


1;
