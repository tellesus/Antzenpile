> **ARCHIVE ONLY — frozen 2026-10-04.** Historical record; not an active plan, current contract or implementation instruction. Use the [current documentation](../../../README.md). Original path: `docs/tasks/117_colony_network_guidance.md`. Historical status and recommendations below apply only to their recorded build.

# 117 — Colony network guidance

Status: complete. Depends on 116.

Outcome: optional Help explains the implemented first-daughter progression and the distinct costs/purposes of resource supplies and worker settlers. A new player can find founding, named pile attention and support controls without interpreting a map or assuming free workers/food.

Implementation: two concise pages in the existing requested guide, six short lines each; update adaptation wording for queued/locked brood. Retain previous/next/wrap, close/Escape, mutual modal shielding and at least 44-pixel mouse/touch controls. Do not claim Daughter→Home supplies or full mating biology exist. No new saved state, tutorial gating or automatic orders.

Verification: existing guide/navigation regression, final full headless suite, Main smoke and actual mouse/touch help navigation in both normal views at 1280×720/900×600. Inspect both new pages for line length/fit and ensure reading leaves paused simulation unchanged. Import the new probe. No tests that merely assert copy strings.

Handoff: first-satellite milestone is ready for continued feature work; scope paid Daughter→Home resource delivery (Part3§88) with local labor/store cost, physical travel, same-connection exclusivity and returned reports before coding.

Completion: full 6,982 checks, zero failures; import/Main90 passed without errors. Actual mouse/touch opened, navigated/wrapped and closed all six optional pages in INWARD/OUTWARD at both sizes without changing simulation. Both new pages rendered and inspected for fit: [founding](../../../evidence/card117_inward_1280_3.png), [worker/resource support](../../../evidence/card117_outward_900_4.png). No new runtime systems, saved state or copy-mirroring tests.

Changed groups: existing ColonyControls guide content; actual input/render probe and two evidence images; UI contract/card/roadmap. Next audit local Daughter→Home resource transport against original Part3§88; funding pile, physical party/connection ownership and returned receipt must be explicit before coding. Keep current one-daughter and Home worker-trial defaults.
