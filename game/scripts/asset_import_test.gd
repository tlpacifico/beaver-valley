extends Node3D
## Milestone 1 technical test: branch exported from Blender and a third-party animated
## model next to the placeholder character. No collecting or building.

const Shapes = preload("res://scripts/prototype_shapes.gd")
const Actor = preload("res://scripts/prototype_actor.gd")
const AnimatedModel = preload("res://scripts/animated_test_model.gd")
const BRANCH := preload("res://assets/props/test_branch.glb")
var actor: CharacterBody3D
var branch: Node3D
var animated: Node3D
var camera: Camera3D
var status: Label


func _ready() -> void:
	var ground := Shapes.solid_box(Vector3(9, 0.4, 7), Color("69967b"))
	ground.position.y = -0.2
	add_child(ground)
	# 1-meter grid to read the scale in screenshots.
	for i in range(-4, 5):
		var line := Shapes.box(Vector3(0.02, 0.005, 7), Color("5a8469"))
		line.position = Vector3(i, 0.003, 0)
		add_child(line)
	actor = Actor.new()
	actor.position = Vector3(-2.5, 0.05, -0.5)
	actor.set_physics_process(false)
	add_child(actor)
	branch = BRANCH.instantiate()
	branch.position = Vector3(-2.5, 0, 0.6)
	add_child(branch)
	animated = AnimatedModel.new()
	animated.position = Vector3(1, 0, 0)
	add_child(animated)
	camera = Camera3D.new()
	add_child(camera)
	camera.position = Vector3(5, 6, 7)
	camera.look_at(Vector3(-0.5, 0.3, 0))
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 6.5
	camera.current = true
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -30, 0)
	sun.light_energy = 0.9
	sun.shadow_enabled = true
	add_child(sun)
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color("162a30")
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color("d4e4e0")
	world.environment.ambient_light_energy = 0.5
	add_child(world)
	_build_interface()
	if "--capture-assets" in OS.get_cmdline_user_args():
		_capture()


func _build_interface() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var title := Label.new()
	title.text = "CASTOR / TESTE DE IMPORTAÇÃO (recursos técnicos)"
	title.position = Vector2(24, 18)
	title.add_theme_font_size_override("font_size", 22)
	layer.add_child(title)
	status = Label.new()
	status.position = Vector2(24, 52)
	status.add_theme_font_size_override("font_size", 16)
	layer.add_child(status)
	var credits := Label.new()
	credits.text = "Modelo de teste: Fox — PixelMannen (CC0), tomkranis (CC BY 4.0), @AsoboStudio e @scurest (CC BY 4.0)"
	credits.position = Vector2(24, 568)
	credits.add_theme_font_size_override("font_size", 12)
	layer.add_child(credits)


func _process(_delta: float) -> void:
	status.text = "Clica no chão para mover o modelo animado. Animação: %s" % animated.current_animation()


func _unhandled_input(event: InputEvent) -> void:
	var pressed: bool = (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed) \
		or (event is InputEventScreenTouch and event.pressed)
	if pressed:
		var hit: Variant = Plane(Vector3.UP, 0).intersects_ray(camera.project_ray_origin(event.position), camera.project_ray_normal(event.position))
		if hit != null and absf(hit.x) < 4.2 and absf(hit.z) < 3.2:
			animated.walk_to(hit)


func _save(file_name: String) -> bool:
	await RenderingServer.frame_post_draw
	return get_viewport().get_texture().get_image().save_png("user://" + file_name) == OK


func _capture() -> void:
	await get_tree().create_timer(0.8).timeout
	var ok: bool = animated.current_animation() == AnimatedModel.IDLE and not animated.is_walking()
	ok = await _save("assets-idle.png") and ok
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = camera.unproject_position(Vector3(2.5, 0, 1.5))
	Input.parse_input_event(click)
	await get_tree().create_timer(0.6).timeout
	ok = ok and animated.is_walking() and animated.current_animation() == AnimatedModel.WALK
	ok = await _save("assets-walk.png") and ok
	await get_tree().create_timer(2.5).timeout
	ok = ok and not animated.is_walking() and animated.current_animation() == AnimatedModel.IDLE
	if ok:
		print("CASTOR_GRAPHICS_OK assets_idle_walk_capture")
	else:
		push_error("Asset capture: unexpected animation state.")
	get_tree().quit(0 if ok else 1)
