library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity center_lane_top is

    generic (
        g_FIFO_BUFFER_SIZE  : integer := 64;
        g_WIDTH             : integer := 200;
        g_HEIGHT            : integer := 160;

        -- Hysteresis 
        g_HYSTERESIS_HIGH_THRESHOLD : integer := 150;
        g_HYSTERESIS_LOW_THRESHOLD  : integer := 100;
        g_ROI                       : integer := 270;

        -- Generics for Hough Transform
        g_RHO_RES_LOG   : integer := 2;     -- Clog2(Rho Resolution = 2)
        g_RHOS          : integer := 50;   -- Sqrt(ROWS ^ 2 + COLS ^ 2) / Rho Resolution
        g_THETAS        : integer := 180;   -- Can decrease this (e.g. to 64)
        g_TOP_N         : integer := 16;    -- Number of top voted Rhos and Theta values to consider
        g_BRAM_ADDR_WIDTH : integer := 10;  -- Clog2(g_RHOS * g_THETAS), size of BRAM to hold votes
        g_BRAM_DATA_WIDTH : integer := 10;  -- Clog2(g_HEIGHT * g_WIDTH), maximum count of votes for each Rho
        -- Quantization
        g_BOT_BITS : integer := 10;
        g_TOP_BITS : integer := 10;
        -- Steering
        g_OFFSET : integer := 51; 
        g_ANGLE : integer := 307
    );

    port (
        i_CLK       : in    std_logic;
        i_RST       : in    std_logic;

        -- Input data
        o_FULL      : out   std_logic;
        i_WR_EN     : in    std_logic;
        i_LEFT_RHO      : in std_logic_vector(g_BRAM_ADDR_WIDTH - 1 downto 0);
        i_LEFT_THETA    : in std_logic_vector(g_BRAM_ADDR_WIDTH - 1 downto 0);
        i_RIGHT_RHO     : in std_logic_vector(g_BRAM_ADDR_WIDTH - 1 downto 0);
        i_RIGHT_THETA   : in std_logic_vector(g_BRAM_ADDR_WIDTH - 1 downto 0);

        -- Output pixel data
        o_EMPTY     : out   std_logic;
        i_RD_EN     : in    std_logic;
        -- o_PIXEL     : out   std_logic_vector(7 downto 0)

        -- Output steering data        
        o_STEERING      : out std_logic_vector(g_BOT_BITS - 1 downto 0)
    );

end entity center_lane_top;

architecture rtl of center_lane_top is

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
            g_TOP_BITS : integer := 10;
            g_BOT_BITS : integer := 10;
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

begin

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

    o_FULL <= w_hough_full;
    w_hough_wr_en <= i_WR_EN;

    w_hough_left_rho_din <= i_LEFT_RHO;
    w_hough_left_theta_din <= i_LEFT_THETA;
    w_hough_right_rho_din <= i_RIGHT_RHO;
    w_hough_right_theta_din <= i_RIGHT_THETA;


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

    o_EMPTY <= w_center_lane_empty;
    w_center_lane_rd_en <= i_RD_EN;
    o_STEERING <= w_center_lane_dout; 

end architecture rtl;