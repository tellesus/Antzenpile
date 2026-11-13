> **ARCHIVE ONLY — frozen 2026-10-04.** Historical record; not an active plan, current contract or implementation instruction. Use the [current documentation](../../../README.md). Original path: `docs/tasks/044_honeydew_mutualism_controls.md`. Historical status and recommendations below apply only to their recorded build.

# 044 — Honeydew relationship in OUTWARD

Status: complete (2026-10-01). Depends on [043](043_honeydew_mutualism_simulation.md) and the existing selected-trace OUTWARD context.

## Goal

Make the first mutualism legible and controllable without exposing hidden producer condition or future output. A player who has learned and exploited the aphid source may choose to reserve six workers for protection or withdraw them, then observe the labor tradeoff through colony facts.

## Implementation contract

- Give returned evidence from `aphid_01` a honeydew producer identity in colony knowledge or an approved detached source classification. The ordinary carbohydrate trace remains hidden until its scout report returns. Do not identify an unobserved source from WorldState in the view.
- In the selected OUTWARD source context, describe discovered honeydew and show a **Protect producers** action only after a loaded route return and if it is not already tended. Show its six-worker labor cost, current available workers, and a concise rejection reason when labor is insufficient. While tended, show the committed worker count and **Withdraw protection**. Keep both touch-sized and routed through GameRoot semantic callbacks to SimulationController.
- The context may report the colony's own tending/exploitation history. Do not show exact producer condition, hidden carbohydrate quantity, pulse timing, predator meter or guaranteed yield forecast. Keep existing depletion and uncertainty cues intact. F3 may show exact truth for diagnosis.
- Do not add a general diplomacy screen, combat, predator agents, new resource types, or worker portraits. Keep the rotating sensory panorama and sparse negative-space style.

## Verification

Use a command-driven scout→route→loaded return→tend→withdraw test, including normal-view snapshots before knowledge and after each transition, button hit/callback checks for mouse and touch, and labor rejection. Inspect the 1280×720 and 900×600 contexts in the pinned engine for overlap/readability. Run the full headless suite and Main smoke, update UI/data docs and this card with actual results, then commit one logical change.

## Completion evidence and handoff

- GameRoot now projects a honeydew identity only after a returned KnownNode exists and supplies detached relationship/labor facts. OUTWARD labels that trace and offers contextual protection or withdrawal after the loaded return. Insufficient labor gives a short rejection. Existing trail, Recheck and investigation actions remain available.
- `tests/test_honeydew_controls.gd` covers discovery, evidence gate, semantic command rejection, mouse/touch actions, worker release, labor shortage, and data minimization. The full pinned headless suite passes with **4127 checks, 0 failures**. Pinned graphical probe captured selected tended contexts at 1280×720 and a 900×600 window (900×506 game image under the project aspect ratio); visual inspection found no overlap. Main headless smoke and import produced no script errors. This sandbox could not write Godot's user-level logs/editor settings and reported a missing root certificate store; those environment messages did not affect the run.
- Changed files: GameRoot and OUTWARD view; honeydew state test and new control test/runner; graphical layout probe; README, architecture/data/UI/plan docs; this card.
- Next: playtest the protection tradeoff with active trails and brood before tuning output, labor or predator pressure. Later ecology relationships and rivals need separate bounded cards.
