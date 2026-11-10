extends SceneTree
## Ending restore: a completed chapter opens in winter with the family, without
## replaying the ending overlay, and offers a protected new adventure.

const DamSave = preload("res://scripts/dam_save.gd")
const SAVE_TEST_DIRECTORY := "user://ending_test/"
var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _expect(condition: bool, description: String) -> void:
	if not condition:
		failures += 1
		push_error(description)


func _completed_chapter_state() -> Dictionary:
	var state := DamSave.empty_state()
	state["placed_materials"] = ["branch_normal_01", "branch_normal_02", "branch_normal_03"]
	state["stage_completed"] = true
	state["finish_choice"] = "finish_moss"
	state["home_slots"] = ["home_part_rounded", "home_part_plank"]
	state["food_placements"] = ["food_bundle_01", "food_bundle_03", "food_bundle_04"]
	return state


func _run() -> void:
	_expect(DamSave.clear_save(SAVE_TEST_DIRECTORY), "Could not clear the isolated ending save directory.")
	root.size = Vector2i(960, 600)
	_expect(DamSave.save_state(_completed_chapter_state(), SAVE_TEST_DIRECTORY), "Could not prepare a completed chapter save.")
	var world: Node = load("res://scenes/movement.tscn").instantiate()
	world.save_directory = SAVE_TEST_DIRECTORY
	root.add_child(world)
	await physics_frame
	await physics_frame
	var winter: Node = world.get("winter_scene")
	_expect(winter != null, "The winter scene is missing from the valley.")
	if winter == null:
		world.queue_free()
		quit(1)
		return
	_expect(bool(world.get("winter_active")), "A completed chapter did not open in winter.")
	_expect(bool(winter.get("is_winter")), "The winter scene is not active.")
	_expect(int(winter.call("get_snow_count")) >= 40, "The winter scene has no falling snow.")
	_expect(int(winter.call("get_family_count")) >= 2, "The beaver family is missing from the ending.")
	_expect(int(winter.call("get_snow_patch_count")) >= 15, "The winter scene has no terrain snow patches.")
	var home: Node = world.get("home_stage")
	_expect(home != null and bool(home.call("is_snow_visible")), "The lodge has no snow cap in winter.")
	var dam_snow: Node = winter.get_node_or_null("DamSnow")
	_expect(dam_snow != null and dam_snow.visible, "The finished dam has no snow cover in winter.")
	for position: Vector3 in winter.call("get_family_positions"):
		var xz: Vector2 = Vector2(position.x, position.z)
		_expect(not world.terrain.is_water_footprint(xz), "A family member is standing in the lake.")
		_expect(absf(position.y - (world.terrain.height_at(xz) + 0.05)) <= 0.12, "A family member is not grounded on the relief.")
	for patch in winter.find_children("SnowPatch*", "MeshInstance3D", true, false):
		var patch_node := patch as MeshInstance3D
		var ground_normal: Vector3 = world.terrain.normal_at(Vector2(patch_node.global_position.x, patch_node.global_position.z))
		_expect(patch_node.global_transform.basis.y.normalized().dot(ground_normal) >= 0.92, "A snow patch is not aligned with the terrain slope.")
	var overlay: Control = world.get("ending_overlay")
	_expect(overlay != null and not overlay.visible, "Reloading a completed chapter replayed the ending overlay.")
	var title: Label = world.get("ending_title")
	var message: Label = world.get("ending_message")
	_expect(title != null and title.text == "O inverno chegou!", "The ending title is missing or wrong.")
	_expect(message != null and "família" in message.text and "comida" in message.text, "The ending message does not mention the family and the stored food.")
	_expect(not ("hibernar" in message.text.to_lower()) and not ("dormir" in message.text.to_lower()), "The ending suggests hibernation.")
	var new_adventure: Button = world.get("winter_new_adventure_button")
	_expect(new_adventure != null and new_adventure.visible and new_adventure.text == "Nova aventura", "The protected new-adventure action is missing.")
	_expect(world.status.text.begins_with("O inverno chegou!"), "The restored winter status is wrong.")
	_expect(world.get_node("CanvasLayer/FoodProgress").visible and world.get_node("CanvasLayer/FoodProgress").text == "Comida guardada: ●●●", "The restored winter progress is wrong.")
	_expect(not world.food_completion_feedback.visible and not world.home_invite.visible, "Old completion messages are still visible in winter.")
	_expect(world.food_stage.is_complete() and world.food_stage.is_active, "The restored chapter is not food-complete.")
	_expect(world.home_stage.is_complete() and world.placed_count == 3, "The restored home or dam is incomplete.")

	new_adventure.pressed.emit()
	_expect(world.restart_dialog.visible, "The new-adventure action did not ask for confirmation.")
	_expect(world.restart_dialog.title == "Começar uma nova aventura?", "The new-adventure title is wrong.")
	_expect(world.restart_dialog.get_ok_button().text == "Começar de novo", "The new-adventure confirmation button is wrong.")
	_expect(world.restart_dialog.get_cancel_button().text == "Cancelar", "The new-adventure cancel button is wrong.")
	_expect("represa" in world.restart_dialog.dialog_text and "comida" in world.restart_dialog.dialog_text, "The new-adventure warning does not mention the lost progress.")
	_expect(DamSave.load_state(SAVE_TEST_DIRECTORY)["state"]["food_placements"].size() == 3, "Opening the new-adventure confirmation cleared the save.")
	world.restart_dialog.hide()
	world.call("_continue_visiting")
	_expect(not overlay.visible and bool(world.get("winter_active")), "Continuing to visit the valley left the ending overlay or removed winter.")
	_expect(not winter.visible or bool(winter.get("is_winter")), "Continuing to visit the valley hid the winter scene.")
	world.queue_free()
	await process_frame
	_expect(DamSave.clear_save(SAVE_TEST_DIRECTORY), "Could not clean up the isolated ending save files.")
	if failures == 0:
		print("CASTOR_ENDING_OK winter_restore snow family protected_new_adventure continue")
	quit(0 if failures == 0 else 1)
