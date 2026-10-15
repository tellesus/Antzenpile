# Development save policy

Player decision, 2026-10-15. This policy supersedes every earlier instruction, task, catalog, acceptance test or goal about preserving saves from previous builds.

During development and the limited beta, save/load is supported **only for saves created by the same build of the game**. A save from another build is unsupported even if its schema happens to match. Tell the player to start a new colony after changing builds; never silently reinterpret an old run as a current one.

Save → quit/restart → load and save → End Run → review → load must work on the same build, with exact continuation, current state validation, real ownership and the knowledge boundary intact. A failed save/load must leave the live run and last good same-build slot unchanged. Keep corrupt-file/checksum/size/atomicity checks. Ending or restarting a run must not silently replace its saved slot.

Do not spend development resources on old-save recovery, compatibility matrices, migrations, backfills, default-field adapters or preserving earlier balance/content behavior for previous saves. Table those goals and tests. Existing compatibility code may remain incidentally; it is not a support promise and must not constrain current development. Remove or simplify it when useful to the current task, without launching a separate compatibility-cleanup project.

This does not authorize deleting unrelated local files or player data. Leaving an old slot untouched is file safety, not a requirement to make it load. Archived cards and immutable evidence record earlier work; their old compatibility requirements have no current authority.

Reconsider backward compatibility when preparing a true public release. At that point, explicitly choose the supported release/save versions, migration policy and verification. It is not a limited-beta milestone or current release blocker.

The same-build admission check is tracked in [187](tasks/187_development_save_policy.md). The earlier [178](tasks/178_player_save_validation.md) validates current serialized state and actual review/reload flows; it does not yet identify the producing build.
