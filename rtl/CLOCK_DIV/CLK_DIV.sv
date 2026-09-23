module CLK_DIV #(

) (
  input   wire         i_ref_clk,
  input   wire         i_rst_n,
  input   wire         i_clk_en,
  input   wire  [7:0]  i_div_ratio,

  output  wire         o_div_clk
);
  logic clk_div_reg;

  wire  clk_div_en  = i_clk_en && (i_div_ratio != 1'b0) && (i_div_ratio != 1'b1);
  wire  err_ratio   = i_clk_en && !clk_div_en;   // meant for div_ratio 0,1

  assign o_div_clk = (clk_div_en) ? clk_div_reg: i_ref_clk;

  wire  [6:0] half    = i_div_ratio[7:1];
  wire  [6:0] half_p1 = half  + 1'b1;

  wire  odd     = i_div_ratio[0];
  logic odd_flag;

  logic [6:0] clk_counter;

  always_ff @(posedge i_ref_clk, negedge i_rst_n) begin
    if (!i_rst_n) begin
      clk_div_reg   <=  1'b0;
      clk_counter <=  7'b1;
      odd_flag    <=  1'b0;
    end else if (clk_div_en) begin
      if ((clk_counter  ==  half) && !odd) begin
        clk_div_reg   <=  ~clk_div_reg;
        clk_counter <=  7'b1;
      end else if (((clk_counter  ==  half) && odd && odd_flag) || ((clk_counter  ==  half_p1) && odd && !odd_flag)) begin
        clk_div_reg   <=  ~clk_div_reg;
        clk_counter <=  7'b1;
        odd_flag    <=  ~odd_flag;
      end else begin
        clk_counter <=  clk_counter + 1'b1;
      end
    end
  end
endmodule
