# 093 — Soften repeating percussion

Status: complete (2026-10-02), prompted by the player's listening feedback after 092.

Outcome: remove the piercing repeated click and make the high percussion blend into occasional phrase accents. Keep the low drums, harmony, harp and marimba unchanged; preserve synchronization, chamber gates, fades, loop length, preferences and returned-information cues.

Scope: offline Midden arrangement/mix only. Remove wooden clicks; soften/lower and space out shaker hits. No new runtime audio effects, samples, dependencies or gameplay changes.

Verify: compare actual before/after PCM high-frequency energy and instrument event counts; prove the other three stems are byte-identical; check all eight mix combinations, exact frames/rates, boundary continuity and headroom. Run resource import, actual four-layer playback/wrap probe and the final full headless suite. Human listening remains the final judgment of the timbre.

Completed: 12 wooden clicks removed; shaker reduced from 64 to eight varied accents, lower gain and offline 3-kHz filtering. Retain the calibrated common gain so low harmony/drums, harp and marimba exports remain byte-identical. No new runtime cost or changed sound preferences/cues.

[Evidence](../MUSIC_EVALUATION.md): actual Midden PCM energy above 2.5 kHz falls 15.80 dB; all eight mixes retain peak <0.203 and boundary step <0.000113. Identical frame/rate/format/payload. Godot import, 90-frame Main smoke and actual four-layer development/focus/strain/paused-64x-wrap/reload playback passed with zero measured phase spread. Final full suite: **6003 checks / zero failures**. Only existing environmental editor-settings/log/certificate permission warnings.

Changed groups: Midden WAV, offline score/mix authoring and provenance, two numerical evidence files, evaluation/roadmap/card. Handoff: restart the game to load the new WAV and judge whether this addresses the reported sound. The exact sound was inferred from arrangement/source spectra; no subjective listening approval or Android validation is claimed. Other roadmap work remains outside this feedback fix.
