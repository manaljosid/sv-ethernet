/**
 * @file udp_switch.sv
 * 
 * @author Mani Magnusson
 * @date   2024
 * 
 * @brief Port-based UDP switch
 */

`default_nettype none

module udp_switch # (
    parameter int PORT_COUNT = 2,
    parameter bit [15:0] PORTS [PORT_COUNT]
) (
    input var logic clk,
    input var logic reset,
    
    input var logic [31:0]  local_ip,

    UDP_TX_HEADER_IF.Sink   udp_tx_header_if_sink [PORT_COUNT],
    AXIS_IF.Slave           udp_tx_payload_if_sink [PORT_COUNT],

    UDP_RX_HEADER_IF.Source udp_rx_header_if_source     [PORT_COUNT],
    AXIS_IF.Master          udp_rx_payload_if_source    [PORT_COUNT],

    UDP_TX_HEADER_IF.Source udp_tx_header_if_source,
    AXIS_IF.Master          udp_tx_payload_if_source,

    UDP_RX_HEADER_IF.Sink   udp_rx_header_if_sink,
    AXIS_IF.Slave           udp_rx_payload_if_sink
);

    var logic [$clog2(PORT_COUNT)-1:0] select;
    var logic drop;

    always_comb begin
        select = '0;
        drop = 1'b0;
        for (int i = 0; i < PORT_COUNT; i++) begin
            if (udp_rx_header_if_sink.dest_port==PORTS[i] 
                && udp_rx_header_if_sink.ip_dest_ip==local_ip)  begin
                select = i;
            end else begin
                drop = 1'b1;
            end
        end
    end

    udp_demux_wrapper # (
        .M_COUNT(PORT_COUNT)
    ) udp_demux_wrapper_inst (
        .clk(clk),
        .reset(reset),
        .udp_rx_header_if_source(udp_rx_header_if_source),
        .udp_rx_payload_if_source(udp_rx_payload_if_source),
        .udp_rx_header_if_sink(udp_rx_header_if_sink),
        .udp_rx_payload_if_sink(udp_rx_payload_if_sink),
        .enable(1'b1),
        .drop(drop),
        .select(select)
    );

    // Just arb mux the outgoing packets
    udp_arb_mux_wrapper # (
        .S_COUNT(PORT_COUNT)
    ) udp_arb_mux_wrapper_inst (
        .clk(clk),
        .reset(reset),
        .udp_tx_header_if_sink(udp_tx_header_if_sink),
        .udp_tx_payload_if_sink(udp_tx_payload_if_sink),
        .udp_tx_header_if_source(udp_tx_header_if_source),
        .udp_tx_payload_if_source(udp_tx_payload_if_source)
    );
endmodule

`default_nettype wire