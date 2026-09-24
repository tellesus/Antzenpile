# Coding rules

## Scope and style

- Implement one task card in a small logical commit. Avoid unrelated cleanup and unused future-system folders/classes. Expand roadmap cards against actual code before implementation.
- Prefer typed GDScript, explicit fields and ownership, short focused functions, and descriptive names. Use snake_case files/methods/fields and PascalCase class names. Comments explain invariants and non-obvious choices.
- Data and balance live in authored definitions/configuration. Keep provisional values visibly tunable. Favor simple, inspectable algorithms over speculative optimization or framework building.
- Do not introduce plugins, addons, or external libraries unless the task explicitly authorizes them; otherwise obtain approval. Keep the prototype nearly dependency-free. No engine upgrades as incidental cleanup.
- Prefer composition to deep inheritance. After bootstrap, keep main runnable between tasks; experimental visual work belongs on a separate branch. Use commit subjects such as `task 012: implement trail allocation`.

## Boundaries

- Simulation is headless, uses only run-owned seeded randomness, and advances through fixed ticks. No UI text, camera, particle, audio, or input-key dependencies in simulation state/systems.
- Views consume knowledge-derived sensory data or approved colony summaries; send semantic commands back. Simulation owns validation and mutation. Debug access is an explicit exception, never a normal presentation shortcut.
- Every worker commitment/release/population change uses the ledger. Do not repair a failed invariant by silently editing totals. Route/cohort counts are reconciled views of commitments, not additional workers.
- Authored Resources are immutable definitions. Mutable runtime arrays/dictionaries are per-run. Use stable IDs and explicit versioned serialization; no opaque scene save as authoritative state.
- Keep simulation/visual RNG streams separate. Stable processing order is required for repeatable seeds; do not rely on incidental scene order.

## Validation

Task 001 creates `tests/run_tests.gd` with a nonzero exit on failure. Run from the repository root using the pinned Godot console executable:

```text
godot --headless --path . --script res://tests/run_tests.gd
```

This is the planned interface until bootstrap documents the verified local executable. Tests should exercise behavior and invariants, not reproduce implementation details. Introduce relevant tests with the system, not empty future suites.

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

Run relevant headless tests plus the full small suite when feasible. Manually verify visual/input/audio behavior where the card requires it. A headless pass does not prove renderer performance, touch usability, or music synchronization. Record platform and engine version for performance evidence; do not invent device budgets or claim Android validation from a desktop-only run.

## Handoff

Record status, changed files, commands/checks and results, known limitations, and next bounded action in the task card. Update contracts/decisions when implementation resolves provisional details. Report a blocker precisely; do not substitute a different design silently. Keep meaningful gameplay history separate from switchable development logs.
