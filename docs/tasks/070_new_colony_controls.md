# 070 — Start a fresh colony in game

Status: complete. Depends on 069; original run-seed/reproducibility design. Repeat playtests currently require relaunching or command-driven fixtures.

Outcome: Colony in either view opens an explicit restart panel. Repeat the current seed or choose a fresh seed, with a clear warning that unsaved progress is replaced and the saved slot stays intact. This uses the same authored backyard; seed changes stochastic behavior, not map geometry. Cancel/Escape closes without mutation. No automatic restart or game-over model. Preserve audio preferences and the existing controller object so bound commands still target its new run; reconnect fixed-clock systems once, clear transient view/debug references and start in OUTWARD. Separate seed generation in presentation from run-owned gameplay randomness.

Verify: same-seed founding/replay equality, distinct seed, invalid-operation atomicity, old clock disconnection, all run-scoped systems replaced, no residual knowledge/jobs/pressure, saved-slot/preferences preserved, command callbacks after reset, modal exclusivity/input, mouse/touch and normal/compact graphical probe; import/Main and final suite. Handoff: fresh playtests precede any authored map variation; do not imply this changes terrain or introduces procedural maps.

Evidence: focused restart/save/run/preferences checks 263/0; final suite 5,064/0; import/Main passed. Windows graphical probe passed both modes at 1280x720/900x600, exclusive Sound/Colony modals, cancel without mutation, repeat reset, preserved levels and saved slot, and existing Scout callback targeting the fresh run. Compact OUTWARD panel inspected. Signed integer seeds remain supported; malformed non-integers reject atomically. Host permissions/certificate warnings only; no Android/human test.

Changed groups: controller new-run attachment; shared Colony restart overlay and modal exclusivity; common loaded-view refresh for current controller references and transient input/feedback/debug selection; replay/save/UI probes and contracts. Handoff: current geometry remains the backyard. Next bounded authored scenario variation can use the same reset/seed/save pathway.
