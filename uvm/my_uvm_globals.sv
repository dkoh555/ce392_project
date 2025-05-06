`ifndef __GLOBALS__
`define __GLOBALS__

// UVM Globals
localparam string IMG_IN_NAME  = "../c/images/real1.bmp";
localparam string LEFT_RHO_CMP_NAME = "../c/images/out/real1/left_rho_idx_cmp.txt";
localparam string LEFT_THETA_CMP_NAME = "../c/images/out/real1/left_theta_idx_cmp.txt";
localparam string RIGHT_RHO_CMP_NAME = "../c/images/out/real1/right_rho_idx_cmp.txt";
localparam string RIGHT_THETA_CMP_NAME = "../c/images/out/real1/right_theta_idx_cmp.txt";
localparam string LEFT_RHO_OUT_NAME = "../c/images/out/real1/left_rho_idx_out.txt";
localparam string LEFT_THETA_OUT_NAME = "../c/images/out/real1/left_theta_idx_out.txt";
localparam string RIGHT_RHO_OUT_NAME = "../c/images/out/real1/right_rho_idx_out.txt";
localparam string RIGHT_THETA_OUT_NAME = "../c/images/out/real1/right_theta_idx_out.txt";
localparam string STEERING_OUT_NAME = "../c/images/out/real1/steering_out.txt";
localparam string STEERING_CMP_NAME = "../c/images/out/real1/steering_cmp.txt";
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
localparam int BRAM_ADDR_WIDTH = 17; 
localparam int BRAM_DATA_WIDTH = 19; 
localparam int BOT_BITS = 10;
localparam int TOP_BITS = 10;
localparam int BUFFS = 8;
localparam int BUFFS_LOG = 3;

localparam int OFFSET = 51;
localparam int ANGLE = 307;

`endif
