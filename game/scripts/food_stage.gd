class_name FoodStage
extends Node3D
## Prototype winter food store. The child carries suitable bundles from the bank
## into the water, where each one visibly joins the pile. Same verbs as the dam.

signal status_changed(text: String)
signal voice_requested(event_id: String)
signal sound_requested(event_id: String)
signal placed(count: int)
signal completed
signal activated

const FoodBundleScript = preload("res://scripts/food_bundle.gd")
const Shapes = preload("res://scripts/prototype_shapes.gd")

const DEFAULT_TARGET_POSITION := Vector3(-0.2, 0.06, -4.6)
const DEFAULT_BUNDLE_ORIGINS: Array[Vector3] = [Vector3(-5.2, 0.18, 0.6), Vector3(-3.8, 0.18, 0.6), Vector3(-2.4, 0.18, 0.6), Vector3(2.2, 0.18, 0.6), Vector3(3.6, 0.18, 0.6)]
const BUNDLE_KINDS: Array[FoodBundle.Kind] = [FoodBundle.Kind.SUITABLE, FoodBundle.Kind.THIN, FoodBundle.Kind.SUITABLE, FoodBundle.Kind.SUITABLE, FoodBundle.Kind.THIN]
const BUNDLE_IDS: Array[String] = ["food_bundle_01", "food_bundle_02", "food_bundle_03", "food_bundle_04", "food_bundle_05"]
const BUNDLE_LAYER: int = 64
const TARGET_LAYER: int = 128
const REQUIRED_COUNT: int = 3

var target_position: Vector3 = DEFAULT_TARGET_POSITION
var water_surface_y: float = 0.0
var bundle_origins: Array[Vector3] = DEFAULT_BUNDLE_ORIGINS.duplicate()
var is_active: bool = false
var placed_count: int = 0
var placed_bundles: Array[FoodBundle] = []
var bundles: Array[FoodBundle] = []
var pending_bundle: FoodBundle
var carried_bundle: FoodBundle
var target_pending: bool = false
var help_highlight_active: bool = false
var placement_help_active: bool = false

var _actor: CharacterBody3D
var _navigation: ValleyNavigation
var _lodge_approach_position: Vector3 = Vector3(-0.7, 0.0, -3.5)
var _bundle_cues: Array[MeshInstance3D] = []
var _target_ring: MeshInstance3D
var _target_area: Area3D
var _completion_sparkles: Array[MeshInstance3D] = []


func configure(terrain: ValleyTerrain, layout: ValleyLayout) -> void:
	var lodge_site := layout.lodge_site()
	_lodge_approach_position = layout.anchor(&"lodge")
	var target := Vector2(lodge_site.x + 0.7, lodge_site.z + 0.6)
	# Beavers cache branches under water beside the lodge; the actor still
	# approaches from the dry bank.
	target_position = Vector3(target.x, terrain.initial_water_level() - 0.08, target.y)
	water_surface_y = terrain.initial_water_level()
	var spots: Array[Vector2] = [Vector2(1.2, -4.1), Vector2(2.4, -4.7), Vector2(3.6, -4.1), Vector2(4.4, -4.8), Vector2(3.0, -3.5)]
	bundle_origins.clear()
	for spot in spots:
		bundle_origins.append(Vector3(spot.x, terrain.height_at(spot) + 0.05, spot.y))


func _ready() -> void:
	_build_target()
	_build_bundles()
	_build_completion_sparkles()


func bind(actor: CharacterBody3D, navigation: ValleyNavigation) -> void:
	_actor = actor
	_navigation = navigation


func activate() -> void:
	if is_active:
		return
	activate_silent()
	status_changed.emit("Agora vamos guardar comida para o inverno! Escolhe um feixe.")
	voice_requested.emit("food_invite")
	activated.emit()


func activate_silent() -> void:
	if is_active:
		return
	is_active = true
	for bundle in bundles:
		bundle.visible = true
	_target_ring.visible = true
	_update_cues()


func _physics_process(_delta: float) -> void:
	if not is_active or _actor == null or _navigation == null:
		return
	if not _actor.is_arrived():
		return
	if pending_bundle != null:
		_finish_pickup()
	elif target_pending:
		_finish_placement()


func request_collect(bundle: FoodBundle) -> bool:
	if not is_active or not bundles.has(bundle) or is_complete():
		return false
	if bundle.state == FoodBundle.State.PLACED:
		return false
	if bundle == carried_bundle:
		status_changed.emit("O castor já leva este feixe.")
		return true
	if bundle == pending_bundle:
		return true
	if pending_bundle != null:
		pending_bundle.cancel_reservation()
		pending_bundle = null
	target_pending = false
	var points := _approach_path(bundle.position)
	if points.is_empty():
		status_changed.emit("Esse feixe está longe demais para chegar.")
		return false
	if carried_bundle != null and carried_bundle != bundle:
		carried_bundle.return_to_origin(self)
		carried_bundle = null
	_actor.follow_path(points)
	bundle.reserve()
	pending_bundle = bundle
	help_highlight_active = false
	placement_help_active = false
	status_changed.emit("O castor vai buscar o feixe.")
	_update_cues()
	return true


func request_place() -> bool:
	if not is_active:
		return false
	if is_complete():
		status_changed.emit("A comida está guardada!")
		return false
	if carried_bundle == null:
		if pending_bundle != null:
			status_changed.emit("O castor vai buscar o feixe.")
			return false
		status_changed.emit("Toca num feixe e depois na água.")
		voice_requested.emit("help_food_collect")
		return false
	if not is_bundle_suitable(carried_bundle):
		status_changed.emit("Este feixe é pequeno. Escolhe outro.")
		voice_requested.emit("food_unsuitable")
		help_highlight_active = true
		placement_help_active = false
		_update_cues()
		return false
	if target_pending:
		return true
	if pending_bundle != null:
		pending_bundle.cancel_reservation()
		pending_bundle = null
	var points := _approach_lodge_path()
	if points.is_empty():
		status_changed.emit("Não consigo chegar à água.")
		return false
	_actor.follow_path(points)
	target_pending = true
	placement_help_active = false
	help_highlight_active = false
	status_changed.emit("O castor vai guardar o feixe.")
	_update_cues()
	return true


func request_help() -> bool:
	if not is_active:
		return false
	if is_complete():
		status_changed.emit("A comida está guardada!")
		return true
	if carried_bundle != null:
		if not is_bundle_suitable(carried_bundle):
			status_changed.emit("Este feixe é pequeno. Escolhe outro.")
			voice_requested.emit("food_unsuitable")
			help_highlight_active = true
			placement_help_active = false
		else:
			status_changed.emit("Leva o feixe até à água.")
			voice_requested.emit("help_food_place")
			help_highlight_active = false
			placement_help_active = true
		_update_cues()
		return true
	if pending_bundle != null:
		status_changed.emit("O castor vai buscar o feixe.")
		voice_requested.emit("help_food_collect")
		return true
	status_changed.emit("Escolhe um feixe de ramos para guardar.")
	voice_requested.emit("help_food_collect")
	help_highlight_active = true
	placement_help_active = false
	_update_cues()
	return true


func cancel_pending() -> void:
	if pending_bundle != null:
		pending_bundle.cancel_reservation()
		pending_bundle = null
	target_pending = false
	placement_help_active = false
	_update_cues()


func return_carried() -> void:
	if carried_bundle == null:
		return
	carried_bundle.return_to_origin(self)
	carried_bundle = null
	_update_cues()


func is_complete() -> bool:
	return placed_count == REQUIRED_COUNT


func is_bundle_suitable(bundle: FoodBundle) -> bool:
	return bundle != null and bundle.kind == FoodBundle.Kind.SUITABLE


func get_target_position() -> Vector3:
	return target_position


func get_suitable_count() -> int:
	var count := 0
	for bundle in bundles:
		if is_bundle_suitable(bundle):
			count += 1
	return count


func get_thin_count() -> int:
	var count := 0
	for bundle in bundles:
		if not is_bundle_suitable(bundle):
			count += 1
	return count


func get_visible_pile_count() -> int:
	var count := 0
	for bundle in bundles:
		if bundle.state == FoodBundle.State.PLACED and bundle.visible:
			count += 1
	return count


func get_placed_bundle_ids() -> Array[String]:
	var ids: Array[String] = []
	for bundle in placed_bundles:
		ids.append(bundle.stable_id)
	return ids


func restore_placements(bundle_ids: Array) -> void:
	if not is_active:
		return
	for index in range(mini(REQUIRED_COUNT, bundle_ids.size())):
		var bundle_id := str(bundle_ids[index])
		var bundle := _bundle_by_id(bundle_id)
		if bundle == null:
			continue
		bundle.place_at(self, _pile_transform(placed_count), placed_count)
		placed_bundles.append(bundle)
		placed_count += 1
	_update_cues()


func _bundle_by_id(bundle_id: String) -> FoodBundle:
	for bundle in bundles:
		if bundle.stable_id == bundle_id:
			return bundle
	return null


func _finish_pickup() -> void:
	var bundle := pending_bundle
	pending_bundle = null
	if bundle == null:
		return
	if carried_bundle != null and carried_bundle != bundle:
		carried_bundle.return_to_origin(self)
	carried_bundle = bundle
	bundle.carry(_actor)
	sound_requested.emit("collect")
	voice_requested.emit("help_food_place")
	help_highlight_active = false
	placement_help_active = false
	status_changed.emit("O castor leva o feixe. Escolhe o local na água.")
	_update_cues()


func _finish_placement() -> void:
	if not target_pending or carried_bundle == null:
		return
	if not is_bundle_suitable(carried_bundle):
		target_pending = false
		status_changed.emit("Este feixe é pequeno. Escolhe outro.")
		voice_requested.emit("food_unsuitable")
		_update_cues()
		return
	var bundle := carried_bundle
	carried_bundle = null
	target_pending = false
	bundle.place_at(self, _pile_transform(placed_count), placed_count)
	placed_count += 1
	placed_bundles.append(bundle)
	placed.emit(placed_count)
	sound_requested.emit("complete" if is_complete() else "place")
	if is_complete():
		status_changed.emit("A comida está guardada!")
		voice_requested.emit("food_complete")
		_show_completion()
		completed.emit()
	else:
		status_changed.emit("O feixe ficou guardado!")
	_update_cues()


func _pile_transform(index: int) -> Transform3D:
	var offsets := [-0.34, 0.0, 0.34]
	var offset_x: float = offsets[mini(index, offsets.size() - 1)]
	var basis := Basis(Vector3.UP, float(index) * 0.7).scaled(Vector3.ONE)
	return Transform3D(basis, target_position + Vector3(offset_x, 0.02, 0.0))


func _approach_path(target: Vector3) -> PackedVector3Array:
	if _navigation == null or _actor == null:
		return PackedVector3Array()
	return _navigation.find_approach(_actor.global_position, Vector2(target.x, target.z), 9)


func _approach_lodge_path() -> PackedVector3Array:
	if _navigation == null or _actor == null:
		return PackedVector3Array()
	return _navigation.find_approach(_actor.global_position, Vector2(_lodge_approach_position.x, _lodge_approach_position.z), 3)


func _update_cues() -> void:
	if not is_active:
		return
	var complete := is_complete()
	for index in range(bundles.size()):
		var bundle := bundles[index]
		var selectable := not complete and (bundle.state == FoodBundle.State.FREE or bundle.state == FoodBundle.State.RESERVED)
		bundle.hit_area.collision_layer = BUNDLE_LAYER if selectable else 0
		var cue := _bundle_cues[index]
		cue.visible = selectable
		if bundle == pending_bundle:
			cue.scale = Vector3.ONE * 1.2
			(cue.mesh as TorusMesh).material.albedo_color = Color("ffca45")
		else:
			cue.scale = Vector3.ONE
			var highlight := help_highlight_active and is_bundle_suitable(bundle)
			(cue.mesh as TorusMesh).material.albedo_color = Color("70e6a1") if highlight else Color("fff0a3")
	if _target_ring != null:
		_target_ring.visible = not complete
		(_target_ring.mesh as TorusMesh).material.albedo_color = Color("70e6a1") if placement_help_active or (carried_bundle != null and is_bundle_suitable(carried_bundle)) else Color("ffe17d")
	if _target_area != null:
		_target_area.collision_layer = TARGET_LAYER if not complete else 0


func _build_target() -> void:
	_target_ring = MeshInstance3D.new()
	_target_ring.name = "FoodTargetCue"
	var ring := TorusMesh.new()
	ring.inner_radius = 0.82
	ring.outer_radius = 1.1
	ring.material = Shapes.material(Color("ffe17d"))
	_target_ring.mesh = ring
	_target_ring.position = Vector3(target_position.x, water_surface_y + 0.12, target_position.z)
	_target_ring.visible = false
	_target_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_target_ring)
	_target_area = Area3D.new()
	_target_area.name = "FoodTargetArea"
	_target_area.collision_layer = 0
	_target_area.collision_mask = 0
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.2, 0.8, 1.7)
	collision.shape = shape
	collision.position = target_position
	_target_area.add_child(collision)
	add_child(_target_area)


func _build_bundles() -> void:
	for index in range(bundle_origins.size()):
		var bundle: FoodBundle = FoodBundleScript.new()
		bundle.name = "FoodBundle%d" % index
		bundle.configure_bundle(BUNDLE_KINDS[index], BUNDLE_IDS[index])
		bundle.position = bundle_origins[index]
		add_child(bundle)
		bundle.visible = false
		bundles.append(bundle)
		if bundle.hit_area != null:
			bundle.hit_area.collision_layer = 0
		var cue := _ground_ring(bundle_origins[index], 0.65, Color("fff0a3"))
		cue.name = "FoodBundleCue%d" % index
		cue.visible = false
		_bundle_cues.append(cue)


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


func _build_completion_sparkles() -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("fff0a3")
	material.emission_enabled = true
	material.emission = Color("ffcf45")
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for index in range(4):
		var sparkle := MeshInstance3D.new()
		sparkle.name = "FoodSparkle%d" % index
		var sphere := SphereMesh.new()
		sphere.radius = 0.12
		sphere.height = 0.24
		sphere.material = material
		sparkle.mesh = sphere
		sparkle.visible = false
		sparkle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(sparkle)
		_completion_sparkles.append(sparkle)


func _show_completion() -> void:
	for index in range(_completion_sparkles.size()):
		var sparkle := _completion_sparkles[index]
		sparkle.position = target_position + Vector3((index - 1.5) * 0.35, 0.5, 0.0)
		sparkle.scale = Vector3.ONE * 0.05
		sparkle.visible = true
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(sparkle, "position:y", sparkle.position.y + 0.55, 0.55)
		tween.tween_property(sparkle, "scale", Vector3.ONE, 0.25)
		tween.tween_property(sparkle, "scale", Vector3.ZERO, 0.3).set_delay(0.55)
		tween.chain().tween_callback(sparkle.hide)
