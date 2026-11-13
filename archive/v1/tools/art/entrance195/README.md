# Local entrance and ambience production — 195

This pass uses two explicitly authorized sources: ambientCG Ground054 color/displacement maps and the public high-quality preview of **Leaves rustling.wav** by leah15 on Freesound. Both are CC0-1.0, verified on their source pages on 2026-10-16. `source_manifest.json` records exact public URLs, author, license, byte size and SHA-256. The Freesound input is the public MP3 preview, not the login-required original WAV. No account, paid service or subscription was used.

Run `fetch_sources.py` with Python to fetch and validate the two inputs into `.godot/card195/sources`. A changed checksum stops the fetch. The cache is not shipped or committed. Existing Python/NumPy and installed Blender 5.2.2 LTS are the authoring tools; no newly installed library or runtime addon is needed.

## Entrance

Run Blender `-b --factory-startup --python tools/art/entrance195/render_entrance.py`. This constructs original deterministic geometry with seed195: irregular excavated banks and throat, five worn ramps, asymmetric deposited chips, dry root and plant fragments, an orthographic camera and three lights. The two scanned maps supply fine grain/color, not the geometry. The `.blend` remains editable in `.godot/card195/entrance.blend`; the committed generator plus checked source downloads reproduce it. The PNG is 1600×560 RGBA with mipmaps in Godot. It replaces the192 SVG at runtime; that older source remains historical/recoverable.

The result is a baked local illustration, not a newly surveyed landscape, construction state or runtime 3D scene. Existing bounded decorative ants remain separate. The outer field fades into black; all source geometry is local to the entrance.

## Ambience

Run `compose_ambience.py --blender <installed-blender.exe>`. Blender's bundled Audaspace decodes the public MP3. Existing NumPy processing removes DC/rumble/brittle high frequencies, overlaps deterministic short stereo grains into a 24-second loop, soft-limits and leaves peak headroom. The script writes `assets/audio/colony_ambience.wav` and `.godot/card195/audio.json`. This is designed granular foley, not a recording of actual ants. No voices, remote wildlife, event signals or biological claims are added.

Only the finished PNG/WAV ship. The runtime uses one extra bounded audio player with its own ambience preference (default50%), independent of the four existing synchronized music players and returned information cues. Known Home workforce controls bounded intensity; pause, relinquished/empty Home and ended review yield silence after a real-time fade. It is a Home colony bed, not positional sound from whichever pile is being inspected. Audio preferences stay outside colony saves. The native probe checks real mixer output/wrap, pause silence, independent controls and unchanged run state; technical checks do not establish listening enjoyment.

## Source license links

- https://ambientcg.com/view?id=Ground054
- https://docs.ambientcg.com/license/
- https://freesound.org/people/leah15/sounds/191454/
- https://creativecommons.org/publicdomain/zero/1.0/
