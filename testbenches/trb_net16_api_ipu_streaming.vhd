
LIBRARY ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.trb_net_std.all;
use work.trb_net_components.all;

entity trb_net16_api_ipu_streaming is
  port(
    CLK    : in std_logic;
    RESET  : in std_logic;
    CLK_EN : in std_logic;

    -- Internal direction port

    FEE_INIT_DATA_OUT         : out std_logic_vector (c_DATA_WIDTH-1 downto 0);
    FEE_INIT_DATAREADY_OUT    : out std_logic;
    FEE_INIT_PACKET_NUM_OUT   : out std_logic_vector (c_NUM_WIDTH-1  downto 0);
    FEE_INIT_READ_IN          : in  std_logic;

    FEE_REPLY_DATA_IN         : in  std_logic_vector (c_DATA_WIDTH-1 downto 0);
    FEE_REPLY_DATAREADY_IN    : in  std_logic;
    FEE_REPLY_PACKET_NUM_IN   : in  std_logic_vector (c_NUM_WIDTH-1 downto 0);
    FEE_REPLY_READ_OUT        : out std_logic;

    CTS_INIT_DATA_IN          : in  std_logic_vector (c_DATA_WIDTH-1 downto 0);
    CTS_INIT_DATAREADY_IN     : in  std_logic;
    CTS_INIT_PACKET_NUM_IN    : in  std_logic_vector (c_NUM_WIDTH-1  downto 0);
    CTS_INIT_READ_OUT         : out std_logic;

    CTS_REPLY_DATA_OUT        : out std_logic_vector (c_DATA_WIDTH-1 downto 0);
    CTS_REPLY_DATAREADY_OUT   : out std_logic;
    CTS_REPLY_PACKET_NUM_OUT  : out std_logic_vector (c_NUM_WIDTH-1  downto 0);
    CTS_REPLY_READ_IN         : in  std_logic;

    --Event information coming from CTS
    CTS_NUMBER_OUT            : out std_logic_vector (15 downto 0); --valid while start_readout is high
    CTS_CODE_OUT              : out std_logic_vector (7  downto 0); --valid while start_readout is high
    CTS_INFORMATION_OUT       : out std_logic_vector (7  downto 0); --valid while start_readout is high
    CTS_READOUT_TYPE_OUT      : out std_logic_vector (3  downto 0); --valid while start_readout is high
    CTS_START_READOUT_OUT     : out std_logic;  --goes high after request is transported through hub, goes low
                                                --after user send information to cts.

    --Information sent to CTS
    --status data, equipped with DHDR
    CTS_DATA_IN             : in  std_logic_vector (31 downto 0);
    CTS_DATAREADY_IN        : in  std_logic;
    CTS_READOUT_FINISHED_IN : in  std_logic;      --no more data, end transfer, send TRM, should be high 1 CLK cycle
    CTS_READ_OUT            : out std_logic;
    CTS_LENGTH_IN           : in  std_logic_vector (15 downto 0); --valid when raising dataready for first time
    CTS_STATUS_BITS_IN      : in  std_logic_vector (31 downto 0); --valid when readout_finished is high

    -- Data from Frontends
    FEE_DATA_OUT           : out std_logic_vector (15 downto 0);  --data from FEE
    FEE_DATAREADY_OUT      : out std_logic;  --data on data_out is valid
    FEE_READ_IN            : in  std_logic;  --must be high always unless connected entity can not read data, otherwise you will never get a dataready
    FEE_STATUS_BITS_OUT    : out std_logic_vector (31 downto 0); --valid after busy is low again
    FEE_BUSY_OUT           : out std_logic;  --goes high shortly after start_readout; goes low when last dataword from FEE
                                             --has been read.

    MY_ADDRESS_IN         : in  std_logic_vector (15 downto 0);
    CTRL_SEQNR_RESET      : in std_logic

    );
end entity;

architecture trb_net16_api_ipu_streaming_arch of trb_net16_api_ipu_streaming is

  attribute syn_hier : string;
  attribute syn_hier of trb_net16_api_ipu_streaming_arch : architecture is "hard, firm";

  signal APL_CTS_TARGET_ADDRESS : std_logic_vector(15 downto 0) := x"FFFF";
  signal APL_CTS_DATA_OUT       : std_logic_vector(15 downto 0);
  signal APL_CTS_PACKET_NUM_OUT : std_logic_vector(2 downto 0);
  signal APL_CTS_DATAREADY_OUT  : std_logic;
  signal APL_CTS_READ_IN        : std_logic;
  signal APL_CTS_SEQNR_OUT      : std_logic_vector(7 downto 0);
  signal APL_CTS_ERROR_PATTERN_IN : std_logic_vector(31 downto 0);

  signal APL_FEE_DTYPE_IN         : std_logic_vector(3 downto 0);
  signal APL_FEE_ERROR_PATTERN_IN : std_logic_vector(31 downto 0);
  signal APL_FEE_SEND_IN          : std_logic;
  signal APL_FEE_DATA_OUT         : std_logic_vector(15 downto 0);
  signal APL_FEE_PACKET_NUM_OUT   : std_logic_vector(2 downto 0);
  signal APL_FEE_DATAREADY_OUT    : std_logic;
  signal APL_FEE_READ_IN          : std_logic;
  signal APL_FEE_TYP_OUT          : std_logic_vector(2 downto 0);
  signal APL_FEE_RUN_OUT          : std_logic;
  signal APL_FEE_SEQNR_OUT        : std_logic_vector(7 downto 0);
  signal APL_FEE_LENGTH_IN        : std_logic_vector(15 downto 0);

  signal APL_CTS_TYP_OUT          : std_logic_vector(2 downto 0);


  signal APL_CTS_DATA_IN        : std_logic_vector(15 downto 0);
  signal APL_CTS_PACKET_NUM_IN  : std_logic_vector(2 downto 0);
  signal APL_CTS_DATAREADY_IN   : std_logic;
  signal APL_CTS_READ_OUT       : std_logic;
  signal APL_CTS_SHORT_TRANSFER_IN : std_logic;
  signal APL_CTS_DTYPE_IN       : std_logic_vector(3 downto 0);
  signal APL_CTS_SEND_IN        : std_logic;
  signal APL_CTS_RUN_OUT        : std_logic;
  signal APL_CTS_LENGTH_IN      : std_logic_vector(15 downto 0);

  signal buf_CTS_CODE_OUT               : std_logic_vector(7 downto 0);
  signal buf_CTS_INFORMATION_OUT        : std_logic_vector(7 downto 0);
  signal buf_CTS_READOUT_TYPE_OUT       : std_logic_vector(3 downto 0);
  signal buf_CTS_NUMBER_OUT             : std_logic_vector(15 downto 0);
  signal buf_CTS_START_READOUT_OUT      : std_logic;
  signal last_buf_CTS_START_READOUT_OUT : std_logic;
  signal cts_start_readout_rising       : std_logic;

  signal end_of_data_reached            : std_logic;
  signal data_counter                   : signed(17 downto 0);
  signal data_length                    : signed(17 downto 0);
  signal buf_FEE_DATAREADY_OUT          : std_logic;
  
  
  signal CTS_DATAREADY_IN_a : std_logic;

begin

APL_CTS_TARGET_ADDRESS <= x"FFFF";
APL_FEE_LENGTH_IN <= x"0000";

-------------------------------------------------------------------------------
--Application Interface, receiving request from CTS
-------------------------------------------------------------------------------
  THE_CTS_API: trb_net16_api_base
    generic map (
      API_TYPE          => c_API_PASSIVE,
      FIFO_TO_INT_DEPTH => c_FIFO_BRAM,
      FIFO_TO_APL_DEPTH => c_FIFO_BRAM,
      FORCE_REPLY       => cfg_FORCE_REPLY(1),
      USE_VENDOR_CORES   => c_YES,
      SECURE_MODE_TO_APL => c_YES,
      SECURE_MODE_TO_INT => c_YES,
      APL_WRITE_ALL_WORDS=> c_YES,
      BROADCAST_BITMASK  => x"FF"
      )
    port map (
      --  Misc
      CLK    => CLK,
      RESET  => RESET,
      CLK_EN => CLK_EN,
      -- APL Transmitter port
      APL_DATA_IN           => APL_CTS_DATA_IN,
      APL_PACKET_NUM_IN     => APL_CTS_PACKET_NUM_IN,
      APL_DATAREADY_IN      => APL_CTS_DATAREADY_IN,
      APL_READ_OUT          => open, --APL_CTS_READ_OUT,
      APL_SHORT_TRANSFER_IN => APL_CTS_SHORT_TRANSFER_IN,
      APL_DTYPE_IN          => APL_CTS_DTYPE_IN,
      APL_ERROR_PATTERN_IN  => APL_CTS_ERROR_PATTERN_IN,
      APL_SEND_IN           => APL_CTS_SEND_IN,
      APL_TARGET_ADDRESS_IN => APL_CTS_TARGET_ADDRESS,
      -- Receiver port
      APL_DATA_OUT      => APL_CTS_DATA_OUT,
      APL_PACKET_NUM_OUT=> open,
      APL_TYP_OUT       => open,
      APL_DATAREADY_OUT => open, --APL_CTS_DATAREADY_OUT,
      APL_READ_IN       => APL_CTS_READ_IN,
      -- APL Control port
      APL_RUN_OUT       => APL_CTS_RUN_OUT,
      APL_MY_ADDRESS_IN => MY_ADDRESS_IN,
      APL_SEQNR_OUT     => APL_CTS_SEQNR_OUT,
      APL_LENGTH_IN     => APL_CTS_LENGTH_IN,
      -- Internal direction port
      INT_MASTER_DATAREADY_OUT => CTS_REPLY_DATAREADY_OUT,
      INT_MASTER_DATA_OUT      => CTS_REPLY_DATA_OUT,
      INT_MASTER_PACKET_NUM_OUT=> CTS_REPLY_PACKET_NUM_OUT,
      INT_MASTER_READ_IN       => CTS_REPLY_READ_IN,
      INT_MASTER_DATAREADY_IN  => '0',
      INT_MASTER_DATA_IN       => (others => '0'),
      INT_MASTER_PACKET_NUM_IN => (others => '0'),
      INT_MASTER_READ_OUT      => open,
      INT_SLAVE_DATAREADY_OUT  => open,
      INT_SLAVE_DATA_OUT       => open,
      INT_SLAVE_PACKET_NUM_OUT => open,
      INT_SLAVE_READ_IN        => '0',
      INT_SLAVE_DATAREADY_IN => CTS_INIT_DATAREADY_IN,
      INT_SLAVE_DATA_IN      => CTS_INIT_DATA_IN,
      INT_SLAVE_PACKET_NUM_IN=> CTS_INIT_PACKET_NUM_IN,
      INT_SLAVE_READ_OUT     => CTS_INIT_READ_OUT,
      -- Status and control port
      CTRL_SEQNR_RESET => CTRL_SEQNR_RESET,
      STAT_FIFO_TO_INT => open,
      STAT_FIFO_TO_APL => open
      );

process
begin
	APL_CTS_TYP_OUT <= "000";
	APL_CTS_DATAREADY_OUT <= '0';
	APL_CTS_PACKET_NUM_OUT <= "000";
	
	APL_CTS_READ_OUT <= '1';
	
	CTS_DATAREADY_IN_a <= '0';
	
	APL_FEE_DATAREADY_OUT <= '0';
	APL_FEE_TYP_OUT <= TYPE_DAT;
	
	wait for 9 us;
	wait until rising_edge(CLK);
	APL_CTS_TYP_OUT <= "011";
	APL_CTS_DATAREADY_OUT <= '1';
	APL_CTS_PACKET_NUM_OUT <= "011";
	wait until rising_edge(CLK);
	APL_CTS_TYP_OUT <= "000";
	APL_CTS_DATAREADY_OUT <= '0';
	APL_CTS_PACKET_NUM_OUT <= "000";
	
	wait for 100 ns;
	CTS_DATAREADY_IN_a <= '1';
	wait for 1000 ns;
	CTS_DATAREADY_IN_a <= '0';
	
	
	wait for 10 ns;
	
	APL_FEE_DATAREADY_OUT <= '1';
	
	wait for 100 ns;
	APL_FEE_DATAREADY_OUT <= '0';
	
	
	wait;
end process;

-------------------------------------------------------------------------------
--Application Interface, sending request to FEE
-------------------------------------------------------------------------------

  THE_FEE_API: trb_net16_api_base
    generic map (
      API_TYPE          => c_API_ACTIVE,
      FIFO_TO_INT_DEPTH => c_FIFO_BRAM,
      FIFO_TO_APL_DEPTH => c_FIFO_BRAM,
      FORCE_REPLY       => cfg_FORCE_REPLY(1),
      USE_VENDOR_CORES   => c_YES,
      SECURE_MODE_TO_APL => c_YES,
      SECURE_MODE_TO_INT => c_YES,
      APL_WRITE_ALL_WORDS=> c_NO,
      BROADCAST_BITMASK  => x"FF"
      )
    port map (
      --  Misc
      CLK    => CLK,
      RESET  => RESET,
      CLK_EN => CLK_EN,
      -- APL Transmitter port
      APL_DATA_IN           => (others => '0'),
      APL_PACKET_NUM_IN     => (others => '0'),
      APL_DATAREADY_IN      => '0',
      APL_READ_OUT          => open,
      APL_SHORT_TRANSFER_IN => '1',
      APL_DTYPE_IN          => APL_FEE_DTYPE_IN,
      APL_ERROR_PATTERN_IN  => APL_FEE_ERROR_PATTERN_IN,
      APL_SEND_IN           => APL_FEE_SEND_IN,
      APL_TARGET_ADDRESS_IN => (others => '1'),
      -- Receiver port
      APL_DATA_OUT      => APL_FEE_DATA_OUT,
      APL_PACKET_NUM_OUT=> APL_FEE_PACKET_NUM_OUT,
      APL_TYP_OUT       => open, --APL_FEE_TYP_OUT,
      APL_DATAREADY_OUT => open, -- APL_FEE_DATAREADY_OUT,
      APL_READ_IN       => APL_FEE_READ_IN,
      -- APL Control port
      APL_RUN_OUT       => APL_FEE_RUN_OUT,
      APL_MY_ADDRESS_IN => MY_ADDRESS_IN,
      APL_SEQNR_OUT     => APL_FEE_SEQNR_OUT,
      APL_LENGTH_IN     => APL_FEE_LENGTH_IN,
      -- Internal direction port
      INT_MASTER_DATAREADY_OUT => FEE_INIT_DATAREADY_OUT,
      INT_MASTER_DATA_OUT      => FEE_INIT_DATA_OUT,
      INT_MASTER_PACKET_NUM_OUT=> FEE_INIT_PACKET_NUM_OUT,
      INT_MASTER_READ_IN       => FEE_INIT_READ_IN,
      INT_MASTER_DATAREADY_IN  => '0',
      INT_MASTER_DATA_IN       => (others => '0'),
      INT_MASTER_PACKET_NUM_IN => (others => '0'),
      INT_MASTER_READ_OUT      => open,
      INT_SLAVE_DATAREADY_OUT  => open,
      INT_SLAVE_DATA_OUT       => open,
      INT_SLAVE_PACKET_NUM_OUT => open,
      INT_SLAVE_READ_IN        => '0',
      INT_SLAVE_DATAREADY_IN => FEE_REPLY_DATAREADY_IN,
      INT_SLAVE_DATA_IN      => FEE_REPLY_DATA_IN,
      INT_SLAVE_PACKET_NUM_IN=> FEE_REPLY_PACKET_NUM_IN,
      INT_SLAVE_READ_OUT     => FEE_REPLY_READ_OUT,
      -- Status and control port
      CTRL_SEQNR_RESET => CTRL_SEQNR_RESET,
      STAT_FIFO_TO_INT => open,
      STAT_FIFO_TO_APL => open
      );

-------------------------------------------------------------------------------
--Reading CTS data, forwarding to FEE
-------------------------------------------------------------------------------

  THE_IPUDATA : trb_net16_ipudata
    generic map(
      DO_CHECKS => c_NO
      )
    port map(
    --  Misc
      CLK    => CLK,
      RESET  => RESET,
      CLK_EN => '1',
    -- Port to API
      API_DATA_OUT           => APL_CTS_DATA_IN,
      API_PACKET_NUM_OUT     => APL_CTS_PACKET_NUM_IN,
      API_DATAREADY_OUT      => APL_CTS_DATAREADY_IN,
      API_READ_IN            => APL_CTS_READ_OUT,
      API_SHORT_TRANSFER_OUT => APL_CTS_SHORT_TRANSFER_IN,
      API_DTYPE_OUT          => APL_CTS_DTYPE_IN,
      API_ERROR_PATTERN_OUT  => APL_CTS_ERROR_PATTERN_IN,
      API_SEND_OUT           => APL_CTS_SEND_IN,
      -- Receiver port
      API_DATA_IN            => APL_CTS_DATA_OUT,
      API_PACKET_NUM_IN      => APL_CTS_PACKET_NUM_OUT,
      API_TYP_IN             => APL_CTS_TYP_OUT,
      API_DATAREADY_IN       => APL_CTS_DATAREADY_OUT,
      API_READ_OUT           => APL_CTS_READ_IN,
      -- APL Control port
      API_RUN_IN             => APL_CTS_RUN_OUT,
      API_SEQNR_IN           => APL_CTS_SEQNR_OUT,
      API_LENGTH_OUT         => APL_CTS_LENGTH_IN,
      MY_ADDRESS_IN          => MY_ADDRESS_IN,

      --Information received with request
      IPU_NUMBER_OUT         => buf_CTS_NUMBER_OUT,
      IPU_INFORMATION_OUT    => buf_CTS_INFORMATION_OUT,
      IPU_READOUT_TYPE_OUT   => buf_CTS_READOUT_TYPE_OUT,
      IPU_CODE_OUT           => buf_CTS_CODE_OUT,
      --start strobe
      IPU_START_READOUT_OUT  => buf_CTS_START_READOUT_OUT,
      --detector data, equipped with DHDR
      IPU_DATA_IN            => CTS_DATA_IN,
      IPU_DATAREADY_IN       => CTS_DATAREADY_IN_a,
      --no more data, end transfer, send TRM
      IPU_READOUT_FINISHED_IN => CTS_READOUT_FINISHED_IN,
      --will be low every second cycle due to 32bit -> 16bit conversion
      IPU_READ_OUT           => CTS_READ_OUT,
      IPU_LENGTH_IN          => CTS_LENGTH_IN,
      IPU_ERROR_PATTERN_IN   => CTS_STATUS_BITS_IN,

      STAT_DEBUG             => open
      );

---------------------------------------------------------------------
--Forward CTS request to FEE & Put Information to Output
---------------------------------------------------------------------


  PROC_START_READOUT_RISING : process(CLK)
    begin
      if rising_edge(CLK) then
        last_buf_CTS_START_READOUT_OUT <= buf_CTS_START_READOUT_OUT;
        cts_start_readout_rising <= buf_CTS_START_READOUT_OUT and not last_buf_CTS_START_READOUT_OUT;
      end if;
    end process;
  APL_FEE_SEND_IN                <= cts_start_readout_rising;

  APL_FEE_READ_IN                <= '1' when FEE_READ_IN = '1' or (APL_FEE_TYP_OUT /= TYPE_DAT) or end_of_data_reached = '1' else '0';
  buf_FEE_DATAREADY_OUT          <= APL_FEE_DATAREADY_OUT when APL_FEE_TYP_OUT = TYPE_DAT and end_of_data_reached = '0' else '0';
  FEE_DATA_OUT                   <= APL_FEE_DATA_OUT;
  FEE_BUSY_OUT                   <= APL_FEE_RUN_OUT;

  APL_FEE_ERROR_PATTERN_IN(15 downto 0)  <= buf_CTS_NUMBER_OUT;
  APL_FEE_ERROR_PATTERN_IN(23 downto 16) <= buf_CTS_CODE_OUT;
  APL_FEE_ERROR_PATTERN_IN(31 downto 24) <= buf_CTS_INFORMATION_OUT(7 downto 0);
  APL_FEE_DTYPE_IN                       <= buf_CTS_READOUT_TYPE_OUT;
  FEE_DATAREADY_OUT                      <= buf_FEE_DATAREADY_OUT;

  CTS_NUMBER_OUT                 <= buf_CTS_NUMBER_OUT;
  CTS_INFORMATION_OUT            <= buf_CTS_INFORMATION_OUT;
  CTS_READOUT_TYPE_OUT           <= buf_CTS_READOUT_TYPE_OUT;
  CTS_CODE_OUT                   <= buf_CTS_CODE_OUT;
  CTS_START_READOUT_OUT          <= buf_CTS_START_READOUT_OUT;

---------------------------------------------------------------------
-- Find end of data
---------------------------------------------------------------------
  PROC_COUNT_DATA : process(CLK)
    begin
      if rising_edge(CLK) then
        if RESET = '1' or APL_FEE_RUN_OUT = '0' then
          data_counter        <= to_signed(-3,18);
          end_of_data_reached <= '0';
        elsif APL_FEE_READ_IN = '1' and buf_FEE_DATAREADY_OUT = '1' then
          data_counter        <= data_counter + 1;
          if data_counter = data_length then
            end_of_data_reached <= '1';
          end if;
        end if;
      end if;
    end process;

  PROC_EOD : process(CLK)
    begin
      if rising_edge(CLK) then
         if RESET = '1' or APL_FEE_RUN_OUT = '0' then
          data_length <= to_signed(0,18);
        elsif buf_FEE_DATAREADY_OUT = '1' and data_counter = to_signed(-1,18) then
          data_length <= signed('0' & APL_FEE_DATA_OUT & '0');
        end if;
      end if;
    end process;

---------------------------------------------------------------------
-- Handle incoming data from FEE
---------------------------------------------------------------------

  PROC_IPU_STATUS_BITS : process(CLK)
    begin
      if rising_edge(CLK) then
        if    APL_FEE_PACKET_NUM_OUT = c_F1 and APL_FEE_TYP_OUT = TYPE_TRM then
          FEE_STATUS_BITS_OUT(31 downto 16) <= APL_FEE_DATA_OUT;
        elsif APL_FEE_PACKET_NUM_OUT = c_F2 and APL_FEE_TYP_OUT = TYPE_TRM then
          FEE_STATUS_BITS_OUT(15 downto 0) <= APL_FEE_DATA_OUT;
        end if;
      end if;
    end process;

--   PROC_IPU_DATA : process(CLK)
--     begin
--       if rising_edge(CLK) then
--         if FEE_READ_IN = '1' then
--           FEE_DATAREADY_OUT <= '0';
--         end if;
--         if APL_FEE_READ_IN = '1' and APL_FEE_DATAREADY_OUT = '1' and APL_FEE_TYP_OUT = TYPE_DAT then
--           if APL_FEE_PACKET_NUM_OUT = c_F0 or APL_FEE_PACKET_NUM_OUT = c_F2 then
--             FEE_DATA_OUT(31 downto 16) <= APL_FEE_DATA_OUT;
--           elsif APL_FEE_PACKET_NUM_OUT = c_F1 or APL_FEE_PACKET_NUM_OUT = c_F3 then
--             FEE_DATA_OUT(15 downto  0) <= APL_FEE_DATA_OUT;
--             FEE_DATAREADY_OUT <= '1';
--           end if;
--         end if;
--       end if;
--     end process;



end architecture;