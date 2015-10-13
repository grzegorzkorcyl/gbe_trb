LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.std_logic_unsigned.ALL;
USE ieee.math_real.all;
USE ieee.numeric_std.ALL;

library work;
use work.trb_net_std.all;
use work.trb_net_components.all;
use work.trb_net16_hub_func.all;

use work.trb_net_gbe_components.all;
use work.trb_net_gbe_protocols.all;

ENTITY aa_full_wrapper_tb IS
END aa_full_wrapper_tb;

ARCHITECTURE behavior OF aa_full_wrapper_tb IS

signal clk_sys, clk_125, reset, gsr_n, trigger : std_logic := '0';

begin
	
	uut : entity work.gbe_wrapper
		generic map(
			DO_SIMULATION             => 1,
			INCLUDE_DEBUG             => 0,
			USE_INTERNAL_TRBNET_DUMMY => 0,
			USE_EXTERNAL_TRBNET_DUMMY => 1,
			RX_PATH_ENABLE            => 1,
			FIXED_SIZE_MODE           => 0,
			INCREMENTAL_MODE          => 0,
			FIXED_SIZE                => 100, --13750,
			FIXED_DELAY_MODE          => 1,
			UP_DOWN_MODE              => 1,
			UP_DOWN_LIMIT             => 1000,
			FIXED_DELAY               => 10,
			NUMBER_OF_GBE_LINKS       => 4,
			LINKS_ACTIVE              => "1111",
			LINK_HAS_PING             => "1111",
			LINK_HAS_ARP              => "1111",
			LINK_HAS_DHCP             => "1111",
			LINK_HAS_READOUT          => "1000",
			LINK_HAS_SLOWCTRL         => "1000",
			NUMBER_OF_OUTPUT_LINKS    => 4
		)
		port map(
			CLK_SYS_IN               => clk_sys,
			CLK_125_IN               => clk_125,
			RESET                    => reset,
			GSR_N                    => gsr_n,
			SD_RXD_P_IN              => (others => '0'),
			SD_RXD_N_IN              => (others => '0'),
			SD_TXD_P_OUT             => open,
			SD_TXD_N_OUT             => open,
			SD_PRSNT_N_IN            => (others => '0'),
			SD_LOS_IN                => (others => '0'),
			SD_TXDIS_OUT             => open,
			TRIGGER_IN               => trigger,
			CTS_NUMBER_IN            => (others => '0'),
			CTS_CODE_IN              => (others => '0'),
			CTS_INFORMATION_IN       => (others => '0'),
			CTS_READOUT_TYPE_IN      => (others => '0'),
			CTS_START_READOUT_IN     => '0',
			CTS_DATA_OUT             => open,
			CTS_DATAREADY_OUT        => open,
			CTS_READOUT_FINISHED_OUT => open,
			CTS_READ_IN              => '0',
			CTS_LENGTH_OUT           => open,
			CTS_ERROR_PATTERN_OUT    => open,
			FEE_DATA_IN              => (others => '0'),
			FEE_DATAREADY_IN         => '0',
			FEE_READ_OUT             => open,
			FEE_STATUS_BITS_IN       => (others => '0'),
			FEE_BUSY_IN              => '0',
			MC_UNIQUE_ID_IN          => (others => '0'),
			GSC_CLK_IN               => clk_sys,
			GSC_INIT_DATAREADY_OUT   => open,
			GSC_INIT_DATA_OUT        => open,
			GSC_INIT_PACKET_NUM_OUT  => open,
			GSC_INIT_READ_IN         => '1',
			GSC_REPLY_DATAREADY_IN   => '1',
			GSC_REPLY_DATA_IN        => x"abcd",
			GSC_REPLY_PACKET_NUM_IN  => "111",
			GSC_REPLY_READ_OUT       => open,
			GSC_BUSY_IN              => '0',
			SLV_ADDR_IN              => (others => '0'),
			SLV_READ_IN              => '0',
			SLV_WRITE_IN             => '0',
			SLV_BUSY_OUT             => open,
			SLV_ACK_OUT              => open,
			SLV_DATA_IN              => (others => '0'),
			SLV_DATA_OUT             => open,
			BUS_ADDR_IN              => (others => '0'),
			BUS_DATA_IN              => (others => '0'),
			BUS_DATA_OUT             => open,
			BUS_WRITE_EN_IN          => '0',
			BUS_READ_EN_IN           => '0',
			BUS_ACK_OUT              => open,
			MAKE_RESET_OUT           => open,
			DEBUG_OUT                => open
		);

	process
	begin
		clk_sys <= '1'; wait for 5 ns;
		clk_sys <= '0'; wait for 5 ns;
	end process;
	
	process
	begin
		clk_125 <= '1'; wait for 4 ns;
		clk_125 <= '0'; wait for 4 ns;
	end process;
	
	process
	begin
		reset <= '1';
		gsr_n <= '0';
		wait for 100 ns;
		reset <= '0';
		gsr_n <= '1';
		wait for 20 us;
		
		trigger <= '1';
		
--		for i in 0 to 10000 loop
--			trigger <= '1';
--			wait for 100 ns;
--			trigger <= '0';
--			wait for 10 us;
--		end loop;
		
		wait;
	end process;
	

end; 