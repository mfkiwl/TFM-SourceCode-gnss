#!/usr/bin/gnuplot -persist

# * Persist flag indicates plot windows to remain open even if the script
#   ends...

# ============================================================================ #
# Main Routine:                                                                #
# ============================================================================ #

# Preliminary:
#  - Identify script arguments:
#    $1 --> satellite system
#    $2 --> raw_data input path
#    $3 --> plots output path
  SAT_SYS=ARG1
  INP_PATH=ARG2
  OUT_PATH=ARG3

  print "Input satellite system = ", SAT_SYS
  print "Input raw_data path    = ", INP_PATH
  print "Output path for plots  = ", OUT_PATH
  print ""

# Global plot options:
  set datafile commentschars "#"
  set grid

# ---------------------------------------------------------------------------- #
# 1. Satellite system plots:
# ---------------------------------------------------------------------------- #

# ************************************** #
#    1.a Constellation availability:     #
# ************************************** #
print "Plot 1.a : Constellation availability"

  # Extract information from $sat_sys-num-sat-info.out:
  num_sat_info=INP_PATH."/".SAT_SYS."-num-sat-info.out"

  print "Num sat info file path = ", num_sat_info

  # Set plot properties:
  set terminal png size 1400,600
  set output OUT_PATH."/".SAT_SYS."-availability.png"
  set title  "Satellite System '".SAT_SYS."': Constellation Availability"
  set xlabel "Observation Epochs"
  set ylabel "Number of Satellites"

  # Set axis ranges by extracting the data stats:
  # Maximum number of satellites wiil always be in "available sat" column:
  stats num_sat_info using 7 name "NUM_SAT" nooutput
  set yrange[5:NUM_SAT_max+2]
  set xrange[0:NUM_SAT_records]

  # TODO: set X axis time format!

  set style fill transparent solid 0.6
  plot num_sat_info using  7 title "Available Satellites" with filledcurve y=0,\
       num_sat_info using  8 title "Valid Obs Satellites" with filledcurve y=0,\
       num_sat_info using  9 title "Valid Nav Satellites" with filledcurve y=0,\
       num_sat_info using 10 title "Valid LSQ Satellites" with filledcurve y=0

print ""

# *************************************** #
#    1.b Satellite observed elevation:    #
# *************************************** #
print "Plot 1.b Satellite observed elevation"

  # Elevation by sat can be extracted from $sat_sys-sat-elevation.out
  sat_elevation=INP_PATH."/".SAT_SYS."-sat-elevation.out"

  print "Satellite elevation file path = ", sat_elevation

  # Set plot properties:
  set terminal png size 1400,800
  set output OUT_PATH."/".SAT_SYS."-elevation.png"
  set title  "Satellite System '".SAT_SYS."': Observed Elevation"
  set xlabel "Observation Epochs"
  set ylabel "Elevation [deg]"

  # Get data file stats for retrieving number of columns:
  stats sat_elevation using 8 nooutput
  print "Satellite elevation output number of columns = ", STATS_columns

  # Axis ranges:
  set xrange[0:STATS_records]
  set yrange[0:90] # 0 to pi/2

  # Automatic set of SAT_ID to dataset title:
  set key autotitle columnheader
  # Plot iteration for all satellites and finally for configured mask:
  plot for [i=9:STATS_columns] sat_elevation using i with lines lw 1,\
       sat_elevation using 8 title "Configured satellite mask" with lines lw 3

print ""

# ******************* #
#    1.c Sky plot:    #
# ******************* #
print "Plot 1.c: Sky Plot"

  # Information can be extracted from:
  # elevation by satellite + azimut by satellite
  sat_azimut=INP_PATH."/".SAT_SYS."-sat-azimut.out"

  print "Satellite elevation file path = ", sat_elevation
  print "Satellite azimut    file path = ", sat_azimut

  # Compute file stats:
  stats sat_azimut    using 7 skip 1 nooutput prefix "AZI"
  stats sat_elevation using 7 skip 1 nooutput prefix "ELV"

  num_epochs=AZI_records
  num_sat=ELV_columns-8
  azi_first_sat_col_index=8
  elv_first_sat_col_index=9 # = azi_first_sat_col_index + 1

  print "Number of epochs = ", num_epochs
  print "Number of sats   = ", num_sat


  # Set plot properties:
  set terminal png; set output OUT_PATH."/".SAT_SYS."-sky-plot.png"

  # Plot aspect:
  set size square
  set title "Satellite System '".SAT_SYS."': Sky Plot"
  unset border; unset grid
  unset xlabel; unset ylabel

  # Polar properties
  set angle degrees
  set polar; set grid polar; set border polar

  # Orentation tics:
  unset xtics; unset ytics; unset rtics
  set ttics add ("N" 90, "E" 0, "S" 270, "W" 180) font ":Bold"

  # Azimut and elevation range:
  unset xrange; unset yrange
  set trange[0:360]; set rrange[90:0]

  # Increase samples to plot:
  set samples 300

  # How to plot:
  # Init arrays to hold azimut and elevation:
  array azimut[num_epochs]
  array elevation[num_epochs]

  plot for[i=8:20] sat_azimut using i:0 with lines


print ""



# 2. Receiver Position plots:
#    2.a Easting/Northing point densisty plot:
#    2.b Upping plot:
#    2.c Easting/Northing/Upping point density 3D plot:


# 3. Ex-post Dilution of Precission:
#    3.a ECEF frame DOP:
#    3.b ENU frame DOP:


# 4. Least Squeares Estimation plots:
#    4.a Number of iterations:
#    4.b Ex-post Standard Deviation Estimator:
#    4.c Delta Parameter estimation:
#    4.d Residuals by satellite:
#    4.e Elevation by satellite (same as 1.b plot)


# 5. Ionosphere and Troposphere Delay Estimation plots:
#    5.a Ionosphere Computed Delay by satellite:
#    5.b Troposphere Computed delay by satellite:
#    5.c Elevation by satellite (same as 1.b plot)


# ============================================================================ #
# Private Functions:                                                           #
# ============================================================================ #
