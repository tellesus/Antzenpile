> **ARCHIVE ONLY — frozen 2026-10-04.** Historical record; not an active plan, current contract or implementation instruction. Use the [current documentation](../../../README.md). Original path: `docs/tasks/027_periodic_resource_ecology.md`. Historical status and recommendations below apply only to their recorded build.

# 027 — Periodic resource ecology

Status: complete 2026-09-30; follows the player's choice to develop exterior resource ecology and recurring events before economy balance.

## Goal

Make one existing backyard source renew on an authored recurring schedule. This establishes the first physical resource-ecology event without changing brood costs, trail yields, or initial stores.

## Scope and contracts

- Treat `carb_sheltered` as a flowering source whose nectar returns in periodic pulses. Author the target, first tick, interval, pulse quantity and capacity in a diffable resource. These are provisional slice values, not final balance.
- Advance the schedule from the fixed simulation clock in a headless EcologySystem. A pulse adds up to capacity, reactivates a depleted source if it adds quantity, and never creates a new world node or modifies another resource. All timing must be deterministic under pause, speed changes and save/reload. Avoid adding snapshot state when the next pulse is exactly derivable from saved clock ticks and immutable authored data.
- Keep the renewal hidden. Do not update KnownNode reports or normal OUTWARD/INWARD data at the event. Existing trail and scouting interactions may discover its consequences only through their usual paths. F3 may show current physical quantity.
- An empty trail remains reported depleted until the player cancels/reinvests it. Do not automatically restart a route from hidden renewal; a later card can address temporal knowledge and retesting UX.
- Limit this task to one periodic source; no random resource spawning, seasons, human schedules, predators, or rate tuning.

## Verification and handoff

Test pulses before/at/after schedule boundaries, capacity, depleted reactivation, unrelated sources, pause/speed, full-precision save continuation around a pulse, and no knowledge/UI leak. Run pinned Godot import, full headless suite and Main smoke. Update architecture/data model/decision register/README as needed, record actual evidence and changed files here, then make one logical commit.

## Completion evidence and handoff

- Authored a 12-unit nectar pulse for the sheltered carbohydrate source every 300 simulated seconds, beginning at 300, capped at 100. A depleted source physically reactivates; the event does not update colony knowledge or restart depleted trail labor. No brood costs, initial stores or collection rates changed.
- The new headless test checks first and second schedule boundaries, pause/4× behavior, capacity, unchanged unrelated source, no hidden-knowledge or OUTWARD signal leak, stale KnownNode evidence and depleted trail status, plus exact full-precision continuation across a pulse. Existing minimal test worlds that omit the source are safely skipped. Snapshot version remains 5.
- Pinned Godot 4.7.2 import passed. Full headless suite passed with 3,624 checks and zero failures; headless Main smoke exited 0. The prior 790-second scripted run now ends with 188.4 carbohydrate rather than 176.4 due to this new renewal, with protein and water unchanged. No Android-device or graphical interaction test was run.
- Changed files: `src/sim/ecology/{ecology_system,resource_pulse_definition}.gd` and UIDs, `data/ecology/backyard_nectar.tres`, `src/core/simulation_controller.gd`, `tests/test_ecology.gd` and UID, `tests/run_tests.gd`, `README.md`, `docs/{ARCHITECTURE,DATA_MODEL,DECISIONS}.md`, and this card. Next: make depleted-source retesting an explicit player action or introduce temporal knowledge of recurrence before adding more periodic sources.
