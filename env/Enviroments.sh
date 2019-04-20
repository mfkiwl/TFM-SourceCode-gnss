#!/bin/bash

# Script arguments:
user_path=$1

# Welcome message:
echo ""
echo "Hello! This is TFM Source code v0.0.1"

echo "Welcome $USER";
echo "..."
echo ""

# Ask for installation path:
echo "Your GNSS source code is going to be located in '$user_path'"

# Set enviroments:
export SRC_ROOT=$user_path
export ENV_ROOT=$SRC_ROOT/env/
export LIB_ROOT=$SRC_ROOT/lib/
export DAT_ROOT=$SRC_ROOT/dat/
export UTIL_ROOT=$SRC_ROOT/util/
export GRPP_ROOT=$SRC_ROOT/GNSS_RINEX_Post-Processing/
export GSPA_ROOT=$SRC_ROOT/GNSS_Service-Performance-Analyzer/

# Goddby message:
echo ""
echo "Enviroments have been loaded successfully!"
echo ""
env | grep "ROOT"
echo ""
echo "You should just watch how they are defined..."
echo "Till the next time ;)"
echo ""

# End of script
