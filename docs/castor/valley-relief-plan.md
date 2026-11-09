# Playable valley relief implementation plan

**Status:** proposed on 9 November 2026 following the author's feedback that the flat scene reads as a board game. No terrain implementation or validation is implied.

**Goal:** turn the existing flat play area into a small inhabited valley with sloping ground, an excavated riverbed and an upstream lake basin, preserving the complete chapter and saved adventures.

**Architecture:** author one deterministic terrain surface and derive visible ground, collision, placement heights and route data from it. Retain click/tap movement and the existing actor, but replace flat-grid path construction with one shared height-aware route service. Keep the valley small and the water in prepared visual states.

**Technology:** existing Godot 4.7.2, typed GDScript, Compatibility renderer and Blender/glTF asset workflow. No paid services, new terrain plugin or shared-tool changes.

**Specification:** [milestone 4b](roadmaps/04b-visual-valley.md), with the relief direction below superseding the literal raised-board interpretation of the [v3 concept](mockups/valley-map-v3.svg).

Execute small, verifiable increments. Commit only when requested. The author reviews the first running composition before detailed scenery production. Existing child/device validation gates remain open.

## Proposed landscape

- A low central valley floor, enclosed by gentle side hills and a higher rear ridge. Keep the foreground lower so the camera can see the actor and targets.
- A continuous river channel cut into the ground, entering from the rear and leaving toward the foreground. The dam spans a narrow section; the upstream basin widens into the lake.
- Two broad, gently sloping shore routes and small clearings for branches and home parts. Avoid stairs, narrow ledges and sharp changes of slope.
- A low, dry land connection around the upstream end of the basin, outside the maximum water footprint, so both banks remain connected without swimming or a new bridge-building mechanic. If this cannot fit legibly, keep all required activities on one connected bank for the first version.
- A lodge mound and food storage near reachable shore positions. The visible placement location may be in water; the actor's interaction approach must remain on solid dry ground.
- Irregular terrain edges and hills extending beyond the play routes. Remove the visible rectangular rim; terrain and vegetation communicate the limits. Any invisible safety collision must coincide with an understandable landscape boundary.
- Reuse the two Meshy trees after terrain placement is stable. Adding more props is not the means of establishing depth.

**Initial proportions to try, not acceptance targets:** retain roughly the current playable footprint; widen only the decorative perimeter as needed. With the existing actor about 0.9 m tall, try walkable rises of 0.3–0.8 m, surrounding hills of 1.5–3 m and a riverbed roughly 0.3–0.6 m below the main shore. Start with route slopes at or below 20 degrees and a conservative physical floor limit of 30 degrees. Tune these from actual traversal and framing rather than treating the numbers as final art direction.

## What the code currently assumes

- `movement_world.gd` creates one flat ground box and rectangular boundary walls; terrain taps above `y = 0.1` are rejected.
- Dam, home and food each build path points with `y = 0`, using an `AStarGrid2D` and integer X/Z positions.
- `prototype_actor.gd` intentionally ignores vertical offset when following waypoints and uses gravity for floor contact. Arrival currently means its waypoint list is empty.
- Spawn, loose items, destination rings, water, lodge and winter decorations use fixed heights. Those must be anchored to the new ground or to an explicit water/building datum.
- Saves contain stable material IDs and stage choices rather than world positions. This permits moving the landscape without a save reset; restore must resolve those IDs into the new layout.

Adding hills only to the visible mesh would leave these assumptions broken. The work below changes presentation and traversal together.

## Source and responsibility map

| File | Responsibility |
|---|---|
| New `game/scripts/valley_terrain.gd` | Deterministic surface definition, terrain mesh, matching static collision and ground-height queries |
| New `game/scripts/valley_layout.gd` | Shared spawn, stage, collection, shore-approach and water-state anchors; stable gameplay IDs stay unchanged |
| New `game/scripts/valley_navigation.gd` | Height-aware route graph, traversable edge checks and shared world-space paths |
| `game/scripts/movement_world.gd` | Assemble the services; input routing, stage orchestration and restore; remove flat-ground construction and duplicated path conversion |
| `game/scripts/prototype_actor.gd` | Stable slope traversal, grounded arrival and interrupted-path handling |
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

Use an `AStar3D` graph over a sampled X/Z surface as the initial implementation: it supports explicit edge rejection and world-space heights without introducing navigation-mesh baking into this small fixed level. A cell graph is acceptable internally; the player should see smooth ground and stable movement. Start with 0.5 m sampling and four-neighbour links, then adjust only if the actual routes justify it.

Connections must check the segment between nodes for terrain slope, actor clearance, obstacles and water, not just whether endpoints are valid. Start/target connections from arbitrary positions need those same checks. Exclude the maximum lake footprint from walking for this first version so rising water cannot strand the actor or require dynamic navigation rebuilding. Reserve clearance for the actor's 0.26 m capsule radius plus a small margin.

## R1 — Review the landform before detailing it

- [ ] Capture the current valley as a baseline. Add the isolated relief preview with neutral terrain colors, a channel, lake basin and simple shapes for dam/lodge/collection zones.
- [ ] Define the deterministic terrain and named anchors. Build visible terrain and static collision from the same triangles; do not leave the old flat collider underneath the playable surface.
- [ ] Show temporary overlays for future walking routes, maximum water area and blocked hills. Clearly distinguish these guides from functioning navigation at this stage.
- [ ] Try the current elevated camera first. Adjust height, tilt and framing to reveal the slopes and riverbed while keeping important targets visible; manual camera control remains unnecessary.
- [ ] Show the author the actual running view at 960 × 600 and a phone-shaped viewport. Include a low side view as a diagnostic, but assess acceptance using the play camera.

**Acceptance:** the author can recognize a valley from the untextured landform, without relying on trees to supply depth. Record camera and terrain proportions before producing detailed scenery. If it still reads as a raised board, revise R1 rather than decorate it.

## R2 — Prove movement on one slope and one bank

- [ ] Implement the shared navigation graph against terrain collision/height, preserving one connected dry route around the basin. Steep hills, open water and outside terrain are not destinations.
- [ ] Replace the absolute-height tap rejection with terrain-surface identification. Clicking a raised valid slope must work; clicking a rock or inaccessible hill must not become a route through it.
- [ ] Adapt actor movement to follow ground with gravity and floor snapping. Keep the visual body upright initially; do not pitch the entire capsule or carried objects to every triangle normal.
- [ ] Make waypoint advancement require appropriate horizontal proximity and grounded vertical proximity. A point on the wrong elevation is not reached merely because X/Z match. Use tolerance consistent with the existing 0.035 m horizontal arrival behavior and verify it experimentally on slopes.
- [ ] Test uphill, downhill, stopping, retargeting halfway up a slope, carrying a branch and repeatedly tapping the same point. Verify no bouncing, sliding while idle, hovering, clipping or permanent movement without arrival.
- [ ] Add focused terrain tests comparing sampled heights against collision rays at slope interiors and triangle boundaries. Add navigation cases for inaccessible slopes, water-crossing edges, obstacle clearance and unreachable targets.

**Acceptance:** the actor visibly climbs and descends the real surface in the preview, arrives reliably and never routes across unsupported water. Capture a short traversal demonstration. Do not integrate all stages while this foundation is unstable.

## R3 — Bring the three stages onto the terrain

- [ ] Integrate the terrain and navigation services into the main scene and stage bindings. Remove the parallel flat-grid routes rather than maintaining contradictory routing systems.
- [ ] Position spawn, loose branches, home parts, food bundles, destination markers and help rings from shared ground anchors. Keep target markers close to the actual ground; use local flattening at interaction clearings where necessary for readable rings.
- [ ] Assign explicit dry approach points for dam, lodge wall/roof and food store. Check physical reach from the shore as well as mathematical path connectivity.
- [ ] Preserve interaction semantics: repeated selection, swap, cancellation, unsuitable items, occupied slots, help and all three stages. Returning an item restores its new grounded origin, not the old hard-coded elevation.
- [ ] Retain existing placement IDs/order and finish choices. Update test setup to select meaningful objects and approaches instead of assuming original absolute coordinates.
- [ ] Replay each collection/placement route, including at least one item on a raised clearing, using actual input rays in addition to direct method calls.

**Acceptance:** complete dam, home and food on the relieved terrain without walking through water, teleporting objects or selecting invisible targets. Keep saved adventures isolated during tests.

## R4 — Make the water and winter fit the basin

- [ ] Define initial/intermediate/full water levels and footprints within the authored riverbed/basin. Use horizontal prepared water surfaces; do not stretch water through dry hills or raise the downstream reach with the upstream lake.
- [ ] Make the dam span the channel and visually retain the upstream water. Verify the lodge mound and food pile align with water and remain readable at every relevant state.
- [ ] Keep every required approach above maximum water. Verify water transitions do not create a hidden barrier or allow the actor to walk visibly under the lake.
- [ ] Ground trees, stones, owl, otter and family at their new positions. Adapt winter snow patches to the terrain rather than leaving them at one world height; preserve access and visibility after the ending.
- [ ] Capture the same play camera before building, with the complete dam, and in winter. Confirm slopes, river depth and the basin remain evident across all states.

**Acceptance:** water collects in the low ground and the chapter changes the same understandable landscape. No physical water simulation, swimming or new building mechanics are introduced.

## R5 — Validate saves, readability and the installed build

- [ ] Load isolated schema 1 and schema 2 fixtures representing partial dam, each finish, partial/complete home, partial food and winter. Resolve positions from the new anchors and respawn on safe terrain, preserving durable progress.
- [ ] Exercise save-failure warnings, backup recovery, transient carried-item recovery and protected restart. Terrain changes alone must not trigger a schema bump or clear player progress.
- [ ] Add terrain/navigation tests to `./tools/castor.ps1 check`; run the complete suite. Retain movement speed/frame-rate checks and assess uphill/downhill travel for excessive slowdown.
- [ ] Export Windows and inspect the actual build, including raised-ground taps, full progression and ending. Use isolated save/capture paths and compare before/after views.
- [ ] Run the adult priority-device rehearsal and record camera/resolution, frame-time observations and any touch occlusion or heating. Android remains pending until installed and tested on the real phone.
- [ ] Obtain the author's acceptance of the relief and observe a short child session when available. Record help needed, mis-taps and whether the raised ground makes routes harder to understand.
- [ ] Update the 4b checklist, inventory, how-to-run instructions for the preview, and startup progress. Separate implemented, visually accepted and device-tested statuses.

**Acceptance:** existing progress survives, all stages are playable, and the accepted camera communicates a valley without sacrificing ease of play. Automated checks cannot close author/child/device gates.

## Risks and scope limits

| Risk | Planned response |
|---|---|
| Hills hide the actor or targets | Keep foreground low, put primary tasks in open clearings and review from the actual camera in R1/R3 |
| Navigation cuts a steep bank between valid nodes | Test complete connections and actor clearance, including arbitrary start positions |
| Visual ground differs from collision or placement height | Derive all three from one terrain definition and verify with collision-ray tests |
| Basin divides required gameplay into disconnected banks | Reserve the dry upstream connection before asset placement, or consolidate required tasks on a connected bank |
| Water or snow conceals interaction surfaces | Review every stage from the same camera and constrain routes against maximum water |
| Terrain work expands into a new game | Preserve one level, existing item counts, saves and verbs; no jumping, swimming, dynamic terrain or new quests |

The first implementation delivery should be **R1 plus the R2 traversal sample**, not a full visual remake. Detailed asset production resumes after the landform and slope behavior are accepted.
