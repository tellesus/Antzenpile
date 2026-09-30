# 028 — Recheck a depleted trail

Status: complete 2026-09-30; follows periodic physical renewal in task 027.

## Goal

Give the player a clear way to test whether a remembered source is available again without revealing the hidden renewal schedule.

## Scope and contracts

- Add a semantic Recheck command for a depleted route with committed workers and no travelers still in flight. Reuse its route, segment, captured estimate and ledger commitment. Clear only its reported-depleted state; its next cohort must make the ordinary outbound collection and inbound return. A still-empty source reports depleted again after that travel.
- Reject unknown, active, recalling, inactive, uncommitted or still-travelling routes atomically with a short reason. Never query the source at command time. Normal UI must not imply recheck will succeed.
- Put one touch-sized Recheck action in a selected depleted trail's OUTWARD context, alongside Cancel. It goes through GameRoot's semantic callback and the same mouse/touch hit path. Do not add a source schedule, live quantity, map marker, auto-retry, or new ledger pool to presentation.
- Preserve version-5 save format and exact continuation of a recheck in flight.

## Verification and handoff

Test rejection atomicity, empty and renewed physical outcomes, worker accounting, delayed resource delivery, detached UI interaction and full-precision save continuation. Run pinned import, full headless suite and Main smoke. Update relevant docs and record evidence, changed files and next action here before a small commit.

## Completion evidence and handoff

- `TrailSystem.recheck` accepts only a settled depleted route with existing committed workers. It resets the stop/cooldown without looking up source truth, changing labor or replacing route/segment IDs. Empty and renewed outcomes both use ordinary aggregate travel and return.
- OUTWARD now shows **RECHECK** beside Cancel on the selected depleted route after travelers are home. It dispatches through GameRoot's semantic callback and the existing mouse/touch context path. The label does not reveal whether nectar has returned.
- The ecology test now covers unknown/active/in-flight/recalling rejection, an empty recheck, touch dispatch after renewal, delayed cargo delivery, worker conservation and exact full-precision continuation with the recheck cohort in flight. Pinned Godot 4.7.2 import, full headless suite and headless Main smoke passed: 3,642 checks, zero failures. No Android-device or graphical click test was run.
- Changed files: `src/sim/trails/trail_system.gd`, `src/core/{simulation_controller,game_root}.gd`, `src/presentation/outward/outward_view.gd`, `tests/test_ecology.gd`, `README.md`, `docs/{ARCHITECTURE,DATA_MODEL,UI_RULES,DECISIONS}.md`, and this card. Next: broader recurrent resource behavior or temporal knowledge; defer resource balance until those systems create more meaningful choices.
