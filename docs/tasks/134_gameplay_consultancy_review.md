# 134 — Gameplay and communication consultancy review

Status: complete — review and recommendations only.

Requested 2026-10-04: review current mechanics, combat, scouting, gathering, colony/network systems, communication and interface organization; produce a staged, prioritized improvement plan. This is a review, not authorization to implement its proposals or expand later systems.

Player outcome: a concrete plan that makes colony decisions easier to understand and more rewarding without removing uncertain perception, physical travel, biological tradeoffs or the sensory presentation.

Scope: current card-133 implementation at `036ab0b`; design/code inspection, fresh desktop walkthrough, targeted current-build scenarios and graphical inspection. Separate observed defects from consultant judgments, older evidence and hypotheses requiring human playtests.

Verification: follow the opening loop through returned discoveries, gathering and internal care; inspect threat/approach, genetics and network decisions; examine current ordinary-command evidence and source contracts; verify any new measurements use normal commands and returned information. Preserve the player's saved slot and unrelated workspace changes. Record actual checks and limits in the final report.

Deliverable: `docs/GAMEPLAY_REVIEW_2026_10_04.md`, including priorities, bounded implementation sequence, copy examples, acceptance criteria and playtest questions. Existing desktop completion work remains visible; proposed reorderings require an explicit acceptance decision.

Completion evidence: full current headless suite recorded 8,405 checks with zero failures before the reboot. Nine new ordinary 1,200-second economic runs grew colonies and passed saved-twin continuation/ledger checks. Fifteen paid ambusher branches concluded; twelve current rival counterplay branches passed their evaluator. Measurements are retained in `docs/evidence/card134_gameplay.json`, with the new harness retained as non-imported documentation in `card134_measurement.gd.txt`.

Review findings: clarify immediate versus waiting orders; preserve/read important returned reports at high speed; expose concurrent needs; teach the opening; improve source, trait and pile comparisons. No broad rebalance is supported by this limited sample. The recovery-watch historical guard is a source-level wording finding; the attempted ordinary post-clear reproduction did not establish an end-to-end failure and is not presented as one.

Presentation evidence: fresh live opening/exploration/returned-source walkthrough before interruption, plus inspection of four pre-existing late-system captures. Successful live gathering, fresh compact rendering, audio listening and human playtesting were not completed. After the player requested use of their machine, all further work was background/headless; no further desktop input. Import/Main/graphical gates were not repeated for documentation-only changes. No gameplay, player save or unrelated work changed.

Changed groups: consultancy report; review/evidence record; concise roadmap link. No design decisions were silently accepted and no future implementation cards were expanded.

Handoff: proposed next bounded outcome is explicit order labels and honest recovery/recall wording, followed by reports/time-control clarity. Obtain acceptance of the proposed short clarity milestone before replacing the existing run-continuity/endings priority. Preserve tabled mobile and fixed session-length work.
