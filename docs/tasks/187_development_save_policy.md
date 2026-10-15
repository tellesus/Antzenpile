# 187 — Same-build development saves

Status: complete; policy, build admission and verified Windows delivery published on main.

Player instruction: backwards compatibility is not a development goal or priority. Table work preserving previous saves until a true public release. Save files are supported only by the build that created them; current-build save/load must remain reliable. Continue actual game development and deliver one unified playtest build.

[Save policy](../SAVE_POLICY.md) is authoritative across instructions, design, roadmap, technical references, catalogs and completed-card history. [Current goals](../DEVELOPMENT_GOALS.md) record the remaining ordered work. Historical evidence stays factual and is not an active compatibility requirement. No old-file recovery or migration is authorized as current work.

Next: attach a deterministic producing-build identity to the disk envelope, reject absent/different build identity before state restoration, and keep same-build save/restart/review/load/continuation and failed-load atomicity. Identify editor/runtime content and exported package builds reproducibly; avoid a manual schema bump standing in for build identity. No migration adapter or schema weakening. Verify focused admission/current-flow checks, final full/import/Main and the unified committed-main Windows package.

Implemented exact-build envelope admission and deterministic editor/package identities. 11656 checks, 0 failures; focused 191 checks, 0 failures; import/Main, six native review flows and two separate-process restart checks pass. [Evidence](../evidence/card187/README.md).

Runtime `fd9b5917fe453b327ef290415e404cfba4ae3ac6`; 664 audited resources. Save build identity `windows-4d456d5fd9081629e976c8a754f3f1925ae0b55c043d33dff7327b1011a6706a`. Isolated export/inventory/extraction, actual headless/native release startup, PCK save/settings/review, current-save native retention/reload/continuation and direct armed-search checks pass. Two separate unchanged-PCK processes save then load/continue with the recorded identical build identity. Full: 11656 checks, 0 failures; focused: 191 checks, 0 failures. ZIP SHA256 `11706582eb7413edbcb038426dbf342df1073abe93d5ec5c7282e691e0bb55d1`. Both main checkouts match;109 original local files unchanged. Previous-build saves are unsupported. Human visual/audio/feel, physical touch and clean-machine acceptance remain separate.

Next: remaining animal/site/foreign impressions, context/onboarding/interface, music/exit cleanup and integrated game review.
