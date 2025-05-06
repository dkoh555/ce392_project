import uvm_pkg::*;

interface my_uvm_if;
    logic        clock;
    logic        reset;
    logic        in_full;
    logic        in_wr_en;
    logic [23:0] in_din;
    logic        out_empty;
    logic        out_rd_en;
    logic  [BRAM_ADDR_WIDTH-1:0] out_left_rho_dout;
    logic  [BRAM_ADDR_WIDTH-1:0] out_left_theta_dout;
    logic  [BRAM_ADDR_WIDTH-1:0] out_right_rho_dout;
    logic  [BRAM_ADDR_WIDTH-1:0] out_right_theta_dout;
endinterface
