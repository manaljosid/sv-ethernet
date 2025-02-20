


`default_nettype none

module udp_axis_slave # (
    parameter bit [15:0] UDP_PORT = 1234,
    parameter bit [31:0] TARGET_IP = {8'd192, 8'd168, 8'd1, 8'd1}
) (
    input var logic         clk,
    input var logic         reset,

    UDP_TX_HEADER_IF.Source udp_tx_header_if,
    AXIS_IF.Master          udp_tx_payload_if,

    AXIS_IF.Slave           in_axis_if
);
    localparam int BYTE_COUNT = in_axis_if.TDATA_WIDTH / 8;
    initial begin
        assert (udp_tx_payload_if.TDATA_WIDTH == 8)
        else $error("Assertion in %m failed, only udp_payload_if data width of 8 is supported");
    end

    typedef enum {
        STATE_IDLE,
        STATE_TX_HEADER,
        STATE_TX_ID,
        STATE_TX_DATA
    } state_t;
    
    state_t state;

    var logic [31:0] transfer_id;
    var logic [3:0] id_byte_index;
    var logic [BYTE_COUNT-1:0] data_byte_index;

    AXIS_IF # (
        .TDATA_WIDTH(8),
        .TUSER_WIDTH(1)
    ) axis_adapter_if_to_axis_mux();

    always_ff @ (posedge clk) begin
        if (reset) begin
            state <= STATE_IDLE;

            transfer_id <= '0;

            udp_tx_header_if.hdr_valid = 1'b0;
            udp_tx_payload_if.tvalid = 1'b0;
        end else begin
            case (state)
                STATE_IDLE : begin
                    if (axis_adapter_if_to_axis_mux.tvalid && axis_adapter_if_to_axis_mux.tready) begin
                        //
                    end
                end
                STATE_TX_HEADER : begin
                end
                STATE_TX_ID : begin
                end
                STATE_TX_DATA : begin
                end
            endcase
        end
    end

    axis_adapter_wrapper axis_adapter_wrapper_inst (
        .clk(clk),
        .reset(reset),
        .in_axis_if(in_axis_if),
        .out_axis_if(axis_adapter_if_to_axis_mux)
    );
endmodule

`default_nettype wire