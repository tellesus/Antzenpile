# 178 — Current-build save and review reliability

Status: implementation; verification pending. Re-scoped by the player on 2026-10-15: historical save compatibility is unnecessary; validate saves made while testing the current build.

Player report: “I played a short run, saved, watched the replay, and then when I tried to restore from save it said it failed validation.”

Outcome: a current-build save loads and continues after End Run/review without weakening atomic validation or allowing a revealed ended run to resume. Before replacing a slot, validate its exact serialized payload through the same fresh RunState restoration used by the loader. A rejected write keeps the previous slot and the live state unchanged, with readable feedback. Start from current `main`, not any retired beta or graphics branch.

The original local slot and a private byte-for-byte copy remain untouched and unpublished. The reported historical failure was not reproduced; no historical root cause or migration fix is claimed. The player's latest instruction removes further compatibility investigation from scope.

Verify current fresh/scenario, mature active jobs, daughter supplies and armed-search snapshots; actual save → End Run → review controls → load → exact continuation, failed-save retention and failed-load atomicity. Run focused and final full/import/Main/native/packed gates. Measure save validation cost on the target Windows machine. This is current-build reliability evidence, not recovery of the original failure.

Verification: 11652 checks, 0 failures; focused 187 checks, 0 failures; import/Main and six native review flows pass. [Evidence](../evidence/card178/README.md). Publication/Windows delivery pending.
