extends RefCounted
class_name DamRecipe
## Stable recipe definitions for dam construction. Recipes are plain data: they
## map every deliverable object to a material type and define the visual slots
## that can accept each type. No type is inferred from identifier text.

const MIXED_BRANCH_IDS: Array[String] = ["branch_01", "branch_02", "branch_03", "branch_04", "branch_05"]
const MIXED_LOG_IDS: Array[String] = ["log_01", "log_02", "log_03", "log_04", "log_05"]
const MIXED_STONE_IDS: Array[String] = ["stone_01", "stone_02", "stone_03", "stone_04", "stone_05"]
const MIXED_TREE_IDS: Array[String] = ["tree_01", "tree_02", "tree_03", "tree_04", "tree_05"]
const LEGACY_MATERIAL_IDS: Array[String] = ["branch_thick_01", "branch_rotten_01", "branch_normal_01", "branch_normal_02", "branch_normal_03"]


## Returns the full recipe for a known recipe ID, or an empty dictionary if the
## ID is not recognised. Callers must not mutate the returned dictionary.
static func for_id(recipe_id: String) -> Dictionary:
	if recipe_id == "mixed_fifteen":
		return _mixed_fifteen()
	if recipe_id == "legacy_three":
		return _legacy_three()
	return {}


static func _mixed_fifteen() -> Dictionary:
	var material_type_for_id: Dictionary = {}
	var material_ids: Array[String] = []
	var tree_sources: Array[Dictionary] = []
	for index: int in range(5):
		var branch_id := MIXED_BRANCH_IDS[index]
		var log_id := MIXED_LOG_IDS[index]
		var stone_id := MIXED_STONE_IDS[index]
		var tree_id := MIXED_TREE_IDS[index]
		material_type_for_id[branch_id] = "branch"
		material_type_for_id[log_id] = "log"
		material_type_for_id[stone_id] = "stone"
		material_ids.append(branch_id)
		material_ids.append(log_id)
		material_ids.append(stone_id)
		tree_sources.append({"tree_id": tree_id, "log_id": log_id})

	var slots: Array[Dictionary] = []
	for index: int in range(5):
		slots.append({"slot_index": index, "zone": "dam_fill", "compatible_types": ["branch"]})
	for index: int in range(5):
		slots.append({"slot_index": index + 5, "zone": "dam_wall", "compatible_types": ["log"]})
	for index: int in range(5):
		slots.append({"slot_index": index + 10, "zone": "dam_base", "compatible_types": ["stone"]})

	return {
		"recipe_id": "mixed_fifteen",
		"requirements": {"branch": 5, "log": 5, "stone": 5},
		"material_ids": material_ids,
		"material_type_for_id": material_type_for_id,
		"slots": slots,
		"tree_sources": tree_sources,
	}


static func _legacy_three() -> Dictionary:
	var material_type_for_id: Dictionary = {}
	for id: String in LEGACY_MATERIAL_IDS:
		material_type_for_id[id] = "branch"

	var slots: Array[Dictionary] = []
	for index: int in range(3):
		slots.append({"slot_index": index, "zone": "dam_fill", "compatible_types": ["branch"]})

	return {
		"recipe_id": "legacy_three",
		"requirements": {"branch": 3},
		"material_ids": LEGACY_MATERIAL_IDS.duplicate(),
		"material_type_for_id": material_type_for_id,
		"slots": slots,
		"tree_sources": [],
	}
