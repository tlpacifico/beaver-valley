extends Node3D
## Original primitive support characters. Both remain outside gameplay selection and physics.

@export var owl_position: Vector3 = Vector3(-4.5, 1.1, -3.0)
@export var otter_position: Vector3 = Vector3(4.5, 0.0, -3.0)
@export var celebration_duration: float = 4.0
@export var hint_duration: float = 4.0

var _owl: Node3D
var _otter: Node3D
var _clock: float = 0.0
var _celebrating: bool = false
var _celebration_time: float = 0.0
var _hint_time_remaining: float = 0.0
var _hint_is_timed: bool = false


func configure(terrain: ValleyTerrain, _layout: ValleyLayout) -> void:
	owl_position = Vector3(5.0, terrain.height_at(Vector2(5.0, 1.2)) + 0.38, 1.2)
	otter_position = Vector3(-1.8, terrain.initial_water_level() + 0.05, -4.4)


func _ready() -> void:
	_owl = _build_owl()
	_owl.position = owl_position
	add_child(_owl)
	_owl.visible = false
	_otter = _build_otter()
	_otter.position = otter_position
	add_child(_otter)
	_otter.visible = false


## Show or hide the owl that marks an available hint.
func set_hint(active: bool) -> void:
	_hint_is_timed = false
	_hint_time_remaining = 0.0
	if _owl != null:
		_owl.visible = active


## Show the owl briefly; calling again renews the interval.
func show_hint() -> void:
	_hint_is_timed = true
	_hint_time_remaining = maxf(hint_duration, 0.1)
	if _owl != null:
		_owl.visible = true


## Show a short, non-interactive otter celebration when the lake forms.
func celebrate() -> void:
	if _otter == null:
		return
	_otter.visible = true
	_otter.position = otter_position
	_otter.rotation = Vector3.ZERO
	_celebrating = true
	_celebration_time = 0.0


func _process(delta: float) -> void:
	_clock += delta
	if _hint_is_timed:
		_hint_time_remaining -= delta
		if _hint_time_remaining <= 0.0:
			_hint_is_timed = false
			if _owl != null:
				_owl.visible = false
	if _owl != null and _owl.visible:
		_owl.position.y = owl_position.y + sin(_clock * 2.4) * 0.06
	if _celebrating and _otter != null:
		_celebration_time += delta
		var progress: float = minf(_celebration_time / maxf(celebration_duration, 0.1), 1.0)
		var bounce: float = absf(sin(progress * TAU * 2.0)) * 0.42
		_otter.position.y = otter_position.y + bounce
		_otter.rotation.z = sin(progress * TAU * 2.0) * 0.12
		if progress >= 1.0:
			_celebrating = false
			_otter.visible = false


func _build_owl() -> Node3D:
	var owl := Node3D.new()
	_add_sphere(owl, Vector3(0.0, 0.0, 0.0), Vector3(0.58, 0.68, 0.44), Color("8b6548"))
	_add_sphere(owl, Vector3(0.0, -0.28, 0.23), Vector3(0.40, 0.36, 0.24), Color("e6d4ad"))
	# Ear tufts give the silhouette a clear owl shape.
	_add_cone(owl, Vector3(-0.36, 0.53, 0.0), Vector3(0.2, 0.32, 0.2), Color("705039"))
	_add_cone(owl, Vector3(0.36, 0.53, 0.0), Vector3(0.2, 0.32, 0.2), Color("705039"))
	for side in [-1.0, 1.0]:
		_add_sphere(owl, Vector3(side * 0.2, 0.18, 0.38), Vector3(0.22, 0.22, 0.12), Color("f3e8ca"))
		_add_sphere(owl, Vector3(side * 0.2, 0.18, 0.49), Vector3(0.105, 0.12, 0.07), Color("27231f"))
	_add_cone(owl, Vector3(0.0, -0.02, 0.52), Vector3(0.14, 0.2, 0.14), Color("d99b42"))
	return owl


func _build_otter() -> Node3D:
	var otter := Node3D.new()
	_add_sphere(otter, Vector3(0.0, 0.43, 0.0), Vector3(0.72, 0.38, 0.36), Color("79543d"))
	_add_sphere(otter, Vector3(0.48, 0.68, 0.08), Vector3(0.36, 0.34, 0.32), Color("896044"))
	_add_sphere(otter, Vector3(0.57, 0.58, 0.31), Vector3(0.25, 0.16, 0.12), Color("e8d3b2"))
	_add_sphere(otter, Vector3(0.78, 0.62, 0.36), Vector3(0.08, 0.07, 0.06), Color("25201d"))
	_add_sphere(otter, Vector3(0.37, 0.78, 0.34), Vector3(0.055, 0.06, 0.05), Color("25201d"))
	_add_sphere(otter, Vector3(-0.68, 0.34, -0.04), Vector3(0.66, 0.16, 0.2), Color("79543d"))
	_add_sphere(otter, Vector3(0.0, 0.18, 0.12), Vector3(0.32, 0.12, 0.25), Color("e8d3b2"))
	return otter


func _add_sphere(parent: Node3D, offset: Vector3, size: Vector3, color: Color) -> void:
	var part := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	part.mesh = mesh
	part.scale = size * 2.0
	part.position = offset
	part.material_override = _material(color)
	parent.add_child(part)


func _add_cone(parent: Node3D, offset: Vector3, size: Vector3, color: Color) -> void:
	var part := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.0
	mesh.bottom_radius = 0.5
	mesh.height = 1.0
	part.mesh = mesh
	part.scale = size * 2.0
	part.position = offset
	part.material_override = _material(color)
	parent.add_child(part)


func _material(color: Color) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = 0.88
	return result
