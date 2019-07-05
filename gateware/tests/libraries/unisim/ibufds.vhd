library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity ibufds is
	generic (
		diff_term      : boolean; -- Differential Termination 
		ibuf_low_pwr   : boolean; -- Low power (TRUE) vs. performance (FALSE)
		iostandard     : string
		);
	port (
		o  : out std_logic; -- Clock buffer output
		i  : in  std_logic; -- Diff_p clock buffer input (connect directly to top-level port)
		ib : in  std_logic  -- Diff_n clock buffer input (connect directly to top-level port)
	    );
end entity;

architecture behavioral of ibufds is
begin
	o <= not i;
end architecture;
