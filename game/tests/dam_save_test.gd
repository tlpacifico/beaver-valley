extends SceneTree
## Focused checks for durable state validation, replacement and recovery.

const DamSave = preload("res://scripts/dam_save.gd")
const TEST_DIRECTORY := "user://dam_save_test/"
const V1_TEST_DIRECTORY := "user://dam_save_v1_test/"
var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _expect(condition: bool, description: String) -> void:
	if not condition:
		failures += 1
		push_error(description)


func _write_text(path: String, content: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(content)
	file.flush()
	var write_error: Error = file.get_error()
	file.close()
	return write_error == OK


func _remove(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _test_path(filename: String) -> String:
	return TEST_DIRECTORY.path_join(filename)


func _run() -> void:
	# All filesystem checks use a dedicated subdirectory; the user's real save is untouched.
	_remove(_test_path(DamSave.SAVE_FILE))
	_remove(_test_path(DamSave.TEMP_FILE))
	_remove(_test_path(DamSave.BACKUP_FILE))
	var state: Dictionary = DamSave.empty_state()
	_expect(DamSave.validate_state(state), "Fresh state did not validate.")
	var array_version: Dictionary = state.duplicate(true)
	array_version["schema_version"] = []
	_expect(not DamSave.validate_state(array_version), "An array schema version was accepted.")
	_expect(not DamSave.save_state(array_version, TEST_DIRECTORY), "An array schema version reached the save writer.")
	var string_version: Dictionary = state.duplicate(true)
	string_version["schema_version"] = "2"
	_expect(not DamSave.validate_state(string_version), "A string schema version was accepted.")
	var fractional_version: Dictionary = state.duplicate(true)
	fractional_version["schema_version"] = 2.5
	_expect(not DamSave.validate_state(fractional_version), "A fractional schema version was accepted.")
	var completed_state: Dictionary = state.duplicate(true)
	completed_state["placed_materials"] = ["branch_normal_01", "branch_normal_02", "branch_normal_03"]
	completed_state["stage_completed"] = true
	completed_state["finish_choice"] = "finish_moss"
	_expect(DamSave.validate_state(completed_state), "Known finish choice on a completed stage was rejected.")
	var unknown_finish: Dictionary = completed_state.duplicate(true)
	unknown_finish["finish_choice"] = "finish_unknown"
	_expect(not DamSave.validate_state(unknown_finish), "Unknown finish choice was accepted.")
	var premature_finish: Dictionary = state.duplicate(true)
	premature_finish["finish_choice"] = "finish_moss"
	_expect(not DamSave.validate_state(premature_finish), "Finish choice before stage completion was accepted.")
	var chapter_state: Dictionary = completed_state.duplicate(true)
	chapter_state["home_slots"] = ["home_part_rounded", "home_part_plank"]
	_expect(DamSave.validate_state(chapter_state), "A valid home placement was rejected.")
	var one_slot_state: Dictionary = completed_state.duplicate(true)
	one_slot_state["home_slots"] = ["home_part_mossy", ""]
	_expect(DamSave.validate_state(one_slot_state), "A home stage with one filled position was rejected.")
	var food_state: Dictionary = chapter_state.duplicate(true)
	food_state["food_placements"] = ["food_bundle_01", "food_bundle_03"]
	_expect(DamSave.validate_state(food_state), "A valid food placement was rejected.")
	var home_before_dam: Dictionary = state.duplicate(true)
	home_before_dam["home_slots"] = ["home_part_rounded", ""]
	_expect(not DamSave.validate_state(home_before_dam), "A home placement before the dam was accepted.")
	var duplicate_home: Dictionary = chapter_state.duplicate(true)
	duplicate_home["home_slots"] = ["home_part_rounded", "home_part_rounded"]
	_expect(not DamSave.validate_state(duplicate_home), "A duplicated home part was accepted.")
	var unknown_home: Dictionary = chapter_state.duplicate(true)
	unknown_home["home_slots"] = ["home_part_unknown", ""]
	_expect(not DamSave.validate_state(unknown_home), "An unknown home part was accepted.")
	var food_without_home: Dictionary = completed_state.duplicate(true)
	food_without_home["food_placements"] = ["food_bundle_01"]
	_expect(not DamSave.validate_state(food_without_home), "Food was accepted before both home positions were filled.")
	var thin_food: Dictionary = chapter_state.duplicate(true)
	thin_food["food_placements"] = ["food_bundle_02"]
	_expect(not DamSave.validate_state(thin_food), "A thin food bundle was accepted for persistence.")
	var duplicate_food: Dictionary = chapter_state.duplicate(true)
	duplicate_food["food_placements"] = ["food_bundle_01", "food_bundle_01"]
	_expect(not DamSave.validate_state(duplicate_food), "A duplicated food bundle was accepted.")
	var too_much_food: Dictionary = chapter_state.duplicate(true)
	too_much_food["food_placements"] = ["food_bundle_01", "food_bundle_03", "food_bundle_04", "food_bundle_01"]
	_expect(not DamSave.validate_state(too_much_food), "More than three food placements were accepted.")
	_expect(not DamSave.save_state({"schema_version": 1, "held_material": "branch_a"}, TEST_DIRECTORY), "Transient held material was accepted for persistence.")
	_expect(not DamSave.save_state(state, "res://unsafe"), "A non-user save directory was accepted.")
	var unknown_material: Dictionary = state.duplicate(true)
	unknown_material["placed_materials"] = ["res://branches/branch.glb"]
	_expect(not DamSave.validate_state(unknown_material), "Resource path was accepted as a material identifier.")
	var duplicate_material: Dictionary = state.duplicate(true)
	duplicate_material["placed_materials"] = ["branch_normal_01", "branch_normal_01"]
	_expect(not DamSave.validate_state(duplicate_material), "Duplicate material identifiers were accepted.")
	var unknown_obstacle: Dictionary = state.duplicate(true)
	unknown_obstacle["solved_obstacles"] = ["res://obstacle"]
	_expect(not DamSave.validate_state(unknown_obstacle), "Obstacle resource path was accepted as an identifier.")
	var missing := DamSave.load_state(TEST_DIRECTORY)
	_expect(missing["source"] == "default" and missing["state"] == state, "Missing save did not return the default state.")

	state["placed_materials"] = ["branch_normal_01"]
	_expect(DamSave.save_state(state, TEST_DIRECTORY), "Initial save could not be written.")
	var initial_load := DamSave.load_state(TEST_DIRECTORY)
	_expect(initial_load["source"] == "primary" and initial_load["state"] == state, "Saved progress did not round-trip.")
	var next_state: Dictionary = state.duplicate(true)
	next_state["placed_materials"] = ["branch_normal_01", "branch_normal_02", "branch_normal_03"]
	next_state["stage_completed"] = true
	next_state["finish_choice"] = "finish_moss"
	_expect(DamSave.save_state(next_state, TEST_DIRECTORY), "Updated save could not replace the current save.")
	var backup_load := DamSave.load_state(TEST_DIRECTORY)
	_expect(backup_load["source"] == "primary" and backup_load["state"] == next_state, "Replacement save was not promoted.")
	_expect(_write_text(_test_path(DamSave.SAVE_FILE), "{ malformed json"), "Could not write malformed primary for recovery test.")
	var corrupt_recovery := DamSave.load_state(TEST_DIRECTORY)
	_expect(corrupt_recovery["source"] == "backup" and corrupt_recovery["state"] == state and corrupt_recovery["recovered"], "Corrupt primary did not recover the previous valid backup.")
	_expect(_write_text(_test_path(DamSave.SAVE_FILE), "{\"schema_version\": [], \"stage_id\": \"dam_valley\"}"), "Could not write malformed schema-version primary for recovery test.")
	var malformed_version_recovery := DamSave.load_state(TEST_DIRECTORY)
	_expect(malformed_version_recovery["source"] == "backup" and malformed_version_recovery["state"] == state and malformed_version_recovery["recovered"], "An array schema version did not recover the valid backup.")

	# Simulate interruption after the old primary was backed up but before temp promotion.
	_remove(_test_path(DamSave.SAVE_FILE))
	_expect(_write_text(_test_path(DamSave.TEMP_FILE), JSON.stringify(next_state)), "Could not write temp file for interruption test.")
	_expect(FileAccess.file_exists(_test_path(DamSave.TEMP_FILE)), "Interruption test did not create the temp file.")
	var interrupted := DamSave.load_state(TEST_DIRECTORY)
	_expect(interrupted["source"] == "backup" and interrupted["state"] == state, "Interrupted replacement did not recover the backup.")
	_remove(_test_path(DamSave.BACKUP_FILE))
	var corrupt_only := DamSave.load_state(TEST_DIRECTORY)
	_expect(corrupt_only["source"] == "default", "Corrupt save without backup did not fall back to defaults.")
	_expect(_write_text(_test_path(DamSave.BACKUP_FILE), "not json"), "Could not write corrupt backup for recovery test.")
	var corrupt_pair := DamSave.load_state(TEST_DIRECTORY)
	_expect(corrupt_pair["source"] == "default", "Corrupt primary and backup did not fall back to defaults.")

	var legacy_state := {
		"schema_version": 1,
		"stage_id": "dam_valley",
		"placed_materials": ["branch_normal_01"],
		"solved_obstacles": [],
		"gnawed_materials": [],
		"bent_materials": [],
		"finish_choice": "",
		"stage_completed": false,
	}
	_expect(not DamSave.save_state(legacy_state, V1_TEST_DIRECTORY), "A schema 1 state was accepted for writing.")
	_expect(DamSave.save_state(next_state, V1_TEST_DIRECTORY), "Could not prepare the schema 1 migration directory.")
	_expect(_write_text(V1_TEST_DIRECTORY.path_join(DamSave.SAVE_FILE), JSON.stringify(legacy_state)), "Could not write a schema 1 save.")
	var migrated := DamSave.load_state(V1_TEST_DIRECTORY)
	_expect(migrated["source"] == "primary" and int(migrated["state"]["schema_version"]) == 2, "A schema 1 save was not migrated to schema 2.")
	_expect(migrated["state"]["placed_materials"] == ["branch_normal_01"] and not migrated["state"]["stage_completed"], "Migration did not preserve the dam progress.")
	_expect(migrated["state"]["home_slots"] == ["", ""] and migrated["state"]["food_placements"].is_empty(), "Migration did not start the home and food stages empty.")
	_expect(DamSave.clear_save(V1_TEST_DIRECTORY), "Could not clean the schema 1 migration directory.")

	_remove(_test_path(DamSave.SAVE_FILE))
	_remove(_test_path(DamSave.TEMP_FILE))
	_remove(_test_path(DamSave.BACKUP_FILE))
	if failures == 0:
		print("CASTOR_DAM_SAVE_OK stable_ids validation round_trip replacement backup_recovery interruption malformed_corrupt_missing schema2_migration")
	quit(0 if failures == 0 else 1)
