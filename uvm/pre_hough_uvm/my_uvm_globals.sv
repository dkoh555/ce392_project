`ifndef __GLOBALS__
`define __GLOBALS__

// Support for multiple images
localparam string IMG_OUT_NAMES [0:1] = '{"../c/images/out/real10/rtl.bmp", "../c/images/out/real11/rtl.bmp"};
localparam string IMG_CMP_NAMES [0:1] = '{"../c/images/out/real10/roi_raw.bmp", "../c/images/out/real11/roi_raw.bmp"};
localparam string IMG_IN_NAMES  [0:1] = '{"../c/images/real10.bmp", "../c/images/real11.bmp"};

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
localparam int ROI = 40;

localparam int RHO_RES_LOG = 2;    
localparam int RHOS = 50;  
localparam int THETAS = 180;  
localparam int TOP_N = 4;   
localparam int BRAM_ADDR_WIDTH = 10; 
localparam int BRAM_DATA_WIDTH = 10; 
localparam int BOT_BITS = 10;
localparam int TOP_BITS = 8; 

localparam int OFFSET = 51;
localparam int ANGLE = 307;

`endif