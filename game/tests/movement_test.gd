extends SceneTree
## R3 chapter integration on the authored terrain: real input rays, branch
## gnawing, all three stages and the winter ending, with water/hill refusal.

const DamSave = preload("res://scripts/dam_save.gd")
const SAVE_TEST_DIRECTORY := "user://dam_save_world_test/"
const REGRESSION_SAVE_DIRECTORY := "user://movement_regression_test/"
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


func _run() -> void:
	_expect(DamSave.clear_save(SAVE_TEST_DIRECTORY), "Could not clear the integration-test save directory.")
	_expect(_seed_legacy_save(SAVE_TEST_DIRECTORY), "Could not seed the integration-test directory with a legacy recipe.")
	await _run_dam_regressions()
	root.size = Vector2i(960, 600)
	var world: Node = load("res://scenes/movement.tscn").instantiate()
	world.save_directory = SAVE_TEST_DIRECTORY
	root.add_child(world)
	await _wait(func() -> bool: return world.actor.is_on_floor(), 5.0)
	var skeleton := world.actor.find_child("Skeleton3D", true, false) as Skeleton3D
	_expect(skeleton != null and skeleton.get_bone_count() == 13, "The chapter did not load the new beaver rig by default.")
	if failures > 0:
		quit(1)
		return
	_expect(world.actor.animation_player.has_animation(&"Walk"), "The new beaver is missing its walking clip.")
	var body := world.actor.beaver_model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var coat := body.mesh.surface_get_material(0) as StandardMaterial3D
	_expect(coat != null and coat.albedo_texture != null, "The new beaver is missing its painted coat.")
	var spawn_ground: float = world.terrain.height_at(Vector2(world.actor.global_position.x, world.actor.global_position.z))
	_expect(absf(world.actor.global_position.y - spawn_ground) <= 0.15, "A fresh chapter did not spawn safely on the terrain surface.")

	_expect(world.terrain != null and world.navigation != null, "The chapter is not using the shared terrain/navigation.")
	_expect(world.navigation.get_cell_count() == 704, "The expanded shared navigation grid is not 32 × 22 cells.")
	_expect(world.branches.size() == 5 and world.branch_cues.size() == 5, "The chapter does not expose five branches.")
	_expect(world.branches.all(func(branch: Node3D) -> bool: return branch.global_position.y > world.terrain.full_water_level()), "A branch is not grounded on dry land.")
	_expect(world.status.text == "Escolhe um ramo para a represa.", "The initial instruction is not the current dam objective.")
	_expect(world.home_stage._lodge_nodes.size() > 0 and world.home_stage._lodge_nodes.all(func(node: Node3D) -> bool: return not node.visible), "The lodge is visible before the dam is built.")
	_expect(world.camera.projection == Camera3D.PROJECTION_PERSPECTIVE and is_equal_approx(world.camera.fov, 36.0), "The chapter is not using the accepted perspective camera.")
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
	_expect(world.request_help() and world.incompatible_place_attempts == 0, "Help was unavailable before incompatible placement attempts or changed the attempt counter.")
	_expect(world.support_characters._owl.visible and world.help_highlight_active, "No-material help did not show the owl or highlight a suitable branch.")
	_expect(world.branch_cues.size() == 5 and world.branch_cues.slice(0, 4).all(func(cue: MeshInstance3D) -> bool: return cue.visible), "Available ground branches do not have persistent visual selection cues.")
	_expect(not world.branch_cues[4].visible and not world.branches[4].visible, "The tree branch is exposed before the tree is cut.")
	_expect(world.placement_cue != null and world.placement_cue.visible, "Dam target does not have a persistent visual cue.")
	_expect(world.dam_target_cue != null and world.dam_target_cue.visible, "The dam crest has no second placement marker.")
	_expect(world.progress_label.text == "Ramos na represa: ○○○", "Initial dam progress is not shown visually.")
	_expect(world.help_button.visible and world.help_button.text == "?" and world.help_button.tooltip_text == "Ajuda", "Discreet on-request help button is missing.")
	world.voice.cancel()
	world.help_highlight_active = false
	world._update_branch_cues()
	_expect(not world.adult_restart_button.visible, "Adult restart should be hidden from the child's normal controls.")
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
	_expect(world.adult_restart_button.visible and world.status.text == status_before_title_hold, "Long title touch did not reveal adult controls cleanly.")
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

	var water_point := Vector3(world.terrain.lake_center().x, world.terrain.initial_water_level(), world.terrain.lake_center().y)
	_expect(not world._move_from_screen(world.camera.unproject_position(water_point + Vector3.UP * 0.2)), "A tap on the lake started movement.")
	_expect(not world.request_move(Vector3(-8.0, 0.0, -5.0)), "A tap outside the playable bank started movement.")

	# Real input ray on a raised branch clearing. branch_normal_03 now belongs to
	# the interactive tree, so the ray uses a ground branch; the tree path has its
	# own checks below.
	var branch: Node = world.branches[3]
	var branch_screen: Vector2 = world.camera.unproject_position(branch.global_position + Vector3.UP * 0.15)
	_expect(world._move_from_screen(branch_screen), "Tapping a branch on the raised bank did not start collection.")
	_expect(await _wait(func() -> bool: return world.actor.current_animation == &"Walk", 5.0), "The new beaver did not play Walk while approaching the branch.")
	_expect(await _wait(func() -> bool: return world.carried_branch == branch, 15.0), "The branch was not carried after the approach.")
	_expect(branch.get_parent() == world.actor and branch.position.is_equal_approx(Vector3(-0.11, 0.44, -0.48)) and is_zero_approx(branch.rotation.z), "The collected branch did not attach at the new beaver's paws.")
	_expect(world.request_place(), "The carried branch could not be routed to the dam.")
	_expect(await _wait(func() -> bool: return world.placed_count == 1, 15.0), "The first branch was not placed in the dam.")
	_expect(await _wait_dam_presentation(world, 1, world.terrain.intermediate_water_level()), "The first dam placement did not present one log and the intermediate lake.")
	_expect(is_equal_approx(world.water_level, world.terrain.intermediate_water_level()), "The first dam placement did not raise the lake to the intermediate level.")

	# Thick branch: pick it up, gnaw it and place it.
	var thick: Node = world.branches[0]
	_expect(world.request_collect(thick), "The thick branch could not be selected.")
	_expect(await _wait(func() -> bool: return world.carried_branch == thick, 15.0), "The thick branch was not carried.")
	_expect(world.request_gnaw(), "The thick branch could not be gnawed.")
	_expect(thick.gnawed and world.request_place(), "The gnawed branch could not be placed.")
	_expect(await _wait(func() -> bool: return world.placed_count == 2, 15.0), "The second branch was not placed.")
	_expect(await _wait_dam_presentation(world, 2, world.terrain.full_water_level()), "The second dam placement did not present two logs and the full lake.")
	_expect(is_equal_approx(world.water_level, world.terrain.full_water_level()), "The second dam placement did not fill the lake.")

	var third: Node = world.branches[2]
	_expect(world.request_collect(third), "The third branch could not be selected.")
	_expect(await _wait(func() -> bool: return world.carried_branch == third, 15.0), "The third branch was not carried.")
	_expect(world.request_place(), "The third branch could not be routed to the dam.")
	_expect(await _wait(func() -> bool: return world.placed_count == 3, 15.0), "The third branch was not placed.")
	_expect(await _wait_dam_presentation(world, 3, world.terrain.full_water_level()), "The third dam placement did not present the completed structure without another rise.")
	_expect(world.home_stage.is_active, "Completing the dam did not activate the home stage.")
	_expect(world.water_surface.mesh is ArrayMesh and (world.water_surface.mesh as ArrayMesh).get_surface_count() > 0, "The lake water mesh is missing after the dam.")
	_expect(world.stream_surface.mesh is ArrayMesh and (world.stream_surface.mesh as ArrayMesh).get_surface_count() > 0, "The downstream stream mesh is missing after the dam.")
	_expect(world.placement_center.y > world.terrain.full_water_level(), "Placed branches are not above the full lake surface.")
	_expect(not world.dam_target_cue.visible, "The dam crest marker is still visible after completion.")
	_expect(world.water_level == world.terrain.full_water_level(), "The complete dam does not keep the full lake level.")

	# Home: two parts on the grounded lodge.
	var home: Node = world.home_stage
	var parts: Array = home.parts
	_expect(await _place_home_part(home, parts[0], 0), "The first home part could not be placed.")
	_expect(await _place_home_part(home, parts[1], 1), "The second home part could not be placed.")
	_expect(home.is_complete(), "The home stage did not complete.")
	_expect(world.food_stage.is_active, "Completing the home did not activate the food stage.")

	# Food: three suitable bundles from the bank to the shore target.
	var food: Node = world.food_stage
	var placed_food := 0
	for bundle in food.bundles:
		if not food.is_bundle_suitable(bundle):
			continue
		var target_count := placed_food + 1
		_expect(food.request_collect(bundle), "A suitable food bundle could not be selected.")
		_expect(await _wait(func() -> bool: return food.carried_bundle == bundle, 15.0), "A suitable bundle was not carried.")
		_expect(bundle.position.is_equal_approx(Vector3(-0.11, 0.44, -0.48)), "The food bundle did not attach at the new beaver's paws.")
		_expect(food.request_place(), "The bundle could not be routed to the food target.")
		_expect(await _wait(func() -> bool: return food.placed_count == target_count, 15.0), "A suitable bundle was not stored.")
		placed_food = target_count
		if placed_food == 3:
			break
	_expect(await _wait(func() -> bool: return world.winter_active, 5.0), "The winter ending did not start after the third bundle.")
	_expect(world.winter_scene.visible, "The winter scene is not visible at the ending.")

	if failures == 0:
		print("CASTOR_MOVEMENT_OK terrain_click water_refusal branch_ray gnaw dam home food winter")
	quit(0 if failures == 0 else 1)


func _wait_dam_presentation(world: Node, count: int, level: float) -> bool:
	return await _wait(func() -> bool: return world.visual_environment.get_visible_dam_log_count() == count and is_equal_approx(world.water_level, level), 8.0)


func _place_home_part(home: Node, part: Node, slot_index: int) -> bool:
	if not home.request_collect(part):
		return false
	if not await _wait(func() -> bool: return home.carried_part == part, 15.0):
		return false
	_expect(part.position.is_equal_approx(Vector3(-0.11, 0.44, -0.48)), "The lodge part did not attach at the new beaver's paws.")
	if not home.request_place(slot_index):
		return false
	return await _wait(func() -> bool: return home.placed_slot_count == slot_index + 1, 15.0)


func _run_dam_regressions() -> void:
	_expect(DamSave.clear_save(REGRESSION_SAVE_DIRECTORY), "Could not clear the regression-test save directory.")
	_expect(_seed_legacy_save(REGRESSION_SAVE_DIRECTORY), "Could not seed the regression-test directory with a legacy recipe.")
	root.size = Vector2i(960, 600)
	var world: Node = load("res://scenes/movement.tscn").instantiate()
	world.save_directory = REGRESSION_SAVE_DIRECTORY
	root.add_child(world)
	await _wait(func() -> bool: return world.actor.is_on_floor(), 5.0)
	var rotten: CollectibleBranch = world.branches[1]
	_expect(world.request_collect(rotten), "Could not start the rotten-branch regression.")
	_expect(await _wait(func() -> bool: return world.carried_branch == rotten), "Rotten branch was not carried.")
	_expect(rotten.bent and not world.request_place(), "Rotten branch did not bend or was accepted for the dam.")
	_expect(world.carried_branch == rotten and rotten.state == CollectibleBranch.State.CARRIED, "Refusing a rotten branch discarded the carried item.")
	var bent_save: Dictionary = DamSave.load_state(REGRESSION_SAVE_DIRECTORY)["state"]
	_expect(bent_save["bent_materials"] == ["branch_rotten_01"] and "branch_rotten_01" in bent_save["solved_obstacles"], "Solving the rotten-branch obstacle was not saved.")

	var first_normal: CollectibleBranch = world.branches[2]
	_expect(world.request_collect(first_normal), "Could not swap the rotten branch for a suitable branch.")
	_expect(await _wait(func() -> bool: return world.carried_branch == first_normal), "Suitable branch did not replace the rotten branch.")
	_expect(rotten.state == CollectibleBranch.State.FREE and rotten.bent and rotten.get_parent() == world, "Swapping the rotten branch lost its bent state or origin.")
	_expect(world.request_collect(first_normal), "Repeated targeting of the carried branch failed.")
	_expect(first_normal.get_parent() == world.actor and first_normal.state == CollectibleBranch.State.CARRIED, "Repeated targeting duplicated or dropped the carried branch.")
	var second_normal: CollectibleBranch = world.branches[3]
	_expect(world.request_collect(second_normal), "Could not reserve another branch during the regression.")
	_expect(world.pending_branch == second_normal and second_normal.state == CollectibleBranch.State.RESERVED, "The second branch was not reserved while the first was carried.")
	_expect(world.request_collect(first_normal), "Retargeting the carried branch did not cancel the pending pickup.")
	_expect(world.pending_branch == null and second_normal.state == CollectibleBranch.State.FREE and world.actor.is_arrived(), "Canceling a pickup left the beaver moving or the item reserved.")
	var thick: CollectibleBranch = world.branches[0]
	_expect(world.request_collect(thick), "Could not select the optional thick branch.")
	_expect(await _wait(func() -> bool: return world.carried_branch == thick), "Optional thick branch was not carried.")
	_expect(world.request_gnaw() and thick.gnawed, "The thick-branch obstacle could not be solved.")
	var solved_save: Dictionary = DamSave.load_state(REGRESSION_SAVE_DIRECTORY)["state"]
	_expect(solved_save["gnawed_materials"] == ["branch_thick_01"] and "branch_thick_01" in solved_save["solved_obstacles"], "Solving the thick-branch obstacle was not saved.")
	_expect(world.request_collect(first_normal), "Could not swap the gnawed thick branch for a normal branch.")
	_expect(await _wait(func() -> bool: return world.carried_branch == first_normal), "Normal branch did not replace the gnawed thick branch.")
	_expect(thick.state == CollectibleBranch.State.FREE and thick.gnawed, "Swapping away the thick branch lost its solved state.")
	_expect(world.request_place() and world.request_place(), "Repeated dam targeting was not accepted safely.")
	_expect(await _wait(func() -> bool: return world.placed_count == 1), "First normal branch was not placed exactly once.")

	# E2: branch_normal_03 is supplied only by the interactive tree. The
	# normal-only dam needs the authored cut once, then the branch is collectable.
	_expect(world.request_gnaw_tree(), "The interactive tree could not be selected for the normal-only dam.")
	_expect(await _wait(func() -> bool: return world.tree_cut == true, 20.0), "The interactive tree did not finish its authored fall.")

	for branch_index in [3, 4]:
		var branch: CollectibleBranch = world.branches[branch_index]
		_expect(world.request_collect(branch), "Could not collect normal branch %d." % branch_index)
		_expect(await _wait(func() -> bool: return world.carried_branch == branch), "Normal branch %d was not carried." % branch_index)
		_expect(world.request_place(), "Could not place normal branch %d." % branch_index)
		var expected_count: int = branch_index - 1
		_expect(await _wait(func() -> bool: return world.placed_count == expected_count), "Normal branch %d was not placed once." % branch_index)
	_expect(await _wait(func() -> bool: return world.placed_count == 3), "The normal-only dam did not reach three placements.")
	_expect(await _wait_dam_presentation(world, 3, world.terrain.full_water_level()), "The normal-only dam did not present its completed structure.")
	_expect(world.placed_count == 3 and world.home_stage.is_active, "Three normal branches alone did not complete the dam and open the home stage.")
	_expect(world.branches[0].state == CollectibleBranch.State.FREE, "Normal-only dam completion consumed the optional thick branch.")
	_expect(world.select_finish_choice("finish_golden"), "Completed dam did not accept the golden finishing choice.")
	var trim_material := (world.finish_trim.mesh as BoxMesh).material as StandardMaterial3D
	_expect(trim_material.albedo_color.is_equal_approx(Color("d6a83e")), "The golden finish was not applied to the short crest accent.")
	_expect(world.select_finish_choice("finish_moss"), "Completed dam did not accept the moss finishing choice.")
	_expect(trim_material.albedo_color.is_equal_approx(Color("668b59")), "The moss finish was not applied to the short crest accent.")
	_expect(world.finish_choice == "finish_moss" and world.finish_trim.visible, "The selected dam finish was not applied.")
	var completed_save: Dictionary = DamSave.load_state(REGRESSION_SAVE_DIRECTORY)["state"]
	_expect(completed_save["finish_choice"] == "finish_moss" and completed_save["stage_completed"], "The finishing choice or completed dam was not saved.")
	world.queue_free()
	await process_frame

	var restored: Node = load("res://scenes/movement.tscn").instantiate()
	restored.save_directory = REGRESSION_SAVE_DIRECTORY
	root.add_child(restored)
	await _wait(func() -> bool: return restored.actor.is_on_floor(), 5.0)
	var restored_spawn_y: float = restored.terrain.height_at(Vector2(restored.actor.global_position.x, restored.actor.global_position.z))
	_expect(absf(restored.actor.global_position.y - restored_spawn_y) <= 0.15 and restored.actor.is_on_floor(), "Restored progress did not use a safe grounded spawn.")
	_expect(restored.branches[1].bent and restored.branches[1].state == CollectibleBranch.State.FREE, "Solved rotten-branch state was not restored at its origin.")
	_expect(restored.branches[0].gnawed and restored.branches[0].state == CollectibleBranch.State.FREE, "Solved thick-branch state was not restored at its origin.")
	_expect(restored.placed_count == 3 and restored.home_stage.is_active and restored.finish_choice == "finish_moss", "Dam completion, finish choice or stage gate was not restored.")
	_expect(restored.finish_trim.visible, "Restored finishing choice is not visible on the dam.")
	var restored_save: Dictionary = DamSave.load_state(REGRESSION_SAVE_DIRECTORY)["state"]
	_expect("branch_rotten_01" in restored_save["solved_obstacles"] and "branch_thick_01" in restored_save["solved_obstacles"], "Solved obstacle states disappeared after restoring the save.")
	restored.queue_free()
	await process_frame
	_expect(DamSave.clear_save(REGRESSION_SAVE_DIRECTORY), "Could not clean up the regression-test save directory.")


func _seed_legacy_save(directory: String) -> bool:
	return DamSave.save_state(DamSave.empty_state(DamSave.LEGACY_RECIPE_ID), directory)
