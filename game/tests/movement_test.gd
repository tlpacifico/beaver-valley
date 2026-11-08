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
	if failures == 0:
		print("CASTOR_MOVEMENT_OK bounds_obstacle_floor_retarget_mouse_speed rate=", Engine.physics_ticks_per_second)
	quit(0 if failures == 0 else 1)
