module BINARY_TO_GRAY #(
  parameter DATA_WIDTH  = 8
) (
  input   wire  [DATA_WIDTH-1:0]  data_in,

  output  wire  [DATA_WIDTH-1:0]  data_out
);

  assign data_out = data_in ^ {1'b0,data_in[DATA_WIDTH-1:1]};

endmodule
