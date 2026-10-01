# Post-slice systems review — 2026-09-30

This is a deterministic command-driven integration run plus a Windows graphical probe, not a human playtest or balance approval. It uses the authored backyard, seed 3030, and ordinary game commands; it does not edit hidden nodes, worker totals or stores. The original 20–30 minute session target remains tabled.

## Combined run

| Observed milestone | Simulated time |
| --- | ---: |
| First traffic-gated rain begins | 40.00 s |
| Nursery development starts, after Food Exchange and exterior returns | 88.75 s |
| Developed Nursery supports two overlapping aggregate cohorts | 178.75 s |
| Scout delivers picnic protein report after its hidden appearance | 493.25 s |
| Second rain front finishes | 759.50 s |
| Returned investigation supports a tentative recurrence hint | 1064.25 s |

The run reached 16 emerged brood and 56 living workers. Five routes were invested over time; the player recalled five idle workers from the depleted picnic route, leaving four routes committed and 36 workers available at the end. Seven scout reports were delivered. Worker-ledger conservation, nonnegative stores, hidden/knowledge separation and a 100-tick complex save continuation all passed. The source appeared before any player-facing signal, disappeared while its report remained, and taught recurrence only after a later scout returned. Both rain fronts applied the existing exposed-chemistry loss and steady water benefit.

The Nursery payment left about **8.31 carbohydrate, 3.0 protein and 2.45 water**. By the final review the stores held **156.09 carbohydrate, 110.52 protein and 95.2 water**. This shows that four continuously funded routes can accumulate much more than the current brood/chamber uses, even after travel energy and two cohorts. The temporary 24-unit protein source was discoverable and harvestable, but did not create a storage overflow or missed intake. Card 034 remains deferred under its conditional gate; the surplus is evidence for a future resource-use or labor-pressure review, not a reason to impose a speculative cap now. The scripted 1064.25 seconds are simulated time, not human decision time.

## Windows presentation and limits

With the pinned executable set as `GODOT_EXE` in the README, the visual checks are reproducible from the repository root:

```powershell
& $env:GODOT_EXE --disable-vsync --path . --script res://tests/probe_post_slice_views.gd
& $env:GODOT_EXE --disable-vsync --path . --script res://tests/profile_slice.gd
```

The pinned Godot 4.7.2 Compatibility/OpenGL build ran on an AMD Ryzen 7 7800X3D / Radeon RX 6650 XT at 1280×720 and 900×600. A graphical probe of the selected picnic trace and Nursery context produced [full-size OUTWARD](evidence/card036_selected_outward_1280.png), [compact OUTWARD](evidence/card036_selected_outward_900.png), and [compact INWARD](evidence/card036_selected_nursery_900.png) captures. Inspection found the trace, evidence text, Invest and Investigate actions, Nursery status, and bottom controls separated and readable without bloom. The first compact review exposed an Investigate/bottom-control collision; the card-036 layout correction moved the evidence line and button inside the context card, and a 900×600 hit-rectangle regression check now guards it. Darkness and sparse strokes remain the dominant visual field.

With VSync disabled, the selected OUTWARD probe measured **0.39 ms p95** at 1280×720 and **0.38 ms p95** at 900×600, with at most **8 scene nodes and 47 draw calls**. The older three-route graphical probe measured 0.51 ms p95 in rain OUTWARD, 0.51 ms in rain INWARD, 0.40 ms in mature OUTWARD and 0.44 ms in mature INWARD. A separate windowed pass with VSync enabled ran near 33 FPS (about 31 ms frame intervals) on this desktop; the uncapped measurements show low scene workload, but the windowed pacing discrepancy remains an environment/display observation rather than a mobile-performance claim. The headless suite passes **3,850 checks, zero failures** after the layout correction. No Android-device test, physical touch test, current-build human playthrough or music-listening assessment has been completed.

## Next design gate

The combined mechanics work, but current resource surpluses make the long-run economic choice weak. Keep the session-duration target tabled. Before a broad balance pass or adding a new resource cap, use a current-build human playthrough to assess whether scouts, uncertain recurrence, labor recall, two-cohort care and repeat rain make interesting decisions. For subsequent implementation, the original GDD's next narrow expansion is one biologically costly Adaptation Web choice tied to brood, protein, nurses and time, with a trait tradeoff and delayed workforce expression. That needs its own executable card; do not scaffold rivals, daughter queens or the full web at once.
