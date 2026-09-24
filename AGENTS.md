# Working on Antzenpile

Translate the design into code; do not invent major game systems.

## Begin each task

- Read the assigned card, `docs/ARCHITECTURE.md`, `docs/CODING_RULES.md`, and relevant entries in `docs/DECISIONS.md`. Read `DATA_MODEL.md` for state changes and `UI_RULES.md` for presentation work.
- Inspect the existing implementation and task dependencies. Work on one bounded task; do not implement later cards opportunistically.
- Tasks 001–006 are executable specifications. Tasks 007–022 are roadmap cards to expand against the actual code before implementing. Review the skeleton after 006.
- Current repository state is documentation only. Do not claim commands or tests exist until their task creates and verifies them.

## Preserve the design

- Godot/GDScript; Windows first, mobile-safe rendering and input from the beginning. Preserve the pinned engine after bootstrap.
- Keep hidden 2D reality, simulation, colony knowledge/perception, and presentation separate. Normal UI consumes approved presentation data, never hidden world objects. Debug truth access must stay development-only.
- Simulation must run headlessly. Lightweight typed state owns gameplay; scene nodes and graphics do not.
- Aggregate workers, brood, and trail travelers. Scouts are the capped, individually simulated exception. Every worker transfer goes through the authoritative ledger.
- Keep TrailRoute and TrailSegment separate, even with one segment per prototype route. Pheromone and familiarity are distinct.
- OUTWARD is a rotating 2D sensory panorama, not a physical camera or minimap. INWARD is an abstract functional network, not a tunnel floorplan.
- Darkness is information. Preserve negative space, thin luminous trails, capped visual representatives, restrained effects, and readability without bloom.

## Finish each task

- Run the card's relevant headless tests and manual checks. Report actual results, commands, and anything not run. Do not add dependencies or redesign systems to avoid a failing invariant.
- Update the card with completion evidence, changed files, and a brief handoff. Keep the docs consistent with implemented contracts.
- Use a small logical commit. Preserve unrelated work.
- Routine implementation choices may follow the documented defaults. If specifications conflict or a choice changes locked architecture/gameplay, isolate the conflict and ask for a design decision; continue independent work. Record accepted changes in `docs/DECISIONS.md`.
