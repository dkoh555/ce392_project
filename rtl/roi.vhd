library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Verified to be functionally correct
-- 100+ MHz

entity roi is

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


end entity roi;

architecture rtl of roi is

    -- States
    type t_state is (s_READ, s_WRITE);
    signal q_state, n_state : t_state;

    -- Row and column count
    signal q_col, n_col : unsigned(9 downto 0);
    signal q_row, n_row : unsigned(9 downto 0);

    -- Roi pixel signals
    signal q_roi_pixel, n_roi_pixel : std_logic_vector(7 downto 0);

begin

    state_seq : process (i_CLK, i_RST) begin

        if (i_RST = '1') then
            q_state <= s_READ;
            q_roi_pixel <= (others => '0');
            q_col <= (others => '0');
            q_row <= (others => '0');
        elsif (rising_edge(i_CLK)) then
            q_state <= n_state;
            q_roi_pixel <= n_roi_pixel;
            q_col <= n_col;
            q_row <= n_row;
        end if;

    end process state_seq;

    state_comb : process (q_state, i_PIXEL, q_roi_pixel, i_EMPTY, i_FULL, q_col, q_row) begin

        n_col <= q_col;
        n_row <= q_row;

        n_roi_pixel <= q_roi_pixel;
        n_state <= q_state;
        o_RD_EN <= '0';
        o_WR_EN <= '0';
        
        case (q_state) is
        
            when s_READ =>
                if (i_EMPTY = '0') then
                    -- If within region of interest
                    if (q_row <= to_unsigned(g_ROI, q_row'length)) then
                        n_roi_pixel <= i_PIXEL;
                    -- If outside of region of interest
                    else
                        n_roi_pixel <= (others => '0');
                    end if;
                    n_state <= s_WRITE;
                    o_RD_EN <= '1';
                    -- If end of line has been reached
                    if (q_col = to_unsigned(g_WIDTH - 1, q_col'length)) then
                        -- If end of image has been reached
                        if (q_row = to_unsigned(g_HEIGHT - 1, q_row'length)) then
                            -- Reset row count
                            n_row <= (others => '0');
                        -- If end of image has not been reached
                        else
                            -- Increment row count
                            n_row <= q_row + to_unsigned(1, n_row'length);
                        end if;
                        -- Reset column count
                        n_col <= (others => '0');
                    -- If end of line has not been reached
                    else
                        -- Increment column count
                        n_col <= q_col + to_unsigned(1, n_col'length);
                    end if;
                end if;

            when s_WRITE =>
                if (i_FULL = '0') then
                    n_state <= s_READ;
                    o_WR_EN <= '1';
                end if;

        end case;

    end process state_comb;

    -- Shift right roi pixel by 8
    o_PIXEL <= q_roi_pixel;


end architecture rtl;