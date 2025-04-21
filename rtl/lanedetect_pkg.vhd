library IEEE;
use IEEE.std_logic_1164.all;

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
    
end package lanedetect_pkg;

package body lanedetect_pkg is

end package body lanedetect_pkg;