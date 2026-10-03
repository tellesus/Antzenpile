# Combat/conflict review — 118

**Verdict:** the ambusher response is a coherent playable loop. Rival conflict has useful response choices but confusing recruitment/aftermath. Guest rejection works once found, but its warning does not lead clearly to that response. Improve those connections before expanding warfare. This review changes no gameplay or rates.

Windows, pinned Godot 4.7.2 Compatibility/Radeon RX 6650 XT, 2026-10-03. These are command-driven comparisons and inspected renders, not a human enjoyment test or a broad balance verdict.

## Existing loops

| Trouble | Colony evidence | Response | Closure | Assessment |
| --- | --- | --- | --- | --- |
| Journey ambush | Returning survivors report attacks; absent witnesses establish missing workers without a cause. | Recall gatherers; pay three workers for a survey; after returned localization, send twelve defenders, reinforce or recall. | Returned survivors/losses and “Ambusher driven off”; renewed gathering tests recovery. | Complete and understandable in the dedicated panel. |
| Rival crossing | Returned foreign chemistry, then a physical messenger reports contested traffic. | Recall gatherers or raise their target in four-worker steps; travelers join through actual travel. | Returning groups report withdrawal or foreign withdrawal. | Mechanically functional; repeat recruitment and competing panels obscure the next decision. |
| Harmful nest guest | Local brood loss is initially uncertain; repeated harm becomes internal foreignness. | Commit four local rejection workers; stop/resume the effort; recognition traits affect later encounters. | “Guest purged”, released labor and no further damage until a new intrusion. | Response/outcome are clear in Guest context; finding that context is the weak link. |
| Scout absence | Overdue/expected-return missing status, with unknown cause and remembered departure. | Recall a living mission, change exploration effort/direction, use standing caution learned from returned journey losses. | Actual return or settled absence; successful delivered defense clears future caution. | Uncertainty is intentional. An unreturned scout cannot identify a killer or authorize a localized attack. |

Producer tending increases output and is separate from route defense. Local disease, climate and contaminated food have their own evidence/remedies; the UI must not imply every loss is a combat casualty.

## Current measurements

### Rival response — fifteen ordinary continuations

Three seeds (3048, 3030, 482817) use actual directional exploration, returned source memory and ordinary gathering. Each seed branches at its first **returned contested report**, then runs 600 simulated seconds. No inserted knowledge, resources, workers or enemy manipulation. These windows compare responses; they do not prescribe a session length.

| Response from five-worker target | Returned rival-loss range | Additional net cargo | Result |
| --- | ---: | ---: | --- |
| Keep current target | 2 | 70–76 | Nine bouts per seed; repeated withdrawal/contested reports. |
| Raise target to 9 (+4) | 8 | 35–57 | No secured report; seven/eight bouts, one assigned survivor left. |
| Raise target to 13 (+8) | 5–7 | 90 | Secured report after 110.5–178 seconds; one to three later contested reports. |
| Raise target to 17 (+12) | 5–7 | 90 | Secured report after 110.5–178 seconds; zero/one later contested report. |
| Recall on the warning | 1 | 1 | Withdrawal returns after 8.5 seconds; all assigned workers eventually released. |

The recall loss had already occurred privately before the first warning; recall does not undo it. Reported deaths are measured from the warning, not from the private start of fighting. Stronger target settings are comparisons, not recommended fixed balance values. Finite-source depletion also ends traffic in the successful high-staffing branches. The existing combined-ecology regression independently demonstrates that +4 **can** win in another ordinary colony state (one player loss versus four rival losses); arrival timing, prior traffic and seeded rounds matter.

### Guest response — three branches of the same local symptom

Seed 5050, ordinary starting colony, first observed loss at 1260 seconds. Over the following 260 seconds, prompt rejection preserves seven of the eight original brood (one total encounter loss), waiting sixty seconds for foreignness preserves six (two losses), and no rejection leaves three (five losses). Prompt purge is observed after 36.25 seconds; delayed purge after 102.25 seconds from the initial warning. All branches continue exactly after loading.

At both first loss and foreignness, OUTWARD only offers **CHECK NURSERY / CARB** in this run. Removing Guest from the detached summary leaves attention unchanged. Nursery shows the total brood losses but gives no explanation/link to Guest; Guest itself explains foreignness and offers rejection. The returned exterior alarm count remains zero, since its provider counts exterior losses only. Thus unrelated feeding pressure can hide the actionable internal conflict.

### Ambusher recovery and other coverage

Re-ran the ordinary three-seed defense/early-recall/no-defense comparison. All completed defenses drove off the ambusher, with 4/1/0 defensive deaths. Reopened gathering had zero additional ambush deaths versus four per untreated/early-recalled branch over 180 seconds. Net cargo varied with other ecology (20/2/1 after defense versus 10/4/9 untreated); removing one threat does not guarantee more overall intake. The shared predator and independent rival traffic remain distinct.

Current full-suite tests also cover locally paid daughter defense, casualty ownership, missing scouts, learned caution, recognition tradeoffs and fresh guest recurrence. Earlier [daughter defense](DAUGHTER_DEFENSE_EVALUATION.md), [scout caution](SCOUT_CAUTION_EVALUATION.md) and [recognition comparisons](BALANCE_EVALUATION.md) remain supporting evidence; their longer evaluators were not rerun here.

## Findings and recommended order

1. **High priority — connect observed guest harm to rejection.** Add a persistent, voluntary local-loss cue to existing attention. First loss stays “cause uncertain”; only actual association permits “foreignness”. Nursery should link to the observed Guest context, including when food/health pressure coexists. Clear active harm after purge and keep encounter history separate. Test simultaneous causes, recurrence, standard/compact navigation and absence of private diagnosis. See [OUTWARD warning](evidence/card118_guest_outward_900.png) and [Nursery detour](evidence/card118_guest_nursery_900.png).
2. **High priority — give rival reports their own response context.** The generic Journey Reports and Response link currently opens the ambusher survey panel after explicit foreign-ant fighting. It offers a paid danger survey, omits rival reinforcement controls and says no defensive return even after a foreign withdrawal. Keep unknown/mixed danger survey available, but show the delivered rival outcome and recall/reinforcement controls together for known fighting. Explain that reinforcement commits more gatherers, takes travel and cannot reverse already incurred losses. See [rival detour](evidence/card118_rival_journey_900.png).
3. **High priority — make rival resolution and renewed conflict meaningful.** Even after the rival commitment falls to its two-worker retreat threshold, arriving cohorts can form a fresh contested swarm; it immediately resolves secured when the rival joins, with no additional casualties. The successful response still displays JOURNEY ALARM, while historical foreign chemistry makes the plus button continue to say “contest”. After withdrawal, positive gathering intent likewise causes repeated recruitment. Separate dated resolved fighting from current returned alarm; suppress no-contest escalation at the existing retreat threshold. Review whether automatic retreat should suspend contest recruitment pending a renewed player order. That latter behavior would change the current standing-traffic default and needs an explicit follow-up decision, not a silent change in this review. Do not expose enemy numbers or promise permanent safety. See [returned foreign withdrawal with alarm](evidence/card118_rival_heavy_response_1280.png).
4. **Medium priority — explain committed reinforcements and recovery.** The ambusher panel still offers Request 4 Defenders while its one reinforcement batch is traveling; clicking again rejects “No further reinforcement can be dispatched”. The dispatch is already known locally, so show that batch as committed and block duplicates without revealing its remote position/survival. After returned success, offer an obvious return to gathering controls while retaining player control over reopening traffic. Existing defender travel, uncertain outcomes and nonrefunded recall costs are meaningful and should stay.

Suggested bounded follow-ups: (a) known local-loss attention/Guest navigation; (b) rival report/response/aftermath presentation plus pending-reinforcement wording; (c) rival re-engagement review and regression-backed correction after settling the standing-order behavior. Re-run response comparisons after each relevant change; then conduct a human playtest before broader combat tuning. Resume daughter-to-Home supplies afterward. No new combat species, soldiers, omniscient battle view, broad economy rebalance or session target is needed to address these findings.

## Verification and reproducibility

- Final headless suite: **6,982 checks, zero failures**; includes combined ecology, both piles' paid defense and evidence/save/ledger contracts.
- New `tests/evaluate_conflict_review.gd`: **118 checks, zero failures**, fifteen rival and three guest branches, every quarter-second matched restored twins. [Raw review rows](evidence/card118_review.json); [current ambusher comparisons](evidence/card118_ambush_recovery.json). Passing integrity checks do not mean the discovered usability gaps passed a gameplay quality gate.
- `tests/probe_conflict_review.gd`: **28 rendered contexts**, actual mouse/touch input-event navigation at standard and compact window settings, zero navigation/capture failures. Inspected representative warning, survey, away/pending, victory, Guest/Nursery and rival detour frames. Compatibility, bloom-independent presentation; no touch-device or frame-rate claim.
- Pinned editor import passed without script/resource errors. Main smoke was not repeated: no runtime/scene/resource behavior changed; graphical probes launched the actual Root/views. Full headless suite ran once after final review-script changes.
- Reproduce with the pinned engine using `--headless --path . --script res://tests/evaluate_conflict_review.gd`, followed by `--path . --script res://tests/probe_conflict_review.gd`. The evaluator creates the ignored checkpoints required by the probe. Ambusher comparison: `tests/evaluate_journey_defense.gd`. No fixtures require the committed screenshots.
