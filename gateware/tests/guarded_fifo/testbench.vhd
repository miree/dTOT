library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity testbench is
end entity;

architecture simulation of testbench is
  -- clock generation
  constant clk_period      : time := 20  ns;
  -- signals to connect to fifo
  constant depth     : integer := 4;  -- the number of fifo entries is 2**depth
  constant bit_width : integer := 32; -- number of bits in each entry
  signal clk         : std_logic := '1';
  signal rst         : std_logic := '1';
  signal data_i, data_o : std_logic_vector ( bit_width-1 downto 0 );
  signal push, pop   : std_logic := '0';
  signal full, empty : std_logic;
begin

  -- instantiate device under test (dut)
  dut : entity work.guarded_fifo
    generic map (
      depth     => depth ,
      bit_width => bit_width
    )
    port map (
      clk_i   => clk,
      rst_i   => rst,
      data_i  => data_i,
      data_o  => data_o,
      push_i  => push,
      pop_i   => pop,
      full_o  => full,
      empty_o => empty
    );

  -- generate clk and reset signal
  clk <= not clk after clk_period/2;
  rst <= '0' after clk_period*20;


  tests: process
  begin
    wait until rst = '0';
    wait until rising_edge(clk);

    -- in the beginning the fifo is empty
    assert full  = '0' ;
    assert empty = '1' ;

    -- fill the fifo until it is full
    for n in 1 to 2**depth loop
      wait until rising_edge(clk);
      data_i <= std_logic_vector(to_unsigned(n, bit_width));
      push <= '1';
      -- after the first insertion empty should go down
      if n > 2 then
        assert empty = '0' ;
      end if;
    end loop;

    wait until rising_edge(clk);
    push <= '0';

    -- now the fifo should be full
    wait until rising_edge(clk);
    assert full  = '1' ;
    assert empty = '0' ;

    -- empty the fifo until it is empty
    pop <= '1';
    for n in 1 to 2**depth loop
      wait until rising_edge(clk);
      -- after the first pop full should go down
      if n > 1 then
        assert full = '0' ;
        assert data_o = std_logic_vector(to_unsigned(n-1, bit_width)); 
      end if;
    end loop;

    wait until rising_edge(clk);
    -- now the fifo should be empty
    assert empty = '1';
    assert full  = '0' ;
    pop <= '0';

    -- empty the fifo even further and observe if empty stays '1'
    wait until rising_edge(clk);
    pop <= '1';
    for n in 1 to 2**depth loop
      wait until rising_edge(clk);
      assert empty = '1';
      assert full  = '0';
    end loop;
    pop <= '0';

  end process;


end architecture;