module SAMPLER(
  input   wire          clk,
  input   wire          rst_n,

  input   wire   [5:0]  prescale,
  input   wire          rx_in,

  input   wire          edge_bit_en,
  input   wire   [5:0]  edge_cnt,

  output  logic         sampled_bit,
  output  logic         sample_done
);
  logic first_bit, middle_bit;

  wire  [5:0] divided_prescale;
  wire        large_prescale; // prescale >= 8

  assign divided_prescale = {1'b0,prescale[5:1]};

  assign large_prescale = |prescale[5:3];

  // first_bit
  always_ff @(posedge clk, negedge rst_n) begin
    if (!rst_n) begin
      first_bit   <=  0;
    end else if (edge_bit_en && large_prescale) begin
      if (edge_cnt == (divided_prescale - 6'b1)) begin
        first_bit   <=  rx_in;
      end
    end
  end

  // middle_bit
  always_ff @(posedge clk, negedge rst_n) begin
    if (!rst_n) begin
      middle_bit  <=  0;
    end else if (edge_bit_en) begin
      if (edge_cnt == (divided_prescale)) begin
        middle_bit  <=  rx_in;
      end
    end
  end

  // sampled_bit
  always_ff @(posedge clk, negedge rst_n) begin
    if (!rst_n) begin
      sampled_bit <=  1'b0;
    end else if (large_prescale) begin
      if (edge_cnt == (divided_prescale + 6'b1)) begin
        sampled_bit <=  (first_bit & rx_in) | (first_bit & middle_bit) | (middle_bit & rx_in);
      end
    end else if (edge_cnt == (divided_prescale)) begin
        sampled_bit <=  rx_in;
    end
  end

  // sample_done
  always_ff @(posedge clk, negedge rst_n) begin
    if (!rst_n) begin
      sample_done <=  1'b0;
    end else if (large_prescale) begin
      if (edge_cnt == (divided_prescale + 6'b1)) begin
        sample_done <=  1'b1;
      end else begin
        sample_done <=  1'b0;
      end
    end else if (edge_cnt == (divided_prescale)) begin
      sample_done <=  1'b1;
    end else begin
      sample_done <=  1'b0;
    end
  end
endmodule
