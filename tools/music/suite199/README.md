# Warm Current — C2 layered production suite199

The player calls198's C2 much better/pretty solid and finds C1's piano sounds unpleasant. This suite develops the selected C2 warm FM-key voice, pad, bass and quiet two-event rhythm. It contains **no sampled piano, plucked voice, rolled foreground chord or external recording**. The198 `soft_keys` function is reused unchanged; new notes/section arrangement and circular room-tail rendering are original project production work. No reference recording is sampled or used for conditioning.

This is196's independent production handoff: compatible musical sections and an illustrative adaptive listening mix, before runtime implementation. It is not a new gameplay system, a delivered game soundtrack or proof that the extended mix is musically accepted.

## Musical structure

Four musical roles—foreground, space, bass and rhythm—share **72BPM,4/4,16bars,2,352,000frames** per section at44.1kHz. Each section lasts53⅓seconds. All sections share the same eight two-bar harmonic rooms; changing a section at the common boundary retains musical phase and harmony. Air has three widely spaced foreground notes, Warm/Current have seven, and Breath has none. Current adds C2's restrained pulse; the last two bars omit its new hits. No chamber permanently owns an instrument in this production proposal.

Parts remain separate stereo16-bit WAVs under `builds/music_suite199/sections/<section>/<role>.wav`. `full.wav` is their reference sum. Voice tails wrap on the common grid. The same dense damped room character is rendered with periodic convolution and early reflections, so room tails also cross the loop boundary. Files use one common gain calibrated on Current; sparse variants remain quieter rather than being independently normalized.

Breath has no foreground, bass or rhythm. Its pad fades in over two bars and out during bars10–12, followed by a **four-bar whole-music rest**. This supplies genuine quiet rather than filling every gap with another sound. It is a musical presentation proposal, not a new game pause or world-state signal.

## Demonstration

The main4:26.67 mix follows Air → Warm → Current → Breath → Warm. Section changes start at0:53.33,1:46.67,2:40 and3:33.33. Each uses a two-bar6⅔-second complementary sin-squared/cos-squared blend with weights summing to1, preserving levels for correlated common material. There is a full musical rest at3:20–3:33.33, followed by a gradual return. The demo has its own entrance/ending fades and is not itself a game loop.

`Technical_CueOverlap.wav/mp3` is a separate local check using existing returned discovery/alarm files at83/139/228seconds with the current−15dB cue gain. **Those cues are absent from the main listening preview.** This checks headroom/overlap, not their artistic acceptance or actual report timing. The demonstration playlist is fixed authoring data, not a gameplay-driven scheduler.

## Reproduce and verify

Existing Python3.11/NumPy/SciPy and approved Blender5.2.2/Audaspace are sufficient. No source sample download, instrument/plugin/compiler/model installation, optional tool or paid service is needed. These are not Surge renders. Shared authoring utilities are imported from197/198; their unused piano functions are not invoked, and all recorded score events are checked against the allowed synthesized voices.

```powershell
python tools/music/suite199/render_suite.py
& 'C:\Program Files\Blender Foundation\Blender 5.2\blender.exe' -b --factory-startup --python tools/music/suite199/encode_preview.py
python tools/music/suite199/check_suite.py
```

The ignored output folder preserves lossless section/role/demo files, score/seed/event/playlist records and technical metrics. The main160kbps MP3 preview and final evidence are committed under `docs/evidence/card199`. Readback uses gapless PCM data as in198. [Inherited meter/encoding limitations](../pilot197/README.md) apply: the original BS.1770-style meter and oversampled peak estimates are preparation aids, not certified instruments.

Checks read the actual files: exact frame alignment, all60 nonempty part combinations, role reconstruction, exposed loop-wrap steps compared with nearby ordinary waveform slopes, crossfade boundaries/weight sums, deliberate silence, MP3 readback and existing cue overlap. An initial fixed absolute wrap-step threshold rejected a normal periodic waveform slope; the final check tests whether the boundary is an outlier relative to nearby slopes instead of requiring adjacent waveform samples to be identical. This is not proof of audible seamlessness; actual game decoder/transition timing and human listening remain later gates. Runtime code/assets, simulation, saves and the Windows package are unchanged by this production card.
