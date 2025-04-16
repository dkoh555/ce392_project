`ifndef __GLOBALS__
`define __GLOBALS__

// UVM Globals
localparam string IMG_IN_NAME  = "../c/images/testlane0.bmp";
localparam string IMG_OUT_NAME = "../c/images/testlane0_rtl.bmp";
localparam string IMG_CMP_NAME = "../c/images/testlane0_output.bmp";
localparam int IMG_WIDTH = 720;
localparam int IMG_HEIGHT = 540;
localparam int BMP_HEADER_SIZE = 54;
localparam int BYTES_PER_PIXEL = 3;
localparam int BMP_DATA_SIZE = (IMG_WIDTH * IMG_HEIGHT * BYTES_PER_PIXEL);
localparam int CLOCK_PERIOD = 10;

`endif
