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

## Details to resolve in their task

Scout cap/pathing parameters, knowledge uncertainty formulas, trail balance and cohort bucket duration, brood/resource rates, the precise Food Exchange benefit and costs, rain timing/intensity, save migration policy, and measured rendering budgets. Roadmap cards must resolve their own required details before coding. Do not implement later ecology, adaptation, rivals, or replay just because their names appear in the design.

## Change log

- Initial documentation pack: locked decisions distilled; foundation defaults labeled; implementation tasks remain unstarted.
- 2026-09-28 / 001: A01–A02 resolved to `4.7.2.stable.official.ed1daf0bf` and Compatibility (`gl_compatibility`). Verified Windows import, runner, headless Main, and editor launch. No architecture change.
