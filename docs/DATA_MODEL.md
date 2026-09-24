# Data model

Contracts below describe the slice destination. Implement each object only when its task arrives. Names are durable vocabulary; fields are minimum responsibilities, not a mandate to prebuild unused systems. IDs identify objects and definitions across serialization; views must not hold mutable authoritative references.

## Authoritative state

| Object | Minimum data / responsibility |
| --- | --- |
| RunState | run_seed, scenario_id, run-owned RNG and current state, clock, world/colony/knowledge/trail references |
| SimulationClock | paused, time_scale, simulation_time, tick_interval, tick count and fractional accumulator |
| WorldState | bounds, terrain, World Nodes keyed by stable ID |
| WorldNodeState | id, definition_id, position, quantity, active, properties |
| ColonyState | piles; colony worker/resource summaries derived from pile state |
| PileState | id, position, queen_count, worker ledger, brood_cohorts, resources, primitive_food_exchange, known_trails |
| WorkerLedger | total living workers and disjoint available/internal/scout/trail/other commitment pools |
| BroodCohort | stage, count, development_progress, nutrition, care |
| ScoutAgent | id, position, origin_pile, state, mission_id, observations, return_path |
| KnowledgeBase | observations delivered to colony, Known Nodes, route memories |
| KnownNode | stable knowledge ID, evidence/source references, estimated position/classification, confidence, last observation time |
| TrailNetwork | routes and segments; aggregate transit cohorts |
| TrailRouteState | id, origin, destination, desired_workers, allocated_workers, active_workers, round_trip_time, resource_flow, status; segment references |
| TrailSegmentState | id, route_ids, pheromone_strength, route_familiarity, traffic, exposure, terrain_modifier |
| TransitCohort | route_id, direction, worker_count, payload, remaining_travel_time |

Resource pools initially contain **carbohydrate, protein, water**. Authored definitions describe types; runtime state describes current quantities. Do not hardcode individual food sources into system scripts. World position is 2D; the proposed bootstrap convention is meters, +x east, +y south.

## Knowledge and presentation contracts

Observation records what a scout encountered and when, with source identity/evidence and uncertainty. It is not itself a UI element. Define the detailed schema when expanding the knowledge card; the important contract now is separate ownership and delayed delivery.

PerceivedSignal contains `id`, `category`, `bearing`, `estimated_distance`, `strength`, `confidence`, `age`, `risk`, `traffic`, `source_knowledge_id`. Derive it from colony knowledge. Numeric confidence becomes qualitative UI wording in PerceptionModel. Unknown fields remain unknown, not perfect defaults. Renderer animation and facing do not change knowledge.

MusicState exposes semantic development level for the slice. Stability/crisis may be added later. Audio does not inspect arbitrary simulation internals.

## Invariants

1. **Worker conservation:** total living workers = available + internal jobs + scouts + trails + other explicit commitments. Pools are disjoint, integral, and nonnegative. `workers_total` and `workers_available` on a pile are ledger-backed values, never independent counters.
2. Every transfer goes through the ledger. Birth/maturation and death explicitly change the total and an affected pool together. Failed transfers change nothing. Queens and immature brood are not workers.
3. Desired trail workers are a target, allocated workers are actual commitments, and active travelers are a subset of those commitments. Cohorts must not be counted again as a separate top-level worker pool. Recall stops new departures; in-flight workers become available only on return.
4. Pheromone and familiarity are separate values clamped to [0,1]. Traffic reinforces pheromone; disuse decays it. Familiarity grows and decays more slowly. Rain increases exposed-segment pheromone loss while leaving most familiarity intact.
5. Routes express colony intent/commitment; segments express shared physical/chemical infrastructure. Begin with one segment per route but retain separate IDs/objects. Later, multiple routes may share a segment.
6. Foragers travel in bounded, bucketed cohorts, not individual agents. Resources are collected at the destination and deposited on return, not at allocation. Quantities and payloads cannot become negative or duplicate on reload.
7. Unobserved World Nodes do not exist in KnowledgeBase or produce PerceivedSignals. A live node ID in evidence is not permission to query its current hidden state for UI.
8. Definitions remain immutable during a run. Runtime instances do not share mutable resources, arrays, or dictionaries across fresh runs.

## Serialization

Use explicit `to_dict()` / `from_dict()` equivalents and a versioned envelope containing save_version, seed, scenario ID, clock, RNG state, world, colony, knowledge, trails, and pending work as it becomes implemented. Reference definitions by stable ID. Rebuild runtime references through validated IDs; do not serialize scene nodes or views.

Preserve 64-bit seed/RNG values losslessly (for JSON, decimal strings are a suitable encoding). Reject unsupported versions and invalid references without partially replacing a live run. The continuation check is: save, continue 100 ticks versus reload that save, continue the same 100 ticks. Compare authoritative state, not decorative effects. Full disk save/load belongs to its later task; early tasks supply only the contracts they need.
