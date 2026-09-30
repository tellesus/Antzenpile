# 008 — Scout discovery and observations

Historical implementation card: task [023](023_persistent_scout_search.md) supersedes the exploration deadline below while preserving private sensing and return-only delivery.

Status: implemented 2026-09-29.

## Goal

Let scouts detect World Nodes and carry observations home.

## Why this exists

Private encounters must not become immediate colony-wide knowledge.

## Dependencies

[007](007_scout_mission_agent.md) and the preceding task sequence. Read [ARCHITECTURE](../ARCHITECTURE.md), [CODING_RULES](../CODING_RULES.md), and relevant [DATA_MODEL](../DATA_MODEL.md)/[UI_RULES](../UI_RULES.md) contracts.

## Allowed scope

Detection radius, typed Observation, scout-carried evidence, and delivery boundary on return.

## Required behavior

Capture encountered evidence/time without making UI. Transfer carried observations once, only on successful return. Use a minimal delivered-observation inbox; KnownNode merging remains 009.

Resolved below; user-authorized sensory discovery is recorded as decision D15.

## Explicit non-goals

KnownNode confidence/merging, visual signals, and trail creation. Do not implement future systems not explicitly requested.

## Interfaces to preserve

Scout ownership of undelivered evidence and a distinct colony delivery boundary.

## Acceptance tests

Knowledge Separation test: hidden node and unreturned encounter produce no colony evidence; returning transfers it exactly once. Until 009–010 exist, test the inbox boundary, then extend the same scenario to knowledge/signals.

## Manual verification

Run the relevant prototype/debug scene and inspect the behavior above. On expansion, name exact files, commands, fixtures, and expected results; do not treat this roadmap as a fully specified coding prompt.

## Done when

The expanded card's checks pass, existing behavior remains intact, and the handoff records changed files, tests, limitations, and next task. One logical commit.

## Executable expansion — nearby sensory discovery

User feedback (2026-09-29): scouts sense resources nearby and progressively locate them; discovery never requires running over the exact resource point.

- Use an authored 4 m chemical-sense radius and 1 m close-confirmation radius. Active, nonempty sources emit cues; outside range supplies no cue. These are provisional game-scale values, not biological claims. Wind/plume physics and distinct sensory modalities remain later work.
- Each scout carries one typed Observation per source per mission. Store stable observation/scout/origin/source IDs, resource classification, first/latest evidence times, estimated position, uncertainty radius, and close-confirmation flag. Do not report live quantity or exact coordinates. IDs permit later merging but never authorize UI truth queries.
- First detection produces an uncertain estimate. Closer encounters reduce uncertainty (0.25 m floor plus half the distance); seeded measurement error lies within that radius. Equal/worse proximity does not reroll estimates or add duplicate evidence. Close sensing confirms within 1 m, without point contact.
- Exploring scouts investigate the strongest nearby unconfirmed cue using its estimated position, updating their route only at grid waypoints. Terrain pathing remains authoritative. After confirmation or cue loss they resume their original mission target. Preserve actual traveled breadcrumbs and the existing exploration deadline; returning scouts may sense but never divert or extend return.
- Deliver detached observations into a run-owned inbox exactly once on successful home arrival, immediately before retiring the scout. Blocked/away scouts retain private evidence; neither sensing nor debug inspection delivers it. Inbox merging/KnownNodes remain task 009.
- Serialize carried observations, investigation state, mission target, and delivered inbox; reject malformed/duplicate/reused evidence IDs atomically. Old evidence remains unchanged when hidden truth changes later.
- Extend debug inspection with scout estimates/uncertainty and carried versus delivered counts. All such information remains development-only.

## Exact validation

Add `tests/test_observations.gd`: off-path nearby detection and steering; outside-range/inactive/empty rejection; improving localization before contact; no duplicate encounters; no delivery before return or while blocked; exactly-once delivery; stale evidence isolation; deterministic mid-investigation JSON continuation; invalid evidence restore atomicity. Run full pinned-engine suite and Main smoke check. Manually use F3 dispatch to inspect private evidence and the inbox before/after return.

## Implementation handoff

- Added `observation.gd`, `scout_senses.gd`, and `tests/test_observations.gd`; extended ScoutConfig/data, ScoutAgent investigation/snapshots, ScoutSystem steering/return delivery, RunState inbox validation, and debug evidence inspection. Updated DATA_MODEL, DECISIONS, and README.
- Pinned Godot import, full headless suite, and Main smoke check passed: 2,756 checks, 0 failures. Off-path test narrowed uncertainty 2.23 m → 0.38 m; first close confirmation at 0.79 m without point contact. Mid-investigation full-precision JSON continuation matches.
- Windows manual: initial private/delivered counts zero; scout selection shows a private carbohydrate estimate (29.78,20.72), radius 0.75 m, and its uncertainty circle while delivered stays zero. Also observed a private water encounter with delivered count unchanged at three, then four after return. No runtime errors in the preview log.
- Prototype approximation: range-based chemical sensing and noisy estimates, without wind, plume transport, or chemical occlusion. Existing terrain routing and mission time still apply. Detection/confirmation values are tunable and not biological claims. Knowledge merging/signals/player UI remain excluded. Mobile-device and release-export checks remain unrun.
- Next: task 009, consume delivered observations into KnowledgeBase/Known Nodes without live truth refresh.
