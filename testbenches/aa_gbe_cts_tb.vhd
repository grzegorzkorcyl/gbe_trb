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

ENTITY aa_gbe_cts_tb IS
END aa_gbe_cts_tb;

ARCHITECTURE behavior OF aa_gbe_cts_tb IS
	signal clk_sys, clk_125, reset, gsr_n, trigger : std_logic := '0';
	signal busip0, busip1                          : CTRLBUS_RX;
	signal cts_data : std_logic_vector(31 downto 0);
	signal cts_dataready : std_logic;
	signal cts_readout_finished : std_logic;
	signal cts_read : std_logic;
	signal cts_length : std_logic_vector(15 downto 0);
	signal cts_status : std_logic_vector(31 downto 0);
	signal cts_start_readout : std_logic;

begin


 api_ipu_streaming : entity work.trb_net16_api_ipu_streaming
  port map(
    CLK    => clk_sys,
    RESET  => reset,
    CLK_EN => '1',

    -- Internal direction port

    FEE_INIT_DATA_OUT         => open,
    FEE_INIT_DATAREADY_OUT    => open,
    FEE_INIT_PACKET_NUM_OUT   => open,
    FEE_INIT_READ_IN          => '1',

    FEE_REPLY_DATA_IN         => (others => '0'),
    FEE_REPLY_DATAREADY_IN    => '0',
    FEE_REPLY_PACKET_NUM_IN   => (others => '0'),
    FEE_REPLY_READ_OUT        => open,

    CTS_INIT_DATA_IN          => (others => '0'),
    CTS_INIT_DATAREADY_IN     => '0',
    CTS_INIT_PACKET_NUM_IN    => (others => '0'),
    CTS_INIT_READ_OUT         => open,

    CTS_REPLY_DATA_OUT        => open,
    CTS_REPLY_DATAREADY_OUT   => open,
    CTS_REPLY_PACKET_NUM_OUT  => open,
    CTS_REPLY_READ_IN         => '1',

    --Event information coming from CTS
    CTS_NUMBER_OUT            => open,
    CTS_CODE_OUT              => open,
    CTS_INFORMATION_OUT       => open,
    CTS_READOUT_TYPE_OUT      => open,
    CTS_START_READOUT_OUT     => cts_start_readout,
                                                --after user send information to cts.

    --Information sent to CTS
    --status data, equipped with DHDR
    CTS_DATA_IN             => cts_data,
    CTS_DATAREADY_IN        => cts_dataready,
    CTS_READOUT_FINISHED_IN => cts_readout_finished,
    CTS_READ_OUT            => cts_read,
    CTS_LENGTH_IN           => cts_length,
    CTS_STATUS_BITS_IN      => cts_status,

    -- Data from Frontends
    FEE_DATA_OUT           => open,
    FEE_DATAREADY_OUT      => open,
    FEE_READ_IN            => '1',
    FEE_STATUS_BITS_OUT    => open,
    FEE_BUSY_OUT           => open,
                                             --has been read.

    MY_ADDRESS_IN         => x"1234",
    CTRL_SEQNR_RESET      => '0'

    );
    
    
	uut : entity work.gbe_wrapper
	generic map(
		DO_SIMULATION             => 1,
		INCLUDE_DEBUG             => 0,
		USE_INTERNAL_TRBNET_DUMMY => 0,
		USE_EXTERNAL_TRBNET_DUMMY => 0,
		RX_PATH_ENABLE            => 1,
		FIXED_SIZE_MODE           => 1,
		INCREMENTAL_MODE          => 0,
		FIXED_SIZE                => 100, --13750,
		FIXED_DELAY_MODE          => 1,
		UP_DOWN_MODE              => 1,
		UP_DOWN_LIMIT             => 1000,
		FIXED_DELAY               => 10,
		NUMBER_OF_GBE_LINKS       => 4,
		LINKS_ACTIVE              => "1000",
		LINK_HAS_PING             => "1000",
		LINK_HAS_ARP              => "1000",
		LINK_HAS_DHCP             => "1000",
		LINK_HAS_READOUT          => "1000",
		LINK_HAS_SLOWCTRL         => "0000"
	)
	port map(
		CLK_SYS_IN               => clk_sys,
		CLK_125_IN               => clk_125,
		RESET                    => reset,
		GSR_N                    => gsr_n,
		SD_PRSNT_N_IN            => (others => '0'),
		SD_LOS_IN                => (others => '0'),
		SD_TXDIS_OUT             => open,
		TRIGGER_IN               => trigger,
		CTS_NUMBER_IN            => (others => '0'),
		CTS_CODE_IN              => (others => '0'),
		CTS_INFORMATION_IN       => (others => '0'),
		CTS_READOUT_TYPE_IN      => (others => '0'),
		CTS_START_READOUT_IN     => cts_start_readout,
		CTS_DATA_OUT             => cts_data,
		CTS_DATAREADY_OUT        => cts_dataready,
		CTS_READOUT_FINISHED_OUT => cts_readout_finished,
		CTS_READ_IN              => cts_read,
		CTS_LENGTH_OUT           => cts_length,
		CTS_ERROR_PATTERN_OUT    => cts_status,
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
		-- IP configuration
		BUS_IP_RX                => busip0,
		BUS_IP_TX                => open,
		-- Registers config
		BUS_REG_RX               => busip1,
		BUS_REG_TX               => open,
		MAKE_RESET_OUT           => open,
		DEBUG_OUT                => open
	);


	process
	begin
		clk_sys <= '1';
		wait for 5 ns;
		clk_sys <= '0';
		wait for 5 ns;
	end process;

	process
	begin
		clk_125 <= '1';
		wait for 4 ns;
		clk_125 <= '0';
		wait for 4 ns;
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
