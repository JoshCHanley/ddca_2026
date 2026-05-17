
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.rv32_mem_pkg.all;
use work.rv32_isa_pkg.all;
use work.rv32_alu_pkg.all;
use work.rv32_fsm_types_pkg.all;
use work.rv32_ext_m_pkg.all;

entity rv32_fsm_ctrl_unit is
	port (
		clk : in std_logic;
		res_n : in std_logic;
		opcode : in opcode_t;
		funct3 : in funct3_t;
		funct7 : in funct7_t;
		funct12 : in funct12_t;
		imm10 : in std_ulogic;
		rs1 : in reg_address_t;
		rs2 : in reg_address_t;
		alu_z : in std_ulogic;
		dmem_busy : in std_ulogic;
		imem_busy : in std_ulogic;
		ext_m_busy : in std_logic;
		ma : out ma_ctrl_t;
		mb : out mb_ctrl_t;
		mpc : out mpc_ctrl_t;
		mrs : out mrs_ctrl_t;
		mwb : out mwb_ctrl_t;
		wr_pc : out std_ulogic;
		wr_ir : out std_ulogic;
		wr_wb : out std_ulogic;
		wr_nx : out std_ulogic;
		rd_rf : out std_logic;
		wr_rf : out std_logic;
		rd_imem : out std_ulogic;
		alu_op : out rv32_alu_op_t;
		memu_op : out memu_op_t;
		ext_m_op : out ext_m_op_t;
		ext_m_start : out std_ulogic;
		cvs : out cvs_ctrl_t;
		csr_wr_op : out csr_wr_op_t := NOP;
		csr_rd_op : out csr_rd_op_t := NOP;
		trap_op : out trap_op_t := NOP;
		inc_instret : out std_logic := '0'
	);
end entity;


architecture arch of rv32_fsm_ctrl_unit is
    type fsm_state_type is (FETCH, FETCH2, DECODE, DECODE2, EXECUTE, MEMORY, WRITEBACK);
    type fsm_t is record
        state : fsm_state_type;
    end record;
    signal s, s_nxt : fsm_t;
    constant RESET : fsm_t := (
        state => FETCH
    );
begin
    sync : process(clk, res_n)
    begin
        if res_n = '0' then
            s <= RESET;
        elsif rising_edge(clk) then
            s <= s_nxt;
        end if;
    end process;

    comb : process(all)
    begin
        s_nxt <= s;
        
        ma <= SEL_RS;
        mb <= SEL_RF;
        mpc <= SEL_NX;
        mrs <= SEL_RS1;
        mwb <= SEL_WB;
        cvs <= SEL_RF;
        
        wr_pc <= '0';
        wr_ir <= '0';
        wr_wb <= '0';
        wr_nx <= '0';
        wr_rf <= '0';
        
        rd_rf <= '0';
        rd_imem <= '0';
        
        alu_op <= ALU_NOP;
        memu_op <= MEMU_NOP;
        ext_m_op <= M_MUL;
        ext_m_start <= '0';
        
        csr_wr_op <= NOP;
        csr_rd_op <= NOP;
        trap_op <= NOP;
        inc_instret <= '0';

        case s.state is
            when FETCH =>
                -- Request instruction and immediately wait for memory latency
                rd_imem <= '1';
                s_nxt.state <= FETCH2;

            when FETCH2 =>
                rd_imem <= '1';
                ma <= SEL_PC;
                mb <= SEL_4;
                alu_op <= ALU_ADD;
                
                if imem_busy = '0' then
                    wr_ir <= '1'; 
                    wr_nx <= '1'; 
                    s_nxt.state <= DECODE;
                end if;

            when DECODE =>
                rd_rf <= '1';
                mrs <= SEL_RS1;
                
                case opcode is
                    when OPCODE_OP | OPCODE_STORE | OPCODE_BRANCH =>
                        s_nxt.state <= DECODE2;
                    when others =>
                        s_nxt.state <= EXECUTE;
                end case;

            when DECODE2 =>
                rd_rf <= '1';
                mrs <= SEL_RS2;
                s_nxt.state <= EXECUTE;

                
            when EXECUTE =>
                wr_wb <= '1';
                
                case opcode is
                    when OPCODE_OP_IMM => 
                        ma <= SEL_RF; 
                        mb <= SEL_IMM;
                        s_nxt.state <= WRITEBACK;
                        
                        case funct3 is
                            when "000" => alu_op <= ALU_ADD;
                            when "010" => alu_op <= ALU_SLT;
                            when "011" => alu_op <= ALU_SLTU;
                            when "100" => alu_op <= ALU_XOR;
                            when "110" => alu_op <= ALU_OR;
                            when "111" => alu_op <= ALU_AND;
                            when "001" => alu_op <= ALU_SLL;
                            when "101" => 
                                if imm10 = '1' then alu_op <= ALU_SRA; else alu_op <= ALU_SRL; end if;
                            when others => alu_op <= ALU_NOP;
                        end case;
                        
                    when OPCODE_OP => 
                        ma <= SEL_RS; 
                        mb <= SEL_RF;
                        s_nxt.state <= WRITEBACK;
                        
                        case funct3 is
                            when "000" => 
                                if imm10 = '1' then alu_op <= ALU_SUB; else alu_op <= ALU_ADD; end if;
                            when "010" => alu_op <= ALU_SLT;
                            when "011" => alu_op <= ALU_SLTU;
                            when "100" => alu_op <= ALU_XOR;
                            when "110" => alu_op <= ALU_OR;
                            when "111" => alu_op <= ALU_AND;
                            when "001" => alu_op <= ALU_SLL;
                            when "101" => 
                                if imm10 = '1' then alu_op <= ALU_SRA; else alu_op <= ALU_SRL; end if;
                            when others => alu_op <= ALU_NOP;
                        end case;

                    when OPCODE_AUIPC =>
                        ma <= SEL_PC;
                        mb <= SEL_IMM;
                        alu_op <= ALU_ADD;
                        s_nxt.state <= WRITEBACK;

                    when OPCODE_LUI =>
                        ma <= SEL_RS; 
                        mb <= SEL_IMM;
                        alu_op <= ALU_NOP; 
                        s_nxt.state <= WRITEBACK;

                    when OPCODE_LOAD =>
                        ma <= SEL_RF; 
                        mb <= SEL_IMM;
                        alu_op <= ALU_ADD;
                        s_nxt.state <= MEMORY;

                    when OPCODE_STORE =>
                        ma <= SEL_RS; 
                        mb <= SEL_IMM;
                        alu_op <= ALU_ADD;
                        -- mrs <= SEL_RS2;
                        s_nxt.state <= MEMORY;

                    when OPCODE_BRANCH =>
                        wr_wb <= '0';
                        ma <= SEL_RS;
                        mb <= SEL_RF;
                        s_nxt.state <= WRITEBACK;
                        
                        case funct3 is
                            when "000" => alu_op <= ALU_SUB;  if alu_z = '1' then s_nxt.state <= MEMORY; end if;
                            when "001" => alu_op <= ALU_SUB;  if alu_z = '0' then s_nxt.state <= MEMORY; end if;
                            when "100" => alu_op <= ALU_SLT;  if alu_z = '0' then s_nxt.state <= MEMORY; end if;
                            when "101" => alu_op <= ALU_SLT;  if alu_z = '1' then s_nxt.state <= MEMORY; end if;
                            when "110" => alu_op <= ALU_SLTU; if alu_z = '0' then s_nxt.state <= MEMORY; end if;
                            when "111" => alu_op <= ALU_SLTU; if alu_z = '1' then s_nxt.state <= MEMORY; end if;
                            when others => null;
                        end case;

                    when OPCODE_JAL =>
                        ma <= SEL_PC;
                        mb <= SEL_IMM;
                        alu_op <= ALU_ADD;
                        wr_nx <= '1';
                        wr_wb <= '0';
                        s_nxt.state <= MEMORY; 

                    when OPCODE_JALR =>
                        ma <= SEL_RF;
                        mb <= SEL_IMM;
                        alu_op <= ALU_ADD;
                        wr_nx <= '1';
                        wr_wb <= '0';
                        s_nxt.state <= MEMORY; 

                    when others =>
                        s_nxt.state <= FETCH;
                end case;

            when MEMORY =>
                case opcode is
                    when OPCODE_LOAD =>
                        case funct3 is
                            when "000" => memu_op <= (rd => '1', wr => '0', access_type => MEM_B);
                            when "001" => memu_op <= (rd => '1', wr => '0', access_type => MEM_H);
                            when "010" => memu_op <= (rd => '1', wr => '0', access_type => MEM_W);
                            when "100" => memu_op <= (rd => '1', wr => '0', access_type => MEM_BU);
                            when "101" => memu_op <= (rd => '1', wr => '0', access_type => MEM_HU);
                            when others => memu_op <= (rd => '1', wr => '0', access_type => MEM_W);
                        end case;
                        if dmem_busy = '0' then s_nxt.state <= WRITEBACK; end if;
                        
                    when OPCODE_STORE =>
                        case funct3 is
                            when "000" => memu_op <= (rd => '0', wr => '1', access_type => MEM_B);
                            when "001" => memu_op <= (rd => '0', wr => '1', access_type => MEM_H);
                            when "010" => memu_op <= (rd => '0', wr => '1', access_type => MEM_W);
                            when others => memu_op <= (rd => '0', wr => '1', access_type => MEM_W);
                        end case;
                        if dmem_busy = '0' then s_nxt.state <= WRITEBACK; end if;

                    when OPCODE_BRANCH =>
                        ma <= SEL_PC;
                        mb <= SEL_IMM;
                        alu_op <= ALU_ADD;
                        wr_nx <= '1';
                        s_nxt.state <= WRITEBACK;

                    when OPCODE_JAL | OPCODE_JALR =>
                        ma <= SEL_PC;
                        mb <= SEL_4;
                        alu_op <= ALU_ADD;
                        wr_wb <= '1';
                        s_nxt.state <= WRITEBACK;
                        
                    when others =>
                        s_nxt.state <= WRITEBACK;
                end case;

            when WRITEBACK =>
                wr_pc <= '1';
                mpc <= SEL_NX;
                s_nxt.state <= FETCH;

                case opcode is
                    when OPCODE_OP | OPCODE_OP_IMM | OPCODE_LUI | OPCODE_AUIPC =>
                        wr_rf <= '1';
                        mwb <= SEL_WB; 
                        
                    when OPCODE_LOAD =>
                        wr_rf <= '1';
                        mwb <= SEL_MEMU;
                        
                        case funct3 is
                            when "000" => memu_op <= (rd => '0', wr => '0', access_type => MEM_B);
                            when "001" => memu_op <= (rd => '0', wr => '0', access_type => MEM_H);
                            when "010" => memu_op <= (rd => '0', wr => '0', access_type => MEM_W);
                            when "100" => memu_op <= (rd => '0', wr => '0', access_type => MEM_BU);
                            when "101" => memu_op <= (rd => '0', wr => '0', access_type => MEM_HU);
                            when others => memu_op <= (rd => '0', wr => '0', access_type => MEM_W);
                        end case;
                        
                    when OPCODE_JAL | OPCODE_JALR =>
                        wr_rf <= '1';
                        mwb <= SEL_WB; 
                        mpc <= SEL_NX;
                        
                    when others => null;
                end case;

        end case;
    end process;
end architecture;