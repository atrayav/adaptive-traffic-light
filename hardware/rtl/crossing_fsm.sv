`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 09/03/2026 07:32:18 PM
// Design Name: 
// Module Name: crossing_fsm
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


module crossing_fsm #(
    // Timing parameters
    //
    // During simulation, use very small values.
    // During hardware implementation, override these with
    // values based on the 100 MHz Arty clock.

    parameter int unsigned MIN_GREEN_CYCLES   = 50,
    parameter int unsigned FIXED_GREEN_CYCLES = 100,
    parameter int unsigned MAX_WAIT_CYCLES    = 150,

    parameter int unsigned YELLOW_CYCLES      = 20,
    parameter int unsigned ALL_STOP_CYCLES    = 10,
    parameter int unsigned WALK_CYCLES        = 40,
    parameter int unsigned CLEAR_CYCLES       = 20

)(
    input  logic clk,
    input  logic rst,

    // Inputs from rest of FPGA system

    // 1 = vehicle/shoe currently detected
    input  logic vehicle_present,

    // Pulse/high level indicating pedestrian button press
    input  logic ped_request,

    // 1 = most recent sensor/packet information is trustworthy
    input  logic sensor_valid,

    // 1 = adaptive traffic mode
    // 0 = fixed timing mode
    input  logic adaptive_mode,

    // Traffic outputs

    output logic vehicle_red,
    output logic vehicle_yellow,
    output logic vehicle_green,

    output logic ped_walk,

    // Debug outputs

    output logic       request_pending,
    output logic [2:0] state_debug
);


    // STATE DEFINITIONS

    typedef enum logic [2:0] {

        VEH_GREEN  = 3'd0,
        VEH_YELLOW = 3'd1,
        ALL_STOP   = 3'd2,
        PED_WALK   = 3'd3,
        PED_CLEAR  = 3'd4

    } state_t;


    state_t state;
    state_t next_state;

    // COUNTERS

    logic [31:0] phase_counter;
    logic [31:0] request_wait_counter;


    // TIMER DONE SIGNALS

    logic min_green_done;
    logic fixed_green_done;
    logic max_wait_done;

    logic yellow_done;
    logic all_stop_done;
    logic walk_done;
    logic clear_done;

    // STATE REGISTER

    always_ff @(posedge clk) begin

        if (rst) begin
            state <= VEH_GREEN;
        end

        else begin
            state <= next_state;
        end

    end


    // PEDESTRIAN REQUEST LATCH
    //
    // A short button press is remembered until the request
    // is actually served.
    //
    // We only accept new requests during VEH_GREEN.
    //
    // This prevents repeated presses during WALK/CLEAR from
    // accidentally creating another immediate crossing.
    
    always_ff @(posedge clk) begin

        if (rst) begin

            request_pending <= 1'b0;

        end

        else begin

            // Clear request as we ENTER pedestrian WALK.
            if ((state != PED_WALK) &&
                (next_state == PED_WALK)) begin

                request_pending <= 1'b0;

            end

            // Otherwise latch a valid pedestrian request.
            else if (
                (state == VEH_GREEN) &&
                sensor_valid &&
                ped_request
            ) begin

                request_pending <= 1'b1;

            end

        end

    end


    // PHASE COUNTER
    //
    // Tracks how long the controller has been in its
    // current traffic state.
    //
    // Reset whenever the FSM changes state.

    always_ff @(posedge clk) begin

        if (rst) begin

            phase_counter <= 32'd0;

        end

        else if (state != next_state) begin

            phase_counter <= 32'd0;

        end

        else begin

            phase_counter <= phase_counter + 1'b1;

        end

    end


    // PEDESTRIAN WAIT COUNTER
    //
    // Tracks how long a pedestrian request has been waiting
    // while vehicles have the green phase.
    //
    // Used to guarantee a bounded maximum wait.

    always_ff @(posedge clk) begin

        if (rst) begin

            request_wait_counter <= 32'd0;

        end

        else if (!request_pending) begin

            request_wait_counter <= 32'd0;

        end

        else if (state == VEH_GREEN) begin

            request_wait_counter <= request_wait_counter + 1'b1;

        end

    end


    // TIMER COMPARISONS
    //
    // Using >= instead of == makes the logic more robust if
    // a counter somehow passes the exact threshold.

    always_comb begin

        min_green_done =
            (phase_counter >= MIN_GREEN_CYCLES - 1);

        fixed_green_done =
            (phase_counter >= FIXED_GREEN_CYCLES - 1);

        max_wait_done =
            (request_wait_counter >= MAX_WAIT_CYCLES - 1);

        yellow_done =
            (phase_counter >= YELLOW_CYCLES - 1);

        all_stop_done =
            (phase_counter >= ALL_STOP_CYCLES - 1);

        walk_done =
            (phase_counter >= WALK_CYCLES - 1);

        clear_done =
            (phase_counter >= CLEAR_CYCLES - 1);

    end


    // NEXT-STATE LOGIC

    always_comb begin

        // Default:
        // stay in current state.
        next_state = state;


        case (state)

            // VEHICLE GREEN

            VEH_GREEN: begin

                // Adaptive mode
                //
                // Requirements:
                //
                // 1. A pedestrian request must exist.
                // 2. Minimum vehicle green must be completed.
                // 3. Sensor data must be valid.
                // 4. Then transition if:
                //      - there is a traffic gap
                //        OR
                //      - pedestrian maximum wait expired

                if (adaptive_mode) begin

                    if (
                        request_pending       &&
                        sensor_valid          &&
                        min_green_done        &&
                        (
                            !vehicle_present  ||
                            max_wait_done
                        )
                    ) begin

                        next_state = VEH_YELLOW;

                    end

                end


                // Fixed mode
                //
                // Ignores vehicle presence.
                //
                // A pedestrian request is served only after the
                // predetermined fixed green period expires.

                else begin

                    if (
                        request_pending &&
                        fixed_green_done
                    ) begin

                        next_state = VEH_YELLOW;

                    end

                end

            end


            // VEHICLE YELLOW

            VEH_YELLOW: begin

                if (yellow_done) begin

                    next_state = ALL_STOP;

                end

            end


            // ALL STOP
            //
            // Provides safety interval between vehicle traffic
            // stopping and pedestrian WALK beginning.

            ALL_STOP: begin

                if (all_stop_done) begin

                    next_state = PED_WALK;

                end

            end

            // PEDESTRIAN WALK

            PED_WALK: begin

                if (walk_done) begin

                    next_state = PED_CLEAR;

                end

            end


            // PEDESTRIAN CLEARANCE

            PED_CLEAR: begin

                if (clear_done) begin

                    next_state = VEH_GREEN;

                end

            end


            // FAIL-SAFE DEFAULT

            default: begin

                next_state = VEH_GREEN;

            end

        endcase

    end


    // OUTPUT DECODER
    //
    // Moore FSM:
    // outputs depend only on current state.

    always_comb begin

        // Safe defaults
        vehicle_red    = 1'b0;
        vehicle_yellow = 1'b0;
        vehicle_green  = 1'b0;
        ped_walk       = 1'b0;


        case (state)

            // Vehicles may proceed

            VEH_GREEN: begin

                vehicle_green = 1'b1;

            end


            // Vehicle clearance warning

            VEH_YELLOW: begin

                vehicle_yellow = 1'b1;

            end


            // Nobody proceeds

            ALL_STOP: begin

                vehicle_red = 1'b1;

            end


            // Vehicles stopped, pedestrian may cross

            PED_WALK: begin

                vehicle_red = 1'b1;
                ped_walk    = 1'b1;

            end


            // Pedestrian clearance interval

            PED_CLEAR: begin

                vehicle_red = 1'b1;

            end


            // Should never occur

            default: begin

                vehicle_red = 1'b1;

            end

        endcase

    end


    // DEBUG STATE OUTPUT

    assign state_debug = state;


endmodule