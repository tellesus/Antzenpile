# Current development goals

Updated 2026-10-16. Player feedback reopens M8:192 rebuilds shared UI/dispatch/entrance/scout presentation;193 repairs actual-release gameplay omissions. Both are implemented and verified; appearance and gameplay coherence remain player acceptance. Canonical `main` and one latest Windows playtest build contain the combined work; earlier topic branches/exports are historical.

| Goal | Current result |
| --- | --- |
| Recover/consolidate stalled graphics work | Complete176/177: recovered code and six runtime captures, PRs1/2 merged; main is the only remote development branch. |
| Development save policy/reliability | Complete178/187: same-build-only admission, exact continued state, save/end/review/load/restart and failed-write retention. |
| M8 graphics/interface revisions | Complete179–189 and191: living neon clouds/workers, all supported food/threat/site/animal/foreign forms, explicit gathering/combat/borrowing/search, current help, bounded review and mature compact controls. Player appearance/feel remains acceptance. |
| Music/ordinary audio exit | Complete190/191: original longer stereo adaptive score, distinct voices/rests/cues and verified phase/fades/preferences; normal close drains queued audio before exit. Player listening/fatigue remains acceptance. |
| Integrated gameplay/interface/package review | Complete191 automated scope: fresh three-setting development/network/recovery, native standard/compact inspection, active1×/64× measurements and current-main Windows/PCK gates. |
| Organic UI, excavated entrance and scout scent | Complete192 implementation: shared warm surfaces, five-circle count editors, contextual icons/tooltips, pellet-built local entrance, textured scout memory, direct known adaptation navigation and clearer Midden rules. Full 12,380 checks and native captures/timing pass. |
| Release gameplay correctness | Complete193: 42 mutations execute outside debug assertions; the original missing recruitment pool is reproduced in the old release and 1,237 corrected actual-release checks pass. |

The next design outcome is the fresh-colony decision arc in [Gameplay coherence review](GAMEPLAY_REDESIGN_REVIEW.md), with combat, adaptation and construction choices assessed together. Continue player testing of the revised beta: appearance, listening/enjoyment, balance/control feel, physical touch if used, real session frame pacing and another-machine launch. Further high-speed/driver tuning follows measured playtest evidence; final Windows 1.0/release acceptance is not claimed by automated checks. Do not create speculative feature branches to fill this acceptance stage. New concrete reports become bounded cards on main.

[Save policy](SAVE_POLICY.md) overrides every older goal/card/catalog: loading, recovering, preserving compatibility or migrating **previous-build saves is not a development goal, priority, regression gate or resource allocation**. It stays tabled until true public release preparation. Start a new colony after changing builds. Same-build save/load/quit/restart/review must continue to work. Leaving unrelated files untouched is file safety, not old-save support.

Mobile and Post-1.0 systems remain deliberately deferred in the [roadmap](ROADMAP_1_0.md). [Current build/evidence](CURRENT_BUILD.md) and [Windows guide](WINDOWS_BETA.md) identify actual delivery and its limits.
