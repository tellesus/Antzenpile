# Working on Antzenpile

Translate the design into code; do not invent major game systems.

## Begin each task

- Read the current card, `docs/CODING_RULES.md`, and the relevant sections of `docs/ARCHITECTURE.md` and `docs/DECISIONS.md`. Read the relevant `DATA_MODEL.md` and `UI_RULES.md` sections when state or presentation changes. Search for affected contracts; do not reread every completed card or the entire historical roadmap on each task.
- Inspect the existing implementation and task dependencies. Work on one bounded task; do not implement later cards opportunistically.
- Use the current section of `docs/POST_SLICE_PLAN.md` for order. Define a player-visible outcome and its verification before expanding a new card; split simulation and presentation only when each part has a useful independent handoff. Tasks 001–044 are historical records, including deferred 034.
- Consult README for current scope. Do not claim future commands or tests exist until their task creates and verifies them.

## Preserve the design

- Godot/GDScript; Windows first, mobile-safe rendering and input from the beginning. Preserve the pinned engine after bootstrap.
- Keep hidden 2D reality, simulation, colony knowledge/perception, and presentation separate. Normal UI consumes approved presentation data, never hidden world objects. Debug truth access must stay development-only.
- Simulation must run headlessly. Lightweight typed state owns gameplay; scene nodes and graphics do not.
- Aggregate workers, brood, and trail travelers. Scouts are the capped, individually simulated exception. Every worker transfer goes through the authoritative ledger.
- Keep TrailRoute and TrailSegment separate, even with one segment per prototype route. Pheromone and familiarity are distinct.
- OUTWARD is a rotating 2D sensory panorama, not a physical camera or minimap. INWARD is an abstract functional network, not a tunnel floorplan.
- Darkness is information. Preserve negative space, thin luminous trails, capped visual representatives, restrained effects, and readability without bloom.

## Finish each task

- Run targeted checks while iterating, then the full headless suite once after the final code change. Run import for new/changed Godot resources, Main smoke for runtime or scene changes, and graphical/manual checks for affected presentation. Repeat a gate after a fix that could affect it; do not run every gate after each small edit. Record actual results and anything not run.
- Update the card with concise completion evidence, changed-file groups, and a brief handoff. Update architecture/data/UI/decision docs only where a contract or decision changed; refresh README at a feature milestone, not for every card.
- Use a small logical local commit per bounded card and preserve unrelated work. Publish related commits together after a feature milestone or at the end of the work session; keep their individual history.
- Routine implementation choices may follow the documented defaults. If specifications conflict or a choice changes locked architecture/gameplay, isolate the conflict and ask for a design decision; continue independent work. Record accepted changes in `docs/DECISIONS.md`.
- Keep working across cards without waiting for acknowledgement. Give the player a concise report at a feature milestone, a material change of direction, or a real blocker; ask for input only when the design sources cannot settle a consequential choice.
