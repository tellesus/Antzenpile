# Resource and source catalog

Current 1.0 design. Shared rules: [SYS-03](../SYSTEMS_BIBLE.md#sys-03-resource-sources-and-nutrition), [SYS-04](../SYSTEMS_BIBLE.md#sys-04-trails-travel-and-cargo). Delivery: [M1/M2/M6](../ROADMAP_1_0.md). [Current build](../CURRENT_BUILD.md) distinguishes physical foundations from planned type support.

## Rules family

A **source type** describes an actual object or producer. A **source instance** is one physical patch/object with position, remaining portions and activity. A **memory** is dated evidence about that instance. A **trail** is a labor/travel commitment to it. These are four different things.

The colony retains three nutrient stores: carbohydrate, protein and water. Specific foods provide one or more nutrients after actual processing/delivery. Adding a food does not add a new currency or a separate item inventory. Cargo retains the captured source type, harvested portions, output bundle and contamination provenance needed for correct settlement.

Shared source lifecycle: unavailable → active → worked → depleted; producer renewal/temporary expiry can change reality without changing memory. Reports may be partial, confirmed, stale, empty or associated with loss. Source depletion, trail danger and tending are independent facts. A depleted producer can later renew; a finite carcass cannot secretly regenerate.

### Definition template

| Field | Meaning and rule |
| --- | --- |
| Catalog ID / runtime ID | Stable type identity; never reuse an ID for a mechanically different food. Catalog IDs below are design keys. Runtime IDs are assigned in the implementing card. |
| Player name / descriptions | Concrete recognized name, coarse unidentified cue, gathering/tending explanation and known handling tradeoff. |
| Nutrient roles / portion yield | Authored C/P/W output per harvested portion. Sum need not be one: stores are game nutrition units, not grams or real caloric chemistry. Conversion is fixed per captured portion. |
| Bulk / handling | Carry burden, harvesting time and optional Food Exchange processing modifier. No special subsystem just to rename a source. |
| Availability family | Finite, producer, wetness-fed or episodic. Reuse a tested lifecycle and authored deterministic renewal/expiry rules. |
| Exposure / terrain | Whether local rain/heat affects new production, evaporation or accessibility. No normal UI forecast of hidden schedules. |
| Relationship | Optional tending/competition content ID; gatherers, attendants and defenders remain separate jobs. |
| Identification evidence | Coarse cue and sufficient returning sample/witness. No name pulled from a hidden object merely because a designer named it. |
| Contamination compatibility | The source can carry physical contamination when authored; the colony learns symptoms/associations through reports, not this definition's truth. |
| Save and tests | Stable type/profile version; portions/output conservation, exact return, knowledge aging and old-save fallback. |

### Identification and labels

Use “Sweet trace”, “Protein trace” or “Water trace” while identity is unresolved. A returning close sample can establish “Flower nectar”, “Ripe fruit” or “Insect remains”. The visible name records the **best justified identity**, not a continuously refreshed world label. A later broad/stale report must not erase an established identity, but may change availability confidence.

For duplicate known types, use knowledge-owned labels such as “Ripe fruit A” and a remembered direction. Optional player nicknames are presentation/knowledge metadata, never world IDs. Hashes such as “Carbohydrate #B5B5” cease to be the primary name. A player name does not disclose location, quantity, purity, freshness or a species that was not sensed.

The first migration preserves old saved worlds. Generic legacy definitions remain generic until valid new evidence exists; no silent reassignment of a saved protein node to a particular insect. Fresh scenarios author concrete type IDs. Keep three resource filters for nutrient roles, with multi-yield sources appearing where appropriate rather than duplicating their workers/cargo.

## 1.0 content roster

Yield ratios are **initial design seeds**, not verified balance or literal biology. C/P/W denotes carbohydrate/protein/water per game portion. Existing rates/costs remain unchanged until their implementation/balance card explicitly changes them.

| ID / recognized type | Seed C/P/W | Availability and handling | Decision and identity evidence | Status |
| --- | --- | --- | --- | --- |
| RES-NECTAR — Flower nectar | 1 / 0 / 0 | Producer; small easily carried portions; exposed output responds to hot/dry conditions. | Reliable energy near a flower patch versus exposure and tending-independent renewal. Close returning plant/nectar sample establishes identity. | Partial: renewing nectar exists; typed identity/profile planned M1/M2. |
| RES-HONEYDEW — Aphid honeydew | 1 / 0 / 0 | Living producer; attendants improve future output; gatherers transport it. | Spend labor supporting a dependable producer, while separately handling route threats. Witness/sample establishes aphids and sugary droplets. | Foundation: wording/tending/production; modular type migration M1/M2. |
| RES-FRUIT — Ripe fruit | 1 / 0 / 0.25 | Finite soft food; moderate bulk; accessible while physically present. | Mixed energy/water during dry conditions versus a temporary patch that can run out. Returning pulp sample establishes fruit, not its hidden remaining lifetime. | Planned 1.0 M2/M6. |
| RES-SEED — Cracked seeds | 0.4 / 0.6 / 0 | Finite dry food; heavier handling per portion than nectar; cracked/soft material avoids a separate milling industry. | Persistent but slower mixed nutrition; carrying/food-sharing choices affect usefulness. Close sample distinguishes seed pieces from an unidentified food trace. | Planned 1.0 M2/M6. |
| RES-INSECT — Insect remains | 0 / 1 / 0 | Finite accessible remains; ordinary harvesting and real return. | Protein for growth without requiring a hunt; still exposed to other foragers and route danger. Carried/witnessed remains establish coarse identity. | Partial: generic protein sources exist; concrete identity M1. |
| RES-HUNT — Hunted arthropod remains | 0 / 1 / 0 | Created only by a real confirmed kill; finite; reuses remains gathering. | Higher-risk food acquisition competes with merely driving a predator away. A surviving returning witness establishes the kill/remains. | Foundation: finite carcass after Hunt; modular profile M1/M2. |
| RES-CRUMBS — Picnic crumbs | 0.8 / 0.2 / 0 | Episodic, finite mixed food; appearance/expiry are authored physical events. | Exploit a temporary opportunity versus risky human-associated ground; the name is learned from a close returning sample. Contamination is not advertised by the name. | Partial: timed carbohydrate crumbs exist; mixed profile M2/M6. |
| RES-DEW — Dew drops | 0 / 0 / 1 | Small wetness-fed portions; exposed water evaporates; bounded local production without a full weather-fluid simulation. | Nearby opportunistic water versus a larger more durable source. Returning liquid/plant-surface evidence supports the name. | Planned 1.0 M6. |
| RES-PUDDLE — Rain puddle | 0 / 0 / 1 | Finite water, physically refilled by rain and reduced by hot/dry conditions. | Larger intake with weather dependence; rechecks discover changes. A close returning ground-water sample establishes identity. | Partial: rain-fed/exposed water exists; type M1/M6. |
| RES-SEEP — Sheltered seep | 0 / 0 / 1 | Slow renewing water; more sheltered than a puddle, possibly beside a damp nest site. | More dependable water access competes with journey length/damp-site care. Returning sheltered-ground evidence supports the type. | Planned 1.0 M6. |

Two entries sharing a nutrient ratio still need different availability, handling or relationship rules. Insect remains and hunted remains differ by creation/risk/evidence; puddles, dew and seeps differ by scale/exposure/renewal. Do not create five cosmetically different nectar resources as separate mechanics.

## Processing, travel and safety

1. Actual harvest withdraws portions from the physical source once. Capture their source/profile and yield in the cohort.
2. Carry and handling constrain the actual trip; Food Exchange processing acts on arrivals, not on a live remote stock estimate.
3. Resource intake occurs at the owning pile after travel; local stores receive the captured bundle once. Lost or delivered cargo cannot be counted twice.
4. Current carbohydrate travel-debt recovery remains viable. Mixed food may settle debt only from actual carried carbohydrate output; protein/water components never become free travel energy.
5. Stopping a trail prevents new departures and requests recall. It does not erase carried contaminated food or teleport cargo into stores.
6. Changing a type/profile requires a migration rule for already captured cargo. Old cohorts must not change their nutrition retroactively merely because an authored definition changed.

## How a new resource earns inclusion

Specify a distinct choice, reuse an availability/handling family, add approved identification copy and verify an ordinary trip/recovery. Record nutrient and worker conservation, delayed knowledge, contaminated intake where applicable, pause/speed and saved continuation. Establishing catalog schema is not permission to add spoilage, stock caps, milling or beneficial microbes in the same card.

Post 1.0: large food taxonomy, fungus cultivation, full seed-processing chains and separate mineral/material economies. Nest projects continue to use the established nutrition/labor abstraction in 1.0.
