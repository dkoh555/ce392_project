//------------------------------------------------------------------------------
// Module : sample_every_4
// 
// On every clock the input data_in[23:0] is sampled, but only every 4th word
// is presented on data_out with valid=1.  All other cycles valid=0.
//------------------------------------------------------------------------------ 
module sample_every_4 (
    input            clk,      // clock
    input            rst_n,    // active‐low reset
    input  [23:0]    data_in,  // 24‐bit input stream (one word per clk)
	input			 wr_en,
    output reg       valid,    // high for one cycle when data_out is new
    output reg [23:0] data_out // output word, valid when valid==1
);

  // count from 0 to 3
  reg [1:0] count;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      count    <= 2'b00;
      data_out <= 24'b0;
      valid    <= 1'b0;
    end else begin
	  if (wr_en) begin
        // by convention we sample & assert valid when count==0
        if (count == 2'b00) begin
          data_out <= data_in;
          valid    <= 1'b1;
        end else begin
          valid    <= 1'b0;
        end
        // increment mod‐4
        count <= count + 2'b01;
	  end else begin
	    count <= count;
		valid <= 1'b0;
		data_out <= 24'b0;
	  end
    end
  end

endmodule
