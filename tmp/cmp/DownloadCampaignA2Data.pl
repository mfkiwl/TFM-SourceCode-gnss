#!/usr/bin/perl -w

use Carp;
use strict;

use Data::Dumper;
use feature qq(say);
use Cwd qq(abs_path);

use lib $ENV{ ENV_ROOT };
use Enviroments qq(:ALL);

use lib SRC_ROOT_PATH;
use GeneralConfiguration qq(:ALL);

use lib LIB_ROOT_PATH;
use MyUtil qq(:ALL);
use MyPrint qq(:ALL);
use TimeGNSS qq(:ALL);

# ---------------------------------------------------------------------------- #


# 1. Load info containing stations and date information:

my @station_list;
my @date_list;

# 2. Download rinex data:
for my $sta (@station_list) {
  for my $date_ref (@date_list) {

    # De-refernece date info:
    my ($year, $doy);

    # Rinex observation files:
    qx{./DownloadRinexObsFromFTP-BKG.pl $year $doy $sta $obs_path};

    # Rinex navigation files:
    for my $sat_sys (&RINEX_GPS_ID, &RINEX_GAL_ID) {
      qx{./DownloadRinexNavFromFTP-BKG.pl $sat_sys $year $doy $sta $nav_path};
    }

  }
}
