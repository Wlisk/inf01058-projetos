library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity FSM_ELEVATOR is 
generic(
	FLOORS:		natural := 4;
	LN_FLOORS:	natural := 2
);
port(
	btn_floor: 		in bit_vector(LN_FLOORS downto 0);
	btn_elev: 		in bit_vector(LN_FLOORS-1 downto 0);
	clk: 				in std_logic;
	rst: 				in std_logic;
	out_floor: 		out bit_vector(LN_FLOORS-1 downto 0);
	out_state: 		out bit_vector(1 downto 0);
	setdoor: 		out bit
);
end FSM_ELEVATOR;

architecture FSM_HARDWARE of FSM_ELEVATOR is 
	type STATEType is (S_RESET, S_WAIT, S_UP, S_CLOSE, S_OPEN, S_DOWN);
	type FLOORType is array(0 to (FLOORS * 2)-1) of bit;
	type ELEVType is array(0 to FLOORS-1) of bit;
	subtype CSTATEType is bit_vector(1 downto 0);
	subtype NUMFLOORSType is natural range 0 to FLOORS-1;
	
	constant DCLOSE: 	bit := '0';
	constant DOPEN: 	bit := '1';
	constant CTRUE: 	bit := '1';
	constant CFALSE: 	bit := '0';
	constant RESET: 	std_logic := '0';
	constant BTN_PER_FLOOR: natural := 2;
	constant BTN_UP: natural := 0;
	constant BTN_DW: natural := 1;
	
	constant CS_UP: 		CSTATEType := "00";
	constant CS_DOWN: 	CSTATEType := "01";
	constant CS_OPEN: 	CSTATEType := "10";
	constant CS_CLOSE: 	CSTATEType := "11";
	
	constant MIN_FLOOR: natural := 0;
	constant MAX_FLOOR: natural := FLOORS-1;
	
	signal state, next_state: 	STATEType := S_RESET;
	signal btn_floor_status: 	FLOORType := (others => '0');
	signal btn_elev_status: 	ELEVType := (others => '0');
	signal reset_hold: 	bit  := CFALSE;
	signal curr_floor: 	NUMFLOORSType;
	signal going_up: 		bit := CFALSE;
	signal going_down: 	bit := CFALSE;
	
	------------------------------------------------------------------------------------
	-- fn to check if there is buttons above curr floor active
	function is_btn_up_active(cfloor: NUMFLOORSType; btnsf: FLOORType; btnse: ELEVType) 
	return boolean is
		variable i: natural := cfloor + 1;
		variable j: integer := i * 2;
		variable is_active: boolean := false;
	begin 
		while i < FLOORS loop
			if(btnse(i) = CTRUE) then is_active := true; 
			elsif(btnsf(j+BTN_UP) = CTRUE) then is_active := true;
			end if;
			
			j := j + BTN_PER_FLOOR;
			i := i + 1;
		end loop;
		return is_active;
	end function is_btn_up_active;
	
	------------------------------------------------------------------------------------
	-- fn to check if the is buttons bellow curr floor active
	function is_btn_down_active(cfloor: NUMFLOORSType; btnsf: FLOORType; btnse: ELEVType) 
	return boolean is
		variable i: integer := cfloor - 1;
		variable j: integer := i * 2;
		variable is_active: boolean := false;
	begin 
		while i > 0 loop
			if(btnse(i) = CTRUE) then is_active := true; 
			elsif(btnsf(j+BTN_DW) = CTRUE) then is_active := true;
			end if;
			
			j := j - BTN_PER_FLOOR;
			i := i - 1;
		end loop;
		return is_active;
	end function is_btn_down_active;
	
	------------------------------------------------------------------------------------
	-- fn to check if elevator is to open door
	function is_to_open(
		cfloor: NUMFLOORSType; 
		btnsf: FLOORType; 
		btnse: ELEVType; 
		gup: bit; gdown: bit
	) 
	return boolean is 
		variable set_open: boolean := false;
		constant btn_dw: natural := cfloor + BTN_DW;
		constant btn_up: natural := cfloor + BTN_UP;
	begin
		if(btnse(cfloor) = CTRUE) then set_open := true;
				
		elsif(gup = CFALSE AND gdown = CFALSE) then
			if(btnsf(btn_up) = CTRUE OR btnsf(btn_dw) = CTRUE) then 
				set_open := true;
			end if;
				
		elsif(gup = CTRUE) then 
			if(btnsf(btn_up) = CTRUE) then set_open := true; end if;
				
		elsif(gdown = CTRUE) then
			if(btnsf(btn_dw) = CTRUE) then set_open := true; end if;
				
		end if;
		return set_open;
	end function is_to_open;
	
begin
	------------------------------------------------------------------------------------
	-- CLOCK CONTROL 
	PROCESS_CLOCK: process(clk, rst)
	begin 
		if(rst = RESET) then 
			reset_hold <= CTRUE; 
			state <= S_RESET;
		elsif(rising_edge(clk)) then 
			state <= next_state;
		end if;
	end process PROCESS_CLOCK;
	
	------------------------------------------------------------------------------------
	-- STATES CONTROL 
	PROCESS_STATES: process(state, curr_floor, btn_floor_status, btn_elev_status)
		variable result_gup: boolean := false;
		variable result_gdw: boolean := false;
	begin 
		case state is
			-- RESETING STATE -------------------------------------------------
			-- resets control signals & if curr floor != MIN_FLOOR then goes down to base floor
			when S_RESET =>
				going_up <= CFALSE;
				going_down <= CFALSE;
				
				btn_floor_status <= (others => '0');
				btn_elev_status <= (others => '0');
				
				if(curr_floor= MIN_FLOOR) then 
					reset_hold <= CFALSE;
					next_state <= S_WAIT;
				else next_state <= S_DOWN; end if;

			-- WAITING STATE --------------------------------------------------
			-- waits when no btns active (not going up neither going down)
			-- goes open the door if elev in same floor of btn active
			-- goes move down if any button active bellow curr floor
			-- goes move up if any button active above curr floor
			-- goes move down or stay at MIN_FLOOR if reset set
			when S_WAIT => 
				going_up <= CFALSE;
				going_down <= CFALSE;
					
				result_gup := is_btn_up_active(curr_floor, btn_floor_status, btn_elev_status);
				result_gdw := is_btn_down_active(curr_floor, btn_floor_status, btn_elev_status);
					
				if(is_to_open(curr_floor, btn_floor_status, btn_elev_status, going_up, going_down) = true) then 
					next_state <= S_OPEN;
				elsif(result_gup = true) then next_state <= S_UP;
				elsif(result_gdw = true) then next_state <= S_DOWN;
				else next_state <= S_WAIT;
				end if;
				
			-- DOOR OPEN STATE ------------------------------------------------
			-- set btns for curr floor as visited (false) & go close the door
			when S_OPEN =>
				btn_floor_status(curr_floor) <= CFALSE;
				if(going_up = CTRUE) then btn_floor_status(curr_floor+BTN_UP) <= CFALSE;
				elsif(going_down = CTRUE) then btn_floor_status(curr_floor+BTN_DW) <= CFALSE;
				end if;
				next_state <= S_CLOSE;
				
			-- DOOR CLOSE STATE -----------------------------------------------
			-- goes open the door if button for curr floor active
			-- goes wait if not btns active anymore
			when S_CLOSE =>
				result_gup := is_btn_up_active(curr_floor, btn_floor_status, btn_elev_status);
				result_gdw := is_btn_down_active(curr_floor, btn_floor_status, btn_elev_status);
				
				if(going_up = CTRUE AND result_gup = false) then
					going_up <= CFALSE;
				elsif(going_down = CTRUE AND result_gdw = false) then
					going_down <= CFALSE;
				end if;
					
				if(going_up = CFALSE AND result_gdw = true) then
					going_down <= CTRUE;
				elsif(going_down = CFALSE AND result_gup = true) then
					going_up <= CTRUE;
				end if;
		
				if(is_to_open(curr_floor, btn_floor_status, btn_elev_status, going_up, going_down) = true) then 
					next_state <= S_OPEN;
				elsif(going_up = CTRUE) then next_state <= S_UP;
				elsif(going_down = CTRUE) then next_state <= S_DOWN;
				else next_state <= S_WAIT;
				end if;
					
			-- GOING UP STATE -------------------------------------------------
			-- continues to go down | go open the door if btn set or end of floors
			when S_UP => 
				going_up <= CTRUE;
				going_down <= CFALSE;
					
				if(curr_floor = MAX_FLOOR) then next_state <= S_OPEN;
				elsif(is_to_open(curr_floor, btn_floor_status, btn_elev_status, going_up, going_down) = true) then 
					next_state <= S_OPEN;
				else 
					next_state <= S_UP;
					if(curr_floor /= MIN_FLOOR) then curr_floor<= curr_floor+ 1; end if;
				end if;
				
			-- GOING DOWN STATE -----------------------------------------------
			-- continues to go up | go open the door if btn set or start of floors
			-- goes down if reset and not on MIN_FLOOR
			when S_DOWN => 
				going_down <= CTRUE;
				going_up <= CFALSE;
				
				if(reset_hold = CTRUE) then 	
					if(curr_floor = MIN_FLOOR) then next_state <= S_RESET;
					else 
						curr_floor<= curr_floor- 1;
						next_state <= S_DOWN;
					end if;
				elsif(curr_floor = MIN_FLOOR) then next_state <= S_OPEN;
				elsif(is_to_open(curr_floor, btn_floor_status, btn_elev_status, going_up, going_down) = true) then 
					next_state <= S_OPEN;
				else
					next_state <= S_DOWN;
					if(curr_floor /= MIN_FLOOR) then curr_floor<= curr_floor- 1; end if;
				end if;
					
			-- UNKNOWN STATE --------------------------------------------------
			when others => next_state <= S_WAIT;
		end case;
	end process PROCESS_STATES;
	
	------------------------------------------------------------------------------------
	-- OUTPUT CONTROLS
	PROCESS_OUTPUT: process(state, curr_floor)
	begin
		case state is
			-- GOING UP STATE -------------------------------------------------
			when S_UP => 
				out_floor <= to_bitvector(std_logic_vector(to_unsigned(curr_floor, out_floor'length)));
				out_state <= CS_UP;
			-- GOING DOWN STATE -----------------------------------------------
			when S_DOWN => 
				out_floor<= to_bitvector(std_logic_vector(to_unsigned(curr_floor, out_floor'length)));
				out_state <= CS_DOWN;
			-- DOOR OPEN STATE ------------------------------------------------
			when S_OPEN => 
				setdoor <= DOPEN;
				out_state <= CS_OPEN;
			-- OTHER STATES ---------------------------------------------------
			when others => 
				setdoor <= DCLOSE;
				out_state <= CS_CLOSE;
		end case;
	end process PROCESS_OUTPUT;
end FSM_HARDWARE;