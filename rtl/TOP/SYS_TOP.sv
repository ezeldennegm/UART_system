module SYS_TOP #(
    parameter DATA_WIDTH = 8,
    parameter REGF_DEPTH = 16,
    parameter FIFO_DEPTH = 8,
    parameter SYNC_STAGES = 2
)(
    input   logic  REF_CLK,
    input   logic  UART_CLK,
    input   logic  RST,        // raw, active-low, async

    input   logic  RX_IN,
    output  logic  TX_OUT,

    output  logic  PAR_ERR,
    output  logic  STP_ERR,
    input   wire   SI,
    input   wire   SE,
    input   wire   scan_clk,
    input   wire   scan_rst,
    input   wire   test_mode,
    output  wire   SO
);
    localparam REGF_ADDR = $clog2(REGF_DEPTH);
    localparam FIFO_ADDR = $clog2(FIFO_DEPTH);
    logic REF_M_CLK, UART_M_CLK;


    MUX2x1 MUX_REF_CLK (
        .IN_0(REF_CLK),
        .IN_1(scan_clk),
        .SEL(test_mode),
        .OUT(REF_M_CLK)
    );

    MUX2x1 MUX_UART_CLK (
        .IN_0(UART_CLK),
        .IN_1(scan_clk),
        .SEL(test_mode),
        .OUT(UART_M_CLK)
    );


    //--------------------------------------------------------------------
    // Reset synchronizers (one per clock domain that's actually used)
    //--------------------------------------------------------------------
    logic rst_n_ref, rst_n_uart;
    logic sync_rst_ref, sync_rst_uart;

    logic RST_M ;

    MUX2x1 MUX_RST_M (
        .IN_0(RST),
        .IN_1(scan_rst),
        .SEL(test_mode),
        .OUT(RST_M)
    );

    RST_SYNC #(.NUM_STAGES(SYNC_STAGES)) RST_SYNC_REF (
        .a_rst_n    (RST_M),
        .clk        (REF_M_CLK),
        .sync_rst_n (sync_rst_ref)
    );

    RST_SYNC #(.NUM_STAGES(SYNC_STAGES)) RST_SYNC_UART (
        .a_rst_n    (RST_M),
        .clk        (UART_M_CLK),
        .sync_rst_n (sync_rst_uart)
    );

    MUX2x1 MUX_RST_REF (
        .IN_0(sync_rst_ref),
        .IN_1(scan_rst),
        .SEL(test_mode),
        .OUT(rst_n_ref)
    );

    MUX2x1 MUX_RST_UART (
        .IN_0(sync_rst_uart),
        .IN_1(scan_rst),
        .SEL(test_mode),
        .OUT(rst_n_uart)
    );
    //--------------------------------------------------------------------
    // RegFile  (16 x 8b, single read port -- see SYS_CTRL.sv notes)
    //--------------------------------------------------------------------
    logic [DATA_WIDTH-1:0] reg2, reg3;
    logic [5:0] uart_prescale;
    logic       uart_par_en, uart_par_typ;

    assign {uart_prescale,uart_par_typ,uart_par_en} = reg2;

    logic [3:0] rf_addr;
    logic       rf_wren, rf_rden;
    logic [DATA_WIDTH-1:0] rf_wrdata, rf_rddata;

    logic [DATA_WIDTH-1:0]  alu_a, alu_b;


    REG_FILE #(
        .REGF_DEPTH(REGF_DEPTH),
        .REGF_WIDTH(DATA_WIDTH)
    )REG_FILE_U (
        .CLK     (REF_M_CLK),
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
    logic        alu_m_clk;
    logic [DATA_WIDTH-1:0] alu_out;
    logic [3:0]  alu_fun;

    CLK_GATE CLK_GATE_U (
        .CLK_EN    (alu_clk_en),
        .CLK       (REF_M_CLK),
        .GATED_CLK (alu_gated_clk)
    );
    MUX2x1 MUX_ALU_CLK (
        .IN_0(alu_gated_clk),
        .IN_1(scan_clk),
        .SEL(test_mode),
        .OUT(alu_m_clk)
    );
    ALU #(
        .DATA_WIDTH(DATA_WIDTH)
    ) ALU_U (
        .A          (alu_a),
        .B          (alu_b),
        .ALU_FUN    (alu_fun),
        .CLK        (alu_m_clk),
        .ALU_OUT    (alu_out)
    );

    //--------------------------------------------------------------------
    // UART RX -> Data_Sync (UART_CLK domain -> REF_CLK domain) -> SYS_CTRL
    //--------------------------------------------------------------------
    logic [7:0] rx_out_p, rx_p_data;
    logic       rx_out_v, rx_d_vld;

    DATA_SYNC #(.NUM_STAGES(SYNC_STAGES), .BUS_WIDTH(DATA_WIDTH)) DATA_SYNC_U (
        .clk          (REF_M_CLK),
        .a_rst_n      (rst_n_ref),
        .unsync_bus   (rx_out_p),
        .bus_enable   (rx_out_v),
        .sync_bus     (rx_p_data),
        .enable_pulse (rx_d_vld)
    );

    //--------------------------------------------------------------------
    // SYS_CTRL -> ASYNC_FIFO (write side, REF_CLK domain)
    //--------------------------------------------------------------------
    logic [DATA_WIDTH-1:0] fifo_wr_data, fifo_rd_data;
    logic       fifo_w_inc, fifo_full, fifo_empty;

    logic       clk_div_en;

  SYS_CTRL #(
      .ADDR_WIDTH(REGF_ADDR),
      .FRAME_WIDTH(DATA_WIDTH),
      .ALU_WIDTH(DATA_WIDTH),
      .ALU_FUN_WIDTH(4)
    ) SYS_CTRL (
      .CLK(REF_M_CLK),
      .RST(rst_n_ref),
      .ALU_FUN(alu_fun),
      .CLK_EN(alu_clk_en),
      .ALU_OUT(alu_out),
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
      .RX_P_DATA(rx_p_data),
      .RX_D_VLD(rx_d_vld),
      .TX_P_DATA(fifo_wr_data),
      .TX_D_VLD(fifo_w_inc),
      .FIFO_FULL(fifo_full),
      /*
      .uart_prescale(),
      .uart_par_en(),
      .uart_par_typ(),
      .div_ratio(),
      */
      .clk_div_en(clk_div_en)
    );

    //--------------------------------------------------------------------
    // Clock divider: TX_CLK only (see deviation note 1 above)
    //--------------------------------------------------------------------
    logic TX_CLK;
    logic RX_CLK;
    logic [DATA_WIDTH-1:0] rx_div_ratio;

    CLK_DIV_MUX #(
      .WIDTH(DATA_WIDTH)
    )CLK_DIV_MUX_RX (
      .IN(uart_prescale),
      .OUT(rx_div_ratio)
    );

    logic TX_CLK_div, RX_CLK_div;

    CLK_DIV CLK_DIV_TX (
        .i_ref_clk   (UART_M_CLK),
        .i_rst_n     (rst_n_uart),
        .i_clk_en    (clk_div_en),
        .i_div_ratio (reg3),
        .o_div_clk   (TX_CLK_div)      // renamed
    );

    CLK_DIV CLK_DIV_RX (
        .i_ref_clk   (UART_M_CLK),
        .i_rst_n     (rst_n_uart),
        .i_clk_en    (clk_div_en),
        .i_div_ratio (rx_div_ratio),
        .o_div_clk   (RX_CLK_div)      // renamed
    );

    MUX2x1 MUX_TX_CLK (
        .IN_0(TX_CLK_div),
        .IN_1(scan_clk),
        .SEL (test_mode),
        .OUT (TX_CLK)
    );

    MUX2x1 MUX_RX_CLK (
        .IN_0(RX_CLK_div),
        .IN_1(scan_clk),
        .SEL (test_mode),
        .OUT (RX_CLK)
    );

    //--------------------------------------------------------------------
    // ASYNC_FIFO: write side REF_CLK, read side TX_CLK
    //--------------------------------------------------------------------
    logic tx_fetch_pulse;

    ASYNC_FIFO #(.DATA_WIDTH(DATA_WIDTH), .FIFO_DEPTH(FIFO_DEPTH)) ASYNC_FIFO_U (
        .w_clk     (REF_M_CLK),
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
        .RX_CLK        (RX_CLK),
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
        .pulse_in  (!tx_busy && !fifo_empty),
        .pulse_out (tx_fetch_pulse)
    );

endmodule
