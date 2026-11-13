> **ARCHIVE ONLY — frozen 2026-10-04.** Historical record; not an active plan, current contract or implementation instruction. Use the [current documentation](../../../README.md). Original path: `docs/tasks/005_home_pile_worker_ledger.md`. Historical status and recommendations below apply only to their recorded build.

# 005 — Home pile and worker ledger

Status: implemented 2026-09-28.

## Goal

Create the home pile and the only authority for living-worker counts and transfers.

## Why this exists

Every later labor commitment must conserve workers and avoid double counting.

## Dependencies

[004](004_hidden_world.md); read [ARCHITECTURE](../contracts/ARCHITECTURE.md), [DATA_MODEL](../contracts/DATA_MODEL.md), [CODING_RULES](../../../CODING_RULES.md), and decisions A05–A06.

## Allowed scope

`src/sim/colony/` PileState/ColonyState/WorkerLedger, run initialization, and ledger tests. Only state/accounting; no gameplay allocation UI.

## Required behavior

1. Create `home` at (20,20), queen_count=1, workers_total=40, workers_available=40; all commitment pools start empty. Queens do not count as workers.
2. Ledger owns total living workers and disjoint available, internal, scout, trail, and other explicit commitment pools. Commitment entries carry owner IDs so later systems can reconcile their counts. Pile count getters read the ledger; colony totals derive from its piles.
3. Supply atomic allocate/release/transfer equivalents: move a nonnegative integer between known pools/commitments, fail clearly on insufficient workers or invalid IDs, and never partially mutate. Zero is a no-op; negatives and fractional counts are invalid. Create commitments explicitly; reject unknown release targets.
4. Supply explicit add-living-workers and remove-living-workers utilities that update total and the relevant pool together with a diagnostic reason. These are accounting hooks only, not brood/death systems.
5. Assert `sum(disjoint pools) == total living workers` and all counts nonnegative after every mutation. Failed operations preserve the full prior state. Releasing a commitment requires its system to report actual return; this utility must not imply travelers teleport.
6. Add explicit pile/ledger snapshots consistent with existing state contracts. Brood fields remain absent/empty; no brood logic or cohorts in this task.

## Explicit non-goals

No brood (task 016), food consumption, scouting behavior, trails, travel, automatic labor scheduler, or colony UI. Do not implement future systems not explicitly requested.

## Interfaces to preserve

All future population/commitment changes use this ledger. Route active counts and transit cohorts are subsets of committed workers, never additional top-level pools.

## Acceptance tests

- Allocate 10 to a trail commitment, 2 to scouts, 5 to internal work: available=23, total=40. Return all: available=40, total=40.
- Attempt over-allocation, excessive release, negative/fractional transfer, and unknown commitment release: fail atomically. Zero transfer leaves state unchanged.
- Add 3 living workers to available, remove 1 from an occupied pool: total=42 and all pools reconcile. Over-removal is rejected.
- Run at least 1,000 deterministic valid/invalid transfers, asserting invariants after each; round-trip a populated ledger and compare state.

## Manual verification

Run tests, boot Main, and inspect a compact home/ledger dump. Confirm 1 queen/40 initial workers and no brood implementation.

## Done when

Worker conservation and atomicity pass, ownership is unambiguous, and handoff records evidence. One logical commit; next task 006.

## Implementation handoff

- Added WorkerLedger, PileState, ColonyState under src/sim/colony; RunState owns colony and validates complete candidate state before restoring. Added tests/test_worker_ledger.gd.
- Pinned Godot suite: 1,290 checks, 0 failures, including 1,000 deterministic transfers, rejection atomicity, detached snapshots, and populated JSON continuation. Main boots. Initial home has 1 queen and 40 available workers.
- Explicit commitments use stable IDs, kind, owner ID and count. Count getters derive from the ledger. Population utilities require a diagnostic reason. Zero is a no-op; snapshots support integral JSON values up to 2^53-1. No brood/travel behavior.
- Next: 006 development-only world view.

