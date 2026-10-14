> **ARCHIVE ONLY — frozen 2026-10-04.** Historical record; not an active plan, current contract or implementation instruction. Use the [current documentation](../../../README.md). Original path: `docs/tasks/054_scout_departure_memory.md`. Historical status and recommendations below apply only to their recorded build.

# 054 — Scout departure and mission memory

Status: complete. Depends on 053. Source: accepted playtest plan and D26.

## Player outcome

An accepted home scout dispatch triggers a finite representative that approaches from a side, climbs to the exit and disappears. Selectable faint directional scent shows simulated time since dispatch and awaiting-return status. Rain/time removes scent but leaves a remembered stub. Only after home arrival may a coarse remembered course appear; no live positions, phase, discoveries or remote chemistry enter normal views.

## Scope and verification

Run-owned mission records: departure facts, decaying local scent, return timestamp and at most eight coarse course samples delivered at home. Keep every outstanding mission and at most sixteen recent returns; detours remain existing aggregate trail context. Older saves without records retain unknown departure history rather than inventing it. Validate optional records atomically, preserve exact save/pause/speed continuation and existing worker accounting.

Bounded grouped traces with shared mouse/touch selection, elapsed context and no recruitment controls; finite departure representatives freeze on pause and never replay old dispatches on load. Test rejected dispatch, return-only course, decay/memory persistence, overlap selection, save/legacy/malformed records, animation completion; standard/compact graphics, import/Main and final headless suite.

## Completion evidence

- Finite side-to-exit departures replace the endless Home loop. Eight grouped direction traces maximum; outer stroke/cap selection and repeat-tap cycling inspect missions. Rain/elapsed scent fade leaves departure memory; returned scouts alone add coarse course samples. Outstanding histories persist, recent returns cap at sixteen; legacy histories stay unknown.
- 56 focused checks; full suite 4507 checks, zero failures, including exact continuation, malformed/legacy saves, pause/speed, return-only course, rain stub and finite representative completion. Import/Main have no script/resource failures; existing host log/certificate/editor-settings restrictions remain. Twelve Windows Compatibility graphical contexts at 1280×720/900×600 generated; approach/climb/away/return/stub inspected. Adjusted trace caps below resource labels to avoid overlap; paused snapshots unchanged by drawing.
- Changed groups: typed memory/save validation, ScoutSystem dispatch/decay/arrival, detached root projection/load baseline, pure trace geometry and OUTWARD interaction/drawing, tests/probe and contracts. Handoff: 055 qualitative home-delivered casualty evidence. No new scout hazard, real-time remote tracking or balance changes.
