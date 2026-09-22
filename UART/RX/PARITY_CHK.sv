module PARITY_CHK(
  input   wire   sample_done,
  input   wire   sampled_bit,    // frame parity
  input   wire   parity_calc,    // calculated parity
  input   wire   parity_chk_en,

  output  logic  parity_err
);

  always_comb begin
    if (sample_done && parity_chk_en) begin
      parity_err  = (sampled_bit == parity_calc) ? 1'b0:1'b1;
    end else begin
      parity_err  = 1'b0;
    end
  end
endmodule
