#!/bin/bash

CMP_ROOT_PARH=$1
CRX_2_RNX_BIN='/home/ppinto/WorkArea/dat/crinex2rinex.bin'

# Campaign data is compresed:
#   - OBS data is gzip and crinex compressed
#   - NAV data is gzip compressed

# Gunzip all RINEX data
find $1 | grep ".gz" | xargs gunzip

# Rinex to crinex uncompression for obs data:
OBS_CRX_FILES=`find $1 | grep ".crx"`

for file in $OBS_CRX_FILES;
  do $CRX_2_RNX_BIN $file;
done;
