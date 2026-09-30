# First vertical slice

## Question and arc

**Is interpreting and shaping a living ant trail network interesting enough to carry the game?** Deliver one approximately **20–30 minute** developmental arc, not the full GDD.

Start with one pile, one queen, 40 workers, a small brood cohort, small carbohydrate/protein reserves, basic water, primitive nursery and Food Exchange, and almost no exterior knowledge. These are the eventual slice starting conditions; task 005 creates only the pile/ledger, and task 016 introduces brood. Unspecified quantities are provisional fixture values in [DECISIONS](DECISIONS.md).

One authored hidden backyard map, roughly 40×40 meters, contains exposed and sheltered terrain, **two carbohydrate nodes, one protein node, and one water node**. This is not procedural map generation.

Required arc: send scouts → discover carbohydrate → return information → reinforce signal → create trail → commit workers → food returns → brood develops → workers emerge → discover protein → support growth → Food Exchange becomes strained → commit labor/resources/time to develop it → synchronized additional music layer appears.

After at least one exposed and one sheltered trail exist, trigger one rain event. The exposed trail loses substantially more pheromone; familiarity largely survives and helps recovery. The player decides where to scout, which signal to reinforce, how many workers to commit, whether to maintain a weakening trail, and whether to invest workers in Food Exchange.

## Included and excluded

Include fixed time controls, seeded state, worker conservation, capped scouts, returned observations, colony knowledge, PerceivedSignals, OUTWARD/INWARD, one segment per route, aggregate transit, resource delivery, pheromone/familiarity, brood growth, one chamber transition, two placeholder audio stems, one rain event, versioned save/load, and a developer truth view.

Exclude rivals, foreign trails, swarms, combat, predators, parasites, mutualists, poison, satellite piles, daughter queens, adaptation/genetics, procedural maps, human attention, full reality replay, seasons, complex sanitation, disease, and full trophallaxis simulation. Do not prebuild these systems. Representative visual ants are optional until the core loop works; finished art is not required.

## Implementation order from Part 8

Individual cards record implementation status. 001–006 contain executable instructions; 007–022 are intentionally concise and must be expanded before their implementation.

| Task | Deliverable |
| --- | --- |
| [001](tasks/001_project_bootstrap.md) | Project bootstrap |
| [002](tasks/002_simulation_clock.md) | Simulation clock |
| [003](tasks/003_seeded_run_state.md) | Seeded RunState |
| [004](tasks/004_hidden_world.md) | Hidden world and World Nodes |
| [005](tasks/005_home_pile_worker_ledger.md) | Home pile and worker ledger |
| [006](tasks/006_debug_world_view.md) | Basic developer world view; skeleton review |
| [007](tasks/007_scout_mission_agent.md) | Scout mission and ScoutAgent |
| [008](tasks/008_scout_discovery_observations.md) | Discovery and returned observations |
| [009](tasks/009_knowledge_base_known_nodes.md) | KnowledgeBase and Known Nodes |
| [010](tasks/010_perceived_signals.md) | PerceivedSignals |
| [011](tasks/011_outward_prototype.md) | OUTWARD prototype |
| [012](tasks/012_trail_creation_worker_allocation.md) | Trail creation and worker allocation |
| [013](tasks/013_transit_cohorts_resource_delivery.md) | Transit cohorts and resource delivery |
| [014](tasks/014_pheromone_reinforcement_decay.md) | Pheromone reinforcement and decay |
| [015](tasks/015_route_familiarity.md) | Route familiarity |
| [016](tasks/016_brood_worker_growth.md) | Brood and worker growth |
| [017](tasks/017_inward_prototype.md) | INWARD prototype |
| [018](tasks/018_food_exchange_development.md) | Food Exchange development |
| [019](tasks/019_music_stem_state.md) | Music stem state |
| [020](tasks/020_rain.md) | Rain |
| [021](tasks/021_save_load.md) | Save and load |
| [022](tasks/022_vertical_slice_integration.md) | Integration and pacing; evaluate before expanding |
| [023](tasks/023_persistent_scout_search.md) | Playtest follow-up: persistent scout search for new sources |
| [024](tasks/024_rain_water_collection.md) | Playtest follow-up: steady water collection during rain |
| [025](tasks/025_repeat_brood_cycle.md) | Playtest follow-up: manual repeat brood cycle |

## Acceptance and evaluation

- At the end of the arc the colony is larger, several signals are known, at least two useful trails exist or existed, degradation has occurred, Food Exchange is developed, and the soundtrack has gained a layer.
- The full economic/development/rain sequence also runs headlessly. Worker accounting holds through allocation, scouts, recalls, maturation, and save/load. Hidden objects do not leak into player perception.
- Equivalent simulated duration at all supported speeds produces equivalent authoritative results. Save/reload continuation matches uninterrupted continuation.
- OUTWARD direction/uncertainty and INWARD development are legible with restrained effects; no normal-play truth map. Mouse and touch share interaction logic; no required hover/right-click.
- Aim for 60 FPS presentation on modest desktop hardware. Record measured hardware, workload, renderer, and object/effect counts. No per-worker processing; simulation cost must not depend on visible-ant count. Android export can wait, but mobile-safe constraints cannot.

After 022, stop adding systems and evaluate actual play: scouting satisfaction, returned information, signal reinforcement, living trails, labor tension, useful decay/rain choices, panorama readability, INWARD usefulness, growth, and the music reward. Fix the core loop before beginning ecology, rivals, or adaptation.

The task-022 command-driven and Windows graphical baseline, including measured pacing and unresolved design questions, is recorded in [SLICE_EVALUATION](SLICE_EVALUATION.md). It does not substitute for the planned human playtest.

The player's first playtest led to completed follow-up cards 023–024 for persistent scout search and rainfall water. These refine the core loop before any larger expansion.

Task 025 also addresses the observed one-cycle population ceiling with a manual repeat-brood action. The first-slice acceptance arc above remains the initial milestone; continued growth can now be playtested afterward.
