-- VHDL testbench template generated by SCUBA Diamond_1.3_Production (92)
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;

entity tb is
end entity tb;


architecture test of tb is 

    component fifo_32kx16x8_mb2
        port (Data : in std_logic_vector(17 downto 0); 
        WrClock: in std_logic; RdClock: in std_logic; WrEn: in std_logic; 
        RdEn: in std_logic; Reset: in std_logic; RPReset: in std_logic; 
        AmEmptyThresh : in std_logic_vector(15 downto 0); 
        AmFullThresh : in std_logic_vector(14 downto 0); 
        Q : out std_logic_vector(8 downto 0); 
        WCNT : out std_logic_vector(15 downto 0); 
        RCNT : out std_logic_vector(16 downto 0); Empty: out std_logic; 
        Full: out std_logic; AlmostEmpty: out std_logic; 
        AlmostFull: out std_logic
    );
    end component;

    signal Data : std_logic_vector(17 downto 0) := (others => '0');
    signal WrClock: std_logic := '0';
    signal RdClock: std_logic := '0';
    signal WrEn: std_logic := '0';
    signal RdEn: std_logic := '0';
    signal Reset: std_logic := '0';
    signal RPReset: std_logic := '0';
    signal AmEmptyThresh : std_logic_vector(15 downto 0) := (others => '0');
    signal AmFullThresh : std_logic_vector(14 downto 0) := (others => '0');
    signal Q : std_logic_vector(8 downto 0);
    signal WCNT : std_logic_vector(15 downto 0);
    signal RCNT : std_logic_vector(16 downto 0);
    signal Empty: std_logic;
    signal Full: std_logic;
    signal AlmostEmpty: std_logic;
    signal AlmostFull: std_logic;
begin
    u1 : fifo_32kx16x8_mb2
        port map (Data => Data, WrClock => WrClock, RdClock => RdClock, 
            WrEn => WrEn, RdEn => RdEn, Reset => Reset, RPReset => RPReset, 
            AmEmptyThresh => AmEmptyThresh, AmFullThresh => AmFullThresh, 
            Q => Q, WCNT => WCNT, RCNT => RCNT, Empty => Empty, Full => Full, 
            AlmostEmpty => AlmostEmpty, AlmostFull => AlmostFull
        );

    process

    begin
      Data <= (others => '0') ;
      wait for 100 ns;
      wait until Reset = '0';
      for i in 0 to 32771 loop
        wait until WrClock'event and WrClock = '1';
        Data <= Data + '1' after 1 ns;
      end loop;
      wait;
    end process;

    WrClock <= not WrClock after 5.00 ns;

    RdClock <= not RdClock after 5.00 ns;

    process

    begin
      WrEn <= '0' ;
      wait for 100 ns;
      wait until Reset = '0';
      for i in 0 to 32771 loop
        wait until WrClock'event and WrClock = '1';
        WrEn <= '1' after 1 ns;
      end loop;
      WrEn <= '0' ;
      wait;
    end process;

    process

    begin
      RdEn <= '0' ;
      wait until Reset = '0';
      wait until WrEn = '1';
      wait until WrEn = '0';
      for i in 0 to 32771 loop
        wait until RdClock'event and RdClock = '1';
        RdEn <= '1' after 1 ns;
      end loop;
      RdEn <= '0' ;
      wait;
    end process;

    process

    begin
      Reset <= '1' ;
      wait for 100 ns;
      Reset <= '0' ;
      wait;
    end process;

    process

    begin
      RPReset <= '1' ;
      wait for 100 ns;
      RPReset <= '0' ;
      wait;
    end process;

end architecture test;
