> **ARCHIVE ONLY — frozen 2026-10-04.** Historical record; not an active plan, current contract or implementation instruction. Use the [current documentation](../../../README.md). Original path: `docs/tasks/045_worker_mortality_accounting.md`. Historical status and recommendations below apply only to their recorded build.

# 045 — Worker mortality accounting

Status: complete (2026-10-01). Prerequisite for the first predator in GDD Part 4 §§57–63 and 144.

## Goal and independent handoff

Make legitimate worker deaths compatible with ledger conservation, adaptation inheritance and version-5 saves before an exterior threat can cause them. This foundation changes no live gameplay behavior by itself; its useful handoff is a tested loss API that the predator can call without bypassing population or save invariants.

## Contract

- WorkerLedger records cumulative `lost_total` whenever its existing removal API succeeds. A removal reduces the named pool and total together, increments losses once, and rejects count/overflow failures atomically. Transfers, births and zero removals do not change losses. Old snapshots default the optional counter to zero.
- `PileState.lose_workers(pool, count, adapted_count, reason)` is the gameplay population-loss entry point. The caller explicitly supplies how many of the aggregate losses were adapted; validate adapted and baseline availability before ledger mutation. Record adapted losses separately so lifetime adapted emergence remains verifiable. Commitment owners must reconcile their route/cohort state in the same event; this API does not silently alter another system's fields.
- Colony restore permits a population below the original 40 plus recorded emergences only when recorded losses account for it. Living adapted count plus adapted losses must remain a valid emerged-brood multiple, within total emergence and total losses. A repertoire persists after its last living adapted worker dies, and later brood still inherits it. Reject invalid fields atomically.
- Do not expose deaths to normal UI or add predator behavior in this card. The predator's private encounter and returned colony evidence belong to 046. Keep headless ownership, explicit population changes and existing saves intact.

## Verification

Check available and committed losses, disjoint pools, invalid/zero/overflow removal, post-loss JSON restore, old saves, loss beyond the no-death population floor, partial/all adapted losses, continued inherited brood, and identical save/speed continuation. Run the full suite once after final code, plus runtime smoke. Document the changed population contract and commit this prerequisite separately.

## Completion evidence

- WorkerLedger owns optional cumulative loss history; PileState's atomic loss API reconciles living/lost adapted counts. Colony restore accounts for founding adults, emergence and losses. Captured journey phenotypes remain valid when current adaptation share falls.
- Focused mortality checks: **41 checks, 0 failures**. Full pinned suite: **4169 checks, 0 failures**. Headless Main smoke had no script errors; sandbox log/root-certificate messages remain an environment limitation. No graphical check was needed for this headless prerequisite.
- Changed groups: worker ledger/pile/colony/trail snapshot validation; mortality suite and registry; population contract docs and next predator card.
- Next: [046](046_first_predator_interaction.md) must connect real encounters to private cohort losses and returned colony evidence. It must reconcile cohort/route counts when calling the loss API and keep normal population summaries from revealing unresolved casualties.
