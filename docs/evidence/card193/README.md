# Release-only gameplay repair193

Pinned Godot4.7.2 Compatibility, official Windows release template; isolated test package, no player saves or distributed test hooks.

- Historical e8742f4 runtime: **3 checks, expected 1 failure**. A real paid gathering route followed by recruitment has no response ledger pool in non-debug execution. [Log](baseline-release.log).
- Corrected runtime: **1,237 checks, zero failures**, including an explicit non-debug engine check and13 suites for recruitment, borrowing/cancel/travel, response/armed search, predator/rival continuity, scout loss/return, rain, refuge and reproductive/queen state. [Log](corrected-release.log).
- 42 mutating expressions in 10 runtime files are now evaluated before their debug assertions. The exporter audits assertion calls and permits only reviewed pure queries. Test fixture assertions are explicitly evaluated in the isolated harness; runtime code is copied unchanged.

Godot removes assertions in non-debug builds, including their argument evaluation: [official GDScript reference](https://docs.godotengine.org/en/4.3/tutorials/scripting/gdscript/gdscript_basics.html#assert-keyword). Earlier editor-on-PCK smoke tests could not establish release gameplay parity. The new tool uses the actual release executable with an embedded test scene.

Reproduce with `python tools/package/check_release_gameplay.py --godot <pinned-console> --templates <pinned-template-folder>`; append `--baseline-ref e8742f4` for the expected original failure. Export requires normal host temporary-file access on this workstation; sandbox-only export attempts were rejected by filesystem permissions and were not published. Same-build saves only; no old-save repair.
