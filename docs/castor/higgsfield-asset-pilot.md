# Higgsfield scenery asset pilot plan

**Status:** deferred, 9 November 2026. The author encountered a subscription checkout during Blender plugin connection. No paid trial or subscription is authorized by this plan. Higgsfield asset quality and time savings remain untested.

**Current production route:** use the [local Blender scenery sample plan](blender-scenery-sample-plan.md). The Higgsfield tasks below are retained as an inactive experiment proposal, not execution instructions for the current phase.

## Access finding and resumption condition

The checkout shown by the author offered a three-day trial, EUR 0 due immediately, and EUR 97.17 after the trial, with a EUR 50 discount for one billing cycle. Starting that trial would authorize recurring billing. This records the specific account flow observed, not universal pricing or proof that every Higgsfield route requires Ultra. No purchase or completed generation was reported.

Do not start the trial, purchase credits, install further integrations or seek a paid workaround as part of this experiment. Revisit only if the author explicitly requests it and a usable route and spending limit have been agreed. If resumed, verify access, export rights and current pricing before generation. Until then, there is no Higgsfield dependency in milestone 4b.

**Goal:** determine whether Higgsfield reduces the total work needed to produce a tree and a rock that fit Castor's visual direction and run in Godot.

**Architecture:** generate individual meshes, retain the original outputs, inspect and edit them in Blender, export GLB, and compare them with simple Blender-generated equivalents in an isolated Godot scene. Adopt the method per asset category only when the evidence supports it.

**Technology:** the existing Blender/glTF pipeline, Godot 4.7.2 with Compatibility renderer, and Higgsfield's available mesh-generation workflow.

**Visual specification:** [milestone 4b](roadmaps/04b-visual-valley.md) and [valley-map-v3.svg](mockups/valley-map-v3.svg).

## Position in the roadmap

This optional experiment is deferred and is not a prerequisite for 4b V3. The local Blender sample now supplies the initial tree and rock. The remaining sections describe how a future two-asset comparison could be conducted if explicitly resumed; they do not replace the active local plan.

The official [Blender plugin page](https://higgsfield.ai/plugins/blender) describes mesh generation from prompts or reference images. The [3D Jutsu overview](https://higgsfield.ai/blog/higgsfield-3d-jutsu) describes editable scenes and GLB export. These were consulted on 9 November 2026; advertised topology quality and export capabilities must be checked on actual outputs. Do not treat rendered images or videos as usable 3D assets.

## Constraints and experiment limits

- Generate one decorative tree and one decorative rock. No characters, animation, lodge, terrain, river or new gameplay systems in this pilot.
- Keep developer files, prompts and notes in English. The isolated scene needs no child-facing text; any added child-facing labels must be European Portuguese.
- Preserve the current game's scenes, asset files and saves. Compare assets in a separate test scene without changing the main scene.
- Preserve originals and editable `.blend` sources; never keep only the final GLB. Record source, generation tool/model, date, author/provenance information and applicable usage terms in the inventory.
- Use the existing tool versions. If plugin compatibility would require changing the shared Blender installation, try the browser/export route or record that route as unavailable; do not upgrade shared tools for this experiment.
- Proposed experiment cap: two generated candidates per asset, up to 30 minutes of Blender cleanup per selected asset, and up to 30 minutes to produce each simple comparison asset. These are experiment limits, not promises about production speed. Stop and record a failed or inconclusive trial rather than silently extending them.
- Before the first generation, record the available workflow, displayed cost and the author's agreed credit ceiling. No paid subscription, top-up or unapproved spending is part of this plan. Use an available free route when sufficient; if neither access nor a budget is available, continue the local comparison preparation and leave generation pending.

## Files and deliverables

Create the following only during execution; they do not exist merely because they are listed here.

| Path | Purpose |
|---|---|
| `art/environment/higgsfield-pilot/README.md` | Prompts, reference use, generation settings, provenance, costs, timings and comparison results |
| `art/environment/higgsfield-pilot/originals/` | Unmodified downloaded meshes and associated materials/textures for the selected candidates |
| `art/environment/higgsfield-pilot/scenery_pilot.blend` | Generated candidates and simple comparison assets in separate, clearly named collections |
| `art/environment/higgsfield-pilot/create_baseline.py` | Reproducible simple tree/rock comparison geometry |
| `game/assets/environment/higgsfield_pilot/` | Separate `tree_generated.glb`, `rock_generated.glb`, `tree_baseline.glb` and `rock_baseline.glb` exports and import metadata |
| `game/scenes/scenery_pilot.tscn` and `game/scripts/scenery_pilot.gd` | Isolated comparison scene using the current beaver and representative ground, camera and lighting |
| `builds/scenery-pilot/` | Ignored captures and temporary diagnostic outputs |
| `docs/castor/3d-production.md` and `startup-progress.md` | Asset inventory entries, evidence and adopt/reject/inconclusive decision |

The pilot scene must not instantiate the gameplay world or call its save/restore logic. It loads the beaver asset for scale reference, not a complete playable adventure.

## Task 1 — Prepare the controlled comparison

- [ ] Record the Higgsfield account's available generation/export route and cost information. Prefer the workflow that yields an editable mesh with the least setup; the Blender plugin is an option, not a prerequisite.
- [ ] Record tool/model versions and the applicable asset-use/attribution terms at generation time. Resolve any unclear permission before adopting the output into the game.
- [ ] Use the v3 tree and rock shapes as references, excluding labels, animals and other scenery from the requested output. Retain the unchanged original SVG; any cropped reference is a derived experiment input.
- [ ] Prepare the comparison scene with one candidate at a time, at the same position, camera, lighting and scale. Include the existing beaver and a branch for readability context.
- [ ] Produce simple comparison meshes: an upright trunk with a rounded canopy and an irregular rounded rock. Use flat colors and the same intended dimensions and silhouette goals as the generated candidates. Time this work.

**Check:** the isolated scene opens without touching adventure saves; switching candidates does not change camera, lighting or display scale. Capture a baseline at 960 × 600 and record the camera settings.

## Task 2 — Generate a tree and a rock

Use these as starting prompts, recording the exact prompt and any changes for each attempt.

**Tree prompt**

> One isolated stylized tree for a friendly children's 3D diorama game. Follow the supplied reference: a short pale warm trunk and a broad rounded golden-green canopy, simple soft shapes and a clear silhouette. The trunk and canopy must remain separately editable. Flat-color materials, opaque surfaces, economical geometry, no individual leaf cards, no photorealistic bark, no ground platform, no background, no text, no characters. Upright tree with its base at the origin. Produce an editable 3D mesh, not an image.

**Rock prompt**

> One isolated small stylized riverbank rock for a friendly children's 3D diorama game. Soft irregular rounded silhouette, wider than it is tall, a stable flat underside, warm grey flat-color material and economical geometry. No sharp spikes, tiny cracks, photorealistic texture, vegetation, ground platform, background or text. Produce an editable 3D mesh, not an image.

- [ ] Generate and inspect a first candidate for each asset. Download the actual mesh and required materials/textures, keeping original files untouched.
- [ ] If a candidate misses an essential requirement, make at most one revised generation for that asset with the specific defect stated in the prompt.
- [ ] Record active work time, service waiting time, credits and candidate identity separately. Include rejected attempts in the total cost of the method.
- [ ] If the tool cannot deliver an editable/exportable mesh within the available route, record the failure and stop that part of the experiment.

**Check:** both selected outputs open in Blender as geometry. A convincing preview with no usable mesh does not pass.

## Task 3 — Inspect, clean and export in Blender

- [ ] Inspect each candidate from all sides and from the intended game camera. Check unwanted ground, hidden fragments, holes, inverted normals, thin surfaces and unsupported shader effects.
- [ ] Record triangles, mesh objects, material slots, texture count/resolution and file size before editing.
- [ ] Set base-centered origins, consistent units and applied transforms. Choose dimensions alongside the beaver, then use those exact dimensions for the baseline asset too.
- [ ] Make the tree trunk and canopy independently editable if necessary. Check that canopy recoloring and a rock shape adjustment are practical rather than requiring regeneration.
- [ ] Remove unnecessary geometry and simplify materials within the cleanup cap. Prefer opaque flat-color materials; do not conceal poor mesh quality with a high-resolution render.
- [ ] Record every correction and its time. Save the editable result and export each asset separately using the project's established glTF conventions.
- [ ] Record the same geometry/material measurements after cleanup for both generated and baseline assets.

**Check:** reimport the GLBs and confirm scale, origin, colors and separate editable components survived export. No missing textures or dependencies on personal download paths. If rebuilding the mesh becomes necessary, count that as a failed time-saving result for that asset.

## Task 4 — Compare in Godot

- [ ] Import all four assets using Compatibility and inspect the same-camera captures beside the beaver and branch.
- [ ] Compare shape, palette, shadows and readability at actual play distance, not only enlarged previews. Repeat with the intended phone aspect ratio; do not call this a device test.
- [ ] Duplicate each tree candidate into a small six-tree group and each rock into a six-rock group. Compare generated and baseline groups separately with identical placement, view and lighting.
- [ ] Record frame-time samples and rendering statistics under the same conditions, identifying hardware and whether the run is in the editor or an exported build. Treat small noisy differences as inconclusive; record geometry/material costs even when runtime differences are not measurable.
- [ ] Make one canopy color change and one rock shape change in the `.blend`, re-export and verify both updates in Godot. Record iteration time.
- [ ] Present the author with labelled generated/baseline comparisons for the single assets and repeated groups. Ask which fits the intended valley, allowing rejection of both.
- [ ] Run `./tools/castor.ps1 check` after adding project resources to ensure existing behavior remains intact. Inspect the pilot visually as well; headless checks cannot establish visual quality.

**Check:** the candidates render correctly, remain editable, fit the accepted direction and do not obscure the representative branch/beaver. If Android is available, inspect the pilot on the real device before claiming mobile suitability; otherwise explicitly leave that status pending.

## Task 5 — Decide per asset category

Complete this table with observed results; do not fill missing measurements with estimates presented as facts.

| Measure | Generated tree | Baseline tree | Generated rock | Baseline rock |
|---|---|---|---|---|
| Attempts and total credits | | | | |
| Active generation/modeling time | | | | |
| Service waiting time | | | | |
| Cleanup and export time | | | | |
| Godot integration and iteration time | | | | |
| Final triangles / objects / materials | | | | |
| Textures and GLB size | | | | |
| Same-scene rendering observations | | | | |
| Author visual acceptance | | | | |
| Editable source and permitted use verified | | | | |
| Device validation status | | | | |

**Adopt for an asset category** when the author accepts the appearance, the technical and provenance checks pass, and total active effort is lower than the comparable baseline without unacceptable service delay or cost. Record the measured difference; do not assume a successful tree proves it will generate suitable characters or terrain.

**Keep as an optional visual alternative** if the author prefers its appearance but it does not save time. State that tradeoff explicitly instead of declaring the acceleration experiment successful.

**Reject for an asset category** when cleanup exceeds the cap, exports are unusable, rights are unsuitable, or the accepted baseline is as good with less work. Retain the result notes; production can continue with Blender/scripts.

**Inconclusive** when access, budget, comparable quality, measurements or author review are missing. Identify the missing evidence and do not let the experiment block 4b V1/V2.

- [ ] Record the decision and evidence in the pilot README and startup progress.
- [ ] Add adopted assets to the production inventory with original/generated provenance and editable/export paths.
- [ ] Update 4b V3 with the chosen production method for trees and rocks. A positive pilot may justify a separate lodge trial, but does not authorize generating the entire scene.

## Completion criterion

The pilot is complete when the two asset categories have an evidence-based decision and the author has seen the in-game comparison. Successful generation alone is not completion. No gameplay, save-format or main-scene changes are needed; no commit is implied by executing this plan.
