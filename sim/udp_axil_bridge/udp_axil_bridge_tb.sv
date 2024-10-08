/**
 * @file udp_axil_bridge_tb.sv
 * 
 * @author Mani Magnusson
 * @date  2024
 * 
 * @brief udp_axil_bridge testbench
 */

`timescale 1ns / 1ps
`default_nettype none

`include "vunit_defines.svh"

import axil_bfm::*;
import axis_bfm::*;
import udp_tx_header_bfm::*;
import udp_rx_header_bfm::*;
import udp_axil_bridge_types::*;

module udp_axil_bridge_tb ();
    parameter bit [15:0] UDP_SOURCE_PORT = 8891;
    parameter bit [15:0] UDP_DEST_PORT = 1234;
    parameter int REQUEST_BUFFER_SIZE = 64;

    parameter int AXIL_DATA_WIDTH = 32;
    parameter int AXIL_ADDR_WIDTH = 32;

    logic clk;
    logic reset;

    UDP_TX_HEADER_IF udp_tx_header_if();
    AXIS_IF # (.TUSER_WIDTH(1), .TKEEP_ENABLE(0)) udp_tx_payload_if();

    UDP_RX_HEADER_IF udp_rx_header_if();
    AXIS_IF # (.TUSER_WIDTH(1), .TKEEP_ENABLE(0)) udp_rx_payload_if();

    AXIL_IF # (.ADDR_WIDTH(AXIL_ADDR_WIDTH), .DATA_WIDTH(AXIL_DATA_WIDTH)) axil_if();

    udp_axil_bridge # (
        .UDP_PORT(UDP_DEST_PORT),
        .REQUEST_BUFFER_SIZE(REQUEST_BUFFER_SIZE)
    ) udp_axil_bridge_inst (
        .clk(clk),
        .reset(reset),
        .udp_tx_header_if(udp_tx_header_if),
        .udp_tx_payload_if(udp_tx_payload_if),
        .udp_rx_header_if(udp_rx_header_if),
        .udp_rx_payload_if(udp_rx_payload_if),
        .axil_if(axil_if)
    );

    UDP_TX_HEADER_SLAVE_BFM udp_tx_header_bfm;
    AXIS_Slave_BFM # (.user_width(1)) udp_tx_payload_bfm;

    UDP_RX_HEADER_MASTER_BFM udp_rx_header_bfm;
    AXIS_Master_BFM # (.user_width(1)) udp_rx_payload_bfm;

    AXIL_Slave_BFM # (
        .ADDR_WIDTH(AXIL_ADDR_WIDTH),
        .DATA_WIDTH(AXIL_DATA_WIDTH)
    ) axil_bfm;

    always begin
        #5ns;
        clk = !clk;
    end

    `TEST_SUITE begin
        `TEST_SUITE_SETUP begin
            clk = 1'b0;
            reset = 1'b1;

            udp_tx_header_bfm = new(udp_tx_header_if);
            udp_tx_payload_bfm =  new(udp_tx_payload_if);
            udp_rx_header_bfm = new(udp_rx_header_if);
            udp_rx_payload_bfm =  new(udp_rx_payload_if);
            axil_bfm = new(axil_if, 1'b0);

            udp_tx_header_bfm.reset_task();
            udp_tx_payload_bfm.reset_task();
            udp_rx_header_bfm.reset_task();
            udp_rx_payload_bfm.reset_task();
            axil_bfm.reset_task();

            @ (posedge clk);
            reset = 1'b0;
            @ (posedge clk);
        end

        `TEST_CASE("single_write") begin
            logic [AXIL_ADDR_WIDTH-1:0] address;
            logic [AXIL_DATA_WIDTH-1:0] data;
            logic [axil_if.STRB_WIDTH-1:0] strobe;
            logic [2:0] awprot;

            logic [5:0] ip_dscp;
            logic [1:0] ip_ecn;
            logic [7:0] ip_ttl;
            logic [31:0] ip_source_ip;
            logic [31:0] ip_dest_ip;
            logic [15:0] source_port;
            logic [15:0] dest_port;
            logic [15:0] length;
            logic [15:0] checksum;

            logic [7:0] txdata;
            logic [1:0] txstrb;
            logic [1:0] txkeep;
            logic       txlast;
            logic       txid;
            logic       txdest;
            logic       txuser;
            logic       txwakeup;

            request_union_t req;
            req.request.opcode = WRITE_DATA;
            req.request.address = 30'h5DE9A01;
            req.request.data = 32'hD463AD5F;
            udp_rx_header_bfm.simple_transfer(clk, UDP_SOURCE_PORT, UDP_DEST_PORT, 8*1, 0);

            udp_rx_payload_bfm.transfer(.clk(clk), .data(req.bytes[0]));
            udp_rx_payload_bfm.transfer(.clk(clk), .data(req.bytes[1]));
            udp_rx_payload_bfm.transfer(.clk(clk), .data(req.bytes[2]));
            udp_rx_payload_bfm.transfer(.clk(clk), .data(req.bytes[3]));
            udp_rx_payload_bfm.transfer(.clk(clk), .data(req.bytes[4]));
            udp_rx_payload_bfm.transfer(.clk(clk), .data(req.bytes[5]));
            udp_rx_payload_bfm.transfer(.clk(clk), .data(req.bytes[6]));
            udp_rx_payload_bfm.transfer(.clk(clk), .data(req.bytes[7]), .last(1'b1));

            axil_bfm.write(clk, address, data, strobe, awprot);

            `CHECK_EQUAL(address, 32'h05DE9A01);
            `CHECK_EQUAL(data, 32'hD463AD5F);

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

            `CHECK_EQUAL(source_port, UDP_DEST_PORT);
            `CHECK_EQUAL(dest_port, UDP_SOURCE_PORT);
            `CHECK_EQUAL(ip_source_ip, {8'd192, 8'd168, 8'd1, 8'd111});
            `CHECK_EQUAL(ip_dest_ip, {8'd192, 8'd168, 8'd1, 8'd152});

            req.request.opcode = WRITE_OK;

            for (int i = 0; i < 8; i++) begin
                udp_tx_payload_bfm.transfer(
                    clk,
                    txdata,
                    txstrb,
                    txkeep,
                    txlast,
                    txid,
                    txdest,
                    txuser,
                    txwakeup
                );
                $display("%0h == 7: %0h", i, i == 7);
                `CHECK_EQUAL(txdata, req.bytes[i]);
                `CHECK_EQUAL(txlast, 1'(i == 7));
                `CHECK_EQUAL(txuser, 0);
            end

            /* TODO:
                Do an AXIL transfer and test if the data out of that is what is expected
                Do a UDP transmit with the results
                Check if the UDP transmission gives expected output
            */
        end
    end

    `WATCHDOG(0.1ms);
endmodule

`default_nettype wire