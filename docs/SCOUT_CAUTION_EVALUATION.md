# Learned scout caution — card 098

General standing scouts now prefer ground away from journey corridors with unresolved **home-delivered losses**. Missing scouts alone provide no location. Manual missions and deliberate source rechecks retain their intended risk; successful defense clears future caution only after its report reaches home. This is collective learned geography, not individual XP.

Three paired Backyard trials begin from the same actual returned honeydew alarm, then run five general scouts for 1,500 seconds without paying for defense. The control uses card 097's ScoutSystem from commit `88356e7`; all other systems and starting snapshots match. The current branch uses learned caution. Each policy's midpoint save is restored with its matching ScoutSystem and checked for exact continuation.

| Seed | Previous scout losses | Learned-caution losses |
| --- | ---: | ---: |
| 3043 | 1 | 0 |
| 104729 | 2 | 0 |
| 8675309 | 5 | 3 |

All six trials returned knowledge of all three resource categories and seven sources, conserved workers, and continued exactly after save/load. [Raw results](evidence/card098_caution.json). The preference reduces exposure in these examples; approximate remembered corridors are neither hazard forecasts nor impassable ground. The search falls back when alternatives are unavailable. No collection, brood or ecology rates changed.

The focused suite passed 22 checks, including private-information boundaries, safer departure/frontier preference, unavoidable fallback, deliberate overrides, actual funded defense with delayed report, malformed/legacy saves and pause/speed/RNG continuation. Final combined suite: **6,124 checks, zero failures and no script errors**. Godot import and Main 90-frame smoke passed. Standard/compact Exploration wording and paused-state preservation passed in the graphical probe, with no shutdown warnings. [Compact view](evidence/card098_caution_900.png).

Verification limitation carried from card 097: its recall/absence graphical probe intermittently printed eight ObjectDB instances leaked at shutdown after its input assertions passed. The final Main smoke and card 098 probe exited cleanly. No mobile/device or human usability claim is made.
