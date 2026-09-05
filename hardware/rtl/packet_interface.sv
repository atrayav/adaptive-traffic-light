`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 09/05/2026 02:08:24 PM
// Design Name: 
// Module Name: packet_interface
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module packet_interface #(
    parameter logic [7:0] MAGIC = 8'hA5
)(
    input  logic        clk,
    input  logic        rst,

    input  logic        frame_start,
    input  logic [7:0]  rx_byte,
    input  logic        rx_valid,

    output logic [15:0] distance_mm,
    output logic        ped_button,
    output logic        sensor_valid_flag,
    output logic        packet_valid
);

    logic [2:0] byte_index;

    logic [7:0] magic_rx;
    logic [7:0] distance_hi;
    logic [7:0] distance_lo;
    logic [7:0] flags;

    logic [7:0] expected_checksum;

    always_comb begin
        expected_checksum =
            magic_rx ^
            distance_hi ^
            distance_lo ^
            flags;
    end

    always_ff @(posedge clk) begin

        if (rst) begin
            byte_index         <= 3'd0;

            magic_rx           <= 8'h00;
            distance_hi        <= 8'h00;
            distance_lo        <= 8'h00;
            flags              <= 8'h00;

            distance_mm        <= 16'd0;
            ped_button         <= 1'b0;
            sensor_valid_flag  <= 1'b0;
            packet_valid       <= 1'b0;
        end

        else begin
            packet_valid <= 1'b0;

            if (frame_start) begin
                byte_index <= 3'd0;
            end

            if (rx_valid) begin

                case (byte_index)

                    3'd0: begin
                        magic_rx <= rx_byte;
                    end

                    3'd1: begin
                        distance_hi <= rx_byte;
                    end

                    3'd2: begin
                        distance_lo <= rx_byte;
                    end

                    3'd3: begin
                        flags <= rx_byte;
                    end

                    3'd4: begin

                        if (
                            (magic_rx == MAGIC) &&
                            (rx_byte == expected_checksum)
                        ) begin

                            distance_mm <= {
                                distance_hi,
                                distance_lo
                            };

                            ped_button        <= flags[0];
                            sensor_valid_flag <= flags[1];

                            packet_valid <= 1'b1;
                        end

                    end

                    default: begin
                    end

                endcase

                if (byte_index < 3'd4)
                    byte_index <= byte_index + 1'b1;

            end
        end
    end

endmodule
