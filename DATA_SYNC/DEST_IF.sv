module DEST_IF #(
  parameter   BUS_WIDTH = 8
) (
  input   wire                    clk,
  input   wire                    a_rst_n,      // async active low reset

  input   wire   [BUS_WIDTH-1:0]  unsync_bus,
  input   wire                    pulse_in,

  output  logic  [BUS_WIDTH-1:0]  sync_bus,
  output  logic                   enable_pulse
);

  always_ff @(posedge clk, negedge a_rst_n) begin
    if (!a_rst_n) begin
      sync_bus  <=  'b0;
    end else if (pulse_in) begin
      sync_bus  <=  unsync_bus;
    end
  end

  always_ff @(posedge clk, negedge a_rst_n) begin
    if (!a_rst_n) begin
      enable_pulse  <=  'b0;
    end else begin
      enable_pulse  <=  pulse_in;
    end
  end
endmodule
