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
	var body := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.3
	mesh.height = 0.9
	mesh.material = Shapes.material(Color("c98236"))
	body.mesh = mesh
	body.position.y = 0.48
	visual.add_child(body)
	var tail := Shapes.box(Vector3(0.34, 0.09, 0.5), Color("765038"))
	tail.position = Vector3(0, 0.12, 0.38)
	visual.add_child(tail)
	for side in [-1.0, 1.0]:
		var eye := Shapes.box(Vector3(0.07, 0.09, 0.06), Color("282522"))
		eye.position = Vector3(side * 0.13, 0.72, -0.26)
		visual.add_child(eye)


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
