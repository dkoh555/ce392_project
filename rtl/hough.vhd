library ieee;
library work;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.lanedetect_pkg.all;

entity hough is

    generic (
        g_HEIGHT : integer := 540;
        g_WIDTH  : integer := 720;
        -- Resolution of Hough Transform
        g_RHO_RES_LOG   : integer := 2;     -- Clog2(Rho Resolution = 4)
        g_RHOS          : integer := 50;    -- Sqrt(ROWS ^ 2 + COLS ^ 2) / Rho Resolution
        g_THETAS        : integer := 180;   -- With smaller images, reducing this resolution decreases accuracy significantly
        g_TOP_N         : integer := 4;    -- Number of top voted Rhos and Theta values to consider
        g_BRAM_ADDR_WIDTH : integer := 10;  -- Maximum size based on g_BRAM_DATA_WIDTH and maximum BRAM size
        g_BRAM_DATA_WIDTH : integer := 10;  -- Clog2(sqrt(g_HEIGHT^2 + g_WIDTH^2)), maximum count of votes for each Rho is the diagonal of the image
        -- Quantization
        g_TOP_BITS : integer := 10;
        g_BOT_BITS : integer := 8
        -- Parallelizatin of calculations
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

end entity hough;

architecture rtl of hough is 

    -- Note: According to Quartus, the total size of a BRAM must be less than 2*20 bits
    --  Thus, the total number of theta values per BRAM is limited by g_BRAM_ADDR_WIDTH.
    --  Each theta value is associated with g_RHOS rho values.
    constant c_THETA_PER_BRAM : integer := (2 ** g_BRAM_ADDR_WIDTH) / g_RHOS;
    constant c_BRAMS : integer := (g_THETAS + c_THETA_PER_BRAM - 1) / c_THETA_PER_BRAM; -- Ceiling division
    constant c_MAX_ADDR : unsigned(g_BRAM_ADDR_WIDTH - 1 downto 0) := to_unsigned((2 ** g_BRAM_ADDR_WIDTH) - 1, g_BRAM_ADDR_WIDTH);

    type t_state is (s_IDLE, s_READ, s_CALC, s_FIND, s_FINDL0, s_FINDL1, s_FINDR0, s_FINDR1, s_WRITE);
    signal q_state, n_state : t_state;

    signal q_col, n_col : signed(9 downto 0);
    signal q_row, n_row : signed(9 downto 0);

    -- Calculation signals
    signal q_xs, n_xs : signed(g_TOP_BITS + g_BOT_BITS - 1 downto 0);
    signal q_ys, n_ys : signed(g_TOP_BITS + g_BOT_BITS - 1 downto 0);    
    signal q_count, n_count : unsigned(g_BRAM_ADDR_WIDTH - 1 downto 0);
    signal q_count_calc, n_count_calc : unsigned(4 downto 0);
    type t_sum is array (0 to c_BRAMS - 1) of signed(g_TOP_BITS + g_BOT_BITS - 1 downto 0);
    -- t_index can go up to c_THETA_PER_BRAM * c_BRAMS, which can exceed g_THETAS depending on different generics
    subtype t_theta is integer range 0 to c_THETA_PER_BRAM * c_BRAMS;
    type t_theta_array is array (0 to c_BRAMS - 1) of t_theta;
    signal q_theta, n_theta : t_theta_array;
    signal q_sum, n_sum : t_sum;
    signal q_rho, n_rho : t_sum;
    signal w_centered_x, w_centered_y : signed(g_TOP_BITS + g_BOT_BITS - 1 downto 0);

    -- Testing signals
    type t_test is array (0 to c_BRAMS - 1) of signed(35 downto 0);

    type t_bram_addr is array (0 to c_BRAMS - 1) of std_logic_vector(g_BRAM_ADDR_WIDTH - 1 downto 0);
    type t_bram_data is array (0 to c_BRAMS - 1) of std_logic_vector(g_BRAM_DATA_WIDTH - 1 downto 0);
    type t_bram_en   is array (0 to c_BRAMS - 1) of std_logic;
    signal q_rd_addr, n_rd_addr : t_bram_addr;
    signal q_wr_addr, n_wr_addr : t_bram_addr;
    signal q_wr_en, n_wr_en : t_bram_en;
    signal q_wr_data, n_wr_data : t_bram_data;
    signal w_rd_data : t_bram_data;

    -- Each value represents the location in each bram of the top rho
    type t_top_rhos is array (0 to g_TOP_N - 1) of std_logic_vector(g_BRAM_ADDR_WIDTH - 1 downto 0);
    type t_top_votes is array (0 to g_TOP_N - 1) of std_logic_vector(g_BRAM_DATA_WIDTH - 1 downto 0);
    type t_top_rhos_bram is array (0 to c_BRAMS - 1) of t_top_rhos;
    type t_top_votes_bram is array (0 to c_BRAMS - 1) of t_top_votes;
    signal q_top_rhos, n_top_rhos : t_top_rhos_bram;
    signal q_top_thetas, n_top_thetas : t_top_rhos_bram;
    signal q_top_votes, n_top_votes : t_top_votes_bram;
    signal q_lhs, n_lhs : signed(g_BRAM_ADDR_WIDTH - 1 downto 0);
    signal q_rhs, n_rhs : signed(g_BRAM_ADDR_WIDTH - 1 downto 0);

    -- Writing signals
    signal q_left_votes, n_left_votes : std_logic_vector(g_BRAM_DATA_WIDTH - 1 downto 0);
    signal q_right_votes, n_right_votes : std_logic_vector(g_BRAM_DATA_WIDTH - 1 downto 0);
    signal q_right_rho, n_right_rho : std_logic_vector(g_BRAM_ADDR_WIDTH - 1 downto 0);
    signal q_left_rho, n_left_rho : std_logic_vector(g_BRAM_ADDR_WIDTH - 1 downto 0);
    signal q_right_theta, n_right_theta : std_logic_vector(g_BRAM_ADDR_WIDTH - 1 downto 0);
    signal q_left_theta, n_left_theta : std_logic_vector(g_BRAM_ADDR_WIDTH - 1 downto 0);
    signal q_bram_count, n_bram_count : unsigned(9 downto 0);

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

    -- Instantiate multiple buffers instead of one large one to act as the accumulator
    --  Each BRAM manages all of the rho values associated with a given theta.
    --  The D8M outputs 600 x 480, but we will likely downsize to 300 x 240 or even 150 x 120.
    --  That means our g_RHOS parameter will likely drop down to around 192 (or even 96).
    --  With a smaller g_RHOS, we can fit more THETA values per BRAM.
    --  Each BRAM is responsible for i * c_THETA_PER_BRAM : i * c_THETA_PER_BRAM + c_THETA_PER_BRAM - 1
    gen_bram : for i in 0 to c_BRAMS - 1 generate
        accum_bram_inst : bram 
            generic map (
                BRAM_ADDR_WIDTH => g_BRAM_ADDR_WIDTH,
                BRAM_DATA_WIDTH => g_BRAM_DATA_WIDTH -- Can be smaller for smaller images
            )
            port map (
                clock => i_CLK,
                rd_addr => q_rd_addr(i),
                wr_addr => q_wr_addr(i),
                wr_en   => q_wr_en(i),
                din     => q_wr_data(i),
                dout    => w_rd_data(i)
            );
    end generate;

    state_seq : process (i_CLK, i_RST) begin

        if (i_RST = '1') then
            q_state <= s_IDLE;
            q_col   <= (others => '0');
            q_row   <= (others => '0');
            q_xs    <= (others => '0');
            q_ys    <= (others => '0');
            q_count <= (others => '0');
            q_count_calc <= (others => '0');
            q_theta <= (others => 0);
            q_sum   <= (others => (others => '0'));
            q_rho   <= (others => (others => '0'));
            q_rd_addr       <= (others => (others => '0'));
            q_wr_addr       <= (others => (others => '0'));
            q_wr_en         <= (others => '0');
            q_wr_data       <= (others => (others => '0'));
            q_top_rhos      <= (others => (others => (others => '0')));
            q_top_thetas    <= (others => (others => (others => '0')));
            q_top_votes     <= (others => (others => (others => '0')));
            q_left_votes    <= (others => '0');
            q_right_votes   <= (others => '0');
            q_left_rho      <= (others => '0');
            q_left_theta    <= (others => '0');
            q_right_rho     <= (others => '0');
            q_right_theta   <= (others => '0');
            q_bram_count    <= (others => '0');
            q_lhs           <= (others => '0');
            q_rhs           <= (others => '0');
        elsif (rising_edge(i_CLK)) then
            q_state <= n_state;
            q_col   <= n_col;
            q_row   <= n_row;
            q_xs    <= n_xs;
            q_ys    <= n_ys;
            q_count <= n_count;
            q_count_calc <= n_count_calc;
            q_theta <= n_theta;
            q_sum   <= n_sum;
            q_rho   <= n_rho;
            q_rd_addr       <= n_rd_addr;
            q_wr_addr       <= n_wr_addr;
            q_wr_en         <= n_wr_en;
            q_wr_data       <= n_wr_data;
            q_top_rhos      <= n_top_rhos;
            q_top_thetas    <= n_top_thetas;
            q_top_votes     <= n_top_votes;
            q_left_votes    <= n_left_votes;
            q_right_votes   <= n_right_votes;
            q_left_rho      <= n_left_rho;
            q_left_theta    <= n_left_theta;
            q_right_rho     <= n_right_rho;
            q_right_theta   <= n_right_theta;
            q_bram_count    <= n_bram_count;
            q_lhs           <= n_lhs;
            q_rhs           <= n_rhs;
        end if;

    end process state_seq;

    state_comb : process (i_EMPTY, i_PIXEL, i_FULL, q_state, q_col, q_row, w_centered_x, w_centered_y, q_xs, q_ys, q_count, q_count_calc, q_theta, q_sum, q_rho, q_rd_addr, q_wr_addr, q_wr_en, n_wr_data, q_wr_data, w_rd_data, q_top_rhos, q_top_thetas, q_top_votes, q_left_votes, q_right_votes, q_right_rho, q_left_rho, q_right_theta, q_left_theta, q_bram_count, q_lhs, q_rhs) 
    
        variable v_theta : integer := 0;
        variable v_offset : integer := 0;
        variable curr_theta  : signed(g_BRAM_ADDR_WIDTH - 1 downto 0);
        variable curr_votes  : unsigned(g_BRAM_DATA_WIDTH - 1 downto 0);
        variable ideal_theta : signed(g_BRAM_ADDR_WIDTH - 1 downto 0);

    begin

        -- Default signal assignment
        n_state <= q_state;
        n_col   <= q_col;
        n_row   <= q_row;
        -- q_col is unchanging during calculation phase, so can move outside of case statement to save on combinational logic
        w_centered_x <= resize(q_col - to_signed(g_WIDTH / 2, q_col'length), w_centered_x'length);
        w_centered_y <= resize(q_row - to_signed(g_HEIGHT / 2, q_col'length), w_centered_y'length);
        n_xs <= shift_right(w_centered_x, g_RHO_RES_LOG);
        n_ys <= shift_right(w_centered_y, g_RHO_RES_LOG);
        n_count <= q_count;
        n_count_calc <= q_count_calc;
        n_theta <= q_theta;
        n_sum   <= q_sum;
        n_rho   <= q_rho;
        n_rd_addr <= q_rd_addr;
        n_wr_addr <= q_wr_addr;
        n_wr_en <= (others => '0');
        n_wr_data <= q_wr_data;
        n_top_rhos <= q_top_rhos;
        n_top_thetas <= q_top_thetas;
        n_top_votes <= q_top_votes;

        n_left_votes <= q_left_votes;
        n_right_votes <= q_right_votes;
        n_right_rho <= q_right_rho;
        n_left_rho <= q_left_rho;
        n_right_theta <= q_right_theta;
        n_left_theta <= q_left_theta;
        n_bram_count <= q_bram_count;
        n_lhs        <= q_lhs;
        n_rhs        <= q_rhs;

        -- Default output assignment
        o_RD_EN <= '0';
        o_WR_EN <= '0';
        o_LEFT_RHO <= q_left_rho;
        o_LEFT_THETA <= q_left_theta;
        o_RIGHT_RHO <= q_right_rho;
        o_RIGHT_THETA <= q_right_theta;

        case (q_state) is

            when s_IDLE =>

                -- Clear BRAMs
                for i in 0 to c_BRAMS - 1 loop
                    n_wr_addr(i) <= std_logic_vector(q_count);
                    n_wr_en(i)   <= '1';
                    n_wr_data(i) <= (others => '0');
                end loop;
                -- Increment counter otherwise
                n_count <= q_count + to_unsigned(1, q_count'length);

                -- If all BRAMs have been cleared
                if (q_count = c_MAX_ADDR) then
                    -- Go to READ state
                    n_state <= s_READ;
                end if;

                -- Reset counting signals
                n_left_votes    <= (others => '0');
                n_right_votes   <= (others => '0');
                n_right_rho     <= (others => '0');
                n_left_rho      <= (others => '0');
                n_right_theta   <= (others => '0');
                n_left_theta    <= (others => '0');
                n_bram_count    <= (others => '0');
                n_top_rhos      <= (others => (others => (others => '0')));
                n_top_thetas    <= (others => (others => (others => '0')));
                n_top_votes     <= (others => (others => (others => '0')));

            when s_READ => 

                if (i_EMPTY = '0') then
                    o_RD_EN <= '1';
                    -- If the pixel is black, skip
                    if (i_PIXEL = std_logic_vector(to_unsigned(0, i_PIXEL'length))) then
                        -- If end of image reached, go to write
                        if (q_row = to_signed(g_HEIGHT - 1, q_row'length) and q_col = to_signed(g_WIDTH - 1, q_col'length)) then
                            n_state <= s_FINDL0;
                        -- If end of row reached, reset column count and increment row counter
                        elsif (q_col = to_signed(g_WIDTH - 1, 10)) then
                            n_row <= q_row + to_signed(1, 10);
                            n_col <= to_signed(0, 10);
                        -- Otherwise, just increment column count
                        else
                            n_col <= q_col + to_signed(1, 10);
                        end if;
                    -- Otherwise, accumulate
                    else
                        n_state <= s_CALC;
                    end if;
                end if;
                
                -- Ensure that q_count is set to 0 before calculations are performed
                n_count <= (others => '0');
                n_bram_count <= (others => '0');

            when s_CALC =>
            
                -- q_xs, q_ys calculations occur every cycle
                -- Increment counter to keep track of how many rho calculations have been performed, based on q_count(q_count'left downto 2)
                n_count_calc <= q_count_calc + to_unsigned(1, q_count_calc'length);
                -- On first cycle of calculation
                if (q_count_calc = to_unsigned(0, q_count_calc'length)) then
                    for i in 0 to c_BRAMS - 1 loop
                        -- xs * COS_TABLE[theta] + ys * SIN_TABLE[theta]
                        n_theta(i) <= to_integer(q_count) + c_THETA_PER_BRAM * i;
                        -- Since each BRAM holds g_RHOS (how many rhos) values for c_THETA_PER_BRAM (how many thetas) theta values,
                        --  Each BRAM is in charge of q_count(q_count'left downto 2) + c_THETA_PER_BRAM * i in the COS_TABLE.
                        --  For example, BRAM 0 is in charge of 0 to c_THETA_PER_BRAM - 1 values of theta, and all of the associated rhos.
                        --      BRAM 0: THETA = 0 - RHO 0 to g_RHOS - 1, THETA = 1 - RHO 0 to g_RHOS - 1, ...
                        --               BRAM 1 is in charge of c_THETA_PER_BRAM to c_THETA_PER_BRAM + c_THETA_PER_BRAM - 1
                        -- v_theta should be within bounds of COS_TABLE and SIN_TABLE.
                    end loop;
                elsif (q_count_calc = to_unsigned(1, q_count_calc'length)) then
                    for i in 0 to c_BRAMS - 1 loop
                        -- Next optimization: make g_TOP_BITS = 8, so a single DSP block can handle both 18x18 multiplies
                        n_sum(i) <= resize(q_xs * COS_TABLE(q_theta(i)) + q_ys * SIN_TABLE(q_theta(i)), g_TOP_BITS + g_BOT_BITS);
                    end loop;
                -- On second cycle of calculation
                elsif (q_count_calc = to_unsigned(2, q_count_calc'length)) then
                    for i in 0 to c_BRAMS - 1 loop
                        n_rho(i) <= DEQUANTIZE(q_sum(i)) + to_signed(g_RHOS/2, n_rho(i)'length);                           
                    end loop;
                elsif (q_count_calc = to_unsigned(3, q_count_calc'length)) then
                    for i in 0 to c_BRAMS - 1 loop
                        -- v_offset
                        v_offset := to_integer(q_count) * g_RHOS;
                        -- Address is q_count * g_RHOS + rho value
                        -- q_count the offset based on the current theta
                        if (q_theta(i) < g_THETAS) then
                            n_rd_addr(i) <= std_logic_vector(resize(unsigned(q_rho(i)) + to_unsigned(v_offset, q_rho(i)'length), n_rd_addr(i)'length));
                        else
                            n_rd_addr(i) <= (others => '1');
                        end if;
                    end loop;
                elsif (q_count_calc = to_unsigned(4, q_count_calc'length)) then
                    -- Do nothing, wait for read address to propogate first
                elsif (q_count_calc = to_unsigned(5, q_count_calc'length)) then
                    for i in 0 to c_BRAMS - 1 loop
                        n_wr_addr(i) <= q_rd_addr(i);
                        n_wr_en(i) <= '1';
                        n_wr_data(i) <= std_logic_vector(resize(unsigned(w_rd_data(i)) + to_unsigned(1, w_rd_data(i)'length), n_wr_data(i)'length));
                    end loop;
                else
                    for i in 0 to c_BRAMS - 1 loop
                        -- If the vote count of the current rho is greater than the top rho
                        for rank in 0 to g_TOP_N-1 loop
                            -- If the vote count of the current rho is greater than the vote at this rank
                            -- Also check if it was a valid address, if not, skip
                            if (unsigned(q_wr_data(i)) > unsigned(q_top_votes(i)(rank)) and (q_rd_addr(i) /= std_logic_vector(c_MAX_ADDR))) then
                                -- Shift down lower-ranked values
                                if rank < g_TOP_N - 1 then
                                    n_top_rhos(i)(rank+1 to g_TOP_N-1) <= q_top_rhos(i)(rank to g_TOP_N-2);
                                    n_top_thetas(i)(rank+1 to g_TOP_N-1) <= q_top_thetas(i)(rank to g_TOP_N-2);
                                    n_top_votes(i)(rank+1 to g_TOP_N-1) <= q_top_votes(i)(rank to g_TOP_N-2);
                                end if;
                                -- Assign current rho to top rhos
                                n_top_rhos(i)(rank) <= std_logic_vector(resize(q_rho(i), n_top_rhos(i)(rank)'length));
                                -- Assign current theta to top thetas
                                n_top_thetas(i)(rank) <= std_logic_vector(to_unsigned(q_theta(i), n_top_thetas(i)(rank)'length));
                                -- Assign current votes to top votes
                                n_top_votes(i)(rank) <= n_wr_data(i);
                                -- Exit after inserting the new vote
                                exit;
                            end if;
                        end loop;
                    end loop;

                    -- If all THETAS in each BRAM have been accounted for, move on to next pixel
                    if (q_count = to_unsigned(c_THETA_PER_BRAM - 1, q_count'length)) then
                        n_state <= s_READ;
                        -- If end of row reached, reset column count and increment row counter
                        if (q_col = to_signed(g_WIDTH - 1, 10)) then
                            n_row <= q_row + to_signed(1, 10);
                            n_col <= to_signed(0, 10);
                        -- Otherwise, just increment column count
                        else
                            n_col <= q_col + to_signed(1, 10);
                        end if;
                    end if;
                    -- Increment q_count
                    n_count <= q_count + to_unsigned(1, q_count'length);
                    -- Reset q_count_calc
                    n_count_calc <= (others => '0');

                end if;

            when s_FINDL0 => 

                -- End of image reached, reset column and row count
                n_row <= (others => '0');
                n_col <= (others => '0');

                -- Classify left/right lanes

                -- Thetas corresponding to the left lane:
                --  If the current theta/rho pair has equal or more votes than the previous best
                if (unsigned(q_top_thetas(to_integer(q_bram_count))(to_integer(q_count))) >= to_unsigned(100, g_BRAM_ADDR_WIDTH - 1) and
                    unsigned(q_top_thetas(to_integer(q_bram_count))(to_integer(q_count))) <= to_unsigned(160, g_BRAM_ADDR_WIDTH - 1)) then
                    n_state <= s_FINDL1;
                else
                    n_state <= s_FINDR0;
                end if;

                n_lhs <= signed(q_top_thetas(to_integer(q_bram_count))(to_integer(q_count))) - to_signed(130, g_BRAM_ADDR_WIDTH);
                n_rhs <= signed(q_left_theta) - to_signed(130, g_BRAM_ADDR_WIDTH);

            when s_FINDL1 => 

                if (unsigned(q_top_votes(to_integer(q_bram_count))(to_integer(q_count))) > unsigned(q_left_votes) or
                    (unsigned(q_top_votes(to_integer(q_bram_count))(to_integer(q_count))) = unsigned(q_left_votes) and ABS_SIGNED(q_lhs) < ABS_SIGNED(q_rhs))) then
                        n_left_votes <= std_logic_vector(q_top_votes(to_integer(q_bram_count))(to_integer(q_count)));
                        n_left_rho <= std_logic_vector(q_top_rhos(to_integer(q_bram_count))(to_integer(q_count)));
                        n_left_theta <= std_logic_vector(q_top_thetas(to_integer(q_bram_count))(to_integer(q_count)));
                end if;

                n_state <= s_FINDR0;
            
            when s_FINDR0 =>

                if (unsigned(q_top_thetas(to_integer(q_bram_count))(to_integer(q_count))) >= to_unsigned(20, g_BRAM_ADDR_WIDTH - 1) and
                    unsigned(q_top_thetas(to_integer(q_bram_count))(to_integer(q_count))) <= to_unsigned(80, g_BRAM_ADDR_WIDTH - 1)) then
                    n_state <= s_FINDR1;
                else
                    n_state <= s_FIND;
                end if;

                n_lhs <= signed(q_top_thetas(to_integer(q_bram_count))(to_integer(q_count))) - to_signed(50, g_BRAM_ADDR_WIDTH);
                n_rhs <= signed(q_right_theta) - to_signed(50, g_BRAM_ADDR_WIDTH);

            when s_FINDR1 => 
                    
                if (unsigned(q_top_votes(to_integer(q_bram_count))(to_integer(q_count))) > unsigned(q_right_votes) or
                    (unsigned(q_top_votes(to_integer(q_bram_count))(to_integer(q_count))) = unsigned(q_right_votes) and ABS_SIGNED(q_lhs) < ABS_SIGNED(q_rhs))) then
                        n_right_votes <= std_logic_vector(q_top_votes(to_integer(q_bram_count))(to_integer(q_count)));
                        n_right_rho <= std_logic_vector(q_top_rhos(to_integer(q_bram_count))(to_integer(q_count)));
                        n_right_theta <= std_logic_vector(q_top_thetas(to_integer(q_bram_count))(to_integer(q_count)));
                end if;

                n_state <= s_FIND;

            when s_FIND =>

                -- By default, go back to first find state
                n_state <= s_FINDL0;

                -- If all top values in a given bram have been exhausted, move on to the next one
                if (q_count = to_unsigned(g_TOP_N - 1, q_count'length)) then
                    -- If all top values in all brams have been exhausted, 
                    if (q_bram_count = to_unsigned(c_BRAMS - 1, q_bram_count'length)) then
                        -- Move to writing to FIFOs
                        n_state <= s_WRITE;
                    end if;
                    -- Increment bram count and top values count                
                    n_bram_count <= q_bram_count + to_unsigned(1, q_bram_count'length);
                    n_count <= (others => '0');
                else
                    -- Increment top values count
                    n_count <= q_count + to_unsigned(1, q_count'length);
                end if;

            when s_WRITE =>

                if (i_FULL = '0') then
                    n_state <= s_IDLE;
                    if (unsigned(q_right_votes) /= to_unsigned(0, q_right_votes'length) and unsigned(q_left_votes) /= to_unsigned(0, q_left_votes'length)) then
                        o_WR_EN <= '1';     
                    else
                        o_WR_EN <= '0';
                    end if;            
                end if;
        end case;

    end process state_comb;    

end architecture rtl;