# Current-build save/review reliability178

Player scope, 2026-10-15: saves made while testing the current game; historical compatibility is not required. The original reported failure was not reproduced, so no historical root cause or recovery is claimed. Original/private slots remain untouched and unpublished.

SaveService now validates the exact serialized JSON through a fresh RunState before any filesystem write. If validation fails, readable feedback explains that the slot is unchanged; both live state and previous slot remain intact. The same strict loader invariants, checksum, size limit, temporary-write/readback and rename are retained. No migration or schema change.

Full: 11652 checks, 0 failures; focused: 187 checks, 0 failures; import/Main pass. Current three-setting fresh saves, active rain/scouts/cargo/chamber work, two-nest paid supplies and armed departure/private combat/return/report all save, end/review, reload and continue exactly. Tests reject unrestorable writes while preserving the last good slot and failed-load atomicity. Targeted validation plus write measured roughly16–29ms for14–119KB saves on Ryzen7800X3D/64GB Windows; these are bounded observations, not a worst-case latency promise.

Six actual native mouse/touch review/playback/load/continued-state flows pass at1280×720 and900×600 using RX6650XT, pinned Godot4.7.2 Compatibility/OpenGL. Ended review cannot overwrite the saved unrevealed colony. Playback/scrubbing remains detached. Human feel, physical touchscreen and clean-machine acceptance remain separate. Packaged evidence follows publication.

[Published Windows package evidence](package/README.md).
