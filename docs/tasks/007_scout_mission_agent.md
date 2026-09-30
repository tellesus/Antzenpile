# 007 — Scout mission and ScoutAgent

Historical implementation card: task [023](023_persistent_scout_search.md) supersedes the fixed 30-second mission deadline below. Scouts now search until a new source is confirmed or reachable ground is exhausted.

Status: implemented 2026-09-28.

## Goal

Give the colony a capped individual scout that leaves, explores, and returns.

## Why this exists

Scouts are the exceptional individual agents that will gather evidence.

## Dependencies

[006](006_debug_world_view.md) and the preceding task sequence. Read [ARCHITECTURE](../ARCHITECTURE.md), [CODING_RULES](../CODING_RULES.md), and relevant [DATA_MODEL](../DATA_MODEL.md)/[UI_RULES](../UI_RULES.md) contracts.

## Allowed scope

General mission, directional bias, departure/exploration/return state machine; simple reliable obstacle/terrain-cost pathing and ledger commitment.

## Required behavior

One worker is committed per scout; return releases that same worker. Bound active detailed scouts. Use run RNG and fixed ticks; add scout positions/states to debug inspection.

Resolved below as provisional fixture defaults; see decision A08.

## Explicit non-goals

Discovery, observations, knowledge, and trails. Do not implement future systems not explicitly requested.

## Interfaces to preserve

Ledger ownership, hidden world, fixed clock, and individual-scout/aggregate-worker distinction.

## Acceptance tests

Seeded missions repeat; state transitions and return conserve workers. Manually inspect departure/exploration/return in the debug world.

## Manual verification

Run the relevant prototype/debug scene and inspect the behavior above. On expansion, name exact files, commands, fixtures, and expected results; do not treat this roadmap as a fully specified coding prompt.

## Done when

The expanded card's checks pass, existing behavior remains intact, and the handoff records changed files, tests, limitations, and next task. One logical commit.

## Executable expansion after foundation review

- Files: `src/sim/scouting/` configuration, coarse terrain graph, ScoutAgent state, and ScoutSystem; `data/scouting/default_scouts.tres`; RunState snapshots; SimulationController command/tick wiring; debug inspection; `tests/test_scouting.gd`.
- Provisional fixture tuning: cap 4 active scouts, speed 1 meter/second at terrain cost 1, mission exploration budget 30 simulated seconds, target distance 8–12 meters, directional cone ±45 degrees. General missions choose any bearing. Values live in a typed Resource. These are tunable prototype values, not locked balance.
- `dispatch_scout(origin_id, bearing = null)` validates the origin, available worker, cap and finite optional bearing. Reject without worker/RNG/ID changes if no traversable target can be found in 16 attempts. No resource coordinates inform target choice.
- Use a deterministic cardinal grid at 1-meter resolution and stable point IDs. Rasterize obstacles conservatively; terrain movement cost weights both route choice and travel speed. Home lies on the fixture grid. Unsupported off-grid origins fail explicitly. Pathfinding needs no scene tree.
- An accepted command commits exactly one worker under its scout ID. `departing` lasts one fixed tick; `exploring` follows its planned outward path and remains at its endpoint until the 30-second budget expires; `returning` retraces visited waypoints from its actual position. Return time is additional to the exploration budget. No observation/discovery behavior yet.
- Record visited waypoints, path cursor, elapsed time, mission ID and phase in explicit snapshots. IDs and update order are stable. On arrival at home, release the worker and remove the empty commitment/finished agent; no growing archive of completed agents.
- Static authored terrain guarantees the recorded return path. If a debug/test fixture changes terrain and blocks travel, keep the scout and its worker committed with a blocked phase and retry when passable; do not invent mortality or teleportation. Dynamic terrain, rescue and lost-scout gameplay remain outside this card.
- Debug can inspect scout position/phase and offers an explicitly labeled dispatch control for a general mission. It sends a controller command; drawing and picking remain read-only. Player scouting controls wait for their presentation task.

## Exact validation

Run the pinned engine import, full headless suite, and Main smoke command from README. Add cases for cap/insufficient-worker rejection atomicity, same-seed trajectories, different seeds, all phases and eventual return, slower expensive terrain, obstacle avoidance/unreachable targets, blocked return retaining workers, and populated JSON continuation. Assert conservation throughout missions. Manually dispatch a scout in F3 and observe departure, exploration and return with availability 40→39→40. No hidden node may create knowledge or signals.


## Implementation handoff

- Implemented the files and contracts listed in the expansion; added empty-commitment retirement to WorkerLedger. Completed missions leave no growing agent/commitment history.
- Pinned Godot full suite: 2,326 checks, 0 failures. Includes seeded trajectories, different seeds, cap and rejected-command RNG atomicity, obstacle/cost routing, population conservation, blocked return, malformed snapshots, and mid-mission JSON continuation.
- Windows manual: F3 dispatch showed departing, exploring, returning; available workers 40 -> 39 -> 40 with the scout commitment present until actual arrival. Main remains runnable. Debug dispatch is an explicit command exception; refresh/drawing/picking remain read-only.
- Limitations: provisional coarse-grid movement and exploration budget; no discovery/observations, mortality, dynamic-terrain gameplay, player controls, or mobile-device verification. Snapshot migration remains deferred until the save task.
- Next: expand 008 scout discovery/observations; preserve private carried evidence until return.
