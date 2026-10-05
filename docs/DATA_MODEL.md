# Current state contracts

Baseline: gameplay through 139. Intended new schemas are in the [bible](SYSTEMS_BIBLE.md) and [catalogs](README.md), not implemented merely by this document. Detailed historical fields are [archive-only](archive/pre_1_0/contracts/DATA_MODEL.md); current validators/tests/source own exact shape.

## Persistent envelope and run

RunState snapshot version is **5**. SaveService envelope format is `antzenpile-run`, file version **1**, with SHA-256 payload integrity and a **4 MiB** limit. Saving verifies a temporary write before rename; load constructs/validates a fresh run atomically. The default slot is `user://saves/slot_1.json`; sound preferences are separate. End/new-run does not overwrite the player's slot.

The run owns scenario/seed, fixed clock, separate simulation/genetic RNG state, world, piles/ledgers, scouts/missions, observations/knowledge, routes/segments/cohorts, ecology/weather/health/founding/supply/reinforcement/response and bounded private history. Optional historical fields have explicit validated defaults; unsupported versions fail honestly. Saved worlds are restored, not recreated from the newest scenario definition.

## Authoritative accounting

- WorkerLedger owns living/available/lost and commitments. Per-job/route/cohort totals reconcile with it; they are not extra workers. Actual cross-ledger migration increments transfer history, not deaths. Population conservation accounts for real emergence/loss/migration.
- PileState has three nutrient stores (`carbohydrate`, `protein`, `water`), aggregate brood, current queen count, reproduction, development, health and genetics. There is no current concrete food inventory, generalized queen record or reproduction queue.
- Held worker-brood care is derived from occupancy/care configuration minus dedicated trial nurses, clamped safely. `workers_assignable` excludes held care. Reproductive nurses have their own commitment; new work uses `allocate_workers`.
- Brood captures stage/progress, trial/inherited traits and real losses. Genetics stores disjoint living/lost/imported/exported phenotype bundles. Existing established trait IDs are `lean`, `load`, `persistent`, `security`, `tolerance`, `fighter`; exclusive pairs remain lean/load and security/tolerance.
- Only owned unresolved losses are added back to expected population/expression presentation. Raw truth is never used as an instantaneous UI casualty count.

## World, observation and travel

139 adds optional physical `source_type`, confirmed Observation identity, derived KnownNode identity and persisted positive unique `label_index`. Empty legacy type remains unknown; legacy labels derive deterministically from first receipt. Saved typed identity must match the physical profile/nutrient and a confirmed observation; later broad evidence retains prior identity. TransitCohort optionally captures `harvest_report` under a unique logical observation ID, with route/owner/profile/counter validation; it creates no new worker. A surviving physical return delivers it through the existing inbox; the last lost carrier discards it. Source labels/type project from approved knowledge/producer history, never live stock.

World nodes have physical ID, definition ID, position, activity/quantity and authored contamination. Current ResourceDefinition supplies a broad stable ID. Observation records contain historical identity, estimated position/uncertainty, first/latest observation, proximity and mission ownership; validation checks identity without refreshing from current truth. KnownNode records observation/receipt/confidence/evidence links. Future source-type identification/mixed yields require explicit migration.

TrailRoute owns purpose/origin/destination, desired/allocated/active labor, receipts/depletion/loss/conflict knowledge. TrailSegment owns physical geometry/exposure and scent/familiarity. TransitCohort owns actual travelers, captured profiles/cargo/energy/contamination, causal loss and delivered evidence. Return/cancel cannot duplicate commitment or erase carried cargo. Installed alternate courses require paid returned establishment.

Current purposes include food/founding/interpile with owner-specific rules. Food cohorts cannot borrow expedition labor. Home/Daughter supplies and Home settlers are mutually exclusive on the shared connection. One paid founder activates one daughter through a real ledger/trait transfer; arbitrary site/pile networks are future schema work.

## Response and recruitment

JourneyOrders stores route-keyed whole force targets (zero cancels) and goals. New positive commands are bounded by the pile's known workforce; sent/initial/outcome/acknowledged counts no longer require fixed 12–24/four-worker steps. Twelve initially/four additional remain suggestions. One attempt clears on ending/recall; a lower sent total does not physically recall survivors.

Optional recruitment is exactly `{count, kind, all_hands, waiting, trail_target}` per owned food route. `kind` is defend/gather; `waiting` maps same-pile recalled food routes to reduced targets. A matching `response:<route>` other-kind pool holds at most the requested count. Defender count matches unsent intent; gather target/order cannot conflict with its active response. Orphan pools, malformed types, wrong ownership and inconsistent targets reject atomically.

JourneyResponse owns the shared party, private travel/sample/combat state and delivered survey/pressure/approach/ending records. Expected sent counts include unreported losses; private samples/phase are not projected. Active defense requires living reporters; cohorts/messengers/reinforcements reconcile with the origin's ledger and lifetime loss history.

## Chronology, bounds and compatibility

Validate finite numbers, integral counts, valid IDs/owners, chronology and capacities before mutation. Returned records cannot precede observation or exceed run time. Pending reports cannot become known through load. Lost/migrated phenotypes and queens/reproductives may not be copied between owners.

RunHistory is bounded private physical recording; ended state gates commands. Its storage limits/thinning are disclosed in review. The planned normal-play journal must be a separate knowledge/local-report store. New 1.0 content IDs, queued reproduction, generalized piles and queen migration each need a bounded migration/legacy test before shipping; no future saved fields are declared present here.
