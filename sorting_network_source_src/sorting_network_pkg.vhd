library ieee;
use ieee.std_logic_1164.all;


package sorting_network_pkg is
	type word_array_t is array(natural range <>) of std_ulogic_vector(31 downto 0);
	component sorting_network is
		port (
			clk   : in std_logic;
			res_n : in std_logic;

			unsorted_ready : out std_ulogic;
			unsorted_data  : in  word_array_t(0 to 9);
			unsorted_valid : in  std_ulogic;

			sorted_ready   : in  std_ulogic;
			sorted_data    : out word_array_t(0 to 9);
			sorted_valid   : out std_ulogic
		);
	end component;
end package;

