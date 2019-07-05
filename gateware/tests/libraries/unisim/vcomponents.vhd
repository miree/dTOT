library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package vcomponents is
  component dcm 
    generic (
      clkfx_divide          : integer;
      clkfx_multiply        : integer;
      clkin_divide_by_2     : boolean;
      clkout_phase_shift    : string;
      clk_feedback          : string;
      deskew_adjust         : string;
      dfs_frequency_mode    : string;
      duty_cycle_correction : boolean;
      factory_jf            : std_logic_vector(15 downto 0);
      phase_shift           : integer;
      startup_wait          : boolean
    );
    port (
      clk0      : out std_logic;
      clk180    : out std_logic;
      clk270    : out std_logic;
      clk2x     : out std_logic;
      clk2x180  : out std_logic;
      clk90     : out std_logic;
      clkdv     : out std_logic;
      clkfx     : out std_logic;
      clkfx180  : out std_logic;
      locked    : out std_logic;
      psdone    : out std_logic;
      status    : out std_logic;
      clkfb     : out std_logic;
      clkin     : in  std_logic;
      psclk     : out std_logic;
      psen      : out std_logic;
      psincdec  : out std_logic;
      rst       : in  std_logic
    );
  end component; 


  component ibufds 
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
  end component;


end package; 

