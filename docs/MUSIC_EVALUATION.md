# Warm layered music — 092

The original eight-second sine-tone proof is replaced with an original 48-second/16-bar/80-BPM arrangement. Base provides low warm harmony/bass and soft recorded bass drum, with occasional tuned timpani at phrase ends. Food Exchange adds harp movement, Nursery soft marimba answers/rests, and Midden muted frame drum/wood/shaker detail. Authoring uses seven pinned CC0 VCSL recordings; Godot needs only the four finished WAVs. [Source and provenance](../tools/music/README.md).

## Verified

- Four actual PCM exports: 44,100 Hz, mono/16-bit, exactly 2,116,800 frames each. No independent normalization; common score/mix gain. Loop-overlapping tails/reflections are baked.
- All eight combinations of base plus optional layers: finite samples, peak below 0.203 at runtime gain, smallest headroom about 13.9 dB, boundary step below 0.000113 in floating-point review mixes. Actual stem PCM boundary steps ≤0.000184. [Measurements](evidence/card092_music.json). Numerical continuity/headroom are technical checks, not a subjective pleasantness rating.
- Windows/Godot 4.7.2 Compatibility actual playback: zero measured inter-stem phase spread after development, focused strain, shared seek to 46s followed by actual loop wrap while paused at 64x, and reload. Existing three-real-second fades, condition gains/player reuse and snapshot/RNG isolation passed.
- Actual music/cue preference probe passed in standard/compact INWARD/OUTWARD: touch/modal behavior, persistence, muted music with full cues, continuing playback and snapshot isolation.
- Final full suite: **6003 checks, zero failures**. Resource import and 90-frame Main smoke passed without script/resource errors. Existing environmental Godot user-log/editor-settings/certificate permission warnings remain.

## Limits and playtest

Four uncompressed source/decoded PCM payloads total about 16.15 MiB, approximately 14.80 MiB more than the prototype. No runtime instrument library, reverb node, composer or extra player is added. Desktop functionality does not certify mobile audio memory, thermal behavior or frame pacing; Pixel 7 Pro remains pending. The short playback probe deliberately seeks all voices together to exercise the new 48s wrap without an unnecessary minute-long wait.

Subjective long-repeat listening, headphone/phone-speaker balance and user preference remain playtest questions; no listening approval is claimed. The player can compare `builds/music_review/base.wav` with `base_food_nursery_midden.wav`, and the remaining six partial mixes, or develop the actual chambers in-game. Keep discovery/warning cues audible at the player's chosen volume. No extra music commission or gameplay change was made.
