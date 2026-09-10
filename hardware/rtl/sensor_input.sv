`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 09/05/2026 02:16:58 PM
// Design Name: 
// Module Name: sensor_input
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


module sensor_input #(
    // Margin around a 300 mm target, with hysteresis to avoid chatter.
    parameter int unsigned ENTER_THRESHOLD_MM = 350,
    parameter int unsigned EXIT_THRESHOLD_MM  = 400,
    parameter int unsigned STALE_CYCLES       = 50_000_000
)(
    input  logic        clk,
    input  logic        rst,

    input  logic [15:0] distance_mm,
    input  logic        ped_button,
    input  logic        sensor_valid_flag,
    input  logic        packet_valid,

    output logic        vehicle_present,
    output logic        ped_request,
    output logic        sensor_valid
);

    logic [31:0] stale_counter;
    logic        previous_ped_button;

    always_ff @(posedge clk) begin

        if (rst) begin
            vehicle_present    <= 1'b0;
            ped_request        <= 1'b0;
            sensor_valid       <= 1'b0;

            stale_counter       <= 32'd0;
            previous_ped_button <= 1'b0;
        end

        else begin
            ped_request <= 1'b0;

            if (packet_valid) begin

                stale_counter <= 32'd0;

                if (sensor_valid_flag) begin
                    sensor_valid <= 1'b1;

                    if (
                        !vehicle_present &&
                        distance_mm != 16'd0 &&
                        {16'd0, distance_mm} <= ENTER_THRESHOLD_MM
                    ) begin
                        vehicle_present <= 1'b1;
                    end

                    else if (
                        vehicle_present &&
                        {16'd0, distance_mm} >= EXIT_THRESHOLD_MM
                    ) begin
                        vehicle_present <= 1'b0;
                    end

                    if (
                        ped_button &&
                        !previous_ped_button
                    ) begin
                        ped_request <= 1'b1;
                    end

                    previous_ped_button <= ped_button;
                end

                else begin
                    sensor_valid        <= 1'b0;
                    previous_ped_button <= 1'b0;
                end
            end

            else if (sensor_valid) begin

                if (
                    stale_counter >=
                    STALE_CYCLES - 1
                ) begin

                    sensor_valid        <= 1'b0;
                    previous_ped_button <= 1'b0;

                end

                else begin
                    stale_counter <= stale_counter + 1'b1;
                end

            end
        end
    end

endmodule
