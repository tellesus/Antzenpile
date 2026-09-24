# 019 — Music stem state

Status: roadmap; expand against the actual code before implementation.

## Goal

Add a synchronized music layer when Food Exchange develops.

## Why this exists

The slice needs a perceptible musical reward for growth.

## Dependencies

[018](018_food_exchange_development.md) and the preceding task sequence. Read [ARCHITECTURE](../ARCHITECTURE.md), [CODING_RULES](../CODING_RULES.md), and relevant [DATA_MODEL](../DATA_MODEL.md)/[UI_RULES](../UI_RULES.md) contracts.

## Allowed scope

MusicState development_level, base loop, synchronized secondary loop, and smooth stem fade using placeholder audio.

## Required behavior

Audio consumes semantic development state. Align compatible loop timing; completion brings in the second stem without restarting gameplay. Headless mode remains audio-free.

Before coding: Resolve loop length/synchronization, fade duration, pause/speed and reload behavior; use authorized or original placeholder assets.

## Explicit non-goals

Finished soundtrack, crisis/stability systems, and arbitrary audio queries into simulation. Do not implement future systems not explicitly requested.

## Interfaces to preserve

Semantic MusicState and one-way simulation-to-audio dependency; audio time never advances simulation.

## Acceptance tests

Listen for stable synchronization and smooth entry on completion; repeated events do not duplicate players. Verify all speeds and silent/headless simulation; record checks that require real audio output.

## Manual verification

Run the relevant prototype/debug scene and inspect the behavior above. On expansion, name exact files, commands, fixtures, and expected results; do not treat this roadmap as a fully specified coding prompt.

## Done when

The expanded card's checks pass, existing behavior remains intact, and the handoff records changed files, tests, limitations, and next task. One logical commit.
