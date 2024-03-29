`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 01/07/2018 10:10:33 PM
// Design Name: 
// Module Name: Datapath
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision: 0.07 - Reset WB_DATA Signal
// Revision: 0.06 - Re-write PC+Imm
// Revision: 0.05 - modify datamemory
// Revision: 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module Datapath #(
    parameter PC_W = 9, // Program Counter
    parameter INS_W = 32, // Instruction Width
    parameter RF_ADDRESS = 5, // Register File Address
    parameter DATA_W = 32, // Data WriteData
    parameter DM_ADDRESS = 9, // Data Memory Address
    parameter ALU_CC_W = 4 // ALU Control Code Width
    )(
    input logic clk , reset , // global clock
                              // reset , sets the PC to zero
    RegWrite , MemtoReg ,     // Register file writing enable   // Memory or ALU MUX
    ALUsrc , MemWrite ,       // Register file or Immediate MUX // Memroy Writing Enable
    MemRead ,                 // Memroy Reading Enable
    Branch ,                  // Branch Enable
    JalrSel ,                 // Jalr Mux Select
    input logic [1:0] RWSel , // Mux4to1 Select
    input logic [ ALU_CC_W -1:0] ALU_CC, // ALU Control Code ( input of the ALU )
    output logic [6:0] opcode,
    output logic [6:0] Funct7,
    output logic [2:0] Funct3,
    output logic [DATA_W-1:0] WB_Data //Result After the last MUX
    );

logic [PC_W-1:0] PC, PCPlus4, PCPlusImm;
logic [PC_W-1:0] BrMuxResult, JalrMuxReuslt;
logic [DATA_W-1:0] PCPlusImm32;
logic [INS_W-1:0] Instr;
logic [DATA_W-1:0] Result;
logic [DATA_W-1:0] Reg1, Reg2;
logic [DATA_W-1:0] ReadData;
logic [DATA_W-1:0] SrcB, ALUResult;
logic [DATA_W-1:0] ExtImm;  // ImmOut
logic [DATA_W-1:0] WRMuxResult;
logic BrSel;
logic AluZero;

// next PC
    adder #(9) pcadd(PC, 9'b100, PCPlus4);
    adder #(32) immadd({23'b0, PC}, ExtImm, PCPlusImm32);   
    assign PCPlusImm = PCPlusImm32[PC_W-1:0];
    assign BrSel = Branch & AluZero;
    mux2 #(9) brsmux(PCPlus4, PCPlusImm, BrSel, BrMuxResult);
    mux2 #(9) jalrmux(BrMuxResult, ALUResult[PC_W-1:0], JalrSel, JalrMuxReuslt);
    flopr #(9) pcreg(clk, reset, JalrMuxReuslt, PC);

 //Instruction memory
    instructionmemory instr_mem (PC, Instr);
    
    assign opcode = Instr[6:0];
    assign Funct7 = Instr[31:25];
    assign Funct3 = Instr[14:12];
      
// //Register File
    RegFile rf(clk, reset, RegWrite, Instr[11:7], Instr[19:15], Instr[24:20],
            WRMuxResult, Reg1, Reg2);
    mux2 #(32) resmux(ALUResult, ReadData, MemtoReg, Result);
    //The LAST MUX
    mux4 #(32) wrsmux(Result, {23'b0, PCPlus4}, ExtImm, PCPlusImm32, RWSel, WRMuxResult);
    assign WB_Data = WRMuxResult;
           
//// sign extend
    imm_Gen Ext_Imm (Instr,ExtImm);

//// ALU
    mux2 #(32) srcbmux(Reg2, ExtImm, ALUsrc, SrcB);
    alu alu_module(Reg1, SrcB, ALU_CC, ALUResult, Zero);
    assign AluZero = Zero;
    
////// Data memory 
	datamemory data_mem (clk, reset, MemRead, MemWrite, ALUResult[DM_ADDRESS-1:0], Reg2, Funct3, ReadData);
     
endmodule