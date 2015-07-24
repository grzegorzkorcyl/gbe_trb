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

ENTITY aa_ipu_dummy_tb IS
END aa_ipu_dummy_tb;

ARCHITECTURE behavior OF aa_ipu_dummy_tb IS


signal clk, reset,RX_MAC_CLK : std_logic;

SIGNAL CTS_NUMBER_IN :  std_logic_vector(15 downto 0);
SIGNAL CTS_CODE_IN :  std_logic_vector(7 downto 0);
SIGNAL CTS_INFORMATION_IN :  std_logic_vector(7 downto 0);
SIGNAL CTS_READOUT_TYPE_IN :  std_logic_vector(3 downto 0);
SIGNAL CTS_START_READOUT_IN :  std_logic;
SIGNAL CTS_DATA_OUT :  std_logic_vector(31 downto 0);
SIGNAL CTS_DATAREADY_OUT :  std_logic;
SIGNAL CTS_READOUT_FINISHED_OUT :  std_logic;
SIGNAL CTS_READ_IN :  std_logic;
SIGNAL CTS_LENGTH_OUT :  std_logic_vector(15 downto 0);
SIGNAL CTS_ERROR_PATTERN_OUT :  std_logic_vector(31 downto 0);
SIGNAL FEE_DATA_IN :  std_logic_vector(15 downto 0);
SIGNAL FEE_DATAREADY_IN :  std_logic;
SIGNAL FEE_READ_OUT :  std_logic;
SIGNAL FEE_STATUS_BITS_IN :  std_logic_vector(31 downto 0) := x"0000_0000";
SIGNAL FEE_BUSY_IN :  std_logic;

signal gsr : std_logic;

signal MAC_RX_EOF_IN, MAC_RX_EN_IN : std_logic;
signal MAC_RXD_IN : std_logic_vector(7 downto 0);

signal gbe_ready : std_logic;
signal trigger : std_logic;
signal MLT_CTS_NUMBER_OUT : std_logic_vector(16 * 1 - 1 downto 0);
signal MLT_CTS_CODE_OUT : std_logic_vector(8 * 1 - 1 downto 0);
signal MLT_CTS_READOUT_TYPE_OUT : std_logic_vector(4 * 1 - 1 downto 0);
signal MLT_CTS_READOUT_FINISHED_IN : std_logic_vector(1 - 1 downto 0);
signal MLT_CTS_INFORMATION_OUT : std_logic_vector(8 * 1 - 1 downto 0);
signal MLT_CTS_START_READOUT_OUT : std_logic_vector(1 - 1 downto 0);
signal MLT_CTS_DATA_IN : std_logic_vector(32 * 1 - 1 downto 0);
signal MLT_CTS_DATAREADY_IN : std_logic_vector(1 - 1 downto 0);
signal MLT_CTS_READ_OUT : std_logic_vector(1 - 1 downto 0);
signal MLT_CTS_LENGTH_IN : std_logic_vector(16 * 1 - 1 downto 0);
signal MLT_CTS_ERROR_PATTERN_IN : std_logic_vector(32 * 1 - 1 downto 0);
signal MLT_FEE_DATA_OUT : std_logic_vector(16 * 1 - 1 downto 0);
signal MLT_FEE_DATAREADY_OUT : std_logic_vector(1 - 1 downto 0);
signal MLT_FEE_READ_IN : std_logic_vector(1 - 1 downto 0);
signal MLT_FEE_STATUS_BITS_OUT : std_logic_vector(32 * 1 - 1 downto 0);
signal MLT_FEE_BUSY_OUT : std_logic_vector(1 - 1 downto 0);
	
begin
	
	gsr <= not reset;

	
	dummy_inst : entity work.gbe_ipu_dummy
		generic map(DO_SIMULATION    => 1,
			        FIXED_SIZE_MODE  => 1,
			        FIXED_SIZE       => 20,
			        INCREMENTAL_MODE => 0,
			        UP_DOWN_MODE     => 0,
			        UP_DOWN_LIMIT    => 100,
			        FIXED_DELAY_MODE => 1,
			        FIXED_DELAY      => 50)
		port map(clk                     => CLK,
			     rst                     => RESET,
			     GBE_READY_IN            => gbe_ready,
			     
			     CFG_EVENT_SIZE_IN       => x"0000",
			     CFG_TRIGGERED_MODE_IN   => '0',
			     TRIGGER_IN              => trigger,
			     
			     CTS_NUMBER_OUT          => CTS_NUMBER_IN,
			     CTS_CODE_OUT            => CTS_CODE_IN,
			     CTS_INFORMATION_OUT     => CTS_INFORMATION_IN,
			     CTS_READOUT_TYPE_OUT    => CTS_READOUT_TYPE_IN,
			     CTS_START_READOUT_OUT   => CTS_START_READOUT_IN,
			     CTS_DATA_IN             => CTS_DATA_OUT,
			     CTS_DATAREADY_IN        => CTS_DATAREADY_OUT,
			     CTS_READOUT_FINISHED_IN => CTS_READOUT_FINISHED_OUT,
			     CTS_READ_OUT            => CTS_READ_IN,
			     CTS_LENGTH_IN           => CTS_LENGTH_OUT,
			     CTS_ERROR_PATTERN_IN    => CTS_ERROR_PATTERN_OUT,
			     FEE_DATA_OUT            => FEE_DATA_IN,
			     FEE_DATAREADY_OUT       => FEE_DATAREADY_IN,
			     FEE_READ_IN             => FEE_READ_OUT,
			     FEE_STATUS_BITS_OUT     => FEE_STATUS_BITS_IN,
			     FEE_BUSY_OUT            => FEE_BUSY_IN
	);
	
	dummy_mult : entity work.gbe_ipu_multiplexer
		generic map(
			DO_SIMULATION       => 1,
			INCLUDE_DEBUG       => 1,
			LINK_HAS_READOUT    => "1",
			NUMBER_OF_GBE_LINKS => 1
		)
		port map(
			CLK_SYS_IN                  => CLK,
			RESET                       => RESET,
			CTS_NUMBER_IN               => CTS_NUMBER_IN,
			CTS_CODE_IN                 => CTS_CODE_IN,
			CTS_INFORMATION_IN          => CTS_INFORMATION_IN,
			CTS_READOUT_TYPE_IN         => CTS_READOUT_TYPE_IN,
			CTS_START_READOUT_IN        => CTS_START_READOUT_IN,
			CTS_DATA_OUT                => CTS_DATA_OUT,
			CTS_DATAREADY_OUT           => CTS_DATAREADY_OUT,
			CTS_READOUT_FINISHED_OUT    => CTS_READOUT_FINISHED_OUT,
			CTS_READ_IN                 => CTS_READ_IN,
			CTS_LENGTH_OUT              => CTS_LENGTH_OUT,
			CTS_ERROR_PATTERN_OUT       => CTS_ERROR_PATTERN_OUT,
			FEE_DATA_IN                 => FEE_DATA_IN,
			FEE_DATAREADY_IN            => FEE_DATAREADY_IN,
			FEE_READ_OUT                => FEE_READ_OUT,
			FEE_STATUS_BITS_IN          => FEE_STATUS_BITS_IN,
			FEE_BUSY_IN                 => FEE_BUSY_IN,
			MLT_CTS_NUMBER_OUT          => MLT_CTS_NUMBER_OUT,
			MLT_CTS_CODE_OUT            => MLT_CTS_CODE_OUT,
			MLT_CTS_INFORMATION_OUT     => MLT_CTS_INFORMATION_OUT,
			MLT_CTS_READOUT_TYPE_OUT    => MLT_CTS_READOUT_TYPE_OUT,
			MLT_CTS_START_READOUT_OUT   => MLT_CTS_START_READOUT_OUT,
			MLT_CTS_DATA_IN             => MLT_CTS_DATA_IN,
			MLT_CTS_DATAREADY_IN        => MLT_CTS_DATAREADY_IN,
			MLT_CTS_READOUT_FINISHED_IN => MLT_CTS_READOUT_FINISHED_IN,
			MLT_CTS_READ_OUT            => MLT_CTS_READ_OUT,
			MLT_CTS_LENGTH_IN           => MLT_CTS_LENGTH_IN,
			MLT_CTS_ERROR_PATTERN_IN    => MLT_CTS_ERROR_PATTERN_IN,
			MLT_FEE_DATA_OUT            => MLT_FEE_DATA_OUT,
			MLT_FEE_DATAREADY_OUT       => MLT_FEE_DATAREADY_OUT,
			MLT_FEE_READ_IN             => MLT_FEE_READ_IN,
			MLT_FEE_STATUS_BITS_OUT     => MLT_FEE_STATUS_BITS_OUT,
			MLT_FEE_BUSY_OUT            => MLT_FEE_BUSY_OUT,
			DEBUG_OUT                   => open
		);

	dummy_trbnet : entity work.trb_net16_gbe_response_constructor_TrbNetData
		generic map(
			RX_PATH_ENABLE      => 1,
			DO_SIMULATION       => 1,
			READOUT_BUFFER_SIZE => 4
		)
		port map(
			CLK                           => CLK,
			RESET                         => RESET,
			MY_MAC_IN                     => x"001122334455",
			MY_IP_IN                      => x"00112233",
			PS_DATA_IN                    => (others => '0'),
			PS_WR_EN_IN                   => '0',
			PS_ACTIVATE_IN                => '0',
			PS_RESPONSE_READY_OUT         => open,
			PS_BUSY_OUT                   => open,
			PS_SELECTED_IN                => '0',
			PS_SRC_MAC_ADDRESS_IN         => (others => '0'),
			PS_DEST_MAC_ADDRESS_IN        => (others => '0'),
			PS_SRC_IP_ADDRESS_IN          => (others => '0'),
			PS_DEST_IP_ADDRESS_IN         => (others => '0'),
			PS_SRC_UDP_PORT_IN            => (others => '0'),
			PS_DEST_UDP_PORT_IN           => (others => '0'),
			TC_RD_EN_IN                   => '0',
			TC_DATA_OUT                   => open,
			TC_FRAME_SIZE_OUT             => open,
			TC_FRAME_TYPE_OUT             => open,
			TC_IP_PROTOCOL_OUT            => open,
			TC_DEST_MAC_OUT               => open,
			TC_DEST_IP_OUT                => open,
			TC_DEST_UDP_OUT               => open,
			TC_SRC_MAC_OUT                => open,
			TC_SRC_IP_OUT                 => open,
			TC_SRC_UDP_OUT                => open,
			TC_IDENT_OUT                  => open,
			STAT_DATA_OUT                 => open,
			STAT_ADDR_OUT                 => open,
			STAT_DATA_RDY_OUT             => open,
			STAT_DATA_ACK_IN              => '0',
			DEBUG_OUT                     => open,
			CTS_NUMBER_IN                 => CTS_NUMBER_IN,
			CTS_CODE_IN                   => CTS_CODE_IN,
			CTS_INFORMATION_IN            => CTS_INFORMATION_IN,
			CTS_READOUT_TYPE_IN           => CTS_READOUT_TYPE_IN,
			CTS_START_READOUT_IN          => CTS_START_READOUT_IN,
			CTS_DATA_OUT                  => CTS_DATA_OUT,
			CTS_DATAREADY_OUT             => CTS_DATAREADY_OUT,
			CTS_READOUT_FINISHED_OUT      => CTS_READOUT_FINISHED_OUT,
			CTS_READ_IN                   => CTS_READ_IN,
			CTS_LENGTH_OUT                => CTS_LENGTH_OUT,
			CTS_ERROR_PATTERN_OUT         => CTS_ERROR_PATTERN_OUT,
			FEE_DATA_IN                   => FEE_DATA_IN,
			FEE_DATAREADY_IN              => FEE_DATAREADY_IN,
			FEE_READ_OUT                  => FEE_READ_OUT,
			FEE_STATUS_BITS_IN            => FEE_STATUS_BITS_IN,
			FEE_BUSY_IN                   => FEE_BUSY_IN,
			SLV_ADDR_IN                   => (others => '0'),
			SLV_READ_IN                   => '0',
			SLV_WRITE_IN                  => '0',
			SLV_BUSY_OUT                  => open,
			SLV_ACK_OUT                   => open,
			SLV_DATA_IN                   => (others =>'0'),
			SLV_DATA_OUT                  => open,
			CFG_GBE_ENABLE_IN             => '1',
			CFG_IPU_ENABLE_IN             => '1',
			CFG_MULT_ENABLE_IN            => '0',
			CFG_SUBEVENT_ID_IN            => (others => '0'),
			CFG_SUBEVENT_DEC_IN           => (others => '0'),
			CFG_QUEUE_DEC_IN              => (others => '0'),
			CFG_READOUT_CTR_IN            => (others => '0'),
			CFG_READOUT_CTR_VALID_IN      => '0',
			CFG_INSERT_TTYPE_IN           => '0',
			CFG_MAX_SUB_IN                => x"fff0",
			CFG_MAX_QUEUE_IN              => x"fff0",
			CFG_MAX_SUBS_IN_QUEUE_IN      => x"fff0",
			CFG_MAX_SINGLE_SUB_IN         => x"fff0",
			MONITOR_SELECT_REC_OUT        => open,
			MONITOR_SELECT_REC_BYTES_OUT  => open,
			MONITOR_SELECT_SENT_BYTES_OUT => open,
			MONITOR_SELECT_SENT_OUT       => open,
			MONITOR_SELECT_DROP_IN_OUT    => open,
			MONITOR_SELECT_DROP_OUT_OUT   => open,
			DATA_HIST_OUT                 => open
		);

-- 100 MHz system clock
CLOCK_GEN_PROC: process
begin
	CLK <= '1'; wait for 5.0 ns;
	CLK <= '0'; wait for 5.0 ns;
end process CLOCK_GEN_PROC;


testbench_proc : process
begin
	reset <= '1'; 
	
	trigger <= '0';
	gbe_ready <= '1';
	
	FEE_READ_OUT <= '1';

	wait for 100 ns;
	reset <= '0';
	
	wait for 1 us;

	trigger <= '1';
	wait for 100 ns;
	trigger <= '0';
	
	
	wait for 500 ns;
	wait until rising_edge(CLK);
	FEE_READ_OUT <= '0';
	wait until rising_edge(CLK);
	FEE_READ_OUT <= '1';
	
	wait;

end process testbench_proc;

end; 