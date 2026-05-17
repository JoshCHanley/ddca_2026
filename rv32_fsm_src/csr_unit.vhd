library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.rv32_isa_pkg.all;
use work.rv32_mem_pkg.all;
use work.rv32_fsm_types_pkg.all;

entity rv32_fsm_csr_unit is
	port (
		clk   : in std_ulogic;
		res_n : in std_ulogic;

		csr_addr   : in csr_t;
		csr_rd_op  : in csr_rd_op_t;
		csr_wr_op  : in csr_wr_op_t;
		csr_wrdata : in std_ulogic_vector(XLEN-1 downto 0);
		csr_rddata : out std_ulogic_vector(XLEN-1 downto 0);

		mcause : out std_ulogic_vector(XLEN-1 downto 0);
		mtvec  : inout std_ulogic_vector(XLEN-1 downto 0);

		trap_op : in trap_op_t;

		pc : in std_ulogic_vector(XLEN-1 downto 0);
		inc_instret : in std_ulogic
	);
end entity;


architecture arch of rv32_fsm_csr_unit is

	constant USER_CSR_ADDRESS : csr_t := x"7C0"; -- address of a custom CSR for testing purposes
begin
end architecture;
