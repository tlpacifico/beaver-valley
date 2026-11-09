extends SceneTree
## Integration: the home stage becomes available after the dam and reuses the
## existing tap, carry and place verbs without changing the dam save.

const DamSave = preload("res://scripts/dam_save.gd")
const SAVE_TEST_DIRECTORY := "user://home_stage_test/"
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


func _run() -> void:
	_expect(DamSave.clear_save(SAVE_TEST_DIRECTORY), "Could not clear the isolated home-stage save directory.")
	root.size = Vector2i(960, 600)
	var scene_path := "res://scenes/movement.tscn"

	# The home must stay hidden and unavailable while the dam is incomplete.
	var empty_world: Node = load(scene_path).instantiate()
	empty_world.save_directory = SAVE_TEST_DIRECTORY
	root.add_child(empty_world)
	await physics_frame
	await physics_frame
	var inactive_home: Node = empty_world.get("home_stage")
	_expect(inactive_home != null, "The home stage node is missing from the valley.")
	if inactive_home == null:
		empty_world.queue_free()
		_expect(false, "Home stage is required before the remaining checks can run.")
		quit(1)
		return
	_expect(not bool(inactive_home.get("is_active")), "The home stage was active before the dam was completed.")
	empty_world.queue_free()
	await process_frame

	# A completed dam save restores the valley and makes the home available.
	_expect(DamSave.save_state(_completed_dam_state(), SAVE_TEST_DIRECTORY), "Could not prepare a completed dam save.")
	var world: Node = load(scene_path).instantiate()
	world.save_directory = SAVE_TEST_DIRECTORY
	root.add_child(world)
	await physics_frame
	await physics_frame
	var home: Node = world.get("home_stage")
	_expect(home != null and bool(home.get("is_active")), "Restoring a completed dam did not activate the home stage.")
	if home == null:
		world.queue_free()
		quit(1)
		return
	_expect(world.placed_count == 3, "Activating the home stage changed the completed dam.")
	_expect(world.home_invite.visible and world.home_invite.text == "Agora vamos construir a casa!", "The home stage did not keep the Portuguese invitation visible.")
	_expect(not world.branch_cues.any(func(cue: MeshInstance3D) -> bool: return cue.visible), "Leftover branch cues still compete with the home stage.")
	for branch: CollectibleBranch in world.branches:
		if branch.state == CollectibleBranch.State.FREE:
			_expect(branch.hit_area.collision_layer == 0, "A leftover branch is still selectable during the home stage.")
	_expect(not world.request_collect(world.branches[0]), "A leftover branch still starts collection during the home stage.")
	var parts: Array = home.get("parts")
	_expect(parts.size() == 3, "The home stage does not expose three loose parts.")
	for part: Node in parts:
		_expect(part.visible, "A loose home part is not visible after activation.")
	_expect(int(home.get("slot_count")) == 2 and int(home.get("placed_slot_count")) == 0, "The home stage does not start with two empty positions.")
	_expect(not home.get_node("LodgeWindow").visible, "The warm window is visible before the home is complete.")
	_expect(home.has_method("get_lodge_center"), "The home stage does not expose its lodge position.")
	if home.has_method("get_lodge_center"):
		var lodge_center: Vector3 = home.call("get_lodge_center")
		_expect(lodge_center.z < -3.6, "The lodge is not inside the lake.")
		_expect(home.has_node("LodgeMound") and home.get_node("LodgeMound").visible, "The lodge has no visible mound in the lake.")
		_expect(home.call("get_slot_position", 0).z > lodge_center.z, "The wall position does not face the camera on the lake side.")
		_expect(home.call("get_slot_position", 1).y > home.call("get_slot_position", 0).y, "The roof position is not above the wall position.")
	for part: Node in parts:
		_expect(part.global_position.z > -3.4, "A loose home part is not on the bank.")
	var viewport := Rect2(Vector2.ZERO, Vector2(960, 600))
	for part: Node in parts:
		_expect(viewport.has_point(world.camera.unproject_position(part.global_position + Vector3.UP * 0.15)), "A home part is outside the fixed camera view.")
	_expect(viewport.has_point(world.camera.unproject_position(home.call("get_slot_position", 0))), "The wall position is outside the fixed camera view.")
	_expect(viewport.has_point(world.camera.unproject_position(home.call("get_slot_position", 1))), "The roof position is outside the fixed camera view.")

	# Select the first part through the real camera ray.
	var first_part: Node = parts[0]
	var first_part_screen: Vector2 = world.camera.unproject_position(first_part.global_position + Vector3.UP * 0.15)
	_expect(world._move_from_screen(first_part_screen), "Tapping a loose home part did not start its collection.")
	_expect(home.get("pending_part") == first_part, "The selected home part was not reserved while approaching.")
	_expect(world.request_help() and world.voice.active_event == "help_home_collect", "Help during a pending home pickup did not use the home-specific line.")
	_expect(world.status.text == "O castor vai buscar a peça.", "Help during a pending home pickup did not explain the approach.")
	_expect(not home.call("request_place", 0), "A home position accepted placement before the part arrived.")
	_expect(world.status.text == "O castor vai buscar a peça.", "An early home placement did not explain that the part is still being fetched.")
	_expect(await _wait_for(func() -> bool: return home.get("carried_part") == first_part), "The home part was not carried after arrival.")
	_expect(first_part.get_parent() == world.actor, "The carried home part did not attach to the beaver.")
	_expect(world.request_help() and world.voice.active_event == "help_home_place", "Help with a carried home part did not use the home-specific placement line.")
	_expect(bool(home.get("placement_help_active")), "Help with a carried home part did not highlight a free position.")

	# Place the first part at the wall position through the camera ray.
	var wall_screen: Vector2 = world.camera.unproject_position(home.call("get_slot_position", 0))
	_expect(world._move_from_screen(wall_screen), "Tapping the wall position with a carried part did not start placement.")
	_expect(int(home.get("pending_slot")) == 0, "The wall position was not reserved while approaching.")
	_expect(await _wait_for(func() -> bool: return int(home.get("placed_slot_count")) == 1), "The first home part was not placed on arrival.")
	_expect(bool(home.call("is_slot_occupied", 0)) and home.call("part_at_slot", 0) == first_part, "The wall position did not receive the placed part.")
	_expect(world.status.text == "A peça ficou na casa!", "Placing the first home part did not show a Portuguese confirmation.")
	_expect(not bool(home.call("is_complete")), "The home was completed after only one of two positions.")

	# Any part fits, but an occupied position is refused with a clear message.
	var second_part: Node = parts[1]
	_expect(home.call("request_collect", second_part), "A second home part could not be selected.")
	_expect(await _wait_for(func() -> bool: return home.get("carried_part") == second_part), "The second home part was not carried after arrival.")
	_expect(not home.call("request_place", 0), "An occupied home position accepted another part.")
	_expect(world.status.text == "Esta parte da casa já está cheia.", "An occupied position did not explain the refusal in Portuguese.")

	# Swapping before placement returns the previous part to its origin.
	var third_part: Node = parts[2]
	_expect(home.call("request_collect", third_part), "Selecting a third part while carrying failed.")
	_expect(second_part.get("state") == 0 and second_part.get_parent() == home, "Swapping did not return the previous part to its origin.")
	_expect(await _wait_for(func() -> bool: return home.get("carried_part") == third_part), "The swapped part was not carried after arrival.")

	# Place the second part at the roof position to finish the lodge.
	world.save_directory = "res://unsafe"
	_expect(home.call("request_place", 1), "The roof position could not be selected with a carried part.")
	_expect(await _wait_for(func() -> bool: return int(home.get("placed_slot_count")) == 2), "The second home part was not placed on arrival.")
	_expect(bool(home.call("is_complete")), "The home did not complete with both positions filled.")
	_expect(world.status.text == "Não foi possível guardar o progresso. Pede ajuda a um adulto.", "The home completion or food-stage transition hid a failed-save warning.")
	_expect(home.call("part_at_slot", 1) == third_part, "The roof position did not receive the placed part.")
	_expect(home.get_node("LodgeWindow").visible, "Completing the home did not show a visible warm window.")
	_expect(world.home_completion_feedback.visible and world.home_completion_feedback.text == "A casa está pronta!", "Completing the home did not show the Portuguese completion message.")
	_expect(world.home_invite.visible and world.home_invite.text == "Agora vamos guardar comida para o inverno!", "Completing the home did not hand over to the food invitation.")
	_expect(not world.completion_feedback.visible, "Completing the home left the older dam message visible.")
	_expect(world.status.text == "Não foi possível guardar o progresso. Pede ajuda a um adulto.", "The food-stage invitation hid the home save warning.")
	_expect(second_part.get("hit_area").collision_layer == 0, "The unused home part remained selectable after completion.")
	_expect(world.placed_count == 3, "Building the home changed the completed dam.")
	world.save_directory = SAVE_TEST_DIRECTORY
	_expect(bool(world.call("_save_dam_state")), "Could not save the home after the forced failure check.")
	var first_part_id := str(first_part.get("stable_id"))
	var third_part_id := str(third_part.get("stable_id"))
	var saved_home_state: Dictionary = DamSave.load_state(SAVE_TEST_DIRECTORY)["state"]
	_expect(saved_home_state["home_slots"] == [first_part_id, third_part_id], "The two home placements were not saved in their slots.")

	# The home is now durable; reload restores it and hands over to food.
	world.queue_free()
	await process_frame
	var reload_world: Node = load(scene_path).instantiate()
	reload_world.save_directory = SAVE_TEST_DIRECTORY
	root.add_child(reload_world)
	await physics_frame
	await physics_frame
	var reload_home: Node = reload_world.get("home_stage")
	_expect(reload_home != null and bool(reload_home.get("is_active")), "Reloading a completed dam did not make the home available again.")
	_expect(bool(reload_home.call("is_complete")) and int(reload_home.get("placed_slot_count")) == 2, "Reload did not restore the completed home.")
	_expect(str(reload_home.call("part_at_slot", 0).get("stable_id")) == first_part_id and str(reload_home.call("part_at_slot", 1).get("stable_id")) == third_part_id, "Reload placed the home parts in the wrong positions.")
	_expect(reload_home.get_node("LodgeWindow").visible, "Reload did not restore the lodge window.")
	var reload_food: Node = reload_world.get("food_stage")
	_expect(reload_food != null and bool(reload_food.get("is_active")), "Reload of a completed home did not start the food stage.")
	_expect(reload_world.home_invite.visible and reload_world.home_invite.text == "Agora vamos guardar comida para o inverno!", "Reload of a completed home did not show the food invitation.")
	_expect(reload_world.get_node("CanvasLayer/FoodProgress").visible and reload_world.get_node("CanvasLayer/FoodProgress").text == "Comida guardada: ○○○", "Reload of a completed home did not show the food progress.")
	_expect(DamSave.load_state(SAVE_TEST_DIRECTORY)["state"]["placed_materials"].size() == 3, "Rebuilding the home changed the dam save.")
	reload_world.queue_free()
	await process_frame
	_expect(DamSave.clear_save(SAVE_TEST_DIRECTORY), "Could not clean up the isolated home-stage save files.")
	if failures == 0:
		print("CASTOR_HOME_STAGE_OK activation carry place occupied swap completion saved_restored")
	quit(0 if failures == 0 else 1)
