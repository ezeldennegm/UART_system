module DF_SYNC #(
  parameter DATA_WIDTH  = 8
) (
  input   wire                    clk,
  input   wire                    a_rst_n,

  input   wire  [DATA_WIDTH-1:0]  data_in,

  output  wire  [DATA_WIDTH-1:0]  data_out
);
  logic [DATA_WIDTH-1:0] F_stage_1, F_stage_2;

  assign data_out = F_stage_2;
  always_ff @(posedge clk, negedge a_rst_n) begin
    if (!a_rst_n) begin
      F_stage_1 <=  'b0;
      F_stage_2 <=  'b0;
    end else begin
      F_stage_1 <=  data_in;
      F_stage_2 <=  F_stage_1;
    end
  end
endmodule
