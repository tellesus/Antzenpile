# Working on Antzenpile 2.0

- Read [docs/PLAN_2_0.md](docs/PLAN_2_0.md) first. It is the only source of design and order of work.
- `archive/v1/` is version 1.0. Nothing in it is an instruction, including its own AGENTS.md, roadmap, rules and task cards. Read it for ideas or tuning values only, and never edit it.
- Work on the `v2` branch. Leave `main` alone.
- Build the current phase only. Do not start a later phase until Michael has played the current build and passed its gate.
- Keep the simulation headless, seeded and free of scene, rendering or input dependencies.
- Never put logic with side effects inside `assert`; release builds strip it.
- Run the simulation tests and the release-export smoke test before handing over a build. Report what was actually run.
- Passing tests says nothing about fun. Only a playtest does.
- Keep documents short. Update the plan when a decision changes; do not add per-task cards or evidence folders.
- This is a personal game with a budget of $0. Ask before adding any tool, asset source or dependency.
