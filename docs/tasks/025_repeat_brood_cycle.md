# 025 — Repeat brood cycle

Status: complete 2026-09-30; bounded follow-up to the player's first-playtest request for another hatching cycle.

## Goal

After the starting brood emerges, let the player begin another eight-ant cohort from INWARD. Repeat the existing egg → larva → pupa care, food and emergence rules so population growth remains a colony decision beyond the first cycle.

## Scope and contracts

- Add a semantic `start_brood(pile_id)` command on SimulationController, implemented by BroodSystem. It accepts only a valid pile with a queen and no active cohort, creates one new aggregate egg cohort, and returns a clear rejection reason otherwise. Initial cohort setup remains unchanged.
- Offer one touch-sized **LAY BROOD** action in the selected Queen or Nursery context when the nursery is empty. Use GameRoot's detached INWARD summary and semantic callback; no UI-owned state mutation. One cohort at a time, manual starts only. The egg action has no upfront cost; existing larval nutrition and available-worker care gates remain the costs of growth.
- Assign each cohort a stable sequential ID derived from the number already emerged, and validate it against `brood_matured_total` on restore. Keep the version-5 snapshot and disk-envelope shapes, with existing single-cycle saves still readable. All emerged workers enter through WorkerLedger once.
- No queens, eggs or individual brood become scene nodes. Do not add automatic laying, mortality, genetics, gameplay population caps, resource regeneration, or other reproduction systems.

## Verification

Test initial and repeat-cycle command rejection/acceptance, two complete emergences, labor and resource accounting, low-care/food stalls, save/reload mid-second-cycle exact continuation, legacy version-5 single-cycle snapshot compatibility, invalid cohort ID/count rejection, and INWARD mouse/touch action through the semantic boundary. Run pinned Godot 4.7.2 import, full headless suite and Main smoke. Inspect the empty Nursery action and active second cohort graphically at 1280×720 and 900×600. Update contracts and record evidence in one logical commit.

## Completion evidence and handoff

- BroodSystem now accepts a manual repeat command only when a pile has a queen and an empty nursery. It starts one new eight-ant egg cohort, with no upfront charge. Existing care and larval food rules govern progression; each emergence adds living workers through WorkerLedger once. Cohort IDs advance as `brood_1`, `brood_2`, and so on. Invalid starts leave the run unchanged.
- INWARD's selected Queen and Nursery contexts show **LAY 8 BROOD** when empty. Mouse and touch use the same semantic callback through GameRoot and SimulationController. A second active cohort replaces the action with stage, care and nutrition detail. The view receives only detached colony state.
- The new focused suite covers two completed cycles (40 → 48 → 56 living workers), exact resource debits, no duplicate emergence, queen/active-cohort rejection, care and nutrition stalls, JSON continuation mid-second-cycle, a version-5 single-cycle disk-save round trip, invalid counts/IDs, and INWARD input. Pinned Godot 4.7.2 import, full headless suite and Main smoke passed: 3,584 checks, zero failures.
- Graphical Compatibility inspection at 1280×720 showed the empty Nursery action and active second-cycle details; the 900×600 compact view remained readable. Android device input/performance remains unmeasured. The manual eight-ant batch and no-upfront-cost choice remain provisional balance defaults; this is not a broader reproduction system.
- Changed files: `src/sim/colony/brood_system.gd`, `brood_cohort.gd`, `pile_state.gd`, `colony_state.gd`, `src/core/simulation_controller.gd`, `game_root.gd`, `src/presentation/inward/inward_view.gd`, `tests/test_repeat_brood.gd`, `tests/run_tests.gd`, `README.md`, `docs/ARCHITECTURE.md`, `DATA_MODEL.md`, `UI_RULES.md`, `VERTICAL_SLICE.md`, `SLICE_EVALUATION.md`, `DECISIONS.md`, and this card. Next: playtest repeated growth and decide whether Food Exchange timing needs a design change before expanding the slice further.
