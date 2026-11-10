class_name ValleyTerrain
extends RefCounted
## Deterministic authored terrain for the playable valley relief preview.
## One height grid backs the visible mesh, height queries, water and later
## collision/navigation. R1 only renders it; no physics is created here.

const PLAYABLE_RECT := Rect2(-6.5, -5.5, 13.0, 11.0)
const VARIANTS: Array[StringName] = [&"gentle", &"pronounced", &"wide_bank"]
const ROUTE_SLOPE_LIMIT_DEGREES: float = 20.0
const GRID_STEP: float = 0.25
const GRID_ORIGIN := Vector2(-20.0, -20.0)
const GRID_COLUMNS: int = 160
const GRID_ROWS: int = 160
const WATER_GRID_STEP: float = 0.2
const OVAL_RADIUS_X: float = 19.0
const OVAL_RADIUS_Z: float = 18.5
const CHANNEL_HALF_WIDTH: float = 1.05
const BANK_RUN: float = 2.7
const INITIAL_WATER_LEVEL: float = -0.28
const INTERMEDIATE_WATER_LEVEL: float = -0.16
const FULL_WATER_LEVEL: float = -0.06
const WATER_REACH_ALL: int = 0
const WATER_REACH_UPSTREAM: int = 1
const WATER_REACH_DOWNSTREAM: int = -1
const SKIRT_DEPTH: float = 1.8

var variant: StringName = &"gentle"
var _config: Dictionary = {}
var _heights := PackedFloat32Array()
var _terrain_mesh_cache: ArrayMesh
var _skirt_mesh_cache: ArrayMesh
var _water_mesh_cache: Dictionary = {}


func _init() -> void:
	configure(&"gentle")


func configure(new_variant: StringName) -> void:
	var configured_variant: StringName = new_variant if VARIANTS.has(new_variant) else &"gentle"
	if configured_variant == variant and not _heights.is_empty():
		return
	variant = configured_variant
	_terrain_mesh_cache = null
	_skirt_mesh_cache = null
	_water_mesh_cache.clear()
	match variant:
		&"pronounced":
			_config = {
				"hill_height": 3.4,
				"channel_depth": 0.92,
				"lake_depth": 1.02,
				"river_x": -4.2,
				"curve": 0.50,
				"basin_rx": 4.10,
				"basin_rz": 4.60,
				"dam_z": -1.20,
			}
		&"wide_bank":
			_config = {
				"hill_height": 2.2,
				"channel_depth": 0.76,
				"lake_depth": 0.86,
				"river_x": -5.0,
				"curve": 0.28,
				"basin_rx": 3.50,
				"basin_rz": 3.90,
				"dam_z": -1.60,
			}
		_:
			_config = {
				"hill_height": 2.8,
				"channel_depth": 0.84,
				"lake_depth": 0.94,
				"river_x": -4.5,
				"curve": 0.35,
				"basin_rx": 3.90,
				"basin_rz": 4.30,
				"dam_z": -1.40,
			}
	_rebuild_height_grid()


func display_name() -> String:
	return String(variant).replace("_", " ").capitalize()


func contains(xz: Vector2) -> bool:
	if not xz.is_finite():
		return false
	var angle := atan2(xz.y, xz.x)
	var wobble := 1.0 + 0.035 * sin(3.0 * angle + 0.7) + 0.02 * sin(5.0 * angle + 2.1)
	var qx := xz.x / (OVAL_RADIUS_X * wobble)
	var qz := xz.y / (OVAL_RADIUS_Z * wobble)
	return qx * qx + qz * qz <= 1.0


## Height on the actual visible/collision triangles (linear interpolation over
## the same 0.25 m grid used by terrain_mesh). Same surface everywhere.
func height_at(xz: Vector2) -> float:
	if not xz.is_finite():
		return 0.0
	var fx := (xz.x - GRID_ORIGIN.x) / GRID_STEP
	var fz := (xz.y - GRID_ORIGIN.y) / GRID_STEP
	if fx < 0.0 or fz < 0.0 or fx >= float(GRID_COLUMNS) or fz >= float(GRID_ROWS):
		return _field_height_at(xz)
	var ix := floori(fx)
	var iz := floori(fz)
	var tx := fx - float(ix)
	var tz := fz - float(iz)
	var h00 := _grid_height(ix, iz)
	var h10 := _grid_height(ix + 1, iz)
	var h01 := _grid_height(ix, iz + 1)
	var h11 := _grid_height(ix + 1, iz + 1)
	if tx >= tz:
		return h00 + tx * (h10 - h00) + tz * (h11 - h10)
	return h00 + tz * (h01 - h00) + tx * (h11 - h01)


func normal_at(xz: Vector2) -> Vector3:
	var epsilon := 0.06
	var dx := (height_at(Vector2(xz.x + epsilon, xz.y)) - height_at(Vector2(xz.x - epsilon, xz.y))) / (2.0 * epsilon)
	var dz := (height_at(Vector2(xz.x, xz.y + epsilon)) - height_at(Vector2(xz.x, xz.y - epsilon))) / (2.0 * epsilon)
	return Vector3(-dx, 1.0, -dz).normalized()


func slope_degrees(xz: Vector2) -> float:
	var normal := normal_at(xz)
	return rad_to_deg(acos(clampf(normal.y, -1.0, 1.0)))


func river_center_x(z: float) -> float:
	var base: float = float(_config["river_x"])
	var curve: float = float(_config["curve"])
	return base + curve * sin((z + 1.0) * 0.42) + 0.12 * sin(z * 0.9)


func channel_half_width() -> float:
	return CHANNEL_HALF_WIDTH


func dam_z() -> float:
	return float(_config["dam_z"])


func lake_center() -> Vector2:
	return lake_xz()


func lake_xz() -> Vector2:
	return Vector2(river_center_x(dam_z()) - 0.15, dam_z() - float(_config["basin_rz"]) * 0.85)


func lodge_xz() -> Vector2:
	return Vector2(-0.7, -3.5)


func initial_water_level() -> float:
	return INITIAL_WATER_LEVEL


func intermediate_water_level() -> float:
	return INTERMEDIATE_WATER_LEVEL


func full_water_level() -> float:
	return FULL_WATER_LEVEL


## True where the maximum lake footprint and the channel cover the ground.
## Navigation must treat these cells as blocked from the first frame.
func is_water_footprint(xz: Vector2) -> bool:
	return height_at(xz) < FULL_WATER_LEVEL + 0.02


## Prepared water surface at `xz` for a requested upstream level. The lake
## behind the dam follows the requested level; the downstream reach stays at
## the initial level, because a dam raises what is behind it, not the river
## below it. Returns -INF on dry ground.
func water_surface_height_at(xz: Vector2, level: float) -> float:
	if not xz.is_finite() or not contains(xz):
		return -INF
	var surface := level if xz.y < dam_z() else INITIAL_WATER_LEVEL
	if height_at(xz) >= surface - 0.005:
		return -INF
	return surface


func is_blocked_for_walking(xz: Vector2) -> bool:
	if not PLAYABLE_RECT.has_point(xz):
		return true
	if is_water_footprint(xz):
		return true
	return slope_degrees(xz) > ROUTE_SLOPE_LIMIT_DEGREES


## Visible terrain surface with per-vertex colours and grid normals.
func terrain_mesh() -> ArrayMesh:
	if _terrain_mesh_cache != null:
		return _terrain_mesh_cache
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_material(_terrain_material())
	for column in range(GRID_COLUMNS):
		for row in range(GRID_ROWS):
			var center := _grid_point(column, row) + Vector2(GRID_STEP, GRID_STEP) * 0.5
			if not contains(center):
				continue
			_append_terrain_vertex(surface, column, row)
			_append_terrain_vertex(surface, column + 1, row)
			_append_terrain_vertex(surface, column + 1, row + 1)
			_append_terrain_vertex(surface, column, row)
			_append_terrain_vertex(surface, column + 1, row + 1)
			_append_terrain_vertex(surface, column, row + 1)
	_terrain_mesh_cache = surface.commit()
	return _terrain_mesh_cache


## Static collision from the exact visible triangles. The body uses layer 1 so
## the actor and terrain rays agree with the rendered ground.
func build_collision_body(node_name: String = "ValleyCollision") -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.collision_layer = 1
	body.collision_mask = 0
	var collision := CollisionShape3D.new()
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(terrain_mesh().get_faces())
	collision.shape = shape
	body.add_child(collision)
	return body


## Prepared water surface for the whole valley: the lake uses `level` and the
## downstream reach stays at the initial level. The shore is clipped with the
## terrain triangles instead of emitting whole grid cells, so the water edge
## follows the bank instead of a visible staircase. `clear_xz`/`clear_radius`
## make a small clear-water window above the submerged food cache.
func water_mesh(level: float, clear_xz: Vector2 = Vector2.INF, clear_radius: float = 0.0) -> ArrayMesh:
	return _water_mesh_for(level, WATER_REACH_ALL, clear_xz, clear_radius)


## One reach of the prepared water. The playable chapter keeps the upstream
## lake and the downstream stream in separate meshes so a rising lake can be
## animated without lifting the river below the dam.
func water_mesh_reach(level: float, upstream: bool, clear_xz: Vector2 = Vector2.INF, clear_radius: float = 0.0) -> ArrayMesh:
	var reach := WATER_REACH_UPSTREAM if upstream else WATER_REACH_DOWNSTREAM
	return _water_mesh_for(level, reach, clear_xz, clear_radius)


func _water_mesh_for(level: float, reach: int, clear_xz: Vector2, clear_radius: float) -> ArrayMesh:
	var cache_key := "%s|%d|%s|%.2f" % [str(level), reach, str(clear_xz), clear_radius]
	if _water_mesh_cache.has(cache_key):
		return _water_mesh_cache[cache_key]
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_material(_water_material())
	var x_start := -19.0
	var z_start := -18.5
	var columns := int(round(38.0 / WATER_GRID_STEP))
	var rows := int(round(37.0 / WATER_GRID_STEP))
	for column in range(columns):
		for row in range(rows):
			var x0 := x_start + float(column) * WATER_GRID_STEP
			var x1 := x0 + WATER_GRID_STEP
			var z0 := z_start + float(row) * WATER_GRID_STEP
			var z1 := z0 + WATER_GRID_STEP
			var center := Vector2((x0 + x1) * 0.5, (z0 + z1) * 0.5)
			if not contains(center):
				continue
			var upstream := center.y < dam_z()
			if reach == WATER_REACH_UPSTREAM and not upstream:
				continue
			if reach == WATER_REACH_DOWNSTREAM and upstream:
				continue
			var cell_level := level if upstream else INITIAL_WATER_LEVEL
			_append_water_cell(surface, x0, z0, x1, z1, cell_level, upstream, clear_xz, clear_radius)
	var mesh := surface.commit()
	_water_mesh_cache[cache_key] = mesh
	return mesh


## Clip both terrain triangles of one water cell against the horizontal water
## plane. Vertices on the bank are interpolated, which removes the blocky water
## edge that made the shore read as a staircase in the previous flat mesh.
func _append_water_cell(surface: SurfaceTool, x0: float, z0: float, x1: float, z1: float, level: float, upstream: bool, clear_xz: Vector2, clear_radius: float) -> void:
	var sw := Vector2(x0, z0)
	var se := Vector2(x1, z0)
	var ne := Vector2(x1, z1)
	var nw := Vector2(x0, z1)
	var h_sw := height_at(sw)
	var h_se := height_at(se)
	var h_ne := height_at(ne)
	var h_nw := height_at(nw)
	_append_water_triangle(surface, sw, h_sw, se, h_se, ne, h_ne, level, upstream, clear_xz, clear_radius)
	_append_water_triangle(surface, sw, h_sw, ne, h_ne, nw, h_nw, level, upstream, clear_xz, clear_radius)


func _append_water_triangle(surface: SurfaceTool, a: Vector2, h_a: float, b: Vector2, h_b: float, c: Vector2, h_c: float, level: float, upstream: bool, clear_xz: Vector2, clear_radius: float) -> void:
	var input: Array = [[a, h_a], [b, h_b], [c, h_c]]
	var output: Array = []
	for index in range(3):
		var current: Array = input[index]
		var following: Array = input[(index + 1) % 3]
		var current_inside: bool = float(current[1]) <= level + 0.0001
		var following_inside: bool = float(following[1]) <= level + 0.0001
		if current_inside:
			output.append(current)
		if current_inside != following_inside:
			var current_xz: Vector2 = current[0]
			var following_xz: Vector2 = following[0]
			var t := (level - float(current[1])) / (float(following[1]) - float(current[1]))
			output.append([current_xz.lerp(following_xz, t), level])
	if output.size() < 3:
		return
	for index in range(1, output.size() - 1):
		_append_water_vertex(surface, output[0], level, upstream, clear_xz, clear_radius)
		_append_water_vertex(surface, output[index], level, upstream, clear_xz, clear_radius)
		_append_water_vertex(surface, output[index + 1], level, upstream, clear_xz, clear_radius)


func _append_water_vertex(surface: SurfaceTool, vertex: Array, level: float, upstream: bool, clear_xz: Vector2, clear_radius: float) -> void:
	var xz: Vector2 = vertex[0]
	var ground: float = vertex[1]
	var depth := maxf(level - ground, 0.0)
	surface.set_color(_water_color(depth, upstream, xz, clear_xz, clear_radius))
	surface.set_normal(Vector3.UP)
	surface.add_vertex(Vector3(xz.x, level + 0.008, xz.y))


## Irregular skirt around the terrain boundary. It hides the cut outer edge
## that made the valley read as a raised board, and extends below the visible
## frame as a continuation of the enclosing hills.
func boundary_skirt_mesh(depth: float = SKIRT_DEPTH) -> ArrayMesh:
	if _skirt_mesh_cache != null:
		return _skirt_mesh_cache
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_material(_skirt_material())
	var lip_color := Color("5d754b")
	var soil_color := Color("4a4539")
	for column in range(GRID_COLUMNS):
		for row in range(GRID_ROWS):
			var center := _grid_point(column, row) + Vector2(GRID_STEP, GRID_STEP) * 0.5
			if not contains(center):
				continue
			var x0 := GRID_ORIGIN.x + float(column) * GRID_STEP
			var x1 := x0 + GRID_STEP
			var z0 := GRID_ORIGIN.y + float(row) * GRID_STEP
			var z1 := z0 + GRID_STEP
			var neighbors := [
				[Vector2(0.0, -1.0), Vector2(x0, z0), Vector2(x1, z0), Vector3(0.0, 0.0, -1.0)],
				[Vector2(1.0, 0.0), Vector2(x1, z0), Vector2(x1, z1), Vector3(1.0, 0.0, 0.0)],
				[Vector2(0.0, 1.0), Vector2(x1, z1), Vector2(x0, z1), Vector3(0.0, 0.0, 1.0)],
				[Vector2(-1.0, 0.0), Vector2(x0, z1), Vector2(x0, z0), Vector3(-1.0, 0.0, 0.0)],
			]
			for neighbor_info in neighbors:
				var neighbor_center: Vector2 = center + Vector2(neighbor_info[0]) * GRID_STEP
				if contains(neighbor_center):
					continue
				var a: Vector2 = neighbor_info[1]
				var b: Vector2 = neighbor_info[2]
				var normal: Vector3 = neighbor_info[3]
				var h_a := height_at(a)
				var h_b := height_at(b)
				var top_a := Vector3(a.x, h_a, a.y)
				var top_b := Vector3(b.x, h_b, b.y)
				var lip_a := Vector3(a.x, h_a - 0.16, a.y)
				var lip_b := Vector3(b.x, h_b - 0.16, b.y)
				var bottom_a := Vector3(a.x, maxf(h_a - depth, -depth), a.y)
				var bottom_b := Vector3(b.x, maxf(h_b - depth, -depth), b.y)
				_append_skirt_quad(surface, top_a, top_b, lip_b, lip_a, normal, lip_color)
				_append_skirt_quad(surface, lip_a, lip_b, bottom_b, bottom_a, normal, soil_color)
	var mesh := surface.commit()
	_skirt_mesh_cache = mesh
	return mesh


func _append_skirt_quad(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, normal: Vector3, color: Color) -> void:
	for point in [a, b, c, a, c, d]:
		surface.set_color(color)
		surface.set_normal(normal)
		surface.add_vertex(point)


func _rebuild_height_grid() -> void:
	_heights.resize((GRID_COLUMNS + 1) * (GRID_ROWS + 1))
	for row in range(GRID_ROWS + 1):
		var z := GRID_ORIGIN.y + float(row) * GRID_STEP
		for column in range(GRID_COLUMNS + 1):
			var x := GRID_ORIGIN.x + float(column) * GRID_STEP
			_heights[row * (GRID_COLUMNS + 1) + column] = _field_height_at(Vector2(x, z))


func _grid_height(column: int, row: int) -> float:
	return _heights[row * (GRID_COLUMNS + 1) + column]


func _grid_point(column: int, row: int) -> Vector2:
	return GRID_ORIGIN + Vector2(float(column), float(row)) * GRID_STEP


func _grid_normal(column: int, row: int) -> Vector3:
	var left := _grid_height(maxi(column - 1, 0), row)
	var right := _grid_height(mini(column + 1, GRID_COLUMNS), row)
	var down := _grid_height(column, maxi(row - 1, 0))
	var up := _grid_height(column, mini(row + 1, GRID_ROWS))
	return Vector3(-(right - left) / (2.0 * GRID_STEP), 1.0, -(up - down) / (2.0 * GRID_STEP)).normalized()


## Analytic authored field. Only the grid samples and out-of-grid fallbacks use
## it; every public query uses the triangles that are actually visible.
func _field_height_at(xz: Vector2) -> float:
	if not xz.is_finite():
		return 0.0
	var x := xz.x
	var z := xz.y
	var height := 0.30 + 0.10 * sin(x * 0.60 + 0.3) * cos(z * 0.50 - 0.1)
	var shore_x := river_center_x(z) + CHANNEL_HALF_WIDTH + BANK_RUN
	height += 0.55 * smoothstep(0.0, 1.0, clampf((x - shore_x) / 7.0, 0.0, 1.0))
	height += 0.04 * sin(x * 1.15 - 0.7) * sin(z * 0.95 + 1.1)
	height += 0.06 * (0.5 + 0.5 * sin(x * 0.55 + 0.4)) * (0.5 + 0.5 * cos(z * 0.45 - 0.2))
	var river_x := river_center_x(z)
	var distance := absf(x - river_x)
	height += float(_config["hill_height"]) * _hill_weight(x, z, distance)

	var channel := 1.0 - smoothstep(CHANNEL_HALF_WIDTH, CHANNEL_HALF_WIDTH + BANK_RUN, distance)
	var carve := float(_config["channel_depth"]) * channel
	carve = maxf(carve, float(_config["lake_depth"]) * _lake_weight(x, z))
	height -= carve

	var mound := 0.35 * exp(-2.0 * pow(xz.distance_to(lodge_xz()) / 1.9, 2.0))
	mound *= 1.0 - _lake_weight(x, z)
	height += mound
	return height


func _hill_weight(x: float, z: float, distance_from_river: float) -> float:
	var west := 1.0 - smoothstep(-8.8, -5.8, x)
	var north := 1.0 - smoothstep(-8.0, -5.4, z)
	var weight := maxf(west, north)
	weight = maxf(weight, west * north * 1.15)
	weight *= smoothstep(2.2, 5.5, distance_from_river)
	weight *= 0.85 + 0.15 * sin(z * 0.55 + 0.9)
	return weight


func _lake_weight(x: float, z: float) -> float:
	var center := lake_xz()
	var dx := (x - center.x) / float(_config["basin_rx"])
	var dz := (z - center.y) / float(_config["basin_rz"])
	var q := sqrt(dx * dx + dz * dz)
	var bowl := 1.0 - smoothstep(0.15, 1.0, q)
	var upstream := 1.0 - smoothstep(dam_z() - 0.2, dam_z() + 0.6, z)
	return bowl * upstream


func _append_terrain_vertex(surface: SurfaceTool, column: int, row: int) -> void:
	var point := _grid_point(column, row)
	var height := _grid_height(column, row)
	var normal := _grid_normal(column, row)
	surface.set_color(_terrain_color(height, normal, point))
	surface.set_normal(normal)
	surface.add_vertex(Vector3(point.x, height, point.y))


func _terrain_color(height: float, normal: Vector3, xz: Vector2) -> Color:
	var slope := rad_to_deg(acos(clampf(normal.y, -1.0, 1.0)))
	if height < initial_water_level() - 0.02:
		var bed := Color("4f584a")
		if xz.y < dam_z():
			bed = bed.lerp(Color("4a5445"), 0.35)
		return bed
	if height < initial_water_level() + 0.045:
		var wet_t := clampf((height - initial_water_level()) / 0.045, 0.0, 1.0)
		return Color("7c7a5c").lerp(Color("89845f"), wet_t)
	if height < full_water_level() + 0.03:
		return Color("6c7f61").lerp(Color("788a67"), clampf((height - initial_water_level()) * 2.0, 0.0, 1.0))
	if height < full_water_level() + 0.17:
		var damp_t := clampf((height - (full_water_level() + 0.03)) / 0.14, 0.0, 1.0)
		return Color("7c8d68").lerp(Color("81966c"), damp_t)
	if slope > 30.0:
		return Color("6d7562")
	var variation := 0.5 + 0.5 * sin(xz.x * 0.45 + 0.8) * sin(xz.y * 0.38 - 0.4)
	var low := Color("738c60").lerp(Color("4f6b45"), variation * 0.8)
	var high := Color("809a6b").lerp(Color("5c774f"), variation * 0.7)
	return low.lerp(high, clampf((height - 0.15) / 2.6, 0.0, 1.0))


func _water_color(depth: float, upstream: bool, xz: Vector2, clear_xz: Vector2, clear_radius: float) -> Color:
	var shallow := Color("7aa98b") if upstream else Color("6f9f7a")
	var deep := Color("2f86b5") if upstream else Color("3f8f86")
	var t := clampf((depth - 0.05) / 0.5, 0.0, 1.0)
	var color := shallow.lerp(deep, t)
	var alpha := lerpf(0.52, 0.86, clampf(depth / 0.5, 0.0, 1.0))
	if depth < 0.08:
		var edge := 1.0 - depth / 0.08
		color = color.lerp(Color("d5e2c7"), edge * 0.35)
		alpha = lerpf(alpha, 0.34, edge * 0.8)
	if clear_radius > 0.0 and clear_xz.is_finite():
		var distance := xz.distance_to(clear_xz)
		if distance < clear_radius:
			var clear_t := 1.0 - smoothstep(clear_radius * 0.45, clear_radius, distance)
			color = color.lerp(Color("8fc4ae"), clear_t * 0.55)
			alpha = lerpf(alpha, 0.34, clear_t)
	return Color(color.r, color.g, color.b, clampf(alpha, 0.0, 1.0))


func _terrain_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = false
	material.roughness = 0.92
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


func _water_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = false
	material.albedo_color = Color.WHITE
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


func _skirt_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = false
	material.roughness = 0.96
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material
