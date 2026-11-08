extends SceneTree
## Integration: imported assets keep scale, orientation, materials, skeleton and
## idle/walk switching. Does not replace visual inspection.

var failures: int = 0


func _initialize() -> void:
	# A runtime error stops _run without calling quit(); this limit keeps check from hanging.
	create_timer(20.0).timeout.connect(func() -> void:
		push_error("Asset test exceeded 20 s.")
		quit(1))
	call_deferred("_run")


func _expect(condition: bool, description: String) -> void:
	if not condition:
		failures += 1
		push_error(description)


func _mesh_bounds(node: Node) -> AABB:
	var result := AABB()
	var first := true
	for mesh_instance in node.find_children("*", "MeshInstance3D", true, false):
		var bounds: AABB = mesh_instance.global_transform * mesh_instance.get_aabb()
		result = bounds if first else result.merge(bounds)
		first = false
	return result


func _poses(skeleton: Skeleton3D) -> Array[Transform3D]:
	var result: Array[Transform3D] = []
	for bone in skeleton.get_bone_count():
		result.append(skeleton.get_bone_global_pose(bone))
	return result


func _run() -> void:
	var world: Node = load("res://scenes/asset_import_test.tscn").instantiate()
	root.add_child(world)
	await process_frame
	await process_frame
	# Branch: 1.2 m along +X, origin at the center with its base on the ground, no transforms.
	var branch_mesh: MeshInstance3D = world.branch.find_child("Branch", true, false)
	_expect(branch_mesh != null, "Mesh Branch not found in the .glb.")
	if branch_mesh != null:
		var bounds := branch_mesh.get_aabb()
		_expect(absf(bounds.size.x - 1.2) < 0.03, "Branch length is not 1.2 m: %s" % bounds.size)
		_expect(bounds.size.y < 0.25 and bounds.size.z < 0.4, "Branch is not lying along X: %s" % bounds.size)
		_expect(absf(bounds.position.y) < 0.01, "Branch base is not at origin height: %s" % bounds.position)
		_expect(absf(bounds.get_center().x) < 0.03, "Branch origin is not at the center: %s" % bounds.get_center())
		_expect(branch_mesh.transform.is_equal_approx(Transform3D.IDENTITY), "Branch has an unapplied transform.")
		var names: Array[String] = []
		for surface in branch_mesh.mesh.get_surface_count():
			names.append(branch_mesh.mesh.surface_get_material(surface).resource_name)
		_expect("Bark" in names and "CutTip" in names, "Branch materials missing: %s" % [names])
		print("CASTOR_ASSET_BRANCH size=", bounds.size, " materials=", names)
	# Animated model: skeleton, textured material and scale close to the placeholder character.
	var animated: Node3D = world.animated
	_expect(animated.skeleton != null and animated.skeleton.get_bone_count() > 10, "Test model skeleton missing.")
	var fox_mesh: MeshInstance3D = animated.find_child("fox", true, false)
	var fox_material := fox_mesh.mesh.surface_get_material(0) as BaseMaterial3D if fox_mesh else null
	_expect(fox_material != null and fox_material.albedo_texture != null, "Test model texture missing.")
	var fox_bounds := _mesh_bounds(animated)
	_expect(fox_bounds.size.y > 0.25 and fox_bounds.size.y < 0.7, "Test model height out of range: %s" % fox_bounds.size)
	_expect(fox_bounds.position.y > -0.05, "Test model below the ground: %s" % fox_bounds.position)
	_expect(animated.current_animation() == &"Survey" and not animated.is_walking(), "Idle animation expected while standing.")
	var skeleton: Skeleton3D = animated.skeleton
	var idle_poses := _poses(skeleton)
	animated.walk_to(Vector3(3, 0, 2))
	for frame in range(20):
		await process_frame
	_expect(animated.is_walking() and animated.current_animation() == &"Walk", "Walk animation expected while moving.")
	_expect(_poses(skeleton) != idle_poses, "Skeleton did not move with the animation.")
	var elapsed := 0.0
	while animated.is_walking() and elapsed < 5.0:
		await process_frame
		elapsed += get_root().get_process_delta_time()
	await process_frame
	_expect(not animated.is_walking() and animated.current_animation() == &"Survey", "Should return to idle on arrival.")
	_expect(animated.position.distance_to(Vector3(3, 0, 2)) < 0.05, "Test model did not reach the target.")
	if failures == 0:
		print("CASTOR_ASSETS_OK branch_scale_origin_materials animated_skeleton_idle_walk")
	quit(0 if failures == 0 else 1)
