# 3D character production

[Overall roadmap](../roadmap.md) · [Inventory](../3d-production.md) · Track running across milestones 1–5

**Goal:** turn the visual concepts into recognizable, animated characters inside the game. It does not require modeling everything from scratch; it requires choosing an origin and being able to maintain the assets.

## P1 — Prepare, during milestones 1–2

- [ ] Use a capsule or simple volumes while movement and interaction are being tested.
- [x] In milestone 1, import a test model with a skeleton, idle and walk, with verified license and provenance. Switch animations in the engine and in an installed build. It does not need to be the final beaver nor stay in the game.
- [ ] Review the v3 concepts and choose the species references before the final modeling.
- [ ] Harmonize front, profile, proportions and tails: a concept illustration does not guarantee coherent views for modeling.
- [ ] By the end of milestone 2, record who produces the art and choose own creation, adaptation or external production per character. Assess learning effort and visual compatibility; test a beaver made of simple volumes before settling the finish.
- [ ] Choose the modeling and animation tool when preparing the first asset. If learning is needed, start with a simple object and with the export/import cycle.
- [ ] Define the actions actually used, avoiding a catalog of animations with no role in the MVP.

**Output:** consistent references, planned origin and a minimal list of actions in the inventory.

## P2 — First integrated beaver, milestone 3b

- [ ] Model or adapt a simple version of the beaver; preserve the sturdy body, incisors and wide tail.
- [ ] Apply colors and materials from the visual direction, testing contrast with the stretch of the valley.
- [ ] Prepare the skeleton (rig) and the binding of the mesh to the bones so it deforms correctly.
- [ ] Produce idle and walk first; export and test in the engine before the remaining actions.
- [ ] Add carrying, placing and gnawing. Reuse poses/transitions where the reading stays clear.
- [ ] Define the point where the branch follows the character and check that it does not pass through the ground along the path.
- [ ] Connect animations to the game states; interrupt or repeat actions without leaving the character stuck in a pose.
- [ ] Test scale, orientation, deformations, tail and animations in an installed build.

**Output:** a beaver recognizable in the game camera, with the dam actions and without hindering the interaction. Validate together with the first stretch of environment before producing the rest.

## P3 — Support and chapter, during milestones 3b–4

- [ ] Create the owl with the pose and action needed to point out a cue. Avoid full flight if the story does not require it.
- [ ] Evaluate transform-based animations for simple appearances of the owl and otter; use a skeleton only if the action and deformation justify it.
- [ ] In 3b, create an otter distinguishable from the beaver by silhouette and tail, in a static celebration pose or with code-driven movement when the lake forms. Its own rig and animations do not block this milestone; reuse this version in 4, without requiring demonstrations.
- [ ] Add home and food actions that cannot be communicated by the existing animations.
- [ ] Prepare the final family scene with appropriate reuse, avoiding new playable characters.
- [ ] Check all appearances in the chapter; no animation may block progression.

## P4 — Finalization, milestone 5

- [ ] Fix deformations, sliding feet, poorly attached objects and abrupt transitions that make reading harder.
- [ ] Reduce complexity where measurement on the device justifies it; review materials and textures besides the meshes.
- [ ] Update sources, exports and licenses in the inventory.

**Done when:** all the characters used in the chapter work in the installed build and are readable without depending on written names. Fur, detailed fingers and animations with no role are left for later.
