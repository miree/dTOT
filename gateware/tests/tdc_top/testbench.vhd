library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


entity testbench is
end entity;

architecture simulation of testbench is
  constant clk_period : time := 83.333333 ns;
  signal clk          : std_logic := '0';
  signal rst          : std_logic := '1';

  signal led          : std_logic := '0';

  signal input_data   : std_logic_vector(7 downto 0) := (others => '0');
  signal adbus_io     : std_logic_vector(7 downto 0);
  signal n_rxf_i      : std_logic := '1';
  signal n_txe_i      : std_logic := '0';
  signal n_rd_o       : std_logic := '0';
  signal n_wr_o       : std_logic := '0';
  signal n_siwu_o     : std_logic := '0';
  signal n_oe_o       : std_logic := '0';

  signal async_input  : std_logic_vector(3 downto 0) := (others => '0');

begin
  -- generate clk and reset signal
  clk <= not clk after clk_period/2;

  -- instantiate device under test (dut)
  dut : entity work.tdc_top
    port map (
      clk_i         => clk,
      led_o         => led,
      adbus_io      => adbus_io,
      n_rxf_i       => n_rxf_i,
      n_txe_i       => n_txe_i,
      n_rd_o        => n_rd_o,
      n_wr_o        => n_wr_o,
      n_siwu_o      => n_siwu_o,
      n_oe_o        => n_oe_o,
      async_input_i => async_input
    );

  -- activate all channels
  enable_channels : process
  begin
    for i in 1 to 30 loop
      wait until rising_edge(clk);
    end loop;
    n_rxf_i <= '0';
    input_data <= x"ff";
    wait until rising_edge(n_rd_o);
    n_rxf_i <= '1';

    while true loop
      wait until rising_edge(clk);
      input_data <= std_logic_vector(unsigned(input_data) + 1);
    end loop;

  end process;



  adbus_io <= input_data when n_rxf_i = '0' else (others => 'Z');

  --async_input(0) <= not input_data(5) after 3.300 ns;
  --async_input(1) <= not input_data(5) after 3.300 ns;
  --async_input(2) <= not input_data(5) after 3.300 ns;
  --async_input(3) <= not input_data(5) after 3.300 ns;

  gen_input : process
  begin
    wait for 5 us;
    async_input(0) <= '1';
    wait for 12 ns;
    async_input(0) <= '0';
  end process;


end architecture;