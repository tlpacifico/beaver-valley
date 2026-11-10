class_name CollectibleBranch
extends Node3D
## One branch with a stable origin and a simple interaction collider.

enum State { FREE, RESERVED, CARRIED, PLACED }
enum Kind { NORMAL, THICK, ROTTEN }

var state: State = State.FREE
var origin: Vector3
var hit_area: Area3D
var stable_id: String = ""
var kind: Kind = Kind.NORMAL
var gnawed: bool = false
var bent: bool = false
var thick_bulge: MeshInstance3D
var gnaw_scars: Array[MeshInstance3D] = []


func _ready() -> void:
	origin = position
	hit_area = Area3D.new()
	hit_area.collision_layer = 4
	hit_area.collision_mask = 0
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	# The collider covers the visible selection ring, so tapping its edge still selects the branch.
	shape.size = Vector3(1.25, 0.4, 1.25)
	collision.shape = shape
	collision.position.y = 0.15
	hit_area.add_child(collision)
	add_child(hit_area)


func reserve() -> void:
	state = State.RESERVED


func cancel_reservation() -> void:
	if state == State.RESERVED:
		state = State.FREE


func configure_branch(branch_kind: Kind, identifier: String) -> void:
	kind = branch_kind
	stable_id = identifier
	if kind == Kind.THICK:
		_set_color(Color("9b653b"))
		_add_thick_bulge()
	elif kind == Kind.ROTTEN:
		_set_color(Color("6f7950"))


func _set_color(color: Color) -> void:
	var model := get_node_or_null("BranchModel")
	if model == null:
		return
	for mesh_instance in _mesh_instances(model):
		var mesh := mesh_instance as MeshInstance3D
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		mesh.material_override = material


func _mesh_instances(node: Node) -> Array[Node]:
	var result: Array[Node] = []
	for child in node.get_children():
		if child is MeshInstance3D:
			result.append(child)
		result.append_array(_mesh_instances(child))
	return result


func gnaw() -> void:
	if kind != Kind.THICK or gnawed:
		return
	gnawed = true
	_add_gnaw_scars()
	if thick_bulge != null:
		thick_bulge.visible = false


func _add_thick_bulge() -> void:
	var model := get_node_or_null("BranchModel") as Node3D
	if model == null or thick_bulge != null:
		return
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.16
	cylinder.bottom_radius = 0.16
	cylinder.height = 0.82
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("754721")
	cylinder.material = material
	thick_bulge = MeshInstance3D.new()
	thick_bulge.name = "ThickBulge"
	thick_bulge.mesh = cylinder
	thick_bulge.rotation.z = deg_to_rad(90.0)
	thick_bulge.position = Vector3(0.0, 0.12, 0.0)
	model.add_child(thick_bulge)


func _add_gnaw_scars() -> void:
	if not gnaw_scars.is_empty():
		for scar in gnaw_scars:
			scar.visible = true
		return
	var model := get_node_or_null("BranchModel") as Node3D
	if model == null:
		return
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("efd09a")
	for offset in [-0.055, 0.055]:
		var scar := MeshInstance3D.new()
		scar.name = "GnawMark"
		var mesh := SphereMesh.new()
		mesh.radius = 0.075
		mesh.height = 0.13
		mesh.material = material
		scar.mesh = mesh
		scar.position = Vector3(0.53, 0.13, offset)
		model.add_child(scar)
		gnaw_scars.append(scar)


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
	if kind == Kind.ROTTEN and not bent:
		bend()


func bend() -> void:
	if kind != Kind.ROTTEN or bent:
		return
	bent = true
	rotation.z = deg_to_rad(28.0)


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
	if kind == Kind.ROTTEN and bent:
		rotation.z = deg_to_rad(18.0)
	hit_area.collision_layer = 4
