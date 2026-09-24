# 012 — Trail creation and worker allocation

Status: roadmap; expand against the actual code before implementation.

## Goal

Create a route to a known destination and commit workers.

## Why this exists

Trail investment must impose a real, conserved labor cost.

## Dependencies

[011](011_outward_prototype.md) and the preceding task sequence. Read [ARCHITECTURE](../ARCHITECTURE.md), [CODING_RULES](../CODING_RULES.md), and relevant [DATA_MODEL](../DATA_MODEL.md)/[UI_RULES](../UI_RULES.md) contracts.

## Allowed scope

TrailNetwork, TrailRouteState, one distinct TrailSegmentState per route, desired/allocated worker values, ledger integration and contextual allocation controls.

## Required behavior

Validate destination against colony knowledge and available labor. Keep desired target separate from actual allocation and active traveler count. Make routes/segments inspectable.

Before coding: Resolve allocation priority/shortage rules and inactive-route cancellation; reserve recall behavior for actual travelers in 013.

## Explicit non-goals

Resource flow, transit, pheromone behavior, and multiple/shared segments. Do not implement future systems not explicitly requested.

## Interfaces to preserve

WorkerLedger and TrailRoute versus TrailSegment; never count desired workers as living workers.

## Acceptance tests

Allocate/reduce/cancel commitments without inventing workers; insufficient-labor requests follow the documented policy atomically. Route and segment remain distinct IDs/objects.

## Manual verification

Run the relevant prototype/debug scene and inspect the behavior above. On expansion, name exact files, commands, fixtures, and expected results; do not treat this roadmap as a fully specified coding prompt.

## Done when

The expanded card's checks pass, existing behavior remains intact, and the handoff records changed files, tests, limitations, and next task. One logical commit.
