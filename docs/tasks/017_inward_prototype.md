# 017 — INWARD prototype

Status: roadmap; expand against the actual code before implementation.

## Goal

Expose the colony's internal functional state.

## Why this exists

Players need to see what exterior trails support.

## Dependencies

[016](016_brood_worker_growth.md) and the preceding task sequence. Read [ARCHITECTURE](../ARCHITECTURE.md), [CODING_RULES](../CODING_RULES.md), and relevant [DATA_MODEL](../DATA_MODEL.md)/[UI_RULES](../UI_RULES.md) contracts.

## Allowed scope

Queen, Nursery, Food Exchange, Entrance at four authored positions; contextual population/brood/resources and OUTWARD/INWARD switching.

## Required behavior

Render an abstract network using approved colony summaries. Show available labor and Food Exchange state; selecting nodes reveals detail. Mode switches change presentation only.

Before coding: Resolve fixed layout and contextual summary/selection behavior using UI_RULES.

## Explicit non-goals

Literal tunnels/geography, automatic layout, permanent overview panel, and chamber development logic. Do not implement future systems not explicitly requested.

## Interfaces to preserve

Abstract functional nodes and thin presentation model; no new authoritative counters.

## Acceptance tests

Manual switching preserves simulation continuity/selection policy; displayed values match approved summaries. Check dark negative space, small screens, and no hidden-world queries.

## Manual verification

Run the relevant prototype/debug scene and inspect the behavior above. On expansion, name exact files, commands, fixtures, and expected results; do not treat this roadmap as a fully specified coding prompt.

## Done when

The expanded card's checks pass, existing behavior remains intact, and the handoff records changed files, tests, limitations, and next task. One logical commit.
