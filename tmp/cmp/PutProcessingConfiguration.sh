#!/bin/bash

# Retrieve script arguments:
CFG_FILE=$1
station=$2
date=$3
ini=$4
end=$5
signal=$6
obs=$7

sed -i "s!\$station!$station!" $CFG_FILE
sed -i "s!\$date!$date!" $CFG_FILE
sed -i "s!\$ini!$ini!" $CFG_FILE
sed -i "s!\$end!$end!" $CFG_FILE
sed -i "s!\$signal!$signal!" $CFG_FILE
sed -i "s!\$obs!$obs!" $CFG_FILE
