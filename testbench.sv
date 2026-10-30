`timescale 1ns / 1ps

// Self-checking testbench: it checks the design by itself and prints
// PASSED or FAILED, so you do not have to judge the waveform by eye.
module tb_traffic_light;

    localparam GREEN_TIME  = 10;
    localparam YELLOW_TIME = 3;

    // {light_NS, light_EW}; each light is {Red, Yellow, Green}
    localparam [5:0] S0 = 6'b001_100;   // NS green,  EW red
    localparam [5:0] S1 = 6'b010_100;   // NS yellow, EW red
    localparam [5:0] S2 = 6'b100_001;   // NS red,    EW green
    localparam [5:0] S3 = 6'b100_010;   // NS red,    EW yellow

    reg        clk;
    reg        rst_n;
    wire [2:0] light_NS, light_EW;

    integer errors;        // number of failed checks
    integer transitions;   // number of state changes seen (proves checker was active)
    integer run;           // clock cycles spent in the current state
    reg [5:0] prev;
    reg       started;

    wire [5:0] cur = {light_NS, light_EW};

    // Device Under Test (DUT)
    traffic_light #(.GREEN_TIME(GREEN_TIME), .YELLOW_TIME(YELLOW_TIME)) dut (
        .clk(clk), .rst_n(rst_n),
        .light_NS(light_NS), .light_EW(light_EW)
    );

    // Clock: 10 ns period
    always #5 clk = ~clk;

    // Reference model: how long each state must last, and what comes next
    function integer expected_len(input [5:0] s);
        begin
            case (s)
                S0, S2:  expected_len = GREEN_TIME;
                default: expected_len = YELLOW_TIME;
            endcase
        end
    endfunction

    function [5:0] expected_next(input [5:0] s);
        begin
            case (s)
                S0:      expected_next = S1;
                S1:      expected_next = S2;
                S2:      expected_next = S3;
                default: expected_next = S0;
            endcase
        end
    endfunction

    // Checker: watches the lights at every clock edge
    always @(posedge clk) begin
        if (!rst_n) begin
            started = 0;
            run     = 0;
        end else begin
            // Check 1 (safety): never both green, and at least one red
            if (light_NS[0] && light_EW[0]) begin
                errors = errors + 1;
                $display("[FAIL] t=%0t both directions GREEN", $time);
            end
            if (!(light_NS[2] || light_EW[2])) begin
                errors = errors + 1;
                $display("[FAIL] t=%0t no direction is RED", $time);
            end

            if (!started) begin
                // Check 2: after reset we must start at S0
                if (cur !== S0) begin
                    errors = errors + 1;
                    $display("[FAIL] t=%0t did not start in S0, lights=%b", $time, cur);
                end
                prev = cur; run = 1; started = 1;
            end else if (cur === prev) begin
                run = run + 1;
            end else begin
                // Check 3: previous state lasted the right number of cycles
                if (run != expected_len(prev)) begin
                    errors = errors + 1;
                    $display("[FAIL] t=%0t state %b lasted %0d cycles, expected %0d",
                             $time, prev, run, expected_len(prev));
                end
                // Check 4: states follow the order S0 -> S1 -> S2 -> S3 -> S0
                if (cur !== expected_next(prev)) begin
                    errors = errors + 1;
                    $display("[FAIL] t=%0t wrong next state: %b -> %b", $time, prev, cur);
                end
                transitions = transitions + 1;
                prev = cur; run = 1;
            end
        end
    end

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, tb_traffic_light);

        clk = 0; rst_n = 0;
        errors = 0; transitions = 0; run = 0; prev = 0; started = 0;

        // Hold reset for 2 clock cycles, release on a falling edge
        repeat (2) @(negedge clk);
        rst_n = 1;

        // Test 1: normal operation for 3 full loops (26 cycles per loop)
        $display("--- Test 1: normal operation, 3 full loops ---");
        repeat (78) @(posedge clk);
        if (transitions < 8) begin
            errors = errors + 1;
            $display("[FAIL] only %0d state changes seen, checker not active", transitions);
        end

        // Test 2: reset in the middle of operation (while EW is green)
        $display("--- Test 2: reset applied in the middle of a cycle ---");
        @(posedge clk);
        while (light_EW !== 3'b001) @(posedge clk);
        #2 rst_n = 0;                       // reset arrives between clock edges
        #1;
        if (cur !== S0) begin               // async reset: must react immediately
            errors = errors + 1;
            $display("[FAIL] reset did not return lights to S0, lights=%b", cur);
        end
        @(negedge clk); @(negedge clk);
        rst_n = 1;

        // Test 3: design must recover and run normally after reset
        $display("--- Test 3: recovery after reset ---");
        repeat (30) @(posedge clk);

        if (errors == 0)
            $display(">>> TEST PASSED: all checks OK (%0d state changes checked) <<<", transitions);
        else
            $display(">>> TEST FAILED: %0d error(s) <<<", errors);
        $finish;
    end

endmodule
