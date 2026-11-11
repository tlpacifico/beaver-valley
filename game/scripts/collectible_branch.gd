class_name CollectibleBranch
extends Node3D
## One branch with a stable origin and a simple interaction collider.

## Emitted once when an animated placement reaches its final transform. Instant
## placement and restore never emit it; presentation timers are not saved.
signal placement_visual_finished(slot_index: int)

enum State { FREE, RESERVED, CARRIED, PLACED }
enum Kind { NORMAL, THICK, ROTTEN }

const DEFAULT_CARRY_OFFSET := Vector3(0.0, 0.95, -0.55)
const STONE_SCALES: Array[Vector3] = [
	Vector3(0.84, 0.68, 0.74), Vector3(0.68, 0.90, 0.72), Vector3(0.96, 0.62, 0.78),
	Vector3(0.74, 0.72, 0.96), Vector3(0.88, 0.82, 0.62),
]
const STONE_COLORS: Array[Color] = [
	Color("8a9183"), Color("929184"), Color("788a83"), Color("a09583"), Color("7f858f"),
]

var state: State = State.FREE
var origin: Vector3
var hit_area: Area3D
var stable_id: String = ""
var kind: Kind = Kind.NORMAL
var material_type: String = "branch"
var material_variant: int = 0
var gnawed: bool = false
var bent: bool = false
var placed_slot: int = -1
var thick_bulge: MeshInstance3D
var gnaw_scars: Array[MeshInstance3D] = []
var _flight_tween: Tween
var _flight_generation: int = 0


func _ready() -> void:
	origin = position
	_build_material_visual()
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


func configure_material(type: String, identifier: String, variant: int = 0) -> void:
	material_type = type
	stable_id = identifier
	material_variant = posmod(variant, STONE_SCALES.size())


func _build_material_visual() -> void:
	if material_type == "branch":
		return
	var branch_model := get_node_or_null("BranchModel") as Node3D
	if branch_model != null:
		branch_model.visible = false
	var model := Node3D.new()
	model.name = "MaterialModel"
	add_child(model)
	if material_type == "log":
		_add_log_piece(model, 1.02, 0.18, Color("765033"), Vector3.ZERO)
		_add_log_piece(model, 0.025, 0.145, Color("c69b62"), Vector3(-0.49, 0.0, 0.0))
		_add_log_piece(model, 0.025, 0.145, Color("c69b62"), Vector3(0.49, 0.0, 0.0))
	elif material_type == "stone":
		var stone := MeshInstance3D.new()
		stone.name = "CollectibleStoneModel"
		var mesh := SphereMesh.new()
		mesh.radial_segments = 8
		mesh.rings = 4
		mesh.radius = 0.25
		mesh.height = 0.32
		var material := StandardMaterial3D.new()
		material.albedo_color = STONE_COLORS[material_variant]
		material.roughness = 0.96
		mesh.material = material
		stone.mesh = mesh
		stone.scale = STONE_SCALES[material_variant]
		stone.rotation = Vector3(0.12 * float(material_variant % 3), 0.31 * float(material_variant), 0.08 * float(material_variant % 2))
		stone.position.y = 0.16
		model.add_child(stone)


func _add_log_piece(parent: Node3D, length: float, radius: float, color: Color, at: Vector3) -> void:
	var piece := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius
	cylinder.height = length
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.94
	cylinder.material = material
	piece.mesh = cylinder
	piece.rotation.z = PI * 0.5
	piece.position = at + Vector3(0.0, radius + 0.02, 0.0)
	parent.add_child(piece)


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


func carry(parent: Node3D, offset: Vector3 = DEFAULT_CARRY_OFFSET, roll: float = deg_to_rad(-15.0)) -> void:
	_cancel_flight()
	_flight_generation += 1
	state = State.CARRIED
	if get_parent() != parent:
		var world_transform := global_transform
		get_parent().remove_child(self)
		parent.add_child(self)
		global_transform = world_transform
	position = offset
	rotation = Vector3(0.0, 0.0, roll)
	hit_area.collision_layer = 0
	if kind == Kind.ROTTEN and not bent:
		bend()


func bend() -> void:
	if kind != Kind.ROTTEN or bent:
		return
	bent = true
	rotation.z = deg_to_rad(28.0)


func place(parent: Node3D, target_position: Vector3, slot_index: int, animate: bool = false) -> void:
	state = State.PLACED
	placed_slot = slot_index
	var start_global := global_transform
	if get_parent() != parent:
		var world_transform := global_transform
		get_parent().remove_child(self)
		parent.add_child(self)
		global_transform = world_transform
	position = target_position + Vector3((slot_index - 1) * 0.48, 0.18, 0.0)
	rotation = Vector3(0.0, 0.0, deg_to_rad(-15.0))
	hit_area.collision_layer = 0
	_cancel_flight()
	_flight_generation += 1
	if animate and is_inside_tree():
		var generation := _flight_generation
		var end_global := global_transform
		global_transform = start_global
		_flight_tween = create_tween()
		_flight_tween.tween_method(_set_flight_transform.bind(start_global, end_global), 0.0, 1.0, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_flight_tween.tween_callback(func() -> void: _finish_flight(generation, slot_index, end_global))


## Interpolate the complete transform, including the placement orientation, so
## a branch thrown from the bank does not keep the beaver's facing while flying.
func _set_flight_transform(progress: float, start: Transform3D, end: Transform3D) -> void:
	var basis := start.basis.slerp(end.basis, progress).orthonormalized()
	var origin := start.origin.lerp(end.origin, progress)
	global_transform = Transform3D(basis, origin)


## Report the visual completion exactly once for the latest animated placement.
## A branch freed or removed mid-flight never reaches this callback; a newer
## placement invalidates the older generation.
func _finish_flight(generation: int, slot_index: int, end_global: Transform3D) -> void:
	if generation != _flight_generation:
		return
	_flight_tween = null
	if not is_inside_tree():
		return
	global_transform = end_global
	placement_visual_finished.emit(slot_index)


func _cancel_flight() -> void:
	if _flight_tween != null and _flight_tween.is_valid():
		_flight_tween.kill()
	_flight_tween = null


func return_to_origin(world: Node3D) -> void:
	_cancel_flight()
	_flight_generation += 1
	state = State.FREE
	placed_slot = -1
	if get_parent() != world:
		get_parent().remove_child(self)
		world.add_child(self)
	position = origin
	rotation = Vector3.ZERO
	if kind == Kind.ROTTEN and bent:
		rotation.z = deg_to_rad(18.0)
	hit_area.collision_layer = 4
