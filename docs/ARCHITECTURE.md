# Architecture

## Stack and dependency direction

Godot 4.x/GDScript; target stable 4.7.x and pin the tested patch in task 001. Windows first; Android compatibility is a design constraint now. Use inexpensive 2D presentation and a mobile-compatible renderer, with no dependency on Forward+ effects. Specific renderer selection is a bootstrap decision recorded in [DECISIONS](DECISIONS.md).

```text
Hidden world reality → simulation interactions → colony knowledge
                                                ↓
                                          PerceptionModel
                                                ↓
                                     OUTWARD / INWARD / HUD
```

This expresses information flow, not a license for views to traverse upstream references. Presentation sends semantic commands to SimulationController; it cannot mutate authoritative objects. Simulation validates commands before changing state. Display labels and formatting belong to presentation.

## Ownership

| Owner | Responsibility |
| --- | --- |
| GameRoot | Compose and dispose a run and its views |
| SimulationController | Fixed-tick dispatch, command validation, explicit system references |
| RunState | Seed/RNG, scenario ID, clock, authoritative state references |
| WorldSystem / WorldState | Hidden bounds, terrain, World Nodes |
| ColonySystem / ColonyState | Piles, worker ledger, resources, brood, queens |
| ScoutSystem | Capped detailed scouts and observations |
| KnowledgeSystem / KnowledgeBase | Delivered evidence, Known Nodes, route memory |
| TrailSystem / TrailNetwork | Separate routes, segments, aggregate transit cohorts |
| BroodSystem / ChamberSystem | Development and labor/resource effects |
| EventHistory | Meaningful gameplay events; distinct from diagnostic logging |
| PresentationController / PerceptionModel | Knowledge-derived sensory signals and approved colony summaries |
| OutwardView / InwardView / HUD | Rendering, selection, input intent |
| AudioController | Semantic MusicState, initially development level only |
| DebugTools | Explicit development-only access to truth and intermediate representations |

These are responsibilities, not a requirement to create every class during bootstrap. Add owners as their task needs them. Use direct ownership and injected references; no simulation-manager autoload collection. AppSettings or SaveService may justify a later autoload.

## State and time

- Immutable authored definitions: typed Resource classes and diffable `.tres` where editor integration helps. Runtime state: typed lightweight classes, preferably RefCounted, with stable IDs and explicit serialization.
- The scene tree is not a database. No Node per worker, brood ant, trail traveler, or resource unit. Visible ants and particles are capped, pooled representatives.
- One SimulationClock is authoritative. RunState owns it and exposes its time; do not maintain a second mutable time field. Fixed simulated interval starts at 0.25 seconds, with pause and 1×/4×/16×/64× speeds.
- Render-frame time feeds an accumulator; systems receive fixed simulated steps. Slower systems use accumulators or scheduling. Allocate labor when commitments/population/returns change, not each render frame.
- Gameplay randomness comes only from the run-owned seeded RNG. Rendering never advances it. Stable iteration and event ordering are necessary for repeatability.
- Preserve seed, current RNG state, tick/time, pending accumulators/events, and authoritative state for equivalent save continuation. Versioned explicit dictionaries/JSON are acceptable; save service implementation waits for its card.

## Knowledge boundary

WorldNode → scout interaction → Observation → delivered KnowledgeBase evidence → KnownNode → PerceivedSignal → OUTWARD.

In the slice, a scout's private observations do not become colony knowledge until it returns. A world change does not silently refresh old knowledge. Perception uses known/estimated positions, never live hidden coordinates. INWARD uses an approved colony summary. Views receive snapshots or read-only values, not mutable hidden objects.

Implemented through 009: SimulationController ticks ScoutSystem, then consumes the delivered inbox into RunState.knowledge. KnowledgeBase receives evidence and simulation time only; it owns archived reports and derives Known Nodes. Restore validates source identities at the RunState boundary without refreshing historical coordinates or quantity. Confidence aging is a query, not a mutable second clock.

Implemented through 010: GameRoot owns PerceptionModel and composes `sensory_snapshot(pile_id)` from Known Nodes, pile position and simulation time. The model never receives RunState, hidden WorldState, scouts, archive or RNG. Its typed signals and dictionary snapshots are detached values, rebuilt on demand and after restore. Only the explicit debug view receives both this provider and the separate truth provider. Task 011 composes a normal OUTWARD view only on graphical runs. Its providers return detached signals and an approved pile/clock summary; semantic callbacks dispatch scouts and control the clock. The view has no RunState or WorldState reference. F3 remains the separate, development-only truth layer drawn above it. UI facing/selection are presentation state and do not enter saves.

Task 012 adds RunState-owned TrailNetwork, one typed route and one distinct segment per invested known destination, and TrailSystem commands on SimulationController. Routes capture the current colony estimate without querying live hidden nodes. The pile's WorkerLedger owns committed labor; each active route has a matching `trail:<route_id>` commitment. GameRoot passes detached route labor summaries and semantic create/adjust commands to OUTWARD. Only F3 accesses route geometry and raw ledger state. Travel and resource flow are not yet active.

Task 013 makes TrailSystem a fixed-tick system. Bounded TransitCohorts hold committed workers and cargo during estimated-segment travel. A cohort may query hidden WorldState only when it reaches the captured endpoint; returning cargo is deposited in the pile's resource store. Empty returns report source unavailability, stopping new departures without revealing live quantity through normal UI. A reduction releases idle labor immediately and releases in-flight surplus only on return. RunState snapshots validate route/cohort/ledger relationships and preserve mid-trip continuation. Normal OUTWARD receives only detached route progress and stored resource totals; F3 can inspect cohort and source truth.

Task 014 makes segment pheromone authoritative simulation state. Loaded cohort home arrivals reinforce by worker count; every fixed tick decays all segments, including inactive routes. Familiarity remains separate and unchanged. GameRoot exposes detached pheromone strength in route summaries; TrailVisual maps that value and a visible projected signal into bounded screen-space strokes. It never receives segment endpoints. F3 may inspect numeric chemistry and aggregate traffic.

Task 015 activates separate segment familiarity. Loaded returns teach it more slowly than chemistry, and its much longer half-life leaves a route memory after chemical washout. TrailSystem derives reliability equally from both values; this modestly broadens source interaction tolerance at the captured estimate without changing transit legs. OUTWARD receives detached familiarity for a sparse, faint memory ghost and has no route geometry.

Headless simulations must require no cameras, HUD, particles, ant graphics, or music. Debug inspection can compare all pipeline stages but must never feed truth back into player presentation.

## Planned layout

Create directories only when useful; this is a plan, not existing code.

```text
project.godot
src/core/                         clock, run lifecycle, shared contracts
src/sim/world/                    bounds, terrain, nodes
src/sim/colony/                   piles, ledger, brood, chambers
src/sim/scouting/                 detailed scout agents
src/sim/knowledge/                observations and colony knowledge
src/sim/trails/                   routes, segments, cohorts
src/sim/resources/                resource operations
src/presentation/{outward,inward,ui}/
src/audio/                       semantic audio state
src/debug/                       development-only diagnostics
scenes/{main,outward,inward,debug}/
data/{resources,terrain,chambers,signals}/
tests/                           lightweight headless runner and cases
assets/{audio,fonts,textures,placeholder}/
docs/                            durable design and task cards
```

## Events and diagnostics

Use sparse semantic events such as observation_added, known_node_created, trail_created, resource_delivered, brood_matured, chamber_online, and rain_started. Do not broadcast every field assignment. Diagnostic categories such as SCOUT/TRAIL/BROOD are switchable. Run history stores meaningful events for future history/replay, not log spam.
