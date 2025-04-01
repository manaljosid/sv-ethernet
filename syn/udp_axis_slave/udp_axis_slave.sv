/**
 * @file udp_axis_slave.sv
 *
 * @author Mani Magnusson
 * @date   2025
 *
 * @brief AXI-Stream Slave to UDP module to stream data to Ethernet
 */


`default_nettype none

module udp_axis_slave # (
    parameter bit [15:0] UDP_PORT = 1234,
    parameter bit [31:0] LOCAL_IP = {8'd192, 8'd168, 8'd1, 8'd128},
    parameter bit [31:0] TARGET_IP = {8'd192, 8'd168, 8'd1, 8'd1}
) (
    input var logic         clk,
    input var logic         reset,

    UDP_TX_HEADER_IF.Source udp_tx_header_if,
    AXIS_IF.Master          udp_tx_payload_if,

    AXIS_IF.Slave           in_axis_if
);
    localparam int PACKET_SIZE = 4 + (in_axis_if.TDATA_WIDTH / 8);
    initial begin
        assert (udp_tx_payload_if.TDATA_WIDTH == 8)
        else $error("Assertion in %m failed, only udp_payload_if data width of 8 is supported");
    end

    typedef enum {
        STATE_IDLE,
        STATE_TX_ID,
        STATE_TX_DATA
    } state_t;
    
    state_t state;

    var logic [31:0] transfer_id;
    var logic [2:0] id_byte_index;

    AXIS_IF # (
        .TDATA_WIDTH(8),
        .TUSER_WIDTH(1)
    ) axis_adapter_to_mux_if();

    AXIS_IF # (
        .TDATA_WIDTH(8),
        .TUSER_WIDTH(1)
    ) axis_fsm_to_mux_if();

    always_comb begin
        if (state == STATE_TX_ID) begin
            udp_tx_payload_if.tvalid    = axis_fsm_to_mux_if.tvalid;
            udp_tx_payload_if.tdata     = axis_fsm_to_mux_if.tdata;
            udp_tx_payload_if.tstrb     = axis_fsm_to_mux_if.tstrb;
            udp_tx_payload_if.tkeep     = axis_fsm_to_mux_if.tkeep;
            udp_tx_payload_if.tlast     = axis_fsm_to_mux_if.tlast;
            udp_tx_payload_if.tid       = axis_fsm_to_mux_if.tid;
            udp_tx_payload_if.tdest     = axis_fsm_to_mux_if.tdest;
            udp_tx_payload_if.tuser     = axis_fsm_to_mux_if.tuser;
            udp_tx_payload_if.twakeup   = axis_fsm_to_mux_if.twakeup;

            axis_fsm_to_mux_if.tready   = udp_tx_payload_if.tready;
        end else if (state == STATE_TX_DATA) begin
            udp_tx_payload_if.tvalid    = axis_adapter_to_mux_if.tvalid;
            udp_tx_payload_if.tdata     = axis_adapter_to_mux_if.tdata;
            udp_tx_payload_if.tstrb     = axis_adapter_to_mux_if.tstrb;
            udp_tx_payload_if.tkeep     = axis_adapter_to_mux_if.tkeep;
            udp_tx_payload_if.tlast     = axis_adapter_to_mux_if.tlast;
            udp_tx_payload_if.tid       = axis_adapter_to_mux_if.tid;
            udp_tx_payload_if.tdest     = axis_adapter_to_mux_if.tdest;
            udp_tx_payload_if.tuser     = axis_adapter_to_mux_if.tuser;
            udp_tx_payload_if.twakeup   = axis_adapter_to_mux_if.twakeup;

            axis_adapter_to_mux_if.tready = udp_tx_payload_if.tready;
        end else begin
            udp_tx_payload_if.tvalid    = '0;
            udp_tx_payload_if.tdata     = '0;
            udp_tx_payload_if.tstrb     = '0;
            udp_tx_payload_if.tkeep     = '0;
            udp_tx_payload_if.tlast     = '0;
            udp_tx_payload_if.tid       = '0;
            udp_tx_payload_if.tdest     = '0;
            udp_tx_payload_if.tuser     = '0;
            udp_tx_payload_if.twakeup   = '0;

            axis_fsm_to_mux_if.tready   = '0;
            axis_adapter_to_mux_if.tready = '0;
        end
    end

    always_comb begin
        if (state == STATE_IDLE) begin
            udp_tx_header_if.hdr_valid = axis_adapter_to_mux_if.tvalid;
        end else begin
            udp_tx_header_if.hdr_valid = 1'b0;
        end
    end

    always_ff @ (posedge clk) begin
        if (reset) begin
            state <= STATE_IDLE;

            transfer_id <= '0;
            id_byte_index <= 0;

            udp_tx_header_if.ip_dscp <= '0;
            udp_tx_header_if.ip_ecn <= '0;
            udp_tx_header_if.ip_ttl <= 64;
            udp_tx_header_if.ip_source_ip <= LOCAL_IP;
            udp_tx_header_if.ip_dest_ip <= TARGET_IP;
            udp_tx_header_if.source_port <= UDP_PORT;
            udp_tx_header_if.dest_port <= UDP_PORT;
            udp_tx_header_if.length <= PACKET_SIZE;
            udp_tx_header_if.checksum <= '0;

            axis_fsm_to_mux_if.tvalid <= 1'b0;
            axis_fsm_to_mux_if.tdata <= '0;
        end else begin
            case (state)
                STATE_IDLE : begin
                    if (udp_tx_header_if.hdr_ready && udp_tx_header_if.hdr_valid) begin
                        axis_fsm_to_mux_if.tvalid <= 1'b1;
                        axis_fsm_to_mux_if.tdata <= transfer_id[((8* (id_byte_index + 1)) -1) -: 8];
                        axis_fsm_to_mux_if.tlast <= '0;
                        axis_fsm_to_mux_if.tuser <= '0;

                        id_byte_index <= id_byte_index + 1;
                        
                        state <= STATE_TX_ID;
                    end
                end
                STATE_TX_ID : begin
                    if (udp_tx_payload_if.tready && udp_tx_payload_if.tvalid) begin

                        if (id_byte_index == 4) begin
                            axis_fsm_to_mux_if.tvalid <= 1'b0;
                            id_byte_index <= 0;

                            state <= STATE_TX_DATA;
                        end else begin
                            axis_fsm_to_mux_if.tdata <= transfer_id[((8* (id_byte_index + 1)) -1) -: 8];
                            id_byte_index <= id_byte_index + 1;
                        end
                    end
                end
                STATE_TX_DATA : begin
                    if (udp_tx_payload_if.tready && udp_tx_payload_if.tvalid) begin
                        if (axis_adapter_to_mux_if.tlast) begin
                            udp_tx_header_if.ip_dscp <= '0;
                            udp_tx_header_if.ip_ecn <= '0;
                            udp_tx_header_if.ip_ttl <= 64;
                            udp_tx_header_if.ip_source_ip <= LOCAL_IP;
                            udp_tx_header_if.ip_dest_ip <= TARGET_IP;
                            udp_tx_header_if.source_port <= UDP_PORT;
                            udp_tx_header_if.dest_port <= UDP_PORT;
                            udp_tx_header_if.length <= PACKET_SIZE;
                            udp_tx_header_if.checksum <= '0;

                            transfer_id = transfer_id + 1;

                            state <= STATE_IDLE;
                        end
                    end
                end
            endcase
        end
    end

    axis_adapter_wrapper axis_adapter_wrapper_inst (
        .clk(clk),
        .reset(reset),
        .in_axis_if(in_axis_if),
        .out_axis_if(axis_adapter_to_mux_if)
    );
endmodule

`default_nettype wire