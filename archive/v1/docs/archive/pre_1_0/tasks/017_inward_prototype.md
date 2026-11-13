> **ARCHIVE ONLY — frozen 2026-10-04.** Historical record; not an active plan, current contract or implementation instruction. Use the [current documentation](../../../README.md). Original path: `docs/tasks/017_inward_prototype.md`. Historical status and recommendations below apply only to their recorded build.

# 017 — INWARD prototype

Status: complete (2026-09-30).

## Goal

Expose the colony's internal functional state.

## Why this exists

Players need to see what exterior trails support.

## Dependencies

[016](016_brood_worker_growth.md) and the preceding task sequence. Read [ARCHITECTURE](../contracts/ARCHITECTURE.md), [CODING_RULES](../../../CODING_RULES.md), and relevant [DATA_MODEL](../contracts/DATA_MODEL.md)/[UI_RULES](../contracts/UI_RULES.md) contracts.

## Allowed scope

Queen, Nursery, Food Exchange, Entrance at four authored positions; contextual population/brood/resources and OUTWARD/INWARD switching.

## Required behavior

Render an abstract network using approved colony summaries. Show available labor and Food Exchange state; selecting nodes reveals detail. Mode switches change presentation only.

Resolved contract: GameRoot owns one OUTWARD and one INWARD Node2D on graphical runs; only the active view processes/redraws/accepts input. A semantic `set_mode` command and the named `toggle_inward` action (Tab) switch them without touching RunState. Touch/mouse buttons expose the same switch. Each view retains its own selected ID while hidden; OUTWARD facing is likewise retained. The F3 truth layer stays above both and blocks mode changes while open.

INWARD receives only detached pile/clock summaries from GameRoot: available/total living workers, queen count, aggregate brood records/emergence, three stores, active scouts and allocated trail labor, and the initial Food Exchange state. PileState adds authoritative `food_exchange_state = primitive` now, but no progress or development logic until 018; the required snapshot schema advances to version 3. Four authored normalized positions occupy the left two-thirds of the screen, leaving a right-side context card. Queen reveals queens/living workers; Nursery reveals brood/stage/care/nutrition; Food Exchange reveals Primitive and stores; Entrance reveals available/scout/trail labor. Lines are functional relationships, not geography. No permanent population overview card or simulated tunnel geometry.

## Explicit non-goals

Literal tunnels/geography, automatic layout, permanent overview panel, and chamber development logic. Do not implement future systems not explicitly requested.

## Interfaces to preserve

Abstract functional nodes and thin presentation model; no new authoritative counters.

## Acceptance tests

Manual switching preserves simulation continuity/selection policy; displayed values match approved summaries. Check dark negative space, small screens, and no hidden-world queries.

## Manual verification

Run pinned Godot 4.7.2 import, headless suite, Main smoke and GUI previews at 1280×720 and 900×600. `tests/test_inward.gd` checks detached summaries, selection through shared mouse/touch paths, mode switching/selection persistence, continuity and absence of hidden-world values. Inspect four-node negative space and readable context/control placement in Compatibility.

## Done when

The expanded card's checks pass, existing behavior remains intact, and the handoff records changed files, tests, limitations, and next task. One logical commit.

## Completion evidence and handoff

- Added `src/presentation/inward/inward_view.gd`, GameRoot mode ownership/detached summary, OUTWARD switch button, Primitive Food Exchange state, snapshot version 3 and `tests/test_inward.gd`. Updated README and architecture/data/UI/decision docs. No chamber development logic or hidden-world projection was introduced.
- Pinned Godot 4.7.2 import and headless suite passed: 3,469 checks, 0 failures. Tests verify detached values, no hidden-world dependency, four-node hit layout, mouse/touch selection, button/Tab switching, per-view selection/facing preservation and simulation continuity. Main smoke and diff check passed.
- Inspected Compatibility screenshots at 1280×720 (Nursery selected) and 900×600 (Food Exchange selected). Four functional nodes, faint connections, selected context and controls remained separate/readable without bloom. These temporary previews were not committed; actual device touch ergonomics remain unverified.
- Next: task 018, a single Primitive → Developed Food Exchange transition.
