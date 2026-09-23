module UART_TX_MUX#(
  parameter STOP_BIT = 1,
  parameter START_BIT = 0
)(
  input   wire   [1:0]  mux_sel,
  input   wire          serial_out,
  input   wire          parity_out,
  output  logic         TX_out
);
  always_comb begin
    case (mux_sel)
      2'b00:  TX_out  = START_BIT; // START bit
      2'b01:  TX_out  = serial_out;// serial_out
      2'b11:  TX_out  = parity_out;
      2'b10:  TX_out  = STOP_BIT;
    endcase
  end
endmodule
