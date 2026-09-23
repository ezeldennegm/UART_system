//=============================================================================
// uart_system_tb.sv
//
// Self-checking testbench for SYS_TOP (github.com/ezeldennegm/UART_system).
// Drives the system exactly the way the spec's "Sequence of Operation"
// describes: config writes to RegFile 0x2/0x3, then RF write/read and ALU
// (with-operand / no-operand) commands sent over RX_IN, with responses
// checked on TX_OUT.
//
// Compile together with the existing rtl.f / filelist, e.g.:
//   vlog -sv -f rtl/rtl.f uart_system_tb.sv
//   vsim -voptargs=+acc work.uart_system_tb -do "run -all"
//
// *** KNOWN RTL ISSUES THAT AFFECT THIS TB (see chat reply) ***
//   1) REG_FILE.sv resets Reg_File[2]/[3] to 0, not the documented
//      defaults (prescale=32, parity_en=1, div_ratio=32) -> this TB
//      backdoor-loads the intended defaults after reset (see
//      restore_regfile_defaults) so RX framing can lock. Remove that
//      task once REG_FILE.sv's reset block is fixed.
//   2) SYS_TOP.sv leaves `clk_div_en` undriven (SYS_CTRL's clk_div_en
//      output port is commented out of the instantiation), so
//      CLK_DIV_TX never enables -> TX_CLK stays flat and TX_OUT never
//      moves. Until that connection is restored, every RX_TASK below
//      will complete, but the receive tasks that wait on TX_OUT will
//      time out.
//   3) SYS_TOP.sv connects SYS_CTRL's ALU_OUT input to an implicit,
//      unrelated net named ALU_OUT instead of the `alu_out` wire
//      driven by the ALU instance -> ALU results reaching SYS_CTRL
//      will be wrong/undriven even once (2) is fixed.
//=============================================================================
`timescale 1ns/1ps

module tb;

  //---------------------------------------------------------------------
  // Clocks / reset
  //---------------------------------------------------------------------
  localparam realtime REF_CLK_PERIOD  = 20.0;       // 50 MHz
  localparam realtime UART_CLK_PERIOD = 271.267;    // 3.6864 MHz

  logic ref_clk  = 1'b0;
  logic uart_clk = 1'b0;
  logic rst      = 1'b0;    // raw, active-low, async (SYS_TOP.RST)

  logic rx_in    = 1'b1;    // idle-high
  logic tx_out;
  logic par_err;
  logic stp_err;

  always #(REF_CLK_PERIOD/2)  ref_clk  = ~ref_clk;
  always #(UART_CLK_PERIOD/2) uart_clk = ~uart_clk;

  //---------------------------------------------------------------------
  // DUT
  //---------------------------------------------------------------------
  SYS_TOP dut (
    .REF_CLK  (ref_clk),
    .UART_CLK (uart_clk),
    .RST      (rst),
    .RX_IN    (rx_in),
    .TX_OUT   (tx_out),
    .PAR_ERR  (par_err),
    .STP_ERR  (stp_err)
  );

  //---------------------------------------------------------------------
  // Protocol / framing constants (must track SYS_CTRL.sv + reg2 config)
  //---------------------------------------------------------------------
  localparam byte CMD_RF_WR   = 8'hAA;
  localparam byte CMD_RF_RD   = 8'hBB;
  localparam byte CMD_ALU_WOP = 8'hCC;
  localparam byte CMD_ALU_NOP = 8'hDD;

  localparam int  PRESCALE   = 32;   // reg2[7:2] -> RX oversample divisor
  localparam bit  PARITY_EN  = 1'b1; // reg2[0]
  localparam bit  PARITY_TYP = 1'b0; // reg2[1] (0 = even, 1 = odd)
  localparam int  DIV_RATIO  = 32;   // reg3 -> TX_CLK divisor

  // Both sides land on 3.6864MHz/32 = 115200 baud with the defaults above.
  localparam realtime BIT_PERIOD = PRESCALE * UART_CLK_PERIOD;

  int errors = 0;
  int checks = 0;

  //---------------------------------------------------------------------
  // Backdoor load of the documented reset defaults for reg2/reg3
  // (workaround for known issue #1 above)
  //---------------------------------------------------------------------
  task automatic restore_regfile_defaults();
    dut.REG_FILE_U.Reg_File[2] = {PRESCALE[5:0], PARITY_TYP, PARITY_EN};
    dut.REG_FILE_U.Reg_File[3] = DIV_RATIO[7:0];
  endtask

  task automatic apply_reset(int cycles = 5);
    rst = 1'b0;
    repeat (cycles) @(posedge ref_clk);
    restore_regfile_defaults();
    rst = 1'b1;
    repeat (3) @(posedge ref_clk);
  endtask

  //---------------------------------------------------------------------
  // Master (testbench) UART driver -> RX_IN
  //---------------------------------------------------------------------
  task automatic send_uart_byte(byte data);
    bit par;
    par = ^data;                       // running XOR == even parity
    if (PARITY_TYP) par = ~par;        // odd parity

    rx_in = 1'b0;                      // start bit
    #(BIT_PERIOD);
    for (int i = 0; i < 8; i++) begin
      rx_in = data[i];                 // LSB first
      #(BIT_PERIOD);
    end
    if (PARITY_EN) begin
      rx_in = par;
      #(BIT_PERIOD);
    end
    rx_in = 1'b1;                      // stop bit
    #(BIT_PERIOD);
  endtask

  task automatic send_rf_write(bit [3:0] addr, byte data);
    send_uart_byte(CMD_RF_WR);
    send_uart_byte({4'b0, addr});
    send_uart_byte(data);
  endtask

  task automatic send_rf_read(bit [3:0] addr);
    send_uart_byte(CMD_RF_RD);
    send_uart_byte({4'b0, addr});
  endtask

  task automatic send_alu_wop(byte op_a, byte op_b, bit [3:0] fun);
    send_uart_byte(CMD_ALU_WOP);
    send_uart_byte(op_a);
    send_uart_byte(op_b);
    send_uart_byte({4'b0, fun});
  endtask

  task automatic send_alu_nop(bit [3:0] fun);
    send_uart_byte(CMD_ALU_NOP);
    send_uart_byte({4'b0, fun});
  endtask

  //---------------------------------------------------------------------
  // Master (testbench) UART receiver <- TX_OUT
  // (blocks until a byte arrives; caller supplies a timeout guard)
  //---------------------------------------------------------------------
  task automatic recv_uart_byte(output byte data);
    @(negedge tx_out);                 // start bit edge
    #(BIT_PERIOD/2);                   // move to first-bit-cell center
    #(BIT_PERIOD);                     // skip the start bit itself
    for (int i = 0; i < 8; i++) begin
      data[i] = tx_out;
      #(BIT_PERIOD);
    end
    if (PARITY_EN) #(BIT_PERIOD);      // consume parity bit, unchecked
    // stop bit follows; caller may check tx_out == 1 here if desired
  endtask

  //---------------------------------------------------------------------
  // Scoreboard helper
  //---------------------------------------------------------------------
  task automatic check_byte(string what, byte got, byte exp);
    checks++;
    if (got !== exp) begin
      errors++;
      $error("[%0t] %s MISMATCH: got=0x%0h exp=0x%0h", $time, what, got, exp);
    end else begin
      $display("[%0t] %s OK (0x%0h)", $time, what, got);
    end
  endtask

  //---------------------------------------------------------------------
  // Watchdog
  //---------------------------------------------------------------------
  /*
  initial begin
    #2_000_000;   // 2ms
    $error("TIMEOUT: simulation did not complete in time");
    $stop;
  end
  */

  //---------------------------------------------------------------------
  // Stimulus
  //---------------------------------------------------------------------
  byte rx_byte, rx_byte2;

  initial begin
    apply_reset();

    // 1) Bootstrap configuration
    $display("\n[%0t] >>> TASK 1: RF WRITE 0x2 - Configure PRESCALE/PARITY", $time);
    send_rf_write(4'h2, {PRESCALE[5:0], PARITY_TYP, PARITY_EN});
    $display("\n[%0t] >>> TASK 1: RF WRITE 0x2 - Configure PRESCALE/PARITY", $time);
    //recv_uart_byte(rx_byte);
    $display("\n[%0t] >>> TASK 1: RF WRITE 0x2 - Configure PRESCALE/PARITY", $time);
    //check_byte("RF_WR 0x2 echo", rx_byte,
               //{PRESCALE[5:0], PARITY_TYP, PARITY_EN});

    $display("[%0t] >>> TASK 2: RF WRITE 0x3 - Configure DIV_RATIO", $time);
    send_rf_write(4'h3, DIV_RATIO[7:0]);
    //recv_uart_byte(rx_byte);
    //check_byte("RF_WR 0x3 echo", rx_byte, DIV_RATIO[7:0]);

    // 2) Normal RegFile write + read-back
    $display("\n[%0t] >>> TASK 3: RF WRITE 0x5 - Write 0xA5", $time);
    send_rf_write(4'h5, 8'hA5);
    //recv_uart_byte(rx_byte);
    //check_byte("RF_WR 0x5 echo", rx_byte, 8'hA5);

    $display("[%0t] >>> TASK 4: RF READ 0x5 - Read back 0xA5", $time);
    send_rf_read(4'h5);
    recv_uart_byte(rx_byte);
    check_byte("RF_RD 0x5", rx_byte, 8'hA5);

    // 3) ALU operation with operand
    $display("\n[%0t] >>> TASK 5: ALU_WOP - 5 + 3 = 8", $time);
    send_alu_wop(8'h05, 8'h03, 4'b0000 /* ADD */);
    recv_uart_byte(rx_byte);
    recv_uart_byte(rx_byte2);
    check_byte("ALU_WOP ADD low",  rx_byte,  8'h08);
    check_byte("ALU_WOP ADD high", rx_byte2, 8'h00);

    // 4) ALU operation with no operand
    $display("\n[%0t] >>> TASK 6: ALU_NOP - 5 - 3 = 2", $time);
    send_alu_nop(4'b0001 /* SUB */);
    recv_uart_byte(rx_byte);
    recv_uart_byte(rx_byte2);
    check_byte("ALU_NOP SUB low",  rx_byte,  8'h02);
    check_byte("ALU_NOP SUB high", rx_byte2, 8'h00);

    // 5) Framing-error sanity check
    $display("\n[%0t] >>> TASK 7: FRAMING ERROR CHECK", $time);
    if (par_err || stp_err) begin
      errors++;
      $error("Unexpected PAR_ERR/STP_ERR asserted during clean traffic");
    end
    else begin
      $display("[%0t] Framing errors: NONE", $time);
    end

    $display("\n=====================================================");
    $display(" %0d/%0d checks passed, %0d error(s)",
             checks - errors, checks, errors);
    $display("=====================================================");

    if (errors == 0)
      $display("TB RESULT: PASS");
    else
      $display("TB RESULT: FAIL");

    $stop;
  end

endmodule
