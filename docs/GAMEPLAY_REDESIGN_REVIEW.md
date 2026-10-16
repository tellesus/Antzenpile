# Gameplay coherence review — player feedback, 2026-10-15

The player rejects the current UI as final and reports unsatisfying combat, an adaptation web that feels unchanged from the demo, and unclear Midden appearance/construction/staffing. This is a design problem as well as a presentation problem. Passing automated tests did not establish coherent or enjoyable play.

## Implemented in this pass

192 replaces the shared blue rectangular skin, gathering/combat count editors, conflict action shapes and flat entrance art. Known adaptation families are directly visible/selectable instead of hiding behind a button for the next family. Context text fits its panel. The Midden explains that accumulated waste exposes an open refuse heap; cleaners can work there immediately, while building isolation doubles their cleanup. These are existing rules, not a new construction system.

193 repairs a release-only correctness fault: worker reservations, transfers, payments and other mutations inside debug assertions were omitted by the Windows release engine. This explains the missing recruitment pool displayed as `-1/12`. Recruitment, related combat/rival operations and affected scout/weather/refuge/reproductive operations now execute outside assertions. Editor tests alone were insufficient; an actual release test package is now required. This repairs broken execution, not combat satisfaction.

## Findings that remain design work

**Combat:** the implemented choices are response size, borrowing other labor, defend versus confirmed-predator hunt, optional survey, retreat and alternate course. Recruitment, physical travel and returned information are separate phases, but the player gets a numeric order and then waits. More art cannot supply a meaningful decision if different orders do not produce legible strategic tradeoffs. First evaluate the corrected release with a single reproducible encounter: why intervene, what is being risked, which alternative protects the colony, and what the return teaches. Do not add live enemy health or omniscient tactical controls to compensate for weak feedback.

**Adaptation:** ten traits exist across six families, but only two starting leaves are visible and later families depend on experience plus brood eligibility. The old next-family navigation concealed choices that already existed. Even after navigation is fixed, small paired percentage tradeoffs and waiting for brood may not create enough progression. A subsequent design card should map each existing trait to an observable colony problem, a specific behavior it enables, its cost in a favorable environment, and how the colony learns it. Assess the two starting choices and one later family in actual play before adding more trait entries. Do not claim more catalog entries alone solve depth.

**Construction:** the game conflates an existing colony function, noticing its workload, and building a more effective organ. The Midden exposes that ambiguity: generation reaches a reveal threshold, then workers may clean the open heap, then a paid project doubles effectiveness. Clearer copy is an immediate repair. The next design decision is whether this functional-development model is desirable throughout the colony, or whether some actions genuinely require a constructed organ. Changing that prerequisite is a gameplay decision, not a cosmetic label change. Audit Nursery, Food Exchange, Midden and later chambers together before locking it in.

## Proposed next bounded design outcome (not implemented rules)

Use one fresh-colony arc to connect **discover food → commit labor → observe a colony pressure → choose staffing or construction → observe the improvement → choose an inherited tradeoff**. For each step, write the player's available information, competing choices, cost, expected visible consequence and failure/recovery path. Then prototype that one arc against the existing systems. Avoid expanding the roster or adding a second economy until these choices support each other.

The current UI/art is a reviewable revision, not final player acceptance. Remaining UI work includes contextual hierarchy across dense construction/network/queen panels and stronger adaptation identity; remaining design work includes encounter pacing, meaningful progression and construction prerequisites. Same-build saves, the knowledge boundary, real travel, authoritative labor and the pinned renderer remain in force.

The player also rejected scout traces on2026-10-16.192 replaces their line-and-ring appearance with chemical ribbons and vapor, retaining honest departure memory and returned-course information. The final adaptation layout checks include the later honeydew relationship as well as the initial paired traits.
