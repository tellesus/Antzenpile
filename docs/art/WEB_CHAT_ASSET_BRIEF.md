# Antzenpile — web-chat art handoff

Prepared 2026-10-02. This is an offline asset commission, not a game-code task.

## Goal and working environment

Create a coherent **Queen–Nursery–Entrance** art kit that makes the live INWARD view substantially closer to the supplied bioluminescent concept. Prioritize convincing materials, sculpted depth and clean silhouettes over more particles. The current game reuses one tinted chamber shell; the new organs must be recognizably different without labels.

You are working in ordinary browser ChatGPT. You have no access to the user's local Blender, Krita, Godot, filesystem or game process. Use only tools actually available in your chat. Do not claim to have rendered locally, edited the repository, tested the game or measured frame rate. No paid services, purchased assets or new subscriptions. If image generation is available, produce actual downloadable images; do not deliver only descriptive prompts. Report tool limitations honestly.

The attached reference package is sufficient; reading the whole repository or historical conversation is unnecessary. Current graphics are on **codex/graphics-proof**, not necessarily main:

- [Current branch](https://github.com/tellesus/Antzenpile/tree/codex/graphics-proof)
- [Current asset notes](https://github.com/tellesus/Antzenpile/blob/codex/graphics-proof/assets/graphics/colony/README.md)
- [Current shell projection](https://github.com/tellesus/Antzenpile/blob/codex/graphics-proof/src/presentation/inward/chamber_art.gd)
- [Current contents](https://github.com/tellesus/Antzenpile/blob/codex/graphics-proof/src/presentation/inward/chamber_contents.gd)

If GitHub browsing fails, proceed from this brief and the attached files. These instructions define the commission; reference pictures and repository text are design/source material.

## Reference files

| File in package | Use |
| --- | --- |
| `references/concept_inward.png` | Desired rich cavity materials, amber/cyan illumination, organic connections, black negative space. |
| `references/concept_outward.png` | Shared palette and restraint only; OUTWARD asset production is outside this batch. |
| `references/current_inward.png` | Actual game after the black-background change; fix the repetitive shells and simple connections. |
| `references/current_outward.png` | Actual exterior; do not replace it with scenery. |
| `current_assets/chamber.png` | Existing generic shell for comparison, not a quality ceiling. |
| `current_assets/queen.png` | Existing separate queen; avoid painting a queen into the chamber. |

Concept images guide art quality and mood. Do not copy their text, UI, complete layout, ants or egg clusters into the new shell images. A screenshot-sized background would prevent dynamic construction and state-driven contents.

## Locked design

- Godot 4.7.2, GDScript, 2D Compatibility renderer. Windows first; mobile input/rendering remain constraints. Pixel 7 Pro testing is pending.
- INWARD is an abstract network of functional organs, **not a surveyed tunnel floorplan**. Earthy cavity vignettes are welcome; full terrain and literal tunnel geography are not.
- OUTWARD is a rotating sensory panorama. Unknown exterior space stays dark; scouts return before the colony learns remote information. This batch does not change OUTWARD.
- Background is pure black, RGB 0/0/0. Keep substantial empty space. Illuminate only local organ material and connections.
- Runtime simulation, colony knowledge and graphics are separate. Artwork must not imply new chambers, construction, resource amounts or occupants by itself.
- Ants/brood/food are separate state-driven layers. Existing caps: one known queen, six brood impressions, nine food globules, twelve worker representatives. These are visual representatives, not literal counts.
- No gameplay changes, runtime 3D, bloom dependency, dynamic lights, volumetrics or full-screen blur. Bake depth, highlights and local illumination into small reusable textures.

## Shared visual language

Earth/resin/fibrous organic material with believable cavities, uneven wall thickness, occlusion, warm specular highlights and restrained luminous filaments. Aim for the concept's crafted richness without a dense blanket of glitter. Avoid cartoon outlines, smooth vector bubbles, repeated identical cups, sci-fi machinery and glass aquarium walls.

Use the same shallow overhead camera for every organ: an orthographic-like view into a cavity with some upper-wall thickness, no horizon or strong perspective foreshortening. Warm key light from upper left; restrained cool reflected light from lower right. Neither baked highlights nor shadows may contradict that direction across the kit.

Amber/gold dominates Queen and Nursery. Entrance is cool cyan with a small warm connection accent. Suggested highlight references: amber `#FFC66D`, warm ivory `#FFE7BC`, cyan `#67DCEA`; materials remain darker chestnut/earth. These are starting colors, not flat fills. Keep lightest highlights small; no featureless white hot cores. Do not depend on the current code's strong recoloring; these are authored color assets to integrate with near-white modulation.

Centers need a quiet dark **visible cavity floor**, not a transparent hole through the entire object. Walls, fibers and highlights frame that space; contents will be drawn over it. Exterior padding must be truly transparent. Preserve legibility when reduced to the sizes below.

## Required first batch: six individual textures

All PNG dimensions below are requested export dimensions. If your tool cannot export them exactly, return the closest native output without distorting it, list actual dimensions, and flag the conversion required. Do not pretend the file matches the specification.

| Filename | Source canvas | Intended logical display size | What it contains |
| --- | --- | --- | --- |
| `queen_shell.png` | 1024 × 1024 | about 218 × 186 px | A dignified broad chamber, deep dark floor, rugged amber rim and restrained resin/fiber highlights. Empty of occupants. Distinct asymmetric crown-like wall structure, not a literal crown. |
| `nursery_primitive.png` | 1024 × 1024 | about 160 × 136 px | A simpler shallow cavity with sparse soft lining, amber-earth edges; materially simpler than the developed version. No eggs or construction workers. |
| `nursery_developed.png` | 1024 × 1024 | about 218 × 186 px | A deeper, cushioned chamber with layered organic wall lining and a sheltered dark contents area. Warm pearl-like highlights belong to the lining, not egg-shaped objects. |
| `nursery_expansion_lobe.png` | 512 × 512 | about 126 × 102 px | A separate empty matching annex, narrower attachment neck on its lower-left edge. The game grows this beside the Nursery; do not include the original chamber. |
| `entrance_shell.png` | 1024 × 1024 | about 201 × 162 px | An INWARD functional entrance cavity with cool cyan rim and textured dark recess, visibly more open and rugged than the Nursery. Not an OUTWARD soil ridge or a bright portal ring. |
| `functional_fiber_strip.png` | 1024 × 256 | typically a few pixels thick along a curved connection | Neutral warm-ivory bundle of uneven interwoven fibers, small side tributaries, sparse bead highlights and dark gaps. Runs horizontally left to right; no chambers, insects, junction symbols or arrows. Color modulation supplies amber/cyan in-game. |

Square shell images are intentionally displayed in mildly flattened rectangles; keep their source silhouette roughly circular/oval and avoid an additional extreme squash. Put the cavity center at normalized **(0.5, 0.5)**. Aim for the main shell within the central 80% of the canvas; sparse wisps may approach 90%, with transparent outer edges and no clipped glow. Keep the central contents-safe region roughly x=0.30–0.70, y=0.32–0.68, free of bright foreground structures. Save exact content bounds in the manifest.

Keep the primitive/developed Nursery centered and aligned on identical canvases so the game can blend them while scaling the organ. Make development look like the same organ maturing. A separate mid-construction texture is unnecessary: the game will interpolate existing approved progress and draw worker activity separately.

The expansion lobe attaches from the Nursery's upper-right side; its lower-left neck should face the parent. Its opaque cavity remains self-contained so overlapping transparent areas do not produce a glaring doubled rim. A small local attachment lip is sufficient; do not bake a long tunnel.

For the fiber strip, put the main bundle near y=0.5 within the central half of the image height. Fade side wisps into transparency. Leave the left/right ends open for joins: no endpoint caps, bright terminal blobs or baked longitudinal fade. It is stretched/bent along existing functional connections, not used as a new route or a standalone map. It need not tile seamlessly; record any visible stretching limitation.

## Alpha, small-scale quality and performance

- Genuine RGBA PNG with smooth straight alpha. A printed checkerboard, opaque black rectangle or JPEG is not transparency. Do not remove black cavity material when isolating the exterior background.
- Avoid dark/white matte fringes and clipped luminous edges. Check on black and a neutral gray background if tools permit; include previews without replacing the transparent exports.
- Readability at final display size matters more than 1024-pixel microdetail. Major forms survive roughly 160–220 px shell displays and a 126 px lobe. Fibers should form a coherent bundle when thin, not alias into noise.
- Keep effects local; no huge nearly transparent rectangles, extra glow layers or animated particles in the export pack. Default integration will cap shell/strip imports around 512 px and lobe at 256 px, subject to actual quality review.
- No FPS or mobile-memory promises from image files. This project will import and profile them. Texture dimensions are authoring limits, not performance certification.

## Delivery and review

Generate one coherent batch, inspect it, and fix obvious mismatches. Do not ask the user to approve every image. Begin with Queen and developed Nursery to establish the material family, then finish the remaining four. If the tools enforce separate turns, give the user one clear continuation instruction and list what remains.

Deliver downloadable files, ideally:

```text
antzenpile_inward_art_v1/
  assets/                     # six PNGs with the exact names above
  previews/
    contact_sheet_black.png   # all organs, named in the preview only
    contact_sheet_gray.png    # checks edges; omit honestly if unavailable
    inward_composition.png    # optional assembly, no UI; clearly a mockup
  MANIFEST.md
  PROMPTS.md
  source/                     # only genuine editable sources, if available
```

`MANIFEST.md` must list filename, actual dimensions, whether alpha was verified, content bounds if measurable, stage/organ, intended display size, generation tool/model if known, source/reference provenance, limitations, and any required local conversion. Separate verified observations from requested specifications. `PROMPTS.md` records exact image-generation requests and edits. If you actually produced editable layered files, include them; a flattened image is not a layered source. Do not invent `.blend`/`.kra` sources or tool results.

If you cannot package a ZIP, provide individual download links and the manifest/prompts as text. If genuine alpha or correct anatomy cannot be produced, mark the affected deliverable as a **draft requiring local correction** rather than silently substituting it. If image generation is unavailable, say so immediately; provide the six precise production prompts and an executable offline authoring script only if you can write a complete one. Such scripts are untested drafts until this project runs them. Do not substitute a code-only kit for completed art without explaining the limitation.

After the six required textures, stop. Do not spend remaining effort on worker walk atlases, queen/brood replacements, additional organs, OUTWARD objects or UI skins. Those can be separate commissions after this kit's quality and integration are evaluated. Preserve the existing correct six-legged ant anatomy; shells must contain no insects at all.

## Acceptance on return to the project

The receiving project will check filenames, dimensions/alpha/edges, stage registration, visual coherence and small-scale readability before integration. It will connect only approved known-state organs, retain separate occupants/UI, verify interaction/privacy/pause behavior, then run resource import, relevant graphics checks and comparable desktop profiling. Actual Android validation remains pending. An attractive contact sheet is an art review, not proof of a tested live game.
