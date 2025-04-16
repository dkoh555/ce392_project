history clear
project -load /home/nmh6120/ce387/final_proj/syn/fm_radio.prj
project -new /home/nmh6120/ce387/final_proj/syn/proj_1.prj
project_data -active /home/nmh6120/ce387/final_proj/syn/fm_radio.prj
set_option -frequency 120.000000
project -close /home/nmh6120/ce387/final_proj/syn/fm_radio.prj
add_file -verilog /home/nmh6120/ce387/CE392/rtl/fifo.sv
add_file -vhdl /home/nmh6120/ce387/CE392/rtl/grayscale.vhd
add_file -vhdl /home/nmh6120/ce387/CE392/rtl/lanedetect_top.vhd
project -save proj_1 /home/nmh6120/ce387/CE392/syn/lanedetect.prj
project -run  
project -run  
set_option -technology CYCLONEV
set_option -part 5CSEBA6
set_option -package UI23
project -run  
project -run  
set_option -frequency 1.000000
set_option -frequency 100
project -run  
project -save /home/nmh6120/ce387/CE392/syn/lanedetect.prj 
project -close /home/nmh6120/ce387/CE392/syn/lanedetect.prj
