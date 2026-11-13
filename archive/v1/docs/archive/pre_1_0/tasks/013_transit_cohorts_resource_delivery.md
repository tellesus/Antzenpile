> **ARCHIVE ONLY — frozen 2026-10-04.** Historical record; not an active plan, current contract or implementation instruction. Use the [current documentation](../../../README.md). Original path: `docs/tasks/013_transit_cohorts_resource_delivery.md`. Historical status and recommendations below apply only to their recorded build.

# 013 — Transit cohorts and resource delivery

Status: complete 2026-09-30.

## Goal

Close the first economic loop through aggregate travel and delayed delivery.

## Why this exists

Resources should arrive because committed workers actually return.

## Dependencies

[012](012_trail_creation_worker_allocation.md) and the preceding task sequence. Read [ARCHITECTURE](../contracts/ARCHITECTURE.md), [CODING_RULES](../../../CODING_RULES.md), and relevant [DATA_MODEL](../contracts/DATA_MODEL.md)/[UI_RULES](../contracts/UI_RULES.md) contracts.

## Allowed scope

Bucketed outbound/inbound TransitCohorts, travel delay, collection, pile resource storage/deposit, and recall.

## Required behavior

Depart → travel → collect/deplete node → return → deposit → next cycle. Recall blocks new cycles and waits for in-flight workers; cohort counts are subsets of route commitments. Bound cohort growth.

Before coding: Resolve travel/carry rates, collection contention and depleted-node behavior, bucket interval, and resource-storage defaults.

## Explicit non-goals

Individual foragers, pheromone, rain, brood, and visual ants. Do not implement future systems not explicitly requested.

## Interfaces to preserve

Resource conservation, ledger conservation, and separate route/segment ownership.

## Acceptance tests

No early delivery; one collection/deposit per cycle; no negative/duplicated resources. Recall takes travel time and restores the ledger. Compare equal simulated durations at all speeds.

## Manual verification

Run the relevant prototype/debug scene and inspect the behavior above. On expansion, name exact files, commands, fixtures, and expected results; do not treat this roadmap as a fully specified coding prompt.

## Done when

The expanded card's checks pass, existing behavior remains intact, and the handoff records changed files, tests, limitations, and next task. One logical commit.

## Executable expansion

- Add typed `TransitCohort` under `src/sim/trails/`, owned by RunState's existing `TrailNetwork`. Extend `TrailSystem.tick()` from SimulationController's fixed tick after scouting/knowledge delivery. No scene nodes, individual foragers, or RNG. A route's active worker count is the sum of its cohorts and a subset of its ledger commitment.
- Authored defaults in `data/trails/default_trails.tres`: straight estimated-segment travel at 1 m/s, one unit carried per worker, one departure bucket every 2 simulated seconds, at most eight workers per cohort and eight cohorts per route, and a 2 m source interaction radius around the captured endpoint. Round each leg up to whole 0.25-second ticks (minimum one tick). These are prototype balance values, not claims about ant biology or final terrain routing. Preserve the captured estimated segment; do not silently navigate to live coordinates.
- On a departure opportunity, send up to eight idle committed workers in one outbound cohort. At arrival, check the captured source identity in hidden WorldState and only collect if its live node is active, within interaction radius, and has quantity. Collect at most one unit per worker and the remaining node quantity; decrement world quantity once and carry the result inbound. Process simultaneous arrivals in stable numeric cohort ID order. Empty trips return without payload. Never credit the pile before an inbound arrival.
- Add three per-pile resource pools, initialized from authored prototype reserves of 10 carbohydrate, 5 protein and 10 water. Deposit returned payload into the matching pool, then update cumulative route delivery. Keep storage and world quantities finite/nonnegative. Other consumers/production wait for later cards.
- Set desired workers exactly on commands. Increase reserves only the additional available workers; shortage rejects atomically. Reduce/cancel releases idle excess now, but in-flight workers remain allocated until their cohort returns. Cancellation sets desired zero, blocks departures, enters `recalling` while any worker is away, then retires the empty ledger commitment and becomes `inactive`. Reactivating during recall uses the same route/segment and existing in-flight commitment. Reopen after full cancellation also reuses IDs. No teleporting workers or cargo.
- Empty resource returns report depletion to the colony, stopping new departures and marking the route `depleted` while preserving its commitment for player adjustment/cancellation. A partial final load does not reveal depletion early. A fresh investment after full cancellation clears this report. External world changes or stale knowledge do not create a normal UI signal by themselves.
- Snapshot cohort IDs, direction, worker count, payload category/amount and remaining leg ticks; route status, desired/allocated/active counts, departure cooldown, depletion report and delivered total; pile resource pools; and next cohort ID. Restore atomically validates cohort/route/ledger sums, source/category, carrying limit, tick range, IDs and nonnegative finite quantities. Preserve deterministic continuation mid-outbound and mid-inbound.
- OUTWARD receives detached route progress and pile resource totals in approved summaries; selected trace can show workers travelling, returned resources and depletion/recall status, without hidden node quantity or geometry. F3 may show world node quantity, cohort phase, remaining ticks and pile storage. No pheromone/familiarity change or visual ant traffic in 013.
- Add `tests/test_transit.gd` to the existing headless runner. Exercise no early deposit, exact pickup/deposit, multiple cohorts, contention/depletion, stale endpoint, invalid commands, delayed recall and reactivation, resource/worker conservation, save corruption rollback, mid-trip continuation, and equal simulated outcomes at 1×/4×/16×/64×. Run pinned import/full suite/Main smoke; manually inspect OUTWARD/F3 at 1280×720 and 900×600. No claim of mobile/release validation.

## Completion evidence and handoff (2026-09-30)

- Added `TransitCohort` and run-owned cohort snapshots, ticked from `SimulationController` through `TrailSystem`. Departures use fixed-size buckets; collection occurs at the captured estimated endpoint against hidden source reality, and pile storage changes only on home arrival. Route, segment and cohort IDs remain separate. Workers stay in one ledger commitment throughout travel.
- Extended `TrailRouteState`, `TrailNetwork` restore validation, `PileState` resource pools and authored storage/travel configurations. Reduction releases idle labor and waits for returning cohorts to release the rest. An empty return reports source unavailability and stops departures; full cancellation then reinvestment clears that report. `src/core/game_root.gd` supplies detached progress and storage summaries, OUTWARD shows them on selected traces, and F3 lists raw cohorts, stores and route state.
- Added `tests/test_transit.gd` and updated the task 012 control assertion for real recall. Tests cover trip timing, cargo/world/pile conservation, depletion contention, bounded 8/8/4 batches, partial/full recall, stale endpoints, mid-outbound/inbound save continuation, corrupt snapshot rejection, detached presentation, and equivalent outcomes at 1×/4×/16×/64×.
- Pinned Godot `4.7.2.stable.official.ed1daf0bf`: `--headless --path . --import` passed; `--headless --path . --script res://tests/run_tests.gd` passed (**3,256 checks, 0 failures**); `--headless --path . --quit-after 3` started Main. Windows manual preview at 900×600 and 1280×720 showed resource return/home storage changes and readable controls; F3 showed source depletion, retained commitment and route totals. No Android or release export was run.
- Updated README, architecture, data model, UI rules and decision register. Next: expand [014](014_pheromone_reinforcement_decay.md) against the actual cohort/segment contract. Pheromone and familiarity remain zero; no terrain routing, visible forager ants, resource consumers or rain behavior were added here.
