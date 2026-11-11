extends SceneTree
## P2 construction feedback regression: one dam placement must read as a single
## sequence. The committed slot, count and save happen at the beaver's arrival;
## the branch flight, impact, structural gain, prepared water rise and stage
## celebration are presented once from the arrival signal. Uses isolated saves.
##
## The checks use string-based signal/method access so the script runs against
## the previous tree and fails on the missing coordination instead of parsing.

const DamSave = preload("res://scripts/dam_save.gd")
const TerrainScript = preload("res://scripts/valley_terrain.gd")
const LayoutScript = preload("res://scripts/valley_layout.gd")
const NavigationScript = preload("res://scripts/valley_navigation.gd")
const SCENE_PATH := "res://scenes/movement.tscn"
const TEST_ROOT := "user://construction_feedback_test/"
const DAM_PLACEMENT_SIGNAL := "placement_visual_finished"
const DAM_ARRIVAL_HANDLER := "_on_dam_placement_visual_finished"
const COMPLETION_TEXT := "A represa está pronta!"
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


func _wait_frames(condition: Callable, max_frames: int = 240) -> bool:
	for _frame in range(max_frames):
		await process_frame
		if condition.call():
			return true
	return condition.call()


func _spawn_world(directory: String) -> Node:
	root.size = Vector2i(960, 600)
	if not FileAccess.file_exists(directory.path_join(DamSave.SAVE_FILE)):
		_expect(DamSave.save_state(DamSave.empty_state(DamSave.LEGACY_RECIPE_ID), directory), "Could not seed the world with an explicit legacy recipe.")
	var world: Node = load(SCENE_PATH).instantiate()
	world.save_directory = directory
	root.add_child(world)
	await _wait(func() -> bool: return world.actor != null and world.actor.is_on_floor(), 8.0)
	return world


func _free_world(world: Node) -> void:
	if is_instance_valid(world):
		world.queue_free()
		await process_frame


func _visible_logs(world: Node) -> int:
	var environment: Variant = world.get("visual_environment")
	if environment == null or not environment.has_method("get_visible_dam_log_count"):
		return -1
	return int(environment.call("get_visible_dam_log_count"))


func _water_level(world: Node) -> float:
	return float(world.get("water_level"))


func _feedback(world: Node) -> Label:
	var label := world.get("stage_completion") as Label
	return label if label != null and label.visible else null


func _feedback_text(world: Node) -> String:
	var label := _feedback(world)
	return label.text if label != null else ""


func _feedback_visible(world: Node) -> bool:
	return _feedback(world) != null


func _finish_panel_visible(world: Node) -> bool:
	var panel := world.get("finish_panel") as Control
	return panel != null and panel.visible


func _placed_ids(directory: String) -> Array:
	return DamSave.load_state(directory)["state"]["placed_materials"]


func _two_branch_state() -> Dictionary:
	var state := DamSave.empty_state(DamSave.LEGACY_RECIPE_ID)
	state["placed_materials"] = ["branch_normal_01", "branch_normal_02"]
	return state


func _mixed_counter_text(branches_count: int, logs_count: int, stones_count: int) -> String:
	return "Pedras: %d/5\nTroncos: %d/5\nRamos: %d/5" % [stones_count, logs_count, branches_count]


func _find_free_suitable(world: Node) -> Node:
	for candidate in world.get("branches"):
		if bool(candidate.get("visible")) and int(candidate.get("state")) == CollectibleBranch.State.FREE and bool(world.call("_is_suitable_material", candidate)):
			return candidate
	return null


func _collect_and_request_place(world: Node) -> Node:
	var branch := _find_free_suitable(world)
	if branch == null and not bool(world.get("tree_cut")):
		# E2: once only the tree branch is left, the standing tree supplies it.
		if not bool(world.request_gnaw_tree()):
			return null
		if not await _wait(func() -> bool: return bool(world.get("tree_cut")), 20.0):
			return null
		branch = _find_free_suitable(world)
	if branch == null:
		return null
	if not bool(world.request_collect(branch)):
		return null
	if not await _wait(func() -> bool: return world.get("carried_branch") == branch):
		return null
	if not bool(world.request_place()):
		return null
	return branch


func _expected_slot_position(world: Node, slot_index: int) -> Vector3:
	var center: Vector3 = world.get("placement_center")
	return center + Vector3(float(slot_index - 1) * 0.48, 0.18, 0.0)


func _wait_presentation(world: Node, count: int) -> bool:
	return await _wait(func() -> bool: return _visible_logs(world) == count, 8.0)


func _placed_branches(world: Node) -> Array:
	var result: Array = []
	for candidate in world.get("branches"):
		if int(candidate.get("state")) == CollectibleBranch.State.PLACED:
			result.append(candidate)
	return result


func _deliver_mixed_material(world: Node, material_id: String, counts: Dictionary, expected_total: int) -> Node:
	var material: Node = world.get("objects_by_id").get(material_id)
	_expect(material != null, "The mixed delivery could not find %s in the object registry." % material_id)
	if material == null:
		return null
	if material_id.begins_with("log_"):
		var tree_id := "tree_" + material_id.get_slice("_", 1)
		var tree: Node = world.get("trees_by_id").get(tree_id)
		_expect(tree != null, "The log %s has no source tree %s." % [material_id, tree_id])
		if tree != null and not bool(tree.call("is_cut")):
			if not bool(world.request_gnaw_tree(tree_id)):
				_expect(false, "The source tree %s could not be selected for %s." % [tree_id, material_id])
				return null
			world.actor.follow_path(PackedVector3Array())
			if not await _wait(func() -> bool: return bool(material.visible), 20.0):
				_expect(false, "The source tree %s did not finish falling for %s." % [tree_id, material_id])
				return null
	world.actor.position = world.layout.anchor(&"spawn") + Vector3.UP * 0.05
	world.actor.follow_path(PackedVector3Array())
	var before_collection := _mixed_counter_text(counts.branch, counts.log, counts.stone)
	if not bool(world.request_collect(material)):
		_expect(false, "The mixed delivery could not collect %s (visible=%s state=%d cut_ids=%s stage=%s status=%s)." % [material_id, str(material.visible), int(material.get("state")), str(world.get("_cut_tree_ids")), world.call("_current_stage"), world.status.text])
		return null
	world.actor.follow_path(PackedVector3Array())
	if not await _wait(func() -> bool: return world.get("carried_branch") == material):
		_expect(false, "The mixed delivery did not carry %s." % material_id)
		return null
	_expect(world.progress_label.text == before_collection, "Collecting %s changed the delivered-material counters." % material_id)
	if not bool(world.request_place()):
		_expect(false, "The mixed delivery could not route %s to the dam." % material_id)
		return null
	world.actor.follow_path(PackedVector3Array())
	if not await _wait(func() -> bool: return int(world.get("placed_count")) == expected_total):
		_expect(false, "The delivery of %s did not commit as placement %d." % [material_id, expected_total])
		return null
	counts[material.material_type] += 1
	_expect(world.progress_label.text == _mixed_counter_text(counts.branch, counts.log, counts.stone), "Delivering %s did not update only its material counter." % material_id)
	if expected_total < 15:
		_expect(not bool(world.home_stage.get("is_active")), "The home activated before all 15 mixed placements were presented.")
	else:
		var already_placed: Node = null
		for candidate_id: String in world.get("objects_by_id").keys():
			var candidate: Node = world.get("objects_by_id")[candidate_id]
			if candidate != material and int(candidate.get("state")) == CollectibleBranch.State.PLACED:
				already_placed = candidate
				break
		_expect(already_placed != null, "The final-flight repeated-tap check found no other delivered object.")
		if already_placed != null:
			for _tap in range(3):
				_expect(not bool(world.request_collect(already_placed)), "A repeated tap collected another material during the final placement flight.")
			_expect(not bool(world.request_place()), "A repeated place tap started another placement during the final flight.")
			_expect(world.get("pending_branch") == null and world.get("carried_branch") == null, "A final-flight repeated tap left another material pending or carried.")
		_expect(not bool(world.home_stage.get("is_active")), "The home activated before the fifteenth placement arrived.")
		_expect(_feedback_text(world) != COMPLETION_TEXT, "The final mixed delivery celebrated before its visual arrival.")
	if not await _wait(func() -> bool: return int(world.get("_presented_dam_count")) == expected_total, 8.0):
		_expect(false, "The delivery of %s did not present placement %d." % [material_id, expected_total])
		return null
	return material


func _complete_mixed_home_food(world: Node, directory: String) -> void:
	var home: Node = world.get("home_stage")
	var parts: Array = home.get("parts")
	for slot_index in range(2):
		var part: Node = parts[slot_index]
		_expect(bool(home.call("request_collect", part)), "The completed mixed dam did not allow collection of home part %d." % slot_index)
		world.actor.follow_path(PackedVector3Array())
		_expect(await _wait(func() -> bool: return home.get("carried_part") == part), "The mixed home part %d was not carried." % slot_index)
		_expect(bool(home.call("request_place", slot_index)), "The mixed home part %d could not be placed." % slot_index)
		world.actor.follow_path(PackedVector3Array())
		_expect(await _wait(func() -> bool: return int(home.get("placed_slot_count")) == slot_index + 1), "The mixed home part %d did not persist." % slot_index)
	_expect(bool(home.call("is_complete")) and bool(world.get("food_stage").get("is_active")), "Completing the mixed home did not open the food stage.")
	var food: Node = world.get("food_stage")
	for index in range(3):
		var bundle: Node = null
		for candidate in food.get("bundles"):
			if int(candidate.get("state")) <= 1 and bool(food.call("is_bundle_suitable", candidate)):
				bundle = candidate
				break
		_expect(bundle != null, "The mixed food stage had no suitable bundle %d." % index)
		if bundle == null:
			return
		_expect(bool(food.call("request_collect", bundle)), "The mixed food bundle %d could not be collected." % index)
		world.actor.follow_path(PackedVector3Array())
		_expect(await _wait(func() -> bool: return food.get("carried_bundle") == bundle), "The mixed food bundle %d was not carried." % index)
		_expect(bool(food.call("request_place")), "The mixed food bundle %d could not be stored." % index)
		world.actor.follow_path(PackedVector3Array())
		_expect(await _wait(func() -> bool: return int(food.get("placed_count")) == index + 1), "The mixed food bundle %d did not persist." % index)
	_expect(await _wait(func() -> bool: return bool(world.get("winter_active")), 6.0), "The mixed chapter did not reach winter after food was stored.")
	_expect(str(world.get("finish_choice")).is_empty(), "The mixed dam required its optional finish choice before home, food or winter.")
	var saved_state: Dictionary = DamSave.load_state(directory)["state"]
	_expect(saved_state["home_slots"].all(func(part_id: String) -> bool: return not part_id.is_empty()) and saved_state["food_placements"].size() == 3, "The mixed chapter did not save its home and food after dam completion.")


func _check_mixed_delivery_order(order_name: String, sequence: Array[String], replay_after: bool = false) -> Dictionary:
	var directory := TEST_ROOT + "mixed_" + order_name + "/"
	_expect(DamSave.clear_save(directory), "Could not clear the %s mixed-delivery save." % order_name)
	_expect(DamSave.save_state(DamSave.new_adventure_state(), directory), "Could not seed the %s mixed-delivery save." % order_name)
	var world: Node = await _spawn_world(directory)
	var positions_by_id: Dictionary = {}
	var counts := {"branch": 0, "log": 0, "stone": 0}
	var previous_water := float(world.get("water_level"))
	_expect(world.progress_label.text == _mixed_counter_text(0, 0, 0), "The mixed HUD did not start with the three exact zero counters: %s" % world.progress_label.text)
	_expect(not bool(world.home_stage.get("is_active")), "A fresh mixed adventure activated the home stage.")
	for index in range(sequence.size()):
		var material := await _deliver_mixed_material(world, sequence[index], counts, index + 1)
		if material == null:
			break
		var material_type: String = material.get("material_type")
		var type_index: int = counts[material_type] - 1
		var expected_slot := type_index if material_type == "branch" else (5 + type_index if material_type == "log" else 10 + type_index)
		_expect(int(material.get("placed_slot")) == expected_slot, "%s used delivery-order slot %d instead of stable slot %d." % [sequence[index], int(material.get("placed_slot")), expected_slot])
		_expect(bool(material.visible), "The delivered %s silhouette is not visible." % sequence[index])
		_expect(float(material.global_position.y) >= float(world.terrain.full_water_level()) - 0.01, "The delivered %s is below the prepared maximum water surface." % sequence[index])
		positions_by_id[sequence[index]] = material.global_position
		var level := float(world.get("water_level"))
		_expect(level > previous_water, "Mixed delivery %d did not advance the prepared water presentation." % (index + 1))
		_expect(level <= float(world.terrain.full_water_level()) + 0.001, "Mixed delivery %d exceeded the prepared maximum water level." % (index + 1))
		previous_water = level
		var saved_state: Dictionary = DamSave.load_state(directory)["state"]
		_expect(saved_state["placements"].size() == index + 1, "Mixed delivery %d did not persist exactly one additional placement." % (index + 1))
		if index == sequence.size() - 1:
			_expect(bool(saved_state["stage_completed"]), "The fifteenth mixed placement was not saved as the single completion transition.")
		var saved_record: Dictionary = {}
		for candidate_record: Dictionary in saved_state["placements"]:
			if candidate_record.get("material_id", "") == sequence[index]:
				saved_record = candidate_record
				break
		var expected_zone := "dam_fill" if material_type == "branch" else ("dam_wall" if material_type == "log" else "dam_base")
		_expect(not saved_record.is_empty() and int(saved_record.get("slot_index", -1)) == expected_slot and String(saved_record.get("zone", "")) == expected_zone, "The save did not preserve %s at its stable slot and zone." % sequence[index])
		if index == sequence.size() - 2:
			_expect(not bool(world.home_stage.get("is_active")), "The fourteenth mixed placement activated the home stage.")
		if index == sequence.size() - 1:
			var pulses_before := (world.visual_environment.get("_dam_foam_pulses") as Array).size()
			world.call("_on_dam_placement_visual_finished", int(material.get("placed_slot")), int(world.get("_presentation_generation")))
			await process_frame
			_expect((world.visual_environment.get("_dam_foam_pulses") as Array).size() == pulses_before, "A repeated final-flight callback replayed placement effects.")
	if positions_by_id.size() != sequence.size():
		await _free_world(world)
		_expect(DamSave.clear_save(directory), "Could not clean the incomplete %s mixed-delivery save." % order_name)
		return {}
	_expect(counts.branch == 5 and counts.log == 5 and counts.stone == 5, "The %s order did not finish with 5/5/5 delivered counts." % order_name)
	_expect(bool(world._dam_progress.is_complete()) and int(world._dam_progress.count_for("branch")) == 5 and int(world._dam_progress.count_for("log")) == 5 and int(world._dam_progress.count_for("stone")) == 5, "The mixed progress model did not complete at exactly 5/5/5.")
	_expect(bool(world.home_stage.get("is_active")), "The home did not activate after all 15 mixed placements arrived.")
	_expect(not bool(world.food_stage.get("is_active")) and not bool(world.get("winter_active")), "Food or winter activated before the home was built.")
	_expect(_feedback_text(world) == COMPLETION_TEXT, "The fifteenth mixed arrival did not show the dam completion exactly once.")
	_expect(str(world.sfx.active_event) == "complete", "The fifteenth mixed arrival did not present the completion sound.")
	_expect(float(world.get("water_level")) <= float(world.terrain.full_water_level()) + 0.001, "The completed mixed dam exceeded the prepared water maximum.")
	var final_pulses := (world.visual_environment.get("_dam_foam_pulses") as Array).size()
	world.call("_on_dam_placement_visual_finished", int(sequence.size() - 1), int(world.get("_presentation_generation")))
	await process_frame
	_expect((world.visual_environment.get("_dam_foam_pulses") as Array).size() == final_pulses, "The completed dam emitted a second placement response.")
	if replay_after:
		await _complete_mixed_home_food(world, directory)
		await _free_world(world)
		world = await _spawn_world(directory)
		_expect(int(world.get("placed_count")) == 15 and int(world.get("_presented_dam_count")) == 15, "Replaying the mixed save did not restore all 15 placements silently.")
		_expect(not _feedback_visible(world) and str(world.sfx.active_event).is_empty() and str(world.voice.active_event).is_empty(), "Replaying the completed mixed save re-emitted placement/completion effects.")
		_expect((world.visual_environment.get("_dam_foam_pulses") as Array).is_empty(), "Replaying the completed mixed save spawned placement pulses.")
		_expect(bool(world.get("winter_active")) and bool(world.home_stage.call("is_complete")) and bool(world.food_stage.call("is_complete")), "Replaying mixed dam, home and food progress did not restore winter silently.")
		for material_id: String in positions_by_id:
			var restored: Node = world.get("objects_by_id")[material_id]
			_expect(restored.global_position.distance_to(positions_by_id[material_id]) <= 0.01, "Replaying the mixed save moved %s from its stable slot." % material_id)
			_expect(bool(restored.visible) and int(restored.get("state")) == CollectibleBranch.State.PLACED, "Replaying the mixed save hid or freed placed material %s." % material_id)
	var result := positions_by_id.duplicate(true)
	await _free_world(world)
	_expect(DamSave.clear_save(directory), "Could not clean the %s mixed-delivery save." % order_name)
	return result


func _record_signal(slot_index: int, events: Array) -> void:
	events.append(slot_index)


func _path_length(path: PackedVector3Array) -> float:
	var length := 0.0
	for index in range(1, path.size()):
		length += Vector2(path[index - 1].x, path[index - 1].z).distance_to(Vector2(path[index].x, path[index].z))
	return length


func _run() -> void:
	_expect(DamSave.clear_save(TEST_ROOT), "Could not clear the construction-feedback test root.")
	await _check_placement_signal()
	await _check_commit_presentation_split()
	await _check_repeated_targeting()
	await _check_overlapping_commits()
	await _check_interruption()
	await _check_midflight_save_and_disposal()
	await _check_final_placement()
	var stones_first := await _check_mixed_delivery_order("stones_first", ["stone_01", "stone_02", "stone_03", "stone_04", "stone_05", "log_01", "log_02", "log_03", "log_04", "log_05", "branch_01", "branch_02", "branch_03", "branch_04", "branch_05"])
	if stones_first.is_empty():
		quit(1)
		return
	var logs_first := await _check_mixed_delivery_order("logs_first", ["log_01", "log_02", "log_03", "log_04", "log_05", "branch_01", "branch_02", "branch_03", "branch_04", "branch_05", "stone_01", "stone_02", "stone_03", "stone_04", "stone_05"])
	if logs_first.is_empty():
		quit(1)
		return
	var interleaved := await _check_mixed_delivery_order("interleaved", ["branch_01", "log_01", "stone_01", "branch_02", "log_02", "stone_02", "branch_03", "log_03", "stone_03", "branch_04", "log_04", "stone_04", "branch_05", "log_05", "stone_05"], true)
	for material_id: String in interleaved:
		if stones_first.has(material_id):
			_expect(interleaved[material_id].distance_to(stones_first[material_id]) <= 0.01, "The stable slot for %s moved between interleaved and stones-first deliveries." % material_id)
		if logs_first.has(material_id):
			_expect(interleaved[material_id].distance_to(logs_first[material_id]) <= 0.01, "The stable slot for %s moved between interleaved and logs-first deliveries." % material_id)
	await _check_save_failure()
	var approach_summary: String = await _check_dam_approach()
	_expect(DamSave.clear_save(TEST_ROOT), "Could not clean up the construction-feedback save directories.")
	if failures == 0:
		print("CASTOR_CONSTRUCTION_FEEDBACK_OK signal_once commit_presentation repeated_taps overlap_reconcile interruption midflight_save disposal final_placement mixed_orders mixed_counters completion_once replay_silent save_failure %s" % approach_summary)
	quit(0 if failures == 0 else 1)


## The branch exposes one visual-completion signal: animated placements emit it
## once with their slot; instant placements and freed branches emit nothing.
func _check_placement_signal() -> void:
	var parent := Node3D.new()
	root.add_child(parent)
	var animated: CollectibleBranch = load("res://scenes/collectible_branch.tscn").instantiate()
	parent.add_child(animated)
	await process_frame
	animated.configure_branch(CollectibleBranch.Kind.NORMAL, "branch_normal_01")
	if animated.has_signal(DAM_PLACEMENT_SIGNAL):
		var animated_events: Array = []
		animated.connect(DAM_PLACEMENT_SIGNAL, _record_signal.bind(animated_events))
		animated.place(parent, Vector3(0.5, 0.3, -0.4), 1, true)
		await create_timer(0.7).timeout
		_expect(animated_events.size() == 1, "An animated placement emitted its visual-completion signal %d times instead of once." % animated_events.size())
		_expect(animated_events == [1], "The animated placement reported the wrong slot: %s." % str(animated_events))
		await create_timer(0.3).timeout
		_expect(animated_events.size() == 1, "An animated placement emitted a duplicate visual-completion signal.")
	else:
		_expect(false, "CollectibleBranch has no placement_visual_finished signal for the P2 presentation.")

	var instant: CollectibleBranch = load("res://scenes/collectible_branch.tscn").instantiate()
	parent.add_child(instant)
	await process_frame
	instant.configure_branch(CollectibleBranch.Kind.NORMAL, "branch_normal_02")
	if instant.has_signal(DAM_PLACEMENT_SIGNAL):
		var instant_events: Array = []
		instant.connect(DAM_PLACEMENT_SIGNAL, _record_signal.bind(instant_events))
		instant.place(parent, Vector3(0.5, 0.3, -0.4), 0, false)
		await create_timer(0.2).timeout
		_expect(instant_events.is_empty(), "An instant placement or restore emitted a visual-completion signal.")
	else:
		_expect(false, "CollectibleBranch has no placement_visual_finished signal; instant placement cannot be checked.")

	var freed: CollectibleBranch = load("res://scenes/collectible_branch.tscn").instantiate()
	parent.add_child(freed)
	await process_frame
	freed.configure_branch(CollectibleBranch.Kind.NORMAL, "branch_normal_03")
	if freed.has_signal(DAM_PLACEMENT_SIGNAL):
		var freed_events: Array = []
		freed.connect(DAM_PLACEMENT_SIGNAL, _record_signal.bind(freed_events))
		freed.place(parent, Vector3(0.5, 0.3, -0.4), 2, true)
		await process_frame
		freed.queue_free()
		await process_frame
		await create_timer(0.7).timeout
		_expect(freed_events.is_empty(), "A branch freed mid-flight still emitted its visual-completion signal.")
	else:
		_expect(false, "CollectibleBranch has no placement_visual_finished signal; free-mid-flight cannot be checked.")
	parent.queue_free()
	await process_frame


## The commit is durable immediately, but the logs, water and celebration follow
## the material arrival. A refresh during the flight must not advance them.
func _check_commit_presentation_split() -> void:
	var directory := TEST_ROOT + "split/"
	_expect(DamSave.clear_save(directory), "Could not clear the commit/presentation save directory.")
	var world: Node = await _spawn_world(directory)
	var initial_level: float = world.terrain.initial_water_level()
	_expect(_visible_logs(world) == 0, "A fresh dam does not start with zero visible logs.")
	var branch := await _collect_and_request_place(world)
	_expect(branch != null, "The first dam branch could not be routed for placement.")
	if branch != null:
		_expect(await _wait(func() -> bool: return int(world.get("placed_count")) == 1), "The first branch did not commit at the beaver's arrival.")
		var ids := _placed_ids(directory)
		_expect(ids.size() == 1, "The save did not hold exactly one placement immediately after the commit: %s." % str(ids))
		var committed_logs := _visible_logs(world)
		var committed_level := _water_level(world)
		_expect(committed_logs == 0, "The dam logs advanced to %d before the branch arrived." % committed_logs)
		_expect(is_equal_approx(committed_level, initial_level), "The water advanced to %.3f before the branch arrived (initial %.3f)." % [committed_level, initial_level])
		_expect(not bool(world.home_stage.is_active), "The home stage activated before the first branch arrived.")
		world.call("_refresh_chapter_interface")
		_expect(_visible_logs(world) == 0, "A chapter refresh during the flight advanced the dam logs.")
		_expect(is_equal_approx(_water_level(world), initial_level), "A chapter refresh during the flight advanced the water.")
		if world.has_method(DAM_ARRIVAL_HANDLER) and world.get("_presentation_generation") != null:
			var stale_generation := int(world.get("_presentation_generation")) - 1
			world.call(DAM_ARRIVAL_HANDLER, 0, stale_generation)
			_expect(_visible_logs(world) == 0, "A stale presentation callback advanced the dam logs.")
			_expect(is_equal_approx(_water_level(world), initial_level), "A stale presentation callback advanced the water.")
		_expect(await _wait_presentation(world, 1), "The first branch did not reveal one dam log after its arrival.")
		_expect(is_equal_approx(_water_level(world), world.terrain.intermediate_water_level()), "The first branch did not raise the lake to the intermediate level after arrival.")
		_expect(not bool(world.home_stage.is_active), "The first branch activated the home stage.")
		_expect(_feedback_text(world) != COMPLETION_TEXT, "The first branch showed the dam celebration.")
		_expect(str(world.sfx.active_event) == "place", "The first material arrival did not play the placement sound.")
		var presented: Variant = world.get("_presented_dam_count")
		if presented != null:
			_expect(int(presented) == 1, "The presented dam count did not advance to one at arrival.")
		_expect(world.has_method(DAM_ARRIVAL_HANDLER), "The world has no presentation-generation arrival handler.")
	await _free_world(world)
	_expect(DamSave.clear_save(directory), "Could not clean the commit/presentation save directory.")


## Repeated taps while walking and during the flight must still produce one
## placed branch, one count and one save entry.
func _check_repeated_targeting() -> void:
	var directory := TEST_ROOT + "repeated/"
	_expect(DamSave.clear_save(directory), "Could not clear the repeated-targeting save directory.")
	var world: Node = await _spawn_world(directory)
	var branch := _find_free_suitable(world)
	_expect(branch != null, "The repeated-targeting check found no suitable branch.")
	if branch != null:
		_expect(bool(world.request_collect(branch)), "The repeated-targeting branch could not be selected.")
		_expect(await _wait(func() -> bool: return world.get("carried_branch") == branch), "The repeated-targeting branch was not carried.")
		_expect(bool(world.request_place()) and bool(world.request_place()), "Repeated dam targeting while walking was refused.")
		_expect(await _wait(func() -> bool: return int(world.get("placed_count")) == 1), "The repeated-targeting branch did not commit once.")
		_expect(not bool(world.request_place()), "A placement request during the flight was accepted as a second placement.")
		_expect(await _wait_presentation(world, 1), "The repeated-targeting placement never presented.")
		_expect(int(world.get("placed_count")) == 1, "Repeated targeting placed more than one branch.")
		_expect(_placed_branches(world).size() == 1, "Repeated targeting left more than one placed branch in the dam.")
		var ids := _placed_ids(directory)
		_expect(ids.size() == 1, "Repeated targeting produced %d save entries instead of one." % ids.size())
	await _free_world(world)
	_expect(DamSave.clear_save(directory), "Could not clean the repeated-targeting save directory.")


## If two placements commit before the first material arrives, the surviving
## response reconciles once to the latest committed count and never lowers the
## visible water or replays an older response.
func _check_overlapping_commits() -> void:
	var directory := TEST_ROOT + "overlap/"
	_expect(DamSave.clear_save(directory), "Could not clear the overlapping-commit save directory.")
	var world: Node = await _spawn_world(directory)
	var first: Node = null
	var second: Node = null
	for candidate in world.get("branches"):
		if int(candidate.get("state")) != CollectibleBranch.State.FREE or not bool(world.call("_is_suitable_material", candidate)):
			continue
		if first == null:
			first = candidate
		elif second == null:
			second = candidate
	_expect(first != null and second != null, "The overlapping-commit check found fewer than two suitable branches.")
	if first != null and second != null:
		# Commit both placements inside the first 0.45 s flight window.
		world.carried_branch = first
		world.placement_pending = true
		_expect(await _wait(func() -> bool: return int(world.get("placed_count")) == 1), "The first overlapping placement did not commit.")
		world.carried_branch = second
		world.placement_pending = true
		_expect(await _wait(func() -> bool: return int(world.get("placed_count")) == 2), "The second overlapping placement did not commit in the first flight window.")
		_expect(_visible_logs(world) == 0, "An overlapping commit presented structure before any material arrived.")
		_expect(await _wait_presentation(world, 2), "The overlapping placements did not reconcile to two visible logs.")
		_expect(is_equal_approx(_water_level(world), world.terrain.full_water_level()), "Overlapping placements did not reconcile the water to the latest committed level.")
		_expect(int(world.get("_presented_dam_count")) == 2, "Overlapping placements did not reconcile the presented count.")
		_expect(_feedback_text(world) != COMPLETION_TEXT, "Overlapping placements replayed a stage completion.")
		_expect(_placed_ids(directory).size() == 2, "Overlapping placements did not save both committed branches once.")
	await _free_world(world)
	_expect(DamSave.clear_save(directory), "Could not clean the overlapping-commit save directory.")


## A ground move during the committed flight may cancel the gesture, but the
## branch keeps its committed slot and the world response still appears.
func _check_interruption() -> void:
	var directory := TEST_ROOT + "interruption/"
	_expect(DamSave.clear_save(directory), "Could not clear the interruption save directory.")
	var world: Node = await _spawn_world(directory)
	var branch := await _collect_and_request_place(world)
	_expect(branch != null, "The interruption branch could not be routed for placement.")
	if branch != null:
		_expect(await _wait(func() -> bool: return int(world.get("placed_count")) == 1), "The interruption branch did not commit.")
		var committed_position := _expected_slot_position(world, 0)
		_expect(bool(world.request_move(world.layout.anchor(&"spawn"))), "A ground move during the flight was refused.")
		_expect(await _wait_presentation(world, 1), "The interrupted placement never produced its structural response.")
		await create_timer(0.8).timeout
		_expect(branch.get_parent() == world, "The interrupted branch was returned to the actor or its origin.")
		_expect(int(branch.get("state")) == CollectibleBranch.State.PLACED, "The interrupted branch left the placed state.")
		_expect(branch.global_position.distance_to(committed_position) <= 0.02, "The interrupted branch did not finish at its committed slot.")
		_expect(branch.global_position.distance_to(branch.origin) > 0.5, "The interrupted branch was returned to its origin.")
		_expect(int(world.get("placed_count")) == 1 and _placed_branches(world).size() == 1, "The interrupted placement was duplicated or lost.")
		_expect(is_equal_approx(_water_level(world), world.terrain.intermediate_water_level()), "The interrupted placement lost its water response.")
	await _free_world(world)
	_expect(DamSave.clear_save(directory), "Could not clean the interruption save directory.")


## A save captured during the flight must restore the final placement silently;
## freeing the world mid-flight must not call back into the disposed scene.
func _check_midflight_save_and_disposal() -> void:
	var directory := TEST_ROOT + "midflight/"
	_expect(DamSave.clear_save(directory), "Could not clear the mid-flight save directory.")
	var world: Node = await _spawn_world(directory)
	var branch := await _collect_and_request_place(world)
	_expect(branch != null, "The mid-flight branch could not be routed for placement.")
	if branch == null:
		await _free_world(world)
		return
	_expect(await _wait(func() -> bool: return int(world.get("placed_count")) == 1), "The mid-flight branch did not commit.")
	var ids := _placed_ids(directory)
	_expect(ids.size() == 1, "The mid-flight save does not hold the committed placement: %s." % str(ids))
	var disposed_ok: bool = false
	world.queue_free()
	await process_frame
	await create_timer(0.7).timeout
	disposed_ok = not is_instance_valid(world)
	_expect(disposed_ok, "Freed world was still valid after the flight window.")

	var restored: Node = await _spawn_world(directory)
	_expect(int(restored.get("placed_count")) == 1, "Restoring the mid-flight save did not show exactly one placement.")
	_expect(_visible_logs(restored) == 1, "Restoring the mid-flight save did not show one dam log.")
	_expect(is_equal_approx(_water_level(restored), restored.terrain.intermediate_water_level()), "Restoring the mid-flight save did not show the intermediate water level.")
	_expect(_feedback(restored) == null, "Restoring the mid-flight save replayed a transient message.")
	_expect(not _finish_panel_visible(restored), "Restoring the mid-flight save opened the finish panel.")
	_expect(str(restored.voice.active_event).is_empty(), "Restoring the mid-flight save replayed narration.")
	_expect(str(restored.sfx.active_event).is_empty(), "Restoring the mid-flight save replayed a placement sound.")
	var loaded := _placed_branches(restored)
	_expect(loaded.size() == 1, "Restoring the mid-flight save did not place the branch exactly once.")
	if loaded.size() == 1:
		_expect(loaded[0].global_position.distance_to(_expected_slot_position(restored, 0)) <= 0.01, "The restored mid-flight branch is not at its final slot transform.")
	await _free_world(restored)
	_expect(DamSave.clear_save(directory), "Could not clean the mid-flight save directory.")


## The final placement keeps the two visible logs and full lake until arrival,
## then confirms the last structural step, celebrates and opens the panel.
func _check_final_placement() -> void:
	var directory := TEST_ROOT + "final/"
	_expect(DamSave.clear_save(directory), "Could not clear the final-placement save directory.")
	_expect(DamSave.save_state(_two_branch_state(), directory), "Could not prepare the two-branch save.")
	var world: Node = await _spawn_world(directory)
	var full_level: float = world.terrain.full_water_level()
	_expect(int(world.get("placed_count")) == 2 and _visible_logs(world) == 2, "The two-branch fixture did not restore two dam logs.")
	_expect(is_equal_approx(_water_level(world), full_level), "The two-branch fixture did not restore the full lake.")
	var branch := await _collect_and_request_place(world)
	_expect(branch != null, "The final dam branch could not be routed for placement.")
	if branch != null:
		_expect(await _wait(func() -> bool: return int(world.get("placed_count")) == 3), "The final branch did not commit.")
		_expect(_visible_logs(world) == 2, "The final dam log appeared before the branch arrived (%d visible)." % _visible_logs(world))
		world.call("_refresh_chapter_interface")
		_expect(_visible_logs(world) == 2, "A chapter refresh advanced the final dam log early.")
		_expect(is_equal_approx(_water_level(world), full_level), "The final commit changed the already-full lake.")
		_expect(await _wait_presentation(world, 3), "The final material arrival did not reveal the third dam log.")
		_expect(is_equal_approx(_water_level(world), full_level), "The final arrival lowered or changed the full lake level.")
		var rise: Variant = world.get("water_rise_tween")
		var rise_finished := rise == null
		if rise is Tween:
			rise_finished = not (rise as Tween).is_running()
		_expect(rise_finished, "The final arrival started an unnecessary water rise.")
		_expect(_feedback_text(world) == COMPLETION_TEXT, "The final arrival did not show the dam celebration.")
		_expect(bool(world.home_stage.is_active), "The home stage did not activate after the final response.")
		_expect(not _finish_panel_visible(world), "The finish panel opened before the celebration.")
		await _wait_frames(func() -> bool: return false, 60)
		_expect(not _finish_panel_visible(world), "The finish panel opened before the two-second celebration ended.")
		_expect(await _wait_frames(func() -> bool: return _finish_panel_visible(world), 180), "The finish panel did not open after the dam celebration.")
	await _free_world(world)
	_expect(DamSave.clear_save(directory), "Could not clean the final-placement save directory.")


## A forced save failure must stay visible at the commit and through the delayed
## response and celebration, without replacing the celebration itself.
func _check_save_failure() -> void:
	var directory := TEST_ROOT + "save_failure/"
	_expect(DamSave.clear_save(directory), "Could not clear the save-failure save directory.")
	_expect(DamSave.save_state(_two_branch_state(), directory), "Could not prepare the save-failure two-branch save.")
	var world: Node = await _spawn_world(directory)
	world.save_directory = "res://unsafe"
	var branch := await _collect_and_request_place(world)
	_expect(branch != null, "The save-failure branch could not be routed for placement.")
	if branch != null:
		_expect(await _wait(func() -> bool: return int(world.get("placed_count")) == 3), "The save-failure branch did not commit.")
		var warning := "Não foi possível guardar o progresso. Pede ajuda a um adulto."
		_expect(world.status.text == warning, "The forced save failure was not visible at the commit: %s." % world.status.text)
		_expect(await _wait(func() -> bool: return _feedback_text(world) == COMPLETION_TEXT), "The save-failure final arrival did not celebrate.")
		_expect(world.status.text == warning, "The save warning disappeared when the material arrived.")
		_expect(_feedback_text(world) == COMPLETION_TEXT, "The save warning replaced the dam celebration.")
		_expect(await _wait_frames(func() -> bool: return _finish_panel_visible(world), 240), "The finish panel did not open after the save-failure celebration.")
		_expect(world.status.text == warning, "The save warning disappeared during the celebration or panel.")
		world.save_directory = directory
		_expect(bool(world.call("_save_dam_state")), "The isolated save directory was not restored after the forced failure.")
		world.call("_refresh_chapter_interface")
		_expect(world.status.text != warning, "The save warning stayed visible after a successful save.")
	await _free_world(world)
	_expect(DamSave.clear_save(directory), "Could not clean the save-failure save directory.")


## Compare the current dry dam approach with the closest connected dry bank
## candidate. The candidate must stay out of the lake footprint, remain walkable,
## keep every route reachable and not overlap the dam crest target footprint.
func _check_dam_approach() -> String:
	var terrain = TerrainScript.new()
	terrain.configure(&"wide_bank")
	var layout = LayoutScript.new()
	layout.configure(terrain)
	var navigation = NavigationScript.new()
	navigation.configure(terrain, layout)
	var spawn: Vector3 = layout.anchor(&"spawn")
	var lodge: Vector3 = layout.anchor(&"lodge")
	var clearing: Vector3 = layout.anchor(&"branch_clearing")
	var food: Vector3 = layout.anchor(&"food_bank")
	var dam_center: Vector3 = layout.dam_center()
	var old_xz := Vector2(0.0, -0.2)
	var current_xz: Vector2 = layout.anchor_xz(&"dam_approach")
	var current_point: Vector3 = layout.anchor(&"dam_approach")

	_expect(not terrain.is_water_footprint(current_xz), "The dam approach sits in the maximum lake footprint.")
	_expect(navigation.is_walkable(current_xz), "The dam approach is not walkable.")
	_expect(terrain.slope_degrees(current_xz) <= ValleyTerrain.ROUTE_SLOPE_LIMIT_DEGREES, "The dam approach exceeds the route slope limit.")
	_expect(_clear_of_dam_crest(current_xz, dam_center), "The dam approach placement area overlaps the dam crest target.")
	_expect(not navigation.find_path(spawn, current_point).is_empty(), "The spawn cannot reach the dam approach.")
	_expect(not navigation.find_path(lodge, current_point).is_empty(), "The lodge cannot reach the dam approach.")
	_expect(not navigation.find_path(clearing, current_point).is_empty(), "The collection area cannot reach the dam approach.")
	for anchor_id: StringName in [&"branch_clearing", &"dam_approach", &"lodge", &"food_bank"]:
		_expect(not navigation.find_path(spawn, layout.anchor(anchor_id)).is_empty(), "The spawn lost its route to %s." % anchor_id)
	_expect(not navigation.find_path(lodge, food).is_empty(), "The lodge lost its route to the food bank.")

	var closest_any := Vector2.INF
	var closest_clear := Vector2.INF
	var closest_any_gap := INF
	var closest_clear_gap := INF
	var x := -4.5
	while x <= 2.5:
		var z := -4.5
		while z <= 2.5:
			var xz := Vector2(snappedf(x, 0.001), snappedf(z, 0.001))
			z += 0.1
			if terrain.is_water_footprint(xz):
				continue
			if terrain.slope_degrees(xz) > ValleyTerrain.ROUTE_SLOPE_LIMIT_DEGREES or not navigation.is_walkable(xz):
				continue
			var point := Vector3(xz.x, terrain.height_at(xz), xz.y)
			if navigation.find_path(spawn, point).is_empty() or navigation.find_path(lodge, point).is_empty():
				continue
			var gap := xz.distance_to(Vector2(dam_center.x, dam_center.z))
			if gap < closest_any_gap:
				closest_any_gap = gap
				closest_any = xz
			if _clear_of_dam_crest(xz, dam_center) and gap < closest_clear_gap:
				closest_clear_gap = gap
				closest_clear = xz
		x += 0.1
	_expect(closest_any.is_finite(), "No connected dry bank candidate was found for the dam approach comparison.")
	_expect(closest_clear.is_finite(), "No connected dry bank candidate cleared the dam crest target.")
	_expect(not _clear_of_dam_crest(closest_any, dam_center) or closest_any.is_equal_approx(closest_clear), "The closest dry bank candidate overlaps the dam crest target.")

	var old_point := Vector3(old_xz.x, terrain.height_at(old_xz), old_xz.y)
	var old_walk := _path_length(navigation.find_path(spawn, old_point)) \
		+ _path_length(navigation.find_path(lodge, old_point)) \
		+ _path_length(navigation.find_path(clearing, old_point))
	var current_walk := _path_length(navigation.find_path(spawn, current_point)) \
		+ _path_length(navigation.find_path(lodge, current_point)) \
		+ _path_length(navigation.find_path(clearing, current_point))
	var candidate_point := Vector3(closest_clear.x, terrain.height_at(closest_clear), closest_clear.y)
	var candidate_walk := _path_length(navigation.find_path(spawn, candidate_point)) \
		+ _path_length(navigation.find_path(lodge, candidate_point)) \
		+ _path_length(navigation.find_path(clearing, candidate_point))
	var old_gap := old_xz.distance_to(Vector2(dam_center.x, dam_center.z))
	var current_gap := current_xz.distance_to(Vector2(dam_center.x, dam_center.z))
	var candidate_gap := closest_clear.distance_to(Vector2(dam_center.x, dam_center.z))

	if current_xz.is_equal_approx(old_xz):
		_expect(candidate_walk >= old_walk, "The closest safe candidate improves total walking; the dam approach should have moved.")
	else:
		_expect(current_walk <= old_walk + 0.05, "The moved dam approach does not improve total walking distance.")
		_expect(_clear_of_dam_crest(current_xz, dam_center), "The moved dam approach overlaps the dam crest target.")

	var summary := "approach_old_xz=%.2f,%.2f approach_current_xz=%.2f,%.2f approach_candidate_xz=%.2f,%.2f approach_old_gap_m=%.2f approach_current_gap_m=%.2f approach_candidate_gap_m=%.2f approach_old_walk_m=%.2f approach_current_walk_m=%.2f approach_candidate_walk_m=%.2f" % [
		old_xz.x, old_xz.y, current_xz.x, current_xz.y, closest_clear.x, closest_clear.y,
		old_gap, current_gap, candidate_gap, old_walk, current_walk, candidate_walk,
	]
	print("CASTOR_CONSTRUCTION_APPROACH " + summary)
	return summary


## The placement area is 3.2 x 2.2 m around the approach; the crest target is
## 5.6 x 1.1 m around the dam centre. They must not overlap.
func _clear_of_dam_crest(xz: Vector2, dam_center: Vector3) -> bool:
	var near_crest_x: bool = absf(xz.x - dam_center.x) < 2.8 + 1.6
	var near_crest_z: bool = absf(xz.y - (dam_center.z + 0.08)) < 0.55 + 1.1
	return not (near_crest_x and near_crest_z)
