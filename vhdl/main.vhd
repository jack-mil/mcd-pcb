----------------------------------------------------------------------------------
-- jackmil
--
-- Create Date:		20:58:30 03/02/2022
-- Design Name: 	Single Board Computer Control Logic
-- Module Name:		main - Behavioral
-- Target Devices: XC9572
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.ALL;

entity main is
	Port (
		DUART_INT   : in    STD_LOGIC; -- DUART Interrupt Request
		DUART_IACK  : out   STD_LOGIC; -- DUART Interrupt Acknowledge

		CLK_IN      : in    STD_LOGIC; -- 8MHz input clock
		CPU_CLK     : out   STD_LOGIC; -- CPU clock pin

		SUP_RESET   : in    STD_LOGIC;
		CPU_HALT    : inout STD_LOGIC; -- CPUs reset control lines can be driven
		CPU_RESET   : inout STD_LOGIC; -- or asserted as output
		DUART_RESET : out   STD_LOGIC;

		-- Device CS (Active low)
		DUART_CS    : out   STD_LOGIC;
		RAML_CS     : out   STD_LOGIC;
		RAMH_CS     : out   STD_LOGIC;
		ROML_CS     : out   STD_LOGIC;
		ROMH_CS     : out   STD_LOGIC;

		MEM_OE      : out   STD_LOGIC; -- All memory chips output enable

		CPU_RW      : in    STD_LOGIC; -- CPU read/write* indicator

		CPU_AS      : in    STD_LOGIC; -- Address strobe low when address bus valid
		CPU_UDS     : in    STD_LOGIC; -- Low when upper data D8-D15 valid
		CPU_LDS     : in    STD_LOGIC; -- Low when lower data D0-D7 valid

		DUART_DTACK : in    STD_LOGIC; -- Asserted low by DUART when data bus valid
		CPU_DTACK   : out   STD_LOGIC; -- Low indicates to CPU that databus is valid

		CPU_BERR    : out   STD_LOGIC;	-- Assert low to indicate a bus error

		CPU_BR      : out   STD_LOGIC; -- Active low, unused bus arbitration inputs
		CPU_BGACK   : out   STD_LOGIC; --
		CPU_VPA     : out   STD_LOGIC; -- Unused peripheral input

		ADDR        : in    STD_LOGIC_VECTOR(3 DOWNTO 0); -- Decodable address lines A16-A19

		CPU_FC      : in    STD_LOGIC_VECTOR(2 DOWNTO 0); -- Function Code outputs
		CPU_IPL     : out   STD_LOGIC_VECTOR(2 DOWNTO 0); -- Interupt request line

		LED_G       : out   STD_LOGIC_VECTOR(3 DOWNTO 0); -- Diagnostic LEDs, Green. Active low
		LED_B       : out   STD_LOGIC_VECTOR(3 DOWNTO 0); -- Diagnostic LEDs, Blue. Active low
		FC_LED      : out   STD_LOGIC_VECTOR(2 DOWNTO 0); -- Function code LEDs. Active high.

		DIP_SW      : in 	  STD_LOGIC_VECTOR(3 DOWNTO 0); -- 4 dip switches, active hight
		SW_RESET    : in 	  STD_LOGIC;  -- Reset button, active low
		SW_UTIL     : in 	  STD_LOGIC); -- Unused utility switch, active low

end main;

architecture Behavioral of main is

signal tick 		: STD_LOGIC;
signal clkCounter 	: unsigned(23 downto 0) := (others => '0');

signal l1 : STD_LOGIC;
signal l2 : STD_LOGIC;
signal l3 : STD_LOGIC;
signal reset_clean : STD_LOGIC;

signal green_led : STD_LOGIC_VECTOR(3 DOWNTO 0) := "1010";
signal blue_led : STD_LOGIC_VECTOR(3 DOWNTO 0) := "0101";
begin -- Begin Architecture

	-- CPU clock tied directly to 8MHz input clock
	CPU_CLK <= CLK_IN;

	-- Pullup interrupt acknowledge if unused
	DUART_IACK <= '1';

	-- No bus error possible
	CPU_BERR <= '1';

	-- Pullup unused peripheral pins
	CPU_BR <= '1';
	CPU_BGACK <= '1';
	CPU_VPA <= '1';

	-- No interupts are used
	CPU_IPL <= "111";

	-- -- Tie function control outputs to LEDs
	FC_LED <= CPU_FC;

	-- -- Memory output-enable control inverse of cpu R/W*
	MEM_OE <= not CPU_RW;

	-- Make reset and halt low when supervisor is low or button pressed
	-- Also reset the DUART when cpu is reset
	-- CPU lines have hardware pullup resistors, so set to high imedance
	-- Potential future use of Halt assertion as CPU output (or step cycles)
	CPU_RESET <= '0' when (SUP_RESET='0' or reset_clean='0') else 'Z';
	CPU_HALT <= '0' when (SUP_RESET='0' or reset_clean='0') else 'Z';
	DUART_RESET <= '0' when (SUP_RESET='0' or reset_clean='0') else '1';

	-- -- Select DUART device
	DUART_CS <= CPU_LDS when (ADDR="0010" and CPU_AS='0') else '1';

	-- -- Select RAM devices
	RAML_CS <= CPU_LDS when (ADDR="0001" and CPU_AS='0') else '1';
	RAMH_CS <= CPU_UDS when (ADDR="0001" and CPU_AS='0') else '1';

	-- -- Select ROM devices (Read only)
	ROML_CS <= CPU_LDS when (ADDR="0000" and CPU_AS='0' and CPU_RW='1') else '1';
	ROMH_CS <= CPU_UDS when (ADDR="0000" and CPU_AS='0' and CPU_RW='1') else '1';

	-- -- No delay on RAM/ROM DTACK signal. Hopefully everything is fast enough?
	-- -- Duart supplies reliable DTACK
	CPU_DTACK <= DUART_DTACK when (ADDR="0010") else CPU_AS;


	-- Diagnostic active low LEDs --
--LED_G(0) <= CPU_AS when (DIP_SW(0) = '1') else green_led(0);
	--LED_G(1) <= CPU_RW when (DIP_SW(0) = '1') else green_led(1);
	--LED_G(2) <= DUART_CS when (DIP_SW(0) = '1') else green_led(2);
	--LED_G(3) <= RAML_CS when (DIP_SW(0) = '1') else green_led(3);

	LED_B(0) <= CPU_HALT when (DIP_SW(0) = '1') else blue_led(0);
	LED_B(1) <= CPU_RESET when (DIP_SW(0) = '1') else blue_led(1);
	--LED_B(2) <= CPU_BERR when (DIP_SW(0) = '1') else blue_led(2);
	--LED_B(3) <= CPU_DTACK when (DIP_SW(0) = '1') else blue_led(3);



	-- Optional interrupt functionality --
	--------------------------------------
	-- Set interrupt priority of '4' (active low) when DUART requests interrupts,
	-- and until interrupt acknowledged
	-- CPU_IPL <= "011" when DUART_INT = '0' else "000";

	-- Notify DUART of interrupt acknowledge. Function code will be '111'
	-- Should technically decode A1, A2, and A3 as well (not wired)
	-- DUART_IACK <= '0' when (CPU_FC="111" and CPU_AS='0') else '1';

	-- Input clock at 8Mhz, gives tick a frequency of 3.81Hz, 262 ms period
	tick <= clkCounter(21);

	-- Simple method for clock division
	ClockDivider : process ( CLK_IN )
	begin
		if rising_edge(CLK_IN) then
			clkCounter <= clkCounter + 1;
		end if;
	end process ; -- ClockDivider

	-- Take button input and debounce signal in reset_clean
	Debouncer : process( clkCounter(14) ) -- 1ms polling rate
	-- Should be a 3ms debounce time? Does order matter here?
	begin
		if (rising_edge(clkCounter(14))) then
			l3 <= l2;
			l2 <= l1;
			l1 <= SW_RESET;
		end if;
	end process ; -- Debouncer

	reset_clean <= l1 and l2 and l3;

	-- Diagnostic blink process
	BlinkLEDs : process ( tick )
	 begin
		if (DIP_SW(1) = '1') then
			if (tick='0') then
				green_led <= "0101";
				blue_led <= "1010";
			else
				green_led <= "1010";
				blue_led <= "0101";
			end if;
		else
			green_led <= "1111";
			blue_led <= "1111";
		end if;
	end process; -- BlinkLEDs

	-- end process; -- AddressDecode
end Behavioral;

