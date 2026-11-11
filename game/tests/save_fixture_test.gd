extends SceneTree
## R5 save fixtures: schema 1, schema 2 and schema 3 saves for every chapter
## stage must restore on the new terrain without rewriting the file or resetting
## progress. Schema 3 covers the durable tree cut; schema 4 carries stable
## placements and cut-tree IDs for legacy and mixed recipes.

const DamSave = preload("res://scripts/dam_save.gd")
const CollectibleBranchScript = preload("res://scripts/collectible_branch.gd")
const SCENE_PATH := "res://scenes/movement.tscn"
const FIXTURE_DIRECTORY := "user://r5_save_fixtures/"
const MIXED_FIXTURE_DIRECTORY := "user://mixed_save_fixture/"
var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _expect(condition: bool, description: String) -> void:
	if not condition:
		failures += 1
		push_error(description)


func _wait_for(condition: Callable, timeout_seconds: float = 5.0) -> bool:
	var deadline := Time.get_ticks_msec() + int(timeout_seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		await physics_frame
		if condition.call():
			return true
	return condition.call()


func _run() -> void:
	_expect(DamSave.clear_save(FIXTURE_DIRECTORY), "Could not clear the R5 fixture directory.")
	root.size = Vector2i(960, 600)

	# Schema 1 only carries the dam. It must migrate in memory (adding the home,
	# food and tree keys) and still restore without rewriting the file.
	await _check_fixture(
		"v1_partial_dam",
		_v1_state(["branch_normal_01"], false, ""),
		1, false, 0, false, 0, false, ""
	)
	await _check_fixture(
		"v1_completed_dam_golden",
		_v1_state(["branch_normal_01", "branch_normal_02", "branch_normal_03"], true, "finish_golden"),
		3, true, 0, false, 0, false, "finish_golden"
	)
	await _check_fixture(
		"v1_completed_dam_moss",
		_v1_state(["branch_normal_01", "branch_normal_02", "branch_normal_03"], true, "finish_moss"),
		3, true, 0, false, 0, false, "finish_moss"
	)

	# Schema 2 covers every later stage and must migrate to schema 4 with a
	# standing tree.
	await _check_fixture(
		"v2_partial_dam",
		_v2_state(["branch_normal_01"], false, "", ["", ""], []),
		1, false, 0, false, 0, false, ""
	)
	await _check_fixture(
		"v2_completed_dam_golden",
		_v2_state(["branch_normal_01", "branch_normal_02", "branch_normal_03"], true, "finish_golden", ["", ""], []),
		3, true, 0, false, 0, false, "finish_golden"
	)
	await _check_fixture(
		"v2_completed_dam_moss",
		_v2_state(["branch_normal_01", "branch_normal_02", "branch_normal_03"], true, "finish_moss", ["", ""], []),
		3, true, 0, false, 0, false, "finish_moss"
	)
	await _check_fixture(
		"v2_partial_home",
		_v2_state(["branch_normal_01", "branch_normal_02", "branch_normal_03"], true, "finish_moss", ["home_part_rounded", ""], []),
		3, true, 1, false, 0, false, "finish_moss",
		"home_part_rounded", []
	)
	await _check_fixture(
		"v2_partial_food",
		_v2_state(["branch_normal_01", "branch_normal_02", "branch_normal_03"], true, "finish_moss", ["home_part_rounded", "home_part_plank"], ["food_bundle_01"]),
		3, true, 2, true, 1, false, "finish_moss",
		"", ["food_bundle_01"]
	)
	await _check_fixture(
		"v2_completed_winter",
		_v2_state(["branch_normal_01", "branch_normal_02", "branch_normal_03"], true, "finish_moss", ["home_part_rounded", "home_part_plank"], ["food_bundle_01", "food_bundle_03", "food_bundle_04"]),
		3, true, 2, true, 3, true, "finish_moss",
		"", ["food_bundle_01", "food_bundle_03", "food_bundle_04"]
	)

	# Schema 3 persists the tree cut. The standing tree keeps its branch hidden;
	# the cut tree reveals it at the landing or restores it in the dam.
	await _check_fixture(
		"v3_partial_dam_standing",
		_v3_state(["branch_normal_01"], false, "", ["", ""], [], false),
		1, false, 0, false, 0, false, ""
	)
	await _check_fixture(
		"v3_partial_dam_cut",
		_v3_state(["branch_normal_01"], false, "", ["", ""], [], true),
		1, false, 0, false, 0, false, "",
		"", [], true
	)
	await _check_fixture(
		"v3_completed_dam_cut",
		_v3_state(["branch_normal_01", "branch_normal_02", "branch_normal_03"], true, "finish_golden", ["", ""], [], true),
		3, true, 0, false, 0, false, "finish_golden",
		"", [], true
	)
	# The dam can also be completed without the tree branch. The tree then stays
	# standing and the hidden branch must not become a duplicate pickup.
	await _check_fixture(
		"v3_completed_dam_tree_standing",
		_v3_state(["branch_thick_01", "branch_normal_01", "branch_normal_02"], true, "finish_moss", ["", ""], [], false, ["branch_thick_01"]),
		3, true, 0, false, 0, false, "finish_moss"
	)
	await _check_fixture(
		"v3_partial_home_cut",
		_v3_state(["branch_normal_01", "branch_normal_02", "branch_normal_03"], true, "finish_moss", ["home_part_rounded", ""], [], true),
		3, true, 1, false, 0, false, "finish_moss",
		"home_part_rounded", [], true
	)
	await _check_fixture(
		"v3_completed_winter_cut",
		_v3_state(["branch_normal_01", "branch_normal_02", "branch_normal_03"], true, "finish_moss", ["home_part_rounded", "home_part_plank"], ["food_bundle_01", "food_bundle_03", "food_bundle_04"], true),
		3, true, 2, true, 3, true, "finish_moss",
		"", ["food_bundle_01", "food_bundle_03", "food_bundle_04"], true
	)
	await _check_mixed_persistence_fixture()

	_expect(DamSave.clear_save(FIXTURE_DIRECTORY), "Could not clean the R5 fixture directory.")
	if failures == 0:
		print("CASTOR_SAVE_FIXTURES_OK schema1 schema2 schema3 schema4 partial_dam tree_standing tree_cut mixed_partial five_cut_trees finishes partial_home partial_food winter safe_spawn unchanged_files")
	quit(0 if failures == 0 else 1)


func _check_fixture(
	fixture_name: String,
	state: Dictionary,
	expected_placed: int,
	expected_home_active: bool,
	expected_home_slots: int,
	expected_food_active: bool,
	expected_food_count: int,
	expected_winter: bool,
	expected_finish: String,
	expected_home_part: String = "",
	expected_food_ids: Array = [],
	expected_tree_cut: bool = false
) -> void:
	var directory := FIXTURE_DIRECTORY.path_join(fixture_name)
	_expect(DamSave.clear_save(directory), "Could not clear fixture %s." % fixture_name)
	var schema_version := int(state["schema_version"])
	if schema_version == DamSave.SCHEMA_VERSION:
		_expect(DamSave.save_state(state, directory), "Could not write schema 4 fixture %s." % fixture_name)
	else:
		_expect(_write_json(directory, state), "Could not write schema %d fixture %s." % [schema_version, fixture_name])
	var save_path := directory.path_join(DamSave.SAVE_FILE)
	var before := _read_text(save_path)
	_expect(not before.is_empty(), "Fixture %s produced no save file." % fixture_name)

	var world: Node = load(SCENE_PATH).instantiate()
	world.save_directory = directory
	root.add_child(world)
	var ready: bool = await _wait_for(func() -> bool: return world.actor != null and world.actor.is_on_floor())
	_expect(ready, "Fixture %s did not spawn a grounded actor." % fixture_name)
	if not ready:
		world.queue_free()
		await process_frame
		return
	var xz := Vector2(world.actor.global_position.x, world.actor.global_position.z)
	_expect(absf(world.actor.global_position.y - world.terrain.height_at(xz)) <= 0.15, "Fixture %s spawned above or below the terrain." % fixture_name)
	_expect(not world.terrain.is_water_footprint(xz), "Fixture %s spawned in the lake footprint." % fixture_name)
	_expect(world.placed_count == expected_placed, "Fixture %s restored %d placed branches instead of %d." % [fixture_name, world.placed_count, expected_placed])
	_expect(world.carried_branch == null and world.pending_branch == null, "Fixture %s restored transient carried or reserved branch state." % fixture_name)
	var expected_level: float = world.terrain.initial_water_level()
	if expected_placed == 1:
		expected_level = world.terrain.intermediate_water_level()
	elif expected_placed >= 2:
		expected_level = world.terrain.full_water_level()
	_expect(world.visual_environment.get_visible_dam_log_count() == expected_placed, "Fixture %s restored %d visible dam logs instead of %d." % [fixture_name, world.visual_environment.get_visible_dam_log_count(), expected_placed])
	_expect(is_equal_approx(world.water_level, expected_level), "Fixture %s restored the wrong immediate water level." % fixture_name)
	_expect(not world.stage_completion.visible, "Fixture %s replayed a transient completion message." % fixture_name)
	_expect(world.home_stage.is_active == expected_home_active, "Fixture %s home-stage activation is wrong." % fixture_name)
	_expect(world.home_stage.placed_slot_count == expected_home_slots, "Fixture %s restored %d home slots instead of %d." % [fixture_name, world.home_stage.placed_slot_count, expected_home_slots])
	_expect(world.food_stage.is_active == expected_food_active, "Fixture %s food-stage activation is wrong." % fixture_name)
	_expect(world.food_stage.placed_count == expected_food_count, "Fixture %s restored %d food bundles instead of %d." % [fixture_name, world.food_stage.placed_count, expected_food_count])
	_expect(world.winter_active == expected_winter, "Fixture %s winter activation is wrong." % fixture_name)
	if not expected_finish.is_empty():
		_expect(world.finish_choice == expected_finish, "Fixture %s did not restore its finish choice." % fixture_name)
		_expect(world.finish_trim.visible, "Fixture %s did not show its finish trim." % fixture_name)
	else:
		_expect(not world.finish_trim.visible, "Fixture %s showed a finish trim without a choice." % fixture_name)
	if not expected_home_part.is_empty() and expected_home_slots > 0:
		var part = world.home_stage.part_at_slot(0)
		_expect(part != null and part.stable_id == expected_home_part, "Fixture %s restored the wrong home part." % fixture_name)
	if not expected_food_ids.is_empty():
		_expect(world.food_stage.get_placed_bundle_ids() == expected_food_ids, "Fixture %s restored the wrong food bundle IDs." % fixture_name)
	if expected_winter:
		_expect(world.winter_scene.is_winter and world.winter_scene.visible, "Fixture %s did not restore the winter scene." % fixture_name)
		_expect(not world.ending_overlay.visible, "Fixture %s replayed the ending overlay." % fixture_name)
		_expect(world.winter_new_adventure_button.visible, "Fixture %s lost the protected new-adventure action." % fixture_name)
		_expect(world.winter_scene.get_family_count() >= 2, "Fixture %s lost the beaver family." % fixture_name)
	else:
		_expect(not world.winter_scene.visible, "Fixture %s showed winter before the food store was complete." % fixture_name)

	# E2: branch_normal_03 only exists at the landing once the tree is cut. A
	# save that already placed it also proves the tree must stay cut.
	var placed_materials: Array = state["placed_materials"]
	var branch_is_placed: bool = placed_materials.has("branch_normal_03")
	var expected_effective_cut: bool = expected_tree_cut or branch_is_placed
	_expect(world.tree_cut == expected_effective_cut, "Fixture %s restored tree_cut=%s instead of %s." % [fixture_name, str(world.tree_cut), str(expected_effective_cut)])
	_expect(world.branch_tree != null and world.branch_tree.is_cut() == expected_effective_cut, "Fixture %s restored the wrong tree presentation state." % fixture_name)
	var landing: Vector3 = world.layout.tree_point(world.layout.tree_landing_xz()) + Vector3.UP * 0.02
	if branch_is_placed:
		_expect(world.tree_branch.state == CollectibleBranchScript.State.PLACED, "Fixture %s did not restore the tree branch in the dam." % fixture_name)
		_expect(world.tree_branch.position.distance_to(landing) > 1.0, "Fixture %s left a second tree branch at the landing." % fixture_name)
	else:
		_expect(world.tree_branch.state == CollectibleBranchScript.State.FREE, "Fixture %s did not restore the tree branch as free." % fixture_name)
		_expect(world.tree_branch.position.distance_to(landing) <= 0.001, "Fixture %s did not restore the tree branch at the landing." % fixture_name)
		if expected_effective_cut:
			_expect(world.tree_branch.visible and world.tree_branch.hit_area.collision_layer == 4, "Fixture %s hid the branch revealed by the cut tree." % fixture_name)
		else:
			_expect(not world.tree_branch.visible and world.tree_branch.hit_area.collision_layer == 0, "Fixture %s exposed the tree branch while the tree stands." % fixture_name)
	var tree_branch_index: int = world.branches.find(world.tree_branch)
	var tree_cue_visible: bool = tree_branch_index >= 0 and world.branch_cues[tree_branch_index].visible
	if expected_effective_cut and not branch_is_placed and not expected_home_active:
		_expect(tree_cue_visible, "Fixture %s did not show the revealed tree branch cue." % fixture_name)
	else:
		_expect(not tree_cue_visible, "Fixture %s showed a tree branch cue while it was not available." % fixture_name)
	if expected_home_active:
		_expect(world.branch_cues.all(func(cue: MeshInstance3D) -> bool: return not cue.visible), "Fixture %s left branch cues over the home stage." % fixture_name)
		if expected_home_slots == 2:
			_expect(world.home_stage.is_complete(), "Fixture %s did not restore a complete home." % fixture_name)

	var after := _read_text(save_path)
	_expect(before == after, "Fixture %s rewrote its save file during restore." % fixture_name)
	if schema_version < DamSave.SCHEMA_VERSION:
		var parsed := JSON.parse_string(after) as Dictionary
		_expect(parsed != null and int(parsed["schema_version"]) == schema_version, "Fixture %s changed the schema on disk." % fixture_name)
		var loaded: Dictionary = DamSave.load_state(directory)["state"]
		_expect(int(loaded["schema_version"]) == DamSave.SCHEMA_VERSION, "Fixture %s was not migrated in memory." % fixture_name)
		_expect(loaded["recipe_id"] == DamSave.LEGACY_RECIPE_ID, "Fixture %s did not retain the legacy recipe." % fixture_name)
		if schema_version == DamSave.LEGACY_SCHEMA_VERSION:
			_expect(loaded["home_slots"] == ["", ""] and loaded["food_placements"].is_empty(), "Fixture %s migration did not add the empty chapter placements." % fixture_name)
		var expected_cut_ids: Array = [DamSave.LEGACY_TREE_ID] if expected_effective_cut else []
		_expect(loaded["cut_tree_ids"] == expected_cut_ids and loaded["placed_materials"] == state["placed_materials"], "Fixture %s migration did not preserve the legacy tree/source relationship and dam." % fixture_name)
	world.queue_free()
	await process_frame


func _v1_state(placed: Array, completed: bool, finish: String) -> Dictionary:
	return {
		"schema_version": DamSave.LEGACY_SCHEMA_VERSION,
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
		"schema_version": DamSave.V2_SCHEMA_VERSION,
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


func _v3_state(placed: Array, completed: bool, finish: String, home_slots: Array, food_placements: Array, tree_cut: bool, gnawed_materials: Array = []) -> Dictionary:
	return {
		"schema_version": 3,
		"stage_id": "dam_valley",
		"placed_materials": placed,
		"solved_obstacles": gnawed_materials.duplicate() if not gnawed_materials.is_empty() else [],
		"gnawed_materials": gnawed_materials,
		"bent_materials": [],
		"finish_choice": finish,
		"stage_completed": completed,
		"home_slots": home_slots,
		"food_placements": food_placements,
		"tree_cut": tree_cut,
	}


func _check_mixed_persistence_fixture() -> void:
	_expect(DamSave.clear_save(MIXED_FIXTURE_DIRECTORY), "Could not clear the mixed persistence fixture.")
	var mixed_state := DamSave.new_adventure_state()
	mixed_state["placed_materials"] = ["log_01", "stone_01"]
	mixed_state["placements"] = [
		{"material_id": "log_01", "slot_index": 5, "zone": "dam_wall"},
		{"material_id": "stone_01", "slot_index": 10, "zone": "dam_base"},
	]
	mixed_state["cut_tree_ids"] = ["tree_01", "tree_02", "tree_03", "tree_04", "tree_05"]
	_expect(DamSave.validate_state(mixed_state), "A mixed partial fixture with all five cut trees was rejected.")
	_expect(DamSave.save_state(mixed_state, MIXED_FIXTURE_DIRECTORY), "Could not write the mixed partial fixture.")
	var restored := DamSave.load_state(MIXED_FIXTURE_DIRECTORY)
	_expect(restored["source"] == "primary" and restored["state"]["recipe_id"] == "mixed_fifteen", "The mixed partial fixture did not round-trip its recipe.")
	var restored_placements: Array = restored["state"]["placements"]
	var placement_identity_matches := restored_placements.size() == 2
	if placement_identity_matches:
		for index: int in range(2):
			var expected: Dictionary = mixed_state["placements"][index]
			var actual: Dictionary = restored_placements[index]
			if expected["material_id"] != actual["material_id"] or int(expected["slot_index"]) != int(actual["slot_index"]) or expected["zone"] != actual["zone"]:
				placement_identity_matches = false
	_expect(placement_identity_matches and restored["state"]["cut_tree_ids"] == mixed_state["cut_tree_ids"], "The mixed partial fixture lost stable placements or cut-tree IDs.")
	var carried_state: Dictionary = mixed_state.duplicate(true)
	carried_state["carried_material_id"] = "branch_02"
	_expect(not DamSave.validate_state(carried_state), "Transient carried-item state was accepted into the durable save.")
	var world: Node = load(SCENE_PATH).instantiate()
	world.save_directory = MIXED_FIXTURE_DIRECTORY
	root.add_child(world)
	var ready: bool = await _wait_for(func() -> bool: return world.actor != null and world.actor.is_on_floor())
	_expect(ready, "The mixed recipe identity fixture did not initialize its world.")
	if ready:
		var saved: bool = world.call("_save_dam_state")
		_expect(saved, "Saving a mixed-recipe adventure through the world changed or rejected its recipe.")
		var world_save: Dictionary = DamSave.load_state(MIXED_FIXTURE_DIRECTORY)["state"]
		_expect(world_save["recipe_id"] == "mixed_fifteen", "An ordinary world save downgraded a new adventure to the legacy recipe.")
		var world_placements: Array = world_save["placements"]
		var world_placement_matches := world_placements.size() == 2
		if world_placement_matches:
			for index: int in range(2):
				var expected: Dictionary = mixed_state["placements"][index]
				var actual: Dictionary = world_placements[index]
				if expected["material_id"] != actual["material_id"] or int(expected["slot_index"]) != int(actual["slot_index"]) or expected["zone"] != actual["zone"]:
					world_placement_matches = false
		_expect(world_placement_matches and world_save["cut_tree_ids"] == mixed_state["cut_tree_ids"], "An ordinary world save lost the mixed recipe's stable placements or tree cuts.")
	world.queue_free()
	await process_frame
	_expect(DamSave.clear_save(MIXED_FIXTURE_DIRECTORY), "Could not clean the mixed persistence fixture.")


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


func _read_text(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	return FileAccess.get_file_as_string(path)
