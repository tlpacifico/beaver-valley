extends SceneTree
## Focused checks for durable state validation, replacement and recovery.

const DamSave = preload("res://scripts/dam_save.gd")
const TEST_DIRECTORY := "user://dam_save_test/"
const V1_TEST_DIRECTORY := "user://dam_save_v1_test/"
const V2_TEST_DIRECTORY := "user://dam_save_v2_test/"
const V3_TEST_DIRECTORY := "user://dam_save_v3_test/"
const WRITE_FAILURE_DIRECTORY := "user://dam_save_write_failure_test/"
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
	var state: Dictionary = DamSave.new_adventure_state()
	_expect(DamSave.validate_state(state), "Fresh state did not validate.")
	_expect(state.get("recipe_id", "") == "mixed_fifteen", "A fresh adventure did not select the mixed recipe.")
	_expect(state.get("placements", null) is Array and state["placements"].is_empty(), "A fresh adventure did not start with no stable placements.")
	_expect(state.get("cut_tree_ids", null) is Array and state["cut_tree_ids"].is_empty(), "A fresh adventure did not start with standing trees.")
	var mixed_partial: Dictionary = state.duplicate(true)
	mixed_partial["placed_materials"] = ["log_01"]
	mixed_partial["placements"] = [{"material_id": "log_01", "slot_index": 5, "zone": "dam_wall"}]
	mixed_partial["cut_tree_ids"] = ["tree_01"]
	_expect(DamSave.validate_state(mixed_partial), "A partial mixed-recipe save with its source tree cut was rejected.")
	var five_cut_trees: Dictionary = mixed_partial.duplicate(true)
	five_cut_trees["cut_tree_ids"] = ["tree_01", "tree_02", "tree_03", "tree_04", "tree_05"]
	_expect(DamSave.validate_state(five_cut_trees), "Five distinct mixed-recipe tree cuts were rejected.")
	var duplicate_tree: Dictionary = mixed_partial.duplicate(true)
	duplicate_tree["cut_tree_ids"] = ["tree_01", "tree_01"]
	_expect(not DamSave.validate_state(duplicate_tree), "A duplicated cut-tree ID was accepted.")
	var four_mixed_branches: Dictionary = DamSave.new_adventure_state()
	four_mixed_branches["placed_materials"] = ["branch_01", "branch_02", "branch_03", "branch_04"]
	four_mixed_branches["placements"] = [
		{"material_id": "branch_01", "slot_index": 0, "zone": "dam_fill"},
		{"material_id": "branch_02", "slot_index": 1, "zone": "dam_fill"},
		{"material_id": "branch_03", "slot_index": 2, "zone": "dam_fill"},
		{"material_id": "branch_04", "slot_index": 3, "zone": "dam_fill"},
	]
	_expect(DamSave.validate_state(four_mixed_branches), "The legacy three-object limit was incorrectly applied to a four-object mixed partial save.")
	var duplicate_placement: Dictionary = mixed_partial.duplicate(true)
	duplicate_placement["placed_materials"] = ["log_01", "log_01"]
	duplicate_placement["placements"].append({"material_id": "log_01", "slot_index": 6, "zone": "dam_wall"})
	_expect(not DamSave.validate_state(duplicate_placement), "A duplicate placed object was accepted.")
	var unknown_tree: Dictionary = mixed_partial.duplicate(true)
	unknown_tree["cut_tree_ids"] = ["tree_unknown"]
	_expect(not DamSave.validate_state(unknown_tree), "An unknown cut tree was accepted.")
	var log_without_source: Dictionary = mixed_partial.duplicate(true)
	log_without_source["cut_tree_ids"] = []
	_expect(not DamSave.validate_state(log_without_source), "A placed tree log without its cut source was accepted.")
	var wrong_slot: Dictionary = mixed_partial.duplicate(true)
	wrong_slot["placements"] = [{"material_id": "branch_01", "slot_index": 5, "zone": "dam_wall"}]
	wrong_slot["placed_materials"] = ["branch_01"]
	_expect(not DamSave.validate_state(wrong_slot), "A branch assigned to a log-only slot was accepted.")
	var inconsistent_completion: Dictionary = mixed_partial.duplicate(true)
	inconsistent_completion["stage_completed"] = true
	_expect(not DamSave.validate_state(inconsistent_completion), "A partial recipe marked complete was accepted.")
	state = DamSave.empty_state(DamSave.LEGACY_RECIPE_ID)
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
	_set_legacy_placements(completed_state, ["branch_normal_01", "branch_normal_02", "branch_normal_03"])
	completed_state["stage_completed"] = true
	completed_state["finish_choice"] = "finish_moss"
	_expect(DamSave.validate_state(completed_state), "Known finish choice on a completed stage was rejected.")
	var all_legacy_materials: Dictionary = state.duplicate(true)
	_set_legacy_placements(all_legacy_materials, ["branch_thick_01", "branch_rotten_01", "branch_normal_03"])
	all_legacy_materials["stage_completed"] = true
	_expect(DamSave.validate_state(all_legacy_materials), "A legacy save using three of the five historical branch IDs was rejected.")
	var cut_tree_state: Dictionary = state.duplicate(true)
	cut_tree_state["cut_tree_ids"] = [DamSave.LEGACY_TREE_ID]
	_expect(DamSave.validate_state(cut_tree_state), "A durable legacy tree cut was rejected in schema 4.")
	var non_bool_tree: Dictionary = cut_tree_state.duplicate(true)
	non_bool_tree["cut_tree_ids"] = [true]
	_expect(not DamSave.validate_state(non_bool_tree), "A non-string cut-tree ID was accepted.")
	var missing_tree: Dictionary = cut_tree_state.duplicate(true)
	missing_tree.erase("cut_tree_ids")
	_expect(not DamSave.validate_state(missing_tree), "A schema 4 state without cut_tree_ids was accepted.")
	var extra_tree_key: Dictionary = cut_tree_state.duplicate(true)
	extra_tree_key["tree_planted"] = true
	_expect(not DamSave.validate_state(extra_tree_key), "An unknown schema 4 key was accepted.")
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
	_set_legacy_placements(unknown_material, ["res://branches/branch.glb"])
	_expect(not DamSave.validate_state(unknown_material), "Resource path was accepted as a material identifier.")
	var duplicate_material: Dictionary = state.duplicate(true)
	_set_legacy_placements(duplicate_material, ["branch_normal_01", "branch_normal_01"])
	_expect(not DamSave.validate_state(duplicate_material), "Duplicate material identifiers were accepted.")
	var unknown_obstacle: Dictionary = state.duplicate(true)
	unknown_obstacle["solved_obstacles"] = ["res://obstacle"]
	_expect(not DamSave.validate_state(unknown_obstacle), "Obstacle resource path was accepted as an identifier.")
	var missing := DamSave.load_state(TEST_DIRECTORY)
	_expect(missing["source"] == "default" and missing["state"] == DamSave.new_adventure_state(), "Missing save did not return the default mixed-recipe state.")

	_set_legacy_placements(state, ["branch_normal_01"])
	_expect(DamSave.save_state(state, TEST_DIRECTORY), "Initial save could not be written.")
	var initial_load := DamSave.load_state(TEST_DIRECTORY)
	_expect(initial_load["source"] == "primary" and _same_saved_state(state, initial_load["state"]), "Saved progress did not round-trip.")
	var next_state: Dictionary = state.duplicate(true)
	_set_legacy_placements(next_state, ["branch_normal_01", "branch_normal_02", "branch_normal_03"])
	next_state["stage_completed"] = true
	next_state["finish_choice"] = "finish_moss"
	next_state["cut_tree_ids"] = [DamSave.LEGACY_TREE_ID]
	_expect(DamSave.save_state(next_state, TEST_DIRECTORY), "Updated save could not replace the current save.")
	var backup_load := DamSave.load_state(TEST_DIRECTORY)
	_expect(backup_load["source"] == "primary" and _same_saved_state(next_state, backup_load["state"]), "Replacement save was not promoted.")
	_expect(_write_text(_test_path(DamSave.SAVE_FILE), "{ malformed json"), "Could not write malformed primary for recovery test.")
	var corrupt_recovery := DamSave.load_state(TEST_DIRECTORY)
	_expect(corrupt_recovery["source"] == "backup" and _same_saved_state(state, corrupt_recovery["state"]) and corrupt_recovery["recovered"], "Corrupt primary did not recover the previous valid backup.")
	_expect(_write_text(_test_path(DamSave.SAVE_FILE), "{\"schema_version\": [], \"stage_id\": \"dam_valley\"}"), "Could not write malformed schema-version primary for recovery test.")
	var malformed_version_recovery := DamSave.load_state(TEST_DIRECTORY)
	_expect(malformed_version_recovery["source"] == "backup" and _same_saved_state(state, malformed_version_recovery["state"]) and malformed_version_recovery["recovered"], "An array schema version did not recover the valid backup.")

	# Simulate interruption after the old primary was backed up but before temp promotion.
	_remove(_test_path(DamSave.SAVE_FILE))
	_expect(_write_text(_test_path(DamSave.TEMP_FILE), JSON.stringify(next_state)), "Could not write temp file for interruption test.")
	_expect(FileAccess.file_exists(_test_path(DamSave.TEMP_FILE)), "Interruption test did not create the temp file.")
	var interrupted := DamSave.load_state(TEST_DIRECTORY)
	_expect(interrupted["source"] == "backup" and _same_saved_state(state, interrupted["state"]), "Interrupted replacement did not recover the backup.")
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
	var v1_disk_before := FileAccess.get_file_as_string(V1_TEST_DIRECTORY.path_join(DamSave.SAVE_FILE))
	var migrated := DamSave.load_state(V1_TEST_DIRECTORY)
	_expect(migrated["source"] == "primary" and int(migrated["state"]["schema_version"]) == DamSave.SCHEMA_VERSION, "A schema 1 save was not migrated to schema 4.")
	_expect(migrated["state"]["recipe_id"] == DamSave.LEGACY_RECIPE_ID and migrated["state"]["placements"] == [{"material_id": "branch_normal_01", "slot_index": 0, "zone": "dam_fill"}], "Schema 1 migration did not map the old dam to legacy stable slots.")
	_expect(migrated["state"]["placed_materials"] == ["branch_normal_01"] and not migrated["state"]["stage_completed"], "Migration did not preserve the dam progress.")
	_expect(migrated["state"]["home_slots"] == ["", ""] and migrated["state"]["food_placements"].is_empty(), "Migration did not start the home and food stages empty.")
	_expect(migrated["state"]["cut_tree_ids"].is_empty(), "Schema 1 migration did not start with a standing tree.")
	_expect(FileAccess.get_file_as_string(V1_TEST_DIRECTORY.path_join(DamSave.SAVE_FILE)) == v1_disk_before, "Schema 1 migration rewrote the old save file.")
	_expect(DamSave.clear_save(V1_TEST_DIRECTORY), "Could not clean the schema 1 migration directory.")

	var v2_state := {
		"schema_version": 2,
		"stage_id": "dam_valley",
		"placed_materials": ["branch_normal_01"],
		"solved_obstacles": [],
		"gnawed_materials": [],
		"bent_materials": [],
		"finish_choice": "",
		"stage_completed": false,
		"home_slots": ["", ""],
		"food_placements": [],
	}
	_expect(not DamSave.save_state(v2_state, V2_TEST_DIRECTORY), "A schema 2 state was accepted for writing.")
	_expect(DamSave.save_state(next_state, V2_TEST_DIRECTORY), "Could not prepare the schema 2 migration directory.")
	_expect(_write_text(V2_TEST_DIRECTORY.path_join(DamSave.SAVE_FILE), JSON.stringify(v2_state)), "Could not write a schema 2 save.")
	var v2_disk_before := FileAccess.get_file_as_string(V2_TEST_DIRECTORY.path_join(DamSave.SAVE_FILE))
	var migrated_v2 := DamSave.load_state(V2_TEST_DIRECTORY)
	_expect(migrated_v2["source"] == "primary" and int(migrated_v2["state"]["schema_version"]) == DamSave.SCHEMA_VERSION, "A schema 2 save was not migrated to schema 4.")
	_expect(migrated_v2["state"]["recipe_id"] == DamSave.LEGACY_RECIPE_ID and migrated_v2["state"]["cut_tree_ids"].is_empty(), "Schema 2 migration did not add the legacy recipe and standing tree.")
	_expect(migrated_v2["state"]["home_slots"] == ["", ""] and migrated_v2["state"]["food_placements"].is_empty(), "Schema 2 migration changed the chapter placements.")
	_expect(FileAccess.get_file_as_string(V2_TEST_DIRECTORY.path_join(DamSave.SAVE_FILE)) == v2_disk_before, "Schema 2 migration rewrote the old save file.")
	_expect(DamSave.clear_save(V2_TEST_DIRECTORY), "Could not clean the schema 2 migration directory.")

	var v3_state := {
		"schema_version": 3,
		"stage_id": "dam_valley",
		"placed_materials": ["branch_thick_01", "branch_rotten_01", "branch_normal_03"],
		"solved_obstacles": [],
		"gnawed_materials": [],
		"bent_materials": [],
		"finish_choice": "finish_golden",
		"stage_completed": true,
		"home_slots": ["home_part_rounded", "home_part_plank"],
		"food_placements": ["food_bundle_01"],
		"tree_cut": true,
	}
	_expect(not DamSave.save_state(v3_state, V3_TEST_DIRECTORY), "A schema 3 state was accepted for writing.")
	_expect(DamSave.save_state(next_state, V3_TEST_DIRECTORY), "Could not prepare the schema 3 migration directory.")
	_expect(_write_text(V3_TEST_DIRECTORY.path_join(DamSave.SAVE_FILE), JSON.stringify(v3_state)), "Could not write a schema 3 save.")
	var v3_disk_before := FileAccess.get_file_as_string(V3_TEST_DIRECTORY.path_join(DamSave.SAVE_FILE))
	var migrated_v3 := DamSave.load_state(V3_TEST_DIRECTORY)
	_expect(migrated_v3["source"] == "primary" and migrated_v3["state"]["recipe_id"] == DamSave.LEGACY_RECIPE_ID, "Schema 3 migration did not retain the legacy recipe.")
	_expect(migrated_v3["state"]["cut_tree_ids"] == [DamSave.LEGACY_TREE_ID] and migrated_v3["state"]["placed_materials"] == v3_state["placed_materials"], "Schema 3 tree/source or dam progress was not preserved.")
	_expect(FileAccess.get_file_as_string(V3_TEST_DIRECTORY.path_join(DamSave.SAVE_FILE)) == v3_disk_before, "Schema 3 migration rewrote the old save file.")
	_expect(DamSave.clear_save(V3_TEST_DIRECTORY), "Could not clean the schema 3 migration directory.")

	_expect(DamSave.clear_save(WRITE_FAILURE_DIRECTORY), "Could not prepare the isolated write-failure directory.")
	_expect(DamSave.save_state(state, WRITE_FAILURE_DIRECTORY), "Could not write the original save for write-failure testing.")
	var original_save_text := FileAccess.get_file_as_string(WRITE_FAILURE_DIRECTORY.path_join(DamSave.SAVE_FILE))
	var temp_directory_path := ProjectSettings.globalize_path(WRITE_FAILURE_DIRECTORY.path_join(DamSave.TEMP_FILE))
	_expect(DirAccess.make_dir_absolute(temp_directory_path) == OK, "Could not create the isolated temp-path blocker.")
	_expect(not DamSave.save_state(next_state, WRITE_FAILURE_DIRECTORY), "A failed temp-file write was reported as successful.")
	_expect(DirAccess.remove_absolute(temp_directory_path) == OK, "Could not remove the isolated temp-path blocker.")
	_expect(FileAccess.get_file_as_string(WRITE_FAILURE_DIRECTORY.path_join(DamSave.SAVE_FILE)) == original_save_text, "A failed write changed the previous valid save.")
	_expect(DamSave.clear_save(WRITE_FAILURE_DIRECTORY), "Could not clean the isolated write-failure directory.")

	_remove(_test_path(DamSave.SAVE_FILE))
	_remove(_test_path(DamSave.TEMP_FILE))
	_remove(_test_path(DamSave.BACKUP_FILE))
	if failures == 0:
		print("CASTOR_DAM_SAVE_OK schema4_recipes stable_placements tree_sources legacy_migrations round_trip replacement backup_recovery interruption malformed_corrupt_missing")
	quit(0 if failures == 0 else 1)


func _set_legacy_placements(state: Dictionary, material_ids: Array) -> void:
	state["placed_materials"] = material_ids.duplicate()
	var placements: Array[Dictionary] = []
	for index: int in range(material_ids.size()):
		placements.append({"material_id": material_ids[index], "slot_index": index, "zone": "dam_fill"})
	state["placements"] = placements
	state["cut_tree_ids"] = [DamSave.LEGACY_TREE_ID] if material_ids.has("branch_normal_03") else []


func _same_saved_state(expected: Dictionary, actual: Dictionary) -> bool:
	for key: String in ["schema_version", "stage_id", "recipe_id", "placed_materials", "cut_tree_ids", "solved_obstacles", "gnawed_materials", "bent_materials", "finish_choice", "stage_completed", "home_slots", "food_placements"]:
		if expected.get(key) != actual.get(key):
			return false
	var expected_placements: Array = expected["placements"]
	var actual_placements: Array = actual["placements"]
	if expected_placements.size() != actual_placements.size():
		return false
	for index: int in range(expected_placements.size()):
		var expected_placement: Dictionary = expected_placements[index]
		var actual_placement: Dictionary = actual_placements[index]
		if expected_placement["material_id"] != actual_placement["material_id"] or int(expected_placement["slot_index"]) != int(actual_placement["slot_index"]) or expected_placement["zone"] != actual_placement["zone"]:
			return false
	return true
