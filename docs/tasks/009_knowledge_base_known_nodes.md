# 009 — KnowledgeBase and Known Nodes

Status: roadmap; expand against the actual code before implementation.

## Goal

Turn delivered evidence into inspectable colony knowledge.

## Why this exists

Knowledge must represent estimates and confidence rather than live world truth.

## Dependencies

[008](008_scout_discovery_observations.md) and the preceding task sequence. Read [ARCHITECTURE](../ARCHITECTURE.md), [CODING_RULES](../CODING_RULES.md), and relevant [DATA_MODEL](../DATA_MODEL.md)/[UI_RULES](../UI_RULES.md) contracts.

## Allowed scope

Observation merging, estimated position, confidence, timestamps, KnownNode IDs and creation.

## Required behavior

Consume delivered observations, merge evidence deterministically, retain uncertainty/age. Add truth-versus-known inspection to debug tools; a later hidden-world change must not silently refresh memory.

Before coding: Resolve merge/conflict rules, confidence bounds/update rules, stale evidence policy, and estimate generation.

## Explicit non-goals

Visual signals, player UI, and omniscient knowledge refresh. Do not implement future systems not explicitly requested.

## Interfaces to preserve

KnowledgeBase ownership and stable source-knowledge IDs; read ARCHITECTURE's knowledge boundary.

## Acceptance tests

Before return, no KnownNode; after return, expected knowledge exists. Repeat/merge evidence without duplicate nodes. Mutate hidden truth afterward and verify memory stays unchanged until new evidence.

## Manual verification

Run the relevant prototype/debug scene and inspect the behavior above. On expansion, name exact files, commands, fixtures, and expected results; do not treat this roadmap as a fully specified coding prompt.

## Done when

The expanded card's checks pass, existing behavior remains intact, and the handoff records changed files, tests, limitations, and next task. One logical commit.
