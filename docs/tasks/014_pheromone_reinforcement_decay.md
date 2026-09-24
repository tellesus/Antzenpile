# 014 — Pheromone reinforcement and decay

Status: roadmap; expand against the actual code before implementation.

## Goal

Make chemical trails strengthen through traffic and fade with disuse.

## Why this exists

Trails are living infrastructure rather than permanent UI links.

## Dependencies

[013](013_transit_cohorts_resource_delivery.md) and the preceding task sequence. Read [ARCHITECTURE](../ARCHITECTURE.md), [CODING_RULES](../CODING_RULES.md), and relevant [DATA_MODEL](../DATA_MODEL.md)/[UI_RULES](../UI_RULES.md) contracts.

## Allowed scope

Segment pheromone, successful-traffic reinforcement, natural fixed-time decay, and trail visual response.

## Required behavior

Clamp pheromone to [0,1]. Derive coherent versus gapped/wispy rendering through approved presentation data. Use thin cores/envelopes and bounded effects.

Before coding: Resolve tunable rates, successful-traffic event, and visual strength mapping.

## Explicit non-goals

Rain, familiarity behavior, custom renderer, and final art. Do not implement future systems not explicitly requested.

## Interfaces to preserve

Segment-owned chemistry, aggregate traffic, and UI_RULES; visual state cannot drive simulation.

## Acceptance tests

Traffic reinforces; no traffic decays; values stay bounded and time-scale results agree. Manually read strong versus weakening trails with bloom reduced.

## Manual verification

Run the relevant prototype/debug scene and inspect the behavior above. On expansion, name exact files, commands, fixtures, and expected results; do not treat this roadmap as a fully specified coding prompt.

## Done when

The expanded card's checks pass, existing behavior remains intact, and the handoff records changed files, tests, limitations, and next task. One logical commit.
