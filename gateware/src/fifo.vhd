library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity fifo is 
  generic (
    depth       : integer;
    bit_width   : integer;
    default_out : std_logic := 'U'
  );
  port ( 
    clk_i , rst_i   : in  std_logic;
    push_i, pop_i   : in  std_logic;
    full_o, empty_o : out std_logic;
    data_i          : in  std_logic_vector ( bit_width-1 downto 0 );
    data_o          : out std_logic_vector ( bit_width-1 downto 0 )
  ); 
end entity;

architecture rtl of fifo is
  -- calculate the number of words from 
  --   the depth (which is like the address width)
  constant number_of_words : integer := 2**depth;
  -- define data type of the storage array
  type fifo_data_array is array ( 0 to number_of_words-1) 
            of std_logic_vector ( bit_width-1 downto 0);
  -- define the storage array          
  signal fifo_data : fifo_data_array;
  -- read and write index pointers
  --  give them one bit more to check for overflow
  --  by comparing the most significant bit
  signal w_idx     : unsigned ( depth downto 0 ) := (others => '0');
  signal r_idx     : unsigned ( depth downto 0 ) := (others => '0');

  signal msb_xor       : std_logic;
  signal empty_or_full : boolean;
  signal empty         : std_logic := '1';
  signal full          : std_logic := '0';
  --signal q             : std_logic_vector ( bit_width-1 downto 0 );

begin
  main: process
  begin
    wait until rising_edge(clk_i);
    if rst_i = '1' then 
      w_idx   <= (others => '0'); 
      r_idx   <= (others => '0');
    else
      -- write
      w_idx <= w_idx;
      if push_i = '1' then
        fifo_data(to_integer(w_idx(depth-1 downto 0))) <= data_i;
        w_idx <= w_idx + 1;
      end if;
      -- read
      r_idx <= r_idx;
      data_o <= (others => default_out);
      if pop_i = '1' then
        data_o <= fifo_data(to_integer(r_idx(depth-1 downto 0)));
        r_idx <= r_idx + 1; 
      end if;

    end if;
  end process;

  ---- If read and write index up to (not including) the most significant bit are identical,
  ----  the fifo is either empty or full.
  ---- The xor of the most significant bit decides if the fifo is full or empty.
  msb_xor       <= (r_idx(depth) xor w_idx(depth));
  empty_or_full <= r_idx(depth-1 downto 0) = w_idx(depth-1 downto 0);

  full_o     <=     msb_xor when empty_or_full else '0';
  empty_o    <= not msb_xor when empty_or_full else '0';

end architecture;
