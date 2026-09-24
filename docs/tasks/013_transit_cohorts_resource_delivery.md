# 013 — Transit cohorts and resource delivery

Status: roadmap; expand against the actual code before implementation.

## Goal

Close the first economic loop through aggregate travel and delayed delivery.

## Why this exists

Resources should arrive because committed workers actually return.

## Dependencies

[012](012_trail_creation_worker_allocation.md) and the preceding task sequence. Read [ARCHITECTURE](../ARCHITECTURE.md), [CODING_RULES](../CODING_RULES.md), and relevant [DATA_MODEL](../DATA_MODEL.md)/[UI_RULES](../UI_RULES.md) contracts.

## Allowed scope

Bucketed outbound/inbound TransitCohorts, travel delay, collection, pile resource storage/deposit, and recall.

## Required behavior

Depart → travel → collect/deplete node → return → deposit → next cycle. Recall blocks new cycles and waits for in-flight workers; cohort counts are subsets of route commitments. Bound cohort growth.

Before coding: Resolve travel/carry rates, collection contention and depleted-node behavior, bucket interval, and resource-storage defaults.

## Explicit non-goals

Individual foragers, pheromone, rain, brood, and visual ants. Do not implement future systems not explicitly requested.

## Interfaces to preserve

Resource conservation, ledger conservation, and separate route/segment ownership.

## Acceptance tests

No early delivery; one collection/deposit per cycle; no negative/duplicated resources. Recall takes travel time and restores the ledger. Compare equal simulated durations at all speeds.

## Manual verification

Run the relevant prototype/debug scene and inspect the behavior above. On expansion, name exact files, commands, fixtures, and expected results; do not treat this roadmap as a fully specified coding prompt.

## Done when

The expanded card's checks pass, existing behavior remains intact, and the handoff records changed files, tests, limitations, and next task. One logical commit.
