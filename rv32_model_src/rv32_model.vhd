library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.rv32_mem_pkg.all;
use work.rv32_isa_pkg.all;

entity rv32_model is
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

architecture arch of rv32_model is

	constant CLK_PERIOD : time := 1000 ms/CLK_FREQ;

	type registers_t is array (REG_COUNT-1 downto 0) of data_t;
	-- TODO: Add further types, constants, functions and signals as needed
	function byte_to_word_addr(data : data_t) return mem_address_t is
	begin
		return data(data'left downto 2);
	end function;

begin

	main: process
		variable registers : registers_t;
		variable pc        : data_t;
		variable instr     : instr_t;
		variable opcode    : opcode_t;
		variable funct3    : funct3_t;
		variable funct7    : funct7_t;
		variable immediate : data_t;

		-- TODO: Add further variables and procedures as needed

		variable pc_next : data_t;
		variable rd_idx : integer;
		variable rs1_idx : integer;
		variable rs2_idx : integer;
		variable address : data_t;

		-- TODO: Drive dmem_out and return rddata in the correct byte ordering and with the correct extending bytes if required
		procedure read_from_dmem(constant f3: funct3_t; constant byte_addr: data_t; variable data: out data_t) is
		begin
			dmem_out.rd <= '1';
			dmem_out.address <= byte_to_word_addr(byte_addr);
			dmem_out.byteena <= (others => '1');

			loop
                wait until rising_edge(clk);
                if dmem_in.busy = '0' then
                    exit;
                end if;
            end loop;
            wait for 1 ns;
			dmem_out.rd <= '0';
			data := (others => '0');

			case f3(1 downto 0) is
				when "10" => -- LW
					data := dmem_in.rddata;
					
				when "00" => -- LB/LBU
					                    
                    case byte_addr(1 downto 0) is
                        when "00" => 
                            data(7 downto 0) := dmem_in.rddata(7 downto 0); 
                        when "01" => 
                            data(7 downto 0) := dmem_in.rddata(15 downto 8);
                        when "10" => 
                            data(7 downto 0) := dmem_in.rddata(23 downto 16);
                        when "11" => 
                            data(7 downto 0) := dmem_in.rddata(31 downto 24);
						when others => 
							null;
                    end case;
					if f3(2) = '0' and data(7) = '1' then -- signed
                        data(31 downto 8) := (others => '1');
                    end if;

				when "01" => -- LH/LHU
					case byte_addr(1) is
						when '0' => 
							data(15 downto 0) := dmem_in.rddata(15 downto 0);
						when '1' => 
							data(15 downto 0) := dmem_in.rddata(31 downto 16);						when others => 
							dmem_out.byteena <= (others => '0');
					end case;
					if f3(2) = '0' and data(15) = '1' then
                        data(31 downto 16) := (others => '1'); -- signed
                    end if;

				when others =>
					null;
			end case;
		end procedure;

		-- TODO: Write wrdata (processor byte ordering) to dmem_out
		procedure write_to_dmem(constant f3: funct3_t; constant byte_addr: data_t; constant wrdata: data_t) is
		begin
			dmem_out.wr <= '1';
			dmem_out.address <= byte_to_word_addr(byte_addr);
			case f3 is
				when "010" => -- SW (Store Word)
					dmem_out.byteena <= (others => '1');
					dmem_out.wrdata <= wrdata; 
					
				when "000" => -- SB (Store Byte)
					
					dmem_out.wrdata <= (others => '-'); 
                    
                    case byte_addr(1 downto 0) is
                        when "00" => 
                            dmem_out.byteena <= "0001";
                            dmem_out.wrdata(7 downto 0) <= wrdata(7 downto 0); 
                        when "01" => 
                            dmem_out.byteena <= "0010";
                            dmem_out.wrdata(15 downto 8) <= wrdata(7 downto 0);
                        when "10" => 
                            dmem_out.byteena <= "0100";
                            dmem_out.wrdata(23 downto 16) <= wrdata(7 downto 0);
                        when "11" => 
                            dmem_out.byteena <= "1000";
                            dmem_out.wrdata(31 downto 24) <= wrdata(7 downto 0);
						when others => 
							dmem_out.byteena <= (others => '-');
                    end case;

				when "001" => -- SH (Store Halfword)
					dmem_out.wrdata <= (others => '-');
					case byte_addr(1) is
						when '0' => 
							dmem_out.byteena <= "0011";
							dmem_out.wrdata(15 downto 0) <= wrdata(15 downto 0);
						when '1' => 
							dmem_out.byteena <= "1100";
							dmem_out.wrdata(31 downto 16) <= wrdata(15 downto 0);
						when others => 
							dmem_out.byteena <= (others => '-');
					end case;
				when others =>
					dmem_out.byteena <= (others => '-');
			end case;

			loop
                wait until rising_edge(clk);
                if dmem_in.busy = '0' then
                    exit;
                end if;
            end loop;
            wait for 1 ns;
			dmem_out.wr <= '0';
		end procedure;

		--TODO: Read the address in the imem the pc currently points to and return it in rddata
		procedure read_from_imem(variable data: out instr_t) is
		begin
			imem_out.rd <= '1';
			imem_out.address <= pc(imem_out.address'length+1 downto 2);
			loop
                wait until rising_edge(clk);
                if imem_in.busy = '0' then
                    exit;
                end if;
            end loop;
            wait for 1 ns;
			imem_out.rd <= '0';
			--TODO: return data in imem_in.rddata
			data := imem_in.rddata;
		end procedure;

	begin
		dmem_out <= MEM_OUT_NOP;
		imem_out <= MEM_OUT_NOP;
		wait until res_n;
		wait until rising_edge(clk);
		wait for 1 ns;

		pc := (others => '0');
        for i in 0 to REG_COUNT-1 loop
            registers(i) := (others => '0');
        end loop;

		loop
			read_from_imem(instr);
			-- TODO: Add implementation (get instruction, decode and execute it)
			opcode := get_opcode(instr);
            funct3 := get_funct3(instr);
            funct7 := get_funct7(instr);
            
            rd_idx  := to_integer(unsigned(get_rd(instr)));
            rs1_idx := to_integer(unsigned(get_rs1(instr)));
            rs2_idx := to_integer(unsigned(get_rs2(instr)));


			pc_next := std_logic_vector(unsigned(pc) + 4);

            case opcode is

                when OPCODE_LOAD => 
					immediate := std_ulogic_vector(resize(signed(instr(31 downto 20)), 32));
					address := std_ulogic_vector(unsigned(registers(rs1_idx)) + unsigned(immediate));
					read_from_dmem(funct3, address, registers(rd_idx));

				when OPCODE_STORE =>
					immediate(11 downto 0) := instr(31 downto 25) & instr(11 downto 7);
					immediate(31 downto 12) := (others => instr(31));
					address := std_ulogic_vector(unsigned(registers(rs1_idx)) + unsigned(immediate));
					write_to_dmem(funct3, address, registers(rs2_idx));

				when OPCODE_BRANCH => 
					immediate(12) := instr(31);
                    immediate(11) := instr(7);
                    immediate(10 downto 5) := instr(30 downto 25);
                    immediate(4 downto 1) := instr(11 downto 8);
                    immediate(0) := '0';
                    immediate(31 downto 13) := (others => instr(31));

                    case funct3 is
                        when "000" => -- BEQ
                            if registers(rs1_idx) = registers(rs2_idx) then
                                pc_next := std_logic_vector(unsigned(pc) + unsigned(immediate));
                            end if;
                            
                        when "001" => -- BNE
                            if registers(rs1_idx) /= registers(rs2_idx) then
                                pc_next := std_logic_vector(unsigned(pc) + unsigned(immediate));
                            end if;
                            
                        when "100" => -- BLT
                            if signed(registers(rs1_idx)) < signed(registers(rs2_idx)) then
                                pc_next := std_logic_vector(unsigned(pc) + unsigned(immediate));
                            end if;
                            
                        when "101" => -- BGE
                            if signed(registers(rs1_idx)) >= signed(registers(rs2_idx)) then
                                pc_next := std_logic_vector(unsigned(pc) + unsigned(immediate));
                            end if;
                            
                        when "110" => -- BLTU
                            if unsigned(registers(rs1_idx)) < unsigned(registers(rs2_idx)) then
                                pc_next := std_logic_vector(unsigned(pc) + unsigned(immediate));
                            end if;
                            
                        when "111" => -- BGEU
                            if unsigned(registers(rs1_idx)) >= unsigned(registers(rs2_idx)) then
                                pc_next := std_logic_vector(unsigned(pc) + unsigned(immediate));
                            end if;
                            
                        when others =>
                            null;
                    end case;
				when OPCODE_JALR => 
					immediate := std_ulogic_vector(resize(signed(instr(31 downto 20)), 32));
					address := std_ulogic_vector(unsigned(registers(rs1_idx)) + unsigned(immediate));
					address := address(31 downto 1) & '0';
					registers(rd_idx) := pc_next;

					pc_next := address;

				when OPCODE_JAL => 
					immediate(20) := instr(31);
                    immediate(19 downto 12) := instr(19 downto 12);
                    immediate(11) := instr(20);
                    immediate(10 downto 1) := instr(30 downto 21);
                    immediate(0) := '0';
                    immediate(31 downto 21) := (others => instr(31));

					registers(rd_idx) := pc_next;
					pc_next := std_logic_vector(unsigned(pc) + unsigned(immediate));

                when OPCODE_OP_IMM => 
                    immediate := std_ulogic_vector(resize(signed(instr(31 downto 20)), 32));
                    
                    case funct3 is
                        when "000" => 
                            registers(rd_idx) := std_ulogic_vector(unsigned(registers(rs1_idx)) + unsigned(immediate));
                            
                        when "010" => 
                            if signed(registers(rs1_idx)) < signed(immediate) then
                                registers(rd_idx) := std_ulogic_vector(to_unsigned(1, 32));
                            else
                                registers(rd_idx) := (others => '0');
                            end if;
                            
                        when "011" => 
                            if unsigned(registers(rs1_idx)) < unsigned(immediate) then
                                registers(rd_idx) := std_ulogic_vector(to_unsigned(1, 32));
                            else
                                registers(rd_idx) := (others => '0');
                            end if;
                            
                        when "100" => 
                            registers(rd_idx) := registers(rs1_idx) xor immediate;
                            
                        when "110" => 
                            registers(rd_idx) := registers(rs1_idx) or immediate;
                            
                        when "111" => 
                            registers(rd_idx) := registers(rs1_idx) and immediate;
                            
                        when "001" => 
                            registers(rd_idx) := std_ulogic_vector(shift_left(unsigned(registers(rs1_idx)), to_integer(unsigned(immediate(4 downto 0)))));
                            
                        when "101" => 
                            if instr(30) = '0' then
                                registers(rd_idx) := std_ulogic_vector(shift_right(unsigned(registers(rs1_idx)), to_integer(unsigned(immediate(4 downto 0)))));
                            else
                                registers(rd_idx) := std_ulogic_vector(shift_right(signed(registers(rs1_idx)), to_integer(unsigned(immediate(4 downto 0)))));
                            end if;
                            
                        when others =>
                            null;
                    end case;

				when OPCODE_OP => 
                    case funct3 is
                        when "000" => 
                            if funct7(5) = '1' then
                                registers(rd_idx) := std_ulogic_vector(unsigned(registers(rs1_idx)) - unsigned(registers(rs2_idx)));
                            else
                                registers(rd_idx) := std_ulogic_vector(unsigned(registers(rs1_idx)) + unsigned(registers(rs2_idx)));
                            end if;
                            
                        when "001" => 
                            registers(rd_idx) := std_ulogic_vector(shift_left(unsigned(registers(rs1_idx)), to_integer(unsigned(registers(rs2_idx)(4 downto 0)))));
                            
                        when "010" => 
                            if signed(registers(rs1_idx)) < signed(registers(rs2_idx)) then
                                registers(rd_idx) := std_ulogic_vector(to_unsigned(1, 32));
                            else
                                registers(rd_idx) := (others => '0');
                            end if;
                            
                        when "011" => 
                            if unsigned(registers(rs1_idx)) < unsigned(registers(rs2_idx)) then
                                registers(rd_idx) := std_ulogic_vector(to_unsigned(1, 32));
                            else
                                registers(rd_idx) := (others => '0');
                            end if;
                            
                        when "100" => 
                            registers(rd_idx) := registers(rs1_idx) xor registers(rs2_idx);
                            
                        when "101" => 
                            if funct7(5) = '0' then
                                registers(rd_idx) := std_ulogic_vector(shift_right(unsigned(registers(rs1_idx)), to_integer(unsigned(registers(rs2_idx)(4 downto 0)))));
                            else
                                registers(rd_idx) := std_ulogic_vector(shift_right(signed(registers(rs1_idx)), to_integer(unsigned(registers(rs2_idx)(4 downto 0)))));
                            end if;
                            
                        when "110" => 
                            registers(rd_idx) := registers(rs1_idx) or registers(rs2_idx);
                            
                        when "111" => 
                            registers(rd_idx) := registers(rs1_idx) and registers(rs2_idx);
                            
                        when others =>
                            null;
                    end case;

				when OPCODE_AUIPC =>
					immediate := (others => '0');
					immediate(31 downto 12) := instr(31 downto 12);
					registers(rd_idx) := std_ulogic_vector(unsigned(immediate) + unsigned(pc));
                    
                when OPCODE_LUI =>
					immediate := (others => '0');
					immediate(31 downto 12) := instr(31 downto 12);
					registers(rd_idx) := immediate;

				when OPCODE_FENCE =>
					null;

				when OPCODE_SYSTEM =>
					case funct3 is
                        when "000" =>
                            case instr(31 downto 20) is
                                when "000000000000" =>
                                    report "ECALL instruction reached. Halting or Trapping." severity note;
                                    
                                when "000000000001" =>
                                    report "EBREAK instruction reached. Debugger requested." severity note;
                                    
                                when others =>
                                    null;
                            end case;


                        when "001" => 
                            null; 
                        when "010" =>
                            null;
                        when "011" =>
                            null;
                        when "101" | "110" | "111" => 
                            null;
                            
                        when others =>
                            null;
                    end case;
					
                when others =>
                    null;
            end case;
            registers(0) := (others => '0');
            pc := pc_next;
		end loop;
		wait;
	end process;

end architecture;
