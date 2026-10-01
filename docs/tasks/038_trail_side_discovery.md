# 038 — Automatic trail-side discovery

Status: complete 2026-09-30. The player chose automatic detours with a bounded chance.

## Goal

Let an established trail occasionally notice an unfamiliar nearby resource and send one of its own workers to check it, then rejoin the same traffic. This is physical discovery, not a new player command or an omniscient route scanner.

## Implementation contract

- Only an outbound aggregate TransitCohort may try one detour. At a simulated point along its captured segment, sense an active resource within the authored 4 m scout chemical radius whose ID is not yet in colony KnowledgeBase. Check candidates in stable ID order. Do not expose the source or its location to presentation. Roll the run-owned RNG once for the first eligible encounter per cohort, at provisional 50% chance; a failed roll marks that cohort attempted. If the detailed-scout cap of eight is full, defer the attempt without a roll. Permit at most one unresolved detour report per route/source at a time and at most one detour per cohort.
- A successful detour takes one worker **from that cohort**; no new ledger allocation or cargo appears. The remaining cohort waits at the encounter point while that worker follows a bounded terrain-aware path toward its private chemical estimate, samples along the path and returns to the encounter point. Maximum outward path is 12 grid steps. Keep travel deterministic in fixed ticks and preserve the route's existing cohort/ledger worker count. A blocked step waits and retries. Recall, depletion and rain do not erase a worker or private evidence.
- Reuse scout sensing rules for a private Observation with a unique `scout_N` identity. The detour starts from a sampled cue and follows only its estimated position, never the hidden node coordinate as a navigation target. The report stays with its cohort after rejoining and enters the normal delivered-evidence inbox **only when that cohort reaches home**. A mere cue may produce uncertain knowledge; no success is promised. The origin resource collection and route return remain aggregate.
- Add optional detour/attempt/report fields to TransitCohort's version-5 snapshot. Validate path, position, source/evidence identity, bounded steps, phase, unique IDs and global scout cap on atomic restore. Old saves default to no detour. Provide only a detached count of currently checking workers in selected route context and the shared scout count; no physical detour location or world node leaks.

## Verification

Use an authored route whose segment passes near unfamiliar picnic protein. Test an eligible near cue, no cue beyond 4 m, chance failure, cap deferral, one pending report per route/source, private evidence until home, eventual rejoin and worker conservation, recall during detour, deterministic seed/speed and exact mid-detour save continuation. Reject malformed detour snapshots atomically and load an old cohort record without optional fields. Run pinned import, full headless suite, Main smoke and graphical selected-context check at 900×600; update architecture/data/UI/decisions/README and this card; make a small logical commit.

## Completion evidence and handoff

- Outbound cohorts test a physically nearby unknown cue once, with a seeded 50% chance and no roll while all eight detailed-scout slots are occupied. A successful one-worker detour follows the private sensory estimate on a terrain-aware path, returns to the waiting cohort, and carries its report home. The route's worker count, cargo flow and ledger commitment remain conserved. No physical side-source information reaches OUTWARD before the report arrives.
- The new headless suite covers authored picnic appearance beside a carbohydrate trail, near/far cues, success/failure, shared cap, one unresolved source report, blocked path recovery, rain, recall, private evidence, mid-detour and mid-return save continuation, malformed path/evidence/identity rejection, older cohort defaults and 1×/4× equivalence.
- Pinned Godot `4.7.2.stable.official.ed1daf0bf`: import exited 0, full headless suite passed **4,006 checks with zero failures**, Main headless smoke exited 0, graphical selected-route probe exited 0 at 900×600, and `git diff --check` passed. The visual inspection found **1 checking** readable in the context and scout count, with no map or physical detour point. Sandbox log/settings and root-certificate diagnostics did not change exit status. Android-device and physical touch tests were not run.
- Changed: trail config/cohort/network/system and new typed detour state; run/scout cap and save validation; detached OUTWARD route summary/context; deterministic suite and graphical probe; architecture/data/UI/decision/plan/README docs. Next: expand card 039 into one biologically costly Adaptation Web choice, as requested by the player.
