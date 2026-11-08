extends SceneTree
## Integration: real path with physics, bounds, obstacles and target changes.

var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _expect(condition: bool, description: String) -> void:
	if not condition:
		failures += 1
		push_error(description)


func _run() -> void:
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
	root.add_child(world)
	await physics_frame
	await physics_frame
	_expect(world.voice.active_event == "dam_start", "Entering the scene did not start the introduction voice cue.")
	world.voice.play_event("help_collect")
	var help_stream: AudioStream = world.voice.player.stream
	world.voice.play_event("help_collect")
	_expect(world.voice.active_event == "help_collect" and world.voice.player.stream == help_stream, "Repeating the same help event restarted or replaced its voice clip.")
	world.voice.player.finished.emit()
	_expect(world.voice.active_event.is_empty(), "Finished voice cue did not become available for repetition.")
	world.voice.play_event("help_collect")
	_expect(world.voice.active_event == "help_collect", "Finished help cue could not be repeated.")
	world.voice.play_event("help_place")
	_expect(world.voice.active_event == "help_place" and world.voice.player.stream != help_stream, "A changed situation did not replace the outdated voice cue.")
	world.voice.cancel()
	_expect(world.voice.active_event.is_empty() and not world.voice.player.playing, "Canceling an outdated voice cue did not stop playback.")
	_expect(world.branch_cues.size() == 3 and world.branch_cues.all(func(cue: MeshInstance3D) -> bool: return cue.visible), "Available branches do not have persistent visual selection cues.")
	_expect(world.placement_cue != null and world.placement_cue.visible, "Dam target does not have a persistent visual cue.")
	_expect(world.get_node("CanvasLayer/DamProgress").text == "Ramos na represa: ○○○", "Initial dam progress is not shown visually.")
	_expect(not world.adult_restart_button.visible, "Adult restart should be hidden from the child's normal controls.")
	_expect(world.celebration_sparkles.size() == 5 and world.celebration_sparkles.all(func(sparkle: MeshInstance3D) -> bool: return not sparkle.visible), "Celebration visuals should be prepared but hidden before completion.")
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
	_expect(not world.branch_cues[0].visible, "Carried branch still appears selectable on the ground.")
	_expect(world.request_collect(second_branch), "Selecting another branch failed.")
	for frame in range(900):
		await physics_frame
		if world.carried_branch == second_branch:
			break
	_expect(world.carried_branch == second_branch, "Second branch was not carried after arrival.")
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
	for branch_index in range(3):
		var branch_to_place: Node3D = world.branches[branch_index]
		_expect(world.request_collect(branch_to_place), "Could not collect branch for placement.")
		for frame in range(1200):
			await physics_frame
			if world.carried_branch == branch_to_place:
				break
		_expect(world.carried_branch == branch_to_place, "Branch was not carried before placement.")
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
		_expect(world.carried_branch == null and branch_to_place.state == 3, "Placed branch was lost or remained carried.")
		if branch_index == 0:
			_expect(world.branches[1].state == 0 and world.branches[1].get_parent() == world, "Pending branch was collected at a distance when the beaver reached the placement target.")
		_expect(branch_to_place.get_parent() == world, "Placed branch is not accounted for in the world.")
		placed_branches.append(branch_to_place)
		var expected_depths: Array[float] = [1.2, 1.6, 2.0]
		var water_mesh := world.water_surface.mesh as BoxMesh
		_expect(is_equal_approx(water_mesh.size.z, expected_depths[branch_index]), "Water did not advance to the matching prepared state.")
		_expect(world.branches.size() == 3 and placed_branches.size() == world.placed_count, "Repeated input changed the branch count.")
	_expect(not world.request_place(), "Placement without a carried branch should be rejected.")
	_expect(world.placed_count == 3 and world.carried_branch == null, "Completed dam accepted a duplicate placement.")
	_expect(world.completion_feedback.visible, "Completing the dam did not show celebration feedback.")
	_expect(world.celebration_sparkles.any(func(sparkle: MeshInstance3D) -> bool: return sparkle.visible), "Completing the dam did not trigger the visual celebration burst.")
	_expect(world.status.text == "A represa está completa!", "Completing the dam did not show the completion status.")
	_expect(world.get_node("CanvasLayer/DamProgress").text == "Ramos na represa: ●●●", "Completed dam progress was not updated.")
	world._show_adult_restart()
	_expect(world.adult_restart_button.visible, "Adult restart gesture did not reveal the adult-only control.")
	world._confirm_restart()
	_expect(world.restart_dialog.visible, "Adult restart did not require confirmation.")
	world.restart_dialog.hide()
	world.voice.cancel()
	world.queue_free()
	await process_frame
	if failures == 0:
		print("CASTOR_MOVEMENT_OK bounds_obstacle_floor_retarget_mouse_speed_branch_carry_swap_place_water_visual_cues_completion_adult_restart rate=", Engine.physics_ticks_per_second)
	quit(0 if failures == 0 else 1)
