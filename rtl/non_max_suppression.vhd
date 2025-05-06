library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.lanedetect_pkg.all;

entity non_max_suppression is

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

end entity non_max_suppression;

architecture rtl of non_max_suppression is

    -- 3 Line pixel buffer
    type t_pixel_line is array (0 to g_WIDTH - 1) of std_logic_vector(7 downto 0);
    type t_pixel_lines is array (0 to 2) of t_pixel_line;    
    signal q_lines, n_lines : t_pixel_lines;

    -- Current line
    signal q_line_idx, n_line_idx : unsigned(2 downto 0);
    
    -- 3x3 Sliding pixel window
    type t_pixel_window_line is array (0 to 2) of std_logic_vector(7 downto 0);
    type t_pixel_window is array (0 to 2) of t_pixel_window_line;
    signal q_window, n_window : t_pixel_window;

    -- State signals
    type t_state is (s_READ, s_FETCH, s_CALC, s_WRITE, s_SKIP);
    signal q_state, n_state : t_state;

    -- Hard coded width for row and column count
    signal q_col, n_col : unsigned(9 downto 0);
    signal q_row, n_row : unsigned(9 downto 0);

    -- Directional signals
    signal q_calc_count, n_calc_count : unsigned(4 downto 0);
    type t_dir is array (0 to 3) of unsigned(8 downto 0);
    signal w_center : unsigned(7 downto 0);
    signal q_dir, n_dir : t_dir;

    signal q_pixel, n_pixel : std_logic_vector(7 downto 0);  

    signal w_test : signed(15 downto 0);

begin

    state_seq : process (i_CLK, i_RST) begin

        if (i_RST = '1') then
            -- Pixel buffer and sliding window
            q_lines <= (others => (others => (others => '0')));
            q_window <= (others => (others => (others => '0')));
            q_line_idx <= (others => '0');
            -- States
            q_state <= s_READ;
            -- Pixel arithmetic
            q_col   <= (others => '0');
            q_row   <= (others => '0');
            q_calc_count <= (others => '0');
            q_dir   <= (others => (others => '0'));
            q_pixel   <= (others => '0');
        elsif (rising_edge(i_CLK)) then
            -- Pixel buffer and sliding window
            q_lines <= n_lines;
            q_window <= n_window;
            q_line_idx <= n_line_idx;
            -- States
            q_state <= n_state;
            -- Pixel arithmetic
            q_col   <= n_col;
            q_row   <= n_row;
            q_calc_count <= n_calc_count;
            q_dir   <= n_dir;
            q_pixel <= n_pixel;
        end if;

    end process state_seq;

    state_comb : process (q_lines, q_state, q_col, q_row, q_window, q_calc_count, q_dir, i_PIXEL, i_EMPTY, n_lines, q_pixel, i_FULL, q_line_idx) begin

        -- Default signal assignment
        n_lines <= q_lines;
        n_window <= q_window;
        n_line_idx <= q_line_idx;
        n_state <= q_state;
        n_col   <= q_col;
        n_row   <= q_row;
        n_calc_count <= (others => '0');
        n_dir <= q_dir;
        o_RD_EN <= '0';
        o_WR_EN <= '0';
        -- Default assignment to save on combinational logic
        
        
        -- w_test <= to_signed(SOBEL_H_KERNEL(2, 2), 8) * signed(q_window(2)(2));
        w_test <= (others => '0');
        
        o_PIXEL <= std_logic_vector(q_pixel);
        

        case (q_state) is

            when s_READ =>

                -- If enough pixels have been buffered in towards the end of the image, stop reading
                if (q_col > to_unsigned(g_WIDTH - 1, q_col'length) or q_row > to_unsigned(g_HEIGHT - 1, q_col'length)) then
                    -- If end of line has been reached, increment current line index.
                    if (q_col = to_unsigned(g_WIDTH, q_col'length)) then
                        if (q_line_idx = to_unsigned(2, q_line_idx'length)) then
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
                
                -- Shift into sliding window
                for r in 0 to 2 loop
                    -- Shift current pixels
                    for c in 0 to 1 loop
                        n_window(r)(c + 1) <= q_window(r)(c);
                    end loop;
                    -- Shift in pixels if they exist
                    if (q_col > to_unsigned(g_WIDTH - 1, q_col'length)) then
                        -- Most recent pixels go in position 0
                        n_window(r)(0) <= (others => '0');
                    else
                        if (q_line_idx < to_unsigned(r, q_line_idx'length)) then
                            n_window(r)(0) <= q_lines(3 + to_integer(q_line_idx) - r)(to_integer(q_col));
                        else
                            n_window(r)(0) <= q_lines(to_integer(q_line_idx) - r)(to_integer(q_col));
                        end if;
                    end if;
                end loop;
                
                -- If enough pixels have been buffered in, start pushing them out
                if (q_row > to_unsigned(0, q_row'length) and q_col > to_unsigned(0, q_col'length)) then
                    n_state <= s_CALC;
                else
                    n_state <= s_SKIP;
                end if;

            when s_CALC =>

                -- If on the first cycle of calculations
                if (q_calc_count = to_unsigned(0, q_calc_count'length)) then
                    -- If not enough pixels have been buffered in for the entire Gaussian, simply copy them
                    if (q_col < to_unsigned(2, q_col'length) or q_col > to_unsigned(g_WIDTH - 1, q_col'length) or 
                        q_row < to_unsigned(2, q_col'length) or q_row > to_unsigned(g_HEIGHT - 1, q_col'length)) then
                        n_pixel <= (others => '0');
                        n_state <= s_WRITE;
                    else
                        -- North+South (y: 0, x: 1) (y: 2, x: 1)
                        n_dir(0) <= resize(unsigned(q_window(2)(1)), 9) + resize(unsigned(q_window(0)(1)), 9);
                        -- East+West (y: 1, x: 0) (y: 1, x: 2)
                        n_dir(1) <= resize(unsigned(q_window(1)(2)), 9) + resize(unsigned(q_window(1)(0)), 9);
                        -- North+West (y: 2, x: 2) (y: 0, x: 0)
                        n_dir(2) <= resize(unsigned(q_window(2)(2)), 9) + resize(unsigned(q_window(0)(0)), 9);
                        -- North+East (y: 2, x: 0) (y: 0, x: 2)
                        n_dir(3) <= resize(unsigned(q_window(2)(0)), 9) + resize(unsigned(q_window(0)(2)), 9);
                    end if;
                else
                -- elsif (q_calc_count = to_unsigned(1, q_calc_count'length)) then
                    n_pixel <= (others => '0');
                    if (q_dir(0) >= q_dir(1) and q_dir(0) >= q_dir(2) and q_dir(0) >= q_dir(3)) then
                        if (q_window(1)(1) > q_window(2)(1) and q_window(1)(1) >= q_window(0)(1)) then
                            n_pixel <= q_window(1)(1);
                        end if;
                    elsif (q_dir(1) >= q_dir(2) and q_dir(1) >= q_dir(3)) then
                        if (q_window(1)(1) > q_window(1)(2) and q_window(1)(1) >= q_window(1)(0)) then
                            n_pixel <= q_window(1)(1);
                        end if;
                    elsif (q_dir(2) >= q_dir(3)) then
                        if (q_window(1)(1) > q_window(2)(2) and q_window(1)(1) >= q_window(0)(0)) then
                            n_pixel <= q_window(1)(1);
                        end if;
                    else
                        if (q_window(1)(1) > q_window(2)(0) and q_window(1)(1) >= q_window(0)(2)) then
                            n_pixel <= q_window(1)(1);
                        end if;
                    end if;
                    n_state <= s_WRITE;
                end if;
                n_calc_count <= q_calc_count + to_unsigned(1, 5);
        
            when s_WRITE =>

                if (i_FULL = '0') then
                    n_state <= s_READ;
                    o_WR_EN <= '1';

                    -- If end of image reached, reset column and row count
                    if (q_row = to_unsigned(g_HEIGHT, q_row'length) and q_col = to_unsigned(g_WIDTH, q_col'length)) then
                        n_row <= (others => '0');
                        n_col <= (others => '0');
                    -- If end of row reached, reset column count and increment row counter
                    elsif (q_col = to_unsigned(g_WIDTH, 10)) then
                        n_row <= q_row + to_unsigned(1, 10);
                        n_col <= to_unsigned(0, 10);
                    -- Otherwise, just increment column count
                    else
                        n_col <= q_col + to_unsigned(1, 10);
                    end if;
                end if;

            when s_SKIP =>

                -- If end of row reached, reset column count and increment row counter
                if (q_col = to_unsigned(g_WIDTH, 10)) then
                    n_row <= q_row + to_unsigned(1, 10);
                    n_col <= to_unsigned(0, 10);
                -- Otherwise, just increment column count
                else
                    n_col <= q_col + to_unsigned(1, 10);
                end if;

                n_state <= s_READ;

        end case;

    end process state_comb;

end architecture rtl;