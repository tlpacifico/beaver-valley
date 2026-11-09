extends SceneTree
## Integration: real path with physics, bounds, obstacles and target changes.

const DamSave = preload("res://scripts/dam_save.gd")
const SAVE_TEST_DIRECTORY := "user://dam_save_world_test/"
var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _expect(condition: bool, description: String) -> void:
	if not condition:
		failures += 1
		push_error(description)


func _run() -> void:
	_expect(DamSave.clear_save(SAVE_TEST_DIRECTORY), "Could not clear the isolated integration-test save directory.")
	# Headless mode creates a 64x64 virtual window; events use window pixels.
	root.size = Vector2i(960, 600)
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--physics-rate="):
			Engine.physics_ticks_per_second = int(argument.get_slice("=", 1))
	var scene_path := "res://scenes/movement.tscn"
	if not ResourceLoader.exists(scene_path):
		push_error("Movement scene does not exist yet.")
		quit(1)
		return
	var world: Node = load(scene_path).instantiate()
	world.save_directory = SAVE_TEST_DIRECTORY
	root.add_child(world)
	await physics_frame
	await physics_frame
	_expect(world.voice.active_event == "dam_start", "Entering the scene did not start the introduction voice cue.")
	world.voice.play_event("help_collect")
	var help_stream: AudioStream = world.voice.player.stream
	world.voice.play_event("help_collect")
	_expect(world.voice.active_event == "help_collect" and world.voice.player.stream == help_stream, "Repeating the same help event restarted or replaced its voice clip.")
	world.sfx.play_event("collect")
	_expect(world.sfx.active_event == "collect" and world.voice.active_event == "help_collect" and world.voice.player.stream == help_stream, "Collection sound interrupted the active voice line.")
	_expect(world.sfx.player.stream != null and world.sfx.player.volume_db <= -8.0, "Provisional effects are missing or not mixed quietly.")
	world.voice.player.finished.emit()
	_expect(world.voice.active_event.is_empty(), "Finished voice cue did not become available for repetition.")
	world.voice.play_event("help_collect")
	_expect(world.voice.active_event == "help_collect", "Finished help cue could not be repeated.")
	world.voice.play_event("dam_completed")
	world.voice.player.finished.emit()
	_expect(world.voice.active_event == "home_invite", "Home invitation did not follow the completion line.")
	world.voice.play_event("help_place")
	_expect(world.voice.active_event == "help_place" and world.voice.player.stream != help_stream, "A changed situation did not replace the outdated voice cue.")
	world.voice.cancel()
	_expect(world.voice.active_event.is_empty() and not world.voice.player.playing, "Canceling an outdated voice cue did not stop playback.")
	_expect(world.branch_cues.size() == 5 and world.branch_cues.all(func(cue: MeshInstance3D) -> bool: return cue.visible), "Available branches do not have persistent visual selection cues.")
	_expect(world.placement_cue != null and world.placement_cue.visible, "Dam target does not have a persistent visual cue.")
	_expect(world.get_node("CanvasLayer/DamProgress").text == "Ramos na represa: ○○○", "Initial dam progress is not shown visually.")
	_expect(world.help_button.visible and world.help_button.text == "?" and world.help_button.tooltip_text == "Ajuda", "Discreet on-request help button is missing.")
	# Free branch hit areas must never intercept taps anywhere on the dam target.
	for target_point in [Vector3(1.1, 0.05, -4.8), Vector3(3.9, 0.05, -4.8), Vector3(3.9, 0.05, -3.85), world.placement_center + Vector3.UP * 0.05]:
		var dam_target_screen: Vector2 = world.camera.unproject_position(target_point)
		_expect(not world._move_from_screen(dam_target_screen), "Target tap without a carried branch should not start an action.")
		_expect(world.pending_branch == null and world.status.text == "Toca no ramo e depois na zona amarela.", "A free branch intercepted a point on the dam target.")
	_expect(world.request_help() and world.incompatible_place_attempts == 0, "Help was unavailable before incompatible placement attempts or changed the attempt counter.")
	_expect(world.support_characters._owl.visible, "Requesting help did not show the owl.")
	_expect(world.voice.active_event == "help_collect" and world.help_highlight_active, "No-material help did not speak and highlight a suitable branch.")
	world.voice.cancel()
	world.help_highlight_active = false
	world._update_branch_cues()
	_expect(not world.adult_restart_button.visible, "Adult restart should be hidden from the child's normal controls.")
	_expect(world.celebration_sparkles.size() == 5 and world.celebration_sparkles.all(func(sparkle: MeshInstance3D) -> bool: return not sparkle.visible), "Celebration visuals should be prepared but hidden before completion.")
	# A touchscreen hold can also emit a mouse event with the emulation device ID.
	# It must reveal adult controls without becoming a world click.
	var status_before_title_hold: String = world.status.text
	var title_press := InputEventScreenTouch.new()
	title_press.pressed = true
	title_press.position = Vector2(100, 24)
	world._unhandled_input(title_press)
	_expect(world.title_touch_active, "Title-area screen touch did not begin the adult gesture.")
	var emulated_click := InputEventMouseButton.new()
	emulated_click.device = InputEvent.DEVICE_ID_EMULATION
	emulated_click.button_index = MOUSE_BUTTON_LEFT
	emulated_click.pressed = true
	emulated_click.position = title_press.position
	world._unhandled_input(emulated_click)
	_expect(not world.click_pending, "Touch-emulated mouse event was queued as a world click.")
	world._update_adult_restart_hold(world.title_hold_started + 1.3)
	_expect(world.adult_restart_button.visible, "Long title touch did not reveal the adult restart control.")
	_expect(world.status.text == status_before_title_hold, "Long title touch produced an unrelated ground status message.")
	_expect(not world.click_pending, "Long title touch left an invalid world click pending.")
	var title_release := InputEventScreenTouch.new()
	title_release.pressed = false
	title_release.position = title_press.position
	world._unhandled_input(title_release)
	var real_mouse_click := InputEventMouseButton.new()
	real_mouse_click.device = 0
	real_mouse_click.button_index = MOUSE_BUTTON_LEFT
	real_mouse_click.pressed = true
	real_mouse_click.position = Vector2(500, 300)
	world._unhandled_input(real_mouse_click)
	_expect(world.click_pending and world.click_position == real_mouse_click.position, "Physical mouse click was ignored with touch-emulated mouse filtering enabled.")
	world.click_pending = false
	# Simulate the optional fixed-angle camera following a moved beaver. The branch
	# must remain selectable through the camera's updated projection.
	world.camera_follow_enabled = true
	var initial_follow_basis: Basis = world.camera.global_basis
	world.actor.position = Vector3(3.9, 0.05, 3.5)
	var camera_position_before_follow: Vector3 = world.camera.global_position
	world._update_follow_camera(0.1)
	_expect(world.camera.global_position.distance_to(camera_position_before_follow) > 0.1, "Follow camera did not begin moving toward the beaver.")
	_expect(world.camera.global_basis.is_equal_approx(initial_follow_basis), "Follow camera rotated while moving; the experiment requires a fixed angle.")
	world._update_follow_camera(10.0)
	var nearby_branch: Node3D = world.branches[1]
	var branch_screen: Vector2 = world.camera.unproject_position(nearby_branch.global_position + Vector3.UP * 0.15)
	_expect(Rect2(Vector2.ZERO, Vector2(960, 600)).has_point(branch_screen), "Follow camera moved the nearby branch outside the viewport.")
	_expect(world._move_from_screen(branch_screen), "Branch could not be selected after the follow camera moved.")
	_expect(world.pending_branch == nearby_branch, "Moved-camera ray selected the wrong branch.")
	world._cancel_pending_collection()
	world.actor.follow_path(PackedVector3Array())
	world.actor.position = Vector3(2.0, 0.05, -4.0)
	world._update_follow_camera(10.0)
	var actor_screen: Vector2 = world.camera.unproject_position(world.actor.global_position)
	var follow_target_screen: Vector2 = world.camera.unproject_position(world.placement_center)
	var viewport_rect := Rect2(Vector2.ZERO, Vector2(960, 600))
	_expect(viewport_rect.has_point(actor_screen), "Follow camera did not keep the beaver in frame near the dam.")
	_expect(viewport_rect.has_point(follow_target_screen), "Follow camera did not keep the dam target in frame near the dam.")
	world.camera_follow_enabled = false
	world.actor.position = Vector3(-4, 0.05, 0)
	world.camera.position = Vector3(11, 14, 15)
	world.camera.look_at(Vector3.ZERO)
	_expect(not world.request_move(Vector3(20, 0, 0)), "Should reject a target outside the valley.")
	_expect(not world.request_move(Vector3.ZERO), "Should reject a target inside the rock.")
	_expect(world.request_move(Vector3(4, 0, 0)), "Should accept a target on the other side of the rock.")
	for frame in range(700):
		await physics_frame
		var position: Vector3 = world.actor.position
		_expect(absf(position.x) <= 6.25 and absf(position.z) <= 5.25, "Character left the bounds.")
		_expect(not (absf(position.x) < 0.65 and absf(position.z) < 2.65), "Character passed through the rock.")
		_expect(position.y >= -0.05, "Character fell through the ground.")
		if world.actor.is_arrived():
			break
	_expect(world.actor.position.distance_to(Vector3(4, 0, 0)) < 0.15, "Did not reach the target by going around the rock.")
	_expect(world.request_move(Vector3(5, 0, 4)), "First redirect failed.")
	for frame in range(10):
		await physics_frame
	_expect(world.request_move(Vector3(3, 0, -4)), "Changing target while moving failed.")
	_expect(not world.request_move(Vector3(100, 0, 100)), "Invalid click should be rejected while moving.")
	for frame in range(500):
		await physics_frame
		if world.actor.is_arrived():
			break
	_expect(world.actor.position.distance_to(Vector3(3, 0, -4)) < 0.15, "Invalid click changed the last valid target.")
	# Exercises real mouse input and camera projection, not just the target API.
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = world.camera.unproject_position(Vector3(5, 0, -4))
	Input.parse_input_event(click)
	await physics_frame
	await physics_frame
	_expect(world.destination.position.distance_to(Vector3(5, 0.04, -4)) < 0.1, "Screen click did not select the expected target.")
	var elapsed: float = 0.0
	while not world.actor.is_arrived() and elapsed < 3.0:
		await physics_frame
		elapsed += 1.0 / Engine.physics_ticks_per_second
	_expect(world.actor.position.distance_to(Vector3(5, 0, -4)) < 0.15, "Character did not reach the clicked target.")
	_expect(elapsed > 0.5 and elapsed < 1.0, "Wrong speed for a two-meter path.")
	_expect(not world._move_from_screen(world.camera.unproject_position(Vector3(0, 0.85, 0))), "Click on the rock should be rejected.")
	var first_branch: Node3D = world.branches[0]
	var second_branch: Node3D = world.branches[1]
	# The tapped point lies on the visible outer ring, beyond the old narrow collider.
	_expect(world._move_from_screen(world.camera.unproject_position(first_branch.global_position + Vector3(0.7, 0.05, 0))), "Tapping the visible outer edge of a branch cue did not select it.")
	_expect(world.pending_branch == first_branch and first_branch.state == 1, "Selected branch was not reserved while approaching.")
	_expect(world.branch_cues[0].scale.x > 1.0, "Reserved branch did not receive a stronger visual cue.")
	for frame in range(700):
		await physics_frame
		if world.carried_branch == first_branch:
			break
	_expect(world.carried_branch == first_branch and first_branch.get_parent() == world.actor, "Branch was not carried after arrival.")
	_expect(world.sfx.active_event == "collect", "Branch pickup did not play the collection sound.")
	_expect(not world.branch_cues[0].visible, "Carried branch still appears selectable on the ground.")
	_expect(world.request_help() and world.voice.active_event == "thick_branch", "On-request help did not explain the thick branch.")
	_expect(world.gnaw_button.modulate == Color("fff0a3"), "Thick-branch help did not highlight its gnaw action.")
	world.voice.cancel()
	_expect(world.request_collect(second_branch), "Selecting another branch failed.")
	for frame in range(900):
		await physics_frame
		if world.carried_branch == second_branch:
			break
	_expect(world.carried_branch == second_branch, "Second branch was not carried after arrival.")
	_expect(second_branch.bent and world.status.text == "O ramo podre dobra! Vamos escolher outro.", "Rotten branch did not bend and comment when collected.")
	_expect(world.request_help() and world.voice.active_event == "rotten_branch", "On-request help did not explain the rotten branch.")
	_expect(not world.request_place() and not world.request_place(), "Rotten branch was accepted for the dam.")
	_expect(world.help_highlight_active and world.voice.active_event == "help_compatible" and (world.branch_cues[2].mesh as TorusMesh).material.albedo_color == Color("70e6a1"), "Two incompatible placements did not speak and highlight a suitable branch.")
	_expect(first_branch.get_parent() == world and first_branch.state == 0, "Swapped branch did not return to its origin.")
	_expect(world.request_collect(second_branch), "Repeated selection of carried branch failed.")
	_expect(second_branch.get_parent() == world.actor and second_branch.state == 2, "Repeated selection duplicated or dropped the carried branch.")
	var third_branch: Node3D = world.branches[2]
	_expect(world.request_collect(third_branch), "Approach for third branch failed.")
	var pending_path: PackedVector3Array = world.actor.waypoints.duplicate()
	var pending_destination: Vector3 = world.destination.position
	_expect(not world._move_from_screen(world.camera.unproject_position(Vector3(0, 0.85, 0))), "Invalid rock click should be rejected during branch approach.")
	_expect(world.pending_branch == third_branch and third_branch.state == 1, "Invalid ground click canceled the reserved branch.")
	_expect(world.actor.waypoints == pending_path and world.destination.position == pending_destination, "Invalid ground click changed the branch approach path.")
	_expect(world.request_collect(second_branch), "Selecting the carried branch during another approach failed.")
	_expect(world.pending_branch == null and third_branch.state == 0, "Selecting the carried branch did not cancel the pending pickup.")
	_expect(world.actor.is_arrived() and world.carried_branch == second_branch and second_branch.get_parent() == world.actor, "Canceling a pickup changed the carried branch or left the beaver moving.")
	_expect(world.request_collect(third_branch), "Retrying the third branch approach failed.")
	_expect(world.request_move(Vector3(2, 0, -4)), "Valid ground destination did not replace the branch approach.")
	_expect(world.pending_branch == null and third_branch.state == 0, "Valid ground click did not cancel the reserved branch.")
	_expect(world.destination.position.distance_to(Vector3(2, 0.04, -4)) < 0.1, "Valid ground click did not set the replacement destination.")
	_expect(world.request_collect(third_branch), "Could not reserve branch for failed placement-route case.")
	var failed_route_path: PackedVector3Array = world.actor.waypoints.duplicate()
	var placement_cells: Array[Vector2i] = [Vector2i(2, -4), Vector2i(3, -4), Vector2i(2, -3), Vector2i(3, -3)]
	for cell in placement_cells:
		world.navigation.set_point_solid(cell, true)
	_expect(not world.request_place(), "Placement should fail when every approach cell is blocked.")
	_expect(world.pending_branch == third_branch and third_branch.state == 1, "Failed placement route canceled the pending branch reservation.")
	_expect(world.actor.waypoints == failed_route_path, "Failed placement route changed the active pickup path.")
	for cell in placement_cells:
		world.navigation.set_point_solid(cell, false)
	_expect(world.request_collect(second_branch), "Could not cancel pickup after failed placement-route case.")
	_expect(world.pending_branch == null and third_branch.state == 0, "Pickup reservation was not recoverable after failed placement route.")
	# Place each branch by tapping the broad target; repeated taps during the approach
	# must not place the same branch twice or consume it before arrival.
	var placed_branches: Array[Node3D] = []
	var suitable_branch_indices: Array[int] = [0, 2, 3]
	for branch_index in range(3):
		var branch_to_place: CollectibleBranch = world.branches[suitable_branch_indices[branch_index]]
		_expect(world.request_collect(branch_to_place), "Could not collect branch for placement.")
		for frame in range(1200):
			await physics_frame
			if world.carried_branch == branch_to_place:
				break
		_expect(world.carried_branch == branch_to_place, "Branch was not carried before placement.")
		if branch_to_place.kind == CollectibleBranch.Kind.THICK:
			_expect(not world.request_place() and not world.request_place(), "Thick branch was accepted before gnawing.")
			var original_model_scale: Vector3 = branch_to_place.get_node("BranchModel").scale
			_expect(branch_to_place.thick_bulge != null and branch_to_place.thick_bulge.visible, "Thick branch did not have a visibly enlarged middle section.")
			_expect(world.request_gnaw() and branch_to_place.gnawed, "Thick branch could not be gnawed.")
			_expect(world.sfx.active_event == "gnaw", "Gnaw action did not play its sound effect.")
			_expect(not branch_to_place.thick_bulge.visible and branch_to_place.gnaw_scars.size() == 2, "Gnawing did not create visible bite marks and remove the thick overlay.")
			_expect(branch_to_place.get_node("BranchModel").scale == original_model_scale, "Gnawing changed the branch model scale or attachment.")
		if branch_index == 0:
			var other_branch: Node3D = world.branches[1]
			_expect(world.request_collect(other_branch), "Could not start second pickup during placement scenario.")
			_expect(world.pending_branch == other_branch and other_branch.state == 1, "Second branch was not reserved during first branch approach to target.")
		var target_screen: Vector2 = world.camera.unproject_position(world.placement_center + Vector3.UP * 0.1)
		_expect(world._move_from_screen(target_screen), "Wide target click did not start placement.")
		if branch_index == 0:
			_expect(world.pending_branch == null and world.branches[1].state == 0, "Target tap did not cancel the other branch reservation after finding a valid placement path.")
		_expect(world.placement_pending and world.carried_branch == branch_to_place, "Placement occurred before arrival.")
		_expect(world._move_from_screen(target_screen), "Repeated target tap should be harmless during placement.")
		for frame in range(1200):
			await physics_frame
			if world.placed_count == branch_index + 1:
				break
		_expect(world.placed_count == branch_index + 1, "Placement did not complete once on arrival.")
		_expect(world.visual_environment.get_visible_dam_log_count() == world.placed_count, "Visual dam did not match the placed material count.")
		if branch_index < 2:
			_expect(world.sfx.active_event == "place", "Dam placement did not play its sound effect.")
		else:
			_expect(world.sfx.active_event == "complete", "Dam completion did not play its sound effect.")
			_expect(world.voice.active_event == "dam_completed", "Dam completion sound interrupted the completion voice line.")
		_expect(world.carried_branch == null and branch_to_place.state == 3, "Placed branch was lost or remained carried.")
		if branch_index == 0:
			_expect(world.branches[1].state == 0 and world.branches[1].get_parent() == world, "Pending branch was collected at a distance when the beaver reached the placement target.")
		_expect(branch_to_place.get_parent() == world, "Placed branch is not accounted for in the world.")
		placed_branches.append(branch_to_place)
		var expected_depths: Array[float] = [1.2, 1.6, 2.0]
		var water_mesh := world.water_surface.mesh as BoxMesh
		_expect(is_equal_approx(water_mesh.size.z, expected_depths[branch_index]), "Water did not advance to the matching prepared state.")
		_expect(world.branches.size() == 5 and placed_branches.size() == world.placed_count, "Repeated input changed the branch count.")
	_expect(not world.request_place(), "Placement without a carried branch should be rejected.")
	_expect(world.placed_count == 3 and world.carried_branch == null, "Completed dam accepted a duplicate placement.")
	_expect(world.completion_feedback.visible, "Completing the dam did not show celebration feedback.")
	_expect(world.support_characters._otter.visible, "Completing the dam did not show the otter celebration.")
	_expect(world.celebration_sparkles.any(func(sparkle: MeshInstance3D) -> bool: return sparkle.visible), "Completing the dam did not trigger the visual celebration burst.")
	_expect(world.status.text == "A represa está completa!", "Completing the dam did not show the completion status.")
	_expect(world.get_node("CanvasLayer/DamProgress").text == "Ramos na represa: ●●●", "Completed dam progress was not updated.")
	_expect(world.finish_prompt.visible and world.home_invite.visible and world.home_invite.text == "Agora vamos construir a casa!", "Dam completion did not offer a finish choice and a Portuguese home invitation.")
	_expect(world.home_stage.is_active and world.home_stage.parts.all(func(part: HomePart) -> bool: return part.visible), "Completing the dam did not reveal the home stage parts.")
	_expect(not world.branch_cues.any(func(cue: MeshInstance3D) -> bool: return cue.visible), "Completing the dam left leftover branch cues competing with the home.")
	_expect(world.finish_choice_buttons["finish_golden"].visible and world.finish_choice_buttons["finish_moss"].visible, "Both finish choices are not visible after completion.")
	_expect(world.select_finish_choice("finish_golden") and world.finish_choice == "finish_golden", "Golden finish choice could not be selected.")
	_expect((world.finish_trim.mesh as BoxMesh).material.albedo_color == Color("d6a83e"), "Golden finish choice did not change the visible dam finish.")
	_expect(world.select_finish_choice("finish_moss") and world.finish_choice == "finish_moss", "Finish choice could not be changed.")
	_expect((world.finish_trim.mesh as BoxMesh).material.albedo_color == Color("668b59"), "Changed finish choice did not update the visible dam finish.")
	var durable_save := DamSave.load_state(SAVE_TEST_DIRECTORY)
	_expect(durable_save["state"]["placed_materials"].size() == 3 and durable_save["state"]["stage_completed"], "Completed dam progress was not saved.")
	_expect(durable_save["state"]["finish_choice"] == "finish_moss", "Changed finish choice was not saved.")
	_expect(durable_save["state"]["gnawed_materials"] == ["branch_thick_01"] and durable_save["state"]["bent_materials"] == ["branch_rotten_01"], "Solved obstacle states were not persisted.")
	world.save_directory = "res://invalid_save_path"
	_expect(world.select_finish_choice("finish_golden"), "Finish choice interaction failed while testing a persistence error.")
	_expect(world.status.text == "Não foi possível guardar o progresso. Pede ajuda a um adulto.", "Failed save did not show a clear Portuguese warning.")
	_expect(DamSave.load_state(SAVE_TEST_DIRECTORY)["state"] == durable_save["state"], "Failed save changed the previously valid save.")
	world.save_directory = SAVE_TEST_DIRECTORY
	_expect(world.select_finish_choice("finish_moss"), "Could not restore the saved finish choice after persistence failure test.")
	world._show_adult_restart()
	_expect(world.adult_restart_button.visible, "Adult restart gesture did not reveal the adult-only control.")
	world._confirm_restart()
	_expect(world.restart_dialog.visible, "Adult restart did not require confirmation.")
	_expect(world.restart_dialog.title == "Começar uma nova aventura?", "Restart confirmation title is not explicitly in European Portuguese.")
	_expect(world.restart_dialog.get_ok_button().text == "Começar de novo", "Restart confirmation action button is not in European Portuguese.")
	_expect(world.restart_dialog.get_cancel_button().text == "Cancelar", "Restart confirmation cancel button is not in European Portuguese.")
	_expect(world.restart_dialog.min_size.x >= 480, "Restart confirmation dialog is too narrow for its title.")
	world.restart_dialog.hide()
	_expect(DamSave.load_state(SAVE_TEST_DIRECTORY)["state"]["stage_completed"], "Opening and canceling restart confirmation cleared saved progress.")
	world.save_directory = "res://unsafe"
	world._restart_experiment()
	_expect(world.is_inside_tree() and world.status.text == "Não foi possível guardar o progresso. Pede ajuda a um adulto.", "Failed progress clearing reloaded the stage or hid its save error.")
	world.save_directory = SAVE_TEST_DIRECTORY
	var reload_world: Node = load(scene_path).instantiate()
	reload_world.save_directory = SAVE_TEST_DIRECTORY
	root.add_child(reload_world)
	await physics_frame
	await physics_frame
	_expect(reload_world.placed_count == 3 and reload_world.branches.filter(func(branch: CollectibleBranch) -> bool: return branch.state == CollectibleBranch.State.PLACED).size() == 3, "Reload did not rebuild the three placed branches exactly once.")
	_expect(reload_world.visual_environment.get_visible_dam_log_count() == 3, "Reload did not restore the visual dam.")
	_expect(reload_world.finish_choice == "finish_moss" and reload_world.finish_choice_buttons["finish_moss"].button_pressed, "Reload did not restore the selected finish choice.")
	_expect(reload_world.finish_trim.visible and (reload_world.finish_trim.mesh as BoxMesh).material.albedo_color == Color("668b59"), "Reload did not restore the visible finish appearance.")
	_expect(reload_world.home_invite.visible and reload_world.home_invite.text == "Agora vamos construir a casa!", "Reload did not preserve the Portuguese home invitation.")
	_expect(reload_world.home_stage.is_active and reload_world.home_stage.parts.all(func(part: HomePart) -> bool: return part.visible), "Reload did not make the home stage available after a completed dam.")
	_expect(reload_world.branches[0].gnawed and reload_world.branches[1].bent, "Reload did not restore solved branch changes.")
	_expect(reload_world.carried_branch == null and reload_world.pending_branch == null and Vector2(reload_world.actor.position.x, reload_world.actor.position.z).distance_to(Vector2(-4, 0)) < 0.01 and absf(reload_world.actor.position.y) < 0.1, "Reload restored transient carrying state or an unsafe beaver position.")
	_expect(reload_world._clear_progress_for_restart(), "Confirmed restart could not clear the isolated save files.")
	_expect(DamSave.load_state(SAVE_TEST_DIRECTORY)["state"]["placed_materials"].is_empty(), "Confirmed restart left completed progress in the save.")
	reload_world.queue_free()
	world.voice.cancel()
	world.queue_free()
	await process_frame
	# A separate run proves the thick branch is optional: the three normal branches
	# can complete the same three-slot dam without duplication or replacement.
	var normal_world: Node = load(scene_path).instantiate()
	normal_world.save_directory = SAVE_TEST_DIRECTORY
	root.add_child(normal_world)
	await physics_frame
	await physics_frame
	for normal_index in [2, 3, 4]:
		await _collect_and_place(normal_world, normal_world.branches[normal_index])
	_expect(normal_world.placed_count == 3 and normal_world.carried_branch == null, "Three normal branches did not complete the dam without the thick branch.")
	_expect(normal_world.branches.size() == 5 and normal_world.branches[0].state == CollectibleBranch.State.FREE, "Normal-only completion duplicated or lost a branch.")
	normal_world.queue_free()
	await process_frame
	_expect(DamSave.clear_save(SAVE_TEST_DIRECTORY), "Could not clean up isolated integration-test save files.")
	if failures == 0:
		print("CASTOR_MOVEMENT_OK bounds_obstacle_floor_retarget_mouse_speed_branch_carry_swap_place_water_visual_cues_completion_adult_restart rate=", Engine.physics_ticks_per_second)
	quit(0 if failures == 0 else 1)


func _collect_and_place(world: Node, branch: CollectibleBranch) -> void:
	_expect(world.request_collect(branch), "Normal-only run could not select a normal branch.")
	for frame in range(1200):
		await physics_frame
		if world.carried_branch == branch:
			break
	_expect(world.carried_branch == branch, "Normal-only run did not collect the selected branch.")
	_expect(world.request_help() and world.voice.active_event == "help_place" and world.placement_help_active, "Carried suitable material help did not highlight placement.")
	_expect(world.request_place(), "Normal-only run could not start placement.")
	var expected_count: int = world.placed_count + 1
	for frame in range(1200):
		await physics_frame
		if world.placed_count == expected_count:
			break
	_expect(world.placed_count == expected_count and branch.state == CollectibleBranch.State.PLACED, "Normal-only placement was lost or duplicated.")
