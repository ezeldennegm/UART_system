module SERIALIZER(  // same cycle SERIALIZER
  input   wire         clk,
  input   wire         rst_n,
  input   wire  [7:0]  p_data,
  input   wire         serial_enable,
  input   wire         busy,
  input   wire         data_valid,
  output  wire         serial_out,
  output  wire         serial_done
);
  logic [7:0] loaded_data;
  logic [3:0] counter;
  wire count_max;
  assign serial_done =  (counter == 4'b0111);
  assign count_max =    (counter == 4'b1000);
  // counter
  always_ff @(posedge clk, negedge rst_n) begin
    if (!rst_n) begin
      counter <=  4'b1000;
    end else if (!serial_enable) begin
      counter <=  4'b0000;
    end else if (!count_max) begin
      counter <=  counter + 1;
    end
  end

  always_ff @(posedge clk, negedge rst_n) begin
    if (!rst_n) begin
      loaded_data <=  8'b0;
    end else if (!busy && data_valid) begin
      loaded_data <=  p_data;
    end else if(serial_enable) begin
      loaded_data <=  loaded_data>>1;
    end
  end


  assign serial_out = (serial_enable)  ? loaded_data[0] :1'b1; //high when IDLE

endmodule
