set_property -dict { PACKAGE_PIN E3 IOSTANDARD LVCMOS33 } \
    [get_ports { CLK100MHZ }]

create_clock -add \
    -name sys_clk_pin \
    -period 10.00 \
    -waveform {0 5} \
    [get_ports { CLK100MHZ }]


set_property -dict { PACKAGE_PIN C11 IOSTANDARD LVCMOS33 } \
    [get_ports { sw[1] }]


set_property -dict { PACKAGE_PIN D9 IOSTANDARD LVCMOS33 } \
    [get_ports { btn[0] }]


set_property -dict { PACKAGE_PIN H5 IOSTANDARD LVCMOS33 } \
    [get_ports { led[0] }]

set_property -dict { PACKAGE_PIN J5 IOSTANDARD LVCMOS33 } \
    [get_ports { led[1] }]

set_property -dict { PACKAGE_PIN T9 IOSTANDARD LVCMOS33 } \
    [get_ports { led[2] }]

set_property -dict { PACKAGE_PIN T10 IOSTANDARD LVCMOS33 } \
    [get_ports { led[3] }]


set_property -dict { PACKAGE_PIN G1 IOSTANDARD LVCMOS33 } \
    [get_ports { CK_MISO }]

set_property -dict { PACKAGE_PIN H1 IOSTANDARD LVCMOS33 } \
    [get_ports { CK_MOSI }]

set_property -dict { PACKAGE_PIN F1 IOSTANDARD LVCMOS33 } \
    [get_ports { CK_SCK }]

set_property -dict { PACKAGE_PIN C1 IOSTANDARD LVCMOS33 } \
    [get_ports { CK_SS }]