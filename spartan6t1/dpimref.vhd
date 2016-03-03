----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    13:00:07 02/28/2016 
-- Design Name: 
-- Module Name:    dpimref - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity dpimref is
    Port ( mclk : in  STD_LOGIC; -- 50 MHz clock
           pdb : inout  STD_LOGIC_VECTOR (7 downto 0); -- port data bus bidi
           astb : in  STD_LOGIC; -- address strobe
           dstb : in  STD_LOGIC; -- data strobe
           pwr : in  STD_LOGIC; -- data direction
           pwait : out  STD_LOGIC; --transfer synch
           rgLed : out  STD_LOGIC_VECTOR (7 downto 0); -- led output to the DIO4
           rgSwt : in  STD_LOGIC_VECTOR (7 downto 0);  -- switches inputs from DIO4
           rgBtn : in  STD_LOGIC_VECTOR (4 downto 0); -- buttons inputs
           btn : in  STD_LOGIC; -- button on system board
           ldg : out  STD_LOGIC; 
           led : out  STD_LOGIC); -- led on the system board
end dpimref;

architecture Behavioral of dpimref is

constant stEppReady : std_logic_vector(7 downto 0) := "0000" & "0000";
constant stEppAwrA: std_logic_vector(7 downto 0) := "0001" & "0100";
constant stEppAwrB: std_logic_vector(7 downto 0) := "0010" & "0001";
constant stEppArdA: std_logic_vector(7 downto 0) := "0011" & "0010";
constant stEppArdB: std_logic_vector(7 downto 0) := "0100" & "0011";
constant stEppDwrA: std_logic_vector(7 downto 0) := "0101" & "1000";
constant stEppDwrB: std_logic_vector(7 downto 0) := "0110" & "0001";
constant stEppDrdA: std_logic_vector(7 downto 0) := "0111" & "0010";
constant stEppDrdB: std_logic_vector(7 downto 0) := "1000" & "0011";

------------------------------------------------------------------------
-- Signal Declarations
------------------------------------------------------------------------
-- State machine current state register
signal stEppCur: std_logic_vector(7 downto 0) := stEppReady;
signal stEppNext : std_logic_vector(7 downto 0);
signal clkMain: std_logic;

-- Internal control signales
signal ctlEppWait : std_logic;
signal ctlEppAstb : std_logic;
signal ctlEppDstb : std_logic;
signal ctlEppDir : std_logic;
signal ctlEppWr : std_logic;
signal ctlEppAwr : std_logic;
signal ctlEppDwr : std_logic;

signal busEppOut: std_logic_vector(7 downto 0);
signal busEppIn: std_logic_vector(7 downto 0);
signal busEppData: std_logic_vector(7 downto 0);

-- registers
signal regEppAdr : std_logic_vector(3 downto 0);
signal regData0 : std_logic_vector(7 downto 0);
signal regData1 : std_logic_vector(7 downto 0);
signal regData2 : std_logic_vector(7 downto 0);
signal regData3 : std_logic_vector(7 downto 0);
signal regData4 : std_logic_vector(7 downto 0);
signal regData5 : std_logic_vector(7 downto 0);
signal regData6 : std_logic_vector(7 downto 0);
signal regData7 : std_logic_vector(7 downto 0);

signal regLed : std_logic_vector(7 downto 0);

signal cntr : std_logic_vector(23 downto 0);

begin

-- map basic status and control signals

clkMain <= mclk;

ctlEppAstb <= astb;
ctlEppDstb <= dstb;
ctlEppWr <= pwr;
pwait <= ctlEppWait; -- drive wait from state machine output

-- Data bus direction control. The internal input data bus always
-- gets the port data bus. The port data bus drives the internal
-- output data bus onto the pins when the interface says we are doing
-- a read cycle and we are in one of the read cycles states in the
-- state machine.

busEppIn <= pdb;
pdb <= busEppOut when ctlEppWr = '1' and ctlEppDir = '1' else "ZZZZZZZZ";

-- select either address or data onto the internal output data bus
busEppOut <= "0000" & regEppAdr when ctlEppAstb = '0' else busEppData;

rgLed <= regLed;
ldg <= '1';

--decode the address register and select the appropriate data register
busEppData <= regData0 when regEppAdr = "0000" else
				  regData1 when regEppAdr = "0001" else
              regData2 when regEppAdr = "0010" else
				  regData3 when regEppAdr = "0011" else
				  regData4 when regEppAdr = "0100" else
				  regData5 when regEppAdr = "0101" else
              regData6 when regEppAdr = "0110" else
				  regData7 when regEppAdr = "0111" else
				  rgSwt when regEppAdr = "1000"    else
				  "000" & rgBtn when regEppAdr = "1001" else
				  "00000000";

-- epp interface control state machine

ctlEppWait <= stEppCur(0);
ctlEppDir <= stEppCur(1);
ctlEppAwr <= stEppCur(2);
ctlEppDwr <= stEppCur(3);

-- this process moves the state machine to the next state
-- on each clock cycle

process (clkMain)
	begin
	if clkMain = '1' and clkMain'Event then
		stEppCur <= stEppNext;
	end if;
end process;

-- this process determines the next state machine state based 
-- on the current state and the state machine inputs.

process (stEppCur, stEppNext, ctlEppAstb, ctlEppDstb, ctlEppWr)
begin
	case stEppCur is 
		-- idle state waiting for the beginning of an EPP cycle
		when stEppReady =>
		
			if ctlEppAstb = '0' then
				-- address read or write cycle
				if ctlEppWr = '0' then
					stEppNext <= stEppAwra;
				else
					stEppNext <= stEppArdA;
				end if; -- ctlEppWr
			
			elsif ctlEppDstb = '0' then
				-- data read or write cycle
				if ctlEppWr = '0' then
					stEppNext <= stEppDwrA;
				else
					stEppNext <= stEppDrdA;
				end if;
			else
				--remain in ready state 
				stEppNext <= stEppReady;
			end if; -- astb
			
		-- write address register
		when stEppAwrA =>
			stEppNext <= stEppAwrB;
		
		when stEppAwrB => 
			if ctlEppAstb = '0' then
				stEppNext <= stEppAwrB;
			else
				stEppNext <= stEppReady;
			end if;
		
		--read address register
		when stEppArdA =>
			stEppNext <= stEppArdB;
		
		when stEppArdB =>
			if ctlEppAstb = '0' then
				stEppNext <= stEppArdB;
			else
				stEppNext <= stEppReady;
			end if;
		
		--write data register
		when stEppDwrA =>
			stEppNext <= stEppDwrB;
		
	   when stEppDwrB =>
			if ctlEppDstb = '0' then
				stEppNext <= stEppDwrB;
			else
				stEppNext <= stEppReady;
			end if;
		
		--read data register
		when stEppDrdA =>
			stEppNext <= stEppDrdB;
		
		when stEppDrdB =>
			if ctlEppDstb ='0' then
				stEppNext <= stEppDrdB;
			else
				stEppNext <= stEppReady;
			end if;
		
		-- some unknown state
		when others =>
			stEppNext <= stEppReady;
			
	end case;
end process;

-- epp address register
process(clkMain, ctlEppAwr)
begin
	if clkMain ='1' and ClkMain'Event then
		if ctlEppAwr ='1' then
			regEppAdr <= busEppIn(3 downto 0);
		end if;
	end if;
end process;


-- epp data registers
process (clkMain, regEppAdr, ctlEppDwr, busEppIn)
begin
	if clkMain ='1' and clkMain'Event then
		if ctlEppDwr ='1' and regEppAdr = "0000" then
			regData0 <= busEppIn;
		end if;
	end if;
end process;

process (clkMain, regEppAdr, ctlEppDwr, busEppIn)
begin
	if clkMain ='1' and clkMain'Event then
		if ctlEppDwr ='1' and regEppAdr = "0001" then
			regData1 <= busEppIn;
		end if;
	end if;
end process;

process (clkMain, regEppAdr, ctlEppDwr, busEppIn)
begin
	if clkMain ='1' and clkMain'Event then
		if ctlEppDwr ='1' and regEppAdr = "0010" then
			regData2 <= busEppIn;
		end if;
	end if;
end process;

process (clkMain, regEppAdr, ctlEppDwr, busEppIn)
begin
	if clkMain ='1' and clkMain'Event then
		if ctlEppDwr ='1' and regEppAdr = "0011" then
			regData3 <= busEppIn;
		end if;
	end if;
end process;

process (clkMain, regEppAdr, ctlEppDwr, busEppIn)
begin
	if clkMain ='1' and clkMain'Event then
		if ctlEppDwr ='1' and regEppAdr = "0100" then
			regData4 <= busEppIn;
		end if;
	end if;
end process;

process (clkMain, regEppAdr, ctlEppDwr, busEppIn)
begin
	if clkMain ='1' and clkMain'Event then
		if ctlEppDwr ='1' and regEppAdr = "0101" then
			regData5 <= busEppIn;
		end if;
	end if;
end process;

process (clkMain, regEppAdr, ctlEppDwr, busEppIn)
begin
	if clkMain ='1' and clkMain'Event then
		if ctlEppDwr ='1' and regEppAdr = "0110" then
			regData6 <= busEppIn;
		end if;
	end if;
end process;

process (clkMain, regEppAdr, ctlEppDwr, busEppIn)
begin
	if clkMain ='1' and clkMain'Event then
		if ctlEppDwr ='1' and regEppAdr = "0111" then
			regData7 <= busEppIn;
		end if;
	end if;
end process;

process (clkMain, regEppAdr, ctlEppDwr, busEppIn)
begin
	if clkMain ='1' and clkMain'Event then
		if ctlEppDwr ='1' and regEppAdr = "1010" then
			regLed <= busEppIn;
		end if;
	end if;
end process;

led <= btn or cntr(23);

process(clkMain)
begin
	if clkMain = '1' and clkMain'Event then
		cntr <= cntr +1;
	end if;
end process;


end Behavioral;

