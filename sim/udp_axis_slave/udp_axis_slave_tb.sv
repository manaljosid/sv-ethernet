/**
 * @file udp_axis_slave_tb.sv
 *
 * @author Mani Magnusson
 * @date   2025
 *
 * @brief AXI-Stream slave to UDP with packet ID testbench
 */

`timescale 1ns / 1ps
`default_nettype none

`include "vunit_defines.svh"

import axis_bfm::*;
import udp_tx_header_bfm::*;

module udp_axis_slave_tb ();
    parameter int UDP_PORT = 1234;
    parameter bit [31:0] LOCAL_IP = {8'd192, 8'd168, 8'd1, 8'd128};
    parameter bit [31:0] TARGET_IP = {8'd192, 8'd168, 8'd1, 8'd1};
    parameter int AXIS_IN_TDATA_WIDTH = 16;

    logic clk;
    logic reset;

    UDP_TX_HEADER_IF udp_tx_header_if();
    AXIS_IF # (.TUSER_WIDTH(1), .TKEEP_ENABLE(0)) udp_tx_payload_if();

    AXIS_IF # (.TDATA_WIDTH(AXIS_IN_TDATA_WIDTH), .TUSER_WIDTH(1)) axis_in_if();

    udp_axis_slave # (
        .UDP_PORT(UDP_PORT),
        .LOCAL_IP(LOCAL_IP),
        .TARGET_IP(TARGET_IP)
    ) udp_axis_slave_inst (
        .clk(clk),
        .reset(reset),

        .udp_tx_header_if(udp_tx_header_if),
        .udp_tx_payload_if(udp_tx_payload_if),

        .in_axis_if(axis_in_if)
    );

    UDP_TX_HEADER_SLAVE_BFM udp_tx_header_bfm;
    AXIS_Slave_BFM # (.user_width(1)) udp_tx_payload_bfm;

    AXIS_Master_BFM # (
        .data_width(AXIS_IN_TDATA_WIDTH),
        .keep_enable(1),
        .user_width(1)
    ) axis_in_bfm;

    always begin
        #5ns;
        clk = !clk;
    end

    `TEST_SUITE begin
        `TEST_SUITE_SETUP begin
            clk = 1'b0;
            reset = 1'b1;

            udp_tx_header_bfm   = new(udp_tx_header_if);
            udp_tx_payload_bfm  = new(udp_tx_payload_if);
            axis_in_bfm         = new(axis_in_if);

            udp_tx_header_bfm.reset_task();
            udp_tx_payload_bfm.reset_task();
            axis_in_bfm.reset_task();

            @ (posedge clk);
            reset = 1'b0;
            @ (posedge clk);
        end

        `TEST_CASE("single_transfer") begin
            logic [31:0] transfer_id;
            static logic [AXIS_IN_TDATA_WIDTH-1:0] random_data_in;
            static logic [AXIS_IN_TDATA_WIDTH-1:0] random_data_out;
            logic [5:0] ip_dscp;
            logic [1:0] ip_ecn;
            logic [7:0] ip_ttl;
            logic [31:0] ip_source_ip;
            logic [31:0] ip_dest_ip;
            logic [15:0] source_port;
            logic [15:0] dest_port;
            logic [15:0] length;
            logic [15:0] checksum;

            random_data_in = $urandom();
            fork
                begin
                    axis_in_bfm.simple_transfer(.clk(clk), .data(random_data_in));
                end
                begin
                    udp_tx_header_bfm.transfer(
                        clk,
                        ip_dscp,
                        ip_ecn,
                        ip_ttl,
                        ip_source_ip,
                        ip_dest_ip,
                        source_port,
                        dest_port,
                        length,
                        checksum
                    );
                end
                begin
                    udp_tx_payload_bfm.simple_transfer(.clk(clk), .data(transfer_id[31:24]));
                    udp_tx_payload_bfm.simple_transfer(.clk(clk), .data(transfer_id[23:16]));
                    udp_tx_payload_bfm.simple_transfer(.clk(clk), .data(transfer_id[15:8]));
                    udp_tx_payload_bfm.simple_transfer(.clk(clk), .data(transfer_id[7:0]));
                    for (int i = 0; i < (AXIS_IN_TDATA_WIDTH / 8); i++) begin
                        udp_tx_payload_bfm.simple_transfer(.clk(clk), .data(random_data_out[((8*(i+1))-1) -: 8]));
                    end
                end
            join
            `CHECK_EQUAL(random_data_in, random_data_out);
        end
    end

    `WATCHDOG(0.1ms);
endmodule

`default_nettype wire