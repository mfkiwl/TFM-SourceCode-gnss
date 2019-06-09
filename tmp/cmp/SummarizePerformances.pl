#!/usr/bin/perl -w

# ---------------------------------------------------------------------------- #
# Load perl modules:

use Carp;
use strict;

use Storable;
use Data::Dumper;
use feature qq(say);
use Cwd qq(abs_path);


# ---------------------------------------------------------------------------- #
# Load dedicated modules:

use lib $ENV{ ENV_ROOT };
use Enviroments qq(:CONSTANTS);

use lib SRC_ROOT_PATH;
use GeneralConfiguration qq(:ALL);

use lib LIB_ROOT_PATH;
use MyUtil qq(:ALL);
use MyPrint qq(:ALL);
use TimeGNSS qq(:ALL);

# ---------------------------------------------------------------------------- #
# Main Routine:

my $script_description = <<'EOF';
# ============================================================================ #
# Script: SummarizePerformances.pl
# ============================================================================ #
# Purpose: Summarizes in a tsv file the obtained performances trough the
#          launched campaign
#
# ============================================================================ #
# Usage:
# ============================================================================ #
#  ./SummarizePerformances.pl <cmp_root_path> <station_date_hash>
#
# * NOTE:
#    - Station-date hash configuration must be in binary format
#    - Station-date hash must have CFG_PATH entry
#
# ============================================================================ #
# Script arguments:
# ============================================================================ #
#  - $1 -> Campaign root path
#  - $2 -> Station-Date configuration hash (Storable binary)
#
EOF
print $script_description;

# Read script arguments:
my ($cmp_root_path, $cmp_hash_cfg_path) = @ARGV;

# Retrieve paths:
my $rpt_root_path = abs_path( join('/', $cmp_root_path, 'rpt') );

# Load satation-date hash configuration:
my $ref_cmp_cfg = retrieve($cmp_hash_cfg_path);

# Open file in cmp_root_path:
my $out_file = join('/', $cmp_root_path, 'perfomance_summary.csv');
my $fh; open($fh, '>', $out_file) or die $!;

for my $sta (sort(keys %{$ref_cmp_cfg})) {
  for my $date (sort(keys %{$ref_cmp_cfg->{$sta}})) {
    for my $signal (sort(keys
        %{$ref_cmp_cfg->{$sta}{$date}{SIGNAL_OBS}})) {

      # Retrieve useful info:
      my $date_yymmdd =
        join('/', @{ $ref_cmp_cfg->{$sta}{$date}{YY_MO_DD} });
      my $date_doy  =
        $ref_cmp_cfg->{$sta}{$date}{DOY};
      my $signal_id =
        $ref_cmp_cfg->{$sta}{$date}{SIGNAL_OBS}{$signal};

      # Set GSPA report paths:
      my $gspa_path =
        join('/', $rpt_root_path, $sta, $date, $signal, 'GSPA');

      # Set accuracy, error and integrity files:
      my $acc_file = join('/', $gspa_path, 'accuracy_report.txt');
      my $err_file = join('/', $gspa_path, 'error_report.txt');
      my $int_file = join('/', $gspa_path, 'integrity_report.txt');

      say $sta;
      say "\t$date";
      say "\t\t$signal";
      say "\t\t$acc_file";

      # Grep info:
      # For accuracy perfo:
      my $v_acc_line = qx{grep Vertical $acc_file};
      my $h_acc_line = qx{grep Horizontal $acc_file};

      my @v_acc_items = split(/\s+/, $v_acc_line);
      my @h_acc_items = split(/\s+/, $h_acc_line);

      my @v_acc_ind = @v_acc_items[6..8];
      my @h_acc_ind = @h_acc_items[6..8];

      # For error perfo:
      my $v_err_line = qx{grep Vertical $err_file};
      my $h_err_line = qx{grep Horizontal $err_file};

      my @v_err_items = split(/\s+/, $v_err_line);
      my @h_err_items = split(/\s+/, $h_err_line);

      my @v_err_ind = @v_err_items[5..7];
      my @h_err_ind = @h_err_items[5..7];

      # For integrity perfo:
      my $v_int_line = qx{grep Vertical $int_file};
      my $h_int_line = qx{grep Horizontal $int_file};

      my @v_int_items = split(/\s+/, $v_int_line);
      my @h_int_items = split(/\s+/, $h_int_line);

      my @v_int_ind = @v_int_items[7..12];
      my @h_int_ind = @h_int_items[7..12];

      # Number of epochs:
      my $num_epochs     = $v_acc_items[2];
      my $num_ok_epochs  = $v_acc_items[3];
      my $num_nok_epochs = $num_epochs - $num_ok_epochs;

      # Set line elements:
      my @line = ( $sta,
                   $date, $date_yymmdd, $date_doy,
                   $signal, $signal_id,
                   $num_epochs, '',
                   $num_ok_epochs, '',
                   $num_nok_epochs, '',
                   @v_acc_ind, @h_acc_ind,
                   @v_err_ind, @h_err_ind,
                   @v_int_ind, @h_int_ind);

      say $fh join(";", @line);

      # exit 0; # by the moment
    }
  }
}

# Close file:
close($fh);

# ---------------------------------------------------------------------------- #
# END OF SCRIPT
