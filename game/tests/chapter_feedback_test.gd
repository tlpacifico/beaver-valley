extends SceneTree
## P1 chapter feedback regression: the child should see one current objective,
## one current-stage progress region, temporary feedback and an optional dam
## finish panel, with stage-valid voice. Uses isolated save directories.
##
## The accessors below prefer the P1 interfaces and fall back to the previous
## labels, so the same assertions document both the old overlap and the new
## behaviour.

const DamSave = preload("res://scripts/dam_save.gd")
const TEST_ROOT := "user://chapter_feedback_test/"
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
	var world: Node = load("res://scenes/movement.tscn").instantiate()
	world.save_directory = directory
	root.add_child(world)
	await _wait(func() -> bool: return world.actor != null and world.actor.is_on_floor(), 8.0)
	return world


func _objective(world: Node) -> String:
	var label := world.get("status") as Label
	return label.text if label != null else ""


func _progress(world: Node) -> String:
	var label := world.get("progress_label") as Label
	if label != null:
		return label.text
	for node_name: String in ["DamProgress", "FoodProgress"]:
		var legacy := world.get_node_or_null("CanvasLayer/" + node_name) as Label
		if legacy != null and legacy.visible:
			return legacy.text
	return ""


func _feedback(world: Node) -> Label:
	var label := world.get("stage_completion") as Label
	if label != null and label.visible:
		return label
	for node_name: String in ["CompletionFeedback", "HomeCompletionFeedback", "FoodCompletionFeedback"]:
		var legacy := world.get_node_or_null("CanvasLayer/" + node_name) as Label
		if legacy != null and legacy.visible:
			return legacy
	return null


func _feedback_visible(world: Node) -> bool:
	return _feedback(world) != null


func _feedback_text(world: Node) -> String:
	var label := _feedback(world)
	return label.text if label != null else ""


func _finish_panel_visible(world: Node) -> bool:
	var panel := world.get("finish_panel") as Control
	if panel != null:
		return panel.visible
	var legacy := world.get_node_or_null("CanvasLayer/FinishPrompt") as Control
	return legacy != null and legacy.visible


func _permanent_instructions(world: Node) -> int:
	var count := 0
	var objective := world.get("status") as Control
	if objective != null and objective.visible:
		count += 1
	var legacy_invite := world.get_node_or_null("CanvasLayer/HomeInvite") as Control
	if legacy_invite != null and legacy_invite.visible:
		count += 1
	return count


func _open_finish_panel(world: Node) -> bool:
	if not world.has_method("_set_finish_panel_open"):
		return false
	world.call("_set_finish_panel_open", true)
	return _finish_panel_visible(world)


func _close_finish_panel(world: Node) -> bool:
	var button := world.get("finish_close_button") as Button
	if button == null:
		return false
	button.pressed.emit()
	return not _finish_panel_visible(world)


func _choose_finish(world: Node, choice_id: String) -> bool:
	var buttons: Variant = world.get("finish_choice_buttons")
	if buttons is Dictionary and buttons.has(choice_id):
		var button := buttons[choice_id] as Button
		if button != null:
			button.pressed.emit()
			return true
	return bool(world.call("select_finish_choice", choice_id))


func _crest_screen(world: Node) -> Vector2:
	return world.camera.unproject_position(world.layout.dam_center() + Vector3(0.0, 0.05, 0.0))


func _two_branch_state() -> Dictionary:
	var state := DamSave.empty_state()
	state["placed_materials"] = ["branch_normal_01", "branch_normal_02"]
	return state


func _completed_dam_state(finish: String) -> Dictionary:
	var state := DamSave.empty_state()
	state["placed_materials"] = ["branch_normal_01", "branch_normal_02", "branch_normal_03"]
	state["stage_completed"] = true
	state["finish_choice"] = finish
	return state


func _complete_third_branch(world: Node) -> bool:
	var branch: Node = null
	for candidate in world.branches:
		if int(candidate.get("state")) == 0 and bool(world.call("_is_suitable_material", candidate)):
			branch = candidate
			break
	if branch == null:
		return false
	if not bool(world.request_collect(branch)):
		return false
	if not await _wait(func() -> bool: return world.carried_branch == branch):
		return false
	if not bool(world.request_place()):
		return false
	if not await _wait(func() -> bool: return int(world.placed_count) == 3):
		return false
	# P2 presents the dam celebration after the 0.45 s material flight, so wait
	# for the presentation instead of assuming the same frame as the commit.
	return await _wait(func() -> bool: return _feedback_visible(world) and _feedback_text(world) == "A represa está pronta!", 5.0)


func _first_suitable_bundle(food: Node) -> Node:
	for bundle in food.get("bundles"):
		if int(bundle.get("state")) <= 1 and bool(food.call("is_bundle_suitable", bundle)):
			return bundle
	return null


func _run() -> void:
	_expect(DamSave.clear_save(TEST_ROOT), "Could not clear the chapter-feedback test root.")
	await _check_fresh_chapter()
	await _check_transient_layout()
	await _check_completed_dam()
	await _check_final_flight_blocked()
	await _check_crest_destination()
	await _check_close_cancels_delayed_open()
	await _check_help_cancels_celebration()
	await _check_early_dismissal()
	await _check_save_failure()
	await _check_restored_dam()
	_expect(DamSave.clear_save(TEST_ROOT), "Could not clean up the chapter-feedback save directories.")
	if failures == 0:
		print("CASTOR_CHAPTER_FEEDBACK_OK objective_progress transient_completion finish_panel carry_identity stage_valid_voice save_failure mouse_touch restore")
	quit(0 if failures == 0 else 1)


## A fresh valley shows only the current dam task and no optional controls.
func _check_fresh_chapter() -> void:
	var directory := TEST_ROOT + "fresh/"
	_expect(DamSave.clear_save(directory), "Could not clear the fresh save directory.")
	var world: Node = await _spawn_world(directory)
	_expect(_objective(world) == "Escolhe um ramo para a represa.", "A fresh chapter does not show only the current dam objective: %s" % _objective(world))
	_expect(_progress(world) == "Ramos na represa: ○○○", "The fresh chapter does not show the dam progress region: %s" % _progress(world))
	_expect(not _feedback_visible(world), "A fresh chapter shows a completion message.")
	_expect(not _finish_panel_visible(world), "A fresh chapter shows the dam finish controls.")
	_expect(_permanent_instructions(world) == 1, "A fresh chapter shows more than one permanent instruction.")
	_expect(world.gnaw_button.custom_minimum_size.y >= 44.0 and world.winter_new_adventure_button.custom_minimum_size.y >= 44.0, "A child-facing button is below the 44 px touch target.")
	if world.has_method("_show_stage_completion"):
		world.call("_show_stage_completion", "A represa está pronta!", 0.25)
		world.call("_show_stage_completion", "A casa está pronta!", 0.75)
		_expect(_feedback_visible(world) and _feedback_text(world) == "A casa está pronta!", "A newer completion did not replace the older one.")
		for _frame in range(30):
			await process_frame
		_expect(_feedback_visible(world) and _feedback_text(world) == "A casa está pronta!", "An older completion expiry cleared the newer message.")
		_expect(await _wait_frames(func() -> bool: return not _feedback_visible(world), 90), "The newer completion did not expire on its own.")
	else:
		_expect(false, "The chapter does not own one transient completion message.")
	world.queue_free()
	await process_frame
	_expect(DamSave.clear_save(directory), "Could not clean the fresh save directory.")


## Long transient lines must wrap inside the 960 px reference view instead of
## running past its right edge.
func _check_transient_layout() -> void:
	var directory := TEST_ROOT + "transient_layout/"
	_expect(DamSave.clear_save(directory), "Could not clear the transient-layout save directory.")
	var world: Node = await _spawn_world(directory)
	var label: Label = world.stage_completion
	_expect(label.autowrap_mode != TextServer.AUTOWRAP_OFF, "The transient message region does not wrap text.")
	_expect(label.get_global_rect().end.x <= 960.0, "The transient message region extends past the reference viewport.")
	var long_messages: Array[String] = [
		"O círculo amarelo mostra o destino. Podes escolher outro.",
		"O inverno chegou! Podes visitar o vale ou começar uma nova aventura.",
		"Este ramo é grosso. Podes roê-lo ou escolher outro.",
	]
	for message in long_messages:
		world.call("_show_feedback", message, 3.0)
		await process_frame
		await process_frame
		_expect(label.get_line_count() >= 2, "A long transient message did not wrap: %s" % message)
		_expect(label.get_minimum_size().x <= label.size.x + 1.0, "A long transient message is wider than its region: %s" % message)
		_expect(label.get_minimum_size().y <= label.size.y + 1.0, "A long transient message is taller than its region: %s" % message)
		_expect(label.get_global_rect().end.x <= 960.0, "A long transient message extends past the reference viewport: %s" % message)
	world.queue_free()
	await process_frame
	_expect(DamSave.clear_save(directory), "Could not clean the transient-layout save directory.")


## Completing the dam shows one celebration, then the optional panel, without
## adding a second permanent invitation or touching carried items.
func _check_completed_dam() -> void:
	var directory := TEST_ROOT + "completed/"
	_expect(DamSave.clear_save(directory), "Could not clear the completed-dam save directory.")
	_expect(DamSave.save_state(_two_branch_state(), directory), "Could not prepare a two-branch dam save.")
	var world: Node = await _spawn_world(directory)
	var home: Node = world.home_stage
	var food: Node = world.food_stage
	_expect(int(world.placed_count) == 2 and not bool(home.get("is_active")), "The two-branch fixture did not restore before the home stage.")
	_expect(await _complete_third_branch(world), "The third dam branch could not be placed through the public API.")
	_expect(_feedback_visible(world) and _feedback_text(world) == "A represa está pronta!", "Completing the dam did not show the Portuguese completion message.")
	_expect(not _finish_panel_visible(world), "The finish controls were visible immediately after the dam completion.")
	_expect(_permanent_instructions(world) == 1, "The dam completion added a second permanent invitation.")
	_expect(_objective(world) == "Escolhe uma peça para a casa.", "The home objective did not follow the dam celebration: %s" % _objective(world))
	_expect(await _wait_frames(func() -> bool: return _finish_panel_visible(world), 240), "The finish panel did not open after the celebration.")
	_expect(not _feedback_visible(world), "The completion message stayed visible after its celebration.")

	# A finished dam_completed is only a valid invitation while the home stage runs.
	world.voice.cancel()
	world.voice.play_event("dam_completed")
	world.voice.player.finished.emit()
	_expect(str(world.voice.active_event) == "home_invite", "A finished dam_completed at the home stage did not play the home invitation.")
	world.voice.cancel()

	_expect(_close_finish_panel(world), "The finish panel has no working Fechar control.")
	_expect(not _finish_panel_visible(world), "The Fechar control did not close the finish panel.")

	# The completed dam crest opens the panel while a home part stays carried.
	var parts: Array = home.get("parts")
	var first_part: Node = parts[0]
	_expect(bool(home.call("request_collect", first_part)), "A home part could not be selected after the dam.")
	_expect(await _wait(func() -> bool: return home.get("carried_part") == first_part), "The home part was not carried after the dam.")
	var counts_before: Array[int] = [int(world.placed_count), int(home.get("placed_slot_count")), int(food.get("placed_count"))]
	var crest := _crest_screen(world)
	var mouse_click := InputEventMouseButton.new()
	mouse_click.device = 0
	mouse_click.button_index = MOUSE_BUTTON_LEFT
	mouse_click.pressed = true
	mouse_click.position = crest
	world._unhandled_input(mouse_click)
	_expect(bool(world.click_pending), "A physical mouse press on the completed dam was not queued.")
	world.click_pending = false
	_expect(bool(world._move_from_screen(world.click_position)), "A mouse tap on the completed dam did not open its finish panel.")
	_expect(_finish_panel_visible(world), "The mouse path did not open the finish panel through the dam crest.")
	_expect(home.get("carried_part") == first_part, "Opening the finish panel dropped the carried home part.")
	_expect(int(world.placed_count) == counts_before[0] and int(home.get("placed_slot_count")) == counts_before[1] and int(food.get("placed_count")) == counts_before[2], "Opening the finish panel changed the placed counts.")
	_expect(bool(world.actor.is_arrived()), "Opening the finish panel issued a walking command.")

	_expect(_choose_finish(world, "finish_moss"), "The finish panel did not accept the moss choice.")
	_expect(not _finish_panel_visible(world), "Choosing a finish did not close the panel.")
	_expect(str(world.finish_choice) == "finish_moss", "Choosing a finish did not update the world state.")
	var saved_after_choice: Dictionary = DamSave.load_state(directory)["state"]
	_expect(str(saved_after_choice["finish_choice"]) == "finish_moss", "Choosing a finish was not saved.")

	_expect(bool(world._move_from_screen(crest)), "The completed dam could not be tapped again while carrying a home part.")
	_expect(_finish_panel_visible(world), "The finish panel did not reopen through the dam crest.")
	_expect(_close_finish_panel(world), "The reopened finish panel could not be closed without choosing.")
	_expect(not _finish_panel_visible(world), "Closing without choosing left the finish panel visible.")
	_expect(str(world.finish_choice) == "finish_moss", "Closing without choosing discarded the saved finish choice.")
	var saved_after_close: Dictionary = DamSave.load_state(directory)["state"]
	_expect(str(saved_after_close["finish_choice"]) == "finish_moss", "Closing without choosing changed the saved finish choice.")

	world.ending_overlay.visible = true
	_expect(not _open_finish_panel(world), "The finish panel opened through the ending overlay.")
	world.ending_overlay.visible = false
	world.restart_dialog.popup_centered()
	await process_frame
	_expect(not _open_finish_panel(world), "The finish panel opened through the restart dialog.")
	world.restart_dialog.hide()

	_expect(bool(home.call("request_place", 0)), "The carried home part could not be placed at the wall position.")
	_expect(await _wait(func() -> bool: return int(home.get("placed_slot_count")) == 1), "The first home part was not placed.")
	_expect(_objective(world) == "Escolhe uma peça para a casa.", "The home objective did not return after a placement: %s" % _objective(world))

	# The home completes into the food stage with normal persistence.
	var second_part: Node = parts[1]
	_expect(bool(home.call("request_collect", second_part)), "The second home part could not be selected.")
	_expect(await _wait(func() -> bool: return home.get("carried_part") == second_part), "The second home part was not carried.")
	_expect(bool(home.call("request_place", 1)), "The second home part could not be placed at the roof position.")
	_expect(await _wait(func() -> bool: return int(home.get("placed_slot_count")) == 2), "The home did not complete.")
	_expect(bool(home.call("is_complete")) and bool(food.get("is_active")), "Completing the home did not start the food stage.")
	_expect(_feedback_visible(world) and _feedback_text(world) == "A casa está pronta!", "Completing the home did not show its Portuguese completion message.")
	_expect(not _finish_panel_visible(world), "The dam finish controls stayed visible during the food stage.")
	_expect(_objective(world) == "Escolhe um feixe de comida.", "The food stage did not become the only permanent objective: %s" % _objective(world))
	_expect(_progress(world) == "Comida guardada: ○○○", "The food stage did not replace the current progress region: %s" % _progress(world))
	_expect(await _wait_frames(func() -> bool: return not _feedback_visible(world), 180), "The home completion message did not expire.")
	_expect(_permanent_instructions(world) == 1, "The food stage shows a second permanent instruction.")

	# A late dam_completed must not play an obsolete invitation during food.
	world.voice.play_event("dam_completed")
	world.voice.player.finished.emit()
	_expect(str(world.voice.active_event) != "home_invite", "A late dam_completed played the home invitation during the food stage.")
	world.voice.play_event("dam_completed")
	world.voice.cancel()
	world.voice.player.finished.emit()
	_expect(str(world.voice.active_event).is_empty(), "A cancelled dam_completed still produced a voice callback.")
	_expect(bool(food.get("is_active")), "Headless progress depended on audio completion.")

	# The completed dam crest opens the panel while a food bundle stays carried.
	var bundle := _first_suitable_bundle(food)
	_expect(bundle != null, "The food stage has no suitable bundle for the crest check.")
	if bundle != null:
		_expect(bool(food.call("request_collect", bundle)), "A suitable food bundle could not be selected.")
		_expect(await _wait(func() -> bool: return food.get("carried_bundle") == bundle), "The suitable food bundle was not carried.")
		counts_before = [int(world.placed_count), int(home.get("placed_slot_count")), int(food.get("placed_count"))]
		var crest_touch_position := _crest_screen(world)
		var screen_touch := InputEventScreenTouch.new()
		screen_touch.pressed = true
		screen_touch.position = crest_touch_position
		world._unhandled_input(screen_touch)
		_expect(bool(world.click_pending), "A screen touch on the completed dam was not queued.")
		world.click_pending = false
		_expect(bool(world._move_from_screen(world.click_position)), "A touch on the completed dam did not open its finish panel.")
		_expect(_finish_panel_visible(world), "The touch path did not open the finish panel through the dam crest.")
		_expect(food.get("carried_bundle") == bundle, "Opening the finish panel dropped the carried food bundle.")
		_expect(int(world.placed_count) == counts_before[0] and int(home.get("placed_slot_count")) == counts_before[1] and int(food.get("placed_count")) == counts_before[2], "Opening the finish panel changed the placed counts.")
		_expect(bool(world.actor.is_arrived()), "Opening the finish panel issued a walking command.")
		_expect(_close_finish_panel(world), "The food-stage finish panel could not be closed.")
		_expect(not _finish_panel_visible(world), "The food-stage finish panel stayed visible.")

	world.save_directory = directory
	_expect(bool(world.call("_save_dam_state")), "Could not persist the completed home and carried food stage.")
	world.queue_free()
	await process_frame
	_expect(DamSave.clear_save(directory), "Could not clean the completed-dam save directory.")


## The third durable placement closes dam-material collection immediately; a
## branch reserved during the final flight must never be picked up in the home
## stage, with its gnaw guidance, after the gnaw control is gone.
func _check_final_flight_blocked() -> void:
	var directory := TEST_ROOT + "final_flight_block/"
	_expect(DamSave.clear_save(directory), "Could not clear the final-flight save directory.")
	_expect(DamSave.save_state(_two_branch_state(), directory), "Could not prepare the final-flight dam save.")
	var world: Node = await _spawn_world(directory)
	var final_branch: Node = null
	var leftover: Node = null
	for candidate in world.branches:
		if candidate.stable_id == "branch_normal_03":
			final_branch = candidate
		elif candidate.stable_id == "branch_thick_01":
			leftover = candidate
	_expect(final_branch != null and leftover != null, "The final-flight check could not find its branches.")
	if final_branch != null and leftover != null:
		_expect(bool(world.request_collect(final_branch)), "The final dam branch could not be selected.")
		_expect(await _wait(func() -> bool: return world.get("carried_branch") == final_branch), "The final dam branch was not carried.")
		_expect(bool(world.request_place()), "The final dam branch could not be routed.")
		_expect(await _wait(func() -> bool: return int(world.get("placed_count")) == 3), "The final dam branch did not commit.")
		_expect(not bool(world.home_stage.is_active), "The home stage activated before the final branch arrived.")
		_expect(not bool(world.request_collect(leftover)), "Dam collection was still accepted after the final durable placement.")
		var screen: Vector2 = world.camera.unproject_position(leftover.global_position + Vector3.UP * 0.16)
		world._move_from_screen(screen)
		_expect(world.get("pending_branch") == null, "A screen tap during the final flight reserved a branch.")
		_expect(not bool(leftover.visible), "A leftover dam branch stayed visible after the final commit.")
		_expect(await _wait(func() -> bool: return bool(world.home_stage.is_active)), "The home stage did not start after the final flight.")
		await _wait_frames(func() -> bool: return false, 300)
		_expect(world.get("carried_branch") == null, "The beaver picked up a leftover branch during the home stage.")
		_expect(int(leftover.get("state")) == CollectibleBranch.State.FREE, "The leftover branch left its free state.")
		_expect(str(world.voice.active_event) != "thick_branch", "Thick-branch guidance played during the home stage.")
		_expect(world.status.text == "Escolhe uma peça para a casa.", "The home objective was replaced by a dam instruction: %s" % world.status.text)
	world.queue_free()
	await process_frame
	_expect(DamSave.clear_save(directory), "Could not clean the final-flight save directory.")


func _find_free_suitable(world: Node) -> Node:
	for candidate in world.branches:
		if int(candidate.get("state")) == 0 and bool(world.call("_is_suitable_material", candidate)):
			return candidate
	return null


## The visible crest outline is a placement target before completion, not an
## inert decoration that rejects the tap as invalid ground.
func _check_crest_destination() -> void:
	var directory := TEST_ROOT + "crest_destination/"
	_expect(DamSave.clear_save(directory), "Could not clear the crest-destination save directory.")
	var world: Node = await _spawn_world(directory)
	var branch := _find_free_suitable(world)
	_expect(branch != null, "The crest-destination check found no suitable branch.")
	if branch != null:
		_expect(bool(world.request_collect(branch)), "A branch could not be selected for the crest-destination check.")
		_expect(await _wait(func() -> bool: return world.get("carried_branch") == branch), "The branch was not carried for the crest-destination check.")
		_expect(bool(world._move_from_screen(_crest_screen(world))), "Tapping the pre-completion dam crest did not start placement.")
		_expect(bool(world.placement_pending), "The pre-completion crest tap did not plan a placement.")
		_expect(_feedback_text(world) != "Escolhe um sítio livre no chão.", "The pre-completion crest tap was rejected as invalid ground.")
		world.request_move(world.layout.anchor(&"spawn"))
	world.queue_free()
	await process_frame
	_expect(DamSave.clear_save(directory), "Could not clean the crest-destination save directory.")


## Closing the panel during the celebration must also cancel the delayed open.
func _check_close_cancels_delayed_open() -> void:
	var directory := TEST_ROOT + "close_during_celebration/"
	_expect(DamSave.clear_save(directory), "Could not clear the celebration-close save directory.")
	_expect(DamSave.save_state(_two_branch_state(), directory), "Could not prepare the celebration-close dam save.")
	var world: Node = await _spawn_world(directory)
	_expect(await _complete_third_branch(world), "The celebration-close dam did not complete.")
	_expect(not _finish_panel_visible(world), "The finish panel opened before the celebration ended.")
	_expect(bool(world._move_from_screen(_crest_screen(world))), "The crest did not open the panel during the celebration.")
	_expect(_finish_panel_visible(world), "The finish panel did not open through the crest during the celebration.")
	_expect(_close_finish_panel(world), "Fechar failed to close the panel during the celebration.")
	await _wait_frames(func() -> bool: return false, 160)
	_expect(not _finish_panel_visible(world), "The finish panel reopened after Fechar once the celebration expired.")
	world.queue_free()
	await process_frame
	_expect(DamSave.clear_save(directory), "Could not clean the celebration-close save directory.")


## Explicit help cancels obsolete guidance, including a running celebration.
func _check_help_cancels_celebration() -> void:
	var directory := TEST_ROOT + "help_dismissal/"
	_expect(DamSave.clear_save(directory), "Could not clear the help-dismissal save directory.")
	_expect(DamSave.save_state(_two_branch_state(), directory), "Could not prepare the help-dismissal dam save.")
	var world: Node = await _spawn_world(directory)
	_expect(await _complete_third_branch(world), "The help-dismissal dam did not complete.")
	_expect(_feedback_text(world) == "A represa está pronta!", "The help-dismissal chapter showed no celebration.")
	_expect(bool(world.request_help()), "Help was unavailable during the dam celebration.")
	_expect(_feedback_text(world) != "A represa está pronta!", "Help did not clear the obsolete dam celebration.")
	await _wait_frames(func() -> bool: return false, 160)
	_expect(not _finish_panel_visible(world), "The finish panel opened after help had dismissed the celebration.")
	world.queue_free()
	await process_frame
	_expect(DamSave.clear_save(directory), "Could not clean the help-dismissal save directory.")


## A new action dismisses the dam celebration and must not reopen the panel later.
func _check_early_dismissal() -> void:
	var directory := TEST_ROOT + "early/"
	_expect(DamSave.clear_save(directory), "Could not clear the early-dismissal save directory.")
	_expect(DamSave.save_state(_two_branch_state(), directory), "Could not prepare the early-dismissal dam save.")
	var world: Node = await _spawn_world(directory)
	var home: Node = world.home_stage
	_expect(await _complete_third_branch(world), "The early-dismissal dam did not complete.")
	_expect(_feedback_visible(world) and _feedback_text(world) == "A represa está pronta!", "The early-dismissal chapter showed no dam celebration.")
	var parts: Array = home.get("parts")
	_expect(bool(home.call("request_collect", parts[0])), "A home part could not interrupt the dam celebration.")
	_expect(await _wait_frames(func() -> bool: return not _feedback_visible(world), 30), "A new action did not dismiss the completion message early.")
	for _frame in range(180):
		await process_frame
	_expect(not _finish_panel_visible(world), "The finish panel opened after its celebration had been dismissed early.")
	world.queue_free()
	await process_frame
	_expect(DamSave.clear_save(directory), "Could not clean the early-dismissal save directory.")


## A forced save failure must stay visible through a celebration and the
## home-to-food transition, without turning into a completion message.
func _check_save_failure() -> void:
	var directory := TEST_ROOT + "save_failure/"
	_expect(DamSave.clear_save(directory), "Could not clear the save-failure save directory.")
	_expect(DamSave.save_state(_two_branch_state(), directory), "Could not prepare the save-failure dam save.")
	var world: Node = await _spawn_world(directory)
	var home: Node = world.home_stage
	var food: Node = world.food_stage
	world.save_directory = "res://unsafe"
	_expect(await _complete_third_branch(world), "The save-failure dam did not complete.")
	_expect(world.status.text == "Não foi possível guardar o progresso. Pede ajuda a um adulto.", "The dam completion hid the save warning.")
	_expect(_feedback_visible(world) and _feedback_text(world) == "A represa está pronta!", "The save warning replaced the dam celebration.")
	_expect(_permanent_instructions(world) == 1, "The failed dam save added a second permanent instruction.")
	var parts: Array = home.get("parts")
	for slot_index in range(2):
		var part: Node = parts[slot_index]
		_expect(bool(home.call("request_collect", part)), "A save-failure home part could not be selected.")
		_expect(await _wait(func() -> bool: return home.get("carried_part") == part), "A save-failure home part was not carried.")
		_expect(bool(home.call("request_place", slot_index)), "A save-failure home part could not be placed.")
		_expect(await _wait(func() -> bool: return int(home.get("placed_slot_count")) == slot_index + 1), "A save-failure home part was not placed.")
		_expect(world.status.text == "Não foi possível guardar o progresso. Pede ajuda a um adulto.", "A home placement hid the save warning.")
	_expect(bool(home.call("is_complete")) and bool(food.get("is_active")), "The save-failure home did not start the food stage.")
	_expect(_feedback_visible(world) and _feedback_text(world) == "A casa está pronta!", "The home completion message was hidden by the save warning.")
	_expect(not _finish_panel_visible(world), "The finish panel appeared during the failed save transition.")
	_expect(_progress(world) == "Comida guardada: ○○○", "The failed save transition did not update the food progress.")
	world.save_directory = directory
	_expect(bool(world.call("_save_dam_state")), "The isolated save directory was not restored after the forced failure.")
	world.call("_refresh_chapter_interface")
	_expect(_objective(world) == "Escolhe um feixe de comida.", "The food objective did not return after the save recovered: %s" % _objective(world))
	world.queue_free()
	await process_frame
	_expect(DamSave.clear_save(directory), "Could not clean the save-failure save directory.")


## Restoring a completed dam leaves the panel closed, no celebration and no
## completion narration, with the saved accent applied.
func _check_restored_dam() -> void:
	var directory := TEST_ROOT + "restored/"
	_expect(DamSave.clear_save(directory), "Could not clear the restored-dam save directory.")
	_expect(DamSave.save_state(_completed_dam_state(""), directory), "Could not prepare a completed dam save with an unset finish.")
	var world: Node = await _spawn_world(directory)
	_expect(int(world.placed_count) == 3 and bool(world.home_stage.is_active), "The completed dam did not restore the home stage.")
	_expect(str(world.finish_choice).is_empty(), "The restored unset finish was changed.")
	_expect(not _finish_panel_visible(world), "Restoring a completed dam opened the finish panel.")
	_expect(not _feedback_visible(world), "Restoring a completed dam replayed a completion message.")
	_expect(_objective(world) == "Escolhe uma peça para a casa.", "The restored stage does not show its current objective: %s" % _objective(world))
	_expect(_progress(world) == "Peças na casa: ○○", "The restored stage does not show its current progress: %s" % _progress(world))
	_expect(not world.finish_trim.visible, "Restoring an unset finish showed a finish accent.")
	_expect(str(world.voice.active_event).is_empty(), "Restoring a completed dam replayed completion narration.")
	_expect(world.carried_branch == null and world.home_stage.carried_part == null and world.food_stage.carried_bundle == null, "Restoring a completed dam left an item in the paws.")
	_expect(world.celebration_sparkles.all(func(sparkle: MeshInstance3D) -> bool: return not sparkle.visible), "Restoring a completed dam replayed celebration sparkles at the world origin.")
	world.queue_free()
	await process_frame

	# The saved accent is applied immediately, still with the panel closed.
	_expect(DamSave.save_state(_completed_dam_state("finish_golden"), directory), "Could not prepare a completed dam save with a saved accent.")
	var accented: Node = await _spawn_world(directory)
	_expect(str(accented.finish_choice) == "finish_golden" and accented.finish_trim.visible, "Restoring the saved finish did not show its accent.")
	var accent_material := (accented.finish_trim.mesh as BoxMesh).material as StandardMaterial3D
	_expect(accent_material.albedo_color.is_equal_approx(Color("d6a83e")), "Restoring the saved finish used the wrong accent colour.")
	_expect(not _finish_panel_visible(accented), "Restoring a saved accent opened the finish panel.")
	_expect(not _feedback_visible(accented), "Restoring a saved accent replayed a completion message.")
	accented.queue_free()
	await process_frame
	_expect(DamSave.clear_save(directory), "Could not clean the restored-dam save directory.")
