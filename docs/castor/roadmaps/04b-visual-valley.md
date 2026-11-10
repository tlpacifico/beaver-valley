# 4b — Visual valley composition

[Overall roadmap](../roadmap.md) · Previous: [complete chapter](04-chapter.md) · Next: [MVP](05-mvp.md)

**Status:** in progress: R1–R5 automated and desktop evidence is implemented and tested on 10 November 2026, including save fixtures and a runnable Windows export. Author visual acceptance, adult rehearsal, Android and child observation remain pending. No Android or child validation is implied by this plan.

**Goal:** make the playable valley recognizable as the world proposed by [valley-map-v3.svg](../mockups/valley-map-v3.svg), while preserving the complete chapter and existing progress.

**Architecture:** reshape the existing single valley around a coherent river, banks, dam and upstream lake. Keep the current tap, carry and place interactions and stable save IDs; update scenery, approach points, navigation and framing together. Use prepared water states rather than water simulation.

**Technology:** Godot 4.7.2, typed GDScript, Compatibility renderer; existing Blender/glTF pipeline for external models.

This is a roadmap for staged visual production, not permission to replace the entire game at once. Execute one deliverable at a time and record evidence in [startup-progress.md](../startup-progress.md). Commit only when the author asks. Detailed implementation choices follow the accepted in-engine composition, rather than locking world coordinates before it exists.

## Why this phase exists

Milestone 4 implemented the chapter's actions, saving and ending. The resulting prototype is not an accepted final visual composition. Milestone 3b was closed for sequencing with outstanding work; its closure does not mean the intended valley was achieved. This phase owns the remaining composition and essential visual integration from 3b and 4. Milestone 5 will finalize an already coherent valley, not construct its identity from scratch.

## Relief direction update

The author accepted the first tree integration but identified that the flat scene still reads as a board game. The [playable valley relief plan](../valley-relief-plan.md) now details V1/V2 and the related stage integration: enclosing hills, real traversable slopes, an excavated channel and a lake basin. The v3 map continues to guide palette and spatial relationships, but its flat raised slab is deliberately not the terrain target. The author accepted the `wide_bank` landform and perspective camera in R1 and the isolated slope traversal in R2 on 10 November 2026. R3 brought the terrain, collision and navigation into the chapter. R4 now supplies prepared water states, a readable cache, terrain-aligned snow and a less abrupt outer boundary; see the R4 status below. R5 owns save fixtures, the installed build and human validation.

## Visual contract

The reference guides spatial relationships, palette, silhouettes and personality. It is not a literal camera projection, a requirement for identical pixels or a promise to implement every labelled material.

| Reference element | Required translation into the game | Acceptance evidence |
|---|---|---|
| Small valley composition | A low central floor, enclosing side/rear hills, excavated banks and irregular boundaries; deliberately depart from the flat raised slab | Full-valley in-engine capture showing relief without relying on props |
| River crossing the terrain | A continuous channel with identifiable upstream and downstream areas; not an isolated strip at the rear | Initial-state capture without explanatory labels |
| Dam across the river | Branch placements visibly accumulate across the channel and explain why water collects upstream | Same-camera captures before, during and after building |
| Lake behind the dam | Prepared water states expand upstream, keeping the downstream channel identifiable | Complete-dam capture and playable approach checks |
| Woodland and bank zones | Branches belong to a recognizable collection area; decorative trees and rocks frame the routes | Collection and movement demonstration |
| Lodge and food near the lake | A recognizable beaver lodge of sticks and mud in the water, with a submerged entrance, built only after the dam; food visibly cached underwater nearby | Home and food progress captures |
| Beaver, owl and otter | Friendly, readable silhouettes and a consistent palette at the actual play distance | Character views in the full scene, not only close-ups |
| Bright, simple presentation | Warm ground/vegetation, readable blue water, soft lighting and clear interactive targets | Captures on the actual game camera and installed build |

The reference's signs are design annotations, not an instruction to add labels to the game. Owl help and otter celebration retain their current roles. Stones and mud remain decorative or postponed; this phase does not add collectible material types.

## Scope and constraints

- Keep one valley and the existing dam → home → food → winter progression, material counts, obstacle rules and finishing choices.
- Preserve existing saves and stable item IDs. Changes to coordinates must reconstruct old progress in the new layout without resetting the adventure.
- Use a fixed overview camera as the first composition proposal. No manual camera control is required; the optional follow-camera experiment is not the acceptance view.
- Arrange the required collection and placement approaches on usable ground or supported surfaces. The beaver must not appear to walk on open water to complete a task. Position the lodge and food near reachable shore approaches; swimming is outside this phase.
- Keep targets readable without mandatory text. All child-facing text and audio remain European Portuguese; developer documentation and identifiers remain English.
- Reuse assets where they fit. Improve character silhouette/materials only as needed for scene coherence; do not start a new rig or animation catalogue without a concrete need.
- Preserve editable sources in `art/`, exports in `game/assets/`, and provenance in the asset inventory. Code-generated scenery remains editable through its generator script.
- No new maps, playable animals, quests, water leak, free building, random/infinite terrain generation or physical water simulation. A deterministic code-authored terrain mesh is permitted, with matching collision and placement heights.
- Do not change shared tools or global SDK settings. Do not claim Android, child understanding or performance validated from headless tests or screenshots.

## Work areas

| Files or area | Responsibility during this phase |
|---|---|
| `game/scripts/movement_world.gd` | World assembly, camera, navigation, interaction routing and dam state integration |
| `game/scripts/visual_environment.gd` | Terrain presentation, banks, river/lake appearance, vegetation and scenery rocks |
| `game/scripts/collectible_branch.gd` | Branch readability, carried/placed appearance and dam assembly |
| `game/scripts/home_stage.gd`, `home_part.gd` | Lodge silhouette, wall/roof states and accessible placement approaches |
| `game/scripts/food_stage.gd`, `food_bundle.gd` | Collection area, reachable storage approach and visible food pile |
| `game/scripts/prototype_actor.gd`, `support_characters.gd`, `winter_scene.gd` | Character scale, support placement, family and snow integration |
| `art/environment/`, `art/props/`, `art/characters/`; corresponding `game/assets/` | Editable models and their exported resources; create only assets actually needed |
| `game/tests/`, `tools/castor.ps1` | Existing regression suite and targeted navigation/input/save checks |
| `docs/castor/3d-production.md`, `startup-progress.md` | Asset status, provenance, captures, acceptance and remaining work |

Prefer one shared layout definition if multiple scripts need the same positions. Do not scatter new coordinates across scenery, navigation and interaction code. Do not turn this phase into a general architecture rewrite.

## V1 — Establish the composition in simple volumes

Follow R1 of the [relief plan](../valley-relief-plan.md); then prove the R2 slope traversal sample before expanding the detailed visual set.

- [ ] Capture the current initial, completed-dam, home, food and winter views; retain these as the comparison baseline under ignored `builds/`.
- [ ] Build a simple in-engine composition: raised ground, crossing river, dam perpendicular to the channel, upstream lake footprint, woodland collection area, shore approaches and lodge/food locations.
- [ ] Frame the entire essential play area with the fixed camera. Test the current 960 × 600 reference view and the intended phone aspect ratio; keep UI clear of important objects.
- [ ] Mark walkable and non-walkable areas temporarily for inspection. Show how every existing task can be approached without crossing open water.
- [ ] Present the author with the actual game view beside the v3 reference, explaining deliberate differences. Ask for visual acceptance of composition before detailed asset production.

**Deliverable:** an in-engine layout the author recognizes as the intended valley. Simple volumes are sufficient at this checkpoint. Exact camera angle, proportions and positions are decided here, not assumed from the SVG coordinates.

## V2 — Make river, dam and routes agree

Follow R2–R4 of the [relief plan](../valley-relief-plan.md), including height-aware routes, raised-ground input, grounded interaction anchors and prepared water states.

Depends on the V1 composition checkpoint.

- [x] Integrate terrain boundaries, river banks and the dam into the playable scene; remove or reposition prototype obstacles that conflict with the accepted geography while retaining useful movement challenges. **R3 removed the flat ground, walls and central rock; no replacement obstacle was added yet.**
- [x] Build prepared initial, intermediate and complete water states. Show upstream accumulation caused by the dam; preserve the downstream channel and the chosen dam finish. **R4 separates the upstream lake from the fixed downstream stream, clips the shore to the terrain and raises the lake with a short prepared-surface animation.**
- [x] Update navigation, collision and approach points together. Keep reachable bank positions for collection, lodge assembly and food storage at every water level. **Initial and full water footprints both drive navigation solidity.**
- [x] Update ray targets and selection cues to match the visible objects. Recheck taps near the bank, overlapping objects, the lodge roof and wall, and the screen edges.
- [ ] Exercise movement retargeting and item swapping beside water and obstacles. Ensure the actor cannot be sent across unsupported water, become stranded by a water transition or clip through the terrain boundary. **Water refusal and retargeting are tested; swapping beside water and a water transition remain.**
- [x] Add or adapt targeted behavior tests for changed routes and real screen-ray selections; retain the existing movement and interaction checks.

**Deliverable:** the dam visibly changes a river into an upstream lake, with the entire chapter still traversable. A nice screenshot with broken routes does not satisfy this task.

**R3 status:** the terrain chapter, routes, real-ray selection and grounded stage anchors are integrated and the full chapter passes its tests. R4 now supplies the prepared water and winter presentation.

**R4 status:** `ValleyLake` rises upstream through two prepared levels while `ValleyStream` stays at the initial level; the shore is clipped against the terrain instead of a grid staircase. The dam has a horizontal brush-and-mud crest, abutments, a spillway and a branch flight from the bank cue. The food cache has a clear-water window, a surface marker and a visible submerged basket. Snow patches align to the terrain, the lodge roof and dam carry snow, and the family stands on dry bank. The outer edge has a soil/grass skirt and two layers of distant hills. `./tools/castor.ps1 check` passes, including the new `valley_water_test`. A backdrop seam remains in some views, and none of the water, cache, snow or boundary work has real-device, child or author acceptance yet.

**R5 status:** the automated/desktop part is complete. `save_fixture_test.gd` restores schema 1 and schema 2 fixtures for partial dam, both finishes, partial home, partial food and winter without rewriting the save file; the slope-speed measurement records 1233 ms uphill and downhill against 1219 ms expected for the same 3.41 m route. The Windows debug export ran all capture modes at 960 × 600 and was inspected in `builds/relief/r5_exported_sheet.png`. Independent validation returned PASS WITH FINDINGS; the branch-flight orientation defect and the main presentation findings were fixed. `adb devices` found no phone, so Android, author acceptance, the adult rehearsal and child observation are still open.

## V3 — Establish a coherent visual set

- [ ] Produce the [local Blender tree/rock sample](../blender-scenery-sample-plan.md) using scripts and editable sources, then review it beside the beaver in Godot before replicating the visual set. This can run alongside V1. The [Higgsfield pilot](../higgsfield-asset-pilot.md) is deferred after the observed subscription checkout and is not a prerequisite or paid dependency.
- [ ] Produce one representative section containing bank, tree, rock, branch, water and beaver. Inspect palette, proportions, silhouettes, shadows and target contrast together at the game camera distance.
- [ ] Use the accepted section to populate the small valley with a limited reusable asset set. Avoid dense decoration that hides materials or makes empty scenery look selectable.
- [ ] Replace the remaining dam/obstacle presentation that conflicts with the scene. Distinguish normal, thick, gnawed and rotten branches by shape as well as color.
- [ ] Adjust beaver, owl and otter placement, scale and materials for a shared visual language. Preserve existing idle, walk, carry, gnaw and place behavior and support roles.
- [ ] Inspect carried objects and animations in the new composition, including turning and interruption. Keep the animal and its task readable without zooming.
- [ ] Record sources, authorship, licences where applicable, editable files and exports in the inventory as assets are introduced.

**Deliverable:** the accepted composition has a consistent visual treatment in the running game. The author reviews this representative look before it is replicated throughout the scene; fidelity is assessed in context, not from isolated model renders.

## V4 — Integrate home, food and winter into the valley

- [x] Refine the lodge into a recognizable beaver home on its mound, retaining two clear build positions and meaningful visible differences between chosen parts. **R4 raises the mound and floor to the full lake; the final shell has several mud-and-stick lobes, a front opening and woven sticks. Author acceptance is pending.**
- [x] Place loose home parts and food bundles in intentional shore collection areas. Keep suitable and thin bundles visually distinguishable and their target reachable. **The cache has its own dry approach and clear-water window.**
- [x] Make the food pile readable in the water beside the lodge without relying on the progress counter. **Surface marker, submerged basket and bundle centres below the surface are visible in the overview capture.**
- [x] Place the owl's help cues and the otter's lake celebration where they support the current action without obstructing taps or the camera. **The otter now sits on the full lake surface.**
- [x] Integrate snow, family placement and winter lighting with the same geography. Keep the finished dam, lodge and food visible when revisiting the valley. **Snow patches align to the terrain, the roof and dam carry snow, the family stands on dry bank and the cache stays visible.**
- [x] Restore representative existing saves: partial dam, completed dam with each finish, partially built home, partial food and completed winter. Confirm placements use the new layout and carried/reserved items recover safely. **R5 covers every stage and both finishes with isolated schema 1 and schema 2 fixtures; carried/reserved items are never saved.**
- [x] Verify that existing save failure warnings and protected restart behavior still work after all transitions. **The home, food, ending and restart checks still cover the forced save failure.**

**Deliverable:** each stage belongs to the same valley, and previous progress survives the visual upgrade. No new save schema is required solely for moving scenery; justify and test migration if a later implementation decision actually requires one.

**Validation follow-up:** the independent review returned PASS WITH FINDINGS. The branch-flight orientation defect is fixed, placed material order uses an explicit slot index, the cache centres are below the surface, the finish is a short crest accent instead of a repainted full log, and completion messages have a readable band. A second marker now sits on the dam crest, snow patches are clustered, the distant hills are lighter with a sparse far-edge bush line, and the lodge uses a rounded multi-lobe shell with a front opening. The backdrop seam, bank-side approach cue, surface-basket readability and author acceptance of the new lodge remain open.

## V5 — Validate the complete visual valley

- [x] Run `./tools/castor.ps1 check` and resolve relevant failures. Tests must verify behavior rather than simply repeating new coordinate constants. **Passed on 10 November 2026, including the new water test.**
- [x] Export Windows and inspect the installed/runnable build at the actual play resolution; capture initial, partial dam, lake, lodge, food and winter from the same overview camera. **R5 exported and ran the debug build; all six views are 960 × 600 and inspected in `r5_exported_sheet.png`.**
- [ ] Compare these views with the visual contract and obtain the author's acceptance. Record concrete differences that are intentional and any remaining fixes.
- [ ] Run the outstanding adult rehearsal of about 15 minutes on the chosen priority device, covering movement, taps, collection, all stages, suspend/focus changes and resume. Record device, resolution, frame-time observations and Android heating where applicable.
- [ ] If Android is to be marked validated, install and run on the real phone. Exporting or checking a phone-shaped viewport is insufficient. If unavailable, record the device gate as pending. **R5: `adb devices` found no attached phone; gate pending.**
- [ ] Observe a short, voluntary play session with the child: can she find branches, recognize where to build and see the effect on the valley? Record adult help needed and visual confusion without requiring her to finish in one sitting.
- [ ] Update the environment/character tracks and inventory from observed work. Carry unrelated voice, device and gameplay validation items forward explicitly.

**Deliverable:** a playable, reviewed valley with recorded technical and human evidence, plus a short list of genuine finishing tasks for milestone 5. **Automated and runnable-build evidence is recorded; the review still needs the author, the adult rehearsal, Android and the child.**

## Completion gate and handoff to milestone 5

- [ ] The author recognizes the composition and visual identity of the reference in the running game and accepts documented deviations.
- [ ] River, dam and upstream lake communicate cause and effect; the lodge and food store occupy understandable locations in that landscape.
- [ ] All stages remain accessible and selectable; no required route walks through open water, no scenery hides essential targets, and changing water states cannot strand the actor.
- [ ] Existing saved adventures restore correctly, including the ending and finishing choices, without losing progress.
- [ ] The automated suite passes, the installed priority-device rehearsal is recorded, and the child observation has informed any blocking adjustments.
- [ ] Asset sources and the production tracks reflect what is actually integrated. Remaining work for milestone 5 is bounded presentation, audio, usability and performance refinement, not an unbuilt valley composition.

Keep functional completion, author visual acceptance, child observation and device validation as separate statuses. If any gate remains pending, report it as pending; do not silently close 4b to make the roadmap look complete.
