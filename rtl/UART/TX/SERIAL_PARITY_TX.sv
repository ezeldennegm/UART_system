module SERIAL_PARITY_TX#(
  parameter ODD_PARITY = 1,
  parameter EVEN_PARITY = 0
)( // same cycle parity as first output same cycle SERIALIZER
  input   wire  clk,
  input   wire  rst_n,
  input   wire  parity_type, // 1 for odd, 0 for even
  input   wire  serial_in, // serial input, will be reused in rx
  input   wire  serial_enable,
  input   wire  busy,
  input   wire  data_valid,
  output  wire  parity_out
);
  //parity_type_ct
  reg parity_type_ct;

  // odd and even parity
  reg parity_even;
  wire parity_odd;

  assign parity_odd = ~parity_even;

  assign parity_out = (parity_type_ct == ODD_PARITY)? parity_odd : parity_even;

  //pragma sync_set_reset rst_n
  always @(posedge clk, negedge rst_n) begin
    if (!rst_n) begin
      parity_even <= 1'b0;
    end else begin if (!serial_enable) begin
      parity_even <= 1'b0;
    end else begin
      parity_even <= serial_in ^ parity_even;
    end
    end
  end

  always @(posedge clk, negedge rst_n) begin
    if (!rst_n) begin
      parity_type_ct <= 1'b0;
    end else if (!busy && data_valid) begin
      parity_type_ct <= parity_type;
    end
  end
endmodule
