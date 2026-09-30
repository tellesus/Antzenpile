# 024 — Rain adds colony water

Status: expanded from the player's 2026-09-30 playtest; steady-rate choice accepted, implementation pending.

## Goal

When the authored rain event occurs, add a modest amount of water to each pile's authoritative stores while it rains. Make the benefit visible through existing approved resource summaries.

## Scope and contracts

- Keep the one-shot 60-second event and exposed pheromone washout. Configure three water units per full event, added steadily on fixed simulated ticks (0.05 per second), as selected by the player. The amount remains tunable after playtesting.
- Route deposits through PileState's resource API and preserve exact mid-rain JSON/disk-save continuation. Pausing stops gain; speed changes affect simulated, not real, duration. No direct UI mutation or separate water counter.
- Normal OUTWARD/INWARD show the updated home store only; exact rain state and terrain exposure stay in F3. No visual rainfall-as-map or new collection structure.

## Verification

Test water gain on the first and final rain tick, no gain before/after event or while paused, fixed total under all speeds, valid mid-rain save/reload continuation, and unchanged pheromone/familiarity behavior. Run pinned Godot 4.7.2 import, full suite and Main smoke. Inspect OUTWARD rain status and INWARD Food Exchange water context graphically. Record tests, limitations, changed files and one logical commit.
