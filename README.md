# Antzenpile

A colony-scale strategy game about interpreting and shaping a living ant trail network. The player is the colony: the physical world is hidden, and play proceeds through incomplete collective knowledge and an abstract audiovisual sensorium.

## Current state

Tasks 001–007 are implemented: Godot shell, fixed clock, isolated seeded runs, authored hidden world, conserved worker ledger, development-only truth view, and capped individual scout missions with terrain routing and real return travel. The foundation review is complete; discovery and observations are next. No player gameplay yet. The documentation distills **GDD v0.2, Parts 1–8 and the Part 7A visual lock** from the Ant Game Brainstorm conversation.

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
| [Task cards](docs/tasks/) | 001–006 executable specifications; 007–022 roadmap |

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

The runner returns 0 on success, 1 on check failure or an empty suite. Use the pinned executable, not an arbitrary Godot on PATH. In the editor, F5 runs Main and F8 stops it. The bootstrap window is intentionally empty and near-black, with a 1280×720 landscape viewport and canvas-items stretch. F3 toggles DEBUG: WORLD TRUTH; click home, resource, or scout markers for raw fields. Its labeled dispatch button starts a general scout mission. Other named actions await their gameplay tasks. Release and headless runs do not create the truth view.

## First milestone

A roughly 20–30 minute slice: scout, learn, recruit a trail, bring resources home, support brood, develop Food Exchange, hear an additional music stem, and see exposed trails weaken under rain while familiarity persists. See [slice scope](docs/VERTICAL_SLICE.md). No conventional player map or minimap.
