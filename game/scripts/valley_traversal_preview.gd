extends Node3D
## Isolated R2 traversal preview: the accepted visible terrain is also the
## colliding surface, and click/tap routing uses the shared 0.5 m navigation.
## It does not touch chapter stages, saves or the main scene.

const ActorScript = preload("res://scripts/prototype_actor.gd")
const NavigationScript = preload("res://scripts/valley_navigation.gd")
const CAPTURE_FLAG := "--capture-traversal"
const CAPTURE_DIR := "user://relief"

const CAMERA_POSITION := Vector3(9.5, 14.5, 13.0)
const CAMERA_TARGET := Vector3(-1.5, 0.5, -2.0)
const CAMERA_FOV := 36.0

var terrain: ValleyTerrain
var layout: ValleyLayout
var navigation: ValleyNavigation
var actor: CharacterBody3D
var camera: Camera3D
var destination: MeshInstance3D
var status: Label
var _capturing: bool = false
var _click_pending: bool = false
var _click_position := Vector2.ZERO


func _ready() -> void:
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	terrain = ValleyTerrain.new()
	terrain.configure(&"wide_bank")
	layout = ValleyLayout.new()
	layout.configure(terrain)
	navigation = NavigationScript.new()
	# This preview draws no grove visuals, so it routes on the terrain alone.
	navigation.configure(terrain)
	_build_environment()
	_build_terrain()
	_build_water()
	_build_markers()
	_build_actor()
	_build_camera()
	_build_interface()
	print("RELIEF_TRAVERSAL_READY variant=wide_bank cells=%d solid=%d" % [navigation.get_cell_count(), navigation.get_solid_cell_count()])
	if CAPTURE_FLAG in OS.get_cmdline_user_args():
		_run_capture.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if _capturing:
		return
	if event is InputEventMouseButton and event.device != InputEvent.DEVICE_ID_EMULATION and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_click_position = event.position
		_click_pending = true
	elif event is InputEventScreenTouch and event.pressed:
		_click_position = event.position
		_click_pending = true


func _physics_process(_delta: float) -> void:
	if _click_pending:
		_click_pending = false
		_move_from_screen(_click_position)


func request_move_to(world_position: Vector3) -> bool:
	if not world_position.is_finite():
		return false
	var xz := Vector2(world_position.x, world_position.z)
	if not navigation.is_walkable(xz):
		status.text = "Esse sítio é água ou declive demais."
		return false
	var path := navigation.find_path(actor.global_position, world_position)
	if path.is_empty():
		status.text = "Não há caminho até esse sítio."
		return false
	actor.follow_path(path)
	destination.position = world_position + Vector3.UP * 0.04
	destination.visible = true
	status.text = "O castor vai até ao círculo amarelo."
	return true


func _move_from_screen(screen_position: Vector2) -> void:
	var origin := camera.project_ray_origin(screen_position)
	var end := origin + camera.project_ray_normal(screen_position) * 100.0
	var query := PhysicsRayQueryParameters3D.create(origin, end, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		status.text = "Clica no chão do vale."
		return
	request_move_to(hit.position)


func _build_environment() -> void:
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("162a30")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("d4e4e0")
	environment.ambient_light_energy = 0.45
	world.environment = environment
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-60.0, -25.0, 0.0)
	sun.light_energy = 0.85
	sun.shadow_enabled = true
	add_child(sun)


func _build_terrain() -> void:
	var terrain_node := MeshInstance3D.new()
	terrain_node.name = "TerrainMesh"
	terrain_node.mesh = terrain.terrain_mesh()
	terrain_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(terrain_node)
	var collision := terrain.build_collision_body("ValleyCollision")
	add_child(collision)


func _build_water() -> void:
	var water := MeshInstance3D.new()
	water.name = "WaterMesh"
	water.mesh = terrain.water_mesh(terrain.initial_water_level())
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water)


func _build_markers() -> void:
	var spawn: Vector3 = layout.anchor(&"spawn")
	destination = MeshInstance3D.new()
	destination.name = "Destination"
	var ring := TorusMesh.new()
	ring.inner_radius = 0.26
	ring.outer_radius = 0.34
	ring.material = _material(Color("ffda76"))
	destination.mesh = ring
	destination.visible = false
	add_child(destination)
	var spawn_ring := MeshInstance3D.new()
	var spawn_torus := TorusMesh.new()
	spawn_torus.inner_radius = 0.32
	spawn_torus.outer_radius = 0.42
	spawn_torus.material = _material(Color("fff0a3"))
	spawn_ring.mesh = spawn_torus
	spawn_ring.position = spawn + Vector3.UP * 0.04
	add_child(spawn_ring)

	for spec in [
		{"position": Vector2(0.62, 1.38), "to": Vector2(1.18, 1.50), "radius": 0.055, "color": Color("8a7350")},
		{"position": Vector2(1.35, 1.82), "to": Vector2(1.90, 2.05), "radius": 0.055, "color": Color("8a7350")},
		{"position": Vector2(2.45, 1.05), "to": Vector2(2.95, 1.40), "radius": 0.055, "color": Color("8a7350")},
	]:
		_add_log(spec["position"], spec["to"], spec["radius"], spec["color"])

	var dam_span := layout.dam_span()
	if dam_span.size() == 2:
		for index in range(3):
			var cylinder := CylinderMesh.new()
			cylinder.top_radius = 0.09
			cylinder.bottom_radius = 0.11
			cylinder.height = dam_span[0].distance_to(dam_span[1]) * (1.0 - 0.04 * float(index))
			cylinder.radial_segments = 10
			cylinder.material = _material(Color("7b6a4c"))
			var log_instance := MeshInstance3D.new()
			log_instance.mesh = cylinder
			log_instance.rotation.z = PI * 0.5
			log_instance.position = Vector3(
				(dam_span[0].x + dam_span[1].x) * 0.5,
				terrain.initial_water_level() + 0.09 + 0.15 * float(index),
				terrain.dam_z() + 0.04 * float(index)
			)
			add_child(log_instance)

	var lodge: Vector3 = layout.anchor(&"lodge")
	var dome := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	sphere.radial_segments = 14
	sphere.rings = 7
	sphere.material = _material(Color("8d7f68"))
	dome.mesh = sphere
	dome.scale = Vector3(1.45, 0.62, 1.45)
	dome.position = lodge + Vector3.UP * 0.13
	add_child(dome)

	var food: Vector3 = layout.anchor(&"food_bank")
	for index in range(3):
		var box := MeshInstance3D.new()
		var cube := BoxMesh.new()
		cube.size = Vector3(0.34, 0.22, 0.26)
		cube.material = _material(Color("b09a62"))
		box.mesh = cube
		box.position = food + Vector3(0.35 * float(index) - 0.35, 0.10, 0.12 * float(index))
		add_child(box)


func _build_actor() -> void:
	actor = ActorScript.new()
	actor.name = "Actor"
	var spawn: Vector3 = layout.anchor(&"spawn")
	actor.position = spawn + Vector3.UP * 0.05
	add_child(actor)


func _build_camera() -> void:
	camera = Camera3D.new()
	camera.name = "Camera"
	camera.fov = CAMERA_FOV
	camera.near = 0.1
	camera.far = 200.0
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	add_child(camera)
	camera.position = CAMERA_POSITION
	camera.look_at(CAMERA_TARGET)
	camera.current = true


func _build_interface() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var title := Label.new()
	title.text = "R2 · TRAVESSIA DO VALE"
	title.position = Vector2(16, 10)
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_color_override("font_color", Color("d8e4da"))
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	title.add_theme_constant_override("outline_size", 3)
	layer.add_child(title)
	status = Label.new()
	status.text = "Clica no chão para andar. A água e os declives fortes são recusados."
	status.position = Vector2(16, 32)
	status.add_theme_font_size_override("font_size", 13)
	status.add_theme_color_override("font_color", Color("d8e4da"))
	status.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	status.add_theme_constant_override("outline_size", 3)
	layer.add_child(status)


func _add_log(from_xz: Vector2, to_xz: Vector2, radius: float, color: Color) -> void:
	var from := Vector3(from_xz.x, terrain.height_at(from_xz) + radius, from_xz.y)
	var to := Vector3(to_xz.x, terrain.height_at(to_xz) + radius, to_xz.y)
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius * 0.86
	cylinder.bottom_radius = radius
	cylinder.height = from.distance_to(to)
	cylinder.radial_segments = 8
	cylinder.material = _material(color)
	var instance := MeshInstance3D.new()
	instance.mesh = cylinder
	instance.position = (from + to) * 0.5
	instance.quaternion = Quaternion(Vector3.UP, (to - from).normalized())
	add_child(instance)


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	return material


func _run_capture() -> void:
	_capturing = true
	var directory_error := DirAccess.make_dir_recursive_absolute(CAPTURE_DIR)
	if directory_error != OK:
		push_error("Cannot create traversal capture directory.")
		get_tree().quit(1)
		return
	await _settle(20)
	var ok := await _save_capture("traversal_start.png")
	var targets: Array[Dictionary] = [
		{"id": &"dam_approach", "file": "traversal_dam.png"},
		{"id": &"lodge", "file": "traversal_lodge.png"},
		{"id": &"food_bank", "file": "traversal_food.png"},
		{"id": &"spawn", "file": "traversal_return.png"},
	]
	for target_spec in targets:
		var target: Vector3 = layout.anchor(target_spec["id"])
		status.text = "A caminho: %s" % target_spec["id"]
		if not request_move_to(target):
			push_error("Traversal capture could not route to %s." % target_spec["id"])
			ok = false
			continue
		if not await _wait_for_arrival(12.0):
			push_error("Traversal capture timed out going to %s." % target_spec["id"])
			ok = false
		await _settle(4)
		ok = await _save_capture(target_spec["file"]) and ok
		print("RELIEF_TRAVERSAL_AT %s actor=%s" % [target_spec["id"], actor.global_position])
	if not ok:
		push_error("Traversal capture failed.")
		get_tree().quit(1)
		return
	print("CASTOR_TRAVERSAL_CAPTURE_OK")
	get_tree().quit(0)


func _wait_for_arrival(timeout_seconds: float) -> bool:
	var deadline := Time.get_ticks_msec() + int(timeout_seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if actor.is_arrived():
			return true
		await get_tree().physics_frame
	return actor.is_arrived()


func _settle(frames: int) -> void:
	for _index in range(frames):
		await get_tree().physics_frame


func _save_capture(file_name: String) -> bool:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	if image.is_empty():
		push_error("Empty traversal capture: %s" % file_name)
		return false
	var path := CAPTURE_DIR + "/" + file_name
	var error := image.save_png(path)
	if error != OK:
		push_error("Cannot save traversal capture %s." % file_name)
		return false
	print("RELIEF_TRAVERSAL_CAPTURE %s %s" % [file_name, ProjectSettings.globalize_path(path)])
	return true
