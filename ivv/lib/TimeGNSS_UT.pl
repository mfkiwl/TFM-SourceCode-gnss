#!/usr/bin/perl -w

use Carp;
use strict;

use feature qq(say);

use lib $ENV{ ENV_ROOT };
use Enviroments qq(:CONSTANTS);

use lib LIB_ROOT_PATH;
use TimeGNSS qq(:ALL);


my @date_1 = ( 2019, 01, 01, 00, 00, 00 );
my @date_2 = ( 1987, 01, 01, 00, 00, 00 );
my @date_3 = ( 2019, 05, 16, 00, 00, 00 );
my @date_4 = ( 2019, 05, 15, 23, 59, 59 );
my @date_5 = ( 2019, 12, 31, 00, 00, 00 );

say BuildDateString(@date_1), "\t--> ", sprintf("%03d", Date2DoY(@date_1)), " | 1";
say BuildDateString(@date_2), "\t--> ", sprintf("%03d", Date2DoY(@date_2)), " | 1";
say BuildDateString(@date_3), "\t--> ", sprintf("%03d", Date2DoY(@date_3)), " | 136";
say BuildDateString(@date_4), "\t--> ", sprintf("%03d", Date2DoY(@date_4)), " | 135";
say BuildDateString(@date_5), "\t--> ", sprintf("%03d", Date2DoY(@date_5)), " | 365";
