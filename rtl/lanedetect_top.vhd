library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity lanedetect_top is

    generic (
        g_FIFO_BUFFER_SIZE  : integer := 64;
        g_WIDTH             : integer := 160;
        g_HEIGHT            : integer := 120;

        -- Hysteresis 
        g_HYSTERESIS_HIGH_THRESHOLD : integer := 150;
        g_HYSTERESIS_LOW_THRESHOLD  : integer := 100;
        g_ROI                       : integer := 270;

        -- Generics for Hough Transform
        g_RHO_RES_LOG   : integer := 2;     -- Clog2(Rho Resolution = 2)
        g_RHOS          : integer := 50;   -- Sqrt(ROWS ^ 2 + COLS ^ 2) / Rho Resolution
        g_THETAS        : integer := 180;   -- Can decrease this (e.g. to 64)
        g_TOP_N         : integer := 8;    -- Number of top voted Rhos and Theta values to consider
        g_BRAM_ADDR_WIDTH : integer := 10;  -- Clog2(g_RHOS * g_THETAS), size of BRAM to hold votes
        g_BRAM_DATA_WIDTH : integer := 10;  -- Clog2(g_HEIGHT * g_WIDTH), maximum count of votes for each Rho
        -- Quantization
        g_BOT_BITS : integer := 10;
        g_TOP_BITS : integer := 8;
        -- Steering
        g_OFFSET : integer := 51; 
        g_ANGLE : integer := 307;
        -- Simple Motor Control Parameters
        g_STEERING_THRESHOLD : integer := 100  -- Threshold for determining turn vs straight
    );

    port (
        i_CLK       : in    std_logic;
        --i_RST       : in    std_logic;

        -- Input data
        -- i_PIXEL     : in    std_logic_vector(23 downto 0);
        --o_FULL      : out   std_logic;
        --i_WR_EN     : in    std_logic;

        -- Output control signals
        o_EMPTY         : out   std_logic;
        
        -- Direct PWM motor outputs
        o_LEFT_MOTOR_PWM    : out   std_logic;
        o_RIGHT_MOTOR_PWM   : out   std_logic;
		o_LEFT_MOTOR_INACTIVE	:	out	std_logic;
		o_RIGHT_MOTOR_INACTIVE	:	out std_logic;
		
		-- CLOCKS --
		i_FPGA_CLK1_50		:	in std_logic;
		i_FPGA_CLK2_50		:	in std_logic;
		i_FPGA_CLK3_50		:	in std_logic;
		-- HDMI --
		i_HDMI_I2C_SCL		:	inout std_logic;
		i_HDMI_I2C_SDA		:	inout std_logic;
		i_HDMI_I2S			:	inout std_logic;
		i_HDMI_LRCLK			:	inout std_logic;
		i_HDMI_MCLK			:	inout std_logic;
		i_HDMI_SCLK			:	inout std_logic;
		i_HDMI_TX_CLK			:	out std_logic;
		i_HDMI_TX_DE			:	out std_logic;
		i_HDMI_TX_D			:	out std_logic_vector(23 downto 0);
		i_HDMI_TX_HS			:	out std_logic;
		i_HDMI_TX_INT			:	in std_logic;
		i_HDMI_TX_VS			:	out std_logic;
		-- KEY --
		i_KEY					:	in std_logic_vector(1 downto 0);
		-- SW --
		i_SW					:	in std_logic_vector(3 downto 0);
		-- GPIO_0 (D8M) --
		i_CAMERA_I2C_SCL			:	inout std_logic;
		i_CAMERA_I2C_SDA			:	inout std_logic;
		i_CAMERA_PWDN_n			:	out std_logic;
		i_MIPI_CS_n				:	out std_logic;
		i_MIPI_I2C_SCL			:	inout std_logic;
		i_MIPI_I2C_SDA			:	inout std_logic;
		i_MIPI_MCLK				:	out std_logic;
		i_MIPI_PIXEL_CLK			:	in std_logic;
		i_MIPI_PIXEL_D			:	in std_logic_vector(9 downto 0);
		i_MIPI_PIXEL_HS			:	in std_logic;
		i_MIPI_PIXEL_VS			:	in std_logic;
		i_MIPI_REFCLK				:	out std_logic;
		i_MIPI_RESET_n			:	out std_logic
--		o_DEBUG					:	out std_logic
    );

end entity lanedetect_top;

architecture rtl of lanedetect_top is

    component fifo is
        generic (
            FIFO_DATA_WIDTH : integer;
            FIFO_BUFFER_SIZE : integer
        );
        port (
            reset   : in    std_logic;
            wr_clk  : in    std_logic;
            wr_en   : in    std_logic;
            din     : in    std_logic_vector(FIFO_DATA_WIDTH-1 downto 0);
            full    : out   std_logic;
            rd_clk  : in    std_logic;
            rd_en   : in    std_logic;
            dout    : out   std_logic_vector(FIFO_DATA_WIDTH-1 downto 0);
            empty   : out   std_logic
        );
    end component fifo;

    component grayscale is
        generic (
            g_HEIGHT : integer := 540;
            g_WIDTH  : integer := 720
        );
        port (
            i_CLK   : in    std_logic;
            i_RST   : in    std_logic;
            -- Input FIFO signals
            i_PIXEL : in    std_logic_vector(23 downto 0);
            i_EMPTY : in    std_logic;
            o_RD_EN : out   std_logic;
            -- Output FIFO signals
            o_PIXEL : out   std_logic_vector(7 downto 0);
            i_FULL  : in    std_logic;
            o_WR_EN : out   std_logic
        );
    end component grayscale;

    component gaussian_blur is
        generic (
            g_HEIGHT : integer := 540;
            g_WIDTH  : integer := 720
        );
        port (
            i_CLK : in std_logic;
            i_RST : in std_logic;
            -- Input FIFO signals
            i_PIXEL : in    std_logic_vector(7 downto 0);
            i_EMPTY : in    std_logic;
            o_RD_EN : out   std_logic;
            -- Output FIFO signals
            o_PIXEL : out   std_logic_vector(7 downto 0);
            i_FULL  : in    std_logic;
            o_WR_EN : out   std_logic
        );
    end component gaussian_blur;

    component sobel is

        generic (
            g_HEIGHT : integer := 540;
            g_WIDTH  : integer := 720
        );
    
        port (
            i_CLK   : in std_logic;
            i_RST   : in std_logic;
    
            -- Input FIFO signals
            i_EMPTY : in std_logic;
            o_RD_EN : out std_logic;
            i_PIXEL : in std_logic_vector(7 downto 0);
    
            -- Output FIFO signals
            i_FULL  : in std_logic;
            o_WR_EN : out std_logic;
            o_PIXEL : out std_logic_vector(7 downto 0)
        );
    
    end component sobel;

    component non_max_suppression is

        generic (
            g_HEIGHT : integer := 540;
            g_WIDTH  : integer := 720
        );
    
        port (
            i_CLK   : in std_logic;
            i_RST   : in std_logic;
    
            -- Input FIFO signals
            i_EMPTY : in std_logic;
            o_RD_EN : out std_logic;
            i_PIXEL : in std_logic_vector(7 downto 0);
    
            -- Output FIFO signals
            i_FULL  : in std_logic;
            o_WR_EN : out std_logic;
            o_PIXEL : out std_logic_vector(7 downto 0)
        );
    
    end component non_max_suppression;

    component hysteresis is

        generic (
            g_HEIGHT : integer := 540;
            g_WIDTH  : integer := 720;
            g_HIGH_THRESHOLD : integer := 150;
            g_LOW_THRESHOLD : integer := 100
        );
    
        port (
            i_CLK   : in std_logic;
            i_RST   : in std_logic;
    
            -- Input FIFO signals
            i_EMPTY : in std_logic;
            o_RD_EN : out std_logic;
            i_PIXEL : in std_logic_vector(7 downto 0);
    
            -- Output FIFO signals
            i_FULL  : in std_logic;
            o_WR_EN : out std_logic;
            o_PIXEL : out std_logic_vector(7 downto 0)
        );
    
    end component hysteresis;

    component roi is

        generic (
            g_HEIGHT : integer := 540;
            g_WIDTH  : integer := 720;
            g_ROI    : integer := 270
        );
    
        port (
            i_CLK   : in    std_logic;
            i_RST   : in    std_logic;
            
            -- Input FIFO signals
            i_PIXEL : in    std_logic_vector(7 downto 0);
            i_EMPTY : in    std_logic;
            o_RD_EN : out   std_logic;
            
            -- Output FIFO signals
            o_PIXEL : out   std_logic_vector(7 downto 0);
            i_FULL  : in    std_logic;
            o_WR_EN : out   std_logic
        );
    
    end component roi;

    component hough is

        generic (
            g_HEIGHT : integer := 540;
            g_WIDTH  : integer := 720;
            -- Resolution of Hough Transform
            g_RHO_RES_LOG   : integer := 2;     -- Clog2(Rho Resolution = 2)
            g_RHOS          : integer := 50;   -- Sqrt(ROWS ^ 2 + COLS ^ 2) / Rho Resolution
            g_THETAS        : integer := 180;   -- Can decrease this (e.g. to 64)
            g_TOP_N         : integer := 16;    -- Number of top voted Rhos and Theta values to consider
            g_BRAM_ADDR_WIDTH : integer := 10;  -- Clog2(g_RHOS * g_THETAS), size of BRAM to hold votes
            g_BRAM_DATA_WIDTH : integer := 10;  -- Clog2(g_HEIGHT * g_WIDTH), maximum count of votes for each Rho
            -- Quantization
            g_BOT_BITS : integer := 10;
            g_TOP_BITS : integer := 8
        );

        port (
            i_CLK   : in std_logic;
            i_RST   : in std_logic;

            -- Input FIFO signals
            i_EMPTY : in std_logic;
            o_RD_EN : out std_logic;
            i_PIXEL : in std_logic_vector(7 downto 0);

            -- Output FIFO signals
            o_LEFT_RHO      : out   std_logic_vector(g_BRAM_ADDR_WIDTH - 1 downto 0);
            o_LEFT_THETA    : out   std_logic_vector(g_BRAM_ADDR_WIDTH - 1 downto 0);
            o_RIGHT_RHO     : out   std_logic_vector(g_BRAM_ADDR_WIDTH - 1 downto 0);
            o_RIGHT_THETA   : out   std_logic_vector(g_BRAM_ADDR_WIDTH - 1 downto 0);
            i_FULL          : in    std_logic;
            o_WR_EN         : out   std_logic
        );

    end component hough;

    component center_lane is

        generic (
            g_HEIGHT : integer := 540;
            g_WIDTH  : integer := 720;
            -- Resolution of Hough transform
            g_RHO_RES_LOG   : integer := 1;     -- Clog2(Rho Resolution = 2)
            g_RHOS          : integer := 450;   -- Sqrt(ROWS ^ 2 + COLS ^ 2) / Rho Resolution
            g_THETAS        : integer := 180;   -- Can decrease this (e.g. to 64), also represents number of brams to be used
            g_BRAM_ADDR_WIDTH : integer := 17;
            -- Quantization
            g_BOT_BITS : integer := 10;
            g_TOP_BITS : integer := 8;
            -- Steering
            g_OFFSET : integer := 51; 
            g_ANGLE : integer := 307
        );
        port (
            i_CLK   : in std_logic;
            i_RST   : in std_logic;
    
            -- Input FIFO signals
            i_EMPTY : in std_logic;
            o_RD_EN : out std_logic;
            i_LEFT_RHO      : in   std_logic_vector(g_BRAM_ADDR_WIDTH - 1 downto 0);
            i_LEFT_THETA    : in   std_logic_vector(g_BRAM_ADDR_WIDTH - 1 downto 0);
            i_RIGHT_RHO     : in   std_logic_vector(g_BRAM_ADDR_WIDTH - 1 downto 0);
            i_RIGHT_THETA   : in   std_logic_vector(g_BRAM_ADDR_WIDTH - 1 downto 0);
    
            -- Output FIFO signals
            o_STEERING      : out   std_logic_vector(g_BOT_BITS - 1 downto 0);
            i_FULL          : in    std_logic;
            o_WR_EN         : out   std_logic
        );
    
    end component center_lane;

    -- Simple motor control component declaration (SystemVerilog module)
    component motor_control is
        generic (
            STEERING_WIDTH : integer := 10;
            PWM_RESOLUTION : integer := 8;
            STEERING_THRESHOLD : integer := 100
        );
        port (
            clk : in std_logic;
            reset_n : in std_logic;
            i_steering : in std_logic_vector(STEERING_WIDTH-1 downto 0);
            i_valid : in std_logic;
            o_ready : out std_logic;
            o_left_motor_pwm : out std_logic;
            o_right_motor_pwm : out std_logic
        );
    end component motor_control;
	
	component DE10_NANO_D8M_RTL is
		port (
			-- CLOCKS --
			FPGA_CLK1_50		:	in std_logic;
			FPGA_CLK2_50		:	in std_logic;
			FPGA_CLK3_50		:	in std_logic;
			-- HDMI --
			HDMI_I2C_SCL		:	inout std_logic;
			HDMI_I2C_SDA		:	inout std_logic;
			HDMI_I2S			:	inout std_logic;
			HDMI_LRCLK			:	inout std_logic;
			HDMI_MCLK			:	inout std_logic;
			HDMI_SCLK			:	inout std_logic;
			HDMI_TX_CLK			:	out std_logic;
			HDMI_TX_DE			:	out std_logic;
			HDMI_TX_D			:	out std_logic_vector(23 downto 0);
			HDMI_TX_HS			:	out std_logic;
			HDMI_TX_INT			:	in std_logic;
			HDMI_TX_VS			:	out std_logic;
			-- KEY --
			KEY					:	in std_logic_vector(1 downto 0);
			-- SW --
			SW					:	in std_logic_vector(3 downto 0);
			-- GPIO_0 (D8M) --
			CAMERA_I2C_SCL			:	inout std_logic;
			CAMERA_I2C_SDA			:	inout std_logic;
			CAMERA_PWDN_n			:	out std_logic;
			MIPI_CS_n				:	out std_logic;
			MIPI_I2C_SCL			:	inout std_logic;
			MIPI_I2C_SDA			:	inout std_logic;
			MIPI_MCLK				:	out std_logic;
			MIPI_PIXEL_CLK			:	in std_logic;
			MIPI_PIXEL_D			:	in std_logic_vector(9 downto 0);
			MIPI_PIXEL_HS			:	in std_logic;
			MIPI_PIXEL_VS			:	in std_logic;
			MIPI_REFCLK				:	out std_logic;
			MIPI_RESET_n			:	out std_logic;
			-- FIFO --
			FIFO_RDEN				:	in std_logic;
			FIFO_RDCLK				:	in std_logic;
			FIFO_RDEMPTY			:	out std_logic;
			FIFO_RDDATA				:	out std_logic_vector(23 downto 0)
--			DEBUG					:	out std_logic
		);
	end component DE10_NANO_D8M_RTL;

    -- All existing signals remain the same...
    signal w_input_rd_en : std_logic;
    signal w_input_empty : std_logic;
    signal w_input_data : std_logic_vector(23 downto 0);

    signal w_grayscale_wr_en : std_logic;
    signal w_grayscale_full : std_logic;
    signal w_grayscale_din : std_logic_vector(7 downto 0);
    signal w_grayscale_rd_en : std_logic;
    signal w_grayscale_empty : std_logic;
    signal w_grayscale_dout : std_logic_vector(7 downto 0);

    signal w_gaussian_blur_wr_en : std_logic;
    signal w_gaussian_blur_full : std_logic;
    signal w_gaussian_blur_din : std_logic_vector(7 downto 0);
    signal w_gaussian_blur_rd_en : std_logic;
    signal w_gaussian_blur_empty : std_logic;
    signal w_gaussian_blur_dout : std_logic_vector(7 downto 0);

    signal w_sobel_wr_en : std_logic;
    signal w_sobel_full : std_logic;
    signal w_sobel_din : std_logic_vector(7 downto 0);
    signal w_sobel_rd_en : std_logic;
    signal w_sobel_empty : std_logic;
    signal w_sobel_dout : std_logic_vector(7 downto 0);

    signal w_non_max_suppression_wr_en : std_logic;
    signal w_non_max_suppression_full : std_logic;
    signal w_non_max_suppression_din : std_logic_vector(7 downto 0);
    signal w_non_max_suppression_rd_en : std_logic;
    signal w_non_max_suppression_empty : std_logic;
    signal w_non_max_suppression_dout : std_logic_vector(7 downto 0);

    signal w_hysteresis_wr_en : std_logic;
    signal w_hysteresis_full : std_logic;
    signal w_hysteresis_din : std_logic_vector(7 downto 0);
    signal w_hysteresis_rd_en : std_logic;
    signal w_hysteresis_empty : std_logic;
    signal w_hysteresis_dout : std_logic_vector(7 downto 0);

    signal w_roi_wr_en : std_logic;
    signal w_roi_full : std_logic;
    signal w_roi_din : std_logic_vector(7 downto 0);
    signal w_roi_rd_en : std_logic;
    signal w_roi_empty : std_logic;
    signal w_roi_dout : std_logic_vector(7 downto 0);

    signal w_hough_left_rho_wr_en : std_logic;
    signal w_hough_left_rho_full : std_logic;
    signal w_hough_left_rho_din : std_logic_vector(g_BRAM_ADDR_WIDTH - 1 downto 0);
    signal w_hough_left_rho_rd_en : std_logic;
    signal w_hough_left_rho_empty : std_logic;
    signal w_hough_left_rho_dout : std_logic_vector(g_BRAM_ADDR_WIDTH - 1 downto 0);

    signal w_hough_left_theta_wr_en : std_logic;
    signal w_hough_left_theta_full : std_logic;
    signal w_hough_left_theta_din : std_logic_vector(g_BRAM_ADDR_WIDTH - 1 downto 0);
    signal w_hough_left_theta_rd_en : std_logic;
    signal w_hough_left_theta_empty : std_logic;
    signal w_hough_left_theta_dout : std_logic_vector(g_BRAM_ADDR_WIDTH - 1 downto 0);

    signal w_hough_right_rho_wr_en : std_logic;
    signal w_hough_right_rho_full : std_logic;
    signal w_hough_right_rho_din : std_logic_vector(g_BRAM_ADDR_WIDTH - 1 downto 0);
    signal w_hough_right_rho_rd_en : std_logic;
    signal w_hough_right_rho_empty : std_logic;
    signal w_hough_right_rho_dout : std_logic_vector(g_BRAM_ADDR_WIDTH - 1 downto 0);

    signal w_hough_right_theta_wr_en : std_logic;
    signal w_hough_right_theta_full : std_logic;
    signal w_hough_right_theta_din : std_logic_vector(g_BRAM_ADDR_WIDTH - 1 downto 0);
    signal w_hough_right_theta_rd_en : std_logic;
    signal w_hough_right_theta_empty : std_logic;
    signal w_hough_right_theta_dout : std_logic_vector(g_BRAM_ADDR_WIDTH - 1 downto 0);

    signal w_hough_full : std_logic;
    signal w_hough_rd_en : std_logic;
    signal w_hough_wr_en : std_logic;
    signal w_hough_empty : std_logic;

    signal w_center_lane_wr_en : std_logic;
    signal w_center_lane_full : std_logic;
    signal w_center_lane_din : std_logic_vector(g_BOT_BITS - 1 downto 0);
    signal w_center_lane_rd_en : std_logic;
    signal w_center_lane_empty : std_logic;
    signal w_center_lane_dout : std_logic_vector(g_BOT_BITS - 1 downto 0);

    -- Signals for simple motor control interface
    signal w_motor_control_valid : std_logic;
    signal w_motor_control_ready : std_logic;
    signal w_reset_n : std_logic;
	
	-- Signals for camera interface
	signal i_RST : std_logic;
begin

	i_RST <= not i_KEY(0);
	o_LEFT_MOTOR_INACTIVE <= '0';
	o_RIGHT_MOTOR_INACTIVE <= '0';
    -- Convert active-high reset to active-low for motor control module
    w_reset_n <= not i_RST;
	
	-- Camera instantiation
	camera_inst	:	DE10_NANO_D8M_RTL
		port map (
			-- CLOCKS --
			FPGA_CLK1_50 => i_FPGA_CLK1_50,
			FPGA_CLK2_50 => i_FPGA_CLK2_50,
			FPGA_CLK3_50 => i_FPGA_CLK3_50,
			-- HDMI --
			HDMI_I2C_SCL => i_HDMI_I2C_SCL,
			HDMI_I2C_SDA => i_HDMI_I2C_SDA,
			HDMI_I2S => i_HDMI_I2S,
			HDMI_LRCLK => i_HDMI_LRCLK,
			HDMI_MCLK => i_HDMI_MCLK,
			HDMI_SCLK => i_HDMI_SCLK,
			HDMI_TX_CLK => i_HDMI_TX_CLK,
			HDMI_TX_DE => i_HDMI_TX_DE,
			HDMI_TX_D => i_HDMI_TX_D,
			HDMI_TX_HS => i_HDMI_TX_HS,
			HDMI_TX_INT => i_HDMI_TX_INT,
			HDMI_TX_VS => i_HDMI_TX_VS,
			-- KEY --
			KEY => i_KEY,
			-- SW --
			SW => i_SW,
			-- GPIO_0 (D8M) --
			CAMERA_I2C_SCL => i_CAMERA_I2C_SCL,
			CAMERA_I2C_SDA => i_CAMERA_I2C_SDA,
			CAMERA_PWDN_n => i_CAMERA_PWDN_n,
			MIPI_CS_n => i_MIPI_CS_n,
			MIPI_I2C_SCL => i_MIPI_I2C_SCL,
			MIPI_I2C_SDA => i_MIPI_I2C_SDA,
			MIPI_MCLK => i_MIPI_MCLK,
			MIPI_PIXEL_CLK => i_MIPI_PIXEL_CLK,
			MIPI_PIXEL_D => i_MIPI_PIXEL_D,
			MIPI_PIXEL_HS => i_MIPI_PIXEL_HS,
			MIPI_PIXEL_VS => i_MIPI_PIXEL_VS,
			MIPI_REFCLK => i_MIPI_REFCLK,
			MIPI_RESET_n => i_MIPI_RESET_n,
			-- FIFO --
			FIFO_RDEN => w_input_rd_en,
			FIFO_RDCLK => i_CLK,
			FIFO_RDEMPTY => w_input_empty,
			FIFO_RDDATA => w_input_data
--			DEBUG => o_DEBUG
		);
		
		o_EMPTY <= w_input_empty;

    -- All existing component instantiations remain exactly the same...
--    input_fifo_inst : fifo
--        generic map (
--            FIFO_DATA_WIDTH     => 24,
--            FIFO_BUFFER_SIZE    => g_FIFO_BUFFER_SIZE
--        )
--        port map (
--            reset   => i_RST,
--            wr_clk  => i_CLK,
--            wr_en   => i_WR_EN,
--            din     => i_PIXEL,
--            full    => o_FULL,
--            rd_clk  => i_CLK,
--            rd_en   => w_input_rd_en,
--            dout    => w_input_data,
--            empty   => w_input_empty
--        );

    grayscale_inst : grayscale
        generic map (
            g_HEIGHT => g_HEIGHT,
            g_WIDTH  => g_WIDTH
        )
        port map (
            i_CLK   => i_CLK,
            i_RST   => i_RST,
            -- Input FIFO signals
            i_PIXEL => w_input_data,
            i_EMPTY => w_input_empty,
            o_RD_EN => w_input_rd_en,
            -- Output FIFO signals
            o_PIXEL => w_grayscale_din,
            i_FULL  => w_grayscale_full,
            o_WR_EN => w_grayscale_wr_en
        );

    grayscale_fifo_inst : fifo
        generic map (
            FIFO_DATA_WIDTH     => 8,
            FIFO_BUFFER_SIZE    => g_FIFO_BUFFER_SIZE
        )
        port map (
            reset   => i_RST,
            wr_clk  => i_CLK,
            wr_en   => w_grayscale_wr_en,
            din     => w_grayscale_din,
            full    => w_grayscale_full,
            rd_clk  => i_CLK,
            rd_en   => w_grayscale_rd_en,
            dout    => w_grayscale_dout,
            empty   => w_grayscale_empty
        );

    -- o_PIXEL <= w_grayscale_dout;
    -- o_EMPTY <= w_grayscale_empty;
    -- w_grayscale_rd_en <= i_RD_EN;

    gaussian_blur_inst : gaussian_blur
        generic map (
            g_HEIGHT => g_HEIGHT,
            g_WIDTH  => g_WIDTH
        )
        port map (
            i_CLK => i_CLK,
            i_RST => i_RST,
            -- Input FIFO signals
            i_PIXEL => w_grayscale_dout,
            i_EMPTY => w_grayscale_empty,
            o_RD_EN => w_grayscale_rd_en,
            -- Output FIFO signals
            o_PIXEL => w_gaussian_blur_din,
            i_FULL  => w_gaussian_blur_full,
            o_WR_EN => w_gaussian_blur_wr_en
        );

    gaussian_blur_fifo_inst : fifo
        generic map (
            FIFO_DATA_WIDTH     => 8,
            FIFO_BUFFER_SIZE    => g_FIFO_BUFFER_SIZE
        )
        port map (
            reset   => i_RST,
            wr_clk  => i_CLK,
            wr_en   => w_gaussian_blur_wr_en,
            din     => w_gaussian_blur_din,
            full    => w_gaussian_blur_full,
            rd_clk  => i_CLK,
            rd_en   => w_gaussian_blur_rd_en,
            dout    => w_gaussian_blur_dout,
            empty   => w_gaussian_blur_empty
        );

    -- o_PIXEL <= w_gaussian_blur_dout;
    -- o_EMPTY <= w_gaussian_blur_empty;
    -- w_gaussian_blur_rd_en <= i_RD_EN;


    sobel_inst : sobel
        generic map (
            g_HEIGHT => g_HEIGHT,
            g_WIDTH  => g_WIDTH
        )
        port map (
            i_CLK => i_CLK,
            i_RST => i_RST,
            -- Input FIFO signals
            i_PIXEL => w_gaussian_blur_dout,
            i_EMPTY => w_gaussian_blur_empty,
            o_RD_EN => w_gaussian_blur_rd_en,
            -- Output FIFO signals
            o_PIXEL => w_sobel_din,
            i_FULL  => w_sobel_full,
            o_WR_EN => w_sobel_wr_en
        );

    sobel_fifo_inst : fifo
        generic map (
            FIFO_DATA_WIDTH     => 8,
            FIFO_BUFFER_SIZE    => g_FIFO_BUFFER_SIZE
        )
        port map (
            reset   => i_RST,
            wr_clk  => i_CLK,
            wr_en   => w_sobel_wr_en,
            din     => w_sobel_din,
            full    => w_sobel_full,
            rd_clk  => i_CLK,
            rd_en   => w_sobel_rd_en,
            dout    => w_sobel_dout,
            empty   => w_sobel_empty
        );

    -- o_PIXEL <= w_sobel_dout;
    -- o_EMPTY <= w_sobel_empty;
    -- w_sobel_rd_en <= i_RD_EN;

    non_max_suppression_inst : non_max_suppression
        generic map (
            g_HEIGHT => g_HEIGHT,
            g_WIDTH  => g_WIDTH
        )
        port map (
            i_CLK => i_CLK,
            i_RST => i_RST,
            -- Input FIFO signals
            i_PIXEL => w_sobel_dout,
            i_EMPTY => w_sobel_empty,
            o_RD_EN => w_sobel_rd_en,
            -- Output FIFO signals
            o_PIXEL => w_non_max_suppression_din,
            i_FULL  => w_non_max_suppression_full,
            o_WR_EN => w_non_max_suppression_wr_en
        );

    non_max_suppression_fifo_inst : fifo
        generic map (
            FIFO_DATA_WIDTH     => 8,
            FIFO_BUFFER_SIZE    => g_FIFO_BUFFER_SIZE
        )
        port map (
            reset   => i_RST,
            wr_clk  => i_CLK,
            wr_en   => w_non_max_suppression_wr_en,
            din     => w_non_max_suppression_din,
            full    => w_non_max_suppression_full,
            rd_clk  => i_CLK,
            rd_en   => w_non_max_suppression_rd_en,
            dout    => w_non_max_suppression_dout,
            empty   => w_non_max_suppression_empty
        );


    -- o_PIXEL <= w_non_max_suppression_dout;
    -- o_EMPTY <= w_non_max_suppression_empty;
    -- w_non_max_suppression_rd_en <= i_RD_EN;

    hysteresis_inst : hysteresis
        generic map (
            g_HEIGHT => g_HEIGHT,
            g_WIDTH  => g_WIDTH,
            g_HIGH_THRESHOLD => g_HYSTERESIS_HIGH_THRESHOLD,
            g_LOW_THRESHOLD => g_HYSTERESIS_LOW_THRESHOLD
        )
        port map (
            i_CLK => i_CLK,
            i_RST => i_RST,
            -- Input FIFO signals
            i_PIXEL => w_non_max_suppression_dout,
            i_EMPTY => w_non_max_suppression_empty,
            o_RD_EN => w_non_max_suppression_rd_en,
            -- Output FIFO signals
            o_PIXEL => w_hysteresis_din,
            i_FULL  => w_hysteresis_full,
            o_WR_EN => w_hysteresis_wr_en
        );

    hysteresis_fifo_inst : fifo
        generic map (
            FIFO_DATA_WIDTH     => 8,
            FIFO_BUFFER_SIZE    => g_FIFO_BUFFER_SIZE
        )
        port map (
            reset   => i_RST,
            wr_clk  => i_CLK,
            wr_en   => w_hysteresis_wr_en,
            din     => w_hysteresis_din,
            full    => w_hysteresis_full,
            rd_clk  => i_CLK,
            rd_en   => w_hysteresis_rd_en,
            dout    => w_hysteresis_dout,
            empty   => w_hysteresis_empty
        );

    -- o_PIXEL <= w_hysteresis_dout;
    -- o_EMPTY <= w_hysteresis_empty;
    -- w_hysteresis_rd_en <= i_RD_EN;

    roi_inst : roi
        generic map (
            g_HEIGHT => g_HEIGHT,
            g_WIDTH  => g_WIDTH,
            g_ROI    => g_ROI
        )
        port map (
            i_CLK => i_CLK,
            i_RST => i_RST,
            -- Input FIFO signals
            i_PIXEL => w_hysteresis_dout,
            i_EMPTY => w_hysteresis_empty,
            o_RD_EN => w_hysteresis_rd_en,
            -- Output FIFO signals
            o_PIXEL => w_roi_din,
            i_FULL  => w_roi_full,
            o_WR_EN => w_roi_wr_en
        );

    roi_fifo_inst : fifo
        generic map (
            FIFO_DATA_WIDTH     => 8,
            FIFO_BUFFER_SIZE    => g_FIFO_BUFFER_SIZE
        )
        port map (
            -- reset   => i_RST,
            -- wr_clk  => i_CLK,
            -- wr_en   => i_WR_EN,
            -- din     => i_PIXEL(7 downto 0),
            -- full    => o_FULL,
            reset   => i_RST,
            wr_clk  => i_CLK,
            wr_en   => w_roi_wr_en,
            din     => w_roi_din,
            full    => w_roi_full,
            rd_clk  => i_CLK,
            rd_en   => w_roi_rd_en,
            dout    => w_roi_dout,
            empty   => w_roi_empty
        );

    -- o_PIXEL <= w_roi_dout;
    -- o_EMPTY <= w_roi_empty;
    -- w_roi_rd_en <= i_RD_EN;

    hough_inst : hough
        generic map (
            g_HEIGHT => g_HEIGHT,
            g_WIDTH  => g_WIDTH,
            g_RHO_RES_LOG => g_RHO_RES_LOG,
            g_RHOS => g_RHOS,
            g_THETAS => g_THETAS,
            g_TOP_N => g_TOP_N,
            g_BRAM_ADDR_WIDTH => g_BRAM_ADDR_WIDTH,
            g_BRAM_DATA_WIDTH => g_BRAM_DATA_WIDTH,
            g_BOT_BITS => g_BOT_BITS,
            g_TOP_BITS => g_TOP_BITS
        )
        port map (
            i_CLK => i_CLK,
            i_RST => i_RST,
            i_EMPTY => w_roi_empty,
            o_RD_EN => w_roi_rd_en,
            i_PIXEL => w_roi_dout,
            o_LEFT_RHO      => w_hough_left_rho_din,
            o_LEFT_THETA    => w_hough_left_theta_din,
            o_RIGHT_RHO     => w_hough_right_rho_din,
            o_RIGHT_THETA   => w_hough_right_theta_din,
            i_FULL          => w_hough_full,
            o_WR_EN         => w_hough_wr_en
        );

    w_hough_full <= w_hough_left_rho_full or w_hough_left_theta_full or w_hough_right_rho_full or w_hough_right_theta_full;
    w_hough_left_rho_wr_en <= w_hough_wr_en;
    w_hough_left_theta_wr_en <= w_hough_wr_en;
    w_hough_right_rho_wr_en <= w_hough_wr_en;
    w_hough_right_theta_wr_en <= w_hough_wr_en;

    w_hough_left_rho_rd_en <= w_hough_rd_en;
    w_hough_left_theta_rd_en <= w_hough_rd_en;
    w_hough_right_rho_rd_en <= w_hough_rd_en;
    w_hough_right_theta_rd_en <= w_hough_rd_en;

    w_hough_empty <= w_hough_left_rho_empty or w_hough_left_theta_empty or w_hough_right_rho_empty or w_hough_right_theta_empty;

    hough_left_rho_fifo_inst : fifo
        generic map (
            FIFO_DATA_WIDTH     => g_BRAM_ADDR_WIDTH,
            FIFO_BUFFER_SIZE    => g_FIFO_BUFFER_SIZE
        )
        port map (
            reset   => i_RST,
            wr_clk  => i_CLK,
            wr_en   => w_hough_left_rho_wr_en,
            din     => w_hough_left_rho_din,
            full    => w_hough_left_rho_full,
            rd_clk  => i_CLK,
            rd_en   => w_hough_left_rho_rd_en,
            dout    => w_hough_left_rho_dout,
            empty   => w_hough_left_rho_empty
        );

    hough_left_theta_fifo_inst : fifo
        generic map (
            FIFO_DATA_WIDTH     => g_BRAM_ADDR_WIDTH,
            FIFO_BUFFER_SIZE    => g_FIFO_BUFFER_SIZE
        )
        port map (
            reset   => i_RST,
            wr_clk  => i_CLK,
            wr_en   => w_hough_left_theta_wr_en,
            din     => w_hough_left_theta_din,
            full    => w_hough_left_theta_full,
            rd_clk  => i_CLK,
            rd_en   => w_hough_left_theta_rd_en,
            dout    => w_hough_left_theta_dout,
            empty   => w_hough_left_theta_empty
        );

    hough_right_rho_fifo_inst : fifo
        generic map (
            FIFO_DATA_WIDTH     => g_BRAM_ADDR_WIDTH,
            FIFO_BUFFER_SIZE    => g_FIFO_BUFFER_SIZE
        )
        port map (
            reset   => i_RST,
            wr_clk  => i_CLK,
            wr_en   => w_hough_right_rho_wr_en,
            din     => w_hough_right_rho_din,
            full    => w_hough_right_rho_full,
            rd_clk  => i_CLK,
            rd_en   => w_hough_right_rho_rd_en,
            dout    => w_hough_right_rho_dout,
            empty   => w_hough_right_rho_empty
        );

    hough_right_theta_fifo_inst : fifo
        generic map (
            FIFO_DATA_WIDTH     => g_BRAM_ADDR_WIDTH,
            FIFO_BUFFER_SIZE    => g_FIFO_BUFFER_SIZE
        )
        port map (
            reset   => i_RST,
            wr_clk  => i_CLK,
            wr_en   => w_hough_right_theta_wr_en,
            din     => w_hough_right_theta_din,
            full    => w_hough_right_theta_full,
            rd_clk  => i_CLK,
            rd_en   => w_hough_right_theta_rd_en,
            dout    => w_hough_right_theta_dout,
            empty   => w_hough_right_theta_empty
        );

    -- o_EMPTY <= w_hough_empty;
    -- w_hough_rd_en <= i_RD_EN;
    -- o_LEFT_RHO    <= w_hough_left_rho_dout; 
    -- o_LEFT_THETA  <= w_hough_left_theta_dout;
    -- o_RIGHT_RHO   <= w_hough_right_rho_dout;
    -- o_RIGHT_THETA <= w_hough_right_theta_dout;

    center_lane_inst : center_lane
        generic map(
            g_HEIGHT => g_HEIGHT,
            g_WIDTH  => g_WIDTH,
            g_RHO_RES_LOG => g_RHO_RES_LOG,
            g_RHOS => g_RHOS,
            g_THETAS => g_THETAS,
            g_BRAM_ADDR_WIDTH => g_BRAM_ADDR_WIDTH,
            g_TOP_BITS => g_TOP_BITS,
            g_BOT_BITS => g_BOT_BITS,
            g_OFFSET => g_OFFSET,
            g_ANGLE => g_ANGLE
        )
        port map (
            i_CLK => i_CLK,
            i_RST => i_RST,
            i_EMPTY => w_hough_empty,
            o_RD_EN => w_hough_rd_en,
            i_LEFT_RHO => w_hough_left_rho_dout, 
            i_LEFT_THETA => w_hough_left_theta_dout,
            i_RIGHT_RHO => w_hough_right_rho_dout,
            i_RIGHT_THETA => w_hough_right_theta_dout,
            o_STEERING => w_center_lane_din,
            i_FULL => w_center_lane_full,
            o_WR_EN => w_center_lane_wr_en
        );
    
    center_lane_fifo_inst : fifo
        generic map (
            FIFO_DATA_WIDTH     => g_BOT_BITS,
            FIFO_BUFFER_SIZE    => g_FIFO_BUFFER_SIZE
        )
        port map (
            reset   => i_RST,
            wr_clk  => i_CLK,
            wr_en   => w_center_lane_wr_en,
            din     => w_center_lane_din,
            full    => w_center_lane_full,
            rd_clk  => i_CLK,
            rd_en   => w_center_lane_rd_en,
            dout    => w_center_lane_dout,
            empty   => w_center_lane_empty
        );

    -- NEW: Simple motor control instantiation (SystemVerilog module)
    motor_control_inst : motor_control
        generic map (
            STEERING_WIDTH => g_BOT_BITS,
            PWM_RESOLUTION => 8,
            STEERING_THRESHOLD => g_STEERING_THRESHOLD
        )
        port map (
            clk => i_CLK,
            reset_n => w_reset_n,
            i_steering => w_center_lane_dout,
            i_valid => w_motor_control_valid,
            o_ready => w_motor_control_ready,
            o_left_motor_pwm => o_LEFT_MOTOR_PWM,
            o_right_motor_pwm => o_RIGHT_MOTOR_PWM
        );

    -- Control logic for simple motor control interface
    -- Generate valid signal when data is available and motor control is ready
    w_motor_control_valid <= (not w_center_lane_empty) and w_motor_control_ready;
    w_center_lane_rd_en <= w_motor_control_valid;  -- Read when we send valid data
	
--	o_LEFT_MOTOR_PWM <= '1';
--	o_RIGHT_MOTOR_PWM <= '1';

    --o_EMPTY <= w_center_lane_empty;
	
	

end architecture rtl;