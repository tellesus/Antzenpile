# Antzenpile

**Current development save policy (2026-10-15):** [Same-build saves only](docs/SAVE_POLICY.md). Earlier requirements to preserve/load/migrate previous-build saves are superseded and tabled until true release preparation. Historical implementation/evidence below does not create a compatibility goal.

A colony-scale strategy/4X game about learning an uncertain world, investing living ants, developing functional organs and continuing a lineage through an expanding nest network. Godot/GDScript, pinned **Godot 4.7.2, 2D Compatibility**, Windows desktop first.

## Current build

`main` is the development baseline. PRs [#1](https://github.com/tellesus/Antzenpile/pull/1) and [#2](https://github.com/tellesus/Antzenpile/pull/2) are merged, so the systems beta and recovered organic neon-trail proof are part of the same game. Historical topic branches are retired. Start new work from current `origin/main`; [Current Build](docs/CURRENT_BUILD.md) holds the shared remaining-work list.

The current revision improves [colony clarity201](docs/tasks/201_colony_clarity_playtest.md): a unified function/improvement overview, one connected adaptation web with undiscovered question marks, clearer returned combat outcomes, resolved clouds that fade without blocking resources, compact source controls and original organic brood artwork. The selected C2 music and accepted Blender entrance remain the baseline. This is a personal game made for fun; public-release preparation is tabled. `builds/windows-beta-latest.json` identifies the newest playable Windows build. Start a new colony after changing builds.

The prototype supports returned scout memories, ten concrete source identities, remembered-source comparisons, named standing exploration/rechecks, flexible gathering/queued staffing and real recall, brood/care/development, ten inherited traits, additional named piles, daughter-origin founding/local work and two-way adjacent supplies/whole worker migration. Queens have local condition and paid replacement; both piles can fund maternal trials and reproductive groups without immigrant traits rewriting offspring. A retained delivered/local report journal exposes simultaneous needs. Reproductive and adaptation investment queues have saved next priority; Auto Brood can stay on. Journey Alarm offers optional armed Search and Defend after returned losses; confirmed predators allow Clear/Hunt. Borrow workers from other jobs explicitly controls interruptions and protected work. Aphid honeydew is introduced as sugary aphid droplets. Voluntary End Run opens a separate sampled physical history.

Paid Reproductive Alcove provides dedicated group space; Ventilation Gallery improves staffed regulation while retaining water use. Whole climate/cleanup/scout effort is editable with suggestions; presets remain. Fruit, heavy seeds and episodic crumbs use captured mixed-nutrient cargo. Care, Environment and Chemistry web families offer actual inherited tradeoffs; a Food Cache remains excluded after its gate found no buffering need.

Latest development checks201: **12722 checks,0 failures**, plus1,600 focused checks and native construction/save/load/web/combat/picking checks. [Evidence](docs/evidence/card201/README.md) distinguishes actual encounter behavior from art fixtures and unchanged-pack checks. The fresh Windows build is for continued personal play. [Current Build](docs/CURRENT_BUILD.md) records the implemented food, inherited traits, colony growth, nest network, ecology and recovery systems. Further work follows actual play feedback.

## Current design and implementation order

Start with the [documentation index](docs/README.md), [systems bible](docs/SYSTEMS_BIBLE.md) and [1.0 roadmap](docs/ROADMAP_1_0.md). The catalogs define reusable rules and concrete [resources](docs/catalogs/RESOURCES.md), [chambers](docs/catalogs/CHAMBERS.md), [adaptations](docs/catalogs/ADAPTATIONS.md), [ecology](docs/catalogs/ECOLOGY.md) and [sites/scenarios](docs/catalogs/SITES_AND_SCENARIOS.md).

Active implementation references: [architecture](docs/ARCHITECTURE.md), [data model](docs/DATA_MODEL.md), [UI rules](docs/UI_RULES.md), [decisions](docs/DECISIONS.md), [coding rules](docs/CODING_RULES.md), [current cards](docs/tasks/). Superseded plans/reviews/cards are [ARCHIVE ONLY](docs/archive/README.md). They preserve evidence and never independently set the next task.

Development uses one bounded player-visible card at a time. Systems/balance precede the final graphics/music pass. Budget is $0; simulation tests stay headless, while affected graphics use the recorded pinned-engine capture probes and player feedback. Mobile production and fixed session-duration balance remain tabled.

## Running and checking the prototype

Use the pinned Windows console executable, not an arbitrary Godot on PATH. The engine is not included in the repository. The [official archive](https://godotengine.org/download/archive/4.7.2-stable/) and [official build mirror](https://github.com/godotengine/godot-builds/releases/tag/4.7.2-stable) identify the pinned distribution. From the repository root:

```powershell
$env:GODOT_EXE = 'C:\path\to\Godot_v4.7.2-stable_win64_console.exe'
& $env:GODOT_EXE --version
& $env:GODOT_EXE --headless --path . --import
& $env:GODOT_EXE --headless --path . --script res://tests/run_tests.gd
& $env:GODOT_EXE --headless --path . --quit-after 120
```

The test runner returns nonzero on failures. For ordinary play run the project executable with `--path .`, or open the editor and run Main. A portable Windows systems beta and verified rebuild/export instructions now exist: see [Windows beta](docs/WINDOWS_BETA.md). Extract its ZIP and open `Antzenpile.exe`; Godot is only needed for development. Offline art/music sources and instructions remain under `tools/`; no new runtime dependency is introduced by the design reset.

## Basic controls and saves

- OUTWARD: drag to turn attention, tap traces/alarms for contexts. Exploration sets standing scout effort; Favor This Direction changes search intent. Remembered Sources browses returned memories.
- INWARD/Tab: inspect the abstract functional network. Queen offers Auto/manual worker brood and queued reproductive investment with next-priority controls; adaptation choices queue for future brood.
- Gathering: Plan Gathering/Adjust Target opens a free proposal; the +1/+5/−1/−5 circles edit it and the attached Send circle commits it. Assigned, queued and available workers stay distinct; closing/ESC discards edits.
- Conflict: use the circular count controls to choose a response/addition and select its goal, then Send. Larger contextual icons offer investigation, retreat and alternate approach, with hover explanations. Recalled workers/cargo travel home; borrowing can leave other jobs reduced.
- ENTRANCE → MANAGE CONNECTIONS: choose an adjacent nest, supplies, whole worker settlers a supported queen relocation or an actual paid worker-brood rescue, then ORDER. Each link has one shared traffic slot; stopped parties physically return and report.
- Space pauses; 1/2/3/4 select 1×/4×/16×/64×. Sound controls music and information cues separately. Help describes current controls.
- Escape closes field attention, then opens the Colony menu; its small ESC button supports mouse/touch. Save/Load, Sound and Help are inside. Opening it does not pause.
- Menu Save/Load or Ctrl+S/Ctrl+L use `user://saves/slot_1.json`; loading resets attention while restoring simulation. End Run/Review does not overwrite that slot. Revealed review cannot resume ordinary play.
- F3 development debug truth is unavailable in release/headless play. Normal UI never presents a physical map, live enemy strength or unseen resource stock.

The original milestones and evaluations remain linked from the archive instead of accumulating here. Do not infer a planned API, command, test or feature from the 1.0 catalogs.
