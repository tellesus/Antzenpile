# 178 — Investigate the player save-validation failure

Status: not started. Carried forward from the interrupted implementation chat during consolidation177; no fix is claimed.

Player report: “I played a short run, saved, watched the replay, and then when I tried to restore from save it said it failed validation.”

Outcome: the player's valid saved run loads and continues after End Run/review without weakening atomic validation or allowing a revealed ended run to resume. Start from current `main`, not any retired beta or graphics branch.

First preserve a private byte-for-byte copy of the actual saved slot. Use that copy, plus the ordinary save → End Run → review → load sequence, to identify the first failing validator and determine whether the slot was already invalid when written or was affected by review/serialization. Never overwrite the player's original slot, commit it, post its contents or relax invariants merely to make it load.

Add a focused regression for the confirmed cause, verify failed-load atomicity and exact continued state, then run the appropriate full/import/Main/packed gates once after final runtime changes. Record source/save versions, the reproduced failure and actual results. The existing generic 11,003-check suite and packaged round-trip smoke do not by themselves resolve this specific report.
