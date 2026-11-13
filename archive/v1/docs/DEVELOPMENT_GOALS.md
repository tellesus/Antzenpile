# Current development goals

Updated2026-10-18. This is Michael’s personal Windows game, made for fun. Make actual play clearer, more satisfying and more beautiful. Release preparation and professional shipping ceremony are tabled until the player asks for them. Historical milestones describe implemented systems, not obligations to run a release program.

## Current iteration201

The player requests these improvements, in order:

1. Construction: distinguish what the colony can already do from what building improves. Put benefits, food/labor/time, readiness and progress together. Preserve existing rules unless a deliberate later design change replaces them.
2. Adaptation: show the existing repertoire together as a connected web, with anonymous `?` slots for undiscovered variation. Remove family tabs; keep known traits, brood inheritance and queue actions honest.
3. Combat: explain recruiting, waiting for reports and actual returned results. A resolved encounter should fade and must not obstruct a resource. Keep uncertainty about unseen events.
4. INWARD art: replace plain brood beads with organic egg/larva/pupa forms that fit the luminous colony. Keep representative counts bounded.

[Implementation/evidence201](tasks/201_colony_clarity_playtest.md) records actual status. Further combat/adaptation depth and the fresh-colony decision arc remain in [Gameplay coherence review](GAMEPLAY_REDESIGN_REVIEW.md); a clearer interface alone does not prove these systems are satisfying. Follow concrete play feedback after this iteration rather than automatically expanding the roster or adding new systems.

## Keep the parts that work

The player says C2 music is good and the195 anthill looks great. Keep them as the baseline; do not restart those redesigns or add another music director without a concrete reason. `main` is the canonical game. Refresh the default playable Windows build after runtime changes and publish completed related work while preserving unrelated local files.

Useful checks protect play: targeted behavior/input/knowledge checks during changes, one final integrated headless pass, and affected native visual checks. A packaged game should launch and keep same-build save/load working. Do not turn this into release acceptance, signing, another-machine campaigns or unrequested performance projects.

## Standing constraints

- [Same-build saves only](SAVE_POLICY.md). Previous-build recovery, migration and compatibility are tabled. Start a new colony when changing builds; leave unrelated files and old slots untouched.
- Godot/GDScript, pinned2D Compatibility renderer, Windows first. Keep simulation headless, aggregate labor authoritative and hidden reality separate from colony knowledge/presentation.
- The specifically approved [free art/audio resources](CODING_RULES.md#authorized-art-and-audio-resources) may be used without repeat approval. Paid services are unauthorized; ask for additional tools/resources when needed.
- Mobile, a fixed session-duration target and previously deferred major systems remain tabled. The Food Cache has no demonstrated need and is not an active task.

Iteration201 is delivered: 12722 integrated checks and1,600 focused checks pass; native actual construction/returned encounter/fade/resource-draft checks and the refreshed playable build pass. Continue from personal play feedback; no public-release task has been activated.
