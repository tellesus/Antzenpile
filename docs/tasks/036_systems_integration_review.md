# 036 — Systems integration review

Status: automated review complete 2026-09-30; current-build human playtest pending. Expanded from [the post-slice plan](../POST_SLICE_PLAN.md) against cards 029–035.

## Goal

Exercise the added growth, labor, ecology, evidence and weather systems together before making another balance or expansion decision. The original 20–30 minute session target remains tabled.

## Scope and evidence

- Run one deterministic, command-driven backyard scenario using ordinary player commands only: scout and invest carbohydrate/protein/water routes, develop Food Exchange and Nursery, overlap two aggregate brood cohorts, encounter temporary picnic protein, observe its disappearance and later return, and work through a second rain front. Record milestone times, stores, worker commitments, stalls and missed signals. Keep source truth out of normal presentation.
- Verify a complex mid-run save continues exactly, ledger conservation and resource nonnegativity hold, and both normal modes remain detached from hidden state. Run the full headless suite. Recheck current Windows graphical workload and inspect captures for the longer selected-context layout and negative-space rules if the graphical probe is available. Record precise platform/renderer evidence and limits; do not infer Android performance.
- Do not tune rates to a target session length. If the run reveals a concrete design conflict, isolate it in evaluation notes rather than silently changing a locked system. Human interest, timing and touch comfort require player playtest evidence; record what remains unverified.

## Verification and handoff

Record results in `docs/POST_SLICE_EVALUATION.md`, update README/plan/card status, run pinned import, headless suite, Main smoke, and `git diff --check`, then make a logical commit. After this review, propose the next bounded design choice from the original GDD rather than scaffolding later systems wholesale.

## Completion evidence and handoff

- The [post-slice evaluation](../POST_SLICE_EVALUATION.md) records one ordinary-command run through Food Exchange, Nursery development, two overlapping brood cohorts, five invested routes, a temporary picnic source, explicit recall of its depleted route, source recurrence learned on return, and two rain fronts. At 1064.25 simulated seconds, 16 brood had emerged into 56 conserved workers, 36 were available, and final stores were 156.09 carbohydrate, 110.52 protein and 95.2 water. Complex save continuation, detached normal-view data and nonnegative stores passed. This is simulated time only; no session-duration judgment was made.
- Windows Compatibility/OpenGL graphical probes on Ryzen 7 7800X3D / Radeon RX 6650 XT produced three committed 1280×720 / 900×600 captures. Review found the selected-context Investigate action overlapping the bottom controls at 900×600; the action and evidence line now fit inside the card, with a compact hit-rectangle regression check. The selected-view probe measured 0.39 ms p95 uncapped at 1280×720 and 0.38 ms at 900×600, at most eight scene nodes and 47 draw calls. A separate VSync-on run paced near 33 FPS on this host; it does not establish a device-performance limit.
- Pinned Godot `4.7.2.stable.official.ed1daf0bf`: headless import exited 0, full suite passed **3,850 checks, zero failures**, graphical probes exited 0, Main headless smoke exited 0, and `git diff --check` passed. Sandbox user-log/settings and root-certificate diagnostics did not affect exit status. No Android-device, physical touch, music-listening or current-build human playtest was run.
- Changed: combined integration suite/runner, selected-context compact layout/test, reproducible graphical probe, three visual evidence captures, README/vertical-slice/plan docs, evaluation and this card. Next: obtain player playtest evidence before balance or a storage cap; scope a single biologically costly Adaptation Web choice from the original GDD if continuing implementation.
