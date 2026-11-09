extends SceneTree
## Checks the imported beaver rig, looping clips, animation switching, and carried-branch attachment.

const Actor = preload("res://scripts/prototype_actor.gd")
const BranchScene = preload("res://scenes/collectible_branch.tscn")
var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _expect(condition: bool, description: String) -> void:
	if not condition:
		failures += 1
		push_error(description)


func _bone_poses(skeleton: Skeleton3D) -> Array[Transform3D]:
	var poses: Array[Transform3D] = []
	for bone_index in skeleton.get_bone_count():
		poses.append(skeleton.get_bone_global_pose(bone_index))
	return poses


func _poses_match(first: Array[Transform3D], second: Array[Transform3D]) -> bool:
	if first.size() != second.size():
		return false
	for index in first.size():
		if not first[index].is_equal_approx(second[index]):
			return false
	return true


func _visual_center(actor: Node, node_name: String) -> Vector3:
	var mesh := actor.find_child(node_name, true, false) as MeshInstance3D
	return mesh.global_transform * mesh.get_aabb().get_center()


func _run() -> void:
	var actor := Actor.new() as CharacterBody3D
	root.add_child(actor)
	await process_frame
	_expect(actor.animation_player != null, "Beaver AnimationPlayer is missing.")
	if actor.animation_player != null:
		_expect(actor.animation_player.current_animation == &"Idle", "Actor should start in Idle.")
	var skeleton := actor.find_child("Skeleton3D", true, false) as Skeleton3D
	_expect(skeleton != null and skeleton.get_bone_count() >= 8, "Beaver rig must contain at least eight bones.")
	if actor.animation_player != null and skeleton != null:
		for animation_name: StringName in [&"Idle", &"Walk"]:
			_expect(actor.animation_player.has_animation(animation_name), "Missing beaver animation: %s" % animation_name)
			if not actor.animation_player.has_animation(animation_name):
				continue
			var animation: Animation = actor.animation_player.get_animation(animation_name)
			_expect(animation.loop_mode != Animation.LOOP_NONE, "%s is not configured to loop." % animation_name)
			actor.animation_player.play(animation_name)
			actor.animation_player.advance(0.2)
			var first_cycle_pose := _bone_poses(skeleton)
			actor.animation_player.advance(animation.length)
			_expect(actor.animation_player.is_playing(), "%s stopped after one clip duration." % animation_name)
			var next_cycle_pose := _bone_poses(skeleton)
			_expect(_poses_match(first_cycle_pose, next_cycle_pose), "%s pose is discontinuous between loop cycles." % animation_name)

	var branch := BranchScene.instantiate() as CollectibleBranch
	root.add_child(branch)
	branch.carry(actor)
	actor.follow_path(PackedVector3Array([actor.global_position + Vector3(1.0, 0.0, 0.0)]))
	actor._physics_process(1.0 / 60.0)
	var nose := _visual_center(actor, "NoseMesh")
	var tail := _visual_center(actor, "TailMesh")
	_expect(nose.x - actor.position.x > 0.2, "The beaver's nose does not point in the movement direction (+X).")
	_expect(tail.x - actor.position.x < -0.1, "The beaver's tail is ahead of the movement direction (+X).")
	actor.follow_path(PackedVector3Array([actor.global_position + Vector3(0.0, 0.0, 1.0)]))
	actor._physics_process(1.0 / 60.0)
	nose = _visual_center(actor, "NoseMesh")
	tail = _visual_center(actor, "TailMesh")
	_expect(nose.z - actor.position.z > 0.2, "The beaver's nose does not point in the movement direction (+Z).")
	_expect(tail.z - actor.position.z < -0.1, "The beaver's tail is ahead of the movement direction (+Z).")
	actor.follow_path(PackedVector3Array([actor.global_position + Vector3(1.0, 0.0, -1.0)]))
	actor._physics_process(1.0 / 60.0)
	var carried_offset := actor.global_transform.basis * Vector3(0.0, 0.95, -0.55)
	_expect(branch.global_position.distance_to(actor.global_position + carried_offset) < 0.02, "Carried branch did not follow the beaver's facing rotation.")
	_expect(actor.animation_player.current_animation == &"Walk", "Actor should switch to Walk while moving.")
	actor.follow_path(PackedVector3Array())
	actor._physics_process(1.0 / 60.0)
	actor.play_gnaw_action()
	await create_timer(0.13).timeout
	_expect(absf(actor.beaver_model.rotation.x) > 0.04, "Gnaw action did not visibly move the beaver.")
	actor.follow_path(PackedVector3Array([actor.global_position + Vector3(0.0, 0.0, -1.0)]))
	actor._physics_process(1.0 / 60.0)
	_expect(actor.beaver_model.rotation.is_equal_approx(Vector3.ZERO), "Movement did not interrupt and reset the gnaw action.")
	_expect(actor.animation_player.current_animation == &"Walk", "Movement input was blocked by the gnaw action.")
	actor.follow_path(PackedVector3Array())
	actor._physics_process(1.0 / 60.0)
	actor.play_place_action()
	await create_timer(0.16).timeout
	_expect(actor.beaver_model.position.y < -0.02, "Place action did not visibly lower the beaver.")
	await create_timer(0.4).timeout
	_expect(actor.beaver_model.position.is_equal_approx(Vector3.ZERO), "Place action did not return the beaver to its resting transform.")
	_expect(actor.beaver_model.rotation.is_equal_approx(Vector3.ZERO), "Place action left the beaver in a tilted pose.")
	branch.queue_free()
	actor.queue_free()
	if failures == 0:
		print("CASTOR_BEAVER_OK rig idle_walk_loops loop_continuity movement_switch carried_branch_facing gnaw_place_interruptions")
	quit(0 if failures == 0 else 1)
