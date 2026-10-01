# 039 — First Adaptation Web choice

Status: complete 2026-09-30. The player delegated the first trait-pair choice to implementation judgment.

## Goal

Put one meaningful, biologically funded choice in INWARD. Lean Foragers lower trail travel carbohydrate by 30% but carry 15% less. Load Bearers carry 30% more but increase travel carbohydrate by 20%. The paired cost matters to the existing route economy. These numbers are provisional balance, not a session-length target.

## Implementation contract

- The first selection is irreversible for this slice. Selecting either trait atomically pays 12 carbohydrate, 12 protein and 6 water, reserves two available nurses under one internal ledger commitment, and starts an eight-ant experimental brood cohort occupying ordinary Nursery space. Require a queen, free space, two available nurses, and enough resources. Failed commands leave state unchanged. The cohort goes through normal egg/larva/pupa timing and nutrition. Dedicated nurses count toward its care; release them when it emerges. No research currency, instant worker conversion or individual genomes.
- Before trial emergence, repertoire remains unchosen and route effects remain baseline. On emergence, record the chosen repertoire and eight adapted living workers. Future manually laid cohorts inherit that choice automatically and add to the adapted count only on emergence. Existing workers stay baseline; aggregate route multipliers use adapted/total living workers at each departure. Store both multipliers on each departing cohort so a brood emergence mid-trip cannot change that cohort. New brood still incurs normal larval protein and care costs; no extra invented repeating tax.
- Extend typed PileState and BroodCohort snapshots with optional adaptation fields for older version-5 saves. Validate trait IDs, adapted count, trial/nurse commitment, cohort tags, and population bounds atomically. Extend TransitCohort with optional captured multipliers (default 1) and validate payload/energy against the captured bounds. Preserve deterministic fixed-tick continuation.
- Add a fifth abstract **Adaptation** node in INWARD, connected to Queen and Nursery as a functional relationship. Show costs, the two tradeoffs, trial state, adapted fraction and one-time choice through detached status and semantic commands only. Keep touch targets at least 44 pixels and legible at 900×600. No hidden world access, full web, rivals or caste micromanagement.

## Verification

Test atomic rejection, ledger conservation, nursery capacity and shared care, trial maturation, zero effect until emergence, both route multipliers, mid-trip stability, inherited brood, old-save defaults, exact continuation and malformed snapshot rejection. Run pinned import, full headless suite, Main smoke and graphical INWARD check at 900×600. Update architecture/data/UI/decisions/README and card evidence; make one logical commit.

## Completion evidence and handoff

- Lean Foragers and Load Bearers now run through a one-time, eight-ant brood trial. It spends the authored stores, reserves two nurses through the worker ledger, uses normal maturation and nutrition, releases nurses on emergence, and propagates the chosen repertoire to later cohorts. Existing adults have no instant effect. Departing aggregate trail cohorts capture the expressed workforce fraction as energy/carry multipliers, including the paired downside.
- Focused checks cover rejected choices without mutation, nurse care with no other available workers, one-time selection, trial and inherited emergence, both route costs and cargo capacity, a baseline cohort still travelling when the trait emerges, exact in-flight/mid-trial save continuation, older version-5 defaults, malformed trait/commitment/multiplier rejection, detached INWARD data and touch choice. The full pinned-engine headless suite passed **4,057 checks with zero failures**. Editor import and Main headless smoke exited 0; `git diff --check` passed.
- A graphical Windows probe of the selected Adaptation context exited 0 with eight scene nodes and 64 draw calls. A 900×600 window produced a 900×506 16:9 game image under the project's aspect rule; visual inspection found the fifth abstract node, readable paired tradeoffs and both touch-sized choices without overlap. Android-device and physical touch tests were not run.
- Changed: typed adaptation rules/system; pile, brood and trail cohort state/serialization; controller, detached INWARD summary and fifth node; focused tests/probe; README and architecture/data/UI/decision/plan docs. Next bounded expansion should follow player use of this first choice; resource balance and session duration remain tabled.
