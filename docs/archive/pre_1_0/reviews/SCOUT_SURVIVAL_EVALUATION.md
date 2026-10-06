> **ARCHIVE ONLY — frozen 2026-10-04.** Historical record; not an active plan, current contract or implementation instruction. Use the [current documentation](../../../README.md). Original path: `docs/SCOUT_SURVIVAL_EVALUATION.md`. Historical status and recommendations below apply only to their recorded build.

# Scout survivability — card 097

Pinned Godot 4.7.2, Windows desktop. `tests/evaluate_scout_survival.gd` runs 18 command-driven comparisons: Backyard/Garden Edge, seeds 482817/104729/8675309, three policies. No food grants, rate changes or session-duration target. Start exploration at simulated 300 seconds (existing ambusher active), observe 1,500 more seconds. These are automated policies, not human balance verdicts.

| Setting / seed | General 5: physical scout losses | After first missing return, 2 + west bias | Cleared counterfactual |
| --- | ---: | ---: | ---: |
| Backyard / 482817 | 3 | 2 | 0 |
| Backyard / 104729 | 3 | 2 | 0 |
| Backyard / 8675309 | 3 | 2 | 0 |
| Garden Edge / 482817 | 4 | 3 | 0 |
| Garden Edge / 104729 | 6 | 2 | 0 |
| Garden Edge / 8675309 | 5 | 4 | 0 |

Every trial returned carbohydrate, protein and water evidence and eventually seven known sources. First resource-type accounts arrived 18.5–263 seconds after exploration started (331 seconds for protein in one cleared Garden control). The response uses only a home-known missing count; it reduces exposure but does not locate the predator or guarantee safe ground. Physical casualties can precede known missing accounts; unresolved losses and reserved slots remain private until the conservative expectation/grace boundary.

The cleared column explicitly removes the existing ambusher at the comparison start. It is an unfunded diagnostic counterfactual, **not** evidence that a real defense costs nothing. Card 084 remains the paid physical intervention proof. All 18 midpoint saves continued exactly through later commands; every ledger check passed. Raw results: [card097_exploration.json](../../../evidence/card097_exploration.json).

Targeted tests exercise actual private observations discarded on death, saturation/defeat, late living returns, late-loss grace, overlap phenotype loss, real recall, standing replacements, malformed/legacy saves and pause/speed equivalence. Final suite: **6,102 checks, zero failures and no script errors**. Import and Main 90-frame smoke passed. Actual mouse/touch recall and frozen standard/compact awaiting/missing/attention contexts passed on desktop. No mobile or human usability claim.

The next bounded original-design outcome is collective learned caution around **returned route loss evidence** (Part 2 §13). This uses already learned geography/danger, rather than adding individual XP or inferring danger coordinates from a missing scout.
