# 038 — Trail-side discovery (roadmap)

Status: proposed from player feedback; expand against current code after card 037.

Aggregate trail traffic that passes near an unfamiliar physical cue may automatically, with a bounded seeded chance, send one worker on a short investigation and have it rejoin the same traffic. Specify sensory radius, chance/cooldown, cohort-worker accounting, path/return behavior and save state before coding. The route's ledger commitment must remain authoritative; a detour may not duplicate a worker or cargo. Only physically encountered cues can be sampled, and colony knowledge changes only when the worker's evidence ultimately returns home. Preserve the simultaneous detailed-scout cap and aggregate simulation. The player chose automatic rather than per-detour approval.

Acceptance should cover unknown and known cues, no cue outside sensing range, repeated traffic without unbounded detours, depletion/recall/rain during a detour, save continuation, deterministic RNG and no normal-view truth leak. Keep any presentation signal sparse and return-derived.
