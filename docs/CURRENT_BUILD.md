# Current build and gaps

Baseline: gameplay through card 136; planning through 137. Runtime content matches published commit `774adb95c6e628ca5bcf7efc4efbe02339a0925b`; pre-reset documentation baseline is `44b881f1ae0090a5a2650cd17902610988d073ee`. This document records implementation, not future promises.

## Implemented foundation

| Family | What works now | Principal 1.0 gap |
| --- | --- | --- |
| Runtime and saves | Godot 4.7.2 Compatibility, headless fixed ticks, seeded continuation, strict atomic saves, separate hidden reality/knowledge/presentation. | Packaged Windows build, migration policy for new schemas, measured final performance. |
| Labor | Authoritative per-pile ledger, aggregate brood/travel, held brood care, capped individual scouts. | Consistent flexible staffing/order explanations outside conflict; common waiting/cancel/report presentation. |
| Perception and scouts | Returned uncertain memories, standing exploration, bias/rechecks, caution, physical recall and missing-scout settlement; shared cap eight. | Persistent normal-play report history, source comparison, concrete identified source types and clearer priorities. |
| Resources | Three nutrient stores; physical gathering, travel energy, depletion, nectar/honeydew production, temporary crumbs, rain-refilled water and contamination. | Resource-type catalog, mixed nutrient yield handling, returned identification, meaningful handling profiles. Current broad definition IDs are not a complete food catalog. |
| Routes | Separate route/segment types, scent/familiarity, aggregate cohorts, detours, actual alternate courses and incoming cargo. | Shared multi-segment connections and broader network traffic/closure; no automatic optimal-route planner. |
| INWARD | Queen, Nursery, Food Exchange, Entrance, Midden, climate/refuse/food/care pressure; development and Nursery expansion. | Modular project/chamber definitions, reproductive scheduling and new organs defined by the catalog. |
| Brood/reproductives | Auto/manual worker brood, paid queued adaptation trials, one Home reproductive group and physical first founding. | Queue reproductives while Auto Brood stays on; daughter reproductives; queen health/replacement and generational continuity. |
| Adaptation | Six trait IDs: lean/load, persistent chemistry, security/tolerance and fighter; disjoint phenotype accounting, future-brood expression, founder inheritance. | Definition-driven ten-trait 1.0 catalog, new care/environment branches, reproductive-lineage web at more piles. |
| Network | Home plus exactly one `satellite_1`; local daughter jobs/scouts/gathering/defense; exclusive two-way supplies and Home settlers. | Multiple sites/piles, founding from daughters, paid migration/queen relocation, isolation/evacuation/abandonment. |
| Conflict | Stationary ambusher, independent rival foraging/counter-recruitment, physical messengers, Clear/Hunt, finite remains, retreat, alternate approach. | Moving predator and network/nest hazard responses; more general encounter/content definitions. |
| Conflict controls | Direct circular pop-over; arbitrary whole forces bounded by known labor; alerted trail then nest then explicit All Hands. Real recalls/reservations and care stay protected. | General interface activation feedback; further visual feel is deferred. Player accepts the circle as a substantial improvement. |
| Environment and health | Rain/heat, moisture/temperature care, refuse-related brood strain, recurring guest harm/clearing and contaminated intake. | Planned zone/connection/nest disturbances, new site profiles and useful evacuation counterplay. |
| Runs and presentation | Backyard/Garden Edge/Roadside; voluntary end, sampled post-run physical review; layered desktop art/music and normal sensory UI. | Biological continuation/failure rules, integrated scenario arcs, final graphics/music, onboarding and distribution. |

Queen health/death/replacement, multiple daughters, moving predators, species-specific dog behavior, reproduction queueing and new catalog entries are **not implemented**. Home worker-trial establishment is a retained prototype proxy. Daughter offspring use captured founder traits; there is no full mating/latent-genome simulation.

## Latest actual verification

[Card 136](archive/pre_1_0/tasks/136_direct_conflict_response.md) recorded 8,784 checks, zero failures, 66.30 seconds; clean headless import/Main and conflict drawing callbacks. Its focused suite recorded 1,989 checks. This is tested correctness, not release enjoyment, packaged compatibility or current renderer-performance acceptance.

The player supplies manual visual feedback. No screen monitoring, desktop automation, paid testers or broad compute sweeps are authorized. The documentation reset does not rerun the engine or claim new gameplay evidence. Existing user audio imports/images/translations and saved slot are preserved.

## Updating this baseline

When a milestone ships, link its completed card, replace the relevant gap with actual behavior, and record real gates and omissions. Keep the three statuses separate: implementation evidence, player acceptance, and release acceptance. Archive records are snapshots of their named builds.
