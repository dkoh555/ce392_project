`ifndef __GLOBALS__
`define __GLOBALS__

// Support for multiple images
localparam string STEERING_OUT_NAMES [0:1] = '{"../c/images/out/real0/steering_out.txt", "../c/images/out/real1/steering_out.txt"};
localparam string STEERING_CMP_NAMES [0:1] = '{"../c/images/out/real0/steering_cmp.txt", "../c/images/out/real1/steering_cmp.txt"};
localparam string IMG_IN_NAMES  [0:1] = '{"../c/images/out/real0/roi_raw.bmp", "../c/images/out/real1/roi_raw.bmp"};

// UVM Globals
localparam int IMG_WIDTH = 720;
localparam int IMG_HEIGHT = 540;
localparam int BMP_HEADER_SIZE = 54;
localparam int BYTES_PER_PIXEL = 3;
localparam int BYTES_PER_DATA = 3;
localparam int BMP_DATA_SIZE = (IMG_WIDTH * IMG_HEIGHT * BYTES_PER_PIXEL);
localparam int CLOCK_PERIOD = 10;
localparam int HYSTERESIS_HIGH_THRESHOLD = 100;
localparam int HYSTERESIS_LOW_THRESHOLD = 60;
localparam int ROI = 270;

localparam int RHO_RES_LOG = 1;    
localparam int RHOS = 450;  
localparam int THETAS = 180;  
localparam int TOP_N = 16;   
localparam int BRAM_ADDR_WIDTH = 10; 
localparam int BRAM_DATA_WIDTH = 10; 
localparam int BOT_BITS = 10;
localparam int TOP_BITS = 10;
localparam int BUFFS = 8;
localparam int BUFFS_LOG = 3;

localparam int OFFSET = 51;
localparam int ANGLE = 307;

`endif
