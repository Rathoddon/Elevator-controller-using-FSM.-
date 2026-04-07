`timescale 1ns/1ps

module tb_project_tvdc;

reg  [15:0] request_floor;
reg         clk, reset;
reg  [3:0]  human_entered;
reg         obstruct, power_cut;
wire [3:0]  current_floor;
wire [2:0]  current_state;
wire [15:0] pending_requests;

// State name function for readability
function [127:0] state_name;
    input [2:0] s;
    case (s)
        3'b000: state_name = "IDLE";
        3'b001: state_name = "MOVE_UP";
        3'b010: state_name = "MOVE_DOWN";
        3'b011: state_name = "DOOR_OPEN";
        3'b100: state_name = "DOOR_CLOSE";
        3'b101: state_name = "EMERGENCY";
        default:state_name = "UNKNOWN";
    endcase
endfunction

// DUT instantiation
project_tvdc uut (
    .request_floor(request_floor),
    .clk(clk),
    .reset(reset),
    .human_entered(human_entered),
    .obstruct(obstruct),
    .power_cut(power_cut),
    .current_floor(current_floor),
    .current_state(current_state),
    .pending_requests(pending_requests)
);

// Clock generation
initial begin
    clk = 0;
    forever #5 clk = ~clk; // 100 MHz clock
end

// Monitor signals
initial begin
    $monitor("t=%0t | state=%-10s | floor=%0d | pending=%016b | human=%0d | obs=%b | pwr=%b",
             $time, state_name(current_state), current_floor,
             pending_requests, human_entered, obstruct, power_cut);
end

// Stimulus
initial begin
    reset = 1; request_floor = 16'd0; human_entered = 0;
    obstruct = 0; power_cut = 0;
    #20; reset = 0;

    // TC1: Request floor 4 and 10
    #20;
    $display("\n=== TC1: REQUEST FLOORS 4, 10 ===");
    request_floor = 16'b000001000010000; #10; request_floor = 16'd0; // floor 4
    #400;

    // TC2: Request floor 2 and 1
    #20;
    $display("\n=== TC2: REQUEST FLOORS 2, 1 ===");
    request_floor = 16'b0000000000000110; #10; request_floor = 16'd0; // floor 21
    #300;

    // TC3: Overload
    #20;
    $display("\n=== TC3: OVERLOAD (human_entered=10) ===");
    human_entered = 4'd10;
    #60;
    human_entered = 4'd2;
    #40;

    // TC4: Door Obstruction
    #20;
    $display("\n=== TC4: DOOR OBSTRUCTION ===");
    obstruct = 1;
    #80; obstruct = 0;
    #40;

    // TC5: Power Cut
    #20;
    $display("\n=== TC5: POWER CUT ===");
    power_cut = 1;
    #80; power_cut = 0;
    #60;

    $display("\n=== Simulation finished ===");
    $finish;
end

endmodule
