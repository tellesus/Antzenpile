> **ARCHIVE ONLY — frozen 2026-10-04.** Historical record; not an active plan, current contract or implementation instruction. Use the [current documentation](../../../README.md). Original path: `docs/tasks/032_episodic_exterior_resource.md`. Historical status and recommendations below apply only to their recorded build.

# 032 — Episodic exterior resource

Status: complete 2026-09-30. Expanded from [the post-slice plan](../plans/POST_SLICE_PLAN.md) against the task-027 nectar pulse and the current backyard scenario.

## Goal

Make one physically temporary source appear and disappear in the hidden exterior world, so scouting and trail work must cope with changing reality and stale reports.

## Scope and contracts

- Author a picnic crumb spill as a protein World Node at a fixed exterior location, initially empty and inactive. A deterministic authored schedule sets a bounded quantity at appearance and removes any remainder at expiry. These values are provisional fixtures, not session pacing or economy targets. The event is available only in the backyard scenario and skips a minimal world missing the source.
- The fixed SimulationClock drives both boundaries. Preserve the existing tick order: scouts and trail travelers interact first; ecology changes the world afterward. Derive the next boundary from saved ticks and immutable event data, with no mutable schedule cursor or snapshot version change. Pause, speed and reload must preserve the result.
- An inactive/empty spill cannot be sensed or collected. A scout learns it through ordinary proximity sensing and only delivers evidence on return. A trail invested from that evidence can collect during abundance and may later return empty. Appearance/expiry never rewrites KnowledgeBase, reactivates depleted routes, or exposes the physical schedule/quantity to normal UI. F3 may inspect truth.
- Keep TrailRoute/TrailSegment and ledger contracts unchanged. No new worker, map, UI command, or broad ecology model.

## Verification and handoff

Check before/on/after appearance and expiry, recurring episode, source specificity, quantity bounds, pause/speed, save continuation across both boundaries, absent-source fixture, no knowledge/UI leak, scout discovery and stale evidence after removal. Run pinned import, full headless suite, Main smoke and `git diff --check`. Record evidence and changed files before a logical commit.

## Completion evidence and handoff

- The backyard now includes an inactive picnic crumb protein node. Fixed authored ticks make 24 units appear, remove any remainder after 800 ticks, and repeat after 2400 ticks. The existing EcologySystem changes hidden world state after scout/trail interactions; normal sensing, delivered reports and trail transit need no special event path. A depleted route stays depleted, and delivered evidence can become stale.
- Tests cover initial absence, exact boundaries, repeat appearance, pause/4×, independent protein source, save/reload across appearance and expiry, absent-source fixture, no OUTWARD/knowledge leak, ordinary scout discovery, collection, stale evidence, empty return and worker conservation. A test fixture supplies carbohydrate for protein travel because the existing brood can consume the initial reserve before this late event.
- Pinned Godot `4.7.2.stable.official.ed1daf0bf`: headless import exited 0; full suite passed **3,754 checks, zero failures**; headless Main smoke exited 0; `git diff --check` passed. Sandbox diagnostics about Godot user logs/editor settings and root certificates did not affect exit status. No graphical manual interaction or Android-device check was run.
- Changed: authored picnic event and scenario node, ecology system/definition, WorldLoader/node definition, world/ecology tests and runner, README, architecture/data/decision/plan docs, and this card. Next: expand card 033 to let repeated *delivered evidence* support uncertain timing hints and an explicit known-source investigation, without reading the authored schedule.
