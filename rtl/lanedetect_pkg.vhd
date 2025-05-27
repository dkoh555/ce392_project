library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

--Additional standard or custom libraries go here
package lanedetect_pkg is

	type gaussian_t is array (0 to 4, 0 to 4) of integer;
    constant GAUSSIAN_KERNEL : gaussian_t := (
        ( 1,  4,  6,  4, 1 ),
        ( 4, 16, 24, 16, 4 ),
        ( 6, 24, 36, 24, 6 ),
        ( 4, 16, 24, 16, 4 ),
        ( 1,  4,  6,  4, 1 )
    );

    type sobel_t is array (2 downto 0, 2 downto 0) of integer;
    constant SOBEL_H_KERNEL : sobel_t := (
        ( -1,  0,  1 ),
        ( -2,  0,  2 ),
        ( -1,  0,  1 )
    );
    constant SOBEL_V_KERNEL : sobel_t := (
        ( -1,  -2,  -1 ),
        (  0,   0,   0 ),
        (  1,   2,   1 )
    );

    type hough_table_t is array (0 to 199) of signed(15 downto 0);
    constant SIN_TABLE : hough_table_t := (to_signed(16#0#, 16), to_signed(16#11#, 16), to_signed(16#23#, 16), to_signed(16#35#, 16), to_signed(16#47#, 16), to_signed(16#59#, 16), to_signed(16#6b#, 16), to_signed(16#7c#, 16), to_signed(16#8e#, 16), to_signed(16#a0#, 16), to_signed(16#b1#, 16), to_signed(16#c3#, 16), to_signed(16#d4#, 16), to_signed(16#e6#, 16), to_signed(16#f7#, 16), to_signed(16#109#, 16), to_signed(16#11a#, 16), to_signed(16#12b#, 16), to_signed(16#13c#, 16), to_signed(16#14d#, 16), to_signed(16#15e#, 16), to_signed(16#16e#, 16), to_signed(16#17f#, 16), to_signed(16#190#, 16), to_signed(16#1a0#, 16), to_signed(16#1b0#, 16), to_signed(16#1c0#, 16), to_signed(16#1d0#, 16), to_signed(16#1e0#, 16), to_signed(16#1f0#, 16), to_signed(16#200#, 16), to_signed(16#20f#, 16), to_signed(16#21e#, 16), to_signed(16#22d#, 16), to_signed(16#23c#, 16), to_signed(16#24b#, 16), to_signed(16#259#, 16), to_signed(16#268#, 16), to_signed(16#276#, 16), to_signed(16#284#, 16), to_signed(16#292#, 16), to_signed(16#29f#, 16), to_signed(16#2ad#, 16), to_signed(16#2ba#, 16), to_signed(16#2c7#, 16), to_signed(16#2d4#, 16), to_signed(16#2e0#, 16), to_signed(16#2ec#, 16), to_signed(16#2f8#, 16), to_signed(16#304#, 16), to_signed(16#310#, 16), to_signed(16#31b#, 16), to_signed(16#326#, 16), to_signed(16#331#, 16), to_signed(16#33c#, 16), to_signed(16#346#, 16), to_signed(16#350#, 16), to_signed(16#35a#, 16), to_signed(16#364#, 16), to_signed(16#36d#, 16), to_signed(16#376#, 16), to_signed(16#37f#, 16), to_signed(16#388#, 16), to_signed(16#390#, 16), to_signed(16#398#, 16), to_signed(16#3a0#, 16), to_signed(16#3a7#, 16), to_signed(16#3ae#, 16), to_signed(16#3b5#, 16), to_signed(16#3bb#, 16), to_signed(16#3c2#, 16), to_signed(16#3c8#, 16), to_signed(16#3cd#, 16), to_signed(16#3d3#, 16), to_signed(16#3d8#, 16), to_signed(16#3dd#, 16), to_signed(16#3e1#, 16), to_signed(16#3e5#, 16), to_signed(16#3e9#, 16), to_signed(16#3ed#, 16), to_signed(16#3f0#, 16), to_signed(16#3f3#, 16), to_signed(16#3f6#, 16), to_signed(16#3f8#, 16), to_signed(16#3fa#, 16), to_signed(16#3fc#, 16), to_signed(16#3fd#, 16), to_signed(16#3fe#, 16), to_signed(16#3ff#, 16), to_signed(16#3ff#, 16), to_signed(16#400#, 16), to_signed(16#3ff#, 16), to_signed(16#3ff#, 16), to_signed(16#3fe#, 16), to_signed(16#3fd#, 16), to_signed(16#3fc#, 16), to_signed(16#3fa#, 16), to_signed(16#3f8#, 16), to_signed(16#3f6#, 16), to_signed(16#3f3#, 16), to_signed(16#3f0#, 16), to_signed(16#3ed#, 16), to_signed(16#3e9#, 16), to_signed(16#3e5#, 16), to_signed(16#3e1#, 16), to_signed(16#3dd#, 16), to_signed(16#3d8#, 16), to_signed(16#3d3#, 16), to_signed(16#3cd#, 16), to_signed(16#3c8#, 16), to_signed(16#3c2#, 16), to_signed(16#3bb#, 16), to_signed(16#3b5#, 16), to_signed(16#3ae#, 16), to_signed(16#3a7#, 16), to_signed(16#3a0#, 16), to_signed(16#398#, 16), to_signed(16#390#, 16), to_signed(16#388#, 16), to_signed(16#37f#, 16), to_signed(16#376#, 16), to_signed(16#36d#, 16), to_signed(16#364#, 16), to_signed(16#35a#, 16), to_signed(16#350#, 16), to_signed(16#346#, 16), to_signed(16#33c#, 16), to_signed(16#331#, 16), to_signed(16#326#, 16), to_signed(16#31b#, 16), to_signed(16#310#, 16), to_signed(16#304#, 16), to_signed(16#2f8#, 16), to_signed(16#2ec#, 16), to_signed(16#2e0#, 16), to_signed(16#2d4#, 16), to_signed(16#2c7#, 16), to_signed(16#2ba#, 16), to_signed(16#2ad#, 16), to_signed(16#29f#, 16), to_signed(16#292#, 16), to_signed(16#284#, 16), to_signed(16#276#, 16), to_signed(16#268#, 16), to_signed(16#259#, 16), to_signed(16#24b#, 16), to_signed(16#23c#, 16), to_signed(16#22d#, 16), to_signed(16#21e#, 16), to_signed(16#20f#, 16), to_signed(16#200#, 16), to_signed(16#1f0#, 16), to_signed(16#1e0#, 16), to_signed(16#1d0#, 16), to_signed(16#1c0#, 16), to_signed(16#1b0#, 16), to_signed(16#1a0#, 16), to_signed(16#190#, 16), to_signed(16#17f#, 16), to_signed(16#16e#, 16), to_signed(16#15e#, 16), to_signed(16#14d#, 16), to_signed(16#13c#, 16), to_signed(16#12b#, 16), to_signed(16#11a#, 16), to_signed(16#109#, 16), to_signed(16#f7#, 16), to_signed(16#e6#, 16), to_signed(16#d4#, 16), to_signed(16#c3#, 16), to_signed(16#b1#, 16), to_signed(16#a0#, 16), to_signed(16#8e#, 16), to_signed(16#7c#, 16), to_signed(16#6b#, 16), to_signed(16#59#, 16), to_signed(16#47#, 16), to_signed(16#35#, 16), to_signed(16#23#, 16), to_signed(16#11#, 16), to_signed(16#0#, 16), to_signed(16#0#, 16), to_signed(16#0#, 16), to_signed(16#0#, 16), to_signed(16#0#, 16), to_signed(16#0#, 16), to_signed(16#0#, 16), to_signed(16#0#, 16), to_signed(16#0#, 16), to_signed(16#0#, 16), to_signed(16#0#, 16), to_signed(16#0#, 16), to_signed(16#0#, 16), to_signed(16#0#, 16), to_signed(16#0#, 16), to_signed(16#0#, 16), to_signed(16#0#, 16), to_signed(16#0#, 16), to_signed(16#0#, 16), to_signed(16#0#, 16));
    constant COS_TABLE : hough_table_t := (to_signed(16#400#, 16), to_signed(16#3ff#, 16), to_signed(16#3ff#, 16), to_signed(16#3fe#, 16), to_signed(16#3fd#, 16), to_signed(16#3fc#, 16), to_signed(16#3fa#, 16), to_signed(16#3f8#, 16), to_signed(16#3f6#, 16), to_signed(16#3f3#, 16), to_signed(16#3f0#, 16), to_signed(16#3ed#, 16), to_signed(16#3e9#, 16), to_signed(16#3e5#, 16), to_signed(16#3e1#, 16), to_signed(16#3dd#, 16), to_signed(16#3d8#, 16), to_signed(16#3d3#, 16), to_signed(16#3cd#, 16), to_signed(16#3c8#, 16), to_signed(16#3c2#, 16), to_signed(16#3bb#, 16), to_signed(16#3b5#, 16), to_signed(16#3ae#, 16), to_signed(16#3a7#, 16), to_signed(16#3a0#, 16), to_signed(16#398#, 16), to_signed(16#390#, 16), to_signed(16#388#, 16), to_signed(16#37f#, 16), to_signed(16#376#, 16), to_signed(16#36d#, 16), to_signed(16#364#, 16), to_signed(16#35a#, 16), to_signed(16#350#, 16), to_signed(16#346#, 16), to_signed(16#33c#, 16), to_signed(16#331#, 16), to_signed(16#326#, 16), to_signed(16#31b#, 16), to_signed(16#310#, 16), to_signed(16#304#, 16), to_signed(16#2f8#, 16), to_signed(16#2ec#, 16), to_signed(16#2e0#, 16), to_signed(16#2d4#, 16), to_signed(16#2c7#, 16), to_signed(16#2ba#, 16), to_signed(16#2ad#, 16), to_signed(16#29f#, 16), to_signed(16#292#, 16), to_signed(16#284#, 16), to_signed(16#276#, 16), to_signed(16#268#, 16), to_signed(16#259#, 16), to_signed(16#24b#, 16), to_signed(16#23c#, 16), to_signed(16#22d#, 16), to_signed(16#21e#, 16), to_signed(16#20f#, 16), to_signed(16#200#, 16), to_signed(16#1f0#, 16), to_signed(16#1e0#, 16), to_signed(16#1d0#, 16), to_signed(16#1c0#, 16), to_signed(16#1b0#, 16), to_signed(16#1a0#, 16), to_signed(16#190#, 16), to_signed(16#17f#, 16), to_signed(16#16e#, 16), to_signed(16#15e#, 16), to_signed(16#14d#, 16), to_signed(16#13c#, 16), to_signed(16#12b#, 16), to_signed(16#11a#, 16), to_signed(16#109#, 16), to_signed(16#f7#, 16), to_signed(16#e6#, 16), to_signed(16#d4#, 16), to_signed(16#c3#, 16), to_signed(16#b1#, 16), to_signed(16#a0#, 16), to_signed(16#8e#, 16), to_signed(16#7c#, 16), to_signed(16#6b#, 16), to_signed(16#59#, 16), to_signed(16#47#, 16), to_signed(16#35#, 16), to_signed(16#23#, 16), to_signed(16#11#, 16), to_signed(16#0#, 16), to_signed(16#ffef#, 16), to_signed(16#ffdd#, 16), to_signed(16#ffcb#, 16), to_signed(16#ffb9#, 16), to_signed(16#ffa7#, 16), to_signed(16#ff95#, 16), to_signed(16#ff84#, 16), to_signed(16#ff72#, 16), to_signed(16#ff60#, 16), to_signed(16#ff4f#, 16), to_signed(16#ff3d#, 16), to_signed(16#ff2c#, 16), to_signed(16#ff1a#, 16), to_signed(16#ff09#, 16), to_signed(16#fef7#, 16), to_signed(16#fee6#, 16), to_signed(16#fed5#, 16), to_signed(16#fec4#, 16), to_signed(16#feb3#, 16), to_signed(16#fea2#, 16), to_signed(16#fe92#, 16), to_signed(16#fe81#, 16), to_signed(16#fe70#, 16), to_signed(16#fe60#, 16), to_signed(16#fe50#, 16), to_signed(16#fe40#, 16), to_signed(16#fe30#, 16), to_signed(16#fe20#, 16), to_signed(16#fe10#, 16), to_signed(16#fe00#, 16), to_signed(16#fdf1#, 16), to_signed(16#fde2#, 16), to_signed(16#fdd3#, 16), to_signed(16#fdc4#, 16), to_signed(16#fdb5#, 16), to_signed(16#fda7#, 16), to_signed(16#fd98#, 16), to_signed(16#fd8a#, 16), to_signed(16#fd7c#, 16), to_signed(16#fd6e#, 16), to_signed(16#fd61#, 16), to_signed(16#fd53#, 16), to_signed(16#fd46#, 16), to_signed(16#fd39#, 16), to_signed(16#fd2c#, 16), to_signed(16#fd20#, 16), to_signed(16#fd14#, 16), to_signed(16#fd08#, 16), to_signed(16#fcfc#, 16), to_signed(16#fcf0#, 16), to_signed(16#fce5#, 16), to_signed(16#fcda#, 16), to_signed(16#fccf#, 16), to_signed(16#fcc4#, 16), to_signed(16#fcba#, 16), to_signed(16#fcb0#, 16), to_signed(16#fca6#, 16), to_signed(16#fc9c#, 16), to_signed(16#fc93#, 16), to_signed(16#fc8a#, 16), to_signed(16#fc81#, 16), to_signed(16#fc78#, 16), to_signed(16#fc70#, 16), to_signed(16#fc68#, 16), to_signed(16#fc60#, 16), to_signed(16#fc59#, 16), to_signed(16#fc52#, 16), to_signed(16#fc4b#, 16), to_signed(16#fc45#, 16), to_signed(16#fc3e#, 16), to_signed(16#fc38#, 16), to_signed(16#fc33#, 16), to_signed(16#fc2d#, 16), to_signed(16#fc28#, 16), to_signed(16#fc23#, 16), to_signed(16#fc1f#, 16), to_signed(16#fc1b#, 16), to_signed(16#fc17#, 16), to_signed(16#fc13#, 16), to_signed(16#fc10#, 16), to_signed(16#fc0d#, 16), to_signed(16#fc0a#, 16), to_signed(16#fc08#, 16), to_signed(16#fc06#, 16), to_signed(16#fc04#, 16), to_signed(16#fc03#, 16), to_signed(16#fc02#, 16), to_signed(16#fc01#, 16), to_signed(16#fc01#, 16), to_signed(16#0#, 16), to_signed(16#0#, 16), to_signed(16#0#, 16), to_signed(16#0#, 16), to_signed(16#0#, 16), to_signed(16#0#, 16), to_signed(16#0#, 16), to_signed(16#0#, 16), to_signed(16#0#, 16), to_signed(16#0#, 16), to_signed(16#0#, 16), to_signed(16#0#, 16), to_signed(16#0#, 16), to_signed(16#0#, 16), to_signed(16#0#, 16), to_signed(16#0#, 16), to_signed(16#0#, 16), to_signed(16#0#, 16), to_signed(16#0#, 16), to_signed(16#0#, 16));
    
    constant TOP_BITS : integer := 8;
    constant BOT_BITS : integer := 10;

    function DEQUANTIZE(
        value : signed(TOP_BITS + BOT_BITS - 1 downto 0)
    ) return signed;

    function ABS_SIGNED(
        x : signed
    ) return signed;

    function FIND_MSB(
        value : signed
    ) return integer;

    function CLOG2(
        value : integer
    ) return integer;

end package lanedetect_pkg;

package body lanedetect_pkg is

    function CLOG2(
        value : integer
    ) return integer is
        variable result : integer := 0;
        variable val    : integer := value - 1;
    begin
        if value <= 1 then
            return 0;
        end if;
    
        while val > 0 loop
            val := val / 2;
            result := result + 1;
        end loop;

        return result;
    end function;

    function FIND_MSB(
        value : signed
    ) return integer is
    begin
        for i in value'range loop
            if value(i) = '1' then
                return i;
            end if;
        end loop;
        return 0;
    end function;

    function ABS_SIGNED(
        x : signed
    ) return signed is
    begin
        if x < 0 then
            return -x;
        else
            return x;
        end if;
    end function;

    function DEQUANTIZE(
        value : signed(TOP_BITS + BOT_BITS - 1 downto 0)
    ) return signed is
        constant THRESHOLD : signed := to_signed(2 ** BOT_BITS, TOP_BITS + BOT_BITS);
        variable temp : signed(TOP_BITS + BOT_BITS - 1 downto 0);
        variable shifted_temp : signed(TOP_BITS + BOT_BITS - 1 downto 0);
        variable return_value : signed(TOP_BITS + BOT_BITS - 1 downto 0);
    begin
        -- Take absolute value manually
        if value(value'left) = '1' then
            temp := -value;
        else
            temp := value;
        end if;
    
        -- If value is less than the threshold
        if temp < THRESHOLD then
            for i in return_value'range loop
                return_value(i) := '0';
            end loop;
            return return_value;
        else
            -- Shift right logically
            shifted_temp := shift_right(temp, BOT_BITS);
            -- Restore sign manually
            if value(value'left) = '1' then
                return_value := -shifted_temp;
            else
                return_value := shifted_temp;
            end if;
    
            return return_value;
        end if;
    end function;

end package body lanedetect_pkg;