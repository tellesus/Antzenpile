> **ARCHIVE ONLY — frozen 2026-10-04.** Historical record; not an active plan, current contract or implementation instruction. Use the [current documentation](../../../README.md). Original path: `docs/tasks/030_nursery_capacity_and_care.md`. Historical status and recommendations below apply only to their recorded build.

# 030 — Nursery capacity and care

Status: complete 2026-09-30. Expanded from [the post-slice plan](../plans/POST_SLICE_PLAN.md) against the task-029 brood and INWARD implementation.

## Goal

Make the primitive Nursery's brood space and worker-supported care capacity explicit. Preserve the current one-cohort cycle; chamber development and simultaneous cohorts belong to card 031.

## Scope and contracts

- Give each pile a semantic `nursery_state`, initially `primitive`, with authored primitive brood and care capacities of eight. The state is authoritative; capacities derive from immutable brood configuration. Version-5 saves lacking the new field restore as Primitive. Reject invalid states and brood occupancy above capacity without partially changing a run.
- Derive current care capacity from available workers, up to the Nursery's care limit. The existing two-available-worker threshold still supplies full care for one eight-ant cohort; one worker supplies half capacity and progression pauses, matching current behavior. Keep all worker ownership in the existing ledger.
- Gate the Lay 8 Brood command on free Nursery space as well as queen and one-cohort rules. No upfront food payment, automatic laying, mortality, or extra cohort yet.
- Give INWARD a detached summary of occupied/total brood space and current/maximum care capacity. The selected Queen/Nursery context should explain capacity and care without a new overview screen or hidden world data. Mouse and touch retain the same semantic command path.

## Verification and handoff

Test the initial and repeat cohort, limited worker care, occupied space, invalid and older saves, detached UI values, and unchanged maturation/ledger accounting. Run pinned import, full headless suite, and Main smoke. Record evidence and changed files here before a small commit.

## Completion evidence and handoff

- Primitive Nursery state now belongs to PileState. BroodConfig authors eight space/care slots; available workers provide current care capacity. BroodSystem uses that capacity and checks free space before laying. The current one-cohort sequence, nutrition costs, emergence and worker ledger remain intact.
- INWARD Queen/Nursery contexts show space and care from detached summaries and gate the Lay action on free space. A new test covers old and invalid saves, care with zero/one/two available workers, atomic rejected laying, UI detachment, maturation and repeat laying.
- Pinned Godot `4.7.2.stable.official.ed1daf0bf`: headless import exited 0; full suite passed **3,685 checks, zero failures**; headless Main smoke exited 0. Sandbox warnings about Godot user logs/settings and root certificates did not affect exit status. No graphical manual interaction or Android-device check was run.
- Changed: brood config/data/system, PileState, GameRoot, INWARD view, tests/runner, README, architecture/data/UI/decision/plan docs, and this card. Next: expand card 031 to develop the Nursery through resources, labor and time, then support bounded simultaneous aggregate cohorts. Its costs and benefit remain provisional.
