> **ARCHIVE ONLY — frozen 2026-10-04.** Historical record; not an active plan, current contract or implementation instruction. Use the [current documentation](../../../README.md). Original path: `docs/tasks/041_source_recovery_audit.md`. Historical status and recommendations below apply only to their recorded build.

# 041 — Source recovery and discoverability audit

Status: complete 2026-10-01. Evidence card; no resource-rate change.

## Goal

Determine why tapped-out resources feel difficult to find, and whether the authored backyard has an ordinary-command recovery path. Distinguish an empty physical node from a stale report, a depleted trail, an undiscovered recurring source, and a true progression lock.

## Executable scope

- Use new seed-3030 backyard runs and only SimulationController commands to send scouts, invest routes, allocate labor, investigate known sources and advance time. No direct mutation of nodes, stores or workers in the audit.
- Drive the starting water source to depletion with exposed-only route traffic that withholds the first rain trigger. Record physical quantity, on-hand water, returned depletion evidence and trail state. Wait through at least one rain-cycle interval, investigate the known source, then establish the missing route and observe the first rain's on-hand water benefit.
- Drive the starting protein source to depletion in a second run. After the authored picnic episode begins, use an ordinary scout and route to verify that the separate protein source can be discovered and harvested. Record timing and evidence limitations.
- Compare these against the earlier multiroute integration run, which accumulated stores. Diagnose access separately from balance. If no irreversible lock appears, leave quantities unchanged and document the smallest next gameplay change to consider.
- Preserve hidden-world/knowledge/presentation boundaries: any exact source quantities or schedules in the probe are development-only diagnostics. Normal UI stays on returned evidence and on-hand stock.

## Verification and handoff

Run the repeatable probe, pinned import, full headless suite and `git diff --check`. Update the post-slice evaluation, plan, relevant decision note and this card with actual findings and limits. Commit one logical audit change. Do not make a broad economy pass or set a session-duration target.

## Completion evidence and handoff

- `tests/probe_source_access.gd` uses only ordinary simulation commands to form three seed-3030 runs. Twenty water workers and fifteen exposed-carbohydrate workers exhausted the starting water node by 180.5 seconds, with 109.97 water already on hand. The depleted route and returned knowledge reported empty. Six hundred seconds later the physical node was still zero and another scout investigation returned empty. A subsequently invested sheltered route triggered the first rain, which added about 2.99 on-hand water over 60 seconds. A lower four-worker water allocation left 76 physical water units at 180 seconds.
- Twenty protein workers exhausted the starting protein node by 154.5 seconds. Picnic protein appeared at 450 seconds while colony knowledge remained unchanged; an ordinary scout reported it at 464.25 seconds and an eight-worker route delivered eight units at 475.5 seconds when a carbohydrate route supplied travel energy. A separate exploratory run without that carbohydrate route found the picnic source but could not collect it after carbohydrate fell to 0.0121; route energy was the blocking dependency, not missing protein evidence. The earlier multiroute review accumulated large stores, so these results do not justify global collection-rate tuning.
- No irreversible progression lock was demonstrated. The empty starting water node never refills, but the rain route can recover some colony water. The next narrow candidate is physical rain-fed renewal of that exterior water source, followed by ordinary Recheck; it needs its own card and save/knowledge checks. No authored quantity, command or normal UI changed here.
- Pinned Godot 4.7.2 probe exited successfully; full headless suite passed **4,059 checks, zero failures**; editor import exited successfully with sandbox-local editor-settings/root-certificate warnings and no script error. `git diff --check` passed. No graphical or physical-touch check was needed for this development-only audit.
- Changed: this card, the development-only source probe and its UID, post-slice evaluation/plan, decision register, README and card-040 risk wording. Handoff: specify and verify the narrow water-access candidate before modifying gameplay; keep overall balance and the session-length target tabled.
