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

Task 008 implements Observation with stable observation/scout/origin/source IDs, resource definition, first/latest evidence times, estimated position, uncertainty radius, closest sensed distance, and proximity confirmation. One record per scout/source is refined by closer sensing. Scouts carry records privately; RunState's delivered-observation inbox receives detached copies only on arrival. Task 009 consumes that inbox immediately after scout processing on each fixed tick. No quantity or live coordinate lookup is part of delivered evidence. Investigation routes follow estimates and preserve actual return breadcrumbs.

Task 009 adds a run-owned KnowledgeBase, an archive of detached observations plus delivery times, and one KnownNode per captured source ID (`known:<source_id>`). The newest observation supplies classification, estimated position and uncertainty; ties prefer lower uncertainty, then close confirmation, then lexical evidence ID. Older reports add provenance only. KnownNode retains sorted evidence IDs, the selected evidence ID, first/latest observation times, first/last delivery times, and baseline confidence. Identical re-delivery is a no-op; changed evidence reusing an ID rejects the entire batch. Confidence derives from evidence quality and decays with observation age using the authored knowledge configuration; querying it never changes the remembered estimate. Knowledge processing has no hidden-world or RNG dependency. Snapshot restore validates historical evidence at the RunState boundary, reconstructs Known Nodes from the archive, and atomically rejects inconsistent derived fields. Route memories remain future work.

Task 010 implements PerceivedSignal with `id`, `source_knowledge_id`, `category`, nullable `bearing`, `estimated_distance`, `uncertainty_radius`, `strength`, `confidence`, `confidence_label`, `age`, nullable `risk` and nullable `traffic`. The pure PerceptionModel receives Known Nodes, pile position and time; no world or run references. GameRoot supplies detached dictionary snapshots for views. Stable IDs are `signal:<known_id>`; signals are ordered by knowledge ID. Categories are authored from known classification with `unknown` fallback. Bearing is [0, TAU) radians clockwise from east; a coincident estimate has zero distance and null bearing. Relative bearing from facing wraps to [-PI, PI), preserving null. Risk and traffic remain null until implemented evidence can support them.

Signal strength is provisional presentation salience: aged confidence / (1 + estimated distance / 10 m). It never implies live chemical concentration or remaining resource quantity. Qualitative confidence is uncertain/likely/clear at authored 0.25/0.65 thresholds. Estimates and strength never read hidden coordinates, quantity or active flags. No private scout observation emits a signal. Output mutations, renderer animation and facing cannot change knowledge. Signals are derived on demand, not authoritative save data; rebuild them after restoring the run.

Task 011 projects these signals into a 180-degree OUTWARD field centered on presentation-only facing. Bearing controls horizontal placement; estimated distance affects a vertical display band, never literal terrain depth. The normal view receives only detached signal dictionaries and an approved summary (available workers, active scouts/cap, simulation time, paused and scale). Scout/time actions pass through semantic controller methods. Selected signal ID and facing are view state, not authoritative save state.

Task 012 adds `RunState.trails`, a `TrailNetwork` containing stable `route_N` and `segment_N` objects plus `next_route_id`. A route records origin pile, destination KnownNode ID, captured estimated endpoint, segment ID, desired/allocated/active worker counts, and active/inactive status. A segment records captured start/end, pheromone strength, familiarity, and traffic; the last three remain zero until later tasks. Active route allocation exactly matches a ledger `trail:<route_id>` commitment owned by that route. Desired and allocated counts are separate fields but equal in 012; active travelers remain zero. Cancellation sets both targets to zero, retires the commitment, and retains route/segment identity for reopening. No worker moves or resource collection occurs yet. Snapshots validate IDs, knowledge/colony references, geometry, conservation and orphan commitments before replacing the run. OUTWARD gets detached destination ID and labor/status summaries only, not segment coordinates.

Task 013 adds `TransitCohort` with stable `cohort_N` ID, route ID, outbound/inbound direction, worker count, cargo category/amount, and remaining leg ticks. `next_cohort_id` belongs to TrailNetwork. The sum of cohort workers for a route equals its active worker count and cannot exceed its allocated ledger commitment. Routes also store departure cooldown ticks, cumulative delivered amount, a returned empty-trip report, and active/recalling/inactive/depleted status. A cancelled route remains `recalling` until all cohorts return and its commitment can be retired. `depleted` means a cohort returned without finding an available source at the captured endpoint; it is a report, not a live world query by the UI. PileState now stores three finite nonnegative resource pools; the home fixture starts with authored 10 carbohydrate, 5 protein and 10 water. Collection subtracts world quantity into cohort cargo; home arrival deposits it exactly once. Restore validates cargo capacity/category, leg ticks, IDs, route/cohort/ledger counts, and storage before replacing the run. No resource consumption or source regeneration exists yet.

Task 014 activates `TrailSegmentState.pheromone_strength` and `traffic`. Pheromone is finite in [0,1], decays with a 90 simulated-second half-life on every fixed tick, and increases by 0.035 per worker in a cohort that deposits positive cargo on home arrival. Reinforcement clamps at 1; values below 0.0001 snap to zero. `traffic` counts successful returning workers cumulatively and saturates at the ledger's maximum safe count. Empty returns do not count. Inactive segments retain and decay chemistry. Restore accepts validated nonzero chemistry/traffic and still requires zero familiarity until task 015. The normal route summary exposes only detached strength, never segment coordinates or raw traffic.

Task 015 activates `TrailSegmentState.route_familiarity` as a second finite [0,1] value. A loaded return adds 0.008 per worker; every fixed tick applies a 900 simulated-second half-life, including on inactive segments. `TrailSystem.reliability` is `0.5 * pheromone + 0.5 * familiarity`; the source interaction radius is the task-013 base radius multiplied by `1 + 0.5 * reliability` (2–3 m with current tuning). No view reads this hidden interaction check. Save restore validates nonzero familiarity separately. Detached route summaries may carry both values for qualitative, memory-only presentation.

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

Use `JSON.stringify(snapshot, "", true, true)` when persisting floating-point sensory state: full precision preserves equivalent continuation. This is exercised by the mid-investigation reload test.

Use explicit `to_dict()` / `from_dict()` equivalents and a versioned envelope containing save_version, seed, scenario ID, clock, RNG state, world, colony, knowledge, trails, and pending work as it becomes implemented. Reference definitions by stable ID. Rebuild runtime references through validated IDs; do not serialize scene nodes or views.

Preserve 64-bit seed/RNG values losslessly (for JSON, decimal strings are a suitable encoding). Reject unsupported versions and invalid references without partially replacing a live run. The continuation check is: save, continue 100 ticks versus reload that save, continue the same 100 ticks. Compare authoritative state, not decorative effects. Full disk save/load belongs to its later task; early tasks supply only the contracts they need.
