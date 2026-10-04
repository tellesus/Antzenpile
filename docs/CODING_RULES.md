# Coding rules

## Scope and style

- Implement one bounded task card in a small logical commit. A card should usually end in a player-visible behavior with its simulation, presentation, and evidence together; split it when the pieces need separate verification or a useful independent handoff. Avoid unrelated cleanup and unused future-system folders/classes. Expand roadmap cards against actual code before implementation.
- Prefer typed GDScript, explicit fields and ownership, short focused functions, and descriptive names. Use snake_case files/methods/fields and PascalCase class names. Comments explain invariants and non-obvious choices.
- Data and balance live in authored definitions/configuration. Keep provisional values visibly tunable. Favor simple, inspectable algorithms over speculative optimization or framework building.
- Do not introduce plugins, addons, or external libraries unless the task explicitly authorizes them; otherwise obtain approval. Keep the prototype nearly dependency-free. No engine upgrades as incidental cleanup.
- Prefer composition to deep inheritance. After bootstrap, keep main runnable between tasks; experimental visual work belongs on a separate branch. Use commit subjects such as `task 012: implement trail allocation`.

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
| Save/load | Continued state equals saved/reloaded continuation |
| Presentation | No truth leaks; bearing wrap; mouse/touch shared paths; debug isolation |

Run focused checks during implementation and the full headless suite once when code is final; record actual timing as the suite grows rather than assuming its old four-second cost. Bounded history now adds save/continuation coverage; repeated gates still need a changed result or implementation reason. Repeat it when a subsequent fix can affect simulation or shared contracts. Run the editor import when adding or changing Godot resources, Main smoke for runtime/scene changes, and a graphical/manual probe for affected UI, art, input or audio. Do not routinely repeat all three for documentation-only changes or after an unchanged passing result. A headless pass does not prove renderer performance, touch usability, or music synchronization. Record platform and engine version for performance evidence; do not invent device budgets or claim Android validation from a desktop-only run.

## Handoff

Record status, changed-file groups, checks/results, known limitations, and the next bounded action in the task card. Update only contracts/decisions actually changed; keep README as a milestone overview rather than duplicating every card's history. Make local commits per card and publish related commits as a group at a feature milestone or session end; publishing must be complete before a final handoff. Report progress to the player at milestones and blockers without pausing for routine approval. Keep meaningful gameplay history separate from switchable development logs.
