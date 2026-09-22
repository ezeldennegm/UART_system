module UART_RX_FSM #(
  parameter START_BIT     = 1,
  parameter PARITY_ENABLE = 1
)(
  input   wire   clk,
  input   wire   rst_n,

  input   wire   parity_enable,

  input   wire   rx_in,

  input   wire   bit_done,

  input   wire   deser_done,

  input   wire   start_glitch,
  input   wire   parity_err,
  input   wire   stop_err,
  input   wire   sample_done,


  output  logic  edge_bit_en,

  output  logic  deser_en,
  output  logic  start_chk_en,
  output  logic  parity_chk_en,
  output  logic  stop_chk_en,

  output  logic  parity_error,
  output  logic  stop_error,

  output  logic  data_valid
);
  //
  // FSM states
    typedef enum logic [2:0] {
    IDLE    = 3'b000,
    START   = 3'b001,
    DATA    = 3'b011,
    PARITY  = 3'b010,
    STOP    = 3'b110
  } state_e;

  // FSM SIGNALS
  state_e cu_s, nx_s;

  // STATE TRANSITION
  always_ff @(posedge clk, negedge rst_n) begin
    if (!rst_n) begin
      cu_s  <=  IDLE;
    end else if (cu_s  ==  IDLE && rx_in == START_BIT) begin
      cu_s  <=  START;
    end else if (cu_s ==  START && start_glitch) begin
      cu_s  <=  IDLE;
    end else if (bit_done) begin
      cu_s  <=  nx_s;
    end
  end

  // nx_s logic
  always_comb begin
    case (cu_s)
      /*IDLE: begin
        if (rx_in == START_BIT) begin
          nx_s = START;
        end else begin
          nx_s = IDLE;
        end
      end*/
      START: begin
        nx_s  = DATA;
      end
      DATA: begin
        if (deser_done) begin
          if (parity_enable == PARITY_ENABLE) begin
            nx_s  = PARITY;
          end else begin
            nx_s  = STOP;
          end
        end else begin
          nx_s  = DATA;
        end
      end
      PARITY: nx_s  = STOP;
      STOP: begin
        nx_s = IDLE;
      end
      default: nx_s = IDLE;
    endcase
  end

  // edge_bit_en
  always_comb begin
    case (cu_s)
      IDLE: edge_bit_en  = 1'b0;
      default: edge_bit_en  = 1'b1;
    endcase
  end

  // deser_en
  always_comb begin
    case (cu_s)
      DATA: deser_en  = 1'b1;
      default: deser_en  = 1'b0;
    endcase
  end

  // start_chk_en
  always_comb begin
    case (cu_s)
      START: start_chk_en = 1'b1;
      default: start_chk_en = 1'b0;
    endcase
  end

  // stop_chk_en
  always_comb begin
    case (cu_s)
      STOP: stop_chk_en = 1'b1;
      default: stop_chk_en = 1'b0;
    endcase
  end

  // parity_chk_en
  always_comb begin
    case (cu_s)
      PARITY: parity_chk_en = 1'b1;
      default: parity_chk_en = 1'b0;
    endcase
  end

  // parity_error
  always_ff @(posedge clk, negedge rst_n) begin
    if (!rst_n) begin
      parity_error  <=  1'b0;
    end else if (sample_done) begin
      case (cu_s)
        START:  parity_error  <=  1'b0;
        PARITY: parity_error  <=  parity_err;
      endcase
    end
  end

  // stop_error
  always_ff @(posedge clk, negedge rst_n) begin
    if (!rst_n) begin
      stop_error  <=  1'b0;
    end else if (sample_done) begin
      case (cu_s)
        START:  stop_error  <=  1'b0;
        STOP:   stop_error  <=  stop_err;
      endcase
    end
  end

  // data_valid
  always_ff @(posedge clk, negedge rst_n) begin
    if (!rst_n) begin
      data_valid  <=  1'b0;
    end else if (sample_done) begin
      case (cu_s)
        START:  data_valid  <=  1'b0;
        STOP:   data_valid  <=  (!stop_err & !parity_error);
      endcase
    end
  end

endmodule
