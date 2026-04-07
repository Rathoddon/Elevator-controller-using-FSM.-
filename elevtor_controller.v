`timescale 1ns/1ps

module project_tvdc(
    input  [15:0] request_floor,   // one-hot request vector (16 floors)
    input         clk, reset,
    input  [3:0]  human_entered,
    input         obstruct, power_cut,
    output reg [3:0] current_floor,   // current floor (0-15)
    output reg [2:0] current_state,   // FSM state
    output reg [15:0] pending_requests // sticky requests, visible in waveform
);

parameter IDLE           = 3'b000;
parameter MOVE_UP        = 3'b001;
parameter MOVE_DOWN      = 3'b010;
parameter DOOR_OPEN      = 3'b011;
parameter DOOR_CLOSE     = 3'b100;
parameter EMERGENCY_MODE = 3'b101;
parameter human_capacity = 4'd7;

reg overload, emergency_state;
reg [3:0] door_timer;
reg [2:0] next_state;
reg [3:0] next_floor;
integer j; // loop index
reg has_above, has_below; // flags

// Sequential block: update registers
always @(posedge clk or posedge reset) begin
    if (reset) begin
        current_state    <= IDLE;
        current_floor    <= 4'd0;
        pending_requests <= 16'd0;
    end else begin
        current_state <= next_state;
        current_floor <= next_floor;

        // latch new requests (sticky until served)
        pending_requests <= pending_requests | request_floor;

        // clear served request after door cycle
        if (current_state == DOOR_CLOSE && next_state != DOOR_OPEN)
            pending_requests[current_floor] <= 1'b0;
        if (pending_requests == (1 << current_floor))
            pending_requests <= 16'd0;
    end
end

// Combinational block: FSM transitions
always @(*) begin
    next_state = current_state;
    next_floor = current_floor;

    overload = (human_entered > human_capacity);
    emergency_state = overload | obstruct | power_cut;

    // default flags
    has_above = 0;
    has_below = 0;

    // scan all floors safely
    for (j = 0; j < 16; j = j + 1) begin
        if (j > current_floor && pending_requests[j]) has_above = 1;
        if (j < current_floor && pending_requests[j]) has_below = 1;
    end

    case (current_state)
        IDLE: begin
            if (emergency_state)
                next_state = EMERGENCY_MODE;
            else if (pending_requests[current_floor])
                next_state = DOOR_OPEN;
            else if (has_above)
                next_state = MOVE_UP;
            else if (has_below)
                next_state = MOVE_DOWN;
        end

        MOVE_UP: begin
            if (emergency_state) next_state = EMERGENCY_MODE;
            else begin
                if (current_floor < 15)
                    next_floor = current_floor + 1;
                if (pending_requests[next_floor])
                    next_state = DOOR_OPEN;
            end
        end

        MOVE_DOWN: begin
            if (emergency_state) next_state = EMERGENCY_MODE;
            else begin
                if (current_floor > 0)
                    next_floor = current_floor - 1;
                if (pending_requests[next_floor])
                    next_state = DOOR_OPEN;
            end
        end

        DOOR_OPEN: begin
            if (emergency_state) next_state = EMERGENCY_MODE;
            else if (door_timer >= 4'd10) next_state = DOOR_CLOSE;
        end

        DOOR_CLOSE: begin
            if (emergency_state) next_state = EMERGENCY_MODE;
            else next_state = IDLE;
        end

        EMERGENCY_MODE: begin
            if (!emergency_state) next_state = IDLE;
        end
    endcase
end

// Door timer
always @(posedge clk or posedge reset) begin
    if (reset) door_timer <= 4'd0;
    else if (current_state == DOOR_OPEN) door_timer <= door_timer + 1;
    else door_timer <= 4'd0;
end

endmodule
