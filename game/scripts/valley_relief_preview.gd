extends Node3D
## Isolated R1 relief preview: visible-only valley, three cameras, temporary guides
## and an offline capture mode. No physics, navigation, stages or save access.

const BeaverScene := preload("res://assets/characters/beaver/Beaver.glb")
const GoldenTreeScene := preload("res://assets/environment/meshy_tree/golden_tree.glb")

const ORTHO_POSITION := Vector3(9.5, 14.5, 13.0)
const ORTHO_TARGET := Vector3(-1.5, 0.5, -2.0)
const ORTHO_SIZE := 15.0
const PERSP_POSITION := Vector3(9.5, 14.5, 13.0)
const PERSP_FOV := 36.0
const LOW_SIDE_POSITION := Vector3(9.5, 2.8, 13.5)
const LOW_SIDE_TARGET := Vector3(0.0, 0.6, 0.0)
const LOW_SIDE_FOV := 45.0
const PORTRAIT_SIZE := 24.0
const CAMERA_NEAR := 0.1
const CAMERA_FAR := 200.0

const CAPTURE_FLAG := "--capture-relief"
const CAPTURE_DIR := "user://relief"
const CAPTURE_SIZE := Vector2i(960, 600)
const CAPTURE_PORTRAIT := Vector2i(540, 960)

const ROUTE_WIDTH := 0.16
const ROUTE_LIFT := 0.05
const ANCHOR_MARK_RADIUS := 0.17
const ANCHOR_MARK_LIFT := 0.07
const BLOCKED_SLOPE_DEGREES := 20.0
const BLOCKED_LIFT := 0.03
const GUIDE_COLOR := Color("d7f26a")
const BLOCKED_COLOR := Color(0.85, 0.22, 0.16, 0.30)
const MAX_WATER_COLOR := Color(0.20, 0.80, 0.92, 0.30)
const CLEARING_COLOR := Color(0.82, 0.76, 0.58, 0.55)
const SPAWN_RING_COLOR := Color(0.88, 0.85, 0.70, 0.78)
const LOG_COLOR := Color("8a7350")
const DAM_LOG_COLOR := Color("7b6a4c")
const LODGE_COLOR := Color("8d7f68")
const LODGE_DOOR_COLOR := Color("4f4638")
const FOOD_COLOR := Color("b09a62")
const FOOD_STRAP_COLOR := Color("8f7c4e")
const STICK_COLOR := Color("7f6a4b")

const HUD_COLOR := Color("d8e4da")
const HUD_OUTLINE := Color(0.0, 0.0, 0.0, 0.85)

var _terrain: ValleyTerrain
var _layout: ValleyLayout
var _terrain_mesh: MeshInstance3D
var _water_mesh: MeshInstance3D
var _route_overlay: Node3D
var _route_ribbon: MeshInstance3D
var _route_marks: MeshInstance3D
var _blocked_overlay: Node3D
var _blocked_cells: MeshInstance3D
var _max_water_overlay: MeshInstance3D
var _stage_volumes: Node3D
var _camera: Camera3D
var _hud: CanvasLayer
var _hud_label: Label
var _legend_label: Label
var _active_variant: StringName = &"gentle"
var _projection_mode: StringName = &"ortho"
var _route_visible: bool = false
var _blocked_visible: bool = false
var _max_water_visible: bool = false
var _capture_running: bool = false


func _ready() -> void:
	# Fixed pixel space keeps HUD placement and capture dimensions predictable when
	# the window is resized to the portrait capture size.
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	_terrain = ValleyTerrain.new()
	_layout = ValleyLayout.new()
	_build_environment()
	_build_world_nodes()
	_build_camera()
	_build_hud()
	_set_projection(&"persp")
	_apply_variant(&"wide_bank")
	get_viewport().size_changed.connect(_refresh_hud)
	print("RELIEF_PREVIEW_READY variant=wide_bank projection=persp")
	if CAPTURE_FLAG in OS.get_cmdline_user_args():
		_run_capture.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if _capture_running:
		return
	var key_event := event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return
	match key_event.keycode:
		KEY_1:
			_apply_variant(&"gentle")
		KEY_2:
			_apply_variant(&"pronounced")
		KEY_3:
			_apply_variant(&"wide_bank")
		KEY_O:
			_set_projection(&"ortho")
		KEY_P:
			_set_projection(&"persp")
		KEY_W:
			_set_overlays(not _route_visible, _blocked_visible, _max_water_visible)
			_print_state()
		KEY_B:
			_set_overlays(_route_visible, not _blocked_visible, _max_water_visible)
			_print_state()
		KEY_M:
			_set_overlays(_route_visible, _blocked_visible, not _max_water_visible)
			_print_state()
		KEY_L:
			_set_projection(&"ortho" if _projection_mode == &"lowside" else &"lowside")


func _build_environment() -> void:
	var world := WorldEnvironment.new()
	world.name = "Environment"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("162a30")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("d4e4e0")
	environment.ambient_light_energy = 0.45
	world.environment = environment
	add_child(world)

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-60.0, -25.0, 0.0)
	sun.light_energy = 0.85
	sun.shadow_enabled = true
	add_child(sun)


func _build_world_nodes() -> void:
	_terrain_mesh = MeshInstance3D.new()
	_terrain_mesh.name = "TerrainMesh"
	_terrain_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(_terrain_mesh)

	_water_mesh = MeshInstance3D.new()
	_water_mesh.name = "WaterMesh"
	_water_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_water_mesh)

	_stage_volumes = Node3D.new()
	_stage_volumes.name = "StageVolumes"
	add_child(_stage_volumes)

	_route_overlay = Node3D.new()
	_route_overlay.name = "RouteOverlay"
	_route_overlay.visible = false
	add_child(_route_overlay)
	_route_ribbon = MeshInstance3D.new()
	_route_ribbon.name = "RouteRibbon"
	_route_ribbon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_route_overlay.add_child(_route_ribbon)
	_route_marks = MeshInstance3D.new()
	_route_marks.name = "AnchorMarks"
	_route_marks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_route_overlay.add_child(_route_marks)

	_blocked_overlay = Node3D.new()
	_blocked_overlay.name = "BlockedOverlay"
	_blocked_overlay.visible = false
	add_child(_blocked_overlay)
	_blocked_cells = MeshInstance3D.new()
	_blocked_cells.name = "BlockedCells"
	_blocked_cells.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_blocked_overlay.add_child(_blocked_cells)

	_max_water_overlay = MeshInstance3D.new()
	_max_water_overlay.name = "MaxWaterOverlay"
	_max_water_overlay.visible = false
	_max_water_overlay.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_max_water_overlay.material_override = _make_material(MAX_WATER_COLOR, true)
	add_child(_max_water_overlay)


func _build_camera() -> void:
	_camera = Camera3D.new()
	_camera.name = "PreviewCamera"
	_camera.near = CAMERA_NEAR
	_camera.far = CAMERA_FAR
	_camera.current = true
	add_child(_camera)
	_set_projection(&"ortho")
	print("RELIEF_CAMERA ortho position=%s target=%s size=%.1f | perspective position=%s target=%s fov=%.1f near=%.1f far=%.1f | lowside position=%s target=%s fov=%.1f | portrait=%dx%d size=%.1f" % [
		ORTHO_POSITION,
		ORTHO_TARGET,
		ORTHO_SIZE,
		PERSP_POSITION,
		ORTHO_TARGET,
		PERSP_FOV,
		CAMERA_NEAR,
		CAMERA_FAR,
		LOW_SIDE_POSITION,
		LOW_SIDE_TARGET,
		LOW_SIDE_FOV,
		CAPTURE_PORTRAIT.x,
		CAPTURE_PORTRAIT.y,
		PORTRAIT_SIZE,
	])


func _build_hud() -> void:
	_hud = CanvasLayer.new()
	_hud.name = "Hud"
	add_child(_hud)

	_hud_label = Label.new()
	_hud_label.name = "Status"
	_hud_label.position = Vector2(12.0, 8.0)
	_hud_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_label.add_theme_font_size_override("font_size", 13)
	_hud_label.add_theme_color_override("font_color", HUD_COLOR)
	_hud_label.add_theme_color_override("font_outline_color", HUD_OUTLINE)
	_hud_label.add_theme_constant_override("outline_size", 3)
	_hud.add_child(_hud_label)

	_legend_label = Label.new()
	_legend_label.name = "Legend"
	_legend_label.anchor_top = 1.0
	_legend_label.anchor_bottom = 1.0
	_legend_label.anchor_right = 1.0
	_legend_label.offset_left = 12.0
	_legend_label.offset_right = -12.0
	_legend_label.offset_top = -42.0
	_legend_label.offset_bottom = -8.0
	_legend_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_legend_label.add_theme_font_size_override("font_size", 11)
	_legend_label.add_theme_color_override("font_color", HUD_COLOR)
	_legend_label.add_theme_color_override("font_outline_color", HUD_OUTLINE)
	_legend_label.add_theme_constant_override("outline_size", 3)
	_legend_label.text = "1/2/3 variants   O/P orthographic/perspective\nW route   B blocked hills   M max water   L low side"
	_hud.add_child(_legend_label)


func _apply_variant(new_variant: StringName) -> void:
	_active_variant = new_variant if new_variant in ValleyTerrain.VARIANTS else &"gentle"
	_terrain.configure(_active_variant)
	_layout.configure(_terrain)
	_terrain_mesh.mesh = _terrain.terrain_mesh()
	_water_mesh.mesh = _terrain.water_mesh(_terrain.initial_water_level())
	_rebuild_stage_volumes()
	_rebuild_route_overlay()
	_rebuild_blocked_overlay()
	_max_water_overlay.mesh = _terrain.water_mesh(_terrain.full_water_level())
	_refresh_hud()
	_print_state()


func _rebuild_stage_volumes() -> void:
	_clear_children(_stage_volumes)
	_build_branch_clearing()
	_build_dam()
	_build_lodge()
	_build_home_parts()
	_build_food_bank()
	_build_spawn_ring()
	_build_perimeter_props()
	_add_static_beaver()


func _build_branch_clearing() -> void:
	var center: Vector3 = _layout.anchor(&"branch_clearing")
	var clearing := _make_ground_disc(Vector2(center.x, center.z), 1.12, 0.012, CLEARING_COLOR)
	clearing.name = "BranchClearingDisc"
	_stage_volumes.add_child(clearing)
	_add_short_log("BranchLog0", Vector2(0.62, 1.38), Vector2(1.18, 1.50))
	_add_short_log("BranchLog1", Vector2(1.35, 1.82), Vector2(1.90, 2.05))
	_add_short_log("BranchLog2", Vector2(0.75, 2.12), Vector2(1.35, 2.22))
	_add_short_log("BranchLog3", Vector2(2.45, 1.05), Vector2(2.95, 1.40))
	_add_short_log("BranchLog4", Vector2(0.35, 2.65), Vector2(0.85, 3.05))


func _build_dam() -> void:
	var span := _layout.dam_span()
	if span.size() < 2:
		return
	var start: Vector3 = span[0]
	var finish: Vector3 = span[1]
	var span_length := start.distance_to(finish)
	var center_x := (start.x + finish.x) * 0.5
	var water := _terrain.initial_water_level()
	var levels: Array[float] = [water + 0.09, water + 0.24, water + 0.39]
	var offsets: Array[float] = [0.05, -0.04, 0.02]
	var length_scales: Array[float] = [1.0, 0.96, 0.90]
	for index in range(levels.size()):
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = 0.09
		cylinder.bottom_radius = 0.11
		cylinder.height = span_length * length_scales[index]
		cylinder.radial_segments = 10
		cylinder.material = _make_material(DAM_LOG_COLOR.lightened(0.02 * float(index)))
		var log_instance := MeshInstance3D.new()
		log_instance.name = "DamLog%d" % index
		log_instance.mesh = cylinder
		log_instance.rotation.z = PI * 0.5
		log_instance.position = Vector3(center_x, levels[index], _terrain.dam_z() + offsets[index])
		log_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		_stage_volumes.add_child(log_instance)


func _build_lodge() -> void:
	var center: Vector3 = _layout.anchor(&"lodge")
	var dome := MeshInstance3D.new()
	dome.name = "LodgeDome"
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	sphere.radial_segments = 16
	sphere.rings = 8
	sphere.material = _make_material(LODGE_COLOR)
	dome.mesh = sphere
	dome.scale = Vector3(1.45, 0.62, 1.45)
	dome.position = center + Vector3(0.0, 0.13, 0.0)
	dome.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_stage_volumes.add_child(dome)

	var to_camera := Vector3(ORTHO_POSITION.x - center.x, 0.0, ORTHO_POSITION.z - center.z).normalized()
	var door_xz := Vector2(center.x, center.z) + Vector2(to_camera.x, to_camera.z) * 0.78
	var door := MeshInstance3D.new()
	door.name = "LodgeDoor"
	var box := BoxMesh.new()
	box.size = Vector3(0.26, 0.30, 0.09)
	box.material = _make_material(LODGE_DOOR_COLOR)
	door.mesh = box
	door.position = Vector3(door_xz.x, _terrain.height_at(door_xz) + 0.15, door_xz.y)
	door.rotation.y = atan2(to_camera.x, to_camera.z)
	door.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_stage_volumes.add_child(door)

	_add_short_log("LodgeStick0", Vector2(0.15, -3.05), Vector2(0.62, -3.35))
	_add_short_log("LodgeStick1", Vector2(-0.15, -2.95), Vector2(0.30, -2.70))


func _build_home_parts() -> void:
	var parts: Array[Dictionary] = [
		{"position": Vector2(-2.6, -2.2), "size": Vector3(0.92, 0.22, 0.28), "rotation": 0.4, "color": Color("8a7350")},
		{"position": Vector2(-1.6, -2.6), "size": Vector3(0.62, 0.10, 0.46), "rotation": -0.3, "color": Color("b9a98a")},
		{"position": Vector2(-2.9, -3.2), "size": Vector3(0.72, 0.30, 0.32), "rotation": 0.9, "color": Color("6d7f52")},
	]
	for index in range(parts.size()):
		var spec: Dictionary = parts[index]
		var spot: Vector2 = spec["position"]
		var size: Vector3 = spec["size"]
		var part := MeshInstance3D.new()
		part.name = "HomePart%d" % index
		var box := BoxMesh.new()
		box.size = size
		box.material = _make_material(spec["color"])
		part.mesh = box
		part.position = Vector3(spot.x, _terrain.height_at(spot) + size.y * 0.5, spot.y)
		part.rotation.y = spec["rotation"]
		part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		_stage_volumes.add_child(part)


func _build_food_bank() -> void:
	var spots: Array[Vector2] = [Vector2(2.28, -4.22), Vector2(2.66, -4.42), Vector2(2.38, -4.66), Vector2(3.25, -4.18), Vector2(1.62, -4.72)]
	for index in range(spots.size()):
		var spot: Vector2 = spots[index]
		var bundle := MeshInstance3D.new()
		bundle.name = "FoodBundle%d" % index
		var box := BoxMesh.new()
		box.size = Vector3(0.34, 0.22, 0.26)
		box.material = _make_material(FOOD_COLOR.lightened(0.04 * float(index)))
		bundle.mesh = box
		bundle.position = Vector3(spot.x, _terrain.height_at(spot) + 0.10, spot.y)
		bundle.rotation.y = 0.4 * float(index)
		bundle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		_stage_volumes.add_child(bundle)

		var strap := MeshInstance3D.new()
		strap.name = "FoodStrap%d" % index
		var strap_box := BoxMesh.new()
		strap_box.size = Vector3(0.36, 0.05, 0.28)
		strap_box.material = _make_material(FOOD_STRAP_COLOR)
		strap.mesh = strap_box
		strap.position = bundle.position + Vector3(0.0, 0.02, 0.0)
		strap.rotation.y = bundle.rotation.y
		strap.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_stage_volumes.add_child(strap)


func _build_spawn_ring() -> void:
	var center: Vector3 = _layout.anchor(&"spawn")
	var ring := _make_ground_ring(Vector2(center.x, center.z), 0.40, 0.50, 0.02, SPAWN_RING_COLOR)
	ring.name = "SpawnRing"
	_stage_volumes.add_child(ring)


func _build_perimeter_props() -> void:
	for index in range(2):
		var spot := Vector2(-7.8, -3.0) if index == 0 else Vector2(-3.6, -8.2)
		var tree := GoldenTreeScene.instantiate() as Node3D
		if tree == null:
			continue
		tree.name = "GoldenTree%d" % index
		tree.position = Vector3(spot.x, _terrain.height_at(spot), spot.y)
		tree.scale = Vector3.ONE * 0.68
		_stage_volumes.add_child(tree)

	var boulders: Array[Vector2] = [Vector2(5.4, 1.2), Vector2(-2.2, 4.4)]
	for index in range(boulders.size()):
		var spot := boulders[index]
		var rock := MeshInstance3D.new()
		rock.name = "PerimeterRock%d" % index
		var sphere := SphereMesh.new()
		sphere.radius = 0.5
		sphere.height = 1.0
		sphere.radial_segments = 8
		sphere.rings = 5
		sphere.material = _make_material(Color("7d877d"))
		rock.mesh = sphere
		rock.scale = Vector3(0.9, 0.62, 1.05)
		rock.position = Vector3(spot.x, _terrain.height_at(spot) + 0.16, spot.y)
		rock.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		_stage_volumes.add_child(rock)

	for spot in [Vector2(-2.4, -4.5), Vector2(-3.1, -5.1), Vector2(-2.0, -3.3), Vector2(-3.6, -6.0)]:
		for index in range(4):
			var stalk := MeshInstance3D.new()
			var cylinder := CylinderMesh.new()
			cylinder.top_radius = 0.02
			cylinder.bottom_radius = 0.03
			cylinder.height = 0.45 + 0.06 * float(index % 2)
			cylinder.radial_segments = 5
			cylinder.material = _make_material(Color("6c9b66"))
			stalk.mesh = cylinder
			stalk.position = Vector3(spot.x + 0.12 * float(index) - 0.18, _terrain.height_at(spot) + 0.22, spot.y + 0.05 * float(index))
			stalk.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_stage_volumes.add_child(stalk)


func _add_static_beaver() -> void:
	var spawn: Vector3 = _layout.anchor(&"spawn")
	var toward: Vector3 = _layout.anchor(&"branch_clearing") - spawn
	var beaver := BeaverScene.instantiate() as Node3D
	if beaver == null:
		return
	beaver.name = "StaticBeaver"
	beaver.position = spawn
	beaver.rotation.y = atan2(toward.x, toward.z)
	_stage_volumes.add_child(beaver)
	var player := _find_animation_player(beaver)
	if player != null and player.has_animation(&"Idle"):
		player.get_animation(&"Idle").loop_mode = Animation.LOOP_LINEAR
		player.play(&"Idle")


func _rebuild_route_overlay() -> void:
	var points := _layout.route_points()
	var ribbon_surface := SurfaceTool.new()
	ribbon_surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half_width := ROUTE_WIDTH * 0.5
	for index in range(points.size() - 1):
		var start := Vector2(points[index].x, points[index].z)
		var finish := Vector2(points[index + 1].x, points[index + 1].z)
		var segment := finish - start
		if segment.length() < 0.001:
			continue
		var side := Vector2(-segment.y, segment.x).normalized() * half_width
		var samples := maxi(1, int(ceil(segment.length() / 0.25)))
		for sample in range(samples):
			var from_point := start.lerp(finish, float(sample) / float(samples))
			var to_point := start.lerp(finish, float(sample + 1) / float(samples))
			_append_quad(ribbon_surface, from_point + side, from_point - side, to_point - side, to_point + side, ROUTE_LIFT)
	ribbon_surface.set_material(_make_material(GUIDE_COLOR, true))
	_route_ribbon.mesh = ribbon_surface.commit()

	var marks_surface := SurfaceTool.new()
	marks_surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in range(points.size()):
		_append_disc(marks_surface, Vector2(points[index].x, points[index].z), ANCHOR_MARK_RADIUS, ANCHOR_MARK_LIFT)
	marks_surface.set_material(_make_material(GUIDE_COLOR, true))
	_route_marks.mesh = marks_surface.commit()


func _rebuild_blocked_overlay() -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var step := ValleyTerrain.GRID_STEP
	var start_x := ValleyTerrain.GRID_ORIGIN.x
	var start_z := ValleyTerrain.GRID_ORIGIN.y
	var columns := ValleyTerrain.GRID_COLUMNS
	var rows := ValleyTerrain.GRID_ROWS
	for column in range(columns):
		for row in range(rows):
			var x0 := start_x + float(column) * step
			var x1 := x0 + step
			var z0 := start_z + float(row) * step
			var z1 := z0 + step
			var center := Vector2((x0 + x1) * 0.5, (z0 + z1) * 0.5)
			if not _terrain.contains(center):
				continue
			if _terrain.slope_degrees(center) <= BLOCKED_SLOPE_DEGREES:
				continue
			_append_quad(surface, Vector2(x0, z0), Vector2(x1, z0), Vector2(x1, z1), Vector2(x0, z1), BLOCKED_LIFT)
	surface.set_material(_make_material(BLOCKED_COLOR, true))
	_blocked_cells.mesh = surface.commit()


func _set_projection(mode: StringName) -> void:
	match mode:
		&"persp":
			_projection_mode = &"persp"
			_camera.projection = Camera3D.PROJECTION_PERSPECTIVE
			_camera.fov = PERSP_FOV
			_camera.near = CAMERA_NEAR
			_camera.far = CAMERA_FAR
			_camera.position = PERSP_POSITION
			_camera.look_at(ORTHO_TARGET, Vector3.UP)
		&"lowside":
			_projection_mode = &"lowside"
			_camera.projection = Camera3D.PROJECTION_PERSPECTIVE
			_camera.fov = LOW_SIDE_FOV
			_camera.near = CAMERA_NEAR
			_camera.far = CAMERA_FAR
			_camera.position = LOW_SIDE_POSITION
			_camera.look_at(LOW_SIDE_TARGET, Vector3.UP)
		_:
			_projection_mode = &"ortho"
			_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
			_camera.size = ORTHO_SIZE
			_camera.near = CAMERA_NEAR
			_camera.far = CAMERA_FAR
			_camera.position = ORTHO_POSITION
			_camera.look_at(ORTHO_TARGET, Vector3.UP)
	_refresh_hud()
	_print_state()


func _set_ortho_size(value: float) -> void:
	_camera.size = value
	_refresh_hud()


func _set_overlays(route: bool, blocked: bool, max_water: bool) -> void:
	_route_visible = route
	_blocked_visible = blocked
	_max_water_visible = max_water
	_route_overlay.visible = route
	_blocked_overlay.visible = blocked
	_max_water_overlay.visible = max_water
	_refresh_hud()


func _projection_text() -> String:
	match _projection_mode:
		&"persp":
			return "persp fov %.1f" % _camera.fov
		&"lowside":
			return "low side fov %.1f" % _camera.fov
		_:
			return "ortho size %.1f" % _camera.size


func _overlay_text() -> String:
	var active := PackedStringArray()
	if _route_visible:
		active.append("route")
	if _blocked_visible:
		active.append("blocked")
	if _max_water_visible:
		active.append("max water")
	if active.is_empty():
		return "guides off"
	return "guides " + " ".join(active)


func _refresh_hud() -> void:
	if _hud_label == null or _camera == null:
		return
	var viewport_size := get_viewport().get_visible_rect().size
	_hud_label.text = "R1 relief · %s\n%s · %s\n%d × %d" % [
		String(_active_variant).replace("_", " "),
		_projection_text(),
		_overlay_text(),
		int(round(viewport_size.x)),
		int(round(viewport_size.y)),
	]


func _print_state() -> void:
	var overlays := _overlay_text().replace("guides ", "")
	print("RELIEF_STATE variant=%s projection=%s overlays=%s viewport=%dx%d" % [
		String(_active_variant),
		String(_projection_mode),
		overlays,
		int(round(get_viewport().get_visible_rect().size.x)),
		int(round(get_viewport().get_visible_rect().size.y)),
	])


func _run_capture() -> void:
	_capture_running = true
	var directory_error := DirAccess.make_dir_recursive_absolute(CAPTURE_DIR)
	if directory_error != OK:
		push_error("Cannot create relief capture directory: %s" % error_string(directory_error))
		get_tree().quit(1)
		return
	var fit_reports := {}
	var ok := true
	for variant: StringName in ValleyTerrain.VARIANTS:
		_apply_variant(variant)
		fit_reports[String(variant)] = _layout.fit_report()

		_set_window_size(CAPTURE_SIZE)
		await _settle_frames(5)
		_set_projection(&"ortho")
		_set_ortho_size(ORTHO_SIZE)
		_set_overlays(false, false, false)
		await _settle_frames(4)
		ok = await _save_capture("%s_ortho_960x600.png" % String(variant), CAPTURE_SIZE) and ok

		_set_projection(&"persp")
		await _settle_frames(4)
		ok = await _save_capture("%s_persp_960x600.png" % String(variant), CAPTURE_SIZE) and ok

		_set_projection(&"ortho")
		_set_ortho_size(ORTHO_SIZE)
		_set_overlays(true, true, true)
		await _settle_frames(4)
		ok = await _save_capture("%s_overlays_960x600.png" % String(variant), CAPTURE_SIZE) and ok

		_set_overlays(false, false, false)
		_set_ortho_size(PORTRAIT_SIZE)
		_set_window_size(CAPTURE_PORTRAIT)
		await _settle_frames(6)
		ok = await _save_capture("%s_ortho_540x960.png" % String(variant), CAPTURE_PORTRAIT) and ok

	_apply_variant(&"gentle")
	_set_window_size(CAPTURE_SIZE)
	_set_ortho_size(ORTHO_SIZE)
	await _settle_frames(5)
	_set_projection(&"lowside")
	await _settle_frames(4)
	ok = await _save_capture("gentle_lowside_960x600.png", CAPTURE_SIZE) and ok

	ok = _write_fit_report(fit_reports) and ok
	_set_projection(&"ortho")
	_set_window_size(CAPTURE_SIZE)
	await _settle_frames(2)
	if not ok:
		push_error("Relief capture failed; see the messages above.")
		get_tree().quit(1)
		return
	print("CASTOR_RELIEF_CAPTURE_OK")
	get_tree().quit(0)


func _set_window_size(size: Vector2i) -> void:
	DisplayServer.window_set_size(size)


func _settle_frames(count: int) -> void:
	for _index in range(count):
		await get_tree().process_frame


func _save_capture(file_name: String, expected: Vector2i) -> bool:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	if image.is_empty():
		push_error("Relief capture is empty: %s" % file_name)
		return false
	if image.get_width() != expected.x or image.get_height() != expected.y:
		push_error("Relief capture size mismatch for %s: got %dx%d, expected %dx%d" % [
			file_name,
			image.get_width(),
			image.get_height(),
			expected.x,
			expected.y,
		])
		return false
	var path := CAPTURE_DIR + "/" + file_name
	var error := image.save_png(path)
	if error != OK:
		push_error("Cannot save relief capture %s: %s" % [file_name, error_string(error)])
		return false
	print("RELIEF_CAPTURE %s %dx%d %s" % [
		file_name,
		image.get_width(),
		image.get_height(),
		ProjectSettings.globalize_path(path),
	])
	return true


func _write_fit_report(reports: Dictionary) -> bool:
	var safe := {}
	for variant_key: Variant in reports.keys():
		var report: Dictionary = reports[variant_key]
		safe[String(variant_key)] = _json_safe(report)
	var path := CAPTURE_DIR + "/fit_report.json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Cannot write fit report: %s" % error_string(FileAccess.get_open_error()))
		return false
	file.store_string(JSON.stringify(safe, "\t"))
	file.close()
	print("RELIEF_CAPTURE fit_report.json %s" % ProjectSettings.globalize_path(path))
	return true


func _json_safe(value: Variant) -> Variant:
	if value is Vector2:
		var vector: Vector2 = value
		return [vector.x, vector.y]
	if value is Vector3:
		var vector3: Vector3 = value
		return [vector3.x, vector3.y, vector3.z]
	if value is PackedStringArray:
		var strings: PackedStringArray = value
		var list: Array = []
		for entry in strings:
			list.append(entry)
		return list
	if value is Dictionary:
		var dictionary: Dictionary = value
		var result := {}
		for key: Variant in dictionary.keys():
			result[String(key)] = _json_safe(dictionary[key])
		return result
	if value is Array:
		var array: Array = value
		var items: Array = []
		for item: Variant in array:
			items.append(_json_safe(item))
		return items
	return value


func _make_material(tint: Color, unshaded: bool = false, roughness: float = 0.95) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.roughness = roughness
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	if unshaded:
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if tint.a < 0.999:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material


func _make_ground_disc(center_xz: Vector2, radius: float, lift: float, tint: Color) -> MeshInstance3D:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	_append_disc(surface, center_xz, radius, lift)
	surface.set_material(_make_material(tint, true))
	var instance := MeshInstance3D.new()
	instance.mesh = surface.commit()
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return instance


func _make_ground_ring(center_xz: Vector2, inner_radius: float, outer_radius: float, lift: float, tint: Color) -> MeshInstance3D:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	_append_ring(surface, center_xz, inner_radius, outer_radius, lift)
	surface.set_material(_make_material(tint, true))
	var instance := MeshInstance3D.new()
	instance.mesh = surface.commit()
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return instance


func _make_log_between(from_xz: Vector2, to_xz: Vector2, radius: float, tint: Color) -> MeshInstance3D:
	var from := Vector3(from_xz.x, _terrain.height_at(from_xz) + radius * 0.75, from_xz.y)
	var to := Vector3(to_xz.x, _terrain.height_at(to_xz) + radius * 0.75, to_xz.y)
	var log_length := from.distance_to(to)
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius * 0.86
	cylinder.bottom_radius = radius
	cylinder.height = log_length
	cylinder.radial_segments = 10
	cylinder.material = _make_material(tint)
	var instance := MeshInstance3D.new()
	instance.mesh = cylinder
	instance.position = (from + to) * 0.5
	instance.quaternion = Quaternion(Vector3.UP, (to - from).normalized())
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return instance


func _add_short_log(node_name: String, from_xz: Vector2, to_xz: Vector2) -> void:
	var log_instance := _make_log_between(from_xz, to_xz, 0.055, LOG_COLOR)
	log_instance.name = node_name
	_stage_volumes.add_child(log_instance)


func _append_disc(surface: SurfaceTool, center_xz: Vector2, radius: float, lift: float) -> void:
	var segments := 32
	var rings := 4
	for ring in range(rings):
		var inner_radius := radius * float(ring) / float(rings)
		var outer_radius := radius * float(ring + 1) / float(rings)
		for segment in range(segments):
			var angle_0 := TAU * float(segment) / float(segments)
			var angle_1 := TAU * float(segment + 1) / float(segments)
			var inner_0 := center_xz + Vector2(cos(angle_0), sin(angle_0)) * inner_radius
			var inner_1 := center_xz + Vector2(cos(angle_1), sin(angle_1)) * inner_radius
			var outer_0 := center_xz + Vector2(cos(angle_0), sin(angle_0)) * outer_radius
			var outer_1 := center_xz + Vector2(cos(angle_1), sin(angle_1)) * outer_radius
			_append_quad(surface, inner_0, outer_0, outer_1, inner_1, lift)


func _append_ring(surface: SurfaceTool, center_xz: Vector2, inner_radius: float, outer_radius: float, lift: float) -> void:
	var segments := 48
	for segment in range(segments):
		var angle_0 := TAU * float(segment) / float(segments)
		var angle_1 := TAU * float(segment + 1) / float(segments)
		var inner_0 := center_xz + Vector2(cos(angle_0), sin(angle_0)) * inner_radius
		var inner_1 := center_xz + Vector2(cos(angle_1), sin(angle_1)) * inner_radius
		var outer_0 := center_xz + Vector2(cos(angle_0), sin(angle_0)) * outer_radius
		var outer_1 := center_xz + Vector2(cos(angle_1), sin(angle_1)) * outer_radius
		_append_quad(surface, inner_0, outer_0, outer_1, inner_1, lift)


func _append_quad(surface: SurfaceTool, a: Vector2, b: Vector2, c: Vector2, d: Vector2, lift: float) -> void:
	_append_ground_vertex(surface, a, lift)
	_append_ground_vertex(surface, b, lift)
	_append_ground_vertex(surface, c, lift)
	_append_ground_vertex(surface, a, lift)
	_append_ground_vertex(surface, c, lift)
	_append_ground_vertex(surface, d, lift)


func _append_ground_vertex(surface: SurfaceTool, xz: Vector2, lift: float) -> void:
	surface.set_normal(Vector3.UP)
	surface.add_vertex(Vector3(xz.x, _terrain.height_at(xz) + lift, xz.y))


func _clear_children(node: Node) -> void:
	for child: Node in node.get_children():
		child.free()


func _find_animation_player(root: Node) -> AnimationPlayer:
	if root is AnimationPlayer:
		return root as AnimationPlayer
	for child: Node in root.get_children():
		var found := _find_animation_player(child)
		if found != null:
			return found
	return null
