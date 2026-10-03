# Graphics production pass — 2026-10-03

## Direction and scope

The player's v2 handoff replaces isolated chamber icons/wires with embedded functional organs, dark shared material, structural tissue, baked light and limited foreground occlusion. Native Blender sources retain original meshes/materials and editable painted layer boundaries; built-in imagegen supplied the polished surface finish from those sculpts. No browser-returned kit was used as style authority. No new systems, engine, paid dependency, runtime 3D, surveyed tunnel map or remote-world imagery. Mobile export, device testing, quality tiers and optimization are **tabled by the player**; touch-friendly input remains.

## 095 — INWARD

Larger staggered Queen/Nursery/Entrance establish a common earthen/resin family. Known Food Exchange/Adaptation/Guest/Midden share it; Guest/Midden remain absent until known. Nursery gains a stronger protective lining/depth through existing development, plus a separately known capacity lobe. Body and front use the same source camera/UVs; live contents/representative ants render between them. All labels/UI draw last. Caption outlines and the Food Exchange offset prevent known Guest overlap. Texture sharing avoids duplicate generic-organ loads. Existing pause, health, caps and information boundaries remain.

Sources: [production README](../tools/art/colony_material/README.md), [original sculpt](../tools/art/colony_material/colony_material.blend), [packed finish](../tools/art/colony_material/colony_material_finished.blend). Native GUI automation was unavailable; actual local Blender CLI/Python authoring/export was used. No claim of Krita painting. Original sculpt geometry is editable; imagegen surface pixels and front boundary polygons are packed/editable in the finish source. Ten consumed finish outputs reproduce pixel-for-pixel from that source (see verification JSON); re-running AI generation itself is not deterministic.

Reviewed [before](evidence/card095_inward_before.png), [primitive](evidence/card095_inward_primitive.png), [expanded](evidence/card095_inward_expanded.png), [compact selected](evidence/card095_inward_selected_900.png), [known strain/functions](evidence/card095_known_activity.png) and [alpha on black/gray](evidence/card095_alpha_check.png). Dynamic anatomy is the existing authored worker/queen/brood art, not remade in this pass. Auxiliary functions reuse the Queen material at a distinct footprint/color; more organ-specific sculpt variants remain an art refinement, not missing gameplay.

## Desktop measurement

Windows / Godot 4.7.2 Compatibility / Ryzen 7 7800X3D / RX 6650 XT / driver 26.8.1.260806. Same `probe_release_graphics.gd` fixture before/after; isolated final run without concurrent Blender rendering or regression workloads. VSync disabled for comparable intervals, plus separately paced stress case. Frame intervals include engine/OS scheduling, **not GPU timer measurements**. Raw reports record window, logical viewport, actual render texture, frame counts/p50/p95/p99/worst, draws and texture bytes. At this desktop's scaling, 900×600 window rendered 633×356 and 1920×1080 rendered 2880×1620; comparisons use matched actual render sizes.

| INWARD workload | Before p95 ms | After p95 ms | Before / after draws |
| --- | --- | --- | --- |
| 1280×720 window/render | 1.805 | 1.799 | 196 / 185 |
| 900×600 window (633×356 render) | 1.755 | 1.735 | 194 / 187 |
| 1920×1080 window (2880×1620 render) | 1.845 | 1.805 | 196 / 189 |

Texture memory at standard INWARD: 24.92 -> **55.02 MiB**, +30.10 MiB. Rich layered pixels have a measured memory cost; this is acceptable on the tested desktop and is not a mobile claim. Paced unchanged OUTWARD p95 4.260 -> 4.240 ms at 240 Hz. Both detached workloads preserved exact simulation/RNG snapshots; 6060 full-suite checks, final import/Main and graphical mouse/touch/pause checks passed. Full raw [before](evidence/card095_desktop_before.json), [after](evidence/card095_desktop_after.json), [source verification](evidence/card095_source_verification.json).

The only first-run sandbox messages concerned external engine log/editor settings/certificates; final authorized verification runs wrote normal engine files without those errors. Existing probe shutdown ObjectDB warnings remain; no parse, runtime or test failures. No minimum hardware, release export or Android/Pixel validation is claimed.

## Next bounded section

096: local OUTWARD Home/near-ground depth and smoky knowledge-derived signals. Preserve trail/scout anchors and returned-only recognition, captions, controls, unknown darkness and existing representative limits. No distant scenery or baked ants. Follow with combined desktop comparison; original gameplay roadmap resumes afterward.
