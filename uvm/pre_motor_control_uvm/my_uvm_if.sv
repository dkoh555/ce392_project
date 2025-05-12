import uvm_pkg::*;

interface my_uvm_if;
    logic        clock;
    logic        reset;
    logic        in_full;
    logic        in_wr_en;
    logic [23:0] in_din;
    logic        out_empty;
    logic        out_rd_en;
    logic  [BOT_BITS-1:0] out_steering_dout;
endinterface
