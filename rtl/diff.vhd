entity diff is

    generic (
        g_HEIGHT : integer := 200;
        g_WIDTH  : integer := 200;
        -- Sets the threshold for what is considered a significant difference
        g_THRESHOLD : integer := 10000;
        -- Sets number of slices that need to exceed the threshold to count for difference
        g_SLICES_TO_COUNT : integer := 8;
        -- Sets how many small squares the image should be divided into
        g_SLICES : integer := 16;
        -- (Ok I admit VHDL is not great in this regard because you can't calculate sqrt at compile time)
        -- Because of that you need to set the size of the square manually
        g_SLICE_COL_ROW : integer := 4;
        g_SLICE_SIZE : integer := 50

    );
    port (
        i_CLK   : in std_logic;
        i_RST   : in std_logic;

        -- Current buffer being written to
        i_BUFF  : in std_logic_vector(1 downto 0);
        
        -- Buffer signals
        i_A_DATA    : in std_logic_vector(15 downto 0);
        o_A_RD_ADDR : out std_logic_vector(16 downto 0);
        i_B_DATA    : in std_logic_vector(15 downto 0);
        o_B_RD_ADDR : out std_logic_vector(16 downto 0);
        i_C_DATA    : in std_logic_vector(15 downto 0);
        i_C_RD_ADDR : out std_logic_vector(16 downto 0);

        -- Output signal
        o_DIFF  : out std_logic;
        o_VALID : out std_logic;
    );

end entity diff;

architecture rtl of diff is

    -- If i_BUFF is "00", don't compare images yet
    -- 
    -- 3 Buffers: A (1), B (2), C (3)
    -- If Buffer A is currently being written to (newest frame), then:
    --      Buffer B is the most recent complete frame
    --      Buffer C is the previous complete frame
    -- If Buffer C is currently being written to (newest frame), then:
    --      Buffer A is the most recent complete frame
    --      Buffer B is the previous complete frame
    -- If Buffer B is currently being written to (newest frame), then:
    --      Buffer C is the most recent complete frame
    --      Buffer A is the previous complete frame
    -- For processing purposes, none of this matters - we just compare the
    --  two buffers not currently being written to

    type t_state is (s_IDLE, s_COMPARE, s_OUTPUT);
    signal q_state, n_state : t_state;

    signal q_slice_col, n_slice_col : unsigned(2 downto 0); -- Max 4 slices wide
    signal q_slice_row, n_slice_row : unsigned(2 downto 0); -- Max 4 slices tall
    signal q_local_col, n_local_col : unsigned(7 downto 0); -- Local pixel col inside slice, max 200 pixels
    signal q_local_row, n_local_row : unsigned(7 downto 0); -- Local pixel row inside slice, max 200 pixels

    signal q_count, n_count : unsigned(3 downto 0);
    signal q_sum, n_sum : unsigned(20 downto 0);

    type t_DATA is array (0 to 2) of std_logic_vector(15 downto 0);
    signal w_bram_data : t_DATA;
    signal w_bram_addr : std_logic_vector(16 downto 0);
    signal w_idx0, w_idx1 : unsigned(1 downto 0);

    signal q_diff, n_diff : std_logic;
    signal q_valid, n_valid : std_logic;
    

begin

    state_seq : process (i_CLK, i_RST) is begin

        if (i_RST = '1') then
            q_state <= s_IDLE;     
            q_slice_col   <= (others => '0');
            q_slice_row   <= (others => '0');       
            q_local_col   <= (others => '0');
            q_local_row   <= (others => '0');   
            q_count       <= (others => '0');
            q_sum         <= (others => '0');
            q_diff        <= '0';
            q_valid       <= '0';
        elsif (rising_edge(i_CLK)) then
            q_state <= n_state;
            q_slice_col   <= n_slice_col;
            q_slice_row   <= n_slice_row;
            q_local_col   <= n_local_col;
            q_local_row   <= n_local_row;
            q_count       <= n_count;
            q_sum         <= n_sum;
            q_diff        <= n_diff;
            q_valid       <= n_valid;
        end if;

    end process state_seq;

    state_comb : process () is begin
        
        -- Default signal assignment
        n_state <= q_state;
        n_slice_col   <= q_slice_col;
        n_slice_row   <= q_slice_row;
        n_local_col   <= q_local_col;
        n_local_row   <= q_local_row;
        n_count <= q_count;
        n_sum   <= q_sum;
        n_diff  <= '0';
        n_valid <= '0';
        w_bram_data(0) <= i_A_DATA;
        w_bram_data(1) <= i_B_DATA;
        w_bram_data(2) <= i_C_DATA;
        w_bram_addr <= resize((q_slice_row * to_unsigned(g_SLICE_SIZE, q_slice_row'length) + q_local_row) * to_unsigned(g_WIDTH, w_bram_addr(0)'length) + (q_slice_col * to_unsigned(g_SLICE_SIZE, q_slice_col'length) + q_local_col), w_bram_addr'length);

        case (q_state) is 

            when s_IDLE =>

                -- If at least 2 buffers have been written, we can start comparing
                if (i_BUFF /= "00") then
                    n_state <= s_COMPARE;
                end if;

            when s_COMPARE =>

                n_sum <= (others => '0') when (q_local_col = g_SLICE_SIZE-1 and q_local_row = g_SLICE_SIZE-1) else
                        q_sum + resize(unsigned(w_bram_data(w_idx0)) - unsigned(w_bram_data(w_idx1)), q_sum'length);
                
                -- Determine next column
                n_local_col <= (others => '0') when q_local_col = g_SLICE_SIZE-1 else q_local_col + 1;

                -- Determine next row
                n_local_row <= (others => '0') when (q_local_col = g_SLICE_SIZE-1 and q_local_row = g_SLICE_SIZE-1) else
                                (q_local_row + 1) when q_local_col = g_SLICE_SIZE-1 else
                                q_local_row;

                -- Determine next slice column
                n_slice_col <= (others => '0') when (q_local_col = to_unsigned(g_SLICE_SIZE-1, q_local_col'length) and q_local_row = to_unsigned(g_SLICE_SIZE-1, q_local_row'length) and q_slice_col = to_unsigned(g_SLICE_COL_ROW-1, q_slice_col'length)) else
                                (q_slice_col + 1) when (q_local_col = g_SLICE_SIZE-1 and q_local_row = g_SLICE_SIZE-1) else
                                q_slice_col;

                -- Determine next slice row
                n_slice_row <=  (q_slice_row + 1) when (q_local_col = to_unsigned(g_SLICE_SIZE-1, q_local_col'length) and q_local_row = to_unsigned(g_SLICE_SIZE-1, q_local_row'length) and q_slice_col = to_unsigned(g_SLICE_COL_ROW-1, q_slice_col'length)) else
                                q_slice_row;

                -- Go to output once all slices have been iterated over
                n_state <= s_OUTPUT when q_slice_row = to_unsigned(g_SLICE_COL_ROW, q_slice_row'length) else 
                            q_state;
                
                -- If q_sum > threshold, and end of slice has been reached, increment count
                if (q_sum > to_signed(g_THRESHOLD, q_sum'length) and q_local_col = to_unsigned(g_SLICE_SIZE-1, q_local_col'length) and q_local_row = to_unsigned(g_SLICE_SIZE-1, q_local_row'length) and q_slice_col = to_unsigned(g_SLICE_COL_ROW-1, q_slice_col'length)) then
                    n_count <= q_count + to_unsigned(1, q_count'length);
                end if;
                
            when s_OUTPUT =>

                n_slice_col <= (others => '0');
                n_slice_row <= (others => '0');
                n_valid <= '1';
                if (q_count > to_unsigned(g_SLICES_TO_COUNT, q_count'length)) then
                    n_diff <= '1';
                else
                    n_diff <= '0';
                end if;

                
        end case;

    end process state_comb;

    buff_comb : process (i_BUFF) is begin

        case (i_BUFF) is
            when "00" => -- Not writing
                w_idx0 <= "00"; -- Default value
                w_idx1 <= "00"; -- Default value
            when "01" =>  -- Writing to A (0)
                w_idx0 <= "01"; -- B
                w_idx1 <= "10"; -- C
            when "10" =>  -- Writing to B (1)
                w_idx0 <= "10"; -- C
                w_idx1 <= "00"; -- A
            when "11" =>  -- Writing to C (2)
                w_idx0 <= "00"; -- A
                w_idx1 <= "01"; -- B
        end case;

    end process buff_comb;

    -- Output assignments
    o_A_RD_ADDR <= w_bram_addr;
    o_B_RD_ADDR <= w_bram_addr;
    o_C_RD_ADDR <= w_bram_addr;
    o_DIFF  <= q_diff;
    o_VALID <= q_valid;



end architecture rtl;