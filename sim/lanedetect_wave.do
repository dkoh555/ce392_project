add wave -noupdate -group lanedetect_top_inst
add wave -noupdate -group lanedetect_top_inst -radix hexadecimal /my_uvm_tb/lanedetect_top_inst/*

add wave -noupdate -group input_fifo_inst
add wave -noupdate -group input_fifo_inst -radix hexadecimal  /my_uvm_tb/lanedetect_top_inst/input_fifo_inst/*

add wave -noupdate -group grayscale_inst
add wave -noupdate -group grayscale_inst -radix hexadecimal  /my_uvm_tb/lanedetect_top_inst/grayscale_inst/*

add wave -noupdate -group gaussian_blur_inst
add wave -noupdate -group gaussian_blur_inst -radix hexadecimal  /my_uvm_tb/lanedetect_top_inst/gaussian_blur_inst/*

add wave -noupdate -group sobel_inst
add wave -noupdate -group sobel_inst -radix hexadecimal  /my_uvm_tb/lanedetect_top_inst/sobel_inst/*

add wave -noupdate -group non_max_suppression_inst
add wave -noupdate -group non_max_suppression_inst -radix hexadecimal  /my_uvm_tb/lanedetect_top_inst/non_max_suppression_inst/*

add wave -noupdate -group hysteresis_inst
add wave -noupdate -group hysteresis_inst -radix hexadecimal  /my_uvm_tb/lanedetect_top_inst/hysteresis_inst/*

add wave -noupdate -group roi_inst
add wave -noupdate -group roi_inst -radix hexadecimal  /my_uvm_tb/lanedetect_top_inst/roi_inst/*

add wave -noupdate -group hough_inst
add wave -noupdate -group hough_inst -radix hexadecimal  /my_uvm_tb/lanedetect_top_inst/hough_inst/*

add wave -noupdate -group center_lane_inst
add wave -noupdate -group center_lane_inst -radix hexadecimal  /my_uvm_tb/lanedetect_top_inst/center_lane_inst/*

# turn off std_logic_arith, std_logic_unsigned, and numeric_std warnings
set StdArithNoWarnings      1
set StdNumNoWarnings        1
set NumericStdNoWarnings    1

# run just to 0 ns (where your X/U’s live)
run 0 ns

# turn them back on for the rest of the sim
set StdArithNoWarnings      0
set StdNumNoWarnings        0
set NumericStdNoWarnings    0