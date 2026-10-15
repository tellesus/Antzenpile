# 175 — Portable Windows systems beta

**Current development save policy (2026-10-15):** [Same-build saves only](../SAVE_POLICY.md). Earlier requirements to preserve/load/migrate previous-build saves are superseded and tabled until true release preparation. Historical implementation/evidence below does not create a compatibility goal.

Status: complete. M1–M7 review handoff / M9 packaging foundation.

Outcome: the player can extract a Windows x86_64 ZIP and launch Antzenpile without an editor or repository. This is a systems beta, not Windows 1.0 or final presentation/performance acceptance.

Use the pinned 4.7.2 standard release template and Compatibility renderer. Add a reproducible export preset and dependency-free packaging tool. Export an isolated committed runtime snapshot (project, src, data, scenes, assets), excluding tests, docs, authoring sources, old images, caches and credentials. Preserve existing working files and user saves. Verify template identity, record source/content/file hashes and include engine/asset notices and simple launch/feedback instructions. No downloads or upgrades during ordinary packaging.

Verify import, resource inventory and the exported release executable from the extracted package with isolated user data: Main start/exit and release-only boundaries. Reuse card174's unchanged full gameplay gate; repeat it only if runtime code changes. Record actual package checks and sizes. Native graphics/audio/feel, desktop performance and another-machine acceptance remain player checks under A88.

Commit the source tooling/documentation; keep generated binaries ignored. Publish the completed cards and hand off the concrete package with the remaining M8/M9 checks.

Completion: pinned Windows x86_64 release preset, offline standard-library builder, committed-runtime staging, actual exported-resource inventory, engine/asset notices and extract-and-launch instructions. A unique verified package and stable latest ZIP are ignored build outputs; their manifest identifies source/template/content/file hashes. Player saves and unrelated working files remain untouched.

Evidence: official standard-template archive SHA-256 verified; release-template identity pinned. Isolated import/export succeeded, 621 exported entries audited; extracted payload hashes matched and actual release Main start/exit passed. The unchanged packaged PCK under the pinned editor passed excluded-debug/test resources, exact saved continuation, separate sound settings, ended review and preservation of the earlier save. Initial cold import once faulted at editor shutdown after completed imports; retry exited cleanly, and a later complete fresh build imported without retry. The builder records and bounds that specific retry. Official release disables external script/path overrides, so deeper PCK evidence is explicitly distinguished from release-template interaction acceptance.

Unchanged gameplay retains174's final 11,000/0 gate; no runtime code changed and no redundant full suite ran. Packaging is about56MB compressed. Final published-revision rebuild records the exact current size/hash in `builds/windows-beta-latest.json`. Native graphics/audio/feel, release save/input interaction, performance and another-machine checks were not run.

Handoff: systems beta is ready for player review. [Windows beta guide](../WINDOWS_BETA.md) documents rebuilding and acceptance. M8 follows specific visual/audio/control/balance feedback; M9 still needs final release regressions, stated desktop measurements and clean-machine player acceptance. Neither milestone is declared complete by this package.
