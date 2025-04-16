library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Verified to be functionally correct
-- 100+ MHz

entity grayscale is

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


end entity grayscale;

architecture rtl of grayscale is

    -- States
    type t_state is (s_READ, s_WRITE);
    signal q_state, n_state : t_state;

    -- Grayscale pixel signals
    signal q_grayscale_pixel, n_grayscale_pixel : std_logic_vector(15 downto 0);

    -- Wires for pixel colors
    signal w_pixel_red, w_pixel_green, w_pixel_blue : unsigned(7 downto 0);

begin

    state_seq : process (i_CLK, i_RST) begin

        if (i_RST = '1') then
            q_state <= s_READ;
            q_grayscale_pixel <= (others => '0');
        elsif (rising_edge(i_CLK)) then
            q_state <= n_state;
            q_grayscale_pixel <= n_grayscale_pixel;
        end if;

    end process state_seq;

    state_comb : process (q_state, i_PIXEL, w_pixel_red, w_pixel_green, w_pixel_blue, i_EMPTY, i_FULL) begin

        -- Get color values
        w_pixel_blue <= unsigned(i_PIXEL(23 downto 16));
        w_pixel_green <= unsigned(i_PIXEL(15 downto 8));
        w_pixel_red <= unsigned(i_PIXEL(7 downto 0));

        -- Always set grayscale pixel to reduce combinational logic
        n_grayscale_pixel <= std_logic_vector(w_pixel_red * to_unsigned(76, 8) + w_pixel_green * to_unsigned(150, 8) + w_pixel_blue * to_unsigned(30, 8));
        n_state <= q_state;
        o_RD_EN <= '0';
        o_WR_EN <= '0';
        
        case (q_state) is
        
            when s_READ =>
                if (i_EMPTY = '0') then
                    n_state <= s_WRITE;
                    o_RD_EN <= '1';
                end if;

            when s_WRITE =>
                if (i_FULL = '0') then
                    n_state <= s_READ;
                    o_WR_EN <= '1';
                end if;

        end case;

    end process state_comb;

    -- Shift right grayscale pixel by 8
    o_PIXEL <= q_grayscale_pixel(15 downto 8);


end architecture rtl;