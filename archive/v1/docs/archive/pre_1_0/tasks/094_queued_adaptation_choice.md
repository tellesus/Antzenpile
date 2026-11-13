> **ARCHIVE ONLY — frozen 2026-10-04.** Historical record; not an active plan, current contract or implementation instruction. Use the [current documentation](../../../README.md). Original path: `docs/tasks/094_queued_adaptation_choice.md`. Historical status and recommendations below apply only to their recorded build.

# 094 — Queue the next adaptation brood

Status: complete (2026-10-03), authorized player feedback after 093.

Outcome: selecting a trait queues one changeable choice for the next brood, including when Nursery is full. Selecting another replaces that choice; there is no purchase list. On actual laying the cohort's trait locks, the queue clears and a compatible follow-up trait may be queued. Make queued, waiting, locked and inherited states obvious.

Scope: saved pile queue, semantic selection/cancellation, fixed-tick funded laying and explicit next-brood priority over manual/automatic ordinary laying. Preserve revealed candidates, exclusive inherited branches, one active paid trial, existing costs/nurses/capacity, inherited cohort capture and expression on emergence. No new genetics axis or balance change. A queued trial requests automatic laying even with ordinary brood set to Manual; pausing freezes laying and permits edits.

Verify: full-Nursery replacement without spending; resource/nurse waiting; exact one-time payment/locking; follow-up while another trial grows; priority with Grow/manual and pause; loss/emergence; legacy default and malformed-save atomicity; exact saved continuation. Mouse/touch inspection vs queue action, clear queued/laid copy, both desktop sizes, isolated rendering; import/Main and final full headless suite.

Completed: one serialized editable trait, atomic replacement/cancellation and automatic paid laying at the next eligible fixed tick. Costs/nurses are committed only on laying. Queue clears into an immutable trial cohort; independent compatible follow-ups wait behind that trial. Ordinary Auto Brood and Manual Lay cannot skip the queued choice. Existing candidate/exclusive-axis/capacity/food/ledger/expression rules remain intact; older saves default empty.

Evidence: focused **350 checks / zero failures** before the final additional save/speed assertions; final full suite **6060 checks / zero failures**. Final import and 90-frame Main smoke passed. Actual Windows/Godot 4.7.2 Compatibility probe passed at 1280×720 and 900×600: mouse/touch inspection, queue, replace, automatic locking, follow-up/overview cancellation and rendering snapshot isolation. Reviewed all affected states with distinct queued/locked copy, readable panels and unchanged touch targets. Only existing log/editor-settings/certificate permission warnings; Android remains untested.

Visuals: [full Nursery queue](../../../evidence/card094_queued_space_1280.png), [laid/locked brood](../../../evidence/card094_locked_1280.png), [compact follow-up queue](../../../evidence/card094_followup_900.png). Reproduce with `tests/probe_adaptation_queue.gd`; screenshots otherwise go under ignored `.godot/`.

Changed groups: pile/trait validation/paid trial/Brood scheduling; controller and detached summary/semantic UI action; web/Queen wording/markers; new queue behavior tests and graphical probe, adjusted existing UI contract assertions, architecture/data/UI/decision/roadmap docs. Handoff: restart the game; inspect a trait and use Queue for Next Brood. Select another leaf and use Replace Queued Choice before laying, or cancel. A queue is an explicit laying request even when ordinary Auto Brood is off. Existing inherited forks remain exclusive; no genetic reselection system was added. Resume the graphics roadmap only when continuing broader development.
