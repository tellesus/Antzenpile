# Tactile entrance and local ambience —195

Blender5.2.2 LTS renders original excavated banks, throat and worn ramps using ambientCG Ground054 color/displacement (CC0). A processed CC0 leaf-rustle recording from Freesound supplies a quiet 24-second stereo granular ambience. These are production resources; no extra runtime addon or paid service was introduced. [Source recipe and exact provenance](../../../tools/art/entrance195/README.md).

- [Standard outward](outward_1280.png), [1080p](outward_1920.png), [compact](outward_900.png): final local material, preserved black field and bounded representatives. This is the same detached six-route art fixture used in192, not actual newly discovered sources.
- [Compact independent sound controls](sound_900.png): Music, Information cues and Colony ambience. Native tests exercise ambience selection without changing the run.
- [Native mixer/input evidence](native-final.log): imported loop plays through its wrap, has bounded nonzero mixer output, fades to silence under paused intent and preserves the run snapshot. Dummy driver verifies mixing, not speaker/headphone listening.
- [Focused gate](focused.log): **635 checks, zero failures**. Includes independent preference persistence/atomic rejection, hidden-state invariance, headless silence, pause/ended/relinquished silence and shutdown/restart behavior.
- [PCM/source metrics](audio.json): 44.1kHz stereo,24 seconds, peak−15.918dBFS, RMS−34.146dBFS, circular seam step144 PCM units and effectively zero DC. Runtime default50% and authored−3dB keep this below information cues. These measurements do not establish subjective listening quality.
- [Resource checksums](assets.json), [final import](import-final.log), [Main smoke](main.log), [Blender render](render.log).

The first material attempt spread lit ground/debris too broadly. Native inspection led to a darker peripheral field, a deeper opening and confined deposited grains. The final images above replace those trials. The first Blender save could not write its optional OS thumbnail inside the sandbox; the reproducible generator now disables that thumbnail and final render completes successfully.

[Full regression](full.log): **12,395 checks, zero failures**. [Two isolated 60-second timing samples](performance.json) at1920×1080 on Ryzen7800X3D/RX6650XT: OUTWARD median/p99 **7.773/9.567ms**, INWARD **4.119/4.909ms**. The native editor runs paused simulation with live decorative time, six route/eight scout traces and developed INWARD; snapshots remain equal. These are scene frame-loop measurements, not active-game or release performance acceptance. [Timing log](performance.log).

Windows delivery results follow when complete. No gameplay state/save schema changed; audio preferences remain outside the colony slot. Human appearance/listening acceptance remains open.
