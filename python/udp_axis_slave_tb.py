from pathlib import Path
import random

import vunit_common

# NOTE: This assumes the location of the ./rtl and ./workspace directory relative to where this is run from
WORKSPACE = Path(__file__).parent / "workspace" / "modelsim"
LIB_ROOT = Path(__file__).parent / ".." / "lib"
SYN_ROOT = Path(__file__).parent / ".." / "syn"
SIM_ROOT = Path(__file__).parent / ".." / "sim"

vu, lib = vunit_common.init(WORKSPACE)

vunit_common.add_source(lib, LIB_ROOT / "./sv-axis/syn/axis_adapter_wrapper/axis_adapter_wrapper.sv")
vunit_common.add_source(lib, LIB_ROOT / "./sv-axis/lib/verilog-axis/rtl/axis_adapter.v")

vunit_common.add_source(lib, LIB_ROOT / "./sv-axis/syn/axis_if/axis_if.sv")
vunit_common.add_source(lib, LIB_ROOT / "./sv-axis/sim/axis_bfm/axis_bfm.sv")

vunit_common.add_source(lib, SYN_ROOT / "./udp_tx_header_if/udp_tx_header_if.sv")
vunit_common.add_source(lib, SIM_ROOT / "./udp_header_bfm/udp_tx_header_bfm.sv")

vunit_common.add_source(lib, SYN_ROOT / "./udp_rx_header_if/udp_rx_header_if.sv")
vunit_common.add_source(lib, SIM_ROOT / "./udp_header_bfm/udp_rx_header_bfm.sv")

vunit_common.add_source(lib, SYN_ROOT / "./udp_axis_slave/udp_axis_slave.sv")
vunit_common.add_source(lib, SIM_ROOT / "./udp_axis_slave/udp_axis_slave_tb.sv")

# Create testbench
tb = lib.test_bench("udp_axis_slave_tb")

tb.add_config("TEST")

vu.main()