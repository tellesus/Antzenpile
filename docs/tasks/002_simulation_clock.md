# 002 — Simulation clock

Status: implemented and verified (2026-09-28).

## Goal

Provide the single authoritative fixed-tick clock with pause and 1×/4×/16×/64× speeds.

## Why this exists

Simulation behavior must be independent of render-frame timing and compression speed.

## Dependencies

[001](001_project_bootstrap.md); read [ARCHITECTURE](../ARCHITECTURE.md), [CODING_RULES](../CODING_RULES.md), and decision A03.

## Allowed scope

`src/core/simulation_clock.gd`, focused clock tests registered with the runner, and minimal controller integration only if needed to prove ticking. No player HUD is required.

## Required behavior

1. Implement a lightweight clock with tick_interval = 0.25 simulated seconds, paused, time_scale, tick_count, simulation_time, and fractional accumulator. Start at time 0, unpaused, 1×.
2. Expose an `advance(real_delta)` equivalent and a fixed-step callback/signal. For valid elapsed time, accumulate `real_delta * time_scale`, emit one step per full interval, increment tick count/time exactly once per step, retain the remainder.
3. Pause emits no ticks and adds no paused elapsed time; preserve the pre-pause fractional remainder. Resuming causes no paused-time catch-up.
4. Accept only the four supported scales; reject negative/non-finite delta or invalid scale without changing state. A zero delta does nothing. Reset clears count/time/remainder and restores initial pause/speed defaults.
5. Do not silently discard a long frame's accumulated simulation time. A future bounded catch-up loop must retain backlog. Systems will receive 0.25-second steps, never a scaled variable step.

## Explicit non-goals

No gameplay systems, RNG, save files, time-control HUD, real-time calendars, or slow-system scheduling framework. Do not implement future systems not explicitly requested.

## Interfaces to preserve

SimulationClock owns time. Task 003 will give ownership to RunState and expose a reference; callers must not maintain competing clocks. No dependency on scene rendering or Input.

## Acceptance tests

- Advance 1 second at each speed: 4/16/64/256 ticks and 1/4/16/64 simulated seconds, respectively.
- Compare 64 simulated seconds at every scale: 256 equal fixed steps and equal resulting time.
- Advance 0.125 twice at 1×: zero then one tick. Compare one 1-second input with eight 0.125-second inputs.
- Pause after 0.125 seconds, advance 10 real seconds, resume and advance 0.125: exactly one tick total. Invalid inputs leave all state unchanged. Reset matches a new clock.

## Manual verification

Run the headless suite and a brief diagnostic print of tick counts at each speed. Main still boots; no clock UI is needed.

## Done when

Tests pass with no view instantiated, clock ownership is documented, and handoff records files/results/limitations. One logical commit; next task 003.

## Handoff

- Added lightweight SimulationClock and focused tests; strengthened runner to fail if a suite aborts before completion.
- Fixed 0.25-second steps, validated speeds/deltas, pause/reset, retained fractional time. Catch-up is bounded to 4,096 ticks per advance with backlog retained.
- Headless suite: 39 checks, 0 failures. All four speeds produced 256 ticks for 64 simulated seconds. Invalid inputs, pause/remainder, reset and backlog checked.
- No gameplay/UI added. Next: 003.
