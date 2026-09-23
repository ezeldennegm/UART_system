onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -expand -group CTRL /tb/dut/SYS_CTRL/CLK
add wave -noupdate -expand -group CTRL /tb/dut/SYS_CTRL/RST
add wave -noupdate -expand -group CTRL /tb/dut/SYS_CTRL/ALU_FUN
add wave -noupdate -expand -group CTRL /tb/dut/SYS_CTRL/CLK_EN
add wave -noupdate -expand -group CTRL /tb/dut/SYS_CTRL/ALU_OUT
add wave -noupdate -expand -group CTRL /tb/dut/SYS_CTRL/Address
add wave -noupdate -expand -group CTRL /tb/dut/SYS_CTRL/WrEn
add wave -noupdate -expand -group CTRL /tb/dut/SYS_CTRL/RdEn
add wave -noupdate -expand -group CTRL /tb/dut/SYS_CTRL/WrData
add wave -noupdate -expand -group CTRL /tb/dut/SYS_CTRL/RdData
add wave -noupdate -expand -group CTRL /tb/dut/SYS_CTRL/RX_P_DATA
add wave -noupdate -expand -group CTRL /tb/dut/SYS_CTRL/RX_D_VLD
add wave -noupdate -expand -group CTRL /tb/dut/SYS_CTRL/TX_P_DATA
add wave -noupdate -expand -group CTRL /tb/dut/SYS_CTRL/TX_D_VLD
add wave -noupdate -expand -group CTRL /tb/dut/SYS_CTRL/FIFO_FULL
add wave -noupdate -expand -group CTRL /tb/dut/SYS_CTRL/clk_div_en
add wave -noupdate -expand -group CTRL /tb/dut/SYS_CTRL/state
add wave -noupdate -expand -group CTRL /tb/dut/SYS_CTRL/nstate
add wave -noupdate -expand -group CTRL /tb/dut/SYS_CTRL/cmd_reg
add wave -noupdate -expand -group CTRL /tb/dut/SYS_CTRL/payload
add wave -noupdate -expand -group CTRL /tb/dut/SYS_CTRL/byte_cnt
add wave -noupdate -expand -group CTRL /tb/dut/SYS_CTRL/bytes_needed
add wave -noupdate -expand -group CTRL /tb/dut/SYS_CTRL/is_alu_cmd
add wave -noupdate -expand -group UART /tb/dut/UART_TOP_U/TX_CLK
add wave -noupdate -expand -group UART /tb/dut/UART_TOP_U/RX_CLK
add wave -noupdate -expand -group UART /tb/dut/UART_TOP_U/RST
add wave -noupdate -expand -group UART /tb/dut/UART_TOP_U/TX_IN_P
add wave -noupdate -expand -group UART /tb/dut/UART_TOP_U/TX_IN_V
add wave -noupdate -expand -group UART /tb/dut/UART_TOP_U/TX_OUT_S
add wave -noupdate -expand -group UART /tb/dut/UART_TOP_U/TX_OUT_V
add wave -noupdate -expand -group UART /tb/dut/UART_TOP_U/RX_IN_S
add wave -noupdate -expand -group UART /tb/dut/UART_TOP_U/RX_OUT_P
add wave -noupdate -expand -group UART /tb/dut/UART_TOP_U/RX_OUT_V
add wave -noupdate -expand -group UART /tb/dut/UART_TOP_U/Prescale
add wave -noupdate -expand -group UART /tb/dut/UART_TOP_U/parity_enable
add wave -noupdate -expand -group UART /tb/dut/UART_TOP_U/parity_type
add wave -noupdate -expand -group UART /tb/dut/UART_TOP_U/parity_error
add wave -noupdate -expand -group UART /tb/dut/UART_TOP_U/UART_TX_TOP_inst/UART_TX_SERIALIZER_U/loaded_data
add wave -noupdate -expand -group UART /tb/dut/UART_TOP_U/stop_error
add wave -noupdate -expand -group TX_FSM /tb/dut/UART_TOP_U/UART_TX_TOP_inst/UART_TX_FSM_U/clk
add wave -noupdate -expand -group TX_FSM /tb/dut/UART_TOP_U/UART_TX_TOP_inst/UART_TX_FSM_U/rst_n
add wave -noupdate -expand -group TX_FSM /tb/dut/UART_TOP_U/UART_TX_TOP_inst/UART_TX_FSM_U/data_valid
add wave -noupdate -expand -group TX_FSM /tb/dut/UART_TOP_U/UART_TX_TOP_inst/UART_TX_FSM_U/parity_enable
add wave -noupdate -expand -group TX_FSM /tb/dut/UART_TOP_U/UART_TX_TOP_inst/UART_TX_FSM_U/serial_done
add wave -noupdate -expand -group TX_FSM /tb/dut/UART_TOP_U/UART_TX_TOP_inst/UART_TX_FSM_U/mux_sel
add wave -noupdate -expand -group TX_FSM /tb/dut/UART_TOP_U/UART_TX_TOP_inst/UART_TX_FSM_U/serial_enable
add wave -noupdate -expand -group TX_FSM /tb/dut/UART_TOP_U/UART_TX_TOP_inst/UART_TX_FSM_U/busy
add wave -noupdate -expand -group TX_FSM /tb/dut/UART_TOP_U/UART_TX_TOP_inst/UART_TX_FSM_U/busy_comb
add wave -noupdate -expand -group TX_FSM /tb/dut/UART_TOP_U/UART_TX_TOP_inst/UART_TX_FSM_U/parity_enable_ct
add wave -noupdate -expand -group TX_FSM /tb/dut/UART_TOP_U/UART_TX_TOP_inst/UART_TX_FSM_U/cu_s
add wave -noupdate -expand -group TX_FSM /tb/dut/UART_TOP_U/UART_TX_TOP_inst/UART_TX_FSM_U/nx_s
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {1592428689 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 150
configure wave -valuecolwidth 100
configure wave -justifyvalue left
configure wave -signalnamewidth 1
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ps
update
WaveRestoreZoom {1464912280 ps} {1727056280 ps}
