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