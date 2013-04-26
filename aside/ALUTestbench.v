//  Module: ALUTestbench
//  Desc:   32-bit ALU testbench for the MIPS150 Processor
//  Feel free to edit this testbench to add additional functionality
//  
//  Note that this testbench only tests correct operation of the ALU,
//  it doesn't check that you're mux-ing the correct values into the inputs
//  of the ALU. 

// If #1 is in the initial block of your testbench, time advances by
// 1ns rather than 1ps
`timescale 1ns / 1ps

`include "Opcode.vh"

`define Test #1; checkOutput(opcode, funct)
`define RandFunct funct = {$random} & 6'h3F

module ALUTestbench();

    parameter Halfcycle = 5; //half period is 5ns
    
    localparam Cycle = 2*Halfcycle;
    
    reg Clock;
    
    // Clock Signal generation:
    initial Clock = 0; 
    always #(Halfcycle) Clock = ~Clock;
    
    // Register and wires to test the ALU
    reg [5:0] funct;
    reg [5:0] opcode;
    reg [31:0] A, B;
    wire[31:0] DUTout;
    reg [31:0] REFout; 
    wire [3:0] ALUop;

    reg [30:0] rand_31;
    reg [14:0] rand_15;

    // Signed operations; these are useful
    // for signed operations
    wire signed [31:0] B_signed;
    assign B_signed = $signed(B);

    wire signed_comp, unsigned_comp;
    assign signed_comp = ($signed(A) < $signed(B));
    assign unsigned_comp = A < B;

    // Task for checking output
    task checkOutput;
        input [5:0] opcode, funct;
        if ( REFout !== DUTout ) begin
            $display("FAIL: Incorrect result for opcode %b, funct: %b:", opcode, funct);
            $display("\tA: 0x%h, B: 0x%h, DUTout: 0x%h, REFout: 0x%h", A, B, DUTout, REFout);
            $finish();
        end
        else begin
            $display("PASS: opcode %b, funct %b", opcode, funct);
            $display("\tA: 0x%h, B: 0x%h, DUTout: 0x%h, REFout: 0x%h", A, B, DUTout, REFout);
        end
    endtask

    //This is where the modules being tested are instantiated. 
    ALUdec DUT1(.funct(funct),
        .opcode(opcode),
        .ALUop(ALUop));

    ALU DUT2( .A(A),
        .B(B),
        .ALUop(ALUop),
        .Out(DUTout));

    integer i;
    localparam loops = 25; // number of times to run the tests for

    // Testing logic:
    initial begin
        for(i = 0; i < loops; i = i + 1)
        begin
            /////////////////////////////////////////////
            // Put your random tests inside of this loop
            // and hard-coded tests outside of the loop
            // (see comment below)
            // //////////////////////////////////////////
            #1;
            // Make both A and B negative to check signed operations
            rand_31 = {$random} & 31'h7FFFFFFF;
            rand_15 = {$random} & 15'h7FFF;
            A = {1'b1, rand_31};
            // Hard-wire 16 1's in front of B for sign extension
            B = {16'hFFFF, 1'b1, rand_15};
            // Set funct random to test that it doesn't affect non-R-type insts
            funct = {$random} % 6'b111111;

            // Test load and store instructions (should add operands)
            opcode = `LB;
            REFout = A + B; 
            #1;
            checkOutput(opcode, funct);

            opcode = `LH;
            #1;
            checkOutput(opcode, funct);

            opcode = `LW;
            #1;
            checkOutput(opcode, funct);

            opcode = `LBU;
            #1;
            checkOutput(opcode, funct);

            opcode = `LHU;
            #1;
            checkOutput(opcode, funct);

            opcode = `SB;
            #1;
            checkOutput(opcode, funct);

            opcode = `SH;
            #1;
            checkOutput(opcode, funct);

            opcode = `SW;
            #1;
            checkOutput(opcode, funct);

            /// MY TESTS
            `RandFunct;     opcode = `LUI;      REFout = {B[15:0], 16'h0000};`Test;
            // ADD
            funct = `ADDU;  opcode = `RTYPE;    REFout = A + B;         `Test;
            `RandFunct;     opcode = `ADDIU;                            `Test;

            // SUBTRACT
            funct = `SUBU;  opcode = `RTYPE;    REFout = A - B;         `Test;

            // LEFT-SHIFT
            funct = `SLL;   opcode = `RTYPE;    REFout = B<<A;          `Test;
            funct = `SLLV;                                              `Test;

            // RIGHT-SHIFT
            funct = `SRL;                       REFout = B>>A;          `Test;
            funct = `SRLV;                                              `Test;
            funct = `SRA;                       REFout = $signed(B)>>>A;`Test;
            funct = `SRAV;                                              `Test;

            // < (signed)
            funct = `SLT;                       REFout = signed_comp;   `Test;
            `RandFunct;     opcode = `SLTI;                             `Test;

            // < (unsigned)
            funct = `SLTU;  opcode = `RTYPE;    REFout = unsigned_comp; `Test;
            `RandFunct;     opcode = `SLTIU;                            `Test;
        end

        // Signed & Unsigned random tests
        for(i = 0; i < loops; i = i + 1) begin
            A = {$random} & 32'hFFFF_FFFF;
            B = {$random} & 32'hFFFF_FFFF;
            funct = {$random} & 6'h3F;
           
            // LUI
            `RandFunct;     opcode = `LUI;      REFout = {B[15:0],16'h0000};           `Test;
            // ADD
            funct = `ADDU;  opcode = `RTYPE;    REFout = A+B;           `Test;
            `RandFunct;     opcode = `ADDIU;                            `Test;

            // SUBTRACT
            funct = `SUBU;  opcode = `RTYPE;    REFout = A-B;           `Test;

            // LEFT-SHIFT
            funct = `SLL;   opcode = `RTYPE;    REFout = B<<A;          `Test;
            funct = `SLLV;                                              `Test;

            // RIGHT-SHIFT
            funct = `SRL;                       REFout = B>>A;          `Test;
            funct = `SRLV;                                              `Test;
            funct = `SRA;                       REFout = $signed(B)>>>A;`Test;
            funct = `SRAV;                                              `Test;

            // < (signed)
            funct = `SLT;                       REFout = signed_comp;   `Test;
            `RandFunct;     opcode = `SLTI;                             `Test;

            // < (unsigned)
            funct = `SLTU;  opcode = `RTYPE;    REFout = unsigned_comp; `Test;
            `RandFunct;     opcode = `SLTIU;                            `Test;

            // AND
            funct = `AND;   opcode = `RTYPE;    REFout = A & B;         `Test;
            `RandFunct;     opcode = `ANDI;                             `Test;

            // OR
            funct = `OR;    opcode = `RTYPE;    REFout = A | B;         `Test;
            `RandFunct;     opcode = `ORI;                              `Test;

            // XOR
            funct = `XOR;   opcode = `RTYPE;    REFout = A ^ B;         `Test;
            `RandFunct;     opcode = `XORI;                             `Test;

            // NOR
            funct = `NOR;   opcode = `RTYPE;    REFout = ~(A | B);      `Test;

        end
        ///////////////////////////////
        // Hard coded tests go here
        ///////////////////////////////
        $display("\n\nBEGIN HARD-CODED TESTS");
        funct = `SUBU;      opcode = `RTYPE; 
        A = -1; B = -2;                         REFout = A - B;         `Test;
        A = -2; B = -1;                         REFout = A - B;         `Test;
        A = 1;  B = -2;                         REFout = A - B;         `Test;
        A = -2; B = 1;                          REFout = A - B;         `Test;

        funct = `SLT;       opcode = `RTYPE;   
        A = -5; B = -4;                         REFout = 1;             `Test;
        A = -3; B = -4;                         REFout = 0;             `Test;
        A = 1;  B = -2;                         REFout = 0;             `Test;
        A = -2; B = 1;                          REFout = 1;             `Test;
        A = 2; B = 1;                           REFout = 0;             `Test;
        A = 1; B = 2;                           REFout = 1;             `Test;

        $display("\n\nALL TESTS PASSED!");
        $finish();
    end

  endmodule
