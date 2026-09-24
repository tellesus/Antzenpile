# 021 — Save and load

Status: roadmap; expand against the actual code before implementation.

## Goal

Persist and resume the complete implemented slice.

## Why this exists

Interrupted sessions must resume without changing future simulation outcomes.

## Dependencies

[020](020_rain.md) and the preceding task sequence. Read [ARCHITECTURE](../ARCHITECTURE.md), [CODING_RULES](../CODING_RULES.md), and relevant [DATA_MODEL](../DATA_MODEL.md)/[UI_RULES](../UI_RULES.md) contracts.

## Allowed scope

Versioned explicit save/load of world, pile/ledger, brood, knowledge, scouts, routes/segments/cohorts, chamber state, rain, clock and RNG.

## Required behavior

Store seed/scenario, current RNG state, simulation time/remainders and pending events. Preserve carried versus delivered observations, payloads, and worker ownership. Rebuild presentation/audio from loaded semantic state; validate before replacing the live run.

Before coding: Resolve version/error/atomic-write policy, ID validation, save path, and user controls. Preserve integer RNG state losslessly.

## Explicit non-goals

Replay, cloud saves, broad migration framework, and serialization of view nodes. Do not implement future systems not explicitly requested.

## Interfaces to preserve

Explicit dictionaries/IDs, immutable definitions, all authoritative pending work, and headless compatibility.

## Acceptance tests

Save then continue 100 ticks versus reload then continue 100 ticks: authoritative state matches. Include scout observations, in-flight payloads, chamber progress/rain, invalid save rejection and worker conservation.

## Manual verification

Run the relevant prototype/debug scene and inspect the behavior above. On expansion, name exact files, commands, fixtures, and expected results; do not treat this roadmap as a fully specified coding prompt.

## Done when

The expanded card's checks pass, existing behavior remains intact, and the handoff records changed files, tests, limitations, and next task. One logical commit.
