# 193 — Execute gameplay operations in Windows release builds

Status: source complete and actual-release verified; integrated Windows delivery follows192 in this session.

The screenshot's `-1/12 recruits` is the worker ledger's missing-pool sentinel. Recruitment creates, fills, transfers and retires its pools inside `assert(...)`; Godot removes the entire expression in non-debug builds. Related mutations in response, rivals, scouts, rain, refuge and reproductive loss use the same pattern. Editor-based packaged-PCK tests cannot catch this release-only omission.

Move side effects into explicit typed results before assertions; preserve existing order, ownership and rules. Audit all runtime assertions, leaving pure checks alone. Add a release-specific test artifact using the actual release template, with test fixtures explicitly evaluated outside debug assertions. Exercise real recruitment/cancel/return/borrowing, predator/rival continuations and the other affected families. Do not ship test hooks in the playable package. Keep previous-build saves unsupported.

[Release evidence](../evidence/card193/README.md): baseline failure reproduced; corrected1,237 checks pass. This is a correctness repair, not a combat rebalance or an assertion that the existing combat design is satisfying.

Actual non-debug verification: the historical e8742f4 runtime reproduces the absent recruitment pool (3 checks, expected 1 failure). Corrected runtime passes 1,237 checks across13 suites, with OS.is_debug_build false. Isolated baseline evidence: .godot/release-gameplay-uy5wr03g; corrected: .godot/release-gameplay-5al1xmtq. Runtime audit finds42 mutating assertion expressions across10 files, now evaluated before assertions. The tool allowlists only reviewed pure assertion calls. Sandbox export attempts could not write Godot's OS temporary metadata; the completed checks ran with authorized normal host access and isolated save/settings data. No failed export was published.
