# Antzenpile

A 4X strategy game played as the distributed mind of an ant colony. You see only what your ants touch, and you steer the colony by laying scent, not by commanding units.

This branch (`v2`) is the 2.0 rebuild. It is at phase 1, the toy: ants, emergent trails, food, fog of knowledge and four scent brushes. No rivals, nest or goals yet.

- **Plan:** [docs/PLAN_2_0.md](docs/PLAN_2_0.md)
- **Version 1.0:** complete source, docs and tests are in [archive/v1/](archive/v1/). It is reference material only. The `main` branch still holds 1.0 as it was last played.

## Running it

Engine: Godot 4.7.2 stable, Forward+ renderer.

- **Play (Windows):** double-click `play.bat`. It expects the Godot executable in `.tools/godot/`.
- **Tests:** `godot --headless --path . --script res://tests/run_tests.gd` (exits non-zero on failure).
- **Tuning probe:** `godot --headless --path . --script res://tools/probe.gd` prints how an untouched colony fares each minute.
- **Controls:** left-drag paints the selected scent; keys 1–5 pick Attract, Alarm, Repel, Seek, Erase; `[` and `]` change brush size; right-drag or arrow keys pan; mouse wheel zooms; Space pauses; Tab cycles speed.
