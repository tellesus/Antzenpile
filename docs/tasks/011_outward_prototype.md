# 011 — OUTWARD prototype

Status: complete 2026-09-29.

## Goal

Make the first useful player-facing sensory view.

## Why this exists

This milestone tests whether colony information is understandable.

## Dependencies

[010](010_perceived_signals.md) and the preceding task sequence. Read [ARCHITECTURE](../ARCHITECTURE.md), [CODING_RULES](../CODING_RULES.md), and relevant [DATA_MODEL](../DATA_MODEL.md)/[UI_RULES](../UI_RULES.md) contracts.

## Allowed scope

Near-black field, rotation/bearing, Home Anchor, simple signals, selection/context card; basic scout/labor/time controls.

## Required behavior

Render only PerceivedSignals, using 2D bearing-to-horizontal translation. Share mouse/touch drag logic; issue semantic scout commands. Preserve negative space and a small persistent HUD.

Before coding: Resolve field of view, wrap/culling, hit targets, input conflicts, and minimal panel layout.

## Explicit non-goals

Literal physical map/minimap, 3D camera, finished art, and trail allocation before 012. Do not implement future systems not explicitly requested.

## Interfaces to preserve

UI_RULES, knowledge-only output, and simulation-owned commands; no required hover/right-click.

## Acceptance tests

Test wrap seam and projection; manually rotate/select/launch scouts and use time controls. Hidden nodes stay invisible. Check small landscape layout and reduced effects.

## Manual verification

Run the relevant prototype/debug scene and inspect the behavior above. On expansion, name exact files, commands, fixtures, and expected results; do not treat this roadmap as a fully specified coding prompt.

## Done when

The expanded card's checks pass, existing behavior remains intact, and the handoff records changed files, tests, limitations, and next task. One logical commit.


## Executable expansion

- Add an OUTWARD `Node2D` under `src/presentation/outward/`, with a pure projection helper and lightweight headless projection/input tests. Compose it in GameRoot only for graphical runs. Give it only callable providers for `sensory_snapshot("home")`, an approved colony summary, and semantic dispatch/pause/time commands. Keep the F3 diagnostic view on top and preserve its input priority. No normal view receives RunState, WorldState, KnowledgeBase, or scene nodes from the hidden world.
- Use a 180-degree horizontal field centered on `facing` and `PerceptionModel.relative_bearing` for wrap. Signals at exactly +/-90 degrees remain visible on both edges; beyond them cull. Null bearings have no world direction and are not drawn as clouds. Projection places bearing horizontally; the vertical band is display distance/strength only, with no physical landscape mapping. Rotate view facing only, never the pile or signal data.
- Use near-black background, a restrained home entrance/anchor at the lower center, small bearing indicator, and soft bounded sensory clouds. Carbohydrate amber, protein violet, water cyan with a ripple; category is also textual in selection. No physical resource icons, minimap, stars/soil filler or bloom dependency. Cap signal draw count to visible Known Nodes (currently four), with a few 2D primitives each. Keep the screen mostly dark when knowledge is empty.
- Mouse left drag and touch drag use one pointer-turn method. Tap/release under an 8 px movement threshold selects a signal. Only the field takes drag/select; button presses do not rotate. At least 44 px signal hit radius for touch; nearest visible hit wins, stable ID survives facing changes. Debug F3 intercepts its own input and covers OUTWARD; OUTWARD uses unhandled input to avoid interacting through debug. Keyboard Space and 1/2/3/4 use existing named pause/time actions.
- Bottom controls: large Scout, Pause/Resume and 1x/4x/16x/64x targets. The scout action issues `dispatch_scout("home", facing)` through SimulationController and reports rejection briefly; disabled on worker shortage or cap. HUD: OUTWARD/home, available workers, active scouts, time scale and simulation time. Keep selected context concise and qualitative first (signal category, likely/clear/uncertain, approximate distance, risk unknown). No INWARD toggle or trail investment until their tasks can fulfill those actions.
- GameRoot supplies only approved values: available workers, active scout count/cap, clock time/paused/scale. Controller adds pause/time command methods. Input and view state are presentation-only, not saved. Renderer frame rate, signal facing and visual effects do not advance gameplay RNG.
- Verify at 1280x720 and 900x600 Windows Compatibility: turn, select, dispatch, pause, switch speeds, see a sensed signal only after return, and F3 still shows truth only when toggled. Record any control/layout limitations and unrun mobile/release checks.


## Implementation handoff

- Added `src/presentation/outward/{outward_projection,outward_view}.gd` and engine UID files, plus `tests/test_outward.gd`/UID. GameRoot composes the view only for graphical runs and supplies detached signals, approved status and semantic commands; SimulationController exposes pause/scale commands. Updated README, ARCHITECTURE, DATA_MODEL, DECISIONS, UI_RULES and the test registry.
- Pinned Godot `4.7.2.stable.official.ed1daf0bf`: `--headless --path . --import`, `--headless --path . --script res://tests/run_tests.gd` (2,959 checks, 0 failures), and `--headless --path . --quit-after 3` passed. Checks cover the bearing wrap seam and culling, tap targets, mouse/touch shared input, keyboard actions, scout worker accounting, pause/scale, detached presentation state, hidden truth isolation and an empty undiscovered field.
- Windows Compatibility manual at 1280x720: empty dark field before return; Scout dispatch decremented available labor, 16x advanced time, one food trace appeared only after return, tap opened a qualitative context, drag moved the trace while home stayed fixed, Pause switched to Resume, and F3 truth overlay opened/closed above OUTWARD. At 900x600, status and enlarged controls fit, and Scout worked. Clean final 900x600 preview log has no runtime errors. The display preserves the project aspect ratio with black bands at 900x600.
- The manual preview revealed a clipped right status label and a repeated facing-format error. Both were fixed; a regression check now covers facing labels and the final clean preview has no errors.
- Visuals are deliberate primitive 2D shapes; no bloom, finished art, traffic, risk, trails or INWARD interaction yet. The 900x600 desktop check is not a mobile/touch-device test; release export and mobile performance are unrun. Existing scouts can still wait at a reached target until the 30-second exploration deadline, as explained to the user; this card did not change scout behavior.
- Next bounded task: expand 012 (trail creation and worker allocation) against the current run and OUTWARD signal selection. Preserve distinct TrailRoute and TrailSegment objects and ledger-backed commitments.
