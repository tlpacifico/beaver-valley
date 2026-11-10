class_name ValleyNavigation
extends RefCounted
## Shared 0.5 m AStarGrid2D routing over the authored terrain. A cell is solid
## when it is outside the playable rect, inside the maximum water footprint or
## channel, steeper than the route limit, or too close to such a cell for the
## actor's 0.26 m capsule. Paths are returned in world space, lifted onto the
## same triangles used for collision.

const CELL_SIZE: float = 0.5
const ACTOR_RADIUS: float = 0.26
const CLEARANCE_MARGIN: float = 0.04
const WAYPOINT_LIFT: float = 0.05
const INVALID_CELL := Vector2i(-999999, -999999)

var _terrain: ValleyTerrain
var _astar := AStarGrid2D.new()
var _origin: Vector2 = Vector2.ZERO
var _columns: int = 0
var _rows: int = 0


func configure(terrain: ValleyTerrain) -> void:
	_terrain = terrain
	_origin = ValleyTerrain.PLAYABLE_RECT.position
	_columns = int(round(ValleyTerrain.PLAYABLE_RECT.size.x / CELL_SIZE))
	_rows = int(round(ValleyTerrain.PLAYABLE_RECT.size.y / CELL_SIZE))
	_astar = AStarGrid2D.new()
	_astar.region = Rect2i(0, 0, _columns, _rows)
	_astar.cell_size = Vector2(CELL_SIZE, CELL_SIZE)
	_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_astar.update()
	for column in range(_columns):
		for row in range(_rows):
			var cell := Vector2i(column, row)
			_astar.set_point_solid(cell, _compute_solid(cell))


func cell_to_world(cell: Vector2i) -> Vector3:
	var center := world_xz(cell)
	return Vector3(center.x, _terrain.height_at(center) + WAYPOINT_LIFT, center.y)


func world_xz(cell: Vector2i) -> Vector2:
	return _origin + (Vector2(cell) + Vector2(0.5, 0.5)) * CELL_SIZE


func cell_at(world_xz: Vector2) -> Vector2i:
	return Vector2i(
		floori((world_xz.x - _origin.x) / CELL_SIZE),
		floori((world_xz.y - _origin.y) / CELL_SIZE)
	)


func is_cell_solid(cell: Vector2i) -> bool:
	if not _astar.is_in_boundsv(cell):
		return true
	return _astar.is_point_solid(cell)


func is_walkable(world_xz: Vector2) -> bool:
	var cell := cell_at(world_xz)
	if is_cell_solid(cell):
		return false
	return _is_point_walkable(world_xz)


func nearest_walkable_cell(world_xz: Vector2, max_radius: int = 2) -> Vector2i:
	var base := cell_at(world_xz)
	if not is_cell_solid(base):
		return base
	var best := INVALID_CELL
	var best_distance := INF
	for radius in range(1, max_radius + 1):
		for offset_x in range(-radius, radius + 1):
			for offset_y in range(-radius, radius + 1):
				if maxi(absi(offset_x), absi(offset_y)) != radius:
					continue
				var candidate := base + Vector2i(offset_x, offset_y)
				if is_cell_solid(candidate):
					continue
				var distance := world_xz(candidate).distance_squared_to(world_xz)
				if distance < best_distance:
					best_distance = distance
					best = candidate
	return best


## Strict route: the destination cell must itself be walkable. Returns an empty
## path instead of silently walking to a nearby cell through water or a hill.
func find_path(from: Vector3, to: Vector3) -> PackedVector3Array:
	if _terrain == null:
		return PackedVector3Array()
	var goal := cell_at(Vector2(to.x, to.z))
	if is_cell_solid(goal):
		return PackedVector3Array()
	if not _is_point_walkable(Vector2(to.x, to.z)):
		return PackedVector3Array()
	var start := nearest_walkable_cell(Vector2(from.x, from.z), 3)
	if start == INVALID_CELL:
		return PackedVector3Array()
	var cells := _astar.get_id_path(start, goal)
	if cells.is_empty():
		return PackedVector3Array()
	return _cells_to_world(cells)


## Route to the nearest usable cell around a target (R3 approaches).
func find_approach(from: Vector3, target_xz: Vector2, max_radius_cells: int = 3) -> PackedVector3Array:
	if _terrain == null:
		return PackedVector3Array()
	var base := cell_at(target_xz)
	var best_path := PackedVector3Array()
	var best_distance := INF
	for offset_x in range(-max_radius_cells, max_radius_cells + 1):
		for offset_y in range(-max_radius_cells, max_radius_cells + 1):
			var candidate := base + Vector2i(offset_x, offset_y)
			if is_cell_solid(candidate):
				continue
			var path := find_path(from, cell_to_world(candidate))
			if path.is_empty():
				continue
			var distance := world_xz(candidate).distance_squared_to(target_xz)
			if distance < best_distance:
				best_distance = distance
				best_path = path
	return best_path


func get_solid_cell_count() -> int:
	var count := 0
	for column in range(_columns):
		for row in range(_rows):
			if _astar.is_point_solid(Vector2i(column, row)):
				count += 1
	return count


func get_cell_count() -> int:
	return _columns * _rows


func _compute_solid(cell: Vector2i) -> bool:
	var center := world_xz(cell)
	if not _is_point_walkable(center):
		return true
	var clearance := ACTOR_RADIUS + CLEARANCE_MARGIN
	for index in range(8):
		var angle := TAU * float(index) / 8.0
		var sample := center + Vector2(cos(angle), sin(angle)) * clearance
		if not _is_point_walkable(sample):
			return true
	return false


func _is_point_walkable(point: Vector2) -> bool:
	if not ValleyTerrain.PLAYABLE_RECT.has_point(point):
		return false
	if _terrain.is_water_footprint(point):
		return false
	return _terrain.slope_degrees(point) <= ValleyTerrain.ROUTE_SLOPE_LIMIT_DEGREES


func _cells_to_world(cells: Array[Vector2i]) -> PackedVector3Array:
	var points := PackedVector3Array()
	for cell in cells:
		points.append(cell_to_world(cell))
	return points
