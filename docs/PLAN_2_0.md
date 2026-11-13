# Antzenpile 2.0 plan

Status: draft 2, 2026-11-13. Decisions marked **Decided** were agreed with Michael on that date. Everything else is a proposal until a playtest confirms it.

This is the only planning document. Version 1.0 lives in `archive/v1/` for reference and sets no rules for 2.0.

## 1. The game in one paragraph

You are an ant colony: one mind spread across thousands of bodies. The world is dark except where your ants are touching it now, and dimly remembered where they touched it before. You never give an ant an order. You lay scent, and the colony flows along it. Over one year of about 60–90 minutes you find food, grow, claim ground, fight rival colonies, survive predators and weather, and launch new queens in autumn. Your lineage carries what it learned into the next run.

## 2. Why 2.0 exists

Version 1.0 has an honest, deep simulation and three problems that more polish would not fix:

1. **No place.** The view was a fan of trails into a void, so there were no positional decisions.
2. **One verb.** The player sent a number of workers and waited for a report. The interesting part happened off-screen.
3. **Progression was percentages.** Traits changed numbers rather than what the colony could do.

It was also built systems-first, with fun checked last. Version 2.0 reverses the order: a playable toy first, and nothing gets built on top of a loop that is not yet fun.

## 3. Design pillars

Use these to settle arguments. If a feature breaks one, it does not go in.

1. **You see only what your ants touch.** Live where ants are in contact with the nest, remembered where they have been, dark everywhere else.
2. **You shape flow; you do not command units.** The player's hands are scent signals and brood choices, never unit selection.
3. **The world is the interface.** Trail thickness, glow, movement and sound carry the state. A panel of text is a last resort.
4. **Every adaptation is a new capability.** No "+15%" upgrades.
5. **Everything on the field follows the same rules.** Rival colonies run the same simulation as the player. Predators and weather hit everyone.

## 4. The world and what you know

**Decided:** a real top-down map replaces the 1.0 panorama.

- The map is a grid of roughly 200×200 cells holding terrain (soil, grass, stone, water, shade, human debris), food sources, nests and creatures.
- Each colony has its own knowledge of the map. Nothing is shared and nothing is given free.

**Decided:** information is live on trails and delayed beyond them.

| Where | What you see |
|---|---|
| Cells near ants connected to the nest by an active trail | Real time |
| Cells your ants touched earlier | Last known state, fading toward dark over a few minutes |
| Scouts beyond the trail network | Nothing until a scout walks back and its findings bloom onto the map |
| Everything else | Dark |

Trails are therefore the colony's nervous system. Cutting an enemy trail blinds that colony there; losing your own does the same to you. This is the main reason to build and defend a network, and it keeps the best idea in 1.0 (news travels at ant speed) while letting the player watch the action.

## 5. What the player does

### Signals

Four signals, painted on the map with a brush. Each costs nothing to lay but only works where ants can smell it, and each fades unless ants or the player refresh it.

| Signal | Effect |
|---|---|
| Attract | Foragers favour this ground; a found source reinforces itself |
| Alarm | Nearby ants mass here and fight; soldiers respond first |
| Repel | Ants avoid this ground; use it to route around hazards or abandon a trail |
| Seek | Scouts leaving the nest lean in this direction |

Ants also lay scent on their own. A forager that finds food marks the way home, others follow, and the trail thickens. The player's job is to bias and prune a system that already works, which is what makes it feel like a distributed mind and not a cursor.

### Brood

The other half of the player's hands. Each night the colony chooses what the next brood becomes (workers, scouts, soldiers, later castes, and in autumn new queens) and which chamber the nest grows next. Food in store sets how much brood can be raised.

### The nest

**Decided:** a one-screen cutaway, replacing the abstract organ network. It reads at a glance, it shows stores and brood as real piles, and it gives chamber choices a position.

- About ten chamber slots across three depths.
- Shallow chambers are warm (fast brood) but exposed to raids, heat and flooding. Deep chambers are safe and humid but slow.
- Chamber types: queen, nursery, food store, water store, midden, soldier barracks, plus adaptation-specific chambers.
- No tunnel routing and no ant-by-ant management inside.

One continuous zoom goes from the whole territory down through the entrance into the cutaway.

## 6. The loop

| Timescale | Length | What happens |
|---|---|---|
| Moment | Seconds | See a signal, paint, watch a trail form, thicken or break |
| Day | About 4 minutes | Forage and fight in daylight. Different creatures are active at dusk |
| Night | About 1 minute | Ants come home. Choose brood and one nest change. Read the day's gains and losses on the cutaway |
| Season | 4 days | Each season changes the map and the goal |
| Year | 16 days, about 80 minutes | One run |
| Lineage | Across runs | Queens launched carry one or two adaptations forward |

**Decided:** a run is 60–90 minutes.

### The year

| Season | World | Pressure |
|---|---|---|
| Spring | Scarce food, soft ground, rain | Found the nest, find the first reliable sources |
| Summer | Abundant food, heat, peak predators | Expand, meet rivals, contest ground |
| Autumn | Rich but shrinking food | Raise and launch queens; rivals do the same |
| Winter | Almost no food, cold | Live on stores; the colony that stored enough survives |

**Score** is queens launched in autumn. **Survival** through winter lets the run continue into a second year for players who want it. **Loss** is the death of the queen with no replacement.

## 7. The four X's

- **Explore.** Scouts wander outward and return with a strip of map. Seek biases them. Memory fades, so old ground needs revisiting.
- **Expand.** An outpost can be dug at any point on an established trail. It shortens haul distance, anchors territory and stores a little food. Ground your ants walk often becomes scent-marked territory, where your ants fight better and navigate faster.
- **Exploit.** Sources behave differently enough to need different handling:
  - nectar and fruit: fast sugar, short-lived
  - aphid herds: steady sugar while tended and guarded
  - seeds: heavy, slow, store all winter
  - carrion: a large protein windfall that every colony and scavenger wants
  - dew and seeps: water, vital in summer heat
  - human crumbs: huge, brief, in dangerous ground
- **Exterminate.** Fights happen where flows meet. The decisions are where to mass, when to commit soldiers (who eat but do not forage), which chokepoints to hold and whether to raid a rival's stores, cut its trails or starve it of a source.

## 8. Rivals, predators and hazards

**Decided:** all three are designed and built together.

**Rival colonies** run the identical simulation: same ants, same signals, same brood and nest rules, same blindness. An AI controller paints signals and picks brood in the player's place. Personalities come from weights, not special rules:

- Raider: many soldiers, early aggression, weak economy.
- Farmer: defends aphids and seeds, slow, strong in autumn.
- Scavenger: wide thin trails, avoids fights, steals from kills.

A normal map has two or three rivals. Because rivals are blind in the same way, the player can ambush, feint and cut them off, and can be fooled in return.

**Predators** attack any ant, player or rival:

- Spider: fixed ambush site that makes a stretch of ground deadly.
- Ground beetle: roams at dusk, follows busy trails.
- Antlion pits: static traps in sandy ground.
- Bird: rare, strikes a crowded open area.

Predators can be killed by enough massed ants (and become carrion), avoided with Repel, or used. A trail that draws a beetle onto a rival's supply line is a legitimate play.

**Hazards** are impersonal: rain washes scent away and floods shallow chambers, heat makes open ground costly at midday, and footsteps or a lawnmower flatten a strip of map.

## 9. Adaptations

Each adaptation is a capability with an upkeep cost. A colony unlocks about four to six per run from a pool of roughly twelve, so runs differ.

| Adaptation | Unlocks | Cost |
|---|---|---|
| Majors | Soldier caste that holds chokepoints and kills large prey | Heavy protein upkeep |
| Repletes | Living storage; stores survive raids and floods better | Workers taken out of the field |
| Aphid husbandry | Move herds closer to the nest and guard them | Standing tenders |
| Bridging | Cross gaps and water with living chains | Ants locked in the bridge |
| Night foraging | Work through dusk and night | Meets night predators |
| Seed milling | Seeds become brood food | Needs a mill chamber |
| Trail architects | Cleared highways: faster and rain-resistant | Slow to build |
| Slave raiding | Stolen rival brood hatches as your workers | Provokes the victim |
| Chemical mimicry | Walk rival ground unchallenged for a time | Scouts only |
| Venom | Stronger against predators | Sugar upkeep |
| Rafting | Survive floods; cross water as a raft | Loses brood in transit |
| Thermal tolerance | Forage at midday in summer | Slower in cool weather |

An adaptation is offered when the colony has met the pressure it answers (lost ants to a beetle, had a store flooded, found aphids). The offer appears at night as a choice between two or three.

## 10. Simulation design

- **Headless and deterministic.** The simulation has no dependency on scenes, rendering or input, takes a seed, and can be run and tested from the command line. This carries over from 1.0 and is worth keeping.
- **Ants are simulated as squads.** One simulated agent stands for about five ants and is drawn as several. Target 1,500–2,500 agents across all colonies, ticking ten times a second, with rendering interpolated between ticks.
- **Fields.** Per colony: four signal fields, a territory field and a knowledge field. Shared: terrain, food and hazards. Fields diffuse and decay each tick.
- **Agent behaviour** is a small state machine (idle, scout, forage, haul, fight, tend, flee) that reads local scent and picks a direction with some randomness. Emergent trails come from this, not from pathfinding.
- **Speeds** are pause, 1×, 2× and 4×. The 64× of 1.0 is unnecessary once the action is watchable.
- **Saves** work mid-run within the same build. No compatibility across builds until there is a reason for it.
- **Tests** cover conservation (ants, food), determinism and a few scripted scenarios. A release-export smoke test runs before every playtest build, because 1.0 was bitten by logic placed inside `assert`, which release builds strip.

## 11. Engine and rendering

**Recommendation: stay on Godot 4, switch from the Compatibility renderer to Forward+.**

- The visual ceiling of 1.0 came from the renderer choice. Forward+ gives HDR 2D, real bloom, GPU particles and compute shaders, and the development machine (RX 6650 XT) runs it comfortably.
- Another engine would cost a rewrite of everything and gain nothing this game needs.
- GDScript first. If the phase 1 measurement misses budget (10 ms per tick at 2,500 agents), move only the agent and field update into C# or a GDExtension.
- Pin the engine version at the start of phase 1 and record it here.

## 12. Visual direction

Keep the neon-on-dark identity from 1.0. It was the right call. Change almost everything else.

- **One style.** Everything is drawn as the colony senses it. The photoreal mound from 1.0 goes.
- **Terrain is touch.** Known ground shows as a faint relief texture, tinted by type, at about 10–20% brightness. It gives the eye a place without lighting the scene.
- **Scent is light.** Signal fields render as glowing fluid through a shader with HDR bloom. One hue per signal: amber attract, red alarm, violet repel, cyan seek. Rival scent is desaturated and alien-looking.
- **Ants are particles.** Thousands of tiny bright bodies. A strong trail reads as a river of light, a failing one as a broken dotted line.
- **Memory decays visibly.** Stale areas lose detail, grain up and sink into black.
- **News arrives as a bloom.** A returning scout's knowledge spreads onto the map from the nest entrance outward.
- **The cutaway** uses the same language: chambers as lit hollows in dark earth, stores and brood as countable glowing piles.
- **Interface.** A brush wheel for signals, one resource strip, a season and day ring, and the night choice cards. Detail appears on hover. Target: fewer than 40 words on screen in normal play.
- **Colour-blind safety.** Signals differ in pattern and motion as well as hue.

## 13. Sound and music

**Decided:** the 1.0 audio is dropped and redone.

Sound effects matter more than music here, because sound is a second channel for state the player cannot see.

- **Colony voice.** A soft granular bed whose density follows the number of active ants and whose pitch follows food income. A healthy colony hums; a starving one thins out.
- **Signal sounds.** Each of the four signals has a short tone when painted and a faint texture where it is strong.
- **Spatial events.** Alarm, a kill, a scout returning, a predator's approach, rain. Panned and attenuated by map position so the player can hear where to look.
- **Music.** Sparse, slow, layered stems that follow season and tension (calm, contested, under attack, night). Silence is allowed.

A limitation to plan around: Claude cannot hear. It can build the audio system, wire the layers and source or synthesise candidates, but Michael has to judge every sound by ear. To keep that cheap, audio work is delivered as short labelled audition sets with a keep or reject answer, and licensed CC0 recordings are preferred over code-generated music, which is where 1.0 went wrong.

## 14. Phases

Each phase ends with a build Michael plays. The gate is the same every time: is it fun for 20 minutes, and what was the dull part? A phase that fails its gate is reworked before the next begins.

| Phase | Build | Gate question |
|---|---|---|
| 0. Setup | New Godot project on Forward+, headless test runner, export smoke test, 1.0 archived | Does an empty map run and export? |
| 1. Toy | Map, fog and memory, squad ants, emergent trails, one food type, four signals, bloom rendering, signal sounds | Is steering the flow satisfying with no goals at all? |
| 2. Opposition | One rival colony on the same rules with a simple AI, spider and beetle, alarm and combat, territory | Is there a fight worth winning, and can you read it? |
| 3. Colony | Nest cutaway, brood choices, castes, day and night, stores, outposts | Do night choices change what you do the next day? |
| 4. Year | Seasons, weather, source variety, queen launch, winter, scoring, six adaptations | Does a full run have a shape, and do you want another? |
| 5. Breadth | Remaining adaptations, three rival personalities, three maps (backyard, garden edge, roadside), lineage carry-over | Do two runs feel different? |
| 6. Finish | Final art pass, music, onboarding in the first spring, settings, save and load | Can someone new play without help? |

Rivals and predators arrive in phase 2, before the colony interior, because the field has to be fun with opposition before an economy is layered onto it. They are designed together now (section 8) so nothing built in phase 1 has to be redone for them.

## 15. What carries over from 1.0

| Keep | Drop |
|---|---|
| Headless simulation separate from presentation | The panorama and the abstract organ network |
| Seeded determinism and conservation tests | Routes as abstract graph edges |
| Source, creature and site ideas as content | Order, draft, receipt and report vocabulary |
| Neon-on-dark identity | The report journal as primary feedback |
| The three scenario settings | Percentage traits and paid trait trials |
| | The Compatibility renderer and 64× speed |
| | All 1.0 audio |
| | The card-per-task documentation process |

Little 1.0 code ports directly, because it models routes and 2.0 models space. Treat `archive/v1/` as a reference for ideas and tuning, not as a codebase to refactor.

## 16. Risks

1. **The toy may not be fun.** Flow-steering games live or die on feel. Phase 1 exists to find out in days, not months. If it fails, the fallback is more direct control (rally points), decided then.
2. **Legibility.** Glow on black can turn to mush with three colonies on screen. Phase 2 tests this deliberately; colour budget and rival desaturation are the tools.
3. **Rival AI.** A colony that paints signals well is hard to write. Start with a scripted opener plus simple rules, and let blindness hide its mistakes.
4. **Performance.** Measured in phase 1 with a stated budget and a stated fallback.
5. **Scope.** Twelve adaptations, four predators, three personalities and three maps is a lot. Phase 4 ships with half of each, and phase 5 is where cuts happen if needed.
6. **Audio.** See section 13.

## 17. Working method

- One plan (this file), one short decision log, one changelog. No per-task cards and no evidence folders.
- Small commits on `v2`. `main` stays as 1.0 until a 2.0 build is good enough to replace it.
- Tests protect the simulation. Playtests judge the game. Passing tests is never reported as progress on fun.
- Blunt feedback after every build. "This is boring" in phase 1 saves weeks.

## 18. Decisions from 2026-11-13, second round

- **Decided:** Claude runs builds on the development machine through the connected local repository folder. Michael still plays every gate build himself.
- **Decided:** desktop first, mouse and keyboard. Nothing is designed around touch. A mobile version is considered only if the finished game is fun.
- **Decided:** lineage carry-over happens between runs only, as one or two adaptations. Saving a named lineage to reuse later is a possible addition after phase 6, not part of this plan.

## 19. Open questions

1. Is there a name for the species, or does the game keep the fictional composite from 1.0?
