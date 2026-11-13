> **ARCHIVE ONLY — frozen 2026-10-04.** Historical record; not an active plan, current contract or implementation instruction. Use the [current documentation](../../../README.md). Original path: `docs/tasks/023_persistent_scout_search.md`. Historical status and recommendations below apply only to their recorded build.

# 023 — Persistent scout search and trace localization

Status: complete; player's novelty choice accepted 2026-09-30.

## Goal

Remove the fixed 30-second/8–12 m mission ceiling that can leave water undiscoverable. A scout keeps exploring beyond its initial target, follows a sensed resource trace until close enough to confirm it, then returns with its private evidence. If no reachable unexplored area or relevant source remains, it returns without pretending to have found one.

## Scope and contracts

- Keep the individual-scout cap, run-owned RNG, terrain-aware cardinal movement, breadcrumb return, ledger commitment and return-only knowledge delivery. No hidden world query may reach normal UI.
- Reuse `ScoutAgent`'s existing path, return breadcrumbs, evidence and mission fields where possible; keep version-5 disk saves readable. A deterministic grid-frontier search may use hidden terrain for traversal but cannot peek at resource locations to choose a target.
- A broad chemical cue redirects search through the existing estimate; confirmation uses authored proximity sensing rather than point contact. Seek a source the colony has not already learned, while still collecting updated evidence for known sources encountered on the way.
- Search must terminate when the reachable grid has been exhausted. No arbitrary wall-clock deadline, unbounded random wandering, scout loss or new rescue/mortality mechanic.

## Verification

Add headless cases for discovery outside the old mission range and past 30 seconds; trace approach/confirmation before return; already-known source pass-through; empty/exhausted world returning and releasing its worker; deterministic save/reload continuation mid-search; labor conservation. Run the pinned Godot 4.7.2 import, full suite and Main smoke. Manually inspect one OUTWARD scout path with F3; normal OUTWARD must show no private evidence before return.

## Non-goals and handoff

No new player map, remote automation, new resource or reproduction system. Update architecture/data/decision/README contracts with measured behavior. Record actual tests, limitations and one logical commit before starting 024.

## Completion evidence and handoff

- ScoutSystem now continues from its initial 8–12 m target through unvisited reachable grid cells, favoring outward movement at equal distance. It pursues a new-source sensory estimate and nearby frontier until proximity confirmation, then follows actual breadcrumbs home. Already-known sources can refresh private evidence but do not end the search. Exhausted reachable ground triggers an empty return. The 30-second deadline and authored setting are removed; the individual scout cap, ledger accounting and delayed colony knowledge remain intact.
- `tests/test_persistent_scout.gd` verifies water beyond the initial range on costly terrain, a search exceeding 30 seconds, confirmation before return, a known carbohydrate pass-through to new water, exact JSON continuation mid-search, and worker release after reachable ground is exhausted. The distant water report arrived at 203.25 simulated seconds in the deliberately slowed fixture. Existing scouting/observation/knowledge/perception tests were adjusted to assert state transitions rather than the obsolete fixed mission duration. Snapshot/disk format remains version 5 with no added fields.
- Pinned Godot 4.7.2 import, full headless suite and Main smoke passed: 3,541 checks, zero failures. A graphical F3 inspection at 35 seconds showed the scout still exploring at (28.69, 20), one worker committed, and zero colony knowledge/signals while water remained farther east. The normal OUTWARD view stayed empty as designed.
- Updated README, architecture/data/decision/slice evaluation contracts and registered task 024 as the next bounded playtest follow-up. The current UI has no early scout-recall action; an empty world can therefore keep a scout away until reachable terrain is exhausted. No mobile-device test was run.
- Changed files: `src/sim/scouting/scout_system.gd`, `src/sim/scouting/scout_config.gd`, `data/scouting/default_scouts.tres`, new focused test and runner registration, adjusted existing timing tests, `README.md`, `docs/ARCHITECTURE.md`, `docs/DATA_MODEL.md`, `docs/DECISIONS.md`, `docs/VERTICAL_SLICE.md`, `docs/SLICE_EVALUATION.md`, this card and the drafted task-024 card. Next: implement rain-water collection in 024.
