# 176 — Run and inspect the neon trail proof

Player outcome: PR #2 has an actual Godot 4.7.2 runtime and rendered visual baseline before further M8 effects are built. Scope is presentation validation and corrections to reproducible trail defects; simulation, gameplay, music and the later UI redesign remain unchanged.

Use the `visual/neon-trails-ux-direction-20261014` branch. Import resources, exercise the affected art/projection contracts, run Main, capture strong/weak/ghost/multiple trails at 1920×1080, 1280×720 and 900×600, and inspect entrance geometry, saturation, ant readability, pause and selected contexts. Distinguish detached presentation stress fixtures from real returned knowledge. Run the full headless suite after final runtime changes.

Original Work captures used Linux/llvmpipe. Recovery validated the same code with native Windows/RX 6650 XT captures and two 60-second 1080p frame-loop measurements. Player acceptance and a visible packaged-game playtest remain pending; keep PR #2 draft.

Status: complete for the bounded recovery/validation pass. Preserved all five existing PR commits and recovered the staged trail-mask correction, capture probe, documentation and all six saved runtime-evidence PNGs. Source changes stay within presentation and probes; simulation/gameplay/music are unchanged.

Verification: pinned Godot 4.7.2 import/Main pass; targeted 126/0; full 11,003/0 (475.19 seconds); 12 native captures pass. Both 60-second halo/control samples completed with unchanged snapshots and clean final stderr; timing outliers and background import load are recorded in the evidence. The Windows probes drain deferred draws and wait for the audio mixing thread before exit.

Changed groups: OutwardView/TrailGlow and the optional SensoryArt filament core; repeatable capture/performance probes; reconciled neon direction; preserved Linux and fresh Windows evidence. [Full evidence and limits](../evidence/card176/README.md).

The original complete Linux regression log and six concept-art files were unavailable. Source edits and all six staged runtime-evidence images were recovered. Two generated UID sidecars were regenerated. The new full suite and native captures replace the missing verification log.

Next bounded visual task: richer animated chemical clouds and evidence-supported ant/species impressions. Interaction cleanup, arc-length traffic motion, music and final player approval remain separate; no merge or release acceptance is implied.
