`timescale 1ns / 1ps

// Traffic light controller for a 4-way intersection.
// Moore FSM: the lights depend only on the current state.
// Time is counted in clock cycles (not seconds).
module traffic_light #(
    parameter GREEN_TIME  = 10,   // clock cycles a green light stays on
    parameter YELLOW_TIME = 3     // clock cycles a yellow light stays on
)(
    input  wire      clk,
    input  wire      rst_n,       // active-low reset: 0 = reset, 1 = run
    output reg [2:0] light_NS,    // {Red, Yellow, Green} for North-South
    output reg [2:0] light_EW     // {Red, Yellow, Green} for East-West
);

    // The 4 states
    localparam [1:0] S0_NS_GREEN  = 2'b00;
    localparam [1:0] S1_NS_YELLOW = 2'b01;
    localparam [1:0] S2_EW_GREEN  = 2'b10;
    localparam [1:0] S3_EW_YELLOW = 2'b11;

    reg [1:0] state;   // memory: which state we are in
    reg [7:0] timer;   // counts clock cycles spent in the current state

    // Sequential block: state register + timer (non-blocking <=)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S0_NS_GREEN;
            timer <= 8'd0;
        end else begin
            case (state)
                S0_NS_GREEN: begin
                    if (timer == GREEN_TIME - 1) begin
                        state <= S1_NS_YELLOW;
                        timer <= 8'd0;
                    end else
                        timer <= timer + 1'b1;
                end
                S1_NS_YELLOW: begin
                    if (timer == YELLOW_TIME - 1) begin
                        state <= S2_EW_GREEN;
                        timer <= 8'd0;
                    end else
                        timer <= timer + 1'b1;
                end
                S2_EW_GREEN: begin
                    if (timer == GREEN_TIME - 1) begin
                        state <= S3_EW_YELLOW;
                        timer <= 8'd0;
                    end else
                        timer <= timer + 1'b1;
                end
                S3_EW_YELLOW: begin
                    if (timer == YELLOW_TIME - 1) begin
                        state <= S0_NS_GREEN;
                        timer <= 8'd0;
                    end else
                        timer <= timer + 1'b1;
                end
                default: begin
                    state <= S0_NS_GREEN;
                    timer <= 8'd0;
                end
            endcase
        end
    end

    // Combinational block: decode state into lights (blocking =)
    always @(*) begin
        case (state)
            S0_NS_GREEN:  begin light_NS = 3'b001; light_EW = 3'b100; end
            S1_NS_YELLOW: begin light_NS = 3'b010; light_EW = 3'b100; end
            S2_EW_GREEN:  begin light_NS = 3'b100; light_EW = 3'b001; end
            S3_EW_YELLOW: begin light_NS = 3'b100; light_EW = 3'b010; end
            default:      begin light_NS = 3'b100; light_EW = 3'b100; end
        endcase
    end

endmodule
