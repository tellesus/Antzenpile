# 018 — Food Exchange development

Status: complete (2026-09-30).

## Goal

Develop Primitive Food Exchange into Developed Food Exchange.

## Why this exists

Prove that exterior success produces interior development.

## Dependencies

[017](017_inward_prototype.md) and the preceding task sequence. Read [ARCHITECTURE](../ARCHITECTURE.md), [CODING_RULES](../CODING_RULES.md), and relevant [DATA_MODEL](../DATA_MODEL.md)/[UI_RULES](../UI_RULES.md) contracts.

## Allowed scope

One transition with resource requirement, worker commitment, simulated progress, completion, and one mechanical benefit.

## Required behavior

Check requirements through simulation commands; commit/release labor through ledger. Emit chamber_online once and expose development state. Implement the smallest transition, not a generic builder.

Resolved contract: Primitive Food Exchange requires 12 carbohydrate, 4 protein, 4 water and four available workers to begin. Starting is an atomic simulation command: validate all requirements, reserve four workers in an internal `food_exchange:<pile_id>` ledger commitment and debit resources once. The 60 simulated-second build proceeds through fixed ticks with no further food cost. There is no cancellation in this slice; prepaid resources remain spent and committed labor remains held until completion. Completion changes state to Developed, releases/retires the commitment, emits `chamber_online(pile_id)` exactly once, and grants a 0.75 multiplier to all three larval food costs. The benefit applies only to future consumption ticks, not retroactively. Run snapshots carry primitive/developing/developed plus progress, validate commitment/state, and advance to version 4. No generic chamber builder is introduced.

INWARD Food Exchange context shows requirements, one Start control with rejection feedback, progress during development, and the completed benefit. GameRoot supplies detached costs/progress/state; InwardView invokes only the semantic command. F3 shows exact progress and commitment.

## Explicit non-goals

Other chambers, universal building framework, and finished music. Do not implement future systems not explicitly requested.

## Interfaces to preserve

Ledger and resource accounting; semantic chamber state is the source for later audio.

## Acceptance tests

Requirements prevent premature start/completion; labor stays conserved; completion applies benefit/event once. Manually see progress and completed state in INWARD.

## Manual verification

Run pinned Godot 4.7.2 import, full headless suite, Main smoke and INWARD GUI preview at 1280×720 and 900×600. `tests/test_food_exchange.gd` covers insufficient food/labor atomicity, start cost/commitment, fixed-time completion, one event, ledger release, 25% larval cost reduction, JSON continuation and invalid snapshots. Manually inspect Primitive, Developing and Developed context states.

## Done when

The expanded card's checks pass, existing behavior remains intact, and the handoff records changed files, tests, limitations, and next task. One logical commit.

## Completion evidence and handoff

- Added authored `FoodExchangeConfig`, `FoodExchangeSystem`, PileState state/progress validation, SimulationController command/tick integration, BroodSystem 0.75 developed multiplier, detached INWARD requirements/action, F3 progress and `tests/test_food_exchange.gd`. Required run snapshots are version 4. Updated README and architecture/data/UI/decision contracts. No generic builder or music was introduced.
- Pinned Godot 4.7.2 import and full headless suite: 3,490 checks, 0 failures. Tests cover insufficient requirements, exact upfront payment, ledger conservation, fixed-time completion, one `chamber_online` signal, 25% future larval food saving, reload and invalid commitment/progress snapshots. Main smoke and diff check passed.
- Inspected Compatibility previews at 1280×720 for Primitive and Developing context and 900×600 for Developed. Requirements, progress, benefit and controls remained readable without bloom. Temporary previews were not committed; live device touch was not exercised.
- Next: task 019, synchronized base and secondary music stems driven by semantic development state.
