# Coding rules

**Current development save policy (2026-10-15):** [Same-build saves only](SAVE_POLICY.md). Earlier requirements to preserve/load/migrate previous-build saves are superseded and tabled until true release preparation. Historical implementation/evidence below does not create a compatibility goal.

## Scope and style

- Current design/order lives in `SYSTEMS_BIBLE.md`, `ROADMAP_1_0.md` and their catalogs; `CURRENT_BUILD.md` records implemented status. Archived documents are historical evidence only. Do not treat a catalog entry or future schema as an existing API.
- A modular content card names its system/catalog IDs and implements one complete useful entry before adding more. Reuse typed family owners/definitions; do not build a universal effect interpreter or speculative future scaffolding.
- Implement one bounded task card in a small logical commit. A card should usually end in a player-visible behavior with its simulation, presentation, and evidence together; split it when the pieces need separate verification or a useful independent handoff. Avoid unrelated cleanup and unused future-system folders/classes. Expand roadmap cards against actual code before implementation.
- Prefer typed GDScript, explicit fields and ownership, short focused functions, and descriptive names. Use snake_case files/methods/fields and PascalCase class names. Comments explain invariants and non-obvious choices.
- Data and balance live in authored definitions/configuration. Keep provisional values visibly tunable. Favor simple, inspectable algorithms over speculative optimization or framework building.
- Use the specifically authorized art/audio tools, resources and addon below when useful, without repeat approval. Ask before adding tools/resources or dependencies outside the approved scope. Prefer focused dependencies that improve quality or reduce maintenance. Paid services are not authorized; the $0 budget remains. No engine upgrades as incidental cleanup.
- Prefer composition to deep inheritance. After bootstrap, keep main runnable between tasks; experimental visual work belongs on a separate branch. Use commit subjects such as `task 012: implement trail allocation`.

## Authorized art and audio resources

Player approval, 2026-10-16: the following specific choices are authorized for relevant development work. Approval permits their use; it does not require installing every tool or replacing working systems.

| Tool or resource | Authorized use |
| --- | --- |
| [Blender](https://www.blender.org/) | Continue and expand offline modeling, materials and rendered assets for the 2D game. |
| [Material Maker](https://www.materialmaker.org/) | Procedural material/texture authoring and exported assets. |
| [Poly Haven](https://polyhaven.com/license/) and [ambientCG](https://docs.ambientcg.com/license/) | Free CC0 material assets, processed for the game's visual direction. |
| [Godot Shaders](https://godotshaders.com/license/) | Selected MIT/CC0 shader examples adapted and tested in the pinned Compatibility renderer; verify each entry's license. |
| [Freesound](https://freesound.org/help/faq/) | Free sound recordings, preferably CC0; verify each recording's license and meet attribution requirements where applicable. |
| [Audacity](https://www.audacityteam.org/) | Offline editing, processing and assembly of audio. |
| [Surge XT](https://github.com/surge-synthesizer/surge) | Offline synthesis of musical voices, ambience and sound effects. |
| [Godot Sound Manager](https://github.com/nathanhoad/godot_sound_manager) | Evaluate and integrate the focused MIT-licensed GDScript audio addon when it benefits the existing implementation. |
| [Godot interactive music streams](https://docs.godotengine.org/en/stable/classes/class_audiostreaminteractive.html) | Use the engine's built-in clip/transition facilities when suitable. |

Keep offline authoring tools separate from shipped runtime requirements. Retain asset provenance, license/attribution records and reproducible production sources; pin adopted addon versions and verify affected Windows exports. The existing VCSL sample use remains authorized. This list does not authorize paid services, paid extras offered by these projects, unrelated plugins, engine/renderer changes or major architectural replacements. If another resource is needed, ask the player; their willingness to consider it is not advance approval. The earlier blanket dependency caution must not prevent use of these approved choices.

## Boundaries

- Simulation is headless, uses only run-owned seeded randomness, and advances through fixed ticks. No UI text, camera, particle, audio, or input-key dependencies in simulation state/systems.
- Views consume knowledge-derived sensory data or approved colony summaries; send semantic commands back. Simulation owns validation and mutation. Debug access is an explicit exception, never a normal presentation shortcut.
- Every worker commitment/release/population change uses the ledger. Do not repair a failed invariant by silently editing totals. Route/cohort counts are reconciled views of commitments, not additional workers.
- Player-colony jobs check `PileState.workers_assignable` and allocate through `PileState.allocate_workers` so existing brood keeps its carers. Raw ledger availability includes those carers; direct allocation remains for isolated ledger tests, legacy fixtures and the separate rival ledger.
- Authored Resources are immutable definitions. Mutable runtime arrays/dictionaries are per-run. Use stable IDs and explicit versioned serialization; no opaque scene save as authoritative state.
- Keep simulation/visual RNG streams separate. Stable processing order is required for repeatable seeds; do not rely on incidental scene order.

## Validation

`tests/run_tests.gd` returns a nonzero exit on failure. Run from the repository root using the pinned Godot console executable:

```text
godot --headless --path . --script res://tests/run_tests.gd
```

See README for verified Windows setup. Tests should exercise behavior and invariants, not reproduce implementation details. Introduce relevant tests with the system, not empty future suites.

| System arrives | Required evidence |
| --- | --- |
| Clock | Pause, fixed steps, fractional remainder, equal simulated results at 1×/4×/16×/64× |
| Run/world | Reproducible seed, isolated runs, valid IDs/bounds, lossless RNG continuation |
| Workers | Repeated allocation/release plus invalid-operation atomicity and conservation |
| Scouts/knowledge | Discovery and return; hidden node produces no knowledge or signal before delivery |
| Trails | Allocation, real recall travel, cohort accounting, delayed resource delivery |
| Chemistry/rain | Pheromone decay, slower familiarity loss, exposed vs sheltered rain response |
| Brood/chambers | Maturation conserves accounting; labor/resources/time gate development |
| Save/load | Same-build continued state equals saved/reloaded continuation; different builds reject atomically. No old-save migration work. |
| Presentation | No truth leaks; bearing wrap; mouse/touch shared paths; debug isolation |

Run focused checks during implementation and the full headless suite once when code is final; record actual timing as the suite grows rather than assuming its old four-second cost. Bounded history now adds save/continuation coverage; repeated gates still need a changed result or implementation reason. Repeat it when a subsequent fix can affect simulation or shared contracts. Run the editor import when adding or changing Godot resources, Main smoke for runtime/scene changes, and a graphical/manual probe for affected UI, art, input or audio. Do not routinely repeat all three for documentation-only changes or after an unchanged passing result. A headless pass does not prove renderer performance, touch usability, or music synchronization. Record platform and engine version for performance evidence; do not invent device budgets or claim Android validation from a desktop-only run.

## Handoff

Record status, changed-file groups, checks/results, known limitations, and the next bounded action in the task card. Update only contracts/decisions actually changed; keep README as a milestone overview rather than duplicating every card's history. Make local commits per card and publish related commits as a group at a feature milestone or session end; publishing must be complete before a final handoff. Report progress to the player at milestones and blockers without pausing for routine approval. Keep meaningful gameplay history separate from switchable development logs.

Release correctness gate193: never place a state-changing call inside `assert(...)`; the non-debug engine removes its entire argument expression. Evaluate a typed result first, then assert that result. `tools/package/check_release_gameplay.py --godot <pinned-console> --templates <pinned-template-folder>` audits runtime assertion calls and exports a separate actual-release gameplay test package with isolated data. Run it after changes to affected simulation or package behavior; editor execution of a packaged PCK is not a substitute. `--baseline-ref e8742f4` reproduces the earlier missing-recruitment-pool defect for regression evidence.
