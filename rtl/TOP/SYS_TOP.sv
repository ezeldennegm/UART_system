module SYS_TOP (
    input  logic REF_CLK,
    input  logic UART_CLK,
    input  logic RST,          // raw, active-low, async

    input  logic RX_IN,
    output logic TX_OUT,

    output logic PAR_ERR,
    output logic STP_ERR
);

    //--------------------------------------------------------------------
    // Reset synchronizers (one per clock domain that's actually used)
    //--------------------------------------------------------------------
    logic rst_n_ref, rst_n_uart;

    RST_SYNC #(.NUM_STAGES(2)) RST_SYNC_REF (
        .a_rst_n    (RST),
        .clk        (REF_CLK),
        .sync_rst_n (rst_n_ref)
    );

    RST_SYNC #(.NUM_STAGES(2)) RST_SYNC_UART (
        .a_rst_n    (RST),
        .clk        (UART_CLK),
        .sync_rst_n (rst_n_uart)
    );

    //--------------------------------------------------------------------
    // RegFile  (16 x 8b, single read port -- see SYS_CTRL.sv notes)
    //--------------------------------------------------------------------
    logic       reg2, reg3;
    logic [5:0] uart_prescale;
    logic       uart_par_en, uart_par_typ;

    assign {uart_prescale,parity_type,parity_enable} = reg2;

    logic [3:0] rf_addr;
    logic       rf_wren, rf_rden;
    logic [7:0] rf_wrdata, rf_rddata;

    logic [7:0]  alu_a, alu_b;


    REG_FILE REG_FILE_U (
        .CLK     (REF_CLK),
        .RST     (rst_n_ref),
        .RdEn    (rf_rden),
        .WrEn    (rf_wren),
        .Address (rf_addr),
        .WrData  (rf_wrdata),
        .RdData  (rf_rddata),
        .reg0    (alu_a),
        .reg1    (alu_b),
        .reg2    (reg2),
        .reg3    (reg3)
    );

    //--------------------------------------------------------------------
    // ALU + its clock gate (ALU has no RST/Enable/Valid of its own --
    // CLK_GATE is the "enable": ALU_OUT registers on the cycle CLK_EN
    // is asserted, every other cycle its clock is simply held. ALU is
    // still 16-bit -- width mismatch vs the 8-bit RegFile is bridged
    // inside SYS_CTRL, not here.)
    //--------------------------------------------------------------------
    logic        alu_clk_en;
    logic        alu_gated_clk;
    logic [15:0] alu_out;
    logic [3:0]  alu_fun;

    CLK_GATE CLK_GATE_U (
        .CLK_EN    (alu_clk_en),
        .CLK       (REF_CLK),
        .GATED_CLK (alu_gated_clk)
    );

    ALU ALU_U (
        .A          (alu_a),
        .B          (alu_b),
        .ALU_FUN    (alu_fun),
        .CLK        (alu_gated_clk),
        .ALU_OUT    (alu_out)
    );

    //--------------------------------------------------------------------
    // UART RX -> Data_Sync (UART_CLK domain -> REF_CLK domain) -> SYS_CTRL
    //--------------------------------------------------------------------
    logic [7:0] rx_out_p, rx_p_data;
    logic       rx_out_v, rx_d_vld;

    DATA_SYNC #(.NUM_STAGES(2), .BUS_WIDTH(8)) DATA_SYNC_U (
        .clk          (REF_CLK),
        .a_rst_n      (rst_n_ref),
        .unsync_bus   (rx_out_p),
        .bus_enable   (rx_out_v),
        .sync_bus     (rx_p_data),
        .enable_pulse (rx_d_vld)
    );

    //--------------------------------------------------------------------
    // SYS_CTRL -> ASYNC_FIFO (write side, REF_CLK domain)
    //--------------------------------------------------------------------
    logic [7:0] fifo_wr_data, fifo_rd_data;
    logic       fifo_w_inc, fifo_full, fifo_empty;

    logic       clk_div_en;

  SYS_CTRL #(
      .ADDR_WIDTH(),
      .FRAME_WIDTH(),
      .ALU_WIDTH(),
      .ALU_FUN_WIDTH()
    ) SYS_CTRL (
      .CLK(REF_CLK),
      .RST(rst_n_ref),
      .ALU_FUN(alu_fun),
      .CLK_EN(alu_clk_en),
      .ALU_OUT(ALU_OUT),
      .Address(rf_addr),
      .WrEn(rf_wren),
      .RdEn(rf_rden),
      .WrData(rf_wrdata),
      .RdData(rf_rddata),
      /*
      .reg0(),
      .reg1(),
      .reg2(),
      .reg3(),
      */
      .RX_P_DATA(rx_out_p),
      .RX_D_VLD(rx_out_v),
      .TX_P_DATA(fifo_wr_data),
      .TX_D_VLD(fifo_w_inc),
      .FIFO_FULL(fifo_full)
      /*
      .uart_prescale(),
      .uart_par_en(),
      .uart_par_typ(),
      .div_ratio(),
      .clk_div_en()
      */
    );

    //--------------------------------------------------------------------
    // Clock divider: TX_CLK only (see deviation note 1 above)
    //--------------------------------------------------------------------
    logic TX_CLK;

    CLK_DIV CLK_DIV_TX (
        .i_ref_clk   (UART_CLK),
        .i_rst_n     (rst_n_uart),
        .i_clk_en    (clk_div_en),
        .i_div_ratio (reg3),
        .o_div_clk   (TX_CLK)
    );

    //--------------------------------------------------------------------
    // Clock divider: RX_CLK only (see deviation note 1 above)
    //--------------------------------------------------------------------
    logic RX_CLK;
    logic [7:0] rx_div_ratio;

    CLK_DIV_MUX #(
      .WIDTH(8)
    )CLK_DIV_MUX_RX (
      .IN(uart_prescale),
      .OUT(rx_div_ratio)
    );

    CLK_DIV CLK_DIV_RX (
        .i_ref_clk   (UART_CLK),
        .i_rst_n     (rst_n_uart),
        .i_clk_en    (clk_div_en),
        .i_div_ratio (rx_div_ratio),
        .o_div_clk   (RX_CLK)
    );

    //--------------------------------------------------------------------
    // ASYNC_FIFO: write side REF_CLK, read side TX_CLK
    //--------------------------------------------------------------------
    logic tx_fetch_pulse;

    ASYNC_FIFO #(.DATA_WIDTH(8), .FIFO_DEPTH(8)) ASYNC_FIFO_U (
        .w_clk     (REF_CLK),
        .w_a_rst_n (rst_n_ref),
        .w_inc     (fifo_w_inc),
        .wr_data   (fifo_wr_data),

        .r_clk     (TX_CLK),
        .r_a_rst_n (rst_n_uart),
        .r_inc     (tx_fetch_pulse),

        .rd_data   (fifo_rd_data),
        .empty     (fifo_empty),
        .full      (fifo_full)
    );

    //--------------------------------------------------------------------
    // UART_TOP: TX on divided TX_CLK, RX on raw UART_CLK
    //--------------------------------------------------------------------
    logic tx_busy;

    UART_TOP UART_TOP_U (
        .TX_CLK        (TX_CLK),
        .RX_CLK        (UART_CLK),
        .RST           (rst_n_uart),

        .TX_IN_P       (fifo_rd_data),
        .TX_IN_V       (tx_fetch_pulse),
        .TX_OUT_S      (TX_OUT),
        .TX_OUT_V      (tx_busy),        // UART_TOP wires this to UART_TX_TOP's "busy"

        .RX_IN_S       (RX_IN),
        .RX_OUT_P      (rx_out_p),
        .RX_OUT_V      (rx_out_v),

        .Prescale      (uart_prescale),
        .parity_enable (uart_par_en),
        .parity_type   (uart_par_typ),

        .parity_error  (PAR_ERR),
        .stop_error    (STP_ERR)
    );

    //--------------------------------------------------------------------
    // TX-side FIFO drain: fires on FIFO empty->non-empty while TX idle,
    // and again every time a transmission completes with data still
    // queued (see deviation note 3 above).
    //--------------------------------------------------------------------
    PULSE_GEN PULSE_GEN_U (
        .clk       (TX_CLK),
        .a_rst_n   (rst_n_uart),
        .pulse_in  (tx_busy),
        .pulse_out (tx_fetch_pulse)
    );

endmodule
