# Graphics proof assets

Original Antzenpile artwork, generated from committed authoring sources. No downloaded model, paid addon or runtime 3D scene.

- `worker_walk.png`: chestnut worker, baked light, 12 walk poses; 128-pixel cells in a 6×2 atlas. Head faces up in each cell. Six articulated legs attach to the mesosoma; petiole, gaster, mandibles and elbowed antennae are explicit geometry.
- `worker_scent.png`: white silhouette using the same pose alpha, for colored exterior ants.
- `scent_cloud.svg`: bounded reusable gradient cloud mask. `water_impression.svg`: uncertain surface suggestion blended only from approved confidence.
- `nursery_earth.svg`: bounded earthen Nursery vignette, never a physical chamber location.

Regenerate from the repository root using installed free authoring tools:

```powershell
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' --background --factory-startup --python tools/art/generate_worker_atlas.py
& 'C:/Users/Michael/anaconda3/python.exe' tools/art/generate_proof_vectors.py
```

Worker authoring was verified with Blender 5.2.2 LTS. Scratch pose renders go into ignored `.godot/art_worker`. Import assets with the repository's pinned Godot after regeneration. No user preferences or external scene/model files are required. Krita 5.3.4 is available for future manual refinement; it was not needed for these generated sources.
