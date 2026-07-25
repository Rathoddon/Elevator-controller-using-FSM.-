# Elevator Controller using FSM

A 16-floor single-elevator controller implemented as a Moore-style finite
state machine in Verilog, handling floor requests, door timing, and three
independent emergency conditions (overload, door obstruction, power cut).

## Overview

The controller (`project_tvdc`) models a single elevator car serving 16
floors (0–15). Floor requests arrive as a one-hot 16-bit vector and are
latched into a sticky `pending_requests` register, so multiple requests
can queue up while the elevator is servicing another floor. The FSM scans
all pending requests each cycle to decide whether to move up, move down,
or open its doors, and continuously monitors three safety conditions that
can interrupt normal operation from any state.

## FSM States

| State | Encoding | Behavior |
|---|---|---|
| `IDLE` | `000` | Evaluates pending requests; decides direction or opens doors if there's a request at the current floor |
| `MOVE_UP` | `001` | Increments floor each cycle until a pending request is reached |
| `MOVE_DOWN` | `010` | Decrements floor each cycle until a pending request is reached |
| `DOOR_OPEN` | `011` | Holds open for a fixed timer duration (10 cycles), clearing the served request |
| `DOOR_CLOSE` | `100` | Transitional state before returning to `IDLE` |
| `EMERGENCY_MODE` | `101` | Entered from any state when overload, obstruction, or power cut is asserted; holds until the condition clears |

## Inputs / Outputs

| Signal | Direction | Width | Description |
|---|---|---|---|
| `clk`, `reset` | in | 1 | Clock and synchronous reset |
| `request_floor` | in | 16 | One-hot floor request vector |
| `human_entered` | in | 4 | Number of people currently in the car |
| `obstruct` | in | 1 | Door obstruction sensor |
| `power_cut` | in | 1 | Power-loss signal |
| `current_floor` | out | 4 | Current floor (0–15) |
| `current_state` | out | 3 | Current FSM state |
| `pending_requests` | out | 16 | Sticky request register (visible for waveform debugging) |

## Key Design Behaviors

- **Sticky requests**: `pending_requests` latches every incoming request
  via `pending_requests <= pending_requests | request_floor`, so a
  request isn't lost if it arrives while the elevator is mid-transit
  serving a different floor.
- **Directional scan**: on every cycle, the FSM scans all 16 bits of
  `pending_requests` to determine whether any request exists above or
  below the current floor (`has_above` / `has_below`), and picks a
  direction accordingly.
- **Overload detection**: `overload = (human_entered > 7)` — capacity is
  fixed at 7 occupants.
- **Unified emergency handling**: overload, obstruction, and power cut
  are OR'd into a single `emergency_state` flag, checked from every
  operational state, so any of the three conditions interrupts normal
  service and forces a transition to `EMERGENCY_MODE`. The controller
  returns to `IDLE` automatically once the condition clears.
- **Door timing**: a 4-bit `door_timer` counts cycles while in
  `DOOR_OPEN`; the door closes once the timer reaches 10.

## Repository Contents

| File | Description |
|---|---|
| `project_tvdc.v` | Elevator controller FSM (design source) |
| `tb_project_tvdc.v` | Testbench — five test cases covering normal requests, overload, obstruction, and power cut |

## Test Cases (from `tb_project_tvdc`)

| TC | Scenario | What it verifies |
|---|---|---|
| TC1 | Request floors 4 and 10 | Multi-floor request queueing, correct `MOVE_UP` sequencing, door timing per stop |
| TC2 | Request floors 2 and 1 | `MOVE_DOWN` sequencing, servicing two adjacent-direction requests in order |
| TC3 | `human_entered = 10` (capacity is 7) | Overload correctly forces `EMERGENCY_MODE`; clears once occupancy drops |
| TC4 | Door obstruction asserted | Obstruction correctly forces `EMERGENCY_MODE` from `IDLE` |
| TC5 | Power cut asserted | Power-loss handling forces `EMERGENCY_MODE` regardless of current activity |

## Sample Simulation Output
