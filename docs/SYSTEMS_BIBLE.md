# Antzenpile systems bible — 1.0

Current design book, 2026-10-05. The player authorized this 1.0 foundation and modular planning pass. It supersedes historical design/planning instructions in the [archive](archive/README.md). This document defines intended systems; [Current Build](CURRENT_BUILD.md) and the technical references identify what actually works. Planned rules become runtime contracts only through a verified implementation card.

## 1. The game we are building

The player is a distributed colony: living labor turns incomplete evidence into food, growth, inherited capabilities and a network of viable nests. Darkness and delay create uncertainty about the world; orders, costs, waiting and recovery must remain clear. A complete run can progress through establishment, adaptation, expansion, crisis and reproductive continuity, with voluntary continued play and a meaningful post-run review.

The 1.0 foundation includes a continuing reproductive lineage, multiple independently staffed piles, real transport and rescue, a compact useful ecology, concrete resource identities, ten adaptation choices and additional functional organs. No territory-percentage victory, research currency, tunnel-floorplan building or individual worker micromanagement is introduced. The fictional composite species permits coherent biology-inspired rules without promising literal natural history.

## 2. Shared rules and modular content

### A. Four separate layers

1. **Physical reality:** actual sources, terrain, weather, hazards, organisms and travel. Simulation owns it.
2. **Colony state:** local living workers/queens/brood, stores, commitments, inherited traits and functional organs.
3. **Knowledge:** historical returning observations, local symptoms, commanded intent and inferred absence. A changing world does not silently refresh memory.
4. **Presentation:** sensory panorama, functional INWARD network, reports, impressions and semantic controls. It consumes approved detached data.

Debug truth remains development-only. A separate physical history can be revealed after a run ends; ordinary play cannot resume from that reveal. A normal report journal never reads the private recorder.

### B. Definitions, instances and owners

Each rules family has immutable authored definitions, small typed instance state and a named headless owner. A food profile, trait, chamber or predator is content within its family's tested rules. Add a new family only for a behavior that cannot be expressed honestly by an existing one.

Content declares a stable ID, status/milestone, player purpose, prerequisites, effects/costs, knowledge cues, interactions, save compatibility and verification. IDs are not display labels. Existing saved IDs are preserved or migrated explicitly. Effects use a small whitelist of family-specific hooks; 1.0 does not need a universal effect language, plugin engine or one giant entity schema.

The launch content is in [Resources](catalogs/RESOURCES.md), [Chambers](catalogs/CHAMBERS.md), [Adaptations](catalogs/ADAPTATIONS.md), [Ecology](catalogs/ECOLOGY.md) and [Sites/Scenarios](catalogs/SITES_AND_SCENARIOS.md). Their entries are working design commitments; exact tuning values are authored/provisional. Gated content has an explicit inclusion test.

### C. Living investment and physical ownership

Workers, brood and ordinary travelers stay aggregate. Individually simulated scouts remain capped. All worker transfers use the authoritative ledger; queens, brood, cargo and traits have one owner/location as well. Transfer never means copying or death. A representative ant or chamber node owns no gameplay population.

Every order names its paying pile. Free-for-jobs excludes held brood care and dedicated nurses. Construction/ongoing projects and settlers are protected from routine all-hands recruitment. A returning cohort remains committed until it physically arrives. Unreported exterior losses remain in expected presentation counts until a legitimate report/absence settlement.

### D. One action vocabulary

Inspect/select is free attention. Queue creates editable intent. ORDER/ASSIGN commits a validated target; SEND means actual dispatch when funded. Wait names the missing prerequisite. Stop blocks new work; recall requests physical return; retreat withdraws that encounter/route; cancel removes unsent intent and releases only local reservations. Spent food/time and incoming cargo are not refunded or erased.

Use arbitrary whole staffing where the job's actual model permits it. Suggestions are starting points, not success guarantees. Explain real indivisible reproductive groups, capacities, shared scout/connection slots and care reserves. Never make a prototype increment look like biology.

### E. Verification and scope

Each system handoff includes visible outcomes, owned state/commands, knowledge projection, save validation and useful targeted checks. Ordinary semantic scenarios and saved twins verify conservation, delay, failure/recovery, pause and speed. The player supplies focused visual/audio/feel checks. Budget is $0; no paid testers, screen monitoring or large compute sweeps. Final graphics/music follows systems integration. Fixed session duration and mobile production remain tabled.

## 3. Systems

### SYS-01 Labor and orders

**Purpose:** spend living ants deliberately while maintaining care and recoverability. Foundation: per-pile ledger and conflict reservations. Planned M1/M2: consistent ordinary job targets/wait reasons and staffing suggestions.

An order records owner, job/destination, requested target, currently reserved/committed labor, optional other-task permission and known waiting reason. Each job owner validates before mutation. No global allocator may subtract a worker directly from another job's cached total.

Conflict recruitment draws from the alerted trail, then free nest workers, then explicitly allowed cancellable jobs. Trail recruits physically return before joining. A rival response normally adds gatherers to its existing fighting junction. Other tasks stay reduced until deliberately reassigned; cancellation cannot silently restart risky work. Aggregate care, reproductive/trial nurses and ongoing projects retain protection.

**Release acceptance:** commands distinguish selection, queued assembly and actual departure; invalid orders are atomic; expected unresolved casualties do not leak through sliders or maxima. Fractional/negative counts, double allocation, wrong-pile payment and orphan reservations fail validation.

### SYS-02 Sensing, knowledge and scouts

**Purpose:** learn enough to make decisions without an omniscient map. Foundation: observations, uncertain returned nodes, standing exploration, bias, priorities and caution. M1 adds clearer job summaries, stable source identities and a normal report journal.

A scout owns a bounded mission, real path and captured capabilities. Standing effort shares the known cap between piles; manual rechecks and recurring priorities are distinct. Favoring a direction changes search intent; rotating OUTWARD changes attention. Detours preserve trail workers and deliver evidence physically.

Reports keep observation/receipt times, owning pile, source/route and supported facts. Identity/availability confidence may differ. Group routine receipts while retaining significant losses, survey/pressure/approach outcomes, emergence, completed investments and local warnings. History is bounded with explicit abbreviation; important latest facts remain in authoritative knowledge. Reading/acknowledging a report cannot issue an order. Multiple current needs remain discoverable.

Missing travelers establish absence only through the existing conservative return/grace rules. Unknown loss cannot identify a killer. **Acceptance:** unchanged hidden reality produces no new UI fact; sources and names survive save/filter/pile changes; simultaneous reports remain retrievable at all four speeds.

### SYS-03 Resource sources and nutrition

**Purpose:** turn concrete foods/water sources into different strategic choices. Foundation: three stores and physical producers/depletion. M1/M2/M6 adds the [ten source profiles](catalogs/RESOURCES.md).

Separate source type, physical instance, knowledge memory and route. Type profiles reuse finite/producer/episodic/wetness-fed availability, handling and identification rules. Nutrient role remains carbohydrate/protein/water; a food can yield a captured bundle without becoming another currency. Insect remains, nectar, fruit, seeds, crumbs and several water sources differ mechanically rather than only in names.

Coarse cues become recognized types through valid returning samples. Use stable knowledge-owned A/B labels for duplicates and optional nicknames. Old generic worlds do not acquire invented identities on load. Quantity, purity, renewal schedule and current freshness remain hidden until justified.

**Acceptance:** an actual portion is withdrawn/converted once, delivered outputs match captured cargo, finite remains cannot renew, producer tending is separate from gathering, and mixed foods do not duplicate worker/travel cost or contamination.

### SYS-04 Trails, travel and cargo

**Purpose:** make geography, chemistry and the cost of distance matter. Foundation: distinct routes/segments, scent/familiarity, aggregate cohorts, energy and alternate courses. M5 extends network connections and shared physical segments where meaningful.

A route owns a job/destination; segments own physical course/exposure, shared pheromone and familiarity. Traffic does not copy segments or create several independently credited scent fields on one shared corridor. Installed detours follow a returned paid approach result. Sharing a segment does not merge unrelated worker ownership or refund travel energy.

Cohorts carry actual workers, captured profiles, harvested portions/output, contamination and report payloads. Recalls turn/block real traffic; inbound cargo can still arrive. The carbohydrate bootstrap rule can settle actual travel debt from actual carried carbohydrate, including an eligible mixed bundle; protein/water never become invented fuel.

Connection closure stops new dispatches and names remaining commitments. Stranding/isolation is a physical condition, not a path-cost label; route restoration or paid alternate travel handles it. **Acceptance:** worker/cargo/profile conservation across crossings, alternative courses, closures and interrupted return; normal UI receives no live remote cursor/stock/health.

### SYS-05 INWARD economy and functional chambers

**Purpose:** support more living dependents through deliberate local investments. Foundation: Queen/Nursery/Food Exchange/Entrance/Midden and climate jobs. M2 defines reusable projects/organs; M6 adds refuge. See [Chambers](catalogs/CHAMBERS.md).

Projects declare prerequisites, nutrition, construction workers/time, operating function and cancel/lock behavior. Capacity comes online after paid completion. Ongoing Nursery feeding/care/climate remains real while another organ develops. Upkeep/operating staff are distinct from construction workers.

Reproductive Alcove supplies paid group space; Ventilation Gallery improves the existing regulation job; Refuge protects explicitly supported occupants against a declared disturbance. Food Cache is gated by an observed buffering decision; current surplus alone does not justify a cap/spoilage tax.

Organs have local condition and typed state, while their presentation may unfold as functional lobes. No tunnel grid, materials economy or endless upgrade ladder. **Acceptance:** capacities and caregivers count once, project cancellation cannot reconstruct consumed stores, multiple piles use the same definition with independent ownership, and symptoms navigate to a useful response.

### SYS-06 Brood, reproduction and investment queues

**Purpose:** choose population growth, adaptation and reproductive continuity without catching a brief empty slot. Foundation: aggregate stages, care/feeding, Auto Brood, adaptation queue and immediate Home reproductives. M2 adds reproduction intent and explicit priority.

Keep at most one queued adaptation and one queued reproductive group per pile. The player names the next special investment; if both are pending and no explicit change was made, earlier queued intent has priority. Reordering/canceling is free until funding. Existing laid groups are immutable; no eviction of live brood or cancellation into free eggs/queens.

An eligible special investment gets the next usable space/nurse/food opportunity before new ordinary Auto Brood. Existing brood continues feeding/maturing. If the special order lacks structural eligibility (for example required development or an available group slot), ordinary growth can continue; queueing early cannot deadlock the prerequisites needed to become eligible. Show the exact waiting state. Once eligible, avoid repeatedly consuming its needed space with ordinary laying.

Laying validates nutrition, occupancy and care together; payment/commitment occurs once. Subsequent feeding remains required. The alcove helps scheduling but is not required merely to queue. **Acceptance:** Auto Brood can stay on throughout reproductive investment; adaptation/reproduction priority persists across saves; incapable/underfunded states never create free births or claim a funded outcome.

### SYS-07 Adaptation and inherited expression

**Purpose:** shape future capabilities at an opportunity cost. Foundation: six traits, trial nurses, phenotype bundles and founder traits. M3/M4 delivers the [ten-leaf web](catalogs/ADAPTATIONS.md) and broader lineage ownership.

Definitions supply family, eligibility/evidence, costs, exclusion/prerequisite rules and bounded named hooks. Preserve lean/load and security/tolerance exclusions. New care/environment/deposition traits have adverse or recurring costs. Chemistry is not familiarity; combat weight is not extra workers; recognition is not omniscient enemy detection.

Queueing does not convert adults. Laying captures cohort inheritance; larval effects explicitly belong to that cohort. Emergence/migration/loss changes actual carrier counts; departure snapshots determine travel/combat contributions. Imported adult phenotypes do not rewrite a laying queen's lineage.

The web separates revealed possibilities, queued intent, laid trial, established repertoire and current expression. Family hubs are free navigation. **Acceptance:** every trait changes a useful decision, mixed carriers conserve counts, no universally best stack emerges in the integrated comparisons, and maximum effects are not shown as current expression.

### SYS-08 Queen viability and lineages

**Purpose:** continue the colony beyond one founding queen while making loss consequential. Planned M4. Current queens are counts/captured founder traits, not a complete viability/replacement model.

Use aggregate queen records with identity, owned pile or transport party, supported condition, fertility/reproductive stage and inherited bundle. Local nutrition/condition can threaten viability; no arbitrary short lifespan timer is introduced to force an ending. Supporting/raising/replacing a queen spends actual resources, nurses, space and time.

Young queens/males are physical funded reproductives. Mating remains a coarse funded establishment process; no individual flight simulation. An eligible fertile young queen can replace a lost laying queen or establish a paid new pile, with one ownership transition and clear status. A queen in transit lays nowhere. Existing ready groups and viable brood can matter to queenless recovery.

Established daughters gain reproductive investment and can found later generations. Home's existing trial proxy migrates explicitly; living immigrants do not become the reproductive parent's traits. **Acceptance:** a lineage crosses a queen/nest generation, interrupted replacement/founding conserves queens/males/stores, and viable queenless recovery is not declared extinct.

### SYS-09 Sites, nests and network transport

**Purpose:** spread for access, specialization and resilience. Foundation: one daughter and exclusive supplies/settlers. Planned M5 generalizes owner IDs, site/connection records and rescue. See [Sites](catalogs/SITES_AND_SCENARIOS.md).

Returned site profiles describe coarse shelter/access/damp/exposure; founding still pays for actual investigation/occupation/preparation. A viable established pile may found another. Each pile owns its queen/brood/workers/stores/jobs and its report attention; initial shared returned colony knowledge remains the permitted model.

Supply and migration orders name payer, recipient, purpose, cargo/count and route. Reuse ledger transfers and captured traits at actual arrival. The same connection/cohort cannot simultaneously deliver food, move settlers and evacuate a queen. Conflicting traffic waits or is deliberately stopped and returned. Generalized definitions do not authorize automatic interruption or instant pack replenishment.

Isolation stops new traffic while local growth/food remains possible. Evacuation chooses real workers, eligible brood, a viable queen and transportable stores; one cohort has bounded burden/care. Deliberate abandonment records what was moved, left or lost. **Acceptance:** a three-pile network, daughter-origin founding, interrupted supplies and paid queen relocation all work without duplicates; loss of one pile can leave a viable lineage.

### SYS-10 Ecology, encounters and conflict

**Purpose:** make different threats require different decisions. Foundation: partners, rivals, a stationary predator, guests and surface impact. M6 completes [Ecology](catalogs/ECOLOGY.md), including a roaming predator and rescue-relevant disturbances.

Creature definitions compose a role, bounded physical movement/production, exposure, finite commitments and shared encounter rules. A roaming beetle uses a corridor/pause behavior with saved seeded decisions. Independent rival labor spends its own economy; any replacement-worker production is explicitly food-funded and bounded.

Survey → returned evidence → Clear/Hunt/reinforce/retreat → returned settlement is the huntable response. Low groups obey the existing retreat threshold; no ghost reporter reveals a result after all workers die. Rival reinforcement adds actual gatherers to the junction. Clear/displacement and a confirmed kill have different outcomes; only the latter yields remains.

Unassailable disturbance gets avoidance/isolation/refuge/evacuation actions, not a larger fighting button. Old settlement cannot cancel a newly reissued attempt. Threat pictures progress from supported clues, never hidden health/phase. **Acceptance:** useful counterplay and post-crisis recovery; attacks/physical relocation precede knowledge, and losses/pools conserve across saved interventions.

### SYS-11 Weather, local health and disturbance

**Purpose:** connect local care and exterior opportunity to changing conditions. Foundation: rain/heat, moisture/temperature, refuse strain, harmful guests and contaminated intake. M6 integrates site/zone/nest exposure.

Weather affects actual source production, exposed scent/water and local regulation. Current local rain/air can be sensed; future event schedules and remote source changes cannot. Site shelter shifts exposure without eliminating care or granting full immunity.

Keep separate causal owners for feeding shortage, missing care, climate strain, refuse health, guest-associated harm and contamination. Presentation can show several needs; clearing one cause does not hide another. Symptoms can be uncertain; suspect-source association cannot invent a chemical diagnosis. Carried contaminated food survives recall and recovery takes time.

Local ground disturbance needs an actual sensed response window and usable refuge/evacuation before lethal exposure. Hazard state describes the physical footprint/affected connection or occupants; no global damage pulse. **Acceptance:** mitigation uses labor/stores/space; multiple simultaneous causes remain diagnosable, and preparation/rescue retains physical assets and delays.

### SYS-12 Scenario chapters, viability and endings

**Purpose:** make a complete strategic run, not an indefinite collection of toggles. Foundation: three settings and voluntary physical review. Planned M7; authored composition is in [Scenarios](catalogs/SITES_AND_SCENARIOS.md).

Chapters emerge from real establishment, growth, adaptation, network access, a recoverable crisis and reproductive continuity. They do not force events based solely on elapsed playtime or grant a free resource to meet a narrative beat. Scenario schedules/seeded conditions are physical authored content and remain hidden until sensed.

Track recoverable, queenless-with-continuation, isolated-viable and genuinely unrecoverable conditions across all piles, viable brood/reproductives and real returning commitments. Internal truth may establish potential failure, but ordinary outcome notification waits for legitimate local/returned/absence knowledge; hidden deaths cannot trigger an early revealing end screen.

| Condition | Required interpretation |
| --- | --- |
| Shortage or labor stall | Living/returning workers or a genuinely supported emerging cohort can restore work. Explain food/care/space/traffic causes and available actions; do not declare extinction merely because stores or free labor are zero. |
| Queenless with continuation | A living eligible replacement queen or an actually funded viable reproductive group offers a supported path. A queued/unpaid wish alone is not a queen or a guaranteed recovery. |
| Isolated viable pile | Local queen/dependents/workers can continue while its connection is closed. Count that lineage independently; a lost Home cannot erase a viable daughter. |
| Unrecoverable lineage | No actual supported reproductive continuation exists anywhere, or all actual labor/emergence paths are irretrievably gone. Confirm all local/transit dependents and knowledge/absence settlement before notification; exact supported-path checks are scoped against implemented biology in M7. |

Recognize biological accomplishment/lineage continuation and offer continued play or voluntary review. Do not impose territory percentages or a mandatory session clock. **Acceptance:** no false extinction for carers/brood/queens in transit or a viable daughter; no hidden-resource safety guarantee or free recovery; revealed review remains separate from playable saves.

### SYS-13 Interface, communication and presentation

**Purpose:** clarity about intent under uncertainty about reality. Foundation: rotating OUTWARD, abstract INWARD, direct conflict circle and restrained audio/art. M1 starts consistent activation feedback; M8 performs final graphics/music.

Use a common hierarchy: identity/pile, condition, current order, action/cost/wait reason, expandable evidence. Names describe actual jobs and source types. An unavailable action stays understandable. A brief accepted/queued/rejected response is visible at the activated control; longer status persists where useful. Draft inspection and acknowledgment do not look like a dispatched order.

Report age distinguishes observation from receipt. Optional event-speed/pause behavior, if scoped, acts only on approved returned/local events and never hidden victory/death; reading menus must have consistent time behavior. Tooltips explain quantities/ownership/care and remain touch-accessible, not hover-only requirements.

Preserve darkness/negative space, capped representatives, thin trails and restrained effects. No bloom dependency or conventional minimap. Graphics resolve meaningful distinctions only when knowledge supports them. **Acceptance:** player can find/understand reinforcement, retreat, queue priority, transport conflicts and competing needs at standard/compact sizes; final audio does not obscure cues or make routine play fatiguing.

### SYS-14 Persistence, determinism and delivery

**Purpose:** make the complete game dependable on Windows. Foundation: strict saves, fixed ticks and headless owners; planned M9 package/release gates.

Keep definition identity/version separate from mutable state. Validate fresh state atomically before replacing the controller. Capture RNG, orders, partial travel, cohort traits and ownership; absent legacy fields have explicit safe defaults. Preserve the player's saved slot/settings; ending/restarting cannot silently overwrite them.

Bound journals, witnesses, representations and private replay storage with honest omission notices. No growing unbounded per-ant logs. Scenario content uses shared definitions and stable IDs. Tests are targeted, then one full final suite for code changes; docs use consistency gates.

Ship a reproducible pinned-engine Windows export, clear launch/control/save instructions, asset inventory and supported-machine evidence. Test upgraded/corrupt saves and mature network/crisis/review states. **Acceptance:** clean-machine player run and measured stated desktop performance; no editor paths, secret debug view, new paid dependency or claim based only on headless success.

## 4. Integration rules and handoff checklist

| Cross-system boundary | Rule |
| --- | --- |
| Resource → cargo → stores → brood | Withdraw/convert/deliver once; retain captured type/contamination; only real food funds laying and feeding. |
| Trait → brood → workers → travel | Capture inheritance at laying and departure; use ledger carrier counts; do not retrofit or duplicate phenotype bundles. |
| Chamber → capacity/care → queue | Paid completed capacity only; one occupancy and reserve calculation; eligible special investments get a fair opportunity. |
| Queen → founding/migration → pile | One physical owner/location; fertility/traits captured; no laying or presence at both ends. |
| Hazard → witness/local symptom → action → outcome | Physical event first, justified evidence second; counterplay pays and travels; aftermath can remain uncertain. |
| Network → isolation/evacuation → viability | Close traffic explicitly; count surviving local/transit continuation before failure; show knowledge rather than remote truth. |
| Private history → post-run review | Never a source for normal gameplay reports or forecasts; revealed state closes that play path. |

For every implementation card, specify its catalog/system IDs, visible benefit, dependencies, exact owned state/command changes, invariants/migration, known waiting/failure/recovery and targeted verification. A rule family earns reuse through one complete working entry before bulk content is added. Update Current Build and technical contracts only after actual verification; update the roadmap's completed milestone status with evidence.
