extends SceneTree
## Smoke checks for the isolated R1 relief preview: visible-only scene, no physics,
## expected meshes and hidden guide overlays.

const PreviewScene = preload("res://scenes/valley_relief_preview.tscn")
var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _expect(condition: bool, description: String) -> void:
	if not condition:
		failures += 1
		push_error(description)


func _run() -> void:
	var preview := PreviewScene.instantiate() as Node3D
	root.add_child(preview)
	await process_frame
	await process_frame

	var terrain_mesh := preview.get_node_or_null("TerrainMesh") as MeshInstance3D
	_expect(terrain_mesh != null, "Preview must expose a TerrainMesh.")
	if terrain_mesh != null and terrain_mesh.mesh is ArrayMesh:
		var surface_count := (terrain_mesh.mesh as ArrayMesh).get_surface_count()
		_expect(surface_count > 0, "Terrain mesh has no surface.")
		var bounds := (terrain_mesh.mesh as ArrayMesh).get_aabb()
		_expect(bounds.size.x >= 13.0 and bounds.size.z >= 11.0, "Terrain mesh does not cover the playable footprint.")
		_expect(terrain_mesh.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "Terrain must cast shadows.")
		_expect(terrain_mesh.material_override is StandardMaterial3D or terrain_mesh.mesh.surface_get_material(0) is StandardMaterial3D, "Terrain needs a visible material.")

	var water_mesh := preview.get_node_or_null("WaterMesh") as MeshInstance3D
	_expect(water_mesh != null, "Preview must expose the initial WaterMesh.")
	if water_mesh != null and water_mesh.mesh is ArrayMesh:
		_expect((water_mesh.mesh as ArrayMesh).get_surface_count() > 0, "Initial water mesh is empty.")

	var skirt := preview.get_node_or_null("TerrainSkirt") as MeshInstance3D
	_expect(skirt != null, "Preview must expose the terrain boundary skirt.")
	if skirt != null and skirt.mesh is ArrayMesh:
		_expect((skirt.mesh as ArrayMesh).get_surface_count() > 0, "Terrain boundary skirt is empty.")

	for overlay_name in ["RouteOverlay", "BlockedOverlay", "MaxWaterOverlay"]:
		var overlay := preview.get_node_or_null(overlay_name) as Node3D
		_expect(overlay != null, "Missing overlay: %s" % overlay_name)
		if overlay != null:
			_expect(not overlay.visible, "%s must start hidden." % overlay_name)

	var camera := preview.get_node_or_null("PreviewCamera") as Camera3D
	_expect(camera != null, "Preview must expose PreviewCamera.")
	if camera != null:
		_expect(camera.current, "Preview camera must be current.")
		_expect(camera.projection == Camera3D.PROJECTION_PERSPECTIVE, "Preview must use the accepted perspective projection.")
		_expect(is_equal_approx(camera.fov, 36.0), "Preview field of view must be 36 degrees.")

	_expect(preview.get_node_or_null("StageVolumes") != null, "Preview must group its simple stage volumes.")
	_expect(preview.get("_active_variant") == &"wide_bank", "Preview must open on the accepted wide_bank variant.")
	_expect(preview.find_children("*", "CollisionObject3D", true, false).is_empty(), "R1 preview must not contain physics bodies or areas.")
	_expect(preview.find_children("*", "NavigationRegion3D", true, false).is_empty(), "R1 preview must not contain navigation.")

	preview.queue_free()
	if failures == 0:
		print("CASTOR_VALLEY_PREVIEW_OK meshes no_physics hidden_overlays camera")
	quit(0 if failures == 0 else 1)
