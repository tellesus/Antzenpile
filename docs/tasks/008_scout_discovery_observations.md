# 008 — Scout discovery and observations

Status: roadmap; expand against the actual code before implementation.

## Goal

Let scouts detect World Nodes and carry observations home.

## Why this exists

Private encounters must not become immediate colony-wide knowledge.

## Dependencies

[007](007_scout_mission_agent.md) and the preceding task sequence. Read [ARCHITECTURE](../ARCHITECTURE.md), [CODING_RULES](../CODING_RULES.md), and relevant [DATA_MODEL](../DATA_MODEL.md)/[UI_RULES](../UI_RULES.md) contracts.

## Allowed scope

Detection radius, typed Observation, scout-carried evidence, and delivery boundary on return.

## Required behavior

Capture encountered evidence/time without making UI. Transfer carried observations once, only on successful return. Use a minimal delivered-observation inbox; KnownNode merging remains 009.

Before coding: Resolve detection radius, observation schema, duplicate encounter policy, and undelivered evidence handling.

## Explicit non-goals

KnownNode confidence/merging, visual signals, and trail creation. Do not implement future systems not explicitly requested.

## Interfaces to preserve

Scout ownership of undelivered evidence and a distinct colony delivery boundary.

## Acceptance tests

Knowledge Separation test: hidden node and unreturned encounter produce no colony evidence; returning transfers it exactly once. Until 009–010 exist, test the inbox boundary, then extend the same scenario to knowledge/signals.

## Manual verification

Run the relevant prototype/debug scene and inspect the behavior above. On expansion, name exact files, commands, fixtures, and expected results; do not treat this roadmap as a fully specified coding prompt.

## Done when

The expanded card's checks pass, existing behavior remains intact, and the handoff records changed files, tests, limitations, and next task. One logical commit.
