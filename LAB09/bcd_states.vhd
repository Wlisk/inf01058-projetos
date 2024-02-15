library IEEE;
use IEEE.std_logic_1164.all;

entity bcd_states is 
generic(
	NSTATES: natural := 2
);
port(
	state: in std_logic_vector(NSTATES-1 downto 0);
	bcd_leds: out std_logic_vector(6 downto 0)
);
end bcd_states;

architecture BCDSTATE_HARDWARE of bcd_states is
begin
	with state select 
		bcd_leds <=
			"1011011" when "00",
			"0111101" when "01",
			"1110111" when "10", 
			"1000111" when "11";
end BCDSTATE_HARDWARE;