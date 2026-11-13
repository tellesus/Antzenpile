> **ARCHIVE ONLY — frozen 2026-10-04.** Historical record; not an active plan, current contract or implementation instruction. Use the [current documentation](../../../README.md). Original path: `docs/tasks/031_nursery_development.md`. Historical status and recommendations below apply only to their recorded build.

# 031 — Nursery development

Status: complete 2026-09-30. Expanded from [the post-slice plan](../plans/POST_SLICE_PLAN.md) against the task-030 Nursery and existing Food Exchange build contract.

## Goal

Make internal growth a deliberate investment. Developing the Nursery increases brood space and care capacity from eight to sixteen, so two bounded aggregate cohorts can grow together if the pile can supply labor and food.

## Scope and contracts

- Author provisional development requirements: 18 carbohydrate, 8 protein, 6 water, four available workers, and 90 simulated seconds. Start is a single atomic resource debit and ledger commitment; a failed or duplicate command changes nothing. Completion releases labor and activates the capacity benefit once. The project may start while brood is present, but the extra capacity applies only when complete.
- PileState owns `primitive`/`developing`/`developed` Nursery state and progress. Primitive/Developing retain eight brood/care slots; Developed has sixteen of each. At four care slots per available worker, two workers fully care for one cohort, while four support two. With insufficient care, aggregate cohorts pause rather than die. Keep current food and stage rules.
- Developed Nursery may hold at most two eight-ant cohorts. The player still lays each cohort manually. Give each cohort a unique sequential ID even if maturation order differs; save/restore validates distinct IDs, occupied capacity, development labor and progress. Older version-5 saves without Nursery fields remain loadable as Primitive. No population cap, new worker pool, mortality, or automatic breeding.
- INWARD's selected Nursery context presents state, requirements/progress/benefit, space and care, plus touch-sized Lay and Develop actions through semantic callbacks. The normal view never receives hidden world state.

## Verification and handoff

Test atomic rejected starts, exact payment/labor/time, pause/speed, mid-build save continuation, invalid state rejection, two-cohort development and scarcity, IDs/emergence/ledger conservation, and mouse/touch controls. Run pinned import, full headless suite and Main smoke; record evidence and changed files here before committing.

## Completion evidence and handoff

- NurseryDevelopmentSystem performs one atomic resource payment and ledger labor reservation, completes after 90 simulated seconds, releases labor and activates sixteen brood/care slots. Primitive and Developing retain eight. INWARD shows requirements, progress and the Developed benefit, with a semantic touch-sized Develop action and Lay action when room remains.
- BroodSystem supports two manually started aggregate cohorts only in a Developed Nursery. It computes shared care once per tick, retains the established nutrition/stage rules, and uses sequential IDs through overlapping emergence. Pile restore checks unique IDs, capacity, chamber progress and labor. Version-5 saves without the new progress field still restore as Primitive.
- Tests cover rejected and duplicate builds, exact cost/labor, pause and 4× time, mid-build JSON and disk save/load, malformed saves, care scarcity, two-cohort emergence and turnover, ledger conservation, detached INWARD data, and mouse/touch commands. Pinned Godot `4.7.2.stable.official.ed1daf0bf`: headless import exited 0; full suite passed **3,725 checks, zero failures**; headless Main smoke exited 0; `git diff --check` passed. Sandbox warnings about Godot user logs/settings and root certificates did not affect exit status. No graphical manual interaction or Android-device check was run.
- Changed: Nursery config/data/system, brood config/state/system, pile and colony restore, SimulationController, GameRoot, INWARD view, tests/runner, README, architecture/data/UI/decision/plan docs, and this card. Next: expand card 032 for one physically explained episodic exterior resource. Development costs are provisional pending more systems and playtesting.
