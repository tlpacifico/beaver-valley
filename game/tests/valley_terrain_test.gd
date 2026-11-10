extends SceneTree
## Focused checks for the deterministic R1 valley terrain and its fit evidence.

const TerrainScript = preload("res://scripts/valley_terrain.gd")
const LayoutScript = preload("res://scripts/valley_layout.gd")
var failures: int = 0
var _variant_completed: bool = false


func _initialize() -> void:
	call_deferred("_run")


func _expect(condition: bool, description: String) -> void:
	if not condition:
		failures += 1
		push_error(description)


func _run() -> void:
	for variant: StringName in TerrainScript.VARIANTS:
		_variant_completed = false
		_check_variant(variant)
		_expect(_variant_completed, "Checks for %s did not run to completion (runtime error?)." % variant)
	_check_variants_differ()

	if failures == 0:
		print("CASTOR_VALLEY_TERRAIN_OK deterministic contains channel lake anchors route fit variants meshes interpolation")
	quit(0 if failures == 0 else 1)


func _check_variant(variant: StringName) -> void:
	var terrain = TerrainScript.new()
	terrain.configure(variant)
	var layout = LayoutScript.new()
	layout.configure(terrain)

	for z in range(-8, 9, 2):
		_expect(is_finite(terrain.height_at(Vector2(terrain.river_center_x(float(z)), float(z)))), "Height is not finite at the channel, %s." % variant)
	_expect(terrain.contains(Vector2.ZERO), "%s must contain the valley centre." % variant)
	_expect(not terrain.contains(Vector2(TerrainScript.OVAL_RADIUS_X * 1.3, 0.0)), "%s must not contain a point beyond the oval on X." % variant)
	_expect(not terrain.contains(Vector2(0.0, -TerrainScript.OVAL_RADIUS_Z * 1.3)), "%s must not contain a point beyond the oval on Z." % variant)

	for z in range(-8, 9, 2):
		var channel_height: float = terrain.height_at(Vector2(terrain.river_center_x(float(z)), float(z)))
		_expect(channel_height < terrain.initial_water_level() - 0.05, "%s channel is not below the initial water level at z=%d." % [variant, z])

	var lake_center: Vector2 = terrain.lake_center()
	_expect(terrain.height_at(lake_center) < terrain.full_water_level() - 0.20, "%s lake bed is not below the full water level." % variant)
	_expect(terrain.is_water_footprint(lake_center), "%s lake centre must be part of the maximum water footprint." % variant)

	for id: StringName in LayoutScript.ANCHOR_IDS:
		var xz: Vector2 = layout.anchor_xz(id)
		_expect(terrain.height_at(xz) > terrain.full_water_level() + 0.03, "%s anchor %s sits in the maximum lake footprint." % [variant, id])
		_expect(terrain.slope_degrees(xz) <= TerrainScript.ROUTE_SLOPE_LIMIT_DEGREES, "%s anchor %s is steeper than 20°." % [variant, id])

	var route: PackedVector3Array = layout.route_points()
	_expect(route.size() >= 5, "%s route needs the five activity waypoints." % variant)
	for point in route:
		_expect(point.y > terrain.full_water_level() + 0.02, "%s route point sits in water." % variant)

	var report: Dictionary = layout.fit_report()
	_expect(report.has("fits"), "%s fit report is missing the fits verdict." % variant)
	if not report.has("fits"):
		return
	_expect(report["fits"], "%s fit report should pass: %s" % [variant, report["notes"]])
	_expect(report["usable_bank_area_m2"] >= 35.0, "%s usable bank area is too small." % variant)
	_expect(report["min_bank_width_m"] >= 4.0, "%s usable bank width is too small." % variant)
	_expect(report["anchor_clearance_m"] >= 0.25, "%s activity zones overlap." % variant)
	_expect(report["route_max_slope_degrees"] <= TerrainScript.ROUTE_SLOPE_LIMIT_DEGREES, "%s route is too steep." % variant)
	_expect(not report["hidden_ground_risk"], "%s has a camera-facing slope steeper than the camera elevation." % variant)
	_expect(report["near_bank_max_slope_degrees"] < LayoutScript.CAMERA_ELEVATION_DEGREES, "%s near channel bank is steeper than the camera elevation." % variant)
	print("CASTOR_VALLEY_FIT %s usable=%.1f width=%.1f route=%.1f slope=%.1f clearance=%.1f near_slope=%.1f lodge_slope=%.1f" % [
		variant, report["usable_bank_area_m2"], report["min_bank_width_m"], report["route_length_m"],
		report["route_max_slope_degrees"], report["anchor_clearance_m"],
		report["near_bank_max_slope_degrees"], report["lodge_near_side_max_slope_degrees"],
	])

	var initial_mesh: ArrayMesh = terrain.water_mesh(terrain.initial_water_level())
	var full_mesh: ArrayMesh = terrain.water_mesh(terrain.full_water_level())
	_expect(initial_mesh.get_surface_count() > 0, "%s initial water mesh is empty." % variant)
	_expect(full_mesh.get_surface_count() > 0, "%s full water mesh is empty." % variant)
	if initial_mesh.get_surface_count() > 0 and full_mesh.get_surface_count() > 0:
		_expect(full_mesh.surface_get_array_len(0) > initial_mesh.surface_get_array_len(0), "%s full lake must cover more ground than the initial marsh." % variant)
	_expect(is_equal_approx(terrain.water_surface_height_at(lake_center, terrain.full_water_level()), terrain.full_water_level()), "%s lake surface does not follow the full level." % variant)
	_expect(is_equal_approx(terrain.water_surface_height_at(Vector2(terrain.river_center_x(0.0), 0.0), terrain.full_water_level()), terrain.initial_water_level()), "%s downstream surface was raised with the lake." % variant)

	var skirt: ArrayMesh = terrain.boundary_skirt_mesh()
	_expect(skirt.get_surface_count() > 0, "%s terrain boundary skirt is empty." % variant)
	if skirt.get_surface_count() > 0:
		_expect(skirt.get_aabb().position.y <= -1.0, "%s terrain boundary skirt does not extend below the relief." % variant)

	var terrain_mesh: ArrayMesh = terrain.terrain_mesh()
	_expect(terrain_mesh.get_surface_count() > 0, "%s terrain mesh is empty." % variant)
	if terrain_mesh.get_surface_count() > 0:
		var bounds := terrain_mesh.get_aabb()
		_expect(bounds.size.x >= 20.0 and bounds.size.z >= 18.0, "%s terrain does not cover the decorative perimeter." % variant)
		_expect(bounds.size.y > 1.0, "%s terrain has no visible relief." % variant)
		_check_grid_interpolation(terrain, variant)

	_variant_completed = true


## The public height must be the linear interpolation of the emitted triangles,
## not the analytic curve between them.
func _check_grid_interpolation(terrain, variant: StringName) -> void:
	var samples := [Vector2(1.13, 2.37), Vector2(-1.87, -3.61), Vector2(4.42, -0.29)]
	for xz: Vector2 in samples:
		var step: float = TerrainScript.GRID_STEP
		var origin: Vector2 = TerrainScript.GRID_ORIGIN
		var fx := (xz.x - origin.x) / step
		var fz := (xz.y - origin.y) / step
		var ix := floori(fx)
		var iz := floori(fz)
		var tx := fx - float(ix)
		var tz := fz - float(iz)
		var corner := origin + Vector2(float(ix), float(iz)) * step
		var h00: float = terrain.height_at(corner)
		var h10: float = terrain.height_at(corner + Vector2(step, 0.0))
		var h01: float = terrain.height_at(corner + Vector2(0.0, step))
		var h11: float = terrain.height_at(corner + Vector2(step, step))
		var expected: float
		if tx >= tz:
			expected = h00 + tx * (h10 - h00) + tz * (h11 - h10)
		else:
			expected = h00 + tz * (h01 - h00) + tx * (h11 - h01)
		_expect(is_equal_approx(terrain.height_at(xz), expected), "%s height_at is not on the visible triangles at %s." % [variant, xz])


func _check_variants_differ() -> void:
	var gentle = TerrainScript.new()
	gentle.configure(&"gentle")
	var cached_terrain_mesh: ArrayMesh = gentle.terrain_mesh()
	var cached_initial_water: ArrayMesh = gentle.water_mesh(gentle.initial_water_level())
	_expect(gentle.terrain_mesh() == cached_terrain_mesh, "Repeated terrain mesh requests should reuse the generated mesh.")
	_expect(gentle.water_mesh(gentle.initial_water_level()) == cached_initial_water, "Repeated water mesh requests should reuse the generated level mesh.")
	var gentle_sample := Vector2(-8.6, -4.6)
	var gentle_height: float = gentle.height_at(gentle_sample)
	gentle.configure(&"wide_bank")
	var wide_terrain_mesh: ArrayMesh = gentle.terrain_mesh()
	var wide_initial_water: ArrayMesh = gentle.water_mesh(gentle.initial_water_level())
	_expect(wide_terrain_mesh != cached_terrain_mesh, "Changing terrain variant should invalidate the terrain mesh cache.")
	_expect(wide_initial_water != cached_initial_water, "Changing terrain variant should invalidate the water mesh cache.")
	_expect(not is_equal_approx(gentle.height_at(gentle_sample), gentle_height), "Reconfiguring terrain should update sampled terrain geometry.")
	_expect(wide_terrain_mesh.get_surface_count() > 0 and wide_initial_water.get_surface_count() > 0, "Reconfigured terrain or water mesh is empty.")
	var pronounced = TerrainScript.new()
	pronounced.configure(&"pronounced")
	_expect(absf(gentle.height_at(gentle_sample) - pronounced.height_at(gentle_sample)) >= 0.25, "Landform variants do not differ enough at the hill sample.")
	_expect(absf(gentle.river_center_x(2.0) - pronounced.river_center_x(2.0)) > 0.01, "Variants ignore the river curve.")
