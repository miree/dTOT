
library ieee;
use ieee.std_logic_1164.ALL;
use ieee.numeric_std.all;

-- for differential input
--library unisim;
--use unisim.vcomponents.all;

entity tdc_top is
	generic (
		data_buffer_depth  : natural := 12;
		n_channels         : natural := 4
	);
    port (  
		clk_i     : in    std_logic; -- 12MHz
		led_o     : out   std_logic;

		-- TDC input 
		-- differential input
		--async_input_p: in   std_logic_vector(3 downto 0);
		--async_input_n: in   std_logic_vector(3 downto 0);
		-- single ennded input
		async_input_i : in std_logic_vector(3 downto 0);

		-- ft232h interface
		adbus_io  : inout std_logic_vector(7 downto 0);
		n_rxf_i   : in    std_logic;
		n_txe_i   : in    std_logic;
		n_rd_o    : out   std_logic;
		n_wr_o    : out   std_logic;
		n_siwu_o  : out   std_logic;
		n_oe_o    : out   std_logic;

		-- negative rail generation
		neg_volt_osc_a : out std_logic_vector(2 downto 0);
		neg_volt_osc_b : out std_logic_vector(2 downto 0);

		-- 12MHz oscillator enable;
		osc_en : out std_logic := '1';

		threshold_pwm_o : out std_logic_vector(0 to 3);

		status_led_o : out std_logic_vector(0 to 3);
		signal_led_o : out std_logic_vector(0 to 3)
    );
end entity;

architecture rtl of tdc_top is

	constant threshold_bit_width : natural := 12;
	
	signal async_input : std_logic_vector(n_channels-1 downto 0);

	signal dcm_intermediate_locked : std_logic := '1';
	signal clk_quad_000, clk_quad_090, clk_quad_180, clk_quad_270 : std_logic; -- tdc
	signal counter  : unsigned(26 downto 0);

	-- hold reset line for some time after startup
	signal rst       : std_logic := '1';
	signal rst_count : unsigned( 4 downto 0) := (others => '0');

	signal tdc_pop            : std_logic_vector(n_channels-1 downto 0) := (others => '0');
	signal tdc_empty          : std_logic_vector(n_channels-1 downto 0);
	type tdc_data_array_t is array (n_channels-1 downto 0) of std_logic_vector(31 downto 0);
	signal tdc_data           : tdc_data_array_t;
	signal tdc_idx            : integer range 0 to n_channels-1 := 0;


	signal ftdi_data   : std_logic_vector(7 downto 0) := (others => '0');
	signal header_reg  : std_logic_vector(6 downto 0) := (others => '0');
	signal s_and_t_reg : std_logic_vector(6 downto 0) := (others => '0');
	signal time_2_reg  : std_logic_vector(6 downto 0) := (others => '0');
	signal time_3_reg  : std_logic_vector(6 downto 0) := (others => '0');
	signal time_4_reg  : std_logic_vector(6 downto 0) := (others => '0');
	signal ftdi_push, ftdi_full : std_logic;
	type send_data_state_t is (s_wait_for_event, s_pop_from_tdc, s_read_from_tdc, s_send_header, s_send_sample_and_time, s_send_time_2, s_send_time_3, s_send_time_4);
	signal send_data_state : send_data_state_t := s_wait_for_event;

	signal pwm_value : std_logic_vector(0 to 3);

	signal neg_volt_cnt : unsigned(7 downto 0) := (others => '0');

	type threshold_value_array_t is array (n_channels-1 downto 0) of unsigned(threshold_bit_width-1 downto 0);
	signal threshold_value : threshold_value_array_t := (others => (others => '0'));

	signal registers  : std_logic_vector(63 downto 0);

	signal tdc_reset : std_logic_vector(n_channels-1 downto 0);
begin


	-- differential input
	--inputs: for i in async_input'range generate	
	--	--IBUFDS_inst : IBUFDS
	--	ibufds_inst : ibufds
	--	generic map (
	--		DIFF_TERM    => TRUE, -- Differential Termination 
	--		IBUF_LOW_PWR => TRUE, -- Low power (TRUE) vs. performance (FALSE)
	--		IOSTANDARD   => "DEFAULT")
	--	port map (
	--		O  => async_input(i),  -- Clock buffer output
	--		I  => async_input_p(i),  -- Diff_p clock buffer input (connect directly to top-level port)
	--		IB => async_input_n(i) -- Diff_n clock buffer input (connect directly to top-level port)
	--	);
	--end generate;

	-- single ended input
	async_input <= async_input_i;

	-- reset generator
	gen_rst: process
	begin
		wait until rising_edge(clk_quad_000);
		if rst = '1' then
			rst_count <= rst_count + 1;
		end if;
		if rst_count(4) = '1' then
			rst <= '0';
		end if;
	end process;

	-- make the four clock phases
	clk_gen : entity work.tdc_clk_gen
	port map (
		clk12_i        => clk_i,
		clk_quad_000_o => clk_quad_000,
		clk_quad_090_o => clk_quad_090,
		clk_quad_180_o => clk_quad_180,
		clk_quad_270_o => clk_quad_270
	);


	-- instanciate the time to digital converters (TDC)
	tdcs: for i in async_input'range generate	
	begin 
		tdc_reset(i) <= rst or not registers(60+i);
		tdc_instance : entity work.tdc 
		generic map (
			data_buffer_depth => data_buffer_depth
		)
		port map (
			rst_i      => tdc_reset(i),
			clk_000_i  => clk_quad_000,
			clk_090_i  => clk_quad_090,
			clk_180_i  => clk_quad_180,
			clk_270_i  => clk_quad_270,
			async_i    => async_input(i),
			empty_o    => tdc_empty(i),
			pop_i      => tdc_pop(i),
			data_o     => tdc_data(i),
			led_o      => signal_led_o(i)
		);
	end generate;

	-- generate threshold for dynamic time over threshold (DTOT)
	threshold_pwms: for i in async_input'range generate	
	begin 
		threshold_pwm_inst : entity work.pwm
		generic map (
			bit_width => threshold_bit_width
		)
		port map (
			rst_i       => rst,
			clk_i       => clk_quad_000,
			threshold_i => threshold_value(i),
			pwm_o       => pwm_value(i)
		);
	end generate;

	threshold_pwm_o <= pwm_value;
	----signal_led_o    <= pwm_value;
	----status_led_o    <= pwm_value;


	multiplex_and_send_tdc_data: process
	begin
		wait until rising_edge(clk_quad_000);
		if rst = '1' then
			ftdi_push       <= '0';
			ftdi_data       <= (others => '0');
			header_reg      <= (others => '0');
			s_and_t_reg     <= (others => '0');
			time_2_reg      <= (others => '0');
			time_3_reg      <= (others => '0');
			time_4_reg      <= (others => '0');
			send_data_state <= s_wait_for_event;
			tdc_idx         <= 0;
		else
			case send_data_state is
				when s_wait_for_event =>
					ftdi_push <= '0';
					if ftdi_push = '0' and tdc_empty(tdc_idx) = '0' then
						-- read data from tdc(tdc_idx)
						tdc_pop(tdc_idx) <= '1'; 
						send_data_state <= s_pop_from_tdc;
					else
						if tdc_idx < n_channels-1 then
							tdc_idx <= tdc_idx + 1;
						else 
							tdc_idx <= 0;
						end if;
					end if;
				when s_pop_from_tdc =>
					ftdi_push <= '0';
					tdc_pop(tdc_idx) <= '0';
					send_data_state <= s_read_from_tdc;
				when s_read_from_tdc =>
					ftdi_push <= '0';
					header_reg  <= std_logic_vector(to_unsigned(tdc_idx,3)) & tdc_data(tdc_idx)(7 downto 4);
					s_and_t_reg <= tdc_data(tdc_idx)(3 downto 0) & tdc_data(tdc_idx)(31 downto 29);
					time_2_reg  <= tdc_data(tdc_idx)(28 downto 22);
					time_3_reg  <= tdc_data(tdc_idx)(21 downto 15);
					time_4_reg  <= tdc_data(tdc_idx)(14 downto  8);
					send_data_state <= s_send_header;
				when s_send_header =>
					ftdi_push <= '0';
					if ftdi_push = '0' and ftdi_full = '0' then
						ftdi_push <= '1';
						ftdi_data <= '1' & header_reg;
						send_data_state <= s_send_sample_and_time;
					end if;
				when s_send_sample_and_time =>
					ftdi_push <= '0';
					if ftdi_push = '0' and ftdi_full = '0' then
						ftdi_push <= '1';
						ftdi_data <= '0' & s_and_t_reg;
						send_data_state <= s_send_time_2;
					end if;
				when s_send_time_2 =>
					ftdi_push <= '0';
					if ftdi_push = '0' and ftdi_full = '0' then
						ftdi_push <= '1';
						ftdi_data <= '0' & time_2_reg;
						send_data_state <= s_send_time_3;
					end if;
				when s_send_time_3 =>
					ftdi_push <= '0';
					if ftdi_push = '0' and ftdi_full = '0' then
						ftdi_push <= '1';
						ftdi_data <= '0' & time_3_reg;
						send_data_state <= s_send_time_4;
					end if;
				when s_send_time_4 =>
					ftdi_push <= '0';
					if ftdi_push = '0' and ftdi_full = '0' then
						ftdi_push <= '1';
						ftdi_data <= '0' & time_4_reg;
						send_data_state <= s_wait_for_event;
					end if;
			end case; 
		end if;

	end process;

	-- instanciate FT232H chip (USB to host PC)
	ft232h : entity work.ft232h_async_fifo
	port map (
		clk_i    => clk_quad_000,
		rst_i    => rst,
		-- write interface (write to host PC)
		push_i   => ftdi_push,
		full_o   => ftdi_full,
		data_i   => ftdi_data,

		registers_o => registers,

		-- chip interface
		n_rxf_i  => n_rxf_i,
		n_txe_i  => n_txe_i,
		n_rd_o   => n_rd_o,
		n_wr_o   => n_wr_o,
		n_siwu_o => n_siwu_o,
		n_oe_o   => n_oe_o,
		adbus_io => adbus_io
	);

	status_led_o(0) <= registers(60); -- tdc active leds 
	status_led_o(1) <= registers(61); -- tdc active leds
	status_led_o(2) <= registers(62); -- tdc active leds
	status_led_o(3) <= registers(63); -- tdc active leds
	
	threshold_value(0) <= unsigned(registers(11 downto  0));
	threshold_value(1) <= unsigned(registers(23 downto 12));
	threshold_value(2) <= unsigned(registers(35 downto 24));
	threshold_value(3) <= unsigned(registers(47 downto 36));

	-- negative volt generator, using an FPGA driven charge pump
	neg_gen: process
	begin
		wait until rising_edge(clk_quad_000);
		neg_volt_cnt <= neg_volt_cnt + 1;
	end process;
	neg_volt_osc_a <= (neg_volt_cnt(7), neg_volt_cnt(7), neg_volt_cnt(7));
	neg_volt_osc_b <= not (neg_volt_cnt(7), neg_volt_cnt(7), neg_volt_cnt(7));

	-- always enable the oscillator (for now)
	osc_en <= '1';

end architecture;

