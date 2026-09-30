# 016 — Brood and worker growth

Status: complete (2026-09-30).

## Goal

Close food → brood → workers.

## Why this exists

Resource success should make the colony observably grow.

## Dependencies

[015](015_route_familiarity.md) and the preceding task sequence. Read [ARCHITECTURE](../ARCHITECTURE.md), [CODING_RULES](../CODING_RULES.md), and relevant [DATA_MODEL](../DATA_MODEL.md)/[UI_RULES](../UI_RULES.md) contracts.

## Allowed scope

BroodCohort stages/count/progress/nutrition/care, resource consumption, emergence, and small starting cohort.

## Required behavior

Advance cohort development on simulated time with resource/care constraints. Maturation removes immature count and adds living workers through the ledger exactly once. Keep cohorts aggregate.

Resolved contract: one authored starting cohort of eight (`brood_1`) enters as eggs. Configured stages last 180 simulated seconds egg, 120 larva, 60 pupa. Each fixed larval tick consumes per immature ant per second 0.015 carbohydrate, 0.0045 protein and 0.0075 water; all three must be available before any is deducted or progress advances. Egg/pupa need no direct food. At least two currently available workers are required for care; this is a capacity gate, not a transfer or double-counted work assignment. Insufficient care or food pauses stage progress without brood loss or partial consumption. The cohort records stage, count, stage progress, last-tick nutrition and care. Completion removes it, adds eight available living workers with an explicit ledger reason and records one emergence total. No new egg production or brood mortality is introduced. These are tunable slice defaults, not biological rates.

Pile snapshots serialize the cohort and emerged total. The run snapshot version advances to 2 for this required schema; earlier in-memory version-1 snapshots reject until the later save/load card defines migration. Normal UI will receive detached brood totals/state for task 017. F3 may inspect exact stage, progress and stores now.

## Explicit non-goals

Genetics, lineage, adaptation, and individual brood Nodes. Do not implement future systems not explicitly requested.

## Interfaces to preserve

Brood is not part of living-worker totals until emergence; all births enter through WorkerLedger.

## Acceptance tests

Resource-supported brood matures; insufficient resources follow the specified rule. No duplicate emergence across repeated updates; workers reconcile. Inspect growth headlessly/debug.

## Manual verification

Run pinned Godot 4.7.2 import, headless suite, and Main smoke. `tests/test_brood.gd` must verify supported maturation, carbohydrate shortage/stall and later resumption, low-care stall, resource accounting, one-time ledger emergence, JSON continuation and invalid snapshot rejection. F3 should display brood count/stage/progress; INWARD presentation waits for 017.

## Done when

The expanded card's checks pass, existing behavior remains intact, and the handoff records changed files, tests, limitations, and next task. One logical commit.

## Completion evidence and handoff

- Added authored brood configuration, aggregate BroodCohort and BroodSystem, PileState food/brood serialization, version-2 RunState snapshots, F3 brood detail and `tests/test_brood.gd`. Updated README and architecture/data/decision contracts. No player-facing brood UI is introduced before 017.
- Pinned Godot 4.7.2 import and headless suite passed: 3,444 checks, 0 failures. Tests cover supported maturation, starvation and later recovery, low available-worker care, exact three-resource debits, ledger emergence once, mid-larva JSON continuation and atomic invalid restores. Main smoke/diff check are part of completion verification. Task 018 refined debit precision from millesimal to five-decimal units for its food-efficiency multiplier.
- F3 is the current manual inspection path for stage, progress and stores; no renderer-side brood visualization is added here. The care gate is capacity, not a reserved internal worker assignment. The new required snapshot schema rejects older version-1 dictionaries until migration is specified in 021.
- Next: task 017, abstract INWARD prototype consuming detached colony summaries.
