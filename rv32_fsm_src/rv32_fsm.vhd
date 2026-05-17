library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.rv32_mem_pkg.all;
use work.rv32_isa_pkg.all;
use work.rv32_alu_pkg.all;
use work.rv32_fsm_types_pkg.all;
use work.rv32_ext_m_pkg.all;

entity rv32_fsm is
	generic (
		CLK_FREQ : integer := 50_000_000
	);
	port (
		clk     : in  std_logic;
		res_n   : in  std_logic;

		imem_out : out mem_out_t;
		imem_in  : in  mem_in_t;

		dmem_out : out mem_out_t;
		dmem_in  : in  mem_in_t
	);
end entity;


architecture arch of rv32_fsm is
	subtype data_t is std_ulogic_vector(31 downto 0);

	-- program counter
	signal pc : data_t;

	-- internal registers
	signal ir : data_t; -- instruction register
	signal wb : data_t; -- ALU output buffer, stores mem addr or data that has to written back to the regfile
	signal nx : data_t; -- ALU output buffer, stores next pc (except for taken branches)
	signal rs : data_t; -- last output of the register file
	signal rf : data_t; -- output of the register file

	-- register write signals
	signal wr_wb, wr_nx, wr_pc, wr_ir : std_ulogic;

	signal imm10 : std_ulogic;

	-- muxes
	signal ma : ma_ctrl_t;
	signal mb : mb_ctrl_t;
	signal mpc : mpc_ctrl_t;
	signal mrs : mrs_ctrl_t;
	signal mwb : mwb_ctrl_t;
	signal cvs : cvs_ctrl_t;


	-- ALU signals
	signal alu_op : rv32_alu_op_t;
	signal alu_z : std_ulogic;

	-- memory signals
	signal rd_imem : std_ulogic;
	signal memu_op : memu_op_t;

	--regfile signals
	signal wr_rf : std_ulogic;
	signal rd_rf : std_ulogic;

	-- these signals are only relevant for the rv_ext_m task, you can ignore them for now
	signal ext_m_start, ext_m_busy : std_ulogic;
	signal ext_m_op : ext_m_op_t;

	signal inc_instret : std_ulogic := '0';
	signal csr_wr_op : csr_wr_op_t := NOP;
	signal csr_rd_op : csr_rd_op_t := NOP;
	signal csr_wrdata, csr_rddata : std_ulogic_vector(31 downto 0);
	signal trap_op : trap_op_t := NOP;
	signal mcause, mtvec : std_ulogic_vector(31 downto 0) := (others => '0');

	signal alu_op_a, alu_op_b : data_t;
    signal alu_res            : data_t;
    signal pc_next            : data_t;
    signal imm                : data_t;
    signal rf_rd_addr         : std_ulogic_vector(4 downto 0);
    signal rf_wr_data         : data_t;
    signal memu_rddata        : data_t;

begin

	-- instruction memory interface
	imem_out.address <= pc(imem_out.address'length+1 downto 2);
	imem_out.rd <= rd_imem;
	imem_out.wr <= '0';
	imem_out.byteena <= (others => '1');
	imem_out.wrdata <= (others => '0');


	ctrl_fsm_inst : entity work.rv32_fsm_ctrl_unit
	port map(
		clk => clk,
		res_n => res_n,
		opcode => get_opcode(ir),
		funct3 => get_funct3(ir),
		funct7 => get_funct7(ir),
		funct12 => get_funct12(ir),
		imm10 => imm10,
		rs1 => get_rs1(ir),
		rs2 => get_rs2(ir),
		alu_z => alu_z,
		dmem_busy => dmem_in.busy,
		imem_busy => imem_in.busy,
		ext_m_busy => '0',
		inc_instret => inc_instret,
		ma => ma,
		mb => mb,
		mpc => mpc,
		mrs => mrs,
		mwb => mwb,
		wr_pc => wr_pc,
		wr_ir => wr_ir,
		wr_wb => wr_wb,
		wr_nx => wr_nx,
		rd_rf => rd_rf,
		wr_rf => wr_rf,
		rd_imem => rd_imem,
		alu_op => alu_op,
		memu_op => memu_op,
		ext_m_op => ext_m_op,
		ext_m_start => ext_m_start,
		cvs => cvs,
		csr_wr_op => csr_wr_op,
		csr_rd_op => csr_rd_op,
		trap_op => trap_op
	);

	csr_unit_inst : entity work.rv32_fsm_csr_unit
	port map (
		clk   => clk,
		res_n => res_n,
		csr_addr => get_csr(ir),
		csr_rd_op => csr_rd_op,
		csr_wr_op => csr_wr_op,
		csr_wrdata => csr_wrdata,
		csr_rddata => csr_rddata,
		mcause => mcause,
		mtvec => mtvec,
		trap_op => trap_op,
		inc_instret => inc_instret,
		pc => pc
	);

	process(clk, res_n) -- registers
    begin
        if res_n = '0' then
            pc <= (others => '0');
            ir <= (others => '0');
            wb <= (others => '0');
            nx <= (others => '0');
            rs <= (others => '0');
        elsif rising_edge(clk) then
            
            if wr_pc = '1' then
                pc <= pc_next;
            end if;
            
            if wr_ir = '1' then
                ir <= imem_in.rddata;
            end if;
            
            rs <= rf;
            
            if wr_nx = '1' then
				if get_opcode(ir) = OPCODE_JALR then
					nx <= alu_res and x"FFFFFFFE";
				else
					nx <= alu_res;
				end if;
			end if;
            
            if wr_wb = '1' then
                wb <= alu_res;
            end if;
            
        end if;
    end process;

	imm10 <= ir(30);

    process(ir)
        variable opcode : opcode_t;
    begin
        opcode := get_opcode(ir);
        imm <= (others => '0');
        
        case opcode is
            when OPCODE_LUI | OPCODE_AUIPC =>
                imm(31 downto 12) <= ir(31 downto 12);
            when OPCODE_JAL => -- J-Type
                imm(20) <= ir(31);
                imm(10 downto 1) <= ir(30 downto 21);
                imm(11) <= ir(20);
                imm(19 downto 12) <= ir(19 downto 12);
                imm(31 downto 21) <= (others => ir(31));
            when OPCODE_BRANCH => -- B-Type
                imm(12) <= ir(31);
                imm(10 downto 5) <= ir(30 downto 25);
                imm(4 downto 1) <= ir(11 downto 8);
                imm(11) <= ir(7);
                imm(31 downto 13) <= (others => ir(31));
            when OPCODE_STORE => -- S-Type
                imm(11 downto 5) <= ir(31 downto 25);
                imm(4 downto 0) <= ir(11 downto 7);
                imm(31 downto 12) <= (others => ir(31));
            when others => -- I-Type (LOAD, OP_IMM, JALR)
                imm(11 downto 0) <= ir(31 downto 20);
                imm(31 downto 12) <= (others => ir(31));
        end case;
    end process;

    with mpc select pc_next <=
        wb     when SEL_WB,
        mtvec  when SEL_MTVEC,
        nx     when others; -- SEL_NX

    with ma select alu_op_a <=
        pc     when SEL_PC,
        rf     when SEL_RF,
        rs     when others; -- SEL_RS

    with mb select alu_op_b <=
        imm             when SEL_IMM,
        rf              when SEL_RF,
        x"00000004"     when others; -- SEL_4

    with mrs select rf_rd_addr <=
        get_rs1(ir) when SEL_RS1,
        get_rs2(ir) when others; -- SEL_RS2

    with mwb select rf_wr_data <=
        wb          when SEL_WB,
        memu_rddata when SEL_MEMU,
        csr_rddata  when SEL_CSR,
        (others => '0') when others; -- SEL_EXT_M

	alu_inst : entity work.rv32_alu
        port map (
            op  => alu_op,
            a   => alu_op_a,
            b   => alu_op_b,
            result => alu_res,
            z   => alu_z
        );


    regfile_inst : entity work.rv32_fsm_regfile
        generic map (
            ADDR_WIDTH => 5,
            DATA_WIDTH => 32
        )
        port map (
            clk     => clk,
            rd_addr => rf_rd_addr,
            rd_data => rf,
            rd      => rd_rf,
            wr_addr => get_rd(ir),
            wr_data => rf_wr_data,
            wr      => wr_rf
        );

   memu_inst : entity work.memu
        port map (
            op       => memu_op,
            addr     => wb,
            wrdata   => rf,
            rddata   => memu_rddata,
            mem_in   => dmem_in,
            mem_out  => dmem_out
        );

end architecture;
