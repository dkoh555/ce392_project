`ifndef __GLOBALS__
`define __GLOBALS__

// Support for multiple images
localparam string LEFT_RHO_OUT_NAMES [0:1] = '{"../c/images/out/real10/left_rho_idx_out.txt", "../c/images/out/real11/left_rho_idx_out.txt"};
localparam string LEFT_THETA_OUT_NAMES [0:1] = '{"../c/images/out/real10/left_theta_idx_out.txt", "../c/images/out/real11/left_theta_idx_out.txt"};
localparam string RIGHT_RHO_OUT_NAMES [0:1] = '{"../c/images/out/real10/right_rho_idx_out.txt", "../c/images/out/real11/right_rho_idx_out.txt"};
localparam string RIGHT_THETA_OUT_NAMES [0:1] = '{"../c/images/out/real10/right_theta_idx_out.txt", "../c/images/out/real11/right_theta_idx_out.txt"};
localparam string LEFT_RHO_CMP_NAMES [0:1] = '{"../c/images/out/real10/left_rho_idx_cmp.txt", "../c/images/out/real11/left_rho_idx_cmp.txt"};
localparam string LEFT_THETA_CMP_NAMES [0:1] = '{"../c/images/out/real10/left_theta_idx_cmp.txt", "../c/images/out/real11/left_theta_idx_cmp.txt"};
localparam string RIGHT_RHO_CMP_NAMES [0:1] = '{"../c/images/out/real10/right_rho_idx_cmp.txt", "../c/images/out/real11/right_rho_idx_cmp.txt"};
localparam string RIGHT_THETA_CMP_NAMES [0:1] = '{"../c/images/out/real10/right_theta_idx_cmp.txt", "../c/images/out/real11/right_theta_idx_cmp.txt"};
localparam string IMG_IN_NAMES  [0:1] = '{"../c/images/out/real10/roi_raw.bmp", "../c/images/out/real11/roi_raw.bmp"};

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

localparam int RHO_RES_LOG = 1;    
localparam int RHOS = 450;  
localparam int THETAS = 180;  
localparam int TOP_N = 16;   
localparam int BRAM_ADDR_WIDTH = 10; 
localparam int BRAM_DATA_WIDTH = 10; 
localparam int BOT_BITS = 10;
localparam int TOP_BITS = 10;

localparam int OFFSET = 51;
localparam int ANGLE = 307;

`endif