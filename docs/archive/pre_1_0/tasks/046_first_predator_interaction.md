> **ARCHIVE ONLY — frozen 2026-10-04.** Historical record; not an active plan, current contract or implementation instruction. Use the [current documentation](../../../README.md). Original path: `docs/tasks/046_first_predator_interaction.md`. Historical status and recommendations below apply only to their recorded build.

# 046 — First predator interaction

Status: complete (2026-10-01). Depends on 045. Source: GDD Part 4 §§57–63 and 144.

## Bounded outcome

Add one stationary ambush zone near the honeydew route. After it attacks, the colony eventually gets a loss/alarm report on that remembered route and may stop its traffic and move labor to another source, or keep foraging with fewer surviving workers. Rerouting around a zone and optional combat are later expansions; this first response uses the existing meaningful source/labor choice.

## Contract

- Author one zone at (29,27), radius 2 m, first active at tick 1200, with one casualty per attack and a shared 120-tick recovery. These are provisional fixtures. Attack only aggregate route cohorts in this first prototype; scouts and tending labor are outside the encounter model. Each cohort has at most one encounter opportunity per journey; stable cohort order settles simultaneous opportunities without extra creature agents.
- Apply real death immediately via the pile loss API and reconcile route allocation/active counts. Select the adapted subset with the seeded run RNG from the aggregate live share, without per-worker genomes. A killed carrier loses any payload beyond surviving carry capacity. Preserve the remaining travel/return timing and captured departure phenotype.
- Store private casualty/adapted-casualty counts on the cohort. A wholly lost cohort retains only a bounded expected-return record with zero travelers/cargo; it cannot collect or deliver scout evidence. At its expected home time the colony can infer missing workers but cannot identify the predator. Survivors likewise deliver their loss count only at home. Sum returned plus private casualties against the predator's saved attack history.
- Until that report, normal pile and route summaries retain expected worker counts, including unresolved losses, and expose no zone/timer/predator object. Commands use those expected commitments when changing a labor target so hidden deaths do not silently recruit replacements. A returned loss may leave desired labor above actual survivors; there is no automatic replacement.
- Show a restrained alarm cue and returned-loss line on the known source trace. Keep depletion separate. Existing Cancel/Stop Traffic recalls survivors and blocks departures; a safe alternative source provides avoidance. No omniscient danger map, creature HP bar, or attack command.
- Optional version-5 fields default to no losses/predator encounters for older saves. Validate loss counts, zero-traveler records, route/ledger agreement, attack recovery, report times and true/known totals atomically. Save across an encounter and across its delayed report exactly.

## Verification

Test an ordinary scout→honeydew route→encounter→returned loss, no early knowledge/UI leak, shared saturation, singleton/full-cohort loss, cargo/phenotype rules, cancellation and safe-source avoidance, target changes while a report is private, pause/speed, legacy snapshots, and exact save continuation. Test mouse/touch response and inspect standard/compact contexts. Run final headless suite, import and Main smoke once; document the contracts and commit the complete interaction.

## Completion evidence and handoff

- Implemented authored stationary threat/recovery, seeded ledger/adaptation casualties, survivor cargo limits, zero-traveler expectations, delayed route alarms and expected-count presentation. Existing mouse/touch Stop Traffic and a remembered alternative source form the player response.
- Focused encounter suite: **42 checks, 0 failures**. Final full pinned suite: **4212 checks, 0 failures**. Import and headless Main had no script errors. Windows Compatibility graphical probe captured and visually verified 1280x720 and 900x600 contexts; alarm text and Stop Traffic fit without bloom. Sandbox log/editor-settings/root-certificate warnings remain environment limitations. Android/device performance and audio cues were not tested here.
- Changed groups: predator definition/state/system and controller/run serialization; trail/cohort loss settlement and commands; detached root summaries and OUTWARD alarm controls; encounter tests/registry and reproducible graphical probe; contract docs.
- Limitations: one stationary threat; no attacks on scouts/protection labor, combat or alternate route geometry. Alarm remembers cumulative returned losses and does not imply the threat is still present.
- Next: early visual-quality proof from GDD Part 7A, bringing organic sensory clouds, animated thin chemistry and capped representative ants to the now-distinct mutualism/predation evidence. Keep economy/session tuning tabled.
