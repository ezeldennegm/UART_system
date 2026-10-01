module REG_FILE #(
    parameter REGF_DEPTH = 16,
    parameter REGF_WIDTH = 8,
    parameter REGF_ADDR = $clog2(REGF_DEPTH)
)(
    input   wire                     CLK,
    input   wire                     RST,
    input   wire                     RdEn,
    input   wire                     WrEn,
    input   wire   [REGF_ADDR-1:0]   Address,
    input   wire   [REGF_WIDTH-1:0]  WrData,
    output  logic  [REGF_WIDTH-1:0]  RdData,
    output  wire   [REGF_WIDTH-1:0]  reg0,
    output  wire   [REGF_WIDTH-1:0]  reg1,
    output  wire   [REGF_WIDTH-1:0]  reg2,
    output  wire   [REGF_WIDTH-1:0]  reg3
);
    logic [REGF_WIDTH-1:0] Reg_File [REGF_DEPTH];

    always_ff @(posedge CLK, negedge RST) begin
        if (!RST) begin
            Reg_File[0] <= 'b0;
            Reg_File[1] <= 'b0;
            Reg_File[2] <= {{(REGF_WIDTH-8){1'b0}},{6'd32, 1'b0, 1'b1}};
            Reg_File[3] <='d32;
            for (int i=4; i< REGF_DEPTH ; i++) begin
                Reg_File[i] <= 'b0;
            end
        end else if (WrEn) begin
            Reg_File[Address] <= WrData;
        end
    end


    always_ff @(posedge CLK, negedge RST) begin
        if (!RST) begin
            RdData <= 'b0;
        end else if(RdEn) begin
            RdData <= Reg_File[Address];
        end
    end

    assign reg0 = Reg_File[0];
    assign reg1 = Reg_File[1];
    assign reg2 = Reg_File[2];
    assign reg3 = Reg_File[3];
endmodule
