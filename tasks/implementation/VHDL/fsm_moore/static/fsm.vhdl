library IEEE;
use IEEE.std_logic_1164.all;
use work.fsm_pkg.all;

entity fsm is
	port(
		CLK     : in   std_logic;
		RST     : in   std_logic;
		INPUT   : in   std_logic_vector(2-1 downto 0);
		OUTPUT  : out  std_logic_vector(2-1 downto 0);
		STATE   : out  fsm_state
	);
end fsm;
