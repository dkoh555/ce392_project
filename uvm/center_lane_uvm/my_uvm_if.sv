import uvm_pkg::*;

interface my_uvm_if;
    logic        clock;
    logic        reset;
    logic        in_full;
    logic        in_wr_en;
    logic [BRAM_ADDR_WIDTH-1:0] left_rho;
    logic [BRAM_ADDR_WIDTH-1:0] right_rho;
    logic [BRAM_ADDR_WIDTH-1:0] left_theta;
    logic [BRAM_ADDR_WIDTH-1:0] right_theta;
    logic        out_empty;
    logic        out_rd_en;
    logic  [BOT_BITS-1:0] out_steering_dout;
endinterface
