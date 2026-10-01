module ALU #(
    parameter DATA_WIDTH = 8
)(
    input   wire   [DATA_WIDTH-1:0]  A,
    input   wire   [DATA_WIDTH-1:0]  B,
    input   wire   [3:0]             ALU_FUN,
    input   wire                     CLK,
    output  logic  [DATA_WIDTH-1:0]  ALU_OUT
);

    logic [DATA_WIDTH-1:0] ALU_OUT_C;
    logic [DATA_WIDTH-1:0] overhead;

    // Combinational Cloud for Result
    always_comb begin
        ALU_OUT_C = '0;
        overhead  = '0;
        case (ALU_FUN)
            4'b0000: {overhead,ALU_OUT_C} = A + B;       // Addition
            4'b0001: {overhead,ALU_OUT_C} = A - B;       // Subtraction
            4'b0010:{overhead,ALU_OUT_C} = A * B;       // Multiplication
            4'b0011: {overhead,ALU_OUT_C} = A / B;       // Division
            4'b0100: ALU_OUT_C = A & B;       // AND
            4'b0101: ALU_OUT_C = A | B;       // OR
            4'b0110: ALU_OUT_C = ~(A & B);    // NAND
            4'b0111: ALU_OUT_C = ~(A | B);    // NOR
            4'b1000: ALU_OUT_C = A ^ B;       // XOR
            4'b1001: ALU_OUT_C = ~(A ^ B);    // XNOR
            4'b1010: ALU_OUT_C = (A == B) ? {{(DATA_WIDTH-1){1'b0}},1'b1} : '0;
            4'b1011: ALU_OUT_C = (A > B)  ? {{(DATA_WIDTH-2){1'b0}},2'b10} : '0;
            4'b1100: ALU_OUT_C = (A < B)  ? {{(DATA_WIDTH-2){1'b0}},2'b11} : '0;
            4'b1101: ALU_OUT_C = A >> 1;      // Shift Right
            4'b1110: ALU_OUT_C = A << 1;      // Shift Left
            default: ALU_OUT_C = '0;
        endcase
    end

    // Sequential Output
    always_ff @(posedge CLK) begin
        ALU_OUT <= ALU_OUT_C;
    end

endmodule