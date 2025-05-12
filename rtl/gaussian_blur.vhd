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

    -- BRAM to replace registers
    constant c_BRAMS : integer := 5;
    constant c_BRAM_ADDR_WIDTH : integer := CLOG2(g_WIDTH);
    type t_bram_data is array (0 to c_BRAMS - 1) of std_logic_vector(7 downto 0);
    type t_bram_en   is array (0 to c_BRAMS - 1) of std_logic;
    signal w_addr : std_logic_vector(c_BRAM_ADDR_WIDTH - 1 downto 0);
    signal q_wr_en, n_wr_en : t_bram_en;
    signal w_rd_data : t_bram_data;

    -- Current line
    signal q_line_idx, n_line_idx : unsigned(2 downto 0);

    -- 5x5 Sliding pixel window
    type t_pixel_window_line is array (0 to 4) of std_logic_vector(7 downto 0);
    type t_pixel_window is array (0 to 4) of t_pixel_window_line;
    signal q_window, n_window : t_pixel_window;
    signal q_pixel, n_pixel : std_logic_vector(7 downto 0);

    -- State signals
    type t_state is (s_READ, s_WAIT, s_FETCH, s_CALC, s_WRITE);
    signal q_state, n_state : t_state;

    -- Hard coded width for row and column count
    signal q_col, n_col : unsigned(9 downto 0);
    signal q_row, n_row : unsigned(9 downto 0);

    -- Multiply accumulate signals
    signal q_calc_count, n_calc_count : unsigned(4 downto 0);
    type t_sum is array (0 to 15) of unsigned(15 downto 0);
    signal q_sum, n_sum : t_sum;

    signal w_tmp : std_logic_vector(15 downto 0);

    component bram is
        generic (
            BRAM_ADDR_WIDTH : integer := 10;
            BRAM_DATA_WIDTH : integer := 8
        );
        port (
            clock   : in std_logic;
            rd_addr : in std_logic_vector(BRAM_ADDR_WIDTH - 1 downto 0);
            wr_addr : in std_logic_vector(BRAM_ADDR_WIDTH - 1 downto 0);
            wr_en   : in std_logic;
            din     : in std_logic_vector(BRAM_DATA_WIDTH - 1 downto 0);
            dout    : out std_logic_vector(BRAM_DATA_WIDTH - 1 downto 0) 
        );
    end component bram;

begin

    gen_buff : for i in 0 to c_BRAMS - 1 generate
        buff : bram
            generic map (
                BRAM_ADDR_WIDTH => c_BRAM_ADDR_WIDTH,
                BRAM_DATA_WIDTH => 8
            )
            port map (
                clock   => i_CLK,
                -- Since reading/writing only occurs for one address, only one signal is required.
                rd_addr => w_addr,
                wr_addr => w_addr,
                wr_en   => q_wr_en(i),
                din     => q_pixel,
                dout    => w_rd_data(i)
            );
    end generate;

    state_seq : process (i_CLK, i_RST) begin

        if (i_RST = '1') then
            -- Pixel buffer and sliding window
            q_wr_en <= (others => '0');
            q_window <= (others => (others => (others => '0')));
            q_line_idx <= (others => '0');
            q_pixel <= (others => '0');
            -- States
            q_state <= s_READ;
            -- Pixel arithmetic
            q_col   <= (others => '0');
            q_row   <= (others => '0');
            q_calc_count <= (others => '0');
            q_sum   <= (others => (others => '0'));
        elsif (rising_edge(i_CLK)) then
            -- Pixel buffer and sliding window
            q_wr_en <= n_wr_en;
            q_window <= n_window;
            q_line_idx <= n_line_idx;
            q_pixel <= n_pixel;
            -- States
            q_state <= n_state;
            -- Pixel arithmetic
            q_col   <= n_col;
            q_row   <= n_row;
            q_calc_count <= n_calc_count;
            q_sum   <= n_sum;
        end if;

    end process state_seq;

    state_comb : process (q_state, w_addr, q_wr_en, q_pixel, w_rd_data, q_col, q_row, q_window, q_calc_count, q_sum, i_PIXEL, i_EMPTY, w_tmp, i_FULL, q_line_idx) begin

        -- Default signal assignment
        w_addr <= std_logic_vector(resize(q_col, c_BRAM_ADDR_WIDTH));
        n_wr_en <= (others => '0');
        n_window <= q_window;
        n_line_idx <= q_line_idx;
        n_pixel <= q_pixel;
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
                    -- Go to fetch state since no writing is necessary
                    n_state <= s_FETCH;

                -- If FIFO not empty or if remaining pixels need to be buffered out
                elsif (i_EMPTY = '0') then
                    -- Store pixel in specific BRAM and location
                    if (q_col < to_unsigned(g_WIDTH, q_col'length)) then -- OPTIMIZATION: Remove this if statement
                        -- Assert write enable only for current BRAM
                        n_pixel <= i_PIXEL;
                        n_wr_en(to_integer(q_line_idx)) <= '1';
                        o_RD_EN <= '1';
                    end if;
                    -- Go to wait state
                    n_state <= s_WAIT;
                end if;

            when s_WAIT =>
                -- Once data has been stored in BRAM, go to next state
                n_state <= s_FETCH;
            
            when s_FETCH =>
                    
                    -- For each row of the sliding window
                    for r in 0 to 4 loop
                        -- Shift current pixels
                        n_window(r)(1 to 4) <= q_window(r)(0 to 3);
                        -- Shift in pixels if they exist
                        if (q_col > to_unsigned(g_WIDTH - 1, q_col'length)) then
                            -- Most recent pixels go in position 0
                            n_window(r)(0) <= (others => '0');
                        else
                            if (q_line_idx < to_unsigned(r, q_line_idx'length)) then
                                n_window(r)(0) <= w_rd_data(5 + to_integer(q_line_idx) - r);
                            else
                                n_window(r)(0) <= w_rd_data(to_integer(q_line_idx) - r);
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