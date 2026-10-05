# Antzenpile documentation

Current documentation, established 2026-10-05 by card 138. This is the entry point for design and implementation. The player has authorized a new 1.0 foundation and modular systems book; old plans are retired.

## Read by purpose

| Document | Authority and use |
| --- | --- |
| [Systems bible](SYSTEMS_BIBLE.md) | The planned game: shared rules, system boundaries, player decisions and 1.0 requirements. |
| [1.0 roadmap](ROADMAP_1_0.md) | Implementation order, dependencies, milestone outcomes and release gates. |
| [Current build](CURRENT_BUILD.md) | What actually exists, what is partial, and the latest recorded evidence. Never infer implementation from a catalog entry. |
| [Resource catalog](catalogs/RESOURCES.md) | Concrete foods/water sources, reusable source rules, identification and yield profiles. |
| [Chamber catalog](catalogs/CHAMBERS.md) | Functional organs, projects, staffing and planned additions. |
| [Adaptation catalog](catalogs/ADAPTATIONS.md) | Web families, existing/planned traits, evidence, inheritance and tradeoffs. |
| [Ecology catalog](catalogs/ECOLOGY.md) | Partners, rivals, predators, guests, disturbances and response families. |
| [Sites and scenarios](catalogs/SITES_AND_SCENARIOS.md) | Nest-site profiles, scenario composition and complete-run requirements. |
| [Vision](VISION.md) | The experience and its non-negotiable presentation boundaries. |
| [Architecture](ARCHITECTURE.md), [data model](DATA_MODEL.md), [UI rules](UI_RULES.md) | Current implementation contracts; update them when working code changes a contract. |
| [Decisions](DECISIONS.md) | Current accepted policies, planning changes and how to resolve conflicts. |
| [Coding rules](CODING_RULES.md), [active cards](tasks/) | How a bounded design outcome becomes tested, reviewable code. |
| [Archive](archive/README.md) | Historical plans, cards, contracts and reviews. ARCHIVE ONLY; no development order or current specification. |

## Precedence and status

Direct player instructions take precedence. Current decisions and the bible define intended 1.0 behavior; the roadmap sets order. Current-build/technical references describe implemented behavior. A difference between those two is planned work, not permission to claim it exists. Expand a bounded card before changing code.

**Foundation** means working code exists; **Partial** means only a narrower version exists; **Planned 1.0** is a release requirement not yet implemented; **Gated 1.0** needs the stated evidence before inclusion; **Post 1.0** is intentionally outside the release foundation. Catalog IDs are design identifiers, not claims of current filenames or APIs. Balance magnitudes remain authored and provisional until a card measures them.

The catalogs form the content layer of their rule families. They do not create a generic inventory, spell system, research currency or omniscient map. A new entry should fit an existing family or justify a small extension to that family's rules.

## Maintenance

- Keep a single milestone order in the roadmap; update its status after evidence is recorded.
- Update a catalog entry's implemented status only with a linked completed card. Preserve stable IDs and migration notes.
- Keep completed cards in the active task folder through their milestone handoff, then archive them with a banner and repaired links. Card numbers continue from 138; do not reuse historical numbers.
- Technical references describe code today. Future schemas belong in the bible/catalogs until implemented.
- Evidence is not authority. Historical artifacts remain in [evidence](evidence/README.md) to preserve authoring/resource paths; new evidence records its build and limits.
