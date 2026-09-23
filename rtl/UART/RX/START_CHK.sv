module START_CHK #(
  parameter START_BIT = 0
) (
  input   wire   sample_done,
  input   wire   sampled_bit,
  input   wire   start_chk_en,

  output  logic  start_glitch
);

  always_comb begin
    if (sample_done && start_chk_en) begin
      start_glitch  = (sampled_bit == START_BIT) ? 1'b0:1'b1;
    end else begin
      start_glitch  = 1'b0;
    end
  end
endmodule
