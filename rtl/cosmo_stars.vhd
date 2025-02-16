library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

-- Star background for Cosmo

-- V 1.0 - MacroFPGA - 12/02/2025

entity cosmostars is
port (
	clk			: in  std_logic; -- 4 x dot clock, should be 20Mhz 

	timer_v 		: in  std_logic_vector(8 downto 0); -- Vertical
	timer_h  	: in  std_logic_vector(8 downto 0); -- Horizontal

	I_starreg   : in  std_logic_vector(3 downto 0);
	
	O_RNG         : out std_logic_vector(5 downto 0);
	O_Starfield   : out std_logic_vector(5 downto 0)  
);
end entity;

architecture RTL of cosmostars is

signal RNG     		: std_logic_vector(16 downto 0) := (others => '0');
signal SkippedClocks : std_logic_vector(2 downto 0) := (others => '0');
signal Bright        : std_logic := '0';

begin

	stars : process(clk,timer_h,timer_v)
	
	begin
		if rising_edge(clk) then
			
				-- RNG for CPU to read
				O_RNG <= not RNG(7 downto 2);
						
				-- every screen needs to clock RNG 1024 times per horizontal line for 256 vertical lines
				-- if I_starreg(3) = 0 then it does 4 more non visible ones

				-- V counter goes 32-255,474-511
				
				if (timer_h(8) = '0') and ((I_starreg(3)='0' and timer_v < 506) or (I_starreg(3)='1' and timer_v < 510)) then
					
					-- needs to skip I_starreg(2 downto 0) enabled clocks at start of screen
					
					if SkippedClocks < I_starreg(2 downto 0) then
					
						SkippedClocks <= SkippedClocks + 1;
					
					else
												
						-- Do we display a star
						
						if (RNG(15 downto 8) = "1111111") and (timer_v(8)='0') then
						
							if (Bright = '1') then
							
								O_Starfield <= RNG(7 downto 2);
								
							else
							
								O_Starfield <= "00" & RNG(5 downto 2);
							
							end if;
						
						else
						
							O_Starfield <= "000000";
						
							-- Toggle Brightness
							
							if timer_h(3) = timer_v(0) then
						
								Bright <= '0';
							
							else

								Bright <= not Bright;
								
							end if;
						
						end if;
						
						-- Next RNG
						RNG <= (RNG(12) xor (not RNG(0))) & RNG(16 downto 1);	
						
					end if;
					
				else
				
					O_Starfield <= "000000";
				
					if (timer_h = 500) and (timer_v = 511) then
					
						-- Start of new screen
						SkippedClocks <= (others => '0');
																		
					end if;
					
				end if;

		end if;
	end process;

end architecture;

