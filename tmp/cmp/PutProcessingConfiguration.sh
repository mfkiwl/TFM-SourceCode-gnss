#!/bin/bash

# Retrieve script arguments:
CFG_FILE=$1
cmp_path=$2
station=$3
date=$4
ini=$5
end=$6
signal=$7
obs=$8

sed -i "s!\$cmp_path!$cmp_path!" $CFG_FILE
sed -i "s!\$station!$station!" $CFG_FILE
sed -i "s!\$date!$date!" $CFG_FILE
sed -i "s!\$ini!$ini!" $CFG_FILE
sed -i "s!\$end!$end!" $CFG_FILE
sed -i "s!\$signal!$signal!" $CFG_FILE
sed -i "s!\$obs!$obs!" $CFG_FILE
