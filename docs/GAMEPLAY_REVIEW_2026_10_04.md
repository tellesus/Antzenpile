# Antzenpile: gameplay and communication review

Consultancy review, 2026-10-04. Baseline: card 133, commit `036ab0b`. [Review card](tasks/134_gameplay_consultancy_review.md). Proposals below are recommendations, not accepted changes to gameplay or the release scope.

## Assessment

Antzenpile has a worthwhile central idea: spend living workers to turn uncertain evidence into a functioning colony, then decide how much risk to take for its next generation. Physical returns, imperfect memory, brood-derived adaptation and a second independently staffed pile give that idea substance. Preserve those features, the dark sensory panorama and the abstract interior.

The main weakness is the connection between a player's intention and the game's response. The game has acquired many useful systems, but players must learn separate conventions for ordering, waiting, recalling, interpreting and recovering in each one. A confusing decision can look like a broken simulation. A sound simulation can still produce a dull decision if the player cannot understand the alternatives or notice the outcome.

My recommendation is to make the existing game understandable and responsive before broadening it again. Start with truthful action labels, persistent returned reports, readable causes and recovery paths. Then evaluate the actual tradeoffs—scouting effort, source choice, fighting versus avoidance, growth versus expansion—using players who do not know the implementation. Do not begin with a broad resource rebalance or another major system.

The intended experience should be **uncertainty about the world, clarity about your orders**. The game should reliably answer: What do we know? What have I committed? What are we waiting for? What can I change? What did that decision achieve?

## Evidence and limits

| Evidence | What it establishes |
| --- | --- |
| Current design, implementation and selected prior evaluations | Ownership, actual rules, action semantics and existing design constraints. Historical findings are not automatically current defects. |
| Fresh Windows walkthrough before interruption | Unpaused opening, exploration initially off, five-scout assignment, acceleration, returned traces, shortage attention and selected carbohydrate context. The attempted gathering click was interrupted; successful live gathering was not verified. |
| Nine new ordinary-command runs: three settings × seeds 482817, 71, 3030 | Opening exploration, real gathering, Food Exchange/Nursery development and repeated worker growth over 1,200 simulated seconds. Decisions use detached local/returned information. No resources or discoveries inserted. All nine saved continuations and worker-ledger checks passed. |
| Fifteen new paired ambusher branches | Three existing ordinary paid scout/loss/survey preparations, each continued with clear/hunt at 12/24 workers or a three-worker alternate approach. Orders dispatched and concluded; these are narrow comparisons, not a complete combat balance study. |
| Current rerun of twelve ordinary rival branches | Avoidance, retry, reinforce after pressure and withdraw after pressure; zero evaluation failures, including exact continuation and conservation checks. |
| Full current headless suite | 8,405 checks, zero failures, recorded before reboot. This verifies tested behavior, not enjoyment or usability. |
| Four existing graphics captures inspected | Cards 125, 126, 130 and 131: threat preparation, alternate return, inherited fighting trait and Daughter supply. Useful supporting layout evidence, not a fresh graphical pass or proof of genuine compact-size readability. |

The remaining work was headless after the player needed the desktop. No further mouse, keyboard or game-window control was used. No player save was loaded or overwritten. No gameplay, rates, resources, scenes or engine settings changed. New graphical/import/Main gates were not run for this documentation-only review. The headless tools emitted environmental logging-directory messages on some launches; the completed measurements and rival evaluator exited successfully. An initial measurement harness used a wrong method name; it was corrected and the complete run repeated. A separate attempted ordinary post-defense recovery-watch reproduction encountered rival withdrawal instead of the required depleted state; it is excluded from measured conclusions.

New data: [measurements](evidence/card134_gameplay.json). The retained [measurement source](evidence/card134_measurement.gd.txt) can be copied to `.godot/gameplay_review_measure.gd` and run with the pinned console engine, `--headless --path . --script res://.godot/gameplay_review_measure.gd`. It writes ignored local output. Rival reproduction uses existing `tests/evaluate_conflict_counterplay.gd`. These policies are capable, attentive test players; they do not establish novice success rates. There was no new long-duration Daughter, audio-listening, accessibility-device or human playtest.

## What the measurements say

### Economy and exploration

| Setting | First protein report, by seed 482817 / 71 / 3030 | First worker emergence | Workers emerged by 1,200 s |
| --- | --- | --- | --- |
| Backyard | 40 / 45 / 50 s | 360 / 360 / 360 s | 40 / 40 / 40 |
| Garden Edge | 45 / 555 / 295 s | 360 / 715 / 400 s | 40 / 24 / 32 |
| Roadside | 40 / 45 / 50 s | 360 / 360 / 360 s | 40 / 40 / 40 |

The policy used five standing scouts, Auto Brood, five gatherers per needed resource, available safe remembered alternatives, recovery watches and voluntary withdrawal on known alarms. It developed Food Exchange before Nursery. Measurements were sampled every five simulated seconds; discovery/emergence times have that sampling resolution. The fixed observation window is not a proposed session length.

All nine colonies grew. Seven had no sampled feeding shortage. Garden Edge seed 71 had 71 shortage samples, and seed 3030 had eight: approximately 355 and 40 seconds at this sampling interval. Final stores varied widely, including 13.3–197.7 carbs across the nine runs. This supports improving diagnosis and the ability to redirect exploration. It does not establish that all resources are too scarce or too plentiful. The measurement also does not test the full cost of founding, expanded 32-space production, multiple traits and protracted conflict together.

### Combat and response time

The twelve clear/hunt attempts lasted 43.75–83.75 simulated seconds from dispatch to returned outcome. That is about 2.7–5.2 real seconds at 16×, or 0.7–1.3 seconds at 64×. Their first pressure reports arrived after 23.75 simulated seconds and described observations already 9.75 seconds old. A player can receive useful evidence and lose the opportunity to respond before reading it.

At 12 workers, clear and hunt each secured two of three branches; at 24 each secured three of three. Hunting sometimes added casualties and always required separate gathering to obtain its protein. The three bypasses returned two established approaches and one danger report. Thus these are real alternatives, not merely different names for guaranteed success. Three seeds are insufficient to set final costs or declare a dominant strategy.

Rival counterplay also changed outcomes. Withdrawing after pressure produced two reported losses and 27 delivered resources in each measured branch; committed retries produced eight to ten losses and 80–89 delivered resources. Reinforcement reduced losses in two seeds and did not improve the third. Preserve this choice between exposure and access; improve the player's opportunity to exercise it.

## Prioritized findings and recommendations

Priority **P0** means fix before the next broad gameplay playtest; **P1** means the next clarity/decision-quality milestone; **P2** means investigate after those changes. These are product priorities, not crash-severity labels. “Confirmed” identifies source or observed behavior; judgments and balance hypotheses are named explicitly.

### 1. Orders must say when they spend or commit — P0

**Confirmed:** threat force buttons show bare 12/16/20/24, but selecting one sets a standing order and can dispatch immediately. A separate “Send 12 Defenders” action remains. The panel invites the mistaken reading “choose a number, then press Send.” During shortages the same click instead leaves a waiting order. Other numbered controls represent repeating staffing targets, while a combat order funds only one attempt.

Make each immediate action explicit: **Order 16 defenders**, with “One attempt; departs when workers and travel food are available.” While away, name changes **Raise total commitment to 20**, not another anonymous number. Remove the duplicate 12-worker dispatch path. Display goal, current order, already sent and waiting reason together. Keep the accepted persistent-order behavior; a new confirmation dialog is unnecessary.

Apply a consistent vocabulary throughout: **inspect** is free; **assign** maintains a job; **order/send** commits a mission; **queue** waits for a stated trigger; **recall** requests physical return; **stop after trip** completes a cargo trip. Never imply workers become free immediately if they are still away.

Acceptance: before clicking, unfamiliar players can explain whether the action starts now, waits, repeats or merely inspects. Check funded, unfunded, paused, reinforcement-pending and returning states without exposing private arrivals.

### 2. Teach the opening through the first useful loop — P0

**Observed:** a new colony starts at 1× with exploration off. The visible advice is “Drag to turn. Tap a trace to listen,” before there are traces to inspect. Menu/save/sound controls are more numerous than active gameplay choices. Help exists, but it now spans nine sequential pages.

Add a short, optional contextual introduction: assign explorers → notice a returned source → assign gatherers → observe delivery → inspect feeding/growth. Each step should point to the existing control and disappear when its outcome occurs. Offer a “Why is the field dark?” explanation. Do not require a fixed source, seed, bearing or discovery deadline, and do not dispatch labor for the player.

Introduce INWARD when the player has a reason to inspect it, while leaving it accessible from the start. Explain that brood care is already held at Home and that the initial 38 available workers are part of a 40-worker colony. Keep the help guide as a reference with topic access, not the primary teaching mechanism.

Acceptance: a fresh player can bring a resource home and describe how it helps brood without consulting README. Test an early empty return and Garden Edge's slow discovery, not only the easiest seed.

### 3. Returned information needs persistence and enough reading time — P0

**Confirmed:** discoveries use a three-real-second footer message; later feedback can replace it. Selected contexts retain some evidence, but there is no unified player-facing list of important returned reports. Help/menu overlays block normal time-control input while simulation continues. Combat timing above makes high-speed decisions especially difficult.

Provide a small, bounded **Reports** history containing colony-known events only: new source, empty return, missing party, returned danger/pressure, completed project, emergence, and delivered outcome. Group repeated events and keep source/pile links. Use “observed” and “received” dates where their difference affects a decision. Preserve the existing restrained sound cues and never force the camera to turn.

Offer a clearly described preference to pause or reduce speed on selected important *returned/local* events. Do not react to hidden deaths or private victories. Help and menus should either permit Pause consistently or explicitly pause and restore the previous state. Avoid stopping for every routine scout return. Keep an unread cue until inspected; acknowledgement must not issue a gameplay order.

Acceptance: at 1× through 64×, a player can retrieve a pressure report, distinguish its age from receipt time, and make a reinforcement/withdrawal choice. Simultaneous reports remain accessible. This requires a knowledge-only report store; the private physical-history recorder must never back normal-play UI.

### 4. Warnings should reveal competing needs and actionable causes — P0

**Confirmed:** `ColonyPressure.attention` returns one preferred problem. Guest symptoms—including an ongoing clearing effort—precede food-sharing failures and other Nursery causes. Consequently the most prominent message can represent a response already underway while another need also requires attention.

Keep one restrained attention area, but show that more needs exist and let the player inspect them. Rank actionable worsening conditions above acknowledged work in progress; do not discard the latter. A selected warning should state **condition → consequence → available response**, with the correct pile named.

Example: “Larvae are waiting for protein. Browse remembered protein sources.” For care: “Two workers are needed at Home; recalled gatherers have not returned yet.” Keep uncertain loss causes uncertain. Local sanitation symptoms, suspected guest harm and food-sharing failures must remain distinct.

Acceptance: simultaneous guest clearing, missing protein and Daughter reserve waiting are all discoverable; clicking each opens the relevant existing controls. Recovery clears its own warning without hiding another.

### 5. Scouting needs an understandable job summary — P1

Standing exploration is a good fit for colony-scale play. Retain the explicit directional bias, real returning scouts, shared cap and learned avoidance. The problem is understanding what an effort setting is doing: general discovery, source rechecks and recovery watches share labor, while a manual mission follows a different rule.

Show current intent in plain language: “Five scouts assigned to ongoing exploration; two source recheck priorities.” List those priorities with their last returned result and allow removal locally. Explain that turning changes attention and **Favor this direction** changes search intent. Show shared Home/Daughter capacity beside effort choices only once a Daughter exists; the opening currently introduces “other pile effort 0” prematurely.

Use returned coverage to explain that ground has been searched without success; never promise a hidden resource is nearby. Consider a knowledge-based “Explore for missing protein” preference only if tests show existing need weighting plus directional guidance is inadequate. That would be a separately scoped behavior change, not an instant discovery button.

Acceptance: players can distinguish searching for new sources from revisiting one, recognize queued rechecks when effort is off, and adjust effort between piles without learning private scout positions. Measure idle waiting and repeated futile commands across the same nine opening conditions.

### 6. Source selection should support a resource strategy — P1

**Confirmed:** source names are hashes such as “Carbs #B5B5”; lists are ordered by internal knowledge ID. They expose last/first deliveries, but do not provide a good comparison of current assignment, recent return usefulness and known risk. A trace, a remembered source and a route are related but different concepts.

Use stable colony-assigned names such as **Carbs A**, plus a remembered direction and optional player nickname. Never adopt hidden world-object names. Preserve identity across sorting, saves and pile switching. Offer compact comparison by resource, current order, latest delivered/empty evidence, report age and known journey concern. Let the player sort by those known facts.

Explain the causal loop next to gathering: assigned workers repeatedly travel; resources enter stores only on arrival; more workers increase commitment and potential throughput, not source regeneration. Empty sources may retain assigned workers at Home. Make **Release idle gatherers** or the equivalent existing recall outcome clear so scarce labor is not silently parked.

Show recent observed intake with a stated measurement window if useful; do not turn it into a guaranteed production rate or hidden source stock meter. Distinguish carbs used for travel, larval food and climate water. Explicitly explain the existing recovery exception: carbohydrate trips can settle unpaid travel energy from their returning cargo; protein/water trips must wait for travel carbs.

Acceptance: players can select an alternative after depletion, explain where assigned workers are, and recover from zero carbs without guessing whether a carbohydrate departure is possible.

### 7. Recovery-watch promises must match their safety rules — P0, narrow audit

**Source-confirmed mismatch risk:** depleted routes offer **Watch and Resume Gathering** and confirmation says a fresh return can resume gathering. The automatic resume predicate additionally requires lifetime `reported_losses == 0` and `foreign_reports == 0`. A later addressed threat does not erase those histories. This is a conservative rule, but the current wording does not describe it.

Retain manual approval on risky routes. If the guard prevents automatic resumption, say **Watch for a new source report**, followed by “Gathering will stay paused; choose Resume yourself.” Distinguish exploration off, waiting for investigators, awaiting fresh evidence and awaiting the player's decision. Do not promise automatic recovery where the predicate forbids it.

The attempted ordinary post-defense reproduction did not reach the required depleted condition, so this is a source-level contract finding, not a demonstrated end-to-end post-clear failure. Before changing mechanics, reproduce dangerous, settled, newly dangerous and never-dangerous depleted routes. Deciding to permit automatic resume after settlement would change the accepted safety default and requires a separate design decision.

### 8. Make combat goals comparable and its aftermath useful — P1

The clear/hunt/bypass design is already stronger than a generic attack button. Explain each goal before commitment:

| Choice | Intended gain | Known commitment/tradeoff |
| --- | --- | --- |
| Clear journey | Try to displace the witnessed ambusher | Defenders and travel food; no protein reward |
| Hunt for protein | Try to kill it and reveal edible remains | Additional fighting risk; gatherers still collect finite remains |
| Test another approach | Seek a usable course around the corridor | Recall gathering first; three investigators and food; longer future trips; can return inconclusive/danger |
| Avoid | Stop further gathering exposure on this route | Resources must come from elsewhere; recall still takes time |

Keep rival contests distinct: reinforcement raises the gathering commitment at a contested crossing, not the dedicated ambusher party. Present the choice of continuing, increasing that commitment or withdrawing beside the last dated rival report. Unassailable disturbance should lead directly to avoidance/approach options, never offer a fight-shaped dead end.

Replace history-first combat panels with **current order → latest useful report → response → older history**. Show whether an outcome is historical, whether gathering is currently paused, and which explicit action can reopen it. Do not manufacture a live enemy count, health bar, victory prediction or certain return ETA.

Later balance work should compare food actually recovered, worker losses, time/labor tied up and effects on brood—not win rate alone. Test partial reinforcement after a readable report. The current sample does not justify buffing every defender or making bypass guaranteed.

Acceptance: a player can explain why they chose clear, hunt, bypass or avoidance, then find the follow-through action after return. Test failure, successful clearance without harvest, carcass depletion, fresh alarm after settlement and Roadside impact.

### 9. Growth and maintenance need visible opportunity costs — P1

The brood-care safeguard is a strong improvement; keep it. Auto Brood, climate regulation and cleanup also suit aggregate colony management. Their relationship is harder to understand than their individual controls.

In Nursery, distinguish **brood space**, **care workers held**, **current feeding**, **development stage/progress** and **environmental slowdown**. “Care supports 8/8 brood” is a capacity statement, not the number of workers assigned. Label elapsed stage progress as elapsed; do not leave a bare second count looking like time remaining. Show intrinsic remaining larval food separately from uncertain future gathering.

Before Nursery development, explain both extra capacity and the need to regulate the developed environment. Climate carers automatically humidify/air/cool under existing rules; do not ask players to micromanage modes the simulation already chooses. Show whether conditions are improving, steady or worsening from local observations and what extra staffing can change. Midden should similarly explain the consequence of burden and recovery lag rather than relying on a raw burden number.

Manual brood, ordinary Auto Brood and queued adaptation must state their different rules in the same place. Manual ordinary laying stops automatic repeats; an explicitly queued trial can still start when eligible. Existing brood continues consuming food. Do not silently change that accepted queue behavior to make the label simpler.

Acceptance: after a shortage or blocked order, players can identify food, labor, space or climate as the limiting factor and select a useful remedy. Paid development should feel like a strategic investment, not an unexplained new chore.

### 10. Adaptation needs a visible present benefit, not only a ceiling — P1

**Confirmed:** trait contexts show adult carrier counts and “up to” benefits. Strong Mandibles, for example, displays up to 2× contribution even when only eight of 56 adults carry it. The explanation that effects scale is correct, but leaves the player to compute the current importance.

Show three separate facts: **queued/growing/inherited**, **known adult expression**, and **effect on newly dispatched work at that expression**. Present a colony-known estimate where unresolved travelers make an exact current value inappropriate. Explain that already-departed cohorts retain their captured traits. For fighters, explicitly connect stronger emerged workers to the permanent extra feeding cost of inheriting larvae. For exclusive branches, name the alternative being closed off.

Replace “Other Traits” cycling with named family navigation—Foraging, Trail chemistry, Recognition, Combat—as space permits. Preserve free inspection and one selected-trait action. Keep the biological queue; do not convert it to instantaneous technology purchases.

Balance hypothesis: persistent chemistry may currently deliver a less noticeable benefit than its name and upkeep suggest. Inspect its actual effect on source interaction reliability, discovery and rain recovery before strengthening it or adding new powers. Assess recognition against both tending-labor savings and guest harm. The current guest model has no beneficial guest payoff; do not imply that tolerance is a rich diplomacy system yet.

Acceptance: a player can explain why their first trait cohort did not immediately give the whole colony the advertised maximum, and can identify the continuing cost of their choice.

### 11. The second pile should feel like expansion, not duplicated administration — P1/P2

The separate worker/store ownership, inherited founder traits and real supply connection are valuable. Source and historical evidence establish functioning Daughter growth; this review did not rerun a complete new founding campaign.

Provide one optional contextual network summary: Home and Daughter's known free/held labor, local need, outbound supply order and connection occupancy. Keep normal OUTWARD/INWARD attention switching and the abstract network. No physical minimap is needed.

In supply controls put **payer → recipient**, cargo, recurring assignment and stop behavior first. Worker settlers are a different action: eight stay; the ninth worker returns as messenger. A Daughter context can currently offer Home-funded settlers; make the Home payer unmistakable. “Pack … + traits” should explain that carrier traits modify transport, not suggest genes are cargo.

Describe the shared connection rule and offer navigation to the job that occupies it. Preserve the current explicit stop-and-return requirement; automatic interruption, configurable packs and simultaneous directions would change accepted decisions A74/A82 and are not part of the clarity pass.

The strategic question for later testing is **why found now?** Compare a colony investing the same resources in Home growth, adaptation, force or a Daughter. Evaluate independent intake, resilience and access, not just whether founding succeeds. Do not solve weak incentives by inventing a territory score or free resource bonus.

Acceptance: players know which pile pays every order, can support a shortage without accidentally exporting from that same pile, and can explain the value they expect from expansion.

### 12. Interior threats need diagnosis without misleading certainty — P1/P2

Guest harm, refuse-related brood health, heat/humidity and food-sharing failures can all interrupt growth. Keep their separate symptoms and remedies. Show observed losses and dates, current response and whether recovery takes time. Food-source receipts are particularly useful for tracing suspect intake; link to them without identifying a poison the colony has not detected. Warn that recalling a source does not erase incoming cargo already carried.

The guest model currently makes prompt paid rejection an attractive routine response once harm is observed. That may be appropriate for this prototype, but recurring identical rejection can become maintenance rather than strategy. First test whether players can diagnose it and whether recognizing it changes priorities. Only then scope richer guest tradeoffs from the original design. Do not add false positives, diseases or beneficial guests incidentally to this review's fixes.

Acceptance: players can distinguish “loss observed, cause unknown” from “foreignness associated with harm,” and can explain why improvement is gradual after removing a source of strain.

### 13. Organize UI around decisions and make explanations accessible — P1

Use a consistent context order: **identity/pile**, **current condition**, **current order**, **next useful action/cost**, then expandable **evidence/history**. Task-specific details should have more visual priority than Save/Load/Sound. Keep navigation stable across states; avoid reusing one button position for unrelated jobs without a strong label change.

Add short hover/focus explanations and a tap-accessible equivalent. The current principal views draw text and custom hit regions; there is no general tooltip/focus system to assume is already present. Plain-language explanations must be available without hover, especially for touch. Preserve 44-logical-pixel targets, readable body text and restrained effects. Reflow long sentences rather than shrinking them to fit.

Use semantic keyboard focus for the important controls and test scaling, contrast, focus visibility, long source names and color-independent danger cues. Keep cosmetic ants, sound and glow as supporting signals; critical outcomes must be readable in text. Audio mix, cue recognizability and listening fatigue require a separate listening pass. Do not claim a screenshot proves them.

Illustrative wording:

| Current wording/context | Proposed wording |
| --- | --- |
| 38 available | 38 free workers; inspect for assignments |
| Exploration labor; Off / 2 / 5 / 8 | Ongoing exploration; assigned scout target |
| Prioritize Source Rechecks | Keep checking this source; uses exploration scouts |
| Watch and Resume Gathering on a route barred from auto-resume | Watch for a new report; gathering stays paused |
| Bare force number 16 | Order 16 defenders |
| Earlier report only | Last source report: 2m ago; availability may have changed |
| Auto needs … | Automatic laying waits for …; existing brood continues |
| Pack … + traits | Base pack …; carrying traits modify the load |
| Up to 2× combat contribution | Up to 2× per carrier; current colony expression shown separately |

These are examples to validate in context, not a blanket string replacement. Keep Carbs/Protein/Water, gatherers, scouts, investigators, defenders, attendants, nurses and climate carers consistent across commands, rejections, guide and reports.

### 14. Progression and endings should explain the colony's story — P2, already on the roadmap

The current voluntary physical-history review is a useful foundation. It should eventually answer “what happened and what did the colony know at the time?” rather than merely show an unexplained physical map. Link milestones, orders, received evidence and outcomes after the run has ended, respecting sampled-history gaps. Do not expose that truth during play.

Retain the planned source-backed work on run continuity/endings. Do not add a premature defeat rule while viable brood, carers, recalled workers or another pile can recover. Give the player clear continuations and voluntary goals—sustained growth, an independently supplied Daughter, resolving a costly corridor—without turning optional achievements into locked victory rules or reinstating the tabled session-duration target.

Long-term replayability needs more than new seed labels: current scenario layouts are authored and a fresh seed changes behavior, not geography. Explain that in colony selection. Broader scenarios, reproductive generations and network/ecology expansion remain original-design work; they should follow evidence about what the current loop lacks.

## Recommended implementation sequence

Expand one bounded card at a time against the actual code. Do not prewrite a large backlog of speculative systems. The player has accepted the first clarity step before run continuity/endings, with these refinements: flexible worker counts with honest suggested sizes; conflict staffing from the alerted trail, then the nest, with explicit all-hands before other jobs; a circular radial conflict pop-over with unfolding returned status; evidence-based threat impressions; and a clear aphid honeydew introduction. Card 135 handles current order/recovery wording and the introduction. The integrated recruitment/response follow-up must implement the new worker policy before claiming it in the UI. No paid testing or screen monitoring.

| Stage | Bounded player-visible outcomes, in order | Exit evidence |
| --- | --- | --- |
| A — Trust the controls | Explicit force-order actions; accurate watch/recall/waiting language; Nursery cause/assignment explanations. Then make simultaneous local needs discoverable. | No misleading dispatch/auto-resume promises. Relevant funded/blocked/returning scenarios, approved-data boundary checks and standard/compact input/readability checks. |
| B — Notice and understand | Bounded returned-report history with links; consistent pause access and optional important-event interruption. Then the short contextual opening guide and topic-based help. | A novice completes the first loop; critical evidence remains retrievable at every speed; no private event triggers. |
| C — Choose a strategy | Source comparisons and exploration priorities; combat goal/aftermath organization; current trait-expression explanation. Then local growth/network commitment summaries. | Players can explain costs, ownership and plausible alternatives before acting, and recognize the result afterward. Existing mechanics remain conserved and headless. |
| D — Improve measured decisions | Focused feedback from the player's ordinary sessions and small targeted headless comparisons only where needed. Reuse existing measurements. Adjust demonstrated pacing, opportunity-cost or balance problems, then resume endings/completion. | Useful choices, viable recovery and less clerical repetition in the player's experience; acknowledge the limited sample. Publish each accepted tuning change with its before/after evidence. |

Stages A–C primarily improve presentation/approved summaries. Reports persistence and pause preferences need explicit ownership/save contracts. Any change to automatic recovery eligibility, supply routing, adaptive scout intent, trait effects or biological endings is a separately accepted mechanics change. Do not amend the decision register merely to record recommendations as though the player had chosen them.

## Playtest and acceptance plan

Player constraints accepted after the review: $0 budget, limited compute, no hired testers and no agent-driven computer use or screen monitoring. Use the player's ordinary sessions for short, specific questions from the table below; do not require recruitment or a research sample. Run focused headless regressions while changing behavior and the required full suite after final changes, reusing existing evidence instead of repeating broad evaluations. Ask for a targeted manual check only where perception or usability cannot be established headlessly. Record uncertainty rather than treating one person's feedback as statistical proof.

| Task | What to observe |
| --- | --- |
| Start with a dark field and bring food home | Time to first intentional scouting/gathering; whether Help is needed; mistaken expectations of live knowledge |
| Reach a feeding shortage with a returned alternative | Can the player identify the missing resource, choose a source and explain delayed delivery? |
| Exhaust a source with workers still assigned | Do they understand parked labor, watch versus manual recheck, and whether an order will resume? |
| Receive a loss/pressure report at accelerated speed | Can they find it, interpret its age, and choose withdraw/reinforce before another action becomes irrelevant? |
| Resolve an ambusher or learn an unassailable disturbance | Can they compare clear/hunt/bypass/avoid and follow through to useful gathering? |
| Have simultaneous Nursery and Daughter needs | Do they find both, identify payer/recipient, and avoid confusing supplies with settlers? |
| Queue and emerge a trait cohort | Can they explain its delayed, partial expression and continuing cost? |
| Recover a stalled viable colony; voluntarily end another | Do they distinguish recovery, waiting and actual closure; understand saved-slot versus revealed-run behavior? |

Track mistaken commitments, repeated futile clicks, time spent unable to name a useful action, unnoticed reports, help lookups and whether a chosen strategy achieves its stated goal. Ask “What do you expect this button to do?” before selected high-risk-for-confusion actions, then compare the answer with the actual behavior. Ask which moments felt tense, satisfying or like chores. Do not substitute task completion for enjoyment.

For balance, compare paired seeds and equal starting state across smaller/larger forces, hunt/clear/bypass/avoid, low/high exploration effort, tending versus alternate carbs, Home growth versus Daughter investment, and trait choices versus ordinary brood. Include scarcity, failure, withdrawal and recovery. Record worker opportunity cost, resource intake after travel, brood progress, casualties and command burden. Broaden beyond three seeds before concluding one option dominates.

Each implementation card follows the normal targeted → final full-headless → affected import/Main/graphical gates. Human review, keyboard/accessibility and audio listening remain distinct evidence. No mobile production or fixed session-time target is implied.

## Recommended next action

Begin with the accepted bounded **order clarity and recovery wording** outcome from Stage A, including aphid honeydew introduction. Next address the player's flexible staffing and direct conflict-response feedback, then reports/time-control clarity. Preserve the source-backed desktop completion plan and keep testing within the $0, headless-plus-player-feedback constraint.

## Implementation evidence map

| Finding | Current owners / inspection anchors |
| --- | --- |
| Force numbers dispatch; duplicate action | [OUTWARD](../src/presentation/outward/outward_view.gd), `_run_command`, `_draw_journey_context`; [journey response](../src/sim/ecology/journey_response_system.gd), `set_force`, `_fund_orders` |
| Initial effort, priorities, shared cap | [exploration state](../src/sim/scouting/exploration_state.gd), default `target`; [GameRoot](../src/core/game_root.gd), `exploration_summary`; OUTWARD `_draw_exploration` |
| Ephemeral messages / modal pause access | [discovery notice](../src/presentation/returned_discovery.gd), `poll`; OUTWARD `show_feedback`; [colony controls](../src/presentation/colony_controls.gd), `_input`; GameRoot `interaction_blocked` |
| Single preferred pressure | [colony pressure](../src/presentation/colony_pressure.gd), `attention`; GameRoot `pile_internal_attention` |
| Source identity, comparison and receipts | [source memory](../src/presentation/outward/source_memory.gd), `entries`, `display_name`, `receipt_label`; OUTWARD `_draw_sources` |
| Recovery watch's history guard | [trail system](../src/sim/trails/trail_system.gd), `tick`; OUTWARD `_investigation_title`; GameRoot `toggle_investigation_priority` |
| Combat timing, dated pressure and outcomes | Journey response `_send_messenger`, `_tick_messenger`, `_arrive`, `summary`; [rival evaluation](../tests/evaluate_conflict_counterplay.gd) |
| Care/food/space and queue semantics | [brood system](../src/sim/colony/brood_system.gd), `production_status`, `remaining_food_reserve`, `tick`; [INWARD](../src/presentation/inward/inward_view.gd), `_draw_context` |
| Current trait expression | INWARD `_draw_genetic_context`; [adaptation web](../src/presentation/inward/adaptation_web.gd), `trait_state`, `queue_wait`; [adaptation rules](../src/sim/colony/adaptation_rules.gd) |
| Supply ownership / exclusive connection | [supply system](../src/sim/colony/interpile_supply_system.gd), `set_enabled`, `summary`; INWARD `_draw_supply_context`, `_draw_reinforcement_context`; decisions A74/A82 |
| Distinct interior threats | [guest](../src/sim/ecology/guest_system.gd), [food sharing](../src/sim/colony/food_toxicity_system.gd), [sanitation](../src/sim/colony/sanitation_system.gd), [brood health](../src/sim/colony/brood_health_system.gd) |
| Truth separated from player reports | [physical history](../src/core/run_history.gd), [ended-run viewer](../src/presentation/run_review.gd), [desktop release path](DESKTOP_RELEASE_PATH.md); decision A83 |

Before expanding a card, recheck these against its actual starting commit. Keep simulation decisions free of display strings in new contracts and preserve the authoritative worker ledger. Older documentation sometimes describes superseded behavior: for example, card 116's stalled manual brood predates card 128's care safeguard. It is historical evidence, not a reason to reintroduce that behavior.
