module REG_FILE (
    input   wire           CLK,
    input   wire           RST,
    input   wire           RdEn,
    input   wire           WrEn,
    input   wire   [2:0]   Address,
    input   wire   [15:0]  WrData,
    output  logic  [15:0]  RdData
);
    logic [15:0] Reg_File [8];

    always_ff @(posedge CLK, negedge RST) begin
        if (!RST) begin
            Reg_File[0] <= 16'b0;
            Reg_File[1] <= 16'b0;
            Reg_File[2] <= 16'b0;
            Reg_File[3] <= 16'b0;
            Reg_File[4] <= 16'b0;
            Reg_File[5] <= 16'b0;
            Reg_File[6] <= 16'b0;
            Reg_File[7] <= 16'b0;
        end else if (WrEn) begin
            Reg_File[Address] <= WrData;
        end
    end
    always_ff @(posedge CLK, negedge RST) begin
        if (!RST) begin
            RdData <= 16'b0;
        end else if(RdEn) begin
            RdData <= Reg_File[Address];
        end
    end
endmodule
