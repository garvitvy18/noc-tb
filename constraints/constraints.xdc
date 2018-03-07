create_clock -period 5 [get_ports sys_clk_p]

set_property PACKAGE_PIN AU36 [get_ports uart_tx]
set_property PACKAGE_PIN AU33 [get_ports uart_rx]
set_property PACKAGE_PIN AR35 [get_ports uart_err]
set_property IOSTANDARD LVCMOS18 [get_ports uart_*]


set_property PACKAGE_PIN E19 [get_ports sys_clk_p]
set_property IOSTANDARD LVDS [get_ports sys_clk_p]
set_property PACKAGE_PIN E18 [get_ports sys_clk_n]
set_property IOSTANDARD LVDS [get_ports sys_clk_n]

set_property PACKAGE_PIN AV40 [get_ports reset]
set_property IOSTANDARD LVCMOS18 [get_ports reset]

set_property PACKAGE_PIN AM39 [get_ports led_snd_complete]
set_property PACKAGE_PIN AN39 [get_ports led_rcv_complete]
set_property PACKAGE_PIN AR37 [get_ports led_test_error]
set_property IOSTANDARD LVCMOS18 [get_ports led_*]
