library ieee;

use ieee.std_logic_1164.all;
use IEEE.numeric_std.all;
use IEEE.std_logic_UNSIGNED.all;
use IEEE.std_logic_arith.all;

library work;
use work.trb_net_std.all;
use work.trb_net_components.all;
use work.trb_net16_hub_func.all;

use work.trb_net_gbe_components.all;
use work.trb_net_gbe_protocols.all;

entity trb_net16_gbe_ipu_interface is
	generic(
		DO_SIMULATION : integer range 0 to 1 := 0
	);
	port(
		CLK_IPU                  : in  std_logic;
		CLK_GBE                  : in  std_logic;
		RESET                    : in  std_logic;
		-- IPU interface directed toward the CTS
		CTS_NUMBER_IN            : in  std_logic_vector(15 downto 0);
		CTS_CODE_IN              : in  std_logic_vector(7 downto 0);
		CTS_INFORMATION_IN       : in  std_logic_vector(7 downto 0);
		CTS_READOUT_TYPE_IN      : in  std_logic_vector(3 downto 0);
		CTS_START_READOUT_IN     : in  std_logic;
		CTS_READ_IN              : in  std_logic;
		CTS_DATA_OUT             : out std_logic_vector(31 downto 0);
		CTS_DATAREADY_OUT        : out std_logic;
		CTS_READOUT_FINISHED_OUT : out std_logic; --no more data, end transfer, send TRM
		CTS_LENGTH_OUT           : out std_logic_vector(15 downto 0);
		CTS_ERROR_PATTERN_OUT    : out std_logic_vector(31 downto 0);
		-- Data from Frontends
		FEE_DATA_IN              : in  std_logic_vector(15 downto 0);
		FEE_DATAREADY_IN         : in  std_logic;
		FEE_READ_OUT             : out std_logic;
		FEE_BUSY_IN              : in  std_logic;
		FEE_STATUS_BITS_IN       : in  std_logic_vector(31 downto 0);
		-- slow control interface
		START_CONFIG_OUT         : out std_logic; -- reconfigure MACs/IPs/ports/packet size
		BANK_SELECT_OUT          : out std_logic_vector(3 downto 0); -- configuration page address
		CONFIG_DONE_IN           : in  std_logic; -- configuration finished
		DATA_GBE_ENABLE_IN       : in  std_logic; -- IPU data is forwarded to GbE
		DATA_IPU_ENABLE_IN       : in  std_logic; -- IPU data is forwarded to CTS / TRBnet
		MULT_EVT_ENABLE_IN       : in  std_logic;
		MAX_SUBEVENT_SIZE_IN     : in  std_logic_vector(15 downto 0);
		MAX_QUEUE_SIZE_IN        : in  std_logic_vector(15 downto 0);
		MAX_SUBS_IN_QUEUE_IN     : in  std_logic_vector(15 downto 0);
		MAX_SINGLE_SUB_SIZE_IN   : in  std_logic_vector(15 downto 0);
		READOUT_CTR_IN           : in  std_logic_vector(23 downto 0); -- gk 26.04.10
		READOUT_CTR_VALID_IN     : in  std_logic; -- gk 26.04.10
		CFG_AUTO_THROTTLE_IN     : in  std_logic;
		CFG_THROTTLE_PAUSE_IN    : in  std_logic_vector(15 downto 0);
		-- PacketConstructor interface
		PC_WR_EN_OUT             : out std_logic;
		PC_DATA_OUT              : out std_logic_vector(7 downto 0);
		PC_READY_IN              : in  std_logic;
		PC_SOS_OUT               : out std_logic;
		PC_EOS_OUT               : out std_logic;
		PC_EOQ_OUT               : out std_logic;
		PC_SUB_SIZE_OUT          : out std_logic_vector(31 downto 0);
		PC_TRIG_NR_OUT           : out std_logic_vector(31 downto 0);
		PC_TRIGGER_TYPE_OUT      : out std_logic_vector(3 downto 0);
		MONITOR_OUT              : out std_logic_vector(223 downto 0);
		DEBUG_OUT                : out std_logic_vector(383 downto 0)
	);
end entity trb_net16_gbe_ipu_interface;

architecture RTL of trb_net16_gbe_ipu_interface is
	attribute syn_encoding : string;

	type saveStates is (IDLE, SAVE_EVT_ADDR, WAIT_FOR_DATA, PRE_SAVE_DATA, SAVE_PRE_DATA, SAVE_DATA, ADD_SUBSUB1, ADD_SUBSUB2, ADD_SUBSUB3, ADD_SUBSUB4, ADD_MISSING, TERMINATE, SEND_TERM_PULSE, THROTTLE_PAUSE, CLOSE, FINISH_4_WORDS, CLEANUP);
	signal save_current_state, save_next_state : saveStates;
	attribute syn_encoding of save_current_state : signal is "onehot";

	type loadStates is (IDLE, WAIT_FOR_SUBS, REMOVE, WAIT_ONE, WAIT_TWO, DECIDE, PREPARE_TO_LOAD_SUB, WAIT_FOR_LOAD, LOAD, FINISH_ONE, FINISH_TWO, CLOSE_SUB, CLOSE_QUEUE, CLOSE_QUEUE_IMMEDIATELY);
	signal load_current_state, load_next_state : loadStates;
	attribute syn_encoding of load_current_state : signal is "onehot";

	signal sf_data                                                                     : std_Logic_vector(15 downto 0);
	signal save_eod, sf_wr_en, sf_rd_en, sf_reset, sf_empty, sf_full, sf_afull, sf_eos : std_logic;
	signal sf_q, pc_data                                                               : std_logic_vector(7 downto 0);

	signal cts_rnd, cts_trg : std_logic_vector(15 downto 0);
	signal save_ctr         : std_logic_vector(15 downto 0);

	signal saved_events_ctr, loaded_events_ctr, saved_events_ctr_gbe : std_logic_vector(31 downto 0);
	signal loaded_bytes_ctr                                          : std_Logic_vector(15 downto 0);

	signal trigger_random : std_logic_vector(7 downto 0);
	signal trigger_number : std_logic_vector(15 downto 0);
	signal subevent_size  : std_logic_vector(17 downto 0);
	signal trigger_type   : std_logic_vector(3 downto 0);

	signal bank_select                                                          : std_logic_vector(3 downto 0);
	signal readout_ctr                                                          : std_logic_vector(23 downto 0) := x"000000";
	signal pc_ready_q                                                           : std_logic;
	signal sf_afull_q, sf_afull_qq, sf_afull_qqq, sf_afull_qqqq, sf_afull_qqqqq : std_logic := '0';
	signal sf_aempty                                                            : std_logic;
	signal rec_state, load_state                                                : std_logic_vector(3 downto 0);
	signal queue_size                                                           : std_logic_vector(17 downto 0);
	signal number_of_subs                                                       : std_logic_vector(15 downto 0);
	signal size_check_ctr                                                       : integer range 0 to 7;
	signal sf_data_q, sf_data_qq, sf_data_qqq, sf_data_qqqq, sf_data_qqqqq, sf_data_qqqqqq      : std_logic_vector(15 downto 0);
	signal sf_wr_q, sf_wr_lock                                                  : std_logic;
	signal save_eod_q, save_eod_qq, save_eod_qqq, save_eod_qqqq, save_eod_qqqqq : std_logic;
	signal sf_wr_qq, sf_wr_qqq, sf_wr_qqqq, sf_wr_qqqqq                         : std_logic;
	signal too_large_dropped                                                    : std_logic_vector(31 downto 0);
	signal previous_ttype, previous_bank                                        : std_logic_vector(3 downto 0);
	signal sf_afull_real                                                        : std_logic;
	signal sf_cnt                                                               : std_logic_vector(15 downto 0);

	signal local_fee_busy, local_fee_busy_q, local_fee_busy_qq, local_fee_busy_qqq, local_fee_busy_qqqq, local_fee_busy_qqqqq, local_fee_busy_qqqqqq, local_fee_busy_qqqqqqq, local_fee_busy_qqqqqqqq : std_logic;

	attribute syn_keep : string;
	attribute syn_keep of sf_cnt : signal is "true";
	signal saved_bytes_ctr : std_logic_vector(31 downto 0);
	signal longer_busy_ctr : std_logic_vector(7 downto 0);
	signal uneven_ctr      : std_logic_vector(3 downto 0);
	signal saved_size      : std_logic_vector(16 downto 0);
	signal overwrite_afull : std_logic;

	signal last_three_bytes    : std_logic_vector(3 downto 0);
	signal sf_eos_q, sf_eos_qq : std_logic;
	signal eos_ctr             : std_logic_vector(3 downto 0);

	signal stream_bytes_ps : std_logic_vector(31 downto 0);
	signal one_sec_ctr     : std_logic_vector(31 downto 0);
	signal one_sec_tick    : std_logic;
	signal pause_ctr	   : std_logic_vector(31 downto 0);
	
	signal fee_dataready, fee_dataready_q, fee_dataready_qq, fee_dataready_qqq, fee_dataready_qqqq, fee_dataready_qqqqq : std_logic;
	
	signal temp_data_store : std_logic_vector(6 * 16 - 1 downto 0) := (others => '0');
	
	signal local_read, local_read_q, local_read_qq, local_read_qqq, local_read_qqqq, local_read_qqqqq, local_read_qqqqqq, local_read_qqqqqqq, local_read_qqqqqqqq, local_read_qqqqqqqqq : std_logic := '0';

begin

	--*********
	-- RECEIVING PART
	--*********

	SAVE_MACHINE_PROC : process(RESET, CLK_IPU)
	begin
		if RESET = '1' then
			save_current_state <= IDLE;
		elsif rising_edge(CLK_IPU) then
			save_current_state <= save_next_state;
		end if;
	end process SAVE_MACHINE_PROC;

	SAVE_MACHINE : process(save_current_state, CTS_START_READOUT_IN, pause_ctr, local_fee_busy, saved_size, FEE_BUSY_IN, CTS_READ_IN, size_check_ctr)
	begin
		rec_state <= x"0";
		case (save_current_state) is
			when IDLE =>
				rec_state <= x"1";
				if (CTS_START_READOUT_IN = '1') then
					save_next_state <= SAVE_EVT_ADDR;
				else
					save_next_state <= IDLE;
				end if;

			when SAVE_EVT_ADDR =>
				rec_state       <= x"2";
				save_next_state <= WAIT_FOR_DATA;

			when WAIT_FOR_DATA =>
				rec_state <= x"3";
				if (FEE_BUSY_IN = '1') then
					save_next_state <= PRE_SAVE_DATA;
				else
					save_next_state <= WAIT_FOR_DATA;
				end if;
				
			when PRE_SAVE_DATA =>
				rec_state <= x"e";
				if (size_check_ctr = 5) then
					save_next_state <= SAVE_PRE_DATA;
				else
					save_next_state <= PRE_SAVE_DATA;
				end if;
				
			when SAVE_PRE_DATA =>
				rec_state <= x"e";
				if (size_check_ctr = 0) then
					save_next_state <= SAVE_DATA;
				else
					save_next_state <= SAVE_PRE_DATA;
				end if;

			when SAVE_DATA =>
				rec_state <= x"4";
				--if (FEE_BUSY_IN = '0') then
				if (local_fee_busy = '0') then
					save_next_state <= TERMINATE;
				else
					save_next_state <= SAVE_DATA;
				end if;

			when TERMINATE =>
				rec_state <= x"5";
				if (CTS_READ_IN = '1') then
					save_next_state <= SEND_TERM_PULSE; --CLOSE;
				else
					save_next_state <= TERMINATE;
				end if;

			when SEND_TERM_PULSE =>
				rec_state       <= x"6";
				save_next_state <= CLOSE;

			when CLOSE =>
				rec_state <= x"6";
				--if (CTS_START_READOUT_IN = '0') then
					if (saved_size = x"0000" & "0") then
						save_next_state <= ADD_SUBSUB1;
					else
						save_next_state <= ADD_MISSING;
					end if;
				--else
				--	save_next_state <= CLOSE;
				--end if;

			when ADD_MISSING =>
				rec_state <= x"d";
				if (saved_size = x"0000" & "1") then
					save_next_state <= ADD_SUBSUB1;
				else
					save_next_state <= ADD_MISSING;
				end if;

			when ADD_SUBSUB1 =>
				rec_state       <= x"7";
				save_next_state <= ADD_SUBSUB2;

			when ADD_SUBSUB2 =>
				rec_state       <= x"8";
				save_next_state <= ADD_SUBSUB3;

			when ADD_SUBSUB3 =>
				rec_state       <= x"9";
				save_next_state <= ADD_SUBSUB4;

			when ADD_SUBSUB4 =>
				rec_state       <= x"a";
				save_next_state <= FINISH_4_WORDS;

			when FINISH_4_WORDS =>
				rec_state <= x"b";
				if (size_check_ctr = 1) then
					save_next_state <= CLEANUP;
				else
					save_next_state <= FINISH_4_WORDS;
				end if;

			when CLEANUP =>
				rec_state       <= x"c";
				--save_next_state <= THROTTLE_PAUSE; -- IDLE;
				if (CTS_START_READOUT_IN = '0') then
					save_next_state <= IDLE;
				else
					save_next_state <= CLEANUP;
				end if;

			when others => save_next_state <= IDLE;

		end case;
	end process SAVE_MACHINE;
	
	process(CLK_IPU)
	begin
		if rising_edge(CLK_IPU) then
			if (save_current_state = IDLE) then
				pause_ctr <= (others => '0');
			elsif (save_current_state = THROTTLE_PAUSE) then
				pause_ctr <= pause_ctr + x"1";
			else
				pause_ctr <= pause_ctr;
			end if;
		end if;
	end process;	

	SF_WR_EN_PROC : process(CLK_IPU)
	begin
		if rising_edge(CLK_IPU) then


			--if (sf_afull_q = '0' and save_current_state = SAVE_DATA and FEE_DATAREADY_IN = '1' and FEE_BUSY_IN = '1') then
			--if (sf_afull_qqqqq = '0' and save_current_state = SAVE_DATA and FEE_DATAREADY_IN = '1' and FEE_BUSY_IN = '1') then
			--if (sf_afull_qqqqq = '0' and save_current_state = SAVE_DATA and FEE_DATAREADY_IN = '1' and local_fee_busy = '1') then
			--if (sf_afull_qqqqq = '0' and save_current_state = SAVE_DATA and fee_dataready_qqqqq = '1') then --FEE_DATAREADY_IN = '1') then
			if (save_current_state = SAVE_DATA and local_read_qqqqqqqqq = '1' and fee_dataready_qqqqq = '1') then
				sf_wr_en <= '1';
			elsif (save_current_state = SAVE_PRE_DATA) then
				sf_wr_en <= '1';
			elsif (save_current_state = ADD_SUBSUB1 or save_current_state = ADD_SUBSUB2 or save_current_state = ADD_SUBSUB3 or save_current_state = ADD_SUBSUB4) then
				sf_wr_en <= '1';
			elsif (save_current_state = FINISH_4_WORDS) then
				sf_wr_en <= '1';
			elsif (save_current_state = ADD_MISSING) then
				sf_wr_en <= '1';
			else
				sf_wr_en <= '0';
			end if;
		end if;
	end process SF_WR_EN_PROC;

	LOCAL_BUSY_PROC : process(CLK_IPU)
	begin
		if rising_edge(CLK_IPU) then
			if (save_current_state = IDLE) then
				longer_busy_ctr <= x"14";
			elsif (save_current_state = SAVE_DATA and FEE_BUSY_IN = '0' and sf_afull_qqqqq = '0') then
				longer_busy_ctr <= longer_busy_ctr - x"1";
			else
				longer_busy_ctr <= longer_busy_ctr;
			end if;

			if (FEE_BUSY_IN = '1') then
				local_fee_busy <= '1';
			elsif (save_current_state = SAVE_DATA and longer_busy_ctr > x"00") then
				local_fee_busy <= '1';
			else
				local_fee_busy <= '0';
			end if;
		end if;
	end process LOCAL_BUSY_PROC;

	SF_DATA_EOD_PROC : process(CLK_IPU)
	begin
		if rising_edge(CLK_IPU) then
			case (save_current_state) is
									
				when SAVE_PRE_DATA =>
					sf_data <= temp_data_store( (5 - size_check_ctr + 1) * 16 - 1 downto (5 - size_check_ctr) * 16);
					save_eod <= '0';

				when SAVE_DATA =>
					sf_data  <= sf_data_qqqqqq;
					save_eod <= '0';

				when ADD_SUBSUB1 =>
					sf_data  <= x"0001";
					save_eod <= '0';

				when ADD_SUBSUB2 =>
					sf_data  <= x"5555";
					save_eod <= '0';

				when ADD_SUBSUB3 =>
					sf_data  <= FEE_STATUS_BITS_IN(31 downto 16);
					save_eod <= '1';

				when ADD_SUBSUB4 =>
					sf_data  <= FEE_STATUS_BITS_IN(15 downto 0);
					save_eod <= '0';

				when others => sf_data <= sf_data;
					save_eod <= '0';

			end case;
		end if;
	end process SF_DATA_EOD_PROC;

	process(CLK_IPU)
	begin
		if rising_edge(CLK_IPU) then
			
			sf_data_q     <= FEE_DATA_IN;
			sf_data_qq    <= sf_data_q;
			sf_data_qqq   <= sf_data_qq;
			sf_data_qqqq  <= sf_data_qqq;
			sf_data_qqqqq <= sf_data_qqqq;
			sf_data_qqqqqq <= sf_data_qqqqq;

			save_eod_q     <= save_eod;
			save_eod_qq    <= save_eod_q;
			save_eod_qqq   <= save_eod_qq;
			save_eod_qqqq  <= save_eod_qqq;
			save_eod_qqqqq <= save_eod_qqqq;
			
			sf_afull_q     <= sf_afull;
			sf_afull_qq    <= sf_afull_q;
			sf_afull_qqq   <= sf_afull_qq;
			sf_afull_qqqq  <= sf_afull_qqq;
			sf_afull_qqqqq <= sf_afull_qqqq;
			
			sf_wr_q     <= sf_wr_en and (not sf_wr_lock) and DATA_GBE_ENABLE_IN;
			sf_wr_qq    <= sf_wr_q;
			sf_wr_qqq   <= sf_wr_qq;
			sf_wr_qqqq  <= sf_wr_qqq;
			sf_wr_qqqqq <= sf_wr_qqqq;	
			
			fee_dataready <= FEE_DATAREADY_IN;	
			fee_dataready_q <= fee_dataready;
			fee_dataready_qq <= fee_dataready_q;
			fee_dataready_qqq <= fee_dataready_qq;
			fee_dataready_qqqq <= fee_dataready_qqq;
			fee_dataready_qqqqq <= fee_dataready_qqqq;	

		end if;
	end process;


	process(CLK_IPU)
	begin
		if rising_edge(CLK_IPU) then
			if (save_current_state = IDLE) then
				size_check_ctr <= 1;
			elsif (save_current_state = PRE_SAVE_DATA and FEE_DATAREADY_IN = '1' and size_check_ctr /= 5) then
				size_check_ctr <= size_check_ctr + 1;
			elsif (save_current_state = SAVE_PRE_DATA and size_check_ctr /= 0) then
				size_check_ctr <= size_check_ctr - 1;				
			else
				size_check_ctr <= size_check_ctr;
			end if;
			
			if (save_current_state = IDLE) then
				sf_wr_lock <= '1';
				saved_size <= (others => '0');
			elsif (save_current_state = PRE_SAVE_DATA and size_check_ctr = 3 and FEE_DATAREADY_IN = '1' and (sf_data & "00") < ("00" & MAX_SUBEVENT_SIZE_IN)) then -- condition to ALLOW an event to be passed forward
				sf_wr_lock <= '0';
				saved_size <= (FEE_DATA_IN & "0") + x"1";

--			elsif (save_current_state = PRE_SAVE_DATA and sf_wr_q = '1') then
--				saved_size <= saved_size - x"1";
--			elsif (save_current_state = ADD_MISSING) then
--				saved_size <= saved_size - x"1";
			else
				sf_wr_lock <= sf_wr_lock;
				saved_size <= saved_size;
			end if;
			
		end if;
	end process;
	
	process(CLK_IPU)
	begin
		if rising_edge(CLK_IPU) then
			if (save_current_state = SAVE_EVT_ADDR) then
				temp_data_store(15 downto 0) <= x"ab" & CTS_READOUT_TYPE_IN & CTS_INFORMATION_IN(3 downto 0);
			elsif (save_current_state = PRE_SAVE_DATA and FEE_DATAREADY_IN = '1') then
				temp_data_store( (size_check_ctr + 2) * 16 - 1 downto (size_check_ctr + 1) * 16) <= FEE_DATA_IN;
			else
				temp_data_store <= temp_data_store;
			end if;
		end if;
	end process;

--	process(CLK_IPU)
--	begin
--		if rising_edge(CLK_IPU) then
--			if (save_current_state = IDLE) then
--				size_check_ctr <= 0;
--			elsif (save_current_state = SAVE_DATA and sf_wr_en = '1' and size_check_ctr /= 4) then
--				size_check_ctr <= size_check_ctr + 1;
--			elsif (save_current_state = FINISH_4_WORDS and size_check_ctr /= 0) then
--				size_check_ctr <= size_check_ctr - 1;
--			else
--				size_check_ctr <= size_check_ctr;
--			end if;
--
--			if (save_current_state = IDLE) then
--				sf_wr_lock <= '1';
--				saved_size <= (others => '0');
--			elsif (save_current_state = SAVE_DATA and size_check_ctr = 2 and sf_wr_en = '1' and (sf_data & "00") < ("00" & MAX_SUBEVENT_SIZE_IN)) then -- condition to ALLOW an event to be passed forward
--				sf_wr_lock <= '0';
--				saved_size <= (sf_data & "0") + x"1";
--			elsif (save_current_state = SAVE_DATA and sf_wr_q = '1') then
--				saved_size <= saved_size - x"1";
--			elsif (save_current_state = ADD_MISSING) then
--				saved_size <= saved_size - x"1";
--			else
--				sf_wr_lock <= sf_wr_lock;
--				saved_size <= saved_size;
--			end if;
--
--		end if;
--	end process;

	process(RESET, CLK_IPU)
	begin
		if (RESET = '1') then
			too_large_dropped <= (others => '0');
		elsif rising_edge(CLK_IPU) then
			if (save_current_state = SAVE_DATA and size_check_ctr = 2 and sf_wr_en = '1' and (sf_data & "00") >= ("00" & MAX_SUBEVENT_SIZE_IN)) then
				too_large_dropped <= too_large_dropped + x"1";
			else
				too_large_dropped <= too_large_dropped;
			end if;
		end if;
	end process;

	SAVED_EVENTS_CTR_PROC : process(RESET, CLK_IPU)
	begin
		if (RESET = '1') then
			saved_events_ctr <= (others => '0');
		elsif rising_edge(CLK_IPU) then
			--if (save_current_state = ADD_SUBSUB4 and sf_wr_lock = '0' and DATA_GBE_ENABLE_IN = '1') then
			if (save_current_state = SEND_TERM_PULSE and DATA_GBE_ENABLE_IN = '1') then
				saved_events_ctr <= saved_events_ctr + x"1";
			else
				saved_events_ctr <= saved_events_ctr;
			end if;
		end if;
	end process SAVED_EVENTS_CTR_PROC;

	CTS_DATAREADY_PROC : process(CLK_IPU)
	begin
		if rising_edge(CLK_IPU) then
			--if (save_current_state = SAVE_DATA and FEE_BUSY_IN = '0') then
			if (save_current_state = SAVE_DATA and local_fee_busy = '0') then
				CTS_DATAREADY_OUT <= '1';
			elsif (save_current_state = TERMINATE) then
				CTS_DATAREADY_OUT <= '1';
			else
				CTS_DATAREADY_OUT <= '0';
			end if;
		end if;
	end process CTS_DATAREADY_PROC;

	CTS_READOUT_FINISHED_PROC : process(CLK_IPU)
	begin
		if rising_edge(CLK_IPU) then
			if (save_current_state = CLEANUP) then
				CTS_READOUT_FINISHED_OUT <= '1';
			else
				CTS_READOUT_FINISHED_OUT <= '0';
			end if;
		end if;
	end process CTS_READOUT_FINISHED_PROC;

	CTS_LENGTH_OUT        <= (others => '0');
	CTS_ERROR_PATTERN_OUT <= (others => '0');

	CTS_DATA_PROC : process(CLK_IPU)
	begin
		if rising_edge(CLK_IPU) then
			CTS_DATA_OUT <= "0001" & cts_rnd(11 downto 0) & cts_trg;
		end if;
	end process CTS_DATA_PROC;

	CTS_RND_TRG_PROC : process(CLK_IPU)
	begin
		if rising_edge(CLK_IPU) then
			if (save_current_state = SAVE_DATA and save_ctr = x"0000") then
				cts_rnd <= sf_data;
				cts_trg <= cts_trg;
			elsif (save_current_state = SAVE_DATA and save_ctr = x"0001") then
				cts_rnd <= cts_rnd;
				cts_trg <= sf_data;
			else
				cts_rnd <= cts_rnd;
				cts_trg <= cts_trg;
			end if;
		end if;
	end process CTS_RND_TRG_PROC;

	SAVE_CTR_PROC : process(CLK_IPU)
	begin
		if rising_edge(CLK_IPU) then
			if (save_current_state = IDLE) then
				save_ctr <= (others => '0');
			elsif (save_current_state = SAVE_DATA and sf_wr_en = '1') then
				save_ctr <= save_ctr + x"1";
			else
				save_ctr <= save_ctr;
			end if;
		end if;
	end process SAVE_CTR_PROC;

	sf_afull_sim_gen : if DO_SIMULATION = 1 generate

		--				process
		--				begin
		--					sf_afull <= '0';
		--					wait for 21310 ns;
		--					sf_afull <= '1';
		--					wait for 10 ns;
		--					sf_afull <= sf_afull_real;			
		--					wait;
		--				end process;

		sf_afull <= sf_afull_real;

	end generate sf_afull_sim_gen;

	sf_afull_impl_gen : if DO_SIMULATION = 0 generate
		sf_afull <= sf_afull_real;
	end generate sf_afull_impl_gen;

	--	size_check_debug : if DO_SIMULATION = 1 generate
	--		
	--		process(save_ctr, sf_data_qqqqq, save_current_state)
	--		begin
	--			if (save_ctr > x"000c" and save_current_state = SAVE_DATA) then
	--				assert (save_ctr - x"000c" = sf_data_qqqqq) report "IPU_INTERFACE: Mismatch between data and internal counters" severity warning;
	--			end if;
	--		end process;
	--		
	--	end generate size_check_debug;

	process(CLK_IPU)
	begin
		if rising_edge(CLK_IPU) then
			if (save_current_state = IDLE) then
				overwrite_afull <= '0';
			elsif (sf_wr_q = '1' and save_current_state /= SAVE_DATA) then
				overwrite_afull <= '1';
			elsif (save_current_state = SAVE_DATA) then
				overwrite_afull <= '0';
			else
				overwrite_afull <= overwrite_afull;
			end if;
		end if;
	end process;

	FEE_READ_PROC : process(CLK_IPU)
	begin
		if rising_edge(CLK_IPU) then
			if (save_current_state = SAVE_DATA) then
				if (sf_afull = '0' or overwrite_afull = '1') then
					local_read <= '1';
				else
					local_read <= '0';
				end if;
			elsif (save_current_state = SAVE_PRE_DATA) then
				local_read <= '0';
			elsif (save_current_state = PRE_SAVE_DATA and size_check_ctr > 2 and FEE_DATAREADY_IN = '1') then	
				local_read <= '0';
			elsif (save_current_state = PRE_SAVE_DATA and size_check_ctr > 3) then	
				local_read <= '0';
			else
				local_read <= '1';
			end if;
			
			local_read_q <= local_read;
			local_read_qq <= local_read_q;
			local_read_qqq <= local_read_qq;
			local_read_qqqq <= local_read_qqq;
			local_read_qqqqq <= local_read_qqqq;
			local_read_qqqqqq <= local_read_qqqqq;
			local_read_qqqqqqq <= local_read_qqqqqq;
			local_read_qqqqqqqq <= local_read_qqqqqqq;
			local_read_qqqqqqqqq <= local_read_qqqqqqqq;
			
		end if;
	end process FEE_READ_PROC;
	
	FEE_READ_OUT <= local_read;

	THE_SPLIT_FIFO : entity work.fifo_32kx18x9_wcnt -- fifo_32kx16x8_mb2  --fifo_16kx18x9
		port map(
			-- Byte swapping for correct byte order on readout side of FIFO
			Data(7 downto 0)  => sf_data_qqqqq(15 downto 8),
			Data(8)           => '0',
			Data(16 downto 9) => sf_data_qqqqq(7 downto 0),
			Data(17)          => save_eod_qqqqq,
			WrClock           => CLK_IPU,
			RdClock           => CLK_GBE,
			WrEn              => sf_wr_q, -- sf_wr_en
			RdEn              => sf_rd_en,
			Reset             => sf_reset,
			RPReset           => sf_reset,
			AmEmptyThresh     => b"0000_0000_0000_0010", --b"0000_0000_0000_0010", -- one byte ahead
			AmFullThresh      => b"001_1111_1110_1111", -- 0x7fef = 32751 -- b"001_0011_1000_1000"
			Q(7 downto 0)     => sf_q,
			Q(8)              => sf_eos,
			WCNT              => sf_cnt,
			--RCNT              => open,
			Empty             => sf_empty,
			AlmostEmpty       => sf_aempty,
			Full              => sf_full, -- WARNING, JUST FOR DEBUG
			AlmostFull        => sf_afull_real
		);

	sf_reset <= RESET;

	bytes_ctr_gen : if DO_SIMULATION = 1 generate
		process(CLK_IPU)
		begin
			if rising_edge(CLK_IPU) then
				if (RESET = '1') then
					saved_bytes_ctr <= (others => '0');
				elsif (save_current_state = SAVE_DATA and sf_wr_q = '1') then
					saved_bytes_ctr <= saved_bytes_ctr + x"2";
				elsif (save_current_state = CLEANUP) then
					saved_bytes_ctr <= (others => '0');
				else
					saved_bytes_ctr <= saved_bytes_ctr;
				end if;
			end if;
		end process;
	end generate bytes_ctr_gen;

	--*********
	-- LOADING PART
	--*********

	PC_DATA_PROC : process(CLK_GBE)
	begin
		if rising_edge(CLK_GBE) then
			pc_data <= sf_q;
		end if;
	end process PC_DATA_PROC;

	LOAD_MACHINE_PROC : process(RESET, CLK_GBE)
	begin
		if RESET = '1' then
			load_current_state <= IDLE;
		elsif rising_edge(CLK_GBE) then
			load_current_state <= load_next_state;
		end if;
	end process LOAD_MACHINE_PROC;

	LOAD_MACHINE : process(load_current_state, saved_events_ctr_gbe, loaded_events_ctr, loaded_bytes_ctr, last_three_bytes, sf_eos_q, sf_rd_en, eos_ctr, PC_READY_IN, sf_eos, queue_size, number_of_subs, subevent_size, MAX_QUEUE_SIZE_IN, MAX_SUBS_IN_QUEUE_IN, MAX_SINGLE_SUB_SIZE_IN, previous_bank, previous_ttype, trigger_type, bank_select, MULT_EVT_ENABLE_IN)
	begin
		load_state <= x"0";
		case (load_current_state) is
			when IDLE =>
				load_state      <= x"1";
				load_next_state <= WAIT_FOR_SUBS;

			when WAIT_FOR_SUBS =>
				load_state <= x"2";
				if (saved_events_ctr_gbe /= loaded_events_ctr) then
					load_next_state <= REMOVE;
				else
					load_next_state <= WAIT_FOR_SUBS;
				end if;

			when REMOVE =>
				load_state <= x"3";
				if (loaded_bytes_ctr = x"0008") then
					load_next_state <= WAIT_ONE;
				else
					load_next_state <= REMOVE;
				end if;

			when WAIT_ONE =>
				load_state      <= x"4";
				load_next_state <= WAIT_TWO;

			when WAIT_TWO =>
				load_state      <= x"5";
				load_next_state <= DECIDE;

			--TODO: all queue split conditions here and also in the size process
			when DECIDE =>
				load_state <= x"6";
				if (queue_size > ("00" & MAX_QUEUE_SIZE_IN)) then -- max udp packet exceeded
					load_next_state <= CLOSE_QUEUE;
				elsif (MULT_EVT_ENABLE_IN = '1' and number_of_subs = MAX_SUBS_IN_QUEUE_IN) then
					load_next_state <= CLOSE_QUEUE;
				elsif (MULT_EVT_ENABLE_IN = '0' and number_of_subs = 1) then
					load_next_state <= CLOSE_QUEUE;
				elsif (trigger_type /= previous_ttype and number_of_subs /= x"0000") then
					load_next_state <= CLOSE_QUEUE;
				elsif (bank_select /= previous_bank and number_of_subs /= x"0000") then
					load_next_state <= CLOSE_QUEUE;
				else
					load_next_state <= PREPARE_TO_LOAD_SUB;
				end if;

			when PREPARE_TO_LOAD_SUB =>
				load_state      <= x"7";
				load_next_state <= WAIT_FOR_LOAD;

			when WAIT_FOR_LOAD =>
				load_state <= x"8";
				if (PC_READY_IN = '1') then
					load_next_state <= LOAD;
				else
					load_next_state <= WAIT_FOR_LOAD;
				end if;

			when LOAD =>
				load_state <= x"9";
				if (sf_eos = '1' and sf_rd_en = '1') then
					load_next_state <= FINISH_ONE;
				elsif (sf_eos = '1' and sf_rd_en = '0') then
					load_next_state <= FINISH_TWO;
				else
					load_next_state <= LOAD;
				end if;

			when FINISH_ONE =>
				load_state <= x"d";
				if (PC_READY_IN = '1') then
					load_next_state <= CLOSE_SUB;
				else
					load_next_state <= FINISH_ONE;
				end if;

			when FINISH_TWO =>
				load_state <= x"e";
				if (PC_READY_IN = '1') then
					load_next_state <= FINISH_ONE;
				else
					load_next_state <= FINISH_TWO;
				end if;

			when CLOSE_SUB =>
				load_state <= x"a";
				if (subevent_size > ("00" & MAX_SINGLE_SUB_SIZE_IN) and queue_size = (subevent_size + x"10" + x"8" + x"4")) then
					load_next_state <= CLOSE_QUEUE_IMMEDIATELY;
				else
					load_next_state <= WAIT_FOR_SUBS;
				end if;

			when CLOSE_QUEUE =>
				load_state      <= x"b";
				load_next_state <= PREPARE_TO_LOAD_SUB;

			when CLOSE_QUEUE_IMMEDIATELY =>
				load_state      <= x"c";
				load_next_state <= WAIT_FOR_SUBS;

			when others => load_next_state <= IDLE;

		end case;
	end process LOAD_MACHINE;

	saved_ctr_sync : signal_sync
		generic map(
			WIDTH => 32,
			DEPTH => 2
		)
		port map(
			RESET => RESET,
			CLK0  => CLK_GBE,
			CLK1  => CLK_GBE,
			D_IN  => saved_events_ctr,
			D_OUT => saved_events_ctr_gbe
		);

	process(CLK_GBE)
	begin
		if rising_edge(CLK_GBE) then
			if (load_current_state = LOAD) then
				last_three_bytes <= x"1";
			elsif (load_current_state = CLOSE_SUB and PC_READY_IN = '1') then
				last_three_bytes <= last_three_bytes - x"1";
			else
				last_three_bytes <= last_three_bytes;
			end if;
		end if;
	end process;

	process(CLK_GBE)
	begin
		if rising_edge(CLK_GBE) then
			if (load_current_state = REMOVE) then
				sf_eos_q <= '0';
			elsif (load_current_state = LOAD and sf_eos = '1') then
				sf_eos_q <= '1';
			else
				sf_eos_q <= sf_eos_q;
			end if;

			sf_eos_qq <= sf_eos_q;

			if (load_current_state = REMOVE or load_current_state = IDLE) then
				eos_ctr <= x"f";
			elsif (eos_ctr = x"f" and load_current_state = LOAD and sf_eos = '1' and sf_rd_en = '1') then
				eos_ctr <= x"1";
			elsif (eos_ctr = x"f" and load_current_state = LOAD and sf_eos = '1' and sf_rd_en = '0') then
				eos_ctr <= x"2";
			elsif (eos_ctr /= x"f" and load_current_state = LOAD and sf_rd_en = '1') then
				eos_ctr <= eos_ctr - x"1";
			else
				eos_ctr <= eos_ctr;
			end if;

		end if;
	end process;

	--TODO: all queue split conditions here 
	-- the queue size counter used only for closing current queue
	-- sums up all subevent sizes with their headers and stuff
	process(CLK_GBE)
	begin
		if rising_edge(CLK_GBE) then
			if (load_current_state = IDLE) then
				queue_size <= (others => '0');
			elsif (load_current_state = CLOSE_QUEUE_IMMEDIATELY) then
				queue_size <= (others => '0');
			elsif (load_current_state = WAIT_TWO) then
				queue_size <= queue_size + subevent_size + x"10" + x"8" + x"4";
			elsif (load_current_state = DECIDE) then
				if (queue_size > ("00" & MAX_QUEUE_SIZE_IN)) then
					queue_size <= subevent_size + x"10" + x"8" + x"4";
				elsif (MULT_EVT_ENABLE_IN = '1' and number_of_subs = MAX_SUBS_IN_QUEUE_IN) then
					queue_size <= subevent_size + x"10" + x"8" + x"4";
				elsif (MULT_EVT_ENABLE_IN = '0' and number_of_subs = 1) then
					queue_size <= subevent_size + x"10" + x"8" + x"4";
				elsif (trigger_type /= previous_ttype and number_of_subs /= x"0000") then
					queue_size <= subevent_size + x"10" + x"8" + x"4";
				elsif (bank_select /= previous_bank and number_of_subs /= x"0000") then
					queue_size <= subevent_size + x"10" + x"8" + x"4";
				else
					queue_size <= queue_size;
				end if;
			else
				queue_size <= queue_size;
			end if;
		end if;
	end process;

	process(CLK_GBE)
	begin
		if rising_edge(CLK_GBE) then
			if (load_current_state = IDLE or load_current_state = CLOSE_QUEUE or load_current_state = CLOSE_QUEUE_IMMEDIATELY) then
				number_of_subs <= (others => '0');
			elsif (load_current_state = PREPARE_TO_LOAD_SUB) then
				number_of_subs <= number_of_subs + x"1";
			else
				number_of_subs <= number_of_subs;
			end if;
		end if;
	end process;

	SF_RD_EN_PROC : process(CLK_GBE)
	begin
		if rising_edge(CLK_GBE) then
			if (load_current_state = REMOVE) then
				sf_rd_en <= '1';
			else
				if (PC_READY_IN = '1') then
					if (load_current_state = LOAD and sf_eos = '0') then
						sf_rd_en <= '1';
					elsif (load_current_state = FINISH_ONE or load_current_state = FINISH_TWO) then
						sf_rd_en <= '1';
					else
						sf_rd_en <= '0';
					end if;
				else
					sf_rd_en <= '0';
				end if;
			end if;

		end if;
	end process SF_RD_EN_PROC;

	--*****
	-- information extraction

	process(CLK_GBE)
	begin
		if rising_edge(CLK_GBE) then
			if (load_current_state = IDLE) then
				previous_bank  <= x"0";
				previous_ttype <= x"0";
			elsif (load_current_state = CLOSE_QUEUE or load_current_state = CLOSE_QUEUE_IMMEDIATELY or load_current_state = CLOSE_SUB) then
				previous_bank  <= bank_select;
				previous_ttype <= trigger_type;
			else
				previous_bank  <= previous_bank;
				previous_ttype <= previous_ttype;
			end if;
		end if;
	end process;

	TRIGGER_RANDOM_PROC : process(CLK_GBE)
	begin
		if rising_edge(CLK_GBE) then
			if (load_current_state = IDLE) then
				trigger_random <= (others => '0');
			elsif (load_current_state = REMOVE and sf_rd_en = '1' and loaded_bytes_ctr = x"0005") then
				trigger_random <= pc_data;
			else
				trigger_random <= trigger_random;
			end if;
		end if;
	end process TRIGGER_RANDOM_PROC;

	TRIGGER_NUMBER_PROC : process(CLK_GBE)
	begin
		if rising_edge(CLK_GBE) then
			if (load_current_state = IDLE) then
				trigger_number <= (others => '0');
			elsif (load_current_state = REMOVE and sf_rd_en = '1' and loaded_bytes_ctr = x"0007") then
				trigger_number(7 downto 0) <= pc_data;
			elsif (load_current_state = REMOVE and sf_rd_en = '1' and loaded_bytes_ctr = x"0006") then
				trigger_number(15 downto 8) <= pc_data;
			else
				trigger_number <= trigger_number;
			end if;
		end if;
	end process TRIGGER_NUMBER_PROC;

	SUBEVENT_SIZE_PROC : process(CLK_GBE)
	begin
		if rising_edge(CLK_GBE) then
			if (load_current_state = IDLE) then
				subevent_size <= (others => '0');
			elsif (load_current_state = WAIT_ONE and sf_rd_en = '1' and loaded_bytes_ctr = x"0009") then
				subevent_size(9 downto 2) <= pc_data;
			elsif (load_current_state = REMOVE and sf_rd_en = '1' and loaded_bytes_ctr = x"0008") then
				subevent_size(17 downto 10) <= pc_data;
			else
				subevent_size <= subevent_size;
			end if;
		end if;
	end process SUBEVENT_SIZE_PROC;

	TRIGGER_TYPE_PROC : process(CLK_GBE)
	begin
		if rising_edge(CLK_GBE) then
			if (load_current_state = IDLE) then
				trigger_type <= x"0";
			elsif (load_current_state = REMOVE and sf_rd_en = '1' and loaded_bytes_ctr = x"0003") then
				trigger_type <= pc_data(7 downto 4);
			else
				trigger_type <= trigger_type;
			end if;
		end if;
	end process TRIGGER_TYPE_PROC;

	-- end of extraction
	--*****

	--*****
	-- counters

	LOADED_EVENTS_CTR_PROC : process(RESET, CLK_GBE)
	begin
		if (RESET = '1') then
			loaded_events_ctr <= (others => '0');
		elsif rising_edge(CLK_GBE) then
			if (load_current_state = CLOSE_SUB) then
				loaded_events_ctr <= loaded_events_ctr + x"1";
			else
				loaded_events_ctr <= loaded_events_ctr;
			end if;
		end if;
	end process LOADED_EVENTS_CTR_PROC;

	LOADED_BYTES_CTR_PROC : process(CLK_GBE)
	begin
		if rising_edge(CLK_GBE) then
			if (load_current_state = WAIT_FOR_SUBS) then
				loaded_bytes_ctr <= (others => '0');
			elsif (sf_rd_en = '1') then
				if (load_current_state = REMOVE) then
					loaded_bytes_ctr <= loaded_bytes_ctr + x"1";
				else
					loaded_bytes_ctr <= loaded_bytes_ctr;
				end if;
			else
				loaded_bytes_ctr <= loaded_bytes_ctr;
			end if;
		end if;
	end process LOADED_BYTES_CTR_PROC;

	READOUT_CTR_PROC : process(CLK_GBE)
	begin
		if rising_edge(CLK_GBE) then
			if (READOUT_CTR_VALID_IN = '1') then
				readout_ctr <= READOUT_CTR_IN;
			elsif (load_current_state = DECIDE) then
				readout_ctr <= readout_ctr + x"1";
			else
				readout_ctr <= readout_ctr;
			end if;
		end if;
	end process READOUT_CTR_PROC;

	-- end of counters
	--*****

	--*****
	-- event builder selection


	BANK_SELECT_PROC : process(CLK_GBE)
	begin
		if rising_edge(CLK_GBE) then
			if (load_current_state = IDLE) then
				bank_select <= x"0";
			elsif (load_current_state = REMOVE and sf_rd_en = '1' and loaded_bytes_ctr = x"0003") then
				bank_select <= pc_data(3 downto 0);
			else
				bank_select <= bank_select;
			end if;
		end if;
	end process BANK_SELECT_PROC;

	BANK_SELECT_OUT <= bank_select;

	START_CONFIG_PROC : process(CLK_GBE)
	begin
		if rising_edge(CLK_GBE) then
			if (load_current_state = REMOVE and sf_rd_en = '1' and loaded_bytes_ctr = x"0003") then
				START_CONFIG_OUT <= '1';
			elsif (CONFIG_DONE_IN = '1') then
				START_CONFIG_OUT <= '0';
			else
				START_CONFIG_OUT <= '0';
			end if;
		end if;
	end process START_CONFIG_PROC;

	-- end of event builder selection
	--*****


	PC_WR_EN_PROC : process(CLK_GBE)
	begin
		if rising_edge(CLK_GBE) then
			if (PC_READY_IN = '1') then
				if ((load_current_state = LOAD and sf_eos = '0') or load_current_state = FINISH_ONE or load_current_state = FINISH_TWO) then
					PC_WR_EN_OUT <= '1';
				else
					PC_WR_EN_OUT <= '0';
				end if;
			else
				PC_WR_EN_OUT <= '0';
			end if;
		end if;
	end process PC_WR_EN_PROC;

	PC_SOS_PROC : process(CLK_GBE)
	begin
		if rising_edge(CLK_GBE) then
			if (load_current_state = PREPARE_TO_LOAD_SUB) then
				PC_SOS_OUT <= '1';
			else
				PC_SOS_OUT <= '0';
			end if;
		end if;
	end process PC_SOS_PROC;

	PC_EOD_PROC : process(CLK_GBE)
	begin
		if rising_edge(CLK_GBE) then
			PC_EOS_OUT <= sf_eos;
		end if;
	end process PC_EOD_PROC;

	PC_EOQ_PROC : process(CLK_GBE)
	begin
		if rising_edge(CLK_GBE) then
			if (load_current_state = CLOSE_QUEUE or load_current_state = CLOSE_QUEUE_IMMEDIATELY) then
				PC_EOQ_OUT <= '1';
			else
				PC_EOQ_OUT <= '0';
			end if;
		end if;
	end process PC_EOQ_PROC;

	--*******
	-- outputs

	PC_DATA_OUT <= pc_data;

	PC_SUB_SIZE_OUT <= b"0000_0000_0000_00" & subevent_size;

	PC_TRIG_NR_OUT <= readout_ctr(23 downto 16) & trigger_number & trigger_random;

	PC_TRIGGER_TYPE_OUT <= trigger_type;

	process(CLK_IPU)
	begin
		if rising_edge(CLK_IPU) then
			DEBUG_OUT(3 downto 0)   <= rec_state;
			DEBUG_OUT(7 downto 4)   <= load_state;
			DEBUG_OUT(8)            <= sf_empty;
			DEBUG_OUT(9)            <= sf_aempty;
			DEBUG_OUT(10)           <= sf_full;
			DEBUG_OUT(11)           <= sf_afull;
			DEBUG_OUT(27 downto 12) <= sf_cnt;
		end if;
	end process;

	DEBUG_OUT(383 downto 28)   <= (others => '0');
	MONITOR_OUT(31 downto 0)   <= too_large_dropped;
	MONITOR_OUT(223 downto 32) <= (others => '0');

end architecture RTL;

