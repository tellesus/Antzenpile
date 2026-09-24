# 006 — Debug world view

Status: ready specification; implementation not started.

## Goal

Make the hidden world and worker accounting inspectable in a simple developer view.

## Why this exists

The foundation needs observability before scouting adds movement and knowledge.

## Dependencies

[005](005_home_pile_worker_ledger.md); read [ARCHITECTURE](../ARCHITECTURE.md), [UI_RULES](../UI_RULES.md), and [CODING_RULES](../CODING_RULES.md).

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
