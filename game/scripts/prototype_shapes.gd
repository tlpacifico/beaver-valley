extends RefCounted
## Shapes shared only by the placeholder scenes.

static func material(color: Color) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = 0.85
	return result


static func box(size: Vector3, color: Color) -> MeshInstance3D:
	var result := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material(color)
	result.mesh = mesh
	return result


static func solid_box(size: Vector3, color: Color) -> StaticBody3D:
	var result := StaticBody3D.new()
	result.add_child(box(size, color))
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	result.add_child(collision)
	return result
