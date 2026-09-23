
/////////////////////////////////////////////////////////////
/////////////////////// Clock Gating ////////////////////////
/////////////////////////////////////////////////////////////

module CLK_GATE (
input   wire  CLK_EN,
input   wire  CLK,
output        GATED_CLK
);

//internal connections
logic   Latch_Out ;

//latch (Level Sensitive Device)
always_latch begin
  if(!CLK)      // active low
   begin
    Latch_Out <= CLK_EN ;
   end
 end

// ANDING
assign  GATED_CLK = CLK && Latch_Out ;

endmodule
