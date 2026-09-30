# 010 — PerceivedSignals

Status: complete 2026-09-29.

## Goal

Convert Known Nodes into a presentation-facing sensory model.

## Why this exists

The renderer needs a stable interface that cannot reveal hidden truth.

## Dependencies

[009](009_knowledge_base_known_nodes.md) and the preceding task sequence. Read [ARCHITECTURE](../ARCHITECTURE.md), [CODING_RULES](../CODING_RULES.md), and relevant [DATA_MODEL](../DATA_MODEL.md)/[UI_RULES](../UI_RULES.md) contracts.

## Allowed scope

PerceptionModel and typed PerceivedSignal: category, bearing, strength, confidence; preserve the remaining DATA_MODEL fields as applicable.

## Required behavior

Derive relative bearing/distance from known estimates and active pile; expose age/risk/traffic only when known. Keep qualitative formatting out of simulation.

Before coding: Resolve signal strength/category mapping, unknown-value representation, and angular conventions.

## Explicit non-goals

Polished rendering, camera movement, and querying hidden World Nodes. Do not implement future systems not explicitly requested.

## Interfaces to preserve

PerceivedSignal and source_knowledge_id; no mutable truth references in output.

## Acceptance tests

Extend separation test: hidden/unreturned evidence emits no signal; returned knowledge does. Change hidden truth without new evidence: perceived output stays knowledge-derived. Test cardinal bearings and angle wrap.

## Manual verification

Run the relevant prototype/debug scene and inspect the behavior above. On expansion, name exact files, commands, fixtures, and expected results; do not treat this roadmap as a fully specified coding prompt.

## Done when

The expanded card's checks pass, existing behavior remains intact, and the handoff records changed files, tests, limitations, and next task. One logical commit.


## Executable expansion

- Add typed `PerceivedSignal` and `PerceptionModel` under `src/presentation/`, an authored `PerceptionConfig`/`data/signals/default_perception.tres`, and `tests/test_perception.gd`. No OUTWARD rendering or player controls in this card.
- PerceptionModel takes Known Nodes, active pile position (a value), and simulation time only. No RunState, WorldState, scout, archive, RNG or scene dependency. It does not retain input references or modify knowledge. GameRoot composes this boundary; its sensory snapshot callable returns detached signal dictionaries for presentation/debug use.
- Emit one signal per Known Node in stable knowledge-ID order. ID is `signal:<known_id>`; `source_knowledge_id` keeps selection stable through aging/reports. Do not expose hidden source IDs, true coordinates, quantities, observation archives or mutable KnownNode references. No signals for hidden or unreturned evidence.
- Categories map authored resource definitions to carbohydrate/protein/water; unsupported classifications yield `unknown`. Estimated distance is meters from active pile to remembered estimate; retain uncertainty radius. Bearing is radians in [0, TAU), east=0, south=PI/2, west=PI, north=3PI/2 (positive clockwise in the existing +y south world). At a coincident estimate, distance is zero and bearing is null because direction is undefined.
- Provide a pure relative-bearing helper returning the wrapped difference from facing in [-PI, PI); preserve null bearing. Facing affects projection only, never knowledge or signal strength. Test both wrap seams and multiple full turns.
- Confidence and age come from KnownNode queries. Provisional strength is confidence / (1 + estimated_distance / 10 m), clamped to [0,1]; this expresses presentation salience, not resource amount or a new chemical simulation. No hidden-state refresh or age-based node deletion. Risk and traffic are null (unknown), never invented zero/safe values.
- Qualitative confidence belongs to PerceptionModel: uncertain below 0.25, likely below 0.65, clear otherwise. Thresholds and distance scale are authored provisional settings. Signal output includes numeric confidence and its qualitative label; no formatting in simulation.
- Signals are disposable derived data, not new authoritative save state. Rebuild after restore. Reject invalid origin/time by returning an empty projection; invalid facing gives null relative bearing.
- Extend only the development truth view with a signal count and selected Known Node's projected category, bearing, distance, strength, label and unknown risk/traffic. Obtain these through the same sensory provider intended for later views, separately from debug truth snapshots.

## Exact validation

Run pinned Godot import, full headless suite and Main smoke check. Test cardinal bearings, coincident/shifted origins, angle seams, classification fallback, confidence/strength aging and bounds, unknown risk/traffic, stable ordering/IDs, detached output, no state/RNG changes, hidden/unreturned isolation, stale truth changes and restored signal equality. Manually use F3 dispatch: zero signals before return; afterward select the resource and compare the projected bearing/distance with the remembered estimate. Check preview logs. Record mobile/release checks as unrun.


## Implementation handoff

- Added `src/presentation/{perceived_signal,perception_model,perception_config}.gd` and engine UID files, `data/signals/default_perception.tres`, and `tests/test_perception.gd`/UID. GameRoot owns the projection and exposes detached sensory snapshots; the debug view displays signals through that separate provider. Updated test registry, README, ARCHITECTURE, DATA_MODEL, DECISIONS and this card. Corrected earlier Windows text-encoding corruption in the touched documentation.
- Pinned Godot `4.7.2.stable.official.ed1daf0bf`: `--headless --path . --import`, `--headless --path . --script res://tests/run_tests.gd` (2,930 checks, 0 failures), and `--headless --path . --quit-after 3` all passed.
- Tests cover cardinal bearings, both east seam directions and opposite-facing seam, repeated full turns, coincident/shifted origins, stable ordering/identity, classifications, label boundaries, aging, unknown risk/traffic, detached output, hidden/private evidence isolation, stale truth changes, untouched simulation/RNG, and identical projection after JSON restore/continuation.
- Windows/Compatibility manual F3 check: perceived count 0 with one private returning report; count 1 after arrival. Resource selection showed remembered estimate (29.78,20.72), projected bearing 4.2 degrees clockwise from east, range 9.81 m, strength 0.339 and clear confidence at age 52 s. Risk/traffic remained unknown. Fields fit the 1280x720 development view; preview log has no runtime errors.
- Strength/labels are provisional presentation tuning. No gameplay chemistry, signal culling, player controls, OUTWARD rendering or save format changes added. Mobile-device and release-export checks remain unrun.
- Next bounded task: expand 011 (OUTWARD prototype) against this provider. Resolve field of view, wrapping/culling, input and selection layout before implementing the rotating sensory panorama and basic scout/labor/time controls.
