#!/usr/bin/perl

# Package declaration:
package MyPrint;

# Import useful modules:
use Carp;
use strict;
use warnings;

use Term::ANSIColor; # use colored outputs...
use feature qq(say); # same as print adding a carriage return...

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
  our @EXPORT_OK = qw( &LEVEL_0_DELIMITER
                       &LEVEL_1_DELIMITER
                       &LEVEL_2_DELIMITER
                       &LEVEL_3_DELIMITER
                       &STAR_DELIMITER
                       &PrintTitle0
                       &PrintTitle1
                       &PrintTitle2
                       &PrintTitle3
                       &RaiseError
                       &RaiseWarning
                       &PrintComment
                       &PrintBulletedInfo );

  # Define export tags:
  our %EXPORT_TAGS = ( DEFAULT => [],
                       ALL     => \@EXPORT_OK );
}


# Constants:
# ---------------------------------------------------------------------------- #
use constant MAX_NUM_CHAR_IN_LINE   => 80;
use constant NUM_CHAR_FOR_DELIMITER => 76;

use constant {
  LEVEL_0_DELIMITER => '# '.'#' x NUM_CHAR_FOR_DELIMITER.' #',
  LEVEL_1_DELIMITER => '# '.'=' x NUM_CHAR_FOR_DELIMITER.' #',
  LEVEL_2_DELIMITER => '# '.'-' x NUM_CHAR_FOR_DELIMITER.' #',
  LEVEL_3_DELIMITER => '# '.'·' x NUM_CHAR_FOR_DELIMITER.' #',
  STAR_DELIMITER    => '# '.'*' x NUM_CHAR_FOR_DELIMITER.' #'
};


# Subroutines:
# ---------------------------------------------------------------------------- #
sub PrintTitle0 {
  my ($fh, @contents) = @_;

  say $fh LEVEL_0_DELIMITER;
  for (@contents) {
    my $msg = "# > ".$_;
    say $fh $msg." " x (MAX_NUM_CHAR_IN_LINE - length($msg) - 1)."#";
  }
  say $fh LEVEL_0_DELIMITER;
  say $fh "";

}

sub PrintTitle1 {
  my ($fh, @contents) = @_;

  say $fh LEVEL_1_DELIMITER;
  for (@contents) {
    my $msg = "# > ".$_;
    say $fh $msg." " x (MAX_NUM_CHAR_IN_LINE - length($msg) - 1)."#";
  }
  say $fh LEVEL_1_DELIMITER;
  say $fh "";

}

sub PrintTitle2 {
  my ($fh, @contents) = @_;

  say $fh LEVEL_2_DELIMITER;
  for (@contents) {
    my $msg = "# > ".$_;
    say $fh $msg." " x (MAX_NUM_CHAR_IN_LINE - length($msg) - 1)."#";
  }
  say $fh LEVEL_2_DELIMITER;
  say $fh "";

}

sub PrintTitle3 {
  my ($fh, @contents) = @_;

  say $fh LEVEL_3_DELIMITER;
  for (@contents) {
    my $msg = "# > ".$_;
    say $fh $msg." " x (MAX_NUM_CHAR_IN_LINE - length($msg) - 1)."#";
  }
  say $fh LEVEL_3_DELIMITER;

}

sub RaiseError {
  my ($fh, $code, @info) = @_;

  # Set error time:
  my ($ss,$mm,$hh,$dd,$mo,$year,$wday,$yday,$isdst) = localtime();

  $year += ($year < 80) ? 2000 : 1900;

  # Time message in error:
  my $error_time =
    sprintf("%04d/%02d/%02d %02d:%02d:%02d", $year, $mo+1, $dd, $hh, $mm, $ss);

  # Inform about the error:
  my $colored_error = colored("ERROR", 'bold red');
  say $fh "*** $error_time *** $colored_error:$code ***";
  say $fh "***\t- $_" for (@info);
  say $fh "";

  # Raise error in STDOUT:
  Carp::carp "*** $error_time *** $colored_error:$code ***";

}

sub RaiseWarning {
  my ($fh, $code, @info) = @_;

  # Set warning time:
  my ($ss,$mm,$hh,$dd,$mo,$year,$wday,$yday,$isdst) = localtime();

  $year += ($year < 80) ? 2000 : 1900;

  # Time message in warning:
  my $warn_time =
    sprintf("%04d/%02d/%02d %02d:%02d:%02d", $year, $mo+1, $dd, $hh, $mm, $ss);

  # Inform about the warning:
  my $colored_warning = colored("WARNING", 'bold yellow');
  say $fh "*** $warn_time *** $colored_warning:$code ***";
  say $fh "***\t- ".$_ for (@info);
  say $fh "";

  # Raise warning in STDOUT:
  Carp::carp "*** $warn_time *** $colored_warning:$code ***";

}

sub PrintBulletedInfo {
  my ($fh, $bullet, @contents) = @_;

  say $fh "#$bullet".$_ for (@contents);
  say $fh "";

}

sub PrintComment {
  my ($fh, @contents) = @_;

  say $fh colored("# ".$_, 'green') for (@contents);

}

1;
