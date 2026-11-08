extends Node3D
## Technical test: 3D cube, frame-rate-independent rotation and pause.
const ROTATION_SPEED: float = 0.8
var cube: MeshInstance3D
var rotating: bool = true
var status_label: Label


func _ready() -> void:
	var ground := _box(Vector3(7.0, 0.2, 7.0), Color("527966"))
	ground.position.y = -0.15
	add_child(ground)
	cube = _box(Vector3(1.4, 1.4, 1.4), Color("e4a653"))
	cube.position.y = 0.9
	add_child(cube)
	var camera := Camera3D.new()
	add_child(camera)
	camera.position = Vector3(5.0, 5.0, 6.0)
	camera.look_at(Vector3(0.0, 0.4, 0.0))
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 7.0
	camera.current = true
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55.0, -30.0, 0.0)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	add_child(sun)
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color("132129")
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color("d4e4e0")
	world.environment.ambient_light_energy = 0.6
	add_child(world)
	_build_interface()
	print("CASTOR_BOOTSTRAP_READY platform=", OS.get_name())
	if "--smoke-test" in OS.get_cmdline_user_args():
		_run_smoke_test()


func _box(size: Vector3, color: Color) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.85
	mesh.material = material
	instance.mesh = mesh
	return instance


func _build_interface() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var title := Label.new()
	title.text = "CASTOR / PRIMEIRO TESTE"
	title.position = Vector2(28.0, 22.0)
	title.add_theme_font_size_override("font_size", 26)
	layer.add_child(title)
	status_label = Label.new()
	status_label.text = "O cubo está a rodar."
	status_label.position = Vector2(28.0, 62.0)
	status_label.add_theme_font_size_override("font_size", 18)
	layer.add_child(status_label)
	var button := Button.new()
	button.text = "Pausar / continuar"
	button.position = Vector2(28.0, 104.0)
	button.custom_minimum_size = Vector2(240.0, 58.0)
	button.add_theme_font_size_override("font_size", 20)
	button.pressed.connect(_toggle_rotation)
	layer.add_child(button)


func _process(delta: float) -> void:
	if rotating:
		cube.rotate_y(ROTATION_SPEED * delta)


func _toggle_rotation() -> void:
	rotating = not rotating
	status_label.text = "O cubo está a rodar." if rotating else "O cubo está parado."


func _run_smoke_test() -> void:
	# Scene integration check; does not replace touch testing on the device.
	await get_tree().create_timer(0.5).timeout
	var before: float = cube.rotation.y
	await get_tree().create_timer(0.5).timeout
	if is_equal_approx(before, cube.rotation.y):
		push_error("The cube did not rotate.")
		get_tree().quit(1)
		return
	_toggle_rotation()
	before = cube.rotation.y
	await get_tree().create_timer(0.25).timeout
	if not is_equal_approx(before, cube.rotation.y):
		push_error("Pause did not stop the rotation.")
		get_tree().quit(1)
		return
	_toggle_rotation()
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var error: Error = get_viewport().get_texture().get_image().save_png("user://bootstrap.png")
		if error != OK:
			push_error("Could not save the screenshot.")
			get_tree().quit(1)
			return
	print("CASTOR_SMOKE_OK rotation_and_pause")
	get_tree().quit()
