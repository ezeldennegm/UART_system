module UART_RX_TOP #(
  parameter START_BIT       = 0,
  parameter STOP_BIT        = 1,
  parameter EVEN_PARITY     = 0,
  parameter ODD_PARITY      = 1,
  parameter PARITY_ENABLE   = 1,
  parameter PARITY_DISABLE  = 0
) (
  input   wire         clk,
  input   wire         rst_n,

  input   wire  [5:0]  prescale,
  input   wire         parity_enable,
  input   wire         parity_type,

  input   wire         rx_in,

  output  wire  [7:0]  p_data,

  output  wire         data_valid,

  output  wire         stop_error,
  output  wire         parity_error
);
  // bit_cnt , bit_done
  wire        bit_done;
  // edge_cnt
  wire  [5:0] edge_cnt;
  // deser_done , deser_en
  wire        deser_done, deser_en;

  // edge_bit_en
  wire        edge_bit_en;

  // start_chk_en , stop_chk_en , parity_chk_en
  wire        start_chk_en, stop_chk_en, parity_chk_en;

  // start_glitch , parity_err , stop_err
  wire        start_glitch, parity_err, stop_err;

  // sample_done , sampled_bit
  wire        sample_done, sampled_bit;

  // parity_calc   // calculated parity
  wire        parity_calc;

  UART_RX_FSM #(
    .START_BIT(START_BIT),
    .PARITY_ENABLE(PARITY_ENABLE)
  ) UART_RX_FSM_U0 (
    .clk(clk),
    .rst_n(rst_n),
    .parity_enable(parity_enable),
    .rx_in(rx_in),
    .bit_done(bit_done),
    .deser_done(deser_done),
    .start_glitch(start_glitch),
    .parity_err(parity_err),
    .stop_err(stop_err),
    .sample_done(sample_done),
    .edge_bit_en(edge_bit_en),
    .deser_en(deser_en),
    .start_chk_en(start_chk_en),
    .parity_chk_en(parity_chk_en),
    .stop_chk_en(stop_chk_en),
    .parity_error(parity_error),
    .stop_error(stop_error),
    .data_valid(data_valid)
  );

  EDGE_BIT_CNTR EDGE_BIT_CNTR_U0 (
    .clk(clk),
    .rst_n(rst_n),
    .enable(edge_bit_en),
    .prescale(prescale),
    .edge_cnt(edge_cnt),
    .bit_done(bit_done)
  );

  SAMPLER SAMPLER_U0 (
    .clk(clk),
    .rst_n(rst_n),
    .prescale(prescale),
    .rx_in(rx_in),
    .edge_bit_en(edge_bit_en),
    .edge_cnt(edge_cnt),
    .sampled_bit(sampled_bit),
    .sample_done(sample_done)
  );

  DESERIALIZER DESERIALIZER_U0 (
    .clk(clk),
    .rst_n(rst_n),
    .deser_en(deser_en),
    .sample_done(sample_done),
    .sampled_bit(sampled_bit),
    .deser_done(deser_done),
    .p_data(p_data)
  );

  SERIAL_PARITY #(
    .ODD_PARITY(ODD_PARITY),
    .EVEN_PARITY(EVEN_PARITY)
  ) SERIAL_PARITY_U0 (
    .clk(clk),
    .rst_n(rst_n),
    .parity_type(parity_type),
    .serial_in(sampled_bit),
    .serial_enable(deser_en),
    .parity_chk_en(parity_chk_en),
    .sample_done(sample_done),
    .parity_out(parity_calc)
  );

  PARITY_CHK PARITY_CHK_U0 (
    .sample_done(sample_done),
    .sampled_bit(sampled_bit),
    .parity_calc(parity_calc),
    .parity_chk_en(parity_chk_en),
    .parity_err(parity_err)
  );

  START_CHK #(
    .START_BIT(START_BIT)
  ) START_CHK_U0 (
    .sample_done(sample_done),
    .sampled_bit(sampled_bit),
    .start_chk_en(start_chk_en),
    .start_glitch(start_glitch)
  );

  STOP_CHK #(
    .STOP_BIT(STOP_BIT)
  ) STOP_CHK_U0 (
    .sample_done(sample_done),
    .sampled_bit(sampled_bit),
    .stop_chk_en(stop_chk_en),
    .stop_err(stop_err)
  );
endmodule
