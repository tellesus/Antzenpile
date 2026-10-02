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

The player chose to keep this Develop action available as soon as its existing requirements are met, even before protein discovery or brood pressure. It provides an early project; do not hide it behind a later milestone.

Task 019 adds two restrained, phase-matched placeholder music loops without a new persistent UI panel. Developed Food Exchange brings in the second stem over three real seconds. Pausing or accelerating simulation does not alter the audio tempo; audio has no authority over game time. Headless runs remain silent.

Task 020 shows rain in OUTWARD as a brief semantic status label, sparse thin screen-space streaks, and reduced signal opacity while the event is active. It does not reveal exposed terrain or a physical route map. Actual detached chemical strength and familiarity continue to drive existing scent/ghost visuals; F3 shows exact rain phase, elapsed time and segment exposure for diagnosis.

Task 024 lets the existing selected-context resource summaries show water gained during rain. OUTWARD retains its restrained rain status; INWARD Food Exchange shows the updated store. Neither view gains weather truth or a new collection panel.

Task 035 repeats that same restrained OUTWARD rain status for later fronts. The visual interference remains sparse, and a later washout may prompt the player to adjust an exposed trail's workers. No normal view exposes a front count, next start tick or forecast; F3 truth may show those for diagnosis.

Task 028 gives a selected depleted route a touch-sized **RECHECK** action beside Cancel once all travelers have returned. It asks workers to test the remembered source; the label does not promise renewal or show a schedule. A still-empty return reports unavailability again. The action shares the existing mouse/touch context path and introduces no map or live resource quantity.

Task 029 lets a selected active route say **Waiting for carbohydrate** after a departure fails for lack of energy. This is an observed route condition; the context never displays exact hidden terrain cost, pending cargo or source quantity. The existing home store remains visible. A carbohydrate route can recover from an empty store through a cargo-paid trip, so it does not show this stall.

Task 021 places touch-sized Save and Load buttons at the upper right of both normal views, with Ctrl+S/Ctrl+L named actions sharing the same semantic GameRoot path. A short success or error message appears in the existing view footer. Loading clears transient facing/selection and restarts music from the restored development level; it does not reveal hidden state or add a persistent overview panel.

Task 025 puts one touch-sized **LAY 8 BROOD** action in the selected Queen or Nursery context only while the nursery is empty. Its callback goes through GameRoot to BroodSystem. The action disappears while the cohort is active, and the existing stage/care/nutrition summary replaces it. No permanent population menu or individual egg graphics are introduced.

Task 030 additionally shows occupied/total brood space and current/maximum care capacity in the selected Nursery context. Queen shows occupied Nursery space. Lay Brood requires the detached free-space summary as well as an empty Nursery and a queen; BroodSystem independently validates the command. These are colony facts, not a physical chamber floorplan.

Task 031 adds a selected-Nursery **DEVELOP NURSERY** action with authored costs and a touch-sized target. Developing shows simulated progress and committed labor; Developed shows capacity for two aggregate cohorts. Lay Brood remains available in Queen/Nursery when a Developed Nursery has eight free slots, even while one cohort is active. The context summarizes both stages and shared care/nutrition, without individual brood graphics or a general building menu.

Task 033 places **INVESTIGATE SOURCE** in the selected OUTWARD trace context. It sends a scout to the colony's remembered estimate; no hidden location or source quantity is passed to the view. One short temporal line says an earlier source was found empty or may recur after an approximate, explicitly uncertain observed gap. This line appears only from returned colony evidence, never on physical appearance or expiry. The contextual button is touch-sized and uses the same mouse/touch command path.

Card 037 supersedes the numerical temporal line: after returned positive–empty–positive evidence, say only that a source returned before and its timing is unknown. A most-recent empty return mutes and breaks the OUTWARD trace and labels it EMPTY even without selection. A hidden physical refill alone does not change the cue; a later positive return clears it. This is a report about last contact, not a live source meter.

Task 038 counts an active trail-side detour in the top-bar scout cap and says one worker is **checking** in the selected route context. It does not draw the detour's actual position, expose its target before the report returns, or turn the panorama into a route map. The returning evidence enters existing sensory traces through KnowledgeBase.

Task 039 adds a fifth abstract INWARD function, Adaptation, connected to Queen and Nursery without implying chamber geography. Its selected context presents Lean Foragers and Load Bearers as one-time choices with their paired travel-energy/carry tradeoffs, 12 carbohydrate/12 protein/6 water cost, two committed nurses, and eight ordinary brood slots. During the trial it reports brood stage and delayed expression; afterward it reports the chosen repertoire and adapted share. Both choice buttons are touch-sized. The normal view receives detached pile summary values, never route geometry or a worker genome list.

Task 040 makes all three on-hand resource stores visible in a single restrained INWARD header line even with no function selected. These are detached pile totals, not exterior source quantities. Adaptation Web has a distinct violet context and outlined brood-trial actions; the active trial names its chosen trait. Chamber development keeps its own green action treatment, and the Food Exchange button names the chamber. This clarifies what the colony is growing or developing without turning INWARD into a full inventory dashboard.

Card 044 labels the returned aphid-source evidence as a Honeydew trace in OUTWARD. Its selected context reports whether workers have harvested it and whether six workers protect the producers, alongside available labor. After a loaded return, **Protect producers** commits that labor; while tended, **Withdraw protection** releases it. Both actions share the existing mouse/touch path and fit beside trail and investigation controls. The view does not show producer condition, exact exterior stock, predator pressure, pulse schedule or predicted yield. A depleted-source cue remains a last-return report.

Expose brood, resources, labor, and Food Exchange development through appropriate selection/context. Prioritize selected chamber, major flows, condition, representative ants, other nodes, then texture. No literal tunnel cutaway or permanent Colony Overview panel.

## Input and diagnostics

Use named Godot input actions: select, pan_or_rotate, zoom_attention, pause, time_1, time_4, time_16, time_64, toggle_inward, and development-only debug_world. Mouse and touch drag must call the same rotation logic; player actions cannot require hover or keyboard-only access. Android packaging can wait.

The F3 debug world is a clearly labeled development view with raw truth/knowledge inspection. It may use conventional geometry and utilitarian colors. It must be excluded or inaccessible in normal release play and must not become a player-facing minimap.

Card 046 adds a small muted alarm arc and ALARM label to a remembered source only after a survivor returns or a wholly lost group misses its expected return. Selected context initially reported cumulative lost workers with cause uncertain (card 055 adds delivered witness evidence); source EMPTY remains a separate returned-resource cue. Cancel becomes STOP TRAFFIC on alarmed active/depleted routes and uses the existing mouse/touch recall command. No threat location, identity, saturation timer or immediate casualty count is exposed. Normal population and route counts include unresolved travelers until their report settles. A different known source can receive the released labor.

Card 047 replaces OUTWARD resource rings with irregular soft membranes/motes; water has partial flattened ripples, protein curved fibers, carbohydrate warm particulate glow, and returned alarm a red-orange broken edge. Depletion remains muted sparse remnants plus EMPTY. Trail cores take the resource family color, with bounded drifting chemistry; strong/weak/ghost thresholds remain unchanged. At most six established links each draw three representative ants, plus three near Home; ghosts and idle/unseen links draw no traffic. INWARD has distinct soft functional membranes and at most four flow representatives. Existing selection/hit targets/context controls are preserved. Decoration freezes on pause and stays at real-time speed. The returned-loss cue plays once per new report batch and never replays old alarms on load.

Card 048 adds a pale interleaved FOREIGN edge/label only after returned crossing chemistry; the selected source says Foreign chemistry reported on trail. This identifies an unfamiliar chemical presence, not an enemy nest, confirmed hostility or current force size. Stop Traffic remains the shared recall response; other known sources can receive labor. Resource family, EMPTY and returned mortality ALARM remain separate cues.

Card 049 adds six bounded colliding strokes only after contested evidence reaches home. Selected context says Contested, Foreign workers withdrew, Workers withdrew or Contact dispersed from returned reports, with any returned losses. The route plus button becomes +4 after two foreign reports; both mouse/touch use the existing target command. Reinforcement costs available labor and travels before contact. Stop Traffic withdraws; normal UI receives no live battlefield, side counts or enemy position.

Card 050 adds a conditional Guest function only after an observed entry, joined abstractly to Nursery. Its context progresses from tolerated to uncertain nursery losses, internal foreignness, then purged. A faint Nursery arc appears only with associated foreignness. Nursery shows emerged and lost brood separately from adult counts. Increase Rejection/Stop Rejection are touch-sized contextual actions distinct from chamber and adaptation actions; commanded worker commitment is visible, private odor acquisition/damage schedule/population are not. No evil music announces an undetected cost.

Card 052 focuses an organic Adaptation Web when its INWARD function is selected. Back to Colony closes attention; normal modes remain OUTWARD/INWARD. Violet genetic leaves show available/trial/expressed/alternative states and actual brood-trial costs/actions. A green Honeydew relationship leaf appears only after a returned source report, distinguishes observation from harvest/protection, and offers existing Protect/Withdraw actions with its real labor cost. At most four graph nodes/three links; curves and focus arcs avoid labels. No hidden traits, source condition/schedule or gene purchase for a relationship. Mouse/touch share the same leaf/action path.

Card 053 makes repertoire an inspect-only overview. Graph nodes only select; a selected genetic leaf offers its one trial action at the same context position for either trait. Available/growing/inherited/alternative states stay distinct; no graph click pays a cost.

Card 054 replaces the continuous home activity loop with up to three finite scout departures: side approach, climb, disappearance. Decoration freezes on pause and is independent of simulation speed. OUTWARD has up to eight grouped selectable launch-direction traces; repeated taps cycle nearby missions. Time/rain fades local scent into a broken-cap memory stub. Context shows simulated dispatch age, awaiting return or completed duration; no death inference or worker-recruitment buttons. Only a returned scout supplies a bounded coarse remembered course, rendered in sensory bearing bands rather than physical coordinates. Resource targets retain selection priority.

Card 055 moves the casualty alarm off the food cloud onto its abstract journey curve. The marker does not estimate a hidden danger location; mouse/touch selects the associated resource/route context. Returned evidence distinguishes sudden/repeated attacks, foreign fighting, and unwitnessed missing workers; context preserves mixed uncertainty and shows report age/outcome. Three evidence lines add 48 logical pixels to the body/action layout without shrinking touch targets. Source EMPTY remains independent. No new live loss notification or identified predator is exposed.

Card 056 labels inherited possibilities separately from adults expressing them in the selected trait context. Genetic summaries are detached and preserve expected counts while journey losses remain unreported. No live private casualty bundle or individual genome appears in normal UI.

Card 057 expands the focused web to at most five nodes/four links. Persistent chemistry appears only after delivered wet-journey experience and surviving brood variation. Before revelation, the overview may mention observed weakened scent and possible brood variation without showing an unknown trait. Its one contextual action names the chemistry brood trial and real costs; graph clicks remain free selection. Growing, candidate, inherited and waiting-for-focused-trial states differ. Effects say 'up to' because living adult expression scales them; no seed/probability or weather forecast appears. Standard/compact touch targets remain separate from context and mode controls.
