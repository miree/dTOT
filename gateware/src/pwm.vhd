library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity pwm is 
    generic (
        bit_width : natural
      );
    port (
      rst_i       : in  std_logic;
      clk_i       : in  std_logic;
      threshold_i : in  unsigned(bit_width-1 downto 0);

      -- fifo output interface
      pwm_o        : out std_logic
    );
end entity;

architecture rtl of pwm is
  signal counter : unsigned(bit_width-1 downto 0) := (others => '0');
begin

  process
  begin
    wait until rising_edge(clk_i);
    if rst_i = '1' then
      counter <= (others => '0');
    else
      counter <= counter + 1;
    end if;
  end process;

  pwm_o <= '1' when threshold_i >= counter else '0'; 

end architecture;

