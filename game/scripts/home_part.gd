class_name HomePart
extends Node3D
## One loose home building piece with the same reserve/carry/place lifecycle as a branch.

enum Shape { ROUNDED_LOG, LIGHT_PLANK, MOSSY_LOG }
enum State { FREE, RESERVED, CARRIED, PLACED }

const HIT_LAYER: int = 16

var shape: Shape = Shape.ROUNDED_LOG
var state: State = State.FREE
var stable_id: String = ""
var origin: Vector3
var hit_area: Area3D


func _ready() -> void:
	origin = position
	hit_area = Area3D.new()
	hit_area.name = "HomePartHitArea"
	hit_area.collision_layer = HIT_LAYER
	hit_area.collision_mask = 0
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.35, 0.55, 1.05)
	collision.shape = box
	collision.position.y = 0.15
	hit_area.add_child(collision)
	add_child(hit_area)


func configure_shape(part_shape: Shape, identifier: String) -> void:
	shape = part_shape
	stable_id = identifier
	_build_visual()


func reserve() -> void:
	state = State.RESERVED


func cancel_reservation() -> void:
	if state == State.RESERVED:
		state = State.FREE


func carry(parent: Node3D) -> void:
	state = State.CARRIED
	_reparent_to(parent)
	scale = Vector3.ONE
	position = Vector3(0.0, 0.95, -0.55)
	rotation = Vector3(0.0, 0.0, deg_to_rad(-15.0))
	hit_area.collision_layer = 0


func place_at(parent: Node3D, target_transform: Transform3D, slot_index: int) -> void:
	state = State.PLACED
	_reparent_to(parent)
	global_transform = target_transform
	hit_area.collision_layer = 0


func return_to_origin(world: Node3D) -> void:
	state = State.FREE
	_reparent_to(world)
	scale = Vector3.ONE
	position = origin
	rotation = Vector3.ZERO
	hit_area.collision_layer = HIT_LAYER


func _reparent_to(parent: Node3D) -> void:
	if get_parent() == parent:
		return
	var world_transform := global_transform
	get_parent().remove_child(self)
	parent.add_child(self)
	global_transform = world_transform


func _build_visual() -> void:
	var model := Node3D.new()
	model.name = "HomePartModel"
	add_child(model)
	match shape:
		Shape.ROUNDED_LOG:
			for offset in [-0.24, 0.0, 0.24]:
				_add_cylinder(model, Vector3(0.0, 0.0, offset), 0.145, 1.18, Color("8a5a35"))
		Shape.LIGHT_PLANK:
			_add_box(model, Vector3(0.0, 0.0, 0.0), Vector3(1.2, 0.13, 0.52), Color("d9b77a"))
			_add_box(model, Vector3(0.0, 0.09, 0.0), Vector3(1.22, 0.035, 0.14), Color("b58a52"))
		Shape.MOSSY_LOG:
			for offset in [-0.2, 0.2]:
				_add_cylinder(model, Vector3(0.0, 0.0, offset), 0.155, 1.18, Color("6f7d4e"))
			for moss_offset in [Vector3(-0.3, 0.12, 0.0), Vector3(0.05, 0.13, -0.18), Vector3(0.35, 0.11, 0.12)]:
				_add_sphere(model, moss_offset, 0.1, Color("88a85d"))


func _add_cylinder(parent: Node3D, offset: Vector3, radius: float, height: float, color: Color) -> void:
	var part := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 9
	mesh.material = _material(color)
	part.mesh = mesh
	part.position = offset
	part.rotation.z = PI * 0.5
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(part)


func _add_box(parent: Node3D, offset: Vector3, size: Vector3, color: Color) -> void:
	var part := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = _material(color)
	part.mesh = mesh
	part.position = offset
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(part)


func _add_sphere(parent: Node3D, offset: Vector3, radius: float, color: Color) -> void:
	var part := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 7
	mesh.rings = 4
	mesh.material = _material(color)
	part.mesh = mesh
	part.position = offset
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(part)


func _material(color: Color) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = 0.86
	return result
