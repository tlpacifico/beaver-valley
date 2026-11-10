# Playable valley relief implementation plan

**Status:** proposed on 9 November 2026 following the author's feedback that the flat scene reads as a board game; revised the same day after a review against the current code (single-bank default, camera projection decision, 2D grid routing, smaller R1). No terrain implementation or validation is implied.

**Goal:** turn the existing flat play area into a small inhabited valley with sloping ground, an excavated riverbed and an upstream lake basin, preserving the complete chapter and saved adventures.

**Architecture:** author one deterministic terrain surface and derive visible ground, collision, placement heights and route data from it. Retain click/tap movement, the existing actor and 2D grid pathfinding; move the three duplicated path builders into one shared route service that marks cells from the terrain and lifts paths onto it. Keep the valley small and the water in prepared visual states.

**Technology:** existing Godot 4.7.2, typed GDScript, Compatibility renderer and Blender/glTF asset workflow. No paid services, new terrain plugin or shared-tool changes.

**Specification:** [milestone 4b](roadmaps/04b-visual-valley.md), with the relief direction below superseding the literal raised-board interpretation of the [v3 concept](mockups/valley-map-v3.svg).

Execute small, verifiable increments. Commit only when requested. The author reviews the first running composition before detailed scenery production. Existing child/device validation gates remain open.

## Proposed landscape

- A low central valley floor, enclosed by gentle hills and a higher ridge on the sides away from the camera. Keep the side nearest the camera low so it can see the actor and targets.
- A continuous river channel cut into the ground, entering from the rear and leaving toward the foreground along one side of the playable area, not through its middle. The dam spans a narrow section; the upstream basin widens into the lake. The river must still read as crossing the valley, not as an isolated strip at the rear edge.
- **One playable bank by default.** All required collection, building and storage approaches sit on the bank nearest the camera; the far bank is scenery. A continuous river cannot be bypassed on dry land around its upstream end, so no such connection is planned.
- Optional, only if R1 shows the single bank is too cramped: one fixed crossing (fallen log or stepping stones) downstream of the dam, where the water level never changes. It is prepared scenery with static collision, not a building mechanic.
- Two broad, gently sloping shore routes and small clearings for branches and home parts. Avoid stairs, narrow ledges and sharp changes of slope.
- A lodge mound and food storage near reachable shore positions. The visible placement location may be in water; the actor's interaction approach must remain on solid dry ground.
- The area the full lake will cover is never walkable. Show it from the start as shallow water or marsh with reeds, so the child does not tap apparently dry ground that gives no response.
- Irregular terrain edges and hills extending beyond the play routes. Remove the visible rectangular rim; terrain and vegetation communicate the limits. Any invisible safety collision must coincide with an understandable landscape boundary.
- Reuse the two Meshy trees after terrain placement is stable. Adding more props is not the means of establishing depth.

**Initial proportions to try, not acceptance targets:** retain roughly the current 13 × 11 m playable footprint; widen only the decorative perimeter as needed. With the existing actor about 0.9 m tall, try walkable rises of 0.3–0.8 m, surrounding hills of 1.5–3 m and a riverbed roughly 0.3–0.6 m below the main shore. Start with route slopes at or below 20 degrees and a conservative physical floor limit of 30 degrees. A 0.8 m rise at 20 degrees needs about 2.2 m of run, so R1 must confirm that channel, basin, lodge mound and clearings fit; if not, reduce rises before enlarging the playable area. Tune these from actual traversal and framing rather than treating the numbers as final art direction.

## Camera constraints

The current play camera is **orthographic** (`movement_world.gd`, size 19), placed at (11, 14, 15) and looking diagonally across the area at roughly 37 degrees above the horizontal. This shapes the landform as much as the terrain does:

- An orthographic view has no perspective depth cue. Relief reads only through shading, cast shadows and occlusion, which is a likely cause of the board-game look. R1 compares it with a narrow-field perspective camera from the same direction and records the choice.
- The view is diagonal, so the "foreground" is the +X/+Z corner. Enclosing hills belong on the −X and −Z sides; the two near edges stay low.
- A slope that faces away from the camera and is steeper than the camera's elevation angle is invisible, and hides ground behind it. Keep the near bank of the channel and the near side of any mound gentler than that angle.

## What the code currently assumes

- `movement_world.gd` creates one flat ground box and rectangular boundary walls; terrain taps above `y = 0.1` are rejected. The river is a flat strip along the rear edge.
- Dam, home and food each build path points with `y = 0`, using an `AStarGrid2D` with 1 m cells, integer X/Z positions and no diagonals.
- `prototype_actor.gd` intentionally ignores vertical offset when following waypoints and uses gravity for floor contact. Arrival currently means its waypoint list is empty.
- Spawn, loose items, destination rings, water, lodge and winter decorations use fixed heights. Those must be anchored to the new ground or to an explicit water/building datum.
- Saves contain stable material IDs and stage choices rather than world positions. This permits moving the landscape without a save reset; restore must resolve those IDs into the new layout.

Adding hills only to the visible mesh would leave these assumptions broken. The work below changes presentation and traversal together.

## Source and responsibility map

| File | Responsibility |
|---|---|
| New `game/scripts/valley_terrain.gd` | Deterministic surface definition, terrain mesh, matching static collision and ground-height queries |
| New `game/scripts/valley_layout.gd` | Shared spawn, stage, collection, shore-approach and water-state anchors; stable gameplay IDs stay unchanged |
| New `game/scripts/valley_navigation.gd` | One `AStarGrid2D` whose solid cells come from terrain slope, water and clearance; shared world-space paths lifted onto the surface |
| `game/scripts/movement_world.gd` | Assemble the services; input routing, stage orchestration and restore; remove flat-ground construction and duplicated path conversion |
| `game/scripts/prototype_actor.gd` | Stable slope traversal (floor snapping, slope limit, constant speed) and interrupted-path handling |
| `game/scripts/home_stage.gd`, `food_stage.gd` | Use the shared layout/navigation service for pickup and placement approaches |
| `game/scripts/collectible_branch.gd`, `home_part.gd`, `food_bundle.gd` | Preserve new terrain-anchored origins when returning/swapping objects |
| `game/scripts/visual_environment.gd`, `winter_scene.gd`, `support_characters.gd` | Grounded scenery, water states, snow and support positions |
| New `game/scenes/valley_relief_preview.tscn` | Early terrain/camera/traversal review without touching the adventure save |
| New `game/tests/valley_terrain_test.gd`, `valley_navigation_test.gd`; existing integration tests | Surface, routes and chapter regressions |
| `tools/castor.ps1`, production inventory and progress notes | Run the new checks and record implementation/acceptance evidence |

The terrain's editable source is its deterministic definition in code, not an exported mesh edited in isolation. This is authored terrain built reproducibly, not random or infinite procedural terrain. If later sculpted in Blender, preserve `.blend` and exports together and re-establish one authoritative collision/height source.

## Shared interfaces to establish

- `ValleyTerrain.height_at(world_xz: Vector2) -> float`: height on the actual terrain triangles, using the same triangulation as the visible and collision surfaces. Reject coordinates outside the terrain through a separate bounds query; do not invent a floor there.
- `ValleyTerrain.contains(world_xz: Vector2) -> bool`: whether that coordinate belongs to the terrain footprint.
- `ValleyLayout.ground_anchor(anchor_id: StringName) -> Vector3`: named surface point plus the object's documented ground offset. Water surfaces, lodge parts and food pile transforms use explicit stage anchors, not an arbitrary terrain-height addition.
- `ValleyNavigation.find_path(from: Vector3, to: Vector3) -> PackedVector3Array`: world-space grounded path, empty when unreachable; no silently accepted partial paths.
- `ValleyNavigation.find_approach(from: Vector3, approach_id: StringName) -> PackedVector3Array`: path to one of a target's explicit usable shore/ground approaches.

Keep `AStarGrid2D`. The terrain has exactly one height per X/Z position, so route finding remains a 2D problem and `AStar3D` or navigation-mesh baking would add work without adding capability. Mark a cell solid when its slope exceeds the route limit, when it lies inside the maximum lake footprint or the channel, or when the actor's 0.26 m capsule radius plus a small margin does not clear an obstacle. Paths are cell centres with Y taken from `height_at`. Start with 0.5 m cells; with cells that small and solidity decided per cell, separate per-segment checks are not needed. Try `DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES` to avoid visible stair-step routes on slopes.

Excluding the maximum lake footprint from the start means rising water cannot strand the actor or require rebuilding navigation.

## R1 — Review the landform before detailing it

R1 answers one question: does this read as a valley from the play camera? It needs a visible mesh only. Collision, anchors and navigation wait for R2, after the shape is accepted.

- [x] Capture the current valley as a baseline. Add the isolated relief preview with neutral terrain colors and cast shadows, a channel, a lake basin shown as shallow water or marsh, and simple shapes for dam/lodge/collection zones.
- [x] Define the deterministic terrain as a visible mesh. Prepare two or three landform variants (for example different hill heights or river positions) that can be switched in the preview.
- [x] Compare the current orthographic camera with a narrow-field perspective camera from the same direction. Adjust height, tilt and framing to reveal the slopes and riverbed while keeping important targets visible; manual camera control remains unnecessary. Record the chosen projection and values. **Author chose perspective and the `wide_bank` variant on 9 November 2026.**
- [x] Check the camera constraints above: hills only on the far sides, no hidden ground behind the near channel bank or the lodge mound.
- [ ] Confirm that all required activities fit on the single playable bank within the current footprint at the intended slopes. Decide here whether the optional downstream crossing is needed. **Fit confirmed for all three variants; the crossing decision is pending (none indicated by the fit).**
- [x] Show temporary overlays for future walking routes, maximum water area and blocked hills. Clearly distinguish these guides from functioning navigation at this stage.
- [x] Show the author the actual running view at 960 × 600 and a phone-shaped viewport. Include a low side view as a diagnostic, but assess acceptance using the play camera.

**Acceptance:** the author can recognize a valley from the untextured landform, without relying on trees to supply depth. Record camera projection, camera values and terrain proportions before producing detailed scenery. If it still reads as a raised board, revise R1 rather than decorate it.

### R1 review — results (9 November 2026)

R1 is implemented as an isolated preview, `game/scenes/valley_relief_preview.tscn` with `game/scripts/valley_relief_preview.gd`, backed by `game/scripts/valley_terrain.gd` and `game/scripts/valley_layout.gd`. It does not touch the chapter scene, saves, navigation or the actor. The terrain grid is 0.25 m; `height_at` interpolates the visible triangles, so later collision and anchors can share one surface.

**Landform.** A near playable bank (+X of the channel), a continuous channel along the −X side entering from −Z and leaving toward +Z, an upstream lake basin behind the dam, enclosing hills only on the −X/−Z perimeter and low ground on the near sides. The footprint is an irregular oval of about 19 × 18.5 m around the 13 × 11 m playable rect, so the orthographic framing sees land rather than a rim. Heights: floor about 0.3–1.1 m after the gentle eastward bank rise, hills 2.2–3.4 m, channel bed below the initial water. Initial water is −0.28 m, intermediate −0.16 m and full −0.06 m; the ground below the full level is already marsh-coloured and excluded from walkable routes.

**Variants.**

| Variant | Hills | Channel depth | Lake radii | River centre |
|---|---|---|---|---|
| `gentle` | 2.8 m | 0.84 m | 3.9 × 4.3 m | x ≈ −4.5 m |
| `pronounced` | 3.4 m | 0.92 m | 4.1 × 4.6 m | x ≈ −4.2 m |
| `wide_bank` | 2.2 m | 0.76 m | 3.5 × 3.9 m | x ≈ −5.0 m |

**Camera comparison.** Both views keep the game view direction and elevation but shift the framing to (9.5, 14.5, 13.0) with target (−1.5, 0.5, −2.0), so the elevation stays 36.97°. Orthographic size is 15.0; perspective is fov 36°, near 0.1, far 200. The low-side diagnostic uses (9.5, 2.8, 13.5) toward (0, 0.6, 0), fov 45°; the portrait check is 540 × 960 at orthographic size 24. The comparison isolates projection: same position and target. Perspective shows more depth through the converging channel and nearer foreground, but exposes the outer terrain edge at the top of the frame; orthographic keeps target sizes equal and the whole terrain inside the frame. **The author chose perspective and the `wide_bank` variant on 9 November 2026.** The preview now opens in that combination.

**Fit check.** All numbers are computed by `ValleyLayout.fit_report()` and written to `builds/relief/fit_report.json`.

| Variant | Usable near bank | Min usable width | Route | Route max slope | Zone clearance | Near-bank max slope | Lodge near-side slope | Hidden-ground risk | Fits |
|---|---|---|---|---|---|---|---|---|---|
| `gentle` | 83.9 m² | 7.0 m | 12.1 m | 12.4° | 0.3 m | 33.5° | 29.6° | no | yes |
| `pronounced` | 79.4 m² | 6.5 m | 12.1 m | 12.4° | 0.3 m | 35.7° | 33.6° | no | yes |
| `wide_bank` | 90.5 m² | 7.8 m | 12.1 m | 12.6° | 0.3 m | 28.7° | 20.6° | no | yes |

All required activities fit on the single near bank; the optional downstream crossing is not indicated by this fit. Zone clearance is positive but tight (0.3 m), which R3 should keep in mind when it places real objects.

**Evidence.** Current-valley baseline captures are in `builds/relief/baseline/`; variant, projection, overlay, portrait and low-side captures plus three contact sheets are in `builds/relief/`. `valley_terrain_test.gd` and `valley_preview_test.gd` pass, and the existing `./tools/castor.ps1 check` suite still passes. A final-camera probe found 0 of 1,539 playable `gentle` samples (1,496 `pronounced`, 1,638 `wide_bank`) hidden behind terrain, and 0 hidden anchors. No commit was created.

**Limits.** The author accepted the `wide_bank` variant and perspective as the R2 base on 10 November 2026. The near-bank slope of the `pronounced` variant leaves only about 1.3° of margin below the camera elevation, which no longer matters for the chosen variant but remains a limit if it is revisited. R1 has no collision, navigation or actor traversal; those are R2. The preview uses simple volumes and two existing tree assets only for scale, not as the source of depth. Android, device and child validation were not touched.

## R2 — Prove movement on one slope and one bank

- [x] Build static collision from the same triangles as the accepted visible terrain and define the named anchors. Do not leave the old flat collider underneath the playable surface.
- [x] Implement the shared navigation grid against the terrain. Steep hills, the channel, the maximum lake footprint and outside terrain are not destinations.
- [x] Replace the absolute-height tap rejection with terrain-surface identification. Clicking a raised valid slope must work; clicking a rock or inaccessible hill must not become a route through it. **The isolated traversal preview uses the new ray/navigation path; the chapter scene is integrated in R3.**
- [x] Adapt actor movement with `floor_snap_length`, `floor_max_angle` and `floor_constant_speed`. Keep the visual body upright initially; do not pitch the entire capsule or carried objects to every triangle normal.
- [x] Keep waypoint arrival horizontal, as today (0.035 m). With one height per X/Z position there is no "wrong elevation" to guard against, and a vertical tolerance would only add a way to never arrive.
- [x] Test uphill, downhill, stopping, retargeting halfway up a slope, carrying a branch and repeatedly tapping the same point. Verify no bouncing, sliding while idle, hovering, clipping or permanent movement without arrival. **Uphill, downhill, retargeting and repeated taps are covered in the traversal test; carrying on a slope remains an R3 integration check.**
- [x] Add focused terrain tests comparing sampled heights against collision rays at slope interiors and triangle boundaries. Add navigation cases for inaccessible slopes, water cells, obstacle clearance and unreachable targets.

**Acceptance:** the actor visibly climbs and descends the real surface in the preview, arrives reliably and never routes across unsupported water. Capture a short traversal demonstration. Do not integrate all stages while this foundation is unstable.

### R2 review — results (9 November 2026)

R2 is proven in an isolated traversal scene, `game/scenes/valley_traversal_preview.tscn` with `game/scripts/valley_traversal_preview.gd`, on the accepted `wide_bank` terrain. The chapter scene and its saves remain untouched; stage integration is R3.

- **Collision.** `ValleyTerrain.build_collision_body()` creates a layer-1 `StaticBody3D`/`ConcavePolygonShape3D` from the exact visible triangles. Collision rays match `height_at` within 0.02 m at anchors, triangle interiors and boundaries and on the channel bank.
- **Navigation.** `game/scripts/valley_navigation.gd` keeps one `AStarGrid2D` on 0.5 m cells over the 13 × 11 m playable rect (26 × 22 = 572 cells; 275 solid for `wide_bank`). A cell is solid when it is outside the bank, in the channel or maximum lake footprint, above the 20° route limit, or within the actor's 0.26 m capsule plus 0.04 m margin of such a cell. Paths are lifted onto `height_at`; a strict destination cell refuses routes into water or hills instead of snapping through them. `find_approach` is ready for R3 interaction approaches.
- **Input and actor.** The traversal preview raycasts the terrain collision (layer 1), accepts a raised valid slope, refuses water and inaccessible hills, and routes through navigation. `prototype_actor.gd` now sets `floor_snap_length = 0.35`, `floor_max_angle = 40°`, `floor_constant_speed = true` and `floor_stop_on_slope = true`; waypoint arrival stays horizontal at 0.035 m.
- **Traversal evidence.** `--capture-traversal` walks spawn → dam approach → lodge → food bank → spawn, saving five captures. The actor arrived at every anchor and its ground height followed the terrain (dam y ≈ 0.44 m, lodge y ≈ 0.71 m, food y ≈ 0.61 m, spawn y ≈ 0.68 m). The lodge leg climbs and the return descends. Retargeting halfway up the slope and a repeated tap on the same destination both completed.
- **Tests.** `valley_collision_test.gd`, `valley_navigation_test.gd` and `valley_traversal_test.gd` pass. They cover surface rays, water/steep/outside solidity, path continuity and determinism, approach resolution, slope ascent/descent, grounding, water/hill refusal, screen-click routing, retargeting, repeated taps and the actor floor settings. `./tools/castor.ps1 check` still passes the chapter groups.
- **Limits.** R2 is an isolated preview; the chapter still uses the old flat world and routing until R3. Carrying a branch up and down a slope is not yet exercised on the terrain, and dynamic obstacles, stage approaches and water transitions are R3/R4. No Android, device or child validation was performed. **The author tested the traversal preview and accepted R2 on 10 November 2026.**

## R3–R5 — Outline

These phases depend on a layout that now exists in the isolated preview; their task lists live in [milestone 4b](roadmaps/04b-visual-valley.md) (V2, V4 and V5) and are not duplicated here. The notes below record only what the relief adds to those lists.

**R3 — Bring the three stages onto the terrain (4b V2, V4).** Integrate terrain and navigation into the main scene and remove the parallel flat-grid routes rather than maintaining two routing systems. Position spawn, items, markers and help rings from shared ground anchors; flatten the ground locally at interaction clearings where rings would otherwise be unreadable. Returning an item restores its new grounded origin, not the old hard-coded elevation. Replay at least one item on a raised clearing using actual input rays. Update tests to select meaningful objects and approaches instead of the original absolute coordinates.

### R3 results (10 November 2026)

- The main chapter scene now builds the accepted `wide_bank` terrain, its exact collision and the shared 0.5 m `ValleyNavigation`; the flat ground, boundary walls, central rock and duplicated stage cell paths are gone. The accepted perspective camera (fov 36°, position 9.5, 14.5, 13.0 toward −1.5, 0.5, −2.0) is the play camera.
- Branches, dam approach and placed branches, lodge, home parts, food bundles and food target, owl/otter, trees, bushes, reeds, snow patches, roof cap and family all come from `ValleyLayout`/`ValleyTerrain` anchors or water datums. Stage save IDs, counts, verbs and finishing choices are unchanged.
- Beaver fidelity was applied to the chapter flow: the lodge is hidden until the dam is complete, then appears as a stick-and-mud mound in the lake with its floor at the waterline and a dark submerged entrance; home parts are carried from the dry bank and assembled above the water. The food store is an underwater branch cache beside the lodge, approached from the bank. This deliberately departs from the flat-land mockup where the lodge sat on a dry mound.
- The dam interaction keeps a bank-side yellow cue at `dam_approach`; the castor walks there and places branches across the actual dam line. The cue is hidden once the dam is complete. Home parts sit on three distinct bank clearings around the lodge; food bundles are spread along the food bank. At least one raised branch and the home-part selection are driven through real camera rays in the tests.
- `movement_test.gd` was rewritten for the terrain chapter: spawn grounding, water/outside refusal, real branch ray, thick-branch gnawing, three dam placements, home completion, three food placements and winter. `home_stage_test.gd`, `food_stage_test.gd`, `ending_test.gd`, `visual_environment_test.gd` and `support_characters_test.gd` were updated where their old flat-world assertions no longer applied. `./tools/castor.ps1 check` passes every group.
- Captures of the integrated chapter are `builds/relief/r3_initial.png`, `r3_home.png`, `r3_food.png` and `r3_winter_valley.png`. They show the terrain, the pre-dam bank with no lodge, the water lodge after the dam, the underwater cache and the winter ending from the play camera.
- Limits: R4 still owns water-level behaviour and the winter presentation inside the basin. The dam placement cue is on the bank about 4.6 m from the dam centre, so the branch visibly travels to the dam; a closer interaction clearing should be evaluated with the child. The underwater cache ring is partly behind the lodge from the play camera and needs a readability check. The accepted bank slopes kept the interaction rings readable, so no additional local terrain flattening was added; if child testing shows clipping, add clearings before more decoration. The camera perspective exposes the outer terrain edge at the top of the frame in some views. No Android, device or child validation was performed.

**R4 — Make the water and winter fit the basin (4b V2, V4).** Define initial (shallow/marsh), intermediate and full water levels inside the authored basin as horizontal prepared surfaces; do not raise the downstream reach with the lake. Verify the actor can never walk visibly under the lake. Adapt winter snow patches to terrain height rather than one world height. Capture the same play camera before building, with the complete dam and in winter.

**R5 — Validate saves, readability and the installed build (4b V4, V5).** Load isolated schema 1 and schema 2 fixtures for each stage of progress and respawn on safe terrain; terrain changes alone must not trigger a schema bump. Add the terrain and navigation tests to `./tools/castor.ps1 check`. Assess uphill/downhill travel for excessive slowdown. In the child session, record whether the raised ground makes routes harder to understand. Automated checks cannot close author, child or device gates; Android remains pending until tested on the real phone.

## Risks and scope limits

| Risk | Planned response |
|---|---|
| Relief still reads as a board under the orthographic camera | Compare projections in R1 and decide before any collision or navigation work |
| Hills hide the actor or targets | Hills only on the sides away from the camera; near slopes gentler than the camera elevation; review from the actual camera in R1/R3 |
| Navigation cuts a steep bank between valid cells | Small cells with slope-based solidity; navigation tests for inaccessible slopes |
| Visual ground differs from collision or placement height | Derive all three from one terrain definition and verify with collision-ray tests |
| River divides required gameplay into disconnected banks | Single playable bank by default; optional fixed crossing downstream of the dam, decided in R1 |
| Child taps the future lake area and nothing happens | Show that area as shallow water or marsh from the initial state |
| Single bank is too cramped for all three stages | Check the fit in R1; reduce rises first, then consider the downstream crossing |
| Water or snow conceals interaction surfaces | Review every stage from the same camera and constrain routes against maximum water |
| Terrain work expands into a new game | Preserve one level, existing item counts, saves and verbs; no jumping, swimming, dynamic terrain or new quests |

The first implementation delivery should be **R1 plus the R2 traversal sample**, not a full visual remake. Detailed asset production resumes after the landform and slope behavior are accepted.
