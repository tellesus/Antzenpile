# 015 — Route familiarity

Status: roadmap; expand against the actual code before implementation.

## Goal

Preserve slowly learned route memory separately from chemistry.

## Why this exists

Chemical washout must not erase all learned reliability.

## Dependencies

[014](014_pheromone_reinforcement_decay.md) and the preceding task sequence. Read [ARCHITECTURE](../ARCHITECTURE.md), [CODING_RULES](../CODING_RULES.md), and relevant [DATA_MODEL](../DATA_MODEL.md)/[UI_RULES](../UI_RULES.md) contracts.

## Allowed scope

Familiarity gain/slow decay, reliability contribution, debug display, and an optional subtle presentation ghost.

## Required behavior

Successful travel raises familiarity more slowly than pheromone; familiarity decays much more slowly and contributes to route reliability without replacing pheromone.

Before coding: Resolve gain/decay and reliability formula, bounds, and ghost visibility rules.

## Explicit non-goals

Rain itself, adaptation, and shared-segment routing. Do not implement future systems not explicitly requested.

## Interfaces to preserve

Distinct segment pheromone/familiarity fields; tests must not conflate memory with active chemicals.

## Acceptance tests

Separate values can diverge; suppress/decay chemistry and verify familiarity persists and influences reliability. Debug inspection shows both; ghost is fainter than an active trail.

## Manual verification

Run the relevant prototype/debug scene and inspect the behavior above. On expansion, name exact files, commands, fixtures, and expected results; do not treat this roadmap as a fully specified coding prompt.

## Done when

The expanded card's checks pass, existing behavior remains intact, and the handoff records changed files, tests, limitations, and next task. One logical commit.
