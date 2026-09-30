# Post-slice development plan

Proposed 2026-09-30 after tasks 027–028. This is a sequence and set of decision gates, not an approved balance pass or a license to implement future systems together. Expand each numbered card against the code immediately before building it.

## Design basis and current gap

The repository's durable documents distill GDD v0.2 Parts 1–8 and the Part 7A visual lock. Part 6 calls for resources with physical producers, finite/renewable/episodic lifetimes, recurring environmental schedules, and colony learning from repeated experience. Part 5 makes later adaptation compete for brood, protein, nurses and time instead of a research currency. Part 7 keeps OUTWARD a knowledge-based sensory panorama and INWARD a functional organ network.

The implemented colony can repeatedly raise brood and develop Food Exchange, but Food Exchange is its only chamber investment. In the task-026 scripted run, water temporarily stops the second cohort while carbohydrate and protein accumulate. Task 027 adds one hidden, periodically renewing nectar source, and task 028 lets a depleted trail explicitly recheck it. Rain remains one-shot. The original 20–30 minute human-play target has not been validated. These findings justify adding choices and ecological variability before adjusting rates.

The full original Part 3 chamber specification is not archived in this repository. Recover or confirm the intended next chamber's function before turning the interior proposal below into an executable card; do not infer costs and effects solely from the current surplus.

## Recommended order

| Card | Bounded outcome | Acceptance emphasis |
| --- | --- | --- |
| 029 — Next interior project contract | Specify one next functional development from the original chamber design. The existing Nursery is the leading candidate because repeated brood already creates a clear use for its function. Lock what it changes, its opportunity cost, labor and time commitment, and how it appears in INWARD. This is a short design/card step before code. | Benefit affects a decision the player already makes; no arbitrary store drain or generic purchase menu. Resolve save compatibility before new state is added. |
| 030 — Implement that project | Add only the approved chamber transition and its one gameplay effect, authored cost, authoritative state, ledger labor, INWARD action and save continuation. Add a music change only if the chamber design calls for it. | Resource payment and worker conservation are atomic; effect appears only after completion; existing disk saves remain loadable through a defined default or migration. |
| 031 — Episodic exterior source | Add one physically explained, authored event from Part 6, such as a temporary food spill or pet feeding. It appears, expires and can recur in the hidden backyard. Keep source IDs and schedule deterministic and bounded. | Scouts/foragers discover physical changes through ordinary interactions. Old reports can be stale; normal UI receives no event schedule or hidden quantity. Test save/reload across appearance and removal. |
| 032 — Temporal evidence | Let successful/empty returns and repeated observations support cautious recurrence knowledge. Provide a deliberate way to investigate a previously known source, while the default scout behavior still seeks new sources. | No prediction from authored event data. Timing hints require repeated colony evidence and express uncertainty; false certainty and instant hidden-world refresh are forbidden. |
| 033 — Recurring pressure | Extend a proven environmental disturbance, starting with rain, to recur on an authored schedule or physical trigger. Preserve exposed-pheromone versus familiarity behavior and the modest water benefit. | A later event creates a route/labor choice, not just another cosmetic effect. Deterministic event order, pause/speed and save continuation hold. |
| 034 — Integration and playtest | Run a longer command-driven scenario and a human Windows playthrough through multiple brood cycles, the new chamber, source appearance/disappearance and recurring pressure. Inspect readable UI and frame cost with bounded effects. | Record decision time separately from simulated time; log route choices, idle workers, resource stores, stalls and missed signals. Only then propose targeted balance changes. |

## Later expansion gate

After card 034, decide whether the core colony loop has enough tension and clarity to support a first narrow Adaptation Web slice. Its first trait must have a biological cost and tradeoff, propagate through brood over time, and preserve genetic potential versus current workforce expression. Ecological relationships, rivals, satellite piles, dispersal, human attention and reality replay follow only when their dependencies and player-facing purpose are specified. Do not scaffold all of them at once.

Across every card, retain headless fixed-tick simulation; run-owned seeded state; aggregate workers except individual scouts; worker-ledger conservation; separate TrailRoute and TrailSegment; return-only knowledge; detached normal-view data; versioned saves; negative space and mobile-safe rendering. Keep provisional amounts in authored data and label them as such.
