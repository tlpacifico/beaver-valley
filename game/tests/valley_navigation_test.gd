extends SceneTree
## Focused checks for the shared 0.5 m terrain navigation.

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
	navigation.configure(terrain)

	_expect(navigation.get_cell_count() == 26 * 22, "Navigation grid must cover the 13 × 11 m bank at 0.5 m.")
	_expect(navigation.get_solid_cell_count() > 0, "The lake and steep banks must block some cells.")
	_expect(navigation.get_solid_cell_count() < navigation.get_cell_count(), "The whole bank is solid.")

	var spawn: Vector3 = layout.anchor(&"spawn")
	var lodge: Vector3 = layout.anchor(&"lodge")
	var food: Vector3 = layout.anchor(&"food_bank")
	var dam: Vector3 = layout.anchor(&"dam_approach")
	_expect(navigation.is_walkable(Vector2(spawn.x, spawn.z)), "Spawn is not walkable.")
	_expect(navigation.is_walkable(Vector2(lodge.x, lodge.z)), "Lodge anchor is not walkable.")
	_expect(not navigation.is_walkable(Vector2(terrain.lake_center().x, terrain.lake_center().y)), "Lake centre must not be walkable.")
	_expect(not navigation.is_walkable(Vector2(-8.0, -5.0)), "Hill outside the playable rect must not be walkable.")

	_check_path(terrain, navigation, spawn, lodge, "spawn→lodge")
	_check_path(terrain, navigation, spawn, food, "spawn→food")
	_check_path(terrain, navigation, dam, lodge, "dam→lodge")

	var first := navigation.find_path(spawn, lodge)
	var second := navigation.find_path(spawn, lodge)
	_expect(first == second, "Navigation is not deterministic for the same endpoints.")
	_expect(navigation.find_path(spawn, Vector3(terrain.lake_center().x, 0.0, terrain.lake_center().y)).is_empty(), "A route into the lake must be refused.")

	var approach := navigation.find_approach(spawn, Vector2(lodge.x, lodge.z), 3)
	_expect(not approach.is_empty(), "Approach to the lodge is missing.")
	if not approach.is_empty():
		var last := approach[approach.size() - 1]
		_expect(Vector2(last.x, last.z).distance_to(Vector2(lodge.x, lodge.z)) <= 1.6, "Approach does not end near the lodge.")

	if failures == 0:
		print("CASTOR_VALLEY_NAVIGATION_OK grid water slope approach determinism")
	quit(0 if failures == 0 else 1)


func _check_path(terrain, navigation, from: Vector3, to: Vector3, label: String) -> void:
	var path: PackedVector3Array = navigation.find_path(from, to)
	_expect(not path.is_empty(), "Missing path: %s." % label)
	if path.is_empty():
		return
	var previous := Vector2(from.x, from.z)
	for point in path:
		var xz := Vector2(point.x, point.z)
		_expect(ValleyTerrain.PLAYABLE_RECT.has_point(xz), "%s leaves the playable rect." % label)
		_expect(not terrain.is_water_footprint(xz), "%s crosses the maximum water footprint." % label)
		_expect(terrain.slope_degrees(xz) <= ValleyTerrain.ROUTE_SLOPE_LIMIT_DEGREES, "%s crosses a slope above 20°." % label)
		_expect(previous.distance_to(xz) <= 0.75, "%s has a gap larger than one diagonal cell." % label)
		previous = xz
	_expect(previous.distance_to(Vector2(to.x, to.z)) <= 0.75, "%s does not end at the destination cell." % label)
