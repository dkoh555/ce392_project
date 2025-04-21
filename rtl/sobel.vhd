library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.lanedetect_pkg.all;

entity sobel is

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

end entity sobel;

architecture rtl of sobel is

    -- 3 Line pixel buffer
    type t_pixel_line is array (0 to g_WIDTH - 1) of std_logic_vector(7 downto 0);
    type t_pixel_lines is array (0 to 2) of t_pixel_line;    
    signal q_lines, n_lines : t_pixel_lines;

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

    -- Multiply accumulate signals
    signal q_calc_count, n_calc_count : unsigned(4 downto 0);
    type t_sum is array (0 to 5) of signed(15 downto 0);
    signal q_h_sum, n_h_sum : t_sum;
    signal q_v_sum, n_v_sum : t_sum;
    signal q_pixel, n_pixel : std_logic_vector(7 downto 0);
    signal w_h_grad, w_v_grad : signed(15 downto 0);
    

    signal w_test : signed(15 downto 0);

begin

    state_seq : process (i_CLK, i_RST) begin

        if (i_RST = '1') then
            -- Pixel buffer and sliding window
            q_lines <= (others => (others => (others => '0')));
            q_window <= (others => (others => (others => '0')));
            -- States
            q_state <= s_READ;
            -- Pixel arithmetic
            q_col   <= (others => '0');
            q_row   <= (others => '0');
            q_calc_count <= (others => '0');
            q_h_sum   <= (others => (others => '0'));
            q_v_sum   <= (others => (others => '0'));
            q_pixel   <= (others => '0');
        elsif (rising_edge(i_CLK)) then
            -- Pixel buffer and sliding window
            q_lines <= n_lines;
            q_window <= n_window;
            -- States
            q_state <= n_state;
            -- Pixel arithmetic
            q_col   <= n_col;
            q_row   <= n_row;
            q_calc_count <= n_calc_count;
            q_h_sum   <= n_h_sum;
            q_v_sum   <= n_v_sum;
            q_pixel <= n_pixel;
        end if;

    end process state_seq;

    state_comb : process (q_lines, q_state, q_col, q_row, q_window, q_calc_count, q_h_sum, q_v_sum, i_PIXEL, i_EMPTY, n_lines, w_v_grad, w_h_grad, q_pixel, i_FULL) begin

        -- Default signal assignment
        n_lines <= q_lines;
        n_window <= q_window;
        n_state <= q_state;
        n_col   <= q_col;
        n_row   <= q_row;
        n_calc_count <= (others => '0');
        n_h_sum <= q_h_sum;
        n_v_sum <= q_v_sum;
        o_RD_EN <= '0';
        o_WR_EN <= '0';
        n_pixel <= q_pixel;        
        
        -- w_test <= to_signed(SOBEL_H_KERNEL(2, 2), 8) * signed(q_window(2)(2));
        w_test <= (w_v_grad + w_h_grad);
        
        o_PIXEL <= std_logic_vector(q_pixel);
        

        case (q_state) is

            when s_READ =>
                -- If FIFO not empty or if remaining pixels need to be buffered out
                if (i_EMPTY = '0' or (q_col > to_unsigned(g_WIDTH - 1, q_col'length) or q_row > to_unsigned(g_HEIGHT - 1, q_col'length))) then
                    -- Implicit BRAM definition, store pixel in column location
                    if (q_col < to_unsigned(g_WIDTH, q_col'length)) then
                        n_lines(0)(to_integer(q_col)) <= i_PIXEL;
                        o_RD_EN <= '1';
                    end if;

                    -- If end of line has been reached, shift rows (line counter end is extended by 2 to account for edge pixels)
                    if (q_col = to_unsigned(g_WIDTH, 10)) then
                        for i in 0 to 1 loop
                            n_lines(i + 1) <= q_lines(i);
                        end loop;
                    end if;

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
                        n_window(r)(0) <= n_lines(r)(to_integer(q_col));
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
                        -- For calculations, we need to perform 25 multiplies and then add them together.
                        -- To perform this efficiently, in cycle 0 all of the multiplies are performed and 2 are added together.
                        -- Next, more adds are performed in a tree-like structure.
                        for r in 0 to 2 loop
                            for c in 0 to 1 loop
                                if (c = 1) then
                                    n_h_sum(r * 2 + c) <= to_signed(SOBEL_H_KERNEL(r, 2 * c), 7) * signed(resize(unsigned('0' & q_window(r)(2 * c)), 9));
                                    n_v_sum(r * 2 + c) <= to_signed(SOBEL_V_KERNEL(r, 2 * c), 7) * signed(resize(unsigned('0' & q_window(r)(2 * c)), 9));
                                else
                                    n_h_sum(r * 2 + c) <= to_signed(SOBEL_H_KERNEL(r, 2 * c), 7) * signed(resize(unsigned('0' & q_window(r)(2 * c)), 9)) + to_signed(SOBEL_H_KERNEL(r, 2 * c + 1), 7) * signed(resize(unsigned('0' & q_window(r)(2 * c + 1)), 9));
                                    n_v_sum(r * 2 + c) <= to_signed(SOBEL_V_KERNEL(r, 2 * c), 7) * signed(resize(unsigned('0' & q_window(r)(2 * c)), 9)) + to_signed(SOBEL_V_KERNEL(r, 2 * c + 1), 7) * signed(resize(unsigned('0' & q_window(r)(2 * c + 1)), 9));
                                end if;
                            end loop;
                        end loop;
                    end if;
                elsif (q_calc_count = to_unsigned(1, q_calc_count'length)) then
                    for r in 0 to 2 loop
                        n_h_sum(r) <= q_h_sum(r * 2) + q_h_sum(r * 2 + 1);
                        n_v_sum(r) <= q_v_sum(r * 2) + q_v_sum(r * 2 + 1);
                    end loop;
                elsif (q_calc_count = to_unsigned(2, q_calc_count'length)) then
                    n_h_sum(0) <= q_h_sum(0) + q_h_sum(1) + q_h_sum(2);
                    n_v_sum(0) <= q_v_sum(0) + q_v_sum(1) + q_v_sum(2);
                elsif (q_calc_count = to_unsigned(3, q_calc_count'length)) then
                    -- Absolute value of horizontal gradient
                    if (q_h_sum(0) >= to_signed(0, q_h_sum'length)) then
                        w_h_grad <= q_h_sum(0);
                    else
                        w_h_grad <= resize(-1 * q_h_sum(0), w_h_grad'length);
                    end if;
                    -- Absolute value of vertical gradient
                    if (q_v_sum(0) >= to_signed(0, q_v_sum'length)) then
                        w_v_grad <= q_v_sum(0);
                    else
                        w_v_grad <= resize(-1 * q_v_sum(0), w_v_grad'length);
                    end if;
                    -- Saturate pixel value if greater than 255
                    if (w_v_grad + w_h_grad > to_signed(255, w_v_grad'length)) then
                        n_pixel <= std_logic_vector(to_signed(255, n_pixel'length));
                    else
                        n_pixel <= std_logic_vector(to_unsigned(to_integer(w_v_grad + w_h_grad), 8));
                    end if;
                else
                    -- Cycle 1: 3 relevant additions (0: q_sum(0) + q_sum(1), 1: q_sum(2) + q_sum(3), 2: q_sum(4) + q_sum(5))
                    -- Cycle 2: 3 relevant additions (0: q_sum(0) + q_sum(1) + q_sum(2))
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