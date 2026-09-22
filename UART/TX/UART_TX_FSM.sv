module UART_TX_FSM#(
  parameter ENABLE_PARITY = 1,
  parameter DISABLE_PARITY = 0
)(
  input   wire          clk,
  input   wire          rst_n,          // Active Low synchronous reset
  input   wire          data_valid,
  input   wire          parity_enable,
  input   wire          serial_done,
  output  logic  [1:0]  mux_sel,
  // 2'b00 -> START bit, 2'b10 -> STOP bit, 2'b01->  serial_out, 2'b11 -> PARITY bit
  output  logic  serial_enable,
  output  logic  busy
);
  // busy_comb
  logic busy_comb;
  // parity_enable for current transmission
  logic parity_enable_ct;
  //FSM STATES
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
    end else begin
      cu_s  <=  nx_s;
    end
  end

  // NEXT STATE LOGIC
  always_comb begin
    case (cu_s)
      IDLE:   begin
        if (data_valid) begin
          nx_s  =   START;
        end else begin
          nx_s  =   IDLE;
        end
      end
      START:  begin
        nx_s  =   DATA;
      end
      DATA:   begin
        if (serial_done) begin
          if (parity_enable_ct == ENABLE_PARITY) begin
            nx_s  =   PARITY;
          end else begin
            nx_s  =   STOP;
          end
        end else begin
          nx_s  =   DATA;
        end
      end
      PARITY: begin
        nx_s  =   STOP;
      end
      STOP:   begin
        nx_s  =   IDLE;
      end
      default:  begin
        nx_s  =   IDLE;
      end
    endcase
  end

  // STATE output
  // busy_comb logic // makes it mealy
  always_comb begin
    case (cu_s)
      IDLE: begin
        if (data_valid) begin
          busy_comb = 1'b1;
        end else begin
          busy_comb = 1'b0;
        end
      end
      START:  busy_comb  = 1'b1;
      DATA:   busy_comb  = 1'b1;
      PARITY: busy_comb  = 1'b1;
      STOP:   busy_comb  = 1'b0;
      default:busy_comb  = 1'b0;
    endcase
  end
  // mux_sel
  always_comb begin
    case (cu_s)
      IDLE:   mux_sel =   2'b01; // STOP bit is high and that is what we need at IDLE
      START:  mux_sel =   2'b00;
      DATA:   mux_sel =   2'b01;
      PARITY: mux_sel =   2'b11;
      STOP:   mux_sel =   2'b10;
      default:mux_sel =   2'b10;
    endcase
  end

  // serial_enable
  always_comb begin
    case (cu_s)
      DATA:     serial_enable = 1;
      default:  serial_enable = 0;
    endcase
  end

  always_ff @(posedge clk, negedge rst_n) begin
    if (!rst_n) begin
      parity_enable_ct  <=  0;
    end else if (!busy && data_valid) begin
      parity_enable_ct  <=  parity_enable;
    end
  end

  always_ff @(posedge clk, negedge rst_n) begin
    if (!rst_n) begin
      busy  <=  1'b0;
    end else begin
      busy  <=  busy_comb;
    end
  end
endmodule
