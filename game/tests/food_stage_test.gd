extends SceneTree
## Integration: the food store starts after the lodge and reuses the tap,
## carry and place verbs. The test also covers the home-to-food transition.

const DamSave = preload("res://scripts/dam_save.gd")
const SAVE_TEST_DIRECTORY := "user://food_stage_test/"
var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _expect(condition: bool, description: String) -> void:
	if not condition:
		failures += 1
		push_error(description)


func _wait_for(condition: Callable, max_frames: int = 1200) -> bool:
	for _frame in range(max_frames):
		await physics_frame
		if condition.call():
			return true
	return false


func _completed_dam_state() -> Dictionary:
	var state := DamSave.empty_state()
	state["placed_materials"] = ["branch_normal_01", "branch_normal_02", "branch_normal_03"]
	state["stage_completed"] = true
	state["finish_choice"] = "finish_moss"
	return state


func _place_home_part(home: Node, part_index: int, slot_index: int) -> bool:
	var parts: Array = home.get("parts")
	var part: Node = parts[part_index]
	if not home.call("request_collect", part):
		return false
	if not await _wait_for(func() -> bool: return home.get("carried_part") == part):
		return false
	if not home.call("request_place", slot_index):
		return false
	return await _wait_for(func() -> bool: return int(home.get("placed_slot_count")) == slot_index + 1)


func _first_bundle(food: Node, suitable: bool) -> Node:
	var bundles: Array = food.get("bundles")
	for bundle: Node in bundles:
		if int(bundle.get("state")) > 1:
			continue
		if bool(food.call("is_bundle_suitable", bundle)) == suitable:
			return bundle
	return null


func _run() -> void:
	_expect(DamSave.clear_save(SAVE_TEST_DIRECTORY), "Could not clear the isolated food-stage save directory.")
	root.size = Vector2i(960, 600)
	var scene_path := "res://scenes/movement.tscn"
	_expect(DamSave.save_state(_completed_dam_state(), SAVE_TEST_DIRECTORY), "Could not prepare a completed dam save.")
	var world: Node = load(scene_path).instantiate()
	world.save_directory = SAVE_TEST_DIRECTORY
	root.add_child(world)
	await physics_frame
	await physics_frame
	var home: Node = world.get("home_stage")
	var food: Node = world.get("food_stage")
	_expect(home != null and bool(home.get("is_active")), "The completed dam did not make the home available.")
	_expect(food != null, "The food stage node is missing from the valley.")
	if food == null:
		world.queue_free()
		quit(1)
		return
	_expect(not bool(food.get("is_active")), "The food stage started before the home was finished.")
	_expect(world.get_node("CanvasLayer/DamProgress").visible and not world.get_node("CanvasLayer/FoodProgress").visible, "The food progress replaced the dam progress before the food stage.")

	# Completing the home must hand the chapter over to the food store.
	_expect(await _place_home_part(home, 0, 0), "The first home part could not be placed.")
	_expect(await _place_home_part(home, 1, 1), "The second home part could not be placed.")
	_expect(bool(home.call("is_complete")), "The home did not complete before the food stage.")
	_expect(bool(food.get("is_active")), "The food stage did not start after the home was completed.")
	_expect(world.home_invite.visible and world.home_invite.text == "Agora vamos guardar comida para o inverno!", "The food invitation did not replace the home invitation.")
	_expect(world.home_completion_feedback.visible, "The home completion message disappeared when the food stage started.")
	_expect(world.voice.active_event == "food_invite", "The food invitation voice line did not play.")
	_expect(not world.get_node("CanvasLayer/DamProgress").visible and world.get_node("CanvasLayer/FoodProgress").visible, "The food progress did not replace the dam progress.")
	_expect(world.get_node("CanvasLayer/FoodProgress").text == "Comida guardada: ○○○", "The initial food progress is wrong.")
	var bundles: Array = food.get("bundles")
	_expect(bundles.size() == 5, "The food stage does not expose five bundles.")
	_expect(int(food.call("get_suitable_count")) == 3 and int(food.call("get_thin_count")) == 2, "The food stage does not offer three suitable and two thin bundles.")
	var viewport := Rect2(Vector2.ZERO, Vector2(960, 600))
	var target_position: Vector3 = food.call("get_target_position")
	_expect(target_position.y < world.terrain.full_water_level() - 0.05, "The food cache is not safely underwater at the full lake level.")
	_expect(target_position.y > world.terrain.height_at(Vector2(target_position.x, target_position.z)), "The food cache is buried in the lake bed.")
	_expect(world.terrain.is_water_footprint(Vector2(target_position.x, target_position.z)), "The food cache is not in the lake footprint.")
	_expect(viewport.has_point(world.camera.unproject_position(target_position)), "The food target is outside the fixed camera view.")
	var cache_marker := food.get_node_or_null("FoodCacheMarker") as Node3D
	var cache_basket := food.get_node_or_null("FoodCacheBasket") as Node3D
	_expect(cache_marker != null and cache_marker.visible, "The submerged cache has no visible surface marker.")
	_expect(cache_basket != null and cache_basket.visible, "The submerged cache has no visible basket.")
	if cache_marker != null:
		_expect(absf(cache_marker.global_position.y - world.terrain.full_water_level()) <= 0.08, "The cache surface marker does not sit on the full lake surface.")
	if cache_basket != null:
		_expect(cache_basket.global_position.y < world.terrain.full_water_level(), "The cache basket is not underwater.")
	var dry_cache_approach: Vector2 = world.layout.food_cache_approach_xz()
	_expect(world.navigation.is_walkable(dry_cache_approach), "The cache approach is not on walkable dry ground.")
	_expect(not world.terrain.is_water_footprint(dry_cache_approach), "The cache approach is in the lake.")
	for bundle: Node in bundles:
		_expect(viewport.has_point(world.camera.unproject_position(bundle.global_position + Vector3.UP * 0.15)), "A food bundle is outside the fixed camera view.")

	# A visibly unsuitable bundle can be carried, but the water refuses it.
	var thin_bundle: Node = _first_bundle(food, false)
	_expect(thin_bundle != null, "The food stage has no unsuitable bundle.")
	if thin_bundle != null:
		var thin_screen: Vector2 = world.camera.unproject_position(thin_bundle.global_position + Vector3.UP * 0.15)
		_expect(world._move_from_screen(thin_screen), "Tapping a food bundle did not start its collection.")
		_expect(await _wait_for(func() -> bool: return food.get("carried_bundle") == thin_bundle), "The thin bundle was not carried after arrival.")
		_expect(not food.call("request_place"), "The water accepted a thin bundle.")
		_expect(world.status.text == "Este feixe é pequeno. Escolhe outro.", "The thin bundle refusal is not in Portuguese.")
		_expect(world.voice.active_event == "food_unsuitable", "The thin bundle refusal has no voice cue.")
		_expect(bool(food.get("help_highlight_active")), "The thin bundle refusal did not highlight suitable bundles.")

	# Help points to a suitable bundle, and swapping returns the thin one.
	_expect(world.request_help() and world.voice.active_event == "food_unsuitable", "Help with a thin bundle did not repeat the refusal.")
	var suitable_bundle: Node = _first_bundle(food, true)
	_expect(suitable_bundle != null, "The food stage has no suitable bundle.")
	if suitable_bundle == null:
		world.queue_free()
		quit(1)
		return
	_expect(food.call("request_collect", suitable_bundle), "A suitable bundle could not be selected while carrying a thin one.")
	_expect(thin_bundle.get("state") == 0 and thin_bundle.get_parent() == food, "Swapping did not return the thin bundle to the bank.")
	_expect(await _wait_for(func() -> bool: return food.get("carried_bundle") == suitable_bundle), "The suitable bundle was not carried after the swap.")
	_expect(world.request_help() and world.voice.active_event == "help_food_place", "Help with a suitable bundle did not point to the water.")

	# The real camera ray must reach the water target and start the first placement.
	var target_screen: Vector2 = world.camera.unproject_position(target_position)
	_expect(world._move_from_screen(target_screen), "Tapping the food target did not start placement.")
	_expect(await _wait_for(func() -> bool: return int(food.get("placed_count")) >= 1), "The first food bundle was not placed on arrival.")
	_expect(world.get_node("CanvasLayer/FoodProgress").text == "Comida guardada: ●○○", "The food progress did not advance after the first bundle.")
	_expect(int(food.call("get_visible_pile_count")) == 1, "The first placed bundle is not visible in the water.")

	# The first placement is durable; an interrupted session must restore it.
	var saved_after_first: Dictionary = DamSave.load_state(SAVE_TEST_DIRECTORY)["state"]
	_expect(saved_after_first["food_placements"].size() == 1 and saved_after_first["home_slots"].size() == 2, "The first food placement or the home was not saved.")
	world.queue_free()
	await process_frame
	world = load(scene_path).instantiate()
	world.save_directory = SAVE_TEST_DIRECTORY
	root.add_child(world)
	await physics_frame
	await physics_frame
	home = world.get("home_stage")
	food = world.get("food_stage")
	_expect(bool(home.call("is_complete")) and bool(food.get("is_active")), "The interrupted session did not restore the home and food stage.")
	_expect(int(food.get("placed_count")) == 1 and int(food.call("get_visible_pile_count")) == 1, "The interrupted session did not restore the first food bundle.")
	_expect(world.get_node("CanvasLayer/FoodProgress").text == "Comida guardada: ●○○", "The interrupted session did not restore the food progress.")
	_expect(food.get("carried_bundle") == null and food.get("pending_bundle") == null, "The interrupted session restored a carried or pending bundle.")
	_expect(world.home_invite.visible and world.home_invite.text == "Agora vamos guardar comida para o inverno!", "The interrupted session did not show the food invitation.")
	_expect(food.call("get_placed_bundle_ids").size() == 1, "The interrupted session did not restore exactly one placed bundle.")

	# Two more suitable bundles complete the store.
	for _index in range(2):
		var next_bundle: Node = _first_bundle(food, true)
		if next_bundle == null:
			_expect(false, "Not enough suitable bundles to finish the food store.")
			break
		_expect(food.call("request_collect", next_bundle), "A suitable bundle could not be selected.")
		_expect(await _wait_for(func() -> bool: return food.get("carried_bundle") == next_bundle), "A suitable bundle was not carried.")
		_expect(food.call("request_place"), "The food target could not start placement.")
		var expected_count: int = int(food.get("placed_count")) + 1
		if expected_count == 3:
			world.save_directory = "res://unsafe"
		_expect(await _wait_for(func() -> bool: return int(food.get("placed_count")) == expected_count), "A food bundle was not placed.")
		if expected_count == 3:
			_expect(world.status.text == "Não foi possível guardar o progresso. Pede ajuda a um adulto.", "The food completion message hid a failed-save warning.")
		var saved_after_placement: Dictionary = DamSave.load_state(SAVE_TEST_DIRECTORY)["state"]
		if expected_count < 3:
			_expect(saved_after_placement["food_placements"].size() == expected_count, "A food placement was not saved.")
	_expect(bool(food.call("is_complete")), "The food store did not complete with three bundles.")
	_expect(int(food.get("placed_count")) == 3 and int(food.call("get_visible_pile_count")) == 3, "The food pile does not show all three bundles.")
	for bundle: Node3D in food.get("placed_bundles"):
		_expect(bundle.global_position.y < world.terrain.full_water_level() - 0.05, "A placed bundle centre is at or above the full lake surface.")
	_expect(world.get_node("CanvasLayer/FoodProgress").text == "Comida guardada: ●●●", "The completed food progress is wrong.")
	_expect(world.food_completion_feedback.visible and world.food_completion_feedback.text == "A comida está guardada!", "The food completion message is missing.")
	_expect(not world.home_completion_feedback.visible and not world.home_invite.visible, "The old home messages stayed visible after the food store was completed.")
	_expect(world.voice.active_event == "food_complete", "The food completion voice line did not play.")
	_expect(not world.get_node("CanvasLayer/FoodProgress").visible or world.get_node("CanvasLayer/FoodProgress").text == "Comida guardada: ●●●", "The completed food progress is not readable.")
	bundles = food.get("bundles")
	for bundle: Node in bundles:
		_expect(bundle.get("hit_area").collision_layer == 0, "A food bundle is still selectable after completion.")
	_expect(world.placed_count == 3 and bool(home.call("is_complete")), "The food stage changed the dam or the home.")

	# The third bundle hands over to the winter ending after a short pause.
	_expect(await _wait_for(func() -> bool: return world.ending_overlay.visible, 300), "The ending overlay did not appear after the food store.")
	_expect(world.status.text == "Não foi possível guardar o progresso. Pede ajuda a um adulto.", "The winter transition hid the final food save warning.")
	_expect(world.ending_title.text == "O inverno chegou!", "The ending title is missing.")
	_expect("família" in world.ending_message.text and "comida" in world.ending_message.text, "The ending message is incomplete.")
	_expect(not ("hibernar" in world.ending_message.text.to_lower()) and not ("dormir" in world.ending_message.text.to_lower()), "The ending suggests hibernation.")
	_expect(world.voice.active_event == "winter_arrived", "The winter voice line did not play.")
	var winter: Node = world.get("winter_scene")
	_expect(winter != null and bool(winter.get("is_winter")) and int(winter.call("get_family_count")) >= 2, "The ending did not show the family in winter.")
	_expect(int(winter.call("get_snow_count")) >= 40, "The ending did not show falling snow.")
	_expect(world.winter_new_adventure_button.visible, "The winter new-adventure action is missing.")
	world._continue_visiting()
	_expect(not world.ending_overlay.visible and bool(winter.get("is_winter")) and world.winter_new_adventure_button.visible, "Continuing to visit the valley did not keep winter or hid the new-adventure action.")
	_expect(world.status.text == "Não foi possível guardar o progresso. Pede ajuda a um adulto.", "Continuing to visit hid the failed-save warning.")
	world.save_directory = SAVE_TEST_DIRECTORY
	_expect(bool(world.call("_save_dam_state")), "Could not save the food stage after the forced failure check.")

	var saved_state: Dictionary = DamSave.load_state(SAVE_TEST_DIRECTORY)["state"]
	_expect(saved_state["placed_materials"].size() == 3 and saved_state["stage_completed"], "The food stage changed the dam save.")
	_expect(saved_state["food_placements"].size() == 3 and saved_state["home_slots"].size() == 2, "The completed food store was not saved.")
	world.queue_free()
	await process_frame
	var reload_world: Node = load(scene_path).instantiate()
	reload_world.save_directory = SAVE_TEST_DIRECTORY
	root.add_child(reload_world)
	await physics_frame
	await physics_frame
	var reload_home: Node = reload_world.get("home_stage")
	var reload_food: Node = reload_world.get("food_stage")
	_expect(reload_home != null and bool(reload_home.call("is_complete")), "Reload did not restore the completed home.")
	_expect(reload_food != null and bool(reload_food.get("is_active")) and bool(reload_food.call("is_complete")), "Reload did not restore the completed food store.")
	_expect(int(reload_food.get("placed_count")) == 3 and int(reload_food.call("get_visible_pile_count")) == 3, "Reload did not restore the food pile.")
	var reload_winter: Node = reload_world.get("winter_scene")
	_expect(bool(reload_world.get("winter_active")) and reload_winter != null and bool(reload_winter.get("is_winter")), "Reload did not restore the winter ending.")
	_expect(not reload_world.ending_overlay.visible, "Reload replayed the ending overlay.")
	_expect(reload_world.winter_new_adventure_button.visible, "Reload did not restore the new-adventure action.")
	_expect(reload_world.status.text.begins_with("O inverno chegou!"), "Reload did not restore the winter status.")
	_expect(reload_world.get_node("CanvasLayer/FoodProgress").visible and reload_world.get_node("CanvasLayer/FoodProgress").text == "Comida guardada: ●●●", "Reload did not restore the food progress.")
	_expect(not reload_world.food_completion_feedback.visible and not reload_world.home_invite.visible and not reload_world.home_completion_feedback.visible, "Reload restored the old completion messages.")
	reload_world.queue_free()
	await process_frame
	_expect(DamSave.clear_save(SAVE_TEST_DIRECTORY), "Could not clean up the isolated food-stage save files.")
	if failures == 0:
		print("CASTOR_FOOD_STAGE_OK transition suitable thin_refusal swap pile progress completion saved_restored interrupted ending")
	quit(0 if failures == 0 else 1)
