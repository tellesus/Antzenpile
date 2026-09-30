# 026 — Extended colony integration

Status: complete 2026-09-30; follows task 025 and the player's decision to keep Food Exchange available early.

## Goal

Exercise a longer normal-command run after the first brood emerges. Verify that an early Food Exchange remains useful, another brood cycle can be started, and the existing water discovery/trail loop can support continued growth.

## Scope and contracts

- Preserve early Food Exchange eligibility; do not add a brood-pressure gate or change its cost or music cue. Record this player decision in the decision register and revise the older slice evaluation accordingly.
- Add a reproducible headless integration scenario using only semantic scout, trail, development and brood commands. Follow the existing authored world and initial stores. Check the first and second cohort, water shortage or replenishment behavior, worker conservation, return-only knowledge, and detached view summaries.
- Include mid-second-cycle full-precision save/reload continuation with scouts/travel or water delivery in flight where practical. Report measured simulated milestones and store levels; do not claim human session length from a scripted run.
- No new gameplay system, balance retune, automatic laying, hidden-world targeting, map UI or renderer change.

## Verification and handoff

Run pinned Godot 4.7.2 import, full headless suite and Main smoke. If the existing commands cannot complete the second cycle in the authored world, isolate the failing invariant or resource bottleneck and report it without inventing mechanics. Update README, slice evaluation and card status with measured results, commands and limitations. Commit one logical task-026 change.

## Completion evidence and handoff

- Added `tests/test_extended_slice.gd`, registered in the full runner. It starts Food Exchange development at 40.00 simulated seconds, before protein is known or brood needs food; the first brood emerges at 360.00 seconds. A second manual cohort stalls on empty water at 620.25 seconds, a northbound scout reports water at 666.50 seconds, and a funded water trail supports the second emergence at 790.00 seconds. Living workers rise 40 → 48 → 56 through the ledger.
- The test checks private scout knowledge, water shortage without cohort loss, resumed growth, detached OUTWARD/INWARD summaries, and exact JSON continuation with water transit in flight through the second emergence. At the end, stores are 176.4 carbohydrate, 94.52 protein and 23.2 water. No resource, worker, world or balance value was edited in the test.
- Pinned Godot 4.7.2 import, full headless suite and Main smoke passed: 3,608 checks, zero failures. This is a scripted 13-minute-10-second simulated run, not a human session or Android-device result. It shows that water matters for continued growth while carbohydrate and protein still accumulate substantially.
- Recorded the player's early Food Exchange decision in `docs/DECISIONS.md`; updated the slice's flexible milestone wording and historical evaluation. Changed files: this card, `tests/test_extended_slice.gd`, `tests/test_extended_slice.gd.uid`, `tests/run_tests.gd`, `README.md`, `docs/DECISIONS.md`, `docs/VERTICAL_SLICE.md`, `docs/SLICE_EVALUATION.md`, `docs/UI_RULES.md`, and `docs/VISION.md`. Next: longer human playtest to evaluate resource and time pacing before changing rates or adding a new system.
