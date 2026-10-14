# Modular colony artwork

`chamber.png`, `chemical_cloud.png`, and `home_entrance.png` were generated with the built-in imagegen tool on 2026-10-02. The player's two bioluminescent colony concepts supplied art direction; neither screenshot is shipped as a backdrop. [Prompts](PROMPTS.md) record the requests. These checked-in RGBA outputs are the source assets; regeneration is optional and not deterministic. No API key, paid plugin or runtime service is required.

Godot imports chamber/cloud at a 512-pixel maximum and entrance at 1024. Keep alpha, lossless compression and linear filtering. Entrance sampling uses imported texture dimensions. Only its lower half is drawn, beneath sensory trails, ants and returned-alarm labels. Uninformed exterior space remains dark.

`queen.png` and `brood_{egg,larva,pupa}.png` are original Blender mesh renders. Reproduce with `blender -b --factory-startup --python tools/art/generate_colony_contents.py`. Queen anatomy includes head, enlarged mesosoma/gaster, petiole, six three-segment legs and elbowed antennae; larvae are legless. Lighting is baked and tone-mapped with AgX. Existing walking workers use the proof atlas.

The shell contains no ants, brood, food or controls. ChamberArt derives size, brightness and Nursery's additional lobe from detached local project state. Contents draw at most six brood representatives, nine coarse stored-food globules and one locally known queen, alongside the existing twelve-worker activity cap. Colored globules are store impressions, not brood or a count of physical food objects. Labels, costs, input targets and commands remain separate. Connections represent functional relationships, never surveyed tunnel geometry.
