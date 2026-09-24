# 011 — OUTWARD prototype

Status: roadmap; expand against the actual code before implementation.

## Goal

Make the first useful player-facing sensory view.

## Why this exists

This milestone tests whether colony information is understandable.

## Dependencies

[010](010_perceived_signals.md) and the preceding task sequence. Read [ARCHITECTURE](../ARCHITECTURE.md), [CODING_RULES](../CODING_RULES.md), and relevant [DATA_MODEL](../DATA_MODEL.md)/[UI_RULES](../UI_RULES.md) contracts.

## Allowed scope

Near-black field, rotation/bearing, Home Anchor, simple signals, selection/context card; basic scout/labor/time controls.

## Required behavior

Render only PerceivedSignals, using 2D bearing-to-horizontal translation. Share mouse/touch drag logic; issue semantic scout commands. Preserve negative space and a small persistent HUD.

Before coding: Resolve field of view, wrap/culling, hit targets, input conflicts, and minimal panel layout.

## Explicit non-goals

Literal physical map/minimap, 3D camera, finished art, and trail allocation before 012. Do not implement future systems not explicitly requested.

## Interfaces to preserve

UI_RULES, knowledge-only output, and simulation-owned commands; no required hover/right-click.

## Acceptance tests

Test wrap seam and projection; manually rotate/select/launch scouts and use time controls. Hidden nodes stay invisible. Check small landscape layout and reduced effects.

## Manual verification

Run the relevant prototype/debug scene and inspect the behavior above. On expansion, name exact files, commands, fixtures, and expected results; do not treat this roadmap as a fully specified coding prompt.

## Done when

The expanded card's checks pass, existing behavior remains intact, and the handoff records changed files, tests, limitations, and next task. One logical commit.
