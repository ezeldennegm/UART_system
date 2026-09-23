module PULSE_GEN (
  input   wire  clk,
  input   wire  a_rst_n,

  input   wire  pulse_in,

  output  wire  pulse_out
);
  logic pulse_reg;

  assign pulse_out = (pulse_in & ~pulse_reg);

  always_ff @(posedge clk, negedge a_rst_n) begin
    if (!a_rst_n) begin
      pulse_reg   <=  1'b0;
    end else begin
      pulse_reg   <=  pulse_in;
    end
  end
endmodule
