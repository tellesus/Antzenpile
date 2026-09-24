# 022 — Vertical slice integration pass

Status: roadmap; expand against the actual code before implementation.

## Goal

Make the planned 20–30 minute arc coherent and evaluate it.

## Why this exists

The next expansion depends on evidence that the core experience works.

## Dependencies

[021](021_save_load.md) and the preceding task sequence. Read [ARCHITECTURE](../ARCHITECTURE.md), [CODING_RULES](../CODING_RULES.md), and relevant [DATA_MODEL](../DATA_MODEL.md)/[UI_RULES](../UI_RULES.md) contracts.

## Allowed scope

Fix interface inconsistencies, rough pacing, debug leaks, and integration defects; no new major systems.

## Required behavior

Complete the VERTICAL_SLICE arc, starting conditions, meaningful decisions, rain comparison, growth, Food Exchange and music reward. Keep developer truth inaccessible in normal play.

Before coding: Resolve only integration/pacing issues against playtest evidence; record remaining design questions instead of silently expanding scope.

## Explicit non-goals

Rivals, ecology, adaptation, or any other new major system. Do not implement future systems not explicitly requested.

## Interfaces to preserve

All locked decisions; pause feature expansion after this card and evaluate the questions in VERTICAL_SLICE.

## Acceptance tests

Run full headless suite/save continuation and a timed Windows playthrough. Check 60 FPS desktop target with hardware/workload recorded, bounded object counts, mobile-safe input/effects, debug guards and reduced-bloom legibility.

## Manual verification

Run the relevant prototype/debug scene and inspect the behavior above. On expansion, name exact files, commands, fixtures, and expected results; do not treat this roadmap as a fully specified coding prompt.

## Done when

The expanded card's checks pass, existing behavior remains intact, and the handoff records changed files, tests, limitations, and next task. One logical commit.
