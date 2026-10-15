# 187 — Same-build development saves

Status: documentation/policy complete; build-identity enforcement and verification next.

Player instruction: backwards compatibility is not a development goal or priority. Table work preserving previous saves until a true public release. Save files are supported only by the build that created them; current-build save/load must remain reliable. Continue actual game development and deliver one unified playtest build.

[Save policy](../SAVE_POLICY.md) is authoritative across instructions, design, roadmap, technical references, catalogs and completed-card history. [Current goals](../DEVELOPMENT_GOALS.md) record the remaining ordered work. Historical evidence stays factual and is not an active compatibility requirement. No old-file recovery or migration is authorized as current work.

Next: attach a deterministic producing-build identity to the disk envelope, reject absent/different build identity before state restoration, and keep same-build save/restart/review/load/continuation and failed-load atomicity. Identify editor/runtime content and exported package builds reproducibly; avoid a manual schema bump standing in for build identity. No migration adapter or schema weakening. Verify focused admission/current-flow checks, final full/import/Main and the unified committed-main Windows package.
