# 033 — Evidence of recurrence

Status: complete 2026-09-30. Expanded from [the post-slice plan](../POST_SLICE_PLAN.md) against task-032 temporary protein and existing return-only knowledge.

## Goal

Let the colony notice that a known source was found, found empty, then found again. Give the player a deliberate scout investigation of a remembered source while ordinary scouts continue seeking new sources.

## Scope and contracts

- KnowledgeBase records bounded, source-specific outcomes only when a scout delivers a report, an intentional investigation returns empty, or a foraging cohort arrives home loaded/empty. Consecutive identical outcomes coalesce. A tentative recurrence hint requires an available → unavailable → available sequence; derive the rough gap between positive reports, never from the authored ecology schedule. Keep uncertainty visible and avoid a guaranteed next-spawn prediction.
- Add an Investigate command for a selected Known Node. It targets only its stored estimated position, commits one scout through the existing ledger/cap, and returns after sampling at that estimate. Other sources may be observed en route but do not divert or end the assignment. Default dispatch remains the existing new-source frontier search. Store the scout's intent in its snapshot, optional for older version-5 saves.
- OUTWARD gets only detached timing language and a touch-sized Investigate action in selected context. It receives no world node, live quantity, exact event phase or schedule. A failed command is atomic. Save/reload continues the scout and bounded evidence log exactly.

## Verification and handoff

Test return-only evidence, false/early recurrence prevention, positive–empty–positive hint, source isolation, known-source investigation with empty and present source, cap/ledger behavior, older-save defaults and malformed evidence rejection, pause/speed and save continuation, detached UI data and mouse/touch. Run pinned import, full headless suite, Main smoke and diff check. Record evidence and files before committing.

## Completion evidence and handoff

- KnowledgeBase now coalesces at most sixteen alternating positive/empty outcomes per known source. Scout reports and trail returns enter only at home. A positive–empty–positive sequence yields an approximate gap with an explicit uncertain label, derived from observed return times rather than the authored ecology schedule. Older version-5 snapshots without this log load with empty history.
- A selected OUTWARD trace offers Investigate Source. ScoutSystem validates the Known Node, reserves one ledger worker, travels toward its stored estimate and returns with a normal proximity report or an empty outcome. The separate intent field persists midflight and defaults to empty for older saves. Default scouts retain their new-source search behavior. The view receives a detached hint and calls a semantic command.
- Tests cover first/private evidence, positive–empty–positive inference across the temporary source's recurrence, isolation from another source, empty and successful investigations, unknown-command atomicity, worker conservation, pause/4×, exact midflight reload, older-save defaults, malformed history rejection, bounded history, and touch/mouse command paths. Existing ecology tests now compare the historical report separately from the new outcome log.
- Pinned Godot `4.7.2.stable.official.ed1daf0bf`: headless import exited 0; full suite passed **3,788 checks, zero failures**; headless Main smoke exited 0; `git diff --check` passed. Sandbox user-log/settings and root-certificate diagnostics did not affect exit status. No graphical manual interaction or Android-device check was run.
- Changed: KnowledgeBase, ScoutAgent/ScoutSystem, TrailSystem, RunState/SimulationController, GameRoot/OUTWARD, test runner and ecology/recurrence tests, README, architecture/data/UI/decision/plan docs, and this card. Next: evaluate whether actual episodic intake demonstrates a storage/throughput constraint before expanding conditional card 034; otherwise record the skip and proceed to recurring weather card 035.
