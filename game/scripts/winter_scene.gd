class_name WinterScene
extends Node3D
## Decorative winter ending: falling snow, snow patches, a roof cap and the
## beaver family waiting by the lodge. No collision, no gameplay.

const BeaverScene = preload("res://assets/characters/beaver/Beaver.glb")
const LODGE_CENTER := Vector3(-2.0, 0.32, -4.55)
const FLAKE_COUNT: int = 48
const PATCH_COUNT: int = 22

var is_winter: bool = false

var _snow: Array[MeshInstance3D] = []
var _speeds: Array[float] = []
var _family: Node3D
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 20261109
	_build_snow()
	_build_family()
	_build_patches()
	_build_roof_cap()
	set_winter(false)


func set_winter(active: bool) -> void:
	is_winter = active
	visible = active
	set_process(active)


func get_snow_count() -> int:
	return _snow.size()


func get_family_count() -> int:
	return _family.get_child_count() if _family != null else 0


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
	for spec in [
		[Vector3(-3.55, 0.05, -3.45), 0.85],
		[Vector3(-1.0, 0.05, -3.3), 0.62],
		[Vector3(-2.45, 0.05, -2.9), 0.56],
	]:
		var beaver := BeaverScene.instantiate() as Node3D
		beaver.position = spec[0]
		beaver.scale = Vector3.ONE * float(spec[1])
		beaver.rotation.y = 0.0
		_family.add_child(beaver)
		var animation := _find_animation_player(beaver)
		if animation != null and animation.has_animation(&"Idle"):
			animation.play(&"Idle")


func _build_patches() -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("eef3ec")
	material.roughness = 0.95
	for _index in range(PATCH_COUNT):
		var x := _rng.randf_range(-5.6, 5.6)
		var z := _rng.randf_range(-2.9, 4.8)
		if absf(x) < 0.9 and z > -2.9 and z < 2.9:
			continue
		var patch := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = 0.5
		mesh.height = 1.0
		mesh.radial_segments = 9
		mesh.rings = 4
		mesh.material = material
		patch.mesh = mesh
		patch.scale = Vector3(_rng.randf_range(0.45, 0.85), 0.035, _rng.randf_range(0.3, 0.6))
		patch.position = Vector3(x, 0.03, z)
		patch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(patch)


func _build_roof_cap() -> void:
	var cap := MeshInstance3D.new()
	cap.name = "SnowRoofCap"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(2.4, 0.06, 1.9)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("f4f8ff")
	material.roughness = 0.92
	mesh.material = material
	cap.mesh = mesh
	cap.position = LODGE_CENTER + Vector3(0.0, 1.62, 0.0)
	cap.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(cap)


func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found != null:
			return found
	return null
