`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 09/03/2026 12:13:17 PM
// Design Name: 
// Module Name: top
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


module top (
    input  logic       CLK100MHZ,

    input  logic [1:0] sw,
    input  logic [1:0] btn,

    input  logic       CK_SCK,
    input  logic       CK_SS,
    input  logic       CK_MOSI,
    output logic       CK_MISO,

    output logic [3:0] led
);

    localparam int unsigned CLK_FREQ_HZ = 100_000_000;


    logic btn0_meta;
    logic rst;

    logic sw1_meta;
    logic adaptive_mode;


    logic [7:0] rx_byte;
    logic       rx_valid;
    logic       frame_start;
    logic       frame_end;


    logic [15:0] distance_mm;
    logic        ped_button;
    logic        sensor_valid_flag;
    logic        packet_valid;


    logic vehicle_present;
    logic ped_request;
    logic sensor_valid;


    logic vehicle_red;
    logic vehicle_yellow;
    logic vehicle_green;
    logic ped_walk;

    logic       request_pending;
    logic [2:0] state_debug;


    logic [7:0] status_byte;
    
    assign status_byte = {
    1'b1,              // bit 7: response marker
    vehicle_red,       // bit 6
    vehicle_yellow,    // bit 5
    vehicle_green,     // bit 4
    ped_walk,          // bit 3
    request_pending,   // bit 2
    sensor_valid,      // bit 1
    vehicle_present    // bit 0
};


    always_ff @(posedge CLK100MHZ) begin

        btn0_meta <= btn[0];
        rst       <= btn0_meta;

        sw1_meta      <= sw[1];
        adaptive_mode <= sw1_meta;

    end


    spi_slave u_spi_slave (
        .clk         (CLK100MHZ),
        .rst         (rst),

        .spi_sck     (CK_SCK),
        .spi_cs_n    (CK_SS),
        .spi_mosi    (CK_MOSI),
        .spi_miso    (CK_MISO),

        .tx_byte     (status_byte),

        .rx_byte     (rx_byte),
        .rx_valid    (rx_valid),
        .frame_start (frame_start),
        .frame_end   (frame_end)
    );


    packet_interface u_packet_interface (
        .clk               (CLK100MHZ),
        .rst               (rst),

        .frame_start       (frame_start),
        .rx_byte           (rx_byte),
        .rx_valid          (rx_valid),

        .distance_mm       (distance_mm),
        .ped_button        (ped_button),
        .sensor_valid_flag (sensor_valid_flag),
        .packet_valid      (packet_valid)
    );


    sensor_input #(
        .ENTER_THRESHOLD_MM (350),
        .EXIT_THRESHOLD_MM  (400),
        .STALE_CYCLES       (50_000_000)
    ) u_sensor_input (
        .clk               (CLK100MHZ),
        .rst               (rst),

        .distance_mm       (distance_mm),
        .ped_button        (ped_button),
        .sensor_valid_flag (sensor_valid_flag),
        .packet_valid      (packet_valid),

        .vehicle_present   (vehicle_present),
        .ped_request       (ped_request),
        .sensor_valid      (sensor_valid)
    );


    crossing_fsm #(
        .MIN_GREEN_CYCLES   (3 * CLK_FREQ_HZ),
        .FIXED_GREEN_CYCLES (8 * CLK_FREQ_HZ),
        .MAX_WAIT_CYCLES    (10 * CLK_FREQ_HZ),

        .YELLOW_CYCLES      (2 * CLK_FREQ_HZ),
        .ALL_STOP_CYCLES    (1 * CLK_FREQ_HZ),
        .WALK_CYCLES        (5 * CLK_FREQ_HZ),
        .WALK_EXTENSION_CYCLES (3 * CLK_FREQ_HZ),
        .CLEAR_CYCLES       (2 * CLK_FREQ_HZ)
    ) u_crossing_fsm (
        .clk             (CLK100MHZ),
        .rst             (rst),

        .vehicle_present (vehicle_present),
        .ped_request     (ped_request),
        .sensor_valid    (sensor_valid),
        .adaptive_mode   (adaptive_mode),

        .vehicle_red     (vehicle_red),
        .vehicle_yellow  (vehicle_yellow),
        .vehicle_green   (vehicle_green),
        .ped_walk        (ped_walk),

        .request_pending (request_pending),
        .state_debug     (state_debug)
    );


    assign led[0] = vehicle_green;
    assign led[1] = vehicle_yellow;
    assign led[2] = vehicle_red;
    assign led[3] = ped_walk;

endmodule
