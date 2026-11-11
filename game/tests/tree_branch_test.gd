extends SceneTree
## E2 focused regression: one authored tree supplies exactly one usable dam
## branch after a single gnaw action. Covers the schema 4 storage contract, the
## fresh standing tree, the request-driven gnaw flow, reload recovery after cut,
## carry and placement, a legacy schema 2 save, a forced save failure and using
## the tree branch as dam material. Also covers the authored layout, the play
## camera tap path, the home-stage interaction gate, the felled presentation and
## reloads during the authored fall and after a failed cut save.

const DamSave = preload("res://scripts/dam_save.gd")
const MovementWorldScript = preload("res://scripts/movement_world.gd")

const SCENE_PATH := "res://scenes/movement.tscn"
const BRANCH_ID := "branch_normal_03"
const BRANCH_LAYER := 4
const BRANCH_COUNT: int = 5
const SCHEMA_DIRECTORY := "user://tree_branch_schema_test/"
const FLOW_DIRECTORY := "user://tree_branch_flow_test/"
const LEGACY_DIRECTORY := "user://tree_branch_legacy_test/"
const FAILURE_DIRECTORY := "user://tree_branch_failure_test/"
const DAM_DIRECTORY := "user://tree_branch_dam_test/"
const HOME_GATE_DIRECTORY := "user://tree_branch_home_gate_test/"
const INTERACTION_GATE_DIRECTORY := "user://tree_branch_interaction_gate_test/"
const RELOAD_FALL_DIRECTORY := "user://tree_branch_reload_fall_test/"
const LANDING_TOLERANCE: float = 0.1
## The work spot itself must be at most 0.9 m from the tree accessor. The actor
## stops on a 0.5 m navigation cell centre, so its own arrival check keeps one
## cell of quantisation and the actor's 0.035 m arrival radius.
const WORK_SPOT_MAX_DISTANCE: float = 0.9
const ACTOR_WORK_TOLERANCE: float = 1.35
const LANDING_SPOT_CLEARANCE: float = 1.0
const TREE_TASK_CLEARANCE: float = 1.2
const TREE_MAX_SLOPE_DEGREES: float = 12.0
const FALL_ANGLE_TOLERANCE: float = 0.5
const FALL_DURATION_TOLERANCE: float = 0.35
const GROUND_TOLERANCE: float = 0.02
const CROWN_LANDING_MARGIN: float = 0.25
const RESTORE_STABILITY_SECONDS: float = 1.2

var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _expect(condition: bool, description: String) -> void:
	if not condition:
		failures += 1
		push_error(description)


func _wait(condition: Callable, timeout_seconds: float = 15.0) -> bool:
	var deadline := Time.get_ticks_msec() + int(timeout_seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		await physics_frame
		if condition.call():
			return true
	return condition.call()


func _run() -> void:
	root.size = Vector2i(960, 600)
	_check_schema()
	var world: Node = await _check_fresh_world_and_gnaw()
	world = await _reload_after_cut(world)
	world = await _reload_after_pickup(world)
	world = await _reload_after_placement(world)
	if world != null:
		world.queue_free()
		await process_frame
	_expect(DamSave.clear_save(FLOW_DIRECTORY), "Could not clean the tree-flow save directory.")
	await _check_legacy_schema_2()
	await _check_forced_save_failure()
	await _check_reload_during_fall()
	await _check_home_stage_gating()
	await _check_interaction_gate()
	await _check_tree_branch_as_dam_material()
	if failures == 0:
		print("CASTOR_TREE_BRANCH_OK schema4 tree_standing hidden_branch gnaw cut reload pickup placed legacy_schema2 save_failure dam_material layout tap_path home_gate fall_presentation reload_fall save_failure_reload interaction_gate")
	quit(0 if failures == 0 else 1)


## Schema 4 is the only writable schema, still accepts older schemas and migrates
## them in memory. Malformed stable tree IDs must never reach persistence.
func _check_schema() -> void:
	_expect(DamSave.clear_save(SCHEMA_DIRECTORY), "Could not clear the schema check directory.")
	_expect(DamSave.SCHEMA_VERSION == 4, "SCHEMA_VERSION is %d instead of 4." % DamSave.SCHEMA_VERSION)
	var empty: Dictionary = DamSave.empty_state(DamSave.LEGACY_RECIPE_ID)
	_expect(int(empty["schema_version"]) == 4, "empty_state() is schema %d instead of 4." % int(empty["schema_version"]))
	_expect(empty["recipe_id"] == DamSave.LEGACY_RECIPE_ID and empty["cut_tree_ids"].is_empty(), "The explicit legacy state does not start with its tree standing.")
	_expect(DamSave.validate_state(empty), "The fresh schema 4 legacy state did not validate.")

	var cut_state: Dictionary = empty.duplicate(true)
	cut_state["cut_tree_ids"] = [DamSave.LEGACY_TREE_ID]
	_expect(DamSave.validate_state(cut_state), "A schema 4 state with the legacy tree cut was rejected.")
	_expect(DamSave.save_state(cut_state, SCHEMA_DIRECTORY), "Could not save a schema 4 state with the legacy tree cut.")
	var round_trip := DamSave.load_state(SCHEMA_DIRECTORY)
	_expect(round_trip["source"] == "primary", "The schema 4 save was not read back from the primary file.")
	_expect(round_trip["state"] == cut_state, "A schema 4 cut-tree state did not round-trip unchanged.")
	_expect(round_trip["state"]["cut_tree_ids"] == [DamSave.LEGACY_TREE_ID], "The schema 4 round-trip lost the cut-tree ID.")
	var written := _read_json(SCHEMA_DIRECTORY)
	_expect(int(written.get("schema_version", -1)) == 4 and written.get("cut_tree_ids") == [DamSave.LEGACY_TREE_ID], "save_state() did not write schema 4 with the cut-tree ID.")

	var extra: Dictionary = cut_state.duplicate(true)
	extra["unexpected_key"] = true
	_expect(not DamSave.validate_state(extra), "A schema 4 state with an extra key was accepted.")
	var missing: Dictionary = cut_state.duplicate(true)
	missing.erase("cut_tree_ids")
	_expect(not DamSave.validate_state(missing), "A schema 4 state without cut_tree_ids was accepted.")
	var numeric_cut: Dictionary = cut_state.duplicate(true)
	numeric_cut["cut_tree_ids"] = [1]
	_expect(not DamSave.validate_state(numeric_cut), "A numeric cut-tree ID was accepted.")
	var string_cut: Dictionary = cut_state.duplicate(true)
	string_cut["cut_tree_ids"] = ["tree_unknown"]
	_expect(not DamSave.validate_state(string_cut), "An unknown cut-tree ID was accepted.")

	var v2: Dictionary = _v2_state(["branch_normal_01", "branch_normal_02", BRANCH_ID], true, "finish_moss", ["home_part_rounded", ""], [])
	_expect(DamSave.validate_state(v2), "A valid schema 2 state was rejected by validate_state().")
	_expect(not v2.has("tree_cut"), "The schema 2 fixture unexpectedly carries tree_cut.")
	_expect(not DamSave.save_state(v2, SCHEMA_DIRECTORY), "save_state() accepted a schema 2 state for writing.")
	_expect(_read_json(SCHEMA_DIRECTORY).get("cut_tree_ids") == [DamSave.LEGACY_TREE_ID], "Refusing a schema 2 save disturbed the schema 4 file on disk.")
	var v1: Dictionary = _v1_state([BRANCH_ID], false, "")
	_expect(DamSave.validate_state(v1), "A valid schema 1 state was rejected by validate_state().")
	_expect(not DamSave.save_state(v1, SCHEMA_DIRECTORY), "save_state() accepted a schema 1 state for writing.")

	_expect(DamSave.clear_save(SCHEMA_DIRECTORY), "Could not clear the schema check directory before the migration fixtures.")
	_expect(_write_json(SCHEMA_DIRECTORY, v1), "Could not write the schema 1 fixture.")
	var migrated_v1 := DamSave.load_state(SCHEMA_DIRECTORY)
	_expect(migrated_v1["source"] == "primary", "The schema 1 fixture was not read as the primary save.")
	var migrated_v1_state: Dictionary = migrated_v1["state"]
	_expect(int(migrated_v1_state["schema_version"]) == 4, "A schema 1 save was not migrated to schema 4 in memory.")
	_expect(migrated_v1_state["recipe_id"] == DamSave.LEGACY_RECIPE_ID and migrated_v1_state["cut_tree_ids"] == [DamSave.LEGACY_TREE_ID], "Schema 1 migration did not preserve the placed branch's legacy tree source.")
	_expect(migrated_v1_state["home_slots"] == ["", ""] and migrated_v1_state["food_placements"].is_empty(), "Schema 1 migration did not add empty home and food stages.")
	_expect(migrated_v1_state["placed_materials"] == [BRANCH_ID], "Schema 1 migration did not keep the dam material.")
	_expect(DamSave.validate_state(migrated_v1_state), "The migrated schema 1 state is not a valid schema 4 state.")
	_expect(int(_read_json(SCHEMA_DIRECTORY).get("schema_version", -1)) == 1, "Loading a schema 1 save rewrote its file to schema 4.")

	_expect(DamSave.clear_save(SCHEMA_DIRECTORY), "Could not clear the schema check directory before the schema 2 fixture.")
	_expect(_write_json(SCHEMA_DIRECTORY, v2), "Could not write the schema 2 fixture.")
	var migrated_v2 := DamSave.load_state(SCHEMA_DIRECTORY)
	_expect(migrated_v2["source"] == "primary", "The schema 2 fixture was not read as the primary save.")
	var migrated_v2_state: Dictionary = migrated_v2["state"]
	_expect(int(migrated_v2_state["schema_version"]) == 4, "A schema 2 save was not migrated to schema 4 in memory.")
	_expect(migrated_v2_state["recipe_id"] == DamSave.LEGACY_RECIPE_ID and migrated_v2_state["cut_tree_ids"] == [DamSave.LEGACY_TREE_ID], "Schema 2 migration did not keep the legacy branch source relationship.")
	_expect(migrated_v2_state["home_slots"] == ["home_part_rounded", ""] and migrated_v2_state["food_placements"].is_empty(), "Schema 2 migration did not keep the home and food stages.")
	_expect(migrated_v2_state["placed_materials"].size() == 3, "Schema 2 migration did not keep all three dam materials.")
	_expect(DamSave.validate_state(migrated_v2_state), "The migrated schema 2 state is not a valid schema 4 state.")
	_expect(int(_read_json(SCHEMA_DIRECTORY).get("schema_version", -1)) == 2, "Loading a schema 2 save rewrote its file to schema 4.")
	_expect(DamSave.clear_save(SCHEMA_DIRECTORY), "Could not clean the schema check directory.")


## A fresh isolated chapter: the tree stands, its branch waits hidden at the
## landing without a cue and the tree advertises itself as interactive.
func _check_fresh_world_and_gnaw() -> Node:
	_expect(DamSave.clear_save(FLOW_DIRECTORY), "Could not clear the tree-flow save directory.")
	var world := _spawn_world(FLOW_DIRECTORY)
	_expect(await _wait(func() -> bool: return world.actor != null and world.actor.is_on_floor(), 8.0), "The fresh tree world did not ground the actor.")
	var tree := _find_tree(world)
	_expect(tree != null, "The fresh world has no BranchTree; the interactive tree is missing.")
	if tree == null:
		return world
	_expect(not tree.is_cut(), "The fresh tree already starts cut.")
	_expect_world_tree_cut(world, false, "Fresh world")
	var tree_xz := _tree_xz(world)
	_expect(_flat(tree.global_position).distance_to(tree_xz) <= LANDING_TOLERANCE, "The standing tree is not placed at TREE_XZ.")
	_expect(tree.visible, "The standing tree is not visible.")
	_expect(BranchTree.TREE_LAYER == 64, "BranchTree.TREE_LAYER is %d instead of 64." % BranchTree.TREE_LAYER)
	_expect(BranchTree.TREE_LAYER != HomeStage.SLOT_LAYER, "BranchTree.TREE_LAYER %d is still shared with HomeStage.SLOT_LAYER %d." % [BranchTree.TREE_LAYER, HomeStage.SLOT_LAYER])
	_expect(tree.has_method("is_interactive"), "BranchTree exposes no is_interactive() accessor.")
	_expect(tree.has_method("set_interactive"), "BranchTree exposes no set_interactive() gate.")
	_expect(tree.has_method("fall_angle_degrees"), "BranchTree exposes no fall_angle_degrees() accessor.")
	var hit_area := _tree_hit_area(tree)
	_expect(hit_area != null, "The tree has no hit Area3D on layer %d." % BranchTree.TREE_LAYER)
	_expect(hit_area != null and hit_area.collision_layer == BranchTree.TREE_LAYER, "The standing tree hit area is on layer %d instead of TREE_LAYER %d." % [hit_area.collision_layer if hit_area != null else -1, BranchTree.TREE_LAYER])
	_expect(tree.find_children("*", "PhysicsBody3D", true, false).is_empty(), "The tree introduced a physics body; its fall must stay authored.")
	var ring := _tree_ground_ring(tree)
	_expect(ring != null and ring.visible, "The standing tree has no visible ground-ring cue.")
	var ring_node := _tree_ring_node(tree)
	_expect(ring_node != null and ring_node.is_visible_in_tree(), "The fresh standing tree ground ring is not visible.")
	_expect(_tree_is_interactive(tree), "The fresh standing tree is not interactive in the dam stage.")
	_check_tree_layout(world, tree)

	_expect(world.branches.size() == BRANCH_COUNT, "The fresh world exposes %d branches instead of five." % world.branches.size())
	var branch := _branch_by_id(world)
	_expect(branch != null, "The fresh world has no %s branch." % BRANCH_ID)
	if branch == null:
		return world
	_expect(branch.get_parent() == world, "The hidden tree branch is not a world child before the cut.")
	_expect(not branch.visible, "The tree branch is visible before the tree is cut.")
	_expect(branch.state == CollectibleBranch.State.FREE, "The hidden tree branch is not free.")
	var hidden_layer: int = branch.hit_area.collision_layer if branch.hit_area != null else -1
	_expect(branch.hit_area != null and hidden_layer == 0, "The hidden tree branch is still collectable on layer %d." % hidden_layer)
	var landing := _tree_landing_xz(world)
	_expect(_flat(branch.global_position).distance_to(landing) <= LANDING_TOLERANCE, "The hidden tree branch does not wait at TREE_LANDING_XZ.")
	var cue := _cue_for(world, branch)
	_expect(cue == null or not cue.visible, "The hidden tree branch still shows a pickup cue.")
	var visible_cues := 0
	for branch_cue in world.branch_cues:
		if branch_cue != null and branch_cue.visible:
			visible_cues += 1
	_expect(visible_cues == 4, "The fresh dam cue set shows %d cues; the hidden tree branch must not add one." % visible_cues)
	_expect(_branch_instance_count(world) == 1, "The fresh world has %d %s instances instead of one." % [_branch_instance_count(world), BRANCH_ID])

	var observed: Dictionary = await _cut_tree_through_tap(world, tree)
	_expect(bool(observed["requested"]), "Tapping the standing tree through world._move_from_screen() did not start the gnaw.")
	_expect(bool(observed["walked"]), "The beaver did not walk to the tree work spot.")
	_expect(bool(observed["gnaw"]), "The gnaw action did not run at the tree.")
	_expect(observed.has("gnaw_heading_error"), "The gnaw action never reported its heading at the trunk.")
	if observed.has("gnaw_heading_error"):
		_expect(float(observed["gnaw_heading_error"]) <= 20.0, "The beaver started gnawing %.1f degrees away from the trunk; it must face the tree." % float(observed["gnaw_heading_error"]))
		_expect(float(observed["gnaw_gap"]) >= 0.25 and float(observed["gnaw_gap"]) <= 1.1, "The beaver started gnawing %.2f m from the trunk; the mouth must stay next to it." % float(observed["gnaw_gap"]))
	_expect(bool(observed["cut"]), "The tree did not cut and release its branch after the gnaw.")
	if not bool(observed["cut"]):
		return world
	_expect(tree.is_cut(), "The tree is not cut after the gnaw.")
	_expect_world_tree_cut(world, true, "After the gnaw")
	_expect(world.actor.is_arrived(), "The gnaw finished without the beaver at the work spot.")
	var work_gap := _flat(world.actor.global_position).distance_to(tree_xz)
	_expect(work_gap <= ACTOR_WORK_TOLERANCE, "The beaver stopped %.2f m from the tree; with one 0.5 m navigation cell and its arrival radius the actor may stop at most %.2f m away." % [work_gap, ACTOR_WORK_TOLERANCE])
	var accessor_gap := tree_xz.distance_to(_tree_work_xz(world))
	_expect(accessor_gap <= WORK_SPOT_MAX_DISTANCE, "TREE_WORK_XZ is %.2f m from TREE_XZ; the authored work spot must stay within %.2f m." % [accessor_gap, WORK_SPOT_MAX_DISTANCE])
	_expect_branch_available(world, branch, "After the gnaw")
	_check_fall_presentation(world, tree, observed)
	_expect(_branch_instance_count(world) == 1, "The gnaw produced %d %s instances instead of one." % [_branch_instance_count(world), BRANCH_ID])
	# The cut is durable before the branch is usable; allow the same frame and a
	# short grace for the single save instead of racing a file read.
	var saved_cut := false
	for _frame in range(120):
		saved_cut = _has_legacy_tree_cut(DamSave.load_state(FLOW_DIRECTORY)["state"])
		if saved_cut:
			break
		await physics_frame
	_expect(saved_cut, "The gnaw did not save the legacy cut-tree ID.")
	var saved := DamSave.load_state(FLOW_DIRECTORY)
	_expect(saved["source"] == "primary", "The gnaw did not write a primary save.")
	_expect(_has_legacy_tree_cut(saved["state"]), "The gnaw did not keep the legacy cut-tree ID.")
	_expect(saved["state"]["placed_materials"].is_empty(), "The gnaw saved the landed branch as placed.")
	var count_before := _branch_instance_count(world)
	_expect(not world.request_gnaw_tree(), "A second gnaw request was accepted after the tree was cut.")
	_expect(_branch_instance_count(world) == count_before and world.branches.size() == BRANCH_COUNT, "A repeated gnaw request duplicated or lost a branch.")
	_expect(branch.state == CollectibleBranch.State.FREE and world.carried_branch == null, "A repeated gnaw request disturbed the landed branch.")
	return world


## A: the authored tree points are dry, inside the playable rectangle and on a
## gentle slope; the work spot is a real walkable 0.9 m approach, the landing is
## walkable and clear of the other branch spots, and the tree is clear of every
## other task point.
func _check_tree_layout(world: Node, _tree: BranchTree) -> void:
	var tree_xz := _tree_xz(world)
	var work_xz := _tree_work_xz(world)
	var landing_xz := _tree_landing_xz(world)
	var points: Array = [["TREE_XZ", tree_xz], ["TREE_WORK_XZ", work_xz], ["TREE_LANDING_XZ", landing_xz]]
	for entry in points:
		var label: String = entry[0]
		var xz: Vector2 = entry[1]
		_expect(xz.is_finite(), "%s is not a finite point." % label)
		if not xz.is_finite():
			continue
		_expect(ValleyTerrain.PLAYABLE_RECT.has_point(xz), "%s %s sits outside PLAYABLE_RECT." % [label, str(xz)])
		_expect(not world.terrain.is_water_footprint(xz), "%s %s is inside the maximum water footprint." % [label, str(xz)])
		var slope: float = world.terrain.slope_degrees(xz)
		_expect(slope <= TREE_MAX_SLOPE_DEGREES, "%s %s sits on a %.2f degree slope; the tree points must stay at or below %.0f degrees." % [label, str(xz), slope, TREE_MAX_SLOPE_DEGREES])
	_expect(world.navigation.is_walkable(work_xz), "TREE_WORK_XZ %s is not walkable." % str(work_xz))
	var accessor_gap := tree_xz.distance_to(work_xz)
	_expect(accessor_gap <= WORK_SPOT_MAX_DISTANCE, "TREE_WORK_XZ is %.2f m from TREE_XZ; the work spot must stay within %.2f m." % [accessor_gap, WORK_SPOT_MAX_DISTANCE])
	_expect(world.navigation.is_walkable(landing_xz), "TREE_LANDING_XZ %s is not walkable." % str(landing_xz))
	var other_spots := _other_branch_spots(world)
	_expect(other_spots.size() == 4, "The fresh world exposes %d other branch spots instead of four." % other_spots.size())
	var landing_gap := _nearest_gap(landing_xz, other_spots)
	_expect(landing_gap >= LANDING_SPOT_CLEARANCE, "TREE_LANDING_XZ is %.2f m from the nearest other branch spot; it must stay at least %.2f m clear." % [landing_gap, LANDING_SPOT_CLEARANCE])
	var task_points: Array[Vector2] = []
	task_points.append_array(other_spots)
	for anchor_id: StringName in ValleyLayout.ANCHOR_IDS:
		task_points.append(world.layout.anchor_xz(anchor_id))
	var tree_gap := _nearest_gap(tree_xz, task_points)
	_expect(tree_gap >= TREE_TASK_CLEARANCE, "TREE_XZ is %.2f m from the nearest other task point; it must stay at least %.2f m clear." % [tree_gap, TREE_TASK_CLEARANCE])


## B: the play camera must route a tree tap through world._move_from_screen().
## A second tap on the same screen point is consumed without cancelling the walk.
func _cut_tree_through_tap(world: Node, tree: BranchTree) -> Dictionary:
	var observed := {"requested": false, "walked": false, "gnaw": false, "cut": false, "fall_started_frame": -1, "fall_done_frame": -1}
	if tree == null:
		return observed
	# The body turn must aim the model at the trunk from any approach direction,
	# using the same heading convention as the walking rotation. The actor is
	# moved around the trunk for this unit check, then restored before the walk.
	var tree_xz := _tree_xz(world)
	var original_position: Vector3 = world.actor.global_position
	var original_rotation: Vector3 = world.actor.rotation
	for direction: Vector2 in [Vector2(1.0, 0.0), Vector2(0.0, 1.0), Vector2(-1.0, -0.5)]:
		var approach: Vector2 = tree_xz + direction * 1.5
		world.actor.position = Vector3(approach.x, world.terrain.height_at(approach) + 0.05, approach.y)
		world.actor.face_towards(tree_xz)
		var to_target: Vector2 = (tree_xz - _flat(world.actor.global_position)).normalized()
		var forward: Vector3 = -world.actor.global_basis.z
		var dot: float = clampf(forward.dot(Vector3(to_target.x, 0.0, to_target.y)), -1.0, 1.0)
		_expect(rad_to_deg(acos(dot)) <= 2.0, "face_towards left the beaver %.1f degrees away from the trunk for approach direction %s." % [rad_to_deg(acos(dot)), str(direction)])
	world.actor.global_position = original_position
	world.actor.rotation = original_rotation
	var screen := _tree_screen(world, tree)
	_expect(root.get_visible_rect().has_point(screen), "The tree screen position %s is outside the 960 x 600 play view." % str(screen))
	var first: bool = world._move_from_screen(screen)
	_expect(first, "Tapping the standing tree through world._move_from_screen() did not start the gnaw.")
	if not first:
		return observed
	_expect(_world_tree_pending(world), "The tree tap did not leave a pending tree action.")
	var waypoints_before: PackedVector3Array = world.actor.waypoints.duplicate()
	_expect(not waypoints_before.is_empty(), "The tree tap left the beaver without a walk path to the work spot.")
	var second: bool = world._move_from_screen(screen)
	_expect(second, "A second tap on the same tree screen position was refused instead of being a no-op.")
	_expect(_world_tree_pending(world), "A second tap on the tree cancelled the pending gnaw.")
	_expect(world.actor.waypoints == waypoints_before, "A second tap on the tree changed the beaver's waypoints; the walk was cancelled or retargeted.")
	observed["requested"] = first
	return await _observe_tree_cut(world, tree, observed)


## Shared observation for both the direct request and the play-camera tap. It
## records the walk, the gnaw action, the cut and the authored fall duration.
func _observe_tree_cut(world: Node, tree: BranchTree, observed: Dictionary) -> Dictionary:
	if not bool(observed.get("requested", false)):
		return observed
	var branch := _branch_by_id(world)
	var fall_started := -1
	var fall_done := -1
	var frame_index := 0
	var deadline := Time.get_ticks_msec() + 20000
	while Time.get_ticks_msec() < deadline:
		if world.actor.current_animation == &"Walk":
			observed["walked"] = true
		if world.actor.action_tween != null:
			observed["gnaw"] = true
			if not observed.has("gnaw_heading_error"):
				var tree_xz := _tree_xz(world)
				var to_tree := tree_xz - _flat(world.actor.global_position)
				observed["gnaw_gap"] = to_tree.length()
				var forward: Vector3 = -world.actor.global_basis.z
				var dot: float = clampf(forward.dot(Vector3(to_tree.normalized().x, 0.0, to_tree.normalized().y)), -1.0, 1.0)
				observed["gnaw_heading_error"] = rad_to_deg(acos(dot))
		var angle := _tree_fall_angle(tree)
		# Count simulated physics frames, not wall-clock time: the focused run
		# uses --fixed-fps 60, so the engine simulates the authored duration much
		# faster than real time.
		if tree.is_cut() and fall_started < 0 and is_finite(angle) and angle < BranchTree.FALL_DEGREES - FALL_ANGLE_TOLERANCE:
			fall_started = frame_index
		if tree.is_cut() and fall_done < 0 and is_finite(angle) and absf(angle - BranchTree.FALL_DEGREES) <= FALL_ANGLE_TOLERANCE:
			fall_done = frame_index
		if tree.is_cut() and branch != null and branch.hit_area != null and branch.hit_area.collision_layer == BRANCH_LAYER:
			observed["cut"] = true
			break
		frame_index += 1
		await physics_frame
	observed["fall_started_frame"] = fall_started
	observed["fall_done_frame"] = fall_done
	if tree.is_cut() and branch != null and branch.hit_area != null and branch.hit_area.collision_layer == BRANCH_LAYER:
		observed["cut"] = true
	return observed


## D: after the real cut the authored fall must be complete, the stump and cut
## top shown, and the dedicated fallen trunk/crown must rest above the terrain
## without reaching the branch landing.
func _check_fall_presentation(world: Node, tree: BranchTree, observed: Dictionary) -> void:
	_expect(is_equal_approx(BranchTree.FALL_DURATION, 1.0), "BranchTree.FALL_DURATION is %.2f instead of 1.0." % BranchTree.FALL_DURATION)
	_expect(is_equal_approx(BranchTree.FALL_DEGREES, 90.0), "BranchTree.FALL_DEGREES is %.2f instead of 90." % BranchTree.FALL_DEGREES)
	var angle := _tree_fall_angle(tree)
	_expect(is_finite(angle) and absf(angle - BranchTree.FALL_DEGREES) <= FALL_ANGLE_TOLERANCE, "fall_angle_degrees() is %.2f instead of 90 within %.2f." % [angle, FALL_ANGLE_TOLERANCE])
	var started := int(observed.get("fall_started_frame", -1))
	var done := int(observed.get("fall_done_frame", -1))
	_expect(started >= 0 and done >= started, "The test did not observe the authored fall duration (start frame %d, end frame %d)." % [started, done])
	if started >= 0 and done >= started:
		var physics_fps := float(Engine.get_physics_ticks_per_second())
		var seconds := float(done - started) / physics_fps
		_expect(absf(seconds - BranchTree.FALL_DURATION) <= FALL_DURATION_TOLERANCE, "The authored fall took %.2f simulated seconds instead of %.2f s." % [seconds, BranchTree.FALL_DURATION])
	var stump := _named_mesh(tree, "TreeStump")
	var cut_top := _named_mesh(tree, "TreeStumpCut")
	_expect(stump != null and stump.is_visible_in_tree(), "The cut tree does not show its TreeStump.")
	_expect(cut_top != null and cut_top.is_visible_in_tree(), "The cut tree does not show its TreeStumpCut top.")
	if stump != null:
		var stump_aabb := _node_world_aabb(stump)
		_expect(stump_aabb.size.y >= 0.1, "The visible stump is only %.2f m tall." % stump_aabb.size.y)
	var trunk := _fallen_part(tree, ["trunk"])
	var crown := _fallen_part(tree, ["crown", "canopy"])
	if trunk == null or crown == null:
		var fallback := _fallback_fallen_parts(tree)
		if trunk == null and fallback.size() >= 1:
			trunk = fallback[0]
		if crown == null and fallback.size() >= 2:
			crown = fallback[1]
	_expect(trunk != null and crown != null, "The cut tree exposes no separate horizontal fallen trunk and resting crown.")
	if trunk == null or crown == null:
		return
	var trunk_aabb := _node_world_aabb(trunk)
	var crown_aabb := _node_world_aabb(crown)
	_expect(trunk_aabb.size != Vector3.ZERO and crown_aabb.size != Vector3.ZERO, "The fallen trunk or crown has no measurable mesh.")
	if trunk_aabb.size == Vector3.ZERO or crown_aabb.size == Vector3.ZERO:
		return
	var horizontal := maxf(trunk_aabb.size.x, trunk_aabb.size.z)
	_expect(horizontal >= 0.6, "The fallen trunk is only %.2f m long." % horizontal)
	_expect(trunk_aabb.size.y <= horizontal * 0.8, "The fallen trunk is not horizontal: height %.2f m against horizontal length %.2f m." % [trunk_aabb.size.y, horizontal])
	var trunk_clearance := _aabb_bottom_clearance(world, trunk_aabb)
	_expect(trunk_clearance >= -GROUND_TOLERANCE, "The fallen trunk dips %.2f m below the terrain at its centre; its lowest point must stay at or above terrain - %.2f m." % [-trunk_clearance, GROUND_TOLERANCE])
	var crown_clearance := _aabb_bottom_clearance(world, crown_aabb)
	_expect(crown_clearance >= -GROUND_TOLERANCE, "The resting crown dips %.2f m below the terrain at its centre; its lowest point must stay above the ground." % -crown_clearance)
	var margin := _crown_landing_margin(world, crown_aabb)
	_expect(margin >= CROWN_LANDING_MARGIN, "The fallen crown reaches to within %.2f m of TREE_LANDING_XZ; its far edge must stay at least %.2f m before the landing." % [margin, CROWN_LANDING_MARGIN])


## Reloading a save whose tree was cut must apply the cut at once, without
## replaying the fall, and leave the one branch free at the landing.
func _reload_after_cut(world: Node) -> Node:
	if world != null:
		world.queue_free()
		await process_frame
	var reloaded := _spawn_world(FLOW_DIRECTORY)
	var tree := _find_tree(reloaded)
	_expect(tree != null and tree.is_cut(), "Reloading after the cut did not restore the tree already cut.")
	_expect_world_tree_cut(reloaded, true, "Reloading after the cut")
	var before: Dictionary = _tree_transforms(tree) if tree != null else {}
	await create_timer(RESTORE_STABILITY_SECONDS).timeout
	if tree != null:
		_expect(_tree_transforms_match(before, _tree_transforms(tree)), "Restoring the cut tree replayed its fall instead of applying it immediately.")
	_expect(await _wait(func() -> bool: return reloaded.actor != null and reloaded.actor.is_on_floor(), 8.0), "The reloaded cut world did not ground the actor.")
	var branch := _branch_by_id(reloaded)
	_expect(branch != null, "Reloading after the cut lost %s." % BRANCH_ID)
	if branch != null:
		_expect_branch_available(reloaded, branch, "Reloading after the cut")
	_expect(_branch_instance_count(reloaded) == 1, "Reloading after the cut produced %d %s instances." % [_branch_instance_count(reloaded), BRANCH_ID])
	return reloaded


## Carrying the branch is transient: it is never saved as carried, and a reload
## returns it to the landing with the tree still cut.
func _reload_after_pickup(world: Node) -> Node:
	var branch := _branch_by_id(world)
	_expect(branch != null and world.request_collect(branch), "The revealed tree branch could not be collected before the reload.")
	_expect(await _wait(func() -> bool: return branch != null and world.carried_branch == branch, 15.0), "The beaver did not pick up the tree branch before the reload.")
	_expect(world.carried_branch == branch, "The tree branch was not carried before the reload.")
	var carried_save := DamSave.load_state(FLOW_DIRECTORY)
	_expect(_has_legacy_tree_cut(carried_save["state"]) and carried_save["state"]["placed_materials"].is_empty(), "Carrying the tree branch changed the saved cut or saved it as placed.")
	world.queue_free()
	await process_frame
	var reloaded := _spawn_world(FLOW_DIRECTORY)
	var tree := _find_tree(reloaded)
	var returned := _branch_by_id(reloaded)
	_expect(tree != null and tree.is_cut(), "Reloading after carrying the tree branch lost the cut.")
	_expect(reloaded.carried_branch == null, "Reloading kept the tree branch carried instead of returning it to the landing.")
	if returned != null:
		_expect_branch_available(reloaded, returned, "Reloading after carrying")
		_expect(returned.state == CollectibleBranch.State.FREE, "The carried tree branch did not return as free.")
	_expect(_branch_instance_count(reloaded) == 1, "Reloading after carrying produced %d %s instances." % [_branch_instance_count(reloaded), BRANCH_ID])
	return reloaded


## Placing the branch is durable and unique: a reload shows the tree cut, one
## placed material in the first dam slot and no free duplicate.
func _reload_after_placement(world: Node) -> Node:
	var branch := _branch_by_id(world)
	_expect(branch != null and world.request_collect(branch), "The returned tree branch could not be collected again.")
	_expect(await _wait(func() -> bool: return branch != null and world.carried_branch == branch, 15.0), "The beaver did not carry the tree branch for placement.")
	_expect(world.request_place(), "The carried tree branch could not be routed to the dam.")
	_expect(await _wait(func() -> bool: return world.placed_count == 1, 20.0), "The tree branch did not advance the dam count to one.")
	world.queue_free()
	await process_frame
	var reloaded := _spawn_world(FLOW_DIRECTORY)
	var tree := _find_tree(reloaded)
	var restored := _branch_by_id(reloaded)
	_expect(tree != null and tree.is_cut(), "Reloading after placing the tree branch lost the cut.")
	_expect(reloaded.placed_count == 1, "Reloading restored %d dam placements instead of one." % reloaded.placed_count)
	_expect(restored != null and restored.state == CollectibleBranch.State.PLACED, "The placed tree branch did not restore as placed.")
	if restored != null:
		_expect(restored.placed_slot == 0, "The placed tree branch restored in slot %d instead of the first dam slot." % restored.placed_slot)
	_expect(_branch_instance_count(reloaded) == 1, "Reloading after placing produced %d %s instances." % [_branch_instance_count(reloaded), BRANCH_ID])
	_expect(_free_branch_count(reloaded) == 0, "Reloading after placing left a free tree-branch duplicate.")
	_expect(is_equal_approx(reloaded.water_level, reloaded.terrain.intermediate_water_level()), "The restored one-branch dam did not keep the intermediate water level.")
	var saved := DamSave.load_state(FLOW_DIRECTORY)
	_expect(saved["source"] == "primary", "Reloading after placing did not keep a primary save.")
	_expect(_has_legacy_tree_cut(saved["state"]), "The placed tree branch lost the saved cut.")
	_expect(saved["state"]["placed_materials"] == [BRANCH_ID], "The placed tree branch was not saved exactly once.")
	return reloaded


## A schema 2 save with branch_normal_03 already in the dam predates tree_cut:
## it must load with the tree cut, the dam intact and no free duplicate.
func _check_legacy_schema_2() -> void:
	_expect(DamSave.clear_save(LEGACY_DIRECTORY), "Could not clear the legacy schema 2 save directory.")
	var legacy: Dictionary = _v2_state([BRANCH_ID], false, "", ["", ""], [])
	_expect(not legacy.has("tree_cut"), "The legacy schema 2 fixture unexpectedly carries tree_cut.")
	_expect(DamSave.validate_state(legacy), "The legacy schema 2 fixture is not a valid schema 2 state.")
	_expect(_write_json(LEGACY_DIRECTORY, legacy), "Could not write the legacy schema 2 save.")
	var before := _read_text(LEGACY_DIRECTORY.path_join(DamSave.SAVE_FILE))
	var world := _spawn_world(LEGACY_DIRECTORY)
	var tree := _find_tree(world)
	_expect(tree != null and tree.is_cut(), "A legacy save naming branch_normal_03 as placed did not restore the cut tree.")
	_expect(world.placed_count == 1, "The legacy save restored %d dam placements instead of one." % world.placed_count)
	_expect(world.visual_environment.get_visible_dam_log_count() == 1, "The legacy save did not restore its single dam log.")
	var branch := _branch_by_id(world)
	_expect(branch != null and branch.state == CollectibleBranch.State.PLACED, "The legacy placed tree branch did not restore as placed.")
	_expect(_branch_instance_count(world) == 1, "The legacy save produced %d %s instances." % [_branch_instance_count(world), BRANCH_ID])
	_expect(_free_branch_count(world) == 0, "The legacy save left a free tree-branch duplicate.")
	_expect(is_equal_approx(world.water_level, world.terrain.intermediate_water_level()), "The legacy save did not keep its one-branch dam water level.")
	_expect(_read_text(LEGACY_DIRECTORY.path_join(DamSave.SAVE_FILE)) == before, "Loading the legacy save rewrote the file on disk.")
	var migrated := DamSave.load_state(LEGACY_DIRECTORY)
	_expect(int(migrated["state"]["schema_version"]) == DamSave.SCHEMA_VERSION and _has_legacy_tree_cut(migrated["state"]), "The legacy save did not migrate the placed tree branch's source identity.")
	world.queue_free()
	await process_frame
	_expect(DamSave.clear_save(LEGACY_DIRECTORY), "Could not clean the legacy schema 2 save directory.")


## A failed cut save warns in Portuguese, keeps the cut in memory and still
## leaves exactly one usable branch. A reload from the same directory must then
## recover the branch without a duplicate: either the tree stands with its branch
## hidden, or the tree is cut with exactly one available branch.
func _check_forced_save_failure() -> void:
	_expect(DamSave.clear_save(FAILURE_DIRECTORY), "Could not clear the save-failure directory.")
	var world := _spawn_world(FAILURE_DIRECTORY)
	_expect(await _wait(func() -> bool: return world.actor != null and world.actor.is_on_floor(), 8.0), "The save-failure world did not ground the actor.")
	# An unsafe path makes the cut's single save fail without touching a real save.
	world.save_directory = "res://unsafe"
	var observed: Dictionary = await _cut_tree_through_request(world)
	_expect(bool(observed["cut"]), "The tree did not cut when its save was forced to fail.")
	var warned: bool = await _wait(func() -> bool: return world.status.text == MovementWorldScript.SAVE_FAILURE_TEXT, 5.0)
	_expect(warned, "A failed tree save did not show the Portuguese save warning (status: %s)." % world.status.text)
	var tree := _find_tree(world)
	_expect(tree != null and tree.is_cut(), "The failed save lost the in-memory cut.")
	var branch := _branch_by_id(world)
	_expect_branch_available(world, branch, "After the failed save")
	_expect(_branch_instance_count(world) == 1, "The failed save left %d %s instances." % [_branch_instance_count(world), BRANCH_ID])
	_expect(branch != null and world.request_collect(branch), "The tree branch was not usable after a failed save.")
	_expect(await _wait(func() -> bool: return branch != null and world.carried_branch == branch, 15.0), "The tree branch could not be carried after a failed save.")
	_expect(_branch_instance_count(world) == 1, "Collecting after a failed save duplicated the tree branch.")
	world.queue_free()
	await process_frame
	# Reload from the directory the failed cut could not write. The branch must
	# stay recoverable and unique instead of appearing twice or vanishing.
	var reloaded := _spawn_world(FAILURE_DIRECTORY)
	_expect(await _wait(func() -> bool: return reloaded.actor != null and reloaded.actor.is_on_floor(), 8.0), "The save-failure reload did not ground the actor.")
	var restored_tree := _find_tree(reloaded)
	var restored_branch := _branch_by_id(reloaded)
	_expect(restored_tree != null, "The save-failure reload lost the interactive tree.")
	_expect(restored_branch != null, "The save-failure reload lost %s." % BRANCH_ID)
	_expect(_branch_instance_count(reloaded) == 1, "The save-failure reload produced %d %s instances." % [_branch_instance_count(reloaded), BRANCH_ID])
	var reloaded_save := DamSave.load_state(FAILURE_DIRECTORY)
	var saved_cut: bool = _has_legacy_tree_cut(reloaded_save["state"])
	var saved_placed: Array = reloaded_save["state"]["placed_materials"]
	_expect(saved_placed.count(BRANCH_ID) <= 1, "The save-failure reload saved %s %d times." % [BRANCH_ID, saved_placed.count(BRANCH_ID)])
	if restored_tree != null and restored_tree.is_cut():
		_expect(saved_cut, "The reloaded cut tree is not backed by its cut-tree ID.")
		_expect_branch_available(reloaded, restored_branch, "Save-failure reload with the tree cut")
		_expect(_free_branch_count(reloaded) == 1, "The reloaded cut tree exposes %d free %s branches instead of one." % [_free_branch_count(reloaded), BRANCH_ID])
	else:
		_expect(not saved_cut, "The reloaded standing tree is backed by a cut-tree ID.")
		_expect(restored_branch != null and not restored_branch.visible, "The reloaded standing tree exposes its hidden branch.")
		var restored_layer: int = restored_branch.hit_area.collision_layer if restored_branch != null and restored_branch.hit_area != null else -1
		_expect(restored_layer == 0, "The reloaded standing tree keeps its branch collectable on layer %d." % restored_layer)
		# The hidden branch waits free at the landing; exactly one is allowed,
		# because two would mean the failed cut duplicated branch_normal_03.
		_expect(_free_branch_count(reloaded) == 1, "The reloaded standing tree exposes %d free %s branches instead of its one hidden branch." % [_free_branch_count(reloaded), BRANCH_ID])

	reloaded.queue_free()
	await process_frame
	_expect(DamSave.clear_save(FAILURE_DIRECTORY), "Could not clean the save-failure directory.")


## E: reloading while the authored fall is running must restore the standing
## tree, keep the branch hidden and never persist the interrupted cut.
func _check_reload_during_fall() -> void:
	_expect(DamSave.clear_save(RELOAD_FALL_DIRECTORY), "Could not clear the reload-during-fall directory.")
	var world := _spawn_world(RELOAD_FALL_DIRECTORY)
	_expect(await _wait(func() -> bool: return world.actor != null and world.actor.is_on_floor(), 8.0), "The reload-during-fall world did not ground the actor.")
	var tree := _find_tree(world)
	_expect(tree != null, "The reload-during-fall world has no BranchTree.")
	if tree == null:
		world.queue_free()
		await process_frame
		return
	_expect(_tree_is_interactive(tree), "The fresh reload-during-fall tree is not interactive.")
	_expect(world.request_gnaw_tree(), "The gnaw could not start for the reload-during-fall check.")
	_expect(await _wait(func() -> bool: return tree.is_cut(), 20.0), "The tree never started its authored fall for the reload check.")
	# 0.3 s into the 1.0 s fall: the cut is running but its single save has not
	# been written yet, so reloading here exercises the interrupted fall.
	await create_timer(0.3).timeout
	var mid_cut := DamSave.load_state(RELOAD_FALL_DIRECTORY)
	_expect(not _has_legacy_tree_cut(mid_cut["state"]), "The cut was saved before the authored fall finished (cut-tree ID present 0.3 s into the fall).")
	var branch := _branch_by_id(world)
	_expect(branch != null and not branch.visible, "The tree branch became visible during the authored fall.")
	var branch_layer: int = branch.hit_area.collision_layer if branch != null and branch.hit_area != null else -1
	_expect(branch_layer == 0, "The tree branch became collectable on layer %d during the authored fall." % branch_layer)
	world.queue_free()
	await process_frame
	var reloaded := _spawn_world(RELOAD_FALL_DIRECTORY)
	_expect(await _wait(func() -> bool: return reloaded.actor != null and reloaded.actor.is_on_floor(), 8.0), "The reloaded interrupted-fall world did not ground the actor.")
	var restored_tree := _find_tree(reloaded)
	_expect(restored_tree != null and not restored_tree.is_cut(), "Reloading during the fall did not restore the tree standing.")
	_expect(restored_tree != null and _tree_is_interactive(restored_tree), "Reloading during the fall left the restored tree non-interactive.")
	var ring := _tree_ring_node(restored_tree)
	_expect(ring != null and ring.is_visible_in_tree(), "Reloading during the fall lost the standing tree ground ring.")
	var hit_area := _tree_hit_area(restored_tree)
	_expect(hit_area != null and hit_area.collision_layer == BranchTree.TREE_LAYER, "Reloading during the fall left the tree hit area on layer %d instead of %d." % [hit_area.collision_layer if hit_area != null else -1, BranchTree.TREE_LAYER])
	var restored_branch := _branch_by_id(reloaded)
	_expect(restored_branch != null and not restored_branch.visible, "Reloading during the fall exposed the tree branch.")
	var restored_layer: int = restored_branch.hit_area.collision_layer if restored_branch != null and restored_branch.hit_area != null else -1
	_expect(restored_layer == 0, "Reloading during the fall left the tree branch collectable on layer %d." % restored_layer)
	var saved := DamSave.load_state(RELOAD_FALL_DIRECTORY)
	_expect(not _has_legacy_tree_cut(saved["state"]), "Reloading during the fall still recorded a cut-tree ID.")
	_expect(saved["state"]["placed_materials"].count(BRANCH_ID) == 0, "Reloading during the fall saved %s as placed." % BRANCH_ID)
	reloaded.queue_free()
	await process_frame
	_expect(DamSave.clear_save(RELOAD_FALL_DIRECTORY), "Could not clean the reload-during-fall directory.")


## C: a completed dam that never cut the tree activates the home stage. The
## standing tree must be fully gated then, and a tap on its screen position must
## not become a home-slot interaction even with a home part in the paws.
func _check_home_stage_gating() -> void:
	_expect(DamSave.clear_save(HOME_GATE_DIRECTORY), "Could not clear the home-gate directory.")
	_expect(_write_completed_dam_tree_standing(HOME_GATE_DIRECTORY), "Could not write the completed-dam home-gate fixture.")
	var world := _spawn_world(HOME_GATE_DIRECTORY)
	_expect(await _wait(func() -> bool: return world.actor != null and world.actor.is_on_floor(), 8.0), "The home-gate world did not ground the actor.")
	var tree := _find_tree(world)
	_expect(tree != null, "The home-gate world has no BranchTree.")
	if tree == null:
		world.queue_free()
		await process_frame
		return
	_expect(not tree.is_cut(), "The completed-dam home-gate fixture unexpectedly cut the tree.")
	_expect(world.home_stage.is_active, "The completed-dam home-gate fixture did not activate the home stage.")
	_expect(not _tree_is_interactive(tree), "The standing tree stayed interactive in the home stage.")
	var ring := _tree_ring_node(tree)
	_expect(ring != null and not ring.is_visible_in_tree(), "The standing tree showed its ground ring in the home stage.")
	var hit_area := _tree_hit_area(tree)
	_expect(hit_area != null and hit_area.collision_layer == 0, "The standing tree kept its hit area on layer %d in the home stage." % [hit_area.collision_layer if hit_area != null else -1])
	var part = world.home_stage.parts[0]
	_expect(world.home_stage.request_collect(part), "The home-gate fixture could not collect a home part.")
	_expect(await _wait(func() -> bool: return world.home_stage.carried_part == part, 20.0), "The home-gate fixture could not carry the home part.")
	var placed_before: int = world.home_stage.placed_slot_count
	var screen := _tree_screen(world, tree)
	world._move_from_screen(screen)
	await physics_frame
	_expect(world.home_stage.pending_slot == -1, "Tapping the standing tree in the home stage started home slot %d." % world.home_stage.pending_slot)
	_expect(world.home_stage.placed_slot_count == placed_before, "Tapping the standing tree in the home stage placed a home part.")
	_expect(world.home_stage.carried_part == part, "Tapping the standing tree in the home stage returned the carried home part.")
	_expect(not tree.is_cut() and not _world_tree_pending(world), "Tapping the standing tree in the home stage started a gnaw.")
	var hidden_branch := _branch_by_id(world)
	_expect(hidden_branch != null and not hidden_branch.visible, "Tapping the standing tree in the home stage exposed its hidden branch.")
	world.queue_free()
	await process_frame
	_expect(DamSave.clear_save(HOME_GATE_DIRECTORY), "Could not clean the home-gate directory.")


## G: the same completed-dam fixture without a carried part must still leave the
## uncut tree non-interactive with its quiet ring hidden.
func _check_interaction_gate() -> void:
	_expect(DamSave.clear_save(INTERACTION_GATE_DIRECTORY), "Could not clear the interaction-gate directory.")
	_expect(_write_completed_dam_tree_standing(INTERACTION_GATE_DIRECTORY), "Could not write the completed-dam interaction-gate fixture.")
	var world := _spawn_world(INTERACTION_GATE_DIRECTORY)
	_expect(await _wait(func() -> bool: return world.actor != null and world.actor.is_on_floor(), 8.0), "The interaction-gate world did not ground the actor.")
	var tree := _find_tree(world)
	_expect(tree != null and not tree.is_cut(), "The interaction-gate fixture did not restore the standing tree.")
	_expect(world.home_stage.is_active, "The interaction-gate fixture did not activate the home stage.")
	_expect(not _tree_is_interactive(tree), "The completed dam left the uncut tree interactive in the home stage.")
	var ring := _tree_ring_node(tree)
	_expect(ring != null and not ring.is_visible_in_tree(), "The completed dam left the uncut tree ground ring visible.")
	var hit_area := _tree_hit_area(tree)
	_expect(hit_area != null and hit_area.collision_layer == 0, "The completed dam left the uncut tree hit area on layer %d." % [hit_area.collision_layer if hit_area != null else -1])
	var branch := _branch_by_id(world)
	_expect(branch != null and not branch.visible, "The completed dam exposed the tree branch while the tree stands.")
	world.queue_free()
	await process_frame
	_expect(DamSave.clear_save(INTERACTION_GATE_DIRECTORY), "Could not clean the interaction-gate directory.")


## One authored completed dam that never placed branch_normal_03, so the tree
## stays standing. The thick branch is already gnawed and both normal branches
## are in the dam, which is the supported completion without the tree.
func _write_completed_dam_tree_standing(directory: String) -> bool:
	var state := DamSave.empty_state(DamSave.LEGACY_RECIPE_ID)
	state["placed_materials"] = ["branch_thick_01", "branch_normal_01", "branch_normal_02"]
	state["placements"] = [
		{"material_id": "branch_thick_01", "slot_index": 0, "zone": "dam_fill"},
		{"material_id": "branch_normal_01", "slot_index": 1, "zone": "dam_fill"},
		{"material_id": "branch_normal_02", "slot_index": 2, "zone": "dam_fill"},
	]
	state["solved_obstacles"] = ["branch_thick_01"]
	state["gnawed_materials"] = ["branch_thick_01"]
	state["finish_choice"] = "finish_moss"
	state["stage_completed"] = true
	state["home_slots"] = ["", ""]
	state["food_placements"] = []
	state["cut_tree_ids"] = []
	_expect(DamSave.validate_state(state), "The completed-dam tree-standing fixture is not a valid schema 4 state.")
	if not DamSave.validate_state(state):
		return false
	return DamSave.save_state(state, directory)



## The tree branch is an ordinary dam material: it advances the count once and
## the normal save keeps both the placed material and the cut tree.
func _check_tree_branch_as_dam_material() -> void:
	_expect(DamSave.clear_save(DAM_DIRECTORY), "Could not clear the tree-branch dam directory.")
	var world := _spawn_world(DAM_DIRECTORY)
	_expect(await _wait(func() -> bool: return world.actor != null and world.actor.is_on_floor(), 8.0), "The dam-material world did not ground the actor.")
	var observed: Dictionary = await _cut_tree_through_request(world)
	_expect(bool(observed["cut"]), "The tree did not supply a branch for the dam.")
	var branch := _branch_by_id(world)
	_expect(branch != null and world.request_collect(branch), "The supplied tree branch could not be collected for the dam.")
	_expect(await _wait(func() -> bool: return branch != null and world.carried_branch == branch, 15.0), "The supplied tree branch was not carried to the dam.")
	_expect(world.request_place(), "The carried tree branch could not be routed to the dam.")
	_expect(await _wait(func() -> bool: return world.placed_count == 1, 20.0), "The tree branch did not advance the dam count.")
	_expect(await _wait(func() -> bool: return is_equal_approx(world.water_level, world.terrain.intermediate_water_level()), 8.0), "Using the tree branch did not raise the lake to the one-branch level.")
	var saved := DamSave.load_state(DAM_DIRECTORY)
	_expect(saved["source"] == "primary", "Using the tree branch did not save normally.")
	_expect(int(saved["state"]["schema_version"]) == 4, "The normal save is not schema 4.")
	_expect(_has_legacy_tree_cut(saved["state"]) and saved["state"]["placed_materials"] == [BRANCH_ID], "The normal save did not keep the cut tree and its single placed branch.")
	world.queue_free()
	await process_frame
	_expect(DamSave.clear_save(DAM_DIRECTORY), "Could not clean the tree-branch dam directory.")


## Requests the gnaw through the public action and observes the walk, the gnaw
## action and the finished cut without pixel input.
func _cut_tree_through_request(world: Node) -> Dictionary:
	var observed := {"requested": false, "walked": false, "gnaw": false, "cut": false, "fall_started_frame": -1, "fall_done_frame": -1}
	var tree := _find_tree(world)
	if tree == null:
		return observed
	observed["requested"] = world.request_gnaw_tree()
	return await _observe_tree_cut(world, tree, observed)


func _spawn_world(directory: String) -> Node:
	if not FileAccess.file_exists(directory.path_join(DamSave.SAVE_FILE)):
		_expect(DamSave.save_state(DamSave.empty_state(DamSave.LEGACY_RECIPE_ID), directory), "Could not seed the tree test with an explicit legacy recipe.")
	var world: Node = load(SCENE_PATH).instantiate()
	world.save_directory = directory
	root.add_child(world)
	return world


func _has_legacy_tree_cut(state: Dictionary) -> bool:
	return state.get("cut_tree_ids", []).has(DamSave.LEGACY_TREE_ID)


func _find_tree(world: Node) -> BranchTree:
	for node in world.find_children("*", "", true, false):
		if node is BranchTree:
			return node as BranchTree
	return null


## The durable cut flag belongs to the save. When the world also mirrors it as a
## public tree_cut member, verify the mirror without requiring the internal name.
func _expect_world_tree_cut(world: Node, expected: bool, context: String) -> void:
	var mirrored: Variant = world.get("tree_cut")
	if mirrored == null:
		return
	_expect(bool(mirrored) == expected, "%s: the world tree_cut mirror is not %s." % [context, str(expected)])


## TREE_XZ and TREE_LANDING_XZ are authored by the layout and exposed as
## accessors. Accepting the chapter itself as a host keeps the check focused on
## the point rather than on which node owns the accessor.
func _tree_xz(world: Node) -> Vector2:
	for host in [world.layout, world]:
		if host != null and host.has_method("tree_xz"):
			var point: Vector2 = host.tree_xz()
			return point
	_expect(false, "The chapter exposes no tree_xz() accessor for TREE_XZ.")
	return Vector2(INF, INF)


func _tree_landing_xz(world: Node) -> Vector2:
	for host in [world.layout, world]:
		if host != null and host.has_method("tree_landing_xz"):
			var point: Vector2 = host.tree_landing_xz()
			return point
	_expect(false, "The chapter exposes no tree_landing_xz() accessor for TREE_LANDING_XZ.")
	return Vector2(INF, INF)


func _tree_work_xz(world: Node) -> Vector2:
	for host in [world.layout, world]:
		if host != null and host.has_method("tree_work_xz"):
			var point: Vector2 = host.tree_work_xz()
			return point
	_expect(false, "The chapter exposes no tree_work_xz() accessor for TREE_WORK_XZ.")
	return Vector2(INF, INF)


## Finds the authored hit area by name first, because a gated tree keeps the
## area but sets its collision layer to zero. The layer fallback keeps the helper
## usable on a fresh world.
func _tree_hit_area(tree: Node) -> Area3D:
	if tree == null:
		return null
	var named := tree.find_child("TreeHitArea", true, false) as Area3D
	if named != null:
		return named
	for node in tree.find_children("*", "Area3D", true, false):
		var area := node as Area3D
		if (area.collision_layer & BranchTree.TREE_LAYER) != 0:
			return area
	return null


## The tree's quiet ground ring is a torus like every other authored ring in the
## chapter; a named ring or cue is accepted as a fallback for a custom mesh.
func _tree_ground_ring(tree: Node) -> MeshInstance3D:
	for node in tree.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.visible and mesh_instance.mesh is TorusMesh:
			return mesh_instance
	for node in tree.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if not mesh_instance.visible:
			continue
		var node_name := String(mesh_instance.name).to_lower()
		if node_name.contains("ring") or node_name.contains("cue"):
			return mesh_instance
	return null


## The gated ring is hidden, so the fallback accepts an invisible named torus.
func _tree_ring_node(tree: Node) -> MeshInstance3D:
	if tree == null:
		return null
	var named := tree.find_child("TreeGroundRing", true, false) as MeshInstance3D
	if named != null:
		return named
	for node in tree.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh is TorusMesh:
			return mesh_instance
	return null


## The contract accessors are called dynamically so a missing implementation
## reports a focused assertion instead of aborting the whole script at parse time.
func _tree_is_interactive(tree: BranchTree) -> bool:
	if tree == null or not tree.has_method("is_interactive"):
		return false
	return bool(tree.call("is_interactive"))


func _tree_fall_angle(tree: BranchTree) -> float:
	if tree == null or not tree.has_method("fall_angle_degrees"):
		return NAN
	return float(tree.call("fall_angle_degrees"))


## The pending flag is private interaction state; a world that renames it must
## fail the tap-path assertion rather than silently pass.
func _world_tree_pending(world: Node) -> bool:
	if world == null:
		return false
	var value: Variant = world.get("_tree_pending")
	if value == null:
		return false
	return bool(value)


## Puts the camera back at the authored play camera and projects the readable
## upper trunk, which is the same target a child sees and taps.
func _tree_screen(world: Node, tree: BranchTree) -> Vector2:
	world.camera.position = MovementWorldScript.CAMERA_POSITION
	world.camera.look_at(MovementWorldScript.CAMERA_TARGET)
	world.camera.current = true
	return world.camera.unproject_position(tree.global_position + Vector3.UP * 0.8)


func _other_branch_spots(world: Node) -> Array[Vector2]:
	var spots: Array[Vector2] = []
	for branch in world.branches:
		if branch == null or branch == world.tree_branch:
			continue
		spots.append(_flat(branch.global_position))
	return spots


func _nearest_gap(point: Vector2, spots: Array[Vector2]) -> float:
	var nearest := INF
	for spot in spots:
		nearest = minf(nearest, point.distance_to(spot))
	return nearest


func _cue_for(world: Node, branch: Node) -> Node:
	var index: int = world.branches.find(branch)
	if index < 0 or index >= world.branch_cues.size():
		return null
	return world.branch_cues[index]


func _branch_by_id(world: Node) -> CollectibleBranch:
	for branch in world.branches:
		if branch != null and branch.stable_id == BRANCH_ID:
			return branch as CollectibleBranch
	return null


func _branch_instance_count(world: Node) -> int:
	var count := 0
	for node in world.find_children("*", "", true, false):
		if node is CollectibleBranch and (node as CollectibleBranch).stable_id == BRANCH_ID:
			count += 1
	return count


func _free_branch_count(world: Node) -> int:
	var count := 0
	for node in world.find_children("*", "", true, false):
		if node is CollectibleBranch:
			var branch := node as CollectibleBranch
			if branch.stable_id == BRANCH_ID and branch.state == CollectibleBranch.State.FREE:
				count += 1
	return count


## One landed branch must be visible, free, collectable, at the landing and
## cued as a pickup. Used after the gnaw, a reload and a failed save.
func _expect_branch_available(world: Node, branch: CollectibleBranch, context: String) -> void:
	_expect(branch != null, "%s: the tree branch is missing." % context)
	if branch == null:
		return
	_expect(branch.visible, "%s: the tree branch is not visible at its landing." % context)
	var layer: int = branch.hit_area.collision_layer if branch.hit_area != null else -1
	_expect(branch.hit_area != null and layer == BRANCH_LAYER, "%s: the tree branch is not collectable on layer %d." % [context, BRANCH_LAYER])
	_expect(branch.state == CollectibleBranch.State.FREE, "%s: the tree branch is not free." % context)
	_expect(branch.get_parent() == world, "%s: the tree branch is not parented to the world." % context)
	var landing := _tree_landing_xz(world)
	var gap := _flat(branch.global_position).distance_to(landing)
	_expect(gap <= LANDING_TOLERANCE, "%s: the tree branch is %.2f m from TREE_LANDING_XZ." % [context, gap])
	var cue := _cue_for(world, branch)
	_expect(cue != null and cue.visible, "%s: the revealed tree branch has no pickup cue." % context)


func _tree_transforms(tree: Node) -> Dictionary:
	var transforms := {}
	var root_3d := tree as Node3D
	if root_3d != null:
		transforms["."] = root_3d.transform
	for node in tree.find_children("*", "Node3D", true, false):
		var node_3d := node as Node3D
		if node_3d != null:
			transforms[String(tree.get_path_to(node_3d))] = node_3d.transform
	return transforms


func _tree_transforms_match(before: Dictionary, after: Dictionary) -> bool:
	if before.size() != after.size():
		return false
	for path in before:
		if not after.has(path):
			return false
		var first: Transform3D = before[path]
		var second: Transform3D = after[path]
		if not first.is_equal_approx(second):
			return false
	return true


func _flat(point: Vector3) -> Vector2:
	return Vector2(point.x, point.z)


## World-space bounds of every visible mesh under a node. Used for the felled
## trunk/crown instead of the node origin, which carries no size information.
func _node_world_aabb(node: Node3D) -> AABB:
	var combined := AABB()
	var first := true
	var meshes: Array[MeshInstance3D] = []
	if node is MeshInstance3D:
		meshes.append(node as MeshInstance3D)
	for child in node.find_children("*", "MeshInstance3D", true, false):
		meshes.append(child as MeshInstance3D)
	for mesh_instance in meshes:
		if mesh_instance == null or not mesh_instance.is_visible_in_tree() or mesh_instance.mesh == null:
			continue
		var box: AABB = mesh_instance.global_transform * mesh_instance.get_aabb()
		if first:
			combined = box
			first = false
		else:
			combined = combined.merge(box)
	return combined


## Visible meshes that are not the ring, a gnaw scar or the stump. The felled
## trunk and crown are the remaining authored pieces.
func _visible_tree_meshes(tree: Node3D) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	for node in tree.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance == null or not mesh_instance.is_visible_in_tree() or mesh_instance.mesh == null:
			continue
		var lower := String(mesh_instance.name).to_lower()
		if lower.contains("ring") or lower.contains("scar") or lower.contains("gnaw") or lower.contains("stump"):
			continue
		result.append(mesh_instance)
	return result


func _named_mesh(tree: Node, node_name: String) -> MeshInstance3D:
	var found := tree.find_child(node_name, true, false)
	return found as MeshInstance3D


## Prefer authored names; fall back to the visible non-stump geometry so a
## differently named trunk/crown pair is still measured.
func _fallen_part(tree: Node3D, keywords: Array) -> Node3D:
	for node in tree.find_children("*", "Node3D", true, false):
		var node_3d := node as Node3D
		if node_3d == null or not node_3d.is_visible_in_tree():
			continue
		var lower := String(node_3d.name).to_lower()
		if lower.contains("stump") or lower.contains("ring") or lower.contains("scar") or lower.contains("gnaw") or lower.contains("hit"):
			continue
		for keyword: String in keywords:
			if lower.contains(keyword):
				var box := _node_world_aabb(node_3d)
				if box.size != Vector3.ZERO:
					return node_3d
	return null


func _fallback_fallen_parts(tree: Node3D) -> Array[Node3D]:
	var result: Array[Node3D] = []
	var meshes := _visible_tree_meshes(tree)
	if meshes.size() < 2:
		return result
	var trunk: MeshInstance3D = null
	var trunk_extent := -1.0
	for mesh_instance in meshes:
		var box: AABB = mesh_instance.global_transform * mesh_instance.get_aabb()
		var extent := maxf(box.size.x, box.size.z)
		if extent > trunk_extent:
			trunk_extent = extent
			trunk = mesh_instance
	var crown: MeshInstance3D = null
	var crown_extent := -1.0
	for mesh_instance in meshes:
		if mesh_instance == trunk:
			continue
		var box: AABB = mesh_instance.global_transform * mesh_instance.get_aabb()
		if box.size.y > crown_extent:
			crown_extent = box.size.y
			crown = mesh_instance
	if trunk != null and crown != null:
		result.append(trunk)
		result.append(crown)
	return result


## Lowest mesh point against the terrain directly under the piece's centre.
func _aabb_bottom_clearance(world: Node, box: AABB) -> float:
	var center := box.get_center()
	return box.position.y - world.terrain.height_at(Vector2(center.x, center.z))


## How far the crown's far edge stays before TREE_LANDING_XZ along the authored
## fall direction. Negative means the crown reached or passed the landing.
func _crown_landing_margin(world: Node, box: AABB) -> float:
	var tree_xz := _tree_xz(world)
	var landing_xz := _tree_landing_xz(world)
	var direction := landing_xz - tree_xz
	if direction.length_squared() < 0.000001:
		return -INF
	direction = direction.normalized()
	var landing_projection := landing_xz.dot(direction)
	var far_edge := -INF
	for x in [box.position.x, box.end.x]:
		for z in [box.position.z, box.end.z]:
			far_edge = maxf(far_edge, Vector2(x, z).dot(direction))
	return landing_projection - far_edge


func _v1_state(placed: Array, completed: bool, finish: String) -> Dictionary:
	return {
		"schema_version": 1,
		"stage_id": "dam_valley",
		"placed_materials": placed,
		"solved_obstacles": [],
		"gnawed_materials": [],
		"bent_materials": [],
		"finish_choice": finish,
		"stage_completed": completed,
	}


func _v2_state(placed: Array, completed: bool, finish: String, home_slots: Array, food_placements: Array) -> Dictionary:
	return {
		"schema_version": 2,
		"stage_id": "dam_valley",
		"placed_materials": placed,
		"solved_obstacles": [],
		"gnawed_materials": [],
		"bent_materials": [],
		"finish_choice": finish,
		"stage_completed": completed,
		"home_slots": home_slots,
		"food_placements": food_placements,
	}


func _write_json(directory: String, state: Dictionary) -> bool:
	var error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	if error != OK and error != ERR_ALREADY_EXISTS:
		return false
	var file := FileAccess.open(directory.path_join(DamSave.SAVE_FILE), FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(state))
	file.flush()
	var write_error: Error = file.get_error()
	file.close()
	return write_error == OK


func _read_json(directory: String) -> Dictionary:
	var path := directory.path_join(DamSave.SAVE_FILE)
	if not FileAccess.file_exists(path):
		return {}
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK or not parser.data is Dictionary:
		return {}
	return parser.data


func _read_text(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	return FileAccess.get_file_as_string(path)
