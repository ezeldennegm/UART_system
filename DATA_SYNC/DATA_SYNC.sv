module DATA_SYNC #(
  parameter   NUM_STAGES  = 2,
  parameter   BUS_WIDTH   = 8
) (
  input   wire                    clk,
  input   wire                    a_rst_n,      // async active low reset

  input   wire   [BUS_WIDTH-1:0]  unsync_bus,
  input   wire                    bus_enable,

  output  logic  [BUS_WIDTH-1:0]  sync_bus,
  output  logic                   enable_pulse
);
  //  bus_enable_sync   //  control signal out of MULTI_FLOP
  wire  bus_enable_sync;

  //  bus_enable_pulse  //  control signal out of PULSE_GEN
  wire  bus_enable_pulse;

  MULTI_FLOP #(
    .NUM_STAGES()
  ) MULTI_FLOP_U0 (
    .clk(clk),
    .a_rst_n(a_rst_n),
    .async_ctrl_signal(bus_enable),
    .sync_ctrl_signal(bus_enable_sync)
  );

  PULSE_GEN PULSE_GEN_U0 (
    .clk(clk),
    .a_rst_n(a_rst_n),
    .pulse_in(bus_enable_sync),
    .pulse_out(bus_enable_pulse)
  );

  DEST_IF #(
    .BUS_WIDTH()
  ) DEST_IF_U0 (
    .clk(clk),
    .a_rst_n(a_rst_n),
    .unsync_bus(unsync_bus),
    .pulse_in(bus_enable_pulse),
    .sync_bus(sync_bus),
    .enable_pulse(enable_pulse)
  );
endmodule
