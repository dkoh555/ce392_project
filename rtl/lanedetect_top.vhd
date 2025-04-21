library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity lanedetect_top is

    generic (
        g_FIFO_BUFFER_SIZE  : integer := 64;
        g_WIDTH             : integer := 720;
        g_HEIGHT            : integer := 540
    );

    port (
        i_CLK       : in    std_logic;
        i_RST       : in    std_logic;

        -- Input data
        i_PIXEL     : in    std_logic_vector(23 downto 0);
        o_FULL      : out   std_logic;
        i_WR_EN     : in    std_logic;

        -- Output data
        o_PIXEL     : out   std_logic_vector(7 downto 0);
        o_EMPTY     : out   std_logic;
        i_RD_EN     : in    std_logic
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

begin

    input_fifo_inst : fifo
        generic map (
            FIFO_DATA_WIDTH     => 24,
            FIFO_BUFFER_SIZE    => g_FIFO_BUFFER_SIZE
        )
        port map (
            reset   => i_RST,
            wr_clk  => i_CLK,
            wr_en   => i_WR_EN,
            din     => i_PIXEL,
            full    => o_FULL,
            rd_clk  => i_CLK,
            rd_en   => w_input_rd_en,
            dout    => w_input_data,
            empty   => w_input_empty
        );

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


    o_PIXEL <= w_non_max_suppression_dout;
    o_EMPTY <= w_non_max_suppression_empty;
    w_non_max_suppression_rd_en <= i_RD_EN;
   

end architecture rtl;