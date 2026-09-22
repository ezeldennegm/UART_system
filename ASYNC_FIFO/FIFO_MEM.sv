module FIFO_MEM #(
  parameter DATA_WIDTH  = 8,
  parameter FIFO_DEPTH  = 8,
  parameter ADDR_WIDTH  = 3
) (
  input   wire                    clk,
  input   wire                    wr_en,

  input   wire  [ADDR_WIDTH-1:0]  wr_addr,
  input   wire  [ADDR_WIDTH-1:0]  rd_addr,

  input   wire  [DATA_WIDTH-1:0]  data_in,

  output  wire  [DATA_WIDTH-1:0]  data_out

);
  logic [DATA_WIDTH-1:0] FIFO [FIFO_DEPTH];

  always_ff @(posedge clk) begin
    if (wr_en) begin
      FIFO[wr_addr] <=  data_in;
    end
  end

  assign data_out = FIFO[rd_addr];
endmodule
