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
var _cache_approach_position: Vector3 = Vector3(-1.25, 0.0, -3.65)
var _cache_bed_y: float = -0.45
var _bundle_cues: Array[MeshInstance3D] = []
var _target_ring: Node3D
var _target_area: Area3D
var _cache_marker: Node3D
var _cache_basket: Node3D
var _completion_sparkles: Array[MeshInstance3D] = []


func configure(terrain: ValleyTerrain, layout: ValleyLayout) -> void:
	_cache_approach_position = Vector3(
		layout.food_cache_approach_xz().x,
		terrain.height_at(layout.food_cache_approach_xz()),
		layout.food_cache_approach_xz().y
	)
	var cache_xz := layout.food_cache_xz()
	_cache_bed_y = terrain.height_at(cache_xz)
	# The food stage starts after the dam, so the cache belongs to the full lake
	# surface. Keep every bundle centre below the water and above the lake bed.
	water_surface_y = terrain.full_water_level()
	target_position = Vector3(cache_xz.x, _cache_target_y(water_surface_y), cache_xz.y)
	var spots: Array[Vector2] = [Vector2(1.2, -4.1), Vector2(2.4, -4.7), Vector2(3.6, -4.1), Vector2(4.4, -4.8), Vector2(3.0, -3.5)]
	bundle_origins.clear()
	for spot in spots:
		bundle_origins.append(Vector3(spot.x, terrain.height_at(spot) + 0.05, spot.y))


func set_water_level(level: float) -> void:
	var previous := water_surface_y
	water_surface_y = level
	target_position.y = _cache_target_y(level)
	if _target_ring != null:
		_target_ring.position.y = level + 0.12
	if _cache_marker != null:
		_cache_marker.position.y = level
	if _cache_basket != null:
		_cache_basket.position.y = target_position.y
	if _target_area != null and _target_area.get_child_count() > 0:
		var shape := _target_area.get_child(0) as CollisionShape3D
		if shape != null:
			shape.position = target_position
	var shift := water_surface_y - previous
	if not is_zero_approx(shift):
		for bundle in placed_bundles:
			bundle.position.y += shift


## Centre of the cache: below the surface, above the bed and deep enough that
## the bundle centres stay submerged.
func _cache_target_y(level: float) -> float:
	return minf(maxf(level - 0.24, _cache_bed_y + 0.10), level - 0.06)


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
	if _cache_marker != null:
		_cache_marker.visible = true
	if _cache_basket != null:
		_cache_basket.visible = true
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
	bundle.carry(_actor, _actor.carry_offset)
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
	var basis := Basis(Vector3.UP, float(index) * 0.7).scaled(Vector3.ONE * 0.95)
	# Keep every bundle centre below the surface; the clear-water window and the
	# surface marker keep the submerged reserve readable.
	return Transform3D(basis, target_position + Vector3(offset_x, 0.02 + float(index) * 0.025, 0.0))


func _approach_path(target: Vector3) -> PackedVector3Array:
	if _navigation == null or _actor == null:
		return PackedVector3Array()
	return _navigation.find_approach(_actor.global_position, Vector2(target.x, target.z), 9)


func _approach_lodge_path() -> PackedVector3Array:
	if _navigation == null or _actor == null:
		return PackedVector3Array()
	return _navigation.find_approach(_actor.global_position, Vector2(_cache_approach_position.x, _cache_approach_position.z), 3)


func _update_cues() -> void:
	if not is_active:
		return
	var complete := is_complete()
	var carrying_suitable := carried_bundle != null and is_bundle_suitable(carried_bundle)
	# Quiet closed pickup rings; the storage position is a broken outline.
	for index in range(bundles.size()):
		var bundle := bundles[index]
		var selectable := not complete and (bundle.state == FoodBundle.State.FREE or bundle.state == FoodBundle.State.RESERVED)
		bundle.hit_area.collision_layer = BUNDLE_LAYER if selectable else 0
		var cue := _bundle_cues[index]
		cue.visible = selectable
		if bundle == pending_bundle:
			cue.scale = Vector3.ONE * 1.18
			(cue.mesh as TorusMesh).material.albedo_color = Color("ffca45")
		else:
			cue.scale = Vector3.ONE
			var highlight := help_highlight_active and is_bundle_suitable(bundle)
			if highlight:
				(cue.mesh as TorusMesh).material.albedo_color = Color("70e6a1")
			elif carrying_suitable:
				(cue.mesh as TorusMesh).material.albedo_color = Color("b8b18a")
			else:
				(cue.mesh as TorusMesh).material.albedo_color = Color("e4d9a0")
	if _target_ring != null:
		_target_ring.visible = not complete
		var destination_emphasis := placement_help_active or carrying_suitable
		_target_ring.scale = Vector3.ONE * (1.08 if destination_emphasis else 1.0)
		_set_destination_cue_color(_target_ring, Color("70e6a1") if destination_emphasis else Color("ffe17d"))
	if _target_area != null:
		_target_area.collision_layer = TARGET_LAYER if not complete else 0


func _build_target() -> void:
	_target_ring = _add_destination_outline(Vector3(target_position.x, water_surface_y + 0.12, target_position.z), 1.0, Color("ffe17d"))
	_target_ring.name = "FoodTargetCue"
	_target_ring.visible = false
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
	_build_cache_structures()


## A ring of sticks at the surface and a shallow woven basket below make the
## submerged reserve readable without depending on the progress counter.
func _build_cache_structures() -> void:
	_cache_marker = Node3D.new()
	_cache_marker.name = "FoodCacheMarker"
	_cache_marker.position = Vector3(target_position.x, water_surface_y, target_position.z)
	_cache_marker.visible = false
	add_child(_cache_marker)
	for index in range(7):
		var angle := TAU * float(index) / 7.0
		var stick := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.018
		mesh.bottom_radius = 0.032
		mesh.height = 0.42
		mesh.radial_segments = 5
		mesh.material = Shapes.material(Color("9a6a3f") if index % 2 == 0 else Color("7f8f52"))
		stick.mesh = mesh
		stick.position = Vector3(cos(angle) * 0.82, 0.16, sin(angle) * 0.62)
		stick.rotation = Vector3(0.14 * sin(angle), -angle, 0.10 * cos(angle))
		stick.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_cache_marker.add_child(stick)
	var leaf := MeshInstance3D.new()
	var leaf_mesh := SphereMesh.new()
	leaf_mesh.radius = 0.16
	leaf_mesh.height = 0.10
	leaf_mesh.radial_segments = 7
	leaf_mesh.rings = 3
	leaf_mesh.material = Shapes.material(Color("7fae63"))
	leaf.mesh = leaf_mesh
	leaf.position = Vector3(0.0, 0.05, 0.0)
	leaf.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_cache_marker.add_child(leaf)

	_cache_basket = Node3D.new()
	_cache_basket.name = "FoodCacheBasket"
	_cache_basket.position = target_position
	_cache_basket.visible = false
	add_child(_cache_basket)
	for index in range(5):
		var angle := TAU * float(index) / 5.0
		var basket_stick := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.025
		mesh.bottom_radius = 0.04
		mesh.height = 0.46
		mesh.radial_segments = 5
		mesh.material = Shapes.material(Color("8a5a35"))
		basket_stick.mesh = mesh
		basket_stick.position = Vector3(cos(angle) * 0.52, 0.0, sin(angle) * 0.4)
		basket_stick.rotation = Vector3(0.62, -angle, 0.0)
		basket_stick.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_cache_basket.add_child(basket_stick)


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
	ring.inner_radius = radius * 0.82
	ring.outer_radius = radius
	ring.material = Shapes.material(color)
	cue.mesh = ring
	cue.position = at + Vector3.UP * 0.035
	cue.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(cue)
	return cue


## Destination cue: a broken outline instead of a closed ring, so the pickup
## and placement verbs are distinguishable by shape as well as colour.
func _add_destination_outline(at: Vector3, radius: float, color: Color) -> Node3D:
	var cue := Node3D.new()
	cue.position = at
	for index in range(8):
		var angle := TAU * float(index) / 8.0
		var segment := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(radius * 0.48, 0.035, maxf(radius * 0.10, 0.04))
		mesh.material = Shapes.material(color)
		segment.mesh = mesh
		segment.position = Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
		segment.rotation.y = -angle - PI * 0.5
		segment.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		cue.add_child(segment)
	add_child(cue)
	return cue


func _set_destination_cue_color(cue: Node3D, color: Color) -> void:
	for child in cue.get_children():
		var segment := child as MeshInstance3D
		if segment == null:
			continue
		var mesh := segment.mesh as BoxMesh
		if mesh != null and mesh.material is StandardMaterial3D:
			(mesh.material as StandardMaterial3D).albedo_color = color


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
