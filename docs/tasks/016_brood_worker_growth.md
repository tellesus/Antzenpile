# 016 — Brood and worker growth

Status: roadmap; expand against the actual code before implementation.

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

Before coding: Resolve stage timings, resource costs/care rules, shortage behavior, and starting cohort (A05 is a fixture default).

## Explicit non-goals

Genetics, lineage, adaptation, and individual brood Nodes. Do not implement future systems not explicitly requested.

## Interfaces to preserve

Brood is not part of living-worker totals until emergence; all births enter through WorkerLedger.

## Acceptance tests

Resource-supported brood matures; insufficient resources follow the specified rule. No duplicate emergence across repeated updates; workers reconcile. Inspect growth headlessly/debug.

## Manual verification

Run the relevant prototype/debug scene and inspect the behavior above. On expansion, name exact files, commands, fixtures, and expected results; do not treat this roadmap as a fully specified coding prompt.

## Done when

The expanded card's checks pass, existing behavior remains intact, and the handoff records changed files, tests, limitations, and next task. One logical commit.
