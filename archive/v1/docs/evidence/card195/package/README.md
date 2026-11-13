# Windows delivery — tactile entrance and ambience195

Committed runtime `b3a6c1ccfba7427e74e76c827e222b41ca2768cf`; pinned Godot4.7.2 Compatibility and official Windows release template. **684 audited resources**, **81,501,443 ZIP bytes**. ZIP SHA256 `265e1e9710901da2f33e4fce1b1dd33ef773815b11e9a254a7eeba6882c39f87`. Same-build identity `windows-305cab8ab47f77223003c24158b93141b301c8364c6610266c115f89a0e9356b`.

The builder passed isolated import/export/inventory/extraction, payload hashes, actual release Main startup and unchanged-PCK save/resume/review under the pinned editor. No cold-import retry. [Build result](build.log), [actual release startup](release-main.log), [packed persistence](persistence.log), [manifest/launch paths](manifest-summary.json). The manifest's generic `not_checked` field describes the builder alone; the additional native probes below ran afterward.

Native pinned-editor probes of the unchanged PCK pass compact entrance rendering, touch-based independent volume selection and persistent preferences, nonzero bounded mixer output through the24-second loop wrap, music/cue mute independence, pause silence and audio shutdown/restart. Windows WASAPI was active; captured mixer output is technical verification rather than human listening acceptance. [Ambience log](ambience.log), [entrance](entrance_900.png), [sound controls](entrance_900_sound.png).

[Normal window close](window-close.log) also passes repeated close requests, release of all four music streams and the new ambience stream, and unchanged simulation/no autosave. The real inherited shutdown handler exits after draining queued audio. This is native packed-code lifecycle evidence; actual release startup is independently checked by the builder above.

The separate actual-release gameplay1237-check harness from193 was not rerun because195 changes presentation/audio, not simulation or packaging behavior. [Source/native/full regression and timing](../README.md) cover this change. Human art/audio/feel, physical touch, clean-machine launch and active-session/release frame pacing remain acceptance. Start a new colony after switching builds; previous-build migration remains tabled.
