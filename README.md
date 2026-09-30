# Antzenpile

A colony-scale strategy game about interpreting and shaping a living ant trail network. The player is the colony: the physical world is hidden, and play proceeds through incomplete collective knowledge and an abstract audiovisual sensorium.

## Current state

Tasks 001–033 are implemented/evaluated: Godot shell, fixed clock, isolated seeded runs, authored hidden world, conserved worker ledger, development-only truth view, capped individual scouts that search past their initial range for new sources, nearby chemical sensing with progressive localization, private observations delivered on return, and colony Known Nodes with deterministic report merging and aging confidence. PerceivedSignals derive bearing, estimated distance, strength and qualitative confidence from colony memory. OUTWARD supports rotating sensory traces, scouting, time controls and invested worker trails. Successful returns reinforce short-lived pheromone and slower route familiarity. The Primitive Nursery supports eight brood and care slots; a resource-and-labor development project doubles both capacities, allowing two aggregate cohorts. Each aggregate brood cohort consumes food and can mature into eight living workers through the ledger; after emergence, the player can begin another cycle. INWARD shows Queen, Nursery, Food Exchange and Entrance as an abstract functional network. Once trails bring sufficient food home, the Primitive Food Exchange can be developed with committed workers; completion makes larval food use 25% more efficient. An original synchronized placeholder music layer fades in on completion. Once exposed and sheltered trails both carry resources, one rain event washes out exposed chemistry while familiarity survives and steadily adds three water units to the home store. The sheltered carbohydrate source renews on a hidden periodic nectar schedule, and a temporary picnic crumb spill supplies protein only during authored episodes. Returned scout and forager evidence can suggest uncertain recurrence, and a selected trace can send a scout to investigate its remembered location. Aggregate trail journeys now spend carbohydrate according to workers, distance and terrain; known carbohydrate sources can replenish an empty pile. One local save slot resumes the full run, including work in flight. The documentation distills **GDD v0.2, Parts 1–8 and the Part 7A visual lock** from the Ant Game Brainstorm conversation.

The task-022 integration baseline reaches the original arc in six simulated minutes. See the [slice evaluation](docs/SLICE_EVALUATION.md) for historical Windows performance and pacing measurements. Session-length evaluation is tabled until more systems exist. Playtest follow-ups 023–026 include a longer second-brood integration run, and tasks 027–028 begin exterior resource ecology. Food Exchange remains available early as a player project; economy balance is deferred while more systems come online.

**Pinned engine:** `4.7.2.stable.official.ed1daf0bf`, standard/GDScript Windows x64 build. **Renderer:** Compatibility (`gl_compatibility`) on desktop/mobile. Windows first, Android-compatible architecture now, iOS later. Do not casually upgrade.

## Start here

1. Read [AGENTS.md](AGENTS.md), the current task card, [architecture](docs/ARCHITECTURE.md), and [coding rules](docs/CODING_RULES.md).
2. Consult the [decision register](docs/DECISIONS.md) for locked constraints and explicitly provisional defaults.
3. Implement one task at a time; task cards record status and verification evidence.
4. Review the working skeleton after [006: debug world view](docs/tasks/006_debug_world_view.md), before expanding the scouting cards.

| Document | Purpose |
| --- | --- |
| [VISION](docs/VISION.md) | Player experience and design boundaries |
| [ARCHITECTURE](docs/ARCHITECTURE.md) | Ownership, dependency direction, planned layout |
| [VERTICAL_SLICE](docs/VERTICAL_SLICE.md) | First playable arc, exclusions, evidence of success |
| [DATA_MODEL](docs/DATA_MODEL.md) | State contracts and invariants |
| [UI_RULES](docs/UI_RULES.md) | OUTWARD, INWARD, information and rendering rules |
| [CODING_RULES](docs/CODING_RULES.md) | Implementation and validation workflow |
| [DECISIONS](docs/DECISIONS.md) | Locked choices, defaults, unresolved details |
| [Task cards](docs/tasks/) | 001–033 completed; storage and throughput are proposed next |
| [Slice evaluation](docs/SLICE_EVALUATION.md) | Measured arc, Windows workload and design questions |
| [Post-slice plan](docs/POST_SLICE_PLAN.md) | Revised from the original GDD: tasks 029–033 complete, cards 034–036 proposed, session pacing tabled |

## Running and testing

Download and extract the standard Windows x64 ZIP from the [official 4.7.2 archive](https://godotengine.org/download/archive/4.7.2-stable/) or its [official GitHub mirror](https://github.com/godotengine/godot-builds/releases/tag/4.7.2-stable). The engine is not checked into the repository. In PowerShell, set `GODOT_EXE` to the extracted console executable, then run from the repository root:

```powershell
$env:GODOT_EXE = 'C:\path\to\Godot_v4.7.2-stable_win64_console.exe'
& $env:GODOT_EXE --version
& $env:GODOT_EXE --headless --path . --import
& $env:GODOT_EXE --headless --path . --script res://tests/run_tests.gd
& $env:GODOT_EXE --headless --path . --quit-after 3
& $env:GODOT_EXE --editor --path .
```

The runner returns 0 on success, 1 on check failure or an empty suite. Use the pinned executable, not an arbitrary Godot on PATH. In the editor, F5 runs Main and F8 stops it. The near-black OUTWARD window uses a 1280×720 landscape viewport and canvas-items stretch. Drag the field with a mouse or touch to face another direction; tap a trace for its context. Once a scout has returned with a known resource, its context offers **Invest 5 Workers**, then −1, +1 and Cancel. If a trail reports an unavailable source, select it and use **Recheck** after its travelers return to send them back without assuming the source has renewed. Loaded returns make a thin screen-space scent link appear; disuse breaks and fades it. Cancel blocks departures and returns workers to availability only when their cohort reaches home. The Scout button sends a scout in the facing direction. It keeps searching for a new source after its initial target, follows chemical traces to confirmation, then returns; private evidence appears only after arrival. Use INWARD or Tab to switch to the four-node colony view. After brood emerges, select Queen or Nursery and tap Lay 8 Brood to begin another cycle. Select Nursery to develop it when the displayed costs and labor are available; once complete, Lay 8 Brood can start a second cohort before the first emerges. Select Food Exchange and, once stores meet its displayed requirements, tap Develop; its context shows progress and the completed benefit. Each view remembers its selection. Pause/Resume and 1×/4×/16×/64× buttons also have Space and 1/2/3/4 shortcuts. Save and Load buttons in either view (or Ctrl+S/Ctrl+L) use one local slot at `user://saves/slot_1.json`; loading resets view selection/facing and music phase while restoring the simulation. F3 toggles DEBUG: WORLD TRUTH; click home, resource, or scout markers for raw fields, including brood, development, trail chemistry and commitments. Signals remain absent until a scout returns. Release and headless runs do not create the truth view.

## First milestone

The original slice milestone: scout, learn, recruit a trail, bring resources home, support brood, develop Food Exchange, hear an additional music stem, and see exposed trails weaken under rain while familiarity persists. Session length is tabled until more systems exist. See [slice scope](docs/VERTICAL_SLICE.md). No conventional player map or minimap.
