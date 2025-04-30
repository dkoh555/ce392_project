
setenv LMC_TIMEUNIT -9
vlib work
vmap work work

# rtl files
vlog -work work "../rtl/fifo.sv"
vcom -2008 -work work "../rtl/roi.vhd"
vcom -2008 -work work "../rtl/lanedetect_pkg.vhd"
vcom -2008 -work work "../rtl/grayscale.vhd"
vcom -2008 -work work "../rtl/gaussian_blur.vhd"
vcom -2008 -work work "../rtl/sobel.vhd"
vcom -2008 -work work "../rtl/non_max_suppression.vhd"
vcom -2008 -work work "../rtl/hysteresis.vhd"
vcom -2008 -work work "../rtl/roi.vhd"
vcom -2008 -work work "../rtl/lanedetect_top.vhd"

# uvm library
vlog -work work +incdir+$env(UVM_HOME)/src $env(UVM_HOME)/src/uvm.sv
vlog -work work +incdir+$env(UVM_HOME)/src $env(UVM_HOME)/src/uvm_macros.svh
vlog -work work +incdir+$env(UVM_HOME)/src $env(MTI_HOME)/verilog_src/questa_uvm_pkg-1.2/src/questa_uvm_pkg.sv

# uvm package
vlog -work work +incdir+$env(UVM_HOME)/src "../uvm/my_uvm_pkg.sv"
vlog -work work +incdir+$env(UVM_HOME)/src "../uvm/my_uvm_tb.sv"

# start uvm simulation
vsim -classdebug -voptargs=+acc +notimingchecks -L work work.my_uvm_tb -wlf my_uvm_tb.wlf -sv_lib lib/uvm_dpi -dpicpppath /usr/bin/gcc +incdir+$env(MTI_HOME)/verilog_src/questa_uvm_pkg-1.2/src/

do lanedetect_wave.do

run -all
