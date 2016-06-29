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

use work.trb3_components.all;
use work.cts_pkg.all;

--Configuration is done in this file:   
use work.config.all;

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
	signal fee_data : std_logic_vector(15 downto 0);
	signal fee_dataready : std_logic;
	signal fee_read : std_logic;
	signal fee_busy : std_logic;
	
	signal med_stat_op                 : std_logic_vector(5 * 16 - 1 downto 0);
	signal med_ctrl_op                 : std_logic_vector(5 * 16 - 1 downto 0);
	signal med_data_out                : std_logic_vector(5 * 16 - 1 downto 0);
	signal med_packet_num_out          : std_logic_vector(5 * 3 - 1 downto 0);
	signal med_dataready_out           : std_logic_vector(5 * 1 - 1 downto 0);
	signal med_read_out                : std_logic_vector(5 * 1 - 1 downto 0);
	signal med_data_in                 : std_logic_vector(5 * 16 - 1 downto 0);
	signal med_packet_num_in           : std_logic_vector(5 * 3 - 1 downto 0);
	signal med_dataready_in            : std_logic_vector(5 * 1 - 1 downto 0);
	signal med_read_in                 : std_logic_vector(5 * 1 - 1 downto 0);
	
	signal fee_trg_release_i    : std_logic;
	signal fee_trg_statusbits_i : std_logic_vector(31 downto 0);
	signal fee_data_i           : std_logic_vector(31 downto 0);
	signal fee_data_write_i     : std_logic;
	signal fee_data_finished_i  : std_logic;
	
	signal cts_rdo_trigger            : std_logic;
	signal cts_rdo_trg_data_valid     : std_logic;
	signal cts_rdo_valid_timing_trg   : std_logic;
	signal cts_rdo_valid_notiming_trg : std_logic;
	signal cts_rdo_invalid_trg        : std_logic;
	signal cts_rdo_trg_status_bits_cts : std_logic_vector(31 downto 0) := (others => '0');
	signal cts_rdo_data                : std_logic_vector(31 downto 0);
	signal cts_rdo_write               : std_logic;
	signal cts_rdo_finished            : std_logic;
	
	signal cts_trg_send        : std_logic;
	signal cts_trg_type        : std_logic_vector(3 downto 0);
	signal cts_trg_number      : std_logic_vector(15 downto 0);
	signal cts_trg_information : std_logic_vector(23 downto 0);
	signal cts_trg_code        : std_logic_vector(7 downto 0);
	signal cts_trg_status_bits : std_logic_vector(31 downto 0);
	signal cts_trg_busy        : std_logic;

	signal cts_ipu_send        : std_logic;
	signal cts_ipu_type        : std_logic_vector(3 downto 0);
	signal cts_ipu_number      : std_logic_vector(15 downto 0);
	signal cts_ipu_information : std_logic_vector(7 downto 0);
	signal cts_ipu_code        : std_logic_vector(7 downto 0);
	signal cts_ipu_status_bits : std_logic_vector(31 downto 0);
	signal cts_ipu_busy        : std_logic;
	
	signal cts_ext_trigger, cts_trigger_out, valid_trigger : std_logic;
	
	signal cts_number                  : std_logic_vector(15 downto 0);
	signal cts_code                    : std_logic_vector(7 downto 0);
	signal cts_info		               : std_logic_vector(7 downto 0);
	signal cts_readout_type            : std_logic_vector(3 downto 0);

begin


-- api_ipu_streaming : entity work.trb_net16_api_ipu_streaming
--  port map(
--    CLK    => clk_sys,
--    RESET  => reset,
--    CLK_EN => '1',
--
--    -- Internal direction port
--
--    FEE_INIT_DATA_OUT         => open,
--    FEE_INIT_DATAREADY_OUT    => open,
--    FEE_INIT_PACKET_NUM_OUT   => open,
--    FEE_INIT_READ_IN          => '1',
--
--    FEE_REPLY_DATA_IN         => (others => '0'),
--    FEE_REPLY_DATAREADY_IN    => '0',
--    FEE_REPLY_PACKET_NUM_IN   => (others => '0'),
--    FEE_REPLY_READ_OUT        => open,
--
--    CTS_INIT_DATA_IN          => (others => '0'),
--    CTS_INIT_DATAREADY_IN     => '0',
--    CTS_INIT_PACKET_NUM_IN    => (others => '0'),
--    CTS_INIT_READ_OUT         => open,
--
--    CTS_REPLY_DATA_OUT        => open,
--    CTS_REPLY_DATAREADY_OUT   => open,
--    CTS_REPLY_PACKET_NUM_OUT  => open,
--    CTS_REPLY_READ_IN         => '1',
--
--    --Event information coming from CTS
--    CTS_NUMBER_OUT            => open,
--    CTS_CODE_OUT              => open,
--    CTS_INFORMATION_OUT       => open,
--    CTS_READOUT_TYPE_OUT      => open,
--    CTS_START_READOUT_OUT     => cts_start_readout,
--                                                --after user send information to cts.
--
--    --Information sent to CTS
--    --status data, equipped with DHDR
--    CTS_DATA_IN             => cts_data,
--    CTS_DATAREADY_IN        => cts_dataready,
--    CTS_READOUT_FINISHED_IN => cts_readout_finished,
--    CTS_READ_OUT            => cts_read,
--    CTS_LENGTH_IN           => cts_length,
--    CTS_STATUS_BITS_IN      => cts_status,
--
--    -- Data from Frontends
--    FEE_DATA_OUT           => fee_data,
--    FEE_DATAREADY_OUT      => fee_dataready,
--    FEE_READ_IN            => fee_read,
--    FEE_STATUS_BITS_OUT    => open,
--    FEE_BUSY_OUT           => fee_busy,
--                                             --has been read.
--
--    MY_ADDRESS_IN         => x"1234",
--    CTRL_SEQNR_RESET      => '0'
--
--    );
    
    
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
		CTS_NUMBER_IN            => cts_number,
		CTS_CODE_IN              => cts_code,
		CTS_INFORMATION_IN       => cts_info,
		CTS_READOUT_TYPE_IN      => cts_readout_type,
		CTS_START_READOUT_IN     => cts_start_readout,
		CTS_DATA_OUT             => cts_data,
		CTS_DATAREADY_OUT        => cts_dataready,
		CTS_READOUT_FINISHED_OUT => cts_readout_finished,
		CTS_READ_IN              => cts_read,
		CTS_LENGTH_OUT           => cts_length,
		CTS_ERROR_PATTERN_OUT    => cts_status,
		FEE_DATA_IN              => fee_data,
		FEE_DATAREADY_IN         => fee_dataready,
		FEE_READ_OUT             => fee_read,
		FEE_STATUS_BITS_IN       => (others => '0'),
		FEE_BUSY_IN              => fee_busy,
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
	
	
	endp_gen : for i in 1 to 4 generate 
	
	THE_ENDPOINT : entity work.trb_net16_endpoint_hades_full_handler
		generic map(
			REGIO_NUM_STAT_REGS       => 1,
			REGIO_NUM_CTRL_REGS       => 1,
			ADDRESS_MASK              => x"FFFF",
			BROADCAST_BITMASK         => x"FF",
			BROADCAST_SPECIAL_ADDR    => x"23",
			REGIO_COMPILE_TIME        => x"12345678",
			REGIO_HARDWARE_VERSION    => x"01234567",
			REGIO_INCLUDED_FEATURES   => x"12345678_12345678",
			REGIO_INIT_ADDRESS        => x"4567",
			REGIO_USE_VAR_ENDPOINT_ID => 1,
			CLOCK_FREQUENCY           => 100,
			TIMING_TRIGGER_RAW        => 1,
			--Configure data handler
			DATA_INTERFACE_NUMBER     => 1,
			DATA_BUFFER_DEPTH         => 11,
			DATA_BUFFER_WIDTH         => 32,
			DATA_BUFFER_FULL_THRESH   => 2 ** 11 - 1024,
			TRG_RELEASE_AFTER_DATA    => 1,
			HEADER_BUFFER_DEPTH       => 9,
			HEADER_BUFFER_FULL_THRESH => 2 ** 9 - 16
		)
		port map(
			CLK                                => clk_sys,
			RESET                              => reset,
			CLK_EN                             => '1',
			MED_DATAREADY_OUT                  => med_dataready_in( (i + 1) * 1 - 1),
			MED_DATA_OUT                       => med_data_in((i + 1) * 16 - 1 downto i * 16),
			MED_PACKET_NUM_OUT                 => med_packet_num_in( (i + 1) * 3 - 1 downto i * 3),
			MED_READ_IN                        => med_read_out((i + 1) * 1 - 1),
			MED_DATAREADY_IN                   => med_dataready_out((i + 1) * 1 - 1),
			MED_DATA_IN                        => med_data_out((i + 1) * 16 - 1 downto i * 16),
			MED_PACKET_NUM_IN                  => med_packet_num_out( (i + 1) * 3 - 1 downto i * 3),
			MED_READ_OUT                       => med_read_in((i + 1) * 1 - 1),
			MED_STAT_OP_IN                     => (others => '0'), --med_stat_op(2 * 16 - 1 downto 1 * 16),
			MED_CTRL_OP_OUT                    => open, --med_ctrl_op(2 * 16 - 1 downto 1 * 16),

			--Timing trigger in
			TRG_TIMING_TRG_RECEIVED_IN         => cts_ext_trigger,
			--LVL1 trigger to FEE
			LVL1_TRG_DATA_VALID_OUT            => valid_trigger,
			LVL1_VALID_TIMING_TRG_OUT          => open,
			LVL1_VALID_NOTIMING_TRG_OUT        => open,
			LVL1_INVALID_TRG_OUT               => open,
			LVL1_TRG_TYPE_OUT                  => open,
			LVL1_TRG_NUMBER_OUT                => open,
			LVL1_TRG_CODE_OUT                  => open,
			LVL1_TRG_INFORMATION_OUT           => open,
			LVL1_INT_TRG_NUMBER_OUT            => open,

			--Information about trigger handler errors
			TRG_MULTIPLE_TRG_OUT               => open,
			TRG_TIMEOUT_DETECTED_OUT           => open,
			TRG_SPURIOUS_TRG_OUT               => open,
			TRG_MISSING_TMG_TRG_OUT            => open,
			TRG_SPIKE_DETECTED_OUT             => open,

			--Response from FEE
			FEE_TRG_RELEASE_IN(0)              => fee_trg_release_i, --'0',
			FEE_TRG_STATUSBITS_IN              => fee_trg_statusbits_i, --(others => '0'),
			FEE_DATA_IN                        => fee_data_i, --(others => '0'),
			FEE_DATA_WRITE_IN(0)               => fee_data_write_i, --'0',
			FEE_DATA_FINISHED_IN(0)            => fee_data_finished_i, --'0',
			FEE_DATA_ALMOST_FULL_OUT           => open,

			-- Slow Control Data Port
			REGIO_COMMON_STAT_REG_IN           => (others => '0'), --0x00
			REGIO_COMMON_CTRL_REG_OUT          => open, --0x20
			REGIO_COMMON_STAT_STROBE_OUT       => open,
			REGIO_COMMON_CTRL_STROBE_OUT       => open,
			REGIO_STAT_REG_IN                  => (others => '0'), --start 0x80
			REGIO_CTRL_REG_OUT                 => open, --start 0xc0
			REGIO_STAT_STROBE_OUT              => open,
			REGIO_CTRL_STROBE_OUT              => open,
			REGIO_VAR_ENDPOINT_ID(1 downto 0)  => (others => '0'),
			REGIO_VAR_ENDPOINT_ID(15 downto 2) => (others => '0'),
			BUS_ADDR_OUT                       => open,
			BUS_READ_ENABLE_OUT                => open,
			BUS_WRITE_ENABLE_OUT               => open,
			BUS_DATA_OUT                       => open,
			BUS_DATA_IN                        => (others => '0'),
			BUS_DATAREADY_IN                   => '0',
			BUS_NO_MORE_DATA_IN                => '0',
			BUS_WRITE_ACK_IN                   => '0',
			BUS_UNKNOWN_ADDR_IN                => '0',
			BUS_TIMEOUT_OUT                    => open,
			ONEWIRE_INOUT                      => open,
			ONEWIRE_MONITOR_OUT                => open,
			TIME_GLOBAL_OUT                    => open,
			TIME_LOCAL_OUT                     => open,
			TIME_SINCE_LAST_TRG_OUT            => open,
			TIME_TICKS_OUT                     => open,
			STAT_DEBUG_IPU                     => open,
			STAT_DEBUG_1                       => open,
			STAT_DEBUG_2                       => open,
			STAT_DEBUG_DATA_HANDLER_OUT        => open,
			STAT_DEBUG_IPU_HANDLER_OUT         => open,
			STAT_TRIGGER_OUT                   => open,
			CTRL_MPLEX                         => (others => '0'),
			IOBUF_CTRL_GEN                     => (others => '0'),
			STAT_ONEWIRE                       => open,
			STAT_ADDR_DEBUG                    => open,
			DEBUG_LVL1_HANDLER_OUT             => open
		);
end generate;

	process
		variable ctr : integer := 0;
	begin
		fee_data_write_i <= '0';
		fee_trg_release_i <= '0';
		fee_data_finished_i <= '0';
		fee_trg_statusbits_i <= (others => '0');
		
		wait until valid_trigger = '1';
		wait for 1 us;
		wait until rising_edge(clk_sys);
		fee_data_write_i <= '1';
		
		for i in 0 to 99 loop
			fee_data_i <= std_logic_vector(to_unsigned(ctr, 32));
			wait until rising_edge(clk_sys);
			ctr := ctr + 1;
		end loop;

		fee_data_finished_i <= '1';
		wait until rising_edge(clk_sys);
		fee_data_write_i <= '0';
		fee_data_finished_i <= '0';
		wait until rising_edge(clk_sys);
		fee_trg_release_i <= '1';
		wait until rising_edge(clk_sys);
		fee_trg_release_i <= '0';
			
	end process;

med_stat_op(2 downto 0) <= "111";
med_stat_op(31 downto 3) <= (others => '0');

med_dataready_in(1 * 1 - 1) <= '0';
med_data_in(1 * 16 - 1 downto 0) <= (others => '0');
med_packet_num_in( 1 * 3 - 1 downto 0) <= (others => '0');
med_read_in(1 * 1 - 1) <= '1';

	THE_HUB : entity work.trb_net16_hub_streaming_port_sctrl_cts
		generic map(
			INIT_ADDRESS                  => x"FAAA",
			MII_NUMBER                    => 5,
			MII_IS_UPLINK                 => (0 => 1, others => 0),
			MII_IS_DOWNLINK               => (0 => 0, others => 1),
			MII_IS_UPLINK_ONLY            => (0 => 1, others => 0),
			--			MII_NUMBER                    => INTERFACE_NUM,
			--			MII_IS_UPLINK                 => IS_UPLINK,
			--			MII_IS_DOWNLINK               => IS_DOWNLINK,
			--			MII_IS_UPLINK_ONLY            => IS_UPLINK_ONLY,
			HARDWARE_VERSION              => x"9000cee0",
			INIT_ENDPOINT_ID              => x"0005",
			BROADCAST_BITMASK             => x"7E",
			CLOCK_FREQUENCY               => 100,
			USE_ONEWIRE                   => 0,
			BROADCAST_SPECIAL_ADDR        => x"35",
			RDO_ADDITIONAL_PORT           => 1, --cts_rdo_additional_ports,
			RDO_DATA_BUFFER_DEPTH         => 9,
			RDO_DATA_BUFFER_FULL_THRESH   => 2 ** 9 - 128,
			RDO_HEADER_BUFFER_DEPTH       => 9,
			RDO_HEADER_BUFFER_FULL_THRESH => 2 ** 9 - 16
		)
		port map(
			CLK                                                => clk_sys,
			RESET                                              => reset,
			CLK_EN                                             => '1',

			-- Media interfacces ---------------------------------------------------------------
			MED_DATAREADY_OUT  => med_dataready_out,
			MED_DATA_OUT      => med_data_out,
			MED_PACKET_NUM_OUT => med_packet_num_out,
			MED_READ_IN        => med_read_in,
			MED_DATAREADY_IN  => med_dataready_in,
			MED_DATA_IN       => med_data_in,
			MED_PACKET_NUM_IN  => med_packet_num_in,
			MED_READ_OUT       => med_read_out,
			MED_STAT_OP       => med_stat_op,
			MED_CTRL_OP       => open, --med_ctrl_op,

			-- Gbe Read-out Path ---------------------------------------------------------------
			--Event information coming from CTS for GbE
			GBE_CTS_NUMBER_OUT                                 => cts_number,
			GBE_CTS_CODE_OUT                                   => cts_code,
			GBE_CTS_INFORMATION_OUT                            => cts_info,
			GBE_CTS_READOUT_TYPE_OUT                           => cts_readout_type,
			GBE_CTS_START_READOUT_OUT                          => cts_start_readout,
			--Information sent to CTS
			GBE_CTS_READOUT_FINISHED_IN                        => cts_readout_finished,
			GBE_CTS_STATUS_BITS_IN                             => (others => '0'),
			-- Data from Frontends
			GBE_FEE_DATA_OUT                                   => fee_data,
			GBE_FEE_DATAREADY_OUT                              => fee_dataready,
			GBE_FEE_READ_IN                                    => fee_read,
			GBE_FEE_STATUS_BITS_OUT                            => open,
			GBE_FEE_BUSY_OUT                                   => fee_busy,

			-- CTS Request Sending -------------------------------------------------------------
			--LVL1 trigger
			CTS_TRG_SEND_IN                                    => cts_trg_send,
			CTS_TRG_TYPE_IN                                    => cts_trg_type,
			CTS_TRG_NUMBER_IN                                  => cts_trg_number,
			CTS_TRG_INFORMATION_IN                             => cts_trg_information,
			CTS_TRG_RND_CODE_IN                                => cts_trg_code,
			CTS_TRG_STATUS_BITS_OUT                            => cts_trg_status_bits,
			CTS_TRG_BUSY_OUT                                   => cts_trg_busy,
			--IPU Channel
			CTS_IPU_SEND_IN                                    => cts_ipu_send,
			CTS_IPU_TYPE_IN                                    => cts_ipu_type,
			CTS_IPU_NUMBER_IN                                  => cts_ipu_number,
			CTS_IPU_INFORMATION_IN                             => cts_ipu_information,
			CTS_IPU_RND_CODE_IN                                => cts_ipu_code,
			-- Receiver port
			CTS_IPU_STATUS_BITS_OUT                            => cts_ipu_status_bits,
			CTS_IPU_BUSY_OUT                                   => cts_ipu_busy,

			-- CTS Data Readout ----------------------------------------------------------------
			--Trigger to CTS out
			RDO_TRIGGER_IN                                     => cts_rdo_trigger,
			RDO_TRG_DATA_VALID_OUT                             => cts_rdo_trg_data_valid,
			RDO_VALID_TIMING_TRG_OUT                           => cts_rdo_valid_timing_trg,
			RDO_VALID_NOTIMING_TRG_OUT                         => cts_rdo_valid_notiming_trg,
			RDO_INVALID_TRG_OUT                                => cts_rdo_invalid_trg,
			RDO_TRG_TYPE_OUT                                   => open, --cts_rdo_trg_type,
			RDO_TRG_CODE_OUT                                   => open, --cts_rdo_trg_code,
			RDO_TRG_INFORMATION_OUT                            => open, --cts_rdo_trg_information,
			RDO_TRG_NUMBER_OUT                                 => open, --cts_rdo_trg_number,

			--Data from CTS in
			RDO_TRG_STATUSBITS_IN                              => cts_rdo_trg_status_bits_cts,
			RDO_DATA_IN                                        => cts_rdo_data,
			RDO_DATA_WRITE_IN                                  => cts_rdo_write,
			RDO_DATA_FINISHED_IN                               => cts_rdo_finished,
			--Data from additional modules
			RDO_ADDITIONAL_STATUSBITS_IN                       => (others => '0'),
			RDO_ADDITIONAL_DATA                                => (others => '0'),
			RDO_ADDITIONAL_WRITE                               => (others => '0'),
			RDO_ADDITIONAL_FINISHED                            => (others => '0'),

			-- Slow Control --------------------------------------------------------------------
			COMMON_STAT_REGS                                   => open,
			COMMON_CTRL_REGS                                   => open,
			ONEWIRE                                            => open,
			ONEWIRE_MONITOR_IN                                 => '0',
			MY_ADDRESS_OUT                                     => open,
			UNIQUE_ID_OUT                                      => open,
			TIMER_TICKS_OUT                                    => open,
			EXTERNAL_SEND_RESET                                => '0',
			REGIO_ADDR_OUT                                     => open,
			REGIO_READ_ENABLE_OUT                              => open,
			REGIO_WRITE_ENABLE_OUT                             => open,
			REGIO_DATA_OUT                                     => open,
			REGIO_DATA_IN                                      => (others => '0'),
			REGIO_DATAREADY_IN                                 => '0',
			REGIO_NO_MORE_DATA_IN                              => '0',
			REGIO_WRITE_ACK_IN                                 => '0',
			REGIO_UNKNOWN_ADDR_IN                              => '0',
			REGIO_TIMEOUT_OUT                                  => open,

			--Gbe Sctrl Input
			GSC_INIT_DATAREADY_IN                              => '0',
			GSC_INIT_DATA_IN                                   => (others => '0'),
			GSC_INIT_PACKET_NUM_IN                             => (others => '0'),
			GSC_INIT_READ_OUT                                  => open,
			GSC_REPLY_DATAREADY_OUT                            => open,
			GSC_REPLY_DATA_OUT                                 => open,
			GSC_REPLY_PACKET_NUM_OUT                           => open,
			GSC_REPLY_READ_IN                                  => '1',
			GSC_BUSY_OUT                                       => open,

			--status and control ports
			HUB_STAT_CHANNEL                                   => open,
			HUB_STAT_GEN                                       => open,
			MPLEX_CTRL                                         => (others => '0'),
			MPLEX_STAT                                         => open,
			STAT_REGS                                          => open,
			STAT_CTRL_REGS                                     => open,

			--Fixed status and control ports
			STAT_DEBUG                                         => open,
			CTRL_DEBUG                                         => (others => '0')
		);

	THE_CTS : entity work.CTS
		generic map(
			EXTERNAL_TRIGGER_ID  => x"60", -- fill in trigger logic enumeration id of external trigger logic


			TRIGGER_COIN_COUNT   => 1,
			TRIGGER_PULSER_COUNT => 2,
			TRIGGER_RAND_PULSER  => 1,
			TRIGGER_INPUT_COUNT  => 0,  -- obsolete! now all inputs are routed via an input multiplexer!
			TRIGGER_ADDON_COUNT  => 1,
			PERIPH_TRIGGER_COUNT => 1,
			OUTPUT_MULTIPLEXERS  => 1,
			ADDON_LINE_COUNT     => 0,
			ADDON_GROUPS         => 2,
			ADDON_GROUP_UPPER    => (others => 1)
		)
		port map(
			CLK                        => clk_sys,
			RESET                      => reset,
			TRIGGER_BUSY_OUT           => open,
			TIME_REFERENCE_OUT         => cts_trigger_out,
			ADDON_TRIGGERS_IN          => (others => '0'),
			ADDON_GROUP_ACTIVITY_OUT   => open,
			ADDON_GROUP_SELECTED_OUT   => open,
			EXT_TRIGGER_IN             => cts_ext_trigger, -- my local trigger
			EXT_STATUS_IN              => (others => '0'),
			EXT_CONTROL_OUT            => open,
			EXT_HEADER_BITS_IN         => (others => '0'),
			PERIPH_TRIGGER_IN          => (others => '0'),
			OUTPUT_MULTIPLEXERS_OUT    => open,
			
			CTS_TRG_SEND_OUT           => cts_trg_send,
			CTS_TRG_TYPE_OUT           => cts_trg_type,
			CTS_TRG_NUMBER_OUT         => cts_trg_number,
			CTS_TRG_INFORMATION_OUT    => cts_trg_information,
			CTS_TRG_RND_CODE_OUT       => cts_trg_code,
			CTS_TRG_STATUS_BITS_IN     => cts_trg_status_bits,
			CTS_TRG_BUSY_IN            => cts_trg_busy,
			CTS_IPU_SEND_OUT           => cts_ipu_send,
			CTS_IPU_TYPE_OUT           => cts_ipu_type,
			CTS_IPU_NUMBER_OUT         => cts_ipu_number,
			CTS_IPU_INFORMATION_OUT    => cts_ipu_information,
			CTS_IPU_RND_CODE_OUT       => cts_ipu_code,
			CTS_IPU_STATUS_BITS_IN     => cts_ipu_status_bits,
			CTS_IPU_BUSY_IN            => cts_ipu_busy,
			
			CTS_REGIO_ADDR_IN          => (others => '0'),
			CTS_REGIO_DATA_IN          => (others => '0'),
			CTS_REGIO_READ_ENABLE_IN   => '0',
			CTS_REGIO_WRITE_ENABLE_IN  => '0',
			CTS_REGIO_DATA_OUT         => open,
			CTS_REGIO_DATAREADY_OUT    => open,
			CTS_REGIO_WRITE_ACK_OUT    => open,
			CTS_REGIO_UNKNOWN_ADDR_OUT => open,
			
			LVL1_TRG_DATA_VALID_IN     => cts_rdo_trg_data_valid,
			LVL1_VALID_TIMING_TRG_IN   => cts_rdo_valid_timing_trg,
			LVL1_VALID_NOTIMING_TRG_IN => cts_rdo_valid_notiming_trg,
			LVL1_INVALID_TRG_IN        => cts_rdo_invalid_trg,
			FEE_TRG_STATUSBITS_OUT     => cts_rdo_trg_status_bits_cts,
			FEE_DATA_OUT               => cts_rdo_data,
			FEE_DATA_WRITE_OUT         => cts_rdo_write,
			FEE_DATA_FINISHED_OUT      => cts_rdo_finished
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
		cts_ext_trigger <= '0';
		gsr_n <= '0';
		wait for 100 ns;
		reset <= '0';
		gsr_n <= '1';
		wait for 2 us;

		cts_ext_trigger <= '1';
		
		wait for 150 ns;
		
		cts_ext_trigger <= '0';

		--		for i in 0 to 10000 loop
		--			trigger <= '1';
		--			wait for 100 ns;
		--			trigger <= '0';
		--			wait for 10 us;
		--		end loop;

		wait;
	end process;

end; 
