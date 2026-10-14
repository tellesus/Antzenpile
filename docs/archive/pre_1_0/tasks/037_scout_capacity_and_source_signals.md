> **ARCHIVE ONLY — frozen 2026-10-04.** Historical record; not an active plan, current contract or implementation instruction. Use the [current documentation](../../../README.md). Original path: `docs/tasks/037_scout_capacity_and_source_signals.md`. Historical status and recommendations below apply only to their recorded build.

# 037 — Scout capacity and honest source signals

Status: complete 2026-09-30. Based on player feedback after card 036.

## Goal

Make exploration less bottlenecked and make the OUTWARD view distinguish a source that workers last found empty, without implying ants know a physical renewal time. This card does not rebalance resource income or add trail-side scouts.

## Scope

- Raise the provisional simultaneous scout cap from four to eight in the authored scouting config. Keep one ledger worker per individual scout and the existing capped, deterministic simulation. The cap remains tunable; no population-scaling rule is introduced.
- Derive a reported-empty cue from returned scout/trail outcomes and depleted route reports. Give its OUTWARD trace a muted, broken shape and an explicit EMPTY label, including when it is not selected. A new positive return clears the cue. A hidden refill alone must not clear or create it.
- Replace the numerical recurrence forecast with qualitative language. A positive–empty–positive history may suggest a source has returned before, but no seconds-to-renewal or promised future return appear in normal UI. Preserve return-only knowledge and existing save data.

## Acceptance and handoff

Test eight accepted scouts, atomic ninth rejection, worker conservation and save continuation; verify empty cue before/after hidden renewal and later positive evidence; verify no numerical forecast; inspect OUTWARD at 1280×720 and 900×600 for legibility. Run pinned import, full headless suite, Main smoke and diff check. Update relevant docs and record results here, then commit this bounded task.

## Completion evidence

- The authored cap is eight. All eight use one conserved worker each; the ninth dispatch rejects atomically, and an eight-scout snapshot restores exactly. Existing saves with four or fewer scouts remain valid.
- The last delivered empty outcome or depleted route report mutes and breaks the trace, labels it EMPTY before selection, and keeps the cue through unobserved physical renewal. A later positive report clears it. The recurrence line now says only that the source returned before and timing is unknown.
- Pinned Godot 4.7.2: import exited 0; full headless suite passed **3,860 checks, zero failures**; Main headless smoke exited 0; graphical empty-source probe exited 0 at 1280×720 and 900×600. Captures were inspected: EMPTY text, broken muted trace, selected context and controls remain legible with negative space intact. No Android or physical touch-device test was run. Godot's sandbox user-log/settings and root-certificate diagnostics did not change exit status. `git diff --check` passed.
- Changed: scouting config/default; KnowledgeBase derived hint; OUTWARD trace; scouting, recurrence and integration checks; a reproducible graphical probe; decision/data/UI/plan/evaluation/README docs and cards 036–039. Next: expand automatic trail-side discovery against the current cohort implementation; follow it with a first Adaptation Web choice.
