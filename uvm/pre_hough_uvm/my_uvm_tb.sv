
import uvm_pkg::*;
import my_uvm_package::*;

`include "my_uvm_if.sv"

`timescale 1 ns / 1 ns

module my_uvm_tb;

    my_uvm_if vif();

    lanedetect_top #(
        .g_FIFO_BUFFER_SIZE(64),
        .g_WIDTH(IMG_WIDTH),
        .g_HEIGHT(IMG_HEIGHT)
    ) lanedetect_top_inst (
        .i_CLK(vif.clock),
        .i_RST(vif.reset), 
        .i_PIXEL(vif.in_din),
        .o_FULL(vif.in_full),
        .i_WR_EN(vif.in_wr_en),
        .o_PIXEL(vif.out_dout),
        .o_EMPTY(vif.out_empty),
        .i_RD_EN(vif.out_rd_en)
    );

    initial begin
        // store the vif so it can be retrieved by the driver & monitor
        uvm_resource_db#(virtual my_uvm_if)::set
            (.scope("ifs"), .name("vif"), .val(vif));

        // run the test
        run_test("my_uvm_test");        
    end

    // reset
    initial begin
        vif.clock <= 1'b1;
        vif.reset <= 1'b0;
        @(posedge vif.clock);
        vif.reset <= 1'b1;
        @(posedge vif.clock);
        vif.reset <= 1'b0;
    end

    // 10ns clock
    always
        #(CLOCK_PERIOD/2) vif.clock = ~vif.clock;
endmodule






