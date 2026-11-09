# Local Blender scenery sample plan

**Status:** planned, 9 November 2026; replaces the active execution path of the [deferred Higgsfield pilot](higgsfield-asset-pilot.md).

**Goal:** create one editable stylized tree and one rock, then judge their appearance beside the existing beaver in Godot before producing more scenery.

**Architecture:** generate simple mesh foundations with local Blender Python, refine the editable source, export individual GLBs and inspect them in an isolated Godot scene. No external generation service or subscription is required.

**Technology:** the existing Blender installation and glTF conventions, Godot 4.7.2, typed GDScript and Compatibility renderer. Do not upgrade shared tools or change global settings.

**Reference:** [milestone 4b](roadmaps/04b-visual-valley.md) and [valley-map-v3.svg](mockups/valley-map-v3.svg). This sample supports V3 and can be prepared alongside V1; it does not replace the composition checkpoint with the author.

## Scope and source ownership

- Produce one decorative tree and one decorative rock. No new gameplay, animations, main-scene changes or save changes.
- Use rounded, simple shapes, opaque flat-color materials and readable silhouettes at the game camera distance.
- Keep the tree trunk and canopy separately editable. The rock should have an irregular rounded silhouette and a stable underside.
- Store the generator, editable `.blend` and exported GLBs. Document which changes are generated and which are manual; never rerun a generator over the only copy of manual refinements.
- Record project-created authorship and tool-assisted generation in the asset inventory. Do not assign an invented third-party licence.
- All developer-facing content is English. Any child-facing text must be European Portuguese; the sample does not require UI text.

## Files to create during execution

| Path | Responsibility |
|---|---|
| `art/environment/scenery-sample/README.md` | Dimensions, palette, generator/export instructions, manual-edit policy and observations |
| `art/environment/scenery-sample/create_scenery.py` | Reproducible tree and rock mesh foundations |
| `art/environment/scenery-sample/scenery_sample.blend` | Editable source with separate named tree and rock collections |
| `game/assets/environment/scenery_sample/tree.glb` | Exported tree and its materials |
| `game/assets/environment/scenery_sample/rock.glb` | Exported rock and its materials |
| `game/scenes/scenery_sample.tscn`, `game/scripts/scenery_sample.gd` | Isolated sample with representative ground, lighting, camera, existing beaver and branch |
| `builds/scenery-sample/` | Ignored captures and measurement outputs |

These are planned outputs, not existing deliverables. The sample scene must not instantiate the gameplay world or invoke adventure save/restore logic.

## Task 1 — Model the first two assets

- [ ] Use the reference tree proportions and rock silhouette as the starting point; keep the SVG unchanged.
- [ ] Create a short warm pale trunk and broad rounded canopy. Use a small number of mesh forms rather than individual leaves or transparent leaf cards.
- [ ] Create a warm grey rounded rock, wider than it is tall, with enough asymmetry to avoid looking like a perfect sphere.
- [ ] Inspect both beside the beaver for scale; record chosen dimensions, base-centered origins and applied transforms.
- [ ] Save the generator and editable source. Record active modeling/refinement time as evidence for later production estimates.

**Check:** trunk and canopy can be recolored independently, the rock can be reshaped, and both remain understandable from the intended elevated camera.

## Task 2 — Export and inspect in Godot

- [ ] Export each asset separately using the existing Blender/glTF conventions in [3d-production.md](3d-production.md).
- [ ] Build the isolated sample scene using the current game's representative camera and lighting, with the existing beaver and a branch for context.
- [ ] Check scale, origin, normals, shadows and colors after import. Confirm there are no missing textures or references to personal download folders.
- [ ] Capture the sample at 960 × 600 and the intended phone aspect ratio. Inspect at actual play size as well as close up; a phone-shaped viewport does not validate Android.
- [ ] Make a canopy color change and a rock shape change in the editable source, then re-export and verify the changes in Godot. Record how to preserve these edits during regeneration.

**Check:** the complete edit/export/import loop works, and the models read clearly beside the existing characters rather than only in Blender renders.

## Task 3 — Check reuse and visual cost

- [ ] Place six instances of the tree and six of the rock, varying only scale and rotation within reasonable proportions.
- [ ] Check that repetition is acceptable and the group does not hide the representative beaver or branch.
- [ ] Record triangles, objects, materials, texture usage and exported size. Record frame-time/rendering observations on identified hardware; do not invent a mobile budget from a desktop sample.
- [ ] Run `./tools/castor.ps1 check` after adding project resources and address regressions. Inspect the sample visually as a separate check.

**Check:** the assets are reusable, technically sound and easy to adjust. Real-device performance remains pending unless actually tested.

## Task 4 — Review and decide

- [ ] Show the author the actual Godot sample beside the v3 reference, including full-camera and repeated-group views.
- [ ] Record acceptance or concrete requested changes to silhouette, palette, scale and finish. Rejection of both assets is a valid outcome; do not populate the valley with unaccepted samples.
- [ ] If accepted, record these as the starting visual set for 4b V3 and update the inventory and startup progress. If changes are needed, refine this small sample before expanding production.

**Completion criterion:** the author has accepted the local tree/rock sample in Godot, editable sources and export instructions are retained, and functional checks pass. This proves the local production loop and a small part of the visual direction; it does not close milestone 4b or validate the whole valley.

## Higgsfield remains optional

The paid access flow is the reason for deferral, not evidence that generated models are poor. Do not claim the local route is faster than Higgsfield without a completed comparison. A future trial can reuse these assets as a baseline if the author chooses to reopen it. No paid service or commit is authorized by this plan.
