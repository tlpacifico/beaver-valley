extends SceneTree
## R5 save fixtures: schema 1 and schema 2 saves for every chapter stage must
## restore on the new terrain without rewriting the file or resetting progress.

const DamSave = preload("res://scripts/dam_save.gd")
const SCENE_PATH := "res://scenes/movement.tscn"
const FIXTURE_DIRECTORY := "user://r5_save_fixtures/"
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

	# Schema 1 only carries the dam. It must migrate in memory and still restore.
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

	# Schema 2 covers every later stage.
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

	_expect(DamSave.clear_save(FIXTURE_DIRECTORY), "Could not clean the R5 fixture directory.")
	if failures == 0:
		print("CASTOR_SAVE_FIXTURES_OK schema1 schema2 partial_dam finishes partial_home partial_food winter safe_spawn unchanged_files")
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
	expected_food_ids: Array = []
) -> void:
	var directory := FIXTURE_DIRECTORY.path_join(fixture_name)
	_expect(DamSave.clear_save(directory), "Could not clear fixture %s." % fixture_name)
	var schema_version := int(state["schema_version"])
	if schema_version == DamSave.LEGACY_SCHEMA_VERSION:
		_expect(_write_json(directory, state), "Could not write schema 1 fixture %s." % fixture_name)
	else:
		_expect(DamSave.save_state(state, directory), "Could not write schema 2 fixture %s." % fixture_name)
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
	if expected_home_active:
		_expect(world.branch_cues.all(func(cue: MeshInstance3D) -> bool: return not cue.visible), "Fixture %s left branch cues over the home stage." % fixture_name)
		if expected_home_slots == 2:
			_expect(world.home_stage.is_complete(), "Fixture %s did not restore a complete home." % fixture_name)

	var after := _read_text(save_path)
	_expect(before == after, "Fixture %s rewrote its save file during restore." % fixture_name)
	if schema_version == DamSave.LEGACY_SCHEMA_VERSION:
		var parsed := JSON.parse_string(after) as Dictionary
		_expect(parsed != null and int(parsed["schema_version"]) == DamSave.LEGACY_SCHEMA_VERSION, "Fixture %s changed the schema on disk." % fixture_name)
		_expect(int(DamSave.load_state(directory)["state"]["schema_version"]) == DamSave.SCHEMA_VERSION, "Fixture %s was not migrated in memory." % fixture_name)
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
	var state := DamSave.empty_state()
	state["placed_materials"] = placed
	state["stage_completed"] = completed
	state["finish_choice"] = finish
	state["home_slots"] = home_slots
	state["food_placements"] = food_placements
	return state


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
