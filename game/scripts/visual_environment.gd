extends Node3D
class_name VisualEnvironment
## Small, original, code-authored scenery for the first dam stretch.
## Attach as a child of the walkable world. This node creates no physics bodies.

const Shapes = preload("res://scripts/prototype_shapes.gd")
const GoldenTreeScene = preload("res://assets/environment/meshy_tree/golden_tree.glb")
const WATER_GLINT_X: Array[float] = [-0.28, 0.0, 0.32]
const GOLDEN_TREE_SCALE: float = 0.68

@export var water_depth: float = 0.8
@export var water_front_edge: float = -4.75

var _water_surface: MeshInstance3D
var _water_glints: Array[MeshInstance3D] = []
var _dam_logs: Array[MeshInstance3D] = []
var _dam_finish: String = ""


func _ready() -> void:
	_build_bank_and_water_edge()
	_build_vegetation()
	_build_dam_structure()


## Bind the existing gameplay water surface so the decorative water edge follows it.
## The gameplay script remains responsible for water state and all interactions.
func bind_water_surface(surface: MeshInstance3D) -> void:
	_water_surface = surface
	_sync_water_edge()


## Optional when dam progress changes: pass the active depth and shore-side edge.
func set_water_state(depth: float, front_edge: float) -> void:
	water_depth = maxf(depth, 0.1)
	water_front_edge = front_edge
	var width := 13.0
	if is_instance_valid(_water_surface) and _water_surface.mesh is BoxMesh:
		width = (_water_surface.mesh as BoxMesh).size.x
	_position_water_glints(water_front_edge, water_depth, width)


## Show the completed structural cross-logs for the current 0..3 progress state.
## Finish IDs match the existing choices: "finish_golden", "finish_moss", or empty.
func set_dam_state(count: int, finish: String) -> void:
	var safe_count := clampi(count, 0, _dam_logs.size())
	_dam_finish = finish if finish in ["finish_golden", "finish_moss"] else ""
	for index in range(_dam_logs.size()):
		_dam_logs[index].visible = index < safe_count
		_set_dam_log_finish(_dam_logs[index], index == safe_count - 1 and safe_count == _dam_logs.size())


func get_visible_dam_log_count() -> int:
	var visible_count := 0
	for log in _dam_logs:
		if log.visible:
			visible_count += 1
	return visible_count


## Add an original, faceted rock silhouette over an existing obstacle collider.
## The returned node is decorative only; the caller retains the original physics body.
func add_rock_obstacle(at: Vector3) -> Node3D:
	var rock := Node3D.new()
	rock.name = "RockObstacleVisual"
	rock.position = at
	add_child(rock)
	var boulders: Array[Dictionary] = [
		{"position": Vector3(-0.02, 0.37, -1.9), "size": Vector3(0.88, 0.74, 1.16), "color": Color("798782"), "rotation": Vector3(0.03, 0.08, -0.06)},
		{"position": Vector3(0.03, 0.39, -0.94), "size": Vector3(0.91, 0.78, 1.14), "color": Color("697773"), "rotation": Vector3(-0.04, -0.11, 0.05)},
		{"position": Vector3(-0.04, 0.4, 0.02), "size": Vector3(0.92, 0.8, 1.2), "color": Color("89938b"), "rotation": Vector3(0.02, 0.04, -0.03)},
		{"position": Vector3(0.02, 0.38, 0.98), "size": Vector3(0.9, 0.76, 1.12), "color": Color("727f7b"), "rotation": Vector3(-0.03, 0.1, 0.04)},
		{"position": Vector3(-0.01, 0.36, 1.92), "size": Vector3(0.88, 0.72, 1.12), "color": Color("818c84"), "rotation": Vector3(0.04, -0.06, -0.05)},
		{"position": Vector3(0.0, 0.83, -1.44), "size": Vector3(0.78, 0.57, 0.91), "color": Color("909890"), "rotation": Vector3(-0.04, 0.13, 0.1)},
		{"position": Vector3(-0.03, 0.88, -0.35), "size": Vector3(0.82, 0.63, 0.98), "color": Color("7b8782"), "rotation": Vector3(0.06, -0.09, -0.08)},
		{"position": Vector3(0.02, 0.84, 0.75), "size": Vector3(0.78, 0.58, 0.92), "color": Color("969d93"), "rotation": Vector3(-0.03, 0.07, 0.07)},
		{"position": Vector3(0.0, 0.76, 1.65), "size": Vector3(0.72, 0.52, 0.78), "color": Color("707b77"), "rotation": Vector3(0.04, -0.12, -0.05)},
	]
	for boulder_spec in boulders:
		var boulder := _ellipsoid(boulder_spec["size"], boulder_spec["color"], 7, 4)
		boulder.position = boulder_spec["position"]
		boulder.rotation = boulder_spec["rotation"]
		boulder.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		rock.add_child(boulder)
	return rock


func _build_bank_and_water_edge() -> void:
	# Rounded sand bars sit beside the existing water, not on the walking path.
	for index in range(11):
		var x := -5.0 + float(index)
		var bar := _ellipsoid(Vector3(0.63, 0.075, 0.24), Color("d7bd87"), 8, 4)
		bar.position = Vector3(x, 0.025, -3.44 + sin(float(index) * 0.8) * 0.08)
		add_child(bar)
	# Pale, flat stones give the water a readable shoreline without collision.
	for spec in [
		[Vector3(-4.55, 0.045, -4.15), Vector3(0.48, 0.13, 0.32)],
		[Vector3(-2.75, 0.04, -4.28), Vector3(0.36, 0.11, 0.24)],
		[Vector3(4.55, 0.045, -4.12), Vector3(0.5, 0.14, 0.34)],
		[Vector3(5.45, 0.04, -3.86), Vector3(0.34, 0.1, 0.25)],
	]:
		var stone := _ellipsoid(spec[1], Color("9da99b"), 7, 4)
		stone.position = spec[0]
		add_child(stone)
	_build_water_glints()


func _build_water_glints() -> void:
	# Three soft highlights sit near the bank; they are decorative, not target cues.
	for spec in [
		[Vector3(-3.7, 0.045, -4.72), Vector3(0.7, 0.018, 0.07)],
		[Vector3(0.1, 0.045, -4.82), Vector3(0.95, 0.018, 0.06)],
		[Vector3(4.2, 0.045, -4.66), Vector3(0.62, 0.018, 0.07)],
	]:
		var glint := _ellipsoid(spec[1], Color("a8dce0"), 10, 4)
		glint.position = spec[0]
		add_child(glint)
		_water_glints.append(glint)


func _build_vegetation() -> void:
	# Side-margin vegetation frames the valley while keeping paths and targets clear.
	_add_bush(Vector3(-5.55, 0.0, -2.6), 0.9)
	_add_bush(Vector3(5.55, 0.0, -2.45), 0.82)
	_add_golden_tree(Vector3(-5.55, 0.0, 1.35))
	_add_golden_tree(Vector3(5.55, 0.0, 1.35))
	_add_reeds(Vector3(-4.2, 0.0, -3.65), 4)
	_add_reeds(Vector3(4.0, 0.0, -3.72), 3)


func _add_golden_tree(at: Vector3) -> void:
	# Trees are decorative only: no collision or interaction target is added.
	var tree := GoldenTreeScene.instantiate() as Node3D
	tree.name = "GoldenTree"
	tree.position = at
	tree.scale = Vector3.ONE * GOLDEN_TREE_SCALE
	add_child(tree)


func _add_bush(center: Vector3, scale_factor: float) -> void:
	var trunk := _cylinder(0.16 * scale_factor, 0.68 * scale_factor, Color("806044"), 7)
	trunk.position = center + Vector3(0, 0.34 * scale_factor, 0)
	add_child(trunk)
	for offset in [Vector3(-0.2, 0.72, 0.03), Vector3(0.16, 0.77, 0.0), Vector3(0.0, 0.99, -0.06)]:
		var leaf := _ellipsoid(Vector3(0.42, 0.34, 0.38) * scale_factor, Color("5f9069"), 7, 4)
		leaf.position = center + offset * scale_factor
		add_child(leaf)


func _add_reeds(center: Vector3, count: int) -> void:
	for index in range(count):
		var angle := float(index) * 2.4
		var x := center.x + cos(angle) * 0.28
		var z := center.z + sin(angle) * 0.18
		var stalk := _cylinder(0.035, 0.48 + 0.07 * float(index % 2), Color("6c9b66"), 5)
		stalk.position = Vector3(x, 0.24, z)
		stalk.rotation.z = -0.12 if index % 2 == 0 else 0.12
		add_child(stalk)
		var head := _ellipsoid(Vector3(0.07, 0.15, 0.07), Color("c89b58"), 6, 4)
		head.position = stalk.position + Vector3(0, 0.25, 0)
		add_child(head)


func _build_dam_structure() -> void:
	# Progress logs sit behind the yellow placement ring and above the water plane.
	# The placed collectible branches remain in front, fully visible and selectable.
	for index in range(3):
		var log := _cylinder(0.15, 3.65, Color("93663f"), 8)
		log.name = "DamProgressLog%d" % index
		log.rotation.z = PI * 0.5
		log.position = Vector3(2.5, 0.14 + float(index) * 0.19, -4.93)
		log.visible = false
		add_child(log)
		_dam_logs.append(log)


func _sync_water_edge() -> void:
	if not is_instance_valid(_water_surface):
		_position_water_glints(water_front_edge, water_depth, 13.0)
		return
	var water_mesh := _water_surface.mesh as BoxMesh
	if water_mesh == null:
		return
	var water_front := _water_surface.position.z - water_mesh.size.z * 0.5
	water_depth = water_mesh.size.z
	water_front_edge = water_front
	_position_water_glints(water_front, water_mesh.size.z, water_mesh.size.x)


func _position_water_glints(front_edge: float, depth: float, width: float) -> void:
	for index in range(_water_glints.size()):
		var glint := _water_glints[index]
		# Keep highlights above the active water surface as the gameplay depth changes.
		var relative_x: float = WATER_GLINT_X[index]
		glint.position = Vector3(relative_x * width, 0.045, front_edge + depth * 0.74)


func _set_dam_log_finish(log: MeshInstance3D, is_final_log: bool) -> void:
	var material := Shapes.material(Color("93663f"))
	if is_final_log and _dam_finish == "finish_golden":
		material.albedo_color = Color("d6a83e")
	elif is_final_log and _dam_finish == "finish_moss":
		material.albedo_color = Color("668b59")
	(log.mesh as CylinderMesh).material = material


func _ellipsoid(size: Vector3, color: Color, radial_segments: int, rings: int) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	sphere.radial_segments = radial_segments
	sphere.rings = rings
	sphere.material = Shapes.material(color)
	mesh_instance.mesh = sphere
	mesh_instance.scale = size
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mesh_instance


func _cylinder(radius: float, height: float, color: Color, segments: int) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius * 0.82
	cylinder.bottom_radius = radius
	cylinder.height = height
	cylinder.radial_segments = segments
	cylinder.material = Shapes.material(color)
	mesh_instance.mesh = cylinder
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mesh_instance
