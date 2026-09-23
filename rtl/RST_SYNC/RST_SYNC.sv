module RST_SYNC #(
  parameter NUM_STAGES = 2
) (
  input   wire  a_rst_n,
  input   wire  clk,

  output  wire  sync_rst_n
);
  logic [NUM_STAGES-1:0]  FF_stages;

  assign  sync_rst_n  = FF_stages[0];

  always_ff @(posedge clk, negedge a_rst_n) begin
    if (!a_rst_n) begin
      FF_stages <=  'b0;
    end else begin
      FF_stages <= {1'b1,FF_stages[NUM_STAGES-1:1]};
    end
  end

endmodule
