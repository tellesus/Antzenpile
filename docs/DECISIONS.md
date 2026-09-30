# Decision register

Source: **Ant Game Brainstorm**, GDD v0.2 Parts 1–8, with Part 7A overriding earlier visual ambiguity. This file separates locked design from implementation defaults; changing a lock requires an explicit design decision.

## Locked

| ID | Decision |
| --- | --- |
| D01 | Godot 4.x and GDScript; agreed stable 4.7.x family. Windows first, Android-compatible architecture now, iOS later. Pin tested patch at bootstrap. |
| D02 | Hidden physical 2D world; reality, simulation, knowledge/perception, and presentation remain distinct. Graphics never own gameplay. |
| D03 | Headless simulation, lightweight typed runtime state, immutable authored definitions, explicit versioned serialization. |
| D04 | One fixed simulation clock; seeded run-owned gameplay RNG. Decorative randomness is separate. |
| D05 | Aggregate workers/brood/foragers; capped individual scouts are the exception. One authoritative worker ledger. |
| D06 | TrailRoute and TrailSegment are distinct objects even when initially one-to-one. Aggregate bucketed transit; recall requires return. |
| D07 | Chemical pheromone and learned route familiarity are distinct; rain weakens exposed chemistry while familiarity largely persists. |
| D08 | OUTWARD is a rotating 2D sensory panorama centered on a pile. No normal-play physical map or minimap; no literal 3D world camera. |
| D09 | INWARD is an abstract functional network, not literal chamber geography/tunnels. First four nodes use authored positions. |
| D10 | Negative space communicates absence of relevant information. Thin luminous trails, abstract signal clouds, restrained contextual UI and glow. |
| D11 | Representative ants/effects are pooled and capped. Mobile-safe rendering; no reliance on costly volumetrics, GI, refraction, or many lights. |
| D12 | Slice connects exterior resource success to brood and Primitive → Developed Food Exchange, including one synchronized music stem. |
| D13 | Named input actions; mouse and touch share interaction logic. Simulation belongs to the active run, not global manager singletons. |
| D14 | Debug truth view is development-only. Normal views receive knowledge-derived signals/approved colony summaries. |
| D15 | User clarification, 2026-09-29: scouts sense nearby resources and progressively locate them; discovery does not require crossing the exact resource point. Private evidence still reaches the colony only upon return. |

## Provisional defaults for executable tasks

These are scaffolding choices to remove routine ambiguity, not additional locked game design.

| ID | Default / resolution point |
| --- | --- |
| A01 | Godot 4.7.2 stable is the candidate named earlier in the conversation and listed in the official archive on 2026-09-23. Task 001 records actual version/build and verifies it; do not silently substitute another family. |
| A02 | Start with the Compatibility renderer for the 2D bootstrap and mobile reach; verify the intended 2D visuals remain feasible. Record actual rendering method in 001. Choosing Godot's Mobile renderer later requires a documented reason and checks, not an assumption that glow needs it. |
| A03 | Initial fixed interval 0.25 simulated seconds (4 ticks/second at 1×); speeds 1/4/16/64. Preserve fractional time and backlog rather than silently dropping ticks. |
| A04 | World units: meters, +x east, +y south; 40×40 authored backyard fixture with bounds (0,0)–(40,40) and home at (20,20). Layout is fixed; seed controls explicit fixture variation only. |
| A05 | Foundation fixture: 40 available living workers and 1 queen. Task 005 excludes brood. Later slice fixture defaults: one egg cohort of 8 (task 016), reserves 10 carbohydrate/5 protein/10 water in abstract units as resource storage is introduced. Brood/reserves are test defaults, not approved balance. |
| A06 | Clock owned by RunState; pile worker totals/available are ledger-backed; colony totals derived. This resolves duplicate-looking ownership in Part 8's conceptual fields. |
| A07 | Foundation test APIs/paths and fixture node coordinates in 001–006 are proposed implementation contracts. Equivalent local organization is acceptable if boundaries and acceptance checks remain explicit. |
| A08 | Task 007 prototype defaults: cap 4 scouts, speed 1 m/s divided by terrain cost, 30 simulated seconds exploring plus actual return travel, 8–12 m targets, directional cone ±45°, cardinal 1 m grid. Authored in `data/scouting/default_scouts.tres`. Blocked travel retains the committed worker and retries; mortality/rescue gameplay remains deferred. These are provisional implementation values, not locked balance. |

## Details to resolve in their task

Task 008 sensory defaults: 4 m chemical cue radius, 1 m proximity confirmation, uncertainty radius 0.25 m + half the closest sensed distance. Closer samples refine a seeded estimate; stationary repeats do not reroll. Scouts investigate estimates on their existing grid and retain the original mission deadline. These are provisional game-scale parameters, not a biological model; wind/plume simulation is deferred.

Task 009 knowledge defaults: one Known Node per captured source ID; newest observed time wins, then lower uncertainty, close confirmation, and lexical evidence ID. Older delivered reports add provenance without replacing fresher estimates. Baseline confidence is 0.9 (confirmed) or 0.55 (cue), divided by (1 + uncertainty radius / 4 m); effective confidence halves every 300 simulated seconds since observation. These are provisional, authored in `data/knowledge/default_knowledge.tres`, not statistical probabilities. Merging never consumes RNG or queries hidden truth.

Task 010 perception defaults: authored resource classification maps to carbohydrate/protein/water (otherwise unknown); bearing is radians clockwise from east, relative facing differences wrap to [-PI, PI), and coincident direction is null. Risk and traffic stay null. Presentation strength is aged confidence / (1 + estimated distance / 10 m); confidence labels are uncertain below 0.25, likely below 0.65, clear otherwise. Tuning lives in `data/signals/default_perception.tres`. This is display salience, not live resource quantity or chemistry. No culling/deletion policy is introduced here; task 011 resolves projection and visibility.

Task 011 OUTWARD defaults: 180-degree horizontal field, positive clockwise bearing from east, 8 logical-pixel tap/drag split, at least 44 logical-pixel signal hit radius, 64 logical-pixel-high action buttons, and distance affecting a non-geographic vertical display band. The home anchor stays fixed. These are provisional presentation settings; player UI never reads hidden world state. The first INWARD control waits for its real view in task 017.

Trail balance and cohort bucket duration, brood/resource rates, the precise Food Exchange benefit and costs, rain timing/intensity, save migration policy, and measured rendering budgets. Roadmap cards must resolve their own required details before coding. Do not implement later ecology, adaptation, rivals, or replay just because their names appear in the design.

## Change log

- Initial documentation pack: locked decisions distilled; foundation defaults labeled; implementation tasks remain unstarted.
- 2026-09-28 / 001: A01–A02 resolved to `4.7.2.stable.official.ed1daf0bf` and Compatibility (`gl_compatibility`). Verified Windows import, runner, headless Main, and editor launch. No architecture change.
