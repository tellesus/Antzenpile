# Current implementation architecture

Implementation baseline: gameplay through 147. This is a current technical reference, not a declaration that the [1.0 bible](SYSTEMS_BIBLE.md) is implemented. Historical card-by-card explanations are [archive-only](archive/pre_1_0/contracts/ARCHITECTURE.md).

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

141 makes ordinary gathering an explicit whole target. TrailRoute owns a separate unsent `waiting_workers` count; stable route ticks fund that remainder only through care-protected local allocation. Zero-funded intent has no ledger pool. Reported depletion pauses further funding; cancellation clears waiting and recalls actual travelers. Desired minus surviving allocation is not an automatic replacement order after losses. Home and Daughter share a free staffing draft, with five as a suggestion.

ConflictRecruitment owns route-keyed `response:<route>` other-kind reservations. It recalls the alerted food trail first, then reserves home labor; all-hands may reduce supported cancellable jobs. Travelers must physically return. Care, dedicated nurses, ongoing projects and settlers remain protected. A ready defense reservation transfers to the existing journey party. Rival reinforcement releases/reserves into ordinary gathering atomically. Cancellation releases reserved local labor and does not restore reduced jobs.

JourneyResponse owns one shared party slot across both piles. Combat, reinforcement joining and messengers are actual travel; local counts expose sent/expected labor, not private survivors or combat phase. Low commitments apply the existing retreat threshold before risking their final reporter. Per-origin loss history reconciles the ledger with the shared physical predator.

## Present network and genetics limits

The implemented network is Home plus `satellite_1`. The founding/settler/supply contracts still contain that bounded scope; generalized multi-pile IDs/connections do not exist yet. Home and Daughter supplies share one exclusive physical connection with independent payer receipts. Settler handoff is a ledger transfer, not a death/birth. Do not make content-catalog claims imply arbitrary networks already work.

GeneticRepertoire tracks disjoint phenotype bundles. Brood captures inheritance at laying, movement captures effects at departure, and loss/transfer preserves profiles. Home uses queued worker trials; Daughter offspring use founder queen traits. Full queen records, daughter trials/reproductive generations and new traits require their roadmap cards.

143 adds per-pile InvestmentIntent and an injected InvestmentSystem coordinating existing adaptation/reproduction laying owners. At most one pending trait and one reproductive intent coexist; priority order preserves earliest queuing/replacement and supports explicit reorder. Eligible specials get the next opportunity before ordinary Auto Brood; structurally ineligible early/follow-up intents allow prerequisite growth. Manual laying honors the first pending intent. Queuing spends no resources/space/labor; actual laying removes only its funded intent, leaving paid cohorts and other pending work intact. Current reproductive/trial capability remains Home-only until M4.

144 introduces immutable ChamberDefinition/Catalog and typed ChamberProject/Set/System. The first complete entry is Reproductive Alcove: queued care-protected funding, prepaid construction, cancellation without consumed-food refund and real completion. New projects have ledger pools and clock-validated dates; legacy chamber flags/definitions retain their behavior and costs. Dedicated reproductive capacity subtracts supported reproductive occupancy from shared Nursery space without adding worker slots or caregivers. Queued reproductive laying dates the start of its aging interval, preserving immediate funded saves.

145 adds Ventilation Gallery under that owner, with a bounded regulation-step hook after completion. Humidity and Heat still own distinct actual water debits; no new operating pool or passive immunity. EffortDraft exposes whole climate/cleanup/scout ranges through existing care-protected setters. Suggestions use approved local/known summaries; editing is unsaved attention, not a universal allocator.

146 SourceProfile supplies immutable per-portion yields/bulk. Transit captures a sparse three-nutrient recipe at harvest, withdraws portions once and settles/deposits at physical return; no recipe/world lookup at arrival. Bulk/loss/messenger paths preserve actual payload/dose and evidence. Routes own optional per-nutrient receipts alongside legacy primary totals; approved SourceMemory filters/Reports use actual receipts and known type roles, never live source stock. Garden Edge's first fruit entry uses these rules; generic old worlds/cargo remain unit-primary.

## Information and presentation

140 composes ReportSystem after fixed-tick owners. It captures only delivered knowledge/route/response records and locally visible emergence/projects/traits; it never reads World or RunHistory. Run-owned ReportJournal bounds semantic entries/seen fingerprints, caches immutable encoded rows and primes legacy loads without invented history. Normal ReportControls uses detached rows/current needs, explicit pause/read/free inspection and modal shielding. ColonyPressure.needs exposes concurrent causes and ranks ongoing clearing below untreated strain. Menu/view/review activation cues consume explicit command outcomes; accepted means accepted intent, not remote victory.

Normal OUTWARD is a 2D sensory projection; INWARD is a functional network. Views send semantic callbacks and use detached approved snapshots. Source quantity/availability, enemy location/health, live combat casualties, candidate route geometry and private scout findings never enter normal UI. Current local air/weather and internal symptoms are permitted local observations.

Expected population/carriers include owned unresolved exterior losses until reports/absence settlement. ConflictPopover uses route/local summaries only. Post-run physical history is separate and never backs the planned normal report journal. Ended runs reject gameplay commands; review cannot resume revealed play.

142 SourceMemory sorts detached reported age/intake/order/alarm data with stable ID ties and numeric colony labels. Root projects standing/manual scout intent, shared expected slots and local labor/care/dispatch-spacing waits; no private phase/location/findings. Priority names use existing knowledge identities. Home/Daughter comparison layouts reserve actual compact bounds; sorting/paging is disposable attention without simulation mutation.

## Development toward modular 1.0

139 separates immutable SourceProfile metadata from the existing nutrient ResourceDefinition. Fresh scenario annotations are saved on physical nodes; close scout/harvest/carcass samples establish knowledge identity. SourceCatalog names approved identities and base-26 labels, without world lookup in views. A tiny ActivationFeedback view helper acknowledges taps without run mutations. See the card for validated migration and current limitations; yields/ecology rates remain unchanged.

Use current family owners and immutable authored definitions. M1/M2/M3/M5 extend schemas only when a first complete source/chamber/trait/connection entry needs them. The future catalog schema is design, not an existing API. Avoid a universal effect interpreter, speculative folders, scene-owned simulation or an engine upgrade. Update this reference after an implemented contract changes.
