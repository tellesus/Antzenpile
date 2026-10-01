# 035 — Recurring environmental pressure

Status: complete 2026-09-30. Expanded from [the post-slice plan](../POST_SLICE_PLAN.md) against the existing 60-second rain and version-5 save contract.

## Goal

Let a later weather front revisit established trails, renewing the player's choice to work through washout or adjust labor. Keep the existing uneven chemistry effect, preserved familiarity and modest steady water gain.

## Scope and contracts

- Preserve the first rain trigger: five successful returning workers on each an exposed and a sheltered route. After each 60 simulated seconds of rain, schedule another front after an authored 2400 fixed ticks (600 dry simulated seconds). This provisional interval is a weather fixture, not a session-length target. Subsequent fronts are physical weather and do not require route traffic to retrigger.
- RainState records completed front count and next start tick. The SimulationClock remains the only authoritative time; fixed ticks drive transitions. A version-5 save missing these optional fields defaults a finished one-shot event to a new dry interval from restore, rather than raining instantly. Validate malformed phase/count/tick relationships before swapping live state. No new top-level save version.
- Each front applies the same exposure-scaled pheromone washout, baseline familiarity persistence and 0.05 water/second. OUTWARD receives only semantic raining/dry status; exact count/next tick stays in development truth. No minimap, weather forecast, new particle system or rain benefit change.

## Verification and handoff

Test first-trigger gating, exact finish/restart boundaries, repeated water totals, later exposed/sheltered chemistry, labor/route response, pause and all speed scales, save continuation before/through the second front, old-save defaults and invalid-state rejection, and no normal-view schedule leak. Run pinned import, full headless suite, Main smoke and diff check. Record results and files before committing.

## Completion evidence and handoff

- The first traffic-gated rain is unchanged. Its completion saves a due tick 2400 fixed steps later; that tick starts the next 60-second front independently of route traffic. Each front retains the same exposure-scaled chemistry washout, slower familiarity decay and steady three-water total. F3 truth shows completed count and next tick; normal OUTWARD still receives only semantic rain phase.
- Version-5 RainState now stores completed count and a decimal-string next tick. Older finished saves missing both fields receive a fresh dry interval on restore; waiting/raining old saves retain their phase. Invalid due ticks and phase/count combinations reject before replacing the run.
- Tests cover first trigger, exact second boundary under 4× and reload, dry interval, chemistry/familiarity comparison, water totals, route re-investment with eight workers during later rain, pause, 4×/16×/64× totals, old-save defaults, malformed snapshot rejection, and no normal-view schedule leak. The existing 790-second extended run now ends with 26.2 water instead of 23.2 because it encounters a second front; its brood and conservation checks remain green.
- Pinned Godot `4.7.2.stable.official.ed1daf0bf`: headless import exited 0; full suite passed **3,820 checks, zero failures**; headless Main smoke exited 0; `git diff --check` passed. Sandbox user-log/settings and root-certificate diagnostics did not affect exit status. No graphical manual interaction or Android-device check was run.
- Changed: rain config/definition/state/system, RunState restore, F3 diagnostic line, recurring-weather tests and runner, README, architecture/data/UI/decision/plan docs, and this card. Next: expand card 036 for a longer command-driven integration review and human visual/input playtest evidence; keep the session-length target tabled.
