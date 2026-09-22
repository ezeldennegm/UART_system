module ADDR_PTR_CTRL #(
  parameter MODE        = "WRITE",
  parameter ADDR_WIDTH  = 8
) (
  input   wire                     clk,
  input   wire                     a_rst_n,
  input   wire                     inc,

  input   wire  [ADDR_WIDTH   :0]  xq_ptr,     // other side's ptr

  output  wire                     ctrl_flag,  // empty for READ, full for WRITE

  output  wire  [ADDR_WIDTH -1:0]  addr,
  output  wire  [ADDR_WIDTH   :0]  ptr

);
  logic [ADDR_WIDTH:0] binary_ptr;

  assign  addr  = binary_ptr[ADDR_WIDTH-1:0];

  always_ff @(posedge  clk, negedge  a_rst_n) begin
    if (!a_rst_n) begin
      binary_ptr  <=  'b0;
    end else if (inc && !ctrl_flag) begin
      binary_ptr  <=  binary_ptr + 'b1;
    end
  end

  generate;
    if (MODE == "WRITE") begin : gen_write
      assign  ctrl_flag = (ptr[ADDR_WIDTH]        != xq_ptr[ADDR_WIDTH]       )&
                          (ptr[ADDR_WIDTH - 1]    != xq_ptr[ADDR_WIDTH - 1]   )&
                          (ptr[ADDR_WIDTH - 2:0]  == xq_ptr[ADDR_WIDTH - 2:0] );

      BINARY_TO_GRAY #(
        .DATA_WIDTH(ADDR_WIDTH + 1)
      )B2G_WRITE_U0 (
        .data_in(binary_ptr),
        .data_out(ptr)
      );
    end
    else if (MODE == "READ") begin : gen_read
      assign  ctrl_flag = (ptr == xq_ptr);

      BINARY_TO_GRAY #(
        .DATA_WIDTH(ADDR_WIDTH + 1)
      )B2G_READ_U0 (
        .data_in(binary_ptr),
        .data_out(ptr)
      );
    end
  endgenerate



endmodule
