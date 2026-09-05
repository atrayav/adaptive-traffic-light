`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 09/04/2026 03:51:16 PM
// Design Name: 
// Module Name: tb_crossing
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

module tb_crossing;

    // STATE VALUES
    //
    // These match the values used inside crossing_fsm.sv.
    // We define them here only so waveform/tests are readable.

    localparam logic [2:0] VEH_GREEN  = 3'd0;
    localparam logic [2:0] VEH_YELLOW = 3'd1;
    localparam logic [2:0] ALL_STOP   = 3'd2;
    localparam logic [2:0] PED_WALK   = 3'd3;
    localparam logic [2:0] PED_CLEAR  = 3'd4;


    // TEST TIMING PARAMETERS
    //
    // These are intentionally tiny.
    //
    // We do NOT want to simulate hundreds of millions of
    // cycles just to represent a few real-world seconds.

    localparam int MIN_GREEN_CYCLES   = 10;
    localparam int FIXED_GREEN_CYCLES = 15;
    localparam int MAX_WAIT_CYCLES    = 20;

    localparam int YELLOW_CYCLES      = 4;
    localparam int ALL_STOP_CYCLES    = 3;
    localparam int WALK_CYCLES        = 6;
    localparam int CLEAR_CYCLES       = 4;


    // =========================================================
    // INPUTS TO DUT
    // =========================================================

    logic clk;
    logic rst;

    logic vehicle_present;
    logic ped_request;
    logic sensor_valid;
    logic adaptive_mode;


    // OUTPUTS FROM DUT

    logic vehicle_red;
    logic vehicle_yellow;
    logic vehicle_green;

    logic ped_walk;

    logic       request_pending;
    logic [2:0] state_debug;


    // CLOCK GENERATION
    //
    // Arty A7 clock = 100 MHz
    //
    // 100 MHz -> period = 10 ns
    //
    // Therefore:
    //
    // HIGH for 5 ns
    // LOW  for 5 ns
    //
    // gives a 10 ns period.

    initial begin
        clk = 1'b0;
    end

    always #5 clk = ~clk;


    // DUT INSTANTIATION
    //
    // DUT = Device Under Test
    //
    // We instantiate the real crossing_fsm here, but override
    // its timer parameters with tiny simulation-friendly values.

    crossing_fsm #(

        .MIN_GREEN_CYCLES   (MIN_GREEN_CYCLES),
        .FIXED_GREEN_CYCLES (FIXED_GREEN_CYCLES),
        .MAX_WAIT_CYCLES    (MAX_WAIT_CYCLES),

        .YELLOW_CYCLES      (YELLOW_CYCLES),
        .ALL_STOP_CYCLES    (ALL_STOP_CYCLES),
        .WALK_CYCLES        (WALK_CYCLES),
        .CLEAR_CYCLES       (CLEAR_CYCLES)

    ) dut (

        .clk             (clk),
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


    // HELPER TASK: WAIT N CLOCK CYCLES
    //
    // A task is basically a reusable procedure in a testbench.

    task automatic wait_cycles(input int cycles);

        repeat (cycles) begin
            @(posedge clk);
        end

        // Give nonblocking assignments time to update.
        #1;

    endtask


    // HELPER TASK: RESET DUT

    task automatic reset_dut;

        begin

            rst = 1'b1;

            ped_request = 1'b0;

            wait_cycles(3);

            rst = 1'b0;

            wait_cycles(1);

        end

    endtask


    // HELPER TASK: PRESS PEDESTRIAN BUTTON
    //
    // Generates a request lasting one complete clock cycle.

    task automatic press_ped_button;

        begin

            @(negedge clk);
            ped_request = 1'b1;

            @(negedge clk);
            ped_request = 1'b0;

        end

    endtask



    // HELPER TASK: CHECK CURRENT STATE
    //
    // $fatal stops the simulation immediately if something
    // unexpected occurs.

    task automatic expect_state(
        input logic [2:0] expected_state,
        input string      message
    );

        begin

            #1;

            if (state_debug !== expected_state) begin

                $display(
                    "FAIL: %s | Expected state=%0d, Actual state=%0d",
                    message,
                    expected_state,
                    state_debug
                );

                $fatal;

            end

            else begin

                $display(
                    "PASS: %s",
                    message
                );

            end

        end

    endtask


    // HELPER TASK: WAIT UNTIL A STATE OCCURS
    //
    // Instead of guessing exactly when a transition occurs,
    // wait until it happens, but fail if it takes too long.

    task automatic wait_for_state(
        input logic [2:0] target_state,
        input int         timeout_cycles,
        input string      message
    );

        bit found;

        begin

            found = 1'b0;

            for (
                int i = 0;
                i < timeout_cycles && !found;
                i++
            ) begin

                @(posedge clk);
                #1;

                if (state_debug == target_state) begin
                    found = 1'b1;
                end

            end


            if (!found) begin

                $display(
                    "FAIL: Timeout waiting for %s",
                    message
                );

                $fatal;

            end

            else begin

                $display(
                    "PASS: Reached %s",
                    message
                );

            end

        end

    endtask


    // SAFETY CHECK
    //
    // This block runs EVERY CLOCK CYCLE.
    //
    // Vehicle green and pedestrian walk must never be active
    // simultaneously.

    always @(posedge clk) begin

        #1;

        if (vehicle_green && ped_walk) begin

            $display(
                "SAFETY FAILURE: vehicle GREEN and pedestrian WALK active together!"
            );

            $fatal;

        end

    end


    // MAIN TEST SEQUENCE

    initial begin

        // Starting values

        rst             = 1'b1;

        vehicle_present = 1'b0;
        ped_request     = 1'b0;

        sensor_valid    = 1'b1;

        adaptive_mode   = 1'b1;


        $display("");
        $display("========================================");
        $display(" STARTING CROSSING FSM TESTBENCH");
        $display("========================================");
        $display("");


        // TEST 1: RESET

        $display("");
        $display("TEST 1: RESET");
        $display("----------------------------");

        reset_dut();

        expect_state(
            VEH_GREEN,
            "Reset returns FSM to VEH_GREEN"
        );


        if (!vehicle_green) begin
            $fatal(
                "FAIL: vehicle_green should be HIGH after reset."
            );
        end

        if (vehicle_red) begin
            $fatal(
                "FAIL: vehicle_red should be LOW after reset."
            );
        end

        if (ped_walk) begin
            $fatal(
                "FAIL: ped_walk should be LOW after reset."
            );
        end

        $display(
            "PASS: Reset outputs are correct."
        );


        // TEST 2: REQUEST LATCH

        $display("");
        $display("TEST 2: PEDESTRIAN REQUEST LATCH");
        $display("----------------------------");

        reset_dut();

        // Keep a vehicle present so the FSM won't immediately
        // serve the request after minimum green.
        vehicle_present = 1'b1;

        press_ped_button();

        wait_cycles(2);


        if (!request_pending) begin

            $fatal(
                "FAIL: Pedestrian request was not latched."
            );

        end

        else begin

            $display(
                "PASS: Short pedestrian request was remembered."
            );

        end


        // TEST 3: ADAPTIVE MODE -- TRAFFIC GAP


        $display("");
        $display("TEST 3: ADAPTIVE GAP SERVICE");
        $display("----------------------------");

        reset_dut();

        adaptive_mode   = 1'b1;
        sensor_valid    = 1'b1;

        // No car/shoe present.
        vehicle_present = 1'b0;

        press_ped_button();


        // Request should NOT immediately interrupt vehicle green.
        wait_cycles(3);

        expect_state(
            VEH_GREEN,
            "Minimum vehicle green is enforced"
        );


        // Once minimum green expires and no vehicle exists,
        // the controller should begin the crossing sequence.
        wait_for_state(
            VEH_YELLOW,
            20,
            "VEH_YELLOW after traffic gap"
        );


        wait_for_state(
            ALL_STOP,
            10,
            "ALL_STOP"
        );


        wait_for_state(
            PED_WALK,
            10,
            "PED_WALK"
        );


        // Request should be cleared when WALK starts.
        if (request_pending) begin

            $fatal(
                "FAIL: request_pending should clear when WALK begins."
            );

        end

        else begin

            $display(
                "PASS: Request cleared when pedestrian crossing began."
            );

        end


        wait_for_state(
            PED_CLEAR,
            15,
            "PED_CLEAR"
        );


        wait_for_state(
            VEH_GREEN,
            15,
            "return to VEH_GREEN"
        );


        // TEST 4: ADAPTIVE MODE -- CONTINUOUS TRAFFIC

        $display("");
        $display("TEST 4: MAXIMUM PEDESTRIAN WAIT");
        $display("----------------------------");

        reset_dut();

        adaptive_mode   = 1'b1;
        sensor_valid    = 1'b1;

        // Pretend the shoe/car never leaves.
        vehicle_present = 1'b1;

        press_ped_button();


        // After minimum green, traffic is still present.
        // Therefore the controller should NOT immediately
        // transition.
        wait_cycles(12);

        expect_state(
            VEH_GREEN,
            "Continuous traffic delays crossing"
        );


        // But maximum wait must eventually force service.
        wait_for_state(
            VEH_YELLOW,
            20,
            "VEH_YELLOW after maximum wait"
        );


        wait_for_state(
            PED_WALK,
            20,
            "PED_WALK despite continuous traffic"
        );


        // TEST 5: FIXED MODE

        $display("");
        $display("TEST 5: FIXED-TIME MODE");
        $display("----------------------------");

        reset_dut();

        adaptive_mode   = 1'b0;
        sensor_valid    = 1'b1;

        // No vehicle present, but fixed mode should NOT care.
        vehicle_present = 1'b0;

        press_ped_button();


        wait_cycles(7);

        expect_state(
            VEH_GREEN,
            "Fixed mode ignores early traffic gap"
        );


        wait_for_state(
            VEH_YELLOW,
            15,
            "VEH_YELLOW after fixed green interval"
        );


        // TEST 6: INVALID SENSOR DATA

        $display("");
        $display("TEST 6: INVALID SENSOR DATA");
        $display("----------------------------");

        reset_dut();

        adaptive_mode   = 1'b1;

        sensor_valid    = 1'b0;
        vehicle_present = 1'b0;


        // Because sensor_valid = 0, this request should not
        // be accepted by the current FSM implementation.
        press_ped_button();

        wait_cycles(2);


        if (request_pending) begin

            $fatal(
                "FAIL: Invalid sensor data allowed a request to latch."
            );

        end

        else begin

            $display(
                "PASS: Request ignored while sensor data invalid."
            );

        end


        // Restore valid sensor information.
        sensor_valid = 1'b1;

        press_ped_button();

        wait_cycles(2);


        if (!request_pending) begin

            $fatal(
                "FAIL: Request not accepted after sensor became valid."
            );

        end

        else begin

            $display(
                "PASS: Request accepted after valid sensor data restored."
            );

        end


        // ALL TESTS FINISHED

        $display("");
        $display("========================================");
        $display(" ALL CROSSING FSM TESTS PASSED");
        $display("========================================");
        $display("");


        $finish;

    end


endmodule
