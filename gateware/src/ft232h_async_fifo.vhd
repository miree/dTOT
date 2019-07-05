library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.log2;
use ieee.math_real.ceil;

entity ft232h_async_fifo is
  port (
    clk_i , rst_i : in std_logic;
    push_i        : in  std_logic;
    full_o        : out std_logic;
    data_i        : in  std_logic_vector (7 downto 0);

    registers_o   : out std_logic_vector (63 downto 0);

    n_rxf_i       : in    std_logic;
    n_txe_i       : in    std_logic;
    n_rd_o        : out   std_logic;
    n_wr_o        : out   std_logic;
    n_siwu_o      : out   std_logic;
    n_oe_o        : out   std_logic;
    adbus_io      : inout std_logic_vector(7 downto 0)
  );
end entity;

architecture rtl of ft232h_async_fifo is

  signal n_rxf_sync      : std_logic;
  signal n_txe_sync      : std_logic;

  type state_t is (s_idle, 
                   s_read, 
                   s_write, 
                   s_done);
  signal state            : state_t;

  signal countdown        : unsigned(3 downto 0);
  signal data_valid       : std_logic := '0';
  signal adbus_i, adbus_o : std_logic_vector(7 downto 0);
  signal adbus_inout      : std_logic := '1'; -- '1' is in; '0' is out
  signal dataregister     : std_logic_vector(7 downto 0);

  signal register_selector : std_logic_vector(7 downto 0);
  signal registers         : std_logic_vector(63 downto 0) := (others => '0'); 
                                                            -- 4 12 bit registers glued together
                                                            -- ch0_threshold: [11 downto  0]
                                                            -- ch1_threshold: [23 downto 12]
                                                            -- ch2_threshold: [35 downto 24]
                                                            -- ch3_threshold: [47 downto 36]
                                                            -- ch0_TDCactive: [60]
                                                            -- ch1_TDCactive: [61]
                                                            -- ch2_TDCactive: [62]
                                                            -- ch3_TDCactive: [63]

begin

  registers_o <= registers;

  process
  begin
    wait until rising_edge(clk_i);
    if rst_i = '1' then
      state <= s_idle;
      n_wr_o   <= '1';
      n_rd_o   <= '1';
      adbus_inout <= '0'; -- switch to output on reset
      dataregister <= (others => '1');
      data_valid <= '0';
      countdown <= (others => '0');
      registers <= (others => '0');
    else

      -- input interface
      if data_valid = '0' and push_i = '1' then 
        dataregister <= data_i;
        data_valid   <= '1';
      end if;

      -- sync input signals
      n_rxf_sync <= n_rxf_i;
      n_txe_sync <= n_txe_i;

      state <= state;
      case state is
        when s_idle =>
          if countdown /= 0 then
            countdown <= countdown - 1;
          elsif n_rxf_sync = '0' then
            n_rd_o    <= '0';
            countdown <= to_unsigned(15,4); 
            state     <= s_read;
            adbus_inout <= '1'; 
          elsif data_valid = '1' then
            countdown <= to_unsigned(15,4); 
            state     <= s_write;
          end if;
        when s_read =>
          if countdown /= 0 then
            countdown <= countdown - 1;
          else 
            registers( 4*to_integer(unsigned(adbus_i(7 downto 4)))+3 
            	downto 4*to_integer(unsigned(adbus_i(7 downto 4))) ) <=  adbus_i(3 downto 0);
            --dataregister <= adbus_i;
            n_rd_o    <= '1';
            state     <= s_idle;
            countdown <= to_unsigned(15,4);
          end if;
        when s_write =>
          if countdown /= 0 then
            countdown <= countdown - 1;
            if countdown = 14 then
              adbus_o   <= dataregister;
            end if;
          elsif n_txe_sync = '0' then
            adbus_inout <= '0'; 
            n_wr_o    <= '0'; 
            countdown <= to_unsigned(15,4); 
            state     <= s_done;
          end if; 
        when s_done =>
          if countdown /= 0 then
            countdown <= countdown - 1;
          else 
            n_wr_o     <= '1';
            state      <= s_idle;
            countdown  <= to_unsigned(15,4); 
            data_valid <= '0';
          end if;
      end case;
    end if;

  end process;

  full_o <= data_valid;

  n_siwu_o <= '1';
  n_oe_o   <= '1';

  adbus_i  <= adbus_io when adbus_inout = '1' else (others => 'Z');
  adbus_io <= adbus_o  when adbus_inout = '0' else (others => 'Z');


end architecture;
