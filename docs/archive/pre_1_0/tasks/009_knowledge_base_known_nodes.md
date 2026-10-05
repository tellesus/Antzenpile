> **ARCHIVE ONLY — frozen 2026-10-04.** Historical record; not an active plan, current contract or implementation instruction. Use the [current documentation](../../../README.md). Original path: `docs/tasks/009_knowledge_base_known_nodes.md`. Historical status and recommendations below apply only to their recorded build.

# 009 â€” KnowledgeBase and Known Nodes

Status: complete 2026-09-29.

## Goal

Turn delivered evidence into inspectable colony knowledge.

## Why this exists

Knowledge must represent estimates and confidence rather than live world truth.

## Dependencies

[008](008_scout_discovery_observations.md) and the preceding task sequence. Read [ARCHITECTURE](../contracts/ARCHITECTURE.md), [CODING_RULES](../../../CODING_RULES.md), and relevant [DATA_MODEL](../contracts/DATA_MODEL.md)/[UI_RULES](../contracts/UI_RULES.md) contracts.

## Allowed scope

Observation merging, estimated position, confidence, timestamps, KnownNode IDs and creation.

## Required behavior

Consume delivered observations, merge evidence deterministically, retain uncertainty/age. Add truth-versus-known inspection to debug tools; a later hidden-world change must not silently refresh memory.

Before coding: Resolve merge/conflict rules, confidence bounds/update rules, stale evidence policy, and estimate generation.

## Explicit non-goals

Visual signals, player UI, and omniscient knowledge refresh. Do not implement future systems not explicitly requested.

## Interfaces to preserve

KnowledgeBase ownership and stable source-knowledge IDs; read ARCHITECTURE's knowledge boundary.

## Acceptance tests

Before return, no KnownNode; after return, expected knowledge exists. Repeat/merge evidence without duplicate nodes. Mutate hidden truth afterward and verify memory stays unchanged until new evidence.

## Manual verification

Run the relevant prototype/debug scene and inspect the behavior above. On expansion, name exact files, commands, fixtures, and expected results; do not treat this roadmap as a fully specified coding prompt.

## Done when

The expanded card's checks pass, existing behavior remains intact, and the handoff records changed files, tests, limitations, and next task. One logical commit.

## Executable expansion

- Add typed KnownNode/KnowledgeBase under `src/sim/knowledge/`, authored knowledge confidence settings, RunState ownership/snapshots, controller dispatch after ScoutSystem each tick, and `tests/test_knowledge.gd`.
- Consume only the delivered inbox after scout returns; move detached evidence into a knowledge-owned archive and clear successfully consumed inbox entries. Archived IDs make re-delivery idempotent. A reused ID with changed evidence rejects the whole batch atomically.
- Prototype identity association uses the captured source ID; KnownNode ID is `known:<source_id>`. Identity is not permission to read current world state. One node per observed source; evidence IDs sorted for deterministic snapshots.
- Estimate/classification/uncertainty come from the newest observation time. Equal-time reports prefer smaller uncertainty, then close confirmation, then lexical observation ID. Conflicting positions are not averaged into invented locations. Out-of-order stale reports add provenance but cannot replace fresher estimates.
- Store first evidence time, latest observation time, first/last delivery time, winning evidence ID and all evidence IDs. Keep the winning estimate unchanged between reports. No live hidden-state refresh, deletion, or omniscient depletion information.
- Provisional confidence: baseline 0.9 for close-confirmed evidence, 0.55 for a chemical cue, divided by (1 + uncertainty_radius / 4 m). Effective confidence halves every 300 simulated seconds since observation. Clamp to [0,1]; age and effective confidence are derived queries, not per-frame authoritative writes. All tuning lives in an authored Resource. Repeated identical reports do not manufacture certainty.
- Knowledge processing receives observations/time only, never WorldState, scouts, views, or RNG. Restore validates evidence at the RunState boundary, reconstructs derived Known Nodes from the archive, and rejects inconsistent saved nodes atomically. Full-precision JSON continuation remains required.
- Debug truth view compares source truth with KnownNode estimates, uncertainty, confidence and age. Clearly label known estimates; normal sensory/player presentation remains task 010 onward.

## Exact validation

Run pinned-engine import, full suite and Main smoke check. Test no knowledge before return, automatic inbox consumption on return, repeat/duplicate/conflicting evidence, stale delivery and deterministic ties, hidden truth mutation isolation, confidence bounds/age, no RNG use, populated JSON continuation and corrupt snapshot rejection. Update task 008 tests to inspect pending inbox plus archived deliveries now that the inbox is consumed. Manually dispatch through F3 and inspect truth-versus-known fields after return.


## Implementation handoff

- Added `src/sim/knowledge/{knowledge_base,known_node,knowledge_config}.gd`, their engine UID files, `data/knowledge/default_knowledge.tres`, and `tests/test_knowledge.gd`/UID. Extended RunState, SimulationController, Observation detached copying, debug model/view, test registry and task 008 regression tests. Updated README, ARCHITECTURE, DATA_MODEL, DECISIONS and this card.
- Pinned Godot `4.7.2.stable.official.ed1daf0bf`: `--headless --path . --import`, `--headless --path . --script res://tests/run_tests.gd` (2,887 checks, 0 failures), and `--headless --path . --quit-after 3` all passed. Full-precision populated JSON and 100 subsequent ticks match; existing mid-investigation continuation also passes. Failed restore preserves the live run.
- Windows/Compatibility manual check via F3: private report count 1 and Known/Reports 0 while scout returns; on arrival private count 0 and Known/Reports 1. Resource selection compared truth (30,20) with estimate (29.78,20.72), uncertainty 0.75 m, confidence 0.678 and age 48.3 s. The cyan estimate circle and labels are readable. Preview log has no runtime errors.
- Hidden position/quantity/active changes, stale reports, duplicate delivery, conflicting IDs, invalid confidence/archive timestamps, atomic rejection and detached debug data are covered headlessly. Confidence aging and knowledge updates do not draw RNG.
- Tuning remains provisional, with source-ID association and deterministic newest-evidence selection; no triangulation or statistical probability claim. No player-facing sensory UI, archive pruning, disk save migration, mobile-device test or release export in this task. Prototype snapshots now require a knowledge envelope; backward migration belongs to task 021.
- Next bounded task: expand 010 (PerceivedSignals), deriving bearing, estimated distance and signal information from Known Nodes and the active pile only.
