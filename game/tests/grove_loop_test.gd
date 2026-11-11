extends SceneTree
## Focused checks for the N2 connected land loop. One authored grove must drive
## terrain placement, navigation exclusion, collision and visuals from the same
## source, while two usable routes connect the branch clearing to the woodland
## opening, every direct task route keeps its length, the whole walkable valley
## stays connected and an actual traversal neither clips the grove nor grows the
## save file.

const TerrainScript = preload("res://scripts/valley_terrain.gd")
const LayoutScript = preload("res://scripts/valley_layout.gd")
const NavigationScript = preload("res://scripts/valley_navigation.gd")
const DamSave = preload("res://scripts/dam_save.gd")

const SAVE_TEST_DIRECTORY := "user://grove_loop_test/"
const MIN_OBSTACLES: int = 3
const MAX_OBSTACLES: int = 5
const OBSTACLE_DRY_MARGIN: float = 0.03
const MAX_OBSTACLE_SLOPE: float = 15.0
const TASK_POINT_CLEARANCE: float = 1.0
const GROVE_CELL_CLEARANCE: float = 0.26
const DIRECT_GROWTH_LIMIT: float = 1.0
## 0.5 m cells start and end a measured path at cell centres. The quantisation
## allowance only compares that measured path with its requested endpoint; it
## never relaxes the direct-route growth gate.
const DIRECT_QUANTISATION_TOLERANCE: float = 0.75
const MIN_ROUTE_SEPARATION: float = 1.0
## The actor's capsule plus the navigation clearance margin: the same 0.30 m
## the shared navigation reserves around every authored obstacle.
const ROUTE_OBSTACLE_CLEARANCE: float = NavigationScript.ACTOR_RADIUS + NavigationScript.CLEARANCE_MARGIN
## Free half-corridor every route sample must keep around a grove obstacle, so a
## one-cell squeeze cannot pass as a usable land loop.
const CORRIDOR_HALF_WIDTH: float = 0.75
const OPENING_PLANT_MIN_RADIUS: float = 0.8
const OPENING_PLANT_MAX_RADIUS: float = 1.2
const MIN_WAYPOINT_LATERAL: float = 1.0
const MAX_WAYPOINT_LATERAL: float = 4.0
const WAYPOINT_LATERAL_STEP: float = 0.25
const WAYPOINT_SEARCH_RADIUS_CELLS: int = 4
const ARRIVAL_RADIUS: float = 0.6
const ACTOR_OBSTACLE_CLEARANCE: float = 0.20
const GROUND_TOLERANCE: float = 0.06
const VISUAL_MATCH_RADIUS: float = 0.25
const MIN_COLLISION_HEIGHT: float = 0.9
const MIN_COLLISION_GROUND_REACH: float = 0.35
const COLLISION_POSITION_TOLERANCE: float = 0.15
const EPSILON: float = 0.001

## The ten task points that must stay clear of the grove: the five layout
## anchors plus the five branch pickup spots authored by movement_world.
const TASK_POINTS: Array[Vector2] = [
	Vector2(3.4, 3.9),
	Vector2(1.7, 1.9),
	Vector2(0.0, -0.2),
	Vector2(-0.7, -3.5),
	Vector2(2.5, -4.4),
	Vector2(3.2, 3.0),
	Vector2(0.8, 3.2),
	Vector2(2.6, 1.0),
	Vector2(0.2, 1.2),
	Vector2(4.5, 4.25),
]

## The five branch pickup spots authored by movement_world. Like the anchors,
## they must stay walkable and reachable from spawn with the grove in place.
const BRANCH_SPOTS: Array[Vector2] = [
	Vector2(3.2, 3.0),
	Vector2(0.8, 3.2),
	Vector2(2.6, 1.0),
	Vector2(0.2, 1.2),
	Vector2(4.5, 4.25),
]

## Baseline direct route lengths measured on the accepted 0.5 m navigation.
const DIRECT_ROUTES := [
	["spawn", "branch_clearing", 2.63],
	["spawn", "dam_approach", 5.25],
	["spawn", "lodge", 8.70],
	["spawn", "food_bank", 8.22],
	["dam_approach", "lodge", 3.43],
	["lodge", "food_bank", 3.93],
]

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

	var obstacles: Array = layout.grove_obstacles()
	var opening: Vector2 = layout.woodland_opening_xz()
	var task_points := _task_points(layout)

	_check_authored_grove(terrain, navigation, obstacles, opening, task_points)
	_check_navigation_exclusion(navigation, obstacles)
	_check_connectivity(layout, navigation)
	_check_direct_routes(layout, navigation)
	var loop_routes := _check_loop_routes(terrain, layout, navigation, obstacles, opening)
	await _check_world_and_traversal(terrain, layout, obstacles, opening, loop_routes)

	if failures == 0:
		print("CASTOR_GROVE_LOOP_OK")
	quit(0 if failures == 0 else 1)


func _task_points(layout: ValleyLayout) -> Array:
	var points: Array = TASK_POINTS.duplicate()
	for id: StringName in LayoutScript.ANCHOR_IDS:
		var xz: Vector2 = layout.anchor_xz(id)
		if not points.has(xz):
			points.append(xz)
	return points


## The authored grove positions must respect the valley: inside the playable
## rectangle, dry above the full lake, gentle, clear of every task point and in
## the east half of the bank.
func _check_authored_grove(terrain: ValleyTerrain, navigation: ValleyNavigation, obstacles: Array, opening: Vector2, task_points: Array) -> void:
	_expect(obstacles.size() >= MIN_OBSTACLES and obstacles.size() <= MAX_OBSTACLES, "The authored grove has %d obstacles; 3-5 are required." % obstacles.size())
	var ids := {}
	var centroid := Vector2.ZERO
	for index in range(obstacles.size()):
		var obstacle: Dictionary = obstacles[index]
		for field in ["id", "xz", "y", "radius", "kind"]:
			_expect(obstacle.has(field), "Grove obstacle %d is missing the %s field." % [index, field])
		var id := String(obstacle.get("id", ""))
		var xz: Vector2 = obstacle.get("xz", Vector2.ZERO)
		var y: float = float(obstacle.get("y", 0.0))
		var radius: float = float(obstacle.get("radius", 0.0))
		var kind := String(obstacle.get("kind", ""))
		centroid += xz
		_expect(not id.is_empty() and not ids.has(id), "Grove obstacle %d has an empty or repeated id '%s'." % [index, id])
		ids[id] = true
		_expect(xz.is_finite() and ValleyTerrain.PLAYABLE_RECT.has_point(xz), "Grove obstacle '%s' sits outside PLAYABLE_RECT at %s." % [id, str(xz)])
		var ground: float = terrain.height_at(xz)
		_expect(absf(y - ground) <= 0.01, "Grove obstacle '%s' reports y %.3f instead of the terrain height %.3f." % [id, y, ground])
		_expect(ground >= terrain.full_water_level() + OBSTACLE_DRY_MARGIN - EPSILON, "Grove obstacle '%s' sits at %.3f, below the dry threshold %.3f." % [id, ground, terrain.full_water_level() + OBSTACLE_DRY_MARGIN])
		var slope: float = terrain.slope_degrees(xz)
		_expect(slope <= MAX_OBSTACLE_SLOPE + EPSILON, "Grove obstacle '%s' sits on a %.1f degree slope; the limit is %.1f." % [id, slope, MAX_OBSTACLE_SLOPE])
		_expect(radius > 0.0, "Grove obstacle '%s' has a non-positive radius %.3f." % [id, radius])
		_expect(kind == "boulder" or kind == "trunk", "Grove obstacle '%s' has kind '%s'; only boulder or trunk are allowed." % [id, kind])
		for point: Vector2 in task_points:
			var gap := xz.distance_to(point)
			_expect(gap >= TASK_POINT_CLEARANCE - EPSILON, "Grove obstacle '%s' is %.2f m from task point %s; at least %.1f m are required." % [id, gap, str(point), TASK_POINT_CLEARANCE])
	if not obstacles.is_empty():
		_expect(centroid.x / float(obstacles.size()) > 0.0, "The grove group is not in the east half of the bank.")
	_expect(opening.is_finite() and ValleyTerrain.PLAYABLE_RECT.has_point(opening), "The woodland opening %s is outside PLAYABLE_RECT." % str(opening))
	_expect(navigation.is_walkable(opening), "The woodland opening %s is not walkable." % str(opening))
	_expect(not terrain.is_water_footprint(opening), "The woodland opening %s is inside the maximum water footprint." % str(opening))


## Navigation must exclude exactly the authored obstacles with the actor's
## clearance, so no path can clip a grove in the game, the preview or a test.
func _check_navigation_exclusion(navigation: ValleyNavigation, obstacles: Array) -> void:
	_expect(navigation.obstacle_count() == obstacles.size(), "obstacle_count() reports %d grove obstacles; the layout authors %d." % [navigation.obstacle_count(), obstacles.size()])
	for index in range(obstacles.size()):
		var obstacle: Dictionary = obstacles[index]
		var xz: Vector2 = obstacle.get("xz", Vector2.ZERO)
		_expect(navigation.is_obstacle_blocked(xz), "is_obstacle_blocked() is false at grove obstacle %d centre %s." % [index, str(xz)])
		_expect(not navigation.is_walkable(xz), "Grove obstacle %d centre %s is still walkable." % [index, str(xz)])
		_expect(navigation.is_cell_solid(navigation.cell_at(xz)), "The navigation cell under grove obstacle %d centre %s is not solid." % [index, str(xz)])

	var columns := int(round(ValleyTerrain.PLAYABLE_RECT.size.x / NavigationScript.CELL_SIZE))
	var rows := int(round(ValleyTerrain.PLAYABLE_RECT.size.y / NavigationScript.CELL_SIZE))
	var violations := 0
	var worst_gap := INF
	var worst_description := ""
	for column in range(columns):
		for row in range(rows):
			var cell := Vector2i(column, row)
			if navigation.is_cell_solid(cell):
				continue
			var cell_xz := navigation.world_xz(cell)
			for index in range(obstacles.size()):
				var obstacle: Dictionary = obstacles[index]
				var obstacle_xz: Vector2 = obstacle.get("xz", Vector2.ZERO)
				var radius: float = float(obstacle.get("radius", 0.0))
				var required := radius + GROVE_CELL_CLEARANCE
				var gap := cell_xz.distance_to(obstacle_xz) - required
				if gap < -EPSILON:
					violations += 1
					if gap < worst_gap:
						worst_gap = gap
						worst_description = "cell %s is %.2f m from obstacle %d; %.2f m are required." % [str(cell_xz), cell_xz.distance_to(obstacle_xz), index, required]
	_expect(violations == 0, "The grove left %d walkable cells inside its clearance radius; worst: %s" % [violations, worst_description])


## Every non-solid cell must stay reachable from spawn. An obstacle ring that
## pinches off a pocket would trap the actor even when the tasks still work.
func _check_connectivity(layout: ValleyLayout, navigation: ValleyNavigation) -> void:
	var spawn: Vector3 = layout.anchor(&"spawn")
	var start := navigation.cell_at(Vector2(spawn.x, spawn.z))
	_expect(not navigation.is_cell_solid(start), "The spawn cell is solid with the grove.")
	var visited := {}
	visited[start] = true
	var frontier: Array[Vector2i] = [start]
	while not frontier.is_empty():
		var cell: Vector2i = frontier.pop_back()
		for offset: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var neighbour := cell + offset
			if visited.has(neighbour) or navigation.is_cell_solid(neighbour):
				continue
			visited[neighbour] = true
			frontier.append(neighbour)
	var walkable_count := navigation.get_cell_count() - navigation.get_solid_cell_count()
	_expect(visited.size() == walkable_count, "Flood fill from spawn reached %d of %d non-solid cells; %d walkable cells are cut off from the valley." % [visited.size(), walkable_count, walkable_count - visited.size()])
	for id: StringName in LayoutScript.ANCHOR_IDS:
		var anchor: Vector3 = layout.anchor(id)
		var anchor_xz := Vector2(anchor.x, anchor.z)
		_expect(navigation.is_walkable(anchor_xz), "The %s anchor is not walkable with the grove." % String(id))
		var path: PackedVector3Array = navigation.find_path(spawn, anchor)
		_expect(not path.is_empty(), "No path from spawn to the %s anchor with the grove." % String(id))
	# Every branch pickup must stay reachable as well: the grove may not cut a
	# dropped branch off even when the task anchors still route.
	for spot in BRANCH_SPOTS:
		_expect(navigation.is_walkable(spot), "The branch pickup %s is not walkable with the grove." % str(spot))
		var branch_world := Vector3(spot.x, spawn.y, spot.y)
		var branch_path: PackedVector3Array = navigation.find_path(spawn, branch_world)
		_expect(not branch_path.is_empty(), "No path from spawn to the branch pickup %s with the grove." % str(spot))


## The grove decorates an alternate loop; it must not lengthen the direct task
## routes by more than 1 m. Cell quantisation is allowed only when relating the
## measured path to its requested endpoints, never when judging that growth.
func _check_direct_routes(layout: ValleyLayout, navigation: ValleyNavigation) -> void:
	for spec in DIRECT_ROUTES:
		var from_id := StringName(String(spec[0]))
		var to_id := StringName(String(spec[1]))
		var baseline: float = spec[2]
		var label := "%s→%s" % [String(from_id), String(to_id)]
		var from: Vector3 = layout.anchor(from_id)
		var to: Vector3 = layout.anchor(to_id)
		var path: PackedVector3Array = navigation.find_path(from, to)
		_expect(not path.is_empty(), "The grove removed the direct route %s." % label)
		if path.is_empty():
			continue
		var length := _path_length(path)
		var allowed := baseline + DIRECT_GROWTH_LIMIT
		_expect(length <= allowed + EPSILON, "Direct route %s grew to %.2f m; the %.2f m baseline allows at most %.2f m." % [label, length, baseline, allowed])
		var start_gap := _flat_xz(path[0]).distance_to(_flat_xz(from))
		var end_gap := _flat_xz(path[path.size() - 1]).distance_to(_flat_xz(to))
		_expect(start_gap <= DIRECT_QUANTISATION_TOLERANCE + EPSILON, "Direct route %s starts %.2f m from its anchor; one 0.5 m cell allows %.2f m." % [label, start_gap, DIRECT_QUANTISATION_TOLERANCE])
		_expect(end_gap <= DIRECT_QUANTISATION_TOLERANCE + EPSILON, "Direct route %s ends %.2f m from its anchor; one 0.5 m cell allows %.2f m." % [label, end_gap, DIRECT_QUANTISATION_TOLERANCE])


## Two usable routes must circle the grove between the branch clearing and the
## woodland opening: one through a south/east waypoint and one through a
## west/north waypoint, both clear of every authored obstacle. Returns the
## waypoints so the traversal can walk one side out and the other side back.
func _check_loop_routes(terrain: ValleyTerrain, layout: ValleyLayout, navigation: ValleyNavigation, obstacles: Array, opening: Vector2) -> Dictionary:
	var clearing: Vector2 = layout.anchor_xz(&"branch_clearing")
	var span := opening - clearing
	if span.length() < 0.5:
		_expect(false, "The woodland opening is too close to the branch clearing to form a walking loop.")
		return {}
	var along := span.normalized()
	var perpendicular := Vector2(-along.y, along.x)
	# Route A keeps the larger x + z offset, so it is the south/east waypoint.
	if perpendicular.x + perpendicular.y < 0.0:
		perpendicular = -perpendicular
	var midpoint := (clearing + opening) * 0.5
	var from := Vector3(clearing.x, terrain.height_at(clearing), clearing.y)
	var to := Vector3(opening.x, terrain.height_at(opening), opening.y)
	var route_a := _find_side_route(navigation, obstacles, from, to, midpoint, perpendicular)
	var route_b := _find_side_route(navigation, obstacles, from, to, midpoint, -perpendicular)
	_expect(not route_a.is_empty(), "No south/east route connects the branch clearing to the woodland opening around the grove.")
	_expect(not route_b.is_empty(), "No west/north route connects the branch clearing to the woodland opening around the grove.")
	if route_a.is_empty() or route_b.is_empty():
		return {}
	_check_route_clearance(route_a, obstacles, "south/east")
	_check_route_clearance(route_b, obstacles, "west/north")
	_check_corridor_width(route_a, obstacles, navigation, "south/east")
	_check_corridor_width(route_b, obstacles, navigation, "west/north")
	var separation := _route_separation(route_a, route_b)
	_expect(separation >= MIN_ROUTE_SEPARATION - EPSILON, "The two grove routes are only %.2f m apart at their widest; two usable routes need at least %.1f m of separation." % [separation, MIN_ROUTE_SEPARATION])
	_check_detour(clearing, opening, obstacles, route_a, route_b)
	return {
		"midpoint": midpoint,
		"south_waypoint": _route_waypoint(route_a, midpoint, perpendicular),
		"north_waypoint": _route_waypoint(route_b, midpoint, -perpendicular),
	}


## The grove must really force the loop: the straight clearing-to-opening line
## passes inside an obstacle's reserved clearance, and both loop sides are
## longer than that straight line.
func _check_detour(clearing: Vector2, opening: Vector2, obstacles: Array, route_a: PackedVector3Array, route_b: PackedVector3Array) -> void:
	var straight := clearing.distance_to(opening)
	var blocked := false
	var closest_gap := INF
	var closest_detail := ""
	var samples := maxi(2, int(ceil(straight / 0.05)))
	for sample_index in range(samples + 1):
		var point := clearing.lerp(opening, float(sample_index) / float(samples))
		for obstacle_index in range(obstacles.size()):
			var obstacle: Dictionary = obstacles[obstacle_index]
			var obstacle_xz: Vector2 = obstacle.get("xz", Vector2.ZERO)
			var limit: float = float(obstacle.get("radius", 0.0)) + ROUTE_OBSTACLE_CLEARANCE
			var distance := point.distance_to(obstacle_xz)
			if distance - limit < closest_gap:
				closest_gap = distance - limit
				closest_detail = "obstacle %d at %s is %.2f m from the line; %.2f m are reserved." % [obstacle_index, str(obstacle_xz), distance, limit]
			if distance <= limit + EPSILON:
				blocked = true
	_expect(blocked, "The straight line from the branch clearing to the woodland opening stays outside every obstacle clearance (%s), so the grove does not force the loop." % closest_detail)
	var straight_south := _path_length(route_a)
	var straight_north := _path_length(route_b)
	_expect(straight_south > straight + EPSILON, "The south/east grove route is %.2f m, no longer than the %.2f m straight line; it is not a detour." % [straight_south, straight])
	_expect(straight_north > straight + EPSILON, "The west/north grove route is %.2f m, no longer than the %.2f m straight line; it is not a detour." % [straight_north, straight])


## Every route sample keeps a free 0.75 m half-corridor around the grove, and
## each route cell has a walkable perpendicular neighbour, so the corridor is
## two 0.5 m cells (about 1.0 m) wide instead of one squeezed cell.
func _check_corridor_width(route: PackedVector3Array, obstacles: Array, navigation: ValleyNavigation, label: String) -> void:
	var closest := INF
	var closest_detail := ""
	for index in range(route.size()):
		var sample := _flat_xz(route[index])
		for obstacle_index in range(obstacles.size()):
			var obstacle: Dictionary = obstacles[obstacle_index]
			var obstacle_xz: Vector2 = obstacle.get("xz", Vector2.ZERO)
			var radius: float = float(obstacle.get("radius", 0.0))
			var required := radius + CORRIDOR_HALF_WIDTH
			var distance := sample.distance_to(obstacle_xz)
			if distance - required < closest:
				closest = distance - required
				closest_detail = "sample %d at %s is %.2f m from obstacle %d; %.2f m are required." % [index, str(sample), distance, obstacle_index, required]
	_expect(closest >= -EPSILON, "The %s grove route leaves less than a %.2f m free half-corridor; worst: %s" % [label, CORRIDOR_HALF_WIDTH, closest_detail])
	var cells: Array[Vector2i] = []
	for point in route:
		cells.append(navigation.cell_at(_flat_xz(point)))
	var narrow_cells := 0
	var first_narrow := ""
	for index in range(cells.size()):
		var previous: Vector2i = cells[maxi(index - 1, 0)]
		var next: Vector2i = cells[mini(index + 1, cells.size() - 1)]
		var step := next - previous
		var offsets: Array[Vector2i] = []
		if absi(step.x) >= absi(step.y):
			offsets = [Vector2i(0, 1), Vector2i(0, -1)]
		else:
			offsets = [Vector2i(1, 0), Vector2i(-1, 0)]
		var walkable_neighbour := false
		for offset in offsets:
			if not navigation.is_cell_solid(cells[index] + offset):
				walkable_neighbour = true
		if not walkable_neighbour:
			narrow_cells += 1
			if first_narrow.is_empty():
				first_narrow = str(navigation.world_xz(cells[index]))
	_expect(narrow_cells == 0, "The %s grove route has %d cells without a walkable perpendicular neighbour (two cells are about 1.0 m wide); first at %s." % [label, narrow_cells, first_narrow])


## Waypoint of a side route: the vertex with the largest lateral offset from the
## clearing/opening midpoint, which is the waypoint the search chose.
func _route_waypoint(route: PackedVector3Array, midpoint: Vector2, direction: Vector2) -> Vector3:
	var best := Vector3.ZERO
	var best_lateral := -INF
	for point in route:
		var lateral := (_flat_xz(point) - midpoint).dot(direction)
		if lateral > best_lateral:
			best_lateral = lateral
			best = point
	return best


## Widest feasible waypoint on one side of the grove. The search walks outward
## from the clearing/opening midpoint and keeps the route with the largest
## lateral offset that the shared navigation can actually reach clear of the
## obstacles.
func _find_side_route(navigation: ValleyNavigation, obstacles: Array, from: Vector3, to: Vector3, midpoint: Vector2, direction: Vector2) -> PackedVector3Array:
	var best := PackedVector3Array()
	var best_lateral := MIN_WAYPOINT_LATERAL - 1.0
	var tried := {}
	var lateral := MAX_WAYPOINT_LATERAL
	while lateral >= MIN_WAYPOINT_LATERAL - EPSILON:
		var wanted := midpoint + direction * lateral
		var cell: Vector2i = navigation.nearest_walkable_cell(wanted, WAYPOINT_SEARCH_RADIUS_CELLS)
		if cell != NavigationScript.INVALID_CELL and not tried.has(cell):
			tried[cell] = true
			var waypoint: Vector3 = navigation.cell_to_world(cell)
			var actual_lateral := (Vector2(waypoint.x, waypoint.z) - midpoint).dot(direction)
			if actual_lateral >= MIN_WAYPOINT_LATERAL - EPSILON:
				var route := _route_between(navigation, from, to, waypoint)
				if not route.is_empty() and _route_is_clear(route, obstacles) and actual_lateral > best_lateral:
					best_lateral = actual_lateral
					best = route
		lateral -= WAYPOINT_LATERAL_STEP
	return best


func _route_between(navigation: ValleyNavigation, from: Vector3, to: Vector3, waypoint: Vector3) -> PackedVector3Array:
	var first: PackedVector3Array = navigation.find_path(from, waypoint)
	if first.is_empty():
		return PackedVector3Array()
	var second: PackedVector3Array = navigation.find_path(waypoint, to)
	if second.is_empty():
		return PackedVector3Array()
	var route := PackedVector3Array()
	for point in first:
		route.append(point)
	for index in range(1, second.size()):
		route.append(second[index])
	return route


func _route_is_clear(route: PackedVector3Array, obstacles: Array) -> bool:
	for point in route:
		var xz := _flat_xz(point)
		if not ValleyTerrain.PLAYABLE_RECT.has_point(xz):
			return false
		for obstacle in obstacles:
			var obstacle_xz: Vector2 = obstacle.get("xz", Vector2.ZERO)
			var radius: float = float(obstacle.get("radius", 0.0))
			if xz.distance_to(obstacle_xz) < radius + ROUTE_OBSTACLE_CLEARANCE - EPSILON:
				return false
	return true


func _check_route_clearance(route: PackedVector3Array, obstacles: Array, label: String) -> void:
	var leaves_rect := false
	for point in route:
		if not ValleyTerrain.PLAYABLE_RECT.has_point(_flat_xz(point)):
			leaves_rect = true
	_expect(not leaves_rect, "The %s grove route leaves the playable rectangle." % label)
	for index in range(obstacles.size()):
		var obstacle: Dictionary = obstacles[index]
		var obstacle_xz: Vector2 = obstacle.get("xz", Vector2.ZERO)
		var radius: float = float(obstacle.get("radius", 0.0))
		var closest := INF
		for point in route:
			closest = minf(closest, _flat_xz(point).distance_to(obstacle_xz))
		_expect(closest >= radius + ROUTE_OBSTACLE_CLEARANCE - EPSILON, "The %s grove route passes %.2f m from obstacle %d; at least %.2f m are required." % [label, closest, index, radius + ROUTE_OBSTACLE_CLEARANCE])


## Widest horizontal gap between the two routes: the distance from each route
## vertex to the nearest segment of the other route.
func _route_separation(first: PackedVector3Array, second: PackedVector3Array) -> float:
	var best := 0.0
	for point in first:
		best = maxf(best, _distance_to_polyline(_flat_xz(point), second))
	return best


func _distance_to_polyline(point: Vector2, route: PackedVector3Array) -> float:
	if route.is_empty():
		return INF
	if route.size() == 1:
		return point.distance_to(_flat_xz(route[0]))
	var closest := INF
	var previous := _flat_xz(route[0])
	for index in range(1, route.size()):
		var current := _flat_xz(route[index])
		var nearest := Geometry2D.get_closest_point_to_segment(point, previous, current)
		closest = minf(closest, point.distance_to(nearest))
		previous = current
	return closest


func _check_world_and_traversal(terrain: ValleyTerrain, layout: ValleyLayout, obstacles: Array, opening: Vector2, loop_routes: Dictionary) -> void:
	_expect(DamSave.clear_save(SAVE_TEST_DIRECTORY), "Could not clear the grove-loop save directory.")
	var baseline_state: Dictionary = DamSave.empty_state()
	_expect(DamSave.save_state(baseline_state, SAVE_TEST_DIRECTORY), "Could not write the isolated baseline save before the traversal.")
	var save_before := _read_save_dictionary(SAVE_TEST_DIRECTORY)
	_expect(not save_before.is_empty(), "Could not read the isolated baseline save before the traversal.")

	var world: Node = load("res://scenes/movement.tscn").instantiate()
	world.save_directory = SAVE_TEST_DIRECTORY
	root.add_child(world)
	await physics_frame
	await physics_frame

	_check_grove_collision(world, terrain, obstacles)
	_check_grove_visuals(world, terrain, obstacles)
	_check_opening_visuals(world, terrain, opening)
	_check_visual_environment_collision_free(world)

	var settled: bool = await _wait(func() -> bool: return world.actor.is_on_floor(), 5.0)
	_expect(settled, "The actor did not settle on the ground before the grove traversal.")

	var opening_world := Vector3(opening.x, terrain.height_at(opening), opening.y)
	var clearing_world: Vector3 = layout.anchor(&"branch_clearing")
	var clearing_xz := Vector2(clearing_world.x, clearing_world.z)
	var north_waypoint: Vector3 = loop_routes.get("north_waypoint", opening_world)
	var south_waypoint: Vector3 = loop_routes.get("south_waypoint", clearing_world)
	_expect(not loop_routes.is_empty(), "The two loop waypoints are unavailable, so the traversal cannot walk both grove sides.")

	# Outbound by the west/north side, then on to the woodland opening.
	_expect(world.request_move(north_waypoint), "The west/north loop waypoint could not be requested through the shared navigation.")
	var outbound_side := await _walk_until_arrived(world, 12.0)
	_expect(outbound_side["arrived"], "The actor did not reach the west/north loop waypoint within 12 s.")
	_check_actor_obstacle_clearance(outbound_side["positions"], obstacles, "opening waypoint")

	_expect(world.request_move(opening_world), "The woodland opening could not be requested through the shared navigation.")
	var outbound := await _walk_until_arrived(world, 15.0)
	_expect(outbound["arrived"], "The actor did not reach the woodland opening within 15 s.")
	var outbound_end := _flat_xz(world.actor.global_position)
	_expect(outbound_end.distance_to(opening) <= ARRIVAL_RADIUS, "The actor stopped %.2f m from the woodland opening; %.1f m are allowed." % [outbound_end.distance_to(opening), ARRIVAL_RADIUS])
	_check_actor_obstacle_clearance(outbound["positions"], obstacles, "opening")

	# Return by the other (south/east) side, then back to the branch clearing.
	_expect(world.request_move(south_waypoint), "The south loop waypoint could not be requested for the return leg.")
	var inbound_side := await _walk_until_arrived(world, 12.0)
	_expect(inbound_side["arrived"], "The actor did not reach the south loop waypoint within 12 s.")
	_check_actor_obstacle_clearance(inbound_side["positions"], obstacles, "clearing waypoint")

	_expect(world.request_move(clearing_world), "The branch clearing could not be requested for the return leg.")
	var inbound := await _walk_until_arrived(world, 15.0)
	_expect(inbound["arrived"], "The actor did not return to the branch clearing within 15 s.")
	var inbound_end := _flat_xz(world.actor.global_position)
	_expect(inbound_end.distance_to(clearing_xz) <= ARRIVAL_RADIUS, "The actor stopped %.2f m from the branch clearing; %.1f m are allowed." % [inbound_end.distance_to(clearing_xz), ARRIVAL_RADIUS])
	_check_actor_obstacle_clearance(inbound["positions"], obstacles, "clearing")

	_check_save_unchanged(save_before)

	world.queue_free()
	await process_frame
	_expect(DamSave.clear_save(SAVE_TEST_DIRECTORY), "Could not clean up the grove-loop save directory.")


## Collision must mirror the authored grove exactly: one grounded cylinder per
## obstacle on layer 1, with the authored radius and enough height to block the
## actor.
func _check_grove_collision(world: Node, terrain: ValleyTerrain, obstacles: Array) -> void:
	var body := world.find_child("GroveObstacles", true, false) as StaticBody3D
	_expect(body != null, "movement_world is missing the StaticBody3D GroveObstacles.")
	if body == null:
		return
	_expect(body.collision_layer == 1, "GroveObstacles is on collision layer %d instead of layer 1." % body.collision_layer)
	var shapes: Array = body.find_children("*", "CollisionShape3D", true, false)
	_expect(shapes.size() == obstacles.size(), "GroveObstacles has %d collision shapes; the layout authors %d obstacles." % [shapes.size(), obstacles.size()])
	var shape_radii: Array[float] = []
	for shape_node in shapes:
		var cylinder := shape_node.shape as CylinderShape3D
		if cylinder != null:
			shape_radii.append(cylinder.radius)
	var obstacle_radii: Array[float] = []
	for obstacle in obstacles:
		obstacle_radii.append(float(obstacle.get("radius", 0.0)))
	shape_radii.sort()
	obstacle_radii.sort()
	_expect(shape_radii.size() == obstacle_radii.size(), "GroveObstacles keeps %d cylinders for %d authored obstacles." % [shape_radii.size(), obstacle_radii.size()])
	for index in range(mini(shape_radii.size(), obstacle_radii.size())):
		_expect(is_equal_approx(shape_radii[index], obstacle_radii[index]), "Grove obstacle radius %.3f has a %.3f m collision cylinder." % [obstacle_radii[index], shape_radii[index]])
	for index in range(obstacles.size()):
		var obstacle: Dictionary = obstacles[index]
		var xz: Vector2 = obstacle.get("xz", Vector2.ZERO)
		var nearest: CollisionShape3D = null
		var nearest_distance := INF
		for shape_node in shapes:
			var candidate := shape_node.shape as CylinderShape3D
			if candidate == null:
				continue
			var distance := Vector2(shape_node.global_position.x, shape_node.global_position.z).distance_to(xz)
			if distance < nearest_distance:
				nearest_distance = distance
				nearest = shape_node
		_expect(nearest != null and nearest_distance <= COLLISION_POSITION_TOLERANCE, "No CylinderShape3D sits at grove obstacle %d centre %s." % [index, str(xz)])
		if nearest == null:
			continue
		var cylinder := nearest.shape as CylinderShape3D
		if cylinder == null:
			continue
		var ground: float = terrain.height_at(xz)
		var bottom := nearest.global_position.y - cylinder.height * 0.5
		var top := nearest.global_position.y + cylinder.height * 0.5
		_expect(cylinder.height >= MIN_COLLISION_HEIGHT - EPSILON, "Grove obstacle %d has a %.2f m collision cylinder; the actor capsule needs at least %.1f m." % [index, cylinder.height, MIN_COLLISION_HEIGHT])
		_expect(bottom <= ground + GROUND_TOLERANCE, "Grove obstacle %d collision floats %.2f m above the ground." % [index, bottom - ground])
		_expect(top >= ground + MIN_COLLISION_GROUND_REACH, "Grove obstacle %d collision only reaches %.2f m above the ground." % [index, top - ground])


## Visuals must be grounded and paired one-to-one with the authored obstacles,
## with a boulder cluster for boulder obstacles and a trunk plus canopy for
## trunk obstacles.
func _check_grove_visuals(world: Node, terrain: ValleyTerrain, obstacles: Array) -> void:
	var environment := world.visual_environment as VisualEnvironment
	_expect(environment != null, "The chapter has no VisualEnvironment for the grove visuals.")
	if environment == null:
		return
	var visuals := _collect_grove_visuals(environment)
	var expected_boulders := 0
	var expected_trees := 0
	for obstacle in obstacles:
		var kind := String(obstacle.get("kind", ""))
		if kind == "boulder":
			expected_boulders += 1
		elif kind == "trunk":
			expected_trees += 1
	var actual_boulders := 0
	var actual_trees := 0
	for visual in visuals:
		if visual["kind"] == "boulder":
			actual_boulders += 1
		else:
			actual_trees += 1
	_expect(actual_boulders == expected_boulders, "VisualEnvironment has %d GroveBoulder* nodes; the layout authors %d boulders." % [actual_boulders, expected_boulders])
	_expect(actual_trees == expected_trees, "VisualEnvironment has %d GroveTree* nodes; the layout authors %d trunks." % [actual_trees, expected_trees])
	var matched := {}
	for index in range(obstacles.size()):
		var obstacle: Dictionary = obstacles[index]
		var xz: Vector2 = obstacle.get("xz", Vector2.ZERO)
		var kind := String(obstacle.get("kind", ""))
		var best := -1
		var best_distance := INF
		for visual_index in range(visuals.size()):
			if matched.has(visual_index):
				continue
			var visual: Dictionary = visuals[visual_index]
			if visual["kind"] != kind:
				continue
			var candidate: Node3D = visual["node"]
			var distance := Vector2(candidate.global_position.x, candidate.global_position.z).distance_to(xz)
			if distance < best_distance:
				best_distance = distance
				best = visual_index
		_expect(best >= 0 and best_distance <= VISUAL_MATCH_RADIUS, "No grounded %s visual matches grove obstacle %d at %s." % [kind, index, str(xz)])
		if best < 0:
			continue
		matched[best] = true
		var visual_node: Node3D = visuals[best]["node"]
		var visual_xz := Vector2(visual_node.global_position.x, visual_node.global_position.z)
		var offset := visual_node.global_position.y - terrain.height_at(visual_xz)
		_expect(absf(offset) <= GROUND_TOLERANCE, "Grove visual %s is %.3f m from the terrain instead of grounded within %.2f m." % [str(visual_node.name), offset, GROUND_TOLERANCE])
		var meshes := visual_node.find_children("*", "MeshInstance3D", true, false)
		var composition := "boulder cluster" if kind == "boulder" else "trunk plus canopy"
		_expect(meshes.size() >= 2, "Grove visual %s has %d mesh parts; a %s needs at least two." % [str(visual_node.name), meshes.size(), composition])


func _collect_grove_visuals(environment: Node) -> Array:
	var visuals: Array = []
	var prefixes := {"GroveBoulder": "boulder", "GroveTree": "trunk"}
	for node in environment.find_children("*", "", true, false):
		if not node is Node3D:
			continue
		var node_name := String(node.name)
		for prefix: String in prefixes:
			if not node_name.begins_with(prefix):
				continue
			var index_text := node_name.substr(prefix.length())
			if index_text.is_valid_int():
				visuals.append({"node": node, "kind": prefixes[prefix], "index": int(index_text)})
			break
	return visuals


func _check_visual_environment_collision_free(world: Node) -> void:
	var environment := world.visual_environment as Node
	if environment == null:
		return
	var collisions := environment.find_children("*", "CollisionObject3D", true, false)
	var description := "VisualEnvironment must not add CollisionObject3D nodes; found %d." % collisions.size()
	if not collisions.is_empty():
		description += " First offender: %s." % str(collisions[0].get_path())
	_expect(collisions.is_empty(), description)


## The woodland opening must read as a small clearing landmark: a named group
## with the grass patch plus at least two perimeter plants, all grounded, all
## collider-free and all framing the centre instead of standing on it.
func _check_opening_visuals(world: Node, terrain: ValleyTerrain, opening: Vector2) -> void:
	var environment := world.visual_environment as VisualEnvironment
	if environment == null:
		return
	var group := environment.find_child("WoodlandOpening", true, false) as Node3D
	_expect(group != null, "VisualEnvironment is missing the WoodlandOpening group.")
	if group == null:
		return
	var grass := group.get_node_or_null("OpeningGrass") as MeshInstance3D
	_expect(grass != null, "The WoodlandOpening group has no OpeningGrass patch.")
	if grass != null:
		var grass_xz := Vector2(grass.global_position.x, grass.global_position.z)
		var grass_offset := grass.global_position.y - terrain.height_at(grass_xz)
		_expect(absf(grass_offset - 0.012) <= GROUND_TOLERANCE, "OpeningGrass sits %.3f m above the terrain instead of the authored 0.012 m patch offset." % grass_offset)
	var plants := 0
	for child in group.get_children():
		if not child is Node3D:
			continue
		var node_name := String(child.name)
		if not node_name.begins_with("Fern") and not node_name.begins_with("Bush"):
			continue
		plants += 1
		var plant := child as Node3D
		var plant_xz := Vector2(plant.global_position.x, plant.global_position.z)
		var offset := plant.global_position.y - terrain.height_at(plant_xz)
		_expect(absf(offset) <= GROUND_TOLERANCE, "Woodland opening plant %s is %.3f m from the terrain instead of grounded within %.2f m." % [node_name, offset, GROUND_TOLERANCE])
		var from_centre := plant_xz.distance_to(opening)
		_expect(from_centre >= OPENING_PLANT_MIN_RADIUS - EPSILON and from_centre <= OPENING_PLANT_MAX_RADIUS + EPSILON, "Woodland opening plant %s sits %.2f m from the centre; the clearing edge is %.1f-%.1f m out." % [node_name, from_centre, OPENING_PLANT_MIN_RADIUS, OPENING_PLANT_MAX_RADIUS])
	_expect(plants >= 2, "The WoodlandOpening group has %d ferns or bushes; at least two are required to frame the clearing." % plants)
	var collisions := group.find_children("*", "CollisionObject3D", true, false)
	_expect(collisions.is_empty(), "WoodlandOpening must not add CollisionObject3D nodes; found %d." % collisions.size())


func _check_actor_obstacle_clearance(positions: Array, obstacles: Array, label: String) -> void:
	_expect(not positions.is_empty(), "No actor positions were recorded on the %s leg." % label)
	for index in range(obstacles.size()):
		var obstacle: Dictionary = obstacles[index]
		var obstacle_xz: Vector2 = obstacle.get("xz", Vector2.ZERO)
		var radius: float = float(obstacle.get("radius", 0.0))
		var closest := INF
		for position: Vector2 in positions:
			closest = minf(closest, position.distance_to(obstacle_xz))
		_expect(closest >= radius + ACTOR_OBSTACLE_CLEARANCE - EPSILON, "The actor came within %.2f m of grove obstacle %d on the %s leg; at least %.2f m are required." % [closest, index, label, radius + ACTOR_OBSTACLE_CLEARANCE])


## Walking is optional exploration and must not change any durable gameplay
## progress, though an ordinary save may persist the migrated schema.
func _check_save_unchanged(before: Dictionary) -> void:
	var after := _read_save_dictionary(SAVE_TEST_DIRECTORY)
	_expect(not after.is_empty(), "The isolated save file is unreadable after the grove traversal.")
	if after.is_empty():
		return
	var before_progress := _save_progress_values(before)
	var after_progress := _save_progress_values(after)
	for key: String in before_progress.keys():
		_expect(after_progress.get(key) == before_progress[key], "The grove traversal changed durable progress %s from %s to %s." % [key, str(before_progress[key]), str(after_progress.get(key))])
	_expect(DamSave.validate_state(after), "The save file is not valid after the grove traversal.")


func _save_progress_values(state: Dictionary) -> Dictionary:
	var material_ids: Array = state.get("placed_materials", [])
	var placements: Array = []
	if state.get("placements", []) is Array and not state.get("placements", []).is_empty():
		for placement: Dictionary in state["placements"]:
			placements.append([placement.get("material_id", ""), int(placement.get("slot_index", -1)), placement.get("zone", "")])
	else:
		for index: int in range(material_ids.size()):
			placements.append([material_ids[index], index, "dam_fill"])
	var cut_tree_ids: Array = state.get("cut_tree_ids", [])
	if not state.has("cut_tree_ids") and (bool(state.get("tree_cut", false)) or material_ids.has("branch_normal_03")):
		cut_tree_ids = [DamSave.LEGACY_TREE_ID]
	return {
		"recipe_id": state.get("recipe_id", DamSave.LEGACY_RECIPE_ID),
		"placed_materials": material_ids,
		"placements": placements,
		"cut_tree_ids": cut_tree_ids,
		"solved_obstacles": state.get("solved_obstacles", []),
		"gnawed_materials": state.get("gnawed_materials", []),
		"bent_materials": state.get("bent_materials", []),
		"finish_choice": state.get("finish_choice", ""),
		"stage_completed": state.get("stage_completed", false),
		"home_slots": state.get("home_slots", ["", ""]),
		"food_placements": state.get("food_placements", []),
	}


func _read_save_dictionary(directory: String) -> Dictionary:
	var path := directory.path_join(DamSave.SAVE_FILE)
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var text := file.get_as_text()
	file.close()
	var parser := JSON.new()
	if parser.parse(text) != OK or not parser.data is Dictionary:
		return {}
	return parser.data


func _walk_until_arrived(world: Node, timeout_seconds: float) -> Dictionary:
	var positions: Array[Vector2] = []
	var deadline := Time.get_ticks_msec() + int(timeout_seconds * 1000.0)
	var arrived := false
	while Time.get_ticks_msec() < deadline:
		positions.append(_flat_xz(world.actor.global_position))
		if world.actor.is_arrived():
			arrived = true
			break
		await physics_frame
	if not arrived:
		arrived = world.actor.is_arrived()
	positions.append(_flat_xz(world.actor.global_position))
	return {"arrived": arrived, "positions": positions}


func _wait(condition: Callable, timeout_seconds: float = 15.0) -> bool:
	var deadline := Time.get_ticks_msec() + int(timeout_seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		await physics_frame
		if condition.call():
			return true
	return condition.call()


func _path_length(path: PackedVector3Array) -> float:
	var length := 0.0
	for index in range(1, path.size()):
		length += _flat_xz(path[index - 1]).distance_to(_flat_xz(path[index]))
	return length


func _flat_xz(point: Vector3) -> Vector2:
	return Vector2(point.x, point.z)
