module DESERIALIZER(
  input   wire          clk,
  input   wire          rst_n,

  input   wire          deser_en,
  input   wire          sample_done,
  input   wire          sampled_bit,

  output  logic         deser_done,

  output  logic  [7:0]  p_data
);
  logic [3:0] parallel_data_counter;

  // paraller_data_counter
  always_ff @(posedge clk, negedge rst_n) begin
    if (!rst_n) begin
      parallel_data_counter <=  4'b0;
    end else if (!deser_en) begin
      parallel_data_counter <=  4'b0;
    end else if (sample_done) begin
      parallel_data_counter <=  parallel_data_counter + 1'b1;
    end
  end

  // p_data
  always_ff @(posedge clk, negedge rst_n) begin
    if (!rst_n) begin
      p_data  <=  8'b0;
    end else if (sample_done && deser_en) begin
      p_data  <=  {sampled_bit,p_data[7:1]};
    end
  end

  // deser_done
  always_ff @(posedge clk, negedge rst_n) begin
    if (!rst_n) begin
      deser_done  <=  1'b0;
    end else if (deser_en) begin
      if (parallel_data_counter == 4'b1000) begin
        deser_done  <=  1'b1;
      end
    end else begin
      deser_done  <=  1'b0;
    end
  end

endmodule
