extends CharacterBody3D

const Shapes = preload("res://scripts/prototype_shapes.gd")
const SPEED: float = 2.8
var waypoints: PackedVector3Array = []
var visual: Node3D


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	var collision := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.26
	shape.height = 0.9
	collision.shape = shape
	collision.position.y = 0.45
	add_child(collision)
	visual = Node3D.new()
	add_child(visual)
	_add_ellipsoid(Vector3(0.0, 0.52, 0.08), Vector3(0.39, 0.42, 0.62), Color("a9632d"))
	_add_ellipsoid(Vector3(0.0, 0.75, -0.52), Vector3(0.32, 0.3, 0.34), Color("c98236"))
	_add_ellipsoid(Vector3(0.0, 0.61, -0.81), Vector3(0.25, 0.17, 0.31), Color("e0ad76"))
	# Broad, flattened paddle makes the beaver silhouette recognizable from the game camera.
	_add_ellipsoid(Vector3(0.0, 0.16, 0.78), Vector3(0.34, 0.09, 0.48), Color("49372f"))
	_add_ellipsoid(Vector3(0.0, 0.19, 0.58), Vector3(0.19, 0.11, 0.22), Color("765038"))
	for side in [-1.0, 1.0]:
		_add_ellipsoid(Vector3(side * 0.23, 1.0, -0.55), Vector3(0.13, 0.14, 0.13), Color("765038"))
		_add_ellipsoid(Vector3(side * 0.19, 0.82, -0.78), Vector3(0.045, 0.055, 0.04), Color("282522"))
		var tooth := Shapes.box(Vector3(0.075, 0.12, 0.045), Color("fff0d2"))
		tooth.position = Vector3(side * 0.075, 0.47, -1.035)
		visual.add_child(tooth)
		_add_ellipsoid(Vector3(side * 0.25, 0.25, -0.04), Vector3(0.16, 0.13, 0.2), Color("8a4f2d"))
	_add_ellipsoid(Vector3(0.0, 0.68, -1.07), Vector3(0.11, 0.075, 0.09), Color("392b27"))
	# A light muzzle bridge keeps the nose and front teeth readable at the fixed camera distance.
	_add_ellipsoid(Vector3(0.0, 0.56, -0.94), Vector3(0.17, 0.12, 0.19), Color("e7bd8e"))


func follow_path(path: PackedVector3Array) -> void:
	waypoints = path


func is_arrived() -> bool:
	return waypoints.is_empty()


func _physics_process(delta: float) -> void:
	while not waypoints.is_empty():
		var offset := waypoints[0] - position
		offset.y = 0.0
		if offset.length() > 0.035:
			break
		waypoints.remove_at(0)
	velocity.x = 0.0
	velocity.z = 0.0
	if not waypoints.is_empty():
		var offset := waypoints[0] - position
		offset.y = 0.0
		var movement := offset.normalized() * minf(SPEED, offset.length() / delta)
		velocity.x = movement.x
		velocity.z = movement.z
		visual.rotation.y = atan2(-movement.x, -movement.z)
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= 18.0 * delta
	move_and_slide()


func _add_ellipsoid(center: Vector3, radii: Vector3, color: Color) -> MeshInstance3D:
	var result := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.material = Shapes.material(color)
	result.mesh = mesh
	result.position = center
	result.scale = radii * 2.0
	visual.add_child(result)
	return result
