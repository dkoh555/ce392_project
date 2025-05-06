library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.lanedetect_pkg.all;

-- Verified to be functionally correct
-- 100+ MHz

entity gaussian_blur is

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

end entity gaussian_blur;

architecture rtl of gaussian_blur is

    -- 5 Line pixel buffer
    type t_pixel_line is array (0 to g_WIDTH - 1) of std_logic_vector(7 downto 0); -- Longer than actually needed to save on logic
    type t_pixel_lines is array (0 to 4) of t_pixel_line;    
    signal q_lines, n_lines : t_pixel_lines;

    -- Current line
    signal q_line_idx, n_line_idx : unsigned(2 downto 0);
    type t_pixel_shift is array (0 to 4) of std_logic_vector(7 downto 0);
    signal q_shift_pixels, n_shift_pixels : t_pixel_shift;

    -- 5x5 Sliding pixel window
    type t_pixel_window_line is array (0 to 4) of std_logic_vector(7 downto 0);
    type t_pixel_window is array (0 to 4) of t_pixel_window_line;
    signal q_window, n_window : t_pixel_window;

    -- State signals
    type t_state is (s_READ, s_FETCH, s_CALC, s_WRITE);
    signal q_state, n_state : t_state;

    -- Hard coded width for row and column count
    signal q_col, n_col : unsigned(9 downto 0);
    signal q_row, n_row : unsigned(9 downto 0);

    -- Multiply accumulate signals
    signal q_calc_count, n_calc_count : unsigned(4 downto 0);
    type t_sum is array (0 to 15) of unsigned(15 downto 0);
    signal q_sum, n_sum : t_sum;

    signal w_tmp : std_logic_vector(15 downto 0);

begin

    state_seq : process (i_CLK, i_RST) begin

        if (i_RST = '1') then
            -- Pixel buffer and sliding window
            q_lines <= (others => (others => (others => '0')));
            q_window <= (others => (others => (others => '0')));
            q_line_idx <= (others => '0');
            q_shift_pixels <= (others => (others => '0'));
            -- States
            q_state <= s_READ;
            -- Pixel arithmetic
            q_col   <= (others => '0');
            q_row   <= (others => '0');
            q_calc_count <= (others => '0');
            q_sum   <= (others => (others => '0'));
        elsif (rising_edge(i_CLK)) then
            -- Pixel buffer and sliding window
            q_lines <= n_lines;
            q_window <= n_window;
            q_line_idx <= n_line_idx;
            q_shift_pixels <= n_shift_pixels;
            -- States
            q_state <= n_state;
            -- Pixel arithmetic
            q_col   <= n_col;
            q_row   <= n_row;
            q_calc_count <= n_calc_count;
            q_sum   <= n_sum;
        end if;

    end process state_seq;

    state_comb : process (q_lines, q_state, q_col, q_row, q_window, q_calc_count, q_sum, i_PIXEL, i_EMPTY, n_lines, w_tmp, i_FULL, q_line_idx, q_shift_pixels) begin

        -- Default signal assignment
        n_lines <= q_lines;
        n_window <= q_window;
        n_line_idx <= q_line_idx;
        n_shift_pixels <= q_shift_pixels;
        n_state <= q_state;
        n_col   <= q_col;
        n_row   <= q_row;
        n_calc_count <= (others => '0');
        n_sum <= q_sum;
        o_RD_EN <= '0';
        o_WR_EN <= '0';
        o_PIXEL <= std_logic_vector(q_sum(0)(15 downto 8));

        -- Defined here because of Questasim type casting failure for VHDL
        w_tmp <= q_window(2)(2) & std_logic_vector(to_unsigned(0, 8));

        case (q_state) is

            when s_READ =>
                -- If enough pixels have been buffered in towards the end of the image, stop reading
                if (q_col > to_unsigned(g_WIDTH - 1, q_col'length) or q_row > to_unsigned(g_HEIGHT - 1, q_col'length)) then
                    -- If end of line has been reached, increment current line index.
                    if (q_col = to_unsigned(g_WIDTH + 1, 10)) then
                        if (q_line_idx = to_unsigned(4, q_line_idx'length)) then
                            n_line_idx <= (others => '0');
                        else
                            n_line_idx <= q_line_idx + to_unsigned(1, q_line_idx'length);
                        end if;
                    end if;                    
                    -- Go to fetch state
                    n_state <= s_FETCH;

                -- If FIFO not empty or if remaining pixels need to be buffered out
                elsif (i_EMPTY = '0') then
                    -- Implicit BRAM definition, store pixel in column location
                    if (q_col < to_unsigned(g_WIDTH, q_col'length)) then
                        n_lines(to_integer(q_line_idx))(to_integer(q_col)) <= i_PIXEL;
                        o_RD_EN <= '1';
                    end if;
                    -- Go to fetch state
                    n_state <= s_FETCH;

                end if;
            
            when s_FETCH =>
                    
                    -- For each row of the sliding window
                    for r in 0 to 4 loop
                        -- Shift current pixels
                        n_window(r)(1 to 4) <= q_window(r)(0 to 3);
                        if (q_col > to_unsigned(g_WIDTH - 1, q_col'length)) then
                            n_window(r)(0) <= (others => '0');
                        else
                            if (q_line_idx < to_unsigned(r, q_line_idx'length)) then
                                n_window(r)(0) <= q_lines(5 + to_integer(q_line_idx) - r)(to_integer(q_col));
                            else
                                n_window(r)(0) <= q_lines(to_integer(q_line_idx) - r)(to_integer(q_col));
                            end if;
                        end if;
                    end loop;
                    
                    -- If enough pixels have been buffered in, start pushing them out
                    if (q_row > to_unsigned(1, q_row'length) and q_col > to_unsigned(1, q_col'length)) then
                        n_state <= s_CALC;
                    -- If not enough pixels have been buffered in, increment counters and continue reading
                    else
                        -- If end of row reached, reset column count and increment row counter
                        if (q_col = to_unsigned(g_WIDTH + 1, 10)) then
                            n_row <= q_row + to_unsigned(1, 10);
                            n_col <= to_unsigned(0, 10);
                        -- Otherwise, just increment column count
                        else
                            n_col <= q_col + to_unsigned(1, 10);
                        end if;

                        n_state <= s_READ;
                    end if;

            when s_CALC =>

                -- If on the first cycle of calculations
                if (q_calc_count = to_unsigned(0, 5)) then
                    -- If not enough pixels have been buffered in for the entire Gaussian, simply copy them
                    if (q_col < to_unsigned(4, q_col'length) or q_col > to_unsigned(g_WIDTH - 1, q_col'length) or 
                        q_row < to_unsigned(4, q_col'length) or q_row > to_unsigned(g_HEIGHT - 1, q_col'length)) then
                        n_sum(0) <= unsigned(w_tmp);
                        n_state <= s_WRITE;
                    else
                        -- For calculations, we need to perform 25 multiplies and then add them together.
                        -- To perform this efficiently, in cycle 0 all of the multiplies are performed and 2 are added together.
                        -- Next, more adds are performed in a tree-like structure.
                        for r in 0 to 4 loop
                            for c in 0 to 2 loop
                                if (c = 2) then
                                    n_sum(r * 3 + c) <= to_unsigned(GAUSSIAN_KERNEL(r, 2 * c), 8) * unsigned(q_window(r)(2 * c));
                                else
                                    n_sum(r * 3 + c) <= to_unsigned(GAUSSIAN_KERNEL(r, 2 * c), 8) * unsigned(q_window(r)(2 * c)) + to_unsigned(GAUSSIAN_KERNEL(r, 2 * c + 1), 8) * unsigned(q_window(r)(2 * c + 1));
                                end if;
                            end loop;
                        end loop;
                        n_sum(15) <= (others => '0');
                    end if;
                else
                    -- Cycle 1: 8 relevant additions (0: q_sum(0) + q_sum(1), 1: q_sum(2) + q_sum(3)... 7: q_sum(14) + q_sum(15))
                    -- Cycle 2: 4 relevant additions (0: q_sum(0) + q_sum(1), 1: q_sum(2) + q_sum(3)... 3: q_sum(6) + q_sum(7))
                    -- Cycle 3: 2 relevant additions (0: q_sum(0) + q_sum(1), 1: q_sum(2) + q_sum(3))
                    -- Cycle 4: 1 relevant addition
                    for r in 0 to 7 loop
                        n_sum(r) <= q_sum(r * 2) + q_sum(r * 2 + 1);
                    end loop;
                    -- Once all calculations are complete
                    if (q_calc_count = to_unsigned(4, 5)) then
                        n_state <= s_WRITE;
                    end if;
                end if;
                n_calc_count <= q_calc_count + to_unsigned(1, 5);
        
            when s_WRITE =>

                if (i_FULL = '0') then
                    n_state <= s_READ;
                    o_WR_EN <= '1';

                    -- If end of image reached, reset column and row count
                    if (q_row = to_unsigned(g_HEIGHT + 1, q_row'length) and q_col = to_unsigned(g_WIDTH + 1, q_col'length)) then
                        n_row <= (others => '0');
                        n_col <= (others => '0');
                    -- If end of row reached, reset column count and increment row counter
                    elsif (q_col = to_unsigned(g_WIDTH + 1, 10)) then
                        n_row <= q_row + to_unsigned(1, 10);
                        n_col <= to_unsigned(0, 10);
                    -- Otherwise, just increment column count
                    else
                        n_col <= q_col + to_unsigned(1, 10);
                    end if;
                end if;

        end case;

    end process state_comb;

end architecture rtl;