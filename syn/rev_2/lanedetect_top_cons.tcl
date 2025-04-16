
proc syn_dump_io {} {
	execute_module -tool cdb -args "--back_annotate=pin_device"
}

source "/vol/synopsys/fpga/O-2018.09-SP1/lib/altera/quartus_cons.tcl"
syn_create_and_open_prj lanedetect_top
source $::quartus(binpath)/prj_asd_import.tcl
syn_create_and_open_csf lanedetect_top
syn_handle_cons lanedetect_top
syn_compile_quartus
syn_dump_io
