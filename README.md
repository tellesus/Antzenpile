# Antzenpile

A colony-scale strategy game about interpreting and shaping a living ant trail network. The player is the colony: the physical world is hidden, and play proceeds through incomplete collective knowledge and an abstract audiovisual sensorium.

## Current state

The first playable colony slice is implemented: scouts return uncertain evidence; the colony invests aggregate workers in trails, gathers resources, raises brood, develops functional chambers, and responds to rain. Later cards added repeat brood, a first Adaptation Web choice, recurring exterior resources, trail-side discovery, a honeydew mutualism with player-controlled protection, and a first stationary predator encounter with returning loss alarms. A rival colony now forages independently: sustained foreign contact can form an aggregate swarm, with traveling reinforcements, withdrawal and home-delivered outcomes. A tolerated nest guest can consume brood and acquire colony odor; observed nursery losses allow a worker-funded rejection effort and purge, with partial brood survival conserved. An early visual proof adds organic resource clouds, colored chemical filaments, capped representative ants, functional INWARD forms and a short returned-loss sound. Hidden reality, colony knowledge, and normal presentation remain separate. See the [task cards](docs/tasks/) for individual completion evidence.

Current development follows the [rolling post-slice roadmap](docs/POST_SLICE_PLAN.md). The original session-length target and broad resource balance are tabled until more systems are playable. The [first-slice evaluation](docs/SLICE_EVALUATION.md) and [post-slice evaluation](docs/POST_SLICE_EVALUATION.md) preserve earlier measurements and player feedback.

**Pinned engine:** `4.7.2.stable.official.ed1daf0bf`, standard/GDScript Windows x64 build. **Renderer:** Compatibility (`gl_compatibility`) on desktop/mobile. Windows first, Android-compatible architecture now, iOS later. Do not casually upgrade.

## Start here

1. Read [AGENTS.md](AGENTS.md), the current task card, and relevant sections of the [architecture](docs/ARCHITECTURE.md) and [coding rules](docs/CODING_RULES.md).
2. Consult the [decision register](docs/DECISIONS.md) for locked constraints and explicitly provisional defaults.
3. Implement one task at a time; task cards record status and verification evidence.
4. Use the [rolling roadmap](docs/POST_SLICE_PLAN.md) for the next feature; completed cards are historical records.

| Document | Purpose |
| --- | --- |
| [VISION](docs/VISION.md) | Player experience and design boundaries |
| [ARCHITECTURE](docs/ARCHITECTURE.md) | Ownership, dependency direction, planned layout |
| [VERTICAL_SLICE](docs/VERTICAL_SLICE.md) | First playable arc, exclusions, evidence of success |
| [DATA_MODEL](docs/DATA_MODEL.md) | State contracts and invariants |
| [UI_RULES](docs/UI_RULES.md) | OUTWARD, INWARD, information and rendering rules |
| [CODING_RULES](docs/CODING_RULES.md) | Implementation and validation workflow |
| [DECISIONS](docs/DECISIONS.md) | Locked choices, defaults, unresolved details |
| [Task cards](docs/tasks/) | 001–033, 035, 037–040, 042–050 implemented; 034 deferred; 036 reviewed; 041 source-recovery audit complete |
| [Slice evaluation](docs/SLICE_EVALUATION.md) | Measured arc, Windows workload and design questions |
| [Post-slice evaluation](docs/POST_SLICE_EVALUATION.md) | Combined run, Windows visual/workload review, and remaining playtest questions |
| [Post-slice plan](docs/POST_SLICE_PLAN.md) | Current rolling roadmap and completed post-slice history |

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

The runner returns 0 on success, 1 on check failure or an empty suite. Use the pinned executable, not an arbitrary Godot on PATH. In the editor, F5 runs Main and F8 stops it. The near-black OUTWARD window uses a 1280×720 landscape viewport and canvas-items stretch. Drag the field with a mouse or touch to face another direction; tap a trace for its context. Once a scout has returned with a known resource, its context offers **Invest 5 Workers**, then −1, +1 and Cancel. If a trail reports an unavailable source, select it and use **Recheck** after its travelers return to send them back without assuming the source has renewed. A selected known trace can also send an **Investigate Source** scout. A returned honeydew trace can be harvested by a trail; after a loaded return, **Protect producers** commits six available workers, and **Withdraw protection** releases them. A dangerous honeydew trail can lose workers; an ALARM trace and loss count appear only after return or a missed expected return. **Stop Traffic** blocks departures and recalls survivors; invest those workers in a different known source to avoid the threat. A returned FOREIGN trace can escalate to contested contact; +4 commits reinforcements that still travel to the crossing. Stop Traffic withdraws survivors, and their outcome arrives only at home. Lost workers are not automatically replaced. Loaded returns make a thin screen-space scent link appear; disuse breaks and fades it. Cancel blocks departures and returns workers to availability only when their cohort reaches home. The Scout button sends a scout in the facing direction. It keeps searching for a new source after its initial target, follows chemical traces to confirmation, then returns; private evidence appears only after arrival. Use INWARD or Tab to switch to the five-node colony view. Select the violet Adaptation Web for a one-time Lean or Load brood trial once its displayed costs and Nursery space are available; the new trait takes effect as adapted brood emerges. After brood emerges, select Queen or Nursery and tap Lay 8 Brood to begin another cycle. Select Nursery to develop it when the displayed costs and labor are available; once complete, Lay 8 Brood can start a second cohort before the first emerges. After a guest enters, INWARD adds a Guest function. Nursery losses first have uncertain cause, then repeated losses reveal internal foreignness. Increase Rejection commits four workers until purge; Stop Rejection releases them, and the guest can remain harmful during clearing. Select Food Exchange and, once stores meet its displayed requirements, tap Develop Food Exchange; its context shows progress and the completed benefit. Each view remembers its selection. Pause/Resume and 1×/4×/16×/64× buttons also have Space and 1/2/3/4 shortcuts. Save and Load buttons in either view (or Ctrl+S/Ctrl+L) use one local slot at `user://saves/slot_1.json`; loading resets view selection/facing and music phase while restoring the simulation. F3 toggles DEBUG: WORLD TRUTH; click home, resource, or scout markers for raw fields, including brood, development, trail chemistry and commitments. Signals remain absent until a scout returns. Release and headless runs do not create the truth view.

## First milestone

The original slice milestone: scout, learn, recruit a trail, bring resources home, support brood, develop Food Exchange, hear an additional music stem, and see exposed trails weaken under rain while familiarity persists. Session length is tabled until more systems exist. See [slice scope](docs/VERTICAL_SLICE.md). No conventional player map or minimap.
