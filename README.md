# Antzenpile

A 4X strategy game played as the distributed mind of an ant colony. You see only what your ants touch, and you steer the colony by laying scent, not by commanding units.

This branch (`v2`) is the 2.0 rebuild. It is at phase 0: an empty seeded map that runs, with a headless test runner.

- **Plan:** [docs/PLAN_2_0.md](docs/PLAN_2_0.md)
- **Version 1.0:** complete source, docs and tests are in [archive/v1/](archive/v1/). It is reference material only. The `main` branch still holds 1.0 as it was last played.

## Running it

Engine: Godot 4.7.2 stable, Forward+ renderer.

- **Play (Windows):** double-click `play.bat`. It expects the Godot executable in `.tools/godot/`.
- **Tests:** `godot --headless --path . --script res://tests/run_tests.gd` (exits non-zero on failure).
- **Controls so far:** arrow keys or right-drag to pan, mouse wheel to zoom.
