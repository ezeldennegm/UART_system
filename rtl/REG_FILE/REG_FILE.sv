module REG_FILE (
    input   wire           CLK,
    input   wire           RST,
    input   wire           RdEn,
    input   wire           WrEn,
    input   wire   [2:0]   Address,
    input   wire   [7:0]   WrData,
    output  logic  [7:0]   RdData,
    output  wire   [7:0]   reg0,
    output  wire   [7:0]   reg1,
    output  wire   [7:0]   reg2,
    output  wire   [7:0]   reg3
);
    logic [7:0] Reg_File [16];

    always_ff @(posedge CLK, negedge RST) begin
        if (!RST) begin
            for (int i=0; i<16; i++) begin
                Reg_File[i] <= 8'b0;
            end
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

    assign reg0 = Reg_File[0];
    assign reg1 = Reg_File[1];
    assign reg2 = Reg_File[2];
    assign reg3 = Reg_File[3];
endmodule
