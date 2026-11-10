extends Node3D
class_name VisualEnvironment
## Code-authored scenery grounded on the authored terrain. Attach as a child of
## the world. This node creates no physics bodies.

const Shapes = preload("res://scripts/prototype_shapes.gd")
const GoldenTreeScene = preload("res://assets/environment/meshy_tree/golden_tree.glb")
const GOLDEN_TREE_SCALE: float = 0.68

var _terrain: ValleyTerrain
var _layout: ValleyLayout
var _dam_logs: Array[MeshInstance3D] = []
var _dam_finish: String = ""


func configure(terrain: ValleyTerrain, layout: ValleyLayout) -> void:
	_terrain = terrain
	_layout = layout


func _ready() -> void:
	_build_vegetation()
	_build_dam_structure()


## Kept so older callers do not need to change while the chapter is integrated.
func bind_water_surface(_surface: MeshInstance3D) -> void:
	pass


## Water-state visuals are owned by the terrain water mesh in R3; the structural
## dam logs stay fixed. R4 can add the rising-water details.
func set_water_state(_depth: float, _front_edge: float) -> void:
	pass


## Show the completed structural cross-logs for the current 0..3 progress state.
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
	]
	for boulder_spec in boulders:
		var boulder := _ellipsoid(boulder_spec["size"], boulder_spec["color"], 7, 4)
		boulder.position = boulder_spec["position"]
		boulder.rotation = boulder_spec["rotation"]
		boulder.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		rock.add_child(boulder)
	return rock


func _build_vegetation() -> void:
	if _terrain == null:
		return
	for spot in [Vector2(-7.5, -3.0), Vector2(-3.5, -8.0)]:
		_add_golden_tree(Vector3(spot.x, _terrain.height_at(spot), spot.y))
	_add_bush(Vector3(5.6, _terrain.height_at(Vector2(5.6, 2.6)), 2.6), 0.9)
	_add_bush(Vector3(5.2, _terrain.height_at(Vector2(5.2, -2.4)), -2.4), 0.82)
	_add_reeds(Vector3(-1.9, _terrain.height_at(Vector2(-1.9, -4.0)), -4.0), 4)
	_add_reeds(Vector3(-2.4, _terrain.height_at(Vector2(-2.4, -5.0)), -5.0), 3)


func _add_golden_tree(at: Vector3) -> void:
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
		var ground := _terrain.height_at(Vector2(x, z)) if _terrain != null else center.y
		var stalk := _cylinder(0.035, 0.48 + 0.07 * float(index % 2), Color("6c9b66"), 5)
		stalk.position = Vector3(x, ground + 0.24, z)
		stalk.rotation.z = -0.12 if index % 2 == 0 else 0.12
		add_child(stalk)
		var head := _ellipsoid(Vector3(0.07, 0.15, 0.07), Color("c89b58"), 6, 4)
		head.position = stalk.position + Vector3(0, 0.25, 0)
		add_child(head)


func _build_dam_structure() -> void:
	if _terrain == null or _layout == null:
		return
	var span := _layout.dam_span()
	if span.size() < 2:
		return
	var start: Vector3 = span[0]
	var finish: Vector3 = span[1]
	var length := start.distance_to(finish)
	for index in range(3):
		var log := _cylinder(0.15, length * (1.0 - 0.04 * float(index)), Color("93663f"), 8)
		log.name = "DamProgressLog%d" % index
		log.rotation.z = PI * 0.5
		log.position = Vector3((start.x + finish.x) * 0.5, _terrain.initial_water_level() + 0.12 + float(index) * 0.17, _terrain.dam_z() + 0.03 * float(index))
		log.visible = false
		add_child(log)
		_dam_logs.append(log)


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
