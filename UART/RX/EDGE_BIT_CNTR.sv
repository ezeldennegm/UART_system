module EDGE_BIT_CNTR(
  input   wire          clk,
  input   wire          rst_n,
  input   wire          enable,
  input   wire   [5:0]  prescale,  //4, 8, 16, 32
  output  logic  [5:0]  edge_cnt,  //0 to 31
  output  logic         bit_done
);
  // bit_cnt
  logic [5:0] bit_cnt;
  //bit_done
  assign bit_done = ((bit_cnt == 0) && (edge_cnt == prescale - 1'b1)) ? 1'b1
                  : (edge_cnt == prescale) ? 1'b1 : 1'b0;

  //bit_cnt
  always_ff @(posedge clk, negedge rst_n) begin
    if (!rst_n) begin
      bit_cnt <= 4'b0;
    end else if (!enable) begin
      bit_cnt <= 4'b0;
    end else if (bit_done) begin
      bit_cnt <= bit_cnt + 1'b1;
    end
  end

  //edge_cnt
  always_ff @(posedge clk, negedge rst_n) begin
    if (!rst_n) begin
      edge_cnt <= 6'b1;
    end else if (bit_done) begin
      edge_cnt <=  6'b1;
    end else if (enable) begin
      edge_cnt <= edge_cnt + 1'b1;
    end else begin
      edge_cnt <=  6'b1;
    end
  end

endmodule
