# 200 — C2 soundtrack playtest integration

Status: implementation in progress, 2026-10-17.

Player outcome: the approved C2 suite plays in the default Windows game for a longer session. Completely retire190 music and195 leaf rustle from playback and distribution. Keep independent Music/Information cues controls, return-only cue eligibility, same-build reload baselines and clean shutdown.

Bounded implementation: render a cyclic Air/Warm/Current/Breath/Warm arrangement from199's approved production section mixes, with the same phase-aligned two-bar complementary blends and four-bar rest. Bake those blends into one compressed stereo stream for this first trial: sample-accurate transitions without simulation/frame-clock scheduling or a new adaptive director. Preserve separate production roles for later revision. This is an authored evolving arrangement, not gameplay-reactive music; pause, speed, focus and chamber completion do not change it. Restart/reload begins the cycle softly. No sampled piano, plucks, rustle, paid service, new dependency or simulation rules.

Verification planned: source-to-production waveform comparison, exact cyclic frame count, decoded loop seam/rest/headroom; focused controller/preferences/cue/lifecycle checks; full headless suite after final code; import/Main; native uninterrupted cycle plus wrap, pause/64x, mute/cues, reload and shutdown; compact/standard modal sound UI; committed Windows refresh and unchanged-PCK checks. Preserve unrelated local import changes. No previous-build save work.

Implementation complete: compressed cyclic C2 asset/controller, removed old score/rustle and permanent chamber projection, two-category preferences/compact modal, production/contract updates and superseded tests/probes. Focused332 checks pass; import/Main/native UI/entrance/close pass. Uninterrupted270-second WASAPI capture confirms natural wrap, exact interior rest, peak0.265420, mute clock/cues, reload baseline and shutdown. Full suite and Windows delivery evidence follow in the delivery record. Unrelated retired .import line-ending copies are preserved locally under .godot/card200/retired-imports.
