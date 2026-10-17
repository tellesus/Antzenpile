# 198 — Remove jarring attacks from the listening pilot

Status: complete for listening delivery, 2026-10-17; player response recorded in199. The player rates197 A weakest (intrusive plucks), B promising but incoherent, and C best but quickly tiring because of its three-note hits.

Outcome: two standalone revisions based on C's72BPM harmony/space/breath: C1 removes the repeated plucked/chord attacks while retaining sparse softened piano; C2 explores B's warmer key color inside C's coherent structure with a quieter, lower-register phrase. Neither repeats the rejected three-hit figure. Match measured listening loudness and provide longer repetition previews and separate role tracks.

Scope/verification: existing approved authoring resources and197 source recordings; no optional tool adoption or runtime replacement. Check actual PCM/MP3 files, source hashes, event spacing, gain/headroom, role reconstruction and repeats. Player listening remains the acceptance gate. Preserve earlier auditions and user files. No game code/assets change, so import/full regression/package gates do not apply to these standalone authoring artifacts.

Delivered: [C1/Quiet Sky and C2/Warm Current](../evidence/card198/README.md), both86seconds at72BPM with four separate role WAVs, explicit event records and4:23 three-pass previews. Both remove the recurring210ms plucked triad and rolled foreground key chords, and simplify rhythm to two soft events per active bar. C1 retains sparse softened piano with one common instrument gain calibration; C2 explores a slower, lower key phrase inside C's harmonic/breath structure. Original197 files remain unchanged.

Verification: final PCM/MP3 file gates pass; PCM−23.500LUFS, decoded MP3−23.946LUFS with <0.001LU spread. Estimated oversampled peaks−8.280/−10.705dBTP. Quantized part reconstruction max0.0000611, exact repeats, durations/endpoints/stereo/headroom/source hashes pass. Foreground entrances are at least4.083/3.333seconds apart, no string voice/grouped foreground chords and no rhythmic entrances in the40–60second breath. Authoring syntax, internal links and whitespace checked. These are technical preparation checks, not certified metering or human listening acceptance. No runtime/full suite/import/export rerun or optional tool installation.

Changed-file groups: isolated198 authoring and review/evidence; current feedback/goals/decision/task handoff. Existing technical contracts remain unchanged.

Handoff: compare whether C1 resolves the jarring attacks and whether C2's warmer phrase improves cohesion. Keep or reject musical qualities based on the player's response before a full adaptive-suite/runtime replacement. Optional tools remain deferred.

Feedback199: C2 is much better/pretty solid. C1 is nice but its piano sounds are unpleasant. Use C2's warm synthetic keys as the musical foundation and exclude the recorded piano voice. This selects the direction; longer-form arrangement, adaptive transitions and the final game mix remain to be reviewed.
