# Antzenpile 1.0 roadmap

Current plan, 2026-10-05. Supersedes the archived post-slice, interface and desktop release plans. The [systems bible](SYSTEMS_BIBLE.md) owns rules; its [catalogs](README.md) own concrete content; [current build](CURRENT_BUILD.md) owns implemented status. This roadmap owns order and release gates.

## The release promise

A player can learn an uncertain world, feed and develop a colony, make inherited tradeoffs, raise reproductives, establish a useful nest network, survive a crisis through real counterplay, and continue its lineage beyond the first queen/nest. Biological accomplishments and genuine unrecoverable failure have clear endings/review without forcing a fixed session duration.

The release foundation is a small complete game: generational continuity; multiple independently staffed piles with physical connections; four ecological roles (partners, competitors, huntable predators, unassailable disturbances); ten concrete resource profiles and ten trait choices; functional chamber growth and recovery. Counts describe a content/design coverage target, not an arbitrary gameplay cap. Parameters may change after focused evidence, with rationale recorded.

Windows desktop comes first. Keep touch-sized controls. Mobile, a fixed session-length target, detailed mating flights, latent-genome drift, large species catalogs and campaign travel are Post 1.0. No paid playtesting or new paid tooling; existing art/music gets its final pass after systems settle.

## Milestone order

M0 is complete in [card 138](tasks/138_roadmap_and_systems_bible.md): 14 system families, 46 catalog IDs mapped, 854 local links and 192 archive records checked. M1 is in progress (source identity complete); M2–M9 remain planned. None of their missing features exists merely because it is listed here. Expand one independently useful card at a time, with a player outcome, owning state/commands, knowledge projection, save rules and verification. Do not create unused frameworks for later milestones.

| Milestone | Player outcome and required scope | Dependencies | Exit evidence |
| --- | --- | --- | --- |
| M0 — One current design | New bible/roadmap/catalogs, implementation baseline, current technical references, archive-only history and working navigation. | Actual 136/137 build and accepted player scope. | Catalog/system/milestone coverage, link/status/archive checks; no runtime changes. |
| M1 — Understand and direct work | Concrete known-source identities, stable readable labels, flexible ordinary gathering/tending/care where appropriate, shared order/wait/cancel language, persistent returned/local reports, competing warnings and scout-priority summary. Consistent activation feedback starts with this next interface pass. | Current ledger, knowledge, trails and source definitions. | No hidden identity/stock/loss leak; exact saved orders/labels; mouse/touch semantic paths; player can retrieve simultaneous reports at four speeds. |
| M2 — Schedule growth and develop organs | Queen reproduction queue works with Auto Brood; visible, cancellable next-investment priority; real space/nurses/food gates. Modular chamber/project records; Reproductive Alcove and Ventilation Gallery. Food Exchange handles resource yield bundles. Evaluate a Food Cache only under its explicit bottleneck gate. | M1 orders/source identities; current brood/project/care owners. | Queue is not starved by automatic laying; paid projects preserve existing care/occupancy; cancel/lock behavior saves exactly; concrete foods enter the same three nutrient stores without duplication. |
| M3 — Meaningful adaptation web | Definition-driven six existing traits plus Efficient Nurses, Heat Resilience, Moisture Resilience and Rapid Trail Repair; evidence/compatibility/tradeoff details and current expression. | M2 cost/care/food contracts; existing phenotype ledger. | Each new trait has a useful pressure and a real cost; mixed cohorts/counts and captured travel traits reconcile; no instant adult conversion or universal best choice. |
| M4 — Queens and reproductive continuity | Queen viability, paid replacement, fertile young-queen establishment using aggregate mating, daughter reproductive groups and inherited reproductive lineage. Reuse queued scheduling and simple trait bundles. | M2 queue, M3 trait definitions; existing founding/reproduction. | Same lineage crosses a queen generation; failure/withdrawal refunds only real unspent/returned assets; no copied queens/males/traits or accidental sterilization of viable saves. |
| M5 — A useful nest network | Multiple site profiles/piles, founding from an established daughter, local ownership/jobs, connections with shared segments where needed, deliberate supplies/migration/closure. Paid worker/queen evacuation and abandonment operate before lethal network hazards ship. | M4 portable viable queens/lineages; M1 reports; current route and ledger foundations. | Home plus two daughters and a later-generation founding work; transport conserves workers/queens/cargo/traits; isolation and interruption recover through real travel; expansion has practical value. |
| M6 — Ecological variety and crisis | Complete source profiles; partner/rival content families; stationary arthropod plus roaming beetle hunter; generic heavy traffic upgraded with supported witness cues; localized tainted ground and a surface/nest disturbance. Refuge Chamber supports preparation/evacuation. | M1 source/report rules, M3 expression, M5 isolation/evacuation. | Every hazard has a discoverable symptom and usable response; no instant toxin/species recognition; predator relocation is physical; transport/nest hazard and recovery conserve assets across saves. |
| M7 — Complete runs and balance | Integrate Backyard/Garden Edge/Roadside with distinct sites/resources/risks and opening→growth→expansion→crisis→continuity chapters. Define recoverable/queenless/isolated/unrecoverable states; biological accomplishment and voluntary continuation/review. | M4–M6 implemented. | Purposeful paired player-directed runs compare Home growth, adaptations, fighting/avoidance and expansion; genuine failure accounts for brood, queens, all piles and unresolved returns; no false extinction or hidden-event ending. |
| M8 — Final presentation | Final graphics/music, type-specific source/threat impressions, evolving chamber/web presentation, concise onboarding, accessible text and responsive controls. Retain the accepted circle and refine its feel with player feedback. | Systems/content stable through M7. | Player graphical/audio checks of standard/compact and mature/network/crisis states; controls communicate accepted/queued/rejected actions and ages; no new gameplay inferred from art. |
| M9 — Ship Windows 1.0 | Reproducible export/package, separate saves/settings, content/asset inventory, upgrade/corruption handling, measured final performance and release regressions. | M8 complete; pinned engine/templates available. | Clean-machine player launch/start/resume/save/review/exit; defined desktop/resolution measurements at 1×–64×; mature network/long-run/resource bounds; full suite and release checklist recorded. |

## Content coverage by milestone

| Family and entry IDs | Milestone and status |
| --- | --- |
| RES-NECTAR, RES-HONEYDEW, RES-INSECT, RES-HUNT, RES-PUDDLE | M1 identifies existing physical foundations; M2 normalizes yield handling. |
| RES-FRUIT, RES-SEED, RES-CRUMBS, RES-DEW, RES-SEEP | M2 supports profiles; M6 authors/completes distinct behavior. Crumbs already have a temporary-source foundation. |
| CH-QUEEN, CH-NURSERY, CH-EXCHANGE, CH-ENTRANCE, CH-MIDDEN | M2 refactors existing functionality without silently changing costs. |
| CH-REPRODUCTIVE, CH-VENTILATION | M2 planned additions; each solves a stated scheduling/climate decision. |
| CH-REFUGE | M6 after M5 physical rescue exists. |
| CH-CACHE | M2 bottleneck experiment; Gated 1.0, excluded as a release blocker if no concrete decision is demonstrated. |
| AT-LEAN, AT-LOAD, AT-PERSISTENT, AT-SECURITY, AT-TOLERANCE, AT-MANDIBLES | M3 registry/web migration of existing effects/IDs. |
| AT-NURSES, AT-HEAT, AT-MOISTURE, AT-REPAIR | M3 new inherited tradeoffs, then M4 lineage integration. |
| ECO-APHIDS, ECO-RIVAL, ECO-AMBUSH, ECO-GUEST, ECO-HEAT, ECO-RAIN | Existing foundations; M6 modular definitions/content and M7 balance. |
| ECO-ROAMER, ECO-TAINT, ECO-HEAVY, ECO-NEST | M6 planned complete behaviors; generic contamination/impact foundations are partial. |
| SITE-LOAM, SITE-ROOT, SITE-STONE, SITE-EDGE | M5 distinct returned sites; M6 climate/hazard integration. |
| SC-BACKYARD, SC-GARDEN, SC-ROADSIDE | M7 upgrades the three existing settings; M8/M9 finish/test them. |

Ten resources/traits mean named distinct entries using common rules, not ten independent simulation engines. A catalog variant reuses the same tested state transitions. Physical object instances receive knowledge-owned identities only after evidence returns.

## Next bounded card

**M1-A complete:** [139 returned resource identity](tasks/139_returned_resource_identity.md), five source profiles, delayed sample identification, stable knowledge labels and atomic old-save fallback. Full gate 8,805 checks/0; import/Main/headless source drawing passed. Mixed yields and remaining profiles are still future work.

**M1-B complete:** [140 reports/needs/feedback](tasks/140_reports_needs_and_feedback.md), a bounded delivered/local journal, grouped receipts, saved read state, free navigation, simultaneous needs and common control cues. Final full 9,043/0, import/Main/headless drawing passed.

**M1-C complete:** [141 flexible gathering commitments](tasks/141_flexible_gathering_orders.md), whole initial/edited targets, care-protected unsent staffing, explicit draft/ORDER and real recall at both piles. Full 9,089/0; import/Main/headless drawing passed. Casualty deficits never silently create replacement intent.

**Next: [142 source comparison and scout intent](tasks/142_source_comparison_and_scout_intent.md).** Compare only known intake/age/order/risk and show standing exploration/priorities clearly; finish appropriate ordinary staffing before M2. The next INWARD systems pass is M2 and must include queued reproductive investment; do not replace it with toggling Auto Brood off. Player graphical/feel checks defer to the feature-complete systems beta (A88).

## Release acceptance and cost discipline

- M1–M7 deliver game decisions before art/audio production expands. Each card includes useful presentation and headless verification; these are not separate invisible simulation-only handoffs by default.
- Use targeted semantic scenarios and saved twins while iterating, then the full headless suite after final runtime code. Run only gates affected by subsequent changes. Documentation-only cards use link/coverage/consistency checks.
- The player supplies specific visual/feel/audio and clean-machine checks. No computer-use/screen monitoring, hired testers or large parameter sweeps.
- Measure performance using bounded in-game logs/probes and player runs; headless correctness does not prove renderer or audio quality. Choose stated desktop hardware before claiming a performance gate.
- Use existing immutable Godot definitions and typed owners. Catalog modularity does not authorize addons, a universal scripting/effect language, individual worker simulation or paid assets.
- Review values when a meaningful choice is absent. Record the observed problem, bounded adjustment and comparison. Do not impose a surplus cap to justify a chamber or force a fixed run duration.

## Deliberately after 1.0

Mobile packaging/device optimization; detailed mating flights, individual genomes, latent-trait drift/reselection; large animal/species catalogs and detailed human behavior; beneficial-guest diplomacy; large automated logistics empires; comprehensive annual seasons/campaign/destination travel; fungi/seed-processing industry and arbitrary new currencies. These remain visible longer-term options, not unfinished release requirements. Strong evidence or a direct player instruction can change this boundary in Decisions and the roadmap together.
