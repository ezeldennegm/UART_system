module ASYNC_FIFO #(
  DATA_WIDTH  = 8,
  FIFO_DEPTH  = 8
) (
  input   wire                     w_clk,
  input   wire                     w_a_rst_n,
  input   wire                     w_inc,

  input   wire   [DATA_WIDTH-1:0]  wr_data,

  input   wire                     r_clk,
  input   wire                     r_a_rst_n,
  input   wire                     r_inc,

  output  logic  [DATA_WIDTH-1:0]  rd_data,

  output  wire                     empty,
  output  wire                     full
);
  localparam ADDR_WIDTH = $clog2(FIFO_DEPTH);

  wire  [ADDR_WIDTH- 1:0] w_addr, r_addr;
  wire  [ADDR_WIDTH   :0] w_ptr,  r_ptr ;
  wire  [ADDR_WIDTH   :0] w2r_ptr,r2w_ptr ;

  wire w_clk_en = ( w_inc &&  !full);

  FIFO_MEM #(
    .DATA_WIDTH(DATA_WIDTH),
    .FIFO_DEPTH(FIFO_DEPTH),
    .ADDR_WIDTH(ADDR_WIDTH)
  ) FIFO_MEM_U0 (
    .clk(w_clk),
    .wr_en(w_clk_en),
    .wr_addr(w_addr),
    .rd_addr(r_addr),
    .data_in(wr_data),
    .data_out(rd_data)
  );

  ADDR_PTR_CTRL #(
    .MODE("WRITE"),
    .ADDR_WIDTH(ADDR_WIDTH)
  ) FIFO_WRITE (
    .clk(w_clk),
    .a_rst_n(w_a_rst_n),
    .inc(w_inc),
    .xq_ptr(r2w_ptr),
    .ctrl_flag(full),
    .addr(w_addr),
    .ptr(w_ptr)
  );

  DF_SYNC #(
    .DATA_WIDTH(ADDR_WIDTH+1)
  ) DF_SYNC_R2W (
    .clk(w_clk),
    .a_rst_n(w_a_rst_n),
    .data_in(r_ptr),
    .data_out(r2w_ptr)
  );

  ADDR_PTR_CTRL #(
    .MODE("READ"),
    .ADDR_WIDTH(ADDR_WIDTH)
  ) FIFO_READ (
    .clk(r_clk),
    .a_rst_n(r_a_rst_n),
    .inc(r_inc),
    .xq_ptr(w2r_ptr),
    .ctrl_flag(empty),
    .addr(r_addr),
    .ptr(r_ptr)
  );

  DF_SYNC #(
    .DATA_WIDTH(ADDR_WIDTH+1)
  ) DF_SYNC_W2R (
    .clk(r_clk),
    .a_rst_n(r_a_rst_n),
    .data_in(w_ptr),
    .data_out(w2r_ptr)
  );
endmodule
