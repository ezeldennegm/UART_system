module SERIAL_PARITY#(
  parameter ODD_PARITY = 1,
  parameter EVEN_PARITY = 0
)( // same cycle parity as first output same cycle SERIALIZER
  input   wire  clk,
  input   wire  rst_n,
  input   wire  parity_type,    // 1 for odd, 0 for even
  input   wire  serial_in,      // serial input, will be reused in rx
  input   wire  serial_enable,
  input   wire  parity_chk_en,
  input   wire  sample_done,
  output  wire  parity_out
);

  // odd and even parity
  logic parity_even;
  wire parity_odd;

  assign parity_odd = ~parity_even;

  assign parity_out = (parity_type == ODD_PARITY)? parity_odd : parity_even;

  always_ff @(posedge clk, negedge rst_n) begin
    if (!rst_n) begin
      parity_even <= 1'b0;
    end else begin if (!serial_enable && !parity_chk_en) begin
      parity_even <= 1'b0;
    end else if (sample_done) begin
      parity_even <= serial_in ^ parity_even;
    end
    end
  end

endmodule
