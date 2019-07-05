library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tdc is 
    generic (
      data_buffer_depth : natural := 4
    );
    port (
      rst_i         : in  std_logic;
      clk_000_i     : in  std_logic;
      clk_090_i     : in  std_logic;
      clk_180_i     : in  std_logic;
      clk_270_i     : in  std_logic;

      async_i       : in  std_logic;

      -- fifo output interface
      empty_o       : out std_logic;  
      pop_i         :  in std_logic;  
      data_o        : out std_logic_vector(31 downto 0);

      -- led indicator
      led_o         : out std_logic
    );
end entity;

architecture rtl of tdc is

  signal async_1_000, async_2_000, sync_000 : std_logic := '0';
  signal async_1_090, async_2_090, sync_090 : std_logic := '0';
  signal async_1_180, async_2_180, sync_180 : std_logic := '0';
  signal async_1_270, async_2_270, sync_270 : std_logic := '0';


  signal n_async_i                                : std_logic := '0';
  signal n_async_1_000, n_async_2_000, n_sync_000 : std_logic := '0';
  signal n_async_1_090, n_async_2_090, n_sync_090 : std_logic := '0';
  signal n_async_1_180, n_async_2_180, n_sync_180 : std_logic := '0';
  signal n_async_1_270, n_async_2_270, n_sync_270 : std_logic := '0';


  signal sample, sample_old  : std_logic_vector(7 downto 0) := (others => '0');
  signal push                : std_logic := '0';
  signal full                : std_logic;

  signal buffer_input_data   : std_logic_vector(31 downto 0) := (others => '0');
  signal buffer_push         : std_logic := '0';
  signal buffer_full         : std_logic := '0';

  signal time_counter        : unsigned(23 downto 0) := (others => '0');
  --signal sequence_counter    : unsigned( 3 downto 0) := (others => '0');

  signal led_counter         : unsigned(21 downto 0) := (others => '0');
  signal led_state           : std_logic := '0';
begin

  n_async_i <= not async_i after 500 ps;

  -- invert the led state
  led_o <= not led_state;

  p_000: process
  begin
    wait until rising_edge(clk_000_i);
    async_1_000  <= async_i;
    async_2_000  <= async_1_000;
    sync_000     <= async_2_000;

    n_async_1_000  <= n_async_i after 500 ps;
    n_async_2_000  <= n_async_1_000;
    n_sync_000     <= n_async_2_000;
    -- 90 --------------------------------------
    async_2_090  <= async_1_090;
    sync_090     <= async_2_090;
    n_async_2_090  <= n_async_1_090;
    n_sync_090     <= n_async_2_090;
    --180 --------------------------------------
    sync_180     <= async_2_180;
    n_sync_180     <= n_async_2_180;
    --270 --------------------------------------
  end process;

  p_090: process
  begin
    wait until rising_edge(clk_090_i);
    async_1_090  <= async_i;
    n_async_1_090  <= n_async_i after 500 ps;
    --180 --------------------------------------
    async_2_180  <= async_1_180;
    n_async_2_180  <= n_async_1_180;
    --270 --------------------------------------
    sync_270     <= async_2_270;
    n_sync_270     <= n_async_2_270;
  end process;

  p_180: process
  begin
    wait until rising_edge(clk_180_i);
    async_1_180  <= async_i;
    n_async_1_180  <= n_async_i after 500 ps;
    --270 --------------------------------------
    async_2_270  <= async_1_270;
    n_async_2_270  <= n_async_1_270;
  end process;

  p_270: process
  begin
    wait until rising_edge(clk_270_i);
    async_1_270  <= async_i;
    n_async_1_270  <= n_async_i after 500 ps;
  end process;

  p_sample: process
  begin
    wait until rising_edge(clk_000_i);

    if rst_i = '1' then
      buffer_input_data  <= (others => '0');
      buffer_push        <= '0';
      time_counter       <= (others => '0');
      if async_1_000 = '0' then
        sample_old   <= "10101010";
        sample       <= "10101010";
      else
        sample_old   <= "01010101";
        sample       <= "01010101";
      end if;        
    else 
      time_counter <= time_counter + 1;

      sample(0) <= sync_270;
      sample(1) <= n_sync_270;
      sample(2) <= sync_180;
      sample(3) <= n_sync_180;
      sample(4) <= sync_090;
      sample(5) <= n_sync_090;
      sample(6) <= sync_000;
      sample(7) <= n_sync_000;
      sample_old <= sample;

      buffer_push       <= '0';
      if  (  (sample_old /= sample) and 
             ((sample /= x"55" and sample /= x"aa") or (sample(7) = sample_old(0))) 
          ) or (time_counter = 0) then
            if buffer_full = '0' then
              buffer_push       <= '1';
              buffer_input_data <= std_logic_vector(time_counter) &
                                   (not (sample xor "01010101"));
                                -- ^^ this has to be negated here because negating the async input
                                --      will destroy the subsampling between clocks which relys on 
                                --      the delay of one inverter. If the input is inverted than
                                --      the optimizer will just cancel the dual inversion and the subsampling
                                --      is reversed. Also the led_o has to be inverted.
            else 
              -- buffer is full... but we have something to write... data will be dropped
              -- do something reasonable here, e.g. increment error count 
            end if;
            --sequence_counter <= sequence_counter + 1;
      end if;
    end if;

  end process;

  led_state_p: process
  begin
    wait until rising_edge(clk_000_i);

    if led_counter = 0 then  
      if led_state /= n_sync_000 then 
        led_state <= n_sync_000;
        led_counter <= led_counter - 1;
      end if;
    else
      led_counter <= led_counter - 1;
    end if;
  end process;


  buffer_fifo: entity work.guarded_fifo
  generic map (
    depth       => data_buffer_depth,
    bit_width   => 32,
    default_out => 'U'
  )
  port map(
    clk_i   => clk_000_i,
    rst_i   => rst_i,
    push_i  => buffer_push,
    pop_i   => pop_i,
    full_o  => buffer_full,
    empty_o => empty_o,
    data_i  => buffer_input_data,
    data_o  => data_o
    );



end architecture;
