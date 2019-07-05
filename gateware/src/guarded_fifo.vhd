library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity guarded_fifo is
  generic (
    depth     : integer;
    bit_width : integer;
	 default_out: std_logic := 'U'
  );
  port (
    clk_i , rst_i   : in std_logic;
    push_i, pop_i   : in  std_logic;
    full_o, empty_o : out std_logic;
    data_i          : in  std_logic_vector ( bit_width-1 downto 0 );
    data_o          : out std_logic_vector ( bit_width-1 downto 0 )
  );
end entity;

-- Take a non-guarded fifo and take control over the
-- push and pull lines and prevent illegal operations. 
-- Forward the full and empty signals.
architecture rtl of guarded_fifo is
  signal push, pop, full, empty   : std_logic;
begin
  fifo : entity work.fifo 
  generic map (
    depth     => depth,
    bit_width => bit_width,
	 default_out => default_out
  )
  port map (
    clk_i   => clk_i,
    rst_i   => rst_i,
    push_i  => push,
    pop_i   => pop,
    full_o  => full,
    empty_o => empty,
    data_i  => data_i,
    data_o  => data_o
  );

  full_o  <= full;
  empty_o <= empty;

  push    <= push_i and not full;
  pop     <= pop_i  and not empty;
  
end architecture;
