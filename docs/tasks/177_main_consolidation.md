# 177 — Consolidate the main development game

Status: complete. No runtime/gameplay change in this card.

Player outcome: one canonical `main` checkout and playable Windows build contain the systems beta and recovered neon-trail proof. Future tasks start from current `origin/main`; incomplete work remains in the shared backlog rather than competing long-lived branches.

## Integration and preservation

- PR #2 merged into `codex/graphics-proof` at `f3dcbc2ec72ab717e362fa6a1e05a88b7995525e`; PR #1 then merged that complete branch into `main` at `8ee145dfca4f48e793434b3ddb890844a9de9cf5`. Individual feature commits are preserved by merge commits.
- The merged main tree equals the verified card176 tree exactly: `07bc454094d3e6a1ecbfe5e50e2f6c0617397f3d`. This card changes documentation only. The inherited final runtime gate is **11,003 checks/zero failures**, plus 126 affected checks and 12 native captures; an unchanged full suite was not repeated.
- Both merged GitHub branches were removed. Nineteen older local topic branches had no unmatched patches against the beta; two were already ancestral. All 20 non-main local branches were removed only after a verified complete Git bundle and SHA manifest preserved their original tips.
- The primary checkout is on `main` tracking `origin/main`. All **109** pre-existing modified/untracked local files were backed up and preserved byte-for-byte, including root art and audio import sidecars. No player save or sound preference was changed.
- Recovery backups remain private local artifacts; they are not repository content. The separate recovery checkout also follows main. Old chat instructions do not authorize restarting retired branches.

## Playable package evidence

Built from merged main `8ee145dfca4f48e793434b3ddb890844a9de9cf5` with Godot 4.7.2 Compatibility and the pinned official Windows x86_64 release template. Offline packaging completed with **623 audited resources**, verified extraction/payload hashes, extracted release Main startup/exit, and packed save continuation, separate settings, debug/test exclusion and ended-review checks under the pinned editor. No cold-import retry was needed. ZIP size: **55,987,790 bytes**; SHA-256: `74171380476c76625dd8fa180e1a5c3a18265a685b9aa7b116c7648226973ccb`.

The local `builds/windows-beta-latest.json` identifies actual package paths and source revision. This card's later documentation commit leaves those runtime inputs unchanged, so that package contains the current game. No new release/player acceptance is implied.

## Remaining work

[Current Build](../CURRENT_BUILD.md#development-baseline-and-shared-remaining-work) is the shared active list. The interrupted player-save validation report is carried forward as [178](178_player_save_validation.md), not claimed fixed by generic save tests. Cloud/ant art, interaction simplification, music and final visible-game/timing acceptance remain separate follow-ups. The prior independent PR #1 review was interrupted; no completed reviewer approval is asserted.
