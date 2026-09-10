`timescale 1ns / 1ps

// Regression tests for 300 mm detection and button-driven WALK extensions.
module tb_updates;
    logic clk = 0;
    always #5 clk = ~clk;
    logic rst = 1;
    logic [15:0] distance_mm = 0;
    logic ped_button = 0, sensor_valid_flag = 0, packet_valid = 0;
    logic detected, button_edge, reading_valid;

    sensor_input #(.STALE_CYCLES(8)) sensor (
        .clk(clk), .rst(rst), .distance_mm(distance_mm),
        .ped_button(ped_button), .sensor_valid_flag(sensor_valid_flag),
        .packet_valid(packet_valid), .vehicle_present(detected),
        .ped_request(button_edge), .sensor_valid(reading_valid)
    );

    logic vehicle_present = 0, ped_request = 0, sensor_valid = 1;
    logic adaptive_mode = 1;
    logic red, yellow, green, walk, pending;
    logic [2:0] state;
    localparam int WALK = 8;
    localparam int EXTENSION = 3;

    crossing_fsm #(
        .MIN_GREEN_CYCLES(2), .FIXED_GREEN_CYCLES(3),
        .MAX_WAIT_CYCLES(4), .YELLOW_CYCLES(2), .ALL_STOP_CYCLES(2),
        .WALK_CYCLES(WALK), .WALK_EXTENSION_CYCLES(EXTENSION),
        .CLEAR_CYCLES(2)
    ) fsm (
        .clk(clk), .rst(rst), .vehicle_present(vehicle_present),
        .ped_request(ped_request), .sensor_valid(sensor_valid),
        .adaptive_mode(adaptive_mode), .vehicle_red(red),
        .vehicle_yellow(yellow), .vehicle_green(green), .ped_walk(walk),
        .request_pending(pending), .state_debug(state)
    );

    task automatic tick;
        @(posedge clk); #1;
    endtask

    task automatic reset_all;
        @(negedge clk);
        rst = 1; ped_request = 0; packet_valid = 0;
        vehicle_present = 0; sensor_valid = 1;
        repeat (2) tick();
        @(negedge clk); rst = 0;
    endtask

    task automatic sample(input int mm, input bit button, input bit valid_flag);
        @(negedge clk);
        distance_mm = 16'(mm); ped_button = button;
        sensor_valid_flag = valid_flag; packet_valid = 1;
        tick();
        @(negedge clk); packet_valid = 0;
    endtask

    // A press on cycle WALK is a press on the exact original expiry cycle.
    task automatic walk_trial(input bit mode, input int first_press,
                              input int second_press, input bit car,
                              input bit valid_data, input int expected_cycles);
        int elapsed;
        reset_all();
        adaptive_mode = mode;
        ped_request = 1;
        tick();
        @(negedge clk); ped_request = 0;
        while (!walk) tick();
        elapsed = 0;
        while (walk && elapsed < 40) begin
            @(negedge clk);
            vehicle_present = car;
            sensor_valid = valid_data;
            ped_request = ((elapsed + 1) == first_press) ||
                          ((elapsed + 1) == second_press);
            tick();
            elapsed++;
            if (pending) $fatal(1, "WALK press queued another crossing");
        end
        if (elapsed != expected_cycles || state != 4)
            $fatal(1, "WALK duration: expected %0d, got %0d, state %0d",
                   expected_cycles, elapsed, state);
        @(negedge clk); ped_request = 0;
        repeat (2) tick();
        if (!green) $fatal(1, "Clearance duration changed");
        repeat (6) tick();
        if (!green || pending) $fatal(1, "Unexpected subsequent crossing");
    endtask

    always @(posedge clk) begin
        #2;
        if (!rst && ((green && walk) || (walk && !red)))
            $fatal(1, "Conflicting traffic outputs");
    end

    initial begin
        // Watchdog prevents a broken transition from hanging the regression.
        #100000;
        $fatal(1, "Regression timed out");
    end

    initial begin
        reset_all();
        sample(500, 0, 1);
        if (detected || !reading_valid) $fatal(1, "Far target should be clear");
        sample(300, 0, 1);
        if (!detected) $fatal(1, "300 mm must detect from clear");
        sample(375, 0, 1);
        if (!detected) $fatal(1, "Presence must persist in hysteresis band");
        sample(400, 0, 1);
        if (detected) $fatal(1, "400 mm must clear");
        sample(375, 0, 1);
        if (detected) $fatal(1, "Clear must persist in hysteresis band");
        sample(350, 0, 1);
        if (!detected) $fatal(1, "350 mm entry boundary must detect");
        sample(500, 0, 1);
        sample(310, 0, 1);
        if (!detected) $fatal(1, "Readings around 300 mm need margin");
        sample(500, 0, 1);
        sample(0, 0, 1);
        if (detected) $fatal(1, "Zero distance must not detect");
        sample(300, 0, 0);
        if (reading_valid || detected) $fatal(1, "Invalid reading changed presence");

        sample(500, 1, 1);
        if (!button_edge) $fatal(1, "Fresh press must produce pulse");
        sample(500, 1, 1);
        if (button_edge) $fatal(1, "Held button repeated pulse");
        sample(500, 0, 1);
        sample(500, 1, 1);
        if (!button_edge) $fatal(1, "Second press must produce pulse");
        repeat (9) tick();
        if (reading_valid) $fatal(1, "Stale sensor must become invalid");
        $display("PASS: thresholds, hysteresis, validity, and fresh button edges");

        walk_trial(1, 0, 0, 0, 1, WALK);
        walk_trial(1, WALK-1, 0, 0, 1, WALK+EXTENSION);
        walk_trial(1, WALK, 0, 0, 1, WALK+EXTENSION);
        walk_trial(1, 2, WALK+EXTENSION, 0, 1, WALK+2*EXTENSION);
        walk_trial(0, WALK, 0, 0, 1, WALK+EXTENSION);
        walk_trial(1, WALK, 0, 1, 1, WALK);
        walk_trial(1, WALK, 0, 0, 0, WALK);
        $display("PASS: baseline, late/final-cycle/repeated extensions, both modes, blocked extensions");

        // Reset during an extended WALK must discard all extra time.
        reset_all();
        ped_request = 1; tick();
        @(negedge clk); ped_request = 0;
        while (!walk) tick();
        @(negedge clk); ped_request = 1; tick();
        reset_all(); tick();
        if (!green || walk || pending) $fatal(1, "Reset failed during extension");
        walk_trial(1, 0, 0, 0, 1, WALK);
        $display("ALL UPDATE REGRESSIONS PASSED");
        $finish;
    end
endmodule
