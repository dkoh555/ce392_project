`ifndef __GLOBALS__
`define __GLOBALS__

// Support for multiple images
localparam string STEERING_OUT_NAMES [0:0]    = '{"../uvm/center_lane_uvm/out/steering_out.txt"};
localparam string STEERING_CMP_NAMES [0:0]    = '{"../uvm/center_lane_uvm/cmp/steering_cmp.txt"};
localparam string LEFT_RHO_IN_NAMES [0:0]     = '{"../uvm/center_lane_uvm/in/left_rho_in.txt"    };
localparam string RIGHT_RHO_IN_NAMES [0:0]    = '{"../uvm/center_lane_uvm/in/right_rho_in.txt"   };
localparam string LEFT_THETA_IN_NAMES [0:0]   = '{"../uvm/center_lane_uvm/in/left_theta_in.txt"  };
localparam string RIGHT_THETA_IN_NAMES [0:0]  = '{"../uvm/center_lane_uvm/in/right_theta_in.txt" };

// UVM Globals
localparam int IMG_WIDTH = 160;
localparam int IMG_HEIGHT = 120;
localparam int BMP_HEADER_SIZE = 54;
localparam int BYTES_PER_PIXEL = 3;
localparam int BYTES_PER_DATA = 3;
localparam int BMP_DATA_SIZE = (IMG_WIDTH * IMG_HEIGHT * BYTES_PER_PIXEL);
localparam int CLOCK_PERIOD = 10;
localparam int HYSTERESIS_HIGH_THRESHOLD = 100;
localparam int HYSTERESIS_LOW_THRESHOLD = 60;
localparam int ROI = 60;

localparam int RHO_RES_LOG = 2;    
localparam int RHOS = 50;  
localparam int THETAS = 180;  
localparam int TOP_N = 16;   
localparam int BRAM_ADDR_WIDTH = 10; 
localparam int BRAM_DATA_WIDTH = 10; 
localparam int BOT_BITS = 10;
localparam int TOP_BITS = 10;

localparam int OFFSET = 51;
localparam int ANGLE = 307;

`endif
