> **ARCHIVE ONLY — frozen 2026-10-04.** Historical record; not an active plan, current contract or implementation instruction. Use the [current documentation](../../../README.md). Original path: `docs/tasks/043_honeydew_mutualism_simulation.md`. Historical status and recommendations below apply only to their recorded build.

# 043 — First honeydew mutualism: simulation and evidence

Status: complete (2026-10-01). Part 4 §§87–95 and 145, with the backyard ecology of Part 6, define this bounded beneficial interaction.

## Goal

Add one discoverable honeydew-producing insect colony that creates renewable carbohydrate. Ordinary foraging first exploits it; after a loaded return, the colony may commit separate workers to protect it. Tending raises its output and protects producer condition against simple predator pressure. This is the first ecology relationship, not a full species, combat or diplomacy system.

## Implementation contract

- Author one `aphid_01` carbohydrate World Node in the backyard, away from existing sources. Its initial quantity and periodic output/condition rates live in a typed, diffable ecology definition. The source remains hidden until scout or trail evidence returns. It is a physical source: collection subtracts its stored quantity through existing aggregate TransitCohorts.
- RunState owns one typed HoneydewState with `unknown`/`exploited`/`tended` relationship, producer condition, and separate protection worker count. The transition to `exploited` derives from a loaded home return on the known aphid route, not a hidden source update. A semantic command can start tending only after that evidence and available labor. It creates one `other` worker-ledger commitment, six workers by provisional default; a stop command releases them and returns to `exploited`.
- Every authored 30-second ecology pulse adds baseline carbohydrate while the producers survive. Unprotected predator pressure slowly lowers producer condition to a nonzero floor; tending slowly restores it and raises output. Cap physical carbohydrate at the authored source capacity. These are provisional test values, not general economy tuning. No abstract predator kills workers in this card.
- Existing version-5 saves without HoneydewState still load. New saves validate the relationship, condition, commitment and source identity atomically. A mid-pulse save continues exactly, and no normal perception gets producer condition, schedule or exact source quantity.
- The normal-play interaction and context card are card 044. Keep this card headless and do not add rival colonies, predator agents, aphid population genetics or a separate ecology screen.

## Verification

Test ordinary discovery and loaded return, command rejection before evidence, atomic labor commitment/release, output advantage under tending, pressure on condition, capacity, pause/speed, worker conservation, hidden knowledge, and exact save continuation. Run pinned import, Main smoke, and the full headless suite. Document the implemented contracts and commit one logical change.

## Completion evidence and handoff

- Authored `aphid_01` and typed honeydew definition/state. EcologySystem produces physical carbohydrate on fixed ticks, while RunState validates evidence and the separate ledger commitment before restoring. SimulationController exposes semantic start/stop commands; no normal control is shown yet.
- `tests/test_honeydew.gd` follows an ordinary scout and loaded route, compares tended/untended output and condition, checks labor conservation, capacity, pause/speed, hidden presentation, invalid snapshots and a pre-feature version-5 save. Full headless runner: **4110 checks, 0 failures**. Pinned import and headless Main smoke produced no script errors; the sandbox could not write Godot's user-level editor settings/logs and reported a missing root certificate store.
- Changed files: backyard scenario and honeydew definition; HoneydewState, EcologySystem, RunState, SimulationController; world/ecology fixture tests, new honeydew test and runner; README and architecture/data/decision/plan docs; this card and card 044.
- Next: [044](044_honeydew_mutualism_controls.md) gives the player a knowledge-safe contextual way to tend or withdraw protection. The provisional rates require later playtesting alongside route labor and consumption; no balance conclusion is implied.
