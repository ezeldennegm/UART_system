module ALU(
    input   wire   [15:0]  A,
    input   wire   [15:0]  B,
    input   wire   [3:0]   ALU_FUN,
    input   wire           CLK,
    output  logic  [15:0]  ALU_OUT,
    output  logic          Carry_Flag,
    output  logic          Arith_Flag,
    output  logic          Logic_Flag,
    output  logic          CMP_Flag,
    output  logic          Shift_Flag
);
    logic [15:0] ALU_OUT_C;
    logic Carry_Flag_C;

    // Compinational Cloud For Flags
    always_comb begin
        Arith_Flag = 1'b0;
        Logic_Flag = 1'b0;
        CMP_Flag = 1'b0;
        Shift_Flag = 1'b0;
        case (ALU_FUN)
            // Arithmetic OPS
            4'b0000,
            4'b0001,
            4'b0010,
            4'b0011: Arith_Flag = 1'b1;
            // Logical OPS
            4'b0100,
            4'b0101,
            4'b0110,
            4'b0111,
            4'b1000,
            4'b1001: Logic_Flag = 1'b1;
            // Comparison OPS
            4'b1010,
            4'b1011,
            4'b1100: CMP_Flag = 1'b1;
            // Shift OPS
            4'b1101,
            4'b1110: Shift_Flag = 1'b1;
            default : begin
                Arith_Flag = 1'b0;
                Logic_Flag = 1'b0;
                CMP_Flag = 1'b0;
                Shift_Flag = 1'b0;
            end
        endcase
    end

    // Compinational Cloud for Result and Carry flag
    always_comb begin
        Carry_Flag_C = 1'b0;
        case (ALU_FUN)
            4'b0000: {Carry_Flag_C,ALU_OUT_C} = A + B; // Addition
            4'b0001: {Carry_Flag_C,ALU_OUT_C} = A - B; // Subtraction
            4'b0010: ALU_OUT_C = A * B; // Multiplication (Will Result in width overflow since A*B is 32 bits)
            4'b0011: ALU_OUT_C = A / B; // Division
            4'b0100: ALU_OUT_C = A & B; // AND
            4'b0101: ALU_OUT_C = A | B; // OR
            4'b0110: ALU_OUT_C = ~(A & B); // NAND
            4'b0111: ALU_OUT_C = ~(A | B); // NOR
            4'b1000: ALU_OUT_C = A ^ B; // XOR
            4'b1001: ALU_OUT_C = ~(A ^ B); // XNOR
            4'b1010: ALU_OUT_C = (A == B) ? 16'b1 : 0; // Equal
            4'b1011: ALU_OUT_C = (A > B) ? 16'b10 : 0; // Greater Than
            4'b1100: ALU_OUT_C = (A < B) ? 16'b11 : 0; // Less than
            4'b1101: ALU_OUT_C = A >> 1'b1; // Shift Right
            4'b1110: ALU_OUT_C = A << 1'b1; // Shift Right
            default: ALU_OUT_C = 16'b0;
        endcase
    end

    // Sequential Output
    always_ff @(posedge CLK) begin
        ALU_OUT <= ALU_OUT_C;
        Carry_Flag <= Carry_Flag_C;
    end
endmodule
