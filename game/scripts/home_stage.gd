class_name HomeStage
extends Node3D
## Prototype home stage: three loose parts, two visible positions and the same
## tap, carry and place verbs used by the dam. The stage owns its visuals and
## durable-in-session state; the valley keeps navigation, the actor and saving.

signal status_changed(text: String)
signal voice_requested(event_id: String)
signal sound_requested(event_id: String)
signal part_placed(count: int)
signal completed

const HomePartScript = preload("res://scripts/home_part.gd")
const Shapes = preload("res://scripts/prototype_shapes.gd")

const LODGE_CENTER := Vector3(-2.0, 0.32, -4.55)
const WALL_SLOT_POSITION := Vector3(-2.0, 0.97, -3.82)
const ROOF_SLOT_POSITION := Vector3(-2.0, 1.77, -4.55)
const PART_ORIGINS: Array[Vector3] = [Vector3(-4.8, 0.18, -2.0), Vector3(-3.2, 0.18, -2.0), Vector3(-1.6, 0.18, -2.0)]
const PART_SHAPES: Array[HomePart.Shape] = [HomePart.Shape.ROUNDED_LOG, HomePart.Shape.LIGHT_PLANK, HomePart.Shape.MOSSY_LOG]
const PART_IDS: Array[String] = ["home_part_rounded", "home_part_plank", "home_part_mossy"]
const PART_LAYER: int = 16
const SLOT_LAYER: int = 32

var is_active: bool = false
var slot_count: int = 2
var placed_slot_count: int = 0
var parts: Array[HomePart] = []
var pending_part: HomePart
var carried_part: HomePart
var pending_slot: int = -1
var placement_help_active: bool = false
var help_highlight_active: bool = false
var slot_parts: Array = [null, null]

var _actor: CharacterBody3D
var _navigation: AStarGrid2D
var _part_cues: Array[MeshInstance3D] = []
var _slot_areas: Array[Area3D] = []
var _slot_ghosts: Array[MeshInstance3D] = []
var _lodge_nodes: Array[Node3D] = []
var _completion_sparkles: Array[MeshInstance3D] = []
var _window: MeshInstance3D


func _ready() -> void:
	_build_mound()
	_build_lodge_shell()
	_build_slots()
	_build_parts()
	_build_completion_sparkles()


func bind(actor: CharacterBody3D, navigation: AStarGrid2D) -> void:
	_actor = actor
	_navigation = navigation


func activate() -> void:
	if is_active:
		return
	is_active = true
	for node in _lodge_nodes:
		node.visible = true
	for part in parts:
		part.visible = true
	_update_cues()


func _physics_process(_delta: float) -> void:
	if not is_active or _actor == null or _navigation == null:
		return
	if not _actor.is_arrived():
		return
	if pending_part != null:
		_finish_pickup()
	elif pending_slot >= 0:
		_finish_placement()


func request_collect(part: HomePart) -> bool:
	if not is_active or not parts.has(part) or is_complete():
		return false
	if part.state == HomePart.State.PLACED:
		return false
	if part == carried_part:
		status_changed.emit("O castor já leva esta peça.")
		return true
	if part == pending_part:
		return true
	if pending_part != null:
		pending_part.cancel_reservation()
		pending_part = null
	pending_slot = -1
	var start := Vector2i(roundi(_actor.position.x), roundi(_actor.position.z))
	var points := _approach_path(part.position, start)
	if points.is_empty():
		status_changed.emit("Essa peça está longe demais para chegar.")
		return false
	if carried_part != null and carried_part != part:
		carried_part.return_to_origin(self)
		carried_part = null
	_actor.follow_path(points)
	part.reserve()
	pending_part = part
	help_highlight_active = false
	placement_help_active = false
	status_changed.emit("O castor vai buscar a peça.")
	_update_cues()
	return true


func request_place(slot_index: int) -> bool:
	if not is_active or slot_index < 0 or slot_index >= slot_count:
		return false
	if is_complete():
		status_changed.emit("A casa está pronta!")
		return false
	if slot_parts[slot_index] != null:
		status_changed.emit("Esta parte da casa já está cheia.")
		return false
	if carried_part == null:
		if pending_part != null:
			status_changed.emit("O castor vai buscar a peça.")
			return false
		status_changed.emit("Toca numa peça e depois na casa.")
		voice_requested.emit("help_home_collect")
		return false
	if pending_slot == slot_index:
		return true
	if pending_part != null:
		pending_part.cancel_reservation()
		pending_part = null
	var start := Vector2i(roundi(_actor.position.x), roundi(_actor.position.z))
	var points := _approach_path(get_slot_position(slot_index), start)
	if points.is_empty():
		status_changed.emit("Não consigo chegar a essa parte da casa.")
		return false
	_actor.follow_path(points)
	pending_slot = slot_index
	placement_help_active = false
	help_highlight_active = false
	status_changed.emit("O castor vai colocar a peça.")
	_update_cues()
	return true


func request_help() -> bool:
	if not is_active:
		return false
	if is_complete():
		status_changed.emit("A casa está pronta!")
		return true
	if carried_part != null:
		help_highlight_active = false
		placement_help_active = true
		status_changed.emit("Leva a peça até à casa.")
		voice_requested.emit("help_home_place")
		_update_cues()
		return true
	if pending_part != null:
		status_changed.emit("O castor vai buscar a peça.")
		voice_requested.emit("help_home_collect")
		return true
	placement_help_active = false
	help_highlight_active = true
	status_changed.emit("Escolhe uma peça para a casa.")
	voice_requested.emit("help_home_collect")
	_update_cues()
	return true


func cancel_pending() -> void:
	if pending_part != null:
		pending_part.cancel_reservation()
		pending_part = null
	pending_slot = -1
	placement_help_active = false
	_update_cues()


func return_carried() -> void:
	if carried_part == null:
		return
	carried_part.return_to_origin(self)
	carried_part = null
	_update_cues()


func is_complete() -> bool:
	return placed_slot_count == slot_count


func is_slot_occupied(slot_index: int) -> bool:
	return slot_index >= 0 and slot_index < slot_count and slot_parts[slot_index] != null


func part_at_slot(slot_index: int) -> HomePart:
	if slot_index < 0 or slot_index >= slot_count:
		return null
	return slot_parts[slot_index]


func get_slot_position(slot_index: int) -> Vector3:
	return WALL_SLOT_POSITION if slot_index == 0 else ROOF_SLOT_POSITION


func get_lodge_center() -> Vector3:
	return LODGE_CENTER


## Resolve overlapping slot colliders by the visible position the child tapped.
## The high camera looks through the roof volume toward the wall, so the closest
## ray hit is not necessarily the position drawn under the finger.
func resolve_slot_at(screen_position: Vector2, camera: Camera3D) -> int:
	var best_index := -1
	var best_distance := INF
	for index in range(slot_count):
		if slot_parts[index] != null:
			continue
		var projected := camera.unproject_position(get_slot_position(index))
		var distance := projected.distance_squared_to(screen_position)
		if distance < best_distance:
			best_distance = distance
			best_index = index
	return best_index


func get_available_part_count() -> int:
	var count := 0
	for part in parts:
		if part.state != HomePart.State.PLACED:
			count += 1
	return count


func get_free_slot_count() -> int:
	return slot_count - placed_slot_count


func restore_slots(slot_entries: Array) -> void:
	if not is_active:
		return
	for index in range(mini(slot_count, slot_entries.size())):
		var part_id := str(slot_entries[index])
		if part_id.is_empty():
			continue
		var part := _part_by_id(part_id)
		if part == null:
			continue
		part.place_at(self, _slot_transform(index, part.shape), index)
		slot_parts[index] = part
		placed_slot_count += 1
	if is_complete():
		_show_completion_silent()
	_update_cues()


func _part_by_id(part_id: String) -> HomePart:
	for part in parts:
		if part.stable_id == part_id:
			return part
	return null


func _show_completion_silent() -> void:
	if _window != null:
		_window.visible = true


func _finish_pickup() -> void:
	var part := pending_part
	pending_part = null
	if part == null:
		return
	if carried_part != null and carried_part != part:
		carried_part.return_to_origin(self)
	carried_part = part
	part.carry(_actor)
	sound_requested.emit("collect")
	voice_requested.emit("help_home_place")
	help_highlight_active = false
	placement_help_active = false
	status_changed.emit("O castor leva a peça. Escolhe onde a colocar.")
	_update_cues()


func _finish_placement() -> void:
	var slot_index := pending_slot
	pending_slot = -1
	if carried_part == null or slot_index < 0 or slot_parts[slot_index] != null:
		return
	var part := carried_part
	carried_part = null
	part.place_at(self, _slot_transform(slot_index, part.shape), slot_index)
	slot_parts[slot_index] = part
	placed_slot_count += 1
	part_placed.emit(placed_slot_count)
	sound_requested.emit("complete" if is_complete() else "place")
	if is_complete():
		status_changed.emit("A casa está pronta!")
		_show_completion()
		completed.emit()
	else:
		status_changed.emit("A peça ficou na casa!")
	_update_cues()


func _approach_path(target: Vector3, start: Vector2i) -> PackedVector3Array:
	var candidates: Array[Vector2i] = [
		Vector2i(roundi(target.x) + 1, roundi(target.z)),
		Vector2i(roundi(target.x) - 1, roundi(target.z)),
		Vector2i(roundi(target.x), roundi(target.z) + 1),
		Vector2i(roundi(target.x), roundi(target.z) - 1),
		Vector2i(roundi(target.x) + 1, roundi(target.z) + 1),
		Vector2i(roundi(target.x) - 1, roundi(target.z) - 1),
	]
	candidates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.distance_squared_to(start) < b.distance_squared_to(start)
	)
	for cell in candidates:
		if not _navigation.is_in_boundsv(cell) or _navigation.is_point_solid(cell):
			continue
		var path := _navigation.get_id_path(start, cell)
		if path.is_empty():
			continue
		var points := PackedVector3Array()
		for path_cell in path:
			points.append(Vector3(path_cell.x, 0, path_cell.y))
		return points
	return PackedVector3Array()


func _slot_transform(slot_index: int, shape: HomePart.Shape) -> Transform3D:
	if slot_index == 0:
		var wall_scale := Vector3(1.45, 1.0, 1.0)
		if shape == HomePart.Shape.LIGHT_PLANK:
			wall_scale = Vector3(1.45, 4.2, 1.0)
		return Transform3D(Basis().scaled(wall_scale), WALL_SLOT_POSITION)
	var roof_scale := Vector3(1.8, 1.2, 1.35)
	if shape == HomePart.Shape.LIGHT_PLANK:
		roof_scale = Vector3(1.8, 2.5, 3.2)
	return Transform3D(Basis().scaled(roof_scale), ROOF_SLOT_POSITION)


func _update_cues() -> void:
	if not is_active:
		return
	var complete := is_complete()
	for index in range(parts.size()):
		var part := parts[index]
		var selectable := not complete and (part.state == HomePart.State.FREE or part.state == HomePart.State.RESERVED)
		if part.hit_area != null:
			part.hit_area.collision_layer = PART_LAYER if selectable else 0
		var cue := _part_cues[index]
		cue.visible = selectable and part != carried_part
		if part == pending_part:
			cue.scale = Vector3.ONE * 1.2
			(cue.mesh as TorusMesh).material.albedo_color = Color("ffca45")
		else:
			cue.scale = Vector3.ONE
			(cue.mesh as TorusMesh).material.albedo_color = Color("70e6a1") if help_highlight_active else Color("fff0a3")
	for index in range(slot_count):
		var occupied: bool = slot_parts[index] != null
		if _slot_areas[index] != null:
			_slot_areas[index].collision_layer = SLOT_LAYER if not occupied and not complete else 0
		var ghost := _slot_ghosts[index]
		ghost.visible = not occupied and not complete
		var ghost_color := Color("70e6a1") if carried_part != null or placement_help_active else Color("ffe17d")
		ghost_color.a = 0.34
		(ghost.material_override as StandardMaterial3D).albedo_color = ghost_color


func _build_mound() -> void:
	var mound := MeshInstance3D.new()
	mound.name = "LodgeMound"
	var mound_mesh := SphereMesh.new()
	mound_mesh.radius = 0.5
	mound_mesh.height = 1.0
	mound_mesh.radial_segments = 14
	mound_mesh.rings = 8
	mound_mesh.material = Shapes.material(Color("6b4a2f"))
	mound.mesh = mound_mesh
	mound.scale = Vector3(2.8, 0.36, 2.0)
	mound.position = Vector3(LODGE_CENTER.x, 0.16, LODGE_CENTER.z)
	mound.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mound)
	_lodge_nodes.append(mound)
	var mossy_top := MeshInstance3D.new()
	var top_mesh := SphereMesh.new()
	top_mesh.radius = 0.5
	top_mesh.height = 1.0
	top_mesh.radial_segments = 12
	top_mesh.rings = 6
	top_mesh.material = Shapes.material(Color("6f7d4e"))
	mossy_top.mesh = top_mesh
	mossy_top.scale = Vector3(2.3, 0.22, 1.6)
	mossy_top.position = Vector3(LODGE_CENTER.x, 0.28, LODGE_CENTER.z)
	mossy_top.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mossy_top)
	_lodge_nodes.append(mossy_top)
	# Loose sticks around the waterline read as a lodge mound rather than a floating box.
	for index in range(7):
		var angle := TAU * float(index) / 7.0
		var stick := MeshInstance3D.new()
		var stick_mesh := CylinderMesh.new()
		stick_mesh.top_radius = 0.045
		stick_mesh.bottom_radius = 0.06
		stick_mesh.height = 0.7
		stick_mesh.radial_segments = 6
		stick_mesh.material = Shapes.material(Color("8a5a35"))
		stick.mesh = stick_mesh
		stick.position = Vector3(LODGE_CENTER.x + cos(angle) * 1.1, 0.11, LODGE_CENTER.z + sin(angle) * 0.8)
		stick.rotation = Vector3(0.0, -angle, PI * 0.5)
		stick.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(stick)
		_lodge_nodes.append(stick)


func _build_lodge_shell() -> void:
	var floor_part := _shell_box(Vector3(2.2, 0.12, 1.8), LODGE_CENTER + Vector3(0.0, 0.06, 0.0), Color("5b4632"))
	_lodge_nodes.append(floor_part)
	var back_wall := _shell_box(Vector3(2.2, 1.4, 0.16), LODGE_CENTER + Vector3(0.0, 0.7, -0.82), Color("6b5138"))
	_lodge_nodes.append(back_wall)
	for side_x in [-1.06, 1.06]:
		var side_wall := _shell_box(Vector3(0.16, 1.4, 1.8), LODGE_CENTER + Vector3(side_x, 0.7, 0.0), Color("5f4932"))
		_lodge_nodes.append(side_wall)
	var front_base := _shell_box(Vector3(2.2, 0.28, 0.16), LODGE_CENTER + Vector3(0.0, 0.14, 0.82), Color("4f3d2c"))
	_lodge_nodes.append(front_base)
	var door := _shell_box(Vector3(0.52, 0.7, 0.06), LODGE_CENTER + Vector3(0.0, 0.35, 0.91), Color("2f241b"))
	_lodge_nodes.append(door)
	_window = _shell_box(Vector3(0.38, 0.38, 0.06), LODGE_CENTER + Vector3(1.16, 0.85, 0.0), Color("ffd978"))
	var window_material := _window.mesh.material as StandardMaterial3D
	window_material.emission_enabled = true
	window_material.emission = Color("ffcf45")
	window_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_window.name = "LodgeWindow"
	_window.visible = false


func _shell_box(size: Vector3, at: Vector3, color: Color) -> MeshInstance3D:
	var part := Shapes.box(size, color)
	part.position = at
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(part)
	return part


func _build_slots() -> void:
	for index in range(slot_count):
		var ghost := MeshInstance3D.new()
		ghost.name = "HomeSlotGhost%d" % index
		var ghost_mesh := BoxMesh.new()
		ghost_mesh.size = Vector3(2.2, 0.72, 0.62) if index == 0 else Vector3(2.35, 0.22, 1.9)
		ghost.mesh = ghost_mesh
		ghost.material_override = _ghost_material()
		ghost.position = get_slot_position(index)
		ghost.visible = false
		ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(ghost)
		_slot_ghosts.append(ghost)
		var area := Area3D.new()
		area.name = "HomeSlotArea%d" % index
		area.collision_layer = 0
		area.collision_mask = 0
		area.set_meta("home_slot_index", index)
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(2.45, 1.0, 0.85) if index == 0 else Vector3(2.6, 0.8, 2.2)
		collision.shape = shape
		collision.position = get_slot_position(index)
		area.add_child(collision)
		add_child(area)
		_slot_areas.append(area)


func _build_parts() -> void:
	for index in range(PART_ORIGINS.size()):
		var part: HomePart = HomePartScript.new()
		part.name = "HomePart%d" % index
		part.configure_shape(PART_SHAPES[index], PART_IDS[index])
		part.position = PART_ORIGINS[index]
		add_child(part)
		parts.append(part)
		part.visible = false
		if part.hit_area != null:
			part.hit_area.collision_layer = 0
		var cue := _ground_ring(PART_ORIGINS[index], 0.7, Color("fff0a3"))
		cue.name = "HomePartCue%d" % index
		cue.visible = false
		_part_cues.append(cue)


func _ground_ring(at: Vector3, radius: float, color: Color) -> MeshInstance3D:
	var cue := MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = radius * 0.72
	ring.outer_radius = radius
	ring.material = Shapes.material(color)
	cue.mesh = ring
	cue.position = at + Vector3.UP * 0.035
	cue.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(cue)
	return cue


func _ghost_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.88, 0.49, 0.34)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


func _build_completion_sparkles() -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("fff0a3")
	material.emission_enabled = true
	material.emission = Color("ffcf45")
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for index in range(4):
		var sparkle := MeshInstance3D.new()
		sparkle.name = "HomeSparkle%d" % index
		var sphere := SphereMesh.new()
		sphere.radius = 0.13
		sphere.height = 0.26
		sphere.material = material
		sparkle.mesh = sphere
		sparkle.visible = false
		sparkle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(sparkle)
		_completion_sparkles.append(sparkle)


func _show_completion() -> void:
	if _window != null:
		_window.visible = true
	for index in range(_completion_sparkles.size()):
		var sparkle := _completion_sparkles[index]
		sparkle.position = LODGE_CENTER + Vector3((index - 1.5) * 0.4, 1.5, 0.0)
		sparkle.scale = Vector3.ONE * 0.05
		sparkle.visible = true
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(sparkle, "position:y", sparkle.position.y + 0.6, 0.55)
		tween.tween_property(sparkle, "scale", Vector3.ONE, 0.25)
		tween.tween_property(sparkle, "scale", Vector3.ZERO, 0.3).set_delay(0.55)
		tween.chain().tween_callback(sparkle.hide)
