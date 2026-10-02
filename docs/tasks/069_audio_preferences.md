# 069 — Independent audio preferences

Status: complete. Depends on 068. Original Part 7 §§132–133: music can be lowered without losing information cues; visual equivalents preserve muted play.

Outcome: a compact Sound panel in either view offers independent Music and Information Cue levels (off/25/50/75/100%). Choices are local player preferences, persist separately from a colony save and survive loading/switching views. Do not create an unused ambient category before ambient sound exists. No gameplay pause/state/RNG change, hidden truth, new alarms or lost audio phase. Modal input blocks colony commands while sound controls are open; Escape closes; touch targets at least 44 pixels. Keep existing Save/Load and context layouts intact.

Verify: independent music/cue gain, bounded values/invalid atomicity, preference-file round trip and malformed recovery, load independence, mouse/touch/modal interaction, state/phase unchanged, standard/compact graphical probe, import/Main and final suite. Handoff: use the same preference pattern for ambient audio when implemented; current stems remain a composition proof.

Evidence: focused audio/art/input suites 103/0; final full suite 5,047/0; import/Main passed. Windows graphical probe checked both modes at 1280x720/900x600: touch opening, modal blocking, saved preferences, music off with cues full, continuing playback and equal run snapshots. Compact INWARD panel inspected. Corrupt preference values reject atomically; files tested under ignored local cache. User-directory persistence uses the same ConfigFile path during normal launches; sandbox probes used a cache path. Host permissions/certificate warnings only; Android/human listening unverified.

Changed groups: player-only AudioPreferences, shared modal Sound overlay and input blocking, independent music/cue gains; behavior and graphical probes, UI/architecture/README/roadmap. Handoff: preferences stay outside RunState, off is an inaudible -80 dB mix without stopping loop phase. Future ambient audio should add its own volume only when implemented.
