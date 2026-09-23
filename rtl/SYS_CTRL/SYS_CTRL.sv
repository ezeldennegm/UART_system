module SYS_CTRL #(
    parameter int ADDR_WIDTH    = 4,
    parameter int FRAME_WIDTH   = 8,    // UART byte width == RegFile word width
    parameter int ALU_WIDTH     = 16,   // ALU datapath width
    parameter int ALU_FUN_WIDTH = 4
)(
    input  logic                        CLK,
    input  logic                        RST,          // active-low

    // ---------------- ALU interface ----------------
    /*output logic [ALU_WIDTH-1:0]        ALU_A,
    output logic [ALU_WIDTH-1:0]        ALU_B,*/
    output logic [ALU_FUN_WIDTH-1:0]    ALU_FUN,
    output logic                        CLK_EN,        // to CLK_GATE (doubles as ALU "enable")
    input  logic [ALU_WIDTH-1:0]        ALU_OUT,

    // ---------------- RegFile interface ----------------
    output logic [ADDR_WIDTH-1:0]       Address,
    output logic                        WrEn,
    output logic                        RdEn,
    output logic [FRAME_WIDTH-1:0]      WrData,
    input  logic [FRAME_WIDTH-1:0]      RdData,

    /*
    // Live taps of RegFile locations 0-3 (see header note)
    input  logic [FRAME_WIDTH-1:0]      reg0,
    input  logic [FRAME_WIDTH-1:0]      reg1,
    input  logic [FRAME_WIDTH-1:0]      reg2,
    input  logic [FRAME_WIDTH-1:0]      reg3,
    */

    // ---------------- UART RX path (post Data_Sync, REF_CLK domain) -----
    input  logic [FRAME_WIDTH-1:0]      RX_P_DATA,
    input  logic                        RX_D_VLD,

    // ---------------- UART TX path (ASYNC_FIFO write port) --------------
    output logic [FRAME_WIDTH-1:0]      TX_P_DATA,
    output logic                        TX_D_VLD,
    input  logic                        FIFO_FULL

    /*
    // ---------------- UART / clock-divider config (derived from reg2/reg3)
    output logic [5:0]                  uart_prescale,
    output logic                        uart_par_en,
    output logic                        uart_par_typ,
    output logic [7:0]                  div_ratio,
    output logic                        clk_div_en
    */
);

    //--------------------------------------------------------------------
    // Command opcodes
    //--------------------------------------------------------------------
    localparam logic [7:0] CMD_RF_WR   = 8'hAA;
    localparam logic [7:0] CMD_RF_RD   = 8'hBB;
    localparam logic [7:0] CMD_ALU_WOP = 8'hCC;
    localparam logic [7:0] CMD_ALU_NOP = 8'hDD;

    // Reserved RegFile addresses
    localparam logic [ADDR_WIDTH-1:0] ADDR_OPA = 4'd0;
    localparam logic [ADDR_WIDTH-1:0] ADDR_OPB = 4'd1;

    //--------------------------------------------------------------------
    // FSM states
    //--------------------------------------------------------------------
    typedef enum logic [3:0] {
        S_IDLE,     // wait for command byte
        S_COLLECT,  // collect remaining payload bytes
        S_WR_ADDR,  // RF write: WrEn pulse @ Address/WrData
        S_RD_ADDR,  // RF read : RdEn pulse @ Address
        S_WR_OPA,   // ALU w/op: write OP_A -> addr 0x0 (reg0 picks it up)
        S_WR_OPB,   // ALU w/op: write OP_B -> addr 0x1 (reg1 picks it up)
        S_ALU_LOAD, // pulse CLK_EN for one ALU register update
        S_SEND_LO,  // push low/only response byte into FIFO
        S_SEND_HI   // push high response byte (ALU results only)
    } state_e;

    state_e state, nstate;

    //--------------------------------------------------------------------
    // Frame collection
    //--------------------------------------------------------------------
    logic [7:0] cmd_reg;
    logic [7:0] payload [3];   // up to 3 payload bytes (ALU w/op command)
    logic [1:0] byte_cnt;
    logic [1:0] bytes_needed;
    logic       is_alu_cmd;

    //--------------------------------------------------------------------
    // Sequential state register
    //--------------------------------------------------------------------
    always_ff @(posedge CLK or negedge RST) begin
        if (!RST)
            state <= S_IDLE;
        else
            state <= nstate;
    end

    //--------------------------------------------------------------------
    // Command decode / byte counting
    //--------------------------------------------------------------------
    always_ff @(posedge CLK or negedge RST) begin
        if (!RST) begin
            cmd_reg      <= 8'h00;
            byte_cnt     <= 2'd0;
            bytes_needed <= 2'd0;
            is_alu_cmd   <= 1'b0;
            payload[0]   <= 8'h00;
            payload[1]   <= 8'h00;
            payload[2]   <= 8'h00;
        end else begin
            unique case (state)
                S_IDLE: begin
                    if (RX_D_VLD) begin
                        cmd_reg  <= RX_P_DATA;
                        byte_cnt <= 2'd0;
                        unique case (RX_P_DATA)
                            CMD_RF_WR:   begin bytes_needed <= 2'd2; is_alu_cmd <= 1'b0; end
                            CMD_RF_RD:   begin bytes_needed <= 2'd1; is_alu_cmd <= 1'b0; end
                            CMD_ALU_WOP: begin bytes_needed <= 2'd3; is_alu_cmd <= 1'b1; end
                            CMD_ALU_NOP: begin bytes_needed <= 2'd1; is_alu_cmd <= 1'b1; end
                            default:     begin bytes_needed <= 2'd0; is_alu_cmd <= 1'b0; end
                        endcase
                    end
                end

                S_COLLECT: begin
                    if (RX_D_VLD) begin
                        payload[byte_cnt] <= RX_P_DATA;
                        byte_cnt          <= byte_cnt + 2'd1;
                    end
                end

                default: ; // hold latched values through execute/respond states
            endcase
        end
    end

    //--------------------------------------------------------------------
    // Next-state logic
    //--------------------------------------------------------------------
    always_comb begin
        nstate = state;
        unique case (state)
            S_IDLE:
                if (RX_D_VLD && (RX_P_DATA == CMD_RF_WR   || RX_P_DATA == CMD_RF_RD ||
                                  RX_P_DATA == CMD_ALU_WOP || RX_P_DATA == CMD_ALU_NOP))
                    nstate = S_COLLECT;

            S_COLLECT:
                if (RX_D_VLD && (byte_cnt + 2'd1 == bytes_needed)) begin
                    unique case (cmd_reg)
                        CMD_RF_WR:   nstate = S_WR_ADDR;
                        CMD_RF_RD:   nstate = S_RD_ADDR;
                        CMD_ALU_WOP: nstate = S_WR_OPA;
                        CMD_ALU_NOP: nstate = S_ALU_LOAD;  // reg0/reg1 already hold last operands
                        default:     nstate = S_IDLE;
                    endcase
                end

            S_WR_ADDR:  nstate = S_SEND_LO;
            S_RD_ADDR:  nstate = S_SEND_LO;   // RdData is valid the cycle after RdEn
            S_WR_OPA:   nstate = S_WR_OPB;
            S_WR_OPB:   nstate = S_ALU_LOAD;
            S_ALU_LOAD: nstate = S_SEND_LO;   // ALU_OUT valid the cycle after CLK_EN pulses

            S_SEND_LO:
                if (!FIFO_FULL)
                    nstate = is_alu_cmd ? S_SEND_HI : S_IDLE;

            S_SEND_HI:
                if (!FIFO_FULL)
                    nstate = S_IDLE;

            default: nstate = S_IDLE;
        endcase
    end

    /*
    assign ALU_A         = {{(ALU_WIDTH-FRAME_WIDTH){1'b0}}, reg0};
    assign ALU_B         = {{(ALU_WIDTH-FRAME_WIDTH){1'b0}}, reg1};
    assign uart_par_en   = reg2[0];
    assign uart_par_typ  = reg2[1];
    assign uart_prescale = reg2[7:2];
    assign div_ratio     = reg3;
    */
    assign clk_div_en    = 1'b1;   // clock divider is always on per system spec

    //--------------------------------------------------------------------
    // Output/control signals (Moore outputs, decoded from current state)
    //--------------------------------------------------------------------
    always_comb begin
        // defaults
        Address   = '0;
        WrEn      = 1'b0;
        RdEn      = 1'b0;
        WrData    = '0;
        ALU_FUN   = '0;
        CLK_EN    = 1'b0;
        TX_P_DATA = '0;
        TX_D_VLD  = 1'b0;

        unique case (state)
            S_WR_ADDR: begin
                Address = payload[0][ADDR_WIDTH-1:0];
                WrData  = payload[1];
                WrEn    = 1'b1;
            end

            S_RD_ADDR: begin
                Address = payload[0][ADDR_WIDTH-1:0];
                RdEn    = 1'b1;
            end

            S_WR_OPA: begin
                Address = ADDR_OPA;
                WrData  = payload[0];
                WrEn    = 1'b1;
            end

            S_WR_OPB: begin
                Address = ADDR_OPB;
                WrData  = payload[1];
                WrEn    = 1'b1;
            end

            S_ALU_LOAD: begin
                CLK_EN  = 1'b1;
                ALU_FUN = (cmd_reg == CMD_ALU_WOP) ? payload[2][ALU_FUN_WIDTH-1:0]
                                                    : payload[0][ALU_FUN_WIDTH-1:0];
            end

            S_SEND_LO: begin
                TX_D_VLD = !FIFO_FULL;
                unique case (cmd_reg)
                    CMD_RF_WR:              TX_P_DATA = payload[1];              // echo written byte
                    CMD_RF_RD:              TX_P_DATA = RdData;                  // read result (exact width match)
                    CMD_ALU_WOP,
                    CMD_ALU_NOP:            TX_P_DATA = ALU_OUT[FRAME_WIDTH-1:0]; // ALU result, low byte
                    default:                TX_P_DATA = '0;
                endcase
            end

            S_SEND_HI: begin
                TX_P_DATA = ALU_OUT[ALU_WIDTH-1:FRAME_WIDTH]; // ALU result, high byte
                TX_D_VLD  = !FIFO_FULL;
            end

            default: ;
        endcase
    end

endmodule