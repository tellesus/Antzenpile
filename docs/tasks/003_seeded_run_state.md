# 003 — Seeded RunState

Status: implemented and verified (2026-09-28).

## Goal

Create an isolated run that owns its seed, RNG, scenario identity, and clock.

## Why this exists

A reproducible run is the foundation for debugging, tests, and later saves.

## Dependencies

[002](002_simulation_clock.md); read [ARCHITECTURE](../ARCHITECTURE.md), [DATA_MODEL](../DATA_MODEL.md), and [CODING_RULES](../CODING_RULES.md).

## Allowed scope

`src/core/run_state.gd`, minimal run lifecycle/SimulationController composition, focused tests. Main may create/dispose a run without presenting gameplay.

## Required behavior

1. Implement typed lightweight RunState initialized with an explicit integer seed and scenario ID (foundation default `backyard_slice`). Create its own seeded RandomNumberGenerator and SimulationClock; expose simulation_time through that clock only.
2. Fresh runs share no mutable RNG/clock/container state. Creation/reset with the same seed and scenario reproduces the same initial state.
3. Establish the API for deterministic gameplay draws; prohibit global unseeded randomness and wall-clock-derived gameplay state. Decorative randomness stays outside this API.
4. Provide an explicit in-memory snapshot/restore for implemented fields only: version, scenario, seed, current RNG state, clock count/time/remainder/pause/scale. Restore state without drawing randomness. Preserve integer values losslessly; do not build a disk SaveService.
5. Leave future world/colony/knowledge/trail ownership documented but absent or empty; no placeholder implementations. Validate snapshot version and clock consistency before replacing state.

## Explicit non-goals

No world generation, nodes, workers, scouts, save UI, disk saves, or new gameplay systems. Do not implement future systems not explicitly requested.

## Interfaces to preserve

RunState owns the active run; SimulationController advances its clock. This must work outside the scene tree. Definitions will be shared immutable content; runtime data belongs to a single run.

## Acceptance tests

- Two seed-482817 runs produce identical sequences of 100 draws and clock steps. A different fixed seed produces a different test sequence.
- Advance/draw from one run: another run remains unchanged. Recreate a run: initial sequence repeats.
- Snapshot after 20 draws and a fractional clock advance; restore and compare the next 100 draws/steps with uninterrupted continuation, including time/remainder.
- Mutating the returned snapshot cannot mutate the live run. Invalid snapshot version is rejected without partially replacing the current run.

## Manual verification

Run headless tests and boot Main. Confirm repeatable diagnostic seed/scenario/time output across restart, without graphics or gameplay being required.

## Done when

Isolation and reproducibility pass; ownership/snapshot contracts and handoff are recorded. One logical commit; next task 004.

## Handoff

- Added RunState, run-scoped SimulationController and Main composition; clock owns time and supports validated restoration.
- Snapshots use decimal strings for 64-bit seed/RNG state and tick counts. Restoration validates before mutation and does not draw randomness.
- Verified import, headless Main, and 249 checks with zero failures: repeated seeds, isolated runs, JSON round trip, 100-step continuation, detached snapshots, invalid version/time/integer rejection.
- No world generation or disk save service. Next: 004.
