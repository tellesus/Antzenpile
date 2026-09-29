# 001 — Project bootstrap

Status: implemented and verified (2026-09-28).

## Goal

Create a clean, runnable Godot shell and a usable headless test entry point.

## Why this exists

Every subsequent short task needs a reproducible project and verification command.

## Dependencies

Read [ARCHITECTURE](../ARCHITECTURE.md), [CODING_RULES](../CODING_RULES.md), and [DECISIONS](../DECISIONS.md) A01–A02. No implementation dependencies.

## Allowed scope

`project.godot`, `.gitignore`, minimal `scenes/main/main.tscn`, a main script only if needed, `tests/run_tests.gd`, README setup instructions and decision evidence. Create useful base directories only; the architecture's full layout is a plan.

## Required behavior

1. Verify the official Godot 4.7.2 stable standard/GDScript build (candidate within agreed 4.7.x). Record full `--version` output and download reference. If unavailable, report the exact problem; do not silently choose another engine family.
2. Configure project name Antzenpile, a Main root Node, near-black clear color, landscape target and resizable viewport. Proposed bootstrap default: 1280×720 with canvas_items stretch. Use Compatibility as the provisional mobile-compatible rendering method and record the actual setting.
3. Add named Input Map actions from UI_RULES, with debug_world on F3. Defining actions is enough; implement no gameplay handlers. Later presentation uses shared mouse/touch logic.
4. Set Main as the run scene. Add Godot cache/export ignores; keep authored text resources and necessary UID files trackable. Do not add addons.
5. Create a small dependency-free SceneTree test runner. It prints a summary, exits 0 on success and nonzero on failure, and can register later test cases. Include only a bootstrap smoke check, not fake tests for future systems.
6. Document verified PowerShell commands with the actual console executable or a user-set `GODOT_EXE` path. Clearly replace the README's planned-command notice.

## Explicit non-goals

No clock, run state, ants, world, trails, particles, audio, game UI, or Android packaging. Do not implement future systems not explicitly requested.

## Interfaces to preserve

Keep `res://tests/run_tests.gd` as the headless entry point and `scenes/main/main.tscn` as the initial boot scene. No global simulation autoloads.

## Acceptance tests

- Fresh project import succeeds. `godot --headless --path . --script res://tests/run_tests.gd` succeeds with exit 0 using the pinned executable.
- Temporarily exercise a failing assertion to confirm nonzero exit, then remove the deliberate failure. Report both observations.
- Main can start and exit headlessly without parser/resource errors. An empty suite must not be described as gameplay coverage.

## Manual verification

Open in the pinned editor and run Main on Windows. Confirm a blank near-black landscape window, resizing, configured renderer, and no debugger errors. No mobile performance claim is implied.

## Done when

Project and runner work, exact setup is documented, relevant checks pass, and a short handoff lists changed files/results/limitations. One logical commit; next task 002.

## Handoff

- Added project settings/Input Map, empty Main scene, dependency-free runner and bootstrap suite, ignore/line-ending rules; updated README and agent context.
- Pinned `4.7.2.stable.official.ed1daf0bf`; Compatibility renderer, 1280×720 landscape, canvas_items stretch.
- Verified README import/test/headless-start commands. Suite: 5 checks, 0 failures, exit 0. Temporary failing check produced exit 1 and was removed; passing run repeated.
- Windows editor opened and F5 ran the near-black scene; F8 returned to editor with zero errors/warnings. Compatibility renderer reported AMD Radeon RX 6650 XT. Windowed and maximized editor/game hosts checked; standalone drag-resizing is not yet verified.
- No gameplay, mobile package, or mobile performance claim. Next: 002.
