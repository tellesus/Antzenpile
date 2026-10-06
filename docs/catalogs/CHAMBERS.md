# Functional chamber catalog

Current 1.0 design. Shared rules: [SYS-05](../SYSTEMS_BIBLE.md#sys-05-inward-economy-and-functional-chambers), [SYS-06](../SYSTEMS_BIBLE.md#sys-06-brood-reproduction-and-investment-queues). Delivery: [M2/M6](../ROADMAP_1_0.md). These are functional organs in an abstract network, not a tunnel-building game.

## Rules family

A chamber type declares a function, its supported projects/jobs, capacity and prerequisites. A pile owns a chamber instance's condition/development and its actual commitments. The player chooses an investment or staffing target; a named owner validates, pays and advances it. Existing chamber behavior is retained during refactoring.

Projects share proposed/waiting → funded/developing → complete states. Drafting or queueing pays nothing; funding commits real stores, workers and time. Existing care/climate/feeding continues during development unless the project explicitly states a temporary consequence. Completed development releases construction labor; running staff are a different commitment. Refunds release unspent or actually returned assets, never recreate resources already used.

Every organ uses the same context hierarchy: identity/pile → current function/condition → order/commitment → action and cost → evidence. The Adaptation Web is a genetic/experience view; it is not a chamber purchased as a building.

### Definition template

| Field | Contract |
| --- | --- |
| ID / function | Stable content ID and practical player decision. |
| States / prerequisites | Valid states, discovery/development requirements and owned dependencies; no invisible instant upgrade. |
| Capacity contribution | Exact spaces/throughput/protection contribution and how it combines with existing capacities. Count a slot once. |
| Projects | Costs, construction workers, duration, effects and cancellation/refund semantics. Values are authored; new magnitudes require a bounded card. |
| Operating jobs | Staffing range, provisional suggestion, running resource costs and physical release/recall behavior. |
| Local evidence | What the colony can sense locally, what waits for a remote report and which warnings lead here. |
| Side effects / tradeoff | Capacity competes for food/care; regulation uses labor/water; protection consumes space/maintenance. |
| Owner / save | Typed state owner, ledger pool, valid combinations and migration from old flags. Do not store a second worker total in a scene node. |

## Existing organs to preserve

| ID | Function and supported features | Development/staffing | 1.0 work |
| --- | --- | --- | --- |
| CH-QUEEN — Queen | Worker brood intent, reproductive investment, lineage/queen viability and replacement. | Existing Auto/manual brood and reproductive costs remain; saved reproductive/adaptation priority implemented in [143](../tasks/143_reproductive_investment_queue.md). New lifecycle states come through SYS-08. | Partial; queue works with Auto Brood, viable replacement/continuation remains M4. |
| CH-NURSERY — Nursery | Aggregate egg/larva/pupa occupancy, feeding/care, local health and climate. | Primitive/developed/expanded capacities already exist; further development is a paid project, not an endless level ladder. | Foundation; move capacities/projects into explicit definitions and account for reproductive subspaces. |
| CH-EXCHANGE — Food Exchange | Converts delivered nutrition into feeding; reveals shortages and recent receipts. | Existing paid development/feeding efficiency; running food demand remains real. | Partial; support captured mixed yields and readable intake/feeding distinction. |
| CH-ENTRANCE — Entrance | Local departure/return, current supply/migration/evacuation commitments and connection navigation. | Physical route jobs pay local workers/food. | Partial; multiple connections and named transport actions, never simultaneous reuse of the same cohort. |
| CH-MIDDEN — Midden | Refuse isolation, cleanup, development and brood-health recovery. | Existing cleaners/development remain; flexible staffing uses actual care-protected labor. | Foundation; current basic/developed performance stays explicit, symptoms and actions remain separate from guest/toxin causes. |

## New 1.0 organs

### CH-REPRODUCTIVE — Reproductive Alcove

**Implemented M2 in [144](../tasks/144_reproductive_alcove.md).** A paid Nursery extension supplies eight dedicated reproductive spaces alongside existing worker capacity. Authored provisional project: 24 carbohydrate/12 protein/8 water, four care-protected builders, 90 seconds. Queueing is free; funding pays once; cancel pending/developing work releases builders without refunding spent food; completed space stays locked. Saved independent pile projects and chronology validate atomically.

The alcove adds physical occupancy capacity only after completion. Nurses, laying payment and feeding still come from the pile. An unbuilt alcove does not block queueing: the reproductive order can wait for existing eligible space. Existing eggs/larvae are never evicted to honor a queue. Queen controls remain the place to select reproductive intent; the alcove shows occupancy/care, avoiding duplicate purchase actions.

Decision: spend nutrition/work/time on predictable reproductive scheduling versus expanding worker capacity. Verification: a queued reproductive group can start with Auto Brood on; capacity is counted once across Nursery/alcove; no free nurses, future food guarantee or extra queen before emergence.

### CH-VENTILATION — Ventilation Gallery

**Implemented M2 in [145](../tasks/145_ventilation_and_local_effort.md).** A paid extension improves regulation by up to 50% per actual worker/water use, with integer steps rounded down. Provisional project: 24C/12P/8W, four care-protected builders, 90 seconds. No passive cooling/moistening or extra workers; only completion activates the hook. Staffing and humidifying/cooling water remain with their existing owners.

Its target is a practical alternative to continually increasing climate workers in an exposed/hot or damp site. It must not erase site character or give complete weather immunity. The existing Nursery regulation remains usable before this project completes.

Verification: paired hot/damp ordinary piles show a bounded benefit and a real construction opportunity cost; the same staff and water cannot be charged or credited twice.

### CH-REFUGE — Refuge Chamber

**Planned M6 after evacuation.** A paid protected local space for a viable queen and a bounded amount of brood during a physically approaching disturbance. A shared refuge capacity limits what can shelter; safe evacuation through a connection remains a different action. Protection mitigates the authored hazard's exposure, not all mortality or contamination.

Local preparation occupies space and requires carers. A warning allows voluntary prepare/evacuate; no omniscient alarm is triggered by a hidden hazard before a witness/local symptom. Refuge does not teleport the queen, transfer the lineage to another pile or create a permanent invulnerable colony.

Verification: preparation preserves named living occupants under the supported hazard, unsheltered exposure remains possible, and interrupted shelter/evacuation saves conserve queen/brood/worker ownership. Implement the hazard and usable response as one coherent handoff.

### CH-CACHE — Food Cache

**Gated M2; historical storage gate retained.** Include only after an ordinary episodic/mixed-food run demonstrates an intake/reserve bottleneck with a useful chamber choice. A meaningful cache would buffer eligible arrived portions or improve explicitly limited processing; it would show what is buffered and what staffing changes. It cannot reveal remote source stock or secretly rescue unpaid travel.

The current stores have no demonstrated capacity problem. Do not add a punitive cap/spoilage timer just to make this chamber necessary. If the evidence fails the gate, record the result and keep CH-CACHE out of 1.0's release blockers. Legacy deferred card 034 is evidence/history, not an unfinished command to implement blindly.

## Capacity and recovery checks

- Worker brood, reproductive brood and refuge occupants share the pile's explicitly owned capacities; each has one authoritative location/occupancy.
- Care is derived from actual dependent brood and dedicated nurse assignments. No chamber gives carers a second identity or exempts all-hands from the reserve.
- A project can wait for food/labor; it does not reserve unavailable resources by silently deducting negative stores.
- Inherited care/climate traits change eligible physiological/job formulas through their whitelist, not project geometry or free capacities.
- Multiple piles can own identical chamber definitions with separate condition, stores, projects and jobs.
- The visual network can gain an organ/sub-lobe without inventing a physical tunnel floorplan.

Post 1.0: arbitrary extra levels, seed mills, fungal gardens, material-production chains and detailed excavation/ventilation geometry. Add a new organ only when its function creates a distinct decision under the shared rules.
