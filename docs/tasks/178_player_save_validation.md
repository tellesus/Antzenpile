# 178 — Current-build save and review reliability

**Current development save policy (2026-10-15):** [Same-build saves only](../SAVE_POLICY.md). Earlier requirements to preserve/load/migrate previous-build saves are superseded and tabled until true release preparation. Historical implementation/evidence below does not create a compatibility goal.

Status: complete within the player's revised current-build scope; published to main and the Windows beta. Historical failure unrecovered.

Player report: “I played a short run, saved, watched the replay, and then when I tried to restore from save it said it failed validation.”

Outcome: a current-build save loads and continues after End Run/review without weakening atomic validation or allowing a revealed ended run to resume. Before replacing a slot, validate its exact serialized payload through the same fresh RunState restoration used by the loader. A rejected write keeps the previous slot and the live state unchanged, with readable feedback. Start from current `main`, not any retired beta or graphics branch.

The original local slot and a private byte-for-byte copy remain untouched and unpublished. The reported historical failure was not reproduced; no historical root cause or migration fix is claimed. The player's latest instruction removes further compatibility investigation from scope.

Verify current fresh/scenario, mature active jobs, daughter supplies and armed-search snapshots; actual save → End Run → review controls → load → exact continuation, failed-save retention and failed-load atomicity. Run focused and final full/import/Main/native/packed gates. Measure save validation cost on the target Windows machine. This is current-build reliability evidence, not recovery of the original failure.

Verification: 11652 checks, 0 failures; focused 187 checks, 0 failures; import/Main and six native review flows pass. [Evidence](../evidence/card178/README.md). Publication and Windows delivery are recorded below.

Runtime `760aa23188f5f776d26cef44a02c2c1f8965570d`; 662 audited resources. Isolated import/export/inventory/extraction, headless/native release startup and packed save/settings/review pass. Native unchanged-PCK current-save checks pass: actual scouts/gathering, save, invalid replacement retaining last good slot, ended-review overwrite prevention, touch playback/load and exact40-second continued state. Direct17-ant unsurveyed search/private contact/return remains verified. Full: 11652 checks, 0 failures; focused: 187 checks, 0 failures. ZIP SHA256 `b59c1c14bc7c47cf6680b5cec27f849a4d2ddd6eff4754ad8c76d09fa8e6d807`. Both main checkouts match and all109 original local files are preserved. Human audio/feel, physical touch and clean-machine acceptance remain separate.

[Package evidence](../evidence/card178/package/README.md). Continue remaining visual/context/interface/music and integrated review under standing authorization.
