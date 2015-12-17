library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_ARITH.all;
use IEEE.std_logic_UNSIGNED.all;

library work;
use work.trb_net_std.all;
use work.trb_net_components.all;

use work.trb_net_gbe_components.all;
use work.trb_net_gbe_protocols.all;

entity gbe_ipu_multiplexer is
	generic(
		DO_SIMULATION       : integer range 0 to 1         := 0;
		INCLUDE_DEBUG       : integer range 0 to 1         := 0;

		LINK_HAS_READOUT    : std_logic_vector(3 downto 0) := "1111";
		NUMBER_OF_GBE_LINKS : integer range 0 to 4         := 0
	);
	port(
		CLK_SYS_IN                  : in  std_logic;
		RESET                       : in  std_logic;

		-- CTS interface
		CTS_NUMBER_IN               : in  std_logic_vector(15 downto 0);
		CTS_CODE_IN                 : in  std_logic_vector(7 downto 0);
		CTS_INFORMATION_IN          : in  std_logic_vector(7 downto 0);
		CTS_READOUT_TYPE_IN         : in  std_logic_vector(3 downto 0);
		CTS_START_READOUT_IN        : in  std_logic;
		CTS_DATA_OUT                : out std_logic_vector(31 downto 0);
		CTS_DATAREADY_OUT           : out std_logic;
		CTS_READOUT_FINISHED_OUT    : out std_logic;
		CTS_READ_IN                 : in  std_logic;
		CTS_LENGTH_OUT              : out std_logic_vector(15 downto 0);
		CTS_ERROR_PATTERN_OUT       : out std_logic_vector(31 downto 0);
		-- Data payload interface
		FEE_DATA_IN                 : in  std_logic_vector(15 downto 0);
		FEE_DATAREADY_IN            : in  std_logic;
		FEE_READ_OUT                : out std_logic;
		FEE_STATUS_BITS_IN          : in  std_logic_vector(31 downto 0);
		FEE_BUSY_IN                 : in  std_logic;

		-- CTS interface
		MLT_CTS_NUMBER_OUT          : out std_logic_vector(16 * NUMBER_OF_GBE_LINKS - 1 downto 0);
		MLT_CTS_CODE_OUT            : out std_logic_vector(8 * NUMBER_OF_GBE_LINKS - 1 downto 0);
		MLT_CTS_INFORMATION_OUT     : out std_logic_vector(8 * NUMBER_OF_GBE_LINKS - 1 downto 0);
		MLT_CTS_READOUT_TYPE_OUT    : out std_logic_vector(4 * NUMBER_OF_GBE_LINKS - 1 downto 0);
		MLT_CTS_START_READOUT_OUT   : out std_logic_vector(NUMBER_OF_GBE_LINKS - 1 downto 0);
		MLT_CTS_DATA_IN             : in  std_logic_vector(32 * NUMBER_OF_GBE_LINKS - 1 downto 0);
		MLT_CTS_DATAREADY_IN        : in  std_logic_vector(NUMBER_OF_GBE_LINKS - 1 downto 0);
		MLT_CTS_READOUT_FINISHED_IN : in  std_logic_vector(NUMBER_OF_GBE_LINKS - 1 downto 0);
		MLT_CTS_READ_OUT            : out std_logic_vector(NUMBER_OF_GBE_LINKS - 1 downto 0);
		MLT_CTS_LENGTH_IN           : in  std_logic_vector(16 * NUMBER_OF_GBE_LINKS - 1 downto 0);
		MLT_CTS_ERROR_PATTERN_IN    : in  std_logic_vector(32 * NUMBER_OF_GBE_LINKS - 1 downto 0);
		-- Data payload interface
		MLT_FEE_DATA_OUT            : out std_logic_vector(16 * NUMBER_OF_GBE_LINKS - 1 downto 0);
		MLT_FEE_DATAREADY_OUT       : out std_logic_vector(NUMBER_OF_GBE_LINKS - 1 downto 0);
		MLT_FEE_READ_IN             : in  std_logic_vector(NUMBER_OF_GBE_LINKS - 1 downto 0);
		MLT_FEE_STATUS_BITS_OUT     : out std_logic_vector(32 * NUMBER_OF_GBE_LINKS - 1 downto 0);
		MLT_FEE_BUSY_OUT            : out std_logic_vector(NUMBER_OF_GBE_LINKS - 1 downto 0);

		DEBUG_OUT                   : out std_logic_vector(127 downto 0)
	);
end entity gbe_ipu_multiplexer;

architecture RTL of gbe_ipu_multiplexer is
	signal client_ptr                                              : integer range 0 to NUMBER_OF_GBE_LINKS - 1 := 0;
	signal cts_readout, cts_readout_q                              : std_logic;
	signal switch_ptr, switch_ptr_q, switch_ptr_qq, switch_ptr_qqq : std_logic_vector(1 downto 0)               := "00";

begin
	process(CLK_SYS_IN)
	begin
		if rising_edge(CLK_SYS_IN) then
			if (RESET = '1') then
				if (LINK_HAS_READOUT(0) = '1') then
					client_ptr <= 0;
				elsif (LINK_HAS_READOUT(1) = '1') then
					client_ptr <= 1;
				elsif (LINK_HAS_READOUT(2) = '1') then
					client_ptr <= 2;
				else
					client_ptr <= 3;
				end if;

				switch_ptr <= "00";
			else
				cts_readout   <= MLT_CTS_READOUT_FINISHED_IN(client_ptr); --CTS_START_READOUT_IN;
				cts_readout_q <= cts_readout;
--				if (switch_ptr = "11") then
--					switch_ptr <= "00";
--				else
--					if (cts_readout = '0' and cts_readout_q = '1') then
--						switch_ptr(0) <= '1';
--					else
--						switch_ptr(0) <= switch_ptr(0);
--					end if;
--
--					switch_ptr(1) <= MLT_CTS_READOUT_FINISHED_IN(client_ptr);
--				end if;
--				switch_ptr_q   <= switch_ptr;
--				switch_ptr_qq  <= switch_ptr_q;
--				switch_ptr_qqq <= switch_ptr_qq;

				if (cts_readout = '0' and cts_readout_q = '1') then
				--if (switch_ptr_qqq = "11") then
					client_ptr <= client_ptr;
					case client_ptr is
						when 0 =>
							if (LINK_HAS_READOUT(1) = '1') then
								client_ptr <= 1;
							elsif (LINK_HAS_READOUT(2) = '1') then
								client_ptr <= 2;
							elsif (LINK_HAS_READOUT(3) = '1') then
								client_ptr <= 3;
							else
								client_ptr <= 0;
							end if;

						when 1 =>
							if (LINK_HAS_READOUT(2) = '1') then
								client_ptr <= 2;
							elsif (LINK_HAS_READOUT(3) = '1') then
								client_ptr <= 3;
							elsif (LINK_HAS_READOUT(0) = '1') then
								client_ptr <= 0;
							else
								client_ptr <= 1;
							end if;

						when 2 =>
							if (LINK_HAS_READOUT(3) = '1') then
								client_ptr <= 3;
							elsif (LINK_HAS_READOUT(0) = '1') then
								client_ptr <= 0;
							elsif (LINK_HAS_READOUT(1) = '1') then
								client_ptr <= 1;
							else
								client_ptr <= 2;
							end if;

						when 3 =>
							if (LINK_HAS_READOUT(0) = '1') then
								client_ptr <= 0;
							elsif (LINK_HAS_READOUT(1) = '1') then
								client_ptr <= 1;
							elsif (LINK_HAS_READOUT(2) = '1') then
								client_ptr <= 2;
							else
								client_ptr <= 3;
							end if;
						when others => client_ptr <= client_ptr;
					end case;
				else
					client_ptr <= client_ptr;
				end if;
			end if;
		end if;
	end process;

	process(CLK_SYS_IN)
	begin
		if rising_edge(CLK_SYS_IN) then
			if (RESET = '1') then
				MLT_CTS_NUMBER_OUT(16 * (client_ptr + 1) - 1 downto 16 * client_ptr)     <= (others => '0');
				MLT_CTS_CODE_OUT(8 * (client_ptr + 1) - 1 downto 8 * client_ptr)         <= (others => '0');
				MLT_CTS_INFORMATION_OUT(8 * (client_ptr + 1) - 1 downto 8 * client_ptr)  <= (others => '0');
				MLT_CTS_READOUT_TYPE_OUT(4 * (client_ptr + 1) - 1 downto 4 * client_ptr) <= (others => '0');
				MLT_CTS_START_READOUT_OUT(client_ptr)                                    <= '0';
				CTS_DATA_OUT                                                             <= (others => '0');
				CTS_DATAREADY_OUT                                                        <= '0';
				CTS_READOUT_FINISHED_OUT                                                 <= '0';
				MLT_CTS_READ_OUT(client_ptr)                                             <= '0';
				CTS_LENGTH_OUT                                                           <= (others => '0');
				CTS_ERROR_PATTERN_OUT                                                    <= (others => '0');

				MLT_FEE_DATA_OUT(16 * (client_ptr + 1) - 1 downto 16 * client_ptr)        <= (others => '0');
				MLT_FEE_DATAREADY_OUT(client_ptr)                                         <= '0';
				FEE_READ_OUT                                                              <= '0';
				MLT_FEE_STATUS_BITS_OUT(32 * (client_ptr + 1) - 1 downto 32 * client_ptr) <= (others => '0');
				MLT_FEE_BUSY_OUT(client_ptr)                                              <= '0';
			else
				MLT_CTS_NUMBER_OUT        <= (others => '0');
				MLT_CTS_CODE_OUT          <= (others => '0');
				MLT_CTS_INFORMATION_OUT   <= (others => '0');
				MLT_CTS_READOUT_TYPE_OUT  <= (others => '0');
				MLT_CTS_START_READOUT_OUT <= (others => '0');
				MLT_CTS_READ_OUT          <= (others => '0');
				MLT_FEE_DATA_OUT          <= (others => '0');
				MLT_FEE_DATAREADY_OUT     <= (others => '0');
				MLT_FEE_STATUS_BITS_OUT   <= (others => '0');
				MLT_FEE_BUSY_OUT          <= (others => '0');

				MLT_CTS_NUMBER_OUT(16 * (client_ptr + 1) - 1 downto 16 * client_ptr)     <= CTS_NUMBER_IN;
				MLT_CTS_CODE_OUT(8 * (client_ptr + 1) - 1 downto 8 * client_ptr)         <= CTS_CODE_IN;
				MLT_CTS_INFORMATION_OUT(8 * (client_ptr + 1) - 1 downto 8 * client_ptr)  <= CTS_INFORMATION_IN;
				MLT_CTS_READOUT_TYPE_OUT(4 * (client_ptr + 1) - 1 downto 4 * client_ptr) <= CTS_READOUT_TYPE_IN;
				MLT_CTS_START_READOUT_OUT(client_ptr)                                    <= CTS_START_READOUT_IN;
				CTS_DATA_OUT                                                             <= MLT_CTS_DATA_IN(32 * (client_ptr + 1) - 1 downto 32 * client_ptr);
				CTS_DATAREADY_OUT                                                        <= MLT_CTS_DATAREADY_IN(client_ptr);
				CTS_READOUT_FINISHED_OUT                                                 <= MLT_CTS_READOUT_FINISHED_IN(client_ptr);
				MLT_CTS_READ_OUT(client_ptr)                                             <= CTS_READ_IN;
				CTS_LENGTH_OUT                                                           <= MLT_CTS_LENGTH_IN(16 * (client_ptr + 1) - 1 downto 16 * client_ptr);
				CTS_ERROR_PATTERN_OUT                                                    <= MLT_CTS_ERROR_PATTERN_IN(32 * (client_ptr + 1) - 1 downto 32 * client_ptr);

				MLT_FEE_DATA_OUT(16 * (client_ptr + 1) - 1 downto 16 * client_ptr)        <= FEE_DATA_IN;
				MLT_FEE_DATAREADY_OUT(client_ptr)                                         <= FEE_DATAREADY_IN;
				FEE_READ_OUT                                                              <= MLT_FEE_READ_IN(client_ptr);
				MLT_FEE_STATUS_BITS_OUT(32 * (client_ptr + 1) - 1 downto 32 * client_ptr) <= FEE_STATUS_BITS_IN;
				MLT_FEE_BUSY_OUT(client_ptr)                                              <= FEE_BUSY_IN;
			end if;
		end if;
	end process;

end architecture RTL;			