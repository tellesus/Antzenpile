> **ARCHIVE ONLY — frozen 2026-10-04.** Historical record; not an active plan, current contract or implementation instruction. Use the [current documentation](../../../README.md). Original path: `docs/tasks/006_debug_world_view.md`. Historical status and recommendations below apply only to their recorded build.

# 006 — Debug world view

Status: implemented 2026-09-28; foundation review complete.

## Goal

Make the hidden world and worker accounting inspectable in a simple developer view.

## Why this exists

The foundation needs observability before scouting adds movement and knowledge.

## Dependencies

[005](005_home_pile_worker_ledger.md); read [ARCHITECTURE](../contracts/ARCHITECTURE.md), [UI_RULES](../contracts/UI_RULES.md), and [CODING_RULES](../../../CODING_RULES.md).

## Allowed scope

`src/debug/`, `scenes/debug/`, minimal Main wiring, and isolation checks. Keep all truth-view code separate from future player presentation.

## Required behavior

1. Add development action debug_world (F3) to toggle a clearly labeled `DEBUG: WORLD TRUTH` overlay/view, initially hidden. Draw 40×40 bounds, home, all four resource nodes, coordinates and IDs. Optional simple exposure tint/legend may read existing terrain data.
2. Scale world coordinates to the viewport with a single invertible transform; picking must use its inverse. Distinguish home and resource categories through labels/shapes as well as color. Utilitarian graphics are sufficient.
3. Selecting a node shows raw ID, definition, position, quantity, active state. Selecting home shows queen count, total/available and each ledger commitment. Show seed, simulation time, and pause/speed diagnostically.
4. DebugTools receives explicit read-only access/snapshots from the active run. Drawing, picking, and toggling must not mutate gameplay, consume the run RNG, or create colony knowledge.
5. Gate creation/input in non-debug builds; F3 cannot expose truth in normal release play. Keep headless simulation usable with no debug view instantiated.
6. Later tasks may add scouts, Known Nodes, routes, and chemistry inspection when those systems exist. Do not manufacture those systems now.

## Explicit non-goals

No player map/minimap, sensory UI, discovery, scouts, trails, debug mutation editor, final art, or new simulation systems. Do not implement future systems not explicitly requested.

## Interfaces to preserve

This is the explicit debug exception to knowledge-only presentation. Do not reuse its live-world data access in OUTWARD. UI actions never become authoritative state.

## Acceptance tests

- Existing headless suite still runs without loading the debug scene.
- Given fixed viewport/bounds, world→screen→world round trips for home and each node within a documented floating-point tolerance.
- With identical seeded runs and tick inputs, repeated debug refresh/toggle/selection leaves authoritative snapshots and next RNG draw equivalent to the run without a debug view.

## Manual verification

Run Main: F3 shows home (20,20), the four fixture nodes at their authored coordinates, and matching raw fields on selection; resizing preserves picking. F3 hides it. Verify the release guard through a release build when export templates are available; otherwise record that release-export check as not run and inspect/test the guard explicitly.

## Done when

Read-only inspection and isolation checks pass, evidence/limitations are recorded, and Main remains runnable. One logical commit. **Review the foundation before expanding 007:** clock, isolated seeded run, hidden authored world, worker ledger, and development-only truth view. No scouting implementation in this card.

## Implementation handoff and foundation review

- Added src/debug/debug_world_model.gd (detached snapshots, invertible transform, picking) and debug_world_view.gd (development-only rendering/input), minimal GameRoot wiring, and tests/test_debug_world.gd. Corrected InputMap device matching and logical F3 binding.
- Pinned Godot full suite: 1,326 checks, 0 failures; headless Main boots without creating the debug view. Transform tolerance is 0.0001 world meters at three viewport sizes. Debug activity preserves authoritative state and next RNG draw.
- Windows manual: initially hidden; F3 shows/hides; home shows 1 queen/40 workers; all four labeled resources match fixture positions; carbohydrate and water picking show quantity 100 and active=true. Picking remains correct after maximizing from 1000x700. Final label layout inspected.
- Release export not run: export templates are absent. Creation/input guards inspected and guard predicates tested. Android/touch hardware not tested.
- Foundation review: clock owns time; runs own independent RNG/world/colony; invalid snapshots are atomic; worker commitments reconcile; debug receives detached dictionaries and is lazy-loaded only for graphical debug builds. No normal presentation or knowledge exists yet. No architecture change required.
- Next: expand 007 with explicit provisional scout cap, mission timing, terrain pathing and failed-return policy before coding.

