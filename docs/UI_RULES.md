# UI and visual rules

Part 7A is the locked visual amendment and supersedes ambiguous earlier concepts. Images establish mood and hierarchy, not pixel-accurate implementation targets.

## Shared rules

- Near-black background; large meaningful negative space. When nothing relevant is known or happening, render almost nothing. No filler stars, mist, particles, roots, noise, or ornamental HUD.
- Bioluminescent, organic chemical visualization. Clean sans-serif typography, translucent small context cards, qualitative information first. Avoid a futuristic tactical interface.
- Thin bright trail cores, faint chemical envelopes, representative moving traffic, restrained glow. Strong trails are coherent; fading trails become gapped and irregular. Familiarity can remain as a much fainter ghost after chemical loss.
- Warm amber/gold primarily means carbohydrate/metabolic energy; cyan/blue, violet, red-orange, pale neutral, and restrained positive-state green remain distinct families. Exact hues are tunable. Color must not be the only distinction: water can ripple, alarm pulse abruptly, and death fragment/fade.
- Pool and cap visual ants and effects. Their counts represent activity, not individual worker simulation. Graphics quality, facing, and animation must never alter gameplay.
- Readability must survive reduced/disabled bloom. Prefer curves/Line2D, sprites, simple shaders, bounded particles or instancing. Do not depend on volumetric fog, real-time GI, refraction, many lights, costly soft shadows, heavy depth-of-field, or layered transparent geometry. Profile overdraw on the chosen renderer.

## OUTWARD

The active pile anchors a rotating **2D sensory panorama**, not a camera in a rendered 3D landscape. Approximate bearing is spatially meaningful; vertical placement/depth is a presentation of estimated distance, confidence, and strength.

Knowledge-derived position relative to pile → bearing → wrapped difference from facing → horizontal screen position. Test the wrap seam. View rotation never moves the pile or reveals undiscovered objects. No minimap, ordinary player world map, literal resources, backyard diorama, or ant-eye camera.

The Home Anchor may suggest an entrance, a little soil/silhouette, and representative departures/returns. Beyond it, physical detail rapidly dissolves into abstraction: approximately 15% physical anchor / 85% sensorium is an illustrative art target. Food/water/danger appear as amorphous sensory clouds, not crystals or visible world objects.

Task 011 prototype: one 180-degree bearing field, drag to rotate, tap to select, an anchored home silhouette and restrained resource-color sensory clouds. The status bar gives available workers and time; Scout, Pause and speed are actionable. The view does not render unknown signals, and the F3 truth layer stays separate. Trail and INWARD controls arrive with their systems.

Task 012 adds a contextual investment button to a selected known resource trace. An active route shows desired/allocated workers and −1/+1/Cancel controls. An inactive route offers investment again. These are labor actions, not a map or visualized transport. Insufficient labor reports a short reason and leaves allocation unchanged. The F3 truth view may draw the estimated segment and print route/segment IDs, worker counts and the underlying commitment.

Task 013 shows current travelling workers, cumulative returned resources and the corresponding home store in the selected trace card. A cancelled route reports recall while cohorts return; reinvestment can use the same route. An empty return reports source unavailability. Normal UI never displays hidden world quantity, actual source position, cohort cargo or tick timers. F3 may show them for diagnosis. No visible ant traffic or chemical trail is introduced by this task.

Task 014 adds a qualitative scent label and a screen-space link from the home anchor to a currently visible known signal. This is a sensory hint, not a projection of TrailSegment geometry or a player map. Below 0.1 strength the link is absent; from 0.1 to below 0.45 it appears as four short wisps; at 0.45 and above it is coherent. A thin core and faint fixed-width envelope remain readable without bloom. At most six links render. Facing away hides a link without changing chemistry. F3 can display exact segment strength and successful-worker traffic.

Task 015 adds a memory ghost when chemical strength falls below 0.1 but familiarity remains at least 0.1. It uses only detached familiarity and a currently visible signal, with four shorter, narrower and fainter wisps than even a weak chemical link. The context calls this scent "remembered"; no hidden route endpoint is projected. Memory changes neither facing nor UI selection.

Slice controls: rotation, bearing indicator, selectable signals/context cards, scout action, trail investment/recall, available workers, time controls, and OUTWARD/INWARD toggle. Persistent HUD stays small: available labor, mode, time, urgent colony pressures. Total population/brood/queens belong in context, not a permanent overview panel.

Attention order: selected/critical signal → active major trails → destinations → environmental interference → representative ants → old information → physical suggestion.

## INWARD

Show **Queen, Nursery, Food Exchange, Entrance** as abstract functional organs suspended in darkness. Author the first four positions manually. Connections convey worker/resource flow and dependence, not literal tunnels. Node positions do not claim real chamber geography; later layout may reflow.

Task 017 uses four fixed normalized positions in the left functional field, with a selected-node context card on the right. Queen shows queen and living-worker counts; Nursery shows brood/stage/care/nutrition/emergence; Food Exchange shows its Primitive state and stores; Entrance shows available, scout and trail labor. The top bar keeps only available labor and time. Mouse/touch share node hit targets; OUTWARD and INWARD buttons and Tab switch views without affecting the run. Each view retains its own selection. The debug truth overlay remains separate and blocks mode switching while open.

Task 018 extends selected Food Exchange context: Primitive shows exact start requirements and a touch-sized Develop action with a short rejection reason; Developing shows fixed simulated progress and committed labor; Developed names the 25% larval food-use benefit and stores. It remains one contextual action, not a general build menu. F3 can inspect exact state/progress and the authoritative labor commitment.

Expose brood, resources, labor, and Food Exchange development through appropriate selection/context. Prioritize selected chamber, major flows, condition, representative ants, other nodes, then texture. No literal tunnel cutaway or permanent Colony Overview panel.

## Input and diagnostics

Use named Godot input actions: select, pan_or_rotate, zoom_attention, pause, time_1, time_4, time_16, time_64, toggle_inward, and development-only debug_world. Mouse and touch drag must call the same rotation logic; player actions cannot require hover or keyboard-only access. Android packaging can wait.

The F3 debug world is a clearly labeled development view with raw truth/knowledge inspection. It may use conventional geometry and utilitarian colors. It must be excluded or inaccessible in normal release play and must not become a player-facing minimap.
