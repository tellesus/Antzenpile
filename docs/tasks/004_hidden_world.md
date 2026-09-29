# 004 — Hidden world and World Nodes

Status: implemented 2026-09-28.

## Goal

Load a small authored 2D world with typed resource definitions and runtime World Nodes.

## Why this exists

Scouts must later discover real objects that already exist independently of knowledge and UI.

## Dependencies

[003](003_seeded_run_state.md); read [ARCHITECTURE](../ARCHITECTURE.md), [DATA_MODEL](../DATA_MODEL.md), [CODING_RULES](../CODING_RULES.md), and decision A04.

## Allowed scope

`src/sim/world/` state/loader, resource/terrain definition classes as needed, authored `.tres` data, RunState ownership, and headless fixture tests. Create `data/scenarios/backyard_slice.tres` for fixture content.

## Required behavior

1. WorldState owns bounds (0,0)–(40,40), static terrain regions, and nodes keyed by stable unique ID. Coordinates are meters, +x east/+y south. Reserve home position (20,20) for 005.
2. Define carbohydrate/protein/water as typed immutable resource definitions. Each WorldNodeState has id, definition_id, position, quantity, active, properties. Definitions and scenario placement are data, not hardcoded system branches.
3. Use this provisional authored fixture: `carb_exposed` (30,20), `carb_sheltered` (10,20), `protein_01` (15,30), `water_01` (25,10). Initial quantities are 100 abstract units each, active=true. These are test values, not balance commitments.
4. Represent exposed terrain on x≥20 with exposure 1 and sheltered terrain on x<20 with exposure 0. Both are traversable at cost 1 initially; retain explicit movement-cost/traversability fields for later obstacles. No pathfinder or rain behavior yet.
5. Attach the world to RunState. Load the same authored geometry for every seed; deterministic does not imply procedural. Do not add random variation merely to consume RNG.
6. Validate unique IDs, definition references, bounds, finite/nonnegative quantities, and terrain data. Loading malformed content fails with useful diagnostics, without partial state replacement. Include explicit world/node dictionary round trips; no disk save UI.

## Explicit non-goals

No scouts, discovery/knowledge, player signals, procedural maps, depletion/regrowth simulation, pathfinding, or weather. Do not implement future systems not explicitly requested.

## Interfaces to preserve

World positions/quantities are hidden truth. Only simulation and later explicit debug tools may query them. Normal presentation must wait for knowledge-derived signals. Runtime mutations cannot alter definitions or another run.

## Acceptance tests

- Fixture has four nodes: two carbohydrate, one protein, one water; all positions are in bounds and IDs resolve.
- Independent loads have identical canonical data but independent mutable state. Mutate one node's quantity: other load and definitions stay unchanged.
- Invalid duplicate ID, missing definition, out-of-bounds position, and negative quantity are rejected. Round trip preserves valid node/terrain data.
- Loading the world creates no player knowledge or presentation objects and needs no scene tree.

## Manual verification

Run tests and inspect one compact dump of bounds/node IDs/coordinates/terrain. Main still boots. Visible map inspection waits for 006.

## Done when

The authored world loads and validates headlessly, fixture assumptions are recorded, and handoff lists files/results/limitations. One logical commit; next task 005.

## Implementation handoff

- Added typed definitions and authored data in data/resources and data/scenarios, runtime world state/validation under src/sim/world, RunState ownership, and tests/test_world.gd.
- Pinned Godot headless suite: 268 checks, 0 failures; Main startup passed. Inspected four node IDs/positions and 100-unit quantities.
- Bounds use Godot half-open containment (0 <= coordinate < 40). Generic properties preserve JSON number values; integer-versus-float identity is not their contract. Invalid restores preserve exact prior runtime state.
- No procedural generation, knowledge, or depletion. Next: 005 worker ledger.

