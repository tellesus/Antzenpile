# 029 — Route energy demand

Status: complete 2026-09-30. Expanded the first item in [the post-slice plan](../POST_SLICE_PLAN.md) against the task-028 implementation.

## Goal

Make aggregate foraging travel consume carbohydrate so route distance, terrain and traffic affect its value. This is the Part 3 worker-energy constraint, not individual hunger or a balance pass.

## Scope and contract

- Charge each departing aggregate cohort once for its complete outbound-and-return journey. Authored provisional cost is workers × captured segment length × sampled terrain movement cost × rate, quantized to the pile's five-decimal resource precision. Each departure represents traffic. Empty trips also cost energy.
- Debit the origin pile atomically before creating the cohort. If carbohydrate is insufficient for a protein or water route, keep the workers committed and the route active, but launch no cohort. Retry on later fixed ticks. Show a route-level energy-limited indication only after a departure attempt fails; never expose terrain samples or hidden source quantity to normal UI.
- A known carbohydrate route must remain a possible recovery path. It pays available home carbohydrate at departure and settles the unpaid remainder against returning carbohydrate cargo. An empty or weak trip can deliver nothing; it cannot create a negative store. This exception uses colony-known resource type, not hidden source availability.
- On receipt of carbohydrate, subsequent ticks may resume the route. Recall, depletion, or a successful departure clears the stale indication. Existing version-5 disk saves without the new flag must load with a safe default; mid-trip continuation must not repay energy.
- Do not add passive worker hunger, scout costs, route automation, terrain pathfinding, or resource balance changes in this card.

## Verification and handoff

Test distance/terrain/worker scaling, exact single debit, an empty trip, insufficient-energy retry, labor conservation, detached UI data, and save/reload before and during transit. Run pinned import, full headless suite and Main smoke; record results, changed files and next action here before committing.

## Completion evidence and handoff

- Aggregate departures debit carbohydrate once for a complete journey, using the captured segment and authored movement-cost sample. A known carbohydrate trip can settle a shortfall from returned cargo, so an empty home store can recover without negative resources. Other routes wait, retain their ledger commitment, and expose only an observed energy-limited label in OUTWARD.
- New route/cohort fields default safely when absent from a version-5 save. Restore rejects inflated unpaid energy. Tests cover cost scaling, resource flow, weak and empty trips, insufficient-energy retry, worker conservation, detached UI values, and exact continuation across reload. Older transit and ecology expectations now account for travel expense.
- Pinned Godot `4.7.2.stable.official.ed1daf0bf`: headless import exited 0; full suite passed **3,666 checks, zero failures**; headless Main smoke exited 0; `git diff --check` passed. The sandbox denied writes to Godot's user log/settings and root certificate store, but these diagnostics did not affect the checks. No graphical manual interaction or Android-device check was run.
- Changed: trail configuration/state/system/network and its authored rate, GameRoot's detached trail summary, OUTWARD context, transit/ecology/energy tests and runner, README, architecture/data/UI/decision/plan docs, and this card. Next: expand card 030 against current brood and INWARD code to represent Nursery capacity and care. The 0.003 rate is provisional, not a resource-balance conclusion.
