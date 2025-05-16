library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.lanedetect_pkg.all;

entity center_lane is

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

end entity center_lane;

architecture rtl of center_lane is

    constant c_IMAGE_CENTER_X : integer := g_WIDTH / 2;
    constant c_IMAGE_CENTER_Y : integer := g_HEIGHT / 2;

    type t_state is (s_READ, s_PREDIVIDE0, s_PREDIVIDE1, s_PREDIVIDE2, s_DIVIDE0, s_DIVIDE1, s_CALC0, s_CALC1, s_WRITE);
    signal q_state, n_state : t_state;

    -- Index 0 is left, index 1 is right

    type t_data is array (0 to 1) of signed(g_BRAM_ADDR_WIDTH - 1 downto 0);
    signal q_rho,   n_rho   : t_data;
    signal q_theta, n_theta : t_data;

    type t_quantized is array (0 to 1) of signed(g_TOP_BITS + g_BOT_BITS - 1 downto 0);

    signal q_rho_q,     n_rho_q : t_quantized;
    signal q_cos_q,     n_cos_q : t_quantized;
    signal q_sin_q,     n_sin_q : t_quantized;
    signal q_num_q,     n_num_q : t_quantized;
    signal q_num_q_abs, n_num_q_abs : t_quantized;
    signal q_cos_q_abs, n_cos_q_abs : t_quantized;

    type t_shift is array (0 to 1 ) of signed(CLOG2(g_TOP_BITS + g_BOT_BITS) downto 0);

    signal q_shift, n_shift : t_shift;
    signal q_quotient, n_quotient : t_quantized;

    signal q_x, n_x : t_quantized;

    -- signal q_lane_center_q, n_lane_center_q : signed(g_TOP_BITS + g_BOT_BITS - 1 downto 0);
    signal q_offset_q, n_offset_q : signed(g_TOP_BITS + g_BOT_BITS - 1 downto 0);
    signal q_angle_q, n_angle_q : signed(g_TOP_BITS + g_BOT_BITS - 1 downto 0);
    signal q_steering, n_steering : signed(g_TOP_BITS + g_BOT_BITS - 1 downto 0);

    signal w_test0, w_test1, w_test2 : t_quantized;

    signal w_test4, w_test3 : signed(g_TOP_BITS + g_BOT_BITS - 1 downto 0);

    signal test_val : signed(19 downto 0) := to_signed(16#27000#, 20);
    signal msb_index : integer;


begin

    state_seq : process (i_CLK, i_RST) begin

        if (i_RST = '1') then
            q_state     <= s_READ;
            q_rho       <= (others => (others => '0'));
            q_theta     <= (others => (others => '0'));
            q_rho_q     <= (others => (others => '0'));
            q_cos_q     <= (others => (others => '0'));
            q_sin_q     <= (others => (others => '0'));
            q_num_q     <= (others => (others => '0'));
            q_num_q_abs <= (others => (others => '0'));
            q_cos_q_abs <= (others => (others => '0'));
            q_shift     <= (others => (others => '0'));
            q_quotient  <= (others => (others => '0'));
            q_x         <= (others => (others => '0'));
            q_offset_q  <= (others => '0');
            q_angle_q   <= (others => '0');
            q_steering  <= (others => '0');
        elsif (rising_edge(i_CLK)) then
            q_state     <= n_state;
            q_rho       <= n_rho;
            q_theta     <= n_theta;
            q_rho_q     <= n_rho_q;
            q_cos_q     <= n_cos_q;
            q_sin_q     <= n_sin_q;
            q_num_q     <= n_num_q;
            q_num_q_abs <= n_num_q_abs;
            q_cos_q_abs <= n_cos_q_abs;
            q_shift     <= n_shift;
            q_quotient  <= n_quotient;
            q_x         <= n_x;
            q_offset_q  <= n_offset_q;
            q_angle_q   <= n_angle_q;
            q_steering  <= n_steering;
        end if;

    end process state_seq;

    state_comb : process (q_state, q_rho, q_theta, q_rho_q, q_cos_q, q_sin_q, q_num_q, q_num_q_abs, q_cos_q_abs, q_shift, q_quotient, q_x, q_offset_q, q_angle_q, q_steering, i_EMPTY, i_LEFT_RHO, i_RIGHT_RHO, i_LEFT_THETA, i_RIGHT_THETA) 

    begin

        n_state     <= q_state;
        n_rho       <= q_rho;
        n_theta     <= q_theta;
        n_rho_q     <= q_rho_q;
        n_cos_q     <= q_cos_q;
        n_sin_q     <= q_sin_q;
        n_num_q     <= q_num_q;
        n_num_q_abs <= q_num_q_abs;
        n_cos_q_abs <= q_cos_q_abs;
        n_shift     <= q_shift;
        n_quotient  <= q_quotient;
        n_x         <= q_x;
        n_offset_q  <= q_offset_q;
        n_angle_q   <= q_angle_q;
        n_steering  <= q_steering;
        o_WR_EN     <= '0';
        o_RD_EN     <= '0';
        o_STEERING  <= std_logic_vector(q_steering(BOT_BITS - 1 downto 0));
        
        -- Testing signals
        for i in 0 to 1 loop
            w_test0(i) <= resize(to_signed(c_IMAGE_CENTER_Y, q_sin_q(i)'length) * q_sin_q(i), n_num_q(i)'length);
            w_test1(i) <= to_signed(FIND_MSB(q_num_q_abs(i)), g_TOP_BITS + g_BOT_BITS);
            w_test2(i) <= to_signed(FIND_MSB(q_cos_q_abs(i)), g_TOP_BITS + g_BOT_BITS);
        end loop;

        w_test3 <= shift_left(to_signed(c_IMAGE_CENTER_X, n_offset_q'length), g_BOT_BITS);
        w_test4 <= shift_right(q_x(0) + q_x(1), 1);
        msb_index <= FIND_MSB(test_val);  -- Should return 17


        case (q_state) is

            when s_READ =>
                -- If the input FIFO is not empty
                if (i_EMPTY = '0') then
                    -- Read in the Rho indices and Theta values
                    n_rho(0) <= signed(i_LEFT_RHO);
                    n_rho(1) <= signed(i_RIGHT_RHO);
                    n_theta(0) <= signed(i_LEFT_THETA);
                    n_theta(1) <= signed(i_RIGHT_THETA);
                    n_state <= s_PREDIVIDE0;
                    o_RD_EN <= '1';
                end if;
                -- Reset signals for the next image
                n_rho_q     <= (others => (others => '0'));
                n_cos_q     <= (others => (others => '0'));
                n_sin_q     <= (others => (others => '0'));
                n_num_q_abs <= (others => (others => '0'));
                n_cos_q_abs <= (others => (others => '0'));
                n_shift     <= (others => (others => '0'));
                n_quotient  <= (others => (others => '0'));
                n_x         <= (others => (others => '0'));
                n_offset_q  <= (others => '0');
                n_angle_q   <= (others => '0');
                n_steering  <= (others => '0');

            when s_PREDIVIDE0 =>
                for i in 0 to 1 loop
                    -- Compute actual rho from rho indices, then shift by BOT_BITS to prepare numerator
                    n_rho_q(i) <= shift_left(shift_left(resize(q_rho(i), n_rho_q(i)'length) - to_signed(g_RHOS / 2, n_rho_q(i)'length), g_RHO_RES_LOG), g_BOT_BITS);
                    -- Retrieve cosine and sine values for left and right lanes to prepare divisor
                    n_cos_q(i) <= resize(COS_TABLE(to_integer(q_theta(i))), g_TOP_BITS + g_BOT_BITS);
                    n_sin_q(i) <= resize(SIN_TABLE(to_integer(q_theta(i))), g_TOP_BITS + g_BOT_BITS);
                end loop;
                n_state <= s_PREDIVIDE1;

            when s_PREDIVIDE1 => 
                -- Get the numerator to prepare division
                -- Future Optimization: Create a SIN_TABLE that is alrerady multiplied by c_IMAGE_CENTER_Y
                for i in 0 to 1 loop
                    n_num_q(i) <= q_rho_q(i) + resize(to_signed(c_IMAGE_CENTER_Y, q_sin_q(i)'length) * q_sin_q(i), n_num_q(i)'length);
                end loop;
                n_state <= s_PREDIVIDE2;

            when s_PREDIVIDE2 =>
                -- Get absolute value of rho and cosine to perform division
                for i in 0 to 1 loop
                    n_num_q_abs(i) <= ABS_SIGNED(q_num_q(i));
                    n_cos_q_abs(i) <= ABS_SIGNED(q_cos_q(i));
                end loop;
                n_state <= s_DIVIDE0;

            when s_DIVIDE0 =>
                -- Get most significant bit
                for i in 0 to 1 loop
                    if (to_signed(FIND_MSB(q_num_q_abs(i)) - FIND_MSB(q_cos_q_abs(i)), n_shift(i)'length) < 0) then
                        n_shift(i) <= (others => '0');
                    else
                        n_shift(i) <= to_signed(FIND_MSB(q_num_q_abs(i)) - FIND_MSB(q_cos_q_abs(i)), n_shift(i)'length);
                    end if;
                end loop;
                n_state <= s_DIVIDE1;

            when s_DIVIDE1 =>
                -- If either still can shift
                if (q_shift(0) >= to_signed(0, q_shift(0)'length) or q_shift(1) >= to_signed(0, q_shift(1)'length)) then
                    if (q_num_q_abs(0) >= shift_left(q_cos_q_abs(0), to_integer(q_shift(0))) or q_num_q_abs(1) >= shift_left(q_cos_q_abs(1), to_integer(q_shift(1)))) then
                        n_state <= s_DIVIDE0;
                    else
                        if (q_shift(0) > to_signed(0, q_shift(0)'length) or q_shift(1) > to_signed(0, q_shift(1)'length)) then
                            n_state <= s_DIVIDE0;
                        else
                            n_state <= s_CALC0;
                        end if;
                    end if;
                else
                    n_state <= s_CALC0;
                end if;

                for i in 0 to 1 loop
                    -- Perform division
                    if (q_shift(i) >= to_signed(0, q_shift(i)'length)) then
                        -- If numerator is greater than denominator shifted by q_shift
                        if (q_num_q_abs(i) >= shift_left(q_cos_q_abs(i), to_integer(q_shift(i)))) then
                            n_num_q_abs(i) <= q_num_q_abs(i) - shift_left(q_cos_q_abs(i), to_integer(q_shift(i)));
                            n_quotient(i) <= signed(std_logic_vector(q_quotient(i)) or std_logic_vector(shift_left(to_signed(1, n_quotient(i)'length), to_integer(q_shift(i)))));
                            -- n_state <= s_DIVIDE0;
                        else
                            if (q_shift(i) > to_signed(0, q_shift(i)'length)) then
                                n_num_q_abs(i) <= q_num_q_abs(i) - shift_left(q_cos_q_abs(i), to_integer(q_shift(i)) - 1);
                                n_quotient(i) <= signed(std_logic_vector(q_quotient(i)) or std_logic_vector(shift_left(to_signed(1, n_quotient(i)'length), to_integer(q_shift(i)) - 1)));
                                -- n_state <= s_DIVIDE0;
                            else
                                n_x(i) <= shift_left(-q_quotient(i), g_BOT_BITS) when (q_num_q(i)(q_num_q(i)'high) xor q_cos_q(i)(q_cos_q(i)'high)) = '1' else shift_left(q_quotient(i), g_BOT_BITS);
                                -- n_state <= s_CALC0;
                            end if;
                        end if;
                    else
                        n_x(i) <= shift_left(-q_quotient(i), g_BOT_BITS) when (q_num_q(i)(q_num_q(i)'high) xor q_cos_q(i)(q_cos_q(i)'high)) = '1' else shift_left(q_quotient(i), g_BOT_BITS);
                        -- n_state <= s_CALC0;
                    end if;
                end loop;
                
            when s_CALC0 => 
                -- Calculate offset and angle difference
                n_offset_q <= - shift_right(q_x(0) + q_x(1), 1);
                n_angle_q  <= shift_left(resize(shift_right(q_theta(1) + q_theta(0), 1) - to_signed(g_THETAS/2, q_theta(0)'length), g_TOP_BITS + g_BOT_BITS), g_BOT_BITS);
                n_state <= s_CALC1;

            when s_CALC1 =>
                -- Calculate steering   
                n_steering <= resize(shift_right(q_offset_q * g_OFFSET + q_angle_q * g_ANGLE, g_BOT_BITS * 2), n_steering'length);
                n_state <= s_WRITE;

            when s_WRITE =>
                -- Write to FIFO
                if (i_FULL = '0') then
                    n_state <= s_READ;
                    o_WR_EN <= '1';
                end if;

        end case;

    end process state_comb;


end architecture rtl;