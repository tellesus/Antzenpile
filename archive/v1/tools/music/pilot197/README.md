# Three original listening sketches —197

This is an offline musical pilot for the player's choice, not a replacement installed in the game. No190 melodies/arrangement/assets or195 rustle recording are reused. The RimWorld menu reference informs the written mood brief only; no reference recording was downloaded, sampled, transcribed or used for model conditioning.

The bounded authoring route uses existing Python3.11/NumPy/SciPy, eight new soft CC0 Kawai piano samples from the established VCSL source, original damped-string/FM/slowly modulated additive voices and a linear dense stereo room. The score's chords, phrases, omissions and beat placement are written explicitly; the fixed seed varies voice/pick details rather than choosing a random melody. Each sketch has four separately rendered role tracks with one common master gain.

Surge is approved but was not installed here. Its official Python extension requires a native build; no CMake/MSVC toolchain was found and official distribution metadata did not provide a ready Windows Python extension. The CLI inspection did not establish offline file rendering. Because the player explicitly deferred optional tools until after this pilot, this pass did not install build tools, a DAW, plugin host or model. It uses the existing offline renderer and fresh source material to make the proposed musical alternatives reviewable. **These are not Surge renders** and do not validate that proposed future production path. Audacity/Surge/AI/optional DAW adoption is not claimed by these files.

## Reproduce

Run with the existing Python and approved Blender5.2.2 executable, from the repository root:

```powershell
python tools/music/pilot197/fetch_piano.py
python tools/music/pilot197/render_pilot.py
& 'C:\Program Files\Blender Foundation\Blender 5.2\blender.exe' -b --factory-startup --python tools/music/pilot197/encode_reviews.py
python tools/music/pilot197/check_pilot.py
```

`fetch_piano.py` verifies the pinned VCSL Git tree/blob, size and SHA256 in `sources.json`; cache inputs live under ignored `.godot/card197/sources`. No full library download occurs. Source author: Sam Gossner/Versilian Studios, CC0-1.0. [Library/publisher permission](https://versilian-studios.com/vcsl/), [pinned upstream](https://github.com/sgossner/VCSL/tree/dfcf4a4918771eee884b96ad4493de82ef84daf6).

The renderer writes lossless44.1kHz stereo16-bit previews, four same-length role WAVs, explicit note/voice event JSON, three-pass repeats with2.5-second spaces and metrics under ignored `builds/music_pilot197`. These are standalone arrangements with fades and endings, **not seamless runtime loops**. Blender's bundled Audaspace encodes160kbps MP3 listening copies; three short copies are committed in `docs/evidence/card197/audio`. Longer MP3/WAV copies remain local and reproducible. No encoder/package is installed.

## Preparation checks and limits

The original metering code implements stereo BS.1770 K-weighting/gating, resampling the analysis to48kHz for the published coefficient set. A stereo1kHz0.1-peak tone provides a−20LUFS calibration sanity check. [ITU-R BS.1770-5](https://www.itu.int/dms_pubrec/itu-r/rec/bs/R-REC-BS.1770-5-202311-I%21%21PDF-E.pdf). The meter is not certified. Fourfold oversampling estimates peak headroom; no claim of certified true-peak measurement is made.

PCM mixes share−23.5LUFS. The bundled MP3 encoder attenuates them consistently by about0.45dB; the delivered decoded copies are separately checked against each other, rather than silently claiming they preserve the WAV level exactly. Readback uses Audaspace's gapless PCM data because its streaming WAV writer can append buffer padding. Checks cover durations, finite PCM, endpoints, stereo, headroom, quantized part reconstruction, repeat identity and decoded loudness spread. They do not establish enjoyment, naturalness, fatigue, cue masking or game integration.

Choose musical content by listening. A is spacious and beatless; B uses rounded keys with a quiet groove; C combines plucks/keys with a roughly20-second sparse interval. The next stage follows the player's choice or rejection of all three. No simulation, save format, runtime audio or Windows package changes belong to this pilot.
