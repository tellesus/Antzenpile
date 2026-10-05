# Antzenpile

A colony-scale strategy/4X game about learning an uncertain world, investing living ants, developing functional organs and continuing a lineage through an expanding nest network. Godot/GDScript, pinned **Godot 4.7.2, 2D Compatibility**, Windows desktop first.

## Current build

The prototype supports returned scout memories, standing exploration/rechecks, physical gathering/recall, brood/care/development, six inherited worker traits, first daughter founding/local work, two-way paid supplies and conflict/avoidance. Journey Alarm opens direct circular response controls with flexible recruitment: alerted trail → free nest → explicit All Hands. Aphid honeydew is introduced as sugary aphid droplets. Voluntary End Run opens a separate sampled physical history.

Latest runtime gate: **8,784 headless checks, zero failures**, clean import/Main and headless conflict drawing. The player accepts the circle as an improvement. This is a systems prototype, not a release candidate. Multiple daughters, queen replacement/generations, reproduction queueing under Auto Brood, concrete resource catalogs and new chambers/traits are planned, not implemented. See [Current Build](docs/CURRENT_BUILD.md).

## Current design and implementation order

Start with the [documentation index](docs/README.md), [systems bible](docs/SYSTEMS_BIBLE.md) and [1.0 roadmap](docs/ROADMAP_1_0.md). The catalogs define reusable rules and concrete [resources](docs/catalogs/RESOURCES.md), [chambers](docs/catalogs/CHAMBERS.md), [adaptations](docs/catalogs/ADAPTATIONS.md), [ecology](docs/catalogs/ECOLOGY.md) and [sites/scenarios](docs/catalogs/SITES_AND_SCENARIOS.md).

Active implementation references: [architecture](docs/ARCHITECTURE.md), [data model](docs/DATA_MODEL.md), [UI rules](docs/UI_RULES.md), [decisions](docs/DECISIONS.md), [coding rules](docs/CODING_RULES.md), [current cards](docs/tasks/). Superseded plans/reviews/cards are [ARCHIVE ONLY](docs/archive/README.md). They preserve evidence and never independently set the next task.

Development uses one bounded player-visible card at a time. Systems/balance precede the final graphics/music pass. Budget is $0; automated checks are headless, with focused player visual/audio checks. Mobile production and fixed session-duration balance remain tabled.

## Running and checking the prototype

Use the pinned Windows console executable, not an arbitrary Godot on PATH. The engine is not included in the repository. The [official archive](https://godotengine.org/download/archive/4.7.2-stable/) and [official build mirror](https://github.com/godotengine/godot-builds/releases/tag/4.7.2-stable) identify the pinned distribution. From the repository root:

```powershell
$env:GODOT_EXE = 'C:\path\to\Godot_v4.7.2-stable_win64_console.exe'
& $env:GODOT_EXE --version
& $env:GODOT_EXE --headless --path . --import
& $env:GODOT_EXE --headless --path . --script res://tests/run_tests.gd
& $env:GODOT_EXE --headless --path . --quit-after 120
```

The test runner returns nonzero on failures. For ordinary play run the project executable with `--path .`, or open the editor and run Main. A distributable Windows package/export preset is still future release work. Offline art/music sources and instructions remain under `tools/`; no new runtime dependency is introduced by the design reset.

## Basic controls and saves

- OUTWARD: drag to turn attention, tap traces/alarms for contexts. Exploration sets standing scout effort; Favor This Direction changes search intent. Remembered Sources browses returned memories.
- INWARD/Tab: inspect the abstract functional network. Queen offers Auto/manual worker brood and immediate reproductive investment when supported; adaptation choices queue for future brood.
- Conflict: choose workers/goal in the free draft, then ORDER. Investigate, retreat and alternate approach remain direct actions. Recalled workers/cargo travel home; All Hands can leave other jobs reduced.
- Space pauses; 1/2/3/4 select 1×/4×/16×/64×. Sound controls music and information cues separately. Help describes current controls.
- Save/Load or Ctrl+S/Ctrl+L use `user://saves/slot_1.json`; loading resets attention while restoring simulation. End Run/Review does not overwrite that slot. Revealed review cannot resume ordinary play.
- F3 development debug truth is unavailable in release/headless play. Normal UI never presents a physical map, live enemy strength or unseen resource stock.

The original milestones and evaluations remain linked from the archive instead of accumulating here. Do not infer a planned API, command, test or feature from the 1.0 catalogs.
