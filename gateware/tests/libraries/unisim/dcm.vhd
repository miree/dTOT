library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


entity dcm is
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
      rst       : in  std_logic := '0'
    );
end entity;

architecture behavioral of dcm is
begin


  p_four_phases: process
    variable clk_first, clk_second, period : time := 0 ns;
  begin
    locked <= '0';

    --wait until rst = '0';

    clk0   <= '0';
    clk90  <= '0';
    clk180 <= '0';
    clk270 <= '0';

    wait until rising_edge(clkin);
    wait until rising_edge(clkin);
    wait until rising_edge(clkin);
    clk_first := now;
    report time'image(clk_first);
    wait until rising_edge(clkin);
    clk_second := now;    
    report time'image(clk_second);

    period := (clk_second - clk_first)/4;
    report time'image(period);
    report integer'image(clkfx_multiply);
    report integer'image(clkfx_divide);


    clk0   <= '1';
    clk90  <= '0';
    clk180 <= '0';
    clk270 <= '0';
    wait for period;

    locked <= '1';


    while true loop

      clk0   <= '1';
      clk90  <= '1';
      clk180 <= '0';
      clk270 <= '0';
      wait for period;

      clk0   <= '0';
      clk90  <= '1';
      clk180 <= '1';
      clk270 <= '0';
      wait for period;

      clk0   <= '0';
      clk90  <= '0';
      clk180 <= '1';
      clk270 <= '1';
      wait for period;

      clk0   <= '1';
      clk90  <= '0';
      clk180 <= '0';
      clk270 <= '1';
      wait for period;

    end loop;     


  end process;


  p_multiply: process
    variable clk_first, clk_second, period : time := 0 ns;
  begin

   -- wait until rst = '0';

    clkfx    <= '0';
    clkfx180 <= '0';

    wait until rising_edge(clkin);
    wait until rising_edge(clkin);
    wait until rising_edge(clkin);
    clk_first := now;
    report time'image(clk_first);
    wait until rising_edge(clkin);
    clk_second := now;    
    report time'image(clk_second);

    period := (clk_second - clk_first)/clkfx_multiply*clkfx_divide/2;
    report time'image(period);
    report integer'image(clkfx_multiply);
    report integer'image(clkfx_divide);


    clkfx   <= '1';
    wait for period;


    while true loop
      clkfx    <= '0';
      clkfx180 <= '1';
      wait for period;

      clkfx    <= '1';
      clkfx180 <= '0';
      wait for period;

    end loop;     


  end process;



end architecture;
