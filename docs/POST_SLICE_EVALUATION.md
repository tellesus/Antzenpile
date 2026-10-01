# Post-slice systems review — 2026-09-30

The automated review below is a deterministic command-driven integration run plus a Windows graphical probe, not a balance approval. It uses the authored backyard, seed 3030, and ordinary game commands; it does not edit hidden nodes, worker totals or stores. The player subsequently tried the current build and supplied qualitative feedback, recorded below. The original 20–30 minute session target remains tabled.

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

The combined mechanics work, but current resource surpluses make the long-run economic choice weak. Keep the session-duration target tabled. For subsequent implementation, the original GDD's next narrow expansion is one biologically costly Adaptation Web choice tied to brood, protein, nurses and time, with a trait tradeoff and delayed workforce expression. That needs its own executable card; do not scaffold rivals, daughter queens or the full web at once.

## Player feedback after the automated review

The player finds the basic technology functional but sees too few things to spend gathered resources on, so balance tuning is premature. Four simultaneous scouts feel restrictive while all are away. A tapped-out source needs a visible trace cue, and a numerical "may replenish in X seconds" line suggests knowledge the colony cannot justify. The player wants trail workers near unfamiliar cues to sometimes send a temporary investigator that rejoins the route. They want an initial Adaptation Web choice soon because it adds a meaningful resource spend. Card 037 handles the scout/UI corrections; trail-side investigation and adaptation each need separate bounded specifications. This is qualitative playtest evidence, not a measured duration or economy verdict.

## Player feedback after the first Adaptation choice

The first trait choice appeared and seemed to work. The player asks for a visibly distinct Adaptation Web control, clearer project names, and on-hand carbohydrate/protein/water amounts throughout INWARD. Card 040 addresses this presentation feedback.

They also report that sources tap out quickly and then feel impossible to find. The authored backyard has four starting 100-unit sources: exposed and sheltered carbohydrate, one protein, and one water. Of these, only sheltered carbohydrate renews (+12 every 300 simulated seconds). Picnic protein appears as a separate 24-unit temporary source every 600 simulated seconds for a 200-second episode. The starting protein and water nodes and exposed carbohydrate do not renew. Rain contributes three water per front only after the first front's two-route traffic gate is met. Default scouts seek **new** sources, so a known empty source needs the selected-trace Investigate or depleted-trail Recheck action to test it again; neither action can restore a permanently empty node.

Card 041's ordinary-command seed-3030 audit found that 20 workers emptied starting water by **180.5 simulated seconds**, leaving 109.97 water on hand. Its returned trace reported empty; after another 600 seconds the node was still empty, rain had not begun, and an explicit known-source investigation returned empty. Adding sheltered-route traffic then triggered first rain, which added about **2.99 water** over the next 60 seconds. With only four workers on the water route and five on carbohydrate, **76 units** remained in the water node at 180 seconds. Twenty workers emptied starting protein by **154.5 seconds**. A separate 24-unit picnic protein source appeared at 450 seconds without refreshing colony knowledge; a scout reported it at 464.25 seconds and an eight-worker route delivered eight protein by 475.5 seconds when carbohydrate travel energy was funded. An exploratory run without a carbohydrate route found that same source but could not send collection traffic after its starting carbohydrate ran out. The multiroute integration run still accumulated substantial stores, so depletion speed depends strongly on labor choices and resource-chain support.

This established a misleadingly permanent exterior water trace and a carbohydrate-dependent protein recovery path, but did **not** prove an irreversible colony lock: rain could still supply water after the sheltered/exposed traffic gate, and known carbohydrate routes could recover travel energy. It motivated a narrow rain-fed physical water-source follow-up rather than a broad collection-rate change. Overall economy balance and session duration remain tabled.

## Rain-fed water follow-up

Card 042 implements that narrow candidate. Each raining fixed tick now adds 0.1 physical water to `water_01`, up to its authored capacity of 100; a complete unharvested front adds 24 exterior units in addition to the existing three units delivered directly to colony stores. An ordinary-command run first depleted the water route, then started rain through sheltered traffic. The source refilled while the route and colony memory still reported empty. Only the player's Recheck sent workers back; their loaded home return increased stores and replaced the stale empty report. A mid-rain version-5 save continued exactly. This changes access after rain without changing starting source sizes, trail rates, brood costs, the first-rain gate, or the broader economy balance.
