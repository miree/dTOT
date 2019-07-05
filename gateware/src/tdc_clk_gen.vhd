library ieee;
use ieee.std_logic_1164.ALL;
use ieee.numeric_std.all;

library unisim;
use unisim.VComponents.all;

entity tdc_clk_gen is
    Port (  clk12_i      : in  std_logic; -- 12MHz
			clk_quad_000_o : out std_logic;
			clk_quad_090_o : out std_logic;
			clk_quad_180_o : out std_logic;
			clk_quad_270_o : out std_logic
           );
end entity;

architecture rtl of tdc_clk_gen is
	signal clk_intermediate, clk_fast, clk_i  : std_logic;
	signal dcm_intermediate_locked            : std_logic := '1';
	signal rst_fast                           : std_logic;
	signal dcm_fast_locked                    : std_logic := '1';
	signal rst_fourphases                     : std_logic;
	signal rst_low                            : std_logic := '0';
begin

	clk_i <= clk12_i;

   -- TDC clock from 12 MHz input
	dcm_sp_inst_intermediate : dcm
	generic map (
		clkfx_divide          => 12,  --Wertepaare die gehen:  1   ,   1
		clkfx_multiply        => 25, --                      10   ,  20
		clkin_divide_by_2     => false,
		clkout_phase_shift    => "none",
		clk_feedback          => "1x",
		deskew_adjust         => "system_synchronous",
		dfs_frequency_mode    => "low",
		duty_cycle_correction => true,
		factory_jf            => x"8080",
		phase_shift           => 0,
		startup_wait          => false)
	port map (
		clk0	 => open,
		clk180 	 => open,
		clk270 	 => open,
		clk2x	 => open,
		clk2x180 => open,
		clk90 	 => open,
		clkdv 	 => open,
		clkfx 	 => clk_intermediate, 
		clkfx180 => open,
		locked 	 => dcm_intermediate_locked,
		psdone 	 => open,
		status 	 => open,
		clkfb 	 => open,
		clkin 	 => clk_i,
		psclk 	 => open,
		psen 	 => open,
		psincdec => open,
		rst 	 => rst_low
	);

	dcm_sp_inst_fast : dcm
	generic map (
		clkfx_divide          => 1, -- Wertepaare die gehen:  2   ,    24 
		clkfx_multiply        => 5, --                        4   ,    20
		clkin_divide_by_2     => false,
		clkout_phase_shift    => "none",
		clk_feedback          => "1x",
		deskew_adjust         => "system_synchronous",
		dfs_frequency_mode    => "low",
		duty_cycle_correction => true,
		factory_jf            => x"8080",
		phase_shift           => 0,
		startup_wait          => false)
	port map (
		clk0	 => open,
		clk180 	 => open,
		clk270 	 => open,
		clk2x	 => open,
		clk2x180 => open,
		clk90 	 => open,
		clkdv 	 => open,
		clkfx 	 => clk_fast, 
		clkfx180 => open,
		locked 	 => dcm_fast_locked,
		psdone 	 => open,
		status 	 => open,
		clkfb 	 => open,
		clkin 	 => clk_intermediate,
		psclk 	 => open,
		psen 	 => open,
		psincdec => open,
		rst 	 => rst_fast
	);

	rst_fast <= not dcm_intermediate_locked;

	dcm_sp_inst_fourphases : dcm
	generic map (
		clkfx_divide          => 2, --  
		clkfx_multiply        => 2, -- 
		clkin_divide_by_2     => false,
		clkout_phase_shift    => "none",
		clk_feedback          => "1x",
		deskew_adjust         => "system_synchronous",
		dfs_frequency_mode    => "low",
		duty_cycle_correction => true,
		factory_jf            => x"8080",
		phase_shift           => 0,
		startup_wait          => false)
	port map (
		clk0	 => clk_quad_000_o,
		clk180 	 => clk_quad_180_o,
		clk270 	 => clk_quad_270_o,
		clk2x	 => open,
		clk2x180 => open,
		clk90 	 => clk_quad_090_o,
		clkdv 	 => open,
		clkfx 	 => open, 
		clkfx180 => open,
		locked 	 => open,
		psdone 	 => open,
		status 	 => open,
		clkfb 	 => open,
		clkin 	 => clk_fast,
		psclk 	 => open,
		psen 	 => open,
		psincdec => open,
		rst 	 => rst_fourphases
	);
	rst_fourphases <= not dcm_fast_locked;

end architecture;

