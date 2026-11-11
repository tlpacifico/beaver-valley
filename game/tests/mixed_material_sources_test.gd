extends SceneTree
## Source, route and harvest regressions for the mixed dam recipe, including
## play-camera selection, narrow feedback layout and all max-water cargo trips.

const DamSave = preload("res://scripts/dam_save.gd")
const DamRecipe = preload("res://scripts/dam_recipe.gd")
const MovementWorldScript = preload("res://scripts/movement_world.gd")
const BranchTreeScript = preload("res://scripts/branch_tree.gd")

const SCENE_PATH := "res://scenes/movement.tscn"
const SAVE_DIRECTORY := "user://mixed_material_sources_test/"
const HELP_DIRECTORY := "user://mixed_material_help_test/"
const HELP_LOGS_DIRECTORY := "user://mixed_material_logs_help_test/"
const WORDING_DIRECTORY := "user://mixed_material_tree_wording_test/"
const RETARGET_DIRECTORY := "user://mixed_material_retarget_test/"
const TREE_MAX_SLOPE_DEGREES: float = 12.0
const FACING_TOLERANCE_DEGREES: float = 20.0
const MAX_ROUTE_WAIT_SECONDS: float = 12.0
const PROJECTED_COLLIDER_EDGE_MARGIN: float = 12.0

var failures: int = 0
var max_water_delivered_ids: Dictionary = {}


func _initialize() -> void:
	call_deferred("_run")


func _expect(condition: bool, description: String) -> void:
	if not condition:
		failures += 1
		push_error(description)


func _check_capture_recipe_selection() -> void:
	var capture_world: Node = MovementWorldScript.new()
	if not capture_world.has_method("_capture_recipe_id_for_args"):
		_expect(false, "The capture recipe selector is missing; capture modes cannot choose a recipe explicitly.")
		capture_world.free()
		return
	var tree_recipe: String = capture_world.call("_capture_recipe_id_for_args", ["--capture-tree"])
	_expect(tree_recipe == DamSave.MIXED_RECIPE_ID, "The tree capture does not explicitly select the mixed recipe.")
	var mixed_recipe: String = capture_world.call("_capture_recipe_id_for_args", ["--capture-mixed"])
	_expect(mixed_recipe == DamSave.MIXED_RECIPE_ID, "The mixed water capture does not select the mixed recipe.")
	var legacy_recipe: String = capture_world.call("_capture_recipe_id_for_args", ["--capture-water"])
	_expect(legacy_recipe == DamSave.LEGACY_RECIPE_ID, "The legacy water capture no longer preserves its legacy recipe.")
	if not capture_world.has_method("_capture_view_size_for_args"):
		_expect(false, "The capture harness has no device-aspect viewport sizing selector.")
	else:
		var legacy_size: Vector2i = capture_world.call("_capture_view_size_for_args", ["--capture-water"])
		_expect(legacy_size == Vector2i(960, 600), "The existing legacy capture viewport changed from 960 × 600.")
		var portrait_size: Vector2i = capture_world.call("_capture_view_size_for_args", ["--capture-tree", "--capture-portrait"])
		_expect(portrait_size == Vector2i(540, 960), "The existing portrait capture viewport changed from 540 × 960.")
		var mixed_device_size: Vector2i = capture_world.call("_capture_view_size_for_args", ["--capture-mixed-device-aspect"])
		_expect(mixed_device_size == Vector2i(1334, 600), "The device-aspect mixed capture did not use 1334 × 600.")
		var tree_device_size: Vector2i = capture_world.call("_capture_view_size_for_args", ["--capture-tree-device-aspect"])
		_expect(tree_device_size == Vector2i(1334, 600), "The device-aspect tree capture did not use 1334 × 600.")
	capture_world.free()


func _wait(condition: Callable, timeout_seconds: float = 20.0) -> bool:
	var deadline := Time.get_ticks_msec() + int(timeout_seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		await physics_frame
		if condition.call():
			return true
	return condition.call()


func _run() -> void:
	root.size = Vector2i(960, 600)
	_expect(DamSave.clear_save(SAVE_DIRECTORY), "Could not clear the isolated mixed-source save directory.")
	_expect(DamSave.clear_save(HELP_DIRECTORY), "Could not clear the isolated mixed-help save directory.")
	_expect(DamSave.clear_save(HELP_LOGS_DIRECTORY), "Could not clear the isolated logs-help save directory.")
	_expect(DamSave.clear_save(WORDING_DIRECTORY), "Could not clear the isolated tree-wording save directory.")
	_check_capture_recipe_selection()
	await _check_material_help()
	await _check_logs_only_help()
	await _check_mixed_tree_wording()
	_expect(DamSave.clear_save(RETARGET_DIRECTORY), "Could not clear the isolated retarget save directory.")
	await _check_material_wording_and_tree_retarget()
	_expect(DamSave.clear_save(RETARGET_DIRECTORY), "Could not clean the isolated retarget save directory.")
	var world := await _spawn_world()
	if world != null:
		await _check_narrow_feedback_layout(world)
		_check_mixed_tree_requests_require_ids(world)
		if _check_source_registries_and_layout(world):
			_check_source_routes_at_max_water(world)
			await _check_stone_carry_contract(world)
			await _check_facing_from_three_directions(world)
			await _check_branch_grove_round_trip(world)
			world = await _check_retarget_and_reload(world)
			if world != null:
				await _check_all_material_round_trips_at_max_water(world)
				_check_placed_material_cannot_be_recollected(world)
		if world != null:
			world.queue_free()
			await process_frame
	_expect(max_water_delivered_ids.size() == 15, "Only %d of 15 mixed materials completed an actual max-water source-to-dam trip." % max_water_delivered_ids.size())
	_expect(DamSave.clear_save(SAVE_DIRECTORY), "Could not clean the isolated mixed-source save directory.")
	_expect(DamSave.clear_save(HELP_DIRECTORY), "Could not clean the isolated mixed-help save directory.")
	_expect(DamSave.clear_save(HELP_LOGS_DIRECTORY), "Could not clean the isolated logs-help save directory.")
	_expect(DamSave.clear_save(WORDING_DIRECTORY), "Could not clean the isolated tree-wording save directory.")
	if failures == 0:
		print("CASTOR_MIXED_MATERIAL_SOURCES_OK five_trees five_logs five_branches five_stones hidden_harvest unique_cut heading retarget reload source_routes play_camera_targets tree_selectability grove_cargo_round_trips capture_recipe capture_dimensions narrow_feedback material_help logs_only_help trunk_wording material_wording tree_retarget_pending")
	quit(0 if failures == 0 else 1)


func _check_narrow_feedback_layout(world: Node) -> void:
	if not world.has_method("_layout_message_panel_for_size"):
		_expect(false, "The chapter feedback panel has no responsive layout for a narrow viewport.")
		return
	world.call("_layout_message_panel_for_size", Vector2(540, 960))
	world.stage_completion.text = "O castor leva um tronco. Escolhe outro para o trocar."
	await process_frame
	var label_rect := Rect2(world.stage_completion.position, world.stage_completion.size)
	_expect(label_rect.position.x >= 0.0 and label_rect.end.x <= 540.0, "The feedback text extends beyond the 540 px portrait view: %s." % str(label_rect))
	_expect(world.stage_completion.size.x < 540.0 and world.stage_completion.get_line_count() >= 2, "The long feedback text does not wrap inside the portrait panel.")
	world.call("_layout_message_panel_for_size", Vector2(960, 600))
	await process_frame


func _spawn_world() -> Node:
	var world: Node = load(SCENE_PATH).instantiate()
	world.save_directory = SAVE_DIRECTORY
	root.add_child(world)
	if not await _wait(func() -> bool: return world.actor != null and world.actor.is_on_floor(), 10.0):
		_expect(false, "The fresh mixed-source world did not ground the beaver.")
		return null
	return world


func _spawn_world_in(directory: String, state: Dictionary = {}) -> Node:
	if not state.is_empty():
		_expect(DamSave.save_state(state, directory), "Could not seed the isolated material-help save.")
	var world: Node = load(SCENE_PATH).instantiate()
	world.save_directory = directory
	root.add_child(world)
	if not await _wait(func() -> bool: return world.actor != null and world.actor.is_on_floor(), 10.0):
		_expect(false, "The isolated material-help world did not ground the beaver.")
		return null
	return world


func _logs_only_needed_state() -> Dictionary:
	var state := DamSave.new_adventure_state()
	var material_ids: Array[String] = []
	var placements: Array[Dictionary] = []
	for index in range(5):
		var branch_id: String = DamRecipe.MIXED_BRANCH_IDS[index]
		material_ids.append(branch_id)
		placements.append({"material_id": branch_id, "slot_index": index, "zone": "dam_fill"})
	for index in range(5):
		var stone_id: String = DamRecipe.MIXED_STONE_IDS[index]
		material_ids.append(stone_id)
		placements.append({"material_id": stone_id, "slot_index": 10 + index, "zone": "dam_base"})
	state["placed_materials"] = material_ids
	state["placements"] = placements
	_expect(DamSave.validate_state(state), "The logs-only help fixture is not a valid mixed save.")
	return state


func _check_material_help() -> void:
	var state := DamSave.new_adventure_state()
	state["cut_tree_ids"] = ["tree_01"]
	var world: Node = await _spawn_world_in(HELP_DIRECTORY, state)
	if world == null:
		return
	var stone: CollectibleBranch = world.objects_by_id.get("stone_01")
	var log_item: CollectibleBranch = world.objects_by_id.get("log_01")
	_expect(bool(world.request_place()) == false, "An empty-handed dam tap unexpectedly began placing material.")
	_expect(world.stage_completion.text == "Toca num material para o levar até à zona amarela.", "The mixed empty-handed dam tap still names a branch: %s." % world.stage_completion.text)
	_expect(str(world.voice.active_event).is_empty(), "The mixed empty-handed dam tap played branch-specific help audio.")
	_expect(bool(world.request_help()), "Help was unavailable with free mixed ground materials.")
	_expect(world.stage_completion.text == "Escolhe um material marcado a verde para levar até à represa.", "Mixed ground-material help does not describe its green cues: %s." % world.stage_completion.text)
	for material_id: String in DamRecipe.MIXED_BRANCH_IDS + DamRecipe.MIXED_STONE_IDS:
		_expect(_cue_color(world, material_id) == MovementWorldScript.HELP_CUE_COLOR, "The free required material %s was not highlighted green." % material_id)
	for material: CollectibleBranch in [stone, log_item]:
		var noun := "pedra" if material.material_type == "stone" else "tronco"
		var article := "a" if material.material_type == "stone" else "o"
		var other := "outra" if material.material_type == "stone" else "outro"
		_expect(bool(world.request_collect(material)), "The mixed %s could not enter the pending collection state." % noun)
		_expect(bool(world.request_help()), "Help was unavailable while walking to the mixed %s." % noun)
		_expect(world.stage_completion.text == "O castor vai buscar %s %s. Podes esperar ou escolher %s." % [article, noun, other], "Pending %s help is not material-specific: %s." % [noun, world.stage_completion.text])
		_expect(str(world.voice.active_event).is_empty(), "Pending %s help played branch-specific audio." % noun)
		world.actor.follow_path(PackedVector3Array())
		_expect(await _wait(func() -> bool: return world.carried_branch == material, 10.0), "The mixed %s did not become carried." % noun)
		_expect(bool(world.request_help()), "Help was unavailable while carrying the mixed %s." % noun)
		_expect(world.stage_completion.text == "Leva %s %s até à zona amarela da represa." % [article, noun], "Carried %s help is not material-specific: %s." % [noun, world.stage_completion.text])
		_expect(str(world.voice.active_event).is_empty(), "Carried %s help played branch-specific audio." % noun)
		material.return_to_origin(world)
		world.carried_branch = null
		world.pending_branch = null
		world._update_branch_cues()
	world.queue_free()
	await process_frame


func _check_logs_only_help() -> void:
	var state := _logs_only_needed_state()
	var world: Node = await _spawn_world_in(HELP_LOGS_DIRECTORY, state)
	if world == null:
		return
	_expect(world.progress_label.text == "Pedras: 5/5\nTroncos: 0/5\nRamos: 5/5", "The logs-only help fixture did not restore its intended counters.")
	_expect(bool(world.request_help()), "Help was unavailable when the mixed dam needed logs only.")
	_expect(world.stage_completion.text == "Toca numa árvore para o castor roer e fazer um tronco.", "Logs-only help did not tell the child to gnaw a tree: %s." % world.stage_completion.text)
	_expect(str(world.voice.active_event).is_empty(), "Logs-only help played a branch-specific voice line.")
	_expect(world._mixed_remaining_text() == "Ainda faltam troncos.", "Logs-only progress names the wrong missing materials: %s." % world._mixed_remaining_text())
	for tree: BranchTree in world.trees_by_id.values():
		var ring_material := tree.ground_ring.mesh.material as StandardMaterial3D if tree.ground_ring != null and tree.ground_ring.mesh != null else null
		_expect(tree.is_interactive() and tree.ground_ring.visible, "%s was not visibly interactive during logs-only help." % tree.stable_id)
		_expect(ring_material != null and ring_material.albedo_color == MovementWorldScript.HELP_CUE_COLOR, "%s ground ring was not highlighted for logs-only help." % tree.stable_id)
	world.queue_free()
	await process_frame


func _check_mixed_tree_wording() -> void:
	var world: Node = await _spawn_world_in(WORDING_DIRECTORY, DamSave.new_adventure_state())
	if world == null:
		return
	var tree: BranchTree = world.trees_by_id.get("tree_01")
	var log_item: CollectibleBranch = world.objects_by_id.get("log_01")
	_expect(not bool(world.request_collect(log_item)), "A hidden mixed log was collected before its tree fell.")
	_expect(world.stage_completion.text == "A árvore ainda está de pé. Roe a árvore para obteres o tronco.", "The hidden mixed log still uses branch wording: %s." % world.stage_completion.text)
	_expect(bool(world.request_gnaw_tree("tree_01")), "The mixed tree wording fixture could not start a gnaw.")
	_expect(await _wait(func() -> bool: return tree.is_cut() and not bool(world.get("_tree_action_running")), 20.0), "The mixed tree wording fixture did not finish the fall.")
	_expect(world.stage_completion.text == "A árvore caiu! O tronco está no chão.", "The mixed tree-fall message does not call the material a trunk: %s." % world.stage_completion.text)
	_expect(not bool(world.request_gnaw_tree("tree_01")), "The already-cut mixed tree accepted another gnaw.")
	_expect(world.stage_completion.text == "A árvore já caiu. O tronco está no chão.", "The already-cut mixed tree message does not call the material a trunk: %s." % world.stage_completion.text)
	world.queue_free()
	await process_frame


## Pickup, carry and placement feedback names the actual material, a tree tap
## retargets a pending pickup or placement instead of being ignored, and the
## post-delivery message names the types that are still missing.
func _check_material_wording_and_tree_retarget() -> void:
	var world: Node = await _spawn_world_in(RETARGET_DIRECTORY, DamSave.new_adventure_state())
	if world == null:
		return
	var stone: CollectibleBranch = world.objects_by_id.get("stone_01")
	var tree_id := "tree_02"
	_expect(world._mixed_remaining_text() == "Ainda faltam pedras, troncos e ramos.", "Fresh mixed progress names the wrong missing materials: %s." % world._mixed_remaining_text())

	_expect(bool(world.request_collect(stone)), "The stone could not enter the pending collection state.")
	_expect(world.stage_completion.text == "O castor vai buscar a pedra.", "Stone pickup feedback still names a branch: %s." % world.stage_completion.text)
	_expect(bool(world.request_gnaw_tree(tree_id)), "A tree tap was ignored while a stone pickup was pending.")
	_expect(world.pending_branch == null and stone.state == CollectibleBranch.State.FREE, "Retargeting to a tree left the stone reserved.")
	_expect(bool(world.get("_tree_pending")) and world.get("_tree_pending_id") == tree_id, "The tree tap did not become the active walk.")
	_stop_tree_walk(world)

	_expect(bool(world.request_collect(stone)), "The stone could not be collected again after the tree retarget.")
	world.actor.follow_path(PackedVector3Array())
	_expect(await _wait(func() -> bool: return world.carried_branch == stone, 10.0), "The stone did not become carried.")
	_expect(bool(world.request_collect(stone)), "Tapping the carried stone was rejected.")
	_expect(world.stage_completion.text == "A pedra já está com o castor.", "Carried-stone feedback still names a branch: %s." % world.stage_completion.text)
	_expect(bool(world.request_place()), "The carried stone could not be routed to the dam.")
	_expect(world.stage_completion.text == "O castor vai colocar a pedra.", "Stone placement feedback still names a branch: %s." % world.stage_completion.text)
	_expect(bool(world.request_gnaw_tree(tree_id)), "A tree tap was ignored while a stone placement was pending.")
	_expect(not bool(world.placement_pending) and world.carried_branch == null and stone.state == CollectibleBranch.State.FREE, "Retargeting to a tree left the stone placement pending or carried.")
	_stop_tree_walk(world)

	_expect(bool(world.request_collect(stone)), "The returned stone could not be collected for delivery.")
	world.actor.follow_path(PackedVector3Array())
	_expect(await _wait(func() -> bool: return world.carried_branch == stone, 10.0), "The returned stone did not become carried.")
	_expect(bool(world.request_place()), "The stone could not be delivered after the tree retargets.")
	_expect(await _wait(func() -> bool: return int(world.get("_presented_dam_count")) == 1, 20.0), "The stone delivery did not reach the dam.")
	_expect(world.stage_completion.text == "Boa! A água está a mudar. Ainda faltam pedras, troncos e ramos.", "Post-delivery feedback does not name the missing materials: %s." % world.stage_completion.text)
	world.queue_free()
	await process_frame


func _stop_tree_walk(world: Node) -> void:
	world._cancel_tree_pending()
	world.actor.follow_path(PackedVector3Array())
	world.destination.visible = false
	world._update_branch_cues()


func _check_mixed_tree_requests_require_ids(world: Node) -> void:
	var accepted: bool = world.request_gnaw_tree()
	_expect(not accepted, "A mixed-recipe tree request without an ID harvested an arbitrary tree.")
	_expect(not world.get("_tree_pending") and not world.get("_tree_action_running"), "An ID-less mixed tree request left a tree action active.")
	if accepted:
		world._cancel_tree_pending()
		world.actor.follow_path(PackedVector3Array())
		world.destination.visible = false
		world._update_branch_cues()


func _check_source_registries_and_layout(world: Node) -> bool:
	_expect(world.get("_save_recipe_id") == DamSave.MIXED_RECIPE_ID, "A fresh adventure did not select mixed_fifteen.")
	var trees_value: Variant = world.get("trees_by_id")
	var objects_value: Variant = world.get("objects_by_id")
	_expect(trees_value is Dictionary, "The world does not expose an ID-to-tree registry.")
	_expect(objects_value is Dictionary, "The world does not expose an ID-to-object registry.")
	if not trees_value is Dictionary or not objects_value is Dictionary:
		return false
	var trees: Dictionary = trees_value
	var objects: Dictionary = objects_value
	_expect(trees.size() == 5, "The world registry exposes %d trees instead of five." % trees.size())
	_expect(objects.size() == 15, "The world registry exposes %d mixed objects instead of 15." % objects.size())
	_expect(world.branches.size() == 15, "The shared collectible lifecycle exposes %d mixed objects instead of 15." % world.branches.size())
	if trees.size() != 5 or objects.size() != 15:
		return false

	var type_counts := {"branch": 0, "log": 0, "stone": 0}
	var source_positions: Array[Vector2] = []
	for material_id: String in DamRecipe.MIXED_BRANCH_IDS + DamRecipe.MIXED_LOG_IDS + DamRecipe.MIXED_STONE_IDS:
		var item: Variant = objects.get(material_id)
		_expect(item is CollectibleBranch, "The material registry has no collectible for %s." % material_id)
		if not item is CollectibleBranch:
			continue
		var material := item as CollectibleBranch
		var material_type: String = material.get("material_type")
		_expect(DamRecipe.for_id(DamSave.MIXED_RECIPE_ID).material_type_for_id.get(material_id) == material_type, "%s has material_type %s inconsistent with its recipe." % [material_id, material_type])
		type_counts[material_type] = int(type_counts.get(material_type, 0)) + 1
		_expect(material.stable_id == material_id, "The material registry mapped %s to object %s." % [material_id, material.stable_id])
		_expect(_has_full_size_tap_target(material), "%s has a reduced or missing tap target." % material_id)
		_check_projected_material_collider(world, material)
		source_positions.append(Vector2(material.global_position.x, material.global_position.z))
		var cue: Variant = world.branch_cues[world.branches.find(material)] if world.branches.has(material) else null
		if material_type == "log":
			_expect(not material.visible, "%s is visible before its tree is harvested." % material_id)
			_expect(material.hit_area != null and material.hit_area.collision_layer == 0, "%s is collectable while hidden." % material_id)
			_expect(cue is MeshInstance3D and not (cue as MeshInstance3D).visible, "%s shows a pickup cue while its log is hidden." % material_id)
		elif material_type == "stone":
			_expect(material.visible, "%s is not visible as a ground source." % material_id)
			_expect(cue is MeshInstance3D and (cue as MeshInstance3D).visible, "%s has no visible collection cue." % material_id)
			_expect(_has_distinct_material_visual(material), "%s has no distinct stone model." % material_id)
		else:
			_expect(material.visible, "%s is not visible as a ground branch." % material_id)
			_expect(cue is MeshInstance3D and (cue as MeshInstance3D).visible, "%s has no visible collection cue." % material_id)
		_expect(world.navigation.is_walkable(Vector2(material.global_position.x, material.global_position.z)), "%s is not on a reachable ground point." % material_id)
	_expect(type_counts == {"branch": 5, "log": 5, "stone": 5}, "The world does not expose exactly five objects of each material type: %s." % str(type_counts))
	for first_index in range(source_positions.size()):
		for second_index in range(first_index + 1, source_positions.size()):
			_expect(source_positions[first_index].distance_to(source_positions[second_index]) >= 1.25, "Two required material tap targets overlap or nearly touch.")
	_check_distinct_stone_models(world)
	_expect(_cue_color(world, "branch_01") != _cue_color(world, "stone_01"), "Stone collection cues are indistinguishable from branch cues.")
	_expect(_cue_color(world, "log_01") != _cue_color(world, "stone_01"), "Stone collection cues are indistinguishable from log cues.")

	var tree_records: Array = world.layout.tree_sources()
	_expect(tree_records.size() == 5, "The layout authors %d mixed tree records instead of five." % tree_records.size())
	if tree_records.size() != 5:
		return false
	var seen_tree_ids: Dictionary = {}
	var seen_log_ids: Dictionary = {}
	for record: Dictionary in tree_records:
		var tree_id: String = record.get("tree_id", "")
		var log_id: String = record.get("log_id", "")
		_expect(not seen_tree_ids.has(tree_id), "The layout repeats tree ID %s." % tree_id)
		_expect(not seen_log_ids.has(log_id), "The layout assigns log ID %s more than once." % log_id)
		seen_tree_ids[tree_id] = true
		seen_log_ids[log_id] = true
		var tree: Variant = trees.get(tree_id)
		var log_item: Variant = objects.get(log_id)
		_expect(tree is BranchTree and log_item is CollectibleBranch, "The source record %s does not resolve to one tree and one log." % tree_id)
		if not tree is BranchTree or not log_item is CollectibleBranch:
			continue
		_expect(tree.stable_id == tree_id and tree.log_id == log_id, "%s does not own its declared stable log identity." % tree_id)
		_expect(tree.find_children("*", "PhysicsBody3D", true, false).is_empty(), "%s adds a blocking physics body." % tree_id)
		var authored_direction: Vector3 = record.get("fall_direction", Vector3.ZERO).normalized()
		_expect(tree.fall_direction.dot(authored_direction) >= 0.99, "%s does not use its authored fall direction." % tree_id)
		_expect(tree_records_are_safe(world, record), "%s has an unsafe work, landing or fall point." % tree_id)
		_expect(not world.request_collect(log_item), "%s was collected before its tree fell." % log_id)
		_expect(not (log_item as CollectibleBranch).visible, "%s was revealed by a rejected hidden-log collection." % log_id)
	_expect(seen_tree_ids.size() == 5 and seen_log_ids.size() == 5, "The five tree records do not have five unique tree/log IDs.")
	return true


## Every required pickup and every tree work point must have a route out and
## back to construction. Navigation excludes the maximum water footprint from
## the start of play, so these dry paths remain valid at all prepared levels.
func _check_source_routes_at_max_water(world: Node) -> void:
	var spawn: Vector3 = world.layout.anchor(&"spawn")
	var dam_approach: Vector3 = world.layout.anchor(&"dam_approach")
	var source_ids: Array[String] = DamRecipe.MIXED_BRANCH_IDS + DamRecipe.MIXED_LOG_IDS + DamRecipe.MIXED_STONE_IDS
	for material_id: String in source_ids:
		var material: CollectibleBranch = world.objects_by_id.get(material_id)
		if material == null:
			continue
		var source_xz := Vector2(material.global_position.x, material.global_position.z)
		var screen_position: Vector2 = world.camera.unproject_position(material.global_position + Vector3.UP * 0.2)
		_expect(not world.camera.is_position_behind(material.global_position) and screen_position.x >= 24.0 and screen_position.x <= 936.0 and screen_position.y >= 24.0 and screen_position.y <= 576.0, "%s is outside the 24 px play-camera tap margin at %s." % [material_id, str(screen_position)])
		if material.material_type != "log" and material.visible:
			_expect_unmasked_pickup_ray_hits(world, material)
		var outbound: PackedVector3Array = world.navigation.find_approach(spawn, source_xz, 4)
		var return_path: PackedVector3Array = world.navigation.find_approach(material.global_position, Vector2(dam_approach.x, dam_approach.z), 4)
		_expect(not outbound.is_empty(), "%s has no reachable pickup approach from spawn." % material_id)
		_expect(not return_path.is_empty(), "%s has no dry return route to the construction approach." % material_id)
		_check_route_stays_above_full_water(world, outbound, "%s outbound" % material_id)
		_check_route_stays_above_full_water(world, return_path, "%s return" % material_id)

	for record: Dictionary in world.layout.tree_sources():
		var tree_id: String = record.get("tree_id", "")
		var tree: BranchTree = world.trees_by_id.get(tree_id)
		var work_xz: Vector2 = record.get("work_xz", Vector2.ZERO)
		var work: Vector3 = world.layout.tree_point(work_xz)
		if tree != null:
			var target := tree.global_position + Vector3.UP * 0.8
			var screen: Vector2 = world.camera.unproject_position(target)
			var ray_origin: Vector3 = world.camera.project_ray_origin(screen)
			var ray_end: Vector3 = ray_origin + world.camera.project_ray_normal(screen) * 100.0
			var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
			query.collision_mask = 0xffffffff
			query.collide_with_areas = true
			var hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(query)
			_expect(hit.get("collider") == tree.hit_area, "%s is occluded or misses its play-camera tap point at %s." % [tree_id, str(screen)])
			_check_projected_tree_collider(world, tree)
		var route_to_work: PackedVector3Array = world.navigation.find_path(spawn, work)
		var route_from_work: PackedVector3Array = world.navigation.find_approach(work, Vector2(dam_approach.x, dam_approach.z), 4)
		_expect(not route_to_work.is_empty(), "%s has no dry route from spawn to its gnaw work point." % tree_id)
		_expect(not route_from_work.is_empty(), "%s has no dry route from its work point back to construction." % tree_id)
		_check_route_stays_above_full_water(world, route_to_work, "%s gnaw outbound" % tree_id)
		_check_route_stays_above_full_water(world, route_from_work, "%s gnaw return" % tree_id)


func _check_route_stays_above_full_water(world: Node, path: PackedVector3Array, label: String) -> void:
	for point: Vector3 in path:
		var xz := Vector2(point.x, point.z)
		_expect(world.navigation.is_walkable(xz), "%s crosses a blocked navigation cell at %s." % [label, str(xz)])
		_expect(world.terrain.height_at(xz) >= world.terrain.full_water_level() + 0.02, "%s crosses ground flooded at the maximum prepared level at %s." % [label, str(xz)])


func _expect_unmasked_pickup_ray_hits(world: Node, material: CollectibleBranch) -> void:
	var target := material.global_position + Vector3.UP * 0.2
	var screen: Vector2 = world.camera.unproject_position(target)
	var ray_origin: Vector3 = world.camera.project_ray_origin(screen)
	var ray_end: Vector3 = ray_origin + world.camera.project_ray_normal(screen) * 100.0
	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	query.collision_mask = 0xffffffff
	query.collide_with_areas = true
	var hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(query)
	_expect(hit.get("collider") == material.hit_area, "%s is occluded by a foreground collider or misses its play-camera tap point at %s." % [material.stable_id, str(screen)])


func _check_projected_material_collider(world: Node, material: CollectibleBranch) -> void:
	var collision: CollisionShape3D = null
	for child in material.hit_area.get_children():
		if child is CollisionShape3D and child.shape is BoxShape3D:
			collision = child as CollisionShape3D
			break
	_expect(collision != null, "%s has no box collider whose projected extents can be checked." % material.stable_id)
	if collision == null:
		return
	var box := collision.shape as BoxShape3D
	var half := box.size * 0.5
	for x_sign in [-1.0, 1.0]:
		for y_sign in [-1.0, 1.0]:
			for z_sign in [-1.0, 1.0]:
				var corner := collision.global_transform * Vector3(half.x * x_sign, half.y * y_sign, half.z * z_sign)
				var screen: Vector2 = world.camera.unproject_position(corner)
				_expect(not world.camera.is_position_behind(corner) and screen.x >= PROJECTED_COLLIDER_EDGE_MARGIN and screen.x <= 960.0 - PROJECTED_COLLIDER_EDGE_MARGIN and screen.y >= PROJECTED_COLLIDER_EDGE_MARGIN and screen.y <= 600.0 - PROJECTED_COLLIDER_EDGE_MARGIN, "%s collider corner is outside the %d px landscape margin at %s." % [material.stable_id, int(PROJECTED_COLLIDER_EDGE_MARGIN), str(screen)])


func _check_projected_tree_collider(world: Node, tree: BranchTree) -> void:
	var radius := BranchTree.HIT_RADIUS
	for angle_index in range(8):
		var angle := TAU * float(angle_index) / 8.0
		for height in [0.0, BranchTree.HIT_HEIGHT]:
			var point := tree.global_position + Vector3(cos(angle) * radius, height, sin(angle) * radius)
			var screen: Vector2 = world.camera.unproject_position(point)
			_expect(not world.camera.is_position_behind(point) and screen.x >= PROJECTED_COLLIDER_EDGE_MARGIN and screen.x <= 960.0 - PROJECTED_COLLIDER_EDGE_MARGIN and screen.y >= PROJECTED_COLLIDER_EDGE_MARGIN and screen.y <= 600.0 - PROJECTED_COLLIDER_EDGE_MARGIN, "%s collider edge is outside the %d px landscape margin at %s." % [tree.stable_id, int(PROJECTED_COLLIDER_EDGE_MARGIN), str(screen)])


func _has_distinct_material_visual(material: CollectibleBranch) -> bool:
	for child in material.find_children("*", "MeshInstance3D", true, false):
		if child is MeshInstance3D and (child as MeshInstance3D).visible and not String(child.name).to_lower().contains("ring"):
			return true
	return false


func _has_full_size_tap_target(material: CollectibleBranch) -> bool:
	if material.hit_area == null:
		return false
	for child in material.hit_area.get_children():
		if child is CollisionShape3D and (child as CollisionShape3D).shape is BoxShape3D:
			var size: Vector3 = ((child as CollisionShape3D).shape as BoxShape3D).size
			return size.x >= 1.25 and size.z >= 1.25
	return false


func _check_distinct_stone_models(world: Node) -> void:
	var scales: Array[Vector3] = []
	var colors: Array[Color] = []
	for stone_id: String in DamRecipe.MIXED_STONE_IDS:
		var stone: CollectibleBranch = world.objects_by_id.get(stone_id)
		var model := stone.find_child("CollectibleStoneModel", true, false) as MeshInstance3D if stone != null else null
		_expect(model != null and model.mesh is SphereMesh, "%s has no small standalone stone mesh." % stone_id)
		if model == null or not model.mesh is SphereMesh:
			continue
		var sphere := model.mesh as SphereMesh
		var material := sphere.material as StandardMaterial3D
		_expect(material != null, "%s has no stone material." % stone_id)
		for previous_index in range(scales.size()):
			_expect(model.scale.distance_to(scales[previous_index]) > 0.05, "%s repeats another stone's model proportions." % stone_id)
			_expect(material == null or material.albedo_color != colors[previous_index], "%s repeats another stone's model colour." % stone_id)
		scales.append(model.scale)
		colors.append(material.albedo_color if material != null else Color.BLACK)


func _cue_color(world: Node, material_id: String) -> Color:
	var material: CollectibleBranch = world.objects_by_id.get(material_id)
	if material == null:
		return Color.BLACK
	var cue: MeshInstance3D = world.branch_cues[world.branches.find(material)]
	var torus := cue.mesh as TorusMesh
	var standard := torus.material as StandardMaterial3D if torus != null else null
	return standard.albedo_color if standard != null else Color.BLACK


## The test-only full-water surface fixture leaves recipe/progression state alone.
## Navigation already excludes this maximum footprint in normal play.
func _set_route_water_to_maximum(world: Node) -> void:
	var maximum: float = world.terrain.full_water_level()
	if world.water_rise_tween != null:
		world.water_rise_tween.kill()
		world.water_rise_tween = null
	world.water_level = maximum
	world.water_surface.position.y = 0.0
	world.water_surface.mesh = world.terrain.water_mesh_reach(maximum, true, world.layout.food_cache_xz(), 1.15)
	world.stream_surface.mesh = world.terrain.water_mesh_reach(world.terrain.initial_water_level(), false)
	world.visual_environment.set_water_level(maximum)
	if world.food_stage != null:
		world.food_stage.set_water_level(maximum)
	_expect(is_equal_approx(world.water_level, maximum), "The route test did not establish the maximum prepared water level.")


func _check_stone_carry_contract(world: Node) -> void:
	_set_route_water_to_maximum(world)
	var stone: CollectibleBranch = world.objects_by_id.get("stone_01")
	_expect(stone != null and world.request_collect(stone), "A visible stone did not enter the shared collection lifecycle.")
	if stone == null:
		return
	_expect(await _wait(func() -> bool: return world.carried_branch == stone, 20.0), "The beaver did not carry the selected stone.")
	_expect(stone.material_type == "stone" and stone.state == CollectibleBranch.State.CARRIED and stone.get_parent() == world.actor, "The stone did not preserve its type, state and parent while carried.")
	_expect(world.stage_completion.text == "O castor leva uma pedra. Escolhe outra para a trocar.", "Stone pickup did not show material-specific Portuguese feedback.")
	_expect(world.voice.active_event != "help_place", "Stone pickup played a branch-specific instruction.")
	var opening: Vector2 = world.layout.woodland_opening_xz()
	var opening_world := Vector3(opening.x, world.terrain.height_at(opening), opening.y)
	_expect(world.request_move(opening_world), "The carried stone could not be routed through the woodland opening.")
	_expect(await _wait_actor_at(world, opening, 30.0), "The beaver did not reach the woodland opening with the stone.")
	_expect(world.carried_branch == stone, "The grove route dropped or replaced the carried stone.")
	var dam: Vector3 = world.layout.anchor(&"dam_approach")
	_expect(world.request_move(dam), "The stone could not be retargeted from the opening back to construction.")
	_expect(await _wait_actor_at(world, Vector2(dam.x, dam.z), 30.0), "The beaver did not return to construction with the stone.")
	_expect(world.carried_branch == stone and world.request_place(), "The carried stone could not be delivered after the grove route.")
	var delivered := await _wait(func() -> bool: return int(world.get("placed_count")) == 1 and int(world.get("_presented_dam_count")) == 1, MAX_ROUTE_WAIT_SECONDS)
	_expect(delivered, "The stone round trip did not deliver at zero prior placements under the maximum prepared water level.")
	if delivered:
		max_water_delivered_ids[stone.stable_id] = true


func tree_records_are_safe(world: Node, record: Dictionary) -> bool:
	var tree_xz: Vector2 = record.get("tree_xz", Vector2(INF, INF))
	var work_xz: Vector2 = record.get("work_xz", Vector2(INF, INF))
	var landing_xz: Vector2 = record.get("landing_xz", Vector2(INF, INF))
	var direction: Vector3 = record.get("fall_direction", Vector3.ZERO)
	for point: Vector2 in [tree_xz, work_xz, landing_xz]:
		if not point.is_finite() or not ValleyTerrain.PLAYABLE_RECT.has_point(point):
			return false
		if world.terrain.is_water_footprint(point) or world.terrain.slope_degrees(point) > TREE_MAX_SLOPE_DEGREES:
			return false
	if not world.navigation.is_walkable(work_xz) or not world.navigation.is_walkable(landing_xz):
		return false
	if tree_xz.distance_to(work_xz) > 0.9 or tree_xz.distance_to(landing_xz) < BranchTreeScript.TRUNK_LENGTH * 0.75:
		return false
	var fall_distance := tree_xz.distance_to(landing_xz)
	if fall_distance > BranchTreeScript.TRUNK_LENGTH + 0.15:
		return false
	if direction.length_squared() < 0.99 or absf(direction.y) > 0.001:
		return false
	var to_landing := Vector3(landing_xz.x - tree_xz.x, 0.0, landing_xz.y - tree_xz.y).normalized()
	if direction.normalized().dot(to_landing) < 0.99:
		return false
	var fall_steps := int(ceil(fall_distance / 0.2))
	for step in range(fall_steps + 1):
		var sample := tree_xz.lerp(landing_xz, float(step) / float(fall_steps))
		if world.terrain.is_water_footprint(sample) or world.terrain.slope_degrees(sample) > TREE_MAX_SLOPE_DEGREES:
			return false
	var spawn: Vector3 = world.layout.anchor(&"spawn")
	var work: Vector3 = world.layout.tree_point(work_xz)
	return not world.navigation.find_path(spawn, work).is_empty()


func _check_facing_from_three_directions(world: Node) -> void:
	_set_route_water_to_maximum(world)
	var approach_points: Array[Vector2] = [
		world.layout.anchor_xz(&"spawn"),
		Vector2(0.0, 3.7),
		Vector2(6.8, 4.5),
	]
	for index in range(approach_points.size()):
		var tree_id: String = DamRecipe.MIXED_TREE_IDS[index]
		var tree: BranchTree = world.trees_by_id.get(tree_id)
		var tree_xz := Vector2(tree.global_position.x, tree.global_position.z)
		var approach: Vector2 = approach_points[index]
		_expect(world.navigation.is_walkable(approach), "The heading approach %s is not reachable ground." % str(approach))
		_expect(not world.navigation.find_path(world.layout.anchor(&"spawn"), Vector3(approach.x, world.terrain.height_at(approach), approach.y)).is_empty(), "The heading approach %s cannot be reached from spawn." % str(approach))
		_expect(not world.navigation.find_path(Vector3(approach.x, world.terrain.height_at(approach), approach.y), world.layout.tree_point(world.layout.tree_record(tree_id).work_xz)).is_empty(), "%s has no route from heading approach %s." % [tree_id, str(approach)])
		world.actor.global_position = Vector3(approach.x, world.terrain.height_at(approach) + 0.05, approach.y)
		_expect(world.request_gnaw_tree(tree_id), "%s did not accept a gnaw request from %s." % [tree_id, str(approach)])
		_expect(not world.request_gnaw_tree(tree_id), "%s accepted a duplicate harvest request." % tree_id)
		_expect(await _wait(func() -> bool: return world.actor.action_tween != null, 15.0), "%s did not arrive and start gnawing." % tree_id)
		var to_tree := tree_xz - Vector2(world.actor.global_position.x, world.actor.global_position.z)
		var forward: Vector3 = -world.actor.global_basis.z
		var dot := clampf(forward.dot(Vector3(to_tree.normalized().x, 0.0, to_tree.normalized().y)), -1.0, 1.0)
		var heading_error := rad_to_deg(acos(dot))
		_expect(heading_error <= FACING_TOLERANCE_DEGREES, "%s gnawed %.1f degrees away from its trunk from approach %s." % [tree_id, heading_error, str(approach)])
		_expect(to_tree.length() >= 0.25 and to_tree.length() <= 1.1, "%s gnawed at an unsafe mouth-to-trunk distance of %.2f m." % [tree_id, to_tree.length()])
		_expect(await _wait(func() -> bool: return tree.is_cut() and not world.get("_tree_action_running"), 20.0), "%s did not finish exactly one harvest." % tree_id)
		var log_item: CollectibleBranch = world.objects_by_id.get(tree.log_id)
		_expect(log_item != null and log_item.visible and log_item.state == CollectibleBranch.State.FREE, "%s did not reveal its one free log." % tree_id)
		if log_item != null:
			var cue: MeshInstance3D = world.branch_cues[world.branches.find(log_item)]
			_expect(cue.visible, "%s did not reveal its collection cue with the log." % tree.log_id)
		var saved: Dictionary = DamSave.load_state(SAVE_DIRECTORY)["state"]
		_expect(saved["cut_tree_ids"].count(tree_id) == 1, "%s was not saved exactly once under its stable tree ID." % tree_id)
		_expect(not world.request_gnaw_tree(tree_id), "%s yielded a log more than once." % tree_id)
		_expect(world.objects_by_id.size() == 15, "%s harvest changed the registry size." % tree_id)
		if index == 0 and log_item != null:
			_expect(world.request_collect(log_item), "%s did not enter the shared collection lifecycle after its tree fell." % tree.log_id)
			_expect(await _wait(func() -> bool: return world.carried_branch == log_item, 20.0), "%s was not carried through the shared contract." % tree.log_id)
			_expect(log_item.material_type == "log" and log_item.state == CollectibleBranch.State.CARRIED, "%s lost its log type while carried." % tree.log_id)
			_expect(world.stage_completion.text == "O castor leva um tronco. Escolhe outro para o trocar.", "%s pickup did not show material-specific Portuguese feedback." % tree.log_id)
			_expect(world.voice.active_event != "help_place", "%s pickup played a branch-specific instruction." % tree.log_id)
			_expect(world.request_place(), "%s could not be routed from its tree landing to construction." % tree.log_id)
			var delivered := await _wait(func() -> bool: return int(world.get("placed_count")) == 2 and int(world.get("_presented_dam_count")) == 2, MAX_ROUTE_WAIT_SECONDS)
			_expect(delivered, "%s did not complete a real source-to-dam route after the first delivery under the maximum prepared water level." % tree.log_id)
			if delivered:
				max_water_delivered_ids[log_item.stable_id] = true


func _check_branch_grove_round_trip(world: Node) -> void:
	_set_route_water_to_maximum(world)
	var branch: CollectibleBranch = world.objects_by_id.get("branch_01")
	_expect(branch != null and world.request_collect(branch), "A ground branch could not be selected for the grove round trip.")
	if branch == null:
		return
	_expect(await _wait(func() -> bool: return world.carried_branch == branch, 20.0), "The beaver did not carry branch_01 from its source.")
	var opening: Vector2 = world.layout.woodland_opening_xz()
	var opening_world := Vector3(opening.x, world.terrain.height_at(opening), opening.y)
	_expect(world.request_move(opening_world), "branch_01 could not be routed through the woodland opening.")
	_expect(await _wait_actor_at(world, opening, 30.0), "The beaver did not reach the woodland opening with branch_01.")
	var clearing: Vector3 = world.layout.anchor(&"branch_clearing")
	var loop_start: Vector3 = world.actor.global_position
	_expect(world.request_move(clearing), "branch_01 could not start the return leg from the grove.")
	_expect(await _wait(func() -> bool: return not world.actor.waypoints.is_empty() and world.actor.global_position.distance_to(loop_start) > 0.1, 5.0), "The branch did not begin moving on the grove return before retargeting.")
	var dam: Vector3 = world.layout.anchor(&"dam_approach")
	_expect(world.request_move(dam), "branch_01 could not retarget its in-progress grove return to construction.")
	_expect(await _wait_actor_at(world, Vector2(dam.x, dam.z), 30.0), "The beaver did not reach construction with branch_01 after retargeting.")
	_expect(world.carried_branch == branch and world.request_place(), "branch_01 was not retained for delivery after the grove route.")
	var delivered := await _wait(func() -> bool: return int(world.get("placed_count")) == 3 and int(world.get("_presented_dam_count")) == 3, MAX_ROUTE_WAIT_SECONDS)
	_expect(delivered, "branch_01 did not complete its source-to-dam route after the prior material deliveries under the maximum prepared water level.")
	if delivered:
		max_water_delivered_ids[branch.stable_id] = true


func _wait_actor_at(world: Node, target_xz: Vector2, timeout_seconds: float = 20.0) -> bool:
	return await _wait(func() -> bool:
		return world.actor.waypoints.is_empty() and Vector2(world.actor.global_position.x, world.actor.global_position.z).distance_to(target_xz) <= 0.6,
		timeout_seconds
	)


func _check_retarget_and_reload(world: Node) -> Node:
	var first_id: String = DamRecipe.MIXED_TREE_IDS[3]
	var retarget_id: String = DamRecipe.MIXED_TREE_IDS[4]
	var first_tree: BranchTree = world.trees_by_id[first_id]
	var retarget_tree: BranchTree = world.trees_by_id[retarget_id]
	world.actor.global_position = world.layout.anchor(&"spawn") + Vector3.UP * 0.05
	_expect(await _tap_tree(world, first_tree), "%s did not accept its first screen tap." % first_id)
	var first_path: PackedVector3Array = world.actor.waypoints.duplicate()
	_expect(await _tap_tree(world, first_tree), "A duplicate tap on pending %s was not consumed." % first_id)
	_expect(world.actor.waypoints == first_path, "A duplicate tap changed the active %s route." % first_id)
	_expect(await _tap_tree(world, retarget_tree), "%s could not retarget the pending screen tap from %s." % [retarget_id, first_id])
	_expect(world.get("_tree_pending_id") == retarget_id, "The active walk did not retain the retargeted tree ID.")
	_expect(await _wait(func() -> bool: return retarget_tree.is_cut() and not world.get("_tree_action_running"), 20.0), "%s did not finish after retargeting." % retarget_id)
	_expect(not first_tree.is_cut(), "Retargeting harvested the abandoned %s." % first_id)

	_expect(world.request_gnaw_tree(first_id), "%s did not accept its post-retarget walk." % first_id)
	_expect(await _wait(func() -> bool: return world.actor.action_tween != null, 15.0), "%s did not reach its gnaw before reload." % first_id)
	world.queue_free()
	await process_frame
	world = await _spawn_world()
	if world == null:
		return null
	first_tree = world.trees_by_id[first_id]
	retarget_tree = world.trees_by_id[retarget_id]
	_expect(not first_tree.is_cut(), "Reload during %s gnaw persisted an unfinished harvest." % first_id)
	_expect(retarget_tree.is_cut(), "Reload during another tree's gnaw lost the completed %s harvest." % retarget_id)
	_expect(not (world.objects_by_id[world.layout.tree_record(first_id).log_id] as CollectibleBranch).visible, "Reload during gnaw revealed an unfinished log.")
	return world


func _check_all_material_round_trips_at_max_water(world: Node) -> void:
	var ordered_ids: Array[String] = DamRecipe.MIXED_BRANCH_IDS + DamRecipe.MIXED_LOG_IDS + DamRecipe.MIXED_STONE_IDS
	var mid_progress_trip := ""
	var late_progress_trip := ""
	for material_id: String in ordered_ids:
		if max_water_delivered_ids.has(material_id):
			continue
		var count_before := int(world.get("placed_count"))
		if count_before == 8:
			mid_progress_trip = material_id
		if count_before == 14:
			late_progress_trip = material_id
		await _deliver_material_at_max_water(world, material_id, count_before + 1)
	_expect(mid_progress_trip != "", "No actual max-water route started at 8/15 progress.")
	_expect(late_progress_trip != "", "No actual max-water route started at 14/15 progress.")
	for material_id: String in ordered_ids:
		_expect(max_water_delivered_ids.has(material_id), "%s has no completed actual max-water source-to-dam trip." % material_id)
	if failures == 0:
		print("CASTOR_MIXED_MAX_WATER_ROUTES_OK sources=15 mid=8/15:%s late=14/15:%s" % [mid_progress_trip, late_progress_trip])


func _deliver_material_at_max_water(world: Node, material_id: String, expected_count: int) -> void:
	var material: CollectibleBranch = world.objects_by_id.get(material_id)
	_expect(material != null, "%s is missing from the mixed object registry." % material_id)
	if material == null:
		return
	_set_route_water_to_maximum(world)
	_expect(int(world.get("placed_count")) == expected_count - 1, "%s route began at %d/15 instead of %d/15." % [material_id, int(world.get("placed_count")), expected_count - 1])
	_expect(is_equal_approx(float(world.get("water_level")), world.terrain.full_water_level()), "%s route did not start at the maximum prepared water level." % material_id)
	if material.material_type == "log" and material.state == CollectibleBranch.State.FREE:
		var source_tree_id := ""
		for record: Dictionary in world.layout.tree_sources():
			if String(record.get("log_id", "")) == material_id:
				source_tree_id = String(record.get("tree_id", ""))
				break
		var source_tree: BranchTree = world.trees_by_id.get(source_tree_id)
		_expect(source_tree != null, "%s has no tree source for its public gnaw request." % material_id)
		if source_tree == null:
			return
		if not source_tree.is_cut():
			_expect(world.request_gnaw_tree(source_tree_id), "%s did not accept the public gnaw request." % source_tree_id)
			_expect(await _wait(func() -> bool: return source_tree.is_cut() and not world.get("_tree_action_running"), MAX_ROUTE_WAIT_SECONDS), "%s did not finish gnawing at maximum water." % source_tree_id)
		_expect(is_equal_approx(float(world.get("water_level")), world.terrain.full_water_level()), "%s gnaw route left the maximum-water fixture." % source_tree_id)
		_expect_unmasked_pickup_ray_hits(world, material)
	_expect(world.request_collect(material), "%s did not accept the public collection request at maximum water." % material_id)
	_expect(await _wait(func() -> bool: return world.carried_branch == material, MAX_ROUTE_WAIT_SECONDS), "%s did not complete its actual source-to-carry route at maximum water." % material_id)
	_expect(world.carried_branch == material and material.state == CollectibleBranch.State.CARRIED, "%s was not the unique carried object before delivery." % material_id)
	_expect(world.request_place(), "%s did not accept the public delivery request." % material_id)
	var delivered := await _wait(func() -> bool: return int(world.get("placed_count")) == expected_count and int(world.get("_presented_dam_count")) == expected_count, MAX_ROUTE_WAIT_SECONDS)
	_expect(delivered, "%s did not complete its actual carry-to-dam route for placement %d." % [material_id, expected_count])
	_expect(material.state == CollectibleBranch.State.PLACED, "%s was not placed after its actual max-water trip." % material_id)
	if delivered:
		max_water_delivered_ids[material_id] = true


func _check_placed_material_cannot_be_recollected(world: Node) -> void:
	var branch: CollectibleBranch = world.objects_by_id.get("branch_01")
	_expect(branch != null, "The placed-material regression has no branch_01 object.")
	if branch == null:
		return
	branch.place(world, world.layout.anchor(&"spawn"), 0)
	_expect(not world.navigation.find_approach(world.actor.global_position, Vector2(branch.position.x, branch.position.z), 3).is_empty(), "The placed-material regression has no available collection approach.")
	var accepted: bool = world.request_collect(branch)
	_expect(not accepted, "request_collect accepted a physically placed material after delivery.")
	_expect(branch.state == CollectibleBranch.State.PLACED, "A recollection request changed a delivered material out of PLACED state.")
	_expect(world.pending_branch == null and world.carried_branch == null, "A delivered material re-entered the pending or carried lifecycle.")
	if branch.state != CollectibleBranch.State.PLACED:
		branch.return_to_origin(world)
		world.pending_branch = null
		world.carried_branch = null
		world.actor.follow_path(PackedVector3Array())


func _tap_tree(world: Node, tree: BranchTree) -> bool:
	var target := tree.global_position + Vector3.UP * 0.8
	world.camera.position = target + Vector3(3.0, 2.3, 4.0)
	world.camera.look_at(target)
	world.camera.current = true
	await physics_frame
	var screen: Vector2 = world.camera.unproject_position(target)
	_expect(root.get_visible_rect().has_point(screen), "%s is outside the diagnostic tap view at %s." % [tree.stable_id, str(screen)])
	return world._move_from_screen(screen)
