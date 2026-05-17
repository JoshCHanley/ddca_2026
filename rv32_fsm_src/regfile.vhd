library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity rv32_fsm_regfile is
	generic (
		ADDR_WIDTH : natural := 8;
		DATA_WIDTH : natural := 32
	);
	port (
		clk     : in std_ulogic;
		
		rd_addr : in std_ulogic_vector(ADDR_WIDTH-1 downto 0);
		rd_data : out std_ulogic_vector(DATA_WIDTH-1 downto 0) := (others => '0');
		rd      : in std_ulogic;

		wr_addr : in std_ulogic_vector(ADDR_WIDTH-1 downto 0);
		wr_data : in std_ulogic_vector(DATA_WIDTH-1 downto 0);
		wr      : in std_ulogic
	);
end entity;

architecture arch of rv32_fsm_regfile is
	type mem_t is array(0 to 2**ADDR_WIDTH-1) of std_ulogic_vector(DATA_WIDTH-1 downto 0);
	signal mem : mem_t := (others => (others => '0'));
begin

	ram: process(clk)
	begin
		if(rising_edge(clk)) then
			if(wr = '1') then
				mem(to_integer(unsigned(wr_addr))) <= wr_data;
			end if;

			if rd = '1' then
				rd_data <= mem(to_integer(unsigned(rd_addr)));

				if unsigned(rd_addr) = 0 then
					rd_data <= (others => '0');
				end if;
			end if;
		end if;
	end process;
end architecture;
