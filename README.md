# Antzenpile

A colony-scale strategy game about interpreting and shaping a living ant trail network. The player is the colony: the physical world is hidden, and play proceeds through incomplete collective knowledge and an abstract audiovisual sensorium.

## Current state

Documentation only. No Godot project, game code, assets, or executable tests exist yet. This pack distills **GDD v0.2, Parts 1–8 and the Part 7A visual lock** from the Ant Game Brainstorm design conversation. It is durable implementation context, not a replacement for future design work.

**Stack:** Godot 4.x, GDScript; agreed 4.7.x stable family, with 4.7.2 stable as the bootstrap candidate. Windows first, Android-compatible architecture and rendering from the start, iOS later. Task 001 records the exact tested engine build and renderer; no casual upgrades. The [official archive](https://godotengine.org/download/archive/) lists 4.7.2 as stable (checked 2026-09-23).

## Start here

1. Read [AGENTS.md](AGENTS.md), the current task card, [architecture](docs/ARCHITECTURE.md), and [coding rules](docs/CODING_RULES.md).
2. Consult the [decision register](docs/DECISIONS.md) for locked constraints and explicitly provisional defaults.
3. Implement one task at a time, beginning with [001: project bootstrap](docs/tasks/001_project_bootstrap.md). Creating this pack does not complete any implementation task.
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

Task 001 creates the project and lightweight headless runner, then replaces this section with verified Windows setup instructions. The planned runner command is `godot --headless --path . --script res://tests/run_tests.gd`; it is **not runnable in this documentation-only repository**. Use the pinned executable, not whichever Godot version happens to be on PATH.

## First milestone

A roughly 20–30 minute slice: scout, learn, recruit a trail, bring resources home, support brood, develop Food Exchange, hear an additional music stem, and see exposed trails weaken under rain while familiarity persists. See [slice scope](docs/VERTICAL_SLICE.md). No conventional player map or minimap.
