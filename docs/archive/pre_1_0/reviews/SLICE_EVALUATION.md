> **ARCHIVE ONLY — frozen 2026-10-04.** Historical record; not an active plan, current contract or implementation instruction. Use the [current documentation](../../../README.md). Original path: `docs/SLICE_EVALUATION.md`. Historical status and recommendations below apply only to their recorded build.

# Task 022 slice evaluation

This is the task-022 integration baseline before later playtest changes, not a human playtest or final balance approval. It uses the authored backyard and seed 3030. The command-driven fixture follows normal simulation commands and never edits resources, worker counts or hidden world state.

## Arc and pacing

| Milestone | Simulated time at 1× |
| --- | ---: |
| East/west carbohydrate reports delivered | 43.25 s |
| Two funded trails trigger rain | 65.00 s |
| Food Exchange development starts | 65.00 s |
| Protein report delivered | 92.50 s |
| Food Exchange developed; second music layer requested | 125.00 s |
| Eight brood emerge; living workers 40 → 48 | 360.00 s |

The final run has three known signals and three invested routes. Resources came home before development, the rain event finished, and the ledger conserved all workers. The headless integration test and save/reload continuation suite pass. The scripted arc reaches all implemented milestones in **six simulated minutes**. It does not measure how long a person spends interpreting signals, choosing routes or using accelerated time. A 20–30 minute human session is therefore unverified and appears optimistic with current tuning.

The original task-022 evaluation raised two questions:

- The Food Exchange can be developed at 65 s, before protein is found and before the nursery needs larval food. The player has since chosen to keep this early project available. Its second music layer may arrive before brood growth by design; do not add a timing gate simply to reorder these milestones.
- At emergence the probed run held about 111 carbohydrate and 42 protein, while water had fallen to about 0.2. Continuous routes can exceed this single cohort's demand by a wide margin, so the intended labor and route-maintenance tradeoff is not yet proven. A human playtest should examine resource choices before tuning delivery, costs or cohort timing.

The resource-approach sensing, return-only knowledge, rain chemistry/familiarity contrast, save continuation and worker conservation each have dedicated tests. The player's subjective interest in scouting, weak scent recovery, INWARD context and the placeholder music remains to be assessed by play.

The separate graphical `tests/timed_slice.gd` walkthrough ran the same seed through the OUTWARD scout/trail and INWARD development command paths at 1× with a 60 FPS cap. It reached emergence at **360.00 simulated seconds / 359.83 real seconds**, with 48 conserved workers and three routes. Its intermediate wall-clock times tracked simulation to within about 0.2 seconds. This verifies normal-speed Windows clock/UI integration, but it is automated and cannot measure human decision time.

## Windows presentation and workload

With `GODOT_EXE` set as in the README, run from the repository root:

```powershell
& $env:GODOT_EXE --path . --script res://tests/profile_slice.gd
& $env:GODOT_EXE --path . --script res://tests/timed_slice.gd
```

Run `tests/profile_slice.gd` graphically with the pinned Godot 4.7.2 console executable, Compatibility/OpenGL renderer. It constructs a rain workload with two active routes and a protein scout, then an end-state workload with three routes, three signals and a developed Food Exchange. It samples 240 frame intervals per OUTWARD/INWARD view after 30 warmup frames, at 1280×720. On **AMD Ryzen 7 7800X3D / Radeon RX 6650 XT**, the busiest rain OUTWARD pass measured **4.17 ms median, 4.28 ms p95, 4.43 ms worst** (roughly 234 FPS at p95), with at most **8 scene nodes and 61 draw calls**. The other three view passes had p95 at or below 4.31 ms. This clears the 60 FPS target on this machine only; modest desktop and Android devices remain unmeasured. The fixture used no visible per-worker nodes or costly lighting effects.

Inspected saved probe captures of rain OUTWARD at 1280×720, developed INWARD at 1280×720 and scaled 900×600. Text, functional nodes, controls and selected context remain separated and readable without bloom. The normal views show sensory signals and approved summaries, while F3 truth remains behind its debug-build guard. Existing mouse/touch-path tests cover turning, selection and INWARD actions; physical touch comfort and music listening were not measured. A clean graphical probe exit waits for the audio mixer to release its two loop playbacks; abrupt Godot quit can still warn about playback references.

## Decision point

Historical task-022 recommendation: run a human Windows playthrough, ideally with more than one player, timing choices separately from simulated time. This recommendation preceded tasks 023–028. The later player decision tables the 20–30 minute target until more systems exist; see the note below and the post-slice plan.

The player's first hands-on feedback on 2026-09-30 identified that short scout missions could fail to locate water beyond their range and that rain did not replenish home water. Completed cards 023 and 024 now search for new sources until confirmation and add three water units steadily during rain. The timing and water-shortage figures above remain the original task-022 baseline; repeat the human playtest to assess the revised balance.

Task 025 removes the single-cycle brood ceiling the player encountered. It leaves this original six-minute integration baseline intact; repeated cohorts require a longer human playtest to judge resource demand and growth pacing.

## Task 026 extended command-driven run

With seed 3030 and normal simulation commands, the longer run keeps Food Exchange available before protein discovery and before the first brood needs larval food. It uses no direct resource, worker or world edits.

| Milestone | Simulated time at 1× |
| --- | ---: |
| Food Exchange development starts | 40.00 s |
| First brood emerges; 48 living workers | 360.00 s |
| Second cohort stalls on empty water | 620.25 s |
| Returned scout reports water | 666.50 s |
| Water trail supports second emergence; 56 living workers | 790.00 s |

At first emergence, the run held 147.2 carbohydrate, 67.76 protein and 3.6 water. The second cohort stopped with zero water, then resumed after the player funded a trail to the returned water signal. At second emergence, the stores held 176.4 carbohydrate, 94.52 protein and 23.2 water. This demonstrates a concrete water decision in the authored scenario, while carbohydrate and protein still accumulate substantially. A mid-second-cycle save/reload with water travel in flight reached the same authoritative state. The scripted 13-minute-10-second duration is simulated time, not a measured human session or final balance approval.

The player later tabled the original 20–30 minute session target until more systems exist. These measurements remain useful regression evidence, not a pacing gate for the [post-slice plan](../plans/POST_SLICE_PLAN.md).
