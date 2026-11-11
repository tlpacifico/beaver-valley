extends CharacterBody3D

const BeaverScene = preload("res://assets/characters/beaver/Beaver.glb")
const SPEED: float = 2.8
var model_scene: PackedScene = BeaverScene
var model_scale: float = 1.0
var carry_offset := CollectibleBranch.DEFAULT_CARRY_OFFSET
var waypoints: PackedVector3Array = []
var visual: Node3D
var beaver_model: Node3D
var animation_player: AnimationPlayer
var current_animation: StringName = &""
var action_tween: Tween


func _ready() -> void:
	# Follow the authored terrain: stay attached on descents, climb the route
	# slopes at constant speed and keep the body upright rather than tilting it.
	floor_snap_length = 0.35
	floor_max_angle = deg_to_rad(40.0)
	floor_constant_speed = true
	floor_stop_on_slope = true
	collision_layer = 2
	collision_mask = 1
	var collision := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.26
	shape.height = 0.9
	collision.shape = shape
	collision.position.y = 0.45
	add_child(collision)
	visual = Node3D.new()
	visual.name = "Visual"
	# Blender's -Y forward becomes +Z in the Y-up glTF export, while the actor
	# rotates with Godot's -Z forward. Turn the visible model so its nose follows
	# the body direction; action tweens stay on beaver_model and keep their axes.
	visual.rotation.y = PI
	add_child(visual)
	beaver_model = model_scene.instantiate() as Node3D
	beaver_model.name = "BeaverModel"
	beaver_model.scale = Vector3.ONE * model_scale
	visual.add_child(beaver_model)
	animation_player = _find_animation_player(beaver_model)
	if animation_player != null:
		for animation_name: StringName in [&"Idle", &"Walk"]:
			if animation_player.has_animation(animation_name):
				animation_player.get_animation(animation_name).loop_mode = Animation.LOOP_LINEAR
	_play_animation(&"Idle")


func follow_path(path: PackedVector3Array) -> void:
	waypoints = path


## Turn the body in place so an authored interaction starts with the model facing
## its target. Uses the same heading convention as the walking rotation, so the
## carried item and the nose keep agreeing with the movement direction.
func face_towards(world_xz: Vector2) -> void:
	var offset := world_xz - Vector2(position.x, position.z)
	if offset.length_squared() <= 0.000001:
		return
	rotation.y = atan2(-offset.x, -offset.y)


func is_arrived() -> bool:
	return waypoints.is_empty()


func _physics_process(delta: float) -> void:
	while not waypoints.is_empty():
		var offset := waypoints[0] - position
		offset.y = 0.0
		if offset.length() > 0.035:
			break
		waypoints.remove_at(0)
	velocity.x = 0.0
	velocity.z = 0.0
	if not waypoints.is_empty():
		_cancel_action()
		var offset := waypoints[0] - position
		offset.y = 0.0
		var movement := offset.normalized() * minf(SPEED, offset.length() / delta)
		velocity.x = movement.x
		velocity.z = movement.z
		# Rotate the body so carried branches inherit the same facing direction as the model.
		rotation.y = atan2(-movement.x, -movement.z)
		_play_animation(&"Walk")
	else:
		_play_animation(&"Idle")
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= 18.0 * delta
	move_and_slide()


func play_gnaw_action() -> void:
	_start_action(-0.24, 0.0)
	if action_tween == null:
		return
	action_tween.tween_property(beaver_model, "rotation:x", -0.12, 0.11).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	action_tween.tween_property(beaver_model, "rotation:x", -0.27, 0.10).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	action_tween.tween_property(beaver_model, "rotation:x", 0.0, 0.24).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func play_place_action() -> void:
	_start_action(-0.12, -0.08)
	if action_tween == null:
		return
	action_tween.tween_property(beaver_model, "position:y", -0.08, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	action_tween.parallel().tween_property(beaver_model, "rotation:x", -0.18, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	action_tween.tween_property(beaver_model, "position:y", 0.0, 0.30).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	action_tween.parallel().tween_property(beaver_model, "rotation:x", 0.0, 0.30).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _start_action(start_pitch: float, start_height: float) -> void:
	_cancel_action()
	if beaver_model == null or not is_inside_tree():
		return
	beaver_model.rotation = Vector3(0.0, 0.0, 0.0)
	beaver_model.position.y = start_height
	action_tween = create_tween()
	if start_pitch != 0.0:
		action_tween.tween_property(beaver_model, "rotation:x", start_pitch, 0.10).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _cancel_action() -> void:
	if action_tween != null and action_tween.is_running():
		action_tween.kill()
	if beaver_model != null:
		beaver_model.rotation = Vector3.ZERO
		beaver_model.position.y = 0.0
	action_tween = null



func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found != null:
			return found
	return null


func _play_animation(animation_name: StringName) -> void:
	if animation_player == null or current_animation == animation_name:
		return
	if animation_player.has_animation(animation_name):
		animation_player.play(animation_name, 0.18)
		current_animation = animation_name
