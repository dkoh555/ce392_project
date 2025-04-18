add wave -noupdate -group lanedetect_top_inst
add wave -noupdate -group lanedetect_top_inst -radix hexadecimal /my_uvm_tb/lanedetect_top_inst/*

add wave -noupdate -group input_fifo_inst
add wave -noupdate -group input_fifo_inst -radix hexadecimal  /my_uvm_tb/lanedetect_top_inst/input_fifo_inst/*

add wave -noupdate -group grayscale_inst
add wave -noupdate -group grayscale_inst -radix hexadecimal  /my_uvm_tb/lanedetect_top_inst/grayscale_inst/*

add wave -noupdate -group gaussian_blur_inst
add wave -noupdate -group gaussian_blur_inst -radix hexadecimal  /my_uvm_tb/lanedetect_top_inst/gaussian_blur_inst/*