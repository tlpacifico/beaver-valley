extends Node3D
## One branch with a stable origin and a simple interaction collider.

enum State { FREE, RESERVED, CARRIED, PLACED }

var state: State = State.FREE
var origin: Vector3
var hit_area: Area3D


func _ready() -> void:
	origin = position
	hit_area = Area3D.new()
	hit_area.collision_layer = 4
	hit_area.collision_mask = 0
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	# The collider covers the visible selection ring, so tapping its edge still selects the branch.
	shape.size = Vector3(1.65, 0.4, 1.65)
	collision.shape = shape
	collision.position.y = 0.15
	hit_area.add_child(collision)
	add_child(hit_area)


func reserve() -> void:
	state = State.RESERVED


func cancel_reservation() -> void:
	if state == State.RESERVED:
		state = State.FREE


func carry(parent: Node3D) -> void:
	state = State.CARRIED
	if get_parent() != parent:
		var world_transform := global_transform
		get_parent().remove_child(self)
		parent.add_child(self)
		global_transform = world_transform
	position = Vector3(0.0, 0.95, -0.55)
	rotation = Vector3(0.0, 0.0, deg_to_rad(-15.0))
	hit_area.collision_layer = 0


func place(parent: Node3D, target_position: Vector3, slot_index: int) -> void:
	state = State.PLACED
	if get_parent() != parent:
		var world_transform := global_transform
		get_parent().remove_child(self)
		parent.add_child(self)
		global_transform = world_transform
	position = target_position + Vector3((slot_index - 1) * 0.48, 0.18, 0.0)
	rotation = Vector3(0.0, 0.0, deg_to_rad(-15.0))
	hit_area.collision_layer = 0


func return_to_origin(world: Node3D) -> void:
	state = State.FREE
	if get_parent() != world:
		get_parent().remove_child(self)
		world.add_child(self)
	position = origin
	rotation = Vector3.ZERO
	hit_area.collision_layer = 4
