# Current implementation architecture

Implementation baseline: gameplay through 136. This is a current technical reference, not a declaration that the [1.0 bible](SYSTEMS_BIBLE.md) is implemented. Historical card-by-card explanations are [archive-only](archive/pre_1_0/contracts/ARCHITECTURE.md).

## Ownership and dependency direction

| Layer | Actual owner/location | Boundary |
| --- | --- | --- |
| Authored content | Godot Resource definitions under `data/`, definition scripts under `src/sim/` | Immutable after bootstrap; current resource definitions are broad IDs, not the future source catalog. |
| Fixed simulation | [SimulationController](../src/core/simulation_controller.gd), [RunState](../src/core/run_state.gd), SimulationClock | Typed run-owned state, deterministic ticks and seeded streams; no scene/graphics/input dependency. |
| World and knowledge | `src/sim/world/`, `src/sim/knowledge/`, observations/scout owners | Hidden reality is distinct from historical evidence; new world state cannot refresh old reports. |
| Workers and piles | [PileState](../src/sim/colony/pile_state.gd), [WorkerLedger](../src/sim/colony/worker_ledger.gd) | All commitments/population/transfers through the ledger; protected care derived at the pile. |
| Travel | `src/sim/trails/`, `src/sim/scouting/`, founding/supply/settler owners | Routes and physical segments remain separate; aggregate cohorts plus capped individual scouts. |
| Ecology/local physiology | `src/sim/ecology/`, `src/sim/weather/`, colony job systems | Physical exposure and causal losses through existing owner callbacks; local symptoms and remote evidence remain distinct. |
| Projection/commands | [GameRoot](../src/core/game_root.gd) | Validates semantic actions and provides approved detached sensory/local summaries; normal views do not query world objects. |
| Views/audio | `src/presentation/`, `src/audio/` | Attention, drawing, messages and sound; no authoritative gameplay totals or simulation RNG. |
| Persistence/review | [SaveService](../src/core/save_service.gd), [RunHistory](../src/core/run_history.gd) | Atomic validated snapshots; private physical history is projected only into ended-run review. |

SimulationController attaches systems to one RunState and owns their fixed-tick order. It injects existing job owners into conflict recruitment and care relief. RunState restores fresh typed state before replacing the live controller. Definitions are not mutated to save per-run values.

## Worker/care and conflict contracts

New work checks `PileState.workers_assignable`, not raw ledger availability; `allocate_workers` retains held brood care. Dedicated trial nurses are counted once. Every job target reduction goes through its owner; a view never edits a ledger or repairs a conservation failure.

ConflictRecruitment owns route-keyed `response:<route>` other-kind reservations. It recalls the alerted food trail first, then reserves home labor; all-hands may reduce supported cancellable jobs. Travelers must physically return. Care, dedicated nurses, ongoing projects and settlers remain protected. A ready defense reservation transfers to the existing journey party. Rival reinforcement releases/reserves into ordinary gathering atomically. Cancellation releases reserved local labor and does not restore reduced jobs.

JourneyResponse owns one shared party slot across both piles. Combat, reinforcement joining and messengers are actual travel; local counts expose sent/expected labor, not private survivors or combat phase. Low commitments apply the existing retreat threshold before risking their final reporter. Per-origin loss history reconciles the ledger with the shared physical predator.

## Present network and genetics limits

The implemented network is Home plus `satellite_1`. The founding/settler/supply contracts still contain that bounded scope; generalized multi-pile IDs/connections do not exist yet. Home and Daughter supplies share one exclusive physical connection with independent payer receipts. Settler handoff is a ledger transfer, not a death/birth. Do not make content-catalog claims imply arbitrary networks already work.

GeneticRepertoire tracks disjoint phenotype bundles. Brood captures inheritance at laying, movement captures effects at departure, and loss/transfer preserves profiles. Home uses queued worker trials; Daughter offspring use founder queen traits. Full queen records, daughter trials/reproductive generations and new traits require their roadmap cards.

## Information and presentation

Normal OUTWARD is a 2D sensory projection; INWARD is a functional network. Views send semantic callbacks and use detached approved snapshots. Source quantity/availability, enemy location/health, live combat casualties, candidate route geometry and private scout findings never enter normal UI. Current local air/weather and internal symptoms are permitted local observations.

Expected population/carriers include owned unresolved exterior losses until reports/absence settlement. ConflictPopover uses route/local summaries only. Post-run physical history is separate and never backs the planned normal report journal. Ended runs reject gameplay commands; review cannot resume revealed play.

## Development toward modular 1.0

Use current family owners and immutable authored definitions. M1/M2/M3/M5 extend schemas only when a first complete source/chamber/trait/connection entry needs them. The future catalog schema is design, not an existing API. Avoid a universal effect interpreter, speculative folders, scene-owned simulation or an engine upgrade. Update this reference after an implemented contract changes.
