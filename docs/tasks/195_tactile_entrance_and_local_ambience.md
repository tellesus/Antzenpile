# 195 — Tactile entrance and local ambience

Status: complete, 2026-10-17. Player authorizes trying the approved free production resources to improve the game.

Outcome: a visibly excavated local entrance with irregular banks, a recessed throat, traffic-worn ramps, soil grains and plant fragments, rendered in Blender with a CC0 ambientCG material; quiet processed CC0 leaf-rustle ambience with its own volume preference. Preserve black negative space, the sensory anchor, existing selection and all gameplay/information boundaries.

Presentation scope only: no terrain map, construction progress, unseen weather/animals or new simulation mechanics. Local ambience is decorative, stops/fades under pause or ended review, and consumes approved local summaries. Existing information cues and musical phase remain independent.

Verification: reproducible source/license/hash records, native standard/compact before/after captures, focused audio preference/pause/load/mute/teardown checks, PCM seam/headroom checks, pinned import/Main and final full regression; measure the changed scene and refresh the committed Windows package. Human art/listening acceptance remains separate from automated checks.

Implemented: original Blender geometry and CC0 ambientCG Ground054 material replace the local entrance sprite. The deterministic generator and pinned source hashes reproduce the asset; Blender is an authoring dependency only. A processed CC0 Freesound leaf recording becomes a quiet 24-second granular loop. Music, information cues and colony ambience have independent persistent settings. The ambience follows approved Home summaries, fades under pause/ended review and joins ordinary shutdown cleanup; it is decorative rather than positional world audio.

Verification so far: **12,395 full checks, zero failures**; **635 focused checks, zero failures**. Pinned import/Main pass. Native 1920/1280/900 captures and compact controls pass; mixer output crosses the loop wrap, stays bounded and fades to silence without changing the simulation. PCM peak−15.918dBFS, RMS−34.146dBFS and circular seam144 units. No new runtime addon or paid service. [Evidence](../evidence/card195/README.md) distinguishes mixer verification from human listening.

Two isolated 60-second native editor samples at1080p: OUTWARD median/p99 **7.773/9.567ms**, INWARD **4.119/4.909ms**, paused simulation unchanged. Active-game/release performance acceptance remains separate.

Changed-file groups: presentation entrance/sound/help; audio controller/preferences/state and ended-review intent; original material/ambience assets and reproducible authoring recipes; focused/native/performance/package probes; contract/provenance/evidence documentation.

Windows delivery: committed runtime `b3a6c1c`, **684 audited resources**, ZIP SHA256 `265e1e9710901da2f33e4fce1b1dd33ef773815b11e9a254a7eeba6882c39f87`. Isolated import/export/inventory/extraction, actual release Main and unchanged-PCK save/review pass. Native packed controls/preferences, WASAPI mixer wrap/pause/mute/shutdown and ordinary-close cleanup pass. No cold-import retry. The actual-release gameplay harness193 was not rerun; no simulation/package behavior changed. [Delivery evidence](../evidence/card195/package/README.md).

Handoff: canonical main and the refreshed latest Windows build include195. Start a new colony after switching builds. Player appearance/listening/feel, active-session frame pacing and clean-machine acceptance remain open. Further design work follows the existing gameplay-coherence review and concrete player feedback; this production pass does not define new gameplay systems.
