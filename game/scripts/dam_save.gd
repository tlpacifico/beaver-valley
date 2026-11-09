extends RefCounted
class_name DamSave
## Validated local persistence for the durable chapter state. Transient interaction
## state (carried or reserved items) is excluded. Schema 2 adds the home and food
## placements and still loads schema 1 saves with the dam only.

const DEFAULT_DIRECTORY := "user://"
const SAVE_FILE := "dam_save.json"
const TEMP_FILE := "dam_save.tmp"
const BACKUP_FILE := "dam_save.bak"
const SCHEMA_VERSION := 2
const LEGACY_SCHEMA_VERSION := 1
const BRANCH_IDS: Array[String] = ["branch_thick_01", "branch_rotten_01", "branch_normal_01", "branch_normal_02", "branch_normal_03"]
const FINISH_CHOICE_IDS: Array[String] = ["finish_golden", "finish_moss"]
const HOME_PART_IDS: Array[String] = ["home_part_rounded", "home_part_plank", "home_part_mossy"]
const FOOD_BUNDLE_IDS: Array[String] = ["food_bundle_01", "food_bundle_03", "food_bundle_04"]
const V1_KEYS: Array[String] = ["schema_version", "stage_id", "placed_materials", "solved_obstacles", "gnawed_materials", "bent_materials", "finish_choice", "stage_completed"]
const V2_KEYS: Array[String] = ["schema_version", "stage_id", "placed_materials", "solved_obstacles", "gnawed_materials", "bent_materials", "finish_choice", "stage_completed", "home_slots", "food_placements"]


static func empty_state() -> Dictionary:
	return {
		"schema_version": float(SCHEMA_VERSION),
		"stage_id": "dam_valley",
		"placed_materials": [],
		"solved_obstacles": [],
		"gnawed_materials": [],
		"bent_materials": [],
		"finish_choice": "",
		"stage_completed": false,
		"home_slots": ["", ""],
		"food_placements": [],
	}


static func validate_state(candidate: Variant) -> bool:
	if not candidate is Dictionary:
		return false
	var version: Variant = candidate.get("schema_version", null)
	if not _is_numeric_schema_version(version):
		return false
	if version == LEGACY_SCHEMA_VERSION:
		return _validate_v1(candidate)
	if version == SCHEMA_VERSION:
		return _validate_v2(candidate)
	return false


static func _validate_v1(candidate: Dictionary) -> bool:
	for key: Variant in candidate.keys():
		if not V1_KEYS.has(key):
			return false
	for key: String in V1_KEYS:
		if not candidate.has(key):
			return false
	return _validate_dam_fields(candidate)


static func _validate_v2(candidate: Dictionary) -> bool:
	for key: Variant in candidate.keys():
		if not V2_KEYS.has(key):
			return false
	for key: String in V2_KEYS:
		if not candidate.has(key):
			return false
	if not _validate_dam_fields(candidate):
		return false
	var home_slots: Variant = candidate["home_slots"]
	if not home_slots is Array or home_slots.size() != 2:
		return false
	var seen_home: Dictionary = {}
	for slot: Variant in home_slots:
		if not slot is String:
			return false
		if slot.is_empty():
			continue
		if not HOME_PART_IDS.has(slot) or seen_home.has(slot):
			return false
		seen_home[slot] = true
	if not seen_home.is_empty() and not candidate["stage_completed"]:
		return false
	var food_placements: Variant = candidate["food_placements"]
	if not food_placements is Array or food_placements.size() > 3:
		return false
	var seen_food: Dictionary = {}
	for bundle_id: Variant in food_placements:
		if not bundle_id is String or not FOOD_BUNDLE_IDS.has(bundle_id) or seen_food.has(bundle_id):
			return false
		seen_food[bundle_id] = true
	if not food_placements.is_empty() and (str(home_slots[0]).is_empty() or str(home_slots[1]).is_empty()):
		return false
	return true


static func _validate_dam_fields(candidate: Dictionary) -> bool:
	if str(candidate.get("stage_id", "")) != "dam_valley":
		return false
	if not candidate.get("placed_materials", null) is Array:
		return false
	if not candidate.get("solved_obstacles", null) is Array or not candidate.get("gnawed_materials", null) is Array or not candidate.get("bent_materials", null) is Array:
		return false
	if not candidate.get("finish_choice", null) is String:
		return false
	if not candidate.get("stage_completed", null) is bool:
		return false
	var seen_materials: Dictionary = {}
	for material_id: Variant in candidate["placed_materials"]:
		if not material_id is String or not BRANCH_IDS.has(material_id) or seen_materials.has(material_id):
			return false
		seen_materials[material_id] = true
	var seen_obstacles: Dictionary = {}
	for obstacle_id: Variant in candidate["solved_obstacles"]:
		if not obstacle_id is String or not ["branch_thick_01", "branch_rotten_01"].has(obstacle_id) or seen_obstacles.has(obstacle_id):
			return false
		seen_obstacles[obstacle_id] = true
	var gnawed: Dictionary = {}
	for material_id: Variant in candidate["gnawed_materials"]:
		if material_id != "branch_thick_01" or gnawed.has(material_id):
			return false
		gnawed[material_id] = true
	var bent: Dictionary = {}
	for material_id: Variant in candidate["bent_materials"]:
		if material_id != "branch_rotten_01" or bent.has(material_id):
			return false
		bent[material_id] = true
	if seen_obstacles.has("branch_thick_01") != gnawed.has("branch_thick_01") or seen_obstacles.has("branch_rotten_01") != bent.has("branch_rotten_01"):
		return false
	for material_id: String in candidate["placed_materials"]:
		if material_id == "branch_rotten_01" or (material_id == "branch_thick_01" and not gnawed.has(material_id)):
			return false
	if candidate["placed_materials"].size() > 3 or candidate["stage_completed"] != (candidate["placed_materials"].size() == 3):
		return false
	var finish_choice: String = candidate["finish_choice"]
	if not finish_choice.is_empty() and (not FINISH_CHOICE_IDS.has(finish_choice) or not candidate["stage_completed"]):
		return false
	return true


static func save_state(state: Dictionary, directory: String = DEFAULT_DIRECTORY) -> bool:
	if not state.has("schema_version") or not _is_numeric_schema_version(state["schema_version"]) or state["schema_version"] != SCHEMA_VERSION:
		return false
	if not validate_state(state) or not _is_safe_directory(directory):
		return false
	var directory_error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	if directory_error != OK and directory_error != ERR_ALREADY_EXISTS:
		return false
	var save_path := _path(directory, SAVE_FILE)
	var temp_path := _path(directory, TEMP_FILE)
	var backup_path := _path(directory, BACKUP_FILE)
	var serialized := JSON.stringify(state, "\t")
	var temp_file := FileAccess.open(temp_path, FileAccess.WRITE)
	if temp_file == null:
		return false
	temp_file.store_string(serialized)
	temp_file.flush()
	var write_error: Error = temp_file.get_error()
	temp_file.close()
	if write_error != OK or not _read_valid(temp_path).get("valid", false):
		return false
	# Keep the previous valid save available if replacement is interrupted.
	if FileAccess.file_exists(save_path):
		if _read_valid(save_path).get("valid", false):
			if FileAccess.file_exists(backup_path):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(backup_path))
			var backup_error := DirAccess.rename_absolute(ProjectSettings.globalize_path(save_path), ProjectSettings.globalize_path(backup_path))
			if backup_error != OK:
				return false
		else:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	var replace_error := DirAccess.rename_absolute(ProjectSettings.globalize_path(temp_path), ProjectSettings.globalize_path(save_path))
	if replace_error != OK:
		# The valid backup remains recoverable if promotion of the temp file fails.
		return false
	return true


static func load_state(directory: String = DEFAULT_DIRECTORY) -> Dictionary:
	if not _is_safe_directory(directory):
		return {"state": empty_state(), "source": "default", "recovered": false}
	var primary := _read_valid(_path(directory, SAVE_FILE))
	if primary.get("valid", false):
		return {"state": primary["state"], "source": "primary", "recovered": false}
	var backup := _read_valid(_path(directory, BACKUP_FILE))
	if backup.get("valid", false):
		return {"state": backup["state"], "source": "backup", "recovered": true}
	return {"state": empty_state(), "source": "default", "recovered": false}


static func _read_valid(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"valid": false}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"valid": false}
	var parser := JSON.new()
	var parse_error := parser.parse(file.get_as_text())
	file.close()
	if parse_error != OK:
		return {"valid": false}
	var parsed: Variant = parser.data
	if not parsed is Dictionary:
		return {"valid": false}
	var version: Variant = parsed.get("schema_version", null)
	if not _is_numeric_schema_version(version):
		return {"valid": false}
	if version == LEGACY_SCHEMA_VERSION and _validate_v1(parsed):
		return {"valid": true, "state": _migrate_v1(parsed)}
	if version == SCHEMA_VERSION and _validate_v2(parsed):
		return {"valid": true, "state": parsed}
	return {"valid": false}


static func _is_numeric_schema_version(version: Variant) -> bool:
	return typeof(version) == TYPE_INT or typeof(version) == TYPE_FLOAT


static func _migrate_v1(state: Dictionary) -> Dictionary:
	var migrated := state.duplicate(true)
	migrated["schema_version"] = float(SCHEMA_VERSION)
	migrated["home_slots"] = ["", ""]
	migrated["food_placements"] = []
	return migrated


static func clear_save(directory: String = DEFAULT_DIRECTORY) -> bool:
	if not _is_safe_directory(directory):
		return false
	var success := true
	for filename in [SAVE_FILE, TEMP_FILE, BACKUP_FILE]:
		var path := _path(directory, filename)
		if FileAccess.file_exists(path) and DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) != OK:
			success = false
	return success


static func _is_safe_directory(directory: String) -> bool:
	return directory == DEFAULT_DIRECTORY or (directory.begins_with("user://") and not directory.substr(7).contains("..") and not directory.substr(7).contains(":") and not directory.contains("\\"))


static func _path(directory: String, filename: String) -> String:
	return directory.path_join(filename)
