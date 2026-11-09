class_name FoodBundle
extends Node3D
## One bundle of branches for the winter store. Suitable bundles are thick and
## leafy; thin bundles are visibly small and pale.

enum Kind { SUITABLE, THIN }
enum State { FREE, RESERVED, CARRIED, PLACED }

const HIT_LAYER: int = 64

var kind: Kind = Kind.SUITABLE
var state: State = State.FREE
var stable_id: String = ""
var origin: Vector3
var hit_area: Area3D


func _ready() -> void:
	origin = position
	hit_area = Area3D.new()
	hit_area.name = "FoodBundleHitArea"
	hit_area.collision_layer = HIT_LAYER
	hit_area.collision_mask = 0
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.3, 0.5, 1.0)
	collision.shape = box
	collision.position.y = 0.15
	hit_area.add_child(collision)
	add_child(hit_area)


func configure_bundle(bundle_kind: Kind, identifier: String) -> void:
	kind = bundle_kind
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


func place_at(parent: Node3D, target_transform: Transform3D, _slot_index: int) -> void:
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
	model.name = "FoodBundleModel"
	add_child(model)
	if kind == Kind.SUITABLE:
		for offset in [-0.22, 0.0, 0.22]:
			_add_cylinder(model, Vector3(0.0, 0.0, offset), 0.13, 1.1, Color("8a5a35"))
		for leaf_offset in [Vector3(-0.35, 0.15, 0.0), Vector3(0.0, 0.17, -0.2), Vector3(0.32, 0.14, 0.12), Vector3(0.1, 0.12, 0.24)]:
			_add_sphere(model, leaf_offset, 0.13, Color("6fa45b"))
	else:
		for offset in [-0.14, 0.14]:
			_add_cylinder(model, Vector3(0.0, 0.0, offset), 0.075, 0.92, Color("b39a6b"))
		for leaf_offset in [Vector3(-0.25, 0.1, 0.0), Vector3(0.25, 0.09, 0.08)]:
			_add_sphere(model, leaf_offset, 0.09, Color("d9c56a"))


func _add_cylinder(parent: Node3D, offset: Vector3, radius: float, height: float, color: Color) -> void:
	var part := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 8
	mesh.material = _material(color)
	part.mesh = mesh
	part.position = offset
	part.rotation.z = PI * 0.5
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(part)


func _add_sphere(parent: Node3D, offset: Vector3, radius: float, color: Color) -> void:
	var part := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	sphere.radial_segments = 7
	sphere.rings = 4
	sphere.material = _material(color)
	part.mesh = sphere
	part.position = offset
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(part)


func _material(color: Color) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = 0.86
	return result
