> **ARCHIVE ONLY — frozen 2026-10-04.** Historical record; not an active plan, current contract or implementation instruction. Use the [current documentation](../../../README.md). Original path: `docs/INTERFACE_REVIEW_PLAN.md`. Historical status and recommendations below apply only to their recorded build.

# Interface review and improvement plan

Reviewed 2026-10-02 against the published card-084 build. The review below records the original issues. Its three implementation passes are now complete: [085](../tasks/085_interface_actions_and_input.md), [086](../tasks/086_interface_guidance_and_history.md), and [087](../tasks/087_interface_readability_and_navigation.md). Each card records changed groups and actual verification.

## Original findings

The selected-context approach, distinct chamber/trait treatments, visible INWARD stocks, and restrained sensory art work well. Improve clarity within that structure rather than adding a dashboard or changing the panorama.

| Priority | Observed issue | Proposed improvement |
| --- | --- | --- |
| High | Dragging the text/background of Exploration or a normal source context rotates the panorama underneath. Confirmed with both mouse and touch. | Absorb pointer gestures across the entire panel, including gaps between buttons. Only the exposed sensory field should rotate. |
| High | Honeydew buttons say **Tend Producers**, but INWARD descriptions, feedback and the ecological leaf still say **protection**. That suggests a defense against journey attacks. | Use tending consistently in player-facing text and rejection messages. Explain that tending supports production; the returned journey report offers a separate defensive response. |
| High | **Prioritize Investigation** and **Investigate Journey** look like variations of one action. One directs recurring scout rechecks; the other sends a paid three-worker survey for danger. | Use distinct labels, such as **Prioritize source rechecks** and **Survey journey for danger**, with the labor/purpose beside each. Explain that prioritizing does not immediately dispatch workers when standing exploration is off. |
| High | After a successful defensive return, the source still emphasizes earlier attacks. Journey Response places the old ambusher survey alongside **Ambusher driven off**, without clearly separating history from the newer response. | Make the latest delivered response prominent and date/group older evidence as history. Preserve past losses, uncertainty and separate harvest/survey/defense counts. Hidden victories must not update the display before return. |
| Medium | **Invest 5 Workers**, **Cancel**, **Stop Traffic**, plain plus controls and two kinds of reinforcement obscure which job receives or recalls labor. Some actions explain travel food but give little preparation guidance. | Name the job: assign/recall gatherers, recall survey party, reinforce defenders or contested gathering. Show known labor requirements and understandable local rejection reasons. Use only approved preparation information, never hidden terrain costs or battle state. |
| Medium | Queen text says **Manual laying skips the food check**, which can imply free feeding. **Brood intent**, **Grow**, bare reserve-wait messages and disappearing laying actions require knowledge of the implementation. | Explain manual laying versus automatic repeat broods, continuing food demand, and local reserve waiting. Keep unavailable actions understandable with their current reason. Clarify brood space, care capacity, and climate-worker roles without changing those rules. |
| Medium | **Increase Rejection** starts a fixed worker assignment rather than increasing a selectable strength. Adaptation buttons use **Security/Tolerance** while selected leaves use different names; **expressed**, **Alternative** and maximum bonuses need interpretation. | Name the actual guest job and staffing. Match trait action wording to the selected leaf, explain inheritance in future brood, distinguish maximum effects from current colony expression, and state when the other family choice is already inherited. |
| Medium | Source receipts use **Home 5.0 · … · first …** without a resource or clear meaning. **Memory 2/3**, **Loaded before**, bare scout target numbers, and raw seconds make comparison harder. | Give remembered sources stable colony labels, name delivered resources, separate last delivery from first recorded delivery, and label scout target versus ants away. Use consistent elapsed-time formatting and honest missing-history text for old saves. |
| Medium | Compact contexts have very small text; Nursery controls/cost text are crowded. Food-loss guidance is separated by a large gap. **Colony** leads to help and restart controls together, while **Back to Colony** has different destinations. | Reflow dense contexts without shrinking hit targets. Put explanations beside the relevant action. Give the guide direct access, make the colony-menu destination explicit, and distinguish returning to the network from returning to the menu. |

Related copy: standardize Carbs/Protein/Water terminology; clarify that FOOD attention means carbohydrate memories where that is its actual filter. Replace **Living workers** with wording that does not claim a certain census of ants still away. Normal counts continue to include unresolved travelers. Review short-lived footer messages so important blocking reasons remain visible in context.

## Implemented sequence

The three bounded cards follow the sequence below. They introduce no mechanics or balance changes.

1. **Panel input and action wording.** Fix the confirmed mouse/touch gesture leak; align tending, survey/recheck, labor assignment, rejection, brood and trait language across panels, feedback and help. Keep existing action routing and simulation validation. Use shared panel bounds rather than an interface-framework rewrite.
2. **Decision guidance and returned history.** Group dated harvest, survey and defensive receipts; show the latest returned response on its source context. Improve delivery labels and local blocking reasons, including care/space/reserve constraints and required available workers. A dispatched reinforcement is a known command, not evidence that it arrived: do not infer arrival, eligibility or surviving strength from private combat state. If a request can be rejected only by private state, retain an honest request/result interaction rather than exposing that state through a disabled button.
3. **Readability and navigation.** Reflow the standard/compact contexts, reserve space between labels and controls, shorten repetitive copy, and improve guide/menu destinations. Preserve free graph inspection, one selected trait action, negative space, thin trails, pause behavior and at least 44-logical-pixel controls.

Likely affected areas: `src/presentation/outward/outward_view.gd`, `source_memory.gd`, `src/presentation/inward/inward_view.gd`, `adaptation_web.gd`, shared root/status/input contracts and guide text. Presentation receives detached knowledge/local summaries. Any new command-reason or summary contract must stay headless and avoid display text embedded in simulation rules.

## Verification and evidence

Review evidence: 48 fresh desktop captures at requested 1280×720 and 900×600 sizes across the general audit, recognition probe and ambusher-response probe; 18 representative captures visually inspected. Covered Queen reserve waiting, full/expanded Nursery, Midden, Guest, food losses, stocks, repertoire/recognition, tending, sources, Exploration, guide/sound/menu, and returned defense. General rendering checks preserved simulation snapshots; separate pointer checks reproduced both panel gesture leaks with mouse and touch while leaving simulation unchanged. Existing recognition/defense probes passed in their isolated fixtures. No player save was modified.

For implementation, verify:

- Panel drags do not rotate/select the field behind them; exposed-field drags still rotate. Exercise both shared mouse/touch paths, panel buttons, mode changes and modal dismissal.
- Every action has a distinct purpose and correct existing worker/resource commitment. Test insufficient local labor/food, full Nursery, reserve waiting, active trial, inherited opposing choice, and unavailable reinforcement requests.
- History remains dated after new outcomes, old saves do not fabricate receipts, and privately won/lost encounters cannot change normal information before delivery. No source quantities, renewal forecasts, hidden costs or live combat telemetry enter the UI.
- Visually inspect dense standard/compact states, long names, active/blocked actions and help navigation without bloom. Desktop touch-path checks do not establish Android usability.
- Run targeted checks during changes, one final full headless suite after final code, Main smoke for runtime changes and import only for changed/new resources. Record actual checks in each card.

No code changed during this review, so the full suite/import/Main gates were not repeated solely for this plan. Screenshots and temporary audit scripts are ignored development artifacts under `.godot`; their observations are recorded here. Human playtest and Android checks remain separate follow-up evidence.

Handoff: 085–087 complete this plan. Resume the next original-design milestone when further development is requested; human playtesting and Android usability are still separate from desktop evidence. No balance or art overhaul was included.
