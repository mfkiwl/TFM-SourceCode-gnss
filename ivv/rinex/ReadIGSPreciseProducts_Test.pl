#!/usr/bin/perl -w

use Carp;
use strict;

use Data::Dumper;
use feature qq(say);

# Load bash enviroments:
# ---------------------------------------------------------------------------- #
use lib $ENV{ ENV_ROOT };
use Enviroments qq(:CONSTANTS);

# Load common libraries:
# ---------------------------------------------------------------------------- #
use lib $ENV{ LIB_ROOT };
use MyUtil qq(:ALL);
use MyPrint qq(:ALL);
use TimeGNSS qq(:ALL);

# Load GRPP enviroments:
# ---------------------------------------------------------------------------- #
use lib $ENV{ GRPP_ROOT };
use RinexReader qq(:ALL);

# ============================================================================ #
# Test Area
# ============================================================================ #

my $igs_dat_path = qq(/home/ppinto/WorkArea/dat/igs/);
my $igs_sp3_file = qq(COD0MGXFIN_20183350000_01D_05M_ORB.SP3);

my $ref_precise_orbit =
  ReadPreciseOrbitIGS( join('/', ($igs_dat_path, $igs_sp3_file)), *STDOUT );

# print Dumper $ref_precise_orbit;


# end of script
