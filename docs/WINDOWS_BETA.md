# Portable Windows systems beta

Card [175](tasks/175_windows_systems_beta_package.md) packages the headlessly verified M1–M7 build for player review. Extract the complete ZIP and open `Antzenpile/Antzenpile.exe`; keep its `.pck` beside it. The editor, Python and authoring tools are not needed to play. This is not the final Windows 1.0 release.

## Current playable baseline

Use current `main`. PRs #1 and #2 are merged; the latest package includes the systems beta, recovered soft neon trails and [flowing clouds/returned spider-beetle memories179](tasks/179_living_chemical_clouds.md). `builds/windows-beta-latest.json` is the canonical build pointer. Launch its `launch` path or extract the stable latest ZIP; named older export folders remain historical snapshots. The179 package audits 634 resources and passes the extracted release/PCK gates, plus native rendering under the pinned editor with its unchanged PCK. Final player/release-template input/audio/feel acceptance remains separate.

## Rebuild from a checkout

Python 3.11+ and Git are authoring requirements only. Use the pinned **standard Godot 4.7.2 Windows console editor** and matching standard export templates from the [official release](https://github.com/godotengine/godot-builds/releases/tag/4.7.2-stable). Extract `windows_release_x86_64.exe` and `version.txt` into a local template folder. The script checks version and the release-template SHA-256; it makes no downloads.

```powershell
python tools/package/build_windows_beta.py --godot 'C:\path\Godot_v4.7.2-stable_win64_console.exe' --templates 'C:\path\templates'
```

The builder exports `HEAD`'s committed project/src/data/scenes/assets in a new isolated cache folder; unsaved gameplay edits are intentionally excluded. The checkout's preset and notices are used and hashed. It produces an ignored `builds/Antzenpile-systems-beta-windows.zip`, retains its unique archived ZIP and unpacked launch folder, and writes `builds/windows-beta-latest.json` identifying paths, revision, sizes, hashes and logs. Packages are reproducible from the recorded inputs; binary byte-for-byte determinism is not asserted.

The same-preset ZIP resource audit validates actual exported paths. Tests, debug truth scripts, documentation, authoring sources, credentials, old root images and saves are excluded. `BUILD_MANIFEST.json` records committed runtime and exported-resource hashes, engine/template/preset identity and payload hashes. Engine MIT/third-party notices and asset provenance accompany the game; they do not assign a new license to project work. The beta is unsigned, with no installer or signing certificate.

Import, export, inventory, archive extraction and extracted release Main are checked with isolated user data. Official release templates disable external script/path overrides. An external probe therefore uses the pinned editor with the unchanged packaged PCK to check excluded debug/test resources, saved continuation, separate sound preferences and ended-review isolation. This is packed-code evidence, not a release-template save/input test. The probe is not shipped. A pinned editor access-violation exit after completed cold import may retry **once** only if no import/script errors appeared; both logs and the retry flag remain recorded. Other failures stop packaging.

## Saves and player acceptance

The package uses `%APPDATA%\Godot\app_userdata\Antzenpile`, with `saves/slot_1.json` and separate `audio_preferences.cfg`. It shares development-build paths. Back up that folder before testing an existing save; packaging probes never access it.

Actual native graphics/audio/feel and desktop performance remain unverified by these headless gates. Under [A88](DECISIONS.md), player beta feedback precedes final M8 presentation/balance decisions and M9 release acceptance. Try start/gather/develop/queue a trait, returned conflict/recovery, daughter continuation, save/reload, End Run and exit. Report confusing controls, visual/audio issues, or slowdown with Windows/CPU/GPU/resolution and time speed. Mature/network/crisis states and another-machine launch remain explicit acceptance checks.

Mobile production is tabled. Completing this packaging foundation does not mark M8 or M9 complete.
