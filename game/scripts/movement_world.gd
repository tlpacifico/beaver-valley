extends Node3D
## Flat placeholder valley. The grid guides the path; physics bodies prevent passing through.

const Shapes = preload("res://scripts/prototype_shapes.gd")
const Actor = preload("res://scripts/prototype_actor.gd")
const BranchScene = preload("res://scenes/collectible_branch.tscn")
const VoiceScript = preload("res://scripts/provisional_voice.gd")
const ASSET_TEST_FLAG: String = "user://open-asset-test"
var actor: CharacterBody3D
var camera: Camera3D
var navigation := AStarGrid2D.new()
var destination: MeshInstance3D
var status: Label
var click_pending: bool = false
var click_position := Vector2.ZERO
var branches: Array[Node3D] = []
var pending_branch: Node3D
var carried_branch: Node3D
var placement_pending: bool = false
var placed_count: int = 0
var placement_center := Vector3(2.5, 0.0, -4.4)
var water_surface: MeshInstance3D
var placement_area: Area3D
var branch_cues: Array[MeshInstance3D] = []
var placement_cue: MeshInstance3D
var completion_feedback: Label
var celebration_sparkles: Array[MeshInstance3D] = []
var adult_restart_button: Button
var title_control: Label
var title_hold_started: float = -1.0
var title_touch_active: bool = false
var restart_dialog: ConfirmationDialog
var voice: Node


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
	for branch_position in [Vector3(-4, 0, -3.5), Vector3(4, 0, 3.5), Vector3(-4, 0, 3.5)]:
		var branch: Node3D = BranchScene.instantiate()
		branch.position = branch_position
		add_child(branch)
		branches.append(branch)
		branch_cues.append(_add_ground_ring(branch_position, 0.78, Color("fff0a3")))
	# Flat, non-colliding markers keep the existing walkable prototype intact.
	water_surface = Shapes.box(Vector3(13, 0.03, 0.8), Color("579fbd"))
	water_surface.position = Vector3(0, 0.015, -5.15)
	add_child(water_surface)
	var bank := Shapes.box(Vector3(13, 0.035, 0.35), Color("c6aa75"))
	bank.position = Vector3(0, 0.018, -3.35)
	add_child(bank)
	_build_placement_target()
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
	voice = VoiceScript.new()
	voice.name = "ProvisionalVoice"
	add_child(voice)
	voice.play_event("dam_start")
	_update_branch_cues()
	if "--capture-movement" in OS.get_cmdline_user_args():
		_capture()


func _build_interface() -> void:
	var layer := CanvasLayer.new()
	layer.name = "CanvasLayer"
	add_child(layer)
	title_control = Label.new()
	title_control.text = "CASTOR / PRIMEIROS PASSOS"
	title_control.position = Vector2(24, 18)
	title_control.add_theme_font_size_override("font_size", 24)
	title_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(title_control)
	status = Label.new()
	status.text = "Clica no chão para andar. O castor contorna a rocha."
	status.position = Vector2(24, 54)
	status.add_theme_font_size_override("font_size", 17)
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(status)
	var progress := Label.new()
	progress.name = "DamProgress"
	progress.position = Vector2(24, 88)
	progress.add_theme_font_size_override("font_size", 28)
	progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(progress)
	completion_feedback = Label.new()
	completion_feedback.name = "CompletionFeedback"
	completion_feedback.text = "Fizeste uma represa!"
	completion_feedback.position = Vector2(0, 155)
	completion_feedback.size = Vector2(960, 80)
	completion_feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	completion_feedback.add_theme_font_size_override("font_size", 42)
	completion_feedback.add_theme_color_override("font_color", Color("fff0a3"))
	completion_feedback.visible = false
	completion_feedback.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(completion_feedback)
	_build_celebration_sparkles()
	adult_restart_button = Button.new()
	adult_restart_button.text = "Recomeçar (adulto)"
	adult_restart_button.position = Vector2(720, 18)
	adult_restart_button.visible = false
	adult_restart_button.pressed.connect(_confirm_restart)
	layer.add_child(adult_restart_button)
	restart_dialog = ConfirmationDialog.new()
	restart_dialog.title = "Recomeçar a experiência?"
	restart_dialog.dialog_text = "Os ramos voltam ao início."
	restart_dialog.confirmed.connect(_restart_experiment)
	layer.add_child(restart_dialog)
	_update_progress_cue()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R and event.ctrl_pressed:
		_confirm_restart()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		click_position = event.position
		click_pending = true
	elif event is InputEventScreenTouch and event.pressed:
		if event.position.y <= 48 and event.position.x <= 380:
			title_touch_active = true
			title_hold_started = Time.get_ticks_msec() / 1000.0
		else:
			click_position = event.position
			click_pending = true
	elif event is InputEventScreenTouch and not event.pressed and title_touch_active:
		title_touch_active = false
		title_hold_started = -1.0


func _physics_process(_delta: float) -> void:
	if title_touch_active and title_hold_started >= 0.0 and Time.get_ticks_msec() / 1000.0 - title_hold_started >= 1.2:
		_show_adult_restart()
	if click_pending:
		click_pending = false
		_move_from_screen(click_position)
	if pending_branch != null and actor.is_arrived():
		if carried_branch != null and carried_branch != pending_branch:
			carried_branch.return_to_origin(self)
		carried_branch = pending_branch
		carried_branch.carry(actor)
		pending_branch = null
		status.text = "O castor leva um ramo. Escolhe outro para o trocar."
		voice.play_event("help_place")
		_update_branch_cues()
	if placement_pending and actor.is_arrived():
		placement_pending = false
		if carried_branch != null and placed_count < branches.size():
			carried_branch.place(self, placement_center, placed_count)
			carried_branch = null
			placed_count += 1
			_update_water()
			if placed_count == 1:
				voice.play_event("first_placement")
			status.text = "Boa! A água está a mudar. Escolhe mais um ramo."
			_update_branch_cues()
			_update_progress_cue()
			if placed_count == branches.size():
				voice.play_event("dam_completed")
				status.text = "A represa está completa!"
				completion_feedback.visible = true
				var pulse := create_tween()
				pulse.tween_property(completion_feedback, "scale", Vector2(1.08, 1.08), 0.22).from(Vector2.ONE)
				pulse.tween_property(completion_feedback, "scale", Vector2.ONE, 0.22)
				_play_celebration()


func _move_from_screen(screen_position: Vector2) -> bool:
	var origin := camera.project_ray_origin(screen_position)
	var end := origin + camera.project_ray_normal(screen_position) * 100.0
	var query := PhysicsRayQueryParameters3D.create(origin, end, 1)
	var branch_query := PhysicsRayQueryParameters3D.create(origin, end, 4)
	branch_query.collide_with_areas = true
	var branch_hit := get_world_3d().direct_space_state.intersect_ray(branch_query)
	if not branch_hit.is_empty():
		var selected := branch_hit.collider.get_parent() as Node3D
		return request_collect(selected)
	var target_query := PhysicsRayQueryParameters3D.create(origin, end, 8)
	target_query.collide_with_areas = true
	if not get_world_3d().direct_space_state.intersect_ray(target_query).is_empty():
		return request_place()
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or hit.position.y > 0.1:
		status.text = "Escolhe um sítio livre no chão."
		return false
	return request_move(hit.position)


func request_collect(branch: Node3D) -> bool:
	if not branches.has(branch):
		return false
	placement_pending = false
	if branch == carried_branch:
		if pending_branch != null:
			_cancel_pending_collection()
			actor.follow_path(PackedVector3Array())
			destination.visible = false
			status.text = "O castor continua a levar o mesmo ramo."
			return true
		status.text = "O ramo já está com o castor."
		return true
	if branch == pending_branch:
		return true
	if pending_branch != null and pending_branch != carried_branch:
		pending_branch.cancel_reservation()
		pending_branch = null
	var start := Vector2i(roundi(actor.position.x), roundi(actor.position.z))
	var candidates: Array[Vector2i] = [
		Vector2i(roundi(branch.position.x) + 1, roundi(branch.position.z)),
		Vector2i(roundi(branch.position.x) - 1, roundi(branch.position.z)),
		Vector2i(roundi(branch.position.x), roundi(branch.position.z) + 1),
		Vector2i(roundi(branch.position.x), roundi(branch.position.z) - 1),
	]
	candidates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.distance_squared_to(start) < b.distance_squared_to(start)
	)
	for cell in candidates:
		if not navigation.is_in_boundsv(cell) or navigation.is_point_solid(cell):
			continue
		var path := navigation.get_id_path(start, cell)
		if path.is_empty():
			continue
		var points := PackedVector3Array()
		for path_cell in path:
			points.append(Vector3(path_cell.x, 0, path_cell.y))
		actor.follow_path(points)
		voice.cancel()
		branch.reserve()
		pending_branch = branch
		destination.position = Vector3(cell.x, 0.04, cell.y)
		destination.visible = true
		status.text = "O castor vai buscar o ramo."
		_update_branch_cues()
		return true
	status.text = "Esse ramo está longe demais para chegar."
	return false


func _cancel_pending_collection() -> void:
	if pending_branch == null:
		return
	pending_branch.cancel_reservation()
	pending_branch = null
	_update_branch_cues()


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
	_cancel_pending_collection()
	placement_pending = false
	voice.cancel()
	actor.follow_path(points)
	destination.position = Vector3(target.x, 0.04, target.y)
	destination.visible = true
	status.text = "O círculo amarelo mostra o destino. Podes escolher outro."
	return true


func _build_placement_target() -> void:
	var marker := Shapes.box(Vector3(3.2, 0.04, 1.35), Color("e8c66a"))
	marker.position = placement_center + Vector3(0, 0.025, 0)
	add_child(marker)
	placement_cue = _add_ground_ring(placement_center, 1.15, Color("ffe17d"))
	placement_area = Area3D.new()
	placement_area.collision_layer = 8
	placement_area.collision_mask = 0
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(3.2, 0.5, 1.35)
	collision.shape = shape
	collision.position = placement_center
	placement_area.add_child(collision)
	add_child(placement_area)


func request_place() -> bool:
	if placement_pending:
		return true
	if placed_count >= branches.size():
		status.text = "A represa está completa!"
		return false
	if carried_branch == null:
		status.text = "Toca no ramo e depois na zona amarela."
		voice.play_event("help_collect")
		return false
	var start := Vector2i(roundi(actor.position.x), roundi(actor.position.z))
	var candidates: Array[Vector2i] = [Vector2i(2, -4), Vector2i(3, -4), Vector2i(2, -3), Vector2i(3, -3)]
	candidates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.distance_squared_to(start) < b.distance_squared_to(start)
	)
	for cell in candidates:
		if navigation.is_point_solid(cell):
			continue
		var path := navigation.get_id_path(start, cell)
		if path.is_empty():
			continue
		var points := PackedVector3Array()
		for path_cell in path:
			points.append(Vector3(path_cell.x, 0, path_cell.y))
		# Keep an in-progress pickup intact unless placement has a valid route.
		_cancel_pending_collection()
		voice.cancel()
		actor.follow_path(points)
		placement_pending = true
		destination.position = Vector3(cell.x, 0.04, cell.y)
		destination.visible = true
		status.text = "O castor vai colocar o ramo."
		_update_branch_cues()
		return true
	status.text = "A zona da represa está fora do caminho."
	return false


func _update_water() -> void:
	var depths: Array[float] = [0.8, 1.2, 1.6, 2.0]
	var colors: Array[Color] = [Color("579fbd"), Color("4d9fc7"), Color("439dc9"), Color("3b97c4")]
	var water_mesh := water_surface.mesh as BoxMesh
	water_mesh.size.z = depths[mini(placed_count, 3)]
	water_surface.position.z = -5.55 + depths[mini(placed_count, 3)] * 0.5
	(water_mesh.material as StandardMaterial3D).albedo_color = colors[mini(placed_count, 3)]


func _add_ground_ring(at: Vector3, radius: float, color: Color) -> MeshInstance3D:
	var cue := MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = radius * 0.72
	ring.outer_radius = radius
	ring.material = Shapes.material(color)
	cue.mesh = ring
	cue.position = at + Vector3.UP * 0.035
	add_child(cue)
	return cue


func _update_branch_cues() -> void:
	for index in range(branches.size()):
		var cue := branch_cues[index]
		var available: bool = branches[index].state == 0 or branches[index].state == 1
		cue.visible = available
		if branches[index] == pending_branch:
			cue.scale = Vector3.ONE * 1.22
			(cue.mesh as TorusMesh).material.albedo_color = Color("ffca45")
		else:
			cue.scale = Vector3.ONE
			(cue.mesh as TorusMesh).material.albedo_color = Color("fff0a3")


func _update_progress_cue() -> void:
	var progress: Label = get_node("CanvasLayer/DamProgress")
	var symbols := "●".repeat(placed_count) + "○".repeat(branches.size() - placed_count)
	progress.text = "Ramos na represa: " + symbols


func _build_celebration_sparkles() -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("fff0a3")
	material.emission_enabled = true
	material.emission = Color("ffcf45")
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for index in range(5):
		var sparkle := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.16
		sphere.height = 0.32
		sphere.material = material
		sparkle.mesh = sphere
		sparkle.visible = false
		add_child(sparkle)
		celebration_sparkles.append(sparkle)


func _play_celebration() -> void:
	for index in range(celebration_sparkles.size()):
		var sparkle := celebration_sparkles[index]
		sparkle.position = placement_center + Vector3((index - 2) * 0.48, 0.55, 0.0)
		sparkle.scale = Vector3.ONE * 0.05
		sparkle.visible = true
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(sparkle, "position:y", sparkle.position.y + 0.55, 0.55)
		tween.tween_property(sparkle, "scale", Vector3.ONE, 0.25)
		tween.tween_property(sparkle, "scale", Vector3.ZERO, 0.3).set_delay(0.55)
		tween.chain().tween_callback(sparkle.hide)


func _confirm_restart() -> void:
	restart_dialog.popup_centered()


func _show_adult_restart() -> void:
	title_touch_active = false
	adult_restart_button.visible = true


func _restart_experiment() -> void:
	get_tree().reload_current_scene()


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
