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
var _dam_extra_nodes: Array[Node3D] = []
var _dam_count: int = 0
var _water_level: float = 0.0
var _spillway: Node3D
var _spillway_strips: Array[MeshInstance3D] = []
var _spill_foam: MeshInstance3D


func configure(terrain: ValleyTerrain, layout: ValleyLayout) -> void:
	_terrain = terrain
	_layout = layout
	_water_level = terrain.initial_water_level()


func _ready() -> void:
	_build_backdrop_hills()
	_build_vegetation()
	_build_dam_structure()


## Distant, non-playable hills behind the authored boundary. They continue the
## valley silhouette past the terrain edge, so the far ridge does not end in a
## hard cut against the background.
func _build_backdrop_hills() -> void:
	var hills := Node3D.new()
	hills.name = "BackdropHills"
	add_child(hills)
	var specs: Array[Dictionary] = [
		{"position": Vector3(-24, -1.5, -10), "scale": Vector3(18, 5.0, 14), "color": Color("5b785b")},
		{"position": Vector3(-10, -1.0, -26), "scale": Vector3(20, 4.5, 15), "color": Color("557056")},
		{"position": Vector3(-30, -1.0, 4), "scale": Vector3(14, 6.0, 16), "color": Color("506b52")},
		{"position": Vector3(8, -1.2, -28), "scale": Vector3(18, 4.0, 12), "color": Color("5d7a5b")},
		{"position": Vector3(24, -1.5, -12), "scale": Vector3(15, 5.0, 14), "color": Color("587358")},
		{"position": Vector3(-18, -1.0, -22), "scale": Vector3(16, 6.0, 12), "color": Color("516c55")},
		# Nearer, lower ridges break the silhouette of the distant hills.
		{"position": Vector3(-26, -1.8, -4), "scale": Vector3(12, 3.4, 10), "color": Color("62805b")},
		{"position": Vector3(-17, -1.8, -14), "scale": Vector3(10, 2.8, 8), "color": Color("69875f")},
		{"position": Vector3(14, -1.8, -20), "scale": Vector3(11, 3.0, 8), "color": Color("5d7a57")},
	]
	for spec in specs:
		var hill := _ellipsoid(spec["scale"], spec["color"], 14, 7)
		hill.position = spec["position"]
		hill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		hills.add_child(hill)


## Kept so older callers do not need to change while the chapter is integrated.
func bind_water_surface(_surface: MeshInstance3D) -> void:
	pass


## Water-state visuals are owned by the terrain water meshes; the structural dam
## stays fixed at its crest. The spillway follows the lake surface so the dam
## visibly holds water back and lets it fall downstream.
func set_water_level(level: float) -> void:
	_water_level = level
	_apply_spillway()


func set_dam_state(count: int, _finish: String) -> void:
	_dam_count = clampi(count, 0, _dam_logs.size())
	for index in range(_dam_logs.size()):
		_dam_logs[index].visible = index < _dam_count
		_set_dam_log_material(_dam_logs[index], index == _dam_count - 1 and _dam_count == _dam_logs.size())
	for node in _dam_extra_nodes:
		node.visible = _dam_count > 0
	_apply_spillway()


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
	# A sparse line of darker bushes on the far ridge breaks the hard
	# terrain/backdrop join without closing the playable view.
	for spot in [Vector2(-11.0, -13.0), Vector2(-7.0, -14.4), Vector2(1.0, -15.0), Vector2(5.0, -14.0), Vector2(9.0, -12.4)]:
		if _terrain.contains(spot) and _terrain.slope_degrees(spot) < 34.0:
			_add_bush(Vector3(spot.x, _terrain.height_at(spot), spot.y), 1.15)
	# Reeds follow the near lake shore so the water edge reads as a bank rather
	# than a colour boundary. They are decorative and have no collision.
	for spot in [Vector2(-1.9, -4.0), Vector2(-2.4, -5.0), Vector2(-2.9, -2.2), Vector2(-2.7, -5.8), Vector2(-2.2, -1.4), Vector2(-3.0, -6.4)]:
		_add_reeds(Vector3(spot.x, _terrain.height_at(spot), spot.y), 4 if spot.y < -3.0 else 3)
	for spot in [Vector2(-3.1, -2.6), Vector2(-2.5, -6.2), Vector2(-1.6, -5.5)]:
		_add_shore_rock(Vector3(spot.x, _terrain.height_at(spot), spot.y))


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


func _add_shore_rock(at: Vector3) -> void:
	var rock := _ellipsoid(Vector3(0.58, 0.34, 0.48), Color("7d877d"), 8, 4)
	rock.name = "ShoreRock"
	rock.position = at + Vector3(0.0, 0.06, 0.0)
	add_child(rock)


func _build_dam_structure() -> void:
	if _terrain == null or _layout == null:
		return
	var span := _layout.dam_span()
	if span.size() < 2:
		return
	var start: Vector3 = span[0]
	var finish: Vector3 = span[1]
	var center: Vector3 = _layout.dam_center()
	var full_level := _terrain.full_water_level()
	var length := start.distance_to(finish)
	# Three structural cross-logs reach from bank to bank. The lowest sits at
	# the waterline, so the structure is visible before and after the lake fills.
	for index in range(3):
		var log := _cylinder(0.14, length * (1.0 - 0.04 * float(index)), Color("93663f"), 8)
		log.name = "DamProgressLog%d" % index
		log.rotation.z = PI * 0.5
		log.position = Vector3(center.x, full_level + 0.02 + float(index) * 0.13, center.z + 0.035 * float(index))
		log.visible = false
		add_child(log)
		_dam_logs.append(log)

	# Abutments and two inner posts give the dam a supported silhouette instead
	# of a log floating over the channel.
	for index in range(span.size()):
		var end_point: Vector3 = span[index]
		_add_dam_post("DamAbutment%d" % index, Vector3(end_point.x, end_point.y, end_point.z), 0.12, _layout.dam_crest_y() + 0.08)
		_add_dam_mud(Vector3(end_point.x, end_point.y + 0.06, end_point.z), 0.52)
	for side: float in [-1.0, 1.0]:
		var post_x := center.x + side * 2.05
		var post_ground := _terrain.height_at(Vector2(post_x, center.z))
		_add_dam_post("DamPost%s" % ("West" if side < 0.0 else "East"), Vector3(post_x, post_ground, center.z), 0.09, _layout.dam_crest_y() + 0.04)
	_build_dam_brush(center)
	_build_spillway(center)


## Brush, stakes and mud turn the three cross-logs into a beaver dam rather
## than a fallen log. All of it appears with the first placement.
func _build_dam_brush(center: Vector3) -> void:
	var brush := Node3D.new()
	brush.name = "DamBrush"
	brush.visible = false
	add_child(brush)
	_dam_extra_nodes.append(brush)
	var crest := _layout.dam_crest_y()
	var span := _layout.dam_span()
	var span_length := span[0].distance_to(span[1]) if span.size() >= 2 else 5.0
	var mud_bank := _ellipsoid(Vector3(span_length * 0.88, 0.42, 0.52), Color("65472d"), 12, 5)
	mud_bank.name = "DamMudBank"
	mud_bank.position = Vector3(center.x, crest - 0.18, center.z + 0.10)
	brush.add_child(mud_bank)
	for index in range(9):
		var x := center.x + (float(index) - 4.0) * 0.62
		var z := center.z + 0.12 + float(index % 3) * 0.08
		var from := Vector3(x, crest + 0.03, z)
		var to := Vector3(x + 0.04 * float(index % 2), crest - 0.18, z + 0.30)
		var stick := _stick_between(from, to, 0.026, Color("8b5d36") if index % 2 == 0 else Color("6f4a2c"))
		brush.add_child(stick)
	for index in range(5):
		var x := center.x + (float(index) - 2.0) * 0.86
		var base := Vector3(x, _terrain.height_at(Vector2(x, center.z)) - 0.15, center.z + 0.02)
		var stake := _stick_between(base, Vector3(x, crest + 0.10, center.z), 0.045, Color("7a5433"))
		brush.add_child(stake)
	for index in range(6):
		var mud := _ellipsoid(Vector3(0.48, 0.18, 0.30), Color("6b4a2f"), 8, 4)
		mud.position = Vector3(center.x + (float(index) - 2.5) * 0.58, crest - 0.02, center.z + 0.16)
		mud.rotation.y = 0.2 * float(index)
		brush.add_child(mud)


func _stick_between(from: Vector3, to: Vector3, radius: float, color: Color) -> MeshInstance3D:
	var stick := _cylinder(radius, from.distance_to(to), color, 6)
	stick.position = (from + to) * 0.5
	stick.quaternion = Quaternion(Vector3.UP, (to - from).normalized())
	return stick


func _add_dam_post(node_name: String, base: Vector3, radius: float, top_y: float) -> void:
	var height := maxf(top_y - base.y, 0.12)
	var post := _cylinder(radius, height, Color("7c5737"), 7)
	post.name = node_name
	post.position = Vector3(base.x, base.y + height * 0.5, base.z)
	post.visible = false
	add_child(post)
	_dam_extra_nodes.append(post)


func _add_dam_mud(at: Vector3, scale_factor: float) -> void:
	var mud := _ellipsoid(Vector3(scale_factor, scale_factor * 0.45, scale_factor * 0.85), Color("6b4a2f"), 8, 4)
	mud.name = "DamMud"
	mud.position = at
	mud.visible = false
	add_child(mud)
	_dam_extra_nodes.append(mud)


func _build_spillway(center: Vector3) -> void:
	_spillway = Node3D.new()
	_spillway.name = "DamSpillway"
	_spillway.position = Vector3(center.x, 0.0, center.z + 0.22)
	_spillway.visible = false
	add_child(_spillway)
	for index in range(4):
		var strip := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.09, 0.3, 0.035)
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.74, 0.91, 0.97, 0.62 - 0.08 * float(index))
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		mesh.material = material
		strip.mesh = mesh
		strip.position.x = (float(index) - 1.5) * 0.17
		strip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_spillway.add_child(strip)
		_spillway_strips.append(strip)

	_spill_foam = MeshInstance3D.new()
	_spill_foam.name = "DamSpillFoam"
	var foam := TorusMesh.new()
	foam.inner_radius = 0.32
	foam.outer_radius = 0.46
	var foam_material := StandardMaterial3D.new()
	foam_material.albedo_color = Color(0.86, 0.94, 0.92, 0.65)
	foam_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	foam_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	foam.material = foam_material
	_spill_foam.mesh = foam
	_spill_foam.position = Vector3(center.x, _terrain.initial_water_level() + 0.04, center.z + 0.7)
	_spill_foam.scale = Vector3(1.0, 1.0, 0.7)
	_spill_foam.visible = false
	_spill_foam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_spill_foam)


func _apply_spillway() -> void:
	if _spillway == null or _terrain == null:
		return
	var rise := maxf(_water_level - _terrain.initial_water_level(), 0.0)
	var active := _dam_count > 0 and rise > 0.015
	_spillway.visible = active
	_spill_foam.visible = active
	if not active:
		return
	var height := rise + 0.16
	for strip in _spillway_strips:
		var mesh := strip.mesh as BoxMesh
		mesh.size = Vector3(0.09, height, 0.035)
		strip.position.y = _terrain.initial_water_level() + height * 0.5
	_spill_foam.position.y = _terrain.initial_water_level() + 0.04


## The finish is a short accent owned by the world's finish trim; the long
## structural log keeps its timber colour so the choice does not dominate.
func _set_dam_log_material(log: MeshInstance3D, is_final_log: bool) -> void:
	var material := Shapes.material(Color("85603a") if is_final_log else Color("93663f"))
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
