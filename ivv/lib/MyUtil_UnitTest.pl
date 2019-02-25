#!/usr/bin/perl -w

use Carp;
use strict;

use Data::Dumper;
use feature qq(say);

use lib $ENV{ LIB_ROOT };
use MyUtil qq(:ALL);


my $ref_array = [ 'a', 'b', 'd' ];

say "Before loop:";
print Dumper $ref_array;
say "--------------------------------------------------------------";

for ('a'..'f') {
  PushUnique($ref_array, $_);

  say "After pushing $_:";
  print Dumper $ref_array;

}

my %hash;
my $scalar;
sub code {};
PushUnique( \&code, 'A' );
