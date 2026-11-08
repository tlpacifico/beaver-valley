extends Node3D
## Technical test asset: skeletal model that switches between idle and walk.
## It is not the Castor character nor its art direction.

const MODEL := preload("res://assets/characters/test_fox/Fox.glb")
const IDLE: StringName = &"Survey"
const WALK: StringName = &"Walk"
const SPEED: float = 1.1
## The source file uses roughly centimeters (about 155 long).
const MODEL_SCALE: float = 0.005
var animation_player: AnimationPlayer
var skeleton: Skeleton3D
var target := Vector3.ZERO
var moving: bool = false


func _ready() -> void:
	var model: Node3D = MODEL.instantiate()
	model.scale = Vector3.ONE * MODEL_SCALE
	add_child(model)
	animation_player = model.find_child("AnimationPlayer", true, false)
	skeleton = model.find_child("Skeleton3D", true, false)
	for animation_name in [IDLE, WALK]:
		animation_player.get_animation(animation_name).loop_mode = Animation.LOOP_LINEAR
	target = position
	animation_player.play(IDLE)


func walk_to(destination: Vector3) -> void:
	target = Vector3(destination.x, position.y, destination.z)


func is_walking() -> bool:
	return moving


func current_animation() -> StringName:
	return animation_player.current_animation


func _process(delta: float) -> void:
	var offset := target - position
	offset.y = 0.0
	moving = offset.length() > 0.02
	if moving:
		position += offset.normalized() * minf(SPEED * delta, offset.length())
		# The model faces +Z; turn it towards the movement direction.
		rotation.y = atan2(offset.x, offset.z)
	var wanted := WALK if moving else IDLE
	if animation_player.current_animation != wanted:
		animation_player.play(wanted, 0.2)
