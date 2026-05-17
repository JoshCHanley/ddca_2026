package rv32_fsm_types_pkg is
	type ma_ctrl_t is (SEL_PC, SEL_RF, SEL_RS);
	type mb_ctrl_t is (SEL_IMM, SEL_RF, SEL_4);
	type mpc_ctrl_t is (SEL_WB, SEL_NX, SEL_MTVEC);
	type mrs_ctrl_t is (SEL_RS1, SEL_RS2);
	type mwb_ctrl_t is (SEL_WB, SEL_MEMU, SEL_EXT_M, SEL_CSR);
	
	type cvs_ctrl_t is (SEL_RF, SEL_UIMM);
	type csr_wr_op_t is (NOP, WRITE, SET, CLEAR);
	type csr_rd_op_t is (NOP, READ);

	type trap_op_t is (
		NOP,
		INSTRUCTION_ADDRESS_MISALIGNED, -- mcause = 0x00
		ILLEGAL_INSTRUCTION, -- mcause = 0x01
		INSTRUCTION_ACCESS_FAULT, -- mcause = 0x02
		BREAKPOINT, -- mcause = 0x03
		LOAD_ADDRESS_MISALIGNED, -- mcause = 0x04
		LOAD_ACCESS_FAULT, -- mcause = 0x05
		STORE_AMO_ADDRESS_MISALIGNED, -- mcause = 0x06
		STORE_AMO_ACCESS_FAULT, -- mcause = 0x07
		ECALL_FROM_M_MODE -- mcause = 0xb
	);
end package;
