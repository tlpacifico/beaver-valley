class_name WinterScene
extends Node3D
## Decorative winter ending: falling snow, terrain-aligned snow patches, a roof
## cap owned by the lodge and the beaver family on the dry bank. No collision,
## no gameplay.

const BeaverScene = preload("res://assets/characters/beaver/Beaver.glb")
const DEFAULT_LODGE_CENTER := Vector3(-5.5, -0.61, -4.8)
const FLAKE_COUNT: int = 48
const PATCH_COUNT: int = 30

var lodge_center: Vector3 = DEFAULT_LODGE_CENTER
var family_center: Vector3 = DEFAULT_LODGE_CENTER
var is_winter: bool = false

var _terrain: ValleyTerrain
var _layout: ValleyLayout
var _snow: Array[MeshInstance3D] = []
var _speeds: Array[float] = []
var _patches: Array[MeshInstance3D] = []
var _family: Node3D
var _dam_snow: Node3D
var _rng := RandomNumberGenerator.new()


func configure(terrain: ValleyTerrain, layout: ValleyLayout) -> void:
	_terrain = terrain
	_layout = layout
	lodge_center = layout.lodge_build_center()
	family_center = layout.anchor(&"lodge")


func _ready() -> void:
	_rng.seed = 20261109
	_build_snow()
	_build_family()
	_build_patches()
	_build_dam_snow()
	set_winter(false)


func set_winter(active: bool) -> void:
	is_winter = active
	visible = active
	if _dam_snow != null:
		_dam_snow.visible = active
	set_process(active)


func get_snow_count() -> int:
	return _snow.size()


func get_snow_patch_count() -> int:
	return _patches.size()


func get_family_count() -> int:
	return _family.get_child_count() if _family != null else 0


func get_family_positions() -> Array[Vector3]:
	var positions: Array[Vector3] = []
	if _family == null:
		return positions
	for child in _family.get_children():
		if child is Node3D:
			positions.append((child as Node3D).position)
	return positions


func _process(delta: float) -> void:
	if not visible:
		return
	for index in range(_snow.size()):
		var flake := _snow[index]
		flake.position.y -= _speeds[index] * delta
		flake.rotation.y += delta * 0.7
		if flake.position.y < 0.05:
			flake.position = Vector3(_rng.randf_range(-6.0, 6.0), _rng.randf_range(6.5, 9.0), _rng.randf_range(-5.2, 5.2))


func _build_snow() -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("f4f8ff")
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for _index in range(FLAKE_COUNT):
		var flake := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.055, 0.055, 0.055)
		mesh.material = material
		flake.mesh = mesh
		flake.position = Vector3(_rng.randf_range(-6.0, 6.0), _rng.randf_range(0.3, 8.5), _rng.randf_range(-5.2, 5.2))
		flake.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(flake)
		_snow.append(flake)
		_speeds.append(_rng.randf_range(0.65, 1.25))


func _build_family() -> void:
	_family = Node3D.new()
	_family.name = "BeaverFamily"
	add_child(_family)
	var candidates: Array[Vector2] = [
		Vector2(-1.4, 0.5),
		Vector2(1.2, 0.3),
		Vector2(0.0, -1.0),
		Vector2(-2.1, -0.3),
		Vector2(2.1, 0.0),
		Vector2(-0.8, 1.3),
	]
	var chosen: Array[Vector2] = []
	for candidate in candidates:
		if chosen.size() >= 3:
			break
		var xz := Vector2(family_center.x + candidate.x, family_center.z + candidate.y)
		if not _is_dry_ground(xz, 20.0):
			continue
		if chosen.any(func(other: Vector2) -> bool: return other.distance_to(xz) < 0.55):
			continue
		chosen.append(xz)
	while chosen.size() < 3:
		chosen.append(Vector2(family_center.x, family_center.z))
	var scales: Array[float] = [0.85, 0.62, 0.56]
	for index in range(chosen.size()):
		var xz := chosen[index]
		var beaver := BeaverScene.instantiate() as Node3D
		var ground := _terrain.height_at(xz) if _terrain != null else family_center.y
		beaver.position = Vector3(xz.x, ground + 0.05, xz.y)
		beaver.scale = Vector3.ONE * scales[index]
		beaver.rotation.y = atan2(family_center.x - xz.x, family_center.z - xz.y)
		_family.add_child(beaver)
		var animation := _find_animation_player(beaver)
		if animation != null and animation.has_animation(&"Idle"):
			animation.play(&"Idle")


func _build_patches() -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("eef3ec")
	material.roughness = 0.95
	var secondary_material := StandardMaterial3D.new()
	secondary_material.albedo_color = Color("e4ecf2")
	secondary_material.roughness = 0.95
	var attempts := PATCH_COUNT * 5
	while _patches.size() < PATCH_COUNT and attempts > 0:
		attempts -= 1
		var x := _rng.randf_range(-8.4, 5.8)
		var z := _rng.randf_range(-7.6, 5.0)
		var xz := Vector2(x, z)
		if not _is_snow_patch_spot(xz):
			continue
		# Two or three overlapping blobs make a patch read as drifted snow
		# rather than an isolated white disc.
		var satellites := 1 + _rng.randi_range(0, 1)
		for satellite in range(satellites):
			if _patches.size() >= PATCH_COUNT:
				break
			var patch_xz := xz
			var patch_scale := Vector3(0.30, 0.03, 0.20)
			if satellite > 0:
				patch_xz += Vector2(_rng.randf_range(-0.24, 0.24), _rng.randf_range(-0.20, 0.20))
				if not _is_snow_patch_spot(patch_xz):
					continue
				patch_scale *= _rng.randf_range(0.55, 0.8)
			patch_scale.x = _rng.randf_range(0.28, 0.52) if satellite == 0 else patch_scale.x
			patch_scale.z = _rng.randf_range(0.18, 0.38) if satellite == 0 else patch_scale.z
			var patch := MeshInstance3D.new()
			patch.name = "SnowPatch%d" % _patches.size()
			var mesh := SphereMesh.new()
			mesh.radius = 0.5
			mesh.height = 1.0
			mesh.radial_segments = 9
			mesh.rings = 4
			mesh.material = material if satellite == 0 else secondary_material
			patch.mesh = mesh
			patch.transform = _grounded_transform(patch_xz, patch_scale)
			patch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(patch)
			_patches.append(patch)


func _build_dam_snow() -> void:
	if _terrain == null or _layout == null:
		return
	_dam_snow = Node3D.new()
	_dam_snow.name = "DamSnow"
	add_child(_dam_snow)
	var center := _layout.dam_center()
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("f2f7fb")
	material.roughness = 0.92
	for index in range(3):
		var cap := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.34, 0.09, 0.22)
		mesh.material = material
		cap.mesh = mesh
		cap.position = Vector3(center.x + (float(index) - 1.0) * 1.35, center.y + 0.20, center.z + 0.02)
		cap.rotation.z = 0.06 * float(index % 2)
		cap.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_dam_snow.add_child(cap)
	_dam_snow.visible = false


func _is_snow_patch_spot(xz: Vector2) -> bool:
	if _terrain == null:
		return false
	if not _terrain.contains(xz):
		return false
	if not _is_dry_ground(xz, 34.0):
		return false
	if xz.distance_to(Vector2(lodge_center.x, lodge_center.z)) < 1.9:
		return false
	if _layout != null and xz.distance_to(_layout.food_cache_xz()) < 1.1:
		return false
	if absf(xz.y - _terrain.dam_z()) < 1.1 and absf(xz.x - _terrain.river_center_x(xz.y)) < 3.6:
		return false
	return true


func _is_dry_ground(xz: Vector2, max_slope: float) -> bool:
	if _terrain == null:
		return true
	if not _terrain.contains(xz):
		return false
	if _terrain.is_water_footprint(xz):
		return false
	return _terrain.slope_degrees(xz) <= max_slope


func _grounded_transform(xz: Vector2, scale: Vector3) -> Transform3D:
	var ground := _terrain.height_at(xz) if _terrain != null else 0.03
	if _terrain == null:
		return Transform3D(Basis.from_scale(scale), Vector3(xz.x, ground + 0.04, xz.y))
	var up := _terrain.normal_at(xz)
	var right := Vector3.UP.cross(up)
	if right.length_squared() < 0.0001:
		right = Vector3.RIGHT
	right = right.normalized()
	var forward := right.cross(up).normalized()
	var basis := Basis(right * scale.x, up * scale.y, forward * scale.z)
	return Transform3D(basis, Vector3(xz.x, ground + 0.035, xz.y))


func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found != null:
			return found
	return null
