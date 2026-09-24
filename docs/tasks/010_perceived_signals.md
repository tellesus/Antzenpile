# 010 — PerceivedSignals

Status: roadmap; expand against the actual code before implementation.

## Goal

Convert Known Nodes into a presentation-facing sensory model.

## Why this exists

The renderer needs a stable interface that cannot reveal hidden truth.

## Dependencies

[009](009_knowledge_base_known_nodes.md) and the preceding task sequence. Read [ARCHITECTURE](../ARCHITECTURE.md), [CODING_RULES](../CODING_RULES.md), and relevant [DATA_MODEL](../DATA_MODEL.md)/[UI_RULES](../UI_RULES.md) contracts.

## Allowed scope

PerceptionModel and typed PerceivedSignal: category, bearing, strength, confidence; preserve the remaining DATA_MODEL fields as applicable.

## Required behavior

Derive relative bearing/distance from known estimates and active pile; expose age/risk/traffic only when known. Keep qualitative formatting out of simulation.

Before coding: Resolve signal strength/category mapping, unknown-value representation, and angular conventions.

## Explicit non-goals

Polished rendering, camera movement, and querying hidden World Nodes. Do not implement future systems not explicitly requested.

## Interfaces to preserve

PerceivedSignal and source_knowledge_id; no mutable truth references in output.

## Acceptance tests

Extend separation test: hidden/unreturned evidence emits no signal; returned knowledge does. Change hidden truth without new evidence: perceived output stays knowledge-derived. Test cardinal bearings and angle wrap.

## Manual verification

Run the relevant prototype/debug scene and inspect the behavior above. On expansion, name exact files, commands, fixtures, and expected results; do not treat this roadmap as a fully specified coding prompt.

## Done when

The expanded card's checks pass, existing behavior remains intact, and the handoff records changed files, tests, limitations, and next task. One logical commit.
