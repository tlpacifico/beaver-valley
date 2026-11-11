extends RefCounted
class_name DamSave
## Validated local persistence for the durable chapter state. Transient interaction
## state (carried or reserved items) is excluded. Schema 4 stores a recipe,
## stable placement records and stable cut-tree IDs. Schemas 1 through 3 migrate in
## memory to the legacy recipe without rewriting the original file.

const DamRecipe = preload("res://scripts/dam_recipe.gd")
const DamProgress = preload("res://scripts/dam_progress.gd")

const DEFAULT_DIRECTORY := "user://"
const SAVE_FILE := "dam_save.json"
const TEMP_FILE := "dam_save.tmp"
const BACKUP_FILE := "dam_save.bak"
const SCHEMA_VERSION := 4
const V3_SCHEMA_VERSION := 3
const V2_SCHEMA_VERSION := 2
const LEGACY_SCHEMA_VERSION := 1
const MIXED_RECIPE_ID := "mixed_fifteen"
const LEGACY_RECIPE_ID := "legacy_three"
const LEGACY_TREE_ID := "tree_legacy_01"
const LEGACY_TREE_BRANCH_ID := "branch_normal_03"
const FINISH_CHOICE_IDS: Array[String] = ["finish_golden", "finish_moss"]
const HOME_PART_IDS: Array[String] = ["home_part_rounded", "home_part_plank", "home_part_mossy"]
const FOOD_BUNDLE_IDS: Array[String] = ["food_bundle_01", "food_bundle_03", "food_bundle_04"]
const V1_KEYS: Array[String] = ["schema_version", "stage_id", "placed_materials", "solved_obstacles", "gnawed_materials", "bent_materials", "finish_choice", "stage_completed"]
const V2_KEYS: Array[String] = ["schema_version", "stage_id", "placed_materials", "solved_obstacles", "gnawed_materials", "bent_materials", "finish_choice", "stage_completed", "home_slots", "food_placements"]
const V3_KEYS: Array[String] = ["schema_version", "stage_id", "placed_materials", "solved_obstacles", "gnawed_materials", "bent_materials", "finish_choice", "stage_completed", "home_slots", "food_placements", "tree_cut"]
const V4_KEYS: Array[String] = ["schema_version", "stage_id", "recipe_id", "placed_materials", "placements", "cut_tree_ids", "solved_obstacles", "gnawed_materials", "bent_materials", "finish_choice", "stage_completed", "home_slots", "food_placements"]
const PLACEMENT_KEYS: Array[String] = ["material_id", "slot_index", "zone"]


## The no-argument template remains legacy-shaped for existing world/test
## callers. New adventures use new_adventure_state(), including load's missing
## save fallback, and therefore select mixed_fifteen explicitly.
static func empty_state(recipe_id: String = LEGACY_RECIPE_ID) -> Dictionary:
	return {
		"schema_version": float(SCHEMA_VERSION),
		"stage_id": "dam_valley",
		"recipe_id": recipe_id,
		"placed_materials": [],
		"placements": [],
		"cut_tree_ids": [],
		"solved_obstacles": [],
		"gnawed_materials": [],
		"bent_materials": [],
		"finish_choice": "",
		"stage_completed": false,
		"home_slots": ["", ""],
		"food_placements": [],
	}


static func new_adventure_state() -> Dictionary:
	return empty_state(MIXED_RECIPE_ID)


static func validate_state(candidate: Variant) -> bool:
	if not candidate is Dictionary:
		return false
	var version: Variant = candidate.get("schema_version", null)
	if not _is_numeric_schema_version(version):
		return false
	if version == LEGACY_SCHEMA_VERSION:
		return _validate_v1(candidate)
	if version == V2_SCHEMA_VERSION:
		return _validate_v2(candidate)
	if version == V3_SCHEMA_VERSION:
		return _validate_v3(candidate)
	if version == SCHEMA_VERSION:
		return _validate_v4(candidate)
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
	return _validate_chapter_fields(candidate)


static func _validate_v3(candidate: Dictionary) -> bool:
	for key: Variant in candidate.keys():
		if not V3_KEYS.has(key):
			return false
	for key: String in V3_KEYS:
		if not candidate.has(key):
			return false
	if not candidate["tree_cut"] is bool:
		return false
	if not _validate_dam_fields(candidate):
		return false
	return _validate_chapter_fields(candidate)


static func _validate_v4(candidate: Dictionary) -> bool:
	for key: Variant in candidate.keys():
		if not V4_KEYS.has(key):
			return false
	for key: String in V4_KEYS:
		if not candidate.has(key):
			return false
	if not _validate_dam_fields_v4(candidate):
		return false
	return _validate_chapter_fields(candidate)


static func _validate_chapter_fields(candidate: Dictionary) -> bool:
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
	var legacy_recipe: Dictionary = DamRecipe.for_id(LEGACY_RECIPE_ID)
	var legacy_material_ids: Array = legacy_recipe.get("material_ids", [])
	var legacy_branch_capacity: int = legacy_recipe.get("requirements", {}).get("branch", 0)
	var seen_materials: Dictionary = {}
	for material_id: Variant in candidate["placed_materials"]:
		if not material_id is String or not legacy_material_ids.has(material_id) or seen_materials.has(material_id):
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
	if candidate["placed_materials"].size() > legacy_branch_capacity or candidate["stage_completed"] != (candidate["placed_materials"].size() == legacy_branch_capacity):
		return false
	var finish_choice: String = candidate["finish_choice"]
	if not finish_choice.is_empty() and (not FINISH_CHOICE_IDS.has(finish_choice) or not candidate["stage_completed"]):
		return false
	return true


static func _validate_dam_fields_v4(candidate: Dictionary) -> bool:
	if str(candidate.get("stage_id", "")) != "dam_valley":
		return false
	var recipe_id: Variant = candidate.get("recipe_id", null)
	if not recipe_id is String:
		return false
	var recipe: Dictionary = DamRecipe.for_id(recipe_id)
	if recipe.is_empty() or recipe.get("recipe_id", "") != recipe_id:
		return false
	if not candidate.get("placed_materials", null) is Array:
		return false
	if not candidate.get("placements", null) is Array or not candidate.get("cut_tree_ids", null) is Array:
		return false
	if not candidate.get("solved_obstacles", null) is Array or not candidate.get("gnawed_materials", null) is Array or not candidate.get("bent_materials", null) is Array:
		return false
	if not candidate.get("finish_choice", null) is String or not candidate.get("stage_completed", null) is bool:
		return false

	var progress := DamProgress.new()
	progress.configure(recipe_id)
	var placement_ids: Array[String] = []
	var seen_ids: Dictionary = {}
	var seen_slots: Dictionary = {}
	var slots_by_index: Dictionary = {}
	for slot: Dictionary in recipe.get("slots", []):
		slots_by_index[slot.get("slot_index", -1)] = slot
	for placement: Variant in candidate["placements"]:
		if not placement is Dictionary:
			return false
		for key: Variant in placement.keys():
			if not PLACEMENT_KEYS.has(key):
				return false
		for key: String in PLACEMENT_KEYS:
			if not placement.has(key):
				return false
		var material_id: Variant = placement["material_id"]
		var slot_index: Variant = placement["slot_index"]
		var zone: Variant = placement["zone"]
		if not material_id is String or not _is_integer_value(slot_index) or not zone is String:
			return false
		var stable_slot_index: int = int(slot_index)
		if seen_ids.has(material_id) or seen_slots.has(stable_slot_index) or not progress.can_place(material_id):
			return false
		var material_type: String = recipe["material_type_for_id"].get(material_id, "")
		var slot: Dictionary = slots_by_index.get(stable_slot_index, {})
		if slot.is_empty() or slot.get("zone", "") != zone or not slot.get("compatible_types", []).has(material_type):
			return false
		progress.place(material_id)
		seen_ids[material_id] = true
		seen_slots[stable_slot_index] = true
		placement_ids.append(material_id)
	if candidate["placed_materials"] != placement_ids:
		return false
	if candidate["stage_completed"] != progress.is_complete():
		return false

	if recipe_id == LEGACY_RECIPE_ID:
		if not _validate_legacy_obstacles_v4(candidate):
			return false
	else:
		if not candidate["solved_obstacles"].is_empty() or not candidate["gnawed_materials"].is_empty() or not candidate["bent_materials"].is_empty():
			return false
	if not _validate_cut_tree_ids(candidate["cut_tree_ids"], recipe_id, seen_ids):
		return false
	var finish_choice: String = candidate["finish_choice"]
	if not finish_choice.is_empty() and (not FINISH_CHOICE_IDS.has(finish_choice) or not candidate["stage_completed"]):
		return false
	return true


static func _validate_legacy_obstacles_v4(candidate: Dictionary) -> bool:
	var solved: Dictionary = {}
	for obstacle_id: Variant in candidate["solved_obstacles"]:
		if not obstacle_id is String or not ["branch_thick_01", "branch_rotten_01"].has(obstacle_id) or solved.has(obstacle_id):
			return false
		solved[obstacle_id] = true
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
	if solved.has("branch_thick_01") != gnawed.has("branch_thick_01") or solved.has("branch_rotten_01") != bent.has("branch_rotten_01"):
		return false
	return true


static func _validate_cut_tree_ids(cut_tree_ids: Array, recipe_id: String, placed_ids: Dictionary) -> bool:
	var valid_tree_ids: Dictionary = {}
	var tree_id_for_log: Dictionary = {}
	if recipe_id == LEGACY_RECIPE_ID:
		valid_tree_ids[LEGACY_TREE_ID] = true
		tree_id_for_log[LEGACY_TREE_BRANCH_ID] = LEGACY_TREE_ID
	else:
		var recipe: Dictionary = DamRecipe.for_id(recipe_id)
		for source: Dictionary in recipe.get("tree_sources", []):
			var tree_id: String = source.get("tree_id", "")
			var log_id: String = source.get("log_id", "")
			valid_tree_ids[tree_id] = true
			tree_id_for_log[log_id] = tree_id
	var seen_trees: Dictionary = {}
	for tree_id: Variant in cut_tree_ids:
		if not tree_id is String or not valid_tree_ids.has(tree_id) or seen_trees.has(tree_id):
			return false
		seen_trees[tree_id] = true
	for log_id: String in tree_id_for_log.keys():
		if placed_ids.has(log_id) and not seen_trees.has(tree_id_for_log[log_id]):
			return false
	return true


## Older legacy-world callers only supplied placed_materials and tree_cut.
## Normalize that known shape into schema-4 stable records before validation;
## mixed saves are never inferred or rewritten this way.
static func _normalize_legacy_write(state: Dictionary) -> Dictionary:
	var normalized := state.duplicate(true)
	if normalized.get("schema_version") != SCHEMA_VERSION or normalized.get("recipe_id", "") != LEGACY_RECIPE_ID:
		return normalized
	var material_ids_value: Variant = normalized.get("placed_materials", [])
	var placements_value: Variant = normalized.get("placements", [])
	var cut_tree_ids_value: Variant = normalized.get("cut_tree_ids", [])
	if not material_ids_value is Array or not placements_value is Array or not cut_tree_ids_value is Array:
		return normalized
	var material_ids: Array = material_ids_value
	var placements: Array = placements_value
	if placements.is_empty() and not material_ids.is_empty():
		var legacy_placements: Array[Dictionary] = []
		for index: int in range(material_ids.size()):
			legacy_placements.append({"material_id": material_ids[index], "slot_index": index, "zone": "dam_fill"})
		normalized["placements"] = legacy_placements
	var cut_tree_ids: Array = cut_tree_ids_value
	if normalized.has("tree_cut"):
		if not normalized["tree_cut"] is bool:
			return normalized
		if normalized["tree_cut"] and not cut_tree_ids.has(LEGACY_TREE_ID):
			cut_tree_ids.append(LEGACY_TREE_ID)
		normalized.erase("tree_cut")
	if material_ids.has(LEGACY_TREE_BRANCH_ID) and not cut_tree_ids.has(LEGACY_TREE_ID):
		cut_tree_ids.append(LEGACY_TREE_ID)
	normalized["cut_tree_ids"] = cut_tree_ids
	return normalized


static func save_state(state: Dictionary, directory: String = DEFAULT_DIRECTORY) -> bool:
	if not state.has("schema_version") or not _is_numeric_schema_version(state["schema_version"]) or state["schema_version"] != SCHEMA_VERSION:
		return false
	var normalized_state := _normalize_legacy_write(state)
	if not validate_state(normalized_state) or not _is_safe_directory(directory):
		return false
	var directory_error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	if directory_error != OK and directory_error != ERR_ALREADY_EXISTS:
		return false
	var save_path := _path(directory, SAVE_FILE)
	var temp_path := _path(directory, TEMP_FILE)
	var backup_path := _path(directory, BACKUP_FILE)
	var serialized := JSON.stringify(normalized_state, "\t")
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
		return {"state": new_adventure_state(), "source": "default", "recovered": false}
	var primary := _read_valid(_path(directory, SAVE_FILE))
	if primary.get("valid", false):
		return {"state": primary["state"], "source": "primary", "recovered": false}
	var backup := _read_valid(_path(directory, BACKUP_FILE))
	if backup.get("valid", false):
		return {"state": backup["state"], "source": "backup", "recovered": true}
	return {"state": new_adventure_state(), "source": "default", "recovered": false}


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
	if version == V2_SCHEMA_VERSION and _validate_v2(parsed):
		return {"valid": true, "state": _migrate_v2(parsed)}
	if version == V3_SCHEMA_VERSION and _validate_v3(parsed):
		return {"valid": true, "state": _migrate_v3(parsed)}
	if version == SCHEMA_VERSION and _validate_v4(parsed):
		return {"valid": true, "state": parsed}
	return {"valid": false}


static func _is_numeric_schema_version(version: Variant) -> bool:
	return typeof(version) == TYPE_INT or typeof(version) == TYPE_FLOAT


static func _is_integer_value(value: Variant) -> bool:
	if not _is_numeric_schema_version(value):
		return false
	return is_equal_approx(float(value), roundf(float(value)))


## Schema 1 only knows the dam fields: rebuild chapter keys and retain the old
## three-branch recipe in memory, without writing the migration to disk.
static func _migrate_v1(state: Dictionary) -> Dictionary:
	return _migrate_legacy_state(state, false, true)


## Schema 2 carries the chapter placements but no tree: the tree starts standing.
static func _migrate_v2(state: Dictionary) -> Dictionary:
	return _migrate_legacy_state(state, false, false)


## Schema 3's single tree_cut flag names the original branch_normal_03 source.
static func _migrate_v3(state: Dictionary) -> Dictionary:
	return _migrate_legacy_state(state, bool(state["tree_cut"]), false)


static func _migrate_legacy_state(state: Dictionary, tree_cut: bool, add_chapter_fields: bool) -> Dictionary:
	var migrated := state.duplicate(true)
	migrated["schema_version"] = float(SCHEMA_VERSION)
	migrated["recipe_id"] = LEGACY_RECIPE_ID
	var placements: Array[Dictionary] = []
	var placement_ids: Array[String] = []
	var old_placed: Array = state["placed_materials"]
	for index: int in range(old_placed.size()):
		var material_id: String = old_placed[index]
		placement_ids.append(material_id)
		placements.append({"material_id": material_id, "slot_index": index, "zone": "dam_fill"})
	migrated["placed_materials"] = placement_ids
	migrated["placements"] = placements
	var cut_tree_ids: Array[String] = []
	if tree_cut or placement_ids.has(LEGACY_TREE_BRANCH_ID):
		cut_tree_ids.append(LEGACY_TREE_ID)
	migrated["cut_tree_ids"] = cut_tree_ids
	migrated.erase("tree_cut")
	if add_chapter_fields:
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
