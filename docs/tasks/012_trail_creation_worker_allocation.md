# 012 — Trail creation and worker allocation

Status: complete 2026-09-30.

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


## Executable expansion

- Add run-owned `TrailNetwork`, typed `TrailRouteState` and `TrailSegmentState` under `src/sim/trails/`, a `TrailSystem` for semantic commands, authored `data/trails/default_trails.tres`, and `tests/test_trails.gd`. Include routes/segments in the RunState snapshot and validate ledger/knowledge/ID relationships atomically on restore.
- Create by origin pile ID and KnownNode ID only. Require a known destination with a finite, distinct estimate, a valid origin, and enough available workers for the authored initial five. Do not query the matching World Node or its live quantity/position. Capture the current estimated endpoint; later knowledge changes cannot silently move the route. A route and its one segment have distinct stable IDs; the segment stores estimated start/end geometry plus separate zero-valued pheromone and familiarity fields. Pathfinding/travel and chemistry wait for 013–015.
- User actions allocate exactly the requested worker count. No automatic priority, borrowing, rebalancing or partial allocation in 012: insufficient labor rejects atomically, leaves desired/allocated unchanged, and reports why. Desired target and allocated commitment are distinct route fields even though they match before travel exists; active traveler count stays zero. Scout commitments remain disjoint in the same authoritative ledger. Allocation uses a `trail:<route_id>` commitment owned by that route.
- One origin/destination pair has one route. Duplicate creation while active rejects. Setting desired to zero releases all workers and retires the empty commitment, marking the route inactive while preserving route and segment IDs. Reopening the same pair with sufficient initial labor reuses both IDs. Reduction immediately releases the difference because there are no travelers yet; 013 adds real in-flight recall semantics.
- Route snapshot: ID, origin pile ID, destination KnownNode ID, captured estimate, segment ID, desired/allocated/active counts, active/inactive status. Segment snapshot: ID, owning route ID, captured start/end, pheromone_strength, route_familiarity, traffic (all three zero until their tasks). Network snapshot includes monotonically increasing next route ID. Restore rejects inconsistent or orphan trail commitments, duplicate IDs, missing references, invalid counts, nonzero premature traveler/chemistry fields, and mismatched segment geometry.
- OUTWARD selected-signal card gets invest/adjust/cancel controls backed by detached approved route summaries and semantic commands. Show desired versus allocated workers and current labor cost without presenting a route as a physical world map. F3 truth view exposes route/segment IDs, geometry and ledger commitment for diagnosis. Input uses the same mouse/touch button handling as task 011.
- Validate unknown/private destination, shortage, repeated creation, reductions, cancellation/reopening, multiple worker pools, zero RNG changes, stale hidden truth/knowledge estimate changes, deterministic JSON continuation, corrupted snapshot atomicity, and interaction at 1280x720 and 900x600. Pin Godot version and run import/full suite/Main smoke. Mobile/release checks remain separate.

## Completion evidence and handoff (2026-09-30)

- Added `src/sim/trails/{trail_route_state,trail_segment_state,trail_network,trail_system,trail_config}.gd`, authored `data/trails/default_trails.tres`, and RunState/SimulationController wiring. `TrailNetwork` snapshots reject missing/duplicate references, ledger mismatches, invalid geometry, premature transit/chemistry state, and orphan trail commitments. Creation depends on colony knowledge and reserves five workers; exact adjustments and cancellation use WorkerLedger, with stable route/segment identity across reopening.
- Added OUTWARD selected-signal controls through detached GameRoot route summaries and semantic callbacks. The F3 debug view draws the captured estimated segment and lists route/segment/commitment details. No world truth or route geometry enters normal UI.
- Added `tests/test_trails.gd` and suite registration; updated the synthetic ledger fixture so its arbitrary test pool is `other` rather than an unowned trail. The tests cover private versus delivered knowledge, deterministic save continuation, allocation shortage/rollback, independent labor, cancellation/reopening, corrupt snapshots, detached summaries, and contextual controls.
- Verified with pinned `4.7.2.stable.official.ed1daf0bf`: `--headless --path . --import`, `--headless --path . --script res://tests/run_tests.gd` (**3,088 checks, 0 failures**), `--headless --path . --quit-after 3` (Main starts). Manual Windows preview at 900×600: scout return, selected trace, invest 5, increase to 6, cancel, re-invest, and F3 route/segment inspection. Manual 1280×720: selected trace and invest 5; card and controls remain readable. No mobile or release build run.
- Updated README, architecture, data model, UI rules and decision register. Next: expand [013](013_transit_cohorts_resource_delivery.md) against this route/ledger contract, then implement transit/return semantics; route creation alone produces no travel or resource delivery.
