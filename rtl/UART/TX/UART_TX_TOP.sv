module UART_TX_TOP#(
  parameter START_BIT       = 0,
  parameter STOP_BIT        = 1,
  parameter ODD_PARITY      = 1,
  parameter EVEN_PARITY     = 0,
  parameter ENABLE_PARITY   = 1,
  parameter DISABLE_PARITY  = 0
)(
  input   wire         clk,
  input   wire         rst_n,          // sync active low reset
  input   wire  [7:0]  p_data,
  input   wire         parity_enable,
  input   wire         parity_type,
  input   wire         data_valid,
  output  wire         busy,
  output  wire         TX_out
);
  // wire between FSM SERIALIZER
  wire  serial_enable, serial_done;

  // wire between SERIALIZER SERIAL_PARITY MUX
  wire  serial_out, parity_out;

  // wire between FSM MUX
  wire  [1:0] mux_sel;

  // FSM // control unit
  UART_TX_FSM #(
    .ENABLE_PARITY(ENABLE_PARITY),
    .DISABLE_PARITY(DISABLE_PARITY)
  )UART_TX_FSM_U (
    .clk(clk),
    .rst_n(rst_n),
    .data_valid(data_valid),
    .parity_enable(parity_enable),
    .serial_done(serial_done),
    .mux_sel(mux_sel),
    .serial_enable(serial_enable),
    .busy(busy)
  );

  // SERIALIZER
  SERIALIZER UART_TX_SERIALIZER_U (
    .clk(clk),
    .rst_n(rst_n),
    .p_data(p_data),
    .serial_enable(serial_enable),
    .busy(busy),
    .data_valid(data_valid),
    .serial_out(serial_out),
    .serial_done(serial_done)
  );

  // SERIAL_PARITY
  SERIAL_PARITY_TX #(
    .ODD_PARITY(ODD_PARITY),
    .EVEN_PARITY(EVEN_PARITY)
  )UART_TX_PARITY_U (
    .clk(clk),
    .rst_n(rst_n),
    .parity_type(parity_type),
    .serial_in(serial_out),
    .serial_enable(serial_enable),
    .busy(busy),
    .data_valid(data_valid),
    .parity_out(parity_out)
  );

  // MUX
  UART_TX_MUX #(
    .START_BIT(START_BIT),
    .STOP_BIT(STOP_BIT)
  )UART_TX_MUX_U (
    .mux_sel(mux_sel),
    .serial_out(serial_out),
    .parity_out(parity_out),
    .TX_out(TX_out)
  );
endmodule
