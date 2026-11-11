# Castor — nature, exploration, gameplay and seasons roadmap

Date: 11 November 2026. Status: N1, N2, E1 and E2 are implemented with automated/desktop evidence; E2's first review found two interaction defects and a visual finding, which were fixed and re-verified. No expansion stage is validated by this document.

[Overall roadmap](../roadmap.md) · [Construction polish](../construction-polish-plan.md) · [Progress and child observation](../startup-progress.md) · [How to run](../how-to-run.md)

**Agreed gameplay update (11 November 2026):** new adventures require five ground branches, five logs from five gnawable trees, and five small stones, collected and delivered in any order. See the [mixed-material design](../mixed-material-dam-design.md) and [implementation plan](../mixed-material-dam-plan.md). This supersedes the earlier fixed-three-placement experiment for new adventures; legacy adventures retain their recipe and progress. Optional grass/mud finishing is deferred and never gates completion. The mixed-material loop is implemented; the separate E3 zone-choice interface remains future work.

## Why this expansion

The author reports that his six-year-old daughter completed the game in less than three minutes, enjoyed it, needed no help and wants more story. This supports extending a working family experience. Duration alone is not a failure, and a longer completion time is not the acceptance target.

The agreed direction is richer dam construction, trees that provide material after gnawing, visible river flow, swimming and seasonal continuation in the same valley. The author also requested more natural elements, including rocks and mud, and a more open map with more room for the beaver to move. The concrete activities below are proposed first slices, not individually tested designs. Keep the child's wish for more story central: each addition should offer a recognizable action, choice or consequence.

## Relationship to the existing work

- Milestones 1–5 retain their names and completion criteria. This roadmap does not declare the family MVP complete or add all seasonal work as a condition for delivering it.
- Construction polish P1/P2 is implemented; the reported child session supplies partial P3 evidence. The build, device and starting save remain unspecified. Author visual acceptance, outstanding technical/device checks and detailed observations remain open.
- E1 reuses the water-presentation work proposed in polish P5. Do it once and cross-reference the evidence. E2/E3 intentionally extend gameplay beyond the polish plan's fixed material/placement behaviour; its constraints still govern the original polish work, not these explicit extensions.
- N1–N3 add the requested nature and exploration work alongside the gameplay stages. N1 overlaps polish P6 and the environment production track; share that work and evidence. Existing E identifiers remain stable so prior references still work.
- Finish necessary readability, save and interaction fixes as they arise. Prioritize a small coherent natural area and usable paths before optional tree variety or broad decorative production.
- E4 introduces a continuation after the existing ending. E5 explicitly extends the current land-only movement contract. These changes require their own small implementation designs and regression checks before integration.
- Planning this sequence authorizes documentation, not automatic execution of every stage. Implement one independently playable increment at a time when requested. Commit only when the author asks.

## Order from easier to harder

Difficulty is relative to the current code and includes integration, art, saves and verification. These are effort bands, not calendar estimates. Features within the same band are ordered by dependency and reuse. E7 is optional, not a prerequisite for the seasonal story. The separate D1 drifting-object experiment is also optional and can fit after E3; it does not require swimming.

| Order | Stage | Difficulty | Dependency | Playable result |
|---|---|---|---|---|
| N1 | Natural ground and scenery | Low | Current valley | Rocks, mud patches and grouped vegetation give the banks and clearings a natural identity |
| E1 | Visible river current | Low–medium | Current valley | The river visibly flows and the pool becomes calmer as the dam grows |
| N2 | Open more paths inside the valley | Medium | N1; current terrain/navigation | The beaver can explore a connected loop with alternate land routes |
| E2 | One tree supplies a branch | Medium | Existing collect/carry/place loop; E1 recommended | Choose a tree, gnaw it and collect its material |
| E3 | Choose where to build the dam | Medium | E1 + E2 | Fill two visible construction zones and see their local effect on the water |
| E4 | A short playable winter | Medium | Existing autumn chapter; E3 for the integrated release | Use what was prepared to help the family, then reach a new story ending |
| N3 | Extend the playable valley | Medium–high | N2; stable existing construction sites | Explore a new clearing connected to the original play area with a readable camera |
| E5 | Swimming on one controlled route | Medium–high | Current terrain/water states; stable E3 | Enter the water, cross a small area and leave at a usable bank |
| E6 | Playable spring and seasonal continuity | High | E4 + E5; N3 layout if reusing its new area | See the thaw and use swimming to reach one new story activity |
| E7 | Free swimming in the playable river | High | E5 + E6 | Choose reachable water destinations and move reliably between land and water |

**Optional side experiment D1 — authored branch drift:** medium difficulty, after E1/E3, before or independently of swimming. Moving one object on a prepared path is much smaller than simulating currents that affect arbitrary objects or the castor. The latter would be high/very-high difficulty and is not scheduled here.

Physical fluid simulation, hydraulic erosion, destruction of the dam, underwater diving and procedurally generated rivers are outside this roadmap. Visible flow, swimming and authored drifting objects do not require those systems.

## N1 — Natural ground and scenery

**First slice:** compose one bank and one clearing with existing rock shapes, small stones, visually soft mud patches, reeds, bushes and grouped trees. The project already has shore rocks and dam mud; extend their visual language rather than replacing the whole asset set.

- [x] Give each material a readable place: rounded stones along banks, larger rocks framing the outer slopes, mud near wet ground, and vegetation in small clusters with open clearings between them.
- [x] Keep mud patches walkable and cosmetic initially. Do not add slipping, sinking, slowdown, resource collection or mandatory cleanup to this scenery pass.
- [x] Keep large rocks outside essential paths in this first slice. Small pebbles are nonblocking detail; any later obstacle needs matching physical collision and route exclusion, not only a visible mesh.
- [x] Keep collection objects distinct from decoration and leave the beaver, construction targets and foreground routes visible from the play camera. Avoid dense scattered props across every open patch.
- [x] Use deterministic placement and modest mesh/material reuse. Keep editable sources in `art/` and record provenance for any new external asset.
- [x] Inspect the initial, full-lake and winter scenes. Mud must not flicker against the terrain, and scenery must not cover the cache or appear suspended over changed water levels.

**Likely code/art:** `game/scripts/visual_environment.gd`, implemented as constant primitive geometry grounded on the `wide_bank` surface from `valley_terrain.gd`; no new `art/environment/` source was needed. Reuse [environment production](3d-environment.md) and polish P6 for any later asset-based treatment.

**Done when:** the bank and clearing look coherent at play distance while all existing routes and interaction targets still work. Test the graphical build and record device cost before repeating the treatment across the valley.

**Progress (11 November 2026):** implemented with `game/tests/natural_scenery_test.gd` in `./tools/castor.ps1 check` (`CASTOR_NATURAL_SCENERY_OK`) and captures under `builds/n1-scenery/`; details and commands are in [startup progress](../startup-progress.md). All N1 checklist boxes are supported by the recorded evidence after a remediation pass: the four outer formations sit on the north/west slopes, every boulder's extent clears the playable rectangle, clusters hold three plants and the stone/mud/boulder meshes reuse cached resources. The first independent review returned pass with findings; all but the variant limitation were fixed and re-verified by the focused test, the full `check` and the final captures. Open: the constants are authored only for `wide_bank`, so switching variants needs per-variant authoring. Not validated: real device, touch, child observation and author visual acceptance; the exported build was not remade.

**Material scope:** rocks and mud are scenery in N1. Collecting stones to strengthen a dam or carrying mud to seal a gap remain possible later gameplay designs, with their own distinct purpose and child test. This request does not make every visible rock or mud patch collectible.

## N2 — Open more paths inside the valley

**First slice:** create a connected land loop between the collection clearing, a riverside path and a small woodland opening within the current playable boundary. Provide two ways around a scenery group. Keep the short route between the existing task locations available.

The current playable rectangle is 13 × 11 world units, and actual land access is smaller because water and steep slopes are excluded. Opening the valley means increasing usable connections and reachable ground, not merely changing the camera distance or removing water/slope checks.

- [x] Inspect the current reachable cells, narrow approaches, slopes and obstacles. Record a before view with routes before moving scenery or reshaping ground.
- [ ] Widen or gently reshape the proposed walking corridors using the same terrain source as the mesh and collision. Keep enclosure and relief around the edges while making the valley floor easier to traverse. The integrated N2 contract keeps the terrain, heights and playable rectangle unchanged by design, so no corridor was widened or reshaped; the loop is created by routing around an authored obstacle group instead.
- [x] Treat large rocks and trunks consistently in visuals, collision and route planning. A physical obstacle that the pathfinder ignores can trap the actor; an invisible blocked route is equally misleading. Maintain clearance for the actor's body.
- [ ] Test the whole loop in both directions, retargeting mid-walk and carrying a branch, home piece or food bundle. Keep the maximum flooded area and unusable bank slopes unavailable until swimming is introduced. The focused test now walks the loop out on the west/north side and back on the south/east side, but neither leg carries cargo or retargets midway on the new loop; retargeting and cargo are covered only by the existing movement and traversal tests elsewhere in the valley.
- [x] Make the opening identifiable through a natural landmark, such as a rock group or small grove. Exploration stays optional and carries no failure penalty.

**Likely code:** `valley_layout.gd` (authored grove and opening), `valley_navigation.gd` (exclusion), `movement_world.gd` (collision) and `visual_environment.gd` (visuals), with `grove_loop_test.gd` and the existing terrain/collision/navigation/traversal tests.

**Done when:** the beaver can walk the new loop and alternate route without passing through rocks, losing floor contact or crossing water. Record reachable-cell/path evidence and an actual traversal; a new decorative clearing alone does not complete this stage.

**Progress (11 November 2026):** implemented on the existing `wide_bank` terrain without changing heights, `PLAYABLE_RECT`, water, camera, saves or rules. `ValleyLayout` authors five boulder/trunk obstacles in the east half and a woodland opening at (5.40, -0.60); the same list drives navigation exclusion, `GroveObstacles` collision cylinders on layer 1 and the grounded boulder/tree visuals, so scenery, collision and routing cannot drift apart. The opening is a pale grass patch framed by three collider-free ferns and two bushes; the grove trees were raised to 2.6 m with lifted canopies so the boulders stay visible. After the grove, 273 walkable cells remain and all are reachable from spawn; the bank was already one connected component of 297 cells before N2, so the gain is the loop, the alternate route and the landmark, not new walkable area. The six direct routes stay at or below their baselines (probe growth -0.01 to -0.04 m); two routes connect the branch clearing to the opening (9.54 m south/east and 10.12 m west/north against 4.47 m straight), with probe corridor widths of 1.82/1.84 m and 0.853/0.882 m clearance. `game/tests/grove_loop_test.gd` is in `./tools/castor.ps1 check` with the marker `CASTOR_GROVE_LOOP_OK` and covers authoring constraints, exclusion, connectivity of anchors and branch spots, the strict direct-route growth gate, both loop routes with a 0.75 m free margin and a blocked straight-line proof, collision/visual parity, the opening nodes, a real traversal out and back on opposite sides, and an unchanged isolated save. The focused run and the full `check` exited 0, and the windowed captures show the grove and clearing from the play camera. Evidence and commands are in [startup progress](../startup-progress.md) and ignored `builds/n2-paths/`. The independent review returned **pass_with_findings**; its test-gate and preview minors were fixed and re-verified, the opening landmark was strengthened, and the traversal preview is back to terrain-only routing. Remaining nits: the test duplicates the branch pickup positions, the beaver stops about 0.48 m from the visible boulder, and the working tree mixes N1/E1/N2 hunks for a future commit. Not validated: author visual acceptance, child observation, real device/touch and an exported-build capture. The N2 checklist's reshaping and cargo/retarget loop checks remain open as noted above.

## N3 — Extend the playable valley

**First slice:** add one modest land clearing beyond the current playable boundary, connected to the established loop by usable ground. Keep the original dam, lodge, cache and collection locations recognizable. The extension must be explorable before swimming and later support seasonal scenery or one optional discovery.

- [ ] Author the extension as simple terrain first. Update the playable boundary, terrain sampling, collision and navigation together; increasing `PLAYABLE_RECT` alone must not expose unintended slopes, scenery-only ground or an inaccessible area.
- [ ] Preserve short construction routes and add interest through a landmark or small grove. Do not put all required resources at the far end just to lengthen the session.
- [ ] Compare the reachable dry area before/after and verify a return route from every offered destination. Keep future swim entrances distinguishable from currently usable land.
- [ ] Retain the fixed camera if the enlarged area and targets remain readable. If not, prototype a gently bounded automatic follow camera with a stable view at construction sites; no manual camera operation is required. The existing follow experiment is a starting reference, not an accepted solution. Do not shrink characters or touch targets merely to fit the whole map on screen.
- [ ] Restore old saves using stable object IDs and valid ground anchors. Preserve the child's buildings and progress; check both partial and completed chapters against the enlarged terrain.
- [ ] Test screen-space selection near the view edges, slopes, foreground occlusion, aspect ratios and the priority device. Record navigation/rendering cost before expanding again.

**Likely code:** terrain/layout/navigation scripts, camera and input in `movement_world.gd`, environment generation, preview/capture tools and save/traversal tests.

**Done when:** there is a measurably larger reachable area, the beaver can explore and return using the existing controls, and the camera keeps interactions readable. One new clearing is the first target; an open-world map and unrestricted terrain generation are not required.

**Seasonal connection:** E6 can reuse the enlarged geography, but its swimming discovery must remain distinct from land already reachable in N3. Spring can change a scene or add a separate water-accessible nook without pretending an already open land clearing was previously inaccessible.

## E1 — Visible river current

**First slice:** animate the existing downstream surface, add restrained foam at the dam and use a calmer treatment upstream. Reuse the existing prepared water levels and spillway. Keep scenery and navigation unchanged.

- [x] Create a simple Compatibility-compatible material animation; avoid per-frame water mesh rebuilding.
- [x] Relate the flow presentation to the existing dam progress. The final branch still gives a visible response although the current prepared lake is already full after the second branch.
- [ ] Reuse existing sound assets where possible; document provenance if adding new audio. Keep voice and action sounds intelligible. No new audio was added, so provenance is unchanged, but the listening check was not repeated.
- [x] Check initial, partial and complete dam views, including the clear-water food-cache window and winter appearance.

**Likely code:** `game/shaders/water_flow.gdshader`, with cached reach materials and `set_river_flow` in `valley_terrain.gd`; the presented-count wiring in `movement_world.gd`; foam patches and the placement pulse in `visual_environment.gd`; focused coverage in `game/tests/river_flow_test.gd`.

**Done when:** direction of flow and the quieter upstream area are visible from the play camera; targets and stored food remain readable; water levels, routes and saves retain their behaviour. Record graphical/device performance evidence separately from headless checks.

**Progress (11 November 2026):** implemented as a Compatibility shader over the existing prepared water meshes, two cached `ShaderMaterial` instances, flow that follows the presented dam count, four restrained foam patches and a short placement pulse. The first visual pass used straight z-bands and read as striped fabric on the wide marsh; the shipped shader masks the effect with the baked vertex alpha and uses warped travelling ripples with a subtle brightness lift instead, and the rejected variant is kept in ignored `builds/e1-river/`. `game/tests/river_flow_test.gd` is in `./tools/castor.ps1 check` with the marker `CASTOR_RIVER_FLOW_OK shader_time cached_materials flow_curve clear_cache dam_foam foam_pulse world_wiring`; the focused run and the full check both exited 0. Windowed source captures, visual measurements, motion evidence and capture details are under `builds/e1-river/` and in [startup progress](../startup-progress.md). An independent review returned pass with findings; the shader-uniform and presentation-path test gaps, the foam bounds and the pulse expansion were fixed and mutation-checked, and the combined-mesh preview limitation is documented as deliberate because the playable scene uses the reach meshes. Remaining: no frame-time/FPS or device performance evidence. Not validated: real device or Android, touch, child observation, author visual acceptance and an exported build. The sound box stays open only because intelligibility was not re-listened.

## E2 — One tree supplies a branch

**First slice:** one small interactive tree with an authored fall, one stump and one collectible branch. Reuse the existing gnaw action as a provisional animation. The child taps to start; no rapid tapping or precision timing is required.

- [x] Show three persistent states: standing, cut with material available, and cut with material collected/placed. Define the restore behaviour of a partially completed gnaw action. Implemented and covered for standing, cut, pickup and placed, including reload after each; the partial-gnaw and mid-fall restore (tree standing, branch hidden and not collectable, no cut written) was verified by a temporary probe, not by a committed test.
- [x] Make the tree visually identifiable as interactive. Keep other trees decorative for this experiment. The single tree uses the same 0.68 model scale as the decorative golden trees but reads as the interactive one through a thick warm-tan ring distinct from the white pickup rings; the cream gnaw scars were enlarged into three wedges and remain subtle at play distance.
- [x] Use a fixed fall direction and a clear landing area. Avoid a dynamic falling rigid body or changes to essential walking routes in the first slice. The fixed 90° authored fall now animates a trunk that pivots at its base and a separate crown that rests on the ground: the trunk's lowest surface stays at +0.037 m, the crown at +0.202 m and its far edge 0.370 m before the landing, so the cut shows a stump, a readable horizontal trunk and a grounded crown without a rigid body.
- [x] Initially source one of the existing three required dam branches from the tree, keeping other materials available. Preserve that branch's stable identity so the tree cannot duplicate an already placed material. `branch_normal_03` moved from (4.2, 2.0) to the tree landing, keeps its ID and is the tree's only material; a second gnaw or a collect on the hidden branch is refused, and the other four branches can still complete the dam.
- [x] Persist the tree/material relationship. Older saves with that branch already placed must remain completable without cutting the tree again. If carried materials reset on reload, return this branch to its defined source pickup point. Schema 3 adds `tree_cut`; schema 1/2 saves migrate in memory with `tree_cut` false and are not rewritten, a restore with `branch_normal_03` already placed marks the tree cut, and the branch origin is always the landing.

**Likely code/art:** `game/scripts/branch_tree.gd` (new focused tree script), `valley_layout.gd` (tree, work-spot and landing points), `movement_world.gd` (tree-first tap routing, the 0.6 s gnaw lead, the reveal of `branch_normal_03` and the single save), `dam_save.gd` (schema 3 `tree_cut`), `game/tests/tree_branch_test.gd` and the `--capture-tree` debug mode. The tree reuses the existing `game/assets/environment/meshy_tree/golden_tree.glb` at the decorative instances' scale, so no editable tree source was needed under `art/environment/` and provenance is unchanged.

**Done when:** gnawing once provides exactly one usable material; repeated taps, cancellation, reload during gnawing and reload after placement cannot duplicate or lose it. The child can discover the tree interaction without continuous adult explanation. The two reviewed interaction regressions are now exercised through the tap/input path by the committed test: a second tap while the walk is pending leaves it pending, and a standing tree cannot be selected as a home-stage slot. Reload during the gnaw or fall, and reload after a failed save, are also covered.

**Progress (11 November 2026):** implemented on the existing `wide_bank` terrain without changing heights, water, `PLAYABLE_RECT` or the N2 grove. The tree stands at (4.5, 2.2), the work spot at (5.2, 2.2) 0.70 m away and the landing at (4.5, 4.25) 1.804 m from the nearest other branch spot; `branch_normal_03` moved from (4.2, 2.0) to the landing and the fall is an authored 90° animation over 1.0 s in which a trunk pivots at its base while a separate crown comes to rest on the ground, with a stump and no rigid body. Schema 3 adds `tree_cut`, with schema 1/2 migration in memory and no rewrite of the loaded file. `game/tests/tree_branch_test.gd` is in `./tools/castor.ps1 check` with the marker `CASTOR_TREE_BRANCH_OK schema3 tree_standing hidden_branch gnaw cut reload pickup placed legacy_schema2 save_failure dam_material layout tap_path home_gate fall_presentation reload_fall save_failure_reload interaction_gate`; the focused run and the full check exited 0, and `--capture-tree` writes the standing, gnawing, cut and branch frames. The first independent review returned **fail** with three majors (the shared tree/home layer allowed a standing tree to be selected as a home slot; a second tap cancelled the walking gnaw; the fall buried the canopy); all three were fixed as recorded in [startup progress](../startup-progress.md), together with the reviewed test gaps. The follow-up review then found two current issues: the beaver started the gnaw almost away from the trunk (174°), and the transient message band covered the tree and the beaver. Both were fixed: `actor.face_towards()` aims the body at the trunk before the gesture, the focused test asserts a heading within 20° from three approach directions and during the real gnaw, and the transient band moved under the HUD lines (700 × 84 label at (130, 194)), verified from the play camera in `tree_gnaw.png`. Not validated: real device or Android, touch, child observation, author visual acceptance and an exported build. The map-expansion objective (297 walkable cells before N2 versus 273 now), the small explorable clearing, E3 zones, playable winter and the swimming/spring stages remain open.

## E3 — Choose where to build the dam

**Updated sequencing:** first implement the [mixed-material dam](../mixed-material-dam-design.md) with 15 deliveries and one destination that selects a compatible slot. Then introduce two visible unfinished zones as a separate choice. The former three-placement/two-plus-one capacity experiment is superseded for new adventures; legacy saves retain their recipe. Define the per-material zone capacities in that later design so either zone order remains completable.

- [ ] Provide separate, reachable targets for the two zones while preserving a safe work position. A zone silhouette shows what the carried material will fill.
- [ ] Place the material visibly in the selected zone. Use prepared local flow/foam states to show water passing through a gap and reducing as it fills. No hydraulic simulation is needed.
- [ ] Preserve the existing full-lake limit; distinguish local flow feedback from global water height. Do not promise a physically exact relation between the two.
- [ ] Save each material's zone/slot. Map legacy sequential slots deterministically to the new zones and retain completed dams as complete. Document and test the mapping before changing the save format.
- [ ] Handle a full zone, repeated targeting, changing destination and interruption during the final placement without consuming extra material.

**Likely code:** `movement_world.gd`, `valley_layout.gd`, `collectible_branch.gd`, `visual_environment.gd`, `dam_save.gd` and placement/save tests.

**Done when:** either build order produces a complete dam and advances the story; the child can see where each contribution went and what changed. Preserve home/food/ending progression.

**First observation checkpoint:** try the mixed-material loop with the N1/N2 scenery and E1 flow before adding zone-choice complexity. Record whether she explores voluntarily, discovers the five tree sources, recognizes stones as collectible, enjoys the repeated actions and finds her way back. Fifteen deliveries are the agreed starting recipe, not a minimum-duration target; avoid lengthening travel just to exceed the earlier three-minute session.

**Mixed-material implementation and desktop validation (11 November 2026):** Tasks 1–4 implement the recipe model, schema-4 legacy preservation, five tree/log sources, five branches and stones, recipe-stable placements, the three counters, clamped water/flow, and home/food/winter continuation. Task 5 added explicit mixed capture modes and corrected the capture-tree fixture so it really loads `mixed_fifteen`. The exported Windows captures in `builds/mixed-material-task5/` include mixed dam states 0, 1, 8, 14 and 15, and tree standing/gnaw/fall/pickup from the play camera at 960 × 600 and 540 × 960. The feedback panel wraps within the portrait viewport. The 960 × 600 source-center checks keep all 15 targets at least 24 px inside the frame, and play-camera rays hit all five trees and all ten visible branch/stone targets. The camera was widened slightly to include the new source row; collider sizes are unchanged.

The full `./tools/castor.ps1 check` passed on Windows/Godot 4.7.2 after the Task 5 fixes. Navigation assertions cover all 15 source↔construction paths against the maximum prepared water footprint; the focused source test also performs actual public-request collect/carry/deliver trips for every material at that maximum surface, including trips starting at 8/15 and 14/15. The branch cargo route traverses the grove, retargets during return and reaches construction; the grove test physically walks both loop sides without cargo. The reachable grid has 417 connected cells (704 total, 287 blocked), compared with 273 after the previous N2 grove-only layout: 144 more reachable 0.5 m cells from the east-bank extension, not decorative ground. No milestone or device validation is claimed. Still pending: physical-device/touch traversal, author visual acceptance (including canopy occlusion during gnaw/fall), and the child's observation of discovery, counters, repetition and story continuation. Do not add a playtime target.

**Task 5 review follow-up (11 November 2026):** supersedes the earlier partial-route note above. The focused source test now completes actual collect/carry/deliver trips for all 15 material IDs against a test-only maximum-water surface, including 8/15 and 14/15 starts. `ValleyNavigation` excludes this maximum footprint from the start, so lower presented water levels preserve these routes. Projected collider extents and unmasked physics rays cover all material/tree targets; visual canopy occlusion of the beaver during gnaw/fall remains an author-review item, not an automated pass. Re-captured and programmatically IHDR-checked all cited root PNGs as 960 × 600; matching narrow files under `builds/mixed-material-task5/portrait/` are 540 × 960. Focused source test: 7.1 s; full `./tools/castor.ps1 check`: 144.1 s, exit 0. This remains desktop evidence only; device/touch, child observation and author visual acceptance are pending.

**Device-aspect capture follow-up (11 November 2026):** added separate desktop-only mixed/tree capture modes at 1334 × 600, derived from the recorded POCO 2712 × 1220 ratio at 600 px height. All eleven PNG IHDRs in `builds/mixed-material-task5/device_aspect/` were checked programmatically; mixed partials and tree states were visually inspected for counters, panel overlap and edge targets. The gnaw/fall canopy occlusion remains an author-review item. The Windows capture executable was rebuilt; normal gameplay is unchanged, so the installed Android APK was not re-exported. This does not replace a device run.

## E4 — A short playable winter

**First slice:** continue from the existing winter arrival into one family task. Proposed activity: carry a prepared food bundle from the cache to a family member at the lodge's dry approach, then show a short warm family scene. Keep it completable entirely from land.

- [ ] Keep the existing ending recognizable and offer an explicit Portuguese continuation action, such as “Continuar a história”. Preserve visiting the valley and the protected new-adventure action.
- [ ] Add one clear story request, one delivery and one visible response. Treat the food bundle as a quest-specific presentation of the stored supplies; do not subtract from the original three-placement completion record or create hunger timers.
- [ ] Save the current story phase and whether the family task is complete. Loading an existing completed chapter makes the continuation available without resetting autumn progress.
- [ ] Keep the family task replay-safe: no repeated rewards, missing bundle or forced replay after completion. Use reversible actions and no time pressure.

**Likely code/art:** `winter_scene.gd`, `movement_world.gd`, `food_stage.gd`/`food_bundle.gd` where reusable, a focused seasonal-story component and save support; minimal additional poses/audio with editable sources and provenance.

**Done when:** the child recognizes how autumn preparation helped the family, completes the winter task and reaches a new stopping point. Closing and resuming preserves both the original chapter and winter progress.

## E5 — Swimming on one controlled route

**First slice:** a short surface-swimming route between two authored bank entry points. Test it in a separate scene before connecting it to the chapter. This stage is not free swimming across the entire river.

- [ ] Add explicit walking/swimming movement states. In water, maintain an authored immersion depth relative to the actual local surface instead of falling to the river bed.
- [ ] Add a provisional swim pose/clip, wake and entry/exit response. Keep animation separate from the movement and collision rules.
- [ ] Define a valid route through water with two safe exits. Tapping the opposite destination transitions automatically between walking and swimming; do not require another control scheme.
- [ ] Account for the upstream/downstream surfaces and prepared lake levels. Never route directly through the dam or across an unusable bank.
- [ ] Initially require empty paws. For a water destination while carrying material, retain the item and give clear feedback; never silently drop it. Preserve all original land routes.
- [ ] Define reload recovery at a nearby safe bank for this first slice, without changing saved construction/story progress. Test retargeting and exiting on both sides.

**Likely code:** `prototype_actor.gd`, `valley_navigation.gd`, `valley_layout.gd`, water hit detection in `movement_world.gd`, and editable animation sources in `art/characters/`.

**Done when:** repeated land → water → land trips work at the supported water levels, without sinking, snapping to the wrong surface, stranding the character or losing an item. Verify rendering and controls on the priority device; a desktop prototype alone does not validate Android.

## E6 — Playable spring and seasonal continuity

**First slice:** after the winter task, show a prepared thaw transition. Open the proven swim route to a small spring clearing with one family/story interaction, then provide another clear ending and a way to revisit the valley.

- [ ] Reuse the same terrain and constructions. Change snow, foliage, lighting, sound and selected scenery states; avoid rebuilding a separate map.
- [ ] Proposed story activity: swim to the clearing to meet the otter and discover new plants. Keep the first task compatible with empty-paw swimming; transporting materials in water is not required yet.
- [ ] Introduce an explicit persisted season/story phase, retaining all autumn construction and winter task flags. The passage of seasons follows story completion, not the device clock.
- [ ] Check saves before/during/after each transition and upgrades from legacy completed chapters. A partially shown transition must recover to a valid stable phase without replaying tasks.
- [ ] Give each season its own visible objective, short narrative payoff and stopping point. Do not create an endless seasonal loop or a season-selection menu in the first version.

**Likely code/art:** seasonal-story ownership introduced in E4, `winter_scene.gd`, `visual_environment.gd`, world presentation, save fixtures, foliage/snow variants and voice lines.

**Done when:** autumn → winter → spring forms a coherent playable story in one persistent valley, and the child understands why the new route is available. Reassess interest after each short chapter rather than producing a catalogue of seasonal tasks up front.

## E7 — Free swimming in the playable river (optional)

**First slice:** extend the known swim area into a connected, bounded water region. Preserve the same tap/click controls.

- [ ] Route mixed land/water journeys using actual reachable entries, exits and local water levels. Distinguish navigable water from terrain inside the maximum future lake footprint.
- [ ] Handle mid-route retargeting, banks, dam obstruction and completion of water-state changes during a journey.
- [ ] Add carrying one branch while swimming only after empty-paw routes are reliable; align the material with the swim pose and preserve the normal pickup/placement ownership rules.
- [ ] Test reloading and suspending during swimming, material carrying and shoreline transitions, including the priority device.

**Done when:** any offered destination is reachable and recoverable, and swimming adds useful exploration or access to construction. Unreachable areas remain clearly unavailable. If the controlled route already satisfies the story, this stage can stay deferred.

## D1 — An authored current carries one branch (optional side experiment)

**First slice:** one branch drifts along an authored route to a predictable bank-side collection point. This can be tried after E3 without swimming. Keep the castor's own movement under player control.

- [ ] Define a bounded drift route, speed and stopping point. Support interruption/reload with a stable object identity and a recoverable position.
- [ ] Let the child collect the branch without a timing challenge. If it reaches the end, it waits; it does not disappear or require restarting.
- [ ] Integrate carried, floating and placed states so the same object cannot be owned twice. Test collection while drifting and seasonal/water-state transitions.
- [ ] Evaluate performance and child understanding before considering multiple moving objects. A current that pushes the castor is a separate future design decision, not included automatically.

**Done when:** the child can anticipate where the material goes and retrieve it reliably. The drift must support a story or construction activity; omit it if it is only a technical demonstration.

## Shared delivery checks

For each stage, record implemented scope, commands/results, visual evidence and open items in [startup progress](../startup-progress.md). Use `./tools/castor.ps1 check` for regression coverage and add focused checks for the new behaviour. Inspect a graphical build for animation, water and UI; run the installed build on the priority device before claiming device validation. Use isolated test saves and preserve the child's existing progress.

Record asset origin, author, license and attribution in [3D production](../3d-production.md). Keep editable sources in `art/`. Child-facing strings and voice stay European Portuguese; developer-facing content stays English. Do not change global tools or SDK settings.

Do not infer completion of old milestone gates from the new feature tests. The reported play session is useful evidence for this child; the device/build details and longer-session performance checks still need to be recorded.

## Next deliverable

E2's single tree is implemented with automated/desktop and visual evidence; its reviewed interaction defects and fall presentation were fixed and re-verified, and it is now the legacy recipe's tree. The mixed-material dam (five branches, five tree logs and five stones) is implemented; observe it with the child and on the real device before E3's separate two-zone choice. E1 still needs author visual acceptance, a real-device and touch check, child observation, an exported build and recorded frame-time/device performance before it is validated. Deliver E4 as the next short story chapter; extend the land area in N3 before investing in E5's controlled swimming and E6's spring integration. The table gives the recommended delivery order; independent work can move within an effort band without bypassing its dependencies or validation. E7 remains optional. D1 is a smaller optional side experiment if a drifting branch improves the construction activity; it never blocks the story.
