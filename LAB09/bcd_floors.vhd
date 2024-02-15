library IEEE;
use IEEE.std_logic_1164.all;

entity bcd_floors is 
generic(
	LN_FLOORS: natural := 2
);
port(
	floor: in std_logic_vector(LN_FLOORS-1 downto 0);
	bcd_leds: out std_logic_vector(6 downto 0)
);
end bcd_floors;

architecture BCDFLOOR_HARDWARE of bcd_floors is
begin
	with floor select 
		bcd_leds <=
			"0110000" when "00",
			"1101101" when "01",
			"1111001" when "10", 
			"0110011" when "11";
end BCDFLOOR_HARDWARE;