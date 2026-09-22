module UART_TOP #(
    parameter START_BIT       = 0,
    parameter STOP_BIT        = 1,
    parameter ODD_PARITY      = 1,
    parameter EVEN_PARITY     = 0,
    parameter ENABLE_PARITY   = 1,
    parameter DISABLE_PARITY  = 0,
    parameter PARITY_ENABLE   = 1,
    parameter PARITY_DISABLE  = 0

)(
    input  wire        TX_CLK,
    input  wire        RX_CLK,
    input  wire        RST,

    // TX
    input  wire [7:0]  TX_IN_P,
    input  wire        TX_IN_V,
    output wire        TX_OUT_S,
    output wire        TX_OUT_V,

    // RX
    input  wire        RX_IN_S,
    output wire [7:0]  RX_OUT_P,
    output wire        RX_OUT_V,

    // UART configuration
    input  wire [5:0]  Prescale,
    input  wire        parity_enable,
    input  wire        parity_type,

    // Error outputs
    output wire        parity_error,
    output wire        stop_error
);


    UART_TX_TOP #(
        .START_BIT       (START_BIT),
        .STOP_BIT        (STOP_BIT),
        .ODD_PARITY      (ODD_PARITY),
        .EVEN_PARITY     (EVEN_PARITY),
        .ENABLE_PARITY   (ENABLE_PARITY),
        .DISABLE_PARITY  (DISABLE_PARITY)
    ) UART_TX_TOP_inst (

        .clk             (TX_CLK),
        .rst_n           (RST),
        .p_data          (TX_IN_P),
        .parity_enable   (parity_enable),
        .parity_type     (parity_type),
        .data_valid      (TX_IN_V),
        .busy            (TX_OUT_V),
        .TX_out          (TX_OUT_S)

    );


    UART_RX_TOP #(
        .START_BIT       (START_BIT),
        .STOP_BIT        (STOP_BIT),
        .EVEN_PARITY     (EVEN_PARITY),
        .ODD_PARITY      (ODD_PARITY),
        .PARITY_ENABLE   (PARITY_ENABLE),
        .PARITY_DISABLE  (PARITY_DISABLE)
    ) UART_RX_TOP_inst (

        .clk             (RX_CLK),
        .rst_n           (RST),
        .prescale        (Prescale),
        .parity_enable   (parity_enable),
        .parity_type     (parity_type),
        .rx_in           (RX_IN_S),
        .p_data          (RX_OUT_P),
        .data_valid      (RX_OUT_V),
        .stop_error      (stop_error),
        .parity_error    (parity_error)

    );

endmodule
