# Working on Antzenpile

**Current development save policy (2026-10-15):** [Same-build saves only](docs/SAVE_POLICY.md). Earlier requirements to preserve/load/migrate previous-build saves are superseded and tabled until true release preparation. Historical implementation/evidence below does not create a compatibility goal.

Translate the current design into code; do not invent major game systems during implementation. When the player explicitly requests design/planning work, develop it in the systems bible/catalogs and distinguish planned rules from implemented contracts.

**Player direction (2026-10-18):** this is a personal game made for fun, with one player. Prioritize enjoyable play and concrete feedback. Public-release preparation, clean-machine campaigns and shipping ceremony are tabled. Keep useful regression checks, source history and a fresh playable Windows build; these support development rather than a professional release program.

## Begin each task

- Follow `docs/SAVE_POLICY.md` and `docs/DEVELOPMENT_GOALS.md`: development saves are same-build only. Do not maintain, investigate, migrate or add compatibility tests for previous-build saves. Older card requirements are superseded; revisit only for true public release preparation.

- `main` is the canonical development game. Inspect status, branch and upstream before editing; fetch and start from current `origin/main`, preserving local user files. Do not resume historical topic branches. Use a short-lived branch only when needed and integrate its completed, authorized work into `main` at delivery. Refresh the Windows package after runtime changes so the default playable build includes that work. See `docs/tasks/177_main_consolidation.md`.

- Read the current card, `docs/CODING_RULES.md`, and the relevant sections of `docs/ARCHITECTURE.md` and `docs/DECISIONS.md`. Read the relevant `DATA_MODEL.md` and `UI_RULES.md` sections when state or presentation changes. Search for affected contracts; do not reread every completed card or the entire historical roadmap on each task.
- Inspect the existing implementation and task dependencies. Work on one bounded task; do not implement later cards opportunistically.
- Use `docs/README.md`, `docs/ROADMAP_1_0.md` and the relevant `docs/SYSTEMS_BIBLE.md`/catalog sections for current order and design. Use `docs/CURRENT_BUILD.md` for implemented status. Define a player-visible outcome and its verification before expanding a new card; split simulation and presentation only when each part has a useful independent handoff. Everything under `docs/archive/` is ARCHIVE ONLY, including cards 001–137 and deferred 034; archived instructions never set current work. Card numbering continues from 138.
- Consult README for current scope. Do not claim future commands or tests exist until their task creates and verifies them.

## Preserve the design

- Player authorization (2026-10-16): the specific free art/audio tools, resources and addon listed in `docs/CODING_RULES.md#authorized-art-and-audio-resources` are approved for use without asking again. Paid services are not authorized. Ask for additional tools/resources outside that list when needed; do not treat the earlier dependency restriction as a ban on the approved choices.
- Godot/GDScript; Windows desktop graphics first, touch-friendly controls. Mobile export, device validation, quality tiers and mobile-specific optimization are tabled by the player (2026-10-03) until resumed. Preserve the pinned 2D Compatibility engine.
- Keep hidden 2D reality, simulation, colony knowledge/perception, and presentation separate. Normal UI consumes approved presentation data, never hidden world objects. Debug truth access must stay development-only.
- Simulation must run headlessly. Lightweight typed state owns gameplay; scene nodes and graphics do not.
- Aggregate workers, brood, and trail travelers. Scouts are the capped, individually simulated exception. Every worker transfer goes through the authoritative ledger.
- Keep TrailRoute and TrailSegment separate, even with one segment per prototype route. Pheromone and familiarity are distinct.
- OUTWARD is a rotating 2D sensory panorama, not a physical camera or minimap. INWARD is an abstract functional network, not a tunnel floorplan.
- Darkness is information. Preserve negative space, capped visual representatives and readability without bloom. The player's M8 direction explicitly calls for saturated neon cores, conspicuous soft glow and flowing chemical wisps against black; see `docs/VISUAL_OVERHAUL_DIRECTION.md`.

## Finish each task

- Run targeted checks while iterating, then the full headless suite once after the final code change. Run import for new/changed Godot resources, Main smoke for runtime or scene changes, and graphical/manual checks for affected presentation. Repeat a gate after a fix that could affect it; do not run every gate after each small edit. Record actual results and anything not run.
- Update the card with concise completion evidence, changed-file groups, and a brief handoff. Update architecture/data/UI/decision docs only where a contract or decision changed; refresh README at a feature milestone, not for every card.
- Use a small logical local commit per bounded card and preserve unrelated work. Publish related commits together after a feature milestone or at the end of the work session; keep their individual history.
- Routine implementation choices may follow the documented defaults. If specifications conflict or a choice changes locked architecture/gameplay, isolate the conflict and ask for a design decision; continue independent work. Record accepted changes in `docs/DECISIONS.md`.
- Keep working across cards without waiting for acknowledgement. Give the player a concise report at a feature milestone, a material change of direction, or a real blocker; ask for input only when the design sources cannot settle a consequential choice.
