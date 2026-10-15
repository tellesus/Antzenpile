# 180 — Sensorium art direction and clear playfield

**Current development save policy (2026-10-15):** [Same-build saves only](../SAVE_POLICY.md). Earlier requirements to preserve/load/migrate previous-build saves are superseded and tabled until true release preparation. Historical implementation/evidence below does not create a compatibility goal.

Status: complete, published to main and included in the refreshed Windows systems beta. Player art/feel and final release acceptance remain open. Player requests a substantial visual revision with polish and pop, beyond the earlier trail/cloud proofs.

Outcome: softer flowing chemical volumes, readable illuminated ants, distinct luminous INWARD organs connected by delicate living filaments, a coherent dark interface, and an Escape menu that removes persistent Help/Sound/Save/Load clutter. Preserve known-information boundaries, authoritative simulation, all existing semantic actions and compact/mouse/touch access.

Production: two new transparent imagegen textures, tinted/composed/animated by the engine. No generated scenery, occupants, hidden identities or baked UI. Existing materials remain in source history. The menu groups existing commands; opening/inspection stays free, and pause remains deliberate.

Verification: pinned import, focused art/layout/menu/input/pause/RNG tests, final full suite, native multi-resolution captures of early/active/selected/developed/strained states, workstation timing and refreshed committed-main Windows package. Ship to current main without a dormant feature branch. Music and deeper dispatch redesign remain separate work.

## Verification and changed groups

11,048 full checks/zero failures; 440 focused/zero; pinned import/Main; native multi-resolution early/selected/developed/strained/menu and actual returned-predator captures; exact paused pixels and immutable simulation/RNG; two 60-second workstation timing samples. [Evidence and limitations](../evidence/card180/README.md).

Changed groups: two production alpha textures and mipmaps; soft shader flow; shaded larger ant representatives; luminous functional organs and lightweight connections; shared panel typography/hover styling; GameRoot Escape/utility routing and hidden old launchers; behavior tests and repeatable native/package probes. No simulation rules or audio stems changed.

| Screen | Median FPS | p99 ms | 1% low FPS | Worst ms |
| --- | ---: | ---: | ---: | ---: |
| OUTWARD | 277.85 | 5.588 | 98.92 | 86.278 |
| INWARD | 382.26 | 3.189 | 291.51 | 10.766 |


Handoff: finish publication/package, then collect player visual feedback. Next useful interaction slice is one clear choose-and-send workflow for ordinary worker dispatch, preserving protected care and real travel. Music and remaining art are separate work.

## Main and playable package

Runtime revision [79f482b](https://github.com/tellesus/Antzenpile/commit/79f482bbf7505e17d4e70175ddb9e4ed97fa6d21), 638 audited resources. Both main checkouts updated, all 109 preserved local files unchanged. Isolated package/release Main/packed save-settings-review and native unchanged-PCK material/network/menu checks pass. [Delivery details](../evidence/card180/README.md#published-main-and-windows-package). No extra branch or PR remains. The specific save report178 and further art/dispatch/music/player acceptance remain open.
