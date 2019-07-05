library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity testbench is
end entity;

architecture simulation of testbench is
  -- clock generation
  constant clk_period      : time := 20  ns;
  -- signals to connect to fifo
  signal clk         : std_logic := '1';
  signal rst         : std_logic := '1';
  signal clk_quad_000: std_logic := '0';
  signal clk_quad_090: std_logic := '0';
  signal clk_quad_180: std_logic := '0';
  signal clk_quad_270: std_logic := '0';
begin

  -- generate clk and reset signal
  clk <= not clk after clk_period/2;
  rst <= '0' after clk_period*20;

  dut : entity work.tdc_clk_gen
    port map (  
      clk12_i => clk,
      clk_quad_000_o => clk_quad_000,
      clk_quad_090_o => clk_quad_090,
      clk_quad_180_o => clk_quad_180,
      clk_quad_270_o => clk_quad_270
    );

end architecture;
