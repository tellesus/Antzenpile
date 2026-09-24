# 007 — Scout mission and ScoutAgent

Status: roadmap; expand against the actual code before implementation.

## Goal

Give the colony a capped individual scout that leaves, explores, and returns.

## Why this exists

Scouts are the exceptional individual agents that will gather evidence.

## Dependencies

[006](006_debug_world_view.md) and the preceding task sequence. Read [ARCHITECTURE](../ARCHITECTURE.md), [CODING_RULES](../CODING_RULES.md), and relevant [DATA_MODEL](../DATA_MODEL.md)/[UI_RULES](../UI_RULES.md) contracts.

## Allowed scope

General mission, directional bias, departure/exploration/return state machine; simple reliable obstacle/terrain-cost pathing and ledger commitment.

## Required behavior

One worker is committed per scout; return releases that same worker. Bound active detailed scouts. Use run RNG and fixed ticks; add scout positions/states to debug inspection.

Before coding: Resolve scout cap, mission duration, directional-bias parameters, and pathing/failed-return policy.

## Explicit non-goals

Discovery, observations, knowledge, and trails. Do not implement future systems not explicitly requested.

## Interfaces to preserve

Ledger ownership, hidden world, fixed clock, and individual-scout/aggregate-worker distinction.

## Acceptance tests

Seeded missions repeat; state transitions and return conserve workers. Manually inspect departure/exploration/return in the debug world.

## Manual verification

Run the relevant prototype/debug scene and inspect the behavior above. On expansion, name exact files, commands, fixtures, and expected results; do not treat this roadmap as a fully specified coding prompt.

## Done when

The expanded card's checks pass, existing behavior remains intact, and the handoff records changed files, tests, limitations, and next task. One logical commit.
