module STOP_CHK #(
  parameter STOP_BIT = 1
) (
  input   wire   sample_done,
  input   wire   sampled_bit,
  input   wire   stop_chk_en,

  output  logic  stop_err
);

  always_comb begin
    if (sample_done && stop_chk_en) begin
      stop_err  = (sampled_bit == STOP_BIT) ? 1'b0:1'b1;
    end else begin
      stop_err  = 1'b0;
    end
  end
endmodule
