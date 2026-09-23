module MULTI_FLOP #(
  parameter NUM_STAGES  = 2
) (
  input   wire  clk,
  input   wire  a_rst_n,

  input   wire  async_ctrl_signal,  // one-bit control signal

  output  wire  sync_ctrl_signal
);
  logic [NUM_STAGES-1:0] FF_bus;

  assign sync_ctrl_signal = FF_bus[0];

  always_ff @(posedge clk, negedge a_rst_n) begin
    if (!a_rst_n) begin
      FF_bus  <=  'b0;
    end else begin
      FF_bus  <=  {async_ctrl_signal,  FF_bus[NUM_STAGES-1:1]};
    end
  end

endmodule
