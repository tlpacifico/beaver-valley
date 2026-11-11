extends SceneTree
## R4 prepared water: the lake follows the requested level, the downstream
## reach stays at the initial level and no walkable cell sits below the lake.

const TerrainScript = preload("res://scripts/valley_terrain.gd")
const LayoutScript = preload("res://scripts/valley_layout.gd")
const NavigationScript = preload("res://scripts/valley_navigation.gd")
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
	var layout = LayoutScript.new()
	layout.configure(terrain)
	var navigation = NavigationScript.new()
	navigation.configure(terrain, layout)

	var initial: float = terrain.initial_water_level()
	var intermediate: float = terrain.intermediate_water_level()
	var full: float = terrain.full_water_level()
	var lake: Vector2 = terrain.lake_center()
	var downstream := Vector2(-4.0, 0.0)
	var dry := Vector2(5.0, 4.0)

	_expect(is_equal_approx(terrain.water_surface_height_at(lake, initial), initial), "The initial lake surface is not at the initial level.")
	_expect(is_equal_approx(terrain.water_surface_height_at(lake, intermediate), intermediate), "The intermediate lake surface does not follow the intermediate level.")
	_expect(is_equal_approx(terrain.water_surface_height_at(lake, full), full), "The full lake surface does not follow the full level.")
	_expect(is_equal_approx(terrain.water_surface_height_at(downstream, full), initial), "The downstream reach was raised with the lake.")
	_expect(is_equal_approx(terrain.water_surface_height_at(downstream, intermediate), initial), "The downstream reach followed an intermediate lake level.")
	_expect(is_inf(terrain.water_surface_height_at(dry, full)) and terrain.water_surface_height_at(dry, full) < 0.0, "Dry ground reports a water surface.")

	var upstream_mesh: ArrayMesh = terrain.water_mesh_reach(full, true)
	var downstream_mesh: ArrayMesh = terrain.water_mesh_reach(full, false)
	_expect(upstream_mesh.get_surface_count() > 0, "The upstream lake mesh is empty.")
	_expect(downstream_mesh.get_surface_count() > 0, "The downstream stream mesh is empty.")
	_expect(absf(upstream_mesh.get_aabb().end.y - (full + 0.008)) <= 0.02, "The upstream mesh does not end at the requested lake level.")
	_expect(absf(downstream_mesh.get_aabb().end.y - (initial + 0.008)) <= 0.02, "The downstream mesh does not stay at the initial level.")
	_expect(_maximum_vertex_y(downstream_mesh) <= initial + 0.02, "A downstream vertex is above the fixed stream level.")
	_expect(_maximum_vertex_y(upstream_mesh) <= full + 0.02, "An upstream vertex is above the requested lake level.")

	var initial_mesh: ArrayMesh = terrain.water_mesh(initial)
	var full_mesh: ArrayMesh = terrain.water_mesh(full)
	_expect(full_mesh.surface_get_array_len(0) > initial_mesh.surface_get_array_len(0), "The full lake mesh does not cover more ground than the initial marsh.")

	var clear_cache := terrain.water_mesh(full, layout.food_cache_xz(), 1.15)
	var arrays := clear_cache.surface_get_arrays(0)
	var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var cache := layout.food_cache_xz()
	var minimum_alpha := 1.0
	for index in range(positions.size()):
		if index >= colors.size():
			break
		var xz := Vector2(positions[index].x, positions[index].z)
		if xz.distance_to(cache) <= 0.65:
			minimum_alpha = minf(minimum_alpha, colors[index].a)
	_expect(minimum_alpha < 0.55, "The water above the food cache is not clearer than the lake.")

	var walkable_below_water := 0
	for column in range(26):
		for row in range(22):
			var cell := Vector2i(column, row)
			if navigation.is_cell_solid(cell):
				continue
			var center := navigation.world_xz(cell)
			if terrain.height_at(center) < full + 0.02:
				walkable_below_water += 1
	_expect(walkable_below_water == 0, "%d walkable cells are below the full lake surface." % walkable_below_water)

	if failures == 0:
		print("CASTOR_VALLEY_WATER_OK upstream_rise downstream_fixed clear_cache no_walkable_underwater")
	quit(0 if failures == 0 else 1)


func _maximum_vertex_y(mesh: ArrayMesh) -> float:
	var maximum := -INF
	for surface_index in range(mesh.get_surface_count()):
		var arrays := mesh.surface_get_arrays(surface_index)
		var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for point in positions:
			maximum = maxf(maximum, point.y)
	return maximum
