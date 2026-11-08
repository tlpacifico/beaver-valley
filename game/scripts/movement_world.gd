extends Node3D
## Flat placeholder valley. The grid guides the path; physics bodies prevent passing through.

const Shapes = preload("res://scripts/prototype_shapes.gd")
const Actor = preload("res://scripts/prototype_actor.gd")
const ASSET_TEST_FLAG: String = "user://open-asset-test"
var actor: CharacterBody3D
var camera: Camera3D
var navigation := AStarGrid2D.new()
var destination: MeshInstance3D
var status: Label
var click_pending: bool = false
var click_position := Vector2.ZERO


func _ready() -> void:
	# Exported executables do not accept a scene path; this option opens the asset test.
	# On Android the activity ignores external arguments: debug builds use the marker
	# file instead (created and removed via ADB, see docs/castor/how-to-run.md).
	var flag_file := OS.is_debug_build() and FileAccess.file_exists(ASSET_TEST_FLAG)
	if "--asset-test" in OS.get_cmdline_user_args() or flag_file:
		get_tree().change_scene_to_file.call_deferred("res://scenes/asset_import_test.tscn")
		return
	navigation.region = Rect2i(-6, -5, 13, 11)
	navigation.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	navigation.update()
	for z in range(-2, 3):
		navigation.set_point_solid(Vector2i(0, z))
	var ground := Shapes.solid_box(Vector3(13, 0.4, 11), Color("69967b"))
	ground.position.y = -0.2
	add_child(ground)
	# Flat, non-colliding markers keep the existing walkable prototype intact.
	var water := Shapes.box(Vector3(13, 0.03, 2.0), Color("579fbd"))
	water.position = Vector3(0, 0.015, -4.5)
	add_child(water)
	var bank := Shapes.box(Vector3(13, 0.035, 0.35), Color("c6aa75"))
	bank.position = Vector3(0, 0.018, -3.35)
	add_child(bank)
	var building_target := Shapes.box(Vector3(2.0, 0.04, 0.65), Color("e8c66a"))
	building_target.position = Vector3(2.5, 0.025, -4.4)
	add_child(building_target)
	var rock := Shapes.solid_box(Vector3(0.8, 0.85, 4.8), Color("84949b"))
	rock.position.y = 0.425
	add_child(rock)
	for side in [-1.0, 1.0]:
		var wall_x := Shapes.solid_box(Vector3(0.3, 0.5, 11.6), Color("406451"))
		wall_x.position = Vector3(side * 6.65, 0.25, 0)
		add_child(wall_x)
		var wall_z := Shapes.solid_box(Vector3(13, 0.5, 0.3), Color("406451"))
		wall_z.position = Vector3(0, 0.25, side * 5.65)
		add_child(wall_z)
	actor = Actor.new()
	actor.position = Vector3(-4, 0.05, 0)
	add_child(actor)
	destination = MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.24
	ring.outer_radius = 0.32
	ring.material = Shapes.material(Color("ffda76"))
	destination.mesh = ring
	destination.position.y = 0.04
	destination.visible = false
	add_child(destination)
	camera = Camera3D.new()
	add_child(camera)
	camera.position = Vector3(11, 14, 15)
	camera.look_at(Vector3.ZERO)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 19.0
	camera.current = true
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-60, -25, 0)
	sun.light_energy = 0.85
	sun.shadow_enabled = true
	add_child(sun)
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color("162a30")
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color("d4e4e0")
	world.environment.ambient_light_energy = 0.45
	add_child(world)
	_build_interface()
	if "--capture-movement" in OS.get_cmdline_user_args():
		_capture()


func _build_interface() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var title := Label.new()
	title.text = "CASTOR / PRIMEIROS PASSOS"
	title.position = Vector2(24, 18)
	title.add_theme_font_size_override("font_size", 24)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(title)
	status = Label.new()
	status.text = "Clica no chão para andar. O castor contorna a rocha."
	status.position = Vector2(24, 54)
	status.add_theme_font_size_override("font_size", 17)
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(status)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		click_position = event.position
		click_pending = true
	elif event is InputEventScreenTouch and event.pressed:
		click_position = event.position
		click_pending = true


func _physics_process(_delta: float) -> void:
	if click_pending:
		click_pending = false
		_move_from_screen(click_position)


func _move_from_screen(screen_position: Vector2) -> bool:
	var origin := camera.project_ray_origin(screen_position)
	var end := origin + camera.project_ray_normal(screen_position) * 100.0
	var query := PhysicsRayQueryParameters3D.create(origin, end, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or hit.position.y > 0.1:
		status.text = "Escolhe um sítio livre no chão."
		return false
	return request_move(hit.position)


func request_move(world_position: Vector3) -> bool:
	if not world_position.is_finite():
		return false
	var target := Vector2i(roundi(world_position.x), roundi(world_position.z))
	if not navigation.is_in_boundsv(target) or navigation.is_point_solid(target):
		status.text = "Escolhe um sítio livre no chão."
		return false
	var start := Vector2i(roundi(actor.position.x), roundi(actor.position.z))
	var path := navigation.get_id_path(start, target)
	if path.is_empty():
		return false
	var points := PackedVector3Array()
	# Returning to the current cell center avoids cutting through the rock when the target changes.
	for cell in path:
		points.append(Vector3(cell.x, 0, cell.y))
	actor.follow_path(points)
	destination.position = Vector3(target.x, 0.04, target.y)
	destination.visible = true
	status.text = "O círculo amarelo mostra o destino. Podes escolher outro."
	return true


func _capture() -> void:
	await get_tree().create_timer(0.5).timeout
	var initial_position := actor.position
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = camera.unproject_position(Vector3(4, 0, 0))
	Input.parse_input_event(click)
	await get_tree().create_timer(0.8).timeout
	if not destination.visible or actor.position.distance_to(initial_position) < 0.5:
		push_error("Click did not start movement in the graphical run.")
		get_tree().quit(1)
		return
	await RenderingServer.frame_post_draw
	var error := get_viewport().get_texture().get_image().save_png("user://movement.png")
	if error == OK:
		print("CASTOR_GRAPHICS_OK mouse_movement_capture")
	get_tree().quit(0 if error == OK else 1)
