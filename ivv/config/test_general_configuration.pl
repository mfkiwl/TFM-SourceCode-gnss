#!/usr/bin/perl -w

# Common modules:
use Carp;
use strict;

use Data::Dumper;
use feature qq(say);

# Specific modules:
use lib $ENV{ ENV_ROOT };
use Enviroments qq(:CONSTANTS);

use lib SRC_ROOT_PATH;
use GeneralConfiguration qq(:ALL);

# Script arguments:
my ($config_file_path) = @ARGV;

# Test configuration:
my $ref_config_hash = LoadConfiguration($config_file_path);

print Dumper $ref_config_hash->{INTEGRITY};
