extends SceneTree
## R2 traversal: terrain-following movement, slope ascent/descent, water refusal
## and click routing through the shared 0.5 m navigation.

const TraversalScene = preload("res://scenes/valley_traversal_preview.tscn")
var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _expect(condition: bool, description: String) -> void:
	if not condition:
		failures += 1
		push_error(description)


func _run() -> void:
	var preview := TraversalScene.instantiate() as Node3D
	root.add_child(preview)
	for _index in range(30):
		await physics_frame
	_expect(preview.navigation != null, "Traversal navigation is missing.")
	_expect(preview.actor != null, "Traversal actor is missing.")
	_expect(preview.actor.floor_snap_length >= 0.3, "Actor floor snap is too short for descents.")
	_expect(is_equal_approx(preview.actor.floor_max_angle, deg_to_rad(40.0)), "Actor floor angle is not the R2 value.")
	_expect(preview.actor.floor_constant_speed, "Actor does not keep constant slope speed.")
	await _expect_arrived(preview, preview.layout.anchor(&"dam_approach"), "dam")
	var dam_y: float = preview.actor.global_position.y
	var uphill_start := Engine.get_physics_frames()
	await _expect_arrived(preview, preview.layout.anchor(&"lodge"), "lodge")
	var uphill_ms := int(round(float(Engine.get_physics_frames() - uphill_start) * 1000.0 / 60.0))
	var lodge_y: float = preview.actor.global_position.y
	_expect(lodge_y > dam_y + 0.10, "Actor did not climb from the dam to the lodge (%.2f → %.2f)." % [dam_y, lodge_y])
	var downhill_start := Engine.get_physics_frames()
	await _expect_arrived(preview, preview.layout.anchor(&"dam_approach"), "dam descent")
	var downhill_ms := int(round(float(Engine.get_physics_frames() - downhill_start) * 1000.0 / 60.0))
	_expect(preview.actor.global_position.y < lodge_y - 0.10, "Actor did not descend from the lodge to the dam.")
	var dam_route: PackedVector3Array = preview.navigation.find_path(preview.layout.anchor(&"dam_approach"), preview.layout.anchor(&"lodge"))
	var expected_ms: float = _path_length(dam_route) / 2.8 * 1000.0
	print("CASTOR_TRAVERSAL_SPEED uphill_ms=%d downhill_ms=%d route_m=%.2f expected_ms=%.0f" % [
		uphill_ms, downhill_ms, _path_length(dam_route), expected_ms,
	])
	_expect(uphill_ms <= expected_ms * 2.0 + 1500.0, "Uphill travel is excessively slower than the route length.")
	_expect(downhill_ms <= expected_ms * 2.0 + 1500.0, "Downhill travel is excessively slower than the route length.")
	_expect(uphill_ms >= expected_ms * 0.45, "Uphill travel is implausibly faster than the route length.")
	_expect(downhill_ms >= expected_ms * 0.45, "Downhill travel is implausibly faster than the route length.")
	_expect(uphill_ms < downhill_ms * 2.2 and downhill_ms < uphill_ms * 2.2, "Uphill and downhill travel times differ excessively.")

	_expect(preview.request_move_to(preview.layout.anchor(&"lodge")), "Retarget test could not start.")
	await _wait_frames(18)
	_expect(preview.request_move_to(preview.layout.anchor(&"food_bank")), "Retarget halfway up the slope was refused.")
	await _wait_frames(2)
	_expect(preview.request_move_to(preview.layout.anchor(&"food_bank")), "Repeated tap on the same destination was refused.")
	await _wait_for_arrival(preview)
	var food: Vector3 = preview.layout.anchor(&"food_bank")
	_expect(preview.actor.is_arrived(), "Actor did not arrive after retargeting.")
	_expect(Vector2(preview.actor.global_position.x, preview.actor.global_position.z).distance_to(Vector2(food.x, food.z)) <= 0.75, "Actor did not stop at the retargeted food bank.")

	var lake: Vector2 = preview.terrain.lake_center()
	_expect(not preview.request_move_to(Vector3(lake.x, preview.terrain.height_at(lake), lake.y)), "Water was accepted as a destination.")
	var hill := Vector3(-8.0, 0.0, -5.0)
	_expect(not preview.request_move_to(hill), "A hill outside the playable bank was accepted.")

	var before: Vector3 = preview.actor.global_position
	preview._move_from_screen(preview.camera.unproject_position(preview.layout.anchor(&"spawn") + Vector3.UP * 0.1))
	await _wait_frames(20)
	_expect(preview.actor.global_position.distance_to(before) > 0.15, "Screen click did not start movement.")

	if failures == 0:
		print("CASTOR_VALLEY_TRAVERSAL_OK slope_up_down slope_speed retarget water_refusal click_route floor_settings")
	quit(0 if failures == 0 else 1)


func _wait_frames(count: int) -> void:
	for _index in range(count):
		await physics_frame


func _wait_for_arrival(preview) -> void:
	var deadline := Time.get_ticks_msec() + 12000
	while Time.get_ticks_msec() < deadline and not preview.actor.is_arrived():
		await physics_frame


func _expect_arrived(preview, target: Vector3, label: String) -> void:
	var accepted: bool = preview.request_move_to(target)
	_expect(accepted, "Movement to %s was refused." % label)
	if not accepted:
		return
	var deadline := Time.get_ticks_msec() + 12000
	while Time.get_ticks_msec() < deadline and not preview.actor.is_arrived():
		await physics_frame
	_expect(preview.actor.is_arrived(), "Actor did not arrive at %s." % label)
	var distance := Vector2(preview.actor.global_position.x, preview.actor.global_position.z).distance_to(Vector2(target.x, target.z))
	_expect(distance <= 0.75, "Actor stopped %.2f m from %s." % [distance, label])
	var ground: float = preview.terrain.height_at(Vector2(preview.actor.global_position.x, preview.actor.global_position.z))
	_expect(absf(preview.actor.global_position.y - ground) <= 0.20, "Actor is not grounded at %s." % label)


func _path_length(path: PackedVector3Array) -> float:
	var length := 0.0
	for index in range(1, path.size()):
		var previous := Vector2(path[index - 1].x, path[index - 1].z)
		var current := Vector2(path[index].x, path[index].z)
		length += previous.distance_to(current)
	return length
