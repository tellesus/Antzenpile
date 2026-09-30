# Task 022 slice evaluation

This is an integration baseline, not a human playtest or final balance approval. It uses the authored backyard and seed 3030. The command-driven fixture follows normal simulation commands and never edits resources, worker counts or hidden world state.

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

Two design gaps need evaluation before adding systems or changing balance:

- The Food Exchange can be developed at 65 s, before protein is found and before the nursery needs larval food. Nothing currently makes the Primitive chamber feel strained. A player may receive the music reward well before brood growth, reversing the intended developmental arc. Decide whether the arc should be reordered, development gated, or strain communicated through existing state; do not add a new pressure mechanic without design approval.
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

Stop feature expansion here. Run a human Windows playthrough, ideally with more than one player, timing choices separately from simulated time. Ask whether the sensory search, trail decisions, rain recovery, chamber timing and music reward create the intended 20–30 minute arc. Use those observations to decide on pacing or scope changes before ecology, rivals or adaptation.
