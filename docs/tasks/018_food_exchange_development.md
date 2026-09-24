# 018 — Food Exchange development

Status: roadmap; expand against the actual code before implementation.

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

Before coding: Choose a simple benefit (food-use efficiency or brood throughput), then specify costs, duration, labor/shortage/cancel policy, and completion conditions.

## Explicit non-goals

Other chambers, universal building framework, and finished music. Do not implement future systems not explicitly requested.

## Interfaces to preserve

Ledger and resource accounting; semantic chamber state is the source for later audio.

## Acceptance tests

Requirements prevent premature start/completion; labor stays conserved; completion applies benefit/event once. Manually see progress and completed state in INWARD.

## Manual verification

Run the relevant prototype/debug scene and inspect the behavior above. On expansion, name exact files, commands, fixtures, and expected results; do not treat this roadmap as a fully specified coding prompt.

## Done when

The expanded card's checks pass, existing behavior remains intact, and the handoff records changed files, tests, limitations, and next task. One logical commit.
