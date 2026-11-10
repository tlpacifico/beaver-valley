extends SceneTree
## Verifies that terrain collision is the same surface as the visible mesh.

const TerrainScript = preload("res://scripts/valley_terrain.gd")
const LayoutScript = preload("res://scripts/valley_layout.gd")
var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _expect(condition: bool, description: String) -> void:
	if not condition:
		failures += 1
		push_error(description)


func _run() -> void:
	var terrain = TerrainScript.new()
	terrain.configure(&"wide_bank")
	var body: StaticBody3D = terrain.build_collision_body()
	root.add_child(body)
	await physics_frame
	await physics_frame

	var layout = LayoutScript.new()
	layout.configure(terrain)
	var samples: Array[Vector2] = [
		layout.anchor_xz(&"spawn"),
		layout.anchor_xz(&"branch_clearing"),
		layout.anchor_xz(&"dam_approach"),
		layout.anchor_xz(&"lodge"),
		layout.anchor_xz(&"food_bank"),
		Vector2(0.13, 0.37),
		Vector2(-2.62, 2.11),
		Vector2(3.38, -1.47),
		Vector2(5.0, 4.0),
		Vector2(-1.0, 0.0),
	]
	for sample in samples:
		_check_ray(terrain, sample)

	# Triangle boundaries and a steep channel interior must also agree.
	_check_ray(terrain, Vector2(-3.0, -2.0))
	_check_ray(terrain, Vector2(-4.2, 0.0))
	_check_ray(terrain, Vector2(terrain.river_center_x(1.0), 1.0))

	var mesh := terrain.terrain_mesh()
	_expect(mesh.get_surface_count() > 0, "Collision source mesh is empty.")
	_expect(body.collision_layer == 1, "Terrain collision must use layer 1.")
	_expect(body.get_child_count() == 1 and body.get_child(0) is CollisionShape3D, "Terrain collision shape is missing.")
	if failures == 0:
		print("CASTOR_VALLEY_COLLISION_OK surface_rays triangle_boundaries channel")
	quit(0 if failures == 0 else 1)


func _check_ray(terrain, xz: Vector2) -> void:
	var expected: float = terrain.height_at(xz)
	var query := PhysicsRayQueryParameters3D.create(Vector3(xz.x, 20.0, xz.y), Vector3(xz.x, -10.0, xz.y), 1)
	var hit := root.world_3d.direct_space_state.intersect_ray(query)
	_expect(not hit.is_empty(), "No terrain collision at %s." % xz)
	if hit.is_empty():
		return
	var difference: float = absf(hit.position.y - expected)
	_expect(difference <= 0.02, "Collision at %s differs from the surface by %.4f m." % [xz, difference])
