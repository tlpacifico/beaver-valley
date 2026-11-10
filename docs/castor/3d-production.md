# Castor — inventory and preparation of 3D production

[Overall roadmap](roadmap.md) · [Characters](roadmaps/3d-characters.md) · [Environment](roadmaps/3d-environment.md)

Initial state: 2D concepts and mockups exist. No ready-made 3D models, skeletons or animations were identified. The rows below are planned deliverables, not assets already produced, except for the two milestone 1 technical test assets described further below.

## Minimum inventory

| Asset | Required deliverable | First use | Status |
|---|---|---|---|
| Beaver | Model, materials, skeleton and essential actions | Milestone 3b; placeholder in 1–3a | To be produced |
| Animated test model | Asset with skeleton, idle and walk; license verified | Milestone 1, with no obligation to stay in the game | Imported and validated on Windows and on the POCO X7 (Fox, see below) |
| Test branch | Static object created in Blender to prove export/import/change | Milestone 1, technical asset | Imported, changed and reimported; seen on Windows and on the POCO X7 |
| Owl | Model and pointing/giving-a-hint action | Milestone 3b; placeholder marker in 3a | To be produced |
| Otter | Recognizable representation in a celebration pose or with code-driven movement; own rig/animations optional | Milestone 3b; reuse in 4 without requiring demonstrations | To be produced |
| Family at the end | Simple composition, reusing models where appropriate | Milestone 4 | To be defined without creating new protagonists |
| Terrain and banks | Valley, boundaries and walkable surfaces | Placeholder in 1–3a; visual in 3b | To be produced |
| Water | River, reduced current, puddle and lake | Placeholder in 2–3a; finish in 3b | To be produced |
| Vegetation and scenery stones | Small reusable set, not implying collection | Milestone 3b | Procedural scenery retained; two Meshy golden trees integrated provisionally, with licence and visual acceptance pending |
| Branches | Normal, thick, gnawed and spoiled, recognizable by shape | Normal placeholder in 2; obstacles in 3a; finish in 3b | To be produced |
| Building stones | Candidate collectible material, distinct from scenery stones; function to be decided | Decide before 3a; if included, placeholder in 3a and visual in 3b | Postponed for milestone 3a by author decision |
| Building mud | Candidate material; define a function without depending on the leak challenge, which is postponed | Decide before 3a; if included, placeholder in 3a and visual in 3b | Postponed for milestone 3a by author decision |
| Dam | Parts and progressive states, chosen finish | Placeholder in 2–3a; visual in 3b | To be produced |
| Lodge | Parts and construction states | Milestone 4 | To be produced |
| Food store | Branches and storage states in the water | Milestone 4 | To be produced |
| Winter | Simple scenery changes and snow effect | Milestone 4 | To be produced |
| Voice lines | Script per event, placeholder voice and final recordings | Milestone 2 onward | To be produced |
| Sound effects | Responses for collecting, placing, gnawing and completion | Milestone 2 onward | To be produced |
| Ambient sound | River and nature without masking the voice | Milestone 3b | To be produced |

The [audio plan](audio.md) details the script, voice origin and events. The inventory includes audio to keep asset provenance in a single place, even though this page started with 3D production.

Stones and mud only move on to visual production if the distinct function proposed before 3a is understood by the child in the 3a test without additional explanation from the adult. Mud as a finish is a hypothesis to test, not an inclusion already decided.

Before producing each asset, record: origin (own/adapted/acquired), author, source link, license and attribution, editable file, exported file, scale, materials, animations, milestone and validation status in the engine. For own work, state authorship instead of inventing an external license.

## Proposed file organization

These folders will be created when there is content; they do not represent existing files.

| Path from the root | Responsibility |
|---|---|
| `art/characters/` | Editable sources of the characters and animations. |
| `art/environment/` | Editable sources of the terrain, vegetation, water and stones. |
| `art/props/` | Sources of the collectible materials and constructions. |
| `audio/source/` | Voice, effects and ambient sources; origin and permissions recorded in the audio inventory. |
| `game/` | Project of the chosen engine, including exported/imported assets. |
| `builds/` | Builds generated for testing, outside version control. |

Define the export format, units, axes, origin position and animation conventions in the first import test. Record the decision here before multiplying models. Keep the editable source separate from the file intended for the engine; do not edit only the exported one.

## Technical test assets (milestone 1)

These two assets prove the Blender → glTF → Godot pipeline. They **are not** Castor's art direction nor characters in the game; they can be removed when there are final assets.

| Field | Test branch | Animated test model «Fox» |
|---|---|---|
| Editable source | `art/props/test_branch.blend` + script `art/props/test_branch.py` | `art/characters/test-fox/Fox.glb` (original, unchanged) with `README.md`, `LICENSE.md` and `metadata.json` from the source |
| File used by the game | `game/assets/props/test_branch.glb` (generated; do not edit) | `game/assets/characters/test_fox/Fox.glb` (copy) and `Fox_0.png` extracted by the Godot importer |
| Origin | Created in this project, 8/11/2026 | [Khronos glTF Sample Assets — Models/Fox](https://github.com/KhronosGroup/glTF-Sample-Assets/tree/main/Models/Fox), commit `4995a63` (26/09/2026); SHA-256 of the `.glb` `d97044e7…94771f7` |
| Author and license | Project authorship; no external license | Model: PixelMannen, CC0 1.0. Rigging and animation: tomkranis, CC BY 4.0. glTF conversion: @AsoboStudio and @scurest, CC BY 4.0 |
| Attribution | — | Required (CC BY 4.0): text in `game/ASSET-CREDITS.txt`, included in the executable, and a credits line visible in the test scene |
| Tool | Blender 5.2.3 LTS, bundled glTF exporter | Not edited; direct import into Godot 4.7.2 |
| Scale | 1 unit = 1 m; 1.2 m long, ~0.12 m high | Original in ~centimeters (≈155 long); scale `0.005` in the engine → ≈0.77 m long, ≈0.4 m high |
| Orientation and origin | Length along +X; light top at the +X tip; origin at the center, base on the ground; rotation/scale applied | Faces +Z (confirmed in the walking screenshot); origin at ground level, near the center of the body |
| Materials | `Bark`, `CutTip` and, after the test change, `Leaf`; base colors without textures | One `fox_material` material with the `Fox_0.png` texture |
| Skeleton and animations | — | `Skeleton3D` with 24 bones; `Survey` used as idle, `Walk` as walk (loop enabled in the engine); `Run` not used |
| Validation | Test `tests/asset_import_test.gd`, visual inspection in the engine, in the Windows executable and on the POCO X7 | Same test and screenshots; idle when stopped and walk while moving; confirmed by hand on the POCO X7 |

### Proven export conventions

- Format: binary glTF (`.glb`), exported with `+Y Up` and "Apply Modifiers"; Godot recommends glTF 2.0.
- Units: 1 Blender unit = 1 meter. Apply rotation and scale in Blender (Ctrl+A) before exporting; the test fails if the imported node has a transform.
- Axes: Z up in Blender becomes Y up in Godot; Blender's +Y becomes −Z in Godot. Length of elongated props along +X.
- Origin: at the point that should rest on the ground (center of the base). The game positions the asset by its origin.
- Colors: Blender's "Base Color" values are linear; in Godot they appear converted (for example 0.13 linear ≈ 0.40 sRGB). Choose colors by looking at the result in the engine, not by the number.
- Names: the object and the materials keep their Blender names in Godot (`Branch`, `Bark`…). Avoid an object name identical to the file name.
- Source and export kept separate: edit only the `.blend` in `art/`; the `.glb` in `game/assets/` is regenerated with `./tools/castor.ps1 branch-export`.
- Third-party animations: enable looping in the engine when the file does not include it; do not edit the original `.glb`.

### What to learn in Blender to repeat it alone

The branch was generated by script to be reproducible, but the same result can be done by hand. Minimum concepts, in this order:

1. Navigate the 3D view (rotate, zoom, front/side views via the numeric keypad) and select objects.
2. Add primitives (cylinder, sphere), move/rotate/scale with G/R/S and exact values in the side panel (N).
3. Basic edit mode: extrude and move vertices to refine a simple shape.
4. Join objects (Ctrl+J), apply transforms (Ctrl+A) and put the origin in the right place (Object → Set Origin).
5. Create materials with a base color and assign them to parts of an object.
6. Export glTF (`File → Export → glTF 2.0`, `.glb` format) to `game/assets/...` and confirm in Godot.

Skeleton (rig), weights and animation are left for the milestone 3b beaver; the Fox proves that the engine receives that data, not that we already know how to produce it.

## Common integration criterion

- The model keeps scale, orientation, colors and animations when entering the engine.
- It is recognizable at the real camera distance, including on a small screen.
- Collisions and interaction areas are simple and suited to the game; they do not depend on every detail of the mesh.
- It does not cover important destinations nor block the beaver's path.
- It works in the installed build, not only in the modeling tool or the editor.
- The cost of meshes, materials, textures, shadows and transparency is measured on the chosen device before setting limits. Do not set arbitrary polygon counts as a guarantee of performance.

## Provisional audio asset provenance

The nine generated voice clips use Piper `pt_PT-tugão-medium` and are inventoried with author/source and license notes in [audio production](audio.md#provisional-voice-source-and-event-playback). The model card identifies the Nabu Casa Voice Datasets as CC0 and does not name the performer; the output license is not separately specified, so the clips remain for the family prototype pending clarification before redistribution.

The four procedural sound effects in `game/audio/effects/` are original project-authored audio generated by `tools/generate-provisional-sfx.py`; no third-party samples or attribution apply. See [audio production](audio.md#provisional-sound-effects).

## First visual dam set — milestone 3b

- Beaver: original project-created asset from `art/characters/beaver/create_beaver.py` and editable `Beaver.blend`, exported to `game/assets/characters/beaver/Beaver.glb`. The Blender source and material/rig/animation details are in `art/characters/beaver/README.md`; no third-party asset or external license applies. Includes an eight-bone rig, Idle and Walk clips; short gnaw/place transforms are driven in Godot. The Y-up export puts the nose at +Z, so `prototype_actor.gd` rotates the visual 180° around Y to follow the actor's -Z forward.
- Bank, vegetation, stones and progressive dam: original procedural geometry in `game/scripts/visual_environment.gd`, editable as source; decorative elements are non-colliding and scenery stones are not collectible. No third-party asset or external license applies.
- Owl and otter: original non-colliding procedural primitives in `game/scripts/support_characters.gd`, with transform-driven appearance and celebration; no third-party asset or external license applies.
- `./tools/castor.ps1 check` covers actor animation loops, branch orientation, action interruptions, scenery states, support-character timing and existing gameplay/save behavior. Visual/device and child recognition checks are still required.

## Scenery reference — golden tree (9 November 2026)

`art/environment/scenery-sample/references/golden-tree-v1.png` is an AI-generated 2D reference created for the project with the built-in OpenAI image generation tool. Creative direction follows the project's golden tree concept; no external artist or third-party mesh is claimed. Applicable OpenAI service terms govern the generated output; no separate external asset licence is asserted. See the adjacent `README.md` for provenance. It is intended for an image-to-3D trial and has not been converted, imported or validated as a game asset. Record the generation service and terms of any derived mesh separately before adoption.

## Meshy golden tree trial (9 November 2026)


The author supplied a generated/remeshed GLB after reporting Meshy Pro access. Original and provenance: `art/environment/meshy-tree/originals/golden_tree.glb` and the adjacent parent `README.md`. It contains 3112 triangles and no materials. The editable prepared source is `art/environment/meshy-tree/golden_tree.blend`, reproducible with `prepare_tree.py`; the exported candidate is `game/assets/environment/meshy_tree/golden_tree.glb`. Local preparation added two materials, corrected normals and set a provisional 2.4 m height. Two instances are provisionally integrated at 0.68 scale in the rear side margins of the main valley, replacing two procedural bush clusters. They add no collision or interaction targets and remain in the shared environment across dam, home, food and winter states. The source and export must stay paired if the geometry or materials change. Generation-time licence/attribution must be confirmed: an earlier UI showed CC BY 4.0, while the file itself has no licence metadata; later Pro access must not be assumed to retroactively change those terms. See the asset README for the unresolved terms and visual/device checks.

## Meshy painted beaver trial (10 November 2026)

- Origin: project author supplied `Meshy_AI_Cheerful_Little_Beaver_20261110_character.glb` and a separate palette reference. The mesh is identified as a Meshy generation by the supplied filename. The GLB has no embedded author, licence or attribution metadata. Confirm the generation account and applicable terms before adopting the asset.
- Local preparation: a 1024 × 1024 base-colour texture and a two-second `Idle` action on the supplied 40-bone rig. The editable source and exported GLB are paired in the ignored `builds/beaver-paint-preview/` trial.
- First playable Windows trial: the branchless version with `Idle` and a provisional `Walk` is editable in `art/characters/painted-beaver/PaintedBeaver.blend` and exported as `game/assets/characters/painted_beaver/PaintedBeaver.glb`. The second Meshy generation superseded this trial in the valley.

## Playable Castor from the second Meshy generation (10 November 2026)

- Origin: the project author supplied the Meshy-generated `Meshy_AI_Cheerful_Little_Beave_1110220136_generate.glb` from the branchless reference. The unchanged original is in `art/characters/castor/originals/`. The GLB carries no embedded author, licence or attribution metadata. The generation account, applicable terms and credit requirements still need confirmation before distribution.
- Source and export: `art/characters/castor/Castor.blend` contains the 13-bone rig, two-second `Idle`, provisional `Walk` and packed 1024 × 1024 base colour. `game/assets/characters/castor/Castor.glb` is the playable valley export. The actor applies a 0.72 visual scale and rotates the model to follow its forward direction.
