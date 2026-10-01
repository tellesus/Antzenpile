# 042 — Rain-fed exterior water source

Status: complete 2026-10-01. Narrow follow-up to card 041's source-access audit.

## Goal

Rain should make the known exterior water source physically useful again after it has run dry. The colony must still learn this only through an ordinary returning scout or trail cohort, and a depleted route must require deliberate Recheck.

## Implementation contract

- Author one rain-fed refill rate and capacity for backyard `water_01` in weather data. During each raining fixed tick, add physical water steadily up to capacity. The value is a provisional ecology fixture, not a general balance pass. No refill before the first traffic-gated rain or during the dry interval. Other source nodes are untouched.
- Keep the existing three-water on-hand rain benefit. Do not create a second clock or weather cursor: RainState's saved phase/elapsed time and WorldNodeState's saved quantity are sufficient. Apply the exterior deposit through RainSystem's fixed tick, after trail traffic.
- Do not modify KnowledgeBase or PerceivedSignals when rain fills the source. A depleted route stays depleted. Its existing Recheck action sends committed workers to the captured estimate; a loaded home return updates stores and reported evidence. The normal view may show only returned evidence, rain phase and on-hand stock, never exact physical quantity or guaranteed refill timing.
- Preserve version-5 save compatibility and exact mid-rain continuation. Do not change scout behavior, labor conservation, other resource rates or UI layout.

## Verification and handoff

Use a scenario with the source dry before rain, then verify steady capped physical refill, pause/speed and save continuation, stale colony knowledge, explicit Recheck and delayed cargo delivery. Run pinned import, full headless suite and Main smoke; update data model, decisions, evaluation/plan, README and this card. Commit one logical change.

## Completion evidence and handoff

- RainConfig now authors backyard `water_01`, 0.4 physical water per simulated raining second and a 100-unit cap. RainSystem deposits on fixed ticks after trail travel, in addition to the unchanged 0.05-per-second water delivered directly to the pile. A complete unharvested front refills 24 exterior units; neither dry weather nor pause adds any. Version-5 saves already include the physical node and rain progress, so the schema is unchanged.
- The command-driven test drains water with high route labor, observes returned empty evidence, establishes sheltered traffic to start rain, and confirms that physical refill leaves the route and evidence stale. Explicit Recheck sends workers back; only their loaded return updates knowledge and on-hand stock. A mid-rain JSON snapshot continued exactly after reload; separate checks cover the authored capacity, 16× speed, full-front 24-unit total and ledger conservation.
- Pinned Godot 4.7.2 import, Main headless smoke and the full suite passed; the suite recorded **4,082 checks, zero failures**. Import and smoke reported only sandbox-local root-certificate/editor-settings/log-file warnings, with no script errors. `git diff --check` passed. Graphical and physical-touch checks were not needed because no presentation or input code changed.
- Changed: weather definition/system, one new headless suite and its UID, runner registry, architecture/data model/decision/evaluation/plan/README docs, and this card. The audit probe remains a historical baseline. Next: assess the renewed water route in play before broader resource tuning; the original session-length target remains tabled.
