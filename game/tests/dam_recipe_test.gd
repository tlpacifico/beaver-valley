extends SceneTree
## Focused checks for the mixed-material dam recipe and progress model.

const DamRecipe = preload("res://scripts/dam_recipe.gd")
const DamProgress = preload("res://scripts/dam_progress.gd")
var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _expect(condition: bool, description: String) -> void:
	if not condition:
		failures += 1
		push_error(description)


func _mixed_ids() -> Dictionary:
	return {
		"branches": ["branch_01", "branch_02", "branch_03", "branch_04", "branch_05"],
		"logs": ["log_01", "log_02", "log_03", "log_04", "log_05"],
		"stones": ["stone_01", "stone_02", "stone_03", "stone_04", "stone_05"],
	}


func _recipe_has_exact_materials(recipe: Dictionary, ids: Array[String]) -> bool:
	if recipe.material_ids.size() != ids.size():
		return false
	for id: String in ids:
		if not recipe.material_ids.has(id):
			return false
		if recipe.material_type_for_id.get(id, "") == "":
			return false
	return true


func _test_recipe_definitions() -> void:
	var mixed := DamRecipe.for_id("mixed_fifteen")
	_expect(mixed.recipe_id == "mixed_fifteen", "Mixed recipe ID mismatch.")
	_expect(mixed.requirements == {"branch": 5, "log": 5, "stone": 5}, "Mixed requirements mismatch.")
	var ids := _mixed_ids()
	var all_ids: Array[String] = []
	all_ids.append_array(ids.branches)
	all_ids.append_array(ids.logs)
	all_ids.append_array(ids.stones)
	_expect(_recipe_has_exact_materials(mixed, all_ids), "Mixed recipe does not declare all 15 object IDs and their types.")
	_expect(mixed.slots.size() == 15, "Mixed recipe does not declare 15 slots.")

	var legacy := DamRecipe.for_id("legacy_three")
	_expect(legacy.recipe_id == "legacy_three", "Legacy recipe ID mismatch.")
	_expect(legacy.requirements == {"branch": 3}, "Legacy requirements mismatch.")
	var legacy_ids: Array[String] = ["branch_thick_01", "branch_rotten_01", "branch_normal_01", "branch_normal_02", "branch_normal_03"]
	_expect(_recipe_has_exact_materials(legacy, legacy_ids), "Legacy recipe does not declare all save-compatible object IDs and types.")
	_expect(legacy.slots.size() == 3, "Legacy recipe does not declare 3 slots.")
	_expect(DamRecipe.for_id("unknown_recipe").is_empty(), "Unknown recipe did not return an empty dictionary.")

	# Every mixed slot must carry a zone and deterministic compatible types.
	for slot: Dictionary in mixed.slots:
		_expect(slot.has("slot_index") and slot.has("zone") and slot.has("compatible_types"), "Mixed slot record is missing fields.")


func _test_mixed_fifteen_reversed() -> void:
	var progress := DamProgress.new()
	progress.configure("mixed_fifteen")
	_expect(progress.count_for("branch") == 0 and progress.count_for("log") == 0 and progress.count_for("stone") == 0, "Fresh progress counts are not zero.")
	_expect(not progress.is_complete(), "Fresh progress reported complete.")

	var ids := _mixed_ids()
	# Place all stones first, then all logs, then all branches.
	for id: String in ids.stones:
		_expect(progress.can_place(id), "Reversed-order stone was rejected.")
		var slot := progress.place(id)
		_expect(slot >= 10 and slot <= 14, "Stone did not occupy a base slot in reversed order.")
	for id: String in ids.logs:
		_expect(progress.can_place(id), "Reversed-order log was rejected.")
		var slot := progress.place(id)
		_expect(slot >= 5 and slot <= 9, "Log did not occupy a wall slot in reversed order.")
	for id: String in ids.branches:
		_expect(progress.can_place(id), "Reversed-order branch was rejected.")
		var slot := progress.place(id)
		_expect(slot >= 0 and slot <= 4, "Branch did not occupy a fill slot in reversed order.")
	_expect(progress.is_complete(), "Reversed-order placement did not complete.")


func _test_mixed_fifteen_interleaved() -> void:
	var progress := DamProgress.new()
	progress.configure("mixed_fifteen")
	var ids := _mixed_ids()
	var transitions: int = 0
	var previous_complete: bool = false

	for index: int in range(5):
		for type: String in ["branches", "logs", "stones"]:
			var id: String = ids[type][index]
			_expect(progress.can_place(id), "Interleaved material was rejected.")
			var slot := progress.place(id)
			_expect(slot != -1, "Interleaved placement returned -1.")
			var record: Dictionary = progress.placement_records()[-1]
			_expect(record.material_id == id, "Record material_id mismatch.")
			_expect(record.material_type == _type_from_group(type), "Record material_type mismatch.")
			_expect(record.zone != "", "Record is missing a zone.")
			_expect(record.slot_index == slot, "Record slot_index mismatch.")
			var now_complete: bool = progress.is_complete()
			if now_complete and not previous_complete:
				transitions += 1
			previous_complete = now_complete

	_expect(transitions == 1, "Dam completed more than once or not at all during interleaved placement.")
	_expect(progress.is_complete(), "Interleaved order did not complete.")
	_expect(progress.count_for("branch") == 5 and progress.count_for("log") == 5 and progress.count_for("stone") == 5, "Final counts are not 5/5/5.")


func _type_from_group(group: String) -> String:
	match group:
		"branches": return "branch"
		"logs": return "log"
		"stones": return "stone"
	return ""


func _test_duplicate_and_unknown_rejection() -> void:
	var progress := DamProgress.new()
	progress.configure("mixed_fifteen")
	_expect(progress.place("branch_01") == 0, "First branch placement failed.")
	_expect(not progress.can_place("branch_01"), "Duplicate branch was accepted.")
	_expect(progress.place("branch_01") == -1, "Duplicate branch placement did not return -1.")
	_expect(not progress.can_place("branch_06"), "Unknown branch was accepted.")
	_expect(progress.place("branch_06") == -1, "Unknown branch placement did not return -1.")
	_expect(not progress.can_place("log_00"), "Unknown log was accepted.")
	_expect(not progress.can_place("stone_99"), "Unknown stone was accepted.")
	_expect(not progress.can_place(""), "Empty material ID was accepted.")
	_expect(progress.placement_records().size() == 1, "Rejection mutated the placement records.")


func _test_per_type_capacity_and_completion() -> void:
	var progress := DamProgress.new()
	progress.configure("mixed_fifteen")
	var ids := _mixed_ids()

	# Fill branches only; the dam must not be complete and other types must still be accepted.
	for id: String in ids.branches:
		_expect(progress.place(id) != -1, "Branch placement failed before type cap.")
	_expect(progress.count_for("branch") == 5, "Branch count did not reach capacity.")
	_expect(not progress.is_complete(), "Dam reported complete with only branches.")
	_expect(progress.can_place("log_01"), "Log was rejected while branch type was at capacity.")

	# Fill logs and stones in order.
	for id: String in ids.logs:
		_expect(progress.place(id) != -1, "Log placement failed before type cap.")
	for id: String in ids.stones:
		_expect(progress.place(id) != -1, "Stone placement failed before type cap.")

	_expect(progress.is_complete(), "Dam did not complete after 15 valid deliveries.")
	for id: String in ids.logs:
		_expect(not progress.can_place(id), "Already-placed log was accepted after completion.")
	_expect(progress.place("log_01") == -1, "Place after completion did not return -1.")


func _test_legacy_three() -> void:
	var progress := DamProgress.new()
	progress.configure("legacy_three")
	# The classic normal-branch composition.
	_expect(progress.place("branch_normal_01") != -1, "Legacy normal branch 1 placement failed.")
	_expect(progress.place("branch_normal_02") != -1, "Legacy normal branch 2 placement failed.")
	_expect(progress.place("branch_normal_03") != -1, "Legacy normal branch 3 placement failed.")
	_expect(progress.is_complete(), "Legacy normal-branch composition did not complete.")
	_expect(progress.place("branch_normal_01") == -1, "Legacy duplicate placement did not return -1.")

	# The tree-standing composition uses a thick and a rotten branch.
	progress.configure("legacy_three")
	_expect(progress.place("branch_thick_01") != -1, "Legacy thick branch placement failed.")
	_expect(progress.place("branch_rotten_01") != -1, "Legacy rotten branch placement failed.")
	_expect(progress.place("branch_normal_01") != -1, "Legacy normal branch in alternate composition failed.")
	_expect(progress.is_complete(), "Legacy alternate composition did not complete.")
	_expect(progress.place("branch_normal_02") == -1, "Legacy fourth branch placement did not return -1.")


func _test_configure_resets() -> void:
	var progress := DamProgress.new()
	progress.configure("mixed_fifteen")
	progress.place("branch_01")
	progress.configure("legacy_three")
	_expect(progress.count_for("branch") == 0, "Configure did not reset counts.")
	_expect(progress.placement_records().is_empty(), "Configure did not reset records.")


func _run() -> void:
	_test_recipe_definitions()
	_test_mixed_fifteen_reversed()
	_test_mixed_fifteen_interleaved()
	_test_duplicate_and_unknown_rejection()
	_test_per_type_capacity_and_completion()
	_test_legacy_three()
	_test_configure_resets()
	if failures == 0:
		print("CASTOR_DAM_RECIPE_OK recipe_definitions reversed interleaved rejection capacity completion legacy reset")
	quit(0 if failures == 0 else 1)
