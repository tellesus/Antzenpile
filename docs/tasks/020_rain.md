# 020 — Rain

Status: roadmap; expand against the actual code before implementation.

## Goal

Demonstrate exposure-dependent chemical disruption and remembered recovery.

## Why this exists

Rain proves that routes have differing physical vulnerability.

## Dependencies

[019](019_music_stem_state.md) and the preceding task sequence. Read [ARCHITECTURE](../ARCHITECTURE.md), [CODING_RULES](../CODING_RULES.md), and relevant [DATA_MODEL](../DATA_MODEL.md)/[UI_RULES](../UI_RULES.md) contracts.

## Allowed scope

One rain event, segment exposure, increased pheromone loss, largely preserved familiarity and sensory/debug feedback.

## Required behavior

After exposed and sheltered trails exist, trigger the slice complication. Apply stronger chemical loss to exposed segments while familiarity still contributes to recovery.

Before coding: Resolve trigger/timing/duration/intensity and exposure formula; specify how interference reaches player perception.

## Explicit non-goals

Full weather, floods, seasons, ecology, and global arbitrary trail deletion. Do not implement future systems not explicitly requested.

## Interfaces to preserve

Distinct chemistry/memory fields and knowledge/perception boundary; fixed simulated time.

## Acceptance tests

Compare otherwise identical exposure-1 and exposure-0 segments under rain; exposed loses more pheromone while familiarity largely survives. Verify post-rain recovery and player legibility.

## Manual verification

Run the relevant prototype/debug scene and inspect the behavior above. On expansion, name exact files, commands, fixtures, and expected results; do not treat this roadmap as a fully specified coding prompt.

## Done when

The expanded card's checks pass, existing behavior remains intact, and the handoff records changed files, tests, limitations, and next task. One logical commit.
