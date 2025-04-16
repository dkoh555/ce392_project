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
    
end package lanedetect_pkg;

package body lanedetect_pkg is

end package body lanedetect_pkg;