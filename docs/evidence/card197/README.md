# Three music auditions —197

The player authorizes the196 listening pilot before considering additional tools. These are fresh original compositions and voices with new soft CC0 piano recordings. No190 music or195 rustle bed is present. RimWorld's menu is a mood reference; its audio is not source material. All three are prepared at a common measured listening level. Musical quality remains the player's decision.

| Audition | Direction | Length | Arrangement cue |
| --- | --- | --- | --- |
| [A — Mosslight](audio/A_Mosslight.mp3) | Spacious organic ambient: soft piano, rounded synthetic plucks and slow pads; no drums. | 1:17 | Foreground thins around28–35seconds; sparse ending. |
| [B — Slow Current](audio/B_SlowCurrent.mp3) | Warm FM keys, restrained bass and a light laid-back groove. | 1:24 | Groove arrives after the opening; drops away around52–58seconds. |
| [C — Root and Sky](audio/C_RootAndSky.mp3) | Organic/electronic hybrid with occasional keys and quiet rhythm. | 1:26 | Long sparse interval around40–60seconds, followed by return. |

Set a comfortable volume once and compare them without changing it. Consider which feels right, which voice becomes irritating, whether the beat belongs, and whether you would want it behind decisions. It is valid to reject all three. The pieces have deliberate endings; they are not delivered game loops.

Longer three-pass MP3/WAV previews, lossless short mixes and four separate role WAVs are local under `builds/music_pilot197/<audition>/`. Repeats last3:55,4:17 and4:23 with2.5-second spaces between full passes. They test recognizable repetition rather than pretending the sketch is already a seamless loop. The source recipe regenerates those ignored outputs.

[Reproducible recipe and source provenance](../../../tools/music/pilot197/README.md), [source manifest](../../../tools/music/pilot197/sources.json), [render metrics](metrics.json), [file checks](checks.json), [encoding hashes](encoded.json), [render log](render.log), [encoding log](encode.log), [final check log](checks.log).

The existing Python/NumPy/SciPy renderer and Blender's bundled encoder were used. Surge's native Python route was inspected but not available without a compiler setup; these are not Surge renders. No optional tool, paid service, generative model or runtime dependency was installed. This pilot tests the musical alternatives within the existing authoring setup. If the content/palette fails, the player has deferred additional tool choices to that decision.

The automated gate validates PCM/MP3 preparation, loudness comparison, headroom, part reconstruction and repetition files. It does not certify BS.1770 compliance or establish listening quality. Full game regression/import/export were not run because no runtime code/assets changed. The current package continues to be the earlier build until a chosen replacement is implemented.
