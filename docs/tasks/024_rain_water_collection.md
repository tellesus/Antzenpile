# 024 — Rain adds colony water

Status: complete 2026-09-30; steady-rate choice accepted.

## Goal

When the authored rain event occurs, add a modest amount of water to each pile's authoritative stores while it rains. Make the benefit visible through existing approved resource summaries.

## Scope and contracts

- Keep the one-shot 60-second event and exposed pheromone washout. Configure three water units per full event, added steadily on fixed simulated ticks (0.05 per second), as selected by the player. The amount remains tunable after playtesting.
- Route deposits through PileState's resource API and preserve exact mid-rain JSON/disk-save continuation. Pausing stops gain; speed changes affect simulated, not real, duration. No direct UI mutation or separate water counter.
- Normal OUTWARD/INWARD show the updated home store only; exact rain state and terrain exposure stay in F3. No visual rainfall-as-map or new collection structure.

## Verification

Test water gain on the first and final rain tick, no gain before/after event or while paused, fixed total under all speeds, valid mid-rain save/reload continuation, and unchanged pheromone/familiarity behavior. Run pinned Godot 4.7.2 import, full suite and Main smoke. Inspect OUTWARD rain status and INWARD Food Exchange water context graphically. Record tests, limitations, changed files and one logical commit.

## Completion evidence and handoff

- RainSystem now deposits 0.05 water per simulated second through `PileState.deposit_resource` during the one 60-second event. The first and last fixed ticks add their proportional share; a completed event adds exactly 3.0 units. Pile deposits use five-decimal precision for exact JSON continuation, matching resource debits. RainState and required save version 5 remain unchanged.
- The extended rain tests check waiting, first tick, pause, full duration, post-event, 4×/16×/64× totals, mid-rain JSON continuation, normal-view summaries, and the existing exposure/chemistry/familiarity behavior. Pinned Godot 4.7.2 import and full suite passed: 3,554 checks, zero failures. Headless Main smoke passed.
- A graphical Compatibility-renderer probe showed the restrained OUTWARD `RAIN / scent disturbed` status and INWARD Food Exchange context with water at 10.1 shortly after rain began. No physical Android-device test was run. The three-unit amount remains a provisional balance choice.
- Changed files: `src/sim/weather/rain_system.gd`, `src/sim/weather/rain_config.gd`, `data/weather/default_rain.tres`, `src/sim/colony/pile_state.gd`, `tests/test_rain.gd`, `tests/profile_slice.gd`, `README.md`, `docs/ARCHITECTURE.md`, `docs/DATA_MODEL.md`, `docs/UI_RULES.md`, `docs/VERTICAL_SLICE.md`, `docs/DECISIONS.md`, `docs/SLICE_EVALUATION.md`, and this card. Next: human playtest the revised search and water balance before taking on larger expansion.
